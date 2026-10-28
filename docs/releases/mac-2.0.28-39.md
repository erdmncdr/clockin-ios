# Mac 2.0.28 (39): clock out never traps the timer

Source: `erdmncdr/clockin-ios` main at `d63bae5`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.28.md`. Background: `docs/releases/ios-testflight-0.2-56.md`.

- `ClockStore.clockOut` ends a session whose start is ahead of this clock at its start,
  keeping the accumulated time, instead of refusing (shared with iOS 0.2 (56/57)); an
  invalid clock-out date is left to validation; a remaining refusal sets
  `timerPersistenceError` so the alert shows the reason.
- `ClockOutIntent` (Shortcuts, Mac widget) refreshes the mirror when no session runs.

Verification: timer log suite, import (102), syncapp (105), crashaudit (206); Mac and
iOS Debug builds; read-only second review of 6017a25; build.sh 2.0.28 39; notarize.sh
(Accepted, stapled, Gatekeeper accepted); package.sh; publish.sh --yes; live appcast
2.0.28; website zip = release zip (18520282 bytes).
