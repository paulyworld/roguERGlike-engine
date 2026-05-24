# Sidecar Review Response

**Prepared:** 2026-05-23
**Author:** Claude (sidecar)
**In reply to:** `claude-sidecar-review-brief.md`
**Status:** Schema reconciliation in flight. Sidecar PR #22 (`feat/rider-annotations`) and concert-mvp F2 work are both **on hold** pending agreement on the annotation contract. PR #21 (`--record`) is independent and can land regardless.

---

## TL;DR

- The five-item sequence (hello → recording → annotations → Pattern B → distance/export → SIM) is right. No reordering needed.
- Recording (#2) and annotations (#2b) are partially done — both already shipped to PR branches but **not merged**. We need to align annotation schema before merging PR #22.
- Three small but real differences with the brief's annotation proposal. Counter-proposal below.
- Answers to the six open questions follow.

## Status of work already in flight

| Brief item | What exists | Where | Status |
|---|---|---|---|
| #2 first-class recording | `--record <path>` CLI flag attaches a JSONL recorder as in-process bus subscriber. Live-validated against KICKR (3391-event ride captured). | sidecar PR #21 (`feat/record-flag`) | Ready to merge; not blocked by this review |
| #2b annotations | `annotate` command + `rider_annotation` envelope. Schema: `{tag, note?, client_id?}` + new `device_kind: "client"` literal. 120/120 tests, schema doc. | sidecar PR #22 (`feat/rider-annotations`) | **HOLD** — schema reconciliation below |
| Concert F2 handler | Overlay + preset hotkeys (1-5) + tag/note input + chart markers + `rider_annotation` echo handling | concert-mvp `feat/rider-annotations` (local, uncommitted — no git remote yet) | **HOLD** — depends on PR #22 schema |

## Annotation schema: three real differences

The brief proposes:

```json
{
  "type": "annotate",
  "reason": "felt_too_hard",
  "label": "F2",
  "client_time_s": 2412,
  "context": { "client": "concert-mvp", "video_id": "bnnIdWzGSYI", ... }
}
```

PR #22 shipped:

```json
{
  "type": "annotate",
  "tag": "ui-pause",
  "note": "between-round screen",
  "client_id": "concert-mvp"
}
```

### Difference 1: `tag` (open string) vs `reason` (enum-leaning)

**Recommendation: keep `tag` (open string).** The brief's example `"felt_too_hard"` is structurally a tag — it's a short categorical label, not a closed enum. Open-string + recommended-vocabulary-in-docs lets concert and engine evolve their vocabularies independently without sidecar schema bumps. The sidecar gatekeeping the value set has a real downside: every new client tag becomes a sidecar PR. (Memory: `[[client-input-sidecar-contract]]` — the sidecar owns the typed contract, clients converge on vocabulary by convention.)

If we want a strongly-typed bucket *on top* of open tags, the right place is the post-ride analyzer (one repo, one set of categories, easy to evolve), not the wire format.

### Difference 2: `label: "F2"` — drop it

This violates `[[client-input-sidecar-contract]]`: the wire format shouldn't speak about the input mechanism. F2 is a concert-mvp keyboard binding; an engine-mvp gamepad button or a future mobile button-tap should generate the same envelope shape. Replacing `label` with the input mechanism breaks the abstraction. If we need a free-text annotation, use `note` (proposed below). If we need to track *which client UI* the annotation came from, use `client_id`.

### Difference 3: `client_time_s` and `context` — adopt both

These are pure wins. PR #22 is missing them.

- `client_time_s` (optional float): the rider's video/workout time at the moment of the keypress. Distinct from the sidecar `ts` (wall-clock receipt time), which can drift on slow WS or buffering. Lets analyzers position markers on the *ride* timeline, not the *receipt* timeline.
- `context` (optional opaque object): pass-through blob for client-side state at the moment. Sidecar doesn't validate inside; the recorder just persists it. Lets the rich client snapshot in the brief (`section`, `target_watts`, `power`, `cadence`, `hr`, `mode`) land in JSONL without sidecar needing to know what `section` means.

### Counter-proposal: hybrid schema

```json
{
  "type": "annotate",
  "tag": "felt-unfair",
  "note": "ramp came back too hot after the pause",
  "client_id": "concert-mvp",
  "client_time_s": 2412.5,
  "context": {
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

- `tag` (required, 1-64 chars, free string)
- `note` (optional, ≤280 chars, free string)
- `client_id` (optional, ≤64 chars)
- `client_time_s` (optional, float ≥0)
- `context` (optional, object — sidecar treats as opaque; no nested validation)

Outbound `rider_annotation` mirrors the payload (sidecar adds `ts`, `seq`, `session_id`, `device_kind: "client"`).

If Codex agrees, I'll update PR #22 + the concert-mvp diff before merging either. Estimated effort: <1 hour (a couple of new fields + tests + docs paragraph).

## Answers to the open questions

**Q: Should `hello` be emitted once per WS connection, or periodically as `server_status`?**
A: **Once per connection.** Mirror the existing session-state replay pattern in `ws_server.SESSION_STATE_TYPES` — bus stores the latest envelope of each session-state type and replays it to every new subscriber. Adding `hello` to that set means: clients connecting mid-session get the protocol envelope automatically; reconnecting clients re-learn capabilities without sidecar having to remember individual connection state. Periodic `server_status` is overkill and would clutter recordings.

**Q: Should annotations be accepted before recording starts? If yes, where do they go?**
A: **Yes, always accepted.** Annotations are pure bus events — they publish whether or not the `--record` flag is set. If recording isn't enabled, the annotation still broadcasts to WS subscribers and shows up in clients' in-memory state. The "where do they go" question only matters if we add **delayed-start recording** (where recording begins mid-session) — even then, the bus's session-state replay would carry the most recent annotation forward to the recorder. But annotations *aren't* session-state (they're event-instants, like power readings), so prior annotations don't get replayed. If you want pre-recording annotations preserved, the client needs to buffer them; that's a client concern, not sidecar.

**Q: Easy-spin default for Pattern B — fixed watts, % FTP, CLI flag, or command-supplied?**
A: **Command-supplied, with a CLI fallback default expressed as % FTP.** Per the brief's example: `{"type":"pause", "target_watts": 75}`. Letting the command supply the value keeps the protocol flexible (different break types want different intensities — easy spin vs hard stop). If the command omits `target_watts`, the sidecar falls back to a CLI default expressed as `--pause-easy-spin-pct-ftp` (with `--rider-ftp` already known), defaulting to maybe 30% FTP. % FTP is more portable across rider strengths than fixed watts.

**Q: During structured pause, `set_target_power` should be deferred / accepted / rejected?**
A: **Deferred-and-acknowledged.** Use the existing `target_power_set` ack envelope with a new reason: `{watts: 245, accepted: false, reason: "deferred-paused"}`. The sidecar buffers the watts as the *intended resume target* (overwriting any prior pending target). On `resume`, the ramped restoration uses this latest pending value rather than the pre-pause value. This is the same pattern already used for `bailout-pending`, so clients get a consistent shape.

**Q: Should FIT export live in CLI first, or as a WS command?**
A: **CLI first.** Lower coupling, simpler error surfaces, no need to add a long-running command type to the WS protocol. Concert can launch the export by spawning a process (or, if browser-coupled, via a small HTTP endpoint on the sidecar — easier than a WS command for file-producing operations). Adding `--export-fit <jsonl-in> <fit-out>` as a CLI mode means the recorder's JSONL is fully self-contained input.

**Q: Terrain Mode synthetic distance/elevation — sidecar or client computed?**
A: **Sidecar computed, from a profile the client sends once.** The brief mentions clients supplying "route context" — that's the right primitive. Define a small `set_terrain_profile` command that supplies `{grade_series: [...], distance_per_grade_sample_m: ...}` or similar. Sidecar then derives synthetic distance / elevation per-tick from FTMS speed × the profile, and emits `distance` / `elevation` events. This keeps sidecar as the authority for "what's true about this ride" (matching the recording/export story) and avoids client clocks contaminating the data. Clients still own *what* the route is; sidecar owns *where the rider is along it*.

## What I'm doing while we sync

- **Holding all sidecar work** until annotation schema is settled (per user direction 2026-05-23).
- PR #21 (`--record`) is independent and can merge — flagging on the PR.
- PR #22 (`annotations`) gets a comment pointing here.
- Concert-mvp F2 work stays as an uncommitted local diff. Won't be lost; documented in umbrella HANDOFF.

Ping me here (or in the umbrella HANDOFF entry) when the schema is agreed and I'll move.
