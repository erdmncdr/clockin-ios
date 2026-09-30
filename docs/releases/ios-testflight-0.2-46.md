# iOS 0.2 (46): Sync crash fix

Repository: `erdmncdr/clockin-ios`.
Source: main at `140a8d5`. Everything from 0.2 (45)
(`docs/releases/ios-testflight-0.2-45.md`).

- 0.2 (43) crashed on iOS 27 during sync: three reports from a public beta
  tester's iPhone 15 Pro (iOS 27.0, 24A437), all `EXC_BREAKPOINT` in
  `CKSyncEngine.fetchChanges(_:)` called from `ClockinCloudAdapter.synchronizePass`
  (`CloudKitAdapter.swift:189` in 43). CloudKit's message, read from the
  matching iOS 27.0 CloudKit binary: "BUG IN CLIENT OF CLOUDKIT: Cannot await a
  call into CKSyncEngine from within a delegate callback if that function will
  end up calling back into the delegate. [...] Try performing this in a
  detached Task."
- Cause: the sync pass ran in a `Task` created by whoever called
  `synchronize()`. A retry scheduled from `handleEvent`, or a save applied from
  a fetched record, inherited the delegate-callback marker, so the next pass
  looked like a call from inside the callback. On the Mac the one retry so far
  joined a pass that was still running, which is why 2.0.0 (11) did not crash.
- Fix: launches and passes run in detached tasks; `fetchChanges` and
  `sendChanges` are called only from there.

## Verification

```text
Checks: sync 268, send 37, codec 33; adapter type-check on macOS 14 and iOS 17
Builds: iOS Simulator and Mac Debug succeeded
Archive: 0.2 (46) Production, uploaded 2026-09-30 13:13
Symbolication: build 43 dSYM F95FA4D1-CBF8-3624-A98A-88C8AAAC32A3, CloudKit
  5AFBD6E3-5AAB-3910-88D4-E6540F0C97F7 (iOS DeviceSupport 27.0 24A435)
```

## What to Test

### English

Fixes a crash during iCloud sync. If you tested sync with a development build, the first sync now asks to merge again: open Settings > iCloud, check the counts and choose Merge. Import timecards has a new "Use this file as the reference" option that removes entries the file does not contain, after you confirm.

### Turkish

iCloud eşzamanlaması sırasında olan bir çökme düzeltildi. Eşzamanlamayı daha önce geliştirme sürümüyle denediysen ilk eşzamanlama birleştirmeyi yeniden sorar: Ayarlar > iCloud'u aç, sayıları kontrol et ve Birleştir'i seç. Zaman kartı içe aktarmada yeni "Bu dosyayı esas al" seçeneği, onayından sonra dosyada olmayan kayıtları siler.
