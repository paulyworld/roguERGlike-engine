# roguERGlike-engine

> Godot 4 framework for deck-builder roguelikes driven by real-time effort input.

Generic, reusable Godot components for building roguelike deck-builders that respond to live data from connected fitness equipment. Card system primitives, encounter loop, run structure, UI components, and an effort-input abstraction.

Does **not** contain card designs, balance data, art, or game-specific theme — those live in separate (private) game repos that consume this as a submodule.

## Device agnosticism

This engine subscribes to the [sidecar](https://github.com/Paul/roguERGlike-sidecar) event stream and exposes device-neutral signals (`power_changed`, `effort_surge_started`, `hr_zone_changed`). The same engine works for a bike-themed game, a rowing-themed game, or a treadmill-themed game — only the content/theme layer differs.

Bike-specific signals (`cadence_changed`) and rower-specific signals (`stroke_rate_changed`) coexist; games subscribe to whichever apply to their theme.

## What's in here

- **Card system** — base `Card` resource, effect composition, targeting, draw/discard/exhaust piles
- **Combat loop** — turn structure, intents, status effects
- **Effort bridge** — subscribes to the sidecar WebSocket and surfaces typed signals
- **Run framework** — map nodes, encounter selection, persistent run state
- **Modality framework** — pluggable run-shape templates (interval timing, recovery scenes, effort-band enforcement) that game repos populate with their themed modalities (see `docs/modality-framework.md`)
- **UI primitives** — card display, hand layout, animations
- **Input abstraction** — keyboard, gamepad, and effort-based input as a unified interface

## What's NOT in here

- Specific cards (effects + numbers)
- Enemy designs
- Balance data
- Art, audio, theme
- Story / narrative
- Anything device-specific in *theme* (visual or narrative). Game repos handle that.

## Requirements

- Godot 4.3+
- `roguerglike-sidecar` running locally (or mock mode) for effort input

## Usage

Add as a submodule to your game project:

```bash
git submodule add https://github.com/Paul/roguERGlike-engine addons/roguerglike_engine
```

Then in `project.godot`, add `addons/roguerglike_engine` to the autoload list.

## License

MIT — see [LICENSE](LICENSE). Contributions covered by [CLA.md](CLA.md).
