# Contributing

This repository contains the **generic framework** for the roguERGlike game. Specific card designs, balance data, and theme content live in a separate private repository and are not part of this project.

## In scope

- Card system primitives (base classes, effect composition, targeting)
- Combat / encounter loop infrastructure
- Run / map / progression framework
- Input handling (keyboard, gamepad, effort-based)
- UI primitives reusable across themes
- Integration with the sidecar event stream

## Out of scope

- Specific card designs (numbers, effects, art)
- Enemy / encounter content
- Balance changes
- Theme, narrative, audio assets

Contributions that mix scope will be asked to split.

## Workflow

- Fork → branch off `develop` → PR back to `develop`
- Conventional commits
- GDScript style follows the Godot core style guide
- Include a test scene under `tests/` for new features

By contributing you agree to the [CLA](CLA.md).
