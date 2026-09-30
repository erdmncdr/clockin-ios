# Mac 2.0.2 (13): Every timecard import is the reference for its period

Source: `erdmncdr/clockin-ios` main at `43e463d` (change `71e3ddd`), target
`ClockinMac`. Published to the existing Sparkle feed in `ismailakdag/clockin`
(`macos-updates/appcast.xml`), versioned release `macos-v2.0.2`.

- Import timecards no longer has a "Use this file as the reference" switch.
  Entries in the file's period that it does not contain start selected for
  deletion, any source; a CSV covers every day from its first to its last
  date, pasted timecards the days they contain. Keep all and Choose remain;
  deletion needs confirmation. Same change as iOS 0.2 (47).
- Release notes: `docs/release-notes-mac-2.0.2.md`.

## Verification

```text
build.sh: archive and export succeeded; distribution checks passed
notarize.sh: Accepted; staple validate OK; Gatekeeper: Notarized Developer ID
package.sh: DMG notarized; appcast generated and verified
publish.sh --yes (from 43e463d): versioned DMG and SHA256SUMS public; Clockin.dmg
  and appcast swapped last and checked anonymously
Live appcast: 2.0.2 (13); fixed macos-updates/Clockin.dmg matches the release DMG
```

## Sync note

On 2026-09-30 the Mac's CloudKit zone fetches over HTTP/3 stalled after ~884
response bytes on the home Wi-Fi (server logged SUCCESS in 118 ms); turning
Wi-Fi off and on moved cloudd to HTTP/2 and the pending changes arrived at
once. Nothing in the app caused or could work around it.
