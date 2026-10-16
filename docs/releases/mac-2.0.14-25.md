# Mac 2.0.14 (25): hidden menu bar item notice

Source: `erdmncdr/clockin-ios` main at `4b744ea`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.14.md`.

A tester saw no Clockin icon at all. On a full menu bar macOS hides items that do not
fit; a probe showed such an item window off-screen (y = -33) with no screen. Today now
shows a card with the pinned timer when the item stays off-screen for three seconds while
the menu bar is visible. Overflow behind the active app's menus was seen once here but
not reproduced deterministically, so the card may not cover every hiding case.

Verification: README checks 52/52 (macmenubar 8); publish.sh --yes; live appcast 2.0.14 (25);
anonymous Clockin.zip = release.
