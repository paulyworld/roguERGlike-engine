# Concert Mode Exploration

**Research date:** 2026-05-23

## Summary

The strongest next Concert MVP mode is a terrain interpretation of the existing music intensity profile:

> Treat BPM/intensity as virtual terrain. Higher intensity becomes climbing grade; song breaks and jam sections become flats, rollers, descents, or false flats.

This gives the app a cycling-native metaphor without abandoning the core concert idea. The rider is still "riding the show," but the output becomes climb distance, elevation gain, category, segment time, watts/kg, and eventually leaderboards.

## Coding Posture

Start with a client-only Terrain prototype in gizzERG (`repos/concert-mvp`). Do not wait for FTMS SIM mode, Bluetooth controls, public leaderboards, or group rides.

The first prototype can be developed as a standalone terrain model based on the song/profile chart, with estimated distance from terrain plus realistic speeds for the rider's power/cadence levels. Then decide whether a ride uses that terrain as ERG-on visual/export context, Manual/SIM trainer control, or a future mix of both.

For the polished app shell, use SvelteKit + TypeScript + authored CSS/CSS modules. Terrain math should be pure TypeScript; terrain visuals should be authored UI, canvas, or WebGL as needed, not Tailwind utility sprawl.

The first coded version should answer one question:

> Does a concert feel better when the intensity profile is presented as a virtual climb with grade, elevation, distance, and segments?

Everything else should be staged behind that answer.

## Terrain Mode Concept

Inputs:

- media playback clock;
- concert profile sections and intensity curve;
- rider FTP and weight;
- live power/cadence/HR;
- eventually virtual speed and distance from the sidecar distance module.

Outputs:

- current virtual grade;
- current virtual speed;
- elapsed distance;
- elevation gain;
- distance-domain power and pacing metrics;
- climb/segment category;
- difficulty score;
- segment split and leaderboard placement.

The useful mental model is not "ERG workout with music," but "a virtual climb whose terrain was composed from the song."

Design rules:

- Choruses, dense riffs, fast BPM, or high-authored intensity map to steeper grades.
- Breakdowns, jams, intros, interludes, and low-intensity sections map to flats, descents, or shallow grades.
- Smoothing matters more than literal BPM. Sudden musical changes can create short pitches, but grade should not flicker every beat.
- Difficulty should be reproducible from profile data plus rider settings, so leaderboards are meaningful.
- Separate the terrain route from the trainer-control mode. The same route can later be experienced with ERG on, Manual/SIM, or mixed-mode toggling during a ride.
- To start, route terrain is dictated by the song/profile and should be the same regardless of control mode.

## Route Generation and Terrain Themes

Owner: **Codex / gizzERG (`concert-mvp`)** for client modeling; later shared with sidecar/export when route profile protocol exists.

Initial rule:

- One song/profile-derived route is canonical for the ride.
- ERG-on, Manual/SIM, and mixed mode use the same route geometry: distance, grade, elevation, segments, and category labels.
- Control mode changes how the rider experiences the route, not what the route is.

Future terrain themes:

- Add a terrain-theme layer that modulates the same video/song inputs into different ride shapes.
- Theme examples:
  - `climbing`: biases intense sections toward climbs and sustained elevation gain.
  - `rolling`: turns intensity waves into repeated rollers and short pitches.
  - `flat`: keeps grade mostly low; intense sections become sprint intervals or wind/pace pressure rather than long climbs.
  - `mixed`: preserves more of the raw song contour.
- The theme should not discard the music/video intensity concept. It should reshape it into the desired ride type.

Theme implementation idea:

```text
song_features + authored_overrides + terrain_theme -> route_profile
```

Where `route_profile` contains sampled distance, grade, elevation, segment labels, and metadata needed for results/export.

Important constraint:

- Once a route profile is generated and used for a result, it needs a stable `profile_version` / `route_version` so local results, ghosts, and future leaderboards compare like with like.

## Minimum Viable Terrain Mode

Owner: **Codex / gizzERG (`concert-mvp`)**

Inputs available now:

- current playback time;
- authored profile intensity;
- current target watts;
- rider FTP;
- rider weight, if already present or easy to add;
- latest telemetry from sidecar.

First implementation:

- Add a ride mode selector with existing mode(s) plus `Terrain`.
- Add a dev/test tuning popout with sliders for terrain mapping parameters.
- Convert profile intensity to `grade_percent` with smoothing and clamps.
- Compute virtual speed from a simple deterministic model using terrain plus rider power/cadence estimates.
- Accumulate virtual distance and positive elevation gain client-side.
- Show current grade, distance, elevation gain, segment name/category, and W/kg.
- Render a side-view terrain map: elevation gain/fall as the main profile, vertical color-shaded climb-rating bars, and a rider progress line tracing over the elevation topline.
- Keep power/pacer data in a separate HUD so the terrain graphic can stay visual and readable.
- Keep sending ERG target watts exactly as the current app does.

Explicit deferrals:

- no FTMS SIM writes;
- no real Bluetooth shifting;
- no public leaderboard;
- no server;
- no Strava export of synthetic route details until FIT export policy is settled.

Suggested grade mapping:

```text
grade_percent = clamp((intensity - 0.45) * 18.0, -2.0, 12.0)
```

This is intentionally simple. Tune it from ride feel and F2 annotations rather than overfitting the first formula.

Suggested speed model:

```text
effective_mass_kg = rider_weight_kg + 9.0
speed_mps = physics_step(power_watts, grade_percent, effective_mass_kg)
```

The first `physics_step` can be approximate. The key requirement is determinism for a given profile version and rider input.

## Dev/Test Terrain Tuning Popout

Owner: **Codex / gizzERG (`concert-mvp`)**

During development and ride testing, include a non-production tuning surface that lets us adjust how video/audio/profile data maps into terrain.

Initial controls:

- grade gain / scale;
- grade offset / baseline;
- minimum grade;
- maximum grade;
- smoothing window in seconds;
- downhill allowance on/off;
- intensity floor/ceiling remap;
- virtual bike mass;
- rolling resistance;
- aerodynamic drag scalar.

Useful live outputs:

- current raw intensity;
- smoothed intensity;
- computed grade;
- virtual speed;
- accumulated distance;
- accumulated elevation gain;
- current target watts;
- current W/kg.

Persistence:

- Store tuning presets locally during development.
- Do not treat slider values as final profile schema until a ride-tested preset feels good.
- When promoted, save the chosen mapping as a versioned terrain profile so local results and future leaderboards can identify the exact route version.

UX constraint:

- The popout is a development/test tool. It can be visible in dev mode or behind an explicit toggle, but it should not define the final artistic gizzERG ride interface.

## Initial Terrain Visualization

Owner: **Codex / gizzERG (`concert-mvp`)**

Target the proven cycling-app pattern:

- side-view elevation chart showing the full track/segment terrain;
- vertical shaded bars behind or within the chart that encode climb rating, with red reserved for the hardest sections;
- a progress trace/marker that rides along the top line of the elevation profile;
- separate HUD blocks for current power, cadence, HR, grade, W/kg, distance, elevation gain, and elapsed/remaining time;
- optional pacer panel that shows delta versus personal best, ghost rider, or another rider's time.

Visual intent:

- The elevation map should be the emotional ride surface: it shows what is coming and how hard the current section is.
- The HUD should be operational: current effort, pacing, and trainer state.
- Do not overload the terrain chart with every metric; keep the map scannable at riding distance.

First implementation detail:

- Build this as a deterministic SVG or canvas component fed by the terrain module's sampled route points.
- Use climb-rating color bands from easy/flat through red/hard climb.
- Start with a single rider progress marker; add ghost/pacer overlays after local result replay exists.

## Charting Differences by Mode

ERG and Terrain modes should not be forced into the same chart layout.

Current ERG-focused ride timeline:

- Primary x-axis is media time.
- Primary concern is target watts over time.
- Cadence, HR, and current power explain compliance with the workout target.
- Terrain, if shown, is secondary context.

Terrain-focused timeline:

- Primary x-axis should be distance or route progress, with media time still available as context.
- Primary visual surface is the elevation profile and grade distribution.
- Power is interpreted as work over distance and slope, not only as compliance with a time-based target.
- Speed, W/kg, grade, elevation gain, and pacer delta become first-class metrics.
- The layout should make it easy to see "what climb is coming" and "how far through the climb am I?"

Recommended first Terrain chart layout:

- Full elevation profile as a shaded background region.
- Vertical climb-rating bars layered into the profile, with red for the hardest grades.
- Rider progress line/marker tracing over the top of the elevation profile.
- Optional current viewport/zoom around the rider while preserving a whole-route overview.
- Separate HUD for live power, cadence, HR, grade, speed, W/kg, distance, elevation gain, and pacer delta.

Pacer mode:

- Start with delta versus personal best once local results exist.
- Later allow ghost rider or another rider's time.
- Keep pacer delta outside the terrain chart unless adding a ghost overlay improves readability.

## ERG-On vs Manual/SIM During a Ride

Long-term target: the rider should be able to toggle ERG on/off during a ride.

ERG-on:

- The app/sidecar controls target watts.
- Terrain, distance, elevation, wind, and world visuals can be shown and recorded, but they are not what directly changes trainer resistance.
- Rider feel comes from target watts, cadence, fatigue, ramping, and the psychological context of the terrain/music.
- Speed/distance/elevation are model outputs useful for UI, results, ghosts, and exports.

Manual/SIM:

- The route model controls trainer feel through grade/resistance/simulation parameters.
- Terrain, wind, rolling resistance, rider/bike mass, gearing, and cadence determine how hard it feels to produce power.
- Speed and distance are derivatives of rider power, cadence/gearing/trainer physics, wheel circumference or virtual gearing, slope, wind, and resistance terms.
- Rider choice matters more: gearing and cadence become central controls rather than presentation.

Mixed mode:

- A ride can use the same terrain profile while switching control modes.
- Switching modes should not alter canonical route distance/elevation/category.
- Results and exports should record which control mode was active over time so later analysis can distinguish ERG-on sections from Manual/SIM sections.

## Control Modes

## Industry Reference: Terrain, ERG, and Manual Modes

Current training apps split terrain difficulty into two broad control models.

### ERG-On / Workout Control

In ERG mode, terrain is not the trainer-control input. The app sends a target wattage and the trainer adjusts resistance to hold that wattage as cadence changes.

Observed patterns:

- Zwift workouts: ERG resistance is based on cadence and workout target, not road gradient. Speed is still calculated from rider power.
- TrainerRoad: target power is based on FTP; gearing and cadence do not change the target resistance, though they can change feel and flywheel speed.
- Wahoo SYSTM: ERG meets power targets; Level mode is the alternative where the rider shifts to hit targets.
- ROUVY workouts: ERG mode is for precise power targeting in workouts.

Implication for gizzERG:

- **ERG-on Terrain** should treat grade/elevation as presentation, route stats, and export context.
- Trainer commands remain target watts.
- Difficulty and rider feel are primarily controlled by target-watt mapping, FTP scaling, workout profile intensity, cadence, fatigue, and music/video context.
- Distance and elevation can still be useful in ERG-on mode, but they are model outputs rather than the mechanism directly changing trainer resistance.
- Shifting in ERG Terrain should be UI/pacing flavor only until SIM mode exists.
- Cadence can still vary meaningfully on big "climbs" because riders naturally change cadence under different target watts, fatigue, and perceived terrain. ERG does not make cadence irrelevant; it just prevents cadence/gearing from being the primary way difficulty is set.

Good ERG Terrain difficulty knobs:

- target-watt intensity scale;
- FTP percent caps/floors;
- ramp duration/smoothing;
- recovery floor;
- terrain grade display scale;
- virtual speed model difficulty, if local results use terrain distance/time.

### Manual / SIM / Slope Control

In manual terrain modes, the app sends terrain or resistance rather than a target wattage. The rider changes gear/cadence to choose power output.

In this mode, cadence is primarily up to the rider. Power comes from the combination of felt grade/resistance, selected gear, cadence, rider strength, and trainer physics. The easiest available gear or virtual gear range becomes the practical lower limit for holding a given power on steep terrain, especially for riders whose FTP makes a climb disproportionately hard.

Observed patterns:

- ROUVY route mode uses real route data such as elevation, slope, and length; it models slope, gravity, air resistance, rider/bike weight, and related factors, then sets smart-trainer resistance.
- FulGaz defaults to high realism and exposes separate uphill/downhill slope scaling plus a maximum slope limit. Lowering uphill scaling acts like easier gearing without changing speed for a given power.
- Zwift free ride/SIM mode sends gradient to the trainer, with Trainer Difficulty scaling how much of the gradient is felt. This changes feel/gearing demand, not route speed for a given rider output.
- ROUVY now supports virtual shifting through on-screen controls, keyboard, and companion app on compatible Bluetooth-connected trainers.
- Zwift virtual shifting uses compatible trainers and controller devices; it provides 24 virtual gears and changes resistance electronically to match the selected virtual gear.

Implication for gizzERG:

- **SIM Terrain** should use grade as the trainer-control input once sidecar supports FTMS Indoor Bike Simulation Parameters.
- Difficulty should have separate "route truth" and "trainer feel" concepts:
  - route grade: canonical grade used for scoring, distance, elevation, category, results;
  - felt grade: scaled/clamped grade sent to the trainer for comfort and hardware limits.
- Virtual shifting belongs naturally in SIM Terrain, not ERG Terrain.
- Manual/SIM difficulty should consider FTP-aware accessibility: a route may be canonically steep while the felt grade, virtual gear range, or lowest gear can be adjusted so the rider is not forced below a sustainable cadence.
- Wind should be kept out of the first implementation, but the physics model should leave room for headwind/tailwind/crosswind mechanics later.

Good SIM Terrain difficulty knobs:

- uphill slope scaling;
- downhill slope scaling;
- maximum felt uphill grade;
- maximum felt downhill grade;
- virtual gear range;
- starting/neutral gear;
- rider+bike mass;
- rolling resistance;
- aerodynamic drag;
- route difficulty/category scoring.

Implementation rule:

Do not let comfort scaling corrupt the canonical route. If a song section maps to a 9% climb, keep that 9% in the route/profile and leaderboard version. A rider may choose 50% felt-grade scaling so the trainer feels like 4.5%, but route distance/elevation/category should remain tied to the canonical terrain version.

## ERG-On Distance and Export Stats

Owner: **Codex / gizzERG (`concert-mvp`)** for client display; **Claude / sidecar** for durable recording/export.

In ERG-on Terrain, distance and elevation should be treated carefully:

- They can make the ride feel more complete and legible.
- They can provide useful completed-activity stats for Strava and other platforms.
- They can support local results, ghosts, and route-like replay.
- They should not be presented as the mechanism that caused the resistance unless the app is actually in SIM/manual terrain mode.

Export policy:

- Mark ERG Terrain exports as indoor/virtual trainer activities where the platform supports it.
- Preserve enough metadata to distinguish synthetic distance/elevation from trainer-reported distance.
- Avoid implying outdoor GPS route truth unless a GPX/route file or generated world route is explicitly part of the activity.

Longer-term map direction:

- A generative world map could turn linear ride distance into a visual route, even when no real GPS route exists.
- GPX-backed modes could use actual route distance/elevation as the canonical terrain source.
- Music-generated terrain and GPX-generated terrain should share the same route-sample abstraction: distance, elevation, grade, segment/category metadata, and optional media sync.

### Phase 1: ERG Terrain Skin

Keep using target power. The app displays grade, distance, elevation, and segments, but sidecar still drives trainer resistance by ERG watt target.

Pros:

- Works with current sidecar control path.
- Low risk for live rides.
- Good enough to test whether the terrain metaphor feels compelling.

Cons:

- Shifting is cosmetic because ERG absorbs gear/cadence choices.
- Speed/distance are synthetic and must be labelled as virtual.

### Phase 2: SIM Mode Terrain

Use FTMS Indoor Bike Simulation Parameters instead of target power when the trainer supports it. The sidecar writes grade, wind speed, rolling resistance, and wind resistance to the FTMS Control Point. This makes gears and cadence matter more naturally.

Current research:

- FTMS has a Set Indoor Bike Simulation Parameters procedure with wind speed, grade, coefficient of rolling resistance, and wind resistance coefficient.
- Grade is represented as percent with 0.01 resolution in the FTMS data model.
- Existing sidecar `device_capabilities` already includes `indoor_bike_simulation`, so the client can gate terrain mode correctly once the sidecar implements the write path.

Sources:

- https://support.zwift.com/erg-mode-in-workouts-SkQJC8OEH
- https://support.trainerroad.com/hc/en-us/articles/201869764-Erg-Mode-Explained
- https://support.trainerroad.com/hc/en-us/articles/360024069532-Smart-Trainer-Modes-Explained
- https://support.wahoofitness.com/hc/en-us/articles/4402565516946-A-Guide-to-using-ERG-mode
- https://support.rouvy.com/hc/en-us/articles/360018681117-How-does-ROUVY-control-resistance-and-calculate-virtual-power
- https://feedback.fulgaz.com/en/help/articles/360004732451-the-resistance-andor-climbs-feel-too-hard
- https://support.rouvy.com/hc/en-us/articles/32452137189393
- https://support.zwift.com/en_us/virtual-shifting-faq-r16UiRFlT
- https://files.bluetooth.com/wp-content/uploads/dlm_uploads/2024/10/FTMS.TS_.p6.pdf
- https://dudanov.github.io/python-pyftms/pyftms.html
- https://stackoverflow.com/questions/59653425/zwift-add-resistance-with-ftms-control-point

## Shifting

Shifting should be introduced in layers.

Phase 1:

- UI-only virtual gear selector.
- Keyboard shortcuts and on-screen controls.
- Gear affects displayed target cadence/speed estimates, not trainer physics.

Phase 2:

- Sidecar command surface for `shift_up`, `shift_down`, `set_virtual_gear`.
- In ERG mode, gear remains mostly presentational.
- In SIM mode, gear affects speed model and rider feel.

Phase 3:

- Bluetooth controller support.
- Zwift Click / Zwift Play style devices are the target inspiration, but direct compatibility must be verified experimentally.

Current ecosystem notes:

- Zwift virtual shifting uses compatible trainers plus Zwift Click or Zwift Play paired as Bluetooth Controls units.
- Wahoo documents that Zwift virtual shifting uses 24 linear virtual gears on compatible Wahoo smart trainers.
- Zwift virtual shifting is app/platform-specific; do not assume third-party apps can reuse the exact same protocol without device-level investigation.

Sources:

- https://support.zwift.com/en_us/virtual-shifting-faq-r16UiRFlT
- https://support.wahoofitness.com/hc/en-us/articles/16865097915666-Zwift-virtual-shifting-with-Wahoo-smart-trainers
- https://support.wahoofitness.com/hc/en-us/articles/16470181834642-KICKR-CORE-Zwift-One-FAQ

## Distance, Elevation, and Difficulty

Terrain mode needs a distance module, but the first version can use virtual distance derived from power, grade, rider weight, and a simple physics model.

Minimum model:

- rider mass = configured rider weight;
- bike mass = fixed default, later configurable;
- grade comes from intensity curve;
- speed comes from power/cadence estimates against gravity, rolling resistance, and aerodynamic drag;
- elevation gain accumulates only on positive grades.

Do not overfit the first implementation to BPM alone. The first terrain generator can start from the song/profile chart, then let the tuning popout adjust grade scale, smoothing, floor/ceiling, and speed-model assumptions until the terrain feels plausible for real riding.

## Model Training and Manual Feedback Loop

Owner: **Codex / gizzERG (`concert-mvp`)** for tooling; user supplies ride/video annotations; later analyzers may live in a shared tool or server repo.

The song/video-to-power and song/video-to-terrain model will need manual feedback. Some current quirks are expected:

- A mellow section that ends in a crescendo can trigger a sustained intensity section too early.
- The right training response might be to wait until the next intense song or song part starts.
- Raw musical feel and sports-science-backed training load may disagree.

Build tools to collect and use these corrections:

- F2/rider annotations during rides for subjective feel: too hard, too easy, bad sync, false intensity, missed intensity, cadence mismatch.
- Post-ride timeline editor for correcting section boundaries, intensity starts, intensity ends, and terrain/power intent.
- Ability to mark musical events: crescendo, drop, break, jam, chorus, riff, sprint cue, recovery cue.
- Side-by-side overlays: audio/video-derived intensity, authored overrides, target watts, generated grade, rider power/cadence/HR, and rider annotations.
- Exportable correction data so future model/rule changes can be trained against prior manual edits.

Model/rule outputs should support multiple modes:

- `raw_feel`: follows musical intensity more literally.
- `training_balanced`: keeps the concert feel while respecting workout structure and fatigue management.
- `climbing`: turns intensity into sustained climbs.
- `rolling`: emphasizes repeated changes in grade.
- `flat_sprints`: keeps grade low and maps intensity peaks to sprints or wind/pace pressure.

Different modes can use different weights:

```text
output = weighted_mix(
  audio_energy,
  bpm,
  section_boundaries,
  crescendo_detection,
  authored_overrides,
  sports_science_constraints,
  terrain_theme
)
```

Near-term rule to test:

- Do not let a short end-of-section crescendo automatically create a long sustained effort.
- Require either duration, repeated intensity, a new section boundary, or authored confirmation before extending the high-intensity segment.

Difficulty metrics:

- total elevation gain;
- normalized grade distribution;
- climb score;
- estimated TSS/IF;
- category based on climb score.

For climb categorization, use a Strava-like objective formula first because it is transparent and leaderboard-friendly:

```text
climb_score = climb_length_m * average_grade_percent
```

Strava states a segment can be categorized as a climb if length in meters multiplied by grade is greater than 8,000. Garmin also documents climb category as length multiplied by average grade. UCI and Grand Tour categories are more context-driven, so use "UCI-style" naming in product copy unless/until the exact classification rules are owned by our app.

Sources:

- https://support.strava.com/hc/en-us/articles/216917057-Climb-Categorization
- https://support.garmin.com/en-GB/?faq=5Y8GPTBEYxAd4jtWebIXG9
- https://cyclingmagazine.ca/sections/news/gradient/

## Track Leaderboards

Leaderboards should be track/route-specific, not just global ride totals.

Good initial categories:

- fastest completion time;
- best average watts/kg;
- best normalized power/kg;
- best climb time by category;
- personal best;
- friends-only rank.

Leaderboard fairness requirements:

- Require rider weight for watts/kg boards.
- Record FTP and weight snapshot at ride start.
- Mark hardware source: real trainer power, power meter, estimated power, mock.
- Separate mode versions. If the profile or terrain mapping changes, it must create a new leaderboard version.
- Separate ERG Terrain and SIM Terrain boards because rider agency and physics differ.
- Keep private/local leaderboards before public leaderboards.

Track classification:

- Use Cat 4, Cat 3, Cat 2, Cat 1, HC as route/segment labels.
- Let a single concert produce multiple classified segments: opener climb, mid-show climb, finale climb.
- Also maintain whole-concert GC-style boards.

## Local Result Schema

Owner: **Codex / gizzERG (`concert-mvp`)**

Before any server leaderboard exists, save local results with enough structure to migrate later.

Candidate shape:

```json
{
  "profile_id": "king-gizzard-red-rocks-2022-night-1",
  "profile_version": "terrain-v0",
  "mode": "terrain_erg",
  "started_at": "2026-05-23T18:42:00-06:00",
  "duration_s": 3680,
  "distance_m": 24850,
  "elevation_gain_m": 612,
  "avg_power_w": 187,
  "normalized_power_w": 211,
  "avg_wkg": 2.67,
  "normalized_wkg": 3.01,
  "rider_weight_kg": 70,
  "ftp_w": 250,
  "hardware_source": "trainer_power",
  "sidecar_session_id": "uuid"
}
```

This does not need to be public or cloud-backed. It exists so ghost rides, personal bests, and later server uploads use the same vocabulary.

## Group Ride Mode

Group ride mode is attractive but should be staged carefully.

Phase 1:

- Asynchronous ghosts from prior rides.
- Show a few saved riders on the same track using their recorded power/speed timeline.
- No server dependency.

Phase 2:

- Scheduled shared start using server time.
- Riders see live relative position, watts/kg, and split gaps.
- Chat/reactions can wait; the core is shared effort and presence.

Phase 3:

- True live group ride service.
- Server owns room state, profile version, start time, rider snapshots, and leaderboard ingestion.
- Sidecar remains local trainer runtime; it should not own multiplayer state.

Key design point: group rides should use the same deterministic route/profile version as leaderboards. The server can compare riders because every client is riding the same terrain mapping.

## Product Risks

- BPM is not the same as intensity. The profile needs authored overrides, not pure audio analysis.
- SIM mode can feel worse than ERG if the physics model is crude or if trainers vary widely in grade response.
- Public leaderboards create trust and moderation work. Start private/local.
- Bluetooth controller compatibility may be platform-specific and not guaranteed.
- Grade/distance exports to Strava may imply outdoor-like distance. Export files must clearly mark indoor/virtual trainer activities.

## Implementation Ownership

Current split:

- **Claude / sidecar:** distance derivation, virtual distance/elevation recorder fields, SIM mode FTMS write support, virtual shifting command schema, trainer capability events.
- **Codex / gizzERG (`concert-mvp`):** mode design, terrain mapping, route visualization, UI-only shifting, segment overlays, local leaderboards, ghost rides, and eventual SvelteKit + TypeScript + authored-CSS app shell.
- **Server owner later:** public accounts, cloud leaderboards, group ride rooms, anti-cheat policy, privacy controls.
- **Codex / engine:** no immediate work unless Godot becomes an active client again.

## Recommended Path

1. **Codex / gizzERG (`concert-mvp`):** extract terrain math into a pure module with tests: intensity -> grade, power/grade -> speed, distance/elevation accumulation.
2. **Codex / gizzERG (`concert-mvp`):** prototype Terrain Mode as a pure client mode using the existing intensity profile and ERG target output.
3. **Codex / gizzERG (`concert-mvp`):** add virtual route/elevation UI: current grade, distance, elevation gain, climb category, segment progress.
4. **Claude / sidecar:** finish distance derivation and ensure ride logs include enough samples for post-ride route reconstruction.
5. **Codex / gizzERG (`concert-mvp`):** add local-only track results: time, avg W/kg, normalized W/kg, elevation, category.
6. **Codex / gizzERG (`concert-mvp`):** add UI-only shifting controls and keyboard shortcuts.
7. **Claude / sidecar:** research and implement FTMS SIM mode command support behind `indoor_bike_simulation` capability.
8. **Codex + Claude:** compare ERG Terrain versus SIM Terrain in mock mode and live KICKR rides.
9. **Codex / gizzERG (`concert-mvp`):** add asynchronous ghost riders from prior local ride logs.
10. **Server owner later:** design authenticated leaderboard API with profile versioning and hardware-source flags.
11. **Server owner later:** design scheduled group rides after local ghosts and private leaderboards feel good.

## First PR Cut

Recommended first coding PR in `repos/concert-mvp`:

- Add pure terrain math module.
- Add tests for grade mapping, smoothing, category scoring, and accumulation.
- Add mode selector state for `terrain_erg`.
- Add dev/test terrain tuning popout with sliders for mapping parameters.
- Render read-only Terrain Mode metrics without changing existing trainer command behavior.

This PR should not depend on sidecar changes. It gives Claude room to review and implement sidecar protocol work in parallel.

Do this in the current app if that is fastest. Do not block the Terrain Mode proof on the SvelteKit migration. When the app shell migration begins, preserve the pure terrain/workout/protocol modules and move the presentation into Svelte components with local authored CSS.
