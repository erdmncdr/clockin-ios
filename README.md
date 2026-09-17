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
Clockin/Audio/      bundled focus chimes, in-app playback, notifications and focus radio
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
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-rolling-module-cache Clockin/Views/Components/RollingNumber.swift Tests/manual/rolling/main.swift -o /tmp/clockin-rolling-tests && /tmp/clockin-rolling-tests
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
swiftc -swift-version 6 -strict-concurrency=complete Clockin/Audio/FocusChimeSound.swift Tests/manual/chimesound/main.swift -o /tmp/clockin-chimesound-tests && /tmp/clockin-chimesound-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-controls-module-cache Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift ClockinWidgets/ClockinControlState.swift Tests/manual/controls/main.swift -o /tmp/clockin-controls-tests && /tmp/clockin-controls-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-reminder-module-cache Shared/Core/Models.swift Clockin/Audio/LongSessionReminderSchedule.swift Tests/manual/reminder/main.swift -o /tmp/clockin-reminder-tests && /tmp/clockin-reminder-tests
swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-nudges-module-cache Shared/Core/Models.swift Clockin/Companion/NudgePlanner.swift Clockin/Companion/NudgeCopy.swift Tests/manual/nudges/main.swift -o /tmp/clockin-nudges-tests && /tmp/clockin-nudges-tests
swiftc -swift-version 6 Clockin/Views/Goals/GoalProgress.swift Clockin/Views/Goals/DecimalEditing.swift Tests/manual/goals/main.swift -o /tmp/clockin-goals-tests && /tmp/clockin-goals-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/sessions/main.swift -o /tmp/clockin-sessions-tests && /tmp/clockin-sessions-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/ClockinSnapshot.swift Shared/Sync/ClockinSnapshot+Store.swift Tests/manual/rates/main.swift -o /tmp/clockin-rates-tests && /tmp/clockin-rates-tests
swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Shared/Theme/ClockinThemeChoice.swift Shared/Sync/ClockinSnapshot.swift Shared/Sync/ClockinSnapshot+Store.swift Tests/manual/feedback/main.swift -o /tmp/clockin-feedback-tests && /tmp/clockin-feedback-tests
swiftc -swift-version 6 -strict-concurrency=complete Shared/Core/Models.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Tests/manual/sessiondisplay/main.swift -o /tmp/clockin-sessiondisplay-tests && /tmp/clockin-sessiondisplay-tests
```

The rolling check covers right-indexed glyph diffs, length changes, timer carries,
increasing/decreasing semantic values, prefix/suffix currencies, Turkish formatting,
all combinations of the motion/power/thermal/visibility policy, and the UIKit renderer's
update lifecycle, interruption, restyling, detachment, intrinsic sizing and baseline
alignment. Device CPU and
visual checks for the rolling digits are described in `PERFORMANCE.md`.

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

## Focus chime sounds

The eight original sounds are synthesized from sine partials and deterministic
filtered noise. No recordings, Apple sound files or third-party packages are used.
Regenerate from the repository root:

```bash
swift iOS/Tools/make-chime-sounds.swift
```

The script writes 16-bit linear PCM CAF files at 44.1 kHz, mono, into
`iOS/Clockin/Audio/Sounds/` and a waveform/spectrum preview to
`/tmp/clockin-chime-preview.png`. It reads the files back, prints peak and full-file
RMS in dBFS, and checks duration, format, headroom, zero endpoints, high-frequency
energy and an RMS spread of no more than 3 dB. The sound catalog check above also
verifies every catalog entry has a corresponding decodable CAF. To check a built
bundle, pass its path to `/tmp/clockin-chimesound-tests`.

If a sandbox blocks the default Swift module cache, prefix Swift commands with
`CLANG_MODULE_CACHE_PATH=/tmp/clockin-chime-module-cache`.

Sound ids are stored in `Clockin.ChimeSound`. Existing ids remain unchanged;
legacy `Glass` becomes `glass`; missing, unknown and all other legacy names
become `chime`. `Clockin.ChimeVolume` uses the Mac's fractional 0.1-1.0 range,
defaulting to 0.75. Invalid nonfinite values use the default.

Preview and foreground chimes use AVAudioPlayer; foreground delivery keeps the
banner but suppresses notification audio so there is only one sound. Standalone
chimes use an ambient session and respect the silent switch. Focus radio owns
the shared playback session while running, so chimes borrow that session without
changing its category or deactivating it; during radio playback they can sound in
silent mode. Starting or stopping the radio ends an in-progress chime before the
radio changes session ownership. Background notifications use the bundled sound
at the system volume. Reminder/nudge reservations and worked-time refresh stay
unchanged.

On a real iPhone, verify Preview with notifications denied, selection auto-preview,
10/75/100% volume, silent switch, another app's music, radio start/stop during a
preview, interruption/headphone removal, and one foreground/background interval.
Confirm one sound with a banner in the foreground, selected sound in the
background, and no pending chimes after pausing or ending from a widget/Shortcut.

## Companion mood artwork

Generate the tired (`z*`), proud (`p*`) and four `acc-*` full-frame accessories
from the repository root, without building the app:

```bash
swift iOS/Tools/make-mood-frames.swift
```

The generator detects the source art's pixel unit, eyes, visor and core, preserves
blink silhouettes, and verifies decoded RGBA and alpha outside the edited regions.
It prints changed image pixels and touched art-grid cells for each output. The
labeled preview is `/tmp/clockin-mood-frames.png`, with native, 62/32 pixel and
62/32 point @2x samples, plus blink frames. All scaling uses nearest neighbor.
The clip manifest is left for the separate app integration task.

Run the dependency-free file, dimensions, alpha and frame-number check from
this `iOS` folder:

```bash
swift Tests/manual/moodart/main.swift
```

Both commands accept `-module-cache-path /tmp/clockin-art-module-cache` immediately
after `swift` when the default compiler cache is unavailable in a sandbox.
