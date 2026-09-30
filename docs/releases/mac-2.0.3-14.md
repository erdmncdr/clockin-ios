# Mac 2.0.3 (14): Serious overlaps only

Source: `erdmncdr/clockin-ios` main at `5871ebc` (change `c267c56`), target
`ClockinMac`. Published to the existing Sparkle feed in `ismailakdag/clockin`
(`macos-updates/appcast.xml`), versioned release `macos-v2.0.3`.

- History and the entry editor warn only about serious overlaps: never
  between two timecard entries, and not for overlaps of up to five minutes
  unless they cover half of the shorter entry. Same change as iOS 0.2 (48)
  (`docs/releases/ios-testflight-0.2-48.md`).
- Release notes: `docs/release-notes-mac-2.0.3.md`.

## Verification

```text
build.sh: archive and export succeeded; distribution checks passed
notarize.sh: Accepted; Gatekeeper: Notarized Developer ID
package.sh: DMG notarized; appcast generated and verified
publish.sh --yes (from 5871ebc): versioned DMG and SHA256SUMS public; Clockin.dmg
  and appcast swapped last and checked anonymously
Live appcast: 2.0.3 (14), 19,569,875 bytes; fixed macos-updates/Clockin.dmg
  matches the release DMG
```
