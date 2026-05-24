# Music Intensity & Profile Authoring — Beyond BPM

**Prepared:** 2026-05-23
**Audience:** Codex working in `repos/concert-mvp` (gizzERG) and on engine docs
**Status:** Proposal for discussion. No code commitment yet.

---

## Why this matters now

Two things came together this session:

1. The F2 annotation primitive shipped (sidecar PR #22 + gizzERG PR #1), so we can collect rider feedback at moment precision.
2. The `concert-mode-exploration.md` doc explicitly calls out the failure mode: *"A mellow section that ends in a crescendo can trigger a sustained intensity section too early. The right training response might be to wait until the next intense song or song part starts."*

The user wants to scrub through the video and mark exact song-time changes, lulls between songs, and places where the model misreads the vibe. Their question was: should they do that in a separate Excel doc, or via F2?

Strong answer: **neither, and both.** F2 is right for ride-time feel. A separate Excel is strictly worse than what we have. But scrubbing-based authoring is a *different job* than ride-time feedback and wants its own UX. And the underlying intensity model needs more than BPM regardless of what UX surfaces it.

This proposal sketches three pieces that together address the root cause and the workflow.

## Piece 1 — Audio features beyond BPM (signal side)

BPM is one number. Perceived intensity is many. The doc's crescendo problem is the canonical example: BPM is high, riff is dense, but it's a 5-second tail-end-of-section build that resolves into recovery. Treating that as a sustained block is exactly the model bug riders are flagging.

The accepted way out (used by every audio-driven rhythm/exercise app that doesn't feel dumb) is to combine 4-5 features instead of weighting BPM alone:

| Feature | What it captures | Why it helps here |
|---|---|---|
| **RMS / loudness envelope** | Actual amplitude over time | A breakdown at 130 BPM with reduced energy reads as low RMS even though BPM is unchanged. Closest single proxy for "how big does this feel?" |
| **Spectral centroid** | Where energy sits in the spectrum (bright vs dark) | Lead guitar + cymbals = high. Bass-only jam = low. Captures brightness/aggression independent of tempo. |
| **Spectral flux / onset density** | How much the spectrum is changing; attacks per second | Distinguishes "fast tempo, only the kick is hitting" from "fast tempo, everything is going off." |
| **HPSS ratio** (harmonic vs percussive) | Fraction of energy that's rhythmic vs melodic | Sustained-organ jam = harmonic-dominated, "interlude" feel. Drum-heavy chorus = percussive-dominated. |
| **Section novelty / boundary detection** | Automatic "the song changes here" markers (librosa's laplacian segmentation, `msaf` library) | Cuts manual section-marking burden way down. Model proposes boundaries; rider confirms / corrects. |

Combined intensity model (first cut, to be tuned via F2 feedback):

```
intensity_t = w1·loudness_t  +  w2·spectral_centroid_t  +  w3·onset_density_t  +  w4·(1 − harmonic_ratio_t)
```

Tune `w1..w4` from accumulated `too-hard` / `too-easy` / `false-intensity` / `missed-intensity` annotations.

### Crescendo fix specifically

Two targeted changes that resolve the doc's example without overfitting:

- **Rolling-window confirmation.** Don't promote a high-intensity classification until the elevated signal has held for N seconds *or* an independent boundary detector confirms a new section starts. A 5-second tail-end crescendo doesn't satisfy either gate, so it doesn't extend into the next section.
- **First-class crescendo / drop / sprint cue events.** These are *not* derivatives of intensity — they're discrete musical events with their own UX. A drop = brief sprint window. A crescendo = a *build-up that resolves into* whatever the next section says, never sustained on its own. Authored as profile metadata, not synthesized from a curve.

## Piece 2 — Scrub-mode profile editor (authoring UX)

Mid-ride F2 and out-of-ride profile editing are different jobs:

| Workflow | Where the rider is | Constraint | Output |
|---|---|---|---|
| Mid-ride F2 (shipped) | On the bike, pedaling | Body is busy; one keystroke max | Ride annotation in JSONL |
| Profile authoring (new) | At a desk, scrubbing the video | No ergonomics constraint; can think and type | Edits to the profile JSON itself |

The latter wants something like YouTube's chapter editor or Frame.io's marker panel:

- Scrub through the YouTube player (already in the app)
- Drop typed markers at the current playhead: `song-boundary`, `lull`, `crescendo`, `drop`, `false-intensity`, `missed-intensity`, custom labels
- Inline notes per marker (longer than the 280-char F2 note cap — these are authoring decisions, not pedaling shorthand)
- Optional: override the auto-derived intensity for a window (e.g. "this 8-second block should be classified as recovery, not climb")
- Save back to the profile JSON; bump `profile_version`

**Why this stays separate from ride annotations:**

- Profile edits are decisions about *the music*. True for every future ride.
- Ride annotations are about *this ride, this moment, my body's feel*. Specific to a ride instance.
- Mixing them makes the profile non-reproducible and breaks leaderboard fairness (per the `profile_version` constraint already established in `concert-mode-exploration.md`).

A rider can still F2 *during a ride* to flag "the model is wrong here" — those flow into JSONL and become training feedback to the curve. The profile editor is where they go *afterward* to author the fix.

## Piece 3 — Preprocessing pipeline (tooling architecture)

The audio-feature analysis above wants Python (librosa, essentia, madmom). Web Audio + AudioWorklet would be a much heavier lift and a worse result.

Proposed layout:

```
repos/concert-mvp/                          (gizzERG)
├── src/                                    ← browser app (existing)
├── profiles/                               ← profile JSONs
├── tools/
│   └── profile-builder/                    ← NEW
│       ├── build_profile.py                ← yt-dlp → librosa → curve → profile JSON
│       ├── pyproject.toml
│       └── README.md
└── ...
```

`build_profile.py` workflow:

1. Take a YouTube URL (or local audio file).
2. Download / extract audio with `yt-dlp`.
3. Run librosa: RMS, spectral centroid, spectral flux, onset detection, HPSS, boundary candidates.
4. Sample the derived signal at a fixed rate (say 1 Hz to match the ride sampling rate).
5. Write back into the profile JSON as `derived_intensity_curve`, `audio_features`, `proposed_boundaries`.
6. Bump `profile_version`.

The browser app then consumes `profile.derived_intensity_curve` instead of computing from raw audio. Benefits:

- Reproducible — same audio in, same curve out
- `profile_version` becomes meaningful (different curve = different version = different leaderboard)
- Browser stays light
- Re-running the builder when the algorithm improves regenerates curves for every profile in one batch
- Trainer/optimizer can iterate on weights against the same dataset of features + F2 annotations

## Piece 4 — F2 schema additions (gizzERG-side, no protocol change)

The `context` blob is already opaque pass-through to the sidecar (per the hybrid schema agreed on engine PR #12). Two fields would make F2 annotations directly trainable against the derived curve:

- `context.estimated_intensity` (float 0–1) — what the model thinks the intensity is at the moment of the keypress. Lets a `too-hard` annotation say "you thought it was 0.7, my body says lower."
- `context.audio_features` (object) — the live-computed feature values at the moment: `{loudness, centroid, flux, harmonic_ratio}`. Lets the trainer see *which feature misled the model*.

No sidecar schema change needed — sidecar already treats `context` opaque. Recommended-shape doc in `event-schema.md` can be updated by Claude in passing when the audio pipeline ships, or by Codex directly via the gizzERG repo (the recommended shape is convention, not contract).

## Ownership and sequencing

Per the ownership split in `claude-sidecar-review-brief.md`:

- **Codex / gizzERG:**
  - Piece 1: implement the combined intensity model (`tools/profile-builder/`)
  - Piece 2: scrub-mode profile editor UI
  - Piece 3: the preprocessing tool itself
  - Piece 4: live audio-feature computation in the browser at F2-keypress time, populating `context.estimated_intensity` + `context.audio_features`
- **Claude / sidecar:** no protocol work required for this — the hybrid `context` blob already accommodates the additions. Recommended-shape doc update on the next sidecar pass.

**Suggested sequencing:**

1. **First**: Piece 3 (build_profile.py minimum viable). Just RMS + centroid + onset density combined into a curve, written into the profile JSON. Cheap to build; immediately replaces BPM-only.
2. **Second**: Piece 2 (scrub-mode editor). Reads the curve in alongside the YouTube player so authoring decisions are visible against the model's reading.
3. **Third**: Piece 1 weight-tuning loop. By this point you have curves + F2 annotations from real rides; the optimizer becomes a small offline script that adjusts `w1..w4` to minimize annotation-disagreement.
4. **Fourth**: Piece 4 live-feature populating of F2 context — enables more targeted training signal.

Crescendo handling (rolling-window confirmation + first-class events) lands inside Piece 1 — it's a property of the intensity model, not a separate piece.

## Open questions for Codex

- **Audio source for the preprocessor**: yt-dlp gets you the YouTube audio cleanly, but you've also been working from Bandcamp tracklist metadata. Would the builder ever want to ingest the source studio audio (Bandcamp downloads) and the YouTube-rendered audio separately and reconcile? Reconciliation matters because video intro offsets shift everything.
- **Where the boundary detector fits with manual marker authoring**: do we let the auto-detected boundaries seed the editor (rider confirms / corrects) or only kick in when no manual markers exist?
- **Live feature computation in the browser (Piece 4)**: is this worth the Web Audio integration cost, or do we keep features as a property of the profile and not the moment? If the latter, F2's `context.audio_features` is just "look up the feature at `client_time_s` in the profile curve" — much simpler.
- **Crescendo / drop / sprint as first-class profile events**: should these be a new array (`profile.events`) alongside the existing `cues`, or extension of the cue type? The doc's hint about "crescendo doesn't sustain" suggests they need different treatment than ordinary cues.
- **Profile-version bump policy**: when the preprocessor algorithm changes (different weights, different feature set), do we auto-bump every profile's version on re-run, or version the algorithm and let profiles point at an algorithm version?

## Non-goals

- Not proposing to retire BPM. BPM stays as one of the inputs — it's just no longer the only input. Specifically it's still useful for the cadence guidance (target cadence often half-times BPM), which is independent of the intensity model.
- Not proposing a new sidecar protocol. The hybrid annotation schema already accommodates everything here.
- Not proposing a real-time DAW-style editor. The scrub-mode editor is a YouTube player + marker panel, not Ableton.
- Not proposing to displace authored manual overrides. The profile's authored intensity stays the canonical training signal where present; derived features fill in / refine where the rider hasn't authored.

## Summary

| Today | Proposal |
|---|---|
| BPM-only intensity | 4-5 feature combined intensity, tuned by F2 feedback |
| Manual section boundaries only | Boundary detector proposes, rider confirms |
| F2 is the only feedback surface | F2 (mid-ride) + scrub editor (out-of-ride) |
| Profile JSON has authored cues | Profile JSON also has derived curve + auto-boundaries + first-class events |
| Excel doc would lose context, time alignment, joinability | Stays in-app; everything joins the JSONL recordings via `client_time_s` |

Ping when you've read; happy to discuss sequencing, audio-feature choices, or scope.
