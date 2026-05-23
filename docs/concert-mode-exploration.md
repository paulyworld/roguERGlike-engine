# Concert Mode Exploration

**Research date:** 2026-05-23

## Summary

The strongest next Concert MVP mode is a terrain interpretation of the existing music intensity profile:

> Treat BPM/intensity as virtual terrain. Higher intensity becomes climbing grade; song breaks and jam sections become flats, rollers, descents, or false flats.

This gives the app a cycling-native metaphor without abandoning the core concert idea. The rider is still "riding the show," but the output becomes climb distance, elevation gain, category, segment time, watts/kg, and eventually leaderboards.

## Coding Posture

Start with a client-only ERG Terrain prototype in `repos/concert-mvp`. Do not wait for FTMS SIM mode, Bluetooth controls, public leaderboards, or group rides.

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
- climb/segment category;
- difficulty score;
- segment split and leaderboard placement.

The useful mental model is not "ERG workout with music," but "a virtual climb whose terrain was composed from the song."

Design rules:

- Choruses, dense riffs, fast BPM, or high-authored intensity map to steeper grades.
- Breakdowns, jams, intros, interludes, and low-intensity sections map to flats, descents, or shallow grades.
- Smoothing matters more than literal BPM. Sudden musical changes can create short pitches, but grade should not flicker every beat.
- Difficulty should be reproducible from profile data plus rider settings, so leaderboards are meaningful.

## Minimum Viable Terrain Mode

Owner: **Codex / concert-mvp**

Inputs available now:

- current playback time;
- authored profile intensity;
- current target watts;
- rider FTP;
- rider weight, if already present or easy to add;
- latest telemetry from sidecar.

First implementation:

- Add a ride mode selector with existing mode(s) plus `Terrain`.
- Convert profile intensity to `grade_percent` with smoothing and clamps.
- Compute virtual speed from a simple deterministic model.
- Accumulate virtual distance and positive elevation gain client-side.
- Show current grade, distance, elevation gain, segment name/category, and W/kg.
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

## Control Modes

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
- speed comes from power against gravity, rolling resistance, and aerodynamic drag;
- elevation gain accumulates only on positive grades.

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

Owner: **Codex / concert-mvp**

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
- **Codex / concert-mvp:** mode design, terrain mapping, route visualization, UI-only shifting, segment overlays, local leaderboards, ghost rides.
- **Server owner later:** public accounts, cloud leaderboards, group ride rooms, anti-cheat policy, privacy controls.
- **Codex / engine:** no immediate work unless Godot becomes an active client again.

## Recommended Path

1. **Codex / concert-mvp:** extract terrain math into a pure module with tests: intensity -> grade, power/grade -> speed, distance/elevation accumulation.
2. **Codex / concert-mvp:** prototype Terrain Mode as a pure client mode using the existing intensity profile and ERG target output.
3. **Codex / concert-mvp:** add virtual route/elevation UI: current grade, distance, elevation gain, climb category, segment progress.
4. **Claude / sidecar:** finish distance derivation and ensure ride logs include enough samples for post-ride route reconstruction.
5. **Codex / concert-mvp:** add local-only track results: time, avg W/kg, normalized W/kg, elevation, category.
6. **Codex / concert-mvp:** add UI-only shifting controls and keyboard shortcuts.
7. **Claude / sidecar:** research and implement FTMS SIM mode command support behind `indoor_bike_simulation` capability.
8. **Codex + Claude:** compare ERG Terrain versus SIM Terrain in mock mode and live KICKR rides.
9. **Codex / concert-mvp:** add asynchronous ghost riders from prior local ride logs.
10. **Server owner later:** design authenticated leaderboard API with profile versioning and hardware-source flags.
11. **Server owner later:** design scheduled group rides after local ghosts and private leaderboards feel good.

## First PR Cut

Recommended first coding PR in `repos/concert-mvp`:

- Add pure terrain math module.
- Add tests for grade mapping, smoothing, category scoring, and accumulation.
- Add mode selector state for `terrain_erg`.
- Render read-only Terrain Mode metrics without changing existing trainer command behavior.

This PR should not depend on sidecar changes. It gives Claude room to review and implement sidecar protocol work in parallel.
