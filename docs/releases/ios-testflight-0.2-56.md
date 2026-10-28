# iOS 0.2 (56): clock out never traps the timer

Repository: `erdmncdr/clockin-ios`. Source: main at `6017a25`. Everything from 0.2 (55).

Report (2026-10-28, a tester): "the widget is broken", clock out from the widget did
nothing, then clock out inside the app did nothing either. Build unknown. No crash or
feedback submission on 54/55 in App Store Connect; 53 shows 4 unsubmitted crashes.

Analysis: nothing in 54/55 touches the clock-out path. The one path that matches both
surfaces: `ClockStore.clockOut` refused when `date < running.start` (a session begun on a
device whose clock runs ahead and synced over, or a clock set back), and
`TimerCard` did nothing on nil, the widget intent's dialog is never shown.

- `clockOut` now ends such a session at its start, keeping only the accumulated time,
  instead of refusing; any remaining refusal sets `timerPersistenceError`, so the
  existing alert shows the reason. Test: `Tests/manual/timerlog` (clamped clock-out,
  logged with its origin, not an error).
- Also in the repository for the next build (`44c990b`, after 56 was archived): an
  invalid clock-out date is no longer replaced by the start, and `ClockOutIntent`
  redraws the widget when it still shows a session that is gone.

Archive `build/ios-release/Clockin-0.2-56.xcarchive`, team LU36PKDPT3. Uploaded
2026-10-29 00:10 (+03); processed by 00:18. Build id
`e6d141b0-11bd-41d7-ba61-5d16740358b9`. What to Test in English and Turkish asks
testers who hit it for a Timer log screenshot; added to Clockin Internal and Clockin
Public Beta; beta review submitted (WAITING_FOR_REVIEW); internal and external state
IN_BETA_TESTING; tester notification on.

Verification: timer log suite, import (102), syncapp (105), crashaudit (206); iOS and
Mac Debug builds; a read-only second review of 6017a25 (clamp valid for encoding and
sync merge; no caller relied on the refusal). Not reproduced on a device: the tester's
exact case is still unknown; if the Timer log shows a start from "Another device
(iCloud)", the clock-skew explanation is confirmed.
