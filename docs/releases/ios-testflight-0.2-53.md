# iOS 0.2 (53): Font setting and rolling-text fix

Repository: `erdmncdr/clockin-ios`. Source: main at `9fdec2b`. Everything from 0.2 (52).

- Font is a separate, device-local setting (System for everyone; themes set colors
  only), applied to the app, widgets and the Live Activity (Codex 29).
- Rolling-digit labels no longer clip their last letter (Codex 30).
- The same day the Live Activity relay was restored on Netlify (it had been removed
  by the 2026-10-01 website deploys; see `website/tools/deploy`). The What to Test
  note tells testers to open Clockin or restart the timer if the Dynamic Island
  stopped updating.
- Uploaded 2026-10-03 15:14 (+03); What to Test in English and Turkish; added to
  Clockin Internal and Clockin Public Beta; beta review submitted, external state
  IN_BETA_TESTING; tester notification on.
- No new TestFlight crash feedback since 0.2 (51) (last report 2026-10-01 10:21Z,
  the launch crash fixed in 52).
