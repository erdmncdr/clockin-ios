# iOS 0.2 (25): Foreground focus chimes

Repository: `erdmncdr/clockin-ios`.
Source: `/Users/erdemincedere/Clockin/clockin-iphone`, main at `528d58214c70ac1054a5df99beca048c5d0a0e7d`.
Tracked files were clean. No source or Git changes made.

The Live Activity registration cleanup (`7d7a162`) landed after this build
and is not in it; it ships with 0.2 (26).

## Verification

All 29 required checks passed from the repository root.

| # | Group | Result |
|---|---|---|
| 1 | wardrobe | Passed, exit 0 |
| 2 | radio | Passed, exit 0 |
| 3 | celebrations | Passed, exit 0 |
| 4 | rolling | Passed, exit 0 |
| 5 | haptics | Passed, exit 0 |
| 6 | snapshot | Passed, exit 0 |
| 7 | import | Passed, exit 0 |
| 8 | backups | Passed, exit 0 |
| 9 | overlap | Passed, exit 0 |
| 10 | raterange | Passed, exit 0 |
| 11 | earnings | Passed, exit 0 |
| 12 | historytry | Passed, exit 0 |
| 13 | insights | Passed, exit 0 |
| 14 | mascot | Passed, exit 0 |
| 15 | companion2 | Passed, exit 0 |
| 16 | companion | Passed, exit 0 |
| 17 | momentum | Passed, exit 0 |
| 18 | share | Passed, exit 0 |
| 19 | widgettheme | Passed, exit 0 |
| 20 | chime | Passed, exit 0 |
| 21 | chimesound | Passed, exit 0 |
| 22 | controls | Passed, exit 0 |
| 23 | reminder | Passed, exit 0 |
| 24 | nudges | Passed, exit 0 |
| 25 | goals | Passed, exit 0 |
| 26 | sessions | Passed, exit 0 |
| 27 | rates | Passed, exit 0 |
| 28 | feedback | Passed, exit 0 |
| 29 | sessiondisplay | Passed, exit 0 |

Logs: `/tmp/clockin-25/check-*.log`.

## Archive

Archive: `/tmp/clockin-25/Clockin.xcarchive`.

```text
Clockin.app: version 0.2, build 25
ClockinWidgets.appex: version 0.2, build 25
Root chime CAF files: 8
Archive: succeeded, 0 warnings, 0 errors
Tracked source hashes unchanged: 356
/tmp/clockin-25/Clockin.xcarchive/Products/Applications/Clockin.app: valid on disk
/tmp/clockin-25/Clockin.xcarchive/Products/Applications/Clockin.app: satisfies its Designated Requirement
```

Automatic version and build renumbering disabled.

## Release

Upload succeeded at 2026-09-22 19:09:54 Europe/Istanbul.
App Store Connect confirmed version 0.2, build 25; processing completed successfully.
Build ID: `37969e30-5a2c-4b32-a59f-43fdabb82050`.
The exact English and Turkish test notes below were saved. Automatically notify testers was enabled.

Both groups were verified in their own build lists at 2026-09-22 19:17 Europe/Istanbul:

| Group | Build | Status |
|---|---|---|
| Clockin Internal | 0.2 (25) | Testing |
| Clockin Public Beta | 0.2 (25) | Testing |

The review submission completed and the build is available for testing in both groups.

## What to Test

### English

Focus chimes no longer show a notification while Clockin is open. The chime still sounds, but nothing appears on screen and nothing is left in Notification Center. When Clockin is closed the chime still arrives as a notification, because iOS will not play a sound without one, and those now collapse into a single group that is cleared when you open the app.

### Turkish

Odak çanları artık Clockin açıkken bildirim göstermiyor. Çan yine çalıyor ama ekranda bir şey görünmüyor ve Bildirim Merkezi'nde iz kalmıyor. Clockin kapalıyken çan yine bildirim olarak geliyor, çünkü iOS bildirimsiz ses çalmıyor; bunlar da tek bir grupta toplanıyor ve uygulamayı açtığında temizleniyor.
