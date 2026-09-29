# Clockin sync core, schema 1

This is an inert implementation for review. Nothing creates it from either app. `ClockStore`, `SessionMirror`, `WardrobeStore`, app entry points, project settings and entitlements are unchanged. Only the adapter imports CloudKit; the model, diff, merge, bridge and disk actor import Foundation. Shared data and wire types are `Sendable` values, built in Swift 6 language mode with complete concurrency checking.

## Schema and identity

Use `iCloud.com.erdmncdr.clockin`, the current user's **private** database and custom zone `Clockin`. Never use the public database. Each record has these CloudKit fields:

| Field | CloudKit type | Meaning |
|---|---|---|
| `schema` | Int64 | Currently 1; unknown schemas are quarantined |
| `payload` | Bytes | Canonical JSON `SyncRecord`, including retained revisions |
| `modifiedAt` | Date/Time | Winning revision's timestamp, checked against payload |
| `modifiedBy` | String | Winning revision's installation ID, checked against payload |

JSON dates use Foundation's default seconds since 2001. Binary fields use Codable base64. Keys and revision arrays are sorted for deterministic encoding; wardrobe ownership uses a sorted array on the wire. The legacy archive encoder is untouched.

| Record type | CloudKit record name | Payload within each revision |
|---|---|---|
| `Session` | Session UUID string | Existing `WorkSession` |
| `RateRule` | `RateRule:<UUID>` | Existing `RateRule` |
| `Profile` | `Profile:Profile` | Hourly rate and currency code |
| `Running` | `Running:Running` | Required `session` field, either a `RunningSession` or explicit `null` |
| `Preference` | `Preference:<key>` | Typed bool, integer, double, string or string array |
| `WardrobePurchase` | `WardrobePurchase:<identity>` | Existing item ID, cost, date |
| `WardrobeState` | `WardrobeState:WardrobeState` | Owned IDs, equipped slots, colorway, room, furniture, home layout, lamp and arrangement |

Namespacing everything except sessions avoids collisions between independent UUID domains. Record types and names are schema contracts; change them only through a migration.

A revision has `stamp { modifiedAt, modifiedBy, sequence }`, `deleted`, `payload` and `parents`. `modifiedBy` is a UUID generated once in the local sidecar. Revision identity is `<modifiedBy>:<sequence>` **within a record**. One local snapshot edit can update several records with the same sequence. Causal parents identify superseded revisions. An installation must never reuse a sequence or copy its sidecar identity to another installation.

## Merge rules and departures from the brief

The register stores a **union of immutable revisions**, then projects the winning value. This additional history is necessary: a plain LWW register loses a displaced running timer before another device can recover it, and a deleted or edited completed session can otherwise erase the evidence that a timer ended. Retaining the versions in both the sidecar and CloudKit envelope makes those facts survive arrival order, restarts and a third replica. Join is associative, commutative and idempotent for valid revisions. Reusing an existing revision identity with different contents is quarantined.

- Sessions, rules, profile, preferences and wardrobe selections use `(modifiedAt, modifiedBy, sequence)` order. Exact timestamp ties use lexical installation ID, then the local counter. No timestamp is manufactured on receive.
- Local edit timestamps start with the supplied device time and advance to the next representable instant beyond observed history if necessary. This small logical floor handles clock rollback and lets a deliberate resume supersede an observed remote pause. Offline clock skew still affects the winner; this is not server-time ordering.
- Session/rule deletion is a saved tombstone. **It wins permanently for that UUID**, including against a later stale offline edit. This deliberately strengthens concurrent delete-wins without requiring a per-device vector clock or guessing concurrency from wall time. Restore a deleted entry under a fresh UUID. Tombstones and prior values are never garbage-collected.
- Preferences may be reset through an LWW tombstone and subsequently set again. `Clockin.SeenAccessoryIDs` additionally unions IDs because it represents earned ownership. Unsupported platform-specific choice strings are retained verbatim; applying them is the future platform adapter's responsibility.
- Wardrobe selection/layout is one LWW register; ownership unions every revision and the purchase ledger. The `seeded` migration flag stays on the device. The forgiving app decoder is not used for remote wardrobe validation: a strict DTO prevents malformed layouts from silently resetting a room.
- Purchases identify **permanent, non-consumable item ownership**, using unpadded base64url of UTF-8 `itemID`. Two devices buying the same item are one charge, even with different purchase dates. The earliest purchase date wins, then the lower cost for an exact date tie. Both versions remain recoverable. Different items union. Ledger removal does not upload a deletion. Coins never appear in a record; continue deriving them from work/goals and the merged ledger. Offline purchases of different items can overspend the eventual balance; the current balance clamps at zero, and no item is confiscated.
- Running is LWW including explicit idle. Every retained completed `Clockin`-source session permanently closes its `start`, even after deletion or correction. A selected running value with that start projects as idle. Imported-source sessions do not close runs. Distinct losing unfinished starts are returned as recoverable revisions with stable notice IDs. Pausing/resuming the same start does not create a second timer. Restoring a displaced timer is a future explicit UI operation; use a fresh start identity if the old start has completed.
- Every losing/previous revision is returned through `recoveries`. Concurrent non-running edits produce one notice per record; displaced timers produce one per start, and duplicate collapses produce one per import key. Notice IDs are acknowledged locally **after presentation**, not at receipt, so failed presentation can retry and relaunch does not repeat an acknowledged notice.

There is no timestamp bump for a conflict re-send. The re-send contains the joined history with original stamps. Pure diff compares the previous/current app snapshots, so applying a remote snapshot then saving that same snapshot emits nothing.

## Preference policy

`SyncPreferences.types` is the explicit typed allowlist matching section C of `mac-port-inventory.md`; the check parses that inventory to verify coverage. Unknown keys default to device-local. Wardrobe JSON and ledger keys use their dedicated records, not `Preference` records.

The brief overrides two older inventory classifications: `Clockin.RemoteActivityConsent.v2` and JSON `pinVisible` stay local. Live Activity tokens/registries/deletion queues, setup flags, goal prompt bookkeeping, celebration/badge presentation, notifications, language-derived `AppleLanguages`, UI scale, window frames/sizes and exchange-rate caches never upload. User-selected goals, appearance, sounds, haptics, workweek, companion, layouts and Mac-only display choices do upload. `Clockin.Language` must be read/applied through the correct per-platform suite later.

## First synchronization

The adapter fetches before sending, with automatic engine scheduling disabled. Until first merge is approved, remote records accumulate in durable `staged` state and do not invoke the application's apply callback. An empty cloud (or only this installation's previously uploaded records) permits initial publication without marking a future merge as approved. When the first foreign revision arrives, uploads pause and `needsFirstMergeReview` becomes true. This gives the first device a preview and fresh backup too, even if the other device connects much later. A completed fetch is required to request `firstPreview()`; a network failure does not count as an empty server.

The preview reports raw local and valid foreign remote session counts (excluding unchanged echoes authored solely by this installation), duplicate count and final visible count:

`localCount + remoteCount - duplicates = mergedCount`

Shared UUIDs count once. Different UUIDs with the exact **ClockStore import key** also collapse: `Int(start epoch seconds)|Int(end epoch seconds)|Int(duration)`. This deliberately includes the importer's integer truncation and ignores note/rate/source. The lowest UUID is the deterministic visible representative. Every other version, including different notes, stays recoverable. Projection continues this collapse after first sync so later deliveries of existing duplicates cannot inflate totals. Deleting a visible duplicate tombstones all aliases currently known to that device; a previously unseen alias may still require another explicit deletion after arrival.

After the user approves a particular preview, `approveFirstMerge` copies the **exact existing archive bytes** to a uniquely named `clockin-before-sync-<UUID>.json` beside it, reads the copy back, and rechecks the preview revision. Missing/unreadable archives or failed backups abort the merge. Changes during the backup invalidate approval and require a refreshed preview. Each installation follows this gate before applying foreign data. A new installation needs its normal initial archive save before approval. Merely uploading to an empty cloud does not change the local archive and does not consume this gate.

Only then does the synchronous main-actor callback apply the projected data. The bridge records first-merge completion, retains the backup path and schedules uploads that the fetched server lacks. Canceling/dismissing the preview leaves local state intact and keeps staged data for later review.

## Sidecar and recovery

`sync-state.json` lives beside `clockin.json`. It contains:

- Schema, installation ID, edit sequence and persistence revision.
- Full per-record revision registers, including permanent tombstones and completed-run evidence.
- Pending record keys; the current record body is resolved at send time.
- CloudKit secure-archived system fields per record and JSON-encoded engine state serialization as `Data`.
- Bound iCloud user record ID, initial-publication permission, first-merge status, staged records and first-backup path.
- Quarantined envelopes/reasons and acknowledged notice IDs.

The sidecar's installation ID, queues, account binding, engine cursors, system fields and notice acknowledgments are never sent as user data. Only the record envelopes are sent. Byte-identical convergence refers to the canonical synchronized projection **and record registers**, excluding those installation-specific fields, `pinVisible`, and the wardrobe seeding flag.

`SyncSidecarStore` is a separate actor and uses atomic replacement. It never writes the primary archive. Older asynchronous saves cannot replace a newer persisted revision. Sidecar failure retains memory state and reports an error; it does not undo or prevent a primary archive save. The adapter will not build an upload batch until the current sidecar revision is durable. On launch, compare the archive against the known record projection to recover primary saves that preceded a sidecar failure. A missing sidecar creates a new identity and first-merge flow; a corrupt/unknown-version sidecar throws and must be retained for explicit recovery rather than replaced with an empty sidecar.

Quarantine is per record. Work sessions reuse `hasValidDuration`, and running values reuse `hasValidDuration(at:)` at the revision timestamp for deterministic validation. Rules/profiles additionally require finite nonnegative rates, valid dates/intervals and a three-letter uppercase currency. Preference keys/types and CloudKit envelope ID/type/stamp are checked. Malformed `Running` payloads cannot masquerade as idle. Invalid records do not clear unrelated local values, even before seeding. Raw CloudKit payload bytes are retained and the server record is not deleted or overwritten. Ordinary physical CloudKit deletions are treated as unexpected and retained for review, not converted into unversioned local deletions.

Recovery is an API and durable data in this brief, not a UI. Use `bridge.review().recoveries` and `bridge.state.notices(review)` to build the recovery/notice surfaces. A valid losing payload can be decoded by its record kind. The old archive and old Mac reader require no changes.

## Inert integration surface

All bridge calls and app state mutation belong on the main actor. No changes to the stores are necessary until the later wiring task.

| Application event | Future call |
|---|---|
| Launch | Capture current `SyncSnapshot`; `await disk.load()` or create `SyncSidecar`; construct `SyncBridge(..., apply:)` and `ClockinCloudAdapter`; `try await adapter.launch()` |
| Successful primary archive save | `try bridge.localDidSave(fullCurrentSnapshot)`; then asynchronously `await bridge.persist()` and `await adapter.synchronize()` |
| Successful preference write/reset | Same `localDidSave`, with the full allowed preference map; preserve unsupported remote choices in that map |
| Wardrobe/equipment/room/ledger persistence | Same `localDidSave`, with state **and ledger captured together** |
| Foreground / retry / remote notification | `await adapter.synchronize()`; honor the platform background completion deadline |
| First fetch complete with `state.needsFirstMergeReview` | Present `try bridge.firstPreview()` counts; on approval call `try await bridge.approveFirstMerge(preview, archiveURL:)`, then `await adapter.synchronize()` |
| Displayed conflict notice | `bridge.acknowledgeNotices(ids)`, then persist |

The `apply: @MainActor @Sendable (SyncSnapshot) throws -> Void` callback is the only path back to app storage. Later wiring must validate/stage the full update, save `ClockStore` using its normal failure handling, apply only allowlisted preferences (removing keys absent after a reset), persist ledger then wardrobe, refresh derived earnings/coins, and call `SessionMirror.shared.refresh()` plus `refreshChimes(force: true)` when settings require it. Keep device state from the receiving snapshot. The callback must be synchronous, must not start asynchronous app mutations, and must report primary-save failure before publishing partial state. The bridge suppresses reentrant `localDidSave` calls during this callback and updates its baseline only after success.

Create the initial archive before enabling first merge. Serialize local storage writes and snapshot capture on the main actor; capture **all** stores in a single snapshot so missing preferences are not interpreted as resets. Use the same persistence path for Shortcuts/widget actions in the later wiring; observing only views misses those actions. Extension/app coordination for multiple processes sharing the archive is a separate integration responsibility: one process must own this sidecar writer.

The bridge does not roll back unrelated app work if sidecar persistence fails. If primary storage and several UserDefaults writes can fail independently, the later app wiring needs its own recoverable apply transaction. This brief has no device effects and makes no claim that a widget or Live Activity actually updated.

## Transport behavior and failures

The adapter restores `CKSyncEngine.State.Serialization`, stores state-update events, supplies save-only batches of up to 100 records / 1.5 MB payload, retains system fields, and acknowledges only the exact sent version. An acknowledgment for an older in-flight save cannot clear a newer edit. `CKSyncEngine` owns CloudKit change fetching and conditional save conflict delivery; the delegate supplies the current record batches. See [Apple's CKSyncEngine sample](https://github.com/apple/sample-cloudkit-sync-engine) and [CKSyncEngineDelegate](https://developer.apple.com/documentation/cloudkit/cksyncenginedelegate-1q7g8).

| Failure | Response |
|---|---|
| `serverRecordChanged` | Validate and join the returned server record, retain its system fields, requeue joined local winners/history |
| `unknownItem` while saving | Discard stale system fields and retry the retained record as a create |
| `zoneNotFound` / fetched zone deletion | Keep history/tombstones, reset transport fields, queue zone creation and all retained records; foreign-data review still gates merging and further record upload |
| Network, service, rate limit or zone busy | Retain pending work; respect `retryAfterSeconds` with a minimum delay; next foreground/push/save/retry trigger attempts again |
| Quota full | Keep pending records, report storage error, delay retries; no pruning of work/history |
| Sign-out / account switch | Halt and cancel engine operations; keep the original account's archive/sidecar; never automatically send it to another account |
| Invalid record / reused revision identity | Preserve quarantine and block that record from overwriting the offending server record |
| Primary apply failure | Halt sync without advancing persisted state through that failed event; preserve archive and allow refetch after recovery |
| Sidecar write failure | Keep memory/pending work, expose error and gate upload; primary save remains successful |
| Unsupported schema / corrupt sidecar | Stop for explicit recovery/migration; do not reset silently |

Scheduling is explicit (`automaticallySync = false`) to make approval/account/durability gates reviewable. The later app supplies foreground, push and post-save triggers and a retry scheduler if desired. A trigger arriving during an active synchronization may wait until the next trigger; pending data remains durable. Push is an optimization, not a correctness assumption.

History is intentionally not compacted in v1. The adapter refuses envelopes over **750,000 bytes**, retaining local data and an actionable error rather than truncating history. This is a known pre-release capacity limit, particularly for long-lived Running/Preference/Wardrobe registers. A future schema should move immutable revision archives into separate records or assets before this threshold becomes reachable in production. Do not delete tombstones or completed-run evidence on a time-based retention policy without an explicit replica retirement protocol.

## Developer setup, deferred

1. On the developer team that owns both App IDs, create the iCloud container `iCloud.com.erdmncdr.clockin`. Associate **both** `com.erdmncdr.clockin` (iPhone) and `com.ismailakdag.clockin` (Mac) with that same container and enable iCloud/CloudKit and Push Notifications. Confirm team/container access for the legacy Mac identifier before changing signing. [Apple: create an iCloud container](https://developer.apple.com/help/account/identifiers/create-an-icloud-container/).
2. In the later Xcode wiring task, add iCloud with CloudKit and that container to both targets. Add Push Notifications; on iOS enable the Remote notifications background mode and register for remote notifications. On Mac register with APNs and ensure distribution-specific push/iCloud entitlements match the provisioning profile. If sandboxed, allow outbound network access. No custom push server, Sign in with Apple or account system is needed for this private-database transport. [Apple: add a capability](https://help.apple.com/xcode/mac/current/en.lproj/dev88ff319e7.html).
3. Regenerate development/distribution profiles after capabilities change. For direct-distribution Mac builds, obtain and embed a **Developer ID provisioning profile** supporting the Mac App ID, iCloud container and push, in addition to Developer ID Application signing. Recheck the signed binary/profile, then notarize the resulting distribution. Apple evaluates the profile at launch when advanced capabilities are used. [Apple: Developer ID certificates and provisioning profiles](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).
4. In CloudKit Dashboard/Console, use the container's Development environment to create the seven stable record types with the four fields above. Custom zones are created in each user's private database by the engine flow, not as shared public data. Zone-change fetching needs no app-defined query indexes. Exercise real development devices, then deploy the **schema** to Production; deployment does not copy development user records. Verify TestFlight and Developer ID production builds select the intended container/environment. [Apple: deploying an iCloud container's schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema).
5. Validate two signed devices using the same iCloud account: first previews/backups on both, offline edits, competing starts, clock-out against pause, app termination, account change, push wakeups and quota/network recovery. The local checks and type checks do not prove any of these services or capabilities are configured.
