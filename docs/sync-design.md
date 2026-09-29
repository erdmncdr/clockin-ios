# Clockin sync core, schema 2

This is an inert implementation for review. Nothing creates it from either app. `ClockStore`, `SessionMirror`, `WardrobeStore`, app entry points, project settings and entitlements are unchanged. Only the adapter imports CloudKit; the model, diff, merge, bridge and disk actor import Foundation. Shared data and wire types are `Sendable` values, built in Swift 6 language mode with complete concurrency checking.

## Schema and identity

Use `iCloud.com.erdmncdr.clockin`, the current user's **private** database and custom zone `Clockin`. Never use the public database. Each record has these CloudKit fields:

| Field | CloudKit type | Meaning |
|---|---|---|
| `schema` | Int64 | Currently 2; unknown schemas are quarantined |
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

A revision has `stamp { modifiedAt, modifiedBy, sequence }`, `deleted`, `payload`, retained `parents`, and an immutable optional `observed` causal floor. Installation IDs are 1–128 ASCII letters, digits, hyphens or underscores (production uses UUIDs). Revision identity is `<modifiedBy>:<sequence>` **within a record**; one snapshot save can update several records with the same sequence. Never reuse a sequence or copy an installation's sidecar to another installation.

A schema-2 register also carries `maximumStamp`, optional `sessionFact { clockinStart? }`, and sorted `ownership` set facts. There is no production schema-1 data; schema 1 is rejected, not migrated. Record types, zone and names are unchanged.

## Bounded join, order and proof

Each register keeps the greatest K revisions under a fixed total order. Ordinary revisions order by `(modifiedAt, modifiedBy, sequence)`, then deletion bit and payload bytes as deterministic tie breakers. Reusing a **retained** revision identity with different immutable content is quarantined. A pruned identity is not an unlimited revision-integrity archive.

| Kind | K | Order and rationale |
|---|---:|---|
| Running | 8 | LWW, including explicit idle; frequent operations and a small recent causal context |
| Preference | 8 | LWW including reset tombstones; accommodates bursts of setting changes |
| WardrobeState | 8 | LWW selections/layout; ownership is a separate fact |
| Profile | 4 | LWW; relatively infrequent changes |
| Session | 1 | Every deletion outranks every live revision, then LWW; recovery is captured locally before pruning, and one revision keeps deleted identities small |
| RateRule | 1 | Same permanent deletion order and rationale as Session |
| WardrobePurchase | 3 | Earlier purchase date ranks higher, then lower cost, then greater stamp; winner plus two alternatives |

Session/rule tombstones have **empty payloads**, retain the identity, stamp/causal floor and Session origin fact, and are never removed. An old replica's arbitrarily newer live edit still loses. Restore using a new UUID. The sidecar is proportional to retained identities, including one small register per deleted identity; it is not constant in the number of sessions or rules.

`maximumStamp` joins by maximum and survives pruning even when the payload order prefers an older purchase or a deletion. Local edit stamps advance beyond the maximum observed stamp (across local records) if the clock has rolled back. Receive and re-send never manufacture stamps. Clock skew still influences concurrent LWW choices.

**Proof sketch.** Write T_K(S) for the greatest K elements of S. If x is discarded from A, A already contains K strictly greater elements, which are also present in any union with B. Thus `T_K(A ∪ B) = T_K(T_K(A) ∪ T_K(B))`. This applies unchanged to the fixed deletion-first and reverse-purchase-date orders. Maximum stamps join by max, immutable Session facts must agree, and ownership joins by union independently of the selected revisions. None depend on arrival time, wall-clock expiry, or local acknowledgments.

Parent edges are a projected relation: an edit references all retained revisions it observed, at most K. After pruning, remove references to discarded revisions; parents reference only retained versions. Joining copies of a revision unions their parent edges before projecting them; differing projected edges are not identity reuse. A removed target had K greater revisions, so it can never re-enter the retained union. Hence edge projection also commutes with pruning and join **for input registers with no dangling parents**. The complete register projection P therefore satisfies `P(A ⊔ B) = P(P(A) ⊔ P(B))`. Registers and all their metadata are associative, commutative and idempotent on the valid, immutable-fact-compatible domain. Invalid or disagreeing facts are quarantined outside this algebra.

`observed` is the greatest stamp for this identity known when the revision was authored; it must precede the new stamp. Two distinct-device revisions are *certifiably concurrent* only when each one's causal floor is strictly below the other's stamp. Seeing a revision (including through later sequential edits) raises the floor past its stamp forever. This is a conservative positive concurrency test: an unrelated high floor may suppress a concurrent label, but the replaced payload is still recovered with neutral wording. Pruning a parent cannot invent a conflict. Same-device sequential changes never conflict. Parent absence alone is never conflict evidence.

Convergence means canonical byte-identical retained `SyncRecord` dictionaries (including maximum stamps, projected parents and durable facts) and synchronized snapshots after every valid update has propagated. It excludes only device-local sidecar state, `pinVisible`, and wardrobe seeding. There is no time retention window and no replica-age cutoff.

## Durable domain facts

- Every Session has a required `sessionFact` wrapper. `clockinStart` is the start at creation for a `Clockin`-source session, otherwise nil. Edits to start, note or source **never change it**. The tombstone keeps it. All revisions of an identity must agree on the fact, including nil versus a date; disagreement on join is quarantined. A selected run whose start equals **any known fact** projects as idle, including after the live Session payload has been edited and deleted. Imported sessions do not close runs. This is not inferred from revision history.
- `WardrobeState.ownership` and `Preference:Clockin.SeenAccessoryIDs.ownership` are grow-only sets joined by exact union. Creating a local revision adds its owned/seen IDs to the existing fact. Removing an ID or resetting the preference does not revoke it. Projection additionally unions known purchases into ownership. The `seeded` flag stays local.
- Ownership and purchase IDs must exist in `WardrobeCatalog.items` (67 IDs in this checkout). Arbitrary unknown IDs cannot enter an exact, indefinitely bounded grow-only set. For forward compatibility, unknown-catalog envelopes are retained **whole and unapplied in local quarantine**, with a dedicated allowance of 16 such entries inside the 100-entry/1-MB overall quarantine. An upgrade can decode/re-submit these bytes after catalog support is installed. Entries beyond that allowance evict the oldest unknown envelope with the quarantine overflow notice. This allowance preserves future data for review; it is not permission to project an unrecognized purchase or invent ownership. The server envelope is not overwritten. The bridge reports every rejected key directly to the transport before quarantine eviction, so overflowing quarantine cannot unblock a rejected server record. Quarantine is capped, so preservation is subject to its explicit overflow policy.
- A purchase identity is unpadded base64url of UTF-8 `itemID`. Earliest date wins, then lower cost, then greatest stamp. Later purchase revisions cannot change the first charge. Purchases are permanent non-consumable unlocks and ledger removal never uploads deletion. Coins remain derived; offline buying of different items can overspend the eventual balance, which continues clamping at zero.

Pure diff compares previous/current application values, so saving an applied remote snapshot emits no echo upload.

## Preference policy

`SyncPreferences.types` is the explicit typed allowlist matching section C of `mac-port-inventory.md`; the check parses that inventory to verify coverage. Unknown keys default to device-local. Wardrobe JSON and ledger keys use their dedicated records, not `Preference` records.

The brief overrides two older inventory classifications: `Clockin.RemoteActivityConsent.v2` and JSON `pinVisible` stay local. Live Activity tokens/registries/deletion queues, setup flags, goal prompt bookkeeping, celebration/badge presentation, notifications, language-derived `AppleLanguages`, UI scale, window frames/sizes and exchange-rate caches never upload. User-selected goals, appearance, sounds, haptics, workweek, companion, layouts and Mac-only display choices do upload. `Clockin.Language` must be read/applied through the correct per-platform suite later.

## First synchronization

The adapter fetches before sending, with automatic engine scheduling disabled. Until first merge is approved, remote records accumulate in durable `staged` state and do not invoke the application's apply callback. An empty cloud (or only this installation's previously uploaded records) permits initial publication without marking a future merge as approved. A durable device-local flag remembers that foreign staged data was seen, even after all its revisions are pruned. When the first foreign revision arrives, uploads pause and `needsFirstMergeReview` becomes true. This gives the first device a preview and fresh backup too, even if the other device connects much later. A completed fetch is required to request `firstPreview()`; a network failure does not count as an empty server.

The preview reports raw local and valid foreign remote session counts (excluding unchanged echoes authored solely by this installation), duplicate count and final visible count:

`localCount + remoteCount - duplicates = mergedCount`

Shared UUIDs count once. Different UUIDs with the exact **ClockStore import key** also collapse: `Int(start epoch seconds)|Int(end epoch seconds)|Int(duration)`. This deliberately includes the importer's integer truncation and ignores note/rate/source. The lowest UUID is the deterministic visible representative. Every alias remains its own bounded Session register. If collapsing duplicates removes a value this device had applied, that value enters its local recovery inbox; an unseen remote alias does not generate a local recovery notice. Projection continues this collapse after first sync so later deliveries of existing duplicates cannot inflate totals. Deleting a visible duplicate tombstones all aliases currently known to that device; a previously unseen alias may still require another explicit deletion after arrival.

After the user approves a particular preview, `approveFirstMerge` copies the **exact existing archive bytes** to a uniquely named `clockin-before-sync-<UUID>.json` beside it, reads the copy back, and rechecks the preview revision. Missing/unreadable archives or failed backups abort the merge. Changes during the backup invalidate approval and require a refreshed preview. Each installation follows this gate before applying foreign data. A new installation needs its normal initial archive save before approval. Merely uploading to an empty cloud does not change the local archive and does not consume this gate.

Only then does the synchronous main-actor callback apply the projected data. The bridge records first-merge completion, retains the backup path and schedules uploads that the fetched server lacks. Canceling/dismissing the preview leaves local state intact and keeps staged data for later review.

## Input validation and local-only errors

The same `SyncCore.validate` rules apply on local save and remote input. No payload is silently truncated:

- Session and Running notes: at most 2,000 Swift characters **and 8,000 UTF-8 bytes**. The byte check matters because one grapheme can contain arbitrarily many combining scalars.
- Preference strings: at most 256 characters and 1,024 UTF-8 bytes. Arrays: at most 256 entries, each under the same string limit; the only array preference currently carries catalog IDs.
- Session source/matched-source strings: at most 256 characters / 1,024 UTF-8 bytes. Profiles use a finite nonnegative rate and exactly three uppercase ASCII currency letters. Rules and sessions use existing valid-date/duration/rate checks; Running uses `hasValidDuration(at: revisionStamp)`.
- Wardrobe selections and ownership validate catalog IDs. Equipment/furniture use known slots and at most 16 entries each. Arrangement has at most 16 rooms, 64 items per room, ASCII room/item identifiers at most 64/80 bytes, finite coordinates within ±360/±240. Home-layout decoding remains strict. Each payload additionally has the byte ceiling below, including any unknown JSON fields; malformed JSON is rejected.
- Revision stamps/causal floors, name/type/ID, required Session fact, parent membership/count, unique revision IDs and payload size are checked. Oversized remote revision lists are rejected, not accepted and silently pruned. Join itself handles bounded inputs by deterministic pruning.

An invalid local record stays in the primary local snapshot, is excluded from pending uploads, and receives a durable `SyncLocalIssue` exposed through `bridge.localErrors` and `lastError`, with stable localization key `sync.localValueInvalid` and a localized fallback. Valid records in the same save continue syncing. Subsequent merges/first previews preserve the local-only value over the synchronized projection, and preview counts include that preserved value. Errors survive unrelated saves and relaunch; correcting the value clears its error and authors a fresh revision. The sidecar stores the issue/identity, not another copy of the over-limit payload. Unknown preference keys remain device-local by policy. Invalid remote records go to quarantine without erasing local work.

## Sidecar, recovery and ancillary bounds

`sync-state.json` lives beside `clockin.json`. It contains schema/device/counters, bounded registers, pending keys, bounded system fields and engine checkpoint, account/review/backup state, staged registers, recovery inbox, quarantine and local issues. None of the recovery/acknowledgment/transport state participates in synchronized-register equality.

Recovery is **device-local**. Before a remote update replaces an applied value (or this device's authored winner), the device captures the displaced revision. Recovery is independent of conflict classification: certified concurrency gets a conflict notice; sequential or uncertain replacements get neutral recovery wording. A high unrelated causal floor cannot cause a genuine losing edit to be discarded without recovery. A local edit that immediately loses to a known permanent tombstone or earlier purchase is captured before pruning too; ordinary deliberate local replacements do not populate edit recovery. Distinct unfinished timers are captured when the projection leaves their start; pause/resume of the same start and runs closed by a durable Session fact do not create timer recoveries. Duplicate collapse captures an applied alias that becomes hidden. Ordinary sequential edits do not produce conflicts. Replaying remote losers never populates the inbox merely because they occurred in a received register.

The inbox has at most **50 entries and 256 KB (256,000 bytes) of canonical encoded JSON**, including payload base64 and metadata. Entries are ordered by local insertion, with deterministic record-key ordering for a single merge. When either bound is exceeded, evict oldest unacknowledged entries until both hold. Raise one `recovery-overflow` notice per overflow episode; further evictions do not repeat an acknowledged notice. Acknowledging a recovery removes its payload immediately. An episode ends after its overflow notice is acknowledged and the inbox is drained; then its acknowledgment ID is removed. A later overflow starts a new episode. There is no time expiry and no promise of indefinite preservation when capacity is exhausted. Replaying the same remote register after acknowledgment cannot recapture an unchanged local projection.

Quarantine has at most **100 entries and 1 MB (1,000,000 bytes) encoded JSON**, including its 16-entry future-catalog allowance. It evicts oldest entries, raises one `quarantine-overflow` notice per episode, and uses the same acknowledge-and-drain reset rule. Payloads are kept whole or evicted whole (a single over-budget envelope is evicted with notice). Diagnostic keys/reasons are byte-limited. `removeQuarantine(at:)` is an explicit review/removal API; no app UI is added. Acknowledged entry IDs are not retained; at most the two active overflow acknowledgments exist.

Staged first-merge registers use exactly the same per-record bounds. Pending keys are a unique subset of known uploadable records. System-field archives are at most 16 KiB per known identity; oversized ones are discarded for a conditional-create/refetch fallback. Engine serialization is at most 256 KiB; an oversized checkpoint is omitted with a localized notice so restart performs a fresh fetch. Register data, pending work and recovery survive that fallback.

`SyncSidecarStore` remains a separate actor with atomic replacement, no primary archive writes and a revision guard against stale asynchronous saves. Corrupt/unknown-version sidecars stop for recovery. Failed primary apply does not advance sidecar metadata. Disk failure keeps memory/pending state and gates uploads until a current sidecar revision is durable. On launch the archive is reconciled against retained register projection, including any local-only invalid values.

Use `bridge.review().recoveries`, `bridge.review().notices`, `bridge.localErrors`, `bridge.acknowledgeNotices(ids)` and `bridge.removeQuarantine(at:)` for future UI wiring. Recovery is an inert API and durable data in this change, not a wired user interface.

## Byte bounds

All sizes below are bytes of **canonical JSON**, not raw payload bytes and not CloudKit's total storage accounting. Let `C = WardrobeCatalog.items.count` (67), `B64(n) = 4 × ceil(n/3)`, and

`E(kind) = 2048 + 84C + K × (B64(payloadCap) + 1024 + 152K)`.

The header allowance covers record identity, maximum stamp, fact wrapper and JSON syntax; 84 bytes per catalog ID is conservative (ASCII IDs ≤80 bytes). Each revision reserves 1 KiB for its scalar metadata, including its 128-byte author and optional causal floor; each parent ID needs at most 152 bytes including JSON syntax (128 + colon + 20-digit UInt64 + quotes/comma). Payload Data is base64. Validation makes these finite independently of edit count. The current catalog IDs and defensive bound are exercised by worst-payload tests.

| Kind | K | Raw payload cap | Envelope upper bound |
|---|---:|---:|---:|
| Session | 1 | 16,384 | 30,700 |
| RateRule | 1 | 1,024 | 10,220 |
| Profile | 4 | 1,024 | 19,676 |
| Running | 8 | 16,384 | 200,380 |
| Preference | 8 | 32,768 | 375,132 |
| WardrobeState | 8 | 32,768 | 375,132 |
| WardrobePurchase | 3 | 1,024 | 16,220 |

A deleted Session/RateRule retains a single empty-payload revision, maximum stamp and optional Session fact; a conservative **2,048 bytes** suffices for that tombstoned register (the table remains a valid general bound).

The adapter's defensive refusal is now **524,288 bytes**, strictly above the largest valid register bound, so a valid register cannot reach it regardless of years of use. Oversized invalid wire data is still rejected. Any future catalog/schema extension must keep the tested inequality or revise schema/limits deliberately.

For the complete serialized sidecar, with `R` the multiset of local and staged register copies and `I` the union of their identities plus local-only issue identities, the conservative implemented formula is:

`16,384 + B64(262,144) + Σ[r ∈ R](E(r.kind) + 256) + |I| × (B64(16,384) + 2,048) + 256,000 + 1,000,000`.

That is **fixed bookkeeping/checkpoint + per-identity registers/transport/issues + capped local recovery/quarantine**. The 256-byte allowance covers JSON dictionary keys; the per-identity 2-KiB allowance covers pending keys, issue keys, system-field keys and syntax. Account and backup-path strings are each limited to 1,024 UTF-8 bytes and included in fixed bookkeeping. Save/load validates these local budgets as well as the total formula. Staged and local copies are counted separately; system fields count once per identity. For tombstoned records the optional tighter 2,048-byte register bound may replace E. Session/rule creation increases |I| permanently; mere edits do not. Whole-primary-archive backups are separate user data, not sidecar history.

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
| Quota full | Keep pending records, report storage error, delay retries; no deletion of work/tombstones |
| Sign-out / account switch | Halt and cancel engine operations; keep the original account's archive/sidecar; never automatically send it to another account |
| Invalid record / reused revision identity | Preserve quarantine and block that record from overwriting the offending server record |
| Primary apply failure | Halt sync without advancing persisted state through that failed event; preserve archive and allow refetch after recovery |
| Sidecar write failure | Keep memory/pending work, expose error and gate upload; primary save remains successful |
| Unsupported schema / corrupt sidecar | Stop for explicit recovery/migration; do not reset silently |

Scheduling is explicit (`automaticallySync = false`) to make approval/account/durability gates reviewable. The later app supplies foreground, push and post-save triggers and a retry scheduler if desired. A trigger arriving during an active synchronization may wait until the next trigger; pending data remains durable. Push is an optimization, not a correctness assumption.

History is pruned on every local revision and join; the byte bounds above replace the former reachable 750,000-byte history refusal. Tombstones and Session origin facts have no time-based garbage collection.

## Developer setup, deferred

1. On the developer team that owns both App IDs, create the iCloud container `iCloud.com.erdmncdr.clockin`. Associate **both** `com.erdmncdr.clockin` (iPhone) and `com.ismailakdag.clockin` (Mac) with that same container and enable iCloud/CloudKit and Push Notifications. Confirm team/container access for the legacy Mac identifier before changing signing. [Apple: create an iCloud container](https://developer.apple.com/help/account/identifiers/create-an-icloud-container/).
2. In the later Xcode wiring task, add iCloud with CloudKit and that container to both targets. Add Push Notifications; on iOS enable the Remote notifications background mode and register for remote notifications. On Mac register with APNs and ensure distribution-specific push/iCloud entitlements match the provisioning profile. If sandboxed, allow outbound network access. No custom push server, Sign in with Apple or account system is needed for this private-database transport. [Apple: add a capability](https://help.apple.com/xcode/mac/current/en.lproj/dev88ff319e7.html).
3. Regenerate development/distribution profiles after capabilities change. For direct-distribution Mac builds, obtain and embed a **Developer ID provisioning profile** supporting the Mac App ID, iCloud container and push, in addition to Developer ID Application signing. Recheck the signed binary/profile, then notarize the resulting distribution. Apple evaluates the profile at launch when advanced capabilities are used. [Apple: Developer ID certificates and provisioning profiles](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).
4. In CloudKit Dashboard/Console, use the container's Development environment to create the seven stable record types with the four fields above. Custom zones are created in each user's private database by the engine flow, not as shared public data. Zone-change fetching needs no app-defined query indexes. Exercise real development devices, then deploy the **schema** to Production; deployment does not copy development user records. Verify TestFlight and Developer ID production builds select the intended container/environment. [Apple: deploying an iCloud container's schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema).
5. Validate two signed devices using the same iCloud account: first previews/backups on both, offline edits, competing starts, clock-out against pause, app termination, account change, push wakeups and quota/network recovery. The local checks and type checks do not prove any of these services or capabilities are configured.
