# CLAUDE.md — roguERGlike-engine

You're working in `roguERGlike-engine`, one of four repos in the roguERGlike project.

## Read first

1. `HANDOFF.md` (this directory)
2. `../../INSTRUCTIONS.md` (in the umbrella)
3. The umbrella's `HANDOFF.md` if your work touches multiple repos

## This repo's role

Generic Godot 4 framework for deck-builder roguelikes driven by real-time effort input. Card system primitives, combat loop, run framework, modality framework (interval timing + effort-band enforcement), UI primitives, input abstraction. **No game-specific content** — that lives in `repos/game`.

**Visibility:** public
**License:** MIT

## In scope

- Card system primitives (base `Card` resource, effect composition, targeting, piles)
- Combat / encounter loop infrastructure
- Run / map / progression framework
- Modality framework (see `docs/modality-framework.md`)
- Effort bridge (WebSocket → typed signals)
- Input abstraction (keyboard, gamepad, effort-based)
- UI primitives reusable across themes

## Out of scope

- Specific cards (numbers, names, effects) — lives in `repos/game`
- Enemy / encounter content
- Balance data
- Theme, narrative, art, audio
- Anything device-specific in *theme* (cycling vs. rowing vs. running framing)

## House conventions

- Follow the umbrella `INSTRUCTIONS.md`
- Branch off `develop`, never push to `main` or `develop` directly
- Sign commits (`git commit -S`)
- GDScript style follows the Godot core style guide
- Include a test scene under `tests/` for new features
- Lint with `gdlint`

## Tech-specific notes

- **Godot 4.3+**
- The effort bridge (`src/effort/effort_bridge.gd`) is the only place that talks to the sidecar — everything else listens to its signals
- Event names are **device-neutral** (`power_changed`, `effort_surge_started`) so the same engine works for cycling, rowing, treadmill games
- Bike-specific signals (`cadence_changed`) and rower-specific signals (`stroke_rate_changed`) coexist; games subscribe to whichever apply

## Common tasks

```bash
# Open in Godot editor
godot --editor

# Headless test run
godot --headless --quit-after 5 tests/test_main.tscn

# Lint
gdlint src/
```

## Working with the sidecar

The engine consumes the sidecar's WebSocket. For development:

```bash
# In one terminal (from the sidecar repo):
cd ../sidecar
roguerglike-sidecar --mode mock

# In another (this repo):
godot --editor
# Run the test_main scene; effort_bridge should connect to localhost:8421
```
