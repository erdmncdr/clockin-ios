# Brief 04 result: history, Mac guide and desk mode

Implemented in the allowed files. No commit, project edit, preference migration or edit to the other person's files was made. `docs/mac-plan.md` and its phase 2 status, `docs/mac-port-inventory.md`, the old Mac History/Guide and the current shell were read. The plan itself remains unchanged because it is outside this brief's edit allowlist.

## Mac behavior

### History

- The existing History toolbar now has **By day / Sessions**, bound to `Clockin.HistoryGroupByDay`, Bool, default `true`. Existing Mac choices are read directly.
- By day keeps the shared day totals and overlap warnings. Clicking a day header expands/collapses its entries, with a chevron and localized Expanded/Collapsed accessibility value.
- The old app used `@State expandedDays: Set<Date> = []`, so **all days initially start collapsed**. This port does the same; expansion survives paging/mode switches during that view's lifetime but is not saved to defaults.
- Sessions uses the current page's shared `snapshot.sessions`, sorted newest first. Each row shows its start date, including the year, and time. The date formatter change also applies to other Mac `SessionRow(showsDay: true)` call sites; iOS formatting is unchanged.
- Native single-row selection uses the session UUID. Double-click or context-menu **Edit** opens the shared editor. Context-menu **Delete**, or Delete with a row selected, opens the existing shared confirmation alert. Selection clears on page/mode changes, day-header toggles and removal of the selected session.
- Period paging, ranges, earnings chart, TRY handling, totals, overlap calculations, shared edit sheets and delete confirmation remain shared. No data or earnings calculation changed.

### Usage guide

The existing list, sections and expandable topics remain. The Mac branch hides haptics, phone rotation, widgets, Live Activity/Dynamic Island and Control Center/Lock Screen/Action Button topics. Mac-specific versions of the edit/import, companion, chime and radio explanations remove swipe-only deletion, the Today gear route, widget references and silent-switch/phone-audio instructions.

Added Mac topics cover:

- History's two list modes and view-local expansion.
- Menu bar left-click panel, right-click menu and dismissal.
- Minimal mode and hours, seconds, earnings, TRY and goal fields.
- Pinned timer and Money / Compact / Goal / All / Total layouts.
- Global ⌥⌘I / P / O / E actions, including resume semantics.
- In-app Clock menu shortcuts, section shortcuts and Desk Mode.
- Full-screen desk mode, controls, summary, display wake behavior and exit.
- Sidebar Settings / ⌘, and automatic update checks.

Added **25 English source keys with Turkish translations**. Existing catalog entries are semantically unchanged, including shared topic titles and all iPhone copy. Keys remain sorted. No old Mac radio instructions were copied blindly: the guide describes the current shared controller's immediate station switching.

### Desk mode

New `ClockinMac/DeskModeWindow.swift` contains a main-actor `DeskModeWindowController`, a small `NSWindow` subclass and the SwiftUI host.

- Opens/reuses one normal closable, resizable window and requests native full screen. Repeated requests during entry do not toggle it back out. Late full-screen notifications are checked against the current window.
- The window hosts the **unchanged shared `DeskModeView`**, using `SharedStore.clock` and `SharedStore.exchangeRates`. It receives the same language/locale wrapper, palette, tint, font design, color scheme, grouped form style, timer persistence alert and theme-triggered mirror refresh as the main content/root combination. No second store is created.
- `onClockOut` presents the real `SessionSummaryView` as a sheet in that window. While the summary is shown, desk content is marked inactive.
- Esc has SwiftUI exit-command and AppKit cancel-operation paths. Leaving native full screen closes the desk window; its close button also closes it. Closing does not change the timer's running/paused state.
- A Combine subscription reads the newly published store data, rather than stale `objectWillChange` state. While the window exists and `running?.isPaused == false`, it holds an IOKit `IOPMAssertionCreateWithName` assertion of type `kIOPMAssertionTypePreventUserIdleDisplaySleep`. Pausing, clocking out/cancelling, or closing releases it; resuming/reopening reacquires it. Failed creation is not recorded as a valid assertion. IOKit calls and window lifecycle stay on the main actor. This is the display-idle assertion described in Apple's [assertion types documentation](https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiontypes).
- `MacCommands` adds **View > Desk Mode (⌃⌘F)** alongside the existing View commands.
- `MacSettingsSection` adds **Open Desk Mode** next to **Show home in desk mode**, bound to the existing `WardrobeState.deskKey` (`Clockin.WardrobeShowHomeInDeskMode`). The iOS landscape preference is not used on Mac.

`DeskModeView.swift` needed **no guards or other edits**: its real body type-checks on both platforms. It does not reference `DeskMode.enabledKey`. `DeskModeOrientation.swift` remains untouched and excluded on Mac. `SettingsView.swift` also remains untouched: its original iOS-only desk section is preserved; the Mac controls live in the already-included `MacSettingsSection`.

## iOS-visible changes and no-op audit

| File / changed area | iOS effect |
| --- | --- |
| `HistoryView.swift:35`: `List {` becomes `sessionList {`. New helper at lines 168–179; active iOS lines are the builder declaration and `List(content: content)`. | A transparent construction helper: returns the same unselected SwiftUI List with the same content and modifiers. No added iOS state, gestures, toolbar items or list behavior. The existing grouped rows and both swipe actions are retained verbatim in `#else`. |
| All other History insertions: preference/selection state, Mac sections, toolbar picker, selection resets and row helper. | Under `#if os(macOS)`, absent from the iOS compilation. A source comparison resolving OS guards and inlining the helper matched the previous iOS source, ignoring blank lines. |
| `SessionRow.swift:28–32`: conditional date formatter. | The iOS branch is exactly the prior formatter. OS-resolved iOS source compared byte-for-byte equal to HEAD. |
| `Guide/UsageGuideView.swift`: conditional topic branches and Mac topic insertion. | All prior iOS topics, ordering, wording, availability checks and UI remain. OS-resolved iOS source compared byte-for-byte equal to HEAD. |
| `Shared/Localizable.xcstrings`: 25 additive entries. | New keys are used by Mac-only branches/files. Every existing entry was compared with the starting catalog and remained equal; no current iPhone translation was replaced. |
| New window file and changes to Mac commands/settings. | Only in the Mac source folder/target. |

No changes to `ClockinMac/MacRootView.swift`, `ClockinMac/ClockinMacApp.swift`, `ClockinMac/MacAppServices.swift`, `Clockin/Views/DashboardView.swift` or `Clockin/Views/TimerCard.swift`. The pre-existing brief file is untouched.

## Required Xcode project change

**Remove `Views/DeskMode/DeskModeView.swift` from the Clockin folder's `ClockinMac` membership exceptions** in `Clockin.xcodeproj` (currently the exception at project line 53). Keep `Views/DeskMode/DeskModeOrientation.swift` excluded. `DeskModeView` is now referenced by the new Mac host, so this removal is necessary before building the target.

`ClockinMac` is already a file-system-synchronized source group attached to the Mac target: the new `DeskModeWindow.swift` should be picked up automatically. Confirm it belongs only to `ClockinMac` and that the shared string catalog remains included. No new package or entitlement is needed. I did not edit the project.

## Verification

### SDK type-checks

Both partial checks passed with exit 0 and no diagnostics:

```sh
swiftc -typecheck -swift-version 6 -strict-concurrency=complete \
  -module-cache-path /tmp/clockin-parity-check/cache \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -target arm64-apple-macos14 <temporary source copies>

swiftc -typecheck -swift-version 6 -strict-concurrency=complete \
  -module-cache-path /tmp/clockin-parity-check/cache \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios17.0-simulator <temporary source copies>
```

The installed SDKs are SDK 27; the deployment targets checked are macOS 14 and iOS 17 simulator. The exact source lists/commands and logs are `/tmp/clockin-parity-check/{mac,ios}-command.txt`, `mac.log` and `ios.log`; the runner is `run.py` in that directory.

Actual checked bodies include History, SessionRow, UsageGuide, unchanged DeskModeView, SessionSheets/delete alert, SessionSummary, all Earnings views/models, shared store/model/import/backup/exchange-rate code, goals/insights dependencies, rolling renderer, haptic/button/platform helpers and timer-persistence alert. The Mac pass additionally checks the full new DeskModeWindow and changed MacCommands/MacSettingsSection, plus MacShellSupport, against real AppKit and IOKit declarations. The actual ActiveTimeline/schedule and card/section-title helpers were copied unchanged into the temporary harness from their enclosing files.

Temporary stand-ins, **only under `/tmp`**:

- `@CheckState<Value>` aliases the actual `SwiftUI.State<Value>` wrapper in copied sources, following brief 02. Production `@State` is untouched. A separate run without this substitution reproduced `sandbox-exec: sandbox_apply: Operation not permitted` and the missing `SwiftUIMacros.StateMacro` plugin error; see `native.log`.
- Manual palette/content-active environment keys and an ordinary LanguageSwitch class replace macro-backed environment/Observation plumbing.
- Empty companion/home renderers, celebration/nudge services, manual-entry/start and unrelated Settings child views; minimal SessionMirror/chime interfaces.
- In the Mac pass, minimal existing shell/service interfaces for main window/root, panel, updater and global-shortcut controller. **No substitute for the new desk controller, AppKit or IOKit.** Sparkle and the entire app/service integration are not checked by this harness.

Other checks passed: `python3 -m json.tool Shared/Localizable.xcstrings`, existing-entry equality, all 25 new Turkish translations present, iOS branch source comparisons, and `git diff --check`.

### Required README check tails

Ran the exact README source lists/flags. For commands without an explicit cache, added only `-module-cache-path /tmp/clockin-parity-check/cache` to keep compiler output within writable storage. All exit codes were 0. Logs are `/tmp/clockin-parity-check/{earnings,historytry,sessiondisplay,feedback}.log`.

```text
# earnings
ok: all days covered once: 2028/8
ok: all days covered once: 2028/9
ok: all days covered once: 2028/10
ok: all days covered once: 2028/11
ok: all days covered once: 2028/12
284 total earnings and month-week checks passed

# historytry
ok: widget shifts only required distance 350.0/180.0
ok: widget preserves companion spacing 350.0/400.0
ok: widget fits trailing edge 350.0/400.0
ok: widget shifts only required distance 350.0/400.0
ok: smallest widget centers normal ready group
87 history TRY and widget checks passed

# sessiondisplay
ok: note display never rewrites saved metadata
ok: real pasted parser retains synthetic source
ok: real pasted entry hides source inside generated note
ok: real CSV parser retains synthetic source
ok: real CSV entry uses neutral fallback
61 session display checks passed

# feedback
ok: reopening preserves the long-session duration, end date, and seconds
ok: the changed note persists
ok: editing the end time preserves its explicit end date
ok: new time-only entries still infer overnight shifts
ok: equal new times do not silently turn into 24 hours
22 feedback checks passed
```

## Not verified here

No full Xcode build, app launch, simulator run or live UI test was performed. Complete macro expansion, target membership/linking/resources and integration with the other person's in-progress service/root changes remain for the real builds after the exclusion is removed.

In the app, verify native selection/double-click/context menus/Delete confirmation, header click targets, both history modes across populated and empty pages, English/Turkish fit, and accessibility. Verify View-menu placement and ⌃⌘F routing alongside the system's standard full-screen shortcut. Exercise desk mode from both entry points, repeated entry, Esc/close/full-screen exit, summary dismissal, language/theme changes, home on/off, and timers controlled from the panel/global shortcuts. Check `pmset -g assertions` for acquisition/release on run/pause/resume/stop/close, including save rollback. The type-check and Foundation checks do not prove those native behaviors, animation/layout quality, actual display-sleep prevention or updater operation.
