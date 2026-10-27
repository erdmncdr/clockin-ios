# 33: Who started the timer? A start log and guards

The owner reports that the timer sometimes starts on its own on the iPhone
("durup dururken"). Nothing in the code starts a session without an input,
but several inputs are easy to trigger without noticing, and none of them
leaves a trace:

- iPhone: the Home Screen widget's Clock in button (`ClockInIntent`), the
  Control Center toggle (`SetClockedInIntent`, iOS 18), Siri and Shortcuts
  ("Start Clockin", automations), the Action button, and a start on the Mac
  arriving through iCloud sync (`ClockStore.applySynced`, provenance
  `.remoteChange`; `RemoteClockInNotification` then posts "Clocked in on your
  Mac" only when the app is not active).
- Mac: the global hot keys ⌥⌘I (clock in or resume), ⌥⌘P, ⌥⌘O
  (`ClockinMac/KeyboardShortcuts.swift`) — ⌥⌘I is also Finder's Show
  Inspector and Safari/Chrome's Web Inspector, so pressing it in those apps
  starts Clockin silently; the `clockin://clock-in` URL
  (`ClockinMac/ExternalClockCommand.swift`), which any app or web page on the
  Mac can open, not only the Pulse Chrome extension's native host
  (`ChromeNativeHost`); and the Pulse extension's click watcher
  (`ClockinMac/ChromeExtension/watch.js`).

Build, in a worktree, the pieces below. Both apps (`Clockin` iOS scheme and
`ClockinMac`) must compile; the owner builds them. Keep Swift 6 strict
concurrency clean; follow the comment style around you (short, why-comments;
some files use Turkish without diacritics, new comments in English are fine).

## 1. A timer start log (both platforms)

`Shared/Core/TimerStartLog.swift`: a small, device-local log of timer changes
with their origin. Entry: date, action (`clockIn`, `resume`, `clockOut`,
`pause` is not needed), origin, and for sync entries whether a session was
running before. Keep the last 100 in `UserDefaults.standard` under
`Clockin.TimerStartLog.v1` as JSON (Codable); never synced (add the key to
whatever exclusion `SyncPreferences` needs so it is not picked up — check
`Shared/Sync/Cloud/SyncPreferences.swift`: only listed keys sync, confirm).
Origins (an enum with a stable raw value and a localized title):

- `app` — the app's own buttons (TimerCard, ManualStartView, DeskModeView,
  MenuBarPanelView, MacCommands, MacRootView/desk window if any, the
  `--clock-in` debug argument).
- `widget` — `ClockInIntent` / `TogglePauseIntent` (widget button, Live
  Activity button, Siri, Shortcuts, Action button: iOS cannot tell these
  apart; title "Widget, Siri or Shortcuts").
- `controlCenter` — `SetClockedInIntent`.
- `sync` — `ClockStore.applySynced` when the running session appears, changes
  start, or disappears (title "Another device (iCloud)"); record provenance
  (remote change vs initial import).
- Mac only: `shortcut` (hot keys), `link` (a `clockin://` URL from another
  app), `pulse` (the URL delivered by Clockin's own native-host process, see
  §2).

Record from `ClockStore.clockIn`, `resume`, `clockOut` through a new
`origin: TimerOrigin = .app` parameter (default keeps every existing call
compiling; then pass the right origin at each non-app call site), and from
`applySynced`. Log only after the persist succeeded.

Show it: iOS Settings, Data section, a row "Timer log" opening a list (newest
first, relative date + time, action, origin; a "Clear" toolbar button; an
empty state "Nothing yet. Every start, resume and clock-out is listed here
with where it came from."). Mac: the same list in the Settings category where
the global shortcuts live (`MacSettingsSection`, `.general`), as a section
"Timer log" with the last 10 entries and a Clear button. English and Turkish
for every string in `Shared/Localizable.xcstrings` (append; do not re-sort the
file; "Timer log" → "Sayaç günlüğü", "Another device (iCloud)" → "Başka bir
aygıt (iCloud)", "Widget, Siri or Shortcuts" → "Widget, Siri veya Kısayollar",
"Control Center" → "Denetim Merkezi", "Keyboard shortcut" → "Klavye
kısayolu", "Link from another app" → "Başka bir uygulamadan bağlantı",
"Pulse (Chrome)" stays, "In the app" → "Uygulamada").

## 2. Mac: accept `clockin://` commands only from Clockin itself, else ask

In `ExternalClockCommandReceiver.handle`, read the sender's process id from
the Apple Event (`keySenderPIDAttr`) and resolve it with
`NSRunningApplication(processIdentifier:)`. When the sender's `executableURL`
is this app's own executable (the native host launched by Chrome runs the same
binary), perform at once with origin `.pulse`. Otherwise show an `NSAlert`
(app-modal, activating the app) "Clock in from a link?" / "Clock out from a
link?" with the sender's name when known ("Safari wants to start the Clockin
timer."), buttons Clock in / Cancel (Clock out / Cancel), and perform with
origin `.link` only on confirmation. Commands that are already true (in while
working, out while idle) stay no-ops without an alert.

## 3. Mac: a switch for the global shortcuts

`KeyboardShortcutController`: a preference `Clockin.GlobalShortcutsEnabled`
(default true, `UserDefaults.standard`, not synced). Toggle in the "Global
shortcuts" section above the key list ("Global shortcuts" toggle; footer:
"⌥⌘I is also Show Inspector in Finder and Web Inspector in Safari and Chrome.
Turn the shortcuts off if the timer starts when you press it there."). When
off, unregister the hot keys; when on, register again. Start-up respects it.

## 4. iPhone: a switch for starts from outside the app

Preference `Clockin.ExternalStartsEnabled` (default true, device-local, not
synced). When off, `ClockInIntent`, `TogglePauseIntent` (the resume branch
only) and `SetClockedInIntent` with `value == true` do not start or resume;
they return the dialog "Starting from widgets, Control Center and Siri is off
in Clockin settings." Clock out and pause keep working. Toggle in iOS
Settings, Today section or next to the Timer log row: "Start from widgets,
Control Center and Siri" with footer "Turn this off if the timer starts when
you did not mean it to. You can still clock out from everywhere." Make sure
the Control Center toggle reads the real state after a refused start
(`SessionMirror.shared.refresh()` already runs in `SetClockedInIntent`).

## Verification

- `Tests/manual/timerlog/main.swift` (swiftc, like the others listed in
  README.md "Manual checks"): the log keeps 100, newest first, round-trips
  through JSON, origins have stable raw values; add the swiftc line to
  README.md.
- Run the existing manual checks whose inputs you touched (ClockStore has
  Tests/manual/… that compile it; grep README.md for the files you changed).
- `swiftc -typecheck` is available to you against the SDKs; xcodebuild is
  not. List in the result what you could not compile.

## Rules

No new dependencies. Do not change sync record formats or anything under
`Shared/Sync/Cloud` except, if needed, the preference exclusion list. Do not
touch the website, the relay, or `ClockinMac/ChromeExtension`. No
Codex/Claude names in code, comments or commit messages; do not commit — leave
the worktree dirty, I commit. Write `docs/codex/33-timer-start-log-result.md`:
what changed per file, every call site and its origin, what was verified, and
what the owner should check in the apps.
