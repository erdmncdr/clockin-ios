# Brief 05 result: sync core

Implemented an inert, independently checked sync core and CloudKit adapter. No app wiring, store hooks, entry-point changes, entitlement changes, Xcode project edits, or `ClockinMac/*` edits were made. No commit was created. The pre-existing untracked `docs/codex/05-sync-core.md` was left intact.

## Delivered

- `Shared/Sync/Cloud/SyncModel.swift`: Sendable snapshots, typed preferences, strict wardrobe/running wire types, revision registers and merge/recovery results.
- `SyncPreferences.swift`: explicit section-C allowlist and device-key inventory.
- `SyncMerge.swift`: pure diff, validation, merge, projection, first-merge counts and recovery records.
- `SyncSidecar.swift`: durable pending state, installation/account metadata, quarantine, notices, first-merge gating, atomic sidecar writes and exact-byte archive backups.
- `SyncBridge.swift`: main-actor integration boundary with a synchronous apply callback; no dependencies on app stores.
- `CloudKitAdapter.swift`: separate CKSyncEngine delegate, record codec, system-field persistence, state restoration, batch construction and error handling.
- `Tests/manual/sync/main.swift`, `run` and optional `cloud/main.swift`: dependency-free pure checks, dual-platform type checks and offline CKRecord codec checks. Commands are in README's Checks block.
- [Full design and setup instructions](../sync-design.md).

## Decisions that refine the brief

| Decision | Reason |
|---|---|
| Keep immutable revision history inside each record envelope | LWW alone cannot preserve a losing timer or completed-run evidence through arbitrary delivery order. Joined history converges and remains recoverable on every replica. |
| Permanent remove-wins for session/rule UUIDs | A timestamp cannot distinguish a concurrent offline edit from a later replay. A deleted identity must not resurrect; explicit recovery uses a new UUID. |
| Advance local time above observed history when necessary | A deliberate resume must beat an already-observed remote pause even when the local clock moved backward. Remote receipt never changes stamps. |
| Explicit required `session: null` for idle | An empty or malformed payload must not be accepted as a clock-out. |
| Purchase identity is permanent item ID | Existing wardrobe items are non-consumable. Two offline purchases unlock and charge once; earliest purchase determines cost, with deterministic tie handling. |
| Strict typed wardrobe DTO and explicit preference allowlist | Forgiving archive/UI decoders and blanket UserDefaults replication would accept malformed resets or device-only state. |
| Exclude consent, `pinVisible` and wardrobe `seeded` | The brief overrides the older inventory classification for consent and pin visibility. Migration/setup state belongs to the device. |
| Separate initial publication from first foreign-data approval | The first device may populate an empty cloud, but still previews and backs up before applying the second device's history later. |
| Collapse import-key duplicates in every projection | Late deliveries of first-sync duplicates cannot inflate totals. Original records and metadata remain recoverable; notices use stable IDs. |
| Explicit CKSyncEngine scheduling | Fetch, approval/account checks and durable sidecar persistence precede uploads. Foreground, push, saves and retry triggers drive synchronization. |

The initial merge counts are `local + foreign remote - duplicates = visible merged`. The duplicate key intentionally matches the existing integer-second import key, including its truncation and omission of note/rate/source. Shared UUIDs and different-UUID import duplicates are both counted. Unchanged echoes created solely by this installation are excluded from the foreign count.

## Integration surface for the later wiring task

1. **Launch:** load `SyncSidecarStore(archiveURL:)`, capture the full `SyncSnapshot`, construct `SyncBridge(state:snapshot:disk:apply:)`, then `ClockinCloudAdapter(bridge:)` and `try await launch()`. Retain unreadable sidecars for recovery. Launch reconciliation finds primary saves that preceded a sidecar failure.
2. **After a successful archive save, preference change/reset or wardrobe/ledger change:** call `try bridge.localDidSave(fullSnapshot)` on the main actor, then schedule `await bridge.persist()` and `await adapter.synchronize()`. Primary storage stays authoritative for save success; a sync error must not roll it back. Capture wardrobe and ledger together.
3. **Foreground / remote notification / retry:** call `await adapter.synchronize()`. It retains pending changes and respects retry delays.
4. **First foreign data:** when fetching is complete and `state.needsFirstMergeReview` is true, present `try bridge.firstPreview()`. Approval calls `try await approveFirstMerge(preview, archiveURL:)`; this creates the exact-byte backup and rejects stale previews before applying. Then synchronize again.
5. **Apply callback:** synchronously apply the merged `ClockinData`, allowlisted preferences and wardrobe/ledger through the future app persistence APIs. Throw before publishing partial state if primary persistence fails. The bridge suppresses reentrant callbacks only during this synchronous application, never while awaiting disk I/O. Then refresh derived values and `SessionMirror`/chime behavior in that callback.
6. **Recovery/notice UI:** `try bridge.review()` returns losing values and recoverable timers; `state.notices(review)` removes acknowledged notices. Acknowledge only after showing them and persist the acknowledgment.

The archive schema and backup reader remain unchanged. Actual app apply transactions, UserDefaults suite routing, multi-process writer ownership, recovery UI and notification registration are deliberately deferred to wiring. Their callback contract and setup sequence are documented in `sync-design.md`.

## Verification

Executed on the installed Apple Swift 6.4 toolchain, in Swift 6 language mode. The new checks use `-strict-concurrency=complete -warnings-as-errors`.

- Pure sync: **196 checks**, including 30 seeded runs with 2 or 3 replicas and 80 edits each (2,400 random offline edits). Session/rate edits and deletions, preferences/resets, profile, wardrobe, purchases and timer operations exchange delayed, duplicated and randomly batched records. Both the canonical synchronized state and full revision registers end byte-identical.
- Focused cases: LWW ties, tombstone precedence, pause versus clock-out, two starts and recovery, completed-run resurrection prevention after session deletion, resume with a backward clock, wardrobe ownership and room state, purchase identity/derived coins, all section-C keys, duplicate counts/recovery, invalid existing/unseeded data, explicit idle validation, no echo, durable notice acknowledgments, sidecar roundtrip, stale approval, exact backup bytes, old in-flight save acknowledgment, disk failure, launch gap recovery, failed apply, transport-error visibility and local edits during first-merge persistence.
- Offline CloudKit codec: **17 checks** for all seven record types, secure system-field roundtrips, identity/stamp mismatch and a valid oversized payload. No CKContainer/account/network operation is invoked by this check.
- All eight requested existing suites passed using their README commands. Where a command lacked a module cache argument, `/tmp/clockin-<suite>-module-cache` was added for the restricted filesystem.
- Adapter type-check passed for **`arm64-apple-macosx14.0`** and **`arm64-apple-ios17.0-simulator`**, using the installed **macOS 27.0 and iOS Simulator 27.0 SDKs**.

Commands for the new checks:

```bash
Tests/manual/sync/run
Tests/manual/sync/run typecheck
Tests/manual/sync/run codec
```

The requested macOS 14.0 and iOS 17.0 SDKs are **not installed**; exact old-SDK type checking was therefore not possible. Minimum deployment-target checking with the available SDKs is not the same claim. I did not run either app, configure entitlements, connect the container, exercise live CKSyncEngine events, validate real push delivery/account changes/quota failures, or test two signed devices. The adapter's service error paths are implemented and type-checked, not service-tested.

## Open questions and pre-release limits

- **History capacity:** v1 retains all revisions and refuses CloudKit envelopes above 750,000 bytes instead of truncating them. Before enabling this in production, decide whether immutable history should move to separate records or assets. Tombstones and completed starts need a replica-retirement protocol before any compaction.
- **Purchase economics:** confirm earliest-price selection for the same item and the current zero-clamped balance when different offline purchases overspend. No item is revoked. Repeatable/consumable purchases would need a new identity scheme.
- **Delete/restore UX:** recovery uses fresh UUIDs. Deleting a collapsed duplicate removes every known alias; an alias from a device never seen before can still appear later and need review/deletion. Decide whether a future explicit duplicate-alias protocol is worth this additional schema.
- **Legacy Mac choice values:** the core retains old sound/history-range strings. Their platform mapping remains a UI decision; no lossy automatic rename was introduced.
- **Signing ownership:** confirm both App IDs can use the same developer team's container. Complete capabilities, push, Developer ID provisioning and production schema deployment as documented.
- **Integration:** decide the recovery/first-merge UI and the app's apply transaction across the archive and UserDefaults. The single-writer sidecar actor does not coordinate separate app/extension processes. The later wiring also needs a retry scheduler if foreground/push/save triggers are insufficient.

## Actual check tails

### sync

```text
ok empty cloud permits initial upload without approving a future merge
ok first foreign history pauses uploads and requires its own merge preview
ok local save during first-merge sidecar write is tracked
All 196 sync checks passed.
```

### CloudKit codec

```text
ok mismatched CloudKit metadata rejected
ok CloudKit record-name spoof rejected
ok valid oversized payload is never silently truncated
All 17 CloudKit codec checks passed without network or entitlements.
```

### sessions

```text
ok: each entry takes the times of the row it was previewed with
ok: the second writing of a correcting row is previewed as a duplicate
ok: and importing does not add it as new work once the entry is taken
20 session checks passed
```

### backups

```text
ok: clock out succeeds once storage recovers
ok: successful clock out stays stopped after relaunch
ok: failed start does not create a memory-only timer
38 backup checks passed
```

### import

```text
ok: the in-file twin is previewed as a duplicate
ok: leaving out a row does not let its duplicate through instead
ok: nothing is imported when the only real row was left out
26 import checks passed
```

### maccompat

```text
ok: importBackup also leaves existing archive untouched
ok: strict restore and import never modify supplied backup
ok: backup listing stays strict, matching restore
375 maccompat checks passed; legacy invalid entries quarantined without losing valid work
```

### rates

```text
ok: clock out updates completed snapshot totals
ok: brand-new user has no earlier work
ok: new user has no completed-session impact
84 rate checks passed
```

### feedback

```text
ok: editing the end time preserves its explicit end date
ok: new time-only entries still infer overnight shifts
ok: equal new times do not silently turn into 24 hours
22 feedback checks passed
```

### celebrations

```text
ok past 3-day and 7-day nudges are never replayed
ok quiet archive may show a current mood, not a notification backlog
ok old paused timer starts its nudge observation at first launch
125 celebration checks passed
```

### wardrobe

```text
ok animated wing composition proof
ok invalid seated source safely ignored
ok concurrent frame requests share cached image off main thread
2898 wardrobe checks passed including real art integration and cache
```

### Adapter type-check

```text
PASS CloudKit adapter: macosx (arm64-apple-macosx14.0)
PASS CloudKit adapter: iphonesimulator (arm64-apple-ios17.0-simulator)
```
