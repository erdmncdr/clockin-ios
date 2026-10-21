# Mac 2.0.24 (35): extension renamed Pulse, toolbar-sized icons

Source: `erdmncdr/clockin-ios` main at `bea86d0`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.24.md`. Extension manifest 1.3; same key, so same ID and storage.

- Name Pulse in manifest, popup title, picker bar and page toasts; page event `pulse:command`
  (was `clockin:command`, readable by the site's scripts). Settings step 3 says Pulse; step 4
  (Chrome's "Open Clockin?" prompt, gone since native messaging) removed.
- Icons 16/32/48/128 from the app icon cropped to its tile (`ChromeExtensionInstaller.artwork`);
  128 keeps an 8 px margin. Before, one 128 px icon with the macOS margin looked small.

Verification: chromeicons 10/10 (and a visual side-by-side of old/new); Chrome checks 98 ok twice,
native included ("Pulse ✓ Clock in" toast). publish.sh --yes; live appcast 2.0.24 (35); website zip
= release zip (18396601 bytes).
Not verified: how the user's Chrome removed the extension (its profile folder is TCC-protected).
