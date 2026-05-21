# HANDOFF - roguERGlike-engine

> Branch-local handoff for the Codex MVP playable-loop experiment. Read this before continuing work on `feat/mvp-playable-loop`.

**Last updated:** 2026-05-21
**Current branch:** `feat/mvp-playable-loop`
**Branch purpose:** Side test feature coded in Codex to validate the smallest playable effort/card loop.
**Related umbrella note:** `../../docs/mvp-playable-loop-second-opinion.md`
**Current focus:** Prove a HIIT-shaped encounter loop before expanding engine/framework scope.

## Important Context

This branch is intentionally a side experiment, not the canonical replacement for Claude's active work elsewhere.

Claude has been working on sidecar/handshake/handoff cleanup in other branches and repos. This branch should coexist with that work. It does not change the sidecar contract, does not require sidecar source edits, and does not attempt to finalize engine architecture.

The goal here is narrower: test whether the gameplay loop feels better when card decisions and high-effort intervals are separated.

## Where The Rationale Lives

The design/architecture commentary that led to this branch is in the umbrella repo:

```text
../../docs/mvp-playable-loop-second-opinion.md
```

That note argues for proving a playable loop before building more framework: one mock ride source, one Godot scene, one enemy, one card, one effort mechanic.

## What This Branch Implements

The engine test scene has been changed from a passive sidecar telemetry display into a tiny HIIT encounter prototype:

```text
Recovery / Card Play -> Power Interval -> Recovery / Card Play
```

Files changed on this branch:

- `tests/test_main.gd`
- `tests/test_main.tscn`

The scene still uses the existing `EffortBridge` autoload and sidecar WebSocket stream.

## Current Loop

### Player phase: Recovery / Card Play

- Player can play `Strike`.
- `Strike` costs 1 energy.
- `Strike` deals 6 damage.
- Player is expected to stay under a recovery ceiling.
- Current recovery ceiling is 2.0 W/kg.

### Enemy phase: Power Interval

- Player cannot play cards.
- Player tries to hit a peak W/kg target during a fixed 10 second interval.
- Current target is 3.3 W/kg.
- Rider weight is currently hardcoded at 75 kg for test purposes.

Resolution:

- Target hit: gain 3 energy and block the enemy attack.
- Target missed: gain 1 energy and take 5 damage.

This deliberately avoids the earlier simultaneous health-race loop. Cards happen during recovery; high physical output happens during the enemy/power interval.

## How To Run

Start the sidecar mock mode in one terminal:

```powershell
cd C:\dev\roguERGlike\repos\sidecar
$env:PYTHONPATH="src"
python -m roguerglike_sidecar.cli --mode mock
```

Open the sidecar UI:

```text
http://localhost:8422
```

Run the engine scene in another terminal:

```powershell
cd C:\dev\roguERGlike\repos\engine
git switch feat/mvp-playable-loop
..\..\..\tools\Godot\godot.exe --path .
```

For a 75 kg test rider, 3.3 W/kg is about 248 W.

## Validation Done

Godot headless scene load passes:

```powershell
..\..\..\tools\Godot\godot_console.exe --headless --path . --quit
```

Expected console output includes:

```text
[hiit_mvp] ready; player turn is recovery, enemy turn is power target
```

## Relationship To Claude's Work

Claude's sidecar work remains the source of truth for the mock telemetry server, WebSocket behavior, replay/session-state fixes, and handoff hygiene in the sidecar repo.

This Codex branch consumes that sidecar work through the existing WebSocket contract. If Claude changes the sidecar event schema or handshake behavior, re-test this branch against those changes before merging anything.

Do not fold this branch into broader engine architecture until the loop has been playtested. The implementation is intentionally local to `tests/test_main.*` so it can be thrown away, rewritten, or promoted later.

## Open Questions

- Is 10 seconds the right first interval length for the power target?
- Should the target be based on W/kg, FTP percentage, or both?
- Should recovery compliance matter mechanically, or only display feedback for now?
- Should target hit trigger energy, block, card synergies, or some combination?
- Is hardcoded rider weight acceptable for this test, or should the test scene expose a simple rider-weight control?
- Should this remain in `engine/tests/`, or should the next iteration move into the private `game` repo as a vertical slice?

## Suggested Next Step

Playtest the current loop manually:

1. During recovery, play `Strike` if energy is available.
2. End turn.
3. During the 10 second interval, use the sidecar power slider to exceed the W/kg target.
4. Observe whether earning energy/block during the interval feels better than simultaneous card play and damage racing.

After that, make only one design change at a time. The next likely change is exposing rider weight or target W/kg in the scene so balancing can be tested without code edits.

## Entry Point For Next Session

> Continue the Codex MVP side branch in `repos/engine` on `feat/mvp-playable-loop`. Start by reading `HANDOFF.md` and `../../docs/mvp-playable-loop-second-opinion.md`. Do not broaden the framework yet; use the current HIIT test scene to validate recovery/card-play vs power-interval pacing.
