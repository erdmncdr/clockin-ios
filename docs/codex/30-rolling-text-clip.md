# 30: Rolling text drops the last Turkish letter

Mac Today, Turkish, Terminal Amber theme, System font: the money momentum card
(`Clockin/Views/Momentum/MoneyMomentumView.swift:116-128`) shows "$1,36 kald"
instead of "$1,36 kaldı". The label is `RollingNumberText` in an overlay over a
hidden placeholder `Text("\(min(10, target).money) to go")`; rolling layout
measures each character separately (`RollingNumberFont.layout`).

Find the real cause (glyph measurement or rendering of non-ASCII letters such as
ı, ğ, ş, ç, İ; placeholder vs. rolling width with `.monospacedDigit()`; clipping
of the representable's bounds; trailing alignment), fix it for both iPhone and
Mac, and check every other `RollingNumberText` call site with localized text
(goal "... to go", "Goal reached", earnings) for the same problem in Turkish and
English, all four font designs, long amounts and large text. No layout-time state
writes (see 28).

Add a focused test (layout widths/rendered glyph count for Turkish strings), run
the rolling suite and all README suites that do not need xcodebuild, and the SDK
typecheck. Write `docs/codex/30-rolling-text-clip-result.md`.
