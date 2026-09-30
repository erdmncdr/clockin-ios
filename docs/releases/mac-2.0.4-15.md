# Mac 2.0.4 (15): Poll iCloud every minute while running

Source: `erdmncdr/clockin-ios` main at `9fdd6a0` (change `1e6c16c`), target
`ClockinMac`. Published to the existing Sparkle feed in `ismailakdag/clockin`
(`macos-updates/appcast.xml`), versioned release `macos-v2.0.4`.

- `SyncCoordinator.setPolling`: the Mac asks iCloud for changes every 60
  seconds while it runs; the iPhone (0.2 (49)) does the same while a scene is
  active. Push stays the fast path. Both apps log "push delivered to the app".
- Why: in a test on 2026-09-30 the iPhone started the timer at 16:20:03 and
  Mac 2.0.3 fetched only at 16:20:09, after the user clicked its menu bar icon
  at 16:20:07; no push-triggered fetch was seen that day.
- A signed Debug build polled at 15:49:20, 15:50:21 and 15:51:22.
- Release notes: `docs/release-notes-mac-2.0.4.md`.

## Verification

```text
Checks: sync app 50, sync 268; type-check macOS 14 and iOS 17
build.sh / notarize.sh / package.sh: passed; Gatekeeper: Notarized Developer ID
publish.sh --yes (from 9fdd6a0): Live appcast 2.0.4 (15), 19,579,029 bytes;
  fixed macos-updates/Clockin.dmg matches the release DMG
```
