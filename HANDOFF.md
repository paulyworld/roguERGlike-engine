# HANDOFF - roguERGlike-engine

> Current state of this repo. Updated at the end of every session that touches it. Read first.

**Last updated:** 2026-05-21
**Current branch:** `docs/post-hrs-mvp-promotion-engine`
**Base branch:** `develop`
**Current focus:** Engine handshake scene is merged/live-validated. The Codex MVP HIIT playable-loop experiment is pushed on `feat/mvp-playable-loop` and should be tested separately before any architectural promotion.

## Where We Are

The engine `develop` branch contains the sidecar handshake test scene. It has been live-validated against a real KICKR CORE: `EffortBridge` receives `power_changed` and `cadence_changed` from the sidecar live mode and updates the scene in real time.

A separate Codex side branch exists:

```text
feat/mvp-playable-loop
```

That branch is intentionally experimental. It is not the canonical engine architecture yet. It prototypes a HIIT-style loop where card choices happen during recovery/card-play phases and higher-intensity output happens during power-interval phases.

The broader rationale is documented in the umbrella repo:

```text
../../docs/mvp-playable-loop-second-opinion.md
```

## MVP Branch State

Latest pushed MVP commits include:

```text
04b6b01 feat: split workout telemetry charts
756c0c9 feat: add FTP-based phase targets
418704c feat: add HIIT session charting controls
8b692e1 feat: prototype HIIT MVP playable loop
```

The MVP branch currently includes:

- A 20-minute workout `Ride View` timeline.
- Separate charts for power, heart rate, and cadence.
- Large live readouts for watts, W/kg, HR, and cadence.
- Editable rider settings: weight, FTP, age, max HR, and manual HR zone lower bounds.
- FTP-based phase power targets:
  - Recovery/card play: 55% FTP.
  - Power interval: 120% FTP.
- Phase-specific dotted target lines for target power, target HR, and target cadence.
- Recovery/card timer and power-interval timer.
- Energy rewards based on interval target performance.

There is no longer a required local stash restore step for the MVP branch. The prior handoff note about stashed WIP is stale.

## How To Run The MVP Without A Bike

Start sidecar mock mode:

```powershell
cd C:\dev\roguERGlike\repos\sidecar
$env:PYTHONPATH="src"
python -m roguerglike_sidecar.cli --mode mock
```

Open mock controls:

```text
http://localhost:8422
```

Run the MVP engine scene:

```powershell
cd C:\dev\roguERGlike\repos\engine
git switch feat/mvp-playable-loop
git pull
..\..\..\tools\Godot\godot.exe --path .
```

## How To Run The MVP With The Bike

Start sidecar live mode with the trainer name/address that was validated locally:

```powershell
cd C:\dev\roguERGlike\repos\sidecar
$env:PYTHONPATH="src"
python -m roguerglike_sidecar.cli --mode live --device-bike KICKR
```

Then launch the MVP branch as above. The engine connects to `ws://localhost:8421`, so it consumes either mock or live sidecar telemetry without code changes.

Trainer control writes are not implemented yet. The current live-bike path is passive telemetry only: power/cadence/speed/possibly HR from the trainer. Target power/resistance control will require FTMS control-point support in the sidecar.

## What's Next

1. **Playtest `feat/mvp-playable-loop`.** Use mock mode first, then the KICKR if desired. Evaluate whether the split between recovery/card play and interval/recharge feels better than simultaneous combat/effort.
2. **Decide what target metrics actually score.** Power currently drives energy rewards; HR and cadence are displayed as targets/guidance. Decide whether cadence and HR should affect rewards or synergies.
3. **Add sidecar trainer control only after the loop feels promising.** Needed for ERG/target power or resistance writes during power intervals. This should be guarded by an explicit live-control option.
4. **Card-system foundation.** `card.gd` still references undefined `Effect` and `CombatContext`; define minimal base classes before promoting MVP combat concepts out of the test scene.
5. **Tighten CI.** Current Godot headless boot checks are useful but not true assertions. Add a real test runner or assertion scene later.

## Open Threads

- `feat/mvp-playable-loop` is still a side experiment; keep it local to test-scene scope until playtested.
- `tests/telemetry_chart.gd` is a test harness chart, not a reusable UI primitive yet.
- Distance is not charted because `distance` events are not currently exposed through `EffortBridge`.
- HR zones use `220 - age` defaults plus manual lower-bound overrides; this is sufficient for testing, not final athlete onboarding.
- FTMS control-point writes for ERG/target power are not implemented.
- Multi-platform export config is not set up.

## Notes For Next Session

- Read this handoff plus `../../docs/mvp-playable-loop-second-opinion.md` before continuing MVP work.
- Use `--mode mock` for quick UI/play-loop iteration.
- Use `--mode live --device-bike KICKR` only when actively testing with the trainer.
- If port `8421` is busy, inspect it with:

```powershell
Get-NetTCPConnection -LocalPort 8421 | Select-Object LocalAddress,LocalPort,State,OwningProcess
Get-CimInstance Win32_Process -Filter "ProcessId = <PID>" | Format-List ProcessId,Name,CommandLine
```

## Entry Point For Next Session

> Continue from `feat/mvp-playable-loop`. Test the split Ride View / Power / HR / Cadence charts with mock sidecar first. Then, if the bike is available, run sidecar live mode and verify that real power/cadence update the MVP loop. Do not implement FTMS resistance/ERG writes until the basic loop feels worth continuing.
