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
- `tests/telemetry_chart.gd`

The scene still uses the existing `EffortBridge` autoload and sidecar WebSocket stream.

## Current Loop

### Player phase: Recovery / Card Play

- Player energy is turn-scoped. It expires when the player ends recovery/card play.
- Power interval performance grants the next player turn's energy budget.
- Player can play `Power Strike`.
  - Costs 2 energy.
  - Deals base damage.
  - Gains bonus damage if the previous power interval hit target.
- Player can play `Cadence Guard`.
  - Costs 1 energy.
  - Adds block that persists into the upcoming enemy power interval.
  - Gains bonus block if recovery-phase cadence accuracy is high.
- Player is expected to stay under a recovery ceiling.
- Current recovery ceiling is 2.0 W/kg.
- Player turn is currently timed at 60 seconds for testability.
- Recovery also displays HR guidance: stay below the configured Zone 3 lower bound.

### Enemy phase: Power Interval

- Player cannot play cards.
- Player tries to hit a peak W/kg target during a fixed 30 second interval.
- Current target is 3.3 W/kg.
- Rider weight is editable in the scene and defaults to 75 kg.

Resolution:

- Enemy makes a generic attack during its power interval.
- Block from `Cadence Guard` reduces that attack.
- Target missed: next turn starts with 1 energy.
- Target hit: next turn starts with 3 energy.
- Target exceeded by 15%: next turn starts with 4 energy.
- Target exceeded by 30%: next turn starts with 5 energy.

This deliberately avoids the earlier simultaneous health-race loop. Cards happen during recovery; high physical output happens during the enemy/power interval.

## Charting And Settings

The test scene now includes a live chart with:

- A `Ride View` timeline for the full 20 minute test workout.
- Separate detail charts for power, heart rate, and cadence to reduce visual crowding.
- Time on the x-axis. Distance is still pending until distance events are exposed through the sidecar/engine bridge.
- Background phase bands for recovery/card play vs power interval.
- Dotted phase-specific target lines in each detail chart.
- HR zone boundary lines in the heart-rate detail chart.
- Large live readouts for watts, W/kg, HR, and cadence above the charts.

The left settings panel includes:

- Weight in kg. This drives W/kg calculations.
- FTP in watts. Recovery and interval power targets are derived from this.
- Age input plus an "Apply 220-age zones" button.
- Max HR.
- Manual lower bounds for HR Zones 1-5.

The common default uses `220 - age` for max HR and zone lower bounds at 50/60/70/80/90% of max HR. The zone spin boxes can then be edited manually for more realistic athlete-specific zones.

Current phase targets:

- Recovery/card play: power target is 55% FTP, HR target is below the Zone 3 lower bound, cadence target is 80 rpm.
- Power interval: power target is 120% FTP, HR target is the Zone 4 lower bound, cadence target is 100 rpm.

The chart target lines change by phase segment instead of drawing one global target line across the whole session. The `Ride View` is inspired by workout dashboards such as Zwift/TrainerRoad: big current outputs first, full workout blocks underneath, then detailed metric charts.

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

For a 75 kg test rider:

- Default FTP is 250 W.
- The default interval target is 120% FTP = 300 W = 4.0 W/kg.
- 0.5 W/kg above interval target grants 4 energy.
- 1.0 W/kg above interval target grants 5 energy.

## Validation Done

Godot headless scene load passes:

```powershell
..\..\..\tools\Godot\godot_console.exe --headless --path . --quit
```

Expected console output includes:

```text
[hiit_mvp] ready; timed recovery, power interval, charting enabled
```

## Relationship To Claude's Work

Claude's sidecar work remains the source of truth for the mock telemetry server, WebSocket behavior, replay/session-state fixes, and handoff hygiene in the sidecar repo.

This Codex branch consumes that sidecar work through the existing WebSocket contract. If Claude changes the sidecar event schema or handshake behavior, re-test this branch against those changes before merging anything.

Do not fold this branch into broader engine architecture until the loop has been playtested. The implementation is intentionally local to `tests/test_main.*` so it can be thrown away, rewritten, or promoted later.

## Open Questions

- Is 60 seconds the right first recovery/card-play turn length?
- Is 30 seconds the right first interval length for the power target?
- Should power targets be based on FTP percentage, W/kg, or both? Current test uses FTP for target power and W/kg for cross-rider display/reward margin.
- Should recovery compliance eventually be based on HR drop instead of a fixed timer?
- Should recovery compliance matter mechanically, or only display feedback for now?
- Should target hit trigger energy, block, card synergies, or some combination? Current test uses power for next-turn energy and Power Strike bonus; cadence for Cadence Guard bonus block.
- Should distance be added to the chart once `distance` events flow through `EffortBridge`?
- Should target cadence become a scoring input, or remain guidance only?
- Should this remain in `engine/tests/`, or should the next iteration move into the private `game` repo as a vertical slice?

## Suggested Next Step

Playtest the current loop manually:

1. During recovery, spend turn energy on `Power Strike` and/or `Cadence Guard`.
2. End turn; any unspent energy expires.
3. During the 30 second interval, use the sidecar power slider or real bike output to exceed the W/kg target.
4. At interval end, the enemy attacks; queued block reduces damage.
5. The next player turn receives a fresh energy budget based on interval power accuracy.
6. Observe whether expiring energy plus power/cadence card synergies feels better than banked energy.

After that, make only one design change at a time. The next likely change is exposing rider weight or target W/kg in the scene so balancing can be tested without code edits.

## Entry Point For Next Session

> Continue the Codex MVP side branch in `repos/engine` on `feat/mvp-playable-loop`. Start by reading `HANDOFF.md` and `../../docs/mvp-playable-loop-second-opinion.md`. Do not broaden the framework yet; use the current HIIT test scene to validate recovery/card-play vs power-interval pacing.
