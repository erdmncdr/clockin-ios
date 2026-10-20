# Mac 2.0.22 (33): move-to-Applications question in front

Source: `erdmncdr/clockin-ios` main at `5779f5f`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.22.md`.

- Report: a friend opens the downloaded zip's app, gets no install question, no menu bar icon, and
  Clockin is missing from System Settings > Menu Bar. The move offer runs modally before the status
  item is made; as an accessory app launched from Finder it often failed to activate.
  Probe app (same launch code, opened with `open` while Finder was front): old way 2/2 not
  frontmost (Finder/Chrome stayed front); new way (regular policy for the question, activate,
  floating level) 2/2 frontmost. A full-screen front app would hide the old alert entirely.
- No "Don't ask again" for translocated copies or copies in ~/Downloads, ~/Desktop; a stored
  suppression no longer applies there. Translocated copies skip the signature check; an unreadable
  signature no longer means a development build.
- Copy details gains `app: <kind> <path>`.

Verification: macmover 15/15, macmenubar 8/8, Release compile, notarized; publish.sh --yes;
live appcast 2.0.22 (33); website zip = release zip (18355061 bytes).
Not verified: the real Clockin launched from a quarantined download (would share the real app's
prefs), and the friend's Mac.
