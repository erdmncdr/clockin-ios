# Mac 2.0.1 (12): Sync crash fix, environment reset, file as reference

Source: `erdmncdr/clockin-ios` main at `df46529` (fix `140a8d5`), target
`ClockinMac`. Published to the existing Sparkle feed in `ismailakdag/clockin`
(`macos-updates/appcast.xml`), versioned release `macos-v2.0.1`.

- Sync passes and launches run in detached tasks. A pass started from a task
  created inside a CKSyncEngine delegate callback (a retry scheduled from
  `handleEvent`, or a save applied from a fetched record) trapped in
  `fetchChanges` with "Cannot await a call into CKSyncEngine from within a
  delegate callback". iOS 0.2 (43) crashed this way on iOS 27
  (`docs/releases/ios-testflight-0.2-46.md`); 2.0.0 had the same code.
- The sync state records its CloudKit environment; untagged Mac state is
  adopted as Production.
- Import timecards: "Use this file as the reference".
- Release notes: `docs/release-notes-mac-2.0.1.md`.

## Verification

```text
build.sh: archive and export succeeded; metadata, universal slices, Developer ID,
  Sparkle helpers and widget checks passed; ClockinCloudEnvironment Production
notarize.sh: Accepted; staple validate OK; Gatekeeper: Notarized Developer ID
package.sh: DMG notarized; appcast generated and verified
publish.sh --yes (from df46529): versioned DMG and SHA256SUMS public; Clockin.dmg
  and appcast swapped last and checked anonymously
Live appcast: 2.0.1 (12) -> macos-v2.0.1/Clockin-2.0.1-12.dmg (19,577,707 bytes);
  fixed macos-updates/Clockin.dmg matches it (the website links this file)
```
