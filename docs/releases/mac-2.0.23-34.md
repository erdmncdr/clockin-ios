# Mac 2.0.23 (34): menu bar placement test and diagnostics

Source: `erdmncdr/clockin-ios` main at `0aacfb4`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.23.md`.

Report (2.0.22, macOS 26.6.2, /Applications): `frame={{0, -22}, {36, 22}} onScreen=false`, Clockin
missing from System Settings > Menu Bar, 18 LaunchServices records for the bundle ID (12 trash,
3 translocated, 2 /Volumes). Other app icons show; removing them, Ice off, lsregister -f did not help.

Findings here (macOS 27.0.1):
- Code review: item held strongly by the singleton, made on the main actor, variableLength, image
  and title only (no hosting view). Nothing found that keeps it off the bar.
- An item hidden for lack of room is laid out by the bar: `{{0, -33}, {3272, 33}}` (bar height
  beside the notch). The reported frame keeps AppKit's 22 pt default: never taken in by the bar.
  So the report does not look like a full bar. Not reproduced here.
- This Mac also has trash and build records for the bundle ID and its items show, so the
  records alone are not the cause. `saved: none` also shows on a working Mac.

Change: `MenuBarProbe`; Test menu bar (Today card, Settings) adds a plain item and one with its own
autosave name for 3 s. Verdict: shown / itemOnly (switches Clockin to a plain item, no autosave
name; `Clockin.MenuBarPlainItem`) / noRoom / notAllowed. Copy details adds launch +1/+5/+30 s,
before/after reset, test snapshots (state, frame, length, button and fitting sizes), other running
copies, LaunchServices record counts. Neutral notice and footer copy; Turkish added.

Verification: macmenubar 17/17, macmover 15/15; Debug app with `--menu-bar-probe`: test
shown, both test items placed, reset before/after placed, no test keys left in defaults.
publish.sh --yes; live appcast 2.0.23 (34); website zip = release zip (18393231 bytes).
Not verified: the itemOnly / notAllowed paths on a Mac that shows them.
