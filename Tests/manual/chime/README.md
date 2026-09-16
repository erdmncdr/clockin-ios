# Focus chime runtime regression

The Swift checks beside this file cover date arithmetic. They do not cover
notification delivery, SwiftUI task captures, or cancellation in iOS. Run these
steps on a disposable simulator with notification permission enabled.

1. Clock in; enable Focus chime with a one-minute interval.
2. Tap Preview once. Expect one `Focus chime preview` notification.
3. Stay in the foreground for at least two minutes. Expect one regular
   notification per worked minute, with no interval reset at the app's
   one-minute refresh.
4. Pause. Wait at least 75 seconds. Expect no new scheduled or delivered chime.
5. Resume. Background and foreground the app while chime is enabled.
6. Turn chime off without ending the session. Wait at least 75 seconds in the
   foreground. It must remain off and must not recreate its pending requests.
7. Re-enable chime, then clock out. Wait at least 75 seconds. Expect no new chime.
8. Relaunch. The completed session, selected rate, currency, and chime preference
   must persist; an idle app must not schedule work reminders.

The regression fixed on 2026-09-16 was a long-lived `RootView.task` retaining old
`@AppStorage` values. Repeating `updateChimes` on that old view could overwrite a
new interval or enable notifications after the user turned them off. All
refreshes now read current preferences through `SessionMirror.refreshChimes`.

For evidence, collect the test simulator's unified logs with `simctl spawn
<test-device-uuid> log show`. Observe both the app's `com.apple.UserNotifications`
adding/removing requests and SpringBoard's `Posting banner` messages containing
`Clockin.FocusChime`. Pin start and end timestamps; absence of banners alone
does not prove the queue was cancelled. Do not run against personal session data.
