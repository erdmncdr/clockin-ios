# 19: Guide Mac users to the "Allow Live Activities from iPhone" switch

macOS 26 mirrors the iPhone's Clockin Live Activity into the Mac menu bar next
to Clockin for Mac's own item, so the user sees two timers. Apps cannot change
that setting, but this deep link opens the exact page (verified on macOS 26,
Turkish UI "iPhone Bildirimleri", switch "iPhone'dan Canlı Etkinliklere İzin
Ver" at the top):

    x-apple.systempreferences:com.apple.Notifications-Settings.extension?RemoteNotificationSettings

## Build

1. Settings > Menu bar (`ClockinMac/MacSettingsSection.swift`): below "Show
   details in the menu bar", a short explanation and a button "Open iPhone
   notification settings" that opens the link above (fallback: the plain
   Notifications pane URL if the anchored one fails to open).
2. A one-time tip, Mac only: the first time this Mac sees a running timer that
   started on another device (a running session arriving through sync while
   the Mac did not clock in itself), show a small dismissible card in the menu
   bar panel and at the top of Today: "Seeing two timers in the menu bar?" /
   one line explaining the iPhone Live Activity / buttons "Open Settings" and
   close. Never an alert that steals focus. Remember dismissal on this Mac only
   (standard defaults key, not synced). Find the cleanest place to detect "a
   running session applied from sync" (`Shared/Sync/SyncCoordinator.swift`
   apply path, `ClockStore`, or `ClockinMac/MacAppServices.swift`) without
   touching the sync core's behavior.
3. English strings with Turkish translations in `Shared/Localizable.xcstrings`
   (usual serialization; "menü çubuğu", "Canlı Etkinlik"). iPhone unchanged.

## Deliver

Focused checks where logic is testable (the "started elsewhere" detection),
README suites that do not need xcodebuild, and
`docs/codex/19-live-activity-settings-tip-result.md`.
