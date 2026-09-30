# Mac 2.0.6 (17): Mac UI refresh and safer imports

Source: `erdmncdr/clockin-ios` main at `ddb33c2`, target `ClockinMac`.
Published to the existing Sparkle feed in `ismailakdag/clockin`
(`macos-updates/appcast.xml`), versioned release `macos-v2.0.6`.

Work split with Codex (briefs and results in `docs/codex/09`-`17`):

- UI (`bda04a1`): menu bar helmet without antenna, 17 x 15 pt on a 20 x 18 pt
  canvas (`docs/codex/10-menubar-preview.png`); bottom tab bar
  (`ClockinMac/MacTabBar.swift`) replacing the sidebar; Mac chime card; Settings >
  Menu bar > Show details in the menu bar (`Clockin.MacShowMenuBarDetails`, this
  Mac only) for users whose iPhone Live Activity is mirrored into the menu bar
  (no developer API keeps it off the Mac; `13-live-activity-on-mac-result.md`).
- Review 09 fixes (`048a55f`): import plans bound to the reviewed sessions and
  store-level refusal of changed removal targets; parsers report unreadable rows
  and deletions turn off; polls skip while a first-merge preview is open; copy
  groups counted once from stored durations; prompt re-checks after a merge and
  spends its daily allowance when shown; Mac radio card menu.
- Double-check 16 fixes (`a762d09`): polling recovers when no preview could be
  published; pasted row boundaries from the row grammar; Approved subtotal
  compared with Approved rows only; order-independent review currency and UUID
  tie-breaking.

## Verification

```text
Checks: import 102, overlap 47, sessiondisplay 61, backups 38, syncapp 62,
  sync 268, typecheck macOS 14 / iOS 17; all 42 README commands (Codex run)
Signed Debug build checked: bottom tabs, chime card, re-import alert
build.sh / notarize.sh / package.sh passed; Gatekeeper: Notarized Developer ID
publish.sh --yes (from ddb33c2): Live appcast 2.0.6 (17), 19,658,376 bytes;
  fixed macos-updates/Clockin.dmg matches the release DMG
```
