# 14: Mac menu bar details switch

Implemented a Mac-local **Show details in the menu bar** switch in Settings >
Menu bar. For the reported setup (Minimal mode on, hours and earnings selected),
turning this off removes Clockin for Mac's title text while keeping its status
icon. Turning it back on restores the selected details.

## Changes

- `ClockinMac/MacSettingsSection.swift`: adds
  `@AppStorage("Clockin.MacShowMenuBarDetails", store: .standard)` with a default
  of `true`. The five existing field toggles remain visible but are disabled
  when details are off. Their stored values are untouched. Seconds also retains
  its existing dependency on hours. Minimal mode stays independently editable;
  its existing pin/window behavior is unchanged.
- `ClockinMac/MenuBarHost.swift`: reads the same key from standard defaults,
  falling back to `true` when absent. When off, returns `text: nil` with the
  current running/paused state; idle remains icon-only. The existing defaults
  notification publisher triggers a label refresh. The unchanged controller
  clears the title and continues to select the icon and accessibility value
  from the status state (`Clocked in`, `Paused`, or `Not clocked in`).
- `Shared/Localizable.xcstrings`: adds two English keys with Turkish translations,
  including **Menü çubuğunda ayrıntıları göster**. Visible help explains icon-only
  mode and the possible iPhone Live Activity, with the path System Settings >
  Notifications > Allow Live Activities from iPhone. Serialization uses
  `json.dumps(indent=2, ensure_ascii=False, separators=(',', ': '), sort_keys=True)`
  plus the existing final newline. The catalog diff is only 20 added lines.

The new key is absent from `SyncPreferences`; its explicit sync allowlist keeps
the setting on this Mac. No Minimal mode, pinning, field preference, iPhone,
ActivityKit, or sync implementation was changed. Details enabled preserves the
existing behavior: title text is displayed only in Minimal mode during a session.

The referenced `13-live-activity-on-mac-result.md` was not present in this
checkout. Implementation follows the explicit task 14 requirements and the
available `13-live-activity-on-mac.md` context.

## Verification

Passed:

- `xcrun swiftc -frontend -parse ClockinMac/MacSettingsSection.swift ClockinMac/MenuBarHost.swift`
- `xcrun xcstringstool compile Shared/Localizable.xcstrings --output-directory /tmp/clockin-14-catalog`
- Catalog comparison against HEAD: exactly two new keys, every existing entry
  unchanged, sorted serialization preserved.
- Checked that the new key is absent from `SyncPreferences` and reviewed the
  unchanged controller's title-clearing, icon, and accessibility paths.
- `git diff --check`.

Attempted full build:

```sh
xcodebuild -project Clockin.xcodeproj -scheme ClockinMac \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/clockin-14-derived \
  -clonedSourcePackagesDirPath /tmp/clockin-14-packages \
  CODE_SIGNING_ALLOWED=NO build
```

It exited 74 before compilation: Sparkle could not be cloned because
`github.com` could not be resolved. Log: `/tmp/clockin-14-build.log`.
Swift parsing is not a full type-check or successful app build. Native UI,
VoiceOver, relaunch persistence, and an actual mirrored iPhone Live Activity
were not exercised in this environment.

Manual follow-up after a successful build: with Minimal mode, hours and earnings
on, toggle details off/on while running and paused; check title removal/restoration,
state icons and accessibility values, disabled field controls with retained choices,
unchanged Minimal mode/pinning, and persistence after relaunch. Idle should remain
icon-only in both settings. Check English/Turkish help layout and confirm changing
this preference does not alter the iPhone's Live Activity.
