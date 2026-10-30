The same running timer now contributes one visible session after synchronization, even when two devices clock out at different times. The earliest end wins, and the later local entry remains recoverable. No commit was created; record types, names, zone, schema number, dependencies, website and relay are unchanged.

Changes by file:

| File | Change |
| --- | --- |
| `Shared/Sync/Cloud/SyncMerge.swift` | Groups live sessions by both import key and exact timer identity before choosing a representative. Uses the same grouping for projection, hidden-alias recovery classification and deletion fan-out. First-merge counts already derive from that projection and now include same-timer duplicates. |
| `Shared/Sync/Cloud/SyncModel.swift` | Routes the `Same timer` recovery reason to the existing localized duplicate-recovery notice. No wire-model changes. |
| `Tests/manual/sync/main.swift` | Adds regression coverage for different clock-out times, recovery payload/reason, hours/earnings, redelivery/order, preview arithmetic, UUID ties, imports, distinct fractional starts, deletion, resurrection, corrected starts and overlapping import/timer aliases. |
| `Tests/manual/syncapp/main.swift` | Allows distinct fixture device IDs and exchanges real coordinator-authored records between two real stores through fake transports. Exercises foreground clock-in fetch, the delayed phone clock-out, polling, persisted archives, recovery and push redelivery. |
| `docs/sync-design.md` | Documents the new equivalence and representative rule, manual-entry consequence, recovery and preview behavior. |
| This report | Records implementation, propagation limits, verification and device checks. |

The exact collapse rule is:

1. UUID identity still resolves within its existing Session register. Among live sessions, the existing import-key relation remains `Int(start epoch seconds)|Int(end epoch seconds)|Int(duration)`, independent of source, note or rate.
2. Two sessions whose current source is exactly `Clockin` additionally share a timer when their immutable `sessionFact.clockinStart` values are equal as exact `Date` values. A local session without a captured fact uses its `start`. A known fact is authoritative even if the displayed start was later edited; a known non-Clockin origin does not acquire a timer identity by editing its source.
3. Both relations join into groups, including an import alias of a hidden later clock-out. A group containing same-timer duplicates selects the earliest `end`, then the lowest UUID; an import-only group preserves the existing lowest-UUID selection. This also makes mixed-relation deletion deterministic.
4. Matching only a start never collapses imported sessions, or Clockin sessions with distinct timer identities. Exact import-key matches still collapse under the existing rule. Different subsecond starts are not rounded into one timer.
5. Hidden records remain intact in sync state. A previously visible, unchanged local alias hidden by the same-timer rule is captured with reason `Same timer`; an unseen remote alias does not create a local recovery notice. The first-merge recovery filter retains this reason. Deleting the visible entry tombstones all currently known members of its group, preserving their completion facts. As before, a previously unknown alias arriving after deletion may need another deletion.

`WorkSession` has no manual-versus-timer origin field: both `clockOut` and `addManualSession` write source `Clockin`. Collapsing manual entries with identical starts, including a manual entry sharing a timer start, is an accepted consequence without a schema change. Notes, rates and `matchedExternalSource` cannot reliably distinguish manual entries.

The local path needs no separate `ClockStore` change. `clockOut` appends to `data.sessions` and persists; the synchronous `didPersist` observer calls `localDidPersist`, which captures the record and current snapshot before scheduling network work. `materialize` includes uncaptured local sessions as well as the live winners of captured records, so the remote and local clock-outs meet in the same projection. `applySynced` atomically writes that projection before publishing it and does not emit a local-save echo. The `completed` set still includes every Session completion fact before visibility filtering, including hidden aliases and tombstones; either alias therefore clears a stale running timer even if its Running revision has a newer stamp.

Propagation was traced through `SyncCoordinator`, `CloudKitAdapter`, `ClockinAppDelegate`, `ClockinApp`, `SyncPlatform`, `ClockIntents`, `TodayWidget` and `SessionMirror`. These are code-derived expectations, not measured device latency:

| iPhone state | Trigger and realistic delay |
| --- | --- |
| Foreground | An active scene polls every 60 seconds. With successful Mac upload, network and an approved merge, a missed push means approximately 0–60 seconds until the next fetch starts, plus fetch/apply time. A delivered push can fetch sooner, commonly on a seconds scale under good conditions, with no latency guarantee. Returning to the foreground calls `sceneDidBecomeActive()` immediately, without waiting for the poll. |
| Background or suspended, push delivered | Foreground polling stops. A silent CloudKit notification can wake the app, whose delegate awaits `handleRemoteNotification()` and then mirror updates. After delivery, work starts immediately; delivery itself may take seconds, minutes, or never occur. The roughly 30-second background execution allowance is a work budget, not a delivery deadline. Without a wake, synchronization waits until another execution opportunity or foreground launch. |
| Killed by the system | A later eligible background notification may launch the app; launch starts the coordinator before SwiftUI views exist. Held notifications may be discarded, so there is no finite propagation bound. Opening the app initiates a fresh fetch. |
| Force-quit by the user | Do not expect silent background synchronization. Treat the delay as unbounded until the user relaunches the app; launch/activation then initiates fetch, subject to connectivity and merge approval. |

The Mac's timer save starts coordinator work immediately: the 0.5-second debounce is for preferences, not clock-in/out. The sidecar has a separate 250 ms scheduled persistence coalescer, and the worker persists before network operations. Each adapter pass fetches before sending; slow upload, an existing pass, connectivity, retry backoff, account trouble or a first-merge approval gate can extend all timings above. `pollIfNeeded` deliberately preserves a pending first-merge preview.

`CKSyncEngine.Configuration` uses the private database and `automaticallySync = false`, so the app's triggers explicitly drive fetch/send. There is no hand-written subscription creation in the adapter: the engine discovers an existing database subscription or creates an internal one, as described by Apple's [subscription documentation](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/configuration/subscriptionid). iOS registers for remote notifications in `ClockinAppDelegate` at enabled launch and via `SyncPlatform.registerForRemoteNotifications` when enabling sync in Settings; the entitlement and `remote-notification` background mode are present. The delegate filters for this container's private database notification and awaits the coordinator. Apple's [manual scheduling documentation](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/configuration/automaticallysync) and [background delivery limits](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app) explain why registration alone cannot guarantee timely delivery.

No propagation code change was warranted in this patch: foreground fetch and headless launch startup already exist, and the new real-coordinator regression verifies the foreground path. The Today widget reads the shared snapshot; its timeline refresh is not a CloudKit fetch. App-side widget/Live Activity intents use `SharedStore.clock` immediately and do not await a remote preflight, so they can observe stale state. Adding a safe preflight would need a bounded wait, cancellation/offline behavior and a fresh timer-identity check after the await before changing anything; simply awaiting an unbounded fetch could stall an action. More frequent polling would not run while suspended, and reliable background start cannot be promised by a small client-only change. Widget/Live Activity presentation must also be checked separately from the persisted timer.

Verification completed on 2026-10-30:

| Command | Result |
| --- | --- |
| `Tests/manual/sync/run` | All 296 checks passed, including five years / three replicas, byte-for-byte retained-register and projection convergence, and 1,797-day-old replay without changed winners or recoveries. |
| `Tests/manual/syncapp/run` | All 118 checks passed. The Mac first ends a real one-hour timer; the phone ends the same timer 40 seconds later before fetching. Both stores and both primary archives end with the Mac entry, one hour of earnings, no running timer and the hidden phone record retained. The phone recovery contains its full later payload with `Same timer`. |
| `Tests/manual/sync/run typecheck` | Passed for macOS arm64 / macOS 14 and iOS Simulator arm64 / iOS 17. |
| `Tests/manual/syncapp/run typecheck` | Passed for the same two targets. |
| `git diff --check` | Passed. |

Both harnesses compile with Swift 6, complete strict concurrency and warnings as errors. The SDK commands use `swiftc -typecheck`; no application build, signing or physical-device CloudKit test was performed. The syncapp harness substitutes transport and platform mirror effects, so its results prove store/coordinator behavior and archive persistence, not APNs delivery, WidgetKit scheduling or ActivityKit rendering.

Owner checks on two real devices, after building and installing both updated apps with the same iCloud account and CloudKit environment:

1. Approve any first-merge preview, then start on the Mac with the iPhone foregrounded. Record the observed delay; repeat without receiving a push to check the approximately 60-second polling fallback and with foreground re-entry to check immediate fetch.
2. Start one shared timer, disconnect the iPhone, clock out on the Mac, then clock out on the still-stale iPhone about 40 seconds later. Reconnect and confirm exactly one entry on both, the Mac end/duration/rate, unchanged total hours/earnings and a `Same timer` recovery containing the phone entry. Repeat with the phone's widget or long-session reminder as the later clock-out.
3. Delete the surviving session, sync both ways and reopen both apps. Confirm both aliases remain deleted and a stale paused/running update cannot restart that timer. Check a timecard row with the same start but different end/duration still remains separate.
4. Repeat Mac clock-in with the phone suspended/locked, then system-terminated if practical, and separately force-quit. Inspect sync status and push logs, then open the phone app to verify catch-up. A withheld push or force-quit must not be mistaken for a failed foreground timer apply.
5. Check the actual Today widget and Live Activity as separate surfaces, including a phone with no existing activity, and verify the first-merge preview arithmetic on a disposable duplicate fixture. Confirm the accepted identical-start manual-entry behavior before release.
