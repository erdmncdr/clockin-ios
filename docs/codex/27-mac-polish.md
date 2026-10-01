# 27: Mac polish

The user (Turkish UI, blue accent theme) says parts of the Mac app look amateur.
Make the Mac app feel native and finished. **The iPhone app must not change**:
shared views get `#if os(macOS)` branches or Mac-only wrappers; check iOS still
typechecks and its layout code paths are untouched. Base: this worktree's start
commit (main).

Reference captures of the current Mac app (960 x 860 pt window, Carbon theme):
`website/dist/assets/shot-{today,history,progress,settings}.png`, the user's
screenshots described below. Retake nothing yourself (no GUI here); I will.

## 1. Bottom tab bar: iOS-style Liquid Glass, three tabs

`ClockinMac/MacTabBar.swift`, `ClockinMac/MacRootView.swift`.
- Remove the Settings tab. Settings stays reachable from the dashboard gear,
  Settings... (Cmd-,), the menu bar panel and `MacNavigation.open(.settings)`.
- Today, History, Progress, like the iPhone. Keep Cmd-1...Cmd-3; Cmd-4 can go.
- Make it look like the iOS 26 floating tab bar: on macOS 26+ use
  `GlassEffectContainer`, `.glassEffect(.regular.interactive(), in: .capsule)` for
  the bar and a tinted glass selection capsule (accent tint) that morphs between
  tabs (`glassEffectID`/`matchedGeometryEffect`), accent-colored selected
  symbol/label, subtle hover. Today it renders as an opaque dark capsule; it must
  read as translucent glass over the content scrolling beneath it. Older macOS:
  `.ultraThinMaterial` with a hairline highlight stroke and soft shadow.
- Content must scroll under the bar but the last rows must be reachable (bottom
  content margin equal to the bar height), and it must not cover key numbers at
  the top scroll position more than iOS does.

## 2. Settings: clear, spacious, categorized (Mac only)

The current Settings tab is one long grouped Form (`Clockin/Views/SettingsView.swift`
+ `ClockinMac/MacSettingsSection.swift`): cramped stacked rows, mixed controls, a
lone "Open iPhone notification settings" button inside a toggle list.
- On the Mac, Settings opens as its own page in the main window (tab bar hidden,
  a clear back/Done control returning to the previous section) with a native
  two-column layout: a category list on the left (for example General, Timer &
  goals, Pay & currency, Menu bar, Notifications, iCloud, Data & import, Help &
  about; group what exists) and a grouped `Form` on the right with real section
  spacing, one-line labels, footers for explanations, controls aligned right.
- Reuse the existing setting views/bindings; do not duplicate logic. Extract
  sections from SettingsView into views both platforms can use if needed, but the
  iPhone's Settings must render exactly as before (same order, same sheet).
- Sheets opened from Settings keep `macSheetFrame`.

## 3. Controls that look native

Dropdowns and buttons look homemade. On the Mac:
- Pickers: native `.menu` pickers (bordered pop-up look), sized to content, not
  full-width green text rows; segmented choices (History's Week/Month/6 months/All,
  USD/TRY, By day/Sessions, Progress' Goals/Reports/Badges) as native `.segmented`
  pickers instead of custom capsule pills.
- Buttons: consistent `.bordered` / `.borderedProminent` with sensible
  `controlSize`, one prominent action per area; text-only actions as `.link` or
  plain where that is the Mac idiom; hover feedback where custom.
- Inventory every custom picker/button style used on the Mac paths (Today,
  History, Progress, Settings, sheets, menu bar panel) and fix the ones that look
  off. Keep the app's color theme (accent from the palette).

## 4. History and Progress layout

`Clockin/Views/HistoryView.swift` and the History/Progress views it uses: on the
Mac the content touches the window edges ("PERIOD EARNINGS" at x = 0). Give it
proper margins (about 24-32 pt) and a readable max width, centered, like Today.
Mac copy says "Click", not "Tap" ("Tap a month in the chart to inspect it", ...).
A day in the future must not be selectable/inspectable ("No work on 21 Oct 2026"
showed for a future day).

## 5. Trackpad and pointer interaction

- History chart: two-finger horizontal swipe moves to the previous/next period
  (same as the < > arrows), with a threshold, one step per gesture (use the
  scroll event phases / momentum), vertical scrolling of the page unaffected,
  natural-direction aware. Also Left/Right arrow keys when the chart area is
  focused or hovered. Animate the change.
- Same for any other period navigator (Progress reports, Today goal history if
  any).
- Chart hover: show the value of the bar/day under the pointer (Mac tooltip or
  inline readout) in addition to click-to-inspect.
- Hover highlight and right-click context menus on session rows in History
  (Edit, Duplicate if it exists, Delete with the existing confirmation) where
  the iPhone has swipe actions.
- Do not add global gestures that fight scroll views.

## 6. Desk mode fills the screen

`Clockin/Views/DeskMode/DeskModeView.swift`, `ClockinMac/DeskModeWindow.swift`.
On a 16:10 Mac screen the room is drawn at aspect 1.5 "fit", low and at 30 %
opacity, so the top quarter is a black band and it looks like half a screen; the
companion is cut off at the bottom. On the Mac: the room fills the whole screen
(aspect fill, framed so the window and the companion stay visible on 16:10, 16:9
and 3:2), brighter, timer and money centered over it with legible contrast,
today's total and the controls in the corners. iPhone desk mode unchanged.

## Rules

ASCII Turkish comments. New user-facing strings in `Shared/Localizable.xcstrings`
with English and Turkish (the app says "puantaj", "Ayarlar", "Geçmiş",
"İlerleme"), usual serialization (`json.dumps(indent=2, ensure_ascii=False,
separators=(',', ': '))`, sorted keys, minimal diff). No archive/release, no
CloudKit or relay calls. Run every README suite that does not need xcodebuild and
the Mac + iOS typechecks/SDK harness (`Tests/manual/crashaudit/typecheck.py`).
Write `docs/codex/27-mac-polish-result.md`: what changed per item, files, how I
should verify each visually (which screen, window size, gesture), and anything
you could not do.
