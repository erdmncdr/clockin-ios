# 28: Fix what the 27 review found

I built your 27 work (Debug, signed) and captured every screen with
`website/tools/screenshots/run` (960 x 860 pt window, Carbon). Fix these on top
of `3673f27`; the iPhone app must stay unchanged, same rules as 27.

## 1. Blocker: layout exception crash

The first capture run crashed once, about 5 s after launching straight into
History (`--open-section history --clock-in`, right after a Today launch):
`-[NSWindow(NSDisplayCycle) _postWindowNeedsUpdateConstraints]` raised from
`NSHostingView.setNeedsUpdate` <- `GraphHost.flushTransactions` <-
`NSHostingView.layout` inside the window's display-cycle layout pass. This is
AppKit's "more Update Constraints in Window passes than there are views"
exception: SwiftUI state is being written during layout repeatedly, i.e. a
layout feedback loop. Full report: `/tmp/clockin-28-layout-crash.ips`
(`asiBacktraces`). Main before 27 never showed it; 6 direct relaunches into
History did not reproduce it, so it is timing dependent (the timer ticks every
second while clocked in).

Audit everything 27 added or changed on the Mac paths for writes that can happen
during a layout pass or that can oscillate: `onGeometryChange`/`GeometryReader`
or preference values stored into `@State`/bindings, `NSViewRepresentable`
`updateNSView`/`sizeThatFits`/`layout` that set bindings or call back into
SwiftUI synchronously (`MacPeriodScroll`, `MacChartReadout`, `MacPeriodNavigation`,
hover/inspection state, `MacControlHover`), content margins or frames derived from
measured sizes (tab bar clearance, Settings 700 pt minimum, max-width columns),
`glassEffectID`/`matchedGeometryEffect` selection, `NSWindow` min size changes.
Make every such write idempotent (only when the value actually changes) and
deferred out of the layout pass where needed; remove measured-size feedback.
Explain the root cause you find, and add a check if any part can be tested
headlessly. I will rerun the capture loop afterwards.

## 2. Today: primary actions lost their weight

Pause / Clock out became two small centered capsules. Keep the native look but
restore the hierarchy: full-width, large (`controlSize(.extraLarge)` or `.large`
with a full-width label) side-by-side buttons as before, Clock out clearly the
destructive one, Pause secondary; the same in the menu bar panel. Start (idle)
must be the single prominent action.

## 3. Tab bar still looks opaque

In the capture it is a solid dark grey capsule; rows under it are simply hidden.
It should read like the iOS 26 tab bar: visibly translucent glass (lighter
refraction/highlight edge, content blurred through it), the selection a lighter
glass pill with accent-tinted icon and label rather than a filled green block.
If `.glassEffect(.regular)` on this dark palette renders opaque, use
`.glassEffect(.clear)` or a tuned variant (tint, interactive) and make sure the
bar is not sitting on an opaque backing. Keep the material fallback.

## 4. Settings sidebar selection

The selected category is a large saturated green block. Use the native sidebar
selection look (`List(selection:)` with `.listStyle(.sidebar)`), accent applied
the system way. Give the right pane a title for the category.

## 5. Desk mode: timer panel covers the companion

At 16:10 (1440 x 900 window capture) the translucent timer panel sits over the
companion's head. Place the panel higher (upper third) or make it smaller so the
companion and its desk stay fully visible on 16:10, 16:9 and 3:2; keep it legible.

## 6. History polish

The chart/summary block sits on a separate darker panel that ends before the
day list, so the page has two different backgrounds. Make the top block and the
day list read as one page (same background, consistent 28 pt gutters).

Run the README suites, the 27 checks and the SDK typecheck. Write
`docs/codex/28-mac-polish-fixes-result.md` with the crash root cause.
