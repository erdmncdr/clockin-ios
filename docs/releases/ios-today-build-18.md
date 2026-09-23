# iOS 0.2 (18): compact, configurable Today

- Summary now has side-by-side Session and Today columns, each with worked time,
  earnings and the available TRY equivalent. Session is the active session;
  Today uses the existing start-date-based daily total. Paused time stays frozen,
  an idle session reads zero, and overnight work retains its original start date.
- USD/TRY is a compact bottom strip with a rounded rate and brief refresh/cache
  status. The dated subtitle is removed. No new API polling is added.
- Recent sessions shows the newest three, titled Last 3 Sessions. See all still
  opens History, with editing and context-menu actions retained.
- Customize Today is beside Settings in the fixed header. The same customization
  options also remain available through Settings. Six card-visibility preferences
  and four optional links (Goals & Pace, History, Add entry, Live updates) join
  the existing chime, radio and reminder pins. Preferences are local and retain
  all cards by default. Hiding a card does not change feature settings or records.
- Money Momentum shows the account currency and available TRY equivalent on one
  line separated by `=`. USD/account rate uses up to three decimals, TRY two.
  Tiny positive values use a less-than threshold instead of rounding to zero.
  Earnings calculations and milestone thresholds retain full precision.

## Verification

- 17 existing Money Momentum checks pass, covering working/paused/idle,
  conversion availability, invalid inputs and milestone boundaries.
- Signed Release archive succeeds without compiler warnings or errors.
- App and widget both read 0.2 (18); strict deep codesign verification passes.
- All 336 source hashes match the frozen manifest. `git diff --check` passes.
- Runtime phone interaction and visual acceptance remain unverified in this
  session. Check summary alignment, large text, optional cards/links, modal
  dismissal and restored customization preferences on a device.

## Distribution

Source: `/tmp/clockin-today-18/source`.
Archive: `/tmp/clockin-today-18/Clockin.xcarchive`.
TestFlight upload succeeded on 2026-09-21 at 15:31 Europe/Istanbul.
Build ID: `842edbe1-6e74-458d-97ea-f15623507d2d`. English and Turkish test notes
saved; tester notification enabled at submission. Verified 0.2 (18) as **Testing**
on both Clockin Public Beta and Clockin Internal group Builds pages on 2026-09-21.
