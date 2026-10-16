# Mac 2.0.13 (24): move from Downloads, no stacked update checks

Source: `erdmncdr/clockin-ios` main at `6b878d4`, target `ClockinMac`.
Published to `erdmncdr/clockin-macos`; versioned release `macos-v2.0.13`.
Notes: `docs/release-notes-mac-2.0.13.md`.

- Testers opening the zipped app from Downloads got no move offer. A quarantined
  copy runs translocated; `ApplicationMover.locate` also read the original's
  signature in Downloads, and a failed read classified it as a development
  build. The translocated mirror (already checked) is the signature and copy
  source now. Reproduced in `Tests/manual/macmover` (fails on the old code with
  "got development"). A live run of an unquarantined download showed the move
  alert; the quarantined path stops at Gatekeeper's first-launch dialog, which
  needs a person.
- Spamming Check for Updates queued a second check behind Sparkle's modal
  up-to-date alert. `UpdateChecker.isChecking` now covers a user-started session
  until Sparkle ends it; extra clicks only activate the app, Settings disables
  the button, and the flag is set only when Sparkle actually started a session.

## Verification

```text
README checks 52/52 (macmover 10, macmenubar 6)
build.sh / notarize.sh / package.sh / publish.sh --yes passed
Live appcast 2.0.13 (24); anonymous Clockin.zip and Clockin.dmg = release files
```
