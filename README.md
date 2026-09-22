# Clockin for iPhone

A time tracker for people paid by the hour. Start the clock and the money
counts up with it, on the Lock Screen and in the Dynamic Island as well as in
the app, so the answer to "what have I earned today" never needs the app
reopened.

Written in SwiftUI for iOS 17 and later. Shipping on TestFlight as 0.2.

## What it does

- **A running clock that shows money.** Hourly rate schedules with start dates,
  USD with a Turkish lira equivalent, and a session that keeps counting across
  relaunches.
- **Widgets and a Live Activity.** Home screen and Lock Screen widgets, a Live
  Activity with pause and clock out controls, and Control Center controls.
  A small push service keeps the amount current while the app is closed.
- **History that reads like a timesheet.** Pageable by week, month or six
  months, grouped by day, with a chart, monthly goals and pace. Imports a
  timecard CSV or pasted timecard text and refuses to double a day.
- **Focus chimes and radio.** Eight synthesised chimes on an interval you pick,
  plus internet radio while you work.
- **A companion.** A pixel mascot that reacts to the work, levels up, earns
  focus coins, and has a wardrobe and a room you can arrange.

## Requirements

Xcode with the iOS 18 SDK or later. The app targets iOS 17. Running on a real
iPhone needs a development team set in Xcode; the project does not define one.

## Build and run

```bash
xcodebuild -project Clockin.xcodeproj -scheme Clockin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData build
xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/Clockin.app
xcrun simctl launch booted com.erdmncdr.clockin
```

## Layout

```text
Clockin.xcodeproj   targets: Clockin, ClockinWidgets
Clockin/            the app: screens, Shortcuts provider, icon
Clockin/Audio/      bundled focus chimes, in-app playback, notifications and focus radio
Clockin/Companion/  companion nudges and their scheduling
Clockin/Celebrations/  level ups, badges and their motion
Shared/Core/        store, models and importers
Shared/Sync/        App Group storage, widget snapshot, Live Activity state
Shared/Mascot/      motion engine, drawn frames, wardrobe and room layout
Shared/Intents/     clock in, clock out, pause
ClockinWidgets/     widget and Live Activity
Tools/              scripts that generate the art and the chime sounds
Tests/manual/       dependency-free checks
docs/               implementation notes
```

`docs/implementation-notes.md` covers the parts that are decided rather than
obvious: platform limits, the chime and radio, the companion's moods and
motion, and the wardrobe. `PERFORMANCE.md` covers the rendering and battery
work, and `PARITY.md` tracks what the desktop version has that this one does
not.

## Origin

Clockin began as a macOS app built with a collaborator. This iPhone version is
a separate application written for the phone: its screens, widgets, Live
Activity, companion and check suite are new here. `Shared/Core`, the store,
models and importers, started as a port of that macOS core and has grown apart
from it since. That macOS app is MIT licensed and its notice is kept in
`NOTICE.md`.

## License

[PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0).
Read it, build it, change it, share it, for any purpose that is not commercial.
Commercial use needs permission. The full terms are in `LICENSE`.

## Checks

Each check prints `ok` lines and exits non-zero on the first failure. Run from this folder.

```bash
swiftc -swift-version 6 -strict-concurrency=complete -D WIDGET_EXTENSION -module-cache-path /tmp/clockin-wardrobe-cache Shared/Mascot/MascotMotion.swift Shared/Mascot/MascotFrames.swift Shared/Mascot/WardrobeArt.swift Shared/Mascot/CompanionAccessory.swift Clockin/Celebrations/CelebrationRules.swift Shared/Core/Models.swift Shared/Core/WardrobeBackup.swift Shared/Mascot/Wardrobe.swift Shared/Mascot/WardrobePalette.swift Shared/Mascot/WardrobeCatalog.swift Clockin/Views/Goals/GoalProgress.swift Clockin/Views/Insights/InsightsSnapshot.swift Clockin/Views/Insights/InsightsBadges.swift Clockin/Views/Companion/WardrobeEarnings.swift Shared/Mascot/RoomArrangement.swift Shared/Mascot/RoomPlacement.swift Shared/Mascot/HomeSceneLayout.swift Shared/Mascot/HeritageArt.swift Tests/manual/wardrobe/main.swift -o /tmp/clockin-wardrobe-tests && /tmp/clockin-wardrobe-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-radio-module-cache Clockin/Audio/RadioStation.swift Tests/manual/radio/main.swift -o /tmp/clockin-radio-tests && /tmp/clockin-radio-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-celebrate-module-cache Shared/Mascot/CompanionAccessory.swift Clockin/Celebrations/CelebrationRules.swift Tests/manual/celebrations/main.swift -o /tmp/clockin-celebration-tests && /tmp/clockin-celebration-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-rolling-module-cache Clockin/Views/Components/RollingNumber.swift Tests/manual/rolling/main.swift -o /tmp/clockin-rolling-tests && /tmp/clockin-rolling-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-haptics-module-cache Shared/Theme/HapticEvent.swift Tests/manual/haptics/main.swift -o /tmp/clockin-haptics-tests && /tmp/clockin-haptics-tests
swiftc -swift-version 6 -strict-concurrency=complete Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/snapshot/main.swift -o /tmp/clockin-snapshot-tests && /tmp/clockin-snapshot-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/WardrobeBackup.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/import/main.swift -o /tmp/clockin-import-tests && /tmp/clockin-import-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/WardrobeBackup.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/backups/main.swift -o /tmp/clockin-backup-tests && /tmp/clockin-backup-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/SessionOverlap.swift Tests/manual/overlap/main.swift -o /tmp/clockin-overlap-tests && /tmp/clockin-overlap-tests
swiftc -swift-version 6 Shared/Core/ExchangeRates.swift Tests/manual/raterange/main.swift -o /tmp/clockin-ratedate-tests && TZ=Europe/Istanbul /tmp/clockin-ratedate-tests
swiftc -swift-version 6 Shared/Core/Models.swift Clockin/Views/Earnings/EarningsPeriod.swift Clockin/Views/Earnings/EarningsSnapshot.swift Clockin/Views/Earnings/MonthPerformance.swift Clockin/Views/Goals/GoalProgress.swift Clockin/Views/Insights/InsightsSnapshot.swift Clockin/Views/Insights/InsightsBadges.swift Clockin/Views/Insights/MonthWeek.swift Tests/manual/earnings/main.swift -o /tmp/clockin-earnings-tests && /tmp/clockin-earnings-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-historytry-module-cache Shared/Core/Models.swift Shared/Core/ExchangeRates.swift Clockin/Views/Earnings/EarningsPeriod.swift Clockin/Views/Earnings/EarningsSnapshot.swift Clockin/Views/Earnings/MonthPerformance.swift Clockin/Views/Goals/GoalProgress.swift ClockinWidgets/ReadyWidgetPlacement.swift Clockin/Views/Insights/MonthWeek.swift Tests/manual/historytry/main.swift -o /tmp/clockin-historytry-tests && /tmp/clockin-historytry-tests
swiftc -swift-version 6 Shared/Core/Models.swift Clockin/Views/Goals/GoalProgress.swift Clockin/Views/Insights/InsightsSnapshot.swift Clockin/Views/Insights/InsightsBadges.swift Clockin/Views/Insights/InsightsPeriods.swift Clockin/Views/Insights/MonthWeek.swift Tests/manual/insights/main.swift -o /tmp/clockin-insights-tests && /tmp/clockin-insights-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-mascot-module-cache Shared/Core/Models.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift Shared/Mascot/MascotMotion.swift Shared/Mascot/MascotState.swift Tests/manual/mascot/main.swift -o /tmp/clockin-mascot-tests && /tmp/clockin-mascot-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-mascot2-module-cache Shared/Core/Models.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift Shared/Mascot/MascotMotion.swift Shared/Mascot/MascotState.swift Shared/Mascot/CompanionAccessory.swift Clockin/Celebrations/CelebrationRules.swift Tests/manual/companion2/main.swift -o /tmp/clockin-companion2-tests && /tmp/clockin-companion2-tests
swiftc -swift-version 6 Clockin/Views/Mascot/CompanionMode.swift Tests/manual/companion/main.swift -o /tmp/clockin-companion-tests && /tmp/clockin-companion-tests
swiftc -swift-version 6 Clockin/Views/Momentum/MoneyMomentum.swift Tests/manual/momentum/main.swift -o /tmp/clockin-momentum-tests && /tmp/clockin-momentum-tests
swiftc -swift-version 6 Clockin/Views/Share/ShareStatsFields.swift Tests/manual/share/main.swift -o /tmp/clockin-share-tests && /tmp/clockin-share-tests
swiftc -swift-version 6 Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/widgettheme/main.swift -o /tmp/clockin-widgettheme-tests && /tmp/clockin-widgettheme-tests
swiftc -swift-version 6 Clockin/Audio/ChimeSchedule.swift Tests/manual/chime/main.swift -o /tmp/clockin-chime-tests && /tmp/clockin-chime-tests
swiftc -swift-version 6 -strict-concurrency=complete Clockin/Audio/FocusChimeSound.swift Tests/manual/chimesound/main.swift -o /tmp/clockin-chimesound-tests && /tmp/clockin-chimesound-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-controls-module-cache Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift ClockinWidgets/ClockinControlState.swift Tests/manual/controls/main.swift -o /tmp/clockin-controls-tests && /tmp/clockin-controls-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-reminder-module-cache Shared/Core/Models.swift Clockin/Audio/LongSessionReminderSchedule.swift Tests/manual/reminder/main.swift -o /tmp/clockin-reminder-tests && /tmp/clockin-reminder-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-nudges-module-cache Shared/Core/Models.swift Clockin/Companion/NudgePlanner.swift Clockin/Companion/NudgeCopy.swift Tests/manual/nudges/main.swift -o /tmp/clockin-nudges-tests && /tmp/clockin-nudges-tests
swiftc -swift-version 6 Clockin/Views/Goals/GoalProgress.swift Clockin/Views/Goals/DecimalEditing.swift Tests/manual/goals/main.swift -o /tmp/clockin-goals-tests && /tmp/clockin-goals-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/WardrobeBackup.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/sessions/main.swift -o /tmp/clockin-sessions-tests && /tmp/clockin-sessions-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/WardrobeBackup.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/ClockinSnapshot.swift Shared/Sync/ClockinSnapshot+Store.swift Tests/manual/rates/main.swift -o /tmp/clockin-rates-tests && /tmp/clockin-rates-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/WardrobeBackup.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/ClockinSnapshot.swift Shared/Sync/ClockinSnapshot+Store.swift Tests/manual/feedback/main.swift -o /tmp/clockin-feedback-tests && /tmp/clockin-feedback-tests
swiftc -swift-version 6 -strict-concurrency=complete Shared/Core/Models.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Tests/manual/sessiondisplay/main.swift -o /tmp/clockin-sessiondisplay-tests && /tmp/clockin-sessiondisplay-tests
```

The rolling check covers right-indexed glyph diffs, length changes, timer carries,
increasing/decreasing semantic values, prefix/suffix currencies, Turkish formatting,
all combinations of the motion/power/thermal/visibility policy, and the UIKit renderer's
update lifecycle, interruption, restyling, detachment, intrinsic sizing and baseline
alignment. Device CPU and
visual checks for the rolling digits are described in `PERFORMANCE.md`.

USD accounts can select TRY in History to change all money values on that page.
The choice is saved as `Clockin.HistoryShowsTRY` (USD by default). Each session
uses its start calendar day's rate, falling back to the nearest earlier rate.
Totals, averages and projections sum those historical amounts. Missing rates
keep the affected rows, days, totals or projections in USD, with one
"Some rates are unavailable" note. TRY charts omit days without rates, or months containing such days; when no
day has a rate, the chart falls back to USD. A compact secondary line shows the other
currency where available. No stored earnings or app currency setting changes.

The historytry check uses synthetic sessions and rates to cover exact and missing
days, nearest-earlier fallback, no rates, mixed availability, rows/day/month sums,
active sessions, averages and projections, and the widget's collision clamp.
Page calculations and rate lookups are cached, including missing lookup results.
Currency selection reuses both cached amounts and animates totals once.

For the medium widget, compare Ready at 321 by 152 pt, normal and maximum honored
text size (xLarge), and a long amount. Its text shares the full-width button's
center unless the 80 pt companion plus 8 pt gap requires a minimal right shift.
The two-column Working and Paused layouts remain unchanged. Previews include
these states and the narrow Ready cases. Widget updates have no transitions.

History opens on the current calendar month by default. The last range is saved,
but its page is not. W uses the calendar's first weekday; M starts on the 1st.
6M uses six-month blocks ending in the current month, with one bar per month;
previous pages cover the preceding six months. All is not pageable. Range changes
keep the selected page's anchor date. Totals and the session list follow the page.

The earnings check also covers calendar boundaries, DST, paging, range anchoring,
monthly totals, worked-day averages, the shared Insights pace, shorter-month
comparisons, cumulative/target series, gesture thresholds and goal prompt rules.
The projection adds the completed-work average of the last 7 days for each day
after today. Prior months show final totals, compared with the current goal.

On a simulator, verify History's horizontal swipe and chevrons, its forward limit,
vertical scrolling started over the chart, day taps, empty pages, range switching,
USD/TRY, large text, VoiceOver and Reduce Motion. Verify that Set goals opens
Insights with Edit goals expanded and Daily focused, including when Insights was
previously scrolled down. With no completed sessions, check both idle and running
states; the reminder should appear only after the first completed session.

Build 7 feedback checks: on a fresh History launch, compare the first swipe,
the next swipe, and both chevrons with populated and empty pages in W, M and
6M. Bars cross-fade for 0.22 seconds; the period header and totals keep their
numeric transitions. Repeat after selecting a bar, changing range, and enabling
Reduce Motion. A minute refresh must not trigger the page transition.

History roll regression: use synthetic sessions on two adjacent pages with
different totals and different day-section counts, followed by an empty page.
On a fresh launch, check populated to populated, populated to empty, empty to
populated and the return to the initial page, using swipes and both chevrons.
The title, earnings, duration and completed count must roll together; monthly
summary metrics also roll. Charts cross-fade without sliding, and session rows
update without moving into place. Repeat in W, M and 6M, after a chart selection,
and with Reduce Motion. Verify Edit and Delete swipe actions after paging.
The earnings check covers this populated/empty round trip's titles, page IDs,
session counts and totals; it does not verify SwiftUI animation frames.

In Insights, edit each goal, tap between cards, tap a heatmap cell or picker,
and drag the keyboard down. Controls must still respond, and each edit must
commit once. Done stays below the focused field; opening the keyboard scrolls
that row into view. Also try switching fields, collapsing Edit goals, leaving
the tab, large text, and the Today > Set goals shortcut while scrolled down.
Repeat outside taps on Settings > Pay's two rates and the rate period sheet.
The goals check covers focus hit regions and the single-commit guard. The
session display check uses synthetic sources and verifies neutral labels,
notes, corrections, and unchanged source metadata after a Codable round trip.

`PARITY.md` compares the two apps: what is shared, what only one of them has,
and what differs on purpose.

