# Clockin for iPhone

The iPhone version of Clockin: the same time tracker as the Mac app, with a
home screen and lock screen widget, a Live Activity while the timer runs, and
Shortcuts actions for clocking in and out.

It keeps its own data on the phone and does not sync with the Mac app. History
comes in the same way it does on the Mac, from a timecard CSV or pasted
timecard text, and Settings can export a full backup.

## Build and run

Requires Xcode with the iOS 17 SDK or later. From this folder:

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
swiftc -swift-version 6 -strict-concurrency=complete Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/snapshot/main.swift -o /tmp/clockin-snapshot-tests && /tmp/clockin-snapshot-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/import/main.swift -o /tmp/clockin-import-tests && /tmp/clockin-import-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/backups/main.swift -o /tmp/clockin-backup-tests && /tmp/clockin-backup-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/SessionOverlap.swift Tests/manual/overlap/main.swift -o /tmp/clockin-overlap-tests && /tmp/clockin-overlap-tests
swiftc -swift-version 6 Shared/Core/ExchangeRates.swift Tests/manual/raterange/main.swift -o /tmp/clockin-ratedate-tests && TZ=Europe/Istanbul /tmp/clockin-ratedate-tests
swiftc -swift-version 6 Shared/Core/Models.swift Clockin/Views/Earnings/EarningsSnapshot.swift Tests/manual/earnings/main.swift -o /tmp/clockin-earnings-tests && /tmp/clockin-earnings-tests
swiftc -swift-version 6 Shared/Core/Models.swift Clockin/Views/Insights/InsightsSnapshot.swift Clockin/Views/Insights/InsightsBadges.swift Clockin/Views/Insights/InsightsPeriods.swift Tests/manual/insights/main.swift -o /tmp/clockin-insights-tests && /tmp/clockin-insights-tests
swiftc -swift-version 6 Clockin/Views/Mascot/CompanionMode.swift Tests/manual/companion/main.swift -o /tmp/clockin-companion-tests && /tmp/clockin-companion-tests
swiftc -swift-version 6 Clockin/Views/Momentum/MoneyMomentum.swift Tests/manual/momentum/main.swift -o /tmp/clockin-momentum-tests && /tmp/clockin-momentum-tests
swiftc -swift-version 6 Clockin/Views/Share/ShareStatsFields.swift Tests/manual/share/main.swift -o /tmp/clockin-share-tests && /tmp/clockin-share-tests
swiftc -swift-version 6 Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/widgettheme/main.swift -o /tmp/clockin-widgettheme-tests && /tmp/clockin-widgettheme-tests
swiftc -swift-version 6 Clockin/Audio/ChimeSchedule.swift Tests/manual/chime/main.swift -o /tmp/clockin-chime-tests && /tmp/clockin-chime-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-reminder-module-cache Shared/Core/Models.swift Clockin/Audio/LongSessionReminderSchedule.swift Tests/manual/reminder/main.swift -o /tmp/clockin-reminder-tests && /tmp/clockin-reminder-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-nudges-module-cache Shared/Core/Models.swift Clockin/Companion/NudgePlanner.swift Clockin/Companion/NudgeCopy.swift Tests/manual/nudges/main.swift -o /tmp/clockin-nudges-tests && /tmp/clockin-nudges-tests
swiftc -swift-version 6 Clockin/Views/Goals/GoalProgress.swift Tests/manual/goals/main.swift -o /tmp/clockin-goals-tests && /tmp/clockin-goals-tests
```

`PARITY.md` compares the two apps: what is shared, what only one of them has,
what differs on purpose, and Mac issues still open.

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
