# 11: iOS-style bottom tabs in the Mac window

The user finds the Mac window's left sidebar (Today / History / Progress /
Settings) amateurish and wants tabs at the bottom like the iPhone app.

## Scope

- `ClockinMac/MacRootView.swift`; a new `ClockinMac/MacTabBar.swift` if it
  keeps things clear. Do not change shared iPhone views. `MacNavigation`
  (`ClockinMac/MacCommands.swift`) keeps working: `section`, `open(_:)`, and
  the ⌘1-⌘4 commands.

## Direction

- Replace the `NavigationSplitView` with the detail content filling the
  window and a floating capsule tab bar centred at the bottom: four items,
  SF Symbol above a short label, as on iOS (Today `timer`, History
  `chart.bar.xaxis`, Progress `chart.line.uptrend.xyaxis`, Settings
  `gearshape`). Selected item uses `palette.accent`; others secondary.
- Background: Liquid Glass (`glassEffect`) when available (`if #available(macOS
  26, *)`), otherwise `.regularMaterial` in a capsule with a subtle stroke.
  The deployment target is macOS 14.
- Content must not end up under the bar: use a bottom safe-area inset rather
  than fixed padding, so scroll views scroll behind it but their last rows
  stay reachable.
- Pointer: hover highlight, the whole item is the hit area, accessibility
  labels and `isSelected` trait, keyboard focus not required.
- Keep every modifier currently on the split view (celebration overlay,
  sheets, prompts, environment, `formStyle`, tint, colour scheme, the
  `nudges.openToday` / reminder handlers). Settings may keep its own
  navigation inside the content.
- Check window minimum size in `ClockinMac/MainWindow.swift`; the bar must fit
  at the minimum width.

## Deliver

`docs/codex/11-mac-bottom-tabs-result.md`: what changed, and anything you
would do differently (e.g. whether Settings belongs in the bar on the Mac,
since iOS reaches it from a gear on Today). Type-check what you can; I build
and look at it in the app.
