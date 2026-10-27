# Mac 2.0.27 (38): security review fixes

Source: `erdmncdr/clockin-ios` main at `eb01c71`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.27.md`. Review and fixes: `docs/codex/34-security-review*.md`.

- Pulse extension 1.4: the picker takes only trusted clicks and keys and re-checks its
  ten-minute limit at the click; the background forwards a command only while a setup
  exists, from the picked origin's top frame, with the id of the current setup, so a
  watcher left in an open tab after Remove or a repick is refused.
- Copy details in Menu bar settings reports the title length and bundle names, not the
  title text (which can carry earnings) or full paths.
- `CloudKitAdapter` encode-failure log keeps the record key private.
- Shared with iOS 0.2 (55): `ClockStore.exportBackup() -> Data?` (iOS-only caller).

Verification: Tests/manual/chromeextension/run (logic, link and native runs, twice);
chromeicons (10) against the Debug app; import suite (102) compiling ClockStore; Mac and
iOS Debug builds; a second read-only review pass over the diff; build.sh 2.0.27 38;
notarize.sh (Accepted, stapled, Gatekeeper accepted); package.sh; publish.sh --yes; live
appcast 2.0.27; website zip = release zip (18520030 bytes).
Not verified in a running app: Chrome reloading the extension from the app's copy
(testers may need Reload in chrome://extensions); the Copy details text.
