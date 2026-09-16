# Today performance audit

## Changes

- TimerCard, Today metrics, goal rows and desk mode use plain monospaced digits. `ActiveTimeline` disables animation transactions and stops scheduling when the content is covered, another tab is selected, or the scene is inactive. Separate cards use the same whole-second clock.
- Money Momentum updates once per second while working and once per minute otherwise. Progress no longer interpolates. Its static card decoration sits outside the timeline. Milestone layout is isolated from ticks; a fixed-width text slot contains the updating remaining amount, preserving horizontal and stacked layouts.
- The companion is outside the dashboard's ticking subtree. Its frame tasks and Core Animation loops now also depend on Today visibility, sheet presentation and desk mode. Existing Reduce Motion support remains.
- The badge shimmer uses a static `CAGradientLayer` with a repeating Core Animation translation, preserving the 4.2-second wait and 1.8-second sweep. It is removed while hidden or inactive. Level calculations also stop while hidden. The brief level-up effect remains event-driven.
- Completed daily totals were already cached. The current rate and completed monthly duration are now cached too, invalidated by store mutations and time-zone changes. Running elapsed time is added separately. Today totals now honor their supplied timeline date instead of reading another `.now`.
- Widget snapshots read completed totals directly. Subtracting running earnings calculated at a different instant could previously change the snapshot despite unchanged source data.

## Work after leaving the app

- `SessionMirror`: triggered by store/mood changes, app activation/backgrounding, theme/rate refresh and intent actions. It has no timer. Widgets and controls reload only after a changed snapshot is successfully written. Snapshot fields contain no changing generation timestamp; new tests verify equality across running ticks and inequality for real state changes.
- Live Activity: updates on those mirror events, gated by content-state equality. Running earnings can change between events, but there is no per-second update loop or background polling timer. Its own timer text is system-driven.
- Focus Chime: the foreground minute loop previously removed and re-added up to 20 requests. It now reconciles absolute fire dates, keeps matching requests and only adds/removes changed slots. Pause/stop still cancels immediately; revision checks reconcile requests added during an in-flight operation. Local notification delivery works while the app is suspended.
- Nudge: already compared pending requests by identifier, content, date, time zone and attachment before adding them. That behavior remains. It now reuses cached daily totals and avoids publishing an unchanged mood or rewriting unchanged persisted state.
- The foreground minute task exits whenever `scenePhase != .active`. Long-session reminders refresh on state changes and activation, not every second.
- Audio: Focus Chime uses local notification sounds and owns no audio session. Focus Radio starts audio only from Play. Its 500 ms monitor exists while radio playback is requested, including intentional background playback. Stop, failure, interruption and route loss cancel the monitor, discard the player and deactivate the audio session with `notifyOthersOnDeactivation`. No timer-driven audio activation was found.
- These findings do not establish the cause of the reported 6 to 7 second delay in other apps. That requires the new device trace.

## Complete haptic inventory

All 14 explicit calls are SwiftUI `sensoryFeedback`; no direct UIKit, Core Haptics or AudioServices haptic calls were found. None observes elapsed time, earnings, progress, or a render counter.

| File | Trigger | Event |
| --- | --- | --- |
| TimerCard.swift | `running?.isPaused` | Clock in, pause, resume, clock out/cancel; now gated by visible Today content |
| DeskMode/DeskModeView.swift | `running?.isPaused` | Same actions; gated by visible, active desk mode, avoiding feedback from the underlying Today screen |
| Insights/InsightsBadgesView.swift | `selectedBadge?.id` | Badge selection |
| Insights/InsightsAggregateHeatmapView.swift | `selectedStart` | Period selection |
| Insights/InsightsView.swift | `dailyGoalHours` | Daily goal edit |
| Insights/InsightsView.swift | `monthlyGoalHours` | Monthly goal edit |
| Insights/InsightsHeatmapView.swift | `grouping` | Grouping selection |
| Insights/InsightsHeatmapView.swift | `selectedDay` | Day selection or selection reset |
| Earnings/EarningsChartView.swift | `selectedDate` | Chart selection, only when non-nil |
| HistoryView.swift | `range` | Range selection |
| ManualEntryView.swift | `conflicts.isEmpty` | Warning when an edited entry begins overlapping another entry |
| BackupsView.swift | `message` | Backup operation result |
| Import/TimecardImportView.swift | `excluded` | Import row selection |
| Import/TimecardImportView.swift | `resultToken` | Completed import |

## Verification

- All 20 commands in `README.md` passed, with 851 `ok` lines. The extended rate/cache/snapshot suite reports `84 rate checks passed`; the notification reconciliation suite reports `28 chime checks passed`.
- The new timeline-date regression failed against the original implementation and passed after the fix. Additional checks cover live/paused totals, rate boundaries, monthly rollover, cache invalidation, snapshot stability, notification top-ups and unchanged requests.
- Changed production Swift files pass parsing. The timeline helper and Core Animation shimmer also pass isolated iOS Simulator Swift 6 strict-concurrency type checking. This is not a substitute for the full app build.
- The requested build command was attempted unchanged:

```sh
cd iOS && xcodebuild -project Clockin.xcodeproj -scheme Clockin -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/clockin-perf-fix-dd build CODE_SIGNING_ALLOWED=NO
```

It returned `BUILD FAILED` because the sandbox denied the SwiftUI macro plugin: `sandbox-exec: sandbox_apply: Operation not permitted`, followed by the existing `PaletteEnvironment.swift` `@Entry` macro failing to load. Simulator services were also unavailable. Full app type checking encountered the same sandbox restriction for SwiftUI state macros.

No CPU percentage, on-device haptics, visible layout or frame pacing has been verified in this environment. Rebuild outside the sandbox, repeat the same Today/History trace with a running session, and check sheet/tab/desk transitions, inactive/background behavior, Reduce Motion and larger text sizes. Logs are in `/tmp/clockin-perf-build.log` and `/tmp/clockin-perf-checks/`.

No project configuration, signing, version number, commit or push was changed.
