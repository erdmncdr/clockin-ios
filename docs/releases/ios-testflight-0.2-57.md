# iOS 0.2 (57): follow-ups to the clock-out fix

Repository: `erdmncdr/clockin-ios`. Source: main at `d63bae5`. Everything from 0.2 (56).

- `ClockStore.clockOut`: an invalid date is left to validation instead of being replaced
  by the session's start.
- `ClockOutIntent`: when no session runs, the mirror is refreshed so a widget that still
  shows a gone session redraws.
- Same source as Mac 2.0.28 (39), `docs/releases/mac-2.0.28-39.md`.

Archive `build/ios-release/Clockin-0.2-57.xcarchive`, team LU36PKDPT3. Uploaded
2026-10-29 00:26 (+03); processed by 00:34. Build id
`c778f12d-5ef6-4770-b447-991e79b5262a`. What to Test in English and Turkish; added to
Clockin Internal and Clockin Public Beta; beta review submitted (WAITING_FOR_REVIEW);
internal and external state IN_BETA_TESTING; tester notification on.

Verification: timer log suite; iOS Debug build; the clamp itself reviewed and tested
for 56. Build folders (`export/`, `DerivedData/` of every Mac release, the Debug
DerivedData folders) were moved to the Trash after verification; archives kept.
