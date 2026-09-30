# Mac 2.0.5 (16): Ask to re-import doubled timecards

Source: `erdmncdr/clockin-ios` main at `f071c49` (change `e04fe4f`), target
`ClockinMac`. Published to the existing Sparkle feed in `ismailakdag/clockin`
(`macos-updates/appcast.xml`), versioned release `macos-v2.0.5`.

- `SessionOverlap.importedTwice`: two timecard entries whose start and end are
  each within 15 minutes of the other are one row imported twice (before sync,
  each device imported the same export with its own ids, and the first merge
  kept rows a few minutes apart). `ClockStore.importedTwice` caches the count
  and the extra time.
- `timecardReimportPrompt()` on the Mac and iPhone roots: when copies exist and
  no first merge is pending, an alert asks to import the timecard CSV from the
  first workday to today and opens the import; "Later" snoozes it for a day.
- On the user's data: 29 copies (106.7 hours) before the cleanup, none after;
  the timecard's own overlaps across midnight or a month end are not counted.
  Checked in a signed Debug build on the doubled development data: "29 kayıt
  iki kez içe aktarılmış görünüyor ve yaklaşık 106 sa 43 dk fazla sayılıyor".
- Turkish strings use "puantaj" for timecards throughout.

## Verification

```text
Checks: overlap 42 (4 new), import 30; iOS and Mac builds succeeded
build.sh / notarize.sh / package.sh passed; Gatekeeper: Notarized Developer ID
publish.sh --yes (from f071c49): Live appcast 2.0.5 (16), 19,598,283 bytes;
  fixed macos-updates/Clockin.dmg matches the release DMG
```
