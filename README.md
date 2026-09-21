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
silent mode. Starting the radio ends an in-progress chime before taking session
ownership. Stopping the radio lets an in-progress chime finish using the ambient
category without reactivating the session; the chime then deactivates it.
Background notifications use the bundled sound at the system volume. Reminder/nudge reservations and worked-time refresh stay
unchanged.

On a real iPhone, verify Preview with notifications denied, selection auto-preview,
10/75/100% volume, silent switch, another app's music, radio start/stop during a
preview, interruption/headphone removal, and one foreground/background interval.
Confirm one sound with a banner in the foreground, selected sound in the
background, and no pending chimes after pausing or ending from a widget/Shortcut.

## Focus radio

Settings > Focus radio offers Radio Paradise (Main Mix), Mellow Mix, Global Mix
and Serenity (ambient). Both apps use the same station ids and names. The last
choice is saved in `Clockin.RadioStation`; missing or unknown ids use `rp`, the
main mix. Playback never starts automatically on launch or on a stopped station
selection. A switch while playing or connecting starts the new stream immediately;
a switch while paused stays paused until Play.

After Play, Today shows the station menu, play/pause and Stop below the timer
and companion. Connecting and failed attempts stay visible for cancellation or
retry. Stop removes the card. Volume stays in Settings. The card observes radio
state outside the Today timelines, with no timer or repeating animation.

Pause retains Now Playing at rate zero and keeps remote resume available.
Stop, failure, interruption and route loss clear Now Playing, mark it stopped,
remove and disable remote commands, detach the player item and release the player.
The existing stream monitor runs only while playback is requested and stops on
pause or any terminal path. Queued commands from an ended radio session are ignored.

The radio check covers the catalog, saved-id fallback, card visibility and cleanup
policy, including session ownership during a chime. It does not exercise system
media UI. On an iPhone, verify the following with synthetic work sessions:

1. Start each station in Settings, return to Today, switch stations and confirm
   the audio and Lock Screen title change. Repeat while connecting and paused.
2. Pause/resume from Today, Lock Screen and Control Center; verify the paused
   card persists and Now Playing stays resumable. Stop from Today and Settings;
   verify the card and radio Now Playing entry disappear and headset Play cannot
   restart it. Start again and verify each remote action runs once.
3. Disable the network, try Play, wait for the connection failure, and confirm
   system controls clear while Today offers retry. Restore the network and retry.
4. Try a call/interruption, headphone removal and stop while connecting. Confirm
   cleanup and no automatic restart after the interruption ends.
5. Preview a chime during radio playback, stop the radio during the sound, then
   preview again. Confirm completion, ambient/silent-switch behavior, and no
   restored radio metadata or remote commands. Repeat with other audio playing.
6. Relaunch: the station remains selected, playback and the card stay off. Check
   large text, VoiceOver, Haptics on/off, and a selection tick only on station changes.
## Companion celebrations (iPhone)

`CelebrationCenter` owns one event queue, backed by the pure `CelebrationRules`
and `CelebrationQueue`. `SessionMirror` feeds store changes; RootView's existing
foreground minute refresh supplies live progress. The level badge, Insights and
Badges read the shared snapshot instead of each computing it on a separate minute
loop. No celebration trigger runs from Today or Money Momentum's second ticks.
Live goal and money crossings can therefore appear at the next minute refresh.

The first observation seeds the current level and unlocked badge IDs silently.
Later launches compare against `Clockin.LastCelebratedLevel`; unseen badges use
`Clockin.SeenBadgeIDs`. A batch shows at most three badge banners, then one count.
RootView hosts the overlay above tabs and desk mode. Sheets, alerts and file pickers
block delivery, with a UIKit presentation check before showing. Share opens the
existing stats view. A badge banner opens Badges, leaving desk mode if needed.

The 2.5-second surfaces use a 0.2-second opacity transition. Level celebrations
sit in a centered, opaque themed card over a 45% black scrim that fades in over
0.15 seconds; the card scales from 0.9 to 1 unless Reduce Motion is enabled.
The card grows with Dynamic Type and scrolls when it exceeds the available height.
Tapping the card or scrim dismisses it. Underlying controls and accessibility stay
blocked through the exit fade. Badge banners retain their top placement with an
opaque themed card and a subtle scrim. Confetti sits above the card background,
below its content and buttons, and never receives touches. Confetti
uses a CAEmitterLayer with a finite 0.8-second birth-rate animation; the layer is
removed after its particles expire. Reactions use the shared layered companion host. Motion samples go to CA once;
existing clip tasks swap drawings only at authored frame boundaries. Reduce Motion uses a rest
frame and text. Turning off the companion keeps the same card without its mascot.
Live reactions have a shared 20-second gate, require a visible companion and active
app, and never replay
missed events. Tap reactions share the same gate.

The celebration check covers seeding, persisted levels and badge IDs, batches,
modal/background queueing, reaction crossings and cooldown, and presentation
variants. On a simulator, use synthetic data to cross a level in each tab and desk
mode, behind a sheet and alert, and across background/foreground and relaunch.
Check Share, banner navigation, interrupted dismissal, large text, VoiceOver,
Reduce Motion and companion off. On a phone, verify one success haptic for a level
and measure Today with a running session against the approximately 3% CPU target.
## Companion mood artwork

Generate the tired (`z*`), proud (`p*`) and four legacy `acc-*` full-frame accessories
from the repository root, without building the app:

```bash
swift iOS/Tools/make-mood-frames.swift
```

The generator detects the source art's pixel unit, eyes, visor and core, preserves
blink silhouettes, and verifies decoded RGBA and alpha outside the edited regions.
It prints changed image pixels and touched art-grid cells for each output. The
labeled preview is `/tmp/clockin-mood-frames.png`, with native, 62/32 pixel and
62/32 point @2x samples, plus blink frames. All scaling uses nearest neighbor.
The legacy `acc-*` files remain for compatibility tests; the app now uses layered wardrobe sprites.

Run the dependency-free file, dimensions, alpha and frame-number check from
this `iOS` folder:

```bash
swift Tests/manual/moodart/main.swift
```

Both commands accept `-module-cache-path /tmp/clockin-art-module-cache` immediately
after `swift` when the default compiler cache is unavailable in a sandbox.

## Companion moods, accessories and idle motion

Today, desk mode and the medium widget use the same session mood decision.
A four-second proud window takes priority, then working, then an existing Grumpy
angry nudge. Otherwise an idle companion is tired after at least two quiet calendar
days, which also covers a streak broken yesterday. Friendly ignores stale anger
and uses tired for that drift. Paused sessions keep coffee unless Grumpy applies;
a fresh account with no worked days stays hello. Tired and proud reuse hello's
clip IDs with `z`/`p` prefixes and its feet anchor. Missing frames fall back to the
matching hello drawing, then hello rest. Tired has no automatic hops and waits
3.5-6.5 seconds between drawn clips.

Pride follows a level celebration, badge unlock, daily goal crossing, or saving a
session with more than two hours of worked time (pauses excluded). It does not
follow cancellation, exactly two hours, an already reached goal or goal editing.
It is independent of the playful reaction cooldown. New achievements also write
the window to the widget snapshot; a covered app companion gets its window when
the sheet/alert closes. A level card uses proud. The widget precomputes a still
entry at pride expiry so it can return to its normal mood without an app timer.
WidgetKit controls reload delivery: a four-second expression can be skipped if
iOS delivers the reload after its deadline. The timestamp prevents stale pride.

The layered wardrobe below replaces the legacy Accessory picker and hello-rest
replacement drawings. Existing choices and seen accessory ownership migrate into
wardrobe slots. New ownership uses completed work, keeps the original hour
thresholds, and survives archive reductions. Wardrobe banners use the shared queue.

Standing motion uses a finite 5.2-second sway followed by 7.8 seconds with no sway
animation, one cycle every 13 seconds. Tired uses a 7.8-second sway at 45% amplitude
and a 12-second rest. Angry uses its existing short 0.66-second shake followed by
7.8 seconds of rest. The longer rests reduce continuous render-server work while
independent drawn clips and hops preserve life. CA removes each finished sway;
a cancellable task only wakes to start the next burst, not at every frame or at
the end of a burst. The ordinary clip and hop rhythms are unchanged.

Companion CA animations request 8-15 fps, preferred 12, for normal and tired
sway; angry shakes, hops (including shadow transform and opacity), pop, wiggle
and squash request 24-30 fps, preferred 30. Celebration reactions use the same layered host and 24-30 motion range. Groups and their children
receive the same range. Drawn clip durations and frame-swap key times are
unchanged. These are Core Animation requests; actual pacing and the idle
backboardd target below 3% still need measurement.

All companion motion uses the rolling digits' power/thermal policy: Reduce
Motion, Low Power Mode, serious/critical/unknown thermal state, inactive scenes
and covered or unselected content stop the clip task and remove CA animations.
Nominal and fair thermal states are allowed, matching the digits. Desk mode's
companion lives outside its second-ticking timer subtree. No measurements were
made for this change.

The `companion2` check above covers the catalog, thresholds, saved fallback,
rest-only drawing, progress strings, silent accessory seeding and queue lifecycle,
all tone/anger/streak/quiet-day/pride/session combinations, date boundaries, pride
triggers, shared widget fields, missing-frame fallback, the pure burst schedule
and animation frame rate ranges.
The existing rolling suite checks every combination of visibility, power, thermal
and Reduce Motion gates used by the companion.

Manual visual acceptance with synthetic sessions:

1. On Today and in desk mode, check no-history hello, working, paused, two quiet
   days and a three-day streak broken yesterday. Switch Friendly/Grumpy with
   notifications allowed and denied. Existing angry nudges should still win for
   Grumpy; Friendly drift should be tired. Repeat in the medium widget.
2. Cross a level, unlock a badge, reach a daily goal, and save 2h 1m of work.
   Check proud for about four seconds, then normal behavior. Repeat with a sheet
   or alert open, a running session, custom default mode, Reduce Motion, and
   companion off. Exactly 2h and cancellation must not trigger session pride.
   Verify the level card uses proud and widget pride never remains after expiry.
3. Save completed sessions crossing 25/50/100/250h. Check one New item banner
   and its Companion link. Test None, every owned choice, locked requirements,
   purchases, and ownership after restoring a smaller synthetic archive. On first
   launch with 100h, earned items seed silently with one Wardrobe unlocked banner.
4. Watch hello's blink, glow, antenna dip and hop with a layered accessory.
   It follows each drawn anchor and shares motion; hand items hide for null handR.
   Tired never hops automatically. Check small landscape, large text, VoiceOver,
   themes and rotation while Settings or Companion is presented.
5. For the before/after CPU and rendering comparison, follow the exact capture
   matrix in `PERFORMANCE.md` under Companion idle acceptance measurement.

## Wardrobe and home (iPhone only)

Today companion opens Companion; its text row opens Insights. Badges > Companion
and Settings also open the screen. Outfit, Home and Shop share `WardrobeCatalog.swift`.
All ids below are exact art basenames or JSON keys:

| Slot | IDs |
| --- | --- |
| Head | cap, headphones, antenna, crown, wizard-hat |
| Face | round-glasses, sunglasses |
| Neck | bow-tie, scarf |
| Back | cape, backpack, wings |
| Hand | mug, balloon |
| Colorway | classic, mint, sunset, midnight, gold, stealth |
| Room | cozy, studio, night |
| Furniture | cat-bed (floorLeft), big-plant (floorRight), poster (wallLeft), wall-clock (wallRight), potted-plant (window), round-rug (rug), desk-monitor (desk), bookshelf (shelf) |

Cap, round glasses, Classic and Cozy start free. The four legacy accessories keep
25/50/100/250-hour thresholds. Crown needs level 50, Wizard hat a historical 30-day
streak, Bow tie the First session badge. Purchase prices range from 50 to 1,500.
Missing manifest entries, images, anchors or room slots are omitted. Test fixtures
stay under Tests/manual/wardrobe/fixtures and are not app resources.
The merged art uses `cap` and `mug` for the original baseball-cap and coffee-mug
sprites; the generator also supplies the earned gold `antenna` overlay. Placeholder
shop entries now use the real `balloon`, `sunset` and furniture ids above.
Legacy fixed pose assets also
use the layered host and colorway decoder; without optional pose2/pose3/pose4
anchor entries they remain recolored without overlays, following the missing-anchor
rule.

Coins use completed sessions only: floor each duration to whole minutes, sum those
minutes, then floor the sum divided by six. Add 25 for each completed-work day
meeting the current daily goal, 50 per archive badge (historical longest streak
for streak badges), and 100 per level including level 1. Recomputing after archive
or goal edits may reduce available coins; owned items stay owned and the displayed
balance clamps to zero. No stored earned-coin counter exists.

`Clockin.WardrobeState` stores ownership, outfit, colorway, room, furniture and the
seed flag as JSON. `Clockin.WardrobeLedger` stores purchase id/cost/date JSON.
`Clockin.WardrobeShowHomeInDeskMode` defaults true. The legacy accessory preference
is migrated on first seed; Auto chooses the highest earned legacy item and None
keeps slots empty. Previously selected and seen legacy items retain ownership
even if the archive was reduced. Milestones seed silently with one Wardrobe unlocked banner.
Later unlocks use CelebrationCenter's queue, capped at three item banners plus a
summary. Equip/buy gives one reaction and one gated haptic.

Backups remain portable JSON. Export, automatic backups and before-restore copies
include an optional top-level `wardrobe` section without changing `ClockinData` or
the live archive format. That section holds the two preference JSON strings and
the desk toggle. Existing decoders ignore it. Restoring an older file without the
section preserves the local wardrobe. Settings export now writes a backup rather
than sharing the raw archive. Widgets receive outfit JSON in their existing snapshot.

For device acceptance, verify Today, every drawn mood/clip, celebration cards and the
medium widget with a back item, hat, hand item and non-classic colorway. Check null
hand anchors, tilted head pivots, None, equip, purchase confirm/cancel, insufficient
funds, first launch migration, new unlock navigation and backup restore. Open each
room, place every furniture slot, rotate into desk mode and toggle its home setting.
Check VoiceOver and large text. Scroll the Companion header offscreen, dismiss it,
switch tabs, cover Today, and background the app: all live motion must stop. Compare
Today idle CPU with the existing baseline using PERFORMANCE.md's 120-second runs;
source/type checks do not establish the CPU or visual result.
## Companion wardrobe and home artwork

The wardrobe art contract lives in `Shared/Mascot/Frames/mascot-anchors.json`,
`Frames/colorways.json`, `Wardrobe/wardrobe-sprites.json` and
`Home/home-items.json`. The app and widget decode these same manifests.
Run these commands in order from the repository root:

```bash
swift -module-cache-path /tmp/clockin-art-module-cache iOS/Tools/make-mascot-anchors.swift
swift -module-cache-path /tmp/clockin-art-module-cache iOS/Tools/make-wardrobe.swift
swift -module-cache-path /tmp/clockin-art-module-cache iOS/Tools/make-home.swift
swift -module-cache-path /tmp/clockin-art-module-cache iOS/Tools/make-wardrobe-preview.swift
swift -module-cache-path /tmp/clockin-art-module-cache iOS/Tests/manual/wardrobeart/main.swift
```

The entry points invoke the shared `Tools/MascotArt.swift` engine with the system
Swift compiler through `Tools/run-art.swift`. The tools and runtime compile the
same `Shared/Mascot/WardrobePalette.swift`; Foundation, ImageIO and CoreGraphics
are the only art dependencies. New art is
rasterized on an integer art grid and expanded to 2x2 image pixels, with no
antialiasing. Assets are deterministic; the source frame PNGs remain untouched.
The wardrobe test also works from this `iOS` folder:

```bash
swift -module-cache-path /tmp/clockin-art-module-cache Tests/manual/wardrobeart/main.swift
```

The output includes 63 frame entries with anchors, 25 wardrobe items
(9 head, 4 face, 4 neck, 4 back, 4 hand), six colorways, three 360x240 rooms and
16 furniture items. The 59 numbered `h/t/c/e/a/z/p` frames and four older `acc-*` full-frame
composites are covered, since the latter also match the contract's `a*` prefix.
Legacy accessories keep h01's detected underlying pose; `acc-mug` marks its
occupied image-left hand null.

Geometry follows connected visor and shell contours, the torso and individual
knuckle lobes. Raised mug contours are clipped to the helmet region before visor
measurement. Dark coffee gloves use a separate color mask; a mug's round orange
emblem distinguishes occupied hands from free resting hands. Hidden typing hands
are null. Hand L/R means image left/right. Tilt is clockwise in top-left image
coordinates and comes from the upper visor contour.

Compositing uses `anchorPoint` from each wardrobe entry, not an inferred point
from its slot. Headphones use the visor anchor so both the upright and wider
three-quarter helmets fit inside their ear cups. All other head items use `head`.
Place each pivot on its anchor in image pixels, rotate head/face items by `tilt`
around that pivot, draw the back layer, then the recolored robot, then front items.
Skip an item when its anchor is null. Apply one uniform nearest-neighbor scale to
the composed canvas.

Colorways use a 4,194-byte rule file, with no exact source-color dictionary.
Each of the six entries has a name, an identity flag and six ordered rules:

| Class | Hue (degrees) | HSV saturation | Source brightness |
| --- | --- | --- | --- |
| Glow | 160 to 220 | 0.12 to 1 | max RGB, 0 to 255 |
| Accents | 0 to 55 | 0.16 to 1 | max RGB, 0 to 255 |
| Joints | any | 0 to 0.55 | mean RGB, 80 to 120 |
| Grays | any | 0 to 0.55 | mean RGB, 120 to 175 |
| Shell | any | 0 to 0.55 | mean RGB, 175 to 232 |
| Highlights | any | 0 to 0.55 | mean RGB, 232 to 255 |

The first matching rule wins. Each rule has two target colors; the source pixel's
relative brightness within its range interpolates target hue, saturation and
lightness in HSL, preserving shading instead of flattening a class to one color.
Hue takes the shortest path. Every source RGB with max channel below 80 remains
unchanged, protecting the black visor. Transparent pixels and all alpha values
are unchanged; partially transparent pixels are recolored in straight RGBA.
Unclassified saturated mood marks keep their source colors. Classic returns the
original image before allocating or visiting pixels.

`WardrobeFrameCache` serializes decoding and recoloring off the main actor, without
suspension between lookup and insertion. Animated frames, fixed poses and shop
colorway thumbnails share the frame/colorway cache. Widget timeline preparation
uses the same actor and passes prepared still images to its view; body evaluation
never recolors. The still-composition cache is bounded to 32 outfits. Head and face
items rotate around their anchor; neck, back and hand items stay upright.
`pose2`, `pose3` and `pose4` intentionally have no anchors: Stretch, Dance and Music
are recolored and cached, with all overlays hidden.

Room and furniture coordinates are image pixels too. Floor slots are floor
contact points; `desk` is the tabletop, `shelf` is the shelf bottom and `window`
is the window sill. The desk-monitor sprite extends down from its tabletop pivot.
The app and preview draw the rug first, then furniture, then the companion. It places the
bottom of the companion's opaque feet at `mascotSpot`, using a uniform 0.46 canvas
scale before the whole room is resized to 340 pixels wide.

Visual checks are written outside the repository:

- `/tmp/clockin-colorways-comparison.png`: side-by-side old/rule colorways when
  `/tmp/clockin-wardrobe-preview-before.png` is present.
- `/tmp/clockin-app-composition-{h01,t01,c07,e01}.png`: real runtime composites
  written by the wardrobe test, with five equipped slots.
- `/tmp/clockin-anchors.png`: every frame, with colored crosses and IDs.
- `/tmp/clockin-anchors-{h,t,c,e,a,z,p}.png`: larger per-family anchor sheets.
- `/tmp/clockin-wardrobe-preview.png`: five-slot outfits on hello, typing and
  celebrating poses; native, 62-pixel and 62-point @2x samples; all garment sprites
  with IDs; all six colorways; furnished rooms at 340 pixels wide; every home item.
- `/tmp/clockin-wardrobe-fit.png` and `clockin-wardrobe-fit-1.png` through `-5.png`:
  each item individually on hello, typing, a raised-cup pose and celebrating.
- `/tmp/clockin-home-{cozy,studio,night}.png`: furnished rooms at native resolution.

The independent test checks exact frame coverage, in-canvas anchors and pivots,
slot counts and layer bindings, file decoding, tight wardrobe crops, 2x2 art cells,
the under-20-KB rule schema, tiny RGBA recoloring, classic identity, every source
black visor shade, room coordinates and unclipped placement of every furniture item in every room.

At the smallest 62-pixel preview, the monocle chain and medal engraving lose
fine detail. Backpacks and jetpacks are partly hidden by the typing pose's torso
and laptop, consistently with the required back layer. Their outer silhouettes
remain visible. The 62-point @2x preview retains more of these details.

The wardrobe check also composes all 63 real frames with the app renderer, verifies
every catalog id and slot against actual files, checks null hand anchors and the
three fixed-pose omissions, and checks concurrent frame-cache identity off the
main thread. These checks do not replace the device-only interaction, VoiceOver,
large-text and 120-second CPU acceptance runs described above.
