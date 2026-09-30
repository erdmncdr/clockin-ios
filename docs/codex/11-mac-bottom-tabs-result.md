# 11: Mac bottom tabs result

## Changes

- Replaced `NavigationSplitView` in `ClockinMac/MacRootView.swift` with full-window detail content and a bottom `safeAreaInset`. The inset measures the bar and its floating margins; no fixed bottom padding is added to the screens. Scrollable content receives the reduced safe area so its final rows can clear the bar.
- Added `ClockinMac/MacTabBar.swift`: Today (`timer`), History (`chart.bar.xaxis`), Progress (`chart.line.uptrend.xyaxis`), and Settings (`gearshape`), each with its symbol above a localized label. Selection uses `palette.accent`; other labels use secondary color. Each entire rectangular item is clickable, with hover feedback, an accessibility label, and the selected trait.
- The capsule uses `glassEffect(.regular, in: Capsule())` on macOS 26+, following [Apple's glassEffect API](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)). On macOS 14–15 it uses regular material with a subtle, noninteractive capsule stroke.
- Selection binds directly to `MacNavigation.section`, including the existing nil-to-Today fallback. `MacNavigation`, `open(_:)`, and the Command-1 through Command-4 commands are unchanged. Settings retains its existing navigation stack.
- Every former split-view modifier remains in its original order, including celebration interaction blocking and overlay, sheets, prompts, debug sheet, environment values, grouped forms, tint, typography, color scheme, nudge handling, and reminder handling. Shared iPhone views are unchanged.

## Minimum window size

`ClockinMac/MainWindow.swift` sets a minimum content size of **390 × 650 points**. The capsule is at most 344 points wide, including its 6-point inner padding. Four equal items have 80 points each, with 4-point gaps. Including the inset's 12-point margins on each side requires 368 points, fitting within the current minimum. No window-size change was needed. The bar remains centered in wider windows.

## Validation

- Swift frontend parsing passed for both changed Swift files.
- An exact source comparison against HEAD confirmed that everything from the original `.allowsHitTesting` modifier through the end of `MacRootView` is unchanged, covering the existing modifier chain and detail routing.
- The new file is included by the project's existing synchronized `ClockinMac` source group; no project-file edit is required.
- Direct type-checking was attempted but Xcode 27's SwiftUI `@State` macro plugin cannot start inside this sandbox: `sandbox-exec: sandbox_apply: Operation not permitted`, followed by `SwiftUIMacros.StateMacro` / malformed plugin-response errors.
- A temporary copy with only the hover `@State` declaration manually expanded to `State<MacSection?>` storage **passed type-checking** with Swift 6, complete strict-concurrency checking, and a macOS 14 deployment target. It used the real `MacSection` declaration, a minimal palette environment fixture, and a `NavigationStack`/list/inset integration fixture. This checks both background branches, button styling, hover closures, accessibility traits, selection binding, and inset API usage. It does not validate the production macro expansion or the entire app dependency graph.
- `git diff --check` passed. No full app build or visual runtime review was performed.

The temporary harness is under `/tmp/clockin-bottom-tabs-check`. Its successful command was:

```sh
xcrun swiftc -typecheck -swift-version 6 -strict-concurrency=complete \
  -module-cache-path /tmp/clockin-bottom-tabs-check/cache \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -target arm64-apple-macos14.0 \
  /tmp/clockin-bottom-tabs-check/Dependencies.swift \
  /tmp/clockin-bottom-tabs-check/MacTabBar-expanded.swift
```

For the app review: resize to 390 × 650, switch all four tabs and Command-1–4, scroll History/Progress/Settings to the last row, and inspect hover, VoiceOver selection, light/dark themes, and celebration blocking. Glass on macOS 26+ and the material fallback on macOS 14–15 still need visual verification.

## Design consideration

I kept Settings as the requested fourth tab. For a future Mac-specific revision, I would consider a dedicated Settings window reached through the app menu and Command-comma, leaving three activity tabs. That would also bring the primary tab set closer to the iPhone's Today/History/Progress structure. It would be a separate navigation change; this implementation preserves all four destinations and existing shortcuts.
