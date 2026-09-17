# Today performance audit

## Changes

- TimerCard, Today metrics, goal rows, Money Momentum amounts and desk mode use `RollingNumberText` with monospaced digit cells, as described below. `ActiveTimeline` still disables animation transactions and stops scheduling when the content is covered, another tab is selected, or the scene is inactive. Separate cards use the same whole-second clock.
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

## Rolling digits without the numeric-text blur

The tester baseline is about 30% Clockin CPU with `.contentTransition(.numericText())`
versus about 2.5% with plain text on Today during a running session. In the supplied
Time Profiler findings, about a third of samples were in `vSepConvolveARGB8bgf_vec`
below `RBInterpolatedDisplayListContents renderInContext`. These numbers are the
reported device baseline, not measurements made in this checkout.

`RollingNumberText` lays out individual characters in `HStack(spacing: 0)`, with
monospaced digits and cell identity counted from the right. Each changed digit
has two glyphs: the old glyph moves out and fades, the new glyph moves in and
appears. The only animated properties are `offset` and `opacity`, with a 0.25 s
ease-out curve. A rectangular `.clipped()` bounds each digit. There is no blur,
content transition, drawing group, alpha mask, per-frame timeline, custom
animatable drawing or repeating task. This removes the numeric-text interpolated
content effect that triggered the observed CPU blur path; transform/alpha
animation can be composited by the render server. It does not establish zero CPU
cost: formatting, diffing, layout and SwiftUI updates still need device profiling.

Direction comes from the underlying numeric value supplied beside the formatted
string. Thus all changed digits roll up in `00:59` to `01:00`, while remaining
amounts roll down as they decrease. Symbols, punctuation, spaces and letters change
instantly. Any character-count change makes that whole update instant, including
new hours or thousands separators. Initial appearance and safety-switch changes
also snap to the current value. Unchanged formatted strings do not change render
state. A fresh changed pair replaces an interrupted pair, so old layers do not
accumulate. Each pair retains at most two glyphs, with the outgoing glyph fully
transparent after 0.25 s.

The timeline's disabled animation transaction remains intact. Only a changed
pair locally enables its own offset/opacity animation. Progress bars and the rest
of the ticking subtree do not acquire an animation. Haptics, widget and Live
Activity code are unchanged.

Call sites: TimerCard's timer, earnings and TRY; TodayCard's TODAY, EARNED and TRY;
goal worked/remaining values; Money Momentum's amounts and fixed-slot remaining
label; desk mode's timer, earnings, TRY and today summary. Existing semantic fonts,
explicit timer sizes, scale limits and palette font design remain available.
The component accepts `Font` and an optional design, inheriting the theme when
omitted. It deliberately skips the modifier in that case because
[Apple documents that `fontDesign(nil)` removes inherited design](https://developer.apple.com/documentation/swiftui/view/fontdesign(_:)).
Glyph height comes from SwiftUI layout rather than a fixed pixel estimate, so
semantic fonts follow Dynamic Type. VoiceOver gets the full formatted value as
one label; individual cells are hidden. Existing goal/desk accessibility summaries
continue to override their child labels.

### Shared safety switch

`RollingAnimationPolicy.shared` is one main-actor observable object, following the
app's existing ObservableObject pattern. It owns one observer for
`NSProcessInfoPowerStateDidChange` and one for
`ProcessInfo.thermalStateDidChangeNotification`, for the process lifetime. It
reads thermal state before registering, as required by
[Apple's thermal notification documentation](https://developer.apple.com/documentation/foundation/processinfo/thermalstatedidchangenotification).
Callbacks refresh values on the main actor; unchanged readings are not published.
There is no observer per glyph and no polling loop.

The pure `rollingAnimationAllowed` function requires Reduce Motion off, Low Power
Mode off, thermal state nominal or fair, `clockinContentActive`, an active scene,
and an appeared view. Serious, critical and unknown thermal states disable motion.
The environment supplies tab/sheet/desk visibility from the existing performance
fix; appearance/disappearance and scene phase add local lifecycle gates. Re-enabling
motion does not replay an update made while disabled. In-flight pairs are removed
immediately when a gate closes.

### Device acceptance measurement

1. Use the same physical iPhone, OS, build configuration, data and view position
   for baseline and rolling builds. Enable a running session, USD plus TRY, daily
   and monthly goals and Money Momentum. Keep brightness, companion settings and
   other activity consistent. Start with nominal thermal state and Low Power Mode
   and Reduce Motion off. Let launch work settle, then record at least 60 seconds
   with Today visible, repeating the capture three times.
2. In Instruments Time Profiler, select only Clockin and report steady-state
   average CPU and peaks. The target is **under 5% Clockin CPU**, compared with the
   reported 2.5% plain-text baseline. Inspect the call tree for
   `vSepConvolveARGB8bgf_vec` and `RBInterpolatedDisplayListContents renderInContext`.
   The per-second rolling effect must no longer produce the old blur stack.
   Check Animation Hitches/Core Animation too, so work moved to the render server
   does not hide poor frame pacing or excessive rendering cost.
3. Exercise `09` to `10`, minute/hour carries, decreasing remaining money and
   thousands-separator insertion/removal, including Turkish formatting and
   currency on either side. Confirm only changed digits move, direction is
   correct, and each roll ends in about 0.25 s. Check narrow layouts, every theme,
   larger accessibility text, portrait/desk rotation and VoiceOver reading one
   value. Trigger a second update during a roll and a length change during a roll;
   confirm no lingering glyphs or clipped final text.
4. Repeat with Reduce Motion and Low Power Mode individually enabled, including
   toggles mid-roll. Values should update instantly and no old animation should
   replay after re-enabling. Cover Today with a sheet, switch tabs, open desk mode,
   and background/foreground the app. Covered/inactive content must stop rolling.
   Verify serious/critical thermal gating when those states are available; the
   pure tests exercise every thermal case without artificially heating a phone.
5. Record device model/OS, build configuration, average/peak CPU, thermal state,
   trace duration and trace filename. CPU, energy and visible behavior remain
   unverified until these device results are supplied. No simulator was run here.

### Checkout verification

- All 24 README check suites passed, with 1414 `ok` lines. The new suite reports
  `176 rolling checks passed`, including all 128 combinations of the six policy
  inputs (four thermal states and five Boolean gates).
- All eight changed/new production Swift files passed parsing. The pure helper
  and shared policy passed isolated Swift 6 strict-concurrency type checking for
  the iOS 17 Simulator target. `git diff --check` and source checks for prohibited
  rendering effects passed.
- The requested command was run on the final source:

```sh
cd iOS && xcodebuild -project Clockin.xcodeproj -scheme Clockin -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/clockin-digits-dd build CODE_SIGNING_ALLOWED=NO
```

It exited 65 with `BUILD FAILED`. The sandbox denied the compiler macro plugin
with `sandbox-exec: sandbox_apply: Operation not permitted`; the existing
`PaletteEnvironment.swift` `@Entry` macro then failed to load in ClockinWidgets.
The isolated rolling view type-check attempt hit the same restriction for SwiftUI
`@State` macros. Full application compilation and visual animation behavior
therefore remain unverified. Simulator services were unavailable and no simulator
was launched.

Logs: `/tmp/clockin-digits-build.log`,
`/tmp/clockin-digits-checks/summary.txt`, `/tmp/clockin-digits-checks/rolling.log`,
`/tmp/clockin-digits-parse.log`, `/tmp/clockin-rolling-policy-typecheck.log`, and
`/tmp/clockin-rolling-view-typecheck.log`.

No project file, signing setting, version number, haptic behavior, widget or Live
Activity source was changed. No commit or push was made. The under-5% CPU target
is pending the device measurement above.
