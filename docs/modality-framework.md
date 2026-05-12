# Modality Framework

A **modality** is a run-shape template: it defines how a roguelike run is structured in time, what effort the player is expected to produce at each stage, and how the game enforces that structure mechanically.

In `roguERGlike`, modalities map onto real-world training protocols (Zone 2, HIIT, Tabata, VO2 Max 4×4, Ramp Test, etc.). The actual roster of modalities and their specific numbers live in the **game repos** (bike-themed game has cycling protocols, future rowing game has rowing protocols). The **engine** provides the framework that makes modalities possible.

## What's framework (here) vs. game (separate)

| Framework (this repo) | Game (private repo) |
|---|---|
| `Modality` base resource and template system | Specific modality definitions (Zone2, Tabata, etc.) |
| Effort-band enforcement primitive | What "in band" means in each modality |
| Recovery scene scaffolding | What players do during recoveries |
| Interval timing engine | Specific interval structures |
| FIT/TCX segment emission hooks | Mapping of game phases to workout segments |
| FTP-relative normalization helper | The actual FTP percentages each modality targets |

## Modality template (engine)

```gdscript
class_name Modality extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String

# Total expected run length in seconds. Determines map size and encounter density.
@export var target_duration_s: int

# A run is broken into phases. Each phase has its own effort target and game pace.
@export var phases: Array[ModalityPhase]

# How strictly effort bands are enforced. "soft" = bonuses for staying in band;
# "hard" = run penalties for drifting; "lethal" = run ends.
@export_enum("soft", "hard", "lethal") var enforcement := "soft"

# What workout segment types each phase should be emitted as in the FIT export.
@export var export_segment_map: Dictionary
```

```gdscript
class_name ModalityPhase extends Resource

@export var kind: StringName           # "warmup", "interval", "recovery", "cooldown", "exploration", "boss"
@export var duration_s: int
@export var effort_target_pct_ftp: Vector2   # min, max as fraction of FTP
@export var hr_target_pct_max: Vector2       # min, max as fraction of max HR
@export var encounter_density: float         # encounters per minute during this phase
```

## What modalities can do via the framework

- Set effort-band targets (FTP %, HR %, cadence ranges) for any phase of a run
- Define rigid timed phases (intervals, recoveries) or soft phases (exploration)
- Enforce bands at three escalating levels (bonus, penalty, run-ending)
- Hook into the run-progression system to gate map advancement on effort compliance
- Hook into the FIT exporter so the player's Strava upload reflects the real workout structure

## What modalities cannot do (intentionally)

- Define cards or card effects (game responsibility)
- Set theme or narrative framing (game responsibility)
- Override the rules of card play (handled by the rules-module system separately)

## Why this lives in the engine

The interval-timing logic, effort-band enforcement, and FIT-segment-export hooks are pure infrastructure. They have no opinion on cycling, rowing, or running. A rowing game and a cycling game both want "a 4×4 minute interval protocol with HR-band enforcement"; only the FTP equivalent (Critical Power for rowers) and the theme differ. Keeping the framework here means the rowing game inherits all of it.

See the game repo's `docs/design/training-modalities.md` for the bike-game-specific modality roster.
