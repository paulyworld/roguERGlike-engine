# HANDOFF — roguERGlike-engine

> Current state of this repo. Updated at the end of every session that touches it. Read first.

**Last updated:** 2026-05-12
**Last session log:** `../../docs/sessions/2026-05-12-repo-setup-and-conventions.md` (in umbrella)
**Current branch:** none — not yet `git init`'d
**Current focus:** Repo not yet bootstrapped.

## Where we are

Skeleton exists (README, LICENSE, CLA, CONTRIBUTING, CHANGELOG, project.godot, .gitignore, CI workflow). Effort bridge (`src/effort/effort_bridge.gd`) is real working code that subscribes to the sidecar's WS and emits device-neutral signals. Card base class skeleton in place. Modality framework documented in `docs/modality-framework.md`.

## What's next (immediate)

1. `git init -b main`, push as `roguERGlike-engine` (public)
2. Branch protection on `main`
3. Once sidecar mock mode is up, build a minimal Godot test scene that displays the live event stream — proves the contract end-to-end
4. Start fleshing out the card system: `CombatContext`, basic effects (damage, block, draw), encounter loop skeleton

## Open threads

- The mechanical models (energy / charge / zone / asymmetric) from `repos/game/docs/design/mechanic-experiments.md` will need a `RuleSet` interface defined here in the engine before any of them can be prototyped
- Modality framework documented but not implemented — wait until at least one mechanical model exists to consume it
- Multi-platform export config (Windows/Mac/Linux/web/iOS/Android) not yet set up

## Notes for next session

- The effort bridge is the contract surface with the sidecar — changes to it should be coordinated with the sidecar repo
- Avoid creep: anything game-specific belongs in `repos/game`, not here

## Entry point for next session

> "After sidecar mock mode is running, build a Godot test scene that visualizes the live event stream and proves the WS contract works end-to-end."
