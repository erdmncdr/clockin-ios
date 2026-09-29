# Brief 01: make the UIKit-backed rendering, audio and platform code compile for macOS

Read `docs/mac-plan.md` for context. The `ClockinMac` target (macOS 14,
SwiftUI app, not sandboxed) now compiles `Clockin/` and `Shared/` together with
the iPhone app. `docs/codex/01-mac-build-errors.txt` is the current error list
from `xcodebuild -scheme ClockinMac`. Every file below already has its
`import UIKit` changed to `#if canImport(UIKit) import UIKit #else import AppKit #endif`.

Another person is fixing the SwiftUI-modifier errors at the same time
(`navigationBarTitleDisplayMode`, `insetGrouped`, `keyboardType`,
`fullScreenCover`, `topBarTrailing`, `safeAreaBar`, `LiveActivityIntent`,
`UIApplication.openSettingsURLString` in the settings sections, `UIResponder` in
GoalsPaceView, `ClockinMac/*`). Do not touch those files or lines.

## Your files

- `Clockin/Views/Components/RollingNumberUIView.swift`,
  `RollingNumberText.swift`, `RollingNumberFont.swift`
- `Clockin/Views/Companion/CompanionHomeAtmosphere.swift`,
  `CompanionHomePreview.swift` (only its `UIAccessibility` use)
- `Clockin/Celebrations/CelebrationConfetti.swift`,
  `CelebrationPresentation.swift`, `CelebrationCenter.swift`,
  `LevelFeedbackReview.swift`, and any other file in `Clockin/Celebrations/`
  that fails once these compile
- `Clockin/Views/Mascot/MascotAsset.swift`, `MascotSkinEffects.swift`
- `Clockin/Views/Earnings/ChartInteraction.swift`
- `Clockin/Views/Share/ShareStatsView.swift` (UIImage, UIPasteboard)
- `Clockin/Privacy/PrivacyPolicyBrowser.swift` (on the Mac, open the policy in
  the default browser with `NSWorkspace`/`openURL` instead of an in-app Safari
  view; the SwiftUI call site should not need to change)
- `Clockin/Audio/FocusChimeController.swift`, `FocusRadioController.swift`
  (`AVAudioSession` does not exist on macOS: no session category, activation,
  interruption or route-change handling is needed there)
- the `'ephemeral' is unavailable in macOS` errors in
  `Clockin/Audio/LongSessionReminderController.swift` and
  `Clockin/Companion/NudgeController.swift`
- one new file, `Shared/Theme/Platform.swift`, if and only if three or more of
  your files need the same thing (for example `PlatformColor`/`PlatformFont`/
  `PlatformImage` typealiases, "is Reduce Motion on", "is the app active" and
  the matching change notification). Keep it tiny. `Shared/` is also compiled
  into the iOS widget extension, so it must compile with `WIDGET_EXTENSION`
  defined on iOS.

## Rules

1. **The iPhone build must not change behavior.** Keep every iOS code path
   exactly as it is: wrap with `#if os(iOS)` / `#if canImport(UIKit)` and add
   a macOS branch next to it. Do not refactor iOS code to share a new
   abstraction unless the iOS result is identical. If you do introduce a
   typealias, the iOS branch must be the same type the code used before.
2. **macOS branches should behave like the iPhone, not be stubs,** where the
   feature matters on a Mac: the rolling digits (AppKit `NSView` +
   `NSViewRepresentable`, or a SwiftUI fallback if the file already has one:
   check `RollingNumber.swift` and `RollingAnimationPolicy.swift` first),
   confetti, celebration window probing (on the Mac the "window" is an
   `NSWindow`; visibility is `window?.isVisible` and occlusion state), mascot
   rendering, the room atmosphere, chart drag-to-scrub (a SwiftUI
   `DragGesture`/`onContinuousHover` path is fine on Mac; keep the UIKit
   gesture recognizer path on iOS), and copying the share image to the
   pasteboard (`NSPasteboard`). Things that have no Mac meaning (haptics,
   audio session) become no-ops.
3. `NSViewRepresentable` uses `makeNSView`/`updateNSView`/`dismantleNSView`.
   AppKit views are not flipped by default; set `isFlipped` where the UIKit
   code assumes a top-left origin. `NSView` has no `alpha`/`isHidden` on
   the layer by default in the same way; use `alphaValue`, `isHidden`,
   `wantsLayer = true` where layers are used. `NSColor` needs `.cgColor`
   conversions in the same places as `UIColor`.
4. Swift 6 strict concurrency is on. `NSView` subclasses are `@MainActor`.
   Keep representables and their coordinators main-actor isolated the way the
   iOS versions are.
5. Keep the surrounding style: comments are short, Turkish without
   diacritics in existing Turkish files; match what the file already does.
6. Do not modify `Clockin.xcodeproj`, do not add files outside the list and
   `Shared/Theme/Platform.swift`, do not commit.

## Verification

You cannot run xcodebuild here. For every file you touch, type-check what you
can with the macOS SDK and with the iOS simulator SDK, for example:

```bash
SDK_MAC=$(xcrun --sdk macosx --show-sdk-path)
SDK_IOS=$(xcrun --sdk iphonesimulator --show-sdk-path)
swiftc -typecheck -swift-version 6 -sdk "$SDK_MAC" -target arm64-apple-macos14 <files...>
swiftc -typecheck -swift-version 6 -sdk "$SDK_IOS" -target arm64-apple-ios17.0-simulator <files...>
```

Many files depend on other files in the module; include the minimum set of
dependencies, or type-check just the self-contained ones. If the SwiftUI
macro plugin is blocked in this sandbox, say which files you could not check.
Also run the existing checks from `README.md` that compile any file you
touched (rolling, haptics, celebrations, levelup, radio, chime, chimesound,
reminder, nudges, share if applicable) and paste their tails.

## Result

Write `docs/codex/01-mac-render-result.md`: per file, what the macOS branch
does and anything that is still a stub; what you could and could not
type-check; any iOS line you had to change and why.
