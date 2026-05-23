# Concert Product Roadmap and Ownership

**Decision date:** 2026-05-23
**Audience:** Codex, Claude, and future roguERGlike sessions

## Current Product Direction

`repos/concert-mvp` is the near-term product surface and is now codenamed **gizzERG**. It currently feels like the better riding experience and should get the next usability work.

`repos/sidecar` remains the trainer runtime and safety boundary. It owns BLE, trainer control, cadence bailout, ride logging, protocol versioning, semantic annotations, and Pattern B structured pause.

`repos/engine` remains useful as a future Godot client and reusable effort bridge, but the Godot deck-builder MVP is not the current product focus.

Additional planning notes:

- `docs/claude-sidecar-review-brief.md` is the sidecar implementation packet for Claude review before coding.
- `docs/concert-mode-exploration.md` covers Terrain Mode, shifting, local results, leaderboards, and group rides.
- `docs/training-platform-export-research.md` covers FIT export, Strava upload, TrainingPeaks constraints, and other training platforms.
- Umbrella `INSTRUCTIONS.md` is canonical for workflow: branch from `develop`, PR to `develop`, conventional commits, signed commits on public repos, update `HANDOFF.md`, and write a session log before ending a session.

## gizzERG App Stack Direction

For the future polished concert app, prefer:

```text
SvelteKit + TypeScript + Vite + authored CSS/CSS modules
```

Do not default to React or Tailwind for gizzERG. The product should have a beautiful artistic UI, and prior LLM-assisted React/Tailwind work has created implementation churn and hard-to-review styling. Svelte keeps component markup, logic, and style close together, while authored CSS supports a more distinctive concert/ride visual language.

Recommended app structure:

```text
src/lib/protocol/     sidecar WebSocket client + typed events
src/lib/workout/      profile normalization, ERG target math
src/lib/terrain/      grade, speed, elevation, climb categories
src/lib/ride-log/     local results, annotations, ghost data
src/routes/           Svelte screens
src/styles/           design tokens, global CSS, animation primitives
```

Use shared design tokens for color, spacing, type, depth, and motion. Keep workout/profile/terrain/protocol logic in pure TypeScript modules so it remains testable outside the UI.

## Answers to Current Architecture Choices

### 1. Protocol versioning

This belongs primarily in `repos/sidecar`. Claude should implement it there because the sidecar is the protocol authority.

Recommended shape:

- Add a startup/connection envelope such as `hello` or `server_status`.
- Include `protocol_version`, `sidecar_version`, feature flags, and active mode.
- Clients check this before enabling trainer-control UI.
- Unknown newer major versions should produce a visible warning.

Example envelope:

```json
{
  "type": "hello",
  "data": {
    "protocol_version": "0.2.0",
    "sidecar_version": "0.4.0",
    "features": ["set_target_power", "recording", "annotations", "structured_pause"],
    "mode": "mock"
  }
}
```

The concert app should consume this, but not define it.

### 2. Trainer control boundary

Keep trainer control out of browser UI code. Browser clients compute intent: target watts, pause intent, annotation payloads. Sidecar owns device I/O, safety behavior, command acks, recording, and future pairing.

### 3. Workout logic vs UI

gizzERG should keep moving pure workout logic out of DOM-heavy `app.js`:

- target generation;
- profile normalization;
- workout mode generation;
- TSS/compliance math;
- protocol client wrapper;
- ride sample/annotation model.

SvelteKit + TypeScript + authored CSS/CSS modules is the recommended next frontend infrastructure step once the current logging/annotation loop is validated. A smaller TypeScript + Vite migration is still acceptable as an intermediate step, but the intended app direction is SvelteKit rather than React/Tailwind.

### 4. What "profiles" mean

A profile is the structured data that tells the app how media maps to a ride.

Today this is `src/concert-profile.js`. For a shippable product, profiles should become versioned data files rather than hard-coded app source.

A profile should eventually contain:

- media identity: YouTube id, local media id, URL, or library id;
- timing metadata: duration, intro offset, track boundaries;
- music metadata: song titles, sources, BPM estimates;
- ride cues: target intensity, cadence guidance, labels, ramp behavior;
- workout overlays: endurance/tempo/threshold mode rules or generated cue hints;
- provenance: who authored it, what source was used, confidence/quality notes;
- schema version.

This keeps the door open for a media library: YouTube concerts now, local videos later, audio-only rides, generated animations, or custom first-party video synced to user audio.

### 5. Media abstraction

Do not overfit the model to YouTube. The current app can keep using the YouTube IFrame API, but core workout logic should depend on a playback clock abstraction:

```text
PlaybackClock
  currentTime()
  duration()
  play()
  pause()
  seek(time_s)
  state: playing | paused | ended | buffering
```

Future implementations could wrap YouTube, local video, local audio, or generated visual scenes.

### 6. F2 semantic feedback and ride logging

The latest sidecar handoff says `--record` has landed on `feat/record-flag` and semantic annotations are planned next. That direction is right.

Ownership:

- **Sidecar / Claude:** implement `annotate` command and `rider_annotation` envelope, recorded into the same JSONL stream as telemetry.
- **Concert MVP:** add F2 hotkey UX first. It should send an annotation with current playback time, target watts, current power/cadence/HR, current song/section, workout mode, and free-form/default reason.
- **Engine:** later add a generic `EffortBridge.annotate_ride(...)` wrapper if the Godot client becomes active again.

Recommended annotation examples:

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
    "mode": "raw_feel"
  }
}
```

Do not make this only a bug-report feature. It should also capture semantic rider feedback such as:

- `felt_too_hard`
- `felt_too_easy`
- `cadence_bad_match`
- `music_sync_bad`
- `ui_confusing`
- `trainer_lag`
- `bug_here`

This gives post-ride review enough context to correlate subjective rider behavior with telemetry and trainer commands.

### 7. Python sidecar packaging

Do not refactor away from Python yet.

Python is a reasonable sidecar language right now because the code works, Bleak is available, tests are passing, and the main risk is product packaging rather than runtime capability.

Packaging work should enter the dev pipeline now:

- build a standalone sidecar executable for Windows;
- pin and lock dependencies;
- test BLE behavior from the packaged executable, not only `python -m`;
- decide PyInstaller vs Nuitka vs another packager;
- add app-managed launch/health-check/restart;
- handle firewall prompts and localhost binding clearly;
- plan code signing before broader beta;
- keep JSONL logs easy to find for support.

Consider Rust/Go/C# later only if Python packaging, startup reliability, BLE behavior, or distribution friction becomes the bottleneck. A rewrite now would slow down learning while the product shape is still changing.

### 8. Mobile

Mobile/tablet remains strategically plausible, but not v1. The right near-term path is a desktop app that can bundle/manage the sidecar reliably. Keep the media/profile/playback abstractions clean so a mobile client can reuse the concepts later.

## Revised Practical Recommendation

The immediate sequence should be:

0. **Codex / engine docs:** merge this planning README/docs PR, including the README repositioning and gizzERG stack decision.
1. **Codex + Claude:** reconcile annotation schema with Claude's PR #12 counter-proposal before coding F2 against sidecar PR #22. Current preferred direction to review: `{tag, note?, client_id?, client_time_s?, context?}`; avoid including raw input labels such as `"F2"` in the sidecar contract.
2. **Claude / sidecar:** finish or merge sidecar `--record` branch if not merged.
3. **Claude / sidecar:** add protocol version / feature negotiation.
4. **Claude / sidecar:** add semantic annotations and record them to JSONL after schema agreement.
5. **Codex / gizzERG (`concert-mvp`):** add F2 annotation UX once sidecar annotation schema lands.
6. **Codex / gizzERG (`concert-mvp`):** prototype ERG Terrain Mode as client-only terrain math and UI, including a dev/test tuning popout with sliders for video/audio-to-terrain parameters.
7. **Codex + Claude:** use real ride logs + F2 annotations to tune workout/profile/terrain behavior.
8. **Claude / sidecar:** implement Pattern B structured pause as core infrastructure.
9. **Codex / gizzERG (`concert-mvp`):** add optional concert support for Pattern B where pauses are structured, not ordinary YouTube play/pause.
10. **Claude / sidecar:** add FIT export groundwork for Strava/TrainingPeaks manual upload, then Strava direct upload.
11. **Codex / gizzERG (`concert-mvp`):** add post-ride export/upload UI once sidecar export exists.
12. **Codex / gizzERG (`concert-mvp`):** start SvelteKit + TypeScript + authored CSS migration once the protocol/logging loop is stable.
13. **Codex + Claude:** begin Windows desktop packaging spike with bundled sidecar.

## Ownership Map

| Work | Primary repo | Primary owner in future sessions | Notes |
|---|---|---|---|
| Protocol version / feature negotiation | `sidecar` | Claude | Sidecar defines protocol truth; clients consume. |
| `--record` first-class CLI | `sidecar` | Claude | Already on `feat/record-flag` per handoff. |
| `annotate` command + `rider_annotation` envelope | `sidecar` | Claude | Must persist into JSONL ride logs. |
| F2 annotation UX | `concert-mvp` | Codex or Claude | Send annotation with video/workout/telemetry context. |
| gizzERG app shell | `concert-mvp` | Codex | Prefer SvelteKit + TypeScript + authored CSS/CSS modules; avoid default React/Tailwind. |
| Profile schema design | `concert-mvp` first, later shared docs | Codex or Claude | Move from source-coded profile toward versioned data files. |
| Pattern B structured pause | `sidecar` | Claude | Core riding infrastructure, not engine-MVP-specific. |
| Pattern B client wrappers | `concert-mvp`, `engine` | Codex or Claude | Concert only for structured pauses; engine generic wrapper later. |
| Terrain Mode ERG prototype | `concert-mvp` | Codex | Client-only first; do not wait for SIM mode. |
| Distance derivation | `sidecar` | Claude | Supports exports and later terrain validation. |
| FIT export + Strava upload | `sidecar` | Claude | Strava first; TrainingPeaks direct API requires approval. |
| Export/upload UI | `concert-mvp` | Codex | Delegates to sidecar. |
| SIM mode FTMS writes | `sidecar` | Claude | Later, gated by `indoor_bike_simulation`. |
| Local results and ghosts | `concert-mvp` | Codex | Pre-server leaderboard foundation. |
| Public leaderboards/group rides | `server` later | TBD | Do after local results/ghosts prove useful. |
| SvelteKit + TypeScript migration | `concert-mvp` | Codex | Do after logging/annotation path is stable; use authored CSS/CSS modules. |
| Windows packaging spike | `concert-mvp` + `sidecar` | Codex or Claude | Evaluate bundled sidecar launch and packaged BLE behavior. |
| Godot deck-builder MVP | `engine-mvp` / `engine` | Deferred | Keep as validated side experiment. |

## Next Session Entry Point

> "Product direction: focus on gizzERG (`repos/concert-mvp`). Future app shell should be SvelteKit + TypeScript + authored CSS/CSS modules, not default React/Tailwind. First merge the planning docs/README PR. Then reconcile annotation schema with Claude PR #12's hybrid proposal `{tag, note?, client_id?, client_time_s?, context?}` before F2 work. Terrain Mode should start client-only and include a dev/test tuning popout with sliders for audio/video-to-terrain mapping. Pattern B remains core sidecar infrastructure after/alongside annotations. Do not promote the Godot MVP or rewrite Python sidecar yet."
