# Clockin iOS 0.2 (9): Live Activity earnings

**Regression:** This release used the wrong iOS baseline. Build 8 came from the
`clockin-companion-art` working tree, including uncommitted approved UI changes.
Using main below reverted that UI. The corrective build is documented in
`ios-live-activity-build-10.md`; do not reuse this build's source as the iOS UI baseline.

Uploaded 20 September 2026 at 02:42 Istanbul time. Xcode reported upload and
export succeeded. App Store Connect subsequently showed `0.2 (9)` Testing,
independently verified in both Clockin Internal and Clockin Public Beta.

## Change

The app registers its per-activity push token with the existing Clockin
Netlify service. The server calculates and sends earnings updates once per
minute while the app is suspended. Delivery timing remains subject to APNs.
Pause, resume and calculation changes replace the activity so delayed pushes
cannot restore old state. Tokens and active calculation state expire after
at most eight hours.

The server temporarily receives the active session's rate, earnings, timer
anchor, conversion rate, theme and note. Work history is not uploaded. The
APNs signing key stays in the Netlify site's production environment.

## Source and validation

- Base: `c871b11aa067ceecc8856a3f83bc3e1dcfba08e1`.
- Isolated source: `/tmp/clockin-live-activity-release-0.2-9/source`.
- Overlaid only the Live Activity Info.plist, entitlements, activity attributes,
  SessionMirror and LiveActivityPush files; other uncommitted UI/art changes
  are excluded. File hashes are in the adjacent `source-manifest.json`.
- Signed archive: `/tmp/clockin-live-activity-release-0.2-9/Clockin.xcarchive`.
- App and widget version/build: `0.2 (9)`; signed archive succeeded.
- Release-testing export passed signature, production APNs, device profile,
  endpoint and frequent-update checks. Direct install was not performed.
- Eight backend tests passed. Production health is configured; synthetic
  registration reaches APNs and rejects the deliberately invalid device token.
- Netlify production deploy: `6aaf1ac04267645f19174cad`, minute schedule enabled.
  All 223 existing website file hashes were preserved.

## Phone check

After installing build 9, open Clockin, then start or resume a session. Leave
the app in the background for three minutes and inspect the expanded Live
Activity earnings. Pause and confirm earnings stops changing, then resume and
clock out. A small hourly rate may not change the compact whole-unit label
every minute. Actual device delivery has not yet been observed.

## Distribution

The user explicitly authorized uploading this build and opening the existing
TestFlight groups. Upload log:
`/tmp/clockin-live-activity-release-0.2-9/testflight-upload.log`.
No existing builds are to be expired or withdrawn.
App Store Connect processing build ID: `81ae4887-784c-4110-846f-964d6ec33af2`.
English and Turkish test notes were saved. Both existing groups were assigned,
and TestFlight beta review submission completed with automatic tester
notifications enabled. Both groups show Testing with 90 days remaining.
Public beta link: https://testflight.apple.com/join/tr6kSDMN .
On 20 September the real phone registered a production activity. The server's
minute scheduler ran, its cursor existed, and the inspected function logs had
no errors. The user subsequently confirmed 2–3 earnings updates without opening
the app, followed by a stall. An exact one-minute delivery cadence has not been
measured. See `ios-live-activity-delivery.md` for the follow-up investigation.
