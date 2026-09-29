# Brief 04: history modes, the Mac guide and desk mode on the Mac

Read `docs/mac-plan.md` (phase 2 and its status list) and
`docs/mac-port-inventory.md`. The `ClockinMac` target builds and runs; its
shell (menu bar, pinned timer, commands, Settings in the sidebar) is in
`ClockinMac/`. Another person is working at the same time on
`ClockinMac/MacRootView.swift`, `ClockinMac/ClockinMacApp.swift`, a new
`ClockinMac/MacAppServices.swift`, `Clockin/Views/DashboardView.swift` and
`Clockin/Views/TimerCard.swift`; do not edit those.

The iPhone app ships from this code. Every change below is Mac-only
(`#if os(macOS)` or files in `ClockinMac/`) unless it is a pure no-op on iOS;
the iPhone UI must not change.

## 1. History: collapsible day groups and a flat list (Mac)

The old Mac app (`../clockin-main/Sources/Clockin/HistoryView.swift`) let the
user switch the session list between day groups that collapse and a flat list,
stored in `Clockin.HistoryGroupByDay` (Bool, default true; existing users have
it set). Bring that to the shared `Clockin/Views/HistoryView.swift` on macOS
only:

- a control in the list header (or the window toolbar if the view already
  owns toolbar items there) to switch grouped/flat, bound to the same key;
- grouped: each day header toggles its sessions; remember collapsed days only
  for the life of the view, as the old app did (check what it did);
- flat: one list, newest first, each row showing its date;
- everything else stays the shared implementation: paging, ranges, the
  chart, totals, edit/delete (on the Mac, delete and edit must be reachable
  without swipe actions: a context menu on the row with Edit and Delete, and
  the Delete key on a selected row if the list supports selection cleanly).

## 2. Usage guide on the Mac

`Clockin/Views/Guide/UsageGuideView.swift` explains the iPhone. On macOS:

- hide the iPhone-only topics (widgets, Live Activity / Dynamic Island,
  Control Center and Lock Screen controls, the Action Button, turning the
  phone sideways for desk mode, haptics, the silent switch);
- add Mac topics from the old `../clockin-main/Sources/Clockin/GuideView.swift`
  and from what the new Mac shell actually does (read `ClockinMac/`): the menu
  bar item and its panel, minimal mode and its fields, the pinned timer and
  its five layouts, global shortcuts (⌥⌘I clock in or resume, ⌥⌘P pause or
  resume, ⌥⌘O clock out, ⌥⌘E open), the in-app Clock menu shortcuts, desk
  mode from part 3, where Settings live (sidebar, ⌘,), automatic updates;
- keep the guide's existing structure and tone; English source strings with
  Turkish translations in `Shared/Localizable.xcstrings`.

## 3. Desk mode on the Mac

On the iPhone, turning the phone sideways shows `DeskModeView`: a large,
always-on work timer with the companion's home. On the Mac it becomes a
window command.

- `Clockin/Views/DeskMode/DeskModeView.swift` is currently excluded from the
  Mac target. Make it compile on macOS with the smallest guards (it is fine to
  leave `DeskModeOrientation.swift` excluded; move anything the view needs
  from there, such as `DeskMode.enabledKey`, only if necessary and without
  changing iOS behavior). Tell me in the result that the exclusion should be
  removed from the project; do not edit `Clockin.xcodeproj`.
- New `ClockinMac/DeskModeWindow.swift`: a controller that opens a window
  hosting `DeskModeView` with the same environment the main window gives
  (`MacMainContent` in `ClockinMac/MacShellSupport.swift` shows what that is),
  enters full screen, leaves with Esc or the window's close button, and keeps
  the display awake while a session is running and not paused (IOKit
  `IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleDisplaySleep`,
  released when paused, stopped or the window closes). `onClockOut` shows the
  shared `SessionSummaryView` as a sheet in that window.
- Add a "Desk Mode" command (⌃⌘F) to the View commands in
  `ClockinMac/MacCommands.swift`, and a row for it in
  `ClockinMac/MacSettingsSection.swift` next to the existing
  `Clockin.WardrobeShowHomeInDeskMode` choice if that choice is hidden on the
  Mac today (check `SettingsView`'s `#if os(iOS)` blocks; show the "Show home in
  desk mode" toggle on the Mac too, without the landscape toggle).

## Rules

- Files you may edit: `Clockin/Views/HistoryView.swift`,
  `Clockin/Views/SessionRow.swift` (if needed for the flat row date),
  `Clockin/Views/Guide/*`, `Clockin/Views/DeskMode/DeskModeView.swift`,
  `Clockin/Views/SettingsView.swift` (only the desk-mode block), new files in
  `ClockinMac/`, `ClockinMac/MacCommands.swift`,
  `ClockinMac/MacSettingsSection.swift`, `Shared/Localizable.xcstrings`.
- Swift 6 strict concurrency; AppKit on the main actor.
- Comments short, matching each file (Turkish without diacritics where the
  file already uses it).
- Do not change `Clockin.xcodeproj`. Do not commit.

## Verification

Type-check what you can against both SDKs (macOS 14, iOS 17 simulator) as in
earlier briefs (`docs/codex/02-mac-shell-result.md` shows how you stood in for
the blocked `@State` macro), validate the string catalog with
`python3 -m json.tool`, run the `earnings`, `historytry`, `sessiondisplay` and
`feedback` checks from `README.md` and paste their tails.

## Result

Write `docs/codex/04-mac-parity-result.md`: what each part does on the Mac,
every iOS-visible line you touched and why it is a no-op there, project
changes I need to make, and what you could not verify.
