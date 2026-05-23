# HANDOFF - roguERGlike-engine

> Current state of this repo. Updated at the end of every session that touches it. Read first.

**Last updated:** 2026-05-23
**Current branch:** `develop`
**Base branch:** `develop`
**Current focus:** **Core riding infrastructure, not promotion of the Godot MVP loop.** User decision on 2026-05-23: focus near-term product energy on `repos/concert-mvp`, which currently feels like the better riding experience, while shipping Pattern B pause/resume as MVP-agnostic sidecar infrastructure with thin client adapters.

**Next-step ownership convention:** When recommending next steps, include who should do each item based on the current split. For now, Claude owns sidecar/protocol/runtime work; Codex owns engine/client bridge work and can also take concert-mvp UI/client tasks when requested. This split is fluid and can change later.

## Where we are

The engine `develop` branch contains:

- **Handshake test scene** that subscribes to the sidecar WebSocket and renders live telemetry.
- **`EffortBridge` autoload** with the full read+write surface: power/cadence/HR/speed signals, device-capabilities/control-acquired/target-power-set acks, cadence-bailout engaged/disengaged signals, `is_cadence_paused` state. Write methods for `set_target_power`, `start`, `stop`, `release_control`.

A separate experimental branch:

```text
feat/mvp-playable-loop -> PR #4 (still open)
```

This branch was used as the engine surface in the first end-to-end live ride. It works, but it is **not** the primary near-term product direction. Keep it as a validated side experiment unless the user explicitly reopens the Godot/deck-builder MVP direction.

## Live ride validation (2026-05-22)

- Sidecar: KICKR CORE 1003 + Whoop MG5, ERG control enabled, intensity-aware bailout active.
- Engine: `feat/mvp-playable-loop` MVP scene drove ERG targets via phase transitions.
- Result: end-to-end loop confirmed. Engine pushed targets, sidecar applied them, trainer responded.
- Observation: cadence bailout fired three times in about 10 minutes. Timing was correct per the intensity-aware formula, but all three were during legitimate between-round UI moments. This surfaced the safety-vs-pause architecture concern.

## Pause architecture decision

Documented in `repos/sidecar/docs/architecture/safety-vs-pause.md` (PR #18, merged).

**Cadence bailout is a safety mechanism, not game flow.** Between-round pauses, menu interactions, video pauses, and authored workout breaks need their own pause primitive. Two valid implementations exist:

- **Pattern A - Client-side soft pause** (`repos/concert-mvp`, shipped 2026-05-22). Client sends low `set_target_power` on its own pause condition. No sidecar contract change. Best for user-gesture pauses such as YouTube pause/resume.
- **Pattern B - Sidecar-side suspend** (now planned as core riding infrastructure, not engine-MVP-specific). Client sends `pause` / `resume` commands; sidecar suspends the cadence watcher and sets an easy-spin wattage. Better for code-driven phase boundaries, authored workout breaks, or any explicit workout-clock suspend.

Decision recorded 2026-05-23: Pattern B should be implemented first in `repos/sidecar` as a protocol capability (`pause` / `resume` commands plus `paused` / `resumed` envelopes), then exposed through thin wrappers in clients. For this engine repo, that means adding generic `EffortBridge.pause_effort(...)` / `resume_effort()` support on `develop`, not merging the whole Godot MVP loop just to get pause behavior.

See `docs/riding-infrastructure-direction.md` for the durable decision note.
See `docs/concert-product-roadmap.md` for the product roadmap, profile explanation, F2 annotation direction, packaging guidance, and cross-repo ownership map.
See `docs/training-platform-export-research.md` for Strava / TrainingPeaks / training-platform export direction.
See `docs/concert-mode-exploration.md` for terrain mode, shifting, leaderboards, and group-ride exploration.
See `docs/claude-sidecar-review-brief.md` for the sidecar implementation packet to review before coding.

## What's next

1. **Claude / sidecar:** ship the next protocol foundation. Review `docs/claude-sidecar-review-brief.md`; then implement protocol feature negotiation, annotation recording, Pattern B structured pause, distance/export groundwork, and later terrain/SIM support in the order agreed there.
2. **Codex / concert-mvp:** add client UX around sidecar capabilities as they land: F2 annotations, post-ride export/upload controls, Terrain Mode prototype, local results, and UI-only shifting.
3. **Codex / engine:** add generic Godot bridge support only after sidecar schema lands. Engine should expose `pause_effort(reason, target_watts)` / `resume_effort()` and `effort_paused` / `effort_resumed` signals without depending on the deck-builder MVP branch.
4. **Server owner later:** own authenticated leaderboards, group-ride rooms, public rankings, anti-cheat policy, and account/privacy surfaces once local ghosts and private results are validated.
5. **Keep concert-mvp as the primary riding UX for now.** Concert can continue Pattern A for YouTube play/pause, then optionally adopt Pattern B for authored workout breaks or explicit structured pauses.
6. **Keep `feat/mvp-playable-loop` as a validated side experiment.** Do not promote it by default; revisit only if the user explicitly chooses to return to the Godot/deck-builder MVP.
7. **Card-system foundation** (`Effect: Resource` + `CombatContext: RefCounted`) remains useful engine work, but it is not the immediate riding-infrastructure priority.

## Open threads

- **PR #4 is still open**, marked as side experiment. Live-validated but not the near-term product focus.
- **`tests/telemetry_chart.gd`** is a test harness chart from the MVP branch, not yet a reusable UI primitive.
- **Distance** is decoded by the sidecar but not yet surfaced via EffortBridge; wire up when distance deriver lands in the sidecar.
- **Multi-platform export config** is not set up.
- **Real test runner**: current Godot headless boot checks are useful but not true assertions.

## How to run

### MVP without a bike (mock mode)

```powershell
# Window 1
cd C:\dev\roguERGlike\repos\sidecar
./scripts/run-live-test.ps1 -Mock

# Open mock slider UI: http://localhost:8422

# Window 2
cd C:\dev\roguERGlike\repos\engine-mvp     # worktree on feat/mvp-playable-loop
& "C:\Program Files\Godot\Godot_v4.6-stable_win64.exe" --path . tests/test_main.tscn
```

### MVP with the bike

```powershell
# Window 1
cd C:\dev\roguERGlike\repos\sidecar
./scripts/run-live-test.ps1                # defaults: KICKR + mudrat + FTP 250 + ERG control

# Optional: capture telemetry to JSONL
./scripts/record-session.ps1

# Window 2
cd C:\dev\roguERGlike\repos\engine-mvp
& "C:\Program Files\Godot\Godot_v4.6-stable_win64.exe" --path . tests/test_main.tscn
```

## Sibling MVP: `repos/concert-mvp`

`repos/concert-mvp/` is now the primary near-term riding experience. It is a browser-based YouTube-driven ERG controller that maps video time + rider FTP/weight to target watts via a manually authored rolling concert profile.

It already implements Pattern A client-side pause. Do not force Pattern B into ordinary YouTube play/pause just for symmetry. Pattern B becomes useful there for structured workout pauses: authored breaks, intermissions, explicit workout-clock suspend, or other moments where the cadence-bailout timer should stop.

## Entry point for next session

> "User chose to focus on `repos/concert-mvp` as the primary riding experience and ship Pattern B as core riding infrastructure, not as a reason to promote the Godot MVP. Start with sidecar `pause`/`resume` protocol support (`paused`/`resumed` envelopes, cadence-bailout suspension, easy-spin target), then add generic `EffortBridge.pause_effort(...)` / `resume_effort()` support on engine `develop`. Keep `feat/mvp-playable-loop` as a validated side experiment unless explicitly reopened."
