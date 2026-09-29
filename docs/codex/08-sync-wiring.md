# Brief 08: harden the CloudKit send path, and build the app-side sync coordinator

Read `docs/sync-design.md`, `docs/codex/07-bounded-history-result.md`,
`Shared/Sync/Cloud/*`, `Shared/Core/ClockStore.swift`,
`Clockin/Views/Companion/WardrobeStore.swift`, `Shared/Sync/SessionMirror.swift`,
`Shared/Sync/SharedStore.swift`, `ClockinMac/MacAppServices.swift` and
`Clockin/ClockinApp.swift`. Apple's reference for CKSyncEngine is the sample
at https://github.com/apple/sample-cloudkit-sync-engine (you cannot fetch it;
the relevant behavior is summarized below).

## Part A — send path in `CloudKitAdapter.swift`

Review found these problems; fix them and add offline checks where the logic
can be isolated from CloudKit:

1. `nextRecordZoneChangeBatch` builds batches from the bridge's own pending
   list instead of the engine's. Build from
   `syncEngine.state.pendingRecordZoneChanges` filtered by
   `context.options.scope`, providing record bodies from the bridge
   (`RecordZoneChangeBatch(pendingChanges:recordProvider:)` or equivalent).
   A pending save whose record no longer exists in the bridge is removed from
   the engine's pending state.
2. After every `.sentRecordZoneChanges` event the adapter re-adds **all**
   bridge-pending records. A record that keeps failing with a non-transient
   error is then retried inside the same send loop indefinitely. Re-add only
   what a specific failure requires: the joined record after
   `serverRecordChanged`, the record after clearing system fields on
   `unknownItem`, zone + records after `zoneNotFound`. Treat
   `networkFailure`, `networkUnavailable`, `zoneBusy`, `serviceUnavailable`,
   `requestRateLimited`, `notAuthenticated` and `operationCancelled` as retried
   by the engine itself (do not re-add). Anything else: report, keep the
   record pending in the bridge, and do not re-add it until the next
   `synchronize()` pass; cap re-adds per record per pass (for example 3) so no
   path can loop.
3. A trigger that arrives while `synchronize()` is running is dropped today.
   Record it and run exactly one more pass after the current one finishes.
4. `retryAfter` blocks `synchronize()`, but nothing schedules the retry.
   Schedule one (a cancellable `Task.sleep` until `retryAfter`, coalesced).
5. `launch()` fails outright when `userRecordID()` fails because the device is
   offline or iCloud is temporarily unavailable. Distinguish "no account"
   (stay off, report) from transient failure (retry later with backoff), and
   make `launch()` safe to call again.

## Part B — `SyncCoordinator` (app side, feature-flagged off)

Create `Shared/Sync/SyncCoordinator.swift` (not compiled into the widget; I
will add the project exclusion) — a `@MainActor` object that owns the
bridge/adapter lifecycle for the app process and connects them to the stores:

- **Off by default.** `SyncCoordinator.isEnabled` is false unless a build
  setting / Info.plist key says the app has the iCloud entitlement (define the
  key, e.g. `ClockinCloudSyncEnabled`, default absent) **and** the user has
  sync turned on (a device-local preference, default on once the build
  supports it). When off, nothing touches CloudKit, the sidecar or the stores,
  and both apps behave exactly as today. Make this a checked property.
- **Snapshots.** Capture one full `SyncSnapshot` from `ClockStore.data`, the
  allowlisted preferences (`SyncPreferences`), and the wardrobe state and
  ledger together, on the main actor. Use the correct defaults suite per key
  (`Clockin.Language` lives in the App Group suite on iOS and in standard
  defaults on macOS — see `AppLanguage`).
- **Local changes.** After every successful `ClockStore` save, after
  allowlisted preference changes (observe `UserDefaults.didChangeNotification`
  and diff only allowlisted keys; debounce ~0.5 s) and after wardrobe/ledger
  persistence, call `bridge.localDidSave(snapshot)`, then persist and
  `synchronize()`. Add the smallest hooks needed: for example a
  `didPersist` publisher on `ClockStore` fired only after a successful write
  (not on load), and the same on `WardrobeStore`. Hooks are inert when the
  coordinator is off.
- **Applying remote state.** Implement the bridge's synchronous `apply`
  callback: validate the whole snapshot, then write `ClockStore` through a new
  `applySynced(_:) -> Bool` that uses the store's normal save/rollback path
  and does not fire `didPersist` (no echo), then allowlisted preferences
  (remove keys absent after a remote reset; never touch device-local keys),
  then ledger and wardrobe state through a `WardrobeStore.applySynced`, then
  refresh `SessionMirror`, chimes and celebrations. Throw before publishing
  partial state if the primary save fails. Keep `pinVisible` and other
  device-local fields from the receiving device.
- **Triggers.** Public methods the app entry points will call:
  `start()` (launch), `sceneDidBecomeActive()`, `handleRemoteNotification() async`,
  `accountMayHaveChanged()`. Do not edit `Clockin/ClockinApp.swift`,
  `ClockinAppDelegate.swift` or `ClockinMac/*`; list the exact calls I must add
  and where, including remote-notification registration on each platform.
- **Published state for UI** (I will build the SwiftUI): status
  (off / starting / syncing / up to date / waiting for network / paused with a
  reason / account problem), last successful sync date, the pending
  first-merge preview (counts: this device, other devices, duplicates,
  result) with `approveFirstMerge()` / `postponeFirstMerge()`, the recovery
  inbox entries with enough data to show them (kind, what was replaced, when,
  from which device if known) and `acknowledge(_:)`, and issues (quarantine,
  over-limit local values). All user-facing strings localizable with Turkish
  translations in `Shared/Localizable.xcstrings`.
- **Multiple processes.** Only the app process runs the coordinator; the
  widget never does. Intents run in the app process (`LiveActivityIntent` /
  `AppIntent`) and go through `SharedStore.clock`, so their saves reach the
  coordinator through the store hook. Confirm that by reading the intents.

## Tests

- Offline checks for Part A logic you can isolate (batch building from a
  pending list, re-add policy per error class, per-pass cap, rerun flag,
  retry scheduling) behind a small protocol so no CloudKit call is needed.
- `Tests/manual/syncapp/main.swift`: the coordinator against a fake transport
  and real `ClockStore` on a temp directory: disabled flag is a strict no-op;
  a store save produces exactly one `localDidSave` with the full snapshot;
  applying a remote snapshot writes the store, preferences and wardrobe and
  produces no echo; a preference change outside the allowlist is ignored;
  debounce coalesces bursts; a failing primary save during apply leaves
  preferences and wardrobe untouched and reports; `pinVisible` survives apply.
- Keep all existing checks passing (`sync`, `codec`, `typecheck`, `sessions`,
  `backups`, `import`, `maccompat`, `rates`, `feedback`, `celebrations`,
  `wardrobe`) and add the new commands to README.

## Rules

- Allowed: `Shared/Sync/Cloud/*`, new `Shared/Sync/SyncCoordinator.swift` (and
  small helpers next to it), minimal hooks in `Shared/Core/ClockStore.swift`
  and `Clockin/Views/Companion/WardrobeStore.swift`, `Shared/Localizable.xcstrings`,
  `Tests/manual/*`, `docs/sync-design.md`, README Checks.
- Not allowed: `Clockin.xcodeproj`, entitlements, app entry points,
  `ClockinMac/*`, any SwiftUI view.
- Swift 6 strict concurrency; warnings as errors in new checks.
- Do not commit.

## Result

Write `docs/codex/08-sync-wiring-result.md`: Part A changes and why; the
coordinator API; every hook added to the stores and proof they are inert when
off; the exact entry-point calls, entitlements and Info.plist keys I must add
per platform; test coverage; open questions.
