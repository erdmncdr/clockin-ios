# Clockin: Mac to iPhone feature parity

Contents and counts:

| Section | Count |
|---|---:|
| [1. Missing and worth porting](#1-missing-and-worth-porting) | 14 capabilities, ranked |
| [2. Missing on purpose](#2-missing-on-purpose) | 6 desktop capabilities |
| [3. Present but different](#3-present-but-different) | 11 capability families |
| [4. iPhone only](#4-iphone-only) | 5 additions |
| [5. Screen, menu and panel inventory](#5-screen-menu-and-panel-inventory) | Coverage checklist |
| [6. Persisted preferences, key by key](#6-persisted-preferences-key-by-key) | 26 named keys/patterns plus 2 window autosave records |
| [7. Badge inventory](#7-badge-inventory) | 46 Mac badges, 7 on iPhone |
| [8. Mac bugs and dead code](#8-mac-bugs-and-dead-code) | Source findings, no fixes |

Reviewed on September 12, 2026. This is a static source audit of the current working files, including uncommitted changes, not a claim that every feature was exercised on a device. Both checkouts were read only. No app was launched, no tests that write user preferences were run, and no code was changed. Sizes below cover implementation and focused verification, not elapsed calendar estimates. Small means a local UI addition using existing data; medium means a new view or calculation path; large means a substantial UI plus lifecycle or platform integration.

Source links use these roots: **M** = `../Sources/Clockin` (the Mac app at the repository root); **I** = this `iOS` folder. Each reference gives an implementation line range; the link opens its first line. Missing explanations are inferences unless the code explicitly documents the reason. Item counts count the numbered entries, not repeated cross-references in the inventories.

Two corrections to the task's examples: the Mac already has an animated, interactive mascot; it is not an iPhone-only addition. Daily and monthly goals are editable on iPhone in Insights, despite having no Settings rows. The real orphaned iPhone preference is `Clockin.MascotDefault`.

## Status, 13 September 2026

Every item in section 1 is now ported. Each has deterministic checks under
`Tests/manual/` (see `README.md`); the app builds warning free and the screens
were exercised on the iPhone 17 Pro simulator.

| Item | Where on iPhone | Not verified |
|---|---|---|
| G1.01 Automatic backups | Settings > Data > Automatic backups. Lists every backup; restoring first keeps the current data as a backup, so a restore can be undone. | |
| G1.02 Select imports | Import review: every new row and correction starts selected; tap rows or All/None. | |
| G1.03 Earnings chart | History. Averages per calendar and active day, historical TRY on rows, matched label. | |
| G1.04 Focus chime | Settings > Focus chime. Local notifications from worked time; rescheduled from `SessionMirror`, so widget, Live Activity and Shortcuts changes also clear or move them. iOS sets the volume; the Mac sound list does not exist on iOS. | Delivery on a device, silent mode and Focus |
| G1.05 Reports | Insights > Reports & records. The 30-day trend uses calendar days, the same days as History's 30D. | |
| G1.06 Week/month heatmap | Insights > Work heatmap > Week, Month. | |
| G1.07 Share stats | Insights, share button. Share and copy; no Save to Photos, which needs a photo library permission. | The system share sheet on a device |
| G1.08 Companion picker | Settings > Appearance. | |
| G1.09 Match provenance | History rows show "Matched source" when a timer entry was corrected by a timecard. | |
| G1.10 Goal estimate | Insights > Goals. The daily goal gives a clock time; the monthly goal gives work days and whether the month can hold them. The Mac's "N days away" for a daily goal always read 1. | |
| G1.11 Badges | Badges tab: all 46, unlocked and locked groups, detail with requirement and progress. | |
| G1.12 Guide | Settings > How to use Clockin. | |
| G1.13 Money Momentum | Today. | |
| G1.14 Focus radio | Settings > Focus radio, with lock screen playback (`UIBackgroundModes` audio). | Playback on a device and with the screen locked |

Also changed while porting: widgets and the Live Activity follow the chosen
theme; a save that fails is rolled back in memory instead of showing work that
is not on disk; Settings moved from the tab bar to a gear on Today, and the
freed tab holds level and badges.

## 1. Missing and worth porting

### G1.01. Automatic-backup discovery and Restore latest (small)

Mac Settings displays the newest automatic backup date, saved count, and a confirmation-protected Restore latest action. iPhone has the same backup creation, retention, metadata and restore methods in `Shared/Core/ClockStore.swift`, but Settings offers only export and selection of an external JSON file. A user cannot discover or recover the internal backup through the app.

Mac implementation: [M:SettingsView.swift:358-387](../Sources/Clockin/SettingsView.swift#L358); [M:ClockStore.swift:82-98,337-352,597-619](../Sources/Clockin/ClockStore.swift#L82). iPhone evidence: [I:Clockin/Views/SettingsView.swift:127-156](Clockin/Views/SettingsView.swift#L127) and [I:Shared/Core/ClockStore.swift:82-98,360-375](Shared/Core/ClockStore.swift#L82).

Port: add the date/count row, disabled state when empty, confirmation and operation-specific result. Reuse the existing store API. Explain that backups are throttled to one per 24 hours when initialization/saves trigger them, retain 30 files, and are not an undo snapshot for every edit. Likely omission: Settings UI was simplified while the store was copied.

### G1.02. Select individual imports and corrections (medium)

Mac comparison defaults all actionable rows to selected, lets the user toggle each row or All/None, reports selected count and duration, collapses duplicates, and imports only the chosen new/correction rows. iPhone shows a thorough review but `confirm` passes every recognized session to `importSessions`; there are no checkboxes or selected-only totals. The only escape is changing the source or canceling the whole batch. Duplicate-only imports remain enabled on iPhone.

Mac implementation: [M:ImportComparisonView.swift:13-35,116-169,184-215](../Sources/Clockin/ImportComparisonView.swift#L13). iPhone evidence: [I:Clockin/Views/Import/TimecardImportView.swift:169-217,252-260](Clockin/Views/Import/TimecardImportView.swift#L169).

Port: keep selected actionable IDs in review state, expose accessible toggles and All/None, calculate selected totals, disable an empty import, and pass only the selected rows. Likely omission: the mobile review was implemented as an all-or-nothing flow.

### G1.03. Earnings charts, period filtering and historical TRY analysis (large)

**Chart port implemented after this audit:** History now has 7D / 30D / 3M
(90 calendar days) / ALL filters shared by the daily bar chart, period totals
and completed-session list. Totals include eligible active work by start date,
refreshed once per minute. Tap or drag selects a calendar day and shows worked
duration, original earnings, TRY equivalent and applied rate. USD accounts can
switch the chart to historical TRY; other currencies retain their own label.
Missing conversion rates stay missing rather than becoming zero or silently
using today's rate. Current-rate summary and historical-rate total have separate
labels. Rate requests use calendar-day keys and refresh when session dates change,
including same-count edits and the active session's start date.

Verification: warning-free simulator build; all four filters, the USD/TRY switch
and tap day details exercised on iPhone 17 Pro / iOS 26.5. The period total and
the TRY conversions were read off screen and disagree as they should: a period's
historical-rate total differs from its current-rate figure, so the two
conversions are demonstrably not sharing a rate.

Twelve deterministic calculation checks cover date boundaries, historical
conversion, missing rates, active/paused work, and empty data. They were shown to
fail on deliberately broken copies of the source (latest rate applied to every
day; missing rates treated as zero; an off-by-one period window). Run:
`swiftc -swift-version 6 Shared/Core/Models.swift Clockin/Views/Earnings/EarningsSnapshot.swift Tests/manual/earnings/main.swift -o /tmp/clockin-earnings-tests && /tmp/clockin-earnings-tests`.

Corrected after that first pass: the chart carried a `chartGesture` with
`minimumDistance: 0`, which swallowed the list's vertical scroll. Because the
chart sits at the top of History, dragging down to read older sessions selected
days instead of scrolling. Selection is now a `SpatialTapGesture`, which taps
without competing with the scroll; both were re-checked on the simulator. The
empty state also told people with no sessions at all to choose a wider period,
which ALL already is; that copy now depends on whether any session exists.

Real-device accessibility, very large archives, and the drag-to-scrub interaction
Mac offers remain untested or unported.

Remaining parts of the broader original G1.03 scope: historical TRY on individual
session rows and calendar-day/active-day averages. The text below is the original
audit, before this chart port.

Mac Earnings History has 7D, 30D, 3M (90 days) and ALL filters affecting completed-session lists, scoped time/money/session totals, and inclusion of an active session by its start date. It renders a horizontally scrollable daily line/area/point chart, despite copy calling it a bar chart. A USD/TRY toggle chooses original earnings or daily historical-rate conversion. Point details show date, worked duration, USD, TRY and applied exchange rate. The summary's approximate TRY uses the latest rate, distinct from historical chart conversion. Session rows can show historical TRY. Calendar-day daily/weekly/monthly averages, active days and active-day averages accompany the chart.

iPhone History is an unfiltered completed-session list. Insights has time/earnings totals and a day heatmap, but no earnings chart, selected-period earnings, historical TRY rows/details, or these averages. The historical exchange-rate backend exists on iPhone and is still populated.

Mac implementation: [M:HistoryView.swift:4-10,38-69,97-324,360-467](../Sources/Clockin/HistoryView.swift#L4); [M:ExchangeRates.swift:42-46](../Sources/Clockin/ExchangeRates.swift#L42). iPhone evidence: [I:Clockin/Views/HistoryView.swift:12-75](Clockin/Views/HistoryView.swift#L12); [I:Clockin/Views/Insights/InsightsView.swift:122-159](Clockin/Views/Insights/InsightsView.swift#L122); [I:Shared/Core/ExchangeRates.swift:42-46](Shared/Core/ExchangeRates.swift#L42).

Port: add a chart and period selector to History or Insights, reuse rate lookup, provide tap/drag selection and compact detail rows, distinguish current-rate approximations from daily-rate conversions. Include selected calendar-day and active-day averages. Correct the Mac's non-USD labeling bug rather than copying it. Likely omission: the phone's first History implementation prioritizes editing a simple list.

The top three are ranked this way because backup recovery protects the entire local archive; selective import prevents unwanted corrections before they happen; and earnings analysis is the largest missing everyday benefit of a paid-time tracker. Recovery and import control have higher consequences than cosmetic parity.

### G1.04. Focus chime with interval, sound and volume (large)

Mac has an optional chime while a session is running, keyed to accumulated worked time, excluding pauses. Settings supports 1-120 minutes (default 10), Glass/Ping/Pop/Tink/Funk/Submarine/Sosumi, 10-100% volume (default 75%), and a preview button. A new session or interval/enable change resets the baseline. There is no equivalent iPhone sound or reminder implementation. Timer haptics are not periodic chimes.

Mac implementation: [M:FocusChime.swift:5-73](../Sources/Clockin/FocusChime.swift#L5); [M:SettingsView.swift:327-355](../Sources/Clockin/SettingsView.swift#L327). iPhone contrast: [I:Clockin/Views/TimerCard.swift:64-70](Clockin/Views/TimerCard.swift#L64).

Port: settings and foreground sound playback are small pieces, but reliable reminders when the app is suspended require a separate notification/lifecycle design, cancellation/rescheduling on pause/resume/out, and appropriate packaged sounds. Do not assume macOS named sounds or its continuous process timer transfer directly. System notification delivery may not offer the Mac's per-chime volume behavior. Likely omission: platform audio and background behavior were not ported. The old main-screen countdown is dead UI, not an additional working feature.

### G1.05. Full productivity reports and best-day record (medium)

Mac Progress Reports exposes average completed-session length, best weekday by total duration, best start hour by total duration, average earnings/hour, and rolling last-30-days versus preceding-30-days trend. Records adds best completed day. iPhone has longest session, streaks, active days, totals and last-seven-days comparison, but none of those additional report metrics or an explicit best-day record.

Mac implementation: [M:ProgressView.swift:156-160,232-255](../Sources/Clockin/ProgressView.swift#L156). iPhone contrast: [I:Clockin/Views/Insights/InsightsView.swift:122-159](Clockin/Views/Insights/InsightsView.swift#L122); [I:Clockin/Views/Insights/InsightsSnapshot.swift:1-99](Clockin/Views/Insights/InsightsSnapshot.swift#L1).

Port: extend `InsightsSnapshot` with the missing aggregates and add a Reports/Records disclosure or cards. Clearly define completed versus active contributions: Mac average earnings/hour currently includes active work while its explanatory copy says completed only. Likely omission: only a smaller metrics subset was selected for Insights.

### G1.06. Week and month aggregate heatmap views (medium)

Mac Week and Month are aggregation modes over the archive, not seven-day and thirty-day filters. Each column represents a whole calendar week or month, displays period hours and earnings, and colors by relative earnings. Period details include TRY using the period-start rate with latest fallback. iPhone's 4 weeks / 12 weeks / All changes the visible history span but every square still represents a day. It cannot inspect a week/month as one unit.

Mac implementation: [M:HeatmapView.swift:69-119,201-238,286-305,319-350,367-399](../Sources/Clockin/HeatmapView.swift#L69). iPhone contrast: [I:Clockin/Views/Insights/InsightsHeatmapView.swift:11-37,109-128](Clockin/Views/Insights/InsightsHeatmapView.swift#L11).

Port: retain phone day selection and add an explicit grouping control, period aggregates and touch detail. Persist the chosen range/grouping if matching the Mac. Choose and label period TRY conversion deliberately, since Mac multiplies the entire period by one rate. Likely omission: the mobile grid was independently designed around daily cells.

### G1.07. Shareable stats rewind, with privacy controls (large)

Mac Progress opens a three-page Overview/Rhythm/Milestones preview. Users choose Public/Private, Current page/All 3, then Copy, Save PNG or Share. All 3 produces one long image. Private omits the headline time/earnings and best-day duration but still shares level, XP, streaks and rhythm; it is not anonymization. There is no iPhone stats-image export. Its ShareLink exports raw backup JSON only.

Mac implementation: [M:ProgressView.swift:104-112](../Sources/Clockin/ProgressView.swift#L104); [M:ShareStatsView.swift:153-221,237-290,393-650](../Sources/Clockin/ShareStatsView.swift#L153). iPhone contrast: [I:Clockin/Views/SettingsView.swift:133-137](Clockin/Views/SettingsView.swift#L133) and [I:Clockin/Views/Insights/InsightsView.swift:12-35](Clockin/Views/Insights/InsightsView.swift#L12).

Port: reuse a consistent stats snapshot, build phone preview/page controls, render via the iOS image path, and share/save/copy through native interfaces. Include privacy preview and fix the Mac badge-count mismatch first. Likely omission: substantial standalone view plus AppKit export integrations.

### G1.08. Mascot default-behavior picker and unlock explanation (small)

**Ported after this audit:** iPhone Settings → Appearance now has Default behavior,
using `Clockin.MascotDefault`. All seven Mac modes are listed; locked choices
show their hour threshold and cannot be selected. Total work includes the active
session. The explanation lists the 10/25/50/100-hour unlocks. The control is hidden
when Focus companion is off.

The mode names were duplicated as plain strings in the picker and in
`ClockinMascotStage`; a typo on either side would have silently fallen back to
Auto. They now come from one `CompanionMode` enum, which also owns the thresholds
and the locked-label text.

Verification: warning-free simulator build; the picker was opened on
iPhone 17 Pro / iOS 26.5 and lists all seven modes. The archive used there has every mode
unlocked, so the locked path cannot be reached through the UI there. It is covered
instead by 17 checks on `CompanionMode` (locked selection reverts to Auto, the
threshold itself unlocks, unknown or wrongly cased stored values fall back,
locked labels carry their hour threshold), shown to fail on broken copies of the
rule. Run:
`swiftc -swift-version 6 Clockin/Views/Mascot/CompanionMode.swift Tests/manual/companion/main.swift -o /tmp/clockin-companion-tests && /tmp/clockin-companion-tests`.

Live threshold crossing while Settings is open is still unexercised; the refresh
that would show it was also reduced from once a second to once a minute, since the
thresholds are measured in hours. The simulator's stored preference is currently
Typing, not Auto. The original audit below describes the gap before this port.

Mac Settings writes Auto, Typing, Coffee, Victory (10h), Stretch (25h), Dance (50h), Music (100h). Locked selections revert to Auto. iPhone `ClockinMascotStage` reads exactly this key and implements every mode, but no UI writes it. The enable toggle is unrelated. Both apps also let a tap temporarily show a random pose, without these fixed-mode unlock gates.

Mac implementation: [M:SettingsView.swift:285-304,449-452](../Sources/Clockin/SettingsView.swift#L285); [M:MascotAsset.swift:57-79](../Sources/Clockin/MascotAsset.swift#L57). iPhone evidence: [I:Clockin/Views/Mascot/MascotAsset.swift:39-68](Clockin/Views/Mascot/MascotAsset.swift#L39); [I:Clockin/Views/SettingsView.swift:15-35](Clockin/Views/SettingsView.swift#L15).

Port: add the picker, thresholds based on total completed plus active hours, and locked-state explanation. Most rendering is already implemented. Likely omission: a copied consumer without the matching Settings control.

### G1.09. Persistent import-match provenance in History (small)

Mac History labels a matched session with a checkmark and its external source. iPhone retains `matchedExternalSource` in its data and uses it during reimport matching, but its `SessionRow` only shows a generic timer/import icon and note-or-source text. Once the review closes, a corrected timer row has no explicit matched indicator.

Mac implementation: [M:HistoryView.swift:360-383](../Sources/Clockin/HistoryView.swift#L360); [M:ClockStore.swift:429-461](../Sources/Clockin/ClockStore.swift#L429). iPhone contrast: [I:Clockin/Views/SessionRow.swift:13-62](Clockin/Views/SessionRow.swift#L13); [I:Shared/Core/Models.swift:3-14](Shared/Core/Models.swift#L3).

Port: add an accessible matched/source label to History or the editor. No migration needed. Likely omission: the shared mobile row omitted the secondary badge.

### G1.10. Goal finish estimate (small)

Mac Progress Overview shows the predicted finish time for today's remaining goal during active work. Otherwise it estimates days from the last seven days' completed work, or explains that no estimate is available. iPhone shows time remaining and reached state but no ETA.

Mac implementation: [M:ProgressView.swift:266-281](../Sources/Clockin/ProgressView.swift#L266). iPhone contrast: [I:Clockin/Views/Insights/InsightsView.swift:98-114](Clockin/Views/Insights/InsightsView.swift#L98).

Port: calculate an active-session finish time in the existing goals card; optionally add the seven-day average estimate with careful wording. There is no actual monthly ETA in the Mac code despite reading the monthly-goal key. Likely omission: Insights retained progress bars but omitted prediction copy.

### G1.11. Remaining badges and inspectable badge details (medium)

Mac has 46 badge definitions; iPhone has seven. The 39 missing badges cover more total-hours thresholds, current/record streaks, session counts, longer sessions, XP, active days, early/late starts, weekends, and repeated goal completions. Mac badges open a detail overlay with locked/unlocked status, requirement and current progress. iPhone's seven milestones are static rows with progress text. Section 7 lists every badge and threshold.

Mac implementation: [M:ProgressView.swift:113-130,162-230,290-323](../Sources/Clockin/ProgressView.swift#L113). iPhone contrast: [I:Clockin/Views/Insights/InsightsView.swift:151-180](Clockin/Views/Insights/InsightsView.swift#L151).

Port: a shared badge definition/calculation list and an accessible detail sheet. Preserve the difference between current-streak badges and longest-streak records. Decide whether the very long-session awards are desirable phone incentives. Likely omission: intentionally reduced milestone subset, with no technical platform limitation.

### G1.12. In-app usage guide (small)

Mac question-mark button opens seven topics: session controls/manual start; selecting and importing history; pasted-page review; historical rate schedules; charts/heatmap/progress; desktop tools; backups. iPhone has contextual import instructions and XP explanations, but no complete guide explaining the whole app.

Mac implementation: [M:MainView.swift:199-203](../Sources/Clockin/MainView.swift#L199); [M:GuideView.swift:11-48](../Sources/Clockin/GuideView.swift#L11). iPhone contrast: [I:Clockin/Views/SettingsView.swift:25-40](Clockin/Views/SettingsView.swift#L25); [I:Clockin/Views/Import/TimecardImportView.swift:89-167](Clockin/Views/Import/TimecardImportView.swift#L89).

Port: a Help row and phone-specific guide covering Insights, recovery and external controls. Rewrite the desktop and outdated backup/XP-button instructions. Likely omission: help was not included in the phone navigation.

### G1.13. Money Momentum and next earnings milestone (small)

Mac home shows earning power per second, optional TRY/sec, next multiple-of-ten money target, amount remaining and progress. iPhone shows current earnings and TRY but no earning-power or monetary milestone strip.

Mac implementation: [M:MainView.swift:318-366](../Sources/Clockin/MainView.swift#L318). iPhone contrast: [I:Clockin/Views/TimerCard.swift:17-63](Clockin/Views/TimerCard.swift#L17).

Port: compact optional timer detail using the existing effective rate and currency. Correct exact-multiple behavior and clearly distinguish potential earning power from actual paused earnings. Likely omission: reducing timer-card density.

### G1.14. Focus radio (medium)

Mac Settings has one actual station, Radio Paradise, tagged EN with an explanatory description, Play/Stop and 0-100% volume. Default volume is 70%. The All pinned preset adds radio controls, and the menu bar offers Stop when playing. No iPhone radio player exists. The station picker is not evidence of a multi-station catalog.

Mac implementation: [M:RadioController.swift:5-50](../Sources/Clockin/RadioController.swift#L5); [M:SettingsView.swift:407-436](../Sources/Clockin/SettingsView.swift#L407); [M:PinnedWindow.swift:253-260](../Sources/Clockin/PinnedWindow.swift#L253); [M:ClockinApp.swift:88-91](../Sources/Clockin/ClockinApp.swift#L88).

Port: a small player UI plus audio-session interruptions, route changes and a deliberate background-playback decision. Add real playback failure reporting, which Mac lacks. Likely omission: AppKit-independent player logic was not copied because background audio/product scope needed a separate choice. Ranked last because phone users already have dedicated music apps.

## 2. Missing on purpose

“On purpose” here means platform-appropriate exclusion, not proof of an undocumented historical decision.

| ID | Mac capability and source | iPhone equivalent or disposition |
|---|---|---|
| G2.01 | Floating pinned NSPanel, draggable, resizable, all Spaces/fullscreen auxiliary, saved position and per-preset dimensions. Compact = timer/earnings/TRY; Money adds per-second earnings; Goal = daily/monthly gauges; All adds averages/goals/radio; Total = all-time earnings/TRY, total time, today and current money. [M:PinnedWindow.swift:9-104,117-330](../Sources/Clockin/PinnedWindow.swift#L9). | No free-floating cross-app window on iPhone. Live Activity and widgets provide visibility, but do not implement all five presets, goal fields or radio. Those content gaps are covered in G1 rather than requiring a literal desktop panel. |
| G2.02 | Menu-bar status and minimal mode. Selectable Hours, Seconds, Earnings, TL equivalent, Goal %; running-session values or today's totals when idle; daily/monthly goal percentages capped at 999; icon/status fallback. Minimal mode hides main/pin, retains controls and remembers pin visibility. [M:ClockinApp.swift:66-190](../Sources/Clockin/ClockinApp.swift#L66); [M:SettingsView.swift:212-272](../Sources/Clockin/SettingsView.swift#L212). | Widgets/Live Activity plus app controls. No minimal-mode setting, editable status-field selection or menu-bar icon is needed on a phone. Their current display is fixed. |
| G2.03 | Global/local Option-Command-I clock in/resume, Option-Command-P pause/resume, Option-Command-O clock out, Option-Command-E open. Escape is explicitly assigned to Paste Import Cancel. [M:KeyboardShortcuts.swift:12-47](../Sources/Clockin/KeyboardShortcuts.swift#L12); [M:PasteImportView.swift:62](../Sources/Clockin/PasteImportView.swift#L62); [M:SettingsView.swift:389-405](../Sources/Clockin/SettingsView.swift#L389). | Touch buttons and Siri/Shortcuts. No hardware-keyboard binding implementation found on iPhone. Its Clock In intent does not resume a paused session; use Pause or Resume. No additional custom keyboard shortcuts found in Mac sources. |
| G2.04 | Main-window show/hide, close-to-hide, minimize/resize, restored size, primary-display recentering, Dock activation/reopen, explicit Quit. Main and pin coexist; sheets and badge overlay supplement them. [M:MainWindow.swift:8-88](../Sources/Clockin/MainWindow.swift#L8); [M:ClockinApp.swift:13-43](../Sources/Clockin/ClockinApp.swift#L13),112; [M:MainView.swift:777-786](../Sources/Clockin/MainView.swift#L777). | Normal foreground/background app lifecycle, navigation and sheets. Mac uses a singleton main controller, not arbitrary multiple independent document windows. Do not add “multi-window documents” to the missing list. |
| G2.05 | Interface size 100/115/130/150%, legacy scale migration, resizing minimum content size; hover tooltips and hover-driven chart/heatmap details. [M:UIScale.swift:13-51](../Sources/Clockin/UIScale.swift#L13); [M:SettingsView.swift:193-211](../Sources/Clockin/SettingsView.swift#L193); [M:HistoryView.swift:230-245](../Sources/Clockin/HistoryView.swift#L230); [M:HeatmapView.swift:336-399](../Sources/Clockin/HeatmapView.swift#L336). | Native adaptive layout and system text sizing, tap/drag details instead of hover. iPhone has no global in-app scale percentage. Missing chart/aggregate information is G1, not excused as hover-only. |
| G2.06 | GitHub commit comparison, manual Check now, six-hour automatic-check preference, behind count, commit stamp, launch local update script to rebuild/reinstall. [M:UpdateChecker.swift:23-112](../Sources/Clockin/UpdateChecker.swift#L23); [M:SettingsView.swift:123-190](../Sources/Clockin/SettingsView.swift#L123). | iPhone About shows bundle version/build only. Distribution-specific update delivery replaces a local Mac shell script; the checkout does not establish a shipped App Store update flow. No matching auto-check preference is needed just to copy this developer-oriented updater. |

## 3. Present but different

| ID | Capability | Precise comparison |
|---|---|---|
| G3.01 | Navigation and dashboard placement | Mac has Home, History, Heatmap, Progress, Settings; Progress contains Overview/Badges/Records/Weekly/Reports. Phone has Today, History, Insights, Settings, merging heatmap and a subset of progress into Insights. Mac home has goal bars and all-time footer; phone moves those totals/goals to Insights. Mac home lists four recent sessions, phone five. Phone level badge opens Insights; Mac level chip is only a label/help target. [M:MainView.swift:77-98,226-277,507-546,596-602,777-786](../Sources/Clockin/MainView.swift#L77); [I:Clockin/Views/RootView.swift:16-38](Clockin/Views/RootView.swift#L16); [I:Clockin/Views/DashboardView.swift:17-44,115-169](Clockin/Views/DashboardView.swift#L17). |
| G3.02 | Clock in, pause/resume, out, cancel and summary | Same one-active-session model, elapsed time excluding pauses, earnings, optional note through manual start, cancel confirmation in main UI, and completion summary with time/earnings/base XP. Mac menu/keyboard actions bypass the summary; menu Cancel has no confirmation. Phone external intents likewise return dialogs rather than opening the summary. Home timers show seconds; phone Dynamic Island uses HH:mm on iOS 18+ and lock-screen activity uses seconds. Phone adds explicit cross-midnight attribution text. [M:MainView.swift:369-421](../Sources/Clockin/MainView.swift#L369); [M:ClockStore.swift:138-199](../Sources/Clockin/ClockStore.swift#L138); [I:Clockin/Views/TimerCard.swift:17-176](Clockin/Views/TimerCard.swift#L17); [I:Shared/Intents/ClockIntents.swift:9-83](Shared/Intents/ClockIntents.swift#L9). |
| G3.03 | Start with elapsed time | Both support 0-999 hours, 0-59 minutes, note, inferred start and initial earnings; zero duration cannot start. Mac hours/minutes can be typed or stepped. Phone hours are a stepper, minutes a picker, preview refreshes each second and includes the date, and Start is disabled if another session exists. [M:ManualStartView.swift:6-79](../Sources/Clockin/ManualStartView.swift#L6); [I:Clockin/Views/ManualStartView.swift:9-95](Clockin/Views/ManualStartView.swift#L9). |
| G3.04 | Manual entry, edit, delete | Both choose day/start/end and note, infer next day only if end is earlier than start, reject equal times, preview duration/earnings, preserve seconds on untouched edits and preserve the old work/break gap when times change. Both have confirmed session deletion. Phone supports multiline notes and local save errors, row tap/swipes/context menus; Mac uses explicit pencils/trash and does not surface editor save errors locally. Neither editor has an independent end-date control for multi-day records. [M:ManualEntryView.swift:14-146](../Sources/Clockin/ManualEntryView.swift#L14); [M:ClockStore.swift:382-414](../Sources/Clockin/ClockStore.swift#L382); [I:Clockin/Views/ManualEntryView.swift:13-147](Clockin/Views/ManualEntryView.swift#L13); [I:Clockin/Views/HistoryView.swift:19-41](Clockin/Views/HistoryView.swift#L19). |
| G3.05 | Pay, currency and rate schedules | Both have USD/EUR/GBP/TRY, fallback hourly rate, start date, optional inclusive end date, add/edit/delete, latest-applicable-start precedence, and a minimum of one rate rule. Phone also displays a restored nonstandard currency code in its picker. Mac updates valid rate text and existing rule changes immediately; phone commits the main rate on focus loss and edits periods in Save/Cancel sheets with finite-value validation. Mac defaults new period to Jan 1, 2026, phone today. Phone confirms rate deletion and marks the current rule. [M:SettingsView.swift:96-121](../Sources/Clockin/SettingsView.swift#L96); [M:RateScheduleView.swift:8-139](../Sources/Clockin/RateScheduleView.swift#L8); [I:Clockin/Views/SettingsView.swift:92-124,182-206](Clockin/Views/SettingsView.swift#L92); [I:Clockin/Views/RateScheduleView.swift:12-255](Clockin/Views/RateScheduleView.swift#L12). |
| G3.06 | Daily/monthly goals and XP | Mac Settings accepts decimal hours, comma or dot, clamped only at zero. Phone Insights Edit goals accepts whole-hour steps, daily 0-24 and monthly 0-744; zero disables. Existing fractional stored values can be displayed, but the stepper rounds/clamps when edited. The same keys drive XP at 100/hour, +100 per goal day, another +250 per double-goal day, +500 per goal month, cumulative longest-streak bonuses at 3/7/14/30/60 days, and levels every 500 XP. Changing goals recalculates historical bonuses in both. Mac Progress refreshes every second; phone Insights every minute. [M:SettingsView.swift:307-325](../Sources/Clockin/SettingsView.swift#L307); [M:ProgressView.swift:37-91](../Sources/Clockin/ProgressView.swift#L37); [I:Clockin/Views/Insights/InsightsView.swift:14-16,78-120](Clockin/Views/Insights/InsightsView.swift#L14); [I:Clockin/Views/Insights/InsightsSnapshot.swift:25-99](Clockin/Views/Insights/InsightsSnapshot.swift#L25). |
| G3.07 | History layout | Mac defaults to collapsed day groups, can switch to flat Sessions, remembers that preference, and initially limits display to 30 days/rows with Show all/Show recent. Expanded Mac days list sessions earliest first and show count/first-last span. Phone always groups by day, always shows rows, lists newest first, has no grouping preference, collapse control or 30-item display toggle, and shows day time/money totals. Both preserve individual records. Date filters/chart/provenance omissions are G1. [M:HistoryView.swift:25-33,50-69,326-355,395-435](../Sources/Clockin/HistoryView.swift#L25); [I:Clockin/Views/HistoryView.swift:12-75,143-166](Clockin/Views/HistoryView.swift#L12). |
| G3.08 | Daily heatmap and weekly comparison | Both offer scrollable Monday-first day grids, Start/Today navigation, intensity legend and day hours/earnings. Phone uses tap-selected persistent details and 4/12/All-week spans, Mac hover and full-archive daily mode plus aggregates. Mac range persists; phone range is transient State defaulting to 12. Mac heatmap refreshes every 20s, phone through Insights every 60s. Both show recent-seven versus prior-seven totals; Mac includes any active session and has no upper cutoff for completed entries, phone bounds by start day through today. With zero prior work, Mac displays +100% even for zero current work; phone omits percentage. [M:HeatmapView.swift:20-32,149-185,251-318](../Sources/Clockin/HeatmapView.swift#L20); [M:ProgressView.swift:257-264](../Sources/Clockin/ProgressView.swift#L257); [I:Clockin/Views/Insights/InsightsHeatmapView.swift:11-128](Clockin/Views/Insights/InsightsHeatmapView.swift#L11); [I:Clockin/Views/Insights/InsightsView.swift:122-140](Clockin/Views/Insights/InsightsView.swift#L122). |
| G3.09 | Mascot and appearance | Both have the same eight themes/font designs: Carbon, Neon Orange, Electric Blue, Synthwave, Data Dense, Aurora, Terminal Amber, Daylight. Both have mascot enable, typing/coffee animations and temporary tap poses. Mac effects run periodically by default; phone effects appear on a tap pose and respect Reduce Motion/scene activity. Phone substitutes pose2 for idle rather than the Mac idle asset, and uses a dedicated celebration state. Phone widgets/Live Activity hardcode Carbon independently of the selected app theme. Missing fixed behavior picker is G1.08. [M:Themes.swift:3-44](../Sources/Clockin/Themes.swift#L3); [M:MascotAsset.swift:19-110](../Sources/Clockin/MascotAsset.swift#L19); [I:Shared/Theme/Themes.swift:3-44](Shared/Theme/Themes.swift#L3); [I:Clockin/Views/Mascot/MascotAsset.swift:3-215](Clockin/Views/Mascot/MascotAsset.swift#L3). |
| G3.10 | CSV and pasted timecard import | Both parse UTF-8 CSV, BOM/CRLF/quoted fields, required Start Time/End Time ISO dates, optional Duration in milliseconds, Notes and Time Sheet Source; skip invalid rows. Pasted parser accepts English weekdays/months, Approved/Submitted/Draft/Unapproved, infers years from date range or today, handles overnight rows, and compares recognized duration to Page Approved with >60s mismatch warning. The two CSV parsers and two pasted parsers are identical in this checkout. Mac continuously previews pasted text then opens separate comparison; phone combines CSV/paste in one source-review-result flow, explicitly triggered by Review, with clearer errors and old/new timestamps. Selection omission is G1.02. Both core matchers skip exact duplicates and reconcile external rows by same start day and >=50% overlap of shorter worked duration; authoritative imported times/duration replace matched values while existing nonempty notes remain. [M:CSVImporter.swift:17-118](../Sources/Clockin/CSVImporter.swift#L17); [M:PastedTextImporter.swift:11-196](../Sources/Clockin/PastedTextImporter.swift#L11); [M:ClockStore.swift:358-374,416-499](../Sources/Clockin/ClockStore.swift#L358); [I:Clockin/Views/Import/TimecardImportView.swift:17-326](Clockin/Views/Import/TimecardImportView.swift#L17). |
| G3.11 | JSON backups, local persistence and exchange rates | Both save the same ClockinData schema and can manually export/restore sessions, running timer, rates, currency and pinVisible. Phone restores only after confirmation; Mac Restore file replaces immediately, while Restore latest is confirmed. Mac serializes memory into a named destination; phone shares the existing on-disk `clockin.json`. Both create throttled automatic backups, but phone recovery UI is absent (G1.01). Phone adds duration/date validation during decode. Mac uses Application Support/Clockin; phone uses an App Group container with legacy migration/fallback for widget access. This is not Mac/iPhone sync. Both keep the same USD/TRY cache and one-hour freshness check, current/historical fetches and error statuses. Phone mainly displays latest conversion, leaving historical data without corresponding analysis UI (G1.03). Preferences such as theme/goals/mascot are not part of exported JSON in either app. [M:ClockStore.swift:42-98,312-352,586-619](../Sources/Clockin/ClockStore.swift#L42); [I:Shared/Sync/AppGroup.swift:6-42](Shared/Sync/AppGroup.swift#L6); [I:Shared/Core/Models.swift:71-100](Shared/Core/Models.swift#L71); [I:Clockin/Views/SettingsView.swift:70-89,127-156](Clockin/Views/SettingsView.swift#L70). |

## 4. iPhone only

| ID | Addition | Scope and limits |
|---|---|---|
| G4.01 | Live Activity and Dynamic Island | Working/paused status, system-driven elapsed timer, last-published money, hourly rate, pause/resume/out; lock-screen view also note and optional TRY. Expanded/compact/minimal Island presentations; HH:mm on iOS 18+. Starts from session state when authorized, ends on stop, restarts for currency change. Money is `earnedAtUpdate`, not a continuously advancing second-by-second counter. No remote push updater is present. [I:ClockinWidgets/ClockinLiveActivity.swift:6-166](ClockinWidgets/ClockinLiveActivity.swift#L6); [I:Shared/Sync/SessionMirror.swift:24-119](Shared/Sync/SessionMirror.swift#L24). |
| G4.02 | Actual WidgetKit home/lock-screen widgets | Small, medium, accessory rectangular. Medium has clock-in or pause/resume/out actions; small and accessory have no explicit controls. Current session/today time and earnings, overnight attribution, minute entries for one hour while running, otherwise requested refresh after 15 minutes. The Mac's “pinned widget” is an NSPanel, not WidgetKit. [I:ClockinWidgets/TodayWidget.swift:10-290](ClockinWidgets/TodayWidget.swift#L10); [I:Shared/Sync/ClockinSnapshot.swift](Shared/Sync/ClockinSnapshot.swift). |
| G4.03 | Siri, Shortcuts and user-configurable Action button integration | Three App Shortcuts: Clock In, Clock Out, Pause or Resume, with spoken-result dialogs. The user can choose these through Shortcuts/Action button configuration; there is no in-app Action button settings page. No cancel, import, goal or statistics intents. [I:Clockin/Intents/ClockinShortcuts.swift:3-29](Clockin/Intents/ClockinShortcuts.swift#L3); [I:Shared/Intents/ClockIntents.swift:9-83](Shared/Intents/ClockIntents.swift#L9). |
| G4.04 | Timer action haptics | Start/stop sensory feedback on active-session creation/removal and light impact for pause/resume from the timer view's state changes. No app preference switch and no periodic chime. Not promised for every background intent invocation. [I:Clockin/Views/TimerCard.swift:64-70](Clockin/Views/TimerCard.swift#L64). |
| G4.05 | Completion celebration and animated XP count | Phone summary adds a dedicated mascot celebration and short XP count-up with Reduce Motion alternatives. Mac summary already has the same base XP total and congratulatory copy, but no rendered celebration mascot/count-up. This addition is narrower than “the mascot.” [I:Clockin/Views/SessionSummaryView.swift:15-142](Clockin/Views/SessionSummaryView.swift#L15); [M:SessionSummaryView.swift:10-23](../Sources/Clockin/SessionSummaryView.swift#L10). |

## 5. Screen, menu and panel inventory

This checklist includes shared features so that “not listed as missing” does not mean “not inspected.” Cross-references are not additional counted items.

| Mac entry point | Every custom surface/action found | Classification / phone route |
|---|---|---|
| Main window / Home | Timer/status/earnings/TRY; Clock in; Pause/Resume; Clock out summary; Cancel alert; Start with elapsed; Add past entry; today totals; goals; mascot/tap; level chip; FX status; recent edit/delete/View all; all-time footer; Help; pin; Quit | G3.01-04,06,09,11; momentum G1.13; Help G1.12; G2.01,04. Phone past-entry access is in History rather than Home's idle controls. |
| Bottom navigation | Home, History, Heatmap, Progress, Settings | G3.01. |
| Earnings History | Range picker, summary, USD/TRY toggle, scrolling chart and point inspection, averages, grouped/flat toggle, expand day, Show all/recent, manual-entry plus, per-row source match/TRY, edit/delete alert | G1.03,09; G3.04,07. |
| Work Heatmap | Week/Month/All, total/best-day/active-day summary, day grid or period columns, Start/Today, hover details and TRY, legend | G1.05,06; G3.08; hover G2.05. |
| Progress Overview | Level/XP meter and breakdown, mascot, current streak, total time, XP rate, goal bonus counts, target ETA | G3.06,09; G1.10. |
| Progress Badges | All 46 tiles, locked status, click details; outside click dismisses detail overlay | G1.11, section 7. |
| Progress Records | Longest session, best day, current/longest streak, goal days, total XP | Shared metrics in Insights; best day G1.05. |
| Progress Weekly | Current/prior seven-day time and change | G3.08. |
| Progress Reports | Active days, session average, best weekday/start hour, earnings/hour, 30-day trend | G1.05; active days already present. |
| Share stats sheet | Public/Private; previous/next page; All 3/Current page; preview; Copy; Save PNG panel; native sharing picker; close/status | G1.07. |
| Settings Pay & Currency | Rate text, currency, current rate effective date, Manage rate schedule | G3.05. |
| Rate schedule sheet | Existing rows, editable rate/start/end, optional Until, delete except last; add period; Done | G3.05; phone separate rate editor and delete confirmation. |
| Settings Earnings Goals | Daily/monthly text fields, Off/zero behavior | G3.06, phone Insights. |
| Settings Appearance | Theme/font, interface size, minimal mode toggle and Apply & hide, status fields, pinned preset/visibility, mascot toggle/default behavior | G3.09; G2.01,02,05; G1.08. |
| Settings Focus Chime | Enable, interval stepper, sound, volume, percentage, Test sound | G1.04. |
| Settings Keyboard Shortcuts | Four shortcut descriptions and accessibility-permission explanation | G2.03. |
| Settings Focus Radio | Station picker/description, Play/Stop, volume, percentage, internet-use copy | G1.14. |
| Settings Data | CSV open panel, paste sheet, backup save panel, restore JSON open panel, latest/count, Restore latest alert, status text | G3.10,11; G1.01,02. |
| Settings Updates | Version/commit status, checking spinner/errors, Check now, available-commits row, conditional Update now, automatic toggle | G2.06. |
| CSV/paste comparison | New/Updates/Skip totals, selection count/time, All/None, selectable rows, expandable skipped section capped at 60 visible duplicates, old duration, Cancel/close/Import | G1.02; G3.10. Phone instead shows all duplicate rows and full old/new timestamps. |
| Manual start sheet | Hours/minutes, optional note, inferred start, initial earnings, Cancel/Start | G3.03. |
| Manual entry/edit sheet | Day/start/end, note, duration/earnings/overnight preview, Cancel/Add/Save | G3.04. |
| Session summary sheet | Note/default title, duration, earnings, base XP, encouragement, close/Done | G3.02; phone enhancement G4.05. |
| Help sheet | Seven numbered topics, import-order tip, scroll, close | G1.12. |
| MenuBarExtra menu | Open Clockin; conditional minimal heading; Clock in or Resume or Pause; Clock out and Cancel when active; Stop focus radio when playing; pin toggle outside minimal mode; enter/exit minimal; Quit | G2.02,04; underlying session actions G3.02; radio G1.14. |
| Floating panel | Five presets and their contents, resize/move persistence; All preset radio Play/Stop and volume | G2.01; relevant data additions separately G1. |
| Notifications and sounds | One-second internal focus-chime timer and preview, NSSound fallback beep; streaming radio. No user-notification center registration, scheduled local notifications, goal alerts, clock-out sound or other custom sound path found. | G1.04,14; phone haptics G4.04 and ActivityKit G4.01. View alerts are confirmations/errors, not scheduled notifications. |

No CSV export, PDF/invoice export, cloud sync, project/client management, task-level rates, login, launch-at-login setting, separate system Settings scene or arbitrary document-window feature was found in the Mac application sources. These are not established Mac capabilities missing from the port. The real exports are portable JSON and rendered stats PNG. The real imports are CSV, pasted text and JSON restoration.

## 6. Persisted preferences, key by key

The table covers all product preference strings found in `@AppStorage`, UserDefaults calls/constants and dynamic pin-size keys, including keys outside Settings. System accessibility/scene environment values are not application preference keys.

| Key | Mac default / UI / consumer | iPhone writer and consumer | Group |
|---|---|---|---|
| `Clockin.Theme` | Carbon; Settings Theme & font; app views/pin | Settings Theme; RootView palette; widgets/activity use fixed Carbon | G3.09 |
| `Clockin.UIScalePercent` | 100; options 100/115/130/150; Settings Interface size, global S() | Absent | G2.05 |
| `Clockin.UIScale` | Legacy Double scale, migrated then removed by UIScale | Absent | G2.05 |
| `Clockin.PinnedMode` | Money; Compact/Money/Goal/All/Total picker | Absent | G2.01 |
| `Clockin.PinnedWidth.<mode>` | Written after live resize for each preset, used when restoring/applying | Absent | G2.01 |
| `Clockin.PinnedHeight.<mode>` | Same as width | Absent | G2.01 |
| `Clockin.ChimeEnabled` | false; Settings toggle; FocusChime reads | Absent | G1.04 |
| `Clockin.ChimeSound` | Glass; seven sound options; preview/runtime | Absent | G1.04 |
| `Clockin.ChimeVolume` | 0.75; slider 0.1-1; runtime clamp | Absent | G1.04 |
| `Clockin.ChimeIntervalMinutes` | 10; stepper 1-120; controller defaults 0/unset to 10 | Absent | G1.04 |
| `Clockin.MascotEnabled` | true; Settings Progress mascot; home/progress visibility | Settings Focus companion toggle; dashboard/summary consume | G3.09 |
| `Clockin.MascotDefault` | Auto; seven values, fixed-mode hour locks | Consumer only in MascotAsset.swift:43-68. No Settings or other app UI setter | G1.08 |
| `Clockin.MinimalMode` | false; Settings toggle plus Apply & hide; menu toggle; startup check | Absent | G2.02 |
| `Clockin.MinimalShowHours` | true; minimal status Hours | Absent | G2.02 |
| `Clockin.MinimalShowSeconds` | false; Seconds disabled if Hours off; running timer only | Absent; Island formatting is code, not this preference | G2.02 |
| `Clockin.MinimalShowEarnings` | true; minimal status Earnings | Absent | G2.02 |
| `Clockin.MinimalShowTRY` | true; TL equivalent, only used for USD with rate | Absent | G2.02 |
| `Clockin.MinimalShowGoal` | false; daily/monthly Goal % | Absent | G2.02 |
| `Clockin.PinVisibleBeforeMinimal` | No permanent default; snapshot on entry, restore then remove on exit, fallback true | Absent | G2.02 |
| `Clockin.GoalDailyHours` | 0; decimal Settings field; home/progress/pin/menu/share | Writer in Insights Edit goals (0-24 whole-hour stepper); Insights and LevelBadge consume; no Settings row | G3.06 |
| `Clockin.GoalMonthlyHours` | 0; decimal Settings field; home/progress/pin/menu/share | Writer in Insights Edit goals (0-744 whole-hour stepper); Insights and LevelBadge consume; no Settings row | G3.06 |
| `Clockin.AutoCheckUpdates` | true; Settings toggle; checks when Settings task runs | Absent | G2.06 |
| `Clockin.HistoryGroupByDay` | true; History Sessions/By day button, not Settings | Absent; grouping always by day | G3.07 |
| `Clockin.HeatmapRange` | All; Heatmap Week/Month/All control, not Settings | Absent; local State integer 12, choices 4/12/0 | G3.08, G1.06 |
| `Clockin.USDTRYRates.v1` | Encoded rate dictionary, ExchangeRateStore; no direct Settings setter | Same cache/read/write implementation; historical cache has limited visible use | G3.11, G1.03 |
| `Clockin.USDTRYRatesUpdated.v1` | Last successful check Date, no direct UI setter | Same | G3.11 |

There are **26** named keys/patterns above, plus two AppKit autosave records. The dynamic width/height patterns expand to Compact, Money, Goal, All and Total, so they represent ten possible concrete size keys.

AppKit also persists window frames under autosave names `ClockinMainWindow` and `ClockinPinnedTimer` (the corresponding framework defaults are `NSWindow Frame ClockinMainWindow` and `NSWindow Frame ClockinPinnedTimer`). See [M:MainWindow.swift:46-67](../Sources/Clockin/MainWindow.swift#L46) and [M:PinnedWindow.swift:31-32,56-61,82-99](../Sources/Clockin/PinnedWindow.swift#L31). These are G2.04/G2.01, absent on iPhone; main-window launch deliberately recenters position while retaining size.

Preference evidence: [M:SettingsView.swift:8-36,193-305,307-355,449-452](../Sources/Clockin/SettingsView.swift#L8); [M:UIScale.swift:13-43](../Sources/Clockin/UIScale.swift#L13); [M:PinnedWindow.swift:45-61](../Sources/Clockin/PinnedWindow.swift#L45); [M:HistoryView.swift:25-34](../Sources/Clockin/HistoryView.swift#L25); [M:HeatmapView.swift:19-20,204-213](../Sources/Clockin/HeatmapView.swift#L19); [M:ExchangeRates.swift:17-34,108-115](../Sources/Clockin/ExchangeRates.swift#L17). Phone: [I:Clockin/Views/SettingsView.swift:15-35](Clockin/Views/SettingsView.swift#L15); [I:Clockin/Views/Insights/InsightsView.swift:7-8,78-94](Clockin/Views/Insights/InsightsView.swift#L7); [I:Clockin/Views/Mascot/LevelBadge.swift:6-7](Clockin/Views/Mascot/LevelBadge.swift#L6); [I:Clockin/Views/Mascot/MascotAsset.swift:43-68](Clockin/Views/Mascot/MascotAsset.swift#L43); [I:Shared/Core/ExchangeRates.swift:17-34,108-115](Shared/Core/ExchangeRates.swift#L17).

**Reverse audit:** no additional iPhone-only `@AppStorage`/UserDefaults product key was found. Its entire set is Theme, MascotEnabled, MascotDefault, GoalDailyHours, GoalMonthlyHours and the two FX cache keys. Of those, only MascotDefault has a consumer and no app UI writer. Goals have writers outside Settings; FX keys are intentionally internal caches. There is no saved phone widget family preference, activity field picker, haptic toggle, sync toggle or radio preference hidden elsewhere.

**Other persisted state, not UserDefaults:** both `ClockinData` models store `hourlyRate` (25), `currencyCode` (USD), optional `running` (start/accumulated/resumedAt/note), `sessions` (id/start/end/duration/note/hourlyRate/source/matchedExternalSource), `pinVisible` (false) and optional `rateRules` (id/effectiveFrom/effectiveUntil/hourlyRate). Phone retains pinVisible for Mac JSON compatibility but exposes no pin UI. Both migrate missing rateRules to a July 1, 2026 rule. JSON export excludes all the preference keys above, FX caches and automatic-backup files. `ClockinBuildCommit`, `ClockinUpdateScript` and `ClockinUpstreamBase` are Mac bundle metadata, not writable preferences; phone version/build are also bundle metadata. Radio station/volume, share privacy/page/export mode, selected tabs, History range/showTRY/expanded days/show-all, and update `lastChecked` are transient state, not saved keys. Phone additionally writes `widget-snapshot.json` and ActivityKit content state for external surfaces, not a second user-configurable settings database.

## 7. Badge inventory

[M:ProgressView.swift:162-210](../Sources/Clockin/ProgressView.swift#L162) defines 46 badges. Phone milestone rows are in [I:Clockin/Views/Insights/InsightsView.swift:151-162](Clockin/Views/Insights/InsightsView.swift#L151). “Missing” rows belong to G1.11. The seven present rows are part of the shared progress system (G3.06); First session has a condition difference noted below.

| Mac badge | Requirement | iPhone |
|---|---|---|
| First session | Complete your first session | Present |
| 10-hour club | Work 10 total hours | Missing, G1.11 |
| Half-century | Work 50 total hours | Missing, G1.11 |
| Century | Work 100 total hours | Present |
| Quarter kilo | Work 250 total hours | Missing, G1.11 |
| Half-thousand | Work 500 total hours | Missing, G1.11 |
| Three-quarter legend | Work 750 total hours | Missing, G1.11 |
| Thousand-hour | Work 1,000 total hours | Missing, G1.11 |
| Time titan | Work 1,500 total hours | Missing, G1.11 |
| On a roll | Keep a 3-day streak | Missing, G1.11 |
| Weekly fire | Keep a 7-day streak | Missing, G1.11 |
| Unstoppable | Keep a 30-day streak | Missing, G1.11 |
| Fortnight fire | Reach a 14-day streak | Present |
| Seasoned | Reach a 60-day streak | Missing, G1.11 |
| Weekly finisher | Log 7 sessions | Missing, G1.11 |
| Session collector | Log 25 sessions | Missing, G1.11 |
| Marathon | Complete a 4-hour session | Present |
| Ultra focus | Complete an 8-hour session | Missing, G1.11 |
| XP engine | Earn 10,000 XP | Missing, G1.11 |
| Goal setter | Complete a daily goal | Present |
| Double down | Reach 2× a daily goal | Present |
| Month finisher | Complete a monthly goal | Present |
| Quarter XP | Earn 25,000 XP | Missing, G1.11 |
| Getting steady | Work on 5 different days | Missing, G1.11 |
| Calendar regular | Work on 25 different days | Missing, G1.11 |
| Daily craft | Work on 100 different days | Missing, G1.11 |
| Early bird | Start 5 sessions before 08:00 | Missing, G1.11 |
| Night owl | Start 5 sessions after 22:00 | Missing, G1.11 |
| Weekend warrior | Work on 4 weekend days | Missing, G1.11 |
| Deep archive | Log 50 sessions | Missing, G1.11 |
| Century sessions | Log 100 sessions | Missing, G1.11 |
| Archive master | Log 200 sessions | Missing, G1.11 |
| Session institution | Log 500 sessions | Missing, G1.11 |
| Iron focus | Complete a 12-hour session | Missing, G1.11 |
| Deep dive | Complete a 15-hour session | Missing, G1.11 |
| Goal rhythm | Complete daily goals on 7 days | Missing, G1.11 |
| Goal machine | Complete daily goals on 30 days | Missing, G1.11 |
| Quarter planner | Complete 3 monthly goals | Missing, G1.11 |
| Year planner | Complete 12 monthly goals | Missing, G1.11 |
| Season streak | Reach a 90-day streak | Missing, G1.11 |
| Half-year fire | Reach a 180-day streak | Missing, G1.11 |
| Year-round | Reach a 365-day streak | Missing, G1.11 |
| Always on | Work on 250 different days | Missing, G1.11 |
| Permanent practice | Work on 500 different days | Missing, G1.11 |
| XP architect | Earn 50,000 XP | Missing, G1.11 |
| XP legend | Earn 100,000 XP | Missing, G1.11 |

Mac First session actually tests total worked hours >0, including an active session, while phone tests completed-session count >0. Mac 3/7/30-day badges use the current streak and may relock; 14/60/90/180/365-day awards use longest streak. Phone's Fortnight fire also uses longest streak. Badge calculations are derived from data and current goal preferences, not saved unlock events. Neither platform sends badge-unlocked notifications in the inspected source.

## 8. Mac bugs and dead code

These are source-level findings, not reproduced runtime failures. Some are shared with the port. None were fixed.

1. **A local keyboard monitor swallows unrelated Option-Command keystrokes.** `matches` accepts any nonnil character with exactly those modifiers, and the local monitor returns nil before `perform` checks I/P/O/E. Other shortcuts using the same modifiers can be consumed without an action. [M:KeyboardShortcuts.swift:20-29,32-46](../Sources/Clockin/KeyboardShortcuts.swift#L20).
2. **Non-USD history chart labels/conversion are wrong.** Its points contain earnings in `store.currencyCode`, but the picker/tooltip say USD and the TRY path multiplies those earnings by USD/TRY without a currency guard. EUR/GBP/TRY settings therefore produce mislabeled analysis. [M:HistoryView.swift:106-110,165-187,307-320,436-457](../Sources/Clockin/HistoryView.swift#L106).
3. **Unreadable-file protection does not survive initialization.** `mustNotOverwrite` prevents the migration save only; it is a local variable. If copying an unreadable original fails, a later clock-in/rate edit can still call the unconditional save and overwrite it. The user's recovery message is also not generally shown on Home because the old status-bearing settingsSection is unmounted. [M:ClockStore.swift:45-74,586-594](../Sources/Clockin/ClockStore.swift#L45); [M:MainView.swift:77-98,770-773](../Sources/Clockin/MainView.swift#L77). Shared store pattern exists on phone too; the older remembered corruption finding was rechecked against current code, which now attempts a safety copy.
4. **Import preview and commit can disagree for competing matches.** Preview marks a later incoming row NEW when its best local match was already claimed; commit finds that same claimed match and silently skips the row. It does not try a second-best unclaimed local candidate. Exact-duplicate provenance stamping also cannot occur from the Mac comparison UI because duplicates are excluded from chosen rows. [M:ClockStore.swift:358-374,429-445,489-499](../Sources/Clockin/ClockStore.swift#L358); [M:ImportComparisonView.swift:24-26,158-169](../Sources/Clockin/ImportComparisonView.swift#L24). Core matching behavior is shared; phone sends duplicates too.
5. **Validation gaps can turn malformed data into failed saves or crashes.** Mac CSV accepts an infinite nonnegative numeric Duration; `deduplicationKey` converts duration to Int. Mac rates/goals accept Double values without finite checks, and invalid values can later fail JSON encoding or integer formatting. The phone adds core session-duration validation; both CSV parsers themselves remain identical. [M:CSVImporter.swift:33-44](../Sources/Clockin/CSVImporter.swift#L33); [M:ClockStore.swift:582-593](../Sources/Clockin/ClockStore.swift#L582); [M:SettingsView.swift:102-109,323-325](../Sources/Clockin/SettingsView.swift#L102). Also the pasted date-range parser constructs `start...end` without checking ordering, so a reversed recognized range can trap in both copies. [M:PastedTextImporter.swift:155-165](../Sources/Clockin/PastedTextImporter.swift#L155).
6. **Restore/add success can mask a disk-write failure.** `save()` catches errors into statusMessage, but callers then overwrite it with “Backup restored”, “Entry updated”, “Session deleted” or import success. In-memory state can look saved while the disk is stale. [M:ClockStore.swift:322-334,382-413,464-473,586-594](../Sources/Clockin/ClockStore.swift#L322). Shared with phone.
7. **Backups are described as more frequent than they are.** Settings fallback and Guide say created before each save; code limits automatic copies to once per 24 hours. Restore may therefore lack a fresh pre-restore recovery point. Modification-date sorting also uses copied files' metadata, which deserves validation across restore/restart. [M:SettingsView.swift:375-377](../Sources/Clockin/SettingsView.swift#L375); [M:GuideView.swift:35](../Sources/Clockin/GuideView.swift#L35); [M:ClockStore.swift:38-40,597-619](../Sources/Clockin/ClockStore.swift#L38).
8. **Manual editor preview and multi-day handling can mislead.** Preview uses end minus start, while saving an edited paused/imported record preserves its prior break gap. A note-only edit to a multi-day session cannot reconstruct the original end date from the one-day-plus-times UI and can shorten it. Overnight handling adds a fixed 86,400 seconds rather than a calendar day across DST. [M:ManualEntryView.swift:37-67,110-129](../Sources/Clockin/ManualEntryView.swift#L37); [M:ClockStore.swift:389-400](../Sources/Clockin/ClockStore.swift#L389). Same editor model on phone.
9. **Running and completed earnings use different rate dates.** Active earnings applies the effective rate at now to the whole duration; saved earnings applies the rule at session start to the whole duration. A session crossing a rate boundary can change earnings at clock-out. Neither prorates a session across rules. [M:ClockStore.swift:120-135,173-190](../Sources/Clockin/ClockStore.swift#L120). Shared with phone.
10. **Progress consistency issues.** First session unlocks before completion; shared-card badge count checks only 13 older conditions versus 46 displayed badges. Weekly comparison gives +100% for zero/zero; reports say completed sessions but earnings/hour includes active time. [M:ProgressView.swift:165,232-264](../Sources/Clockin/ProgressView.swift#L165); [M:ShareStatsView.swift:122-129](../Sources/Clockin/ShareStatsView.swift#L122).
11. **Money target at an exact multiple is inconsistent.** At exactly 10, 20, etc., the target equals current earnings and remaining is zero, but remainder-based progress resets to zero. [M:MainView.swift:327-361](../Sources/Clockin/MainView.swift#L327).
12. **Radio reports requested playback, not observed playback.** `isPlaying` becomes true immediately after `play()`, with no player-item error/status observation. `errorMessage` is cleared but never assigned a failure. A dead stream can still look on. [M:RadioController.swift:7-47](../Sources/Clockin/RadioController.swift#L7).
13. **Heatmap updates can lag edits.** Cache invalidation listens to session count and a 20-second timer, not all session/rate/running changes, so same-count edits or rate changes can show stale values until the next tick. Its Week/Month summary is still calculated across visible archive days, not one selected week/month. [M:HeatmapView.swift:149-185,220-238](../Sources/Clockin/HeatmapView.swift#L149).
14. **Updater six-hour claim has limited scope.** `lastChecked` is memory-only, set only after successful decoding; restart or repeated failures can issue checks more often than every six hours. [M:UpdateChecker.swift:23-27,53-56,85-94](../Sources/Clockin/UpdateChecker.swift#L23); [M:SettingsView.swift:159-172](../Sources/Clockin/SettingsView.swift#L159).
15. **Dead/obsolete UI paths.** `MainView.settingsSection` (634-775) is never mounted in body. Its inline pay/data controls, two-preset pin picker, hardcoded “10-minute focus beep”, and next-chime countdown are not working home features. Related importer/rate-sheet flags and duplicate helper wiring in MainView are leftovers with no reachable buttons in the mounted home. `ShareStatsCard` (ShareStatsView.swift:307-391) is an unused old card; exports instantiate LongCard/PageCard. Progress `avatar` (93) and MascotView `asset`/`enabled`/`level` (325-341), History `timer` (36), and RadioController `play(url:)` have no useful current UI use. Home mascot copy still says open Progress with the XP button, while that chip is not a button (MainView.swift:226-277,464-474). Do not count these as features to port.
