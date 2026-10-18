# Mac 2.0.19 (30): pinned timer while clocked in

Source: `erdmncdr/clockin-ios` main at `a5011dc`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.19.md`.

`Clockin.PinWhileClockedIn` (device-local, default off) via `PinnedTimerVisibility.shows`. Debug app on its
own data: option on + clocked in -> panel; idle -> none; option off -> none; minimal mode hid the
main window while the panel stayed. Also fixed the screenshot tool's `-key -bool YES` arguments.

Verification: README 54/54 (pinnedwindow 16); publish.sh --yes; live appcast 2.0.19 (30); zip = release.
