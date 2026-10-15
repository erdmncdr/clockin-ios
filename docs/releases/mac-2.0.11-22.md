# Mac 2.0.11 (22): timer in the menu bar again

Source: `erdmncdr/clockin-ios` main at `090e68d`, target `ClockinMac`.
Published to `erdmncdr/clockin-macos` (`macos-updates/appcast.xml`, fixed
`macos-updates/Clockin.dmg`), versioned release `macos-v2.0.11`.
Notes: `docs/release-notes-mac-2.0.11.md`.

A tester saw only the icon while clocked in. `MenuBarController.refreshLabel`
showed the live text only in minimal mode (off by default), although
Show details in the menu bar (on by default) promises it. Minimal mode now only
hides the window and the pin; digits use a tabular font.

## Verification

```text
Tests/manual/macmenubar: 6 checks pass; fails on the previous code
  ("clocked in with default settings, the live text shows (got '')")
README checks 51/53 (the two misses are simulator install/launch with no booted device)
Signed Debug build; build.sh / notarize.sh (accepted) / package.sh / publish.sh --yes
Live appcast 2.0.11 (22); anonymous Clockin.dmg = release DMG; spctl accepted
```
