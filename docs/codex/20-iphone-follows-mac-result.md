# 20: The iPhone follows a Mac clock-in

Implemented 2026-10-01. App-only path; push-to-start design 18 remains deferred. No relay, CloudKit schema, entitlement or release changes.

## Changes

### Live Activity lifetime

`SessionMirror` now uses `LiveActivityDecision` to distinguish updates from replacements. Currency, frozen calculation inputs (including pause/resume), and remote-update consent can require new immutable ActivityKit attributes.

- In the background or inactive state, a replacement keeps the existing card until foreground refresh. It does not end the card or try to replace it. Ordinary updates that fit the existing attributes still update in place.
- In the foreground, request the replacement **first**. End the previous activities only after the request succeeds, retaining the newly created activity ID. An authorization/limit/request failure leaves the old card intact.
- An idle timer still immediately schedules `end(..., dismissalPolicy: .immediate)` in any application state. This path does not use the foreground replacement gate.
- Turning remote-update consent off still stops token observation and queues the existing relay registration for deletion while a retained card waits for foreground replacement.
- With no existing activity, the original request path remains available, including system-authorized `LiveActivityIntent` launches. A CloudKit silent wake does not gain push-to-start capability; its local request may fail. Opening the app retries normally.

The retained card deliberately keeps its old content when replacement is needed. Protocol 2 stores its calculation baseline in immutable `localState`; writing a new pause/rate/theme into content alone can be undone by a queued relay tick, which reconstructs the old baseline. **The card may therefore show the previous currency, calculation or pause state until Clockin becomes active.** This is the permitted keep-until-active option, not a claim that background calculation changes are now fully represented. Clock-out is still terminal.

`ClockinApp` now refreshes for the initial scene phase too, covering cold foreground launch and notification opening as well as later foreground transitions.

### Silent fetch, clock-out and widgets

The path is:

`ClockinAppDelegate` → `SyncCoordinator.handleRemoteNotification()` → real bridge apply → `ClockStore.applySynced()` → `refreshServices()` → `SessionMirror.refresh()` → idle branch → ActivityKit immediate end.

Before returning the background fetch result, `finishPendingUpdates()` also reconciles the current store synchronously. It awaits the activity operation before notification scheduling and relay cleanup. This avoids relying solely on the deferred `objectWillChange` subscriber and avoids waiting on unrelated notification work before ending the card.

The coordinator counts successful applies that actually change the persisted app snapshot. Each notification compares that revision before/after its awaited serialized worker:

| Result | Meaning |
| --- | --- |
| `.newData` | A successful pass applied changes. |
| `.noData` | No applied changes, identical fetched snapshot, disabled sync, or a first-merge/postponement gate without changes. |
| `.failed` | Network/account, storage, validation, send/quota/retry failure, or an incomplete pass. A failed pass takes precedence over partial applied data. |

Unrelated/mismatched CloudKit notifications retain the early `.noData` return. The delegate maps these outcomes to `UIBackgroundFetchResult` and logs only the outcome in the existing `sync` category.

`SessionMirror.syncSnapshot` already writes changed widget snapshots and calls `WidgetCenter.reloadAllTimelines()` (and iOS 18 control reloads). The apply and completion paths continue to reach it without a view being loaded. Unchanged widget snapshots avoid redundant reloads.

### One local notification per remote timer

The two post-persistence `ClockStore` events from 19 are now available on iOS as well as macOS: `didClockInLocally` and `didApplySyncedRunning(previous:current:)`. Their timing and the Mac tip implementation are unchanged.

`SharedStore.clock` attaches `RemoteClockInNotification` when the single shared store is created, before sync can apply incoming data. The detector only handles a synced non-nil session whose start differs from the previously visible start. Paused active sessions qualify too. Local clock-ins, same-session echoes/edits, archive loading and failed persistence do not generate an alert.

Device-local `UserDefaults.standard` keys, outside the sync preference allowlist:

- `Clockin.NotifyRemoteClockIn.v1`: absent means on.
- `Clockin.RemoteClockInHandledStarts.v1`: dates of local starts and already handled arrivals. Retains multiple starts across process restarts, so clearing the visible timer or starting another one cannot make an older local timer look remote.

An arrival is claimed before asynchronous permission lookup, preventing duplicate submissions. Active-app and opted-out arrivals are also consumed, so later sync echoes do not create delayed alerts. Before submission, the detector rechecks application activity, the setting, and that the same timer still exists. It reads existing authorization only; it never requests permission. Denied/not-requested permission results in no notification. Submission failure is not automatically retried for that timer; this is an at-most-once submission policy, not a delivery guarantee.

The request identifier is keyed by the session start. Its title/body contain no rate, earnings or note:

| Language | Title | Body |
| --- | --- | --- |
| English | Clocked in on your Mac | Open Clockin to show the timer on the Lock Screen and in the Dynamic Island. |
| Turkish | Mesai Mac'te başladı | Puantajı Kilit Ekranı’nda ve Dinamik Ada’da Canlı Etkinlik olarak görmek için Clockin’i açın. |

The existing notification delegate handles the default tap. A retained navigation request opens Today even if it arrives before the root view exists; a warm tap resets tab-owned navigation/sheets and dismisses root companion/summary/share presentations. The regular foreground mirror path starts the Live Activity. The existing foreground notification delegate suppresses presentation if delivery races with activation.

Settings → Privacy & Live Activity includes **Notify when the timer starts on another device** / **Puantaj başka bir cihazda başladığında bildir**. The existing `FocusChimeController` permission flow supplies **Allow notifications** / system-settings controls. Permission is requested only from a setting/button action. All three new catalog entries use the existing sorted, two-space JSON serialization.

`RunningSession` still has no origin device ID. As in 19, start time is the presentation heuristic: “Mac” is the requested copy for a non-local arrival, not independently verified sender hardware. No second polling/general-change detector was introduced.

## Verification

- **45/45 README check commands passed**, including all existing suites and the two new commands. Commands without an explicit Swift cache path received only `-module-cache-path /tmp/clockin-20-readme-cache` because the default cache is outside writable roots. Commands, exit codes and individual logs: `/tmp/clockin-20-readme-checks/`.
- `Tests/manual/iphonefollowsmac/run`: **18 detector checks and 8 Live Activity decision checks**. Uses the production detector, real `ClockStore`, temporary archives and isolated defaults; substitutes only permission, application state and notification submission. Covers own start/echo/late echo, other device, already notified/relaunch, active app, setting off, denied permission, foreground/clock-out races and failed archive writes. The background replacement assertion failed against the old extracted decision before the fix.
- `Tests/manual/iphonefollowsmac/run typecheck`: iOS 17 Simulator SDK, Swift 6 complete strict concurrency, warnings as errors. Compiles the detector tests and real UserNotifications adapter, then real `SharedStore`, `SessionMirror`, ActivityKit attributes/state, widget snapshot and `LiveActivityPush`. Unrelated celebration, wardrobe and audio/nudge services have type-check-only boundary doubles. This is not an ActivityKit runtime test.
- `Tests/manual/syncapp/run`: **82 checks**, including actual coordinator/fake-transport fetches that apply a running timer and then idle, mirror-refresh invocation without a scene, empty/no-op results, failure and review-gate mapping. The added result assertions first failed because the old handler returned `Void`.
- `Tests/manual/macliveactivitytip/run`: **27 checks passed unchanged**. Existing sync suites also pass their macOS and iOS strict concurrency checks.
- `xcstringstool compile` passed. Catalog verification confirms exactly three added entries, all retained entries unchanged, normal serialization, and device-local keys absent from the sync allowlist. Changed integration files parse; `git diff --check` passes.

The broader full-iOS-source typecheck was attempted but blocked by this environment's refusal to launch the SwiftUI macro compiler's nested sandbox (`sandbox-exec: sandbox_apply: Operation not permitted`). The focused iOS checks above avoid those unrelated macros. The Settings section and root navigation were syntax-checked, not fully compiled/rendered here. No `xcodebuild`, signed-device run, visible Lock Screen verification or production deployment was performed.

## Real iPhone + Mac test

Use a signed build on a physical iPhone and a Mac on the same iCloud account/environment, with the existing first merge completed. Record the two app builds, OS versions, notification authorization, Live Activity permission and remote earnings-update consent. Enable Clockin alerts using the existing foreground permission flow. Keep the new setting on initially. Watch the phone's `com.erdmncdr.clockin` / `sync` logs for push receipt and `push fetch result`; distinguish a missing wake from a fetch/apply problem.

1. **Mac start, phone locked:** leave Clockin in the background (not force-quit), start a session on Mac, and wait for a delivered silent fetch. Expect one generic local notification and an updated widget. No automatic new Live Activity is promised from the silent wake. Repeat sync, edit the note, pause/resume and reopen/relock: the same start must not notify again.
2. **Tap notification:** first with Clockin terminated normally, then with History/Progress or Today’s Settings sheet left open. Expect Today. With Live Activities allowed, the foreground path creates the timer card with current state. Repeat in English and Turkish; inspect the Lock Screen and Dynamic Island and confirm notification copy contains no private work details.
3. **Background replacement:** start a card on iPhone, lock it, and change currency, calculation inputs, pause/resume or remote-update consent while it is inactive. A delivered sync must not remove the card. If immutable attributes need replacement, old presentation can remain. Open Clockin: expect current attributes and a single surviving activity. Also test with remote earnings updates disabled, where mutable content can update directly.
4. **Replacement failure:** with an existing card, arrange a denied/failed request (e.g. debugger-controlled ActivityKit request failure or an activity limit) and trigger a foreground replacement. Confirm the old card is retained; retry on the next foreground refresh after the failure condition clears.
5. **Mac clock-out while phone remains locked:** end the timer on Mac. After a delivered/applying silent fetch, expect `newData`, the widget idle state, and immediate Live Activity removal without opening Clockin. Repeat while paused and after a deferred replacement. Replay an unchanged fetch: expect `noData`. Repeat a fetch with network/storage failure: expect `failed` and no fabricated idle state.
6. **Suppression:** start on iPhone (including a widget/Shortcut), then sync Mac edits back: no remote-start notification. Start on Mac while iPhone Clockin is active: no notification; the Live Activity uses the normal foreground path. Turn the new setting off, deny alerts, and leave permission not requested in separate runs: no alert and no background permission prompt. Enabling it on this phone must not change another device's preferences.
7. **Races/recovery:** start then immediately stop on Mac, activate the phone during fetch, repeat a timer after process restart, and toggle consent off with poor connectivity. Confirm no duplicate/obsolete alert before submission, stop remains terminal after an applied idle state, and existing relay deletion retries still work. Recheck the unchanged Mac tip and its dismissal.
8. **Delivery limits:** repeat with Low Power Mode, Background App Refresh disabled, Focus, force quit, offline/reconnect and reboot. Record whether the silent push actually ran. Foreground sync must recover the current timer; an app-only change cannot guarantee an alert or clock-out before iOS grants a wake. A local notification already delivered can remain in Notification Center after the session ends; tapping it still opens the current Today state.

## What I would still do differently

Before release, run the physical matrix above and build all app/widget targets in the normal Xcode environment. Automated pure decisions and SDK typechecks cannot prove ActivityKit presentation, OS push budgeting, tap routing or notification delivery.

For a later protocol revision, put mutable display inputs in a safe device-local cache with an explicit activity lifecycle identity, so pause/rate/currency updates can be shown without retaining obsolete immutable attributes. That needs compatibility and queued-push tests, not a small change to the current relay protocol. A true origin ID would also remove the start-time heuristic. Reliable automatic appearance while the app stays closed remains the separately deferred push-to-start design 18.
