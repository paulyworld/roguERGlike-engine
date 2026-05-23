# Training Platform Export Research

**Research date:** 2026-05-23

## Summary

The best integration path is to make the sidecar produce a high-quality completed activity file first, with direct platform uploads layered on top.

Prioritize:

1. Completed activity export to `.fit`.
2. Manual upload flow for Strava and TrainingPeaks.
3. Direct Strava upload through OAuth + Uploads API.
4. TrainingPeaks direct upload after approved developer API access.
5. Optional later targets: Intervals.icu, Ride with GPS, Wahoo, Garmin.

## Strava

Strava is the most important direct integration target and has the clearest public upload API.

Key points from current docs:

- Strava accepts completed activity files through `POST https://www.strava.com/api/v3/uploads`.
- Upload requires OAuth scope `activity:write`.
- Supported upload file types include `fit`, `fit.gz`, `tcx`, `tcx.gz`, `gpx`, and `gpx.gz`.
- Upload is asynchronous. The app should poll `GET /api/v3/uploads/:id` no more than once per second until Strava returns the activity ID or an error.
- Indoor rides should use `sport_type=VirtualRide` or `Ride` and `trainer=1`.
- A stable `external_id` should be supplied to avoid accidental duplicate uploads.
- Strava manual upload also accepts `.fit`, `.tcx`, and `.gpx` files, with per-file size limits documented by Strava Support.

Sources:

- https://developers.strava.com/docs/uploads/
- https://developers.strava.com/docs/reference/
- https://developers.strava.com/docs/rate-limits/
- https://support.strava.com/hc/en-us/articles/216918007-Bulk-Uploading-Activities-to-Strava

## TrainingPeaks

TrainingPeaks is important, but direct API access is gated.

Key points from current docs:

- TrainingPeaks says compatible completed workout file types can be manually uploaded, including `.fit`, `.tcx`, and `.pwx`.
- Manual upload can be done by opening a planned workout and uploading the file, or by dragging the completed workout file onto the calendar.
- TrainingPeaks API can upload completed workout files to an athlete calendar, but API access is currently for approved developers only and is not available for personal use.
- TrainingPeaks structured workout export is a separate concept from completed activity upload. Structured planned workouts may export as `.ERG`, `.MRC`, `.FIT`, or `.ZWO`, depending on workout type.

Sources:

- https://help.trainingpeaks.com/hc/en-us/articles/234441128-TrainingPeaks-API
- https://help.trainingpeaks.com/hc/en-us/articles/204070114-What-devices-are-compatible-with-TrainingPeaks
- https://help.trainingpeaks.com/hc/en-us/articles/204072994-How-do-I-manually-upload-a-workout-file-into-TrainingPeaks
- https://help.trainingpeaks.com/hc/en-us/articles/115000325647-Structured-Workout-sync-and-Manual-Export

## Other Platforms

Intervals.icu is attractive because it has an open API and supports activity uploads/downloads in FIT, TCX, GPX, ZIP, and GZ formats. It should be the first "secondary" direct upload integration after Strava.

Ride with GPS supports manual import of GPX, TCX, KML, KMZ, and FIT files and can ingest files by email from the account email address.

Wahoo supports FIT file import into the Wahoo app and has a cloud API with workout file upload endpoints, but product usefulness is lower than Strava/TrainingPeaks for the current roadmap.

Garmin Connect developer access is available to approved business developers. It is more relevant for pushing planned workouts/courses or accessing Garmin-originated activity data than for early roguERGlike export.

Sources:

- https://www.intervals.icu/features/open-api/
- https://support.ridewithgps.com/hc/en-us/articles/4419024044827-Upload-Activities-Routes-GPS-Files
- https://support.wahoofitness.com/hc/en-us/articles/18790709768850-Add-or-Edit-an-Activity-manual-text-entry-or-import-FIT-file-Wahoo-App
- https://cloud-api.wahooligan.com/
- https://developer.garmin.com/gc-developer-program/activity-api/

## Implementation Ownership

Current split:

- **Claude / sidecar:** recording model, FIT/TCX export, Strava OAuth/upload client, TrainingPeaks API spike/request package, exported-file validation tests.
- **Codex / concert-mvp:** export/download buttons, upload status UI, account-connection UI, post-ride summary and retry surface.
- **Codex / engine:** only add generic export/upload bridge methods if Godot becomes an active client again.

## Recommended Path

1. **Claude:** Add sidecar export from JSONL ride logs to completed `.fit`.
2. **Claude:** Validate generated FIT uploads manually to Strava and TrainingPeaks before building direct upload.
3. **Claude:** Add Strava OAuth token storage and direct upload command/service in sidecar.
4. **Codex:** Add concert-mvp post-ride "Export FIT" and "Upload to Strava" UI that delegates to sidecar.
5. **Claude:** Add TCX as a fallback export only if FIT compatibility problems appear.
6. **Claude:** Apply for TrainingPeaks API access; keep manual FIT upload as the supported v1 TrainingPeaks path until approved.
7. **Claude or Codex:** Add Intervals.icu upload after Strava, depending on whether the work is sidecar-only API plumbing or concert UI polish.

