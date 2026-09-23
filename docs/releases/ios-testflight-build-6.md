# iOS TestFlight 0.1 (6)

Source: main at `00dd3800c77474b74dcd05a446be9e3a361a9ae6`, after merging PR #35 without conflicts. This build includes PRs #32, #33, #34, and #35.

## Included changes

- Control Center, Lock Screen, and Action Button controls for clock in/out and pause/resume.
- Companion motion and six tap reactions, angry mood frames, and the medium widget companion.
- Friendly/Grumpy nudges with a daily limit and quiet hours.
- Long session reminders and their clock-out, end-time, and snooze actions.
- Earlier-rate settings and the effective-date question when changing hourly rates.
- The six feedback fixes: fresh chime settings, normal notification sound, long-entry end dates, consistent rate selection, overnight snapshot rate, and precise overlap checks.

## Verification

- All README-listed swiftc checks passed on main: 12 Mac suites and 20 iPhone suites. The new rate suites passed 59 Mac checks and 62 iPhone checks. The iPhone suites printed 821 successful checks in total.
- Mac build and generic iOS Simulator app/widget build passed. Signed Release archive passed.
- Both `Clockin.app` and `ClockinWidgets.appex` have version 0.1 and build 6.
- Both bundles contain all 45 mascot PNGs, `mascot-clips.json`, and their privacy manifest. PNG hashes matched the source after the same packaging compression; the JSON matched directly.
- Strict recursive code-signature verification passed. Build/signing settings were supplied at build time; the project file was unchanged.
- This release verification did not include a new physical-device UI test of the combined feature set.

## Distribution

- Upload succeeded on 16 September 2026 at 21:07 Europe/Istanbul. App Store Connect independently showed 0.1 (6) processing.
- Processing completed. Build 0.1 (6) was added to Clockin Internal and Clockin Public Beta with English and Turkish test notes covering every item above.
- Beta review submission completed with automatic tester notifications enabled. Final status in Clockin Public Beta > Builds: **Testing**. Both groups were verified on the build detail page.
- Existing builds were not withdrawn or expired. Public beta link: https://testflight.apple.com/join/tr6kSDMN .
