# 26: Final fix check

**Nothing in these three fixes should block release.** Review 25 findings 1 and 2 are resolved. No path was established where the engine-only write throttle loses application data, duplicates a session, strands pending sends, or skips a record.

Reviewed `git diff 79a456c..e24c9ef` on 2026-10-01. Checkout `947f8e6` differs from `e24c9ef` only by the review-request document. Production and test sources were not edited. Probes and logs are under `/tmp/clockin26-review/`.

## 1. Menu-bar map — confirmed fixed

`ClockinMac/MenuBarHost.swift:52` now makes the notification transform explicitly `@Sendable`. The probe extracts the actual publisher expression from this file, creates it in an `@MainActor` function, attaches `.receive(on: RunLoop.main)`, and posts `UserDefaults.didChangeNotification` from `Thread.detachNewThread`.

With Swift 6 complete strict concurrency and warnings as errors, the actual expression exits **0 in both `-Onone` and `-O`**. Removing only `@Sendable` in the temporary negative-control source reproduces **SIGTRAP (-5) in both modes**. This verifies the transform itself, upstream of the scheduler.

Reproduce: `python3 /tmp/clockin26-review/run-map-probes.py`; results in `map-results.log` and `map-{current,reverted}-{Onone,O}.log`.

## 2. Termination override — removal is safe for this scope

The `.terminateLater` callback, guard, and reply task are gone. There are no remaining production references to that guard or termination reply. `prepareForTermination()` remains available and tested, but has no production caller now; Mac exit must not be described as performing a forced sync flush. Existing synchronous `applicationWillTerminate` cleanup remains at `ClockinMac/ClockinMacApp.swift:109`. The callback-level AppKit probe with default termination exits **0** from `DispatchQueue.main.async` and reaches `applicationWillTerminate` (`quit-results.log`).

The archive does not depend on this callback for saving: `ClockStore.save` writes atomically before `didPersist.send()` (`Shared/Core/ClockStore.swift:1093`). On the next sync launch, the coordinator loads the sidecar and captures the current stores; the adapter checks account/environment, calls `reconcileLocalArchive()`, and persists before creating the engine (`CloudKitAdapter.swift:136-154`). Reconciliation compares the old record projection with the current primary snapshot (`SyncBridge.swift:70`).

The restart probe verifies a missed final sidecar write containing session insertion, edit, deletion, and a profile change: all are rebuilt into `pending`, persisted before sending, and a second reconciliation creates no duplicate versions. This recovery assumes the primary save succeeded. Unflushed sidecar-only UI acknowledgments may replay after exit; reconciliation does not promise to reconstruct those.

## 3. Engine-only throttling — no blocker found

`SyncSidecarStore.save` ignores only `engineState` and `revision` when deciding to defer (`SyncSidecar.swift:377-395`). Every other persisted field participates in equality. Skipping does not advance the cached written state/revision/time. A later application-state change therefore writes the complete current sidecar, including its latest engine checkpoint.

| Path | Result |
| --- | --- |
| Pending sends and old engine queues | `enqueuePending` rebuilds engine saves from durable sidecar `pending` each pass (`CloudKitAdapter.swift:272`). `BatchSource.record` also requires sidecar membership (`:300`), and the batch builder removes unavailable engine entries. Thus an old engine queue can neither suppress a pending record nor independently resend an acknowledged one. Stable record IDs and merge semantics handle replay. |
| Fetch and acknowledgment | Changed records, staged records, pending removals, system fields, quarantine, and recoveries bypass throttling. An old cursor can replay already retained records; it is not advanced beyond newly received data by this optimization. Restart probes verify durable new remote data with an older cursor, idempotent replay, and durable acknowledgments/system fields. |
| Zone creation/reset | Every engine launch queues `.saveZone` (`:156`); this work does not rely on a saved engine queue. `recoverZone` resets transport, queues the zone again and re-enqueues records (`:454`). Clearing fields or changing pending forces a write. If reset changes only engine bytes because fields are already empty and all records already pending, reconstructible zone/send work remains available on restart. |
| First fetch/merge | `fetchComplete` starts false and each pass fetches before sending. Initial upload permission, foreign staging, and first-merge approval are sidecar fields, so changes cannot be throttled. The probes verify both the empty-fetch permission and foreign-data upload block survive reopening; foreign replay does not duplicate staged records. |
| Account/environment | Launch rejects a mismatched account before constructing the engine; account-change events halt the adapter. First account binding is a non-engine delta. Environment binding/reset changes `cloudEnvironment` and merge gates as well as transport state, forcing persistence before engine creation (`:136-154`; `SyncSidecar.swift:299-322`). An old cursor cannot cross this persisted environment boundary. |
| `persist() == true` callers | Ordinary success no longer means the newest engine serialization is on disk. The launch, pre-send, batch-provider, post-send, coordinator-worker and batch-end callers need application records/outbox/gates to be durable; those deltas cannot take the engine-only shortcut. `.upToDate` may coexist with an older disk cursor, but acknowledged records/outbox are retained. No caller was found that requires engine-only queue or cursor durability to make an irreversible application-state decision. |
| Forced checkpoints | Coordinator flush, termination helper and turn-off, plus adapter stop, pass `force: true`. This bypasses engine throttling while retaining identical-state deduplication and old-revision rejection. Reopening verifies the forced cursor is stored. |

Apple describes serialization as opaque state tied to fetched/sent changes, to be persisted alongside local data; this review does **not** assume it contains only a fetch token. The safety conclusion comes from the application's durable outbox, full non-engine equality check, and restart reconstruction. [Apple: CKSyncEngine.Event.StateUpdate](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/stateupdate)

**Nonblocking timing nuance:** this is a save-time throttle, not a timer guaranteeing a checkpoint within 15 wall-clock minutes. `load()` resets `writtenAt`; repeated short launches, a quiet process with no further saves, or a clock rollback can retain an older cursor longer. That changes replay work, not the application-data durability argument above.

## Verification

All requested commands exited **0** with no failure/error/warning markers in their logs:

| Command | Result | Log under `/tmp/clockin26-review/` |
| --- | --- | --- |
| `Tests/manual/sync/run` | 268 checks, including five-year simulation | `check-1.log` |
| `Tests/manual/sync/run persistence` | 30 checks | `check-2.log` |
| `Tests/manual/syncapp/run` | 105 checks | `check-3.log` |
| `Tests/manual/sync/run typecheck` | macOS arm64 14.0 and iOS arm64 simulator 17.0 | `check-4.log` |
| `Tests/manual/syncapp/run typecheck` | macOS arm64 14.0 and iOS arm64 simulator 17.0 | `check-5.log` |

Additional production bridge/sidecar restart probe: **34 checks passed**, via `bash /tmp/clockin26-review/run-restart-probe`; output `restart-results.log`. Its initial assertions were corrected for fixture sessions sharing an import key and for materialization sorting sessions; neither required a source change. The probe uses opaque marker bytes for engine checkpoints and injected record delivery, not a live CKSyncEngine/server. The map and AppKit probes cover the specific callback regressions, not a signed full-app launch, Sparkle install, or system logout. The signed Debug observation in the request was not independently rerun. Both SDK checks are the requested sync harnesses, not full app/archive builds.

`git diff --check` passed. The only workspace change is this report.
