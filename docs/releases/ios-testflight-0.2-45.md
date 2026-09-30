# iOS 0.2 (45): First production merge after development testing, file as reference

Repository: `erdmncdr/clockin-ios`.
Source: main at `76d8170`. 0.2 (44) (`de62f46`, the sync fix alone) was
uploaded and not distributed.

- 0.2 (43) reused the sync state a development build had left on the phone
  after its first merge with the Mac in the CloudKit development environment.
  It therefore skipped the production first merge, reported "up to date" and
  never uploaded the phone's history, while Clockin for Mac 2.0.0 (11) had
  uploaded its 639 records to production.
- The sync state now records its CloudKit environment (`ClockinCloudEnvironment`
  in Info.plist: Development for Debug, Production for Release). State from the
  other environment keeps the local history but drops the server checkpoint,
  change tags and first-merge completion, so the device fetches, shows the
  first-merge preview and uploads after Merge. Untagged state on iOS that had
  completed a first merge is treated as development state; untagged Mac state
  is adopted, because the Mac tested sync with a separate Debug archive.
- Clockin for Mac needs no update: 2.0.0 (11) shows its own first-merge
  preview when the phone's records arrive.
- Import timecards: "Use this file as the reference". The phone and the Mac
  had each imported the Starfleet export with new random ids; the development
  first merge collapsed exact copies but kept rows whose times differed, so
  some work was doubled (the merged development archive had 670 entries and
  2,814 hours against the Mac's 615 and 2,564). With the file as the
  reference, every entry in its period that the file does not contain is
  offered for deletion (any source), matching entries take the file's times
  and new rows are added, after the preview and a confirmation.

## Verification

```text
Checks: sync 268 (3 new environment checks), send 37, codec 33, import 30 (4 new)
Type-check: CloudKit adapter on macOS 14 and iOS 17
Builds: iOS Simulator and Mac Debug succeeded; archive 0.2 (45) Production,
  ClockinCloudSyncEnabled YES; uploaded 2026-09-30 12:43
```

## What to Test

### English

If you tested sync with a development build, the first sync with the App Store environment now asks to merge again. Open Settings > iCloud, check the counts and choose Merge; your entries then appear on your Mac. Import timecards has a new "Use this file as the reference" option: everything in the file's period that the file does not contain is deleted after you confirm, so doubled entries from earlier imports go away.

### Turkish

Eşzamanlamayı daha önce geliştirme sürümüyle denediysen, gerçek ortamdaki ilk eşzamanlama birleştirmeyi yeniden sorar. Ayarlar > iCloud'u aç, sayıları kontrol et ve Birleştir'i seç; kayıtların ardından Mac'te görünür. Zaman kartı içe aktarmada yeni "Bu dosyayı esas al" seçeneği var: dosyanın kapsadığı dönemde dosyada olmayan her kayıt onayından sonra silinir, önceki içe aktarmalardan kalan çift kayıtlar böylece temizlenir.
