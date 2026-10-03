# Mac 2.0.9 (20): Font setting, simpler History, rolling-text fix

Source: `erdmncdr/clockin-ios` main at `9fdec2b`, target `ClockinMac`.
Published to the Sparkle feed in `ismailakdag/clockin` (`macos-updates/appcast.xml`),
versioned release `macos-v2.0.9`. Notes: `docs/release-notes-mac-2.0.9.md`.

- `e5956f3`: History toolbar (By day / Sessions, plus) removed on the Mac; list
  always grouped by day.
- Codex 29 (`0b842b5`, `6ace28a`): font is a device-local setting (System,
  Rounded, Serif, Monospaced; System for everyone); themes set colors only.
  Device-local because shipped clients quarantine unknown preference records.
  Option labels drawn in their own designs (picker styles stripped them).
- Codex 30 (`b2662cc`): rolling text reserved width with ordinary Text (64 pt vs
  67 pt needed) and clipped the last letter ("kaldı").

## Verification

```text
Worktree suites: README 52/52 (rolling 197, fontchoice 145), macpolish 33,
  maclayout 42, SDK typecheck six targets; Mac and iOS simulator builds
Signed Debug: Mac Settings font chips, Terminal Amber + System, Electric Blue +
  Monospaced, momentum label "kaldı"; iPhone simulator font list and Serif
build.sh / notarize.sh / package.sh passed; Notarized Developer ID
publish.sh --yes: live appcast 2.0.9 (20), 19,952,912 bytes; fixed
  macos-updates/Clockin.dmg matches the release DMG
```
