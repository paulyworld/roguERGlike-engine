# ERGlike Engine

> Open-source ERG trainer infrastructure for building apps, games, and ride experiences on top of smart trainers.

ERGlike is an open-source software stack for turning connected fitness hardware into programmable ride experiences. The goal is to make smart-trainer control, telemetry, safety behavior, workout logging, and app integration available as reusable infrastructure so people can build ERG-driven apps without starting from Bluetooth and trainer-control details.

The first test app is **gizzERG**, formerly referred to as `concert-mvp`: a browser-based concert ride that maps music intensity and video time to trainer resistance. gizzERG is proving the core platform loop: media-synchronized workouts, trainer control, ride logging, annotations, export, and eventually terrain-style modes, leaderboards, and group rides.

The GitHub repository name still uses the older `roguERGlike-engine` name for now. The umbrella project has moved to the broader **ERGlike** name; repo renames are deferred until a clean break point.

## Architecture

The stack is split into small pieces with clear ownership:

- **Sidecar runtime**: connects to trainers and sensors, owns BLE/FTMS control, safety behavior, cadence bailout, recording, exports, and protocol events.
- **App clients**: browser, Godot, desktop, or other clients that compute ride intent and present the user experience.
- **This engine repo**: shared app-facing infrastructure, protocol-facing docs, and the current Godot effort bridge for clients that want to consume the sidecar event stream.

The sidecar exposes a local WebSocket protocol. Apps subscribe to telemetry such as power, cadence, heart rate, device capabilities, and trainer-control acknowledgements, then send commands such as target power, start/stop, and future structured pause/resume or simulation controls.

## Why This Exists

Most smart-trainer apps bundle three concerns together:

- hardware communication;
- workout/control logic;
- product UI.

ERGlike keeps those separate. The sidecar is the trainer boundary. Apps can focus on ride design: a concert ride, a game, a structured workout editor, a terrain simulator, a group ride, or something else entirely.

## Current Product Direction

Near-term product work is focused on **gizzERG**, the concert ride MVP. It is currently the fastest way to validate the riding experience.

Key gizzERG directions:

- map music intensity to ERG targets;
- add semantic ride annotations for post-ride tuning;
- export completed rides to FIT for Strava and TrainingPeaks workflows;
- prototype Terrain Mode, where music intensity becomes virtual grade, elevation, and climb segments;
- add local results, ghosts, and eventually leaderboards/group rides.

The older Godot deck-builder MVP remains a useful live-validated experiment, but it is not the primary near-term product surface.

## What's In This Repo

- **EffortBridge for Godot**: subscribes to the sidecar WebSocket and exposes typed signals for power, cadence, heart rate, device capabilities, target-power acknowledgements, and cadence bailout state.
- **Trainer-control client methods**: Godot-side methods for `set_target_power`, `start`, `stop`, and `release_control`.
- **Planning docs**: architecture direction for pause/resume, gizzERG product work, terrain modes, training-platform export, and sidecar review packets.
- **Legacy game framework pieces**: card/run/combat scaffolding from the original deck-builder exploration, kept while the platform direction settles.

## What's Not In This Repo

- BLE hardware control. That belongs in the sidecar runtime.
- gizzERG app UI. That lives in the concert MVP app repo.
- Public accounts, cloud leaderboards, or group ride rooms. Those belong in a future server layer.
- Trainer vendor pairing UX and packaging. Those are sidecar/app distribution concerns.

## App Model

An app built on ERGlike generally does three things:

1. Subscribe to the sidecar event stream.
2. Convert app state into trainer intent.
3. Send safe, typed commands back to the sidecar.

Example app ideas:

- concert rides like gizzERG;
- terrain rides generated from music, GPX, or authored profiles;
- structured interval workouts;
- rhythm games;
- roguelike/deck-builder rides;
- local ghost races;
- group rides and leaderboard challenges.

## Requirements

For the current Godot bridge:

- Godot 4.3+
- ERGlike sidecar running locally, either live or mock mode

For gizzERG:

- the concert MVP app repo
- ERGlike sidecar running locally
- a supported smart trainer for live ERG control, or mock mode for development

## Related Docs

- [Concert product roadmap](docs/concert-product-roadmap.md)
- [Terrain mode exploration](docs/concert-mode-exploration.md)
- [Training platform export research](docs/training-platform-export-research.md)
- [Riding infrastructure direction](docs/riding-infrastructure-direction.md)
- [Claude sidecar review brief](docs/claude-sidecar-review-brief.md)
- [Modality framework](docs/modality-framework.md)

## License

MIT. See [LICENSE](LICENSE). Contributions are covered by [CLA.md](CLA.md).
