# Mac 2.0.7 (18): Launch crash and resource fixes

Source: `erdmncdr/clockin-ios` main at `571514c`, target `ClockinMac`.
Published to the Sparkle feed in `ismailakdag/clockin` (`macos-updates/appcast.xml`),
versioned release `macos-v2.0.7`. Notes: `docs/release-notes-mac-2.0.7.md`.

- Launch crash (`f3977ed`, `e24c9ef`): TestFlight reports from iOS 0.2 (43) and (51)
  trapped 0.3 s after launch in `SyncCoordinator.observe`: CloudKit posts
  `UserDefaults.didChangeNotification` on an XPC thread while caching account info,
  and Combine closures formed on the main actor inherited its isolation (Swift 6
  traps on entry). Fixed there, in the Mac pinned window and in the menu bar's `map`.
  The Mac shares this code; no Mac reports were available to confirm it.
- Audit 24 (`958a091`, merged `25e2a20`): sidecar writes deduplicated and batched;
  widget timeline 74 -> 33 entries with one image per mood (kept at 240 px,
  `1f287c7`); CloudKit gated on the signed entitlement (Mac `SecTask`; iOS always
  on); data-driven traps (duplicate session IDs quarantined, missing earnings,
  huge pasted totals, unknown rolling fonts, reversed ranges) return safely.
- Sidecar engine token (`e24c9ef`): the 2.0.6 release wrote 8.6 GB in 2.7 h
  (5.2 MB `sync-state.json`, mostly `systemFields`). After batching, a signed Debug
  run still rewrote it on every 60 s poll because CKSyncEngine returns a new state
  serialization per fetch; engine-only changes now write at most every 15 minutes
  (forced on background, turn-off, termination helper). Measured: 0 writes in 3
  minutes of polling. Quit no longer uses `.terminateLater` (review 25 finding 2).
- Reviews: 25 (two Mac findings, fixed), 26 (nothing blocks).

## Verification

```text
All 50 README checks pass on 571514c's sources (sync 268, persistence 30,
  syncapp 105, crashaudit 206 + platform 34, iphonefollowsmac 51, ...)
Signed Debug: launches, syncs, 0 sidecar writes over 3 polls, quits in 1 s
build.sh / notarize.sh / package.sh passed; Gatekeeper: Notarized Developer ID;
  entitlements: iCloud.com.erdmncdr.clockin, CloudKit, Production
publish.sh --yes (after pushing main): live appcast 2.0.7 (18), 19,742,429 bytes;
  fixed macos-updates/Clockin.dmg matches the release DMG
```
