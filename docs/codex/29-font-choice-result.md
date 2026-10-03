# 29 — Independent font choice

Implemented on top of `7719d18`. Themes now supply colors and color scheme only. `Clockin.Font` defaults to **System** for both new and existing users; there is no migration from the old theme/font pairings. Choices are System, Rounded, Serif and Monospaced, with English/Turkish catalog entries in the existing serialization format.

## Settings and propagation

- iPhone: Theme and Font are together at the top of **Settings > Appearance**. Font opens a native selection list, with each option rendered in its own design. The remaining section order is unchanged; Language remains in its original section.
- Mac: Theme and Font are together in **Settings > General**. A radio group previews all four designs.
- `ClockinFontChoice` lives beside the Foundation-only theme choice; its SwiftUI design mapping lives in `Themes.swift`. `palette(font:)` combines the two independent choices. Existing screens and `RollingNumberFont` callers keep consuming `palette.fontDesign`.
- The iPhone root and independent Mac root, menu panel, pinned timer and desk window observe the preference using `@AppStorage`. Font changes refresh `SessionMirror` through the existing lifecycle/change-handler pattern. Palette resolution is pure; there are no new geometry, hover, layout or representable callbacks, or layout-time state writes.
- `ClockinSnapshot.font` carries the choice to both widget targets. Missing/null fields and unrecognized names resolve to System. A font-only change changes snapshot equality, causing the existing writer/timeline reload path to run.
- `ClockinActivityState.font` is defaulted and uses `decodeIfPresent`. Old full content payloads and time-only relay ticks still decode. No attributes or relay payload contract changed. Font is deliberately excluded from `hasSameCalculation`, so selecting it updates the existing activity instead of replacing it.
- Live Activity rendering takes the latest font from the device's shared snapshot, with the decoded content font as fallback if the snapshot is unavailable. This also applies after a relay tick reconstructs financial content from immutable `localState`: that old attribute cannot restore an old font. Lock Screen and expanded/compact Dynamic Island text receive the selected design.

## Sync decision

**The font choice is device-local.** `SyncPreferences.accepts` rejects keys absent from `types`. `SyncCore.validate` in `Shared/Sync/Cloud/SyncMerge.swift` requires acceptance for preference records, and `SyncCore.merge` catches a failure by adding it to quarantine. Unknown preferences therefore do not have the silent-ignore behavior required for compatibility with the shipped clients. No assumption of safe cross-version sync was made.

`Clockin.Font` is explicitly listed in `deviceKeys` and absent from the upload allowlist. Theme syncing is unchanged. Tests verify the allowlist decision, no outgoing record on a font-only edit, and the rejection/quarantine behavior that makes publishing this new preference unsafe.

## Verification

- **New font suite:** `Tests/manual/fontchoice/run` — 145 checks passed. Covers all 32 theme/font combinations, preserved colors, Dynamic Island palette design, four distinct native rolling font designs and valid glyph measurements, legacy/empty/current snapshots, legacy full activity content, time-only relay ticks, null/unknown font names, round trips, equality, and snapshot-over-content font resolution. Log: `/tmp/clockin29-font.log`.
- **Live Activity lifecycle:** `Tests/manual/iphonefollowsmac/run` — passed, including 24 lifecycle checks. Eight new cases update each font with relay mode both off and on, keeping the same activity ID with zero requests/ends. The production mirror operations execute against fake ActivityKit/relay boundaries. Log: `/tmp/clockin29-activity.log`.
- **Sync:** `Tests/manual/sync/run` — 273 checks passed, including the new local-font guards and the five-year simulation. Log: `/tmp/clockin29-sync-final.log`.
- **README:** all 49 original commands other than the separately run full SDK harness passed; the new font suite also passed. Nineteen commands initially could not write Swift's default cache in the restricted home directory. They passed with only `-module-cache-path /tmp/clockin29-readme-cache` added. Per-command exits and logs: `/tmp/clockin29-readme/final-results.json`.
- **SDK:** `python3 Tests/manual/crashaudit/typecheck.py` — exit 0, all six checks passed: Clockin and ClockinWidgets on iOS Simulator 17, ClockinMac and ClockinMacWidgets on macOS 14 and 15. Swift 6 strict concurrency and warnings as errors. Log: `/tmp/clockin29-sdk-final.log`; detailed logs: `/private/var/folders/0x/s_c9czd536s9vs8npkcmpn7w0000gn/T/clockin24-sdk-kt76hnts/`.
- **iOS scope:** `python3 Tests/manual/macpolish/ios_paths.py` and `--base HEAD` both return the expected exit 1 because this task intentionally changes iOS. The default baseline checks 40 shared files: 30 unchanged and only the ten intended files below changed, in release and DEBUG. Against task HEAD, exactly those ten change, with five bilingual additions and no existing localization changes. The two widget source changes were separately reviewed; the script only examines `Clockin/` and `Shared/`. Logs: `/tmp/clockin29-ios-paths.log`, `/tmp/clockin29-ios-paths-head.log`.
- `git diff --check` passed.

The ten intended app/shared iOS paths are `Clockin/ClockinApp.swift`, `Clockin/Privacy/LiveActivitySetupView.swift`, `Clockin/Views/RootView.swift`, `Clockin/Views/SettingsView.swift`, `Shared/Sync/ClockinActivityState.swift`, `Shared/Sync/ClockinSnapshot.swift`, `Shared/Sync/Cloud/SyncPreferences.swift`, `Shared/Sync/SessionMirror.swift`, `Shared/Theme/ClockinThemeChoice.swift`, and `Shared/Theme/Themes.swift`.

No xcodebuild build/test, signed launch, device capture, CloudKit call or relay request was performed. The SDK harness uses the repository's documented macro-boundary substitutes; it does not verify macro expansion or rendered UI. The following visual checks remain to be performed.

## iPhone visual checks

1. Upgrade with Carbon, Synthwave or Terminal Amber selected and no `Clockin.Font` preference. Confirm the theme colors remain and the font starts at System. Repeat with a fresh installation.
2. In Appearance, confirm Theme then Font, unchanged surrounding section order, all four options previewing their own design, and the selected checkmark. Repeat in Turkish: “Yazı tipi”, “Sistem”, “Yuvarlak”, “Serif”, “Eş aralıklı”.
3. Select each font and change through all themes. The font must stay selected while colors change. Relaunch and confirm persistence. Check Today, History, Progress, sheets, companion screens and landscape desk mode, including Turkish and large text.
4. While working, switch fonts across timer and money ticks. Check rolling-number baseline, clipping, long amounts, pause/resume, and Reduce Motion. No stale glyphs or unexpected row/window resizing.
5. Check small/medium Home Screen widgets in idle, working and paused states, after the OS reloads the timeline. Check long amounts, maximum supported text size, and Daylight contrast.
6. Start a Live Activity, change font while it remains open, and verify one card remains. Check Lock Screen plus expanded/compact Dynamic Island. With relay updates enabled, background the app and let several ticks arrive: the chosen font must remain, amounts must continue to update, and no replacement card should appear. Repeat from an activity created before upgrading, and with relay updates disabled. Test long timers and wide amounts for clipping.

## Mac visual checks

1. In General, confirm Font sits beside Theme in the same settings group. Check all four radio-label previews, selection, EN/TR labels, keyboard operation and persistence after relaunch.
2. Keep the main window, menu panel, pinned timer and desk mode visible while changing font. All surfaces must update; switching theme must preserve the font. Exercise every pinned mode and long timer/money values.
3. Check Mac widgets after reload, in idle/working/paused states and with Daylight. A font change must reach the widget without a timer edit.
4. At 700 × 650 and 960 × 860, alternate Settings/History, hover charts and rows, resize the window, and switch fonts while the timer runs. Check for clipping, row-height oscillation, layout exceptions and stale rolling glyphs. Repeat desk mode at 1440 × 900 and 1440 × 810.
5. With Mac/iPhone sync enabled, choose different fonts on the two devices. Each must keep its local choice through sync and relaunch, while a theme change still syncs normally. Font-only edits must produce no CloudKit preference upload or quarantine notice.
