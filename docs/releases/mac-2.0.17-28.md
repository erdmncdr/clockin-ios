# Mac 2.0.17 (28): Clock out on more sites

Source: `erdmncdr/clockin-ios` main at `016c753`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.17.md`.

A tester's Clock in worked, Clock out did not. Likely causes (the real site was not seen): the
watcher only considered the nearest button/link, so a picked div/span never matched; and the link
was opened by navigating the page, which a site navigation right after the click can cancel. The
watcher now matches along `composedPath()` and opens the link from a hidden iframe; `lastEvent` is
stored and shown in the popup for diagnosis.

Verification: Tests/manual/chromeextension 67 checks (toggle, two buttons, reloading site, div
buttons; the hidden-frame link reaches Chrome while the site navigates); README 53/53; publish.sh
--yes; live appcast 2.0.17 (28); anonymous Clockin.zip = release.
