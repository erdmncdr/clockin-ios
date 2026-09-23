# iOS 0.2 (13): persisted timer state

Investigation trigger: a tester reports the work timer starts while the app is closed.
No device trace or exact reproduction is available for that report. This release
fixes a separately reproduced persistence defect; it is not proof of that tester's cause.

## Reproduced defect

When the timer file cannot be written, `clockOut()` previously removed the running
session in memory and returned a completed session despite `save()` failing. A
fresh ClockStore loaded the old running session from disk. Pause, resume, cancel
and start had the same failure to keep memory consistent with persisted data.

Timer mutations now restore the previous data when persistence fails. Failed clock
out returns nil, creates no phantom history entry, and preserves the existing timer.
A dedicated app alert explains the failure. App Intents check the resulting state
and return a failure dialog instead of claiming success.

No new server telemetry, background-start confirmation, timer timeout or automatic
session-ending behavior was introduced. Widget/Shortcut invocation is still a
possible separate cause of the original report and has not been established.

## Verification

The existing ClockStore backup test boundary was extended using an isolated,
read-only fixture directory. Before the fix it failed at "failed clock out must
not report a completed session". After the fix, all 38 checks pass, including
failed transitions, relaunch consistency, and successful stop after storage recovers.

The release snapshot uses the companion-art working tree plus owned changes:
`/tmp/clockin-stop-fix-13`. All 330 manifest hashes matched. Signed Release archive
passed, app and widget both identify as 0.2 (13), and strict deep codesign verification
passed. Physical-device alert presentation and the original tester's report remain
unverified.

## Distribution

Uploaded successfully on 2026-09-21 at 00:49 Europe/Istanbul. App Store Connect
build ID: `18100b66-c72b-462e-910c-65c49b3373df`. Processing completed and English
and Turkish test notes were saved. Submitted with automatic tester notification.
Verified 0.2 (13) as **Testing** in both Clockin Internal and Clockin Public Beta
on their respective App Store Connect group Builds pages on 2026-09-21.
Archive: `/tmp/clockin-stop-fix-13/Clockin.xcarchive`.
