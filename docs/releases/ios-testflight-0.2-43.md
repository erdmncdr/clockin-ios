# iOS 0.2 (43): Sync with Clockin for Mac

Repository: `erdmncdr/clockin-ios`.
Source: main at `8d3711d` (the release configuration commit; the archive was
built from its working tree before that commit, with identical app sources).

- Clockin syncs with the new Clockin for Mac through the user's private iCloud
  (container `iCloud.com.erdmncdr.clockin`, CKSyncEngine, custom zone
  `Clockin`): sessions, the running timer, rate rules, pay settings, goals,
  wardrobe and room, purchases and user choices. The app language stays on
  each device.
- The first time a device meets another device's history it shows a preview
  (entries on this device, from other devices, the same on both, after
  merging), saves an exact copy of the archive and merges only on Merge.
- Settings has an iCloud section at the top: on/off, status, last sync and
  "Sync changes", a page with values another device replaced.
- A damaged entry is set aside on its own instead of emptying the store.
- Everything from 0.2 (42).

## Verification

```text
Checks: README 34 of 34, sync 262, coordinator 50, send 37, codec 33
Archive: succeeded
Clockin.app: 0.2 (43), ClockinCloudSyncEnabled YES, iCloud container entitlement present
CloudKit: schema (7 record types) deployed to Production before distribution
Tested before release: iPhone 17 Pro (development build) and Mac, development
environment: first merge 640 + 615 - 585 = 670 entries on both, a timer started
on the phone appeared on the Mac by push
```

## Release

Uploaded 2026-09-30 04:21 Europe/Istanbul with `xcodebuild -exportArchive`
(`Tools/ios-release/ExportOptions.plist`); processing completed. English and
Turkish test notes saved, tester notification on, Clockin Internal and Clockin
Public Beta added and the build submitted for beta review.

## What to Test

### English

Clockin now syncs with the new Clockin for Mac through your private iCloud: sessions, the running timer, pay rates, goals, your companion's outfits, room and coins, theme and chimes. The first time both devices have history, Clockin shows how many entries each has and how many are the same, saves a copy of your data and merges only when you choose Merge. Start the timer on one device and watch it appear on the other. Settings > iCloud shows the sync status.

### Turkish

Clockin artık yeni Mac uygulamasıyla özel iCloud'un üzerinden eşzamanlanıyor: kayıtlar, çalışan sayaç, ücretler, hedefler, arkadaşının kıyafetleri, odası ve jetonları, tema ve çanlar. İki cihazda da geçmiş varsa Clockin ilk seferde her cihazda kaç kayıt olduğunu ve kaçının aynı olduğunu gösterir, verinin bir kopyasını alır ve ancak Birleştir'i seçersen birleştirir. Bir cihazda sayacı başlatıp diğerinde görünmesini deneyin. Eşzamanlama durumu Ayarlar > iCloud'da.
