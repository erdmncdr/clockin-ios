# Mac 2.0.18 (29): pinned timer moves, resizes, stays on screen

Source: `erdmncdr/clockin-ios` main at `a9d7be1`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.18.md`.

- Minimal mode no longer unpins or hides the pinned timer (launch, toggle and refresh paths).
- `PinnedWindowChrome.swift`: drag area and corner grip (both `acceptsFirstMouse`), `PinnedFrame.fitted`
  on show, layout change and display change.
- Real mouse events (CGEvent) on the running Debug app (its own prefs domain
  `com.ismailakdag.clockin.debug`): a frame saved half off-screen opened at x=1266..1512; an empty-spot drag
  moved it by (-400, +150); a corner drag resized 246x96 to 366x156 with the top-left fixed, saved.
  Test processes launched from the shell receive no input here, so the harness checks the parts.

Verification: README 54/54 (pinnedwindow 12); publish.sh --yes; live appcast 2.0.18 (29); zip = release.
