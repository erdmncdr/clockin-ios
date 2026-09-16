# Clockin for iPhone

The iPhone version of Clockin: the same time tracker as the Mac app, with a
home screen and lock screen widget, a Live Activity while the timer runs, and
Shortcuts actions for clocking in and out.

It keeps its own data on the phone and does not sync with the Mac app. History
comes in the same way it does on the Mac, from a timecard CSV or pasted
timecard text, and Settings can export a full backup.

## Build and run

Requires Xcode with the iOS 18 SDK or later; the app supports iOS 17. From this folder:

```bash
xcodebuild -project Clockin.xcodeproj -scheme Clockin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData build
xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/Clockin.app
xcrun simctl launch booted com.erdmncdr.clockin
```

Running on a real iPhone needs a development team set in Xcode; the project
does not define one.

## Layout

```text
Clockin.xcodeproj   targets: Clockin, ClockinWidgets
Clockin/            the app: screens, Shortcuts provider, icon
Clockin/Audio/      focus chime (local notifications) and focus radio
Shared/Core/        store, models and importers, ported from ../Sources/Clockin
Shared/Sync/        App Group storage, widget snapshot, Live Activity state
Shared/Mascot/      shared motion engine, drawn frames and widget still loader
Shared/Intents/     clock in, clock out, pause
ClockinWidgets/     widget and Live Activity
Tests/manual/       dependency-free checks
```

`Shared/Core` started as a copy of the Mac sources. Fixes to shared logic have
to be carried across by hand, for example:

```bash
diff ../Sources/Clockin/ClockStore.swift Shared/Core/ClockStore.swift
```

## Checks

Each check prints `ok` lines and exits non-zero on the first failure. Run from this folder.

```bash
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-haptics-module-cache Shared/Theme/HapticEvent.swift Tests/manual/haptics/main.swift -o /tmp/clockin-haptics-tests && /tmp/clockin-haptics-tests
swiftc -swift-version 6 -strict-concurrency=complete Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/snapshot/main.swift -o /tmp/clockin-snapshot-tests && /tmp/clockin-snapshot-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/import/main.swift -o /tmp/clockin-import-tests && /tmp/clockin-import-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/backups/main.swift -o /tmp/clockin-backup-tests && /tmp/clockin-backup-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/SessionOverlap.swift Tests/manual/overlap/main.swift -o /tmp/clockin-overlap-tests && /tmp/clockin-overlap-tests
swiftc -swift-version 6 Shared/Core/ExchangeRates.swift Tests/manual/raterange/main.swift -o /tmp/clockin-ratedate-tests && TZ=Europe/Istanbul /tmp/clockin-ratedate-tests
swiftc -swift-version 6 Shared/Core/Models.swift Clockin/Views/Earnings/EarningsPeriod.swift Clockin/Views/Earnings/EarningsSnapshot.swift Clockin/Views/Earnings/MonthPerformance.swift Clockin/Views/Goals/GoalProgress.swift Clockin/Views/Insights/InsightsSnapshot.swift Clockin/Views/Insights/InsightsBadges.swift Tests/manual/earnings/main.swift -o /tmp/clockin-earnings-tests && /tmp/clockin-earnings-tests
swiftc -swift-version 6 Shared/Core/Models.swift Clockin/Views/Goals/GoalProgress.swift Clockin/Views/Insights/InsightsSnapshot.swift Clockin/Views/Insights/InsightsBadges.swift Clockin/Views/Insights/InsightsPeriods.swift Tests/manual/insights/main.swift -o /tmp/clockin-insights-tests && /tmp/clockin-insights-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-mascot-module-cache Shared/Core/Models.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift Shared/Mascot/MascotMotion.swift Shared/Mascot/MascotState.swift Tests/manual/mascot/main.swift -o /tmp/clockin-mascot-tests && /tmp/clockin-mascot-tests
swiftc -swift-version 6 Clockin/Views/Mascot/CompanionMode.swift Tests/manual/companion/main.swift -o /tmp/clockin-companion-tests && /tmp/clockin-companion-tests
swiftc -swift-version 6 Clockin/Views/Momentum/MoneyMomentum.swift Tests/manual/momentum/main.swift -o /tmp/clockin-momentum-tests && /tmp/clockin-momentum-tests
swiftc -swift-version 6 Clockin/Views/Share/ShareStatsFields.swift Tests/manual/share/main.swift -o /tmp/clockin-share-tests && /tmp/clockin-share-tests
swiftc -swift-version 6 Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/widgettheme/main.swift -o /tmp/clockin-widgettheme-tests && /tmp/clockin-widgettheme-tests
swiftc -swift-version 6 Clockin/Audio/ChimeSchedule.swift Tests/manual/chime/main.swift -o /tmp/clockin-chime-tests && /tmp/clockin-chime-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-controls-module-cache Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift ClockinWidgets/ClockinControlState.swift Tests/manual/controls/main.swift -o /tmp/clockin-controls-tests && /tmp/clockin-controls-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-reminder-module-cache Shared/Core/Models.swift Clockin/Audio/LongSessionReminderSchedule.swift Tests/manual/reminder/main.swift -o /tmp/clockin-reminder-tests && /tmp/clockin-reminder-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-nudges-module-cache Shared/Core/Models.swift Clockin/Companion/NudgePlanner.swift Clockin/Companion/NudgeCopy.swift Tests/manual/nudges/main.swift -o /tmp/clockin-nudges-tests && /tmp/clockin-nudges-tests
swiftc -swift-version 6 Clockin/Views/Goals/GoalProgress.swift Tests/manual/goals/main.swift -o /tmp/clockin-goals-tests && /tmp/clockin-goals-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/sessions/main.swift -o /tmp/clockin-sessions-tests && /tmp/clockin-sessions-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/ClockinSnapshot.swift Shared/Sync/ClockinSnapshot+Store.swift Tests/manual/rates/main.swift -o /tmp/clockin-rates-tests && /tmp/clockin-rates-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/ClockinSnapshot.swift Shared/Sync/ClockinSnapshot+Store.swift Tests/manual/feedback/main.swift -o /tmp/clockin-feedback-tests && /tmp/clockin-feedback-tests
```

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

`PARITY.md` compares the two apps: what is shared, what only one of them has,
and what differs on purpose.

## Platform notes

Things that cost time to find and are easy to break again:

- **Live Activity values.** A Live Activity only advances time by itself.
  Earnings change when the app sends an update, so the app refreshes it on
  launch, when going to the background and from its buttons.
- **Hours and minutes in the Dynamic Island.** `Text(timerInterval:)` always
  shows seconds, and the timer and stopwatch format styles spell minutes out as
  words. On iOS 18, `Text(.durationOffset(to:), format:
  Duration.TimeFormatStyle(pattern: .hourMinute(...)))` shows `02:45` and keeps
  advancing.
- **One store.** The app, widgets, Shortcuts and Live Activity buttons all use
  `SharedStore.clock`. Separate instances would write the same file without
  seeing each other's changes. `SessionMirror` updates the widget, the Live
  Activity, the chime, companion nudges and the long session reminder from
  store changes rather than from views, because Shortcuts can run with no
  screen loaded.
- **Swipe to delete with confirmation.** Do not give the button
  `role: .destructive`: `List` removes the row before the alert is answered.
- **Sheets and color scheme.** `preferredColorScheme` applies to the nearest
  presentation, so every sheet, nested ones included, sets it again.
- **Shortcuts in the simulator.** An ad-hoc signed build shows the App
  Shortcuts in Spotlight, but `linkd` refuses to run them without a team ID.
  Widget and Live Activity buttons are not affected.
- **App Group in the simulator.** `codesign -d --entitlements` does not list
  the group for simulator builds; check with
  `xcrun simctl get_app_container booted com.erdmncdr.clockin groups`.
