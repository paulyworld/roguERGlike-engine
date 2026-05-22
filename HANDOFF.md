# HANDOFF - roguERGlike-engine

> Current state of this repo. Updated at the end of every session that touches it. Read first.

**Last updated:** 2026-05-21
**Last session log:** `../../docs/sessions/2026-05-21-ftms-erg-end-to-end.md` (in umbrella)
**Current branch:** `docs/post-trainer-control-end-to-end-engine` (PR pending). Active feature work: `feat/mvp-playable-loop` (PR #4, ready for review), now with engine-driven ERG wiring.
**Current focus:** EffortBridge gained the trainer-control write API (merged on develop via PR #7). The MVP HIIT loop branch now calls `EffortBridge.set_target_power(...)` on each phase transition. **Next concrete action: live-validate engine-driven ERG against KICKR + Whoop.**

## Where we are

`develop` now includes the bridge's write-side API:

```gdscript
EffortBridge.set_target_power(watts: int)
EffortBridge.start()           # re-acquire control after stop
EffortBridge.stop()            # pause; can resume via start
EffortBridge.release_control() # explicit end-of-session
```

Plus new inbound signals: `device_disconnected`, `device_capabilities_changed`, `control_acquired`, `control_released`, `target_power_set`. The bridge tracks `supports_target_power: bool` driven by the sidecar's `device_capabilities` event — game UI should gate ERG features on this flag so a non-controllable trainer doesn't get UI affordances that do nothing.

The `feat/mvp-playable-loop` branch (engine PR #4, currently Ready for Review) is in a separate worktree at `repos/engine-mvp/`. The maintainer has evolved it substantially over the day: settings panel (weight, FTP, age, HR zones, warmup minutes), per-metric charts (split from one combined), big readouts, target feedback meters, turn-scoped energy, sidecar URL override, Start Workout button with explicit warmup phase. This session also merged develop into the branch and wired ERG writes at every phase transition — warmup entry + warmup ticks (chart-sample cadence + every 5s explicit), recovery entry, interval entry, reset / victory / defeat. All gated on `EffortBridge.supports_target_power` so the loop still plays even with a passive trainer or no sidecar.

The handshake test scene (`develop`'s `tests/test_main.tscn`) was extended in PR #7 to mirror the new control-lifecycle signals to stdout — useful for headless smoke tests of the bridge.

Sidecar pair status: trainer-control loop is shipped end-to-end on sidecar develop (capability discovery + control writes + control-lifecycle replay), and the write side has been live-validated against the KICKR via a Python WS probe. Engine-as-the-driver is the missing live data point — that's the upcoming test.

## What's next (immediate)

1. **Engine-driven ERG live validation against KICKR + Whoop.** Three windows: sidecar with `--allow-trainer-control --disconnect-bailout-s 900`, sidecar's `python scripts/record_session.py`, Godot on the `engine-mvp` worktree. Configure rider settings (suggest Warmup=2min for a faster first pass), press Start Workout, ride the warmup → recovery → interval cycle, confirm the trainer's resistance tracks the engine's intended targets. JSONL + screenshot become validation evidence.
2. **Merge PR #4 (MVP HIIT playable loop)** once the live test validates. The PR body needs a refresh first — current text predates this session's UX additions and the ERG wiring.
3. **Card-system foundation** on `feat/card-system-foundation`. Minimal `Effect: Resource` with `apply(context: CombatContext)` and `CombatContext: RefCounted` with hand/draw/discard piles. Resolves the `card.gd` parse errors and unblocks real card variety beyond the MVP's two hard-coded cards (Power Strike, Cadence Guard).

Other directions (not blocking):
- **Real headless test runner** (GUT or hand-rolled) — the CI's `godot-headless-tests` step currently runs with `|| true`, so it boots Godot but doesn't actually fail on assertions.
- **Multi-platform export config** (Windows / Mac / Linux / web / iOS / Android) — long-term, not designed yet.
- **Engine derived signals** (`effort_surge_*`, `hr_zone_changed`, `effort_pulse`) — wired through the bridge but no producer in the sidecar yet. Defer until at least one full recorded ride exists to derive from.

## Open threads

- **`card.gd` parse errors** — references undefined `Effect` / `CombatContext`. Not fatal (no autoload depends on `Card`), but blocks card variety. Land alongside the foundation branch.
- **CardRegistry is a no-op stub.** Flesh out alongside card-system work.
- **MVP scene lives under `tests/`** — once a real test runner lands and the loop is more than a prototype, it should move out of `tests/` (probably to `repos/game/`, per the engine/game boundary in the per-repo CLAUDE.md docs).
- **No GUT or test-runner integration yet** — `tests/` currently holds the MVP scene (which functions as both the test and the prototype). Once a real runner lands, the scene should move out.
- **F5 in Godot remains flaky** for "run main scene" — the ▶ Play button in the editor toolbar is the reliable launcher.

## Notes for next session

- The effort bridge (`src/effort/effort_bridge.gd`) is the contract surface with the sidecar — coordinate changes with the sidecar repo and update its `event-schema.md` first.
- Run the sidecar before launching the engine. For real telemetry + ERG: `roguerglike-sidecar --mode live --device-bike "KICKR" --device-hr "mudrat" --allow-trainer-control`. For off-bike iteration: `--mode mock --allow-trainer-control`.
- The MVP loop is on `feat/mvp-playable-loop`, checked out in a separate worktree at `repos/engine-mvp/`. Launch Godot with `--path C:\dev\roguERGlike\repos\engine-mvp` (not the main `repos/engine` checkout).
- KICKR LED diagnostic stays useful: solid blue = sidecar has it; blinking = available.

## Entry point for next session

> "Resume engine-driven ERG live validation. Sidecar in one window with `--allow-trainer-control --disconnect-bailout-s 900`. `python scripts/record_session.py` in another. `godot --path C:\dev\roguERGlike\repos\engine-mvp` in a third. Press Start Workout, ride through warmup → recovery → interval, confirm trainer resistance tracks the engine-driven targets. If green: refresh PR #4's body to reflect the full session's work, then merge. If anything's off, fix in `feat/mvp-playable-loop` before merging."
