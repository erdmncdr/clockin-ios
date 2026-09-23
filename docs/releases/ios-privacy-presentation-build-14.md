# iOS 0.2 (14): privacy presentation

The user reports that Settings → Live updates setup guide immediately closes.
The settings guide had its own sheet modifier on a Section inside a Form, unlike
the other settings destinations. It also bypassed Settings' celebration blocker
and rate-edit presentation guard. The guide itself has no automatic dismissal;
its only dismiss call is the explicit finish action.

The guide and privacy policy now use the SettingsSheet destination owned by the
stable Settings screen. The privacy section only dispatches actions. This removes
the Form section's sheet presenter and includes both destinations in existing
modal coordination, without replacing the approved companion UI.

Both policy buttons now open PrivacyPolicyBrowser (SFSafariViewController). The
guide owns a nested policy sheet, so closing the browser returns to the same step
without enabling updates or marking setup finished. The existing policy URL and
consent text are unchanged.

## Verification

- Release snapshot created from the companion-art working tree, with 3D excluded.
- All 331 source manifest hashes verified; git diff whitespace check passed.
- Signed Release archive succeeded with no compiler warnings/errors in the log.
  App and widget both verified as 0.2 (14); deep strict code-sign verification passed.
- Simulator GUI is unavailable through the computer-use tool (Invalid app for
  both bundle ID and the actual Simulator app path). The immediate-dismissal
  symptom has not been reproduced locally; this change addresses the identified
  presentation ownership discrepancy. On-device acceptance remains required.

## Device acceptance

1. Open Settings, scroll to Privacy & Live Activity, open the guide, and leave it
   visible while the timer/connection state updates. It should remain open.
2. Close and reopen the guide repeatedly; dismissing it should retain Settings.
3. Open policy from Settings, close the browser, and reopen it.
4. Open policy from the guide. Close or swipe down the browser; the guide must
   remain on the same step and consent must remain unchanged.
5. Repeat with live updates enabled and disabled, including first-launch setup.

Archive: `/tmp/clockin-guide-fix-14/Clockin.xcarchive`.
Upload succeeded on 2026-09-21 at 11:25 Europe/Istanbul. Build ID:
`afad099c-7ab3-4808-a75d-8886ed8f65a6`. English and Turkish test notes saved;
automatic tester notification enabled at submission. Verified **Testing** for
0.2 (14) on both Clockin Internal and Clockin Public Beta group Builds pages.
