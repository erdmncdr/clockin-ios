# iOS 0.2 (33): A level earned back is celebrated again

Repository: `erdmncdr/clockin-ios`.
Source: main at `5ba9977b9134aa242b5924fb298accf81a2f8c97`.

- Cancelling a session that crossed a level, or deleting or shortening an
  entry, takes the level back; earning it again now shows the level-up card
  and haptic again instead of treating it as already celebrated. A queued
  card for a level no longer earned is withdrawn.
- Everything from 0.2 (32).

## Verification

```text
Checks: 32 of 32 passed (celebrations: 108 assertions, 5 new)
Archive: succeeded, 0 warnings, 0 errors
Clockin.app: 0.2 (33)
ClockinWidgets.appex: 0.2 (33)
Signature: satisfies its Designated Requirement
Chime sounds: 8
Turkish strings: 1272 of 1272
```

In the simulator: a running session at level 45 was cancelled and the stored
level fell to 42; a new session started with eight hours elapsed reached
level 43 and the card appeared again. Relaunching did not repeat it.

## Release

Upload succeeded at 2026-09-26 14:00:35 Europe/Istanbul; processing completed.
Build ID: `9ed6caf9-95c2-4ccf-92d9-e1ee7fd3f5e8`.
The English and Turkish test notes below were saved and tester notification
was enabled. The build was added to Clockin Public Beta and submitted for
review, then to Clockin Internal from the group's Builds tab. The iOS Builds
list then showed 0.2 (33) as **Testing** in both groups.

## What to Test

### English

If you cancel a session after it crossed a level, the level goes back, and earning it again now shows the level-up celebration again.

### Turkish

Seviye atlatan bir oturumu iptal edersen seviye geri düşüyor; aynı seviyeyi yeniden kazandığında seviye atlama kutlaması tekrar çıkıyor.
