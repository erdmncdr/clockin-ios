# Mac 2.0.15 (26): start from Chrome

Source: `erdmncdr/clockin-ios` main at `6916b78`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.15.md`.

- `clockin://clock-in` / `clock-out` handled by `ExternalClockCommandReceiver` (kAEGetURL, installed in
  applicationWillFinishLaunching). Live check on the Debug build and its own data: out, out again
  (no-op), in, in again (no-op); no extra instance.
- The extension (`ClockinMac/ChromeExtension`, flattened into Resources) is written by Settings >
  General > Start from Chrome to Application Support/Clockin/Chrome Extension; existing copies are
  refreshed at launch. Checked: launch refresh wrote all files and icon128.png.
- `Tests/manual/chromeextension/run`: 26 checks in headless Chrome (picker, registration for the
  picked origin only, toggle and two-button sites, the first clockin:// link reaching Chrome).
  Headless Chrome leaves its "Open Clockin?" prompt unanswered, which blocks later clicks, so the
  two-press runs use a copy that does not open links.
- Not verified: a real work site (shadow DOM or iframes could hide the buttons from the picker).

Verification: README checks 53/53; exported app has the clockin scheme and the 6 extension files;
publish.sh --yes; live appcast 2.0.15 (26); anonymous Clockin.zip = release.
