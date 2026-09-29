# Brief 00: Mac port inventory and data compatibility

Read `docs/mac-plan.md` first. It is in Turkish; the short version: the Mac app
is being rebuilt as a native macOS target (`ClockinMac`) inside this Xcode
project, sharing `Shared/` and most of `Clockin/` with the iPhone app. It keeps
the old Mac identity (`com.ismailakdag.clockin`, Sparkle feed) and the old data
location, so existing Mac users update in place. Full feature parity comes
first; CloudKit sync comes after.

The old Mac app is checked out read-only at `../clockin-main` (Swift package,
sources in `../clockin-main/Sources/Clockin`). Do not modify anything there.

This task is analysis plus one new check. Do not change any existing Swift file,
the Xcode project, or any file outside this worktree. Do not commit. Do not read
anything outside this worktree and `../clockin-main`.

## 1. `docs/mac-port-inventory.md` (English)

a. **iPhone files.** Every `.swift` file under `Clockin/`, `Shared/` and
   `ClockinWidgets/`, grouped by folder, one table row each:
   - verdict: `as-is` (should compile for macOS 14 unchanged), `guard`
     (needs `#if os(iOS)` around a few lines or a small shim), `ios-only`
     (exclude from the Mac target), `mac-rewrite` (the Mac needs its own
     equivalent);
   - the iOS-only APIs it uses (UIKit types, ActivityKit, `UIApplication`,
     haptics, `.navigationBarTitleDisplayMode`, `.keyboardType`,
     `.textInputAutocapitalization`, `UIScreen`, `ControlCenter`,
     `.fullScreenCover`, `tabItem` usage, `ToolbarItemPlacement.topBarLeading`
     and similar, `EditMode`, `.listRowSeparator`-type iOS-only modifiers,
     `UIActivityViewController`, `PhotosUI`, etc.) with line numbers;
   - one short note.
   Be concrete. If unsure whether a SwiftUI modifier exists on macOS 14, say so
   rather than guessing. Also list non-Swift resources the Mac target needs
   (asset catalogs, `.xcstrings`, bundled sounds, fonts) and whether they are
   platform-neutral.

b. **Old Mac app files.** Every file in `../clockin-main/Sources/Clockin`:
   what it does in one line, the counterpart in this repo (file path) if any,
   and a verdict: `port` (bring into the new Mac target, AppKit or Mac-only
   behavior with no iPhone counterpart), `superseded` (the iPhone version
   replaces it), `merge` (the iPhone version replaces it but a Mac behavior
   must be kept; say which). Include `../clockin-main/Resources/Info.plist`
   keys the new target must keep.

c. **UserDefaults key map.** Every key the old Mac app reads or writes (grep
   `../clockin-main/Sources`) and every key this repo uses. One row per key:
   Mac type/meaning, iPhone type/meaning, status (`same`, `renamed`,
   `mac-only`, `iphone-only`, `same name different meaning`), migration needed
   on first launch of the new Mac app, and a sync class for phase 5:
   `sync` (user choice that should follow the user across devices) or
   `device` (window frames, interface size, tokens, notification bookkeeping,
   one-time setup flags, caches such as exchange rates). The user wants
   everything that is a user choice synced, including theme and sounds.

d. **Behavior changes for existing Mac users.** Go through `PARITY.md`
   ("Different on purpose" and "Mac only") and the two `ClockStore.swift`
   files. List every place where a Mac user will see different behavior once
   the Mac runs this repo's code (level/XP rules, restore, failed save, goal
   estimate, history ranges, etc.), and what, if anything, must be migrated or
   announced.

e. **Proposed shims for phase 1.** A short list of the smallest platform
   seams that let `Shared/` and the shared views compile for macOS: name,
   file, what it wraps. Prefer `#if os(iOS)` at call sites for one-offs and a
   tiny shared type only when three or more files need the same thing.

## 2. Data compatibility check: `Tests/manual/maccompat/main.swift`

The old Mac app writes `clockin.json` with `JSONEncoder()` defaults using the
structs in `../clockin-main/Sources/Clockin/Models.swift`. The iPhone decoder
in `Shared/Core/Models.swift` is stricter: it throws on invalid durations and
dates, and `ClockStore` then starts empty after copying the file aside.

Write a dependency-free check in the style of the existing ones (see
`Tests/manual/sessions/main.swift`: `check(_:_:)`, prints `ok:` lines, exits
non-zero on first failure; synthetic data only, and say so in a comment).

- Inside the test file, declare private copies of the Mac model structs under
  different names (for example `MacClockinData`, `MacWorkSession`, ...) exactly
  as the Mac declares them, and encode fixtures with them the way the Mac app
  does. Cover: a file without `rateRules` (pre-schedule Mac), a paused and a
  running `running` session, CSV-imported sessions with
  `matchedExternalSource`, `pinVisible = true`, a non-USD currency, a
  bounded and an open-ended rate rule, an empty file with no sessions.
- Check that this repo's `ClockinData` decodes each fixture, that
  `ClockStore(fileURL:)` pointed at a temporary copy loads it without writing
  a `clockin-unreadable-*.json` copy, that the rate migration runs only when
  `rateRules` is missing, and that what this repo saves still decodes with the
  Mac structs (the old app must be able to read it back if a user downgrades).
- Then read the old Mac app's `ClockStore.swift` and list every code path
  that could write data this repo's decoder rejects (negative or NaN
  duration, `end < start`, dates out of range, ...). Add a fixture for each
  one that is reachable and record the result. If the iPhone decoder rejects
  something the Mac can really write, do not fix it: report it in the result
  file with the Mac code path, so it can be decided.

Add the compile-and-run command for the new check to the Checks block in
`README.md`, next to the other store checks, using the same style.

## Verification

Run, from the worktree root, and paste the tail of each output into the result:

- the new maccompat check;
- the existing `sessions`, `backups` and `import` checks from `README.md`.

Do not run xcodebuild; this sandbox cannot build SwiftUI targets.

## Result

Write `docs/codex/00-inventory-result.md`: what you produced, check outputs,
anything that surprised you, open questions, and any Mac data the iPhone
decoder rejects.
