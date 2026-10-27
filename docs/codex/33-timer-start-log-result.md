# 33 — Timer start log and guards

Implemented in the existing isolated worktree. No commit was created.

## Changes by file

| File | Change |
| --- | --- |
| `Shared/Core/TimerStartLog.swift` | Main-actor observable device-local log, Codable entries, stable raw origin/action/provenance values, localized titles, newest-first retention of 100 entries, reload and Clear. Adds the iPhone external-start preference (missing value means enabled). Production storage is `UserDefaults.standard`, key `Clockin.TimerStartLog.v1`; tests inject an isolated suite. |
| `Shared/Core/ClockStore.swift` | Adds default `.app` origin parameters to clock-in, resume and clock-out, plus an injectable log. Records only after successful persistence. Sync records session appearance, replacement start, resume and disappearance, including provenance and whether a session was already present. |
| `Shared/Intents/ClockIntents.swift` | Widget/Siri/Shortcuts/Live Activity/Action button actions use `.widget`. Shared start/out helpers return the actual result dialog and accept the Control Center origin. On iOS, disabling external starts refuses both start and resume; pausing and clock-out remain available. |
| `Shared/Intents/SetClockedInIntent.swift` | Uses `.controlCenter` for both directions and returns the underlying dialog, including refusals/errors. Keeps the deferred mirror refresh for every result, so a refused start restores the control's real state. |
| `ClockinMac/ExternalClockCommand.swift` | Reads Apple Event `keySenderPIDAttr`, resolves the running sender, compares canonical executable URLs with this app. Only a match runs immediately as `.pulse`; missing or other senders get an activating app-modal localized confirmation, and acceptance runs as `.link`. Already-satisfied commands do not alert. Prevents nested link confirmation dialogs. |
| `ClockinMac/KeyboardShortcuts.swift` | Adds `Clockin.GlobalShortcutsEnabled`, default true. Startup respects it; disabling unregisters all four keys and their handler while retaining the store for re-enabling. Queued hot-key actions check the switch again. Timer actions use `.shortcut`. |
| `Clockin/Views/TimerLogView.swift` | Shared row with action, relative date, clock time, localized origin and sync details. iOS list shows all retained entries with toolbar Clear and the requested empty text. Mac section shows the newest 10 and Clear; Clear removes the entire retained log. |
| `Clockin/Views/SettingsView.swift` | iOS Today section gets the external-start toggle and explanatory footer. Data gets the Timer log navigation row. |
| `ClockinMac/MacSettingsSection.swift` | General includes the shortcut toggle above the existing key list, Inspector-conflict footer, and Timer log section. |
| `Shared/Localizable.xcstrings` | Appends 23 keys with explicit English and Turkish translations, preserving existing entries and ordering. Existing action labels, Cancel and Global shortcuts reuse existing translations. |
| `Shared/Sync/Cloud/SyncPreferences.swift` | Adds the three keys to `deviceKeys`. The existing `types` allowlist remains unchanged: no log or guard preference can be accepted for sync. This is the only file changed under `Shared/Sync/Cloud`. |
| `Tests/manual/timerlog/main.swift` | Retention, ordering, Codable reload, stable raw values, Clear/corrupt JSON, real ClockStore origin propagation, sync transitions, no-ops and failed-persistence regression checks. Uses only temporary archives and an isolated defaults suite. |
| `README.md` | Adds the timer-log swiftc command; adds `TimerStartLog.swift` to all six existing explicit ClockStore compile commands. |
| `Tests/manual/syncapp/run` | Adds the new ClockStore dependency to its source list. |
| `Tests/manual/iphonefollowsmac/run` | Adds the new ClockStore dependency to its source list. |
| `Tests/manual/macliveactivitytip/run` | Adds the new ClockStore dependency to its source list. |
| `Tests/manual/crashaudit/platform-run` | Adds the new ClockStore dependency and adjusts the iOS source slice to preserve its previous coverage. |

No project-file changes were necessary: the targets use filesystem-synchronized source groups. No dependencies, sync record formats, website, relay, or Chrome extension files were changed.

## Call-site audit

All product calls to `ClockStore.clockIn`, `resume`, `clockOut`, and `applySynced` were searched. App calls retain the default origin deliberately.

| File / caller | Operation(s) | Origin |
| --- | --- | --- |
| `Clockin/Views/TimerCard.swift` | Resume button (line 90), clock-out button (99), clock-in button (119) | `.app` |
| `Clockin/Views/ManualStartView.swift` | Start with elapsed time and note (82) | `.app` |
| `Clockin/Views/DeskMode/DeskModeView.swift` | Both layout branches: resume (188, 203), clock-out (193, 208); idle clock-in (217) | `.app` |
| `Clockin/Views/ReminderEndTimeView.swift` | User-selected end time (64) | `.app` |
| `Clockin/Audio/LongSessionReminderController.swift` | User taps the app's reminder notification clock-out action (130) | `.app`; app-owned reminder action, not an App Intent |
| `ClockinMac/MenuBarPanelView.swift` | Clock-in (200), resume branch (212), clock-out (216) | `.app` |
| `ClockinMac/MacCommands.swift` | In-app menu clock-in (56), clock-out (59), resume branch (63) | `.app` |
| `ClockinMac/ClockinMacApp.swift` | `--clock-in` debug argument (54) | `.app` |
| `ClockinMac/MacRootView.swift` / desk window | No direct timer mutation calls; displayed timer/desk controls use the app rows above | `.app` through those controls |
| `Shared/Intents/ClockIntents.swift`, `ClockInIntent.run` | Resume (43), new clock-in (51) | `.widget` from `ClockInIntent.perform`; `.controlCenter` from `SetClockedInIntent` |
| Same file, `ClockOutIntent.run` | Clock-out (83) | `.widget` from `ClockOutIntent.perform`; `.controlCenter` from `SetClockedInIntent` |
| Same file, `TogglePauseIntent.perform` | Resume (117); pause is deliberately not logged | `.widget` |
| `ClockinMac/KeyboardShortcuts.swift` | ⌥⌘I start/resume (71–72), ⌥⌘P resume (74), ⌥⌘O out (75) | `.shortcut`; ⌥⌘P pause and ⌥⌘E navigation add no entry |
| `ClockinMac/ExternalClockCommand.swift`, `ExternalClockCommand.perform` | Start (32), resume (33), out (35) | `.pulse` for same-executable sender; `.link` only after other-sender confirmation |
| `Shared/Sync/SyncCoordinator.swift`, `apply` (349) → `ClockStore.applySynced` | Appearing/replaced running start, paused-to-active resume, disappearing session | `.sync`, preserving `.remoteChange` / `.initialImport` |

The log's timestamp is when the change was recorded, not a backdated manual start/end. `wasRunning` means a session existed before the sync apply (including a paused session); the UI says “Session already present” / “No previous session”. Identical sync applies, note-only changes and pause-only changes are not starts. Canceling a running session or restoring a backup is outside the requested three-action log.

## Verification

Passed from the changed worktree:

- The exact new `swiftc` command in README: all timer-log and persistence regression checks, Swift 6 strict concurrency and warnings as errors.
- Existing README ClockStore commands: import (102), backups (38), sessions (20), maccompat (375), rates (84), feedback (22).
- `Tests/manual/syncapp/run`: 105 checks; `Tests/manual/syncapp/run typecheck`: macOS 14 and iOS 17 Simulator, strict concurrency/warnings as errors.
- `Tests/manual/iphonefollowsmac/run`: 34 remote-start detector checks, 8 activity decisions, 24 Live Activity lifecycle checks. Its `typecheck` mode also passed for the iOS detector, notification adapter, mirror and ActivityKit sources.
- `Tests/manual/macliveactivitytip/run`: 27 checks.
- `Tests/manual/crashaudit/platform-run`: 33 checks plus iOS SDK typecheck. A separate direct strict typecheck of `AppLanguage.swift`, `TimerStartLog.swift`, and `TimerLogView.swift` also passed.
- `python3 Tests/manual/crashaudit/typecheck.py`: all four targets passed with Swift 6, complete strict concurrency and warnings as errors: `Clockin` / `ClockinWidgets` at iOS 17 Simulator; `ClockinMac` / `ClockinMacWidgets` at both macOS 14 and 15. This includes the new UI, App Intent helpers, sender PID API, alert, and hot-key switch.
- Localization JSON parsed; all 23 additions contain English/Turkish values; every preexisting entry and its order is unchanged. `git diff --check` passed. Changed-file audit confirmed the requested scope.

All affected `Tests/manual/sync/run` modes passed as well: default (276 checks, including rejection of all three new device-local keys and the five-year simulation), `persistence` (30), `capability` (2; seven entitlement-free launches), `codec` (35), `send` (37), and `typecheck` (macOS 14 / iOS 17 Simulator). These tests used local fixtures and did not perform authenticated CloudKit operations.

### What was not compiled or exercised

No Xcode scheme build, linking, signing, archive, resource compilation, or App Intents metadata extraction ran; the owner builds the apps. The existing full-target SDK harness uses documented temporary substitutes for the palette `@Entry`, `@State` macro spelling and `LanguageSwitch` observation because macro subprocess sandboxing is restricted here. It does not alter production sources. Successful typechecking therefore does not claim a successful native Xcode build or macro expansion.

No built-app UI interaction, real widget/Control Center/Siri refusal, hot-key registration/unregistration, modal confirmation, native-host Apple Event delivery, or signed two-device iCloud test ran. Those require the owner checks below. The six SDK-check logs are under `/private/var/folders/0x/s_c9czd536s9vs8npkcmpn7w0000gn/T/clockin24-sdk-z6ope3v4/`; the summary is `/tmp/clockin33-typecheck.log`. Existing regression logs are `/tmp/clockin33-*.log`.

## Owner checks in built apps

1. Build the `Clockin` and `ClockinMac` schemes in Xcode, including their widget extensions. Check both English and Turkish layouts, long origin labels, relative dates/time, empty state, and Clear. Generate more than 10 events to confirm Mac shows 10 while iOS keeps up to 100; reopen to verify local persistence.
2. On iPhone, start/resume/out with app buttons and then widget, Live Activity, Siri/Shortcuts/Action button. Confirm `.app` versus the deliberately combined `.widget` title. Test Control Center start/resume/out separately; it must say Control Center.
3. Turn off external starts on iPhone. Widget/Siri/Control Center starts and resumes must refuse with the settings dialog; a paused session must stay paused. Control Center must settle to actual state. Pause and clock-out must still work. App buttons and incoming iCloud changes remain usable. Relaunch and test the saved switch, then re-enable.
4. On Mac, disable global shortcuts, switch to Finder/Safari/Chrome and press ⌥⌘I: no timer mutation. All four global registrations should be gone. Relaunch while disabled, then re-enable and test in/resume/pause/out. In-app menu commands remain available.
5. Open `clockin://clock-in` and `clockin://clock-out` from another Mac app. Verify sender name (or “Another app”), app activation, Cancel leaving timer/log unchanged, and confirmation logging Link from another app. Test paused resume too. In while working and out while idle must not show an alert.
6. Test Pulse through the real Chrome native host, both with Clockin open and starting from closed. It should run without the link alert and log Pulse (Chrome). This checks actual sender PID/executable attribution through Launch Services, which a source typecheck cannot prove.
7. With two signed devices, test remote start, remote replacement start, resume and out, then first-import setup. Verify local `.sync` provenance/prior-session details and that the log and two switches never move to the other device. Existing remote-start notifications should retain their behavior.

## Owner additions

- `ExternalClockPass`: the native host writes a one-time 32-byte pass to the
  data folder and sends it as `clockin://clock-in?pass=…`; the app acts
  without asking when the pass matches (file removed either way), so Pulse
  keeps working even if Launch Services reports another sender for the URL.
  The executable comparison stays as the first check.
- Turkish wording of the new strings aligned with the app's "mesai" terms.
- Built: `Clockin` (iOS Simulator, Debug) and `ClockinMac` (Debug) with
  xcodebuild; the timer log manual check passed (README line).
