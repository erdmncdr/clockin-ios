# 20: The iPhone follows a Mac clock-in (app-only path, no relay change)

Decision (user + me, after your design 18): do the app-only path now; the
push-to-start relay (18) is deferred. Implement on the iPhone:

1. Background Live Activity replacement bug (your finding in 18): when
   `SessionMirror` needs to replace an activity (currency/calculation inputs,
   pause state, remote consent) it ends the old one before requesting a new
   one, and in the background the request fails, so the card disappears.
   In the background, update the existing activity in place with the best
   state it can carry (or keep it until the app is active and replace then);
   never end it without being able to request its replacement. Ending because
   the timer stopped stays immediate, foreground or background.
2. Remote clock-out ends the Live Activity in the background: verify the path
   from a silent-push fetch that applies an idle state to ending the activity,
   and fix anything that blocks it.
3. Silent push result: `ClockinAppDelegate.didReceiveRemoteNotification` should
   return `.newData` when the fetch applied changes, `.noData` otherwise, and
   `.failed` on a failed pass, so iOS budgets background wakes sensibly. Widgets
   must reload after an applied change (check `SessionMirror` already does).
4. "Clocked in on your Mac" local notification: when a running session that
   started on another device is applied while the iPhone app is not active,
   post one local notification ("Clocked in on your Mac" / Turkish "Mesai
   Mac'te başladı", body: "Open Clockin to show the timer on the Lock Screen and
   in the Dynamic Island." Turkish accordingly), no rate/earnings/note. One per
   timer (keyed by the running session start), none for the iPhone's own
   clock-ins or sync echoes, none if the app is active (then the Live Activity
   can start directly). Tapping opens the app (Today), which starts the Live
   Activity through the normal foreground path. Use the existing notification
   permission flow; never prompt from the background.
   Reuse/extend the store events added for the Mac tip in 19
   (`ClockStore` synced-running-apply event, today `#if os(macOS)`) rather than
   inventing a second detector; keep the Mac behavior identical.
5. Setting: iPhone Settings, near the Live Activity / notification settings,
   "Notify when the timer starts on another device", default on, device-local
   (not synced). English + Turkish strings in `Shared/Localizable.xcstrings`
   (usual serialization; the app says "puantaj", "Canlı Etkinlik", "Dinamik Ada").

Tests: focused checks for the detector on iOS (own clock-in, echo, other device,
already notified, app active), the background replacement decision (pure logic
extracted if needed), and the fetch-result mapping; run all README suites that do
not need xcodebuild. Write `docs/codex/20-iphone-follows-mac-result.md` with what
changed, how to test it on a real iPhone + Mac, and anything you would still do
differently.
