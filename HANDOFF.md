# HANDOFF — roguERGlike-engine

> Current state of this repo. Updated at the end of every session that touches it. Read first.

**Last updated:** 2026-05-21
**Last session log:** `../../docs/sessions/2026-05-21-hardware-validation-and-merges.md` (in umbrella)
**Current branch:** `docs/post-phase-2-merge-engine` (PR pending); `feat/handshake-test-scene` + `docs/handoff-refresh` merged; `feat/mvp-playable-loop` in flight as draft PR #4
**Current focus:** Handshake test scene merged and **live-validated against a real KICKR CORE 1003**. MVP HIIT playable loop is in flight on a separate branch (draft PR #4).

## Where we are

The `tests/test_main.tscn` handshake scene works end-to-end against the sidecar's `--mode live`. Real `power_changed` / `cadence_changed` signals fire on the `EffortBridge` autoload as the rider pedals; the labels update in real time. Project boots cleanly headless and in the editor; `CardRegistry` autoload is a no-op stub (was the missing-file failure that blocked boot during the handshake PR).

A separate branch `feat/mvp-playable-loop` is in flight (draft PR #4) — a prototype HIIT card-game loop driven by the live telemetry. Also has uncommitted local edits stashed (`git stash list` shows "mvp-playable-loop WIP — saved before connection-test branch switch 2026-05-21") from when we briefly switched branches for the clean connection test.

## What's next (immediate)

1. **Resume the MVP HIIT playable loop.** `git checkout feat/mvp-playable-loop && git stash pop` to restore the WIP edits. Continue building the card-game prototype; you can now drive it from a real KICKR (or `--mode mock` for off-bike iteration). When ready for review, replace the draft PR #4 body with summary + test plan and mark Ready for review.
2. **Card-system foundation** (a prerequisite either way). `card.gd` still references undefined `Effect` and `CombatContext`. Minimal defines (`Effect: Resource` with `apply(context)`, `CombatContext: RefCounted` with hand/draw/discard piles) on a `feat/card-system-foundation` branch unblock real card work.
3. **Tighten CI**: the `godot-headless-tests` job in `.github/workflows/ci.yml` runs with `|| true` — booting Godot is verified but no assertion fails. Replace with a real headless test runner (GUT, or a hand-rolled scene that exits non-zero on failure).

## Open threads

- **Stashed WIP** on `feat/mvp-playable-loop`: `git stash list` to find, `git stash pop` to restore. Don't lose it.
- **`card.gd` parse errors** — references undefined `Effect` and `CombatContext`. Reordered for `gdlint` in PR #1 but the underlying types still don't exist; not fatal because no autoload depends on `Card`.
- **CardRegistry is a no-op stub** — flesh out alongside card-system work.
- **Derived signals on `EffortBridge`** (`effort_surge_*`, `hr_zone_changed`, `effort_pulse`) are wired and the test scene logs them, but the sidecar has no producer for them yet — they'll start firing once Phase 2 BLE has been running long enough to derive (or once a dedicated deriver lands sidecar-side).
- **Multi-platform export config** (Windows / Mac / Linux / web / iOS / Android) not yet set up.
- **No GUT or test-runner integration yet** — `tests/` currently holds the handshake scene only.
- **First CI runs** — `statusCheckRollup` was empty on merged PRs; matches the `github-actions-first-push-quirk` memory. Next PR push should be the first real CI run.

## Notes for next session

- The effort bridge (`src/effort/effort_bridge.gd`) is the contract surface with the sidecar — coordinate changes with the sidecar repo and update `event-schema.md` first.
- Run the sidecar before launching the engine; otherwise `test_main` shows "disconnected". For real telemetry: `roguerglike-sidecar --mode live --device-bike "<name>"`. For development without the bike: `--mode mock`.
- Godot 4 keys: **F5** = run project's main scene; **F6** = run currently-open scene; the ▶ Play button always works. If F5 silently no-ops, try F6 or the button.
- KICKR LED: solid blue = one BLE host connected (us); blinking = advertising. Use this as a fast diagnostic when "no data" appears in the engine.
- Headless: `godot --headless --quit-after 240` (frames, ≈4s at 60fps) is enough to capture several mock ticks; use `--quit-after 1200` (~20s) for a real-bike check while you pedal.

## Entry point for next session

> "Restore stashed WIP on `feat/mvp-playable-loop` (`git stash list` → `git stash pop`) and continue the HIIT playable loop with real bike data wired in. If the `card.gd` parse errors are in the way, branch `feat/card-system-foundation` first and define minimal `Effect` (Resource with `apply(context)`) and `CombatContext` (RefCounted with hand/draw/discard piles) base classes — small, blocks the larger card work."
