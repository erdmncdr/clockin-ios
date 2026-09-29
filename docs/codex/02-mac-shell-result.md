# Brief 02 result: Mac shell

Implemented the Mac shell from `../clockin-main/Sources/Clockin`, using this repo's shared store, models, palette, radio and screens. No commit was made. `Clockin.xcodeproj`, the old checkout and `NOTICE.md` were not changed. The pre-existing `docs/codex/02-mac-shell.md` was left alone.

The code passes the partial Swift 6 checks below. This is **not a full target build or a running-app verification**. Xcode must first be pointed at the new plist.

## Files and differences from the old code

All Swift paths in this table are under `ClockinMac/`.

| File | Port and adaptation |
| --- | --- |
| `ClockinMacApp.swift` | Replaces `WindowGroup` with `NSApplicationDelegateAdaptor` and an unused Settings scene. Keeps accessory launch, Applications prompt before Sparkle, menu-bar setup, reopen handling, normal-launch re-presentation and minimal-launch pin suppression. Uses `SharedStore.clock` and `.exchangeRates`; never constructs a second store. Settings scene observes window visibility, hides itself and opens the Settings sidebar section. Carbon registrations are removed at termination. |
| `MainWindow.swift` | Ports `MainWindowController`, retained `NSWindow`/`NSHostingView`, frame restoration, primary-display centering on first creation, regular activation when shown, and close = order out. Hosts `MacRootView` through the environment wrapper. A fresh sidebar window starts at 960 × 680; existing saved sizes retain the old unscaled 390 × 650 minimum. No UIScale reads, migration or scaling. |
| `MacRootView.swift` | Keeps Today / History / Progress and adds Settings using the shared `SettingsView`. Selection is held by `MacNavigation`, so commands work while the window is hidden and language rebuilds retain selection. Presents the shared manual-start and manual-entry sheets from commands. No redesign of the shared screens. |
| `MacCommands.swift` | New routing object plus app Settings/Updates commands, Clock menu and View section commands. Observes store, pending command sheet and updater state. App-language changes refresh the localized command labels. |
| `MacShellSupport.swift` | New, small adapters: `MacRollingText` forwards the old point-size call sites to shared `RollingNumberText`; `MacLocalizedContent` supplies language identity and locale to all three hosted surfaces; `MacMainContent` keeps the timer persistence alert and theme-triggered `SessionMirror.refresh()`. |
| `MacDurationText.swift` | New Foundation-only helper for `clock(includeSeconds:)`. Shared `DurationText` stays unchanged. Uses shared duration clamping and seconds formatting; the no-seconds form keeps `HH:MM`. |
| `MenuBarHost.swift` | Ports the old app's host closures using shared dependencies. Retains status fields, live updates, left-click panel and right-click Open / Updates (including pending version) / Quit menu. Panel uses the shared focus radio and also receives the timer persistence alert. |
| `ClosureMenuItem.swift` | Extracted the old main-actor closure-backed `NSMenuItem` into its own file. |
| `MenuBarController.swift` | Retains the nonactivating panel, full-screen Spaces behavior, popup-menu level, content fitting, screen clamping, second-click/outside-click/Esc dismissal, Reduce Motion behavior and animation-generation guard. Accessibility state is localized and refreshed even when the visual label is unchanged. |
| `MenuBarIcon.swift` | Keeps the old vector template mascot icon and idle/running/paused states. |
| `MenuBarStatus.swift` | Keeps idle icon-only behavior, frozen paused values, optional seconds, whole-unit currency/TRY, and daily/monthly goal percentages. Localizes goal abbreviations and keys the locked formatter cache by app locale and currency. |
| `MenuBarPanelView.swift` | Keeps status, mascot, session/today timer and earnings, hourly-rate idle state, TRY equivalent, month totals, daily goal, last-session summary, clock/pause/resume/out/cancel confirmation, radio stop, open/pin/minimal/update/quit actions. Uses shared mascot, rolling renderer, primary/secondary action styles and selected `ClockinPalette`; compact auxiliary actions use native borderless buttons. Removes old UIScale/text-style dependencies. Localizes labels, computed copy and accessibility strings. Minimal mode saves/restores the prior pin choice and changes activation policy as before. |
| `PinnedWindow.swift` | Keeps Money / Compact / Goal / All / Total, floating nonactivating resizable panel, all-Spaces/full-screen/stationary behavior, move/resize saves and per-mode dimensions. Adds a main-actor store/defaults observer because the shared store intentionally does not own AppKit windows. Every pin control calls `ClockStore.setPinned`; the observer reads after publication. Initial restoration does not apply a preset over the autosaved frame. Uses shared theme, rolling numbers and radio; radio Play uses the shared remembered station. Adds accessible radio controls. Defaults remain in unscaled points, with existing saved per-mode sizes taking precedence. |
| `KeyboardShortcuts.swift` | Reimplements global registration with Carbon as requested. **The old checkout actually used NSEvent monitors**, not Carbon. Keeps the four bindings/actions, one app-lifetime registration, idempotent start, and explicit shutdown cleanup. Main-event-loop callbacks enter the main actor. Settings reports a registration conflict instead of pretending all keys registered. |
| `UpdateChecker.swift` | Ports Sparkle controller lifetime, deferred user checks, automatic-check migration, published status and gentle scheduled reminders. Keeps the main-thread KVO/Combine behavior; reminder closure is explicitly main-actor isolated. Sparkle remains the scheduler/installer. |
| `MoveToApplications.swift` | Keeps launch prompt order, writable-copy suppression, non-suppressible DMG prompt, newer/equal installed-build preference, old-copy trashing and delayed relaunch/eject script. Localizes alerts and explanations. No actual app was moved during this task. |
| `ApplicationMover.swift` | Keeps Security translocation lookup, development-build exclusion, system/user Applications selection, staging, rollback and symlink-safe quarantine removal. Localizes application errors. |
| `MacSettingsSection.swift` | Adds minimal mode and all five field toggles, pin visibility and all five layouts, global shortcut information/conflict notice, automatic update checks, manual checks, pending version, last-check date and startup errors. Field preferences remain editable before entering minimal mode. |

Other changes:

- `Clockin/Views/SettingsView.swift`: small conditional insertions for `MacSettingsSection`; iOS-only Done/dismiss toolbar, navigation title and keyboard-dismiss UI stay on iOS. Keeps the NavigationStack for the existing nested Settings navigation. Haptics toggle/silent-switch copy and iPhone-specific language/data/restore descriptions get platform guards. Settings business logic is unchanged.
- `Shared/Localizable.xcstrings`: adds **88 English keys with Turkish translations**, retaining sorted keys and existing JSON formatting. All pre-existing entries are semantically unchanged. A source-literal audit found Turkish entries for all 115 extracted Mac-shell keys; the additional Mac-only Settings copy is also translated.
- `Config/ClockinMac-Info.plist`: exactly the old **11** requested entries: `LSUIElement`, `NSPrincipalClass`, and all nine `SU*` entries. No identifier, executable, name, version or build overrides.
- This result file is the requested documentation exception to the production-file allowlist.

### Refresh and service ownership

Exchange-rate refresh moves from the old `WindowGroup` task into the application delegate: it derives the same sorted unique calendar dates from completed sessions plus the running session, cancels superseded requests, and calls `SessionMirror.refresh()` only after a successful live check with a rate. It runs on minimal-mode launch even if the main window has never been created. The existing `SharedStore` still starts `SessionMirror` and its shared services; no old chime/store/model/theme implementation was copied.

## Preference and window compatibility

Release continues to use the existing standard defaults domain, `com.ismailakdag.clockin`. No bulk preference migration or domain copy is introduced. The shared data path and backups are unchanged. Debug retains its existing isolated identifier/data directory.

| Exact key/name | Preserved meaning/default |
| --- | --- |
| `Clockin.MinimalMode` | Bool, false; minimal launch suppresses main and pinned windows. Explicit Open/reopen can still show the main window, as before. |
| `Clockin.MinimalShowHours` | Bool, true. |
| `Clockin.MinimalShowSeconds` | Bool, false; applies only when hours are shown. |
| `Clockin.MinimalShowEarnings` | Bool, true. |
| `Clockin.MinimalShowTRY` | Bool, true; equivalent appears only for USD with an available rate. |
| `Clockin.MinimalShowGoal` | Bool, false; daily and monthly percentages when goals exist. |
| `Clockin.PinVisibleBeforeMinimal` | Bool, written on entry, retained over relaunch, consumed/removed on exit; absent fallback remains true. |
| `Clockin.PinnedMode` | Raw strings `Money`, `Compact`, `Goal`, `All`, `Total`; default `Money`. Translated labels never become storage values. |
| `Clockin.PinnedWidth.Money`, `Clockin.PinnedHeight.Money` | Existing point sizes; fallback 320 × 112. |
| `Clockin.PinnedWidth.Compact`, `Clockin.PinnedHeight.Compact` | Existing point sizes; fallback 246 × 72. |
| `Clockin.PinnedWidth.Goal`, `Clockin.PinnedHeight.Goal` | Existing point sizes; fallback 300 × 116. |
| `Clockin.PinnedWidth.All`, `Clockin.PinnedHeight.All` | Existing point sizes; fallback 370 × 230. |
| `Clockin.PinnedWidth.Total`, `Clockin.PinnedHeight.Total` | Existing point sizes; fallback 340 × 156. |
| `ClockinMainWindow` | Main-window autosave name; defaults entry `NSWindow Frame ClockinMainWindow`. Size restored, fresh launch centered on primary display. |
| `ClockinPinnedTimer` | Pinned-window autosave name; defaults entry `NSWindow Frame ClockinPinnedTimer`. Position/frame restored, saved mode size preferred. |
| `Clockin.MoveToApplicationsSuppressed` | Bool; suppression applies to writable locations, not read-only disk images. |
| `Clockin.AutoCheckUpdates` → `SUEnableAutomaticChecks` | Copies the legacy Bool only if Sparkle's destination preference is absent, then removes the legacy key. Existing Sparkle choice wins, including false. |
| `SUEnableAutomaticChecks` | Sparkle preference retained; plist default true. Other Sparkle-internal bookkeeping remains in the same domain. |
| `Clockin.Theme` | Existing raw theme names, default `Carbon`, resolved by shared `ClockinThemeChoice`. |
| `Clockin.MascotEnabled` | Bool, true; status panel uses the shared mascot. |
| `Clockin.GoalDailyHours`, `Clockin.GoalMonthlyHours` | Existing Double hours, 0 = off; read by panel, status and pin. |
| `Clockin.UIScale`, `Clockin.UIScalePercent` | **Untouched**, not read, rewritten, removed or migrated by the port. |

`pinVisible` remains the existing **JSON field**, not a new UserDefaults key. Pin toggles, minimal entry/exit and minimal launch use `ClockStore.setPinned`. Unknown `Clockin.PinnedWidth.<mode>` / `Clockin.PinnedHeight.<mode>` keys are not removed; raw mode storage and dynamic key construction are retained. No global shortcut preference is invented. Radio volume remains the shared controller's in-memory value; the old app had no persisted volume key.

All other shared preferences remain owned by the existing shared code. Inventory issues outside this shell (for example old chime sound-name mapping and interface/history parity) are not changed here.

### Keyboard bindings

| Action | Global | In app |
| --- | --- | --- |
| Clock in / resume if paused | ⌥⌘I | ⇧⌘I (Clock In, enabled when idle) |
| Clock out | ⌥⌘O | ⇧⌘O |
| Pause/resume | ⌥⌘P | ⇧⌘P |
| Open main window | ⌥⌘E | Status menu / Dock or Finder reopen |
| Start with elapsed time | — | ⌃⌘I |
| New entry | — | ⌘N |
| Today / History / Progress / Settings | — | ⌘1 / ⌘2 / ⌘3 / ⌘4 |
| Settings | — | ⌘, |

## Xcode handoff

No project edits were made.

1. **Set `INFOPLIST_FILE = Config/ClockinMac-Info.plist` for ClockinMac Debug and Release. Keep `GENERATE_INFOPLIST_FILE = YES`.** The current target has no `INFOPLIST_FILE`; without this change, the feed/signing-key/LSUIElement contract is not incorporated.
2. Keep the existing Swift 6 setting; explicitly set `SWIFT_STRICT_CONCURRENCY = complete` if a named setting is desired. The partial checks used both flags.
3. Keep the existing Release `PRODUCT_BUNDLE_IDENTIFIER = com.ismailakdag.clockin`, `PRODUCT_NAME = Clockin`, `INFOPLIST_KEY_CFBundleDisplayName = Clockin`, macOS 14, `ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = YES`, and `MacAppIcon`. Keep `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in build settings (currently 2.0.0 / 11), not the new plist. Preserve Debug's `.debug` identity.
4. For a distribution archive, use Developer ID Application / team `LU36PKDPT3`, and standard universal `arm64 x86_64` architectures with `ONLY_ACTIVE_ARCH = NO`. Current target signing is ad hoc (`CODE_SIGN_IDENTITY = -`); signing/release is a later phase.
5. `ClockinMac` is already a filesystem-synchronized target group, so the new Swift files should enter that target automatically. Verify membership excludes iPhone/widget targets. Keep Sparkle 2.10.0 linked only to ClockinMac. Do not add the plist to Copy Bundle Resources; it is the input plist.

The new plist preserves these exact Sparkle values: automatic install false, automatic checks true, profiling false, feed `https://github.com/ismailakdag/clockin/releases/download/macos-updates/appcast.xml`, public EdDSA key `vsxEtDN88GYSuw5+GGeCk3eEvZxlDEalz1icmMBCvh8=`, signed feed required, interval 21600, signed-feed failure expiration 0, verify before extraction true. `NSPrincipalClass` is `NSApplication`; `LSUIElement` is true.

## UIScale options for a later brief

1. Keep both old keys indefinitely and use native window resizing plus a future text-size/accessibility control. Explain the discontinued old scale setting in release notes.
2. Map the stored value to a Mac-only text-size/density preference for shared components once those components support it. Keep the original key/value until that migration is explicitly designed.
3. Offer scale only for the menu and pinned surfaces, with an explicit Settings label describing its limited scope. Keep shared screens on their native layout.

None is implemented here. Existing saved window dimensions still restore; old automatic font/dimension scaling does not run.

## Verification and limitations

### Partial macOS type-check

Passed with no diagnostics after adaptation:

```sh
swiftc -typecheck -swift-version 6 -strict-concurrency=complete \
  -module-cache-path /tmp/clockin-shell-check/cache \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -target arm64-apple-macos14 \
  -I /tmp/clockin-shell-check <source list>
```

The exact generated command is in `/tmp/clockin-shell-check/command.txt`; the runner and final log are `/tmp/clockin-shell-check/run.py` and `shell.log`.

Checked **all 18 `ClockinMac/*.swift` files**, including the app entry point, Carbon API calls, AppKit delegates/hosting/controllers, commands, Settings extension, all five pinned layout bodies, panel and Sparkle adapter. Also checked the modified shared `SettingsView`, real shared `ClockStore`, `ExchangeRateStore`, models/import/backup dependencies, `AppGroup`, `SharedStore`, theme/SwiftUI button/haptic implementations, all five rolling implementation files, timer alert, radio controller/station, CompanionMode and decimal-input/platform helpers.

Temporary substitutes, all outside the repo:

- A minimal compiled `Sparkle` module declaring only the APIs used by `UpdateChecker`. This checks Swift typing/isolation against those declarations, **not** compatibility with the resolved Sparkle binary/headers or updater behavior.
- SDK 27's `@State` macro cannot launch its plugin in this sandbox (`sandbox_apply: Operation not permitted`). Temporary source copies replace `@State` with `@CheckState`, an alias to the real `SwiftUI.State<Value>` property wrapper. Production files retain `@State`.
- Manual `EnvironmentKey` implementations stand in for the palette/content-active macro environment; an ordinary class stands in for `LanguageSwitch`'s Observation macro.
- Minimal stand-ins for `SessionMirror`, chime controller and celebration state; empty bodies with matching interfaces for Dashboard, History, Progress, mascot, manual-start/manual-entry and the Settings child screens/sections. **SettingsView itself and MacSettingsSection were checked**, not stubbed, in the final run. Wardrobe/sound constants needed by Settings are stand-ins.

Additionally, `ApplicationMover`, `MoveToApplications`, `MenuBarIcon` and `ClosureMenuItem` passed a direct type-check with real `AppLanguage` and no stand-ins.

### Executed checks

- `python3 -m json.tool Shared/Localizable.xcstrings`: passed.
- `plutil -lint Config/ClockinMac-Info.plist`: passed; parsed plist equals exactly the selected old contract keys and values.
- Existing catalog entries compared to HEAD: unchanged; 88 additions. Sorted order retained.
- `git diff --check`: passed.
- Old menu-bar status harness against the new formatter/status and shared models: **13 passed**.
- Old mover harness against the ported mover: **40 passed**, including fixture-only staging, simulated Trash, symlink/quarantine handling, failure cleanup and rollback. No actual installed app or real Trash was changed.
- Pure positioning portion of the old menu-panel host harness: **5 passed**, covering normal/full-screen geometry, right-edge clamping, second display and missing-item fallback. Live window portion was not run.
- Required README commands: haptics **61 passed**, rolling **197 passed**, snapshot **passed**. The exact snapshot command first failed trying to write the default module cache under `~/.cache/clang`; rerunning the same command with `-module-cache-path /tmp/clockin-shell-check/cache` passed. No test or production-source workaround was made for that failure.

Required check tails:

```text
# haptics
ok: idle render stays silent
ok: disabled press stays silent
ok: reading a signal does not trigger feedback
ok: explicit action advances signal
ok: repeated explicit actions remain distinct
61 haptics checks passed

# rolling
ok: policy combination true/true/3/false/true/true
ok: policy combination true/true/3/true/false/false
ok: policy combination true/true/3/true/false/true
ok: policy combination true/true/3/true/true/false
ok: policy combination true/true/3/true/true/true
197 rolling checks passed

# snapshot (with writable module cache)
ok: the first entry is now, so a resume shows its amount at once
ok: the first two minutes update every fifteen seconds
ok: until ten minutes, every thirty seconds
ok: then every minute, ending inside the hour
ok: entries are strictly increasing and 74 in total
snapshot checks passed
```

### Still requires the real app

No `xcodebuild`, package resolution, signed build, app launch or live UI automation was performed. The following remain unverified: SwiftUI macro expansion and complete target/resource membership; real Sparkle linkage, feed fetch, migration/reminder/install/relaunch behavior; native menu placement/enablement, keyboard registration/conflicts across apps and keyboard layouts; visual fit of every pin layout/theme/language; close/reopen and primary-display behavior with actual saved 1.1.6 preferences; Space switching/nonactivation; Settings editing/dismissal and command-sheet interaction; language changes in the running UI; live radio/network refresh; real DMG/translocation relocation. Rehearse the 1.1.6 update using backed-up data in the later migration/release phase.

Mac layouts of shared screens, RootView celebration/summary orchestration, history modes, widgets and sync remain outside this brief. The shell uses existing shared services without adding those features.
