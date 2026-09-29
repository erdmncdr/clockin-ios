# Brief 01 result — macOS rendering, audio and platform code

Date: 2026-09-29

Implemented the scoped macOS branches. No xcodebuild was run, no project file was changed, and nothing was committed. The other person's SwiftUI modifier/settings/intent work was left untouched, including the navigation modifier in ShareStatsView.

## Per-file behavior

Paths below are relative to the repository root. No required visual feature was replaced with an empty view.

| File | macOS behavior / remaining no-op |
| --- | --- |
| `Clockin/Views/Components/RollingNumberUIView.swift` | Flipped, layer-backed NSView renderer. Reuses two drawing views per digit, the existing right-indexed render state, 0.25-second move/fade transitions, length-change snapping, scaling, accessibility label and animation cleanup. The content and glyphs receive actual NSView frames. No stub. |
| `Clockin/Views/Components/RollingNumberText.swift` | NSViewRepresentable implements make/update/sizeThatFits/dismantle. Keeps the existing baseline alignment and reduce-motion, visibility, scene, thermal and low-power policy. |
| `Clockin/Views/Components/RollingNumberFont.swift` | NSFont recipes for the same supported font choices, designs and monospaced number feature. AppKit ascender/descender/leading supply line metrics; UIKit Dynamic Type scaling remains iOS-only. |
| `Clockin/Views/Companion/CompanionHomeAtmosphere.swift` | Flipped, layer-backed NSViewRepresentables render furniture, mirroring, leaf sway, lamp gradients and animated steam. Core Graphics supplies the Mac steam path. Same positions, colors, timing and teardown. |
| `Clockin/Views/Companion/CompanionHomePreview.swift` | Only the purchase accessibility announcement changed: NSAccessibility announcement on the key window, high priority. The original UIAccessibility statement remains in the iOS branch. |
| `Clockin/Celebrations/CelebrationConfetti.swift` | Flipped NSView and NSViewRepresentable with the existing CAEmitterLayer burst and cleanup. A Core Graphics bitmap supplies the white confetti chip; NSColor supplies the palette. |
| `Clockin/Celebrations/CelebrationPresentation.swift` | NSWindow attachment and companion visibility probes. Visibility checks window.isVisible, visible occlusion state, hidden ancestors, alphaValue, visibleRect and the window content bounds. Window occlusion/key/sheet-end notifications retry queued presentation; subscriptions are removed on detachment. Probes do not intercept clicks. |
| `Clockin/Celebrations/CelebrationCenter.swift` | Weak NSWindow reference, NSApplication activity and NSWorkspace Reduce Motion checks. Presentation waits for a visible, unoccluded window without an attached sheet or app-modal window. Existing queue, blockers, reactions, sound and timing remain. |
| `Clockin/Celebrations/LevelFeedbackReview.swift` | Debug review fixture gets an NSViewRepresentable window probe with viewDidMoveToWindow. |
| `Clockin/Celebrations/LevelUpCrest.swift` | Serif NSFont for Core Text numeral outlines; the existing optical centering and geometry remain. |
| `Clockin/Celebrations/LevelUpHaptics.swift` | Intentional Mac no-op for play/stop. Entire original Core Haptics implementation remains iOS-only. |
| `Clockin/Celebrations/LevelUpSound.swift` | AVAudioPlayer still plays and fades the bundled level-up sound while the Mac app is active. Audio session setup is iOS-only. |
| `Clockin/Views/Mascot/MascotAsset.swift` | Flipped NSViewRepresentable/NSView with the existing layer hierarchy, overlays, wings, skin effects, hop, sway, pop, wiggle and squash. Uses window/screen backing scale and stops motion on detachment/dismantle. iOS-only preferredFrameRateRange is omitted on Mac; Core Animation uses the display's scheduling. |
| `Clockin/Views/Mascot/MascotSkinEffects.swift` | NSColor conversions retain the existing glow, masked sheen, aura particles and pixel sprites. |
| `Clockin/Views/Earnings/ChartInteraction.swift` | SwiftUI zero-distance DragGesture scrubs through onTap locations; onContinuousHover also scrubs. A completed horizontal drag can page when pageable, using the existing EarningsSwipe decision. UIKit recognizers are unchanged. |
| `Clockin/Views/Share/ShareStatsView.swift` | NSImage previews, ImageRenderer.cgImage → NSBitmapImageRep PNG export, ShareLink preview, NSPasteboard PNG copy, and copy failure feedback. Render scale is preserved in pixel output and NSImage point size. |
| `Clockin/Privacy/PrivacyPolicyBrowser.swift` | Same SwiftUI construction/call site. On presentation, opens the policy URL through NSWorkspace in the default browser and dismisses the sheet. If opening fails, shows retry and Done controls. No in-app Safari on Mac. |
| `Clockin/Audio/FocusChimeController.swift` | Keeps AVAudioPlayer playback, volume, notification scheduling and delegate handling. No audio session category/activation/interruption/route/reset observers on Mac. Session-retention method returns false because there is no session to own. Mac authorization checks omit ephemeral. |
| `Clockin/Audio/FocusRadioController.swift` | Keeps AVPlayer streaming, station switching, pause/stop, failure monitoring, volume, Now Playing and remote commands. No audio session setup, activation, interruption/route/reset observers or deactivation on Mac. |
| `Clockin/Audio/LongSessionReminderController.swift` | Only the permission list branches: authorized/provisional on Mac; ephemeral remains accepted on iOS. |
| `Clockin/Companion/NudgeController.swift` | Only the permission list branches, as above. |
| `Shared/Theme/Platform.swift` | Tiny helper used by multiple renderers: PlatformColor is exactly UIColor on iOS and NSColor on Mac. Reduce Motion and app-active queries map directly to platform APIs. The app-active member is excluded under WIDGET_EXTENSION. |

Intentional omissions on Mac are haptics, AVAudioSession operations and iOS animation frame-rate hints. Playback and visual effects themselves are implemented. No production stubs were added for app data, sync or storage.

## iOS preservation

The rolling renderer and font resolver retain their complete original implementations under canImport(UIKit). Chart recognizers, Safari controller, permission checks including ephemeral, audio session handling and Core Haptics retain their original statements under platform guards.

The shared iOS lines that changed beyond adding guards are:

- `UIColor` references in RollingNumberText, CompanionHomeAtmosphere, MascotAsset and MascotSkinEffects now spell `PlatformColor`; its iOS alias is exactly UIColor.
- CelebrationCenter and LevelUpSound use `Platform.isAppActive`; CelebrationCenter uses `Platform.reduceMotion`. The iOS expressions inside those getters are exactly the previous UIApplication/UIAccessibility expressions.
- FurnitureLayerView, HomeAtmosphereLayerView, MascotLayerView and CelebrationConfettiView name a local superclass alias, which is exactly UIView on iOS. `renderingLayer` returns the original nonoptional UIView.layer. Layout/window override bodies delegate to private helpers after the same super call so AppKit lifecycle methods can run the identical layer operations.
- Confetti's original color array is bound to `colors` before mapping, allowing a different platform palette initializer. Its iOS chip renderer, colors, cells and animation values are unchanged.
- ShareStatsView's two `Image(uiImage: preview)` expressions call a private `previewImage` overload that returns exactly `Image(uiImage: image)` on iOS. The iOS renderer and pasteboard statements remain unchanged.

No intended iOS behavior changes. This is source/targeted compiler verification, not a full iPhone app build or device test.

## Compiler verification

Used the installed macOS 27.0 and iPhoneSimulator 27.0 SDKs, targeting **arm64 macOS 14** and **arm64 iOS 17.0 simulator**, Swift 6 with complete strict concurrency. The initial isolated Mac rolling compile reproduced the missing UIView/UIFont errors before edits.

All focused suites below finished with **exit 0 on both SDKs**:

| Suite | Checked code and boundary |
| --- | --- |
| `rolling` | Complete RollingNumberUIView, RollingNumberFont, CelebrationConfetti and Platform; actual RollingNumberRepresentable declarations extracted from RollingNumberText; original RollingNumber model dependency. |
| `audio` | Complete FocusChimeController, FocusRadioController, LongSessionReminderController, NudgeController and LevelUpSound, with real core models/store, schedule, station, sound, nudge and mascot-resource code. Temporary SharedStore/SessionMirror boundary doubles prevent pulling in app lifecycle/Live Activity code. These doubles exist only in /tmp. |
| `layers` | Complete CompanionHomeAtmosphere and MascotSkinEffects; exact MascotAsset animation-rate extension, representables and native renderer extracted from the file. Actual wardrobe/art/cache/motion dependencies; only the unrelated SwiftUI still-image wrapper was omitted from a temporary MascotFrames copy. |
| `center` | Complete CelebrationCenter, CelebrationPresentation and LevelUpHaptics, plus the actual review window probe extracted from LevelFeedbackReview. Uses real queue, model, snapshot adapter, wardrobe, timing, sound, policy and haptic dependencies; the same temporary sync boundary doubles as audio. |
| `small` | Complete ChartInteraction with EarningsSwipe dependencies; actual crest numeral/outline declarations; isolated share renderer/PNG/pasteboard/Image APIs, purchase accessibility announcement APIs and policy browser open API. This verifies those SDK calls, not their entire SwiftUI screens. |

Additional complete checks passed:

- iOS PrivacyPolicyBrowser with its real LiveActivityPrivacy dependency.
- Platform.swift with the iOS simulator SDK, **-D WIDGET_EXTENSION -application-extension**, Swift 6. No UIApplication extension-unavailable API remains in this configuration.

The focused commands use this shape:

```sh
swiftc -typecheck -swift-version 6 -strict-concurrency=complete \
  -module-cache-path /tmp/clockin-mac-render-cache \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -target arm64-apple-macos14 <suite sources>

swiftc -typecheck -swift-version 6 -strict-concurrency=complete \
  -module-cache-path /tmp/clockin-ios-render-cache \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios17.0-simulator <suite sources>
```

Exact argument lists and output are retained locally as `/tmp/clockin-{rolling,audio,layers,center,small}-{mac,ios}.command` and `.log`. Source manifests and temporary harnesses are `/tmp/clockin-*-files.txt`, `/tmp/clockin-typecheck.py` and `/tmp/clockin-*.swift`.

### Incomplete full-file / target checks

The sandbox blocks the SwiftUI macro plugin. A direct Mac PrivacyPolicyBrowser compile reports:

```text
sandbox-exec: sandbox_apply: Operation not permitted
external macro implementation type 'SwiftUIMacros.StateMacro' could not be found
swift-plugin-server produced malformed response
```

The broader iOS frontend check also reports unavailable StateMacro/EntryMacro implementations and dependent missing-state/binding errors. Consequently the complete SwiftUI bodies in **RollingNumberText, MascotAsset, CompanionHomePreview, LevelFeedbackReview, ShareStatsView**, and the **Mac PrivacyPolicyBrowser** are not fully validated here. Their changed native/API portions were checked separately as described above. **LevelUpCrest** was checked at the changed numeral/outline implementation level, not as a complete crest view with its full drawing dependency graph.

An attempted broader Mac frontend check additionally stops at the out-of-scope `Shared/Sync/LiveActivityPush.swift` import of UIKit. These checks are not ClockinMac target builds. The other person's modifier fixes, including ShareStatsView.navigationBarTitleDisplayMode, are still required before a combined target build. Neither complete app target is claimed to build here.

## Native rolling runtime check

Built and ran a temporary AppKit executable against the actual RollingNumberUIView/RollingNumberFont/RollingNumber sources. It checks flipped views, nonzero glyph frames, animated 19→20 carry, snapping on 20→100 length change, accessibility label and stopAnimations cleanup. An offscreen AppKit bitmap was inspected and visibly renders `100`; the final bitmap contains 2,095 nontransparent pixels. This caught the need to set NSView frames explicitly rather than only CALayer bounds.

```text
root (0.0, 0.0, 200.0, 80.0) content (0.0, 4.5, 113.0, 71.0) bounds (0.0, 0.0, 113.0, 71.0)
nontransparent pixels 2095
PASS: flipped rolling views, glyph bounds, animated carry, length change, accessibility and cleanup
```

Artifacts: `/tmp/clockin-native-main.swift`, `/tmp/clockin-native-check.log`, `/tmp/clockin-rolling-native.png`. This does not validate live window occlusion, on-screen confetti/mascot animation, browser launch, system clipboard interaction, notification delivery or audible playback in the assembled app. Those remain integration checks for the combined build.

## README manual checks

All ten requested suites passed: **791 checks total**. The unchanged README commands for chime, chimesound and share initially failed because their default module-cache path was outside the writable sandbox. Rerunning those commands with only `-module-cache-path /tmp/clockin-<name>-module-cache` added passed. Other commands ran as written. These existing suites test model/policy behavior; they do not compile all native UI controllers.

Final output tails:

### rolling — exit 0

```text
ok: policy combination true/true/3/true/false/false
ok: policy combination true/true/3/true/false/true
ok: policy combination true/true/3/true/true/false
ok: policy combination true/true/3/true/true/true
197 rolling checks passed
```

### haptics — exit 0

```text
ok: disabled press stays silent
ok: reading a signal does not trigger feedback
ok: explicit action advances signal
ok: repeated explicit actions remain distinct
61 haptics checks passed
```

### celebrations — exit 0

```text
ok badge persistence key
ok level card waits for explicit dismissal
ok brief companion reaction still expires
ok badge banner allows reading time
108 celebration checks passed
```

### levelup — exit 0

```text
ok: milestone preserves the regular pattern
ok: milestone adds exactly four rank reveal transients
ok: rank reveal is felt after the hitstop
ok: rank reveal has three light sparkles spaced 0.12 seconds apart
27 levelup checks passed
```

### radio — exit 0

```text
ok: terminal state cannot publish Now Playing: interruption, radio true, chime true
ok: failure offers retry; stop hides card: interruption, radio true, chime true
ok: play then pause then stop removes the card
ok: failed playback offers in-app retry without remote resurrection
109 radio checks passed
```

### chime — exit 0

```text
ok: empty queue is filled within the available capacity
ok: interval edit produces exactly the new schedule
ok: legacy request without date metadata is replaced once
ok: floating point date noise does not rewrite requests
29 chime checks passed
```

### chimesound — exit 0

```text
ok: 16-bit linear PCM: tiny-ping
ok: unclipped -3 dBFS peak: tiny-ping
ok: zero endpoints: tiny-ping
ok: RMS levels within 3 dB
96 chime sound checks passed
```

### reminder — exit 0

```text
ok: future end rejected
ok: ending at the last resume keeps the earlier worked time
ok: paused session falls back to start
ok: future resume clamps to now
44 reminder checks passed
```

### nudges — exit 0

```text
ok: evening streak risk takes precedence over no-work mood
ok: overnight active session always uses working companion
ok: injected timezone preserves anchor across daylight saving
ok: calendar-day planning avoids fixed twenty-four-hour drift
93 nudge checks passed
```

### share — exit 0

```text
ok: Public never invents a best day
ok: Private has an empty best-day fallback
ok: Private never invents a best day
ok: Repeated selection is deterministic
27 share checks passed
```

`git diff --check` passes. The code diff is confined to the authorized files and the new Platform.swift helper.
