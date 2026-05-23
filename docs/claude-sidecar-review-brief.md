# Claude Sidecar Review Brief

**Prepared:** 2026-05-23
**Audience:** Claude working in `repos/sidecar`
**Purpose:** Review scope and sequencing before coding the next sidecar changes that unblock Concert MVP product work.

## Current Split

- **Claude owns sidecar/protocol/runtime:** BLE, trainer control, cadence bailout, protocol schema, recording, FIT/TCX export, Strava upload, distance derivation, SIM mode, and future controller input.
- **Codex owns concert-mvp/client UX:** mode UI, F2 annotation UX, post-ride export/upload controls, Terrain Mode visualization, local results, UI-only shifting, and ghosts.
- **Server owner later:** public leaderboards, accounts, group ride rooms, ranking trust, and privacy controls.
- **Engine is deferred:** Godot bridge wrappers come after sidecar schema exists; do not promote the Godot MVP branch to solve Concert needs.

## Review Goal

Please review this packet and either:

1. confirm the implementation sequence is right, or
2. adjust the sequence based on sidecar code realities.

The near-term aim is to make Concert MVP learn faster from real rides while keeping trainer safety and protocol ownership in sidecar.

## Recommended Sequence

### 1. Protocol Hello / Feature Negotiation

Owner: **Claude / sidecar**

Add a startup or connection envelope, probably `hello` or `server_status`.

Candidate payload:

```json
{
  "type": "hello",
  "data": {
    "protocol_version": "0.2.0",
    "sidecar_version": "0.4.0",
    "features": [
      "set_target_power",
      "recording",
      "annotations",
      "structured_pause",
      "distance",
      "activity_export",
      "indoor_bike_simulation"
    ],
    "mode": "mock"
  }
}
```

Notes:

- Sidecar is the protocol authority; clients consume this.
- Feature flags should be stable strings.
- `indoor_bike_simulation` should only be advertised as active when the connected trainer capability and sidecar write path both exist. Until SIM writes are implemented, keep it as a discovered device capability only.
- Unknown newer major protocol versions should let clients show a visible warning.

Acceptance criteria:

- New WS subscribers receive the protocol/capability envelope.
- Tests cover serialization and client subscription behavior.
- Concert can decide whether to enable annotation/export/pause UI from this envelope.

### 2. First-Class Recording and Semantic Annotations

Owner: **Claude / sidecar**

Sidecar should own the durable ride log. Concert should send semantic context, not write files directly.

Commands/events:

```json
{
  "type": "annotate",
  "reason": "felt_too_hard",
  "label": "F2",
  "client_time_s": 2412,
  "context": {
    "client": "concert-mvp",
    "video_id": "bnnIdWzGSYI",
    "section": "Motor Spirit",
    "target_watts": 228,
    "power": 205,
    "cadence": 71,
    "hr": 154,
    "mode": "terrain_erg"
  }
}
```

Sidecar emits/records:

```json
{
  "type": "rider_annotation",
  "data": {
    "reason": "felt_too_hard",
    "label": "F2",
    "client_time_s": 2412,
    "context": {}
  }
}
```

Acceptance criteria:

- Annotation command validates with strict schema.
- Annotation events are broadcast to WS subscribers.
- Annotation events are written into the same JSONL stream as telemetry.
- Bad annotations are rejected/logged without interrupting the stream.

### 3. Pattern B Structured Pause

Owner: **Claude / sidecar**

Pattern B is a sidecar-managed structured pause for authored breaks, workout-clock suspend, and other code-driven pauses. It is not a replacement for Concert's ordinary YouTube play/pause Pattern A.

Candidate commands:

```json
{ "type": "pause", "reason": "structured_break", "target_watts": 75 }
{ "type": "resume" }
```

Candidate events:

```json
{
  "type": "paused",
  "data": {
    "reason": "structured_break",
    "target_watts": 75,
    "previous_target_watts": 210
  }
}
```

```json
{
  "type": "resumed",
  "data": {
    "restored_to_watts": 210,
    "ramped_over_s": 3.0
  }
}
```

Implementation notes:

- Live and mock mode should behave equivalently.
- While structured-paused, cadence bailout timing should be suspended.
- Easy-spin target should be distinct from the bailout floor.
- Resume should restore the pre-pause or latest pending target, whichever policy Claude confirms is safest and clearest.
- Repeated pause/resume commands should be idempotent or return typed rejections.

Acceptance criteria:

- Unit tests prove cadence bailout does not engage during structured pause.
- Unit tests prove resume restores target/ramp behavior.
- Mock mode can demonstrate pause/resume without hardware.
- Existing `set_target_power`, `stop`, and `release_control` semantics remain intact.

### 4. Distance and Activity Export Groundwork

Owner: **Claude / sidecar**

This work supports Strava/TrainingPeaks export and later Terrain Mode.

Scope:

- Finish distance derivation from FTMS where available.
- Add virtual distance/elevation fields for synthetic Terrain Mode when the client supplies route context.
- Export completed ride logs to `.fit` first.
- Add `.tcx` only as a fallback if FIT compatibility problems appear.

Export platform facts:

- Strava direct upload is public API: `POST /api/v3/uploads`, OAuth `activity:write`, async polling.
- TrainingPeaks direct API requires approved developer access; support manual FIT upload first.
- Mark indoor rides as virtual/trainer activities where the target platform supports it.

Acceptance criteria:

- A completed JSONL ride can produce a valid FIT activity file.
- Manual FIT upload works in Strava.
- Manual FIT upload works in TrainingPeaks or the incompatibility is documented with a concrete error.
- Export includes enough metadata to distinguish real/synthetic distance and hardware source.

### 5. Terrain/SIM Mode Protocol

Owner: **Claude / sidecar**

This comes after ERG Terrain is prototyped in Concert and after distance/export basics are stable.

Scope:

- Add explicit sidecar support for FTMS Set Indoor Bike Simulation Parameters.
- Gate it behind both sidecar feature support and connected device capability.
- Accept grade, wind speed, rolling resistance, and wind resistance coefficient.
- Define command/event names before coding.

Potential command:

```json
{
  "type": "set_simulation",
  "grade_percent": 6.5,
  "wind_speed_mps": 0.0,
  "rolling_resistance": 0.004,
  "wind_resistance": 0.51
}
```

Acceptance criteria:

- Unsupported trainers produce typed rejection.
- Mock mode logs/broadcasts accepted simulation params.
- Live mode writes FTMS simulation params on compatible hardware.
- Concert can choose ERG Terrain or SIM Terrain from feature/capability state.

## Open Questions for Claude

- Should protocol `hello` be emitted once per WS connection, or also periodically as `server_status`?
- Should annotations be accepted before recording starts, and if yes, where do they go?
- What exact easy-spin default should Pattern B use: fixed watts, percent FTP, CLI flag, or command-supplied target?
- During structured pause, should `set_target_power` update the pending resume target, be accepted-but-deferred, or be rejected with a typed reason?
- Should FIT export live in the sidecar CLI first, or as a WS command that Concert can call immediately?
- Should Terrain Mode synthetic distance/elevation be computed in Concert and sent as annotations/context, or computed in sidecar from profile samples?

## Non-Goals

- Do not promote `feat/mvp-playable-loop`.
- Do not force Concert's YouTube play/pause onto Pattern B.
- Do not weaken cadence bailout timing to solve client UX.
- Do not build public leaderboards or group rides in sidecar.
- Do not rewrite the sidecar out of Python for these changes.

