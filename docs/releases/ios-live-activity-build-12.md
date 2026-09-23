# iOS 0.2 (12): Live Activity setup

The first foreground launch presents an optional three-step setup guide, including existing installations. It explains remote-update consent, checks the system Live Activities and More Frequent Updates settings, opens the app's public iOS Settings URL, and rechecks settings on return. Users can skip and reopen the guide under Settings → Privacy & Live Activity.

The connection panel distinguishes waiting for the activity token, registering, successful server registration, registration failure, and failure to start a Live Activity. A retry action refreshes the current session. Server registration does not establish device delivery; Apple still controls update timing.

Consent remains off by default and requires an explicit action. Registration payloads, expiration and financial-data minimization are unchanged. This release does not change the Netlify service.

## Source and validation

- Release snapshot: `/tmp/clockin-live-activity-release-0.2-12-final`.
- Prepared from the current `clockin-companion-art` working tree, with the owned Live Activity changes applied by `scripts/prepare-ios-live-activity-release.py`. Do not archive the older main UI directly.
- All 329 source-manifest hashes matched before upload.
- Initial simulator build passed. Final signed Release archive passed without reported compiler warnings or errors.
- App and widget both identify as 0.2 (12); strict deep code-signature verification passed outside the sandbox.
- Bundle contains 8 CAF sounds and no GLB/USDZ resources.
- All 13 manual Live Activity privacy checks passed against the final source snapshot.
- Native tutorial interaction and remote delivery on a physical iPhone are not yet verified. This is not a confirmed diagnosis or fix for the reported friend's device.

## Distribution

Upload succeeded at 2026-09-20 13:07:45 Europe/Istanbul. App Store Connect showed
0.2 (12), build ID `72491d7e-adc4-4e8e-9de4-d048ee93b2bd`, initially as Processing.
After processing and renewed sign-in, English and Turkish test notes were saved
and the build was submitted through the TestFlight beta flow with tester notification enabled.
Both group Builds pages were verified as **Testing**, expiring in 90 days:

- Clockin Internal: `0cc38512-c301-4078-b825-35b5d47d9167`.
- Clockin Public Beta: `57b1eacb-e2d0-49d8-abaf-abd5ed5f324d`.

Public beta link: https://testflight.apple.com/join/tr6kSDMN.
No old builds were expired. The separate App Store privacy publication remains pending
the previously requested final legal confirmation and was not changed by this release.
