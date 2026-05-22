# HANDOFF — roguERGlike-engine

> Current state of this repo. Updated at the end of every session that touches it. Read first.

**Last updated:** 2026-05-22
**Current branch:** `docs/2026-05-22-first-live-ride`
**Base branch:** `develop`
**Current focus:** **`feat/mvp-playable-loop` validated end-to-end against the KICKR + Whoop today.** Ready-for-promotion decision is yours: merge PR #4 to develop, or keep it as a side experiment while concert-mvp explores the alternate (browser-driven) approach. A second MVP repo (`repos/concert-mvp`) shipped a parallel client today.

## Where we are

The engine `develop` branch contains:

- **Handshake test scene** that subscribes to the sidecar WebSocket and renders live telemetry.
- **`EffortBridge` autoload** with the full read+write surface: power/cadence/HR/speed signals, device-capabilities/control-acquired/target-power-set acks, cadence-bailout engaged/disengaged signals, `is_cadence_paused` state. Write methods for `set_target_power`, `start`, `stop`, `release_control`.

A separate experimental branch:

```text
feat/mvp-playable-loop   →  PR #4 (still open)
```

This branch was used as the engine surface in today's first end-to-end live ride. It works. The bailout fired and recovered correctly during natural between-round pauses; ERG targets reached the KICKR; the rider felt the resistance change. Per its own HANDOFF the promotion criterion is "does the loop feel right?" — that's the open question for the user, not a technical one.

## Today's live ride (2026-05-22)

- Sidecar: KICKR CORE 1003 + Whoop MG5, ERG control enabled, intensity-aware bailout active
- Engine: `feat/mvp-playable-loop` MVP scene drove ERG targets via phase transitions (warmup → power-up → recovery → ...)
- Result: end-to-end loop confirmed. Engine pushes targets, sidecar applies them, trainer responds.
- Observation: cadence bailout fired three times in ~10 minutes — all timing-correct per the intensity-aware formula but all during legitimate between-round UI moments. This surfaced the **safety-vs-pause architectural concern** (see below).

## Pause architecture decision

Documented in `repos/sidecar/docs/architecture/safety-vs-pause.md` (PR #18, merged).

**Cadence bailout is a safety mechanism, not game flow.** Between-round pauses, menu interactions, etc. need their own pause primitive owned by the client. Two valid implementations exist:

- **Pattern A — Client-side soft pause** (concert-mvp, shipped 2026-05-22). Client sends low `set_target_power` on its own pause condition. No sidecar contract change. Best for user-gesture pauses (browser app, YouTube pause/resume).
- **Pattern B — Sidecar-side suspend** (planned for engine-mvp). Client sends `pause` / `resume` commands; sidecar suspends the cadence watcher and sets an easy-spin wattage. Better for code-driven phase boundaries in turn-based gameplay.

The engine-mvp's between-round pauses fit Pattern B. When this engine repo is ready to ship Pattern B, the sidecar work is small and well-scoped (documented in the architecture doc). Engine-side: emit `pause` at the right phase boundaries; emit `resume` at phase exit; subscribe to `paused` / `resumed` envelopes to clear any "PAUSED — start pedalling" UI.

## What's next (decision points)

1. **Promote `feat/mvp-playable-loop` to develop, or keep it as a side experiment.** Today's live ride confirms it works. The question per its HANDOFF is whether the HIIT-shaped loop feels worth continuing as the canonical engine surface.
2. **If promoted: ship Pattern B pause command on this side.** Engine writes `pause` at recovery / card-play / setup phase entry; `resume` at power-interval entry. UI: clear the "PAUSED" overlay on `paused` envelope; subscribe to `resumed` to know when the ramp completes.
3. **Card-system foundation** (`Effect: Resource` + `CombatContext: RefCounted`) on `feat/card-system-foundation`. Currently `card.gd` references undefined types. Unblocks card variety beyond the MVP's hard-coded set.
4. **Decide what target metrics actually score.** Power drives energy rewards today. Should cadence and HR affect rewards or synergies? Open per MVP HANDOFF.

## Open threads

- **PR #4 is still open**, marked as side experiment. Live-validated but not promoted. Decision belongs to you.
- **`tests/telemetry_chart.gd`** is a test harness chart, not yet a reusable UI primitive.
- **Distance** is decoded by the sidecar but not yet surfaced via EffortBridge — wire up when distance deriver lands in the sidecar.
- **Multi-platform export config** not set up.
- **Real test runner** — current Godot headless boot checks are useful but not true assertions.

## How to run

### MVP without a bike (mock mode)

```powershell
# Window 1
cd C:\dev\roguERGlike\repos\sidecar
./scripts/run-live-test.ps1 -Mock

# Open mock slider UI: http://localhost:8422

# Window 2
cd C:\dev\roguERGlike\repos\engine-mvp     # worktree on feat/mvp-playable-loop
& "C:\Program Files\Godot\Godot_v4.6-stable_win64.exe" --path . tests/test_main.tscn
```

### MVP with the bike

```powershell
# Window 1
cd C:\dev\roguERGlike\repos\sidecar
./scripts/run-live-test.ps1                # defaults: KICKR + mudrat + FTP 250 + ERG control

# (Optional) Window 2
./scripts/record-session.ps1               # capture telemetry to JSONL

# Window 3
cd C:\dev\roguERGlike\repos\engine-mvp
& "C:\Program Files\Godot\Godot_v4.6-stable_win64.exe" --path . tests/test_main.tscn
```

## Sibling MVP: `repos/concert-mvp`

A second MVP exists at `repos/concert-mvp/` — a browser-based YouTube-driven ERG controller, sibling (not replacement) to engine-mvp. Maps video time + rider FTP/weight to target watts via a manually authored rolling concert profile. Already implements client-side pause (Pattern A). Different ergonomics (no card UI, no phases — just a video timeline). Both MVPs reuse the same sidecar contract.

When deciding the engine's direction: this is a parallel exploration, not a competitor. The "right" engine MVP may inherit ideas from concert-mvp's manual-profile model.

## Entry point for next session

> "Engine `feat/mvp-playable-loop` was live-validated against the KICKR yesterday. Decision: promote to develop or keep as side experiment? If promoting, ship Pattern B pause command alongside (engine emits `pause`/`resume` at phase boundaries; sidecar suspends bailout watcher + sets easy-spin wattage). See `repos/sidecar/docs/architecture/safety-vs-pause.md` for the Pattern B contract. Alternative: continue card-system foundation on `feat/card-system-foundation` while engine-mvp stays an exploration."
