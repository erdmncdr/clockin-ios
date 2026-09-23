# iOS 0.2 (17): one Progress home

Goals & Pace was a subtle link inside another goals card, with a second goal
editor in Insights and an unrelated hour forecast in History. Progress now owns
Goals, Reports and Badges through a persistent segmented selector. The root tab
bar has Today, History and Progress; the initial Progress section is Goals.

## Screen responsibilities

- Today: session controls, current work and a compact daily goal. Its explicit
  “View goals & pace” action opens Progress > Goals. Set goals scrolls to the
  single plan editor and requests Daily focus.
- Goals: monthly and daily progress, visible goal fields, weekly workday count,
  recommendations, month-end outlook and daily hours. Uses the existing local
  preferences and MonthlyWorkPlan calculation. Daily-only users can see daily
  progress and the daily chart without configuring a monthly plan.
- Reports: heatmap, rhythm, totals, records and stats sharing, without another
  goal editor or target forecast.
- Badges: level, ranks, streaks, badges and companion entry. Today level links
  and celebration badge links select this section directly.
- History: period records, editing, actual hours and currency-aware earnings.
  Its separate monthly hour goal/projection is removed. Currency conversion,
  earnings projection and previous-period comparison are preserved.

One NavigationStack owns Progress. The embedded Reports and Badges views do not
create nested stacks. Goal fields retain commit-on-focus-loss behavior and clear
focus when leaving Goals. Release integration retains cached celebration
snapshots, sheet blockers, rank gallery, companion UI and animation visibility.

## Verification

- 28 MonthlyWorkPlan checks and 42 goal/decimal-editing checks pass.
- Signed Release archive succeeds without compiler warnings or errors.
- App and widget metadata both read 0.2 (17); strict deep codesign check passes.
- All 335 files match the frozen release source manifest.
- `git diff --check` passes.
- Real-device interaction and visual acceptance remain unverified. The computer
  use surface did not expose a working Simulator/Device Hub window. Test section
  switching, keyboard focus/commit, share and badge/companion sheet returns,
  and large text on a phone; compilation alone is not interaction proof.

## Distribution

Release source: `/tmp/clockin-progress-17-final/source`.
Archive: `/tmp/clockin-progress-17-final/Clockin.xcarchive`.
Upload succeeded on 2026-09-21 at 15:03 Europe/Istanbul.
Build ID: `3770c3e5-71a9-4ff3-aa6c-a4f12c63d0b7`. English and Turkish test notes
saved; tester notification enabled at submission. Both Clockin Public Beta and
Clockin Internal group build pages visibly show 0.2 (17) as **Testing**, verified
on 2026-09-21.
