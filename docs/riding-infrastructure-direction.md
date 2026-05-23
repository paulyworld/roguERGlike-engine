# Riding Infrastructure Direction

**Decision date:** 2026-05-23

## Decision

Near-term product focus moves to `repos/concert-mvp` because it currently provides the better riding experience. The Godot deck-builder MVP branch (`feat/mvp-playable-loop`) remains valuable as a live-validated experiment, but it should not be promoted to `develop` by default.

Pattern B pause/resume should be shipped as **core riding infrastructure**, not as a deck-builder-specific feature.

## What Pattern B Means

Pattern B is a sidecar-managed structured pause:

- clients send explicit `pause` and `resume` commands;
- the sidecar suspends cadence-bailout timing while paused;
- the sidecar optionally drops the trainer to an easy-spin wattage;
- the sidecar emits typed `paused` and `resumed` envelopes so clients, recorders, and dashboards can distinguish structured pauses from safety bailouts.

This belongs in `repos/sidecar` as trainer-session protocol, then clients can wrap it in their own language/runtime.

## Client Implications

`repos/concert-mvp` can keep using Pattern A for YouTube play/pause because that pause is user-driven and already feels good. Later it can adopt Pattern B for authored workout breaks, explicit workout-clock suspend, intermission handling, or any structured pause that should stop cadence-bailout timing.

`repos/engine` should add only generic bridge support on `develop` once the sidecar schema exists:

```gdscript
EffortBridge.pause_effort(reason: String = "client_pause", target_watts: int = -1)
EffortBridge.resume_effort()
```

And generic state/signals:

```gdscript
signal effort_paused(reason: String, target_watts: int)
signal effort_resumed(restored_to_watts: int, ramped_over_s: float)

var is_effort_paused: bool = false
```

Avoid names tied to a specific MVP, such as `round_paused`, `card_selection_pause`, or `game_paused`.

## Practical Next Step

Implement Pattern B in this order:

1. Sidecar command/event schema and tests.
2. Sidecar live/mock handlers that suspend cadence bailout and apply easy-spin target policy.
3. Engine `EffortBridge` wrappers and test scene logging.
4. Optional concert-mvp wrapper when there is a structured pause use case; do not disturb the current Pattern A YouTube pause behavior just for symmetry.

## Non-Goals

- Do not promote `feat/mvp-playable-loop` just to get Pattern B.
- Do not force concert-mvp to use Pattern B for ordinary YouTube play/pause.
- Do not weaken cadence-bailout safety timing to solve client UX pauses.
