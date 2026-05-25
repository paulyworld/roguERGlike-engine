# ERGlike Vocabulary

**Status:** Canonical. All other docs (sidecar schema, gizzERG HANDOFF, engine planning docs) reference this file rather than redefining terms. Edit here once.

This doc is split into two audiences:

- **Part 1 — Rider-facing** vocabulary the rider chooses from when giving in-ride feedback (F2 overlay). Plain language. Optimized so a tired rider on the bike can pick the right tag in one keystroke.
- **Part 2 — Backend** vocabulary the protocol, profiles, and analyzers use. Technical. Anchored to industry standards where they exist.

Each term defined here is **stable on the wire** — renaming requires a major protocol version bump (per the `hello` envelope's `protocol_version`). New terms can be added freely as minor bumps.

---

## Part 1 — Rider-facing vocabulary (F2 annotation tags)

Press F2 mid-ride → the overlay shows preset hotkeys (1–5) for the most common feedback. Custom tags are supported via the text field for anything else.

### Quick lookup — "I want to say…"

| You feel / observed | Press F2, then… |
|---|---|
| That section was harder than it should have been | `1` → **too-hard** |
| That section was easier than it should have been | `2` → **too-easy** |
| Audio and video look out of sync with each other | `3` → **bad-sync** |
| Something visibly broke (UI froze, sound dropped, etc.) | `4` → **bug** |
| Just want to flag this moment for later review | `5` → **marker** |
| The model thought this was intense, but the music felt mellow | type **false-intensity** |
| The music felt intense, but the model treated it as mellow | type **missed-intensity** |
| Target cadence was off for this section | type **cadence-mismatch** |
| Pausing the video / between rounds (not me walking away) | type **ui-pause** |
| I intentionally stopped pedaling | type **walk-away** |

### Full tag reference

| Tag | Use it when… |
|---|---|
| `too-hard` | The target intensity felt subjectively too hard *for the music in this section*. Different rider, same music, would also feel it. |
| `too-easy` | Counterpart of `too-hard`. The section had room for more. |
| `bad-sync` | The audio and video are drifting out of sync, or the profile timing is misaligned to the source video. |
| `false-intensity` | The model classified this as a high-intensity section, but the music *here* is mellow. The model overshot. |
| `missed-intensity` | The model classified this as low-intensity, but the music *here* is driving. The model undershot. |
| `cadence-mismatch` | The target cadence (rpm) doesn't fit what this section wants — too fast for a grind, too slow for a sprint. |
| `ui-pause` | The client / app is pausing for its own reasons (between-rounds screen, YouTube paused). Distinct from a walk-away — the rider is still on the bike. |
| `walk-away` | The rider intentionally stopped pedaling (water, towel, phone). Distinct from a UI pause — the app is still running but the rider isn't. |
| `bug` | Something visibly broke. Use the optional note field to describe what. |
| `marker` | Generic "remember this moment" timestamp. Use when nothing else fits. |

### Style guidance for adding new tags

Keep tags short, lowercase, hyphenated. Verb-of-observation form (`missed-intensity`, not `intensity-missed`). One tag per observation — if a moment is both `too-hard` AND `bad-sync`, press F2 twice. Custom tags survive into recordings; if a custom tag proves useful across riders, promote it to the table above.

---

## Part 2 — Backend vocabulary

### Intensity scale

**`intensity = target_watts / rider_ftp`** — a normalized number where 1.0 = FTP. Industry standard (Zwift, TrainerRoad, Wahoo SYSTM, Coggan).

Practical range and traditional zones (Coggan zones, used by British Cycling and TrainerRoad):

| Intensity | Zone | Use |
|---|---|---|
| 0.00 – 0.55 | **Z1** Active Recovery | Easy spin, very light |
| 0.56 – 0.75 | **Z2** Endurance | Long aerobic |
| 0.76 – 0.90 | **Z3** Tempo | Sustainable hard |
| 0.91 – 1.05 | **Z4** Lactate Threshold | At/around FTP |
| 1.06 – 1.20 | **Z5** VO2 Max | Hard intervals |
| 1.21 – 1.50 | **Z6** Anaerobic Capacity | Short hard intervals |
| 1.51 – 2.00 | **Z7** Neuromuscular | Sprints, max efforts |

Schema bounds for intensity fields: **`[0.0, 2.0]`**. Values above 2.0 reject at schema validation. The actual safety ceiling lives separately at the BLE write layer (`--max-target-power`, default 800W); the schema bound is "what makes sense as a workout target" and the watts clamp is "what won't burn down the trainer."

**Two clamp layers are intentional:**

1. **Schema** validates `intensity ∈ [0.0, 2.0]` (rejects garbage).
2. **`watts = ftp × intensity`** computed by the client (gizzERG owns this math).
3. **Sidecar `--max-target-power`** caps the final wattage before writing FTMS.

Result: a `1.5` intensity on a 250W FTP becomes 375W → written to trainer (under 800W default clamp). A `1.5` intensity on a 600W FTP becomes 900W → clamped to 800W at the FTMS write.

References:
- British Cycling Zones — https://www.britishcycling.org.uk/knowledge/article/izn20140808-Cycling-Training---The-7-Cycling-Training-Zones-0
- TrainerRoad Power Levels — https://www.trainerroad.com/blog/power-zones-the-pioneers-best-kept-secret/
- Coggan zones (canonical source) — Allen, Coggan, McGregor: *Training and Racing with a Power Meter* (3rd ed.)

### Annotation context fields (recommended convention)

Sidecar treats the `context` blob on `annotate` commands as opaque pass-through. The recommended fields below let analyzers join ride annotations to profile/result data without each client guessing. Clients should populate what they have; sidecar persists verbatim.

| Field | Meaning |
|---|---|
| `profile_id` | The ride profile being played (e.g. `bnnIdWzGSYI`) |
| `profile_version` | Version of that profile — leaderboards/ghosts compare like-with-like |
| `mode` | Ride mode (see *Mode names* below) |
| `video_id` | Source media id |
| `section` | Current song / section label at time of annotation |
| `target_watts` | ERG target wattage at moment of annotation |
| `power`, `cadence`, `hr` | Latest telemetry snapshot |
| `wkg` | Power-to-weight at the moment |
| `grade` | Current virtual grade percent (terrain modes) |
| `speed_kph` | Virtual or trainer-reported speed |
| `distance_m`, `elevation_gain_m` | Accumulated distance/elevation for the ride |
| `hardware_source` | One of `trainer_power` / `power_meter` / `estimated_power` / `mock` |
| `estimated_intensity` *(planned)* | Model's intensity at this moment — lets `too-hard` annotations train against the curve directly |
| `audio_features` *(planned)* | Snapshot of live audio features (loudness, centroid, flux, harmonic_ratio) — same training-signal idea |

### Mode names

Current implemented modes (gizzERG `workout-patterns.js`):

| Mode id | Meaning |
|---|---|
| `raw_feel` | Music-first manual map. Profile authors set intensity directly; no model overlay. |
| `aerobic_builder` | Whole-video endurance/tempo with progressive warmup and cooldown |
| `tempo_intervals` | Repeated tempo / recovery / sweet-spot blocks |

Planned modes (from `concert-mode-exploration.md`):

| Mode id | Meaning |
|---|---|
| `terrain_erg` | ERG-controlled trainer driven by intensity, with grade/distance/elevation shown as **presentation only** (no FTMS SIM writes). Distance is synthetic; the trainer follows watts. |
| `terrain_sim` | SIM-mode trainer driven by grade via FTMS opcode `0x11`. Rider chooses gear + cadence to make power, trainer adjusts resistance. Distance can be synthetic (computed from speed + profile) or trainer-reported. |

### Hardware source (annotation + result schema)

| Value | Meaning |
|---|---|
| `trainer_power` | FTMS-reported watts from a smart trainer |
| `power_meter` | Standalone power meter (pedals, crank-arm), no smart trainer |
| `estimated_power` | Derived from speed + virtual-bike physics; no real power measurement |
| `mock` | Mock-mode sidecar |

### Distance / elevation source (sidecar schema)

| Value | Meaning | Producer |
|---|---|---|
| `trainer` | FTMS `meters_total` from the bike | Sidecar `BleSource` (auto when bit 4 of Indoor Bike Data flags is set) |
| `synthetic` | Computed from a terrain profile + trainer speed | Client (gizzERG, future engine) pushes events |
| `gps` | Real-world GPS or route-replay | Future |

**Do not conflate.** A 30 km Terrain Mode ride is materially different from a 30 km outdoor route. Exports must preserve the distinction. See memory `terrain-distance-ownership`.

### Hello envelope features (`hello.data.features`)

Stable feature strings the sidecar advertises. Clients gate UI on the combination of `features` AND `device_capabilities` (the former is "sidecar protocol can do X"; the latter is "this trainer can do X").

| Feature | What it advertises |
|---|---|
| `set_target_power` | The `set_target_power` command (gated at runtime on `--allow-trainer-control` via typed rejection) |
| `recording` | The `--record <path>` CLI flag |
| `annotations` | The `annotate` command + `rider_annotation` envelope |
| `structured_pause` | The `pause` / `resume` commands + `paused` / `resumed` envelopes |
| `distance` | `distance` + `elevation` events with `source` attribution |
| `activity_export` | FIT export of completed sessions via the `roguerglike-export` CLI |
| `indoor_bike_simulation` | The `set_simulation` command — FTMS opcode `0x11` write path |

Adding a feature here is a minor protocol version bump. Removing or renaming is a major bump.

---

## Part 3 — Profile authoring vocabulary (gizzERG terrain model)

Codex's domain. Listed here so the engine planning docs (`music-intensity-proposal.md`, `concert-mode-exploration.md`) and the gizzERG profile shape both anchor to the same words.

### Override types (`profile.terrain_overrides[].type`)

| Type | Meaning |
|---|---|
| `cap` | Derived intensity may vary but cannot exceed `max_intensity` for the window |
| `floor` | Derived intensity may vary but cannot fall below `min_intensity` |
| `anchor` | Pull blended intensity toward an authored value with a local `weight` |
| `event` | Discrete musical event — see *Override events* |
| `manual-override` | Hard set intensity for a window (highest precedence) |

### Override events (`profile.terrain_overrides[].event`)

| Event | Meaning |
|---|---|
| `crescendo` | Authored as a build-up that *resolves into* the next section. Per the rolling-window confirmation rule, never sustained on its own. |
| `drop` | Short punchy climb / sprint window. Intentionally allows `intensity > 1.0` (Z5–Z7 territory). |
| `song-boundary` | Reset smoothing / permit sharper intensity changes at this point |

These are author-side decisions about the music. They share *noun names* with some rider-side F2 tags but are not the same concept:

- F2 `missed-intensity` near t=1234 = "rider noticed the model under-classified intensity here"
- `event: crescendo` at t=1234 = "author decided this window is a crescendo"

When both appear at the same time, the analyzer's join is: "rider agreed with / disagreed with the authored crescendo." Different layers, complementary vocabulary.

### Terrain themes (`profile.terrain_theme`)

| Theme | Bias |
|---|---|
| `climbing` | Intense sections become sustained climbs and elevation gain |
| `rolling` | Intensity waves become repeated rollers and short pitches |
| `flat` | Grade stays low; intensity peaks become sprint intervals or wind/pace pressure |
| `mixed` | Preserves more of the raw song contour |

References:
- `concert-mode-exploration.md` — terrain themes
- `music-intensity-proposal.md` Piece 3b — Blended Terrain Model (override semantics, blend slider)

---

## Editing this doc

Single source of truth. When adding a tag, override type, mode name, or feature string:

1. Add to the relevant table here.
2. Bump the appropriate version (protocol/profile/etc.) per the rules above.
3. Reference this file from any other doc that mentions the term; don't redefine.

If a term in another doc disagrees with this one, **this file wins** until updated.
