# Brief 02: port the Mac-only shell from the old Mac app

Read `docs/mac-plan.md` (phase 3) and `docs/mac-port-inventory.md` (sections
B and C). The `ClockinMac` target now builds and runs: `ClockinMac/ClockinMacApp.swift`
is a plain SwiftUI `WindowGroup` showing `ClockinMac/MacRootView.swift`, a
sidebar with Today / History / Progress that hosts the shared iPhone screens.
Sparkle 2.10.0 is already linked to `ClockinMac` only.

Your job is to bring back everything that made the old app a Mac app, ported
from `../clockin-main/Sources/Clockin` (read-only, MIT; keep its notice in
`NOTICE.md` as it is). Existing 1.1.6 users update in place, so every
preference key, window autosave name and behavior they rely on must carry over
unchanged.

## Scope

Port, adapting to this repo's `ClockStore`, `ExchangeRateStore`,
`ClockinPalette`/`ClockinThemeChoice`, `FocusRadioController` and shared views:

1. **App shell** (replaces the `WindowGroup` in `ClockinMacApp.swift`):
   `NSApplicationDelegateAdaptor`, accessory activation policy, the
   `MainWindowController` (`NSWindowController` + `NSHostingView` of
   `MacRootView`, autosave name `ClockinMainWindow`, primary-display
   centering on launch, reopen handling, close = order out), the unused
   Settings scene redirect, minimal-mode launch behavior. Use `SharedStore.clock`
   and `SharedStore.exchangeRates`; keep the environment the current
   `ClockinMacApp` injects (locale, language id, timer persistence alert,
   exchange-rate refresh, `SessionMirror` refresh on theme change).
2. **Menu bar:** `MenuBarController`, `MenuBarIcon`, `MenuBarStatus`,
   `MenuBarPanelView`, `ClosureMenuItem`. The panel should look like it
   belongs to the new app: use `ClockinPalette` from the selected theme and
   shared components (`RollingNumberText`, action button styles) where they
   fit, but keep the old panel's content, actions and minimal-mode toggles.
3. **Pinned window:** `PinnedWindow.swift` with its five layouts, Spaces
   behavior, frame/size keys (`Clockin.PinnedMode`, `Clockin.PinnedWidth.*`,
   `Clockin.PinnedHeight.*`, autosave `ClockinPinnedTimer`) and `pinVisible`
   wiring through `ClockStore.setPinned`.
4. **Global keyboard shortcuts:** `KeyboardShortcuts.swift` (Carbon hot keys)
   with the same bindings and registration lifetime.
5. **Updates:** `UpdateChecker.swift` (Sparkle), including the legacy
   automatic-check migration and gentle reminders; menu items in the status
   menu and a "Check for Updates…" command in the app menu.
6. **Applications folder:** `MoveToApplications.swift`, `ApplicationMover.swift`.
7. **Menu commands:** a Clock menu (Clock In, Clock Out, Pause/Resume, Start
   with elapsed time…, New Entry…) with in-app key equivalents that do not
   collide with the global hot keys, and View commands to switch sidebar
   sections (⌘1–⌘4).
8. **Settings in the main window:** add a Settings section to the sidebar
   (the old app kept settings in the main window; ⌘, opens the main window on
   it). Reuse the shared `SettingsView`. If it shows iPhone-only chrome in that
   position (a Done/dismiss button, a `NavigationStack` title that doubles the
   sidebar, keyboard-dismiss affordances), hide it on macOS with the smallest
   `#if os(macOS)` change. Add a `MacSettingsSection` (in `ClockinMac/`) for
   the Mac-only choices: minimal mode and its fields, pinned timer, global
   shortcuts info, update checks, and insert it into `SettingsView` under
   `#if os(macOS)`.
9. **Info.plist:** create `Config/ClockinMac-Info.plist` with the old
   `Resources/Info.plist` keys listed in inventory section B ("Old
   `Resources/Info.plist` contract") that Xcode does not generate:
   `LSUIElement`, all `SU*` Sparkle keys, `NSPrincipalClass`. Do not set
   version, build, identifier or executable keys; the build settings own those.

Not in scope: `UIScale` (the old interface-size preference scaled hard-coded
dimensions that the shared screens do not use; leave the key untouched and
write two or three options for it in the result), Mac layouts of the shared
screens, the celebration overlay/sheets that the iPhone `RootView` hosts,
history's collapsible/flat modes, widgets, sync.

## Rules

1. New files go in `ClockinMac/`. Outside it you may only touch
   `Clockin/Views/SettingsView.swift` (small `#if os(macOS)` insertions),
   `Shared/Localizable.xcstrings`, `Config/ClockinMac-Info.plist` and
   `ClockinMac/*`. Do not touch `Clockin.xcodeproj`; list any build setting you
   need in the result. Do not commit.
2. Do not copy the old store, models, themes or views. If a ported file needs
   something the shared code lacks (for example `DurationText.clock(includeSeconds:)`
   for the menu bar), add a small Mac-side helper in `ClockinMac/` instead of
   changing shared code, and say so.
3. Every user-visible string you add must be localizable and must get a
   Turkish translation in `Shared/Localizable.xcstrings` (edit the JSON
   carefully; keep its formatting and key order style). Follow how existing
   strings are written (`Text("…")` literals; `String(localized:bundle: .app)`
   in code).
4. Swift 6, strict concurrency: AppKit types are `@MainActor`; keep closures
   and Combine sinks main-actor isolated as the old code does.
5. Comments short, Turkish without diacritics where the old file used Turkish,
   English where it used English.

## Verification

You cannot run xcodebuild, Sparkle is not resolvable here, and the SwiftUI
macro plugin is blocked. Type-check what you can with the macOS SDK
(`swiftc -typecheck -swift-version 6 -strict-concurrency=complete -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target arm64-apple-macos14 …`),
using small temporary stand-ins under `/tmp` for SwiftUI-macro or Sparkle
dependencies, and say exactly what was and was not checked. Validate the
`.xcstrings` file with `python3 -m json.tool`. Run the `haptics`, `rolling`
and `snapshot` checks from `README.md` and paste their tails.

## Result

Write `docs/codex/02-mac-shell-result.md`: file-by-file what was ported and
what changed from the old code, every preference key and autosave name kept,
build settings I need to add, UIScale options, and what you could not verify.
