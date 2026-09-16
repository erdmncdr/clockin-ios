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

`Shared/Theme/HapticEvent.swift` contains the pure event mapping and enabled policy.
`Shared/Theme/Haptics.swift` is the only hardware/SwiftUI adapter. It lives beside
the shared button styles so both targets compile without project changes;
`WIDGET_EXTENSION` excludes all playback code and makes press feedback a no-op.
UIKit generators are allocated on first use, prepared for a deliberate action,
and reused. There is no timer, background task, or per-render generator allocation.

Settings > Appearance > Haptics persists `Clockin.HapticsEnabled`, default true.
Every app-controlled haptic, including the former 14 calls, passes this gate.
Turning it off is silent. Turning it back on gives one selection confirmation.
SwiftUI playback is also gated on the active scene; immediate UIKit playback
requires the foreground active application. The app does not read or change the
iOS system haptics setting.

| File / interaction | Feedback | Trigger and duplicate prevention |
| --- | --- | --- |
| ButtonStyles / ActionButtonStyles: hitTarget, pressable, Primary, Secondary, Danger | Light impact | Only false-to-true `isPressed`; never release or a held press. Semantic controls below suppress this style haptic. |
| Today header Settings and Add; Today session rows; level badge; companion text link; goal card; radio Play/Stop; summary Done; import Done / Change source; Share PNG | Light impact | Custom button press only. Opening a sheet or changing tabs programmatically adds nothing. |
| TimerCard and DeskMode: Clock in | Start | Local action signal; no observer of running state. |
| TimerCard and DeskMode: Pause / Resume | Light impact | Local action signal; style feedback suppressed. |
| TimerCard and DeskMode: Clock out; TimerCard: confirmed cancellation; ReminderEndTime: successful Clock out | Stop | Local action signal; no second feedback from the covered Today screen. |
| Root tab bar | Selection | User-written tab binding only; notification/deep-link navigation is silent. |
| History range; earnings chart day tap; USD/TRY picker | Selection | Range or explicit selection changes. Clearing the chart selection is silent. This checkout has no History page-swipe control. Vertical scrolling stays silent. |
| Heatmap grouping and 4/12/all weeks; day / week / month cell; Today shortcut selecting a different cell | Selection | User selection only; no style haptic, none on reset, auto-scroll or data refresh. |
| Badge cell | Selection | Non-nil badge selection only; style suppressed and dismissal silent. |
| Settings Haptics, Focus companion, Desk mode, Focus chime, Nudges; Theme, Tone and Long session reminder pickers; chime interval stepper | Selection | Explicit control writes, not preference observers or normalization on appearance. |
| Settings Earlier work toggle | Selection when enabled; Warning when requesting removal | Removal opens confirmation without a selection haptic. |
| Goal editor daily/monthly steps and valid text commits | Selection | A changed value from the control sends one signal. The two former parent observers were removed. |
| Rate editor Has end date | Selection | Explicit toggle binding. |
| Import row / All / None / leftover row; Period and These entries segments | Selection | Explicit selection signal. Clearing selections after import or a new source is silent. |
| Share stats Privacy / Page / Export segments | Selection | Explicit selection binding. |
| Manual entry Add / Save; rate period Add / Save; rate-change prompt Today / chosen date / Always | Success notification | Only after a successful save; immediate outcome buttons have no press haptic. |
| Automatic backup restore; Settings restore from file | Success or Error notification | Actual Bool result, not the message string. Repeating the same outcome still gives feedback. |
| Finished timecard import | Success notification | Successful persisted import only; import action style suppressed. Failed import gives Error. |
| Entry/rate save failures; invalid goal text; import parse/read/empty-paste failures; backup open/restore failures; invalid reminder end time | Error notification | Explicit attempted operation only. |
| Session deletion; rate-period deletion; cancel-session prompt; import deletion prompt; backup replacement prompt; remove earlier rate prompt | Warning notification | Confirmation becomes presented, never on dismissal. No immediate press haptic on the prompt-opening action. |
| Focus companion tap / accessibility action | Soft impact, intensity 0.6 | One direct reaction event; works with Reduce Motion without starting animation. |

The previous overlap-warning feedback observed computed conflicts and could react
to store changes. It is now visual only; failed saves give Error. Goal preferences,
backup messages and import selection resets no longer act as hardware triggers.
The remaining value triggers represent explicit UI selection or confirmation.
Session actions retain their Start / Stop / light mapping, but no longer vibrate
when widgets, Shortcuts, backup restore or notifications change the store.

No haptic observes elapsed time, earnings, progress, rates, snapshots, scroll
position, appearance, scene activation or companion animation frames. The
performance changes above, including `ActiveTimeline` scheduling and disabled
animation transactions, remain unchanged. No playback is added to widgets,
Live Activities, intents or notification handlers.

## Performance baseline verification

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

## Haptics verification

- All 21 README check suites passed, with 911 `ok` lines. New output: `58 haptics checks passed`. Import and backup tests now also assert the actual success/failure result used by the outcome haptic (`26 import checks passed`, `29 backup checks passed`). Commands without a cache path used `-module-cache-path /tmp/clockin-haptics-module-cache` because the default user cache is outside the sandbox's writable roots.
- The helper and custom button styles passed isolated Swift 6 strict-concurrency type checking against the iOS 17 Simulator target, both as app code and with `WIDGET_EXTENSION` / application-extension restrictions. All 28 changed/new production Swift files passed parsing. `git diff --check` passed.
- The requested build was attempted on the final source:

```sh
cd iOS && xcodebuild -project Clockin.xcodeproj -scheme Clockin -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/clockin-haptics-dd build CODE_SIGNING_ALLOWED=NO
```

It exited 65 with `BUILD FAILED`: `sandbox-exec: sandbox_apply: Operation not permitted`, followed by the existing `PaletteEnvironment.swift` `@Entry` macro failing to load. A separate full-source type-check attempt also hit the sandbox's SwiftUI `@State` macro restriction. These checks do not establish a successful full app build or visible UI behavior.

Logs: `/tmp/clockin-haptics-build.log`, `/tmp/clockin-haptics-checks/summary.txt`, `/tmp/clockin-haptics-typecheck.log`, `/tmp/clockin-haptics-styles-typecheck.log`, `/tmp/clockin-haptics-widget-typecheck.log`, `/tmp/clockin-haptics-parse.log`.

On a phone, check every row of the inventory above with Haptics on and off. Also leave an active timer running, scroll History and the heatmap, dismiss sheets, switch Today/desk mode, background the app and operate a widget or Live Activity. Only the listed deliberate foreground actions should vibrate. Haptics cannot be felt in the simulator; device behavior and full UI integration remain unverified here.
