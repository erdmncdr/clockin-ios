# Brief 08: send hardening and app sync coordinator

Implemented the transport fixes and the app-process coordinator. Sync remains off: neither entry point calls it, the capability key is absent, and no project settings, entitlements, app delegates, Mac files or SwiftUI views were edited. No commit was created. The pre-existing untracked `08-sync-wiring.md` brief was left unchanged.

## Part A: send path

- `nextRecordZoneChangeBatch` reads **`syncEngine.state.pendingRecordZoneChanges`**, restricts records to the requested send scope and Clockin zone, then obtains current bodies/system fields from the bridge. The equivalent explicit batch initializer preserves the existing 100-record / 1.5-MB payload limits. A pending save with no available bridge body is removed from engine state. The schema sends tombstones, never hard deletes.
- A pass enqueues the durable bridge pending list once. `.sentRecordZoneChanges` no longer enqueues the entire list. `serverRecordChanged` validates/joins the returned record and re-adds only its still-pending joined result; `unknownItem` clears that record's system fields before re-adding; `zoneNotFound` resets transport metadata and queues the zone plus retained records.
- `networkFailure`, `networkUnavailable`, `zoneBusy`, `serviceUnavailable`, `requestRateLimited`, `notAuthenticated` and `operationCancelled` leave record retry ownership to CKSyncEngine. Other failures are reported, remain pending in the bridge, and are removed from engine pending state until another pass. Every recovery path is limited to **three re-adds per record per pass**; zone recreation has the same independent budget. At the cap, the record waits for a later pass.
- Rejected joins clear the server system fields they just learned. After a restart, a conditional create must encounter the server conflict again, rather than using the rejected record's change tag to overwrite it.
- An in-flight trigger sets a rerun flag. Bursts yield one follow-up pass, and callers await the shared send task. The next pass gets a fresh retry budget.
- `retryAfter` owns a cancellable, coalesced `Task.sleep` wakeup. Extending the deadline cancels the old sleep; stale/cancelled tasks cannot fire. Stopping/account changes cancel the wakeup.
- Launch checks `accountStatus` before user identity. No account/restriction reports an account problem and leaves the engine absent. Temporary status and transient identity errors retry with 5/10/20/40/80/160/300-second backoff, respecting a larger server delay. Repeated launches share the same task; successful launch resets backoff. Non-transient configuration errors report a pause. Account changes drain previous work, then recheck the original sidecar account ID before constructing a replacement engine. They cannot clear a primary-apply failure or migrate history into another account.

`SyncTransport.swift` contains Foundation-only send policy, pass budgeting, batch-source protocol, clock protocol and wakeup scheduler. The adapter's CKError/account-status mappings are checked separately against actual SDK enum cases. Apple's sample was not fetched; implementation follows the supplied behavior and the installed CloudKit Swift interface. No test opens CKContainer/CKSyncEngine or calls the CloudKit service.

## Coordinator API and ownership

`Shared/Sync/SyncCoordinator.swift` is `@MainActor`, `ObservableObject`, and additionally guarded by `!WIDGET_EXTENSION`. There must be one owner, `SyncCoordinator.shared`, per app process. `SyncAppState.swift` supplies defaults mapping, whole-snapshot validation and UI data types.

| API | Behavior |
|---|---|
| `isEnabled` | Checked on every entry/action/hook: Boolean Info.plist `ClockinCloudSyncEnabled == true` **and** device-local `Clockin.CloudSyncEnabled != false`. The local preference defaults on only in a supported build. |
| `start()` | Creates stores/sidecar/bridge/transport only after the gate; loads/reconciles current state and launches. Returns an optional task for callers that need completion; ordinarily ignore the return. |
| `sceneDidBecomeActive()` | Rechecks allowlisted preferences and schedules a sync, including edits whose defaults notification was missed during suspension. |
| `handleRemoteNotification() async` | Starts if necessary and awaits the coalesced worker. |
| `accountMayHaveChanged()` | Queues account revalidation through the transport. |
| `setSyncEnabled(_:)` | Writes the device-local choice. Off detaches hooks and drains old work; a fast enable waits for that drain before reopening the sidecar. |
| `approveFirstMerge() async` | Uses the displayed preview revision and the store's real archive path for the existing byte-for-byte backup/approval gate. Pending preference changes invalidate the old preview instead of silently approving it. |
| `postponeFirstMerge()` | Keeps staged records/preview and local stores unchanged; exposes a postponed status. |
| `acknowledge(_ id: String)` | Removes a recovery or acknowledges an overflow notice, then persists. |

Published properties: `status`, `lastSuccessfulSync`, `pendingFirstMerge`, `recoveryInbox`, `issues`.

- Status cases are off, starting, syncing, up to date, waiting for network, paused with a typed/localized reason, and account problem. `lastSuccessfulSync` is the latest successful transport pass in this process lifetime.
- The preview retains `localCount`, `remoteCount`, `duplicates`, `mergedCount` and the exact revision approved. The existing bridge computes duplicate/import-alias counts.
- Recovery rows expose kind/title, localized reason, typed replaced payload (session, rate rule, profile, running state, named preference, purchase or wardrobe), record key, original author installation ID, original modification date, and optional local recovery-capture date. `SyncRecovery.recoveredAt` is backward-compatible optional sidecar metadata; older entries have no invented capture time. Author IDs are not device display names.
- Issues expose localized local-value limits, quarantined keys/original bytes and overflow notices. Raw quarantine reasons are diagnostics for review/export, not localized UI copy.
- All status/reason/recovery/issue/kind strings used here have Turkish entries in `Shared/Localizable.xcstrings`, including existing core recovery/limit strings that lacked catalog entries.

The injected factory/clock/refresh boundaries support offline checks. Production defaults resolve `SharedStore.clock`, `WardrobeStore.shared`, `AppLanguage.shared`, the real adapter and SessionMirror only after enabling. The worker serializes disk/transport work; each local capture happens synchronously before that asynchronous work.

## Store hooks and apply order

`ClockStore` changes:

1. `didPersist: PassthroughSubject<Void, Never>` sends on the main actor after the normal atomic archive write succeeds. It does not send on load/migration, write failure or remote apply.
2. Read-only `archiveURL` supplies the actual primary URL for the sidecar and first-merge backup.
3. `applySynced(_ data: ClockinData) -> Bool` retains this device's `pinVisible`, uses the same backup/atomic-write/error path, and publishes replacement `data` only after writing succeeds. Failure leaves previous visible data intact. Success clears an obsolete timer-persistence error; no `didPersist` is emitted.

`WardrobeStore` changes:

1. `didPersist` fires once after ledger and state persistence when their **values** changed, not just JSON dictionary key order. Refresh also reports adoption of persisted state from backup restore, which writes defaults outside the store. Construction does not emit a hook.
2. `prepareSynced(_:ledger:)` encodes both values before the primary write and preserves local `seeded` bookkeeping.
3. `applySynced(_ prepared:)` writes ledger first, then wardrobe, updates in-memory state and invalidates the derived earnings cache. No local persistence hook fires.

The coordinator snapshots `ClockStore.data`, the entire allowlisted preference map and wardrobe **with ledger** in one main-actor turn. Standard defaults own all allowlisted keys except `Clockin.Language`: `AppLanguage.shared` is the iOS App Group suite and macOS standard defaults. Remote reset removes absent allowlisted keys and never edits local keys, including `AppleLanguages`, sync opt-in, celebration bookkeeping or UI scale.

Remote apply is synchronous: validate all domains (including duplicate identities and every purchase row); pre-encode wardrobe/ledger; save ClockStore; write preferences; apply wardrobe/ledger; call `SessionMirror.shared.refresh()` and `refreshChimes(force: true)`. `refresh()` already calls `CelebrationCenter.shared.refresh(store:)`, recalculates wardrobe earnings/unlocks and refreshes widgets/Live Activities. The coordinator suppresses derived-service hooks during the callback and absorbs delayed defaults notifications with its post-apply baseline. Existing invalid local-only values are allowed only if unchanged; remote values cannot inherit that exemption.

Preferences are observed through `UserDefaults.didChangeNotification`, transferred onto the main actor, diffed only against the allowlist and debounced for 0.5 seconds. A store save absorbs an outstanding preference burst into the same full snapshot. Before an incoming merge, `bridge.willReceive` captures an outstanding burst so displaced local preferences can enter recovery. `bridge.didChange` updates UI projections; `localSaveCount` is a non-persisted diagnostic counter used to verify exact local capture counts.

Off-mode proof: both capability-disabled and user-disabled tests exercise launch, foreground, push, account, approval, postpone and acknowledgment. Every resource factory remains at zero, the sidecar does not exist, primary bytes and defaults are unchanged, and refresh callbacks remain at zero. A live disable detaches the hooks; later store changes do not reach the old bridge. Publishers by themselves do not start sync or write any sidecar.

## Calls to add later: iOS

These are instructions only; none were applied. Add `import CloudKit` to the delegate receiving CloudKit notifications.

1. In `Clockin/ClockinAppDelegate.swift`, inside `application(_:willFinishLaunchingWithOptions:)`, after the existing chime-controller initialization, start at **process launch**, including headless intent launches:

   ```swift
   let sync = SyncCoordinator.shared
   sync.start()
   if sync.isEnabled {
       application.registerForRemoteNotifications()
   }
   ```

2. Keep an account observer token as a delegate property, install it once in the same launch callback, and remove it when the delegate is torn down if its lifetime is shortened. The notification can originate off-main:

   ```swift
   cloudAccountObserver = NotificationCenter.default.addObserver(
       forName: .CKAccountChanged, object: nil, queue: nil
   ) { _ in
       Task { @MainActor in SyncCoordinator.shared.accountMayHaveChanged() }
   }
   ```

   The token type is `NSObjectProtocol?`. The coordinator gate makes an account callback inert while disabled. On enabling sync later in Settings, call `setSyncEnabled(true)` **and** `UIApplication.shared.registerForRemoteNotifications()` once that process is enabled.

3. In `Clockin/ClockinApp.swift`, the existing `.onChange(of: scenePhase)` closure should call `SyncCoordinator.shared.sceneDidBecomeActive()` when `phase == .active`. Keep the current mirror refresh calls.

4. Implement the async `UIApplicationDelegate.application(_:didReceiveRemoteNotification:) -> UIBackgroundFetchResult`. Parse with `CKNotification(fromRemoteNotificationDictionary:)`, accept only a `CKDatabaseNotification` whose container is `iCloud.com.erdmncdr.clockin` and scope is `.private`, guard `SyncCoordinator.shared.isEnabled`, then:

   ```swift
   @MainActor
   func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
       let sync = SyncCoordinator.shared
       guard sync.isEnabled,
             let notice = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification,
             notice.containerIdentifier == ClockinCloudRecord.containerID,
             notice.databaseScope == .private else { return .noData }
       await sync.handleRemoteNotification()
       await SessionMirror.shared.finishPendingUpdates()
       // Conservative result until the entry point tracks newly applied record counts.
       return .noData
   }
   ```

   Retain routing for unrelated/Live Activity pushes and report `.failed` when your handler's outcome tracking requires it. The coordinator currently exposes completion/status, not a “number of newly applied records” return value: if that distinction is needed for `.newData` vs `.noData`, add it in the entry-point integration. Test the platform background deadline on signed hardware; cancellation/expiry policy is an integration item below. This private database flow does not need a custom push server or notification-alert permission prompt.

## Calls to add later: macOS

1. In `ClockinMac/ClockinMacApp.swift`, `ClockinMacAppDelegate.applicationDidFinishLaunching`, after `let store = SharedStore.clock`, call `SyncCoordinator.shared.start()`. When enabled, call `NSApplication.shared.registerForRemoteNotifications()` (no alert types).
2. Install the same `.CKAccountChanged` observer once in that delegate, keeping its token. Remove it in `applicationWillTerminate`. A later Settings opt-in uses `setSyncEnabled(true)` plus APNs registration.
3. Add `applicationDidBecomeActive(_:)` to that delegate and call `SyncCoordinator.shared.sceneDidBecomeActive()`. Alternatively hook the already observed `NSApplication.didBecomeActiveNotification` in `MacAppServices`; use one foreground route. An `NSWorkspace.didWakeNotification` trigger can call the same method alongside the existing wake refresh.
4. Implement the Mac delegate callback, retaining routing for unrelated notifications:

   ```swift
   @MainActor
   func application(_ application: NSApplication,
                    didReceiveRemoteNotification userInfo: [String: Any]) {
       guard SyncCoordinator.shared.isEnabled,
             let notice = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification,
             notice.containerIdentifier == ClockinCloudRecord.containerID,
             notice.databaseScope == .private else { return }
       Task { @MainActor in
           await SyncCoordinator.shared.handleRemoteNotification()
           await SessionMirror.shared.finishPendingUpdates()
       }
   }
   ```
5. Keep both platforms' APNs registration success/failure delegate callbacks available for diagnostics. CKSyncEngine manages its database subscription; do not upload the ordinary APNs token to the Live Activity service or invent a separate CloudKit push backend.

## Capabilities, Info.plist and target membership to add later

Both app targets need the same team-accessible container, `iCloud.com.erdmncdr.clockin`, private database/custom zone `Clockin`. Current bundle identifiers in the design are iOS `com.erdmncdr.clockin` and Mac `com.ismailakdag.clockin`; confirm the legacy Mac ID can be provisioned for the shared container.

| Setting | iOS app | macOS app |
|---|---|---|
| Capability assertion | Boolean `ClockinCloudSyncEnabled = YES` in `Config/Clockin-Info.plist`, only for an entitled build | Same Boolean in `Config/ClockinMac-Info.plist` |
| Generated-plist option | A build setting may supply `INFOPLIST_KEY_ClockinCloudSyncEnabled`; verify the built plist contains a **Boolean**, not a string | Same |
| iCloud container entitlement | `com.apple.developer.icloud-container-identifiers = [iCloud.com.erdmncdr.clockin]` | Same |
| iCloud service entitlement | `com.apple.developer.icloud-services = [CloudKit]` | Same |
| Environment | `com.apple.developer.icloud-container-environment` must match the profile/build, Development for development testing and Production for distribution | Same; verify the Developer ID profile/environment |
| Push | `aps-environment` from the matching provisioning profile (the current iOS file already has development APNs) | `com.apple.developer.aps-environment` from the matching provisioning profile |
| Background delivery | Add/retain `UIBackgroundModes` array entry `remote-notification` | APNs registration; no iOS `UIBackgroundModes` key |
| Local shared data | Keep the existing `com.apple.security.application-groups` entry `group.com.erdmncdr.clockin` | Language stays in standard defaults; no new App Group requirement for this change |
| Network sandbox | Existing iOS app networking | If sandboxed, `com.apple.security.network.client = true` |

Regenerate provisioning profiles after enabling CloudKit/Push. Direct-distribution Mac builds need the appropriate Developer ID provisioning profile as well as signing/notarization. Verify the signed entitlements and built plist; the Boolean is an explicit build assertion, not a runtime entitlement probe. Deploy the existing seven-type schema to Production only after development-device validation; development records do not move to production with the schema.

Add the new coordinator/helper sources to **both apps**, and exclude `SyncCoordinator.swift` and `SyncAppState.swift` from the widget target (their `!WIDGET_EXTENSION` guard is additional protection). Include `Shared/Sync/Cloud/SyncTransport.swift` with the Cloud sources. Do not construct a coordinator or grant new CloudKit privileges to the widget.

## Intent confirmation

Read `Shared/Intents/ClockIntents.swift` and `SetClockedInIntent.swift`. Clock-in, clock-out and pause/resume use `SharedStore.clock`; iOS uses `LiveActivityIntent`, Mac uses `AppIntent`. The control's `SetClockedInIntent` is also a `LiveActivityIntent` and delegates to clock-in/out. Each `#if WIDGET_EXTENSION` branch returns without accessing the store. Thus app-process saves reach `ClockStore.didPersist` once the delegate has started the coordinator; no view hook or second ClockStore is needed. Headless and actual device process routing still need a signed integration run.

## Verification

New commands are in README Checks. All new check compilation uses Swift 6, complete strict concurrency and warnings as errors.

- `Tests/manual/sync/run send`: offline engine-pending/scope/missing-body batch selection, count/byte ceilings, all failure classes, independent record caps and deferred work, 100 coalesced in-flight triggers, one rerun, cancellation, launch backoff and server delay, coalesced deadline wakeup, replacement and cancellation of sleeps. Uses a manual clock/continuations, without wall-clock sleeps.
- `Tests/manual/sync/run codec`: original 17 CloudKit codec checks plus actual CKError/account-status mappings, with no account/network access.
- `Tests/manual/syncapp/run`: real temporary ClockStore, real WardrobeStore and sidecar/bridge with fake transport and isolated defaults. Covers both off gates, exact full captures, load/write-failure silence, allowlist/suite mapping, debounce, remote reset/apply/no echo, primary-failure no partial publication, local pin/seeding preservation, derived-refresh invocation, recovery/acknowledgment/issues, debounce-vs-fetch recovery, backup-restoration adoption, fast disable/re-enable, first preview/postpone/backup/approval, and stale approval from pending preferences.
- `Tests/manual/syncapp/run typecheck`: coordinator/stores/adapter against macOS arm64 14.0 and iOS Simulator arm64 17.0 SDKs. Platform effect endpoints (`SharedStore`, `SessionMirror`) are stand-ins for this standalone check; this is not a whole-app Xcode build.
- `Tests/manual/sync/run typecheck`: real CloudKit adapter against both SDKs.
- Existing `sync` (including the full five-year simulation), `sessions`, `backups`, `import`, `maccompat`, `rates`, `feedback`, `celebrations` and `wardrobe` checks were also run. Final results:

| Check | Result |
|---|---|
| sync (full five-year run) | 263 passed |
| send | 37 passed |
| codec / SDK error and account mappings | 33 passed |
| syncapp | 50 passed |
| adapter and syncapp SDK typechecks | macOS arm64 14.0 and iOS Simulator arm64 17.0 passed |
| sessions / backups / import | 20 / 38 / 26 passed |
| maccompat / rates / feedback | 375 / 84 / 22 passed |
| celebrations / wardrobe | 125 / 2,898 passed |
| Turkish sync string coverage | All 30 referenced keys have Turkish translations |
| Widget compile guard | Both new app-side files typecheck with only `-D WIDGET_EXTENSION`, no app dependencies |
| `git diff --check` | Passed |

The extra core check over Brief 07 is the new device-local sync preference exclusion; original checks were not removed. Final long-run sidecar maxima were 1,081,629 / 1,083,842 / 1,088,147 bytes for the three replicas, below the 100,595,340-byte bound at their maxima. Register bounds and convergence remain unchanged.

## Open integration questions and limits

- **Pending scope approval: real chime refresh mutates synchronized preferences.** Reading the real `SessionMirror.syncChimes` found `FocusChimeSound.migrate(in: defaults)`. The migrator writes its fallback to defaults when the key is absent or unsupported. A standalone Swift 6 / warnings-as-errors reproduction confirmed both effects: it recreates a remotely reset key and overwrites an unsupported remote sound. That can generate a preference echo after the coordinator's callback. The proposed exact change is:

  ```diff
  - sound: FocusChimeSound.migrate(in: defaults).rawValue,
  + sound: FocusChimeSound.selected(defaults.string(forKey: FocusChimeSound.preferenceKey)).rawValue,
  ```

  The pure-read alternative was checked to retain both the absent key and an unsupported stored choice while still selecting the playback fallback. `Shared/Sync/SessionMirror.swift` is outside the brief's allowed edit list, so it was **not changed**. A one-line scope exception was requested; no approval had arrived when this report was written. The coordinator's no-echo checks use an injected refresh endpoint; they do **not** prove no echo from this existing production migrator. Resolve this item before enabling sync. This is a concrete remaining wiring issue, not a signed-device verification claim.

- No signed app/device, real account, CKSyncEngine service operation, push wakeup or distribution entitlement was tested. Entry points, target membership, provisioning, first-merge/recovery UI and account-migration UX remain deliberately unwired.
- The remote-notification API awaits the coalesced work, including an already-running pass. It does not impose an APNs background deadline or return a fetched-record count. The entry-point integration must choose its expiration/cancellation policy and verify iOS background execution time, including engine-managed retries, on signed devices. Foreground/post-save triggers and durable pending state remain the correctness path.
- UserDefaults has no synchronous durable-write error result. Validation/encoding happens before the primary write, and primary-write failure is atomic from the coordinator's perspective; process death between independent archive/defaults writes is not a crash-atomic multi-store transaction. A transaction journal would be a separate persistence design if stronger crash guarantees are required.
- `lastSuccessfulSync` is process-local. Recovery dates are local capture dates and author IDs are installation IDs; human-readable device names and historical capture dates are unavailable.
- An apply/validation halt requires app relaunch after the underlying storage/data problem is resolved. Switching accounts cannot clear it or approve account migration. Quarantine replay/removal and account migration are still explicit recovery work, not automatic overwrite paths.
