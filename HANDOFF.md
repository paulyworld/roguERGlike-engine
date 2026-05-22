# HANDOFF - roguERGlike-engine

> Current state of this repo. Updated at the end of every session that touches it. Read first.

**Last updated:** 2026-05-21
**Last session log:** `../../docs/sessions/2026-05-21-cadence-bailout-paused-mid-validation.md` (in umbrella)
**Current branch:** `docs/post-cadence-bailout-paused-engine` (PR pending). Active feature work: `feat/mvp-playable-loop` (PR #4 Ready for Review). Live engine-driven ERG validation against KICKR is still pending.
**Current focus:** EffortBridge now mirrors the sidecar's cadence-bailout events (merged via PR #9). MVP HIIT loop is ready to pick up the new signals when it next merges develop. **Engine-as-driver ERG validation has not yet had a green live ride** — three sidecar bugs (in develop today) blocked the most recent attempt; small follow-up sidecar PR is queued next.

## Where we are

`develop` now includes the complete bridge contract for trainer control + cadence safety:

- **Write API** (from PR #7): `set_target_power(int)`, `start()`, `stop()`, `release_control()`.
- **Inbound signals**: `device_connected`, `device_disconnected`, `device_capabilities_changed`, `control_acquired`, `control_released`, `target_power_set`, plus (new this session) `cadence_bailout_engaged`, `cadence_bailout_disengaged`.
- **State properties**: `supports_target_power: bool` (gate ERG UI on this), `is_cadence_paused: bool` (gate a "PAUSED — start pedalling" overlay on this).

The handshake test scene in `tests/test_main.tscn` connects every signal and mirrors them to stdout — useful for headless smoke checks against any sidecar config.

The MVP HIIT loop branch (`feat/mvp-playable-loop`, engine PR #4, Ready for Review) is the active game-side work. The maintainer + Codex have evolved it substantially: settings panel, per-metric charts, big readouts, target meters, warmup phase with ERG ramp, ERG step-test workout, ERG ramp-test workout, full HIIT encounter loop. The scene's ERG-write wiring (`_apply_warmup_target`, `_apply_recovery_target`, `_apply_interval_target`, `_release_trainer`) all gate on `EffortBridge.supports_target_power`.

When this branch merges to develop or develops merges into it, the new bailout signals are available automatically (EffortBridge is autoloaded). The MVP scene can opt in to a `is_cadence_paused` overlay in a small future commit.

## What's next (immediate)

1. **Wait on sidecar `fix/bailout-startup-and-scan-ux`** (queued, ~45 min sidecar-side PR). Fixes three real bugs surfaced during the most recent live-test attempt: premature bailout timing, fail-once scan UX, missing "claimed control" log line.
2. **Engine-driven ERG live validation against KICKR**. Run the MVP scene through warmup → recovery → interval (or use the ERG Step Test workout for the cleanest signal). Goal: confirm `set_target_power` writes from the engine reach the trainer in real time, AND that the cadence-bailout correctly disengages + re-engages as the rider stops/starts pedalling.
3. **Merge PR #4** once the validation pass is green.

Other directions (not blocking):
- **Card-system foundation** on `feat/card-system-foundation` — minimal `Effect: Resource` with `apply(context: CombatContext)` and `CombatContext: RefCounted` with hand/draw/discard piles. Resolves `card.gd` parse errors and unblocks card variety beyond the MVP's two hard-coded cards (Power Strike, Cadence Guard).
- **Real headless test runner** (GUT or hand-rolled) — current CI `godot-headless-tests` step runs with `|| true`; boots Godot but doesn't enforce assertions.
- **Engine derived signals** (`effort_surge_*`, `hr_zone_changed`, `effort_pulse`) — wired through the bridge, no sidecar producer yet. Defer until at least one full recorded ride exists to derive from.

## Open threads

- **`card.gd` parse errors** — references undefined `Effect` / `CombatContext`. Not fatal (no autoload depends on `Card`), but blocks card variety.
- **CardRegistry is a no-op stub**. Flesh out with card-system work.
- **MVP scene lives under `tests/`** — once a real test runner lands and the loop is more than a prototype, move it to `repos/game/` per the engine/game boundary.
- **No GUT or test-runner integration yet** — `tests/` currently holds the MVP scene.
- **F5 in Godot remains flaky** for "run main scene". The ▶ Play button is the reliable launcher.
- **MVP loop's UI doesn't surface `target_power_set` rejections** to the rider. The bridge fires the signal but the MVP scene doesn't connect to it. When the operator forgets `--allow-trainer-control`, the rider sees "trainer isn't responding" with no clue why. Worth wiring up in the next MVP-side touch: log to the existing log_label.

## Notes for next session

- The effort bridge (`src/effort/effort_bridge.gd`) is the contract surface with the sidecar — coordinate changes with the sidecar repo and update its `event-schema.md` first.
- Run the sidecar BEFORE launching the engine. For real telemetry + ERG: `roguerglike-sidecar --mode live --device-bike "KICKR" --device-hr "mudrat" --allow-trainer-control --rider-ftp 250`. The flag set matters; missing `--allow-trainer-control` is a silent failure on the engine side today (until the bridge starts listening for `target_power_set accepted=false`).
- The MVP loop is on `feat/mvp-playable-loop`, checked out in a separate worktree at `repos/engine-mvp/`. Launch Godot with `--path C:\dev\roguERGlike\repos\engine-mvp` (not the main `repos/engine` checkout).
- **The KICKR's blue LED is NOT a "control claimed" indicator** — solid blue just means BLE GATT connected. Use the sidecar log (once the upcoming `claimed control of <device>` line lands) or the bridge's `control_acquired` signal for authoritative state.

## Entry point for next session

> "Wait for sidecar `fix/bailout-startup-and-scan-ux` PR to land on sidecar develop, then retry engine-driven ERG live validation against KICKR via the MVP scene's ERG Step Test workout. Confirm: `target_power_set` events flow back accepted=true as phases drive the trainer; cadence-bailout fires after the rider stops at a meaningful target and disengages cleanly when riding resumes. If green, merge engine PR #4 (MVP HIIT playable loop)."
