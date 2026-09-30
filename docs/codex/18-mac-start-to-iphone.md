# 18: Clocking in on the Mac should show on the iPhone without opening it (design only)

The user starts the timer in Clockin for Mac; the iPhone only shows it (Live
Activity / Dynamic Island, widgets) after they open the iPhone app. They
expect the phone to follow on its own. Separately they do not want the iPhone's
Live Activity mirrored into the Mac menu bar next to the Mac's own item; the
only control for that is the Mac's global "Allow Live Activities from iPhone"
(System Settings > Notifications), which we will recommend.

Facts to build on:
- Sync: CloudKit private DB, CKSyncEngine, silent pushes; the iPhone handles
  `didReceiveRemoteNotification` (`Clockin/ClockinAppDelegate.swift`) and polls
  every 60 s only while active (`SyncCoordinator.setPolling`).
- iOS cannot `Activity.request` from the background; push-to-start
  (`Activity<…>.pushToStartTokenUpdates`, iOS 17.2+) is the documented way.
- Relay: Netlify functions in `/Users/erdemincedere/Clockin/clockin-main/services/live-activity`
  (read its README, `lib/relay.mjs`, `lib/apns.mjs`, `lib/activity.mjs`). Protocol 2
  is deliberately minimal: per-activity update token in the Authorization
  header, body only `{protocol, environment, expiresAt}`, minute timestamp
  pushes, default-off consent in the app (`Clockin/Privacy/LiveActivity*`,
  `Shared/Sync/LiveActivity*`, `Shared/Sync/SessionMirror.swift`), no financial
  or session content on the server.

Questions:
1. What exactly happens today on the iPhone when the Mac clocks in (silent push
   → fetch → `SessionMirror` → widgets / Live Activity)? What already works in the
   background (e.g. widget reload), and what cannot?
2. Design push-to-start from a Mac clock-in within the relay's privacy stance:
   what the phone registers (push-to-start token, per install), how the Mac proves
   it may trigger a start for that phone (e.g. a per-user secret the phone creates
   and syncs through the private CloudKit DB), what the start payload must
   contain for ActivityKit (attributes-type, attributes, content-state, alert,
   timestamp) and what the widget can instead read locally from the app group,
   ending the activity on clock-out, duplicates when the phone also starts one,
   token rotation/expiry, rate limits, abuse, the consent text and privacy policy
   changes, and what the server would newly learn (clock-in times).
3. Alternatives worth weighing (e.g. only reloading widgets and a local
   notification from the silent push; doing nothing server-side).
4. A step-by-step implementation plan split by repo (iPhone/Mac app vs relay),
   what needs a production relay deploy (the user must approve), and how to test
   on real devices.

Write `docs/codex/18-mac-start-to-iphone-result.md`. No source edits in either repo.
