# Mac 2.0.8 (19): Mac polish

Source: `erdmncdr/clockin-ios` main at `9e4d08e`, target `ClockinMac`.
Published to the Sparkle feed in `ismailakdag/clockin` (`macos-updates/appcast.xml`),
versioned release `macos-v2.0.8`. Notes: `docs/release-notes-mac-2.0.8.md`.

Work split with Codex (briefs and results `docs/codex/27`, `28`):

- 27 (`3673f27`): three-tab glass tab bar, categorized Settings page, native
  controls, History/Progress gutters and Click copy, future days not
  inspectable, trackpad period paging with arrow keys, chart hover, row context
  menus, full-screen desk mode.
- Review of 27 (signed Debug captures): an intermittent AppKit layout exception
  (`_postWindowNeedsUpdateConstraints`, once in about 20 launches into History),
  small Today actions, opaque bar, saturated sidebar selection, desk panel over
  the companion, two History backgrounds.
- 28 (`fa4c48f`): hover no longer resizes the chart row; layout-time writes are
  deferred and equality-checked; constant window minimum; full-width actions;
  clear glass bar; desk panel in the upper wall area; one History page.
- `9a5017c`: Settings sidebar uses the theme accent (the system sidebar drew the
  app's fixed green under the multicolor accent).
- `082da42` (earlier today): pinned-timer saved sizes raised to the panel minimum.

## Verification

```text
README checks 50/50; macpolish 33; maclayout 42; iOS source paths unchanged (32
  shared files); iOS simulator build; SDK typecheck (iOS 17, macOS 14/15)
Signed Debug: 23 launches across Today/History/Progress after 28, no exception
  (before: 1 in ~20); captures EN/Carbon and TR/Electric Blue reviewed
Not exercised by hand: two-finger paging, hover readout, context menus
build.sh / notarize.sh / package.sh passed; Notarized Developer ID; Production
publish.sh --yes: live appcast 2.0.8 (19), 19,944,214 bytes; fixed
  macos-updates/Clockin.dmg matches the release DMG
```
