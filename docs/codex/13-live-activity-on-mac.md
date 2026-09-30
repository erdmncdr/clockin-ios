# 13: Two clocks in the Mac menu bar (ideas only, no code)

macOS 26 shows a nearby iPhone's Live Activities in the Mac menu bar. When the
user starts the timer on the iPhone, Clockin's Live Activity appears in the Mac
menu bar next to Clockin for Mac's own status item (which shows the same
running timer through iCloud sync), so there are two clocks.

What I found: users can switch iPhone Live Activities off on the Mac globally
(System Settings > Notifications, "Allow Live Activities from iPhone"); I found
no documented developer control to keep one app's Live Activity off the Mac.

Questions:
1. Is there any ActivityKit / Info.plist / `ActivityContent` option (iOS 26 /
   macOS 26 era) that keeps a Live Activity off the Mac menu bar or lets the
   app tell where it is shown? Say how sure you are and what you base it on.
2. Read `ClockinMac/MenuBarController.swift`, `ClockinMac/MenuBarStatus.swift`
   and the iPhone Live Activity code (`Shared/Sync/SessionMirror.swift`,
   `Clockin/Privacy/LiveActivity*`) and propose the best product behaviour for
   a user who has both apps. Options to weigh: the Mac item shows only the
   icon (no time) while running; a Mac setting "Show time in the menu bar";
   the iPhone skips or ends its Live Activity when the Mac app has been active
   recently (the Mac could publish a heartbeat through the synced data);
   leave it to the user's system setting. Consider users without a Mac.

Write `docs/codex/13-live-activity-on-mac-result.md`: answer to 1, a
recommendation for 2 with its trade-offs, and the smallest code change it
needs. Do not edit source files.
