# HANDOFF — roguERGlike-engine

> Current state of this repo. Updated at the end of every session that touches it. Read first.

**Last updated:** 2026-05-20
**Last session log:** `../../docs/sessions/2026-05-20-bike-integration-handshake.md` (in umbrella)
**Current branch:** `feat/handshake-test-scene` (PR #1) + `docs/handoff-refresh` (PR pending)
**Current focus:** Sidecar handshake test scene shipped and validated end-to-end; PR #1 awaiting review.

## Where we are

The handshake test scene (`tests/test_main.tscn` + `.gd`) connects to the sidecar over WebSocket via the existing `EffortBridge` autoload, renders live power / cadence / heart-rate values, and mirrors every event to stdout for headless verification. End-to-end against sidecar mock mode confirmed: typed signals (`power_changed`, `cadence_changed`, `heart_rate_changed`, `device_connected`) fire with exactly the values driven through the sidecar's slider UI. Project now boots cleanly headless — `CardRegistry` autoload was a missing-file failure, now stubbed.

## What's next (immediate)

1. **Merge PR #1.** Watch first CI run (gdlint + headless Godot in Docker + gitleaks); per `github-actions-first-push-quirk`, the first push may not auto-trigger Actions.
2. **Tighten CI.** The headless test step currently runs with `|| true` — needs a real test runner (GUT, or hand-rolled assertion in `test_main.gd`) so failures actually fail.
3. **Card system kickoff.** `card.gd` references undefined `Effect` and `CombatContext`; define minimal base classes (`Effect: Resource` with `apply(context)`, `CombatContext: RefCounted` with hand/draw/discard piles) so the card system can grow.

## Open threads

- **`card.gd` parse errors** — still references undefined `Effect` and `CombatContext`. Reordered for `gdlint` in PR #1 but the underlying types don't exist; not fatal because no autoload depends on `Card`.
- **CardRegistry is a no-op stub** — untyped `Dictionary` so it doesn't depend on `Card`'s parse state. Flesh out alongside card-system work.
- **Derived signals on `EffortBridge`** (`effort_surge_*`, `hr_zone_changed`, `effort_pulse`) are wired and logged by the test scene, but the sidecar has no producer for them yet — they'll start firing once Phase 2 BLE / derivers ship.
- **Multi-platform export config** (Windows / Mac / Linux / web / iOS / Android) not yet set up.
- **No GUT or test-runner integration yet** — `tests/` currently holds the handshake scene only.

## Notes for next session

- The effort bridge (`src/effort/effort_bridge.gd`) is the contract surface with the sidecar — coordinate changes with the sidecar repo and update `event-schema.md` first.
- Run the sidecar in mock mode (`roguerglike-sidecar --mode mock`) before launching the engine; otherwise `test_main` shows "disconnected" forever.
- Headless: `godot --headless --quit-after 180` (frames, ≈3s at 60fps) is enough to capture several 1 Hz mock ticks.

## Entry point for next session

> "After PR #1 merges, define minimal `Effect` and `CombatContext` base classes so `card.gd` parses cleanly, then start the encounter loop skeleton (turn order, hand/draw/discard piles, basic effects: damage/block/draw) on a `feat/combat-loop` branch."
