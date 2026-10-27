# iOS 0.2 (54): level-up share picture, timer log, external-start switch

Repository: `erdmncdr/clockin-ios`. Source: main at `5428b1b`. Everything from 0.2 (53).

- Level-up Share makes a picture of the level card (story 1080×1920 or post
  1080×1350) with Save to Photos (add-only access) and Copy (Codex 32, `d3e8387`).
- Timer log in Settings > Data: every clock-in, resume and clock-out with its
  origin (app, widget/Siri/Shortcuts, Control Center, another device through
  iCloud). Device-local, 100 entries (Codex 33, `a38df42`).
- Settings > Today switch `Clockin.ExternalStartsEnabled`: when off, widgets,
  Control Center and Siri cannot start or resume the timer; clock out still works.
- Archive `build/ios-release/Clockin-0.2-54.xcarchive`, team LU36PKDPT3,
  `Tools/ios-release/ExportOptions.plist`.
- Uploaded 2026-10-27 16:55 (+03); App Store Connect showed it processed
  ("Ready to Submit") by 22:50 the same evening. Build id
  `94dd0f15-35a3-45fe-a0dc-4b662219af2a`. What to Test in English and Turkish;
  added to Clockin Internal and Clockin Public Beta; beta review submitted
  (WAITING_FOR_REVIEW); internal and external state IN_BETA_TESTING; tester
  notification on.
- Same day: Mac 2.0.26 (37) with the Mac side of the timer log (`docs/releases/mac-2.0.26-37.md`).

Owner checks in the shipped build: the Control Center toggle is refused and reads
the real state when the switch is off; the log fills from each origin; Save to
Photos asks for add-only access once.
