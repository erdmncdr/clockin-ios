# 30 — Rolling text clipping

## Cause and reproduction

The missing `ı` is a sizing/clipping error, not a missing Turkish glyph. The old
momentum label sized an overlay from a hidden SwiftUI `Text`, while the overlay
rendered independently measured native glyph cells. These are different text
engines and, on Mac, different caption metrics. `.monospacedDigit()` equalizes
digit advances within a font; it does not equalize the two fonts, line heights,
letter advances, kerning or outward rounding.

A headless `NSHostingView` reproduction using the original renderer and the
original placeholder/overlay composition produced:

| Measurement | Original result |
| --- | ---: |
| SwiftUI caption placeholder `$10,00 kaldı` | 64 × 13 pt |
| Rolling `$1,36 kaldı` natural size | 67 × 15 pt |
| Actual representable bounds inside the overlay | 64 × 15 pt |
| Content scale | 1.0 |
| Right edge of final cell | 66.7856 pt |
| Outer native layer clips to bounds | true |

`fittingSize` accepted the 64 pt proposal even though `minimumScaleFactor == 1`
prevented fitting the content into it. The final cell therefore extended beyond
the native clipping boundary. Trailing alignment positioned the already-clipped
representable; it could not restore the missing pixels.

The System 12 pt semibold `ı` has a positive 3.2691 pt advance. Every character
survives the Swift `Character` diff. The shaped whole string measures 66.5727 pt;
the separately measured cells total 66.7856 pt, rounded outward to 67. Per-cell
measurement is appropriate for the existing per-cell renderer. Changing Unicode
handling, dropping diacritics, or adding an arbitrary suffix padding would not
address the incompatible sizing contract. Terminal Amber supplies color, not a
different font measurement.

Evidence: `/tmp/clockin30-before.log`. This is a native hosted reproduction, not
a screenshot of the installed application.

## Changes

- `MoneyMomentumView.swift`: replace the hidden ordinary `Text` overlay with a
  `ZStack` containing a hidden rolling reservation and the live rolling label.
  Both use the same caption recipe, font design, digit features and localized
  key. Both participate in sizing, so a live value longer than the ten-unit
  reservation can enlarge it. The reservation is accessibility-hidden. Leading
  and trailing alignment remain explicit; the enclosing `ViewThatFits` can
  still stack the milestone labels.
- `RollingNumberLayout.fittingSize`: return at least the outward-rounded width
  required at the caller's minimum scale. Unbounded proposals retain natural
  size. Full line height is retained for accents and descenders.
- Both UIKit and AppKit `RollingNumberUIView.fittingSize` implementations use
  that shared calculation. Native clipping remains enabled for the animation;
  the renderer now requests bounds that actually contain its content.
- Font recipes, localized strings, glyph drawing, rolling animation and scale
  floors are unchanged. No geometry reader, preference callback, binding,
  measured-size state, or layout-time SwiftUI state write was added. Sizing and
  baseline callbacks remain pure; native layout only configures native layers.

The corrected hosted countdown reserves 75 × 15 pt for `$10,00 kaldı`; the live
`$1,36 kaldı` gets its complete 67 × 15 pt bounds. Hosting checks cover both
alignments and live amounts larger than the reservation.

## Call-site audit

All direct calls and the `MacRollingText` forwarding calls were inspected.
Only momentum used an independently sized hidden text overlay. Every other
label also shared the unsafe native proposal acceptance, so the common fix
protects those labels without changing their localized content.

| Call site | Text / sizing checked |
| --- | --- |
| `MoneyMomentumView` | Localized money `… to go` / `… kaldı`; same-font reservation, long live value, leading/trailing placement, horizontal/stacked fallback. |
| `TodayGoalsCard` (2 calls) | Worked duration; remaining duration or `Goal reached` / `Hedefe ulaşıldı`. No placeholder; native natural width is now respected. |
| `TimerCard` (3 calls) | 60 pt clock at 0.6 minimum; primary currency and converted TRY earnings. Money labels use natural sizing unless a surrounding environment supplies a scale floor. |
| `DeskModeView` (5 calls) | 120 pt clock at 0.4; primary/converted earnings at 0.5; Today duration and earnings caption. No hidden sizing surrogate. |
| `TodayLayout` (2 calls) | Compact duration and earnings columns at 0.7 minimum. |
| `MacShellSupport` | Explicit size/weight/design forwarding through the shared renderer. |
| `MenuBarPanelView` (4 wrapper calls) | Clock, primary/converted session earnings, monthly earnings; money rows inherit 0.75 or 0.8 minimum. |
| `PinnedWindow` (12 wrapper calls) | Compact, money, focus and total styles: clocks and primary/converted earnings, explicit fonts from 9–24 pt. No placeholder overlays. |

The native matrix includes Turkish and English remaining labels, both goal
completion strings, long prefix/suffix currency amounts, `ı ğ ş ç İ`, and
combining-mark graphemes. It covers System, Rounded, Serif and Monospaced at
9, 12, 13, 14, 15, 16, 17, 20, 21, 23, 24, 28, 30, 60 and 120 pt semibold.
Hosting also exercises the actual regular caption recipe for goal text.
Proposals are 0, 64, 120, 320, 700 and 1920 pt, with minimum scales 1, 0.7, 0.5
and 0.4. The tests require every non-space character to paint pixels, every
character to have nonzero font glyph coverage, matching grapheme/cell counts,
and the trailing cell to remain inside the fitted native bounds.

The fix honors existing readability floors. Below those floors it requests
more width instead of silently deleting a suffix. It does not promise that an
arbitrarily long amount fits every fixed outer window, nor change the existing
single-line labels into wrapping text. Full-screen iPhone accessibility layouts
and fixed pinned-window extremes still require visual device/app checks.

## Verification

| Check | Result |
| --- | --- |
| Focused regression against original native renderer | **Expected failure**, exit 1: narrow placeholder clips the final Turkish letter with scaling disabled. |
| `Tests/manual/rollingtext/run` | **86,705 native assertions**, **840 font/string cases**, **136 SwiftUI hosting assertions**, plus iOS renderer SDK typecheck passed. |
| README rolling suite | **197 passed**. |
| All root README `Checks` commands | **52/52 exited 0**, including the new focused suite, all model/art/sync suites, platform checks and SDK checks. The focused suite was rerun after its coverage expansion. |
| `Tests/manual/maclayout/run` (28 regression) | **38 passed**, plus the four source guards. |
| `python3 Tests/manual/crashaudit/typecheck.py` | **6/6 passed**: iOS app/widget at iOS 17 deployment; Mac app/widget at macOS 14 and 15 deployment. |
| `git diff --check` | Passed. |

Logs: `/tmp/clockin30-checks/results.json` and `01.log`–`52.log`;
`/tmp/clockin30-rollingtext.log`, `/tmp/clockin30-red.log`, and
`/tmp/clockin30-maclayout.log`. Full SDK output is in `08.log`, including the
individual compiler log paths. Production changes were complete before that
SDK pass; subsequent edits only expanded tests and documentation.

These are Swift 6 strict-concurrency/warnings-as-errors checks using the installed
SDKs and the repository's documented temporary macro-boundary substitutions.
The focused hosting fixture substitutes the theme/visibility environment and
aliases the real SwiftUI `State` wrapper; it uses the production rolling view,
representable, resolver, policy and renderer. Its reservation composition is a
fixture matching momentum, not an instantiated full Today screen. Native glyph
painting is tested offscreen on Mac. UIKit compilation and shared geometry are
covered; iPhone/simulator rendering and maximum Dynamic Type were not run.
No xcodebuild, signed app build, release or installed-app change was performed.
