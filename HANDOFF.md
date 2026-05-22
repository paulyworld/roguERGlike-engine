# HANDOFF - roguERGlike-engine

> Branch-local handoff for the Codex MVP playable-loop experiment. Read this before continuing work on `feat/mvp-playable-loop`.

**Last updated:** 2026-05-21
**Current branch:** `feat/mvp-playable-loop`
**Branch purpose:** Side test feature coded in Codex to validate the smallest playable effort/card loop.
**Related umbrella note:** `../../docs/mvp-playable-loop-second-opinion.md`
**Current focus:** Prove a HIIT-shaped encounter loop before expanding engine/framework scope.
**Codex worktree used this session:** `C:\dev\roguERGlike\repos\engine-mvp`

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

The engine test scene has been changed from a passive sidecar telemetry display into a tiny workout/encounter prototype with selectable profiles:

```text
HIIT Encounter: Setup -> Warmup Ramp -> Power-Up Interval -> Recovery / Card Play -> Power Interval -> Recovery / Card Play
Ramp Power Test: Setup -> Ramp Up -> Ramp Down
ERG Step Test: Setup -> 40 W Step Up/Down Repeats
```

Files changed on this branch:

- `tests/test_main.gd`
- `tests/test_main.tscn`
- `tests/telemetry_chart.gd`

The scene still uses the existing `EffortBridge` autoload and sidecar WebSocket stream.

## Setup And Warmup

The MVP now starts in a setup state instead of immediately running combat.

The player can enter rider stats, HR zones, FTP, and warmup length before pressing `Start Workout`. Pressing start clears the charts, starts the session clock, and begins a warmup ramp.

The dashboard now includes:

- Encounter/workout selector.
- Overall workout length in minutes.
- Warmup length in minutes for HIIT.

Warmup defaults:

- Length: 10 minutes, editable from 1-20 minutes.
- Power target: linear ramp from 40% FTP to 70% FTP.
- Cadence target: 85 rpm.
- HR target: ramps from the configured Zone 2 lower bound toward the Zone 3 lower bound.

This is intentionally generic. Public cycling warmup guidance commonly emphasizes a gradual warmup before hard work; this branch uses a conservative FTP-based ramp so rider weight and FTP still drive the displayed targets.

## Current Loop

### Warmup phase: Warmup Ramp

- No cards can be played.
- No enemy attack happens.
- The target meters show warmup power, HR, and cadence.
- The ride timeline shades the warmup block blue before the combat intervals begin.

### Power-up phase: first interval after warmup

- The first interval after warmup is a power-up interval, not an enemy attack interval.
- The warmup transitions directly into this power-up interval. There is no recovery/card phase between warmup and the first power target.
- It uses the same interval power/cadence targets as later power intervals.
- It records sustained power accuracy for the first `Power Strike` modifier.
- It does not apply enemy damage.

### Player phase: Recovery / Card Play

- Player energy is turn-scoped. It expires when the player ends recovery/card play.
- Each recovery/card turn starts with a fixed 3 energy.
- Power interval performance no longer changes energy. It now feeds card modifier readiness.
- Player can play `Power Strike`.
  - Costs 2 energy.
  - Deals base damage.
  - Gains bonus damage if the previous power interval sustained target after the ramp grace.
- Player can play `Cadence Guard`.
  - Costs 1 energy.
  - Adds block that persists into the upcoming enemy power interval.
  - Gains bonus block if recovery-phase cadence accuracy is high.
- Player is expected to stay under a recovery ceiling.
- Current recovery ceiling is 2.0 W/kg.
- Player turn is currently timed at 120 seconds for testability.
- Recovery also displays HR guidance: stay below the configured Zone 3 lower bound.
- A future HIIT recovery gate is called out in the UI: end recovery when HR drops to 65% of max HR instead of relying on a fixed timer.
- `End Turn` is intentionally disabled in this iteration. Recovery advances by timer only so the loop can test real rest duration before the next power interval.

### Enemy phase: Power Interval

- Player cannot play cards.
- Player tries to sustain the target during a fixed 30 second interval.
- Default 75 kg target is 4.0 W/kg, derived from 120% FTP at the default 250 W FTP.
- Rider weight is editable in the scene and defaults to 75 kg.

Resolution:

- Enemy makes a generic attack during its power interval.
- Block from `Cadence Guard` reduces that attack.
- The next turn always starts with 3 energy.
- The previous interval's sustained power accuracy controls whether `Power Strike` gets bonus damage.
- The first 8 seconds of the interval are ignored for power accuracy so trainer ramp time does not punish the player.

This deliberately avoids the earlier simultaneous health-race loop. Cards happen during recovery; high physical output happens during the enemy/power interval.

## Charting And Settings

The test scene now includes a live chart with:

- A `Ride View` timeline for the selected workout length.
- The chart timeline length follows the dashboard's workout-length control.
- Separate detail charts for power, heart rate, and cadence to reduce visual crowding.
- Detail charts have taller plot areas than the first version so the y-axis is easier to read during live testing.
- Time on the x-axis. Distance is still pending until distance events are exposed through the sidecar/engine bridge.
- Background phase bands for recovery/card play vs power interval.
- Dotted phase-specific target lines in each detail chart.
- Each detail chart now labels its y-axis range and annotates the target curve with the relevant target ranges and step values.
- Hovering a chart shows a popup for the hovered time with target and nearest historic performance values. Detail charts show the current metric; Ride View shows power, HR, and cadence together.
- HR zone boundary lines in the heart-rate detail chart.
- Large live readouts for watts, W/kg, HR, and cadence above the charts.
- Prominent target meters for power, HR, and cadence showing actual vs target, delta, and color-coded target ratio.
- ERG write support from Claude's trainer-control bridge is consumed when available. The MVP writes warmup/recovery/interval targets through `EffortBridge.set_target_power`.
- The MVP now displays trainer write state in the device row: target-power capability, control-acquired state, and the latest target-power acknowledgement.
- ERG writes require both `device_capabilities.target_power=true` and `control_acquired=true`.
- In mock mode, launch sidecar with `--allow-trainer-control`; otherwise the WS server has no command handler and drops inbound `set_target_power` commands.
- Ramp Power Test writes a generated up/down ERG target curve across the full workout length.
- ERG Step Test writes discrete 40 W target changes every 15 seconds, climbing from 50% FTP to 150% FTP and then back down. The pattern repeats for as much of the selected workout length as fits.

The left settings panel includes:

- Encounter/workout selector: `HIIT Encounter`, `Ramp Power Test`, or `ERG Step Test`.
- Workout length in minutes. This drives the chart and generated workout curve length.
- Weight in kg. This drives W/kg calculations.
- FTP in watts. Recovery and interval power targets are derived from this.
- Warmup length in minutes.
- Start Workout button. This starts a fresh session using the selected profile.
- Age input plus an "Apply 220-age zones" button.
- Max HR.
- Manual lower bounds for HR Zones 1-5.

The common default uses `220 - age` for max HR and zone lower bounds at 50/60/70/80/90% of max HR. The zone spin boxes can then be edited manually for more realistic athlete-specific zones.

Current phase targets:

- Warmup: power target ramps from 40% FTP to 70% FTP, HR target ramps from Zone 2 lower bound toward Zone 3 lower bound, cadence target is 85 rpm.
- Ramp Power Test: power target ramps from 50% FTP to 120% FTP, then back to 50% FTP across the workout; cadence target ramps from 80 rpm to 100 rpm and back.
- ERG Step Test: power target starts at 50% FTP, increases by 40 W every 15 seconds until 150% FTP, then steps back down by 40 W every 15 seconds; cadence target is 90 rpm.
- Recovery/card play: 120 second timer, power target is 55% FTP, HR target is below the Zone 3 lower bound, cadence target is 80 rpm.
- Power interval: power target is 120% FTP, HR target is the Zone 4 lower bound, cadence target is 100 rpm.

The chart target lines change by phase segment instead of drawing one global target line across the whole session. The `Ride View` is inspired by workout dashboards such as Zwift/TrainerRoad: big current outputs first, full workout blocks underneath, then detailed metric charts.

Target meter colors:

- Red: well below target.
- Yellow: near target.
- Green: target met.
- Blue: substantially over target.

## How To Run

Start the sidecar mock mode in one terminal:

```powershell
cd C:\dev\roguERGlike\repos\sidecar
$env:PYTHONPATH="src"
python -m roguerglike_sidecar.cli --mode mock
```

For ERG write testing, use:

```powershell
python -m roguerglike_sidecar.cli --mode mock --allow-trainer-control
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
- Each recovery/card turn starts with 3 energy.
- Holding the interval target after ramp grace arms the next turn's `Power Strike` bonus.

## Validation Done

Godot headless scene load passes:

```powershell
..\..\..\tools\Godot\godot_console.exe --headless --path . --quit
```

Expected console output includes:

```text
[hiit_mvp] ready; setup, warmup, timed recovery, power interval, charting enabled
```

## Relationship To Claude's Work

Claude's sidecar work remains the source of truth for the mock telemetry server, WebSocket behavior, replay/session-state fixes, and handoff hygiene in the sidecar repo.

This Codex branch consumes that sidecar work through the existing WebSocket contract. If Claude changes the sidecar event schema or handshake behavior, re-test this branch against those changes before merging anything.

Do not fold this branch into broader engine architecture until the loop has been playtested. The implementation is intentionally local to `tests/test_main.*` so it can be thrown away, rewritten, or promoted later.

## Open Questions

- Is 120 seconds the right first recovery/card-play turn length?
- When real HR data is available, should recovery end automatically at 65% max HR or require both timer and HR threshold?
- Is 30 seconds the right first interval length for the power target?
- Should power targets be based on FTP percentage, W/kg, or both? Current test uses FTP for target power and W/kg for cross-rider display/reward margin.
- Should recovery compliance eventually be based on HR drop instead of a fixed timer?
- Should recovery compliance matter mechanically, or only display feedback for now?
- Should target hit trigger card synergies, block, or some combination? Current test uses sustained interval power for Power Strike bonus; cadence for Cadence Guard bonus block.
- Should distance be added to the chart once `distance` events flow through `EffortBridge`?
- Should target cadence become a scoring input, or remain guidance only?
- Should this remain in `engine/tests/`, or should the next iteration move into the private `game` repo as a vertical slice?

## Suggested Next Step

Playtest the current loop manually:

1. Enter rider stats and press `Start Workout`.
2. Ride through the warmup ramp.
3. Complete the first power-up interval; no enemy attack occurs here.
4. During recovery, spend turn energy on `Power Strike` and/or `Cadence Guard`.
5. Wait for the recovery timer; any unspent energy expires when the power interval starts.
6. During later 30 second intervals, use the sidecar power slider or real bike output to hold the W/kg target after ramp grace.
7. At interval end, the enemy attacks; queued block reduces damage.
8. The next player turn receives a fixed 3 energy, with Power Strike bonus readiness based on interval accuracy.
9. Observe whether fixed energy plus power/cadence card synergies feels better than variable energy rewards.

After that, make only one design change at a time. The next likely change is exposing rider weight or target W/kg in the scene so balancing can be tested without code edits.

## Entry Point For Next Session

> Continue the Codex MVP side branch in `repos/engine` on `feat/mvp-playable-loop`. Start by reading `HANDOFF.md` and `../../docs/mvp-playable-loop-second-opinion.md`. Do not broaden the framework yet; use the current HIIT test scene to validate recovery/card-play vs power-interval pacing.
