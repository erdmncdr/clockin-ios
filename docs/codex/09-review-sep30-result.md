Independent review of `9d74fed..5359c91`, completed 2026-09-30. The worktree's later commit only adds the review brief; the reviewed source matches `5359c91`. Documentation was used as release context, not reviewed as implementation.

Six findings, most severe first. No source files were changed.

1. **[P1] A stale reference preview can delete an entry now outside the file's period.**

   Location: `Clockin/Views/Import/TimecardImportView.swift:452-455,467-469`; `Shared/Core/ClockStore.swift:812-815`.

   The view retains the comparison and removal IDs in `phase`; only changing the scope rebuilds it. Confirmation deletes those IDs from the current store without checking that their dates or contents still match what was reviewed. For example, preview a September 10 CSV with an unmatched September 10 imported entry selected for deletion. While the sheet remains open, a sync update moves that same entry ID to October 10. Confirming still shows the September preview but deletes the October entry. The new foreground polling makes updates during a review routine, and reference mode now exposes previously imported entries to this deletion path.

   Reproduced with the real store: create the reference comparison, update the candidate's dates to October under the same ID, then execute `sessionsToImport` and the original leftover IDs. The October entry is removed.

   Suggested fix: bind the import plan to the reviewed store revision and reject/rebuild it if sessions change before confirmation. Validate the expected value of every removal and update target, not just its UUID.

2. **[P1] A partially parsed CSV is treated as a complete deletion reference.**

   Location: `Clockin/Views/Import/TimecardImportView.swift:441-445,452-455`; `Shared/Core/ClockStore.swift:739-745`; supporting parser path: `Shared/Core/CSVImporter.swift:33-35,55-56`.

   `CSVImporter` silently drops rows with an unreadable date or missing field and succeeds if any other row parses. The new whole-range reference preview then treats those dropped rows as absent from the file and preselects their existing entries for deletion. With existing timecards on September 1, 2 and 3, a CSV containing those three rows but an unreadable end timestamp on September 2 produces two recognized rows and marks the existing September 2 timecard “not in the file.” Accepting the default deletion removes valid saved work even though the file contains that row.

   Reproduced through `CSVImporter.parse`, `compareImportedSessions(..., fileIsReference: true)` and `importSessions`: the parser returns two rows and the September 2 entry is deleted. The CSV flow has no rejected-row warning; the partial-total warning is specific to pasted text with an approved total.

   Suggested fix: return rejected-row information from parsing and block reference deletions when parsing is incomplete. Require a complete, successfully parsed file before using absence as evidence for deletion.

3. **[P2] Each poll withdraws an open first-merge preview.**

   Location: `Shared/Sync/SyncCoordinator.swift:88-95`; downstream transitions: `Shared/Sync/Cloud/CloudKitAdapter.swift:199-208`, `Shared/Sync/SyncCoordinator.swift:331-334`, `Clockin/Views/Sync/SyncViews.swift:237-241`.

   Polling calls `start()` even while a first merge awaits approval. Every pass marks the fetch incomplete, making `bridge.firstPreview()` throw and publishing `pendingFirstMerge = nil`. That makes the root sheet's presentation binding false. A user reading the merge preview for more than a minute therefore loses the sheet during the next fetch; a successful fetch makes it eligible for presentation again, while a failed fetch leaves it unavailable until a later success.

   An offline probe using the production bridge/coordinator and the adapter's fetch-state transitions confirmed `pendingFirstMerge`: present → absent during fetch → present after fetch. The sheet consequence follows from its binding; native presentation was not exercised.

   Suggested fix: suspend periodic passes while an unapproved first merge is being reviewed, or retain the displayed preview during refresh and separately track whether approval is valid. Preserve the existing revision check when committing.

4. **[P2] The duplicate warning overstates extra work for groups and sessions with breaks.**

   Location: `Shared/Core/SessionOverlap.swift:88-93`; displayed at `Clockin/Views/Import/TimecardReimportPrompt.swift:34`.

   Every matching pair contributes its entire wall-clock intersection. Three eight-hour copies at 09:00–17:00, 09:01–17:01 and 09:02–17:02 therefore report three duplicate entries and 23 h 56 min extra, although retaining one removes only two entries and 16 hours. Separately, two entries with eight-hour spans but six-hour stored durations report almost eight extra hours instead of six; CSV durations can legitimately exclude breaks (`CSVImporter.swift:37-42`). Both cases were reproduced against the production function.

   Suggested fix: count each redundant entry once against a retained representative and calculate excess from the stored worked durations. Do not sum all pairwise wall-clock intersections as excess earnings time.

5. **[P2] Completing a first merge does not re-evaluate the re-import prompt.**

   Location: `Clockin/Views/Import/TimecardReimportPrompt.swift:21-26`.

   The task identity contains only `found.pairs`, although eligibility also depends on `pendingFirstMerge`. If the two-second task runs with one existing near-duplicate pair and a pending first merge, it sets `showsAlert` to false. Approving a merge that changes preferences or unrelated sessions but leaves that pair intact does not change the task ID: the cleanup prompt stays suppressed until the count changes or the view's task starts again. In the reverse timing, an alert already shown is not withdrawn when a first merge becomes pending with the same pair count.

   Suggested fix: make merge eligibility part of the task/observation inputs and explicitly withdraw the alert while a merge is pending. Re-evaluate after the merge finishes, without relying on the duplicate count changing.

6. **[P3] Choosing Import bypasses the promised daily prompt limit.**

   Location: `Clockin/Views/Import/TimecardReimportPrompt.swift:25-31`.

   Only “Later” records a snooze. With duplicates present, choose “Import timecards,” cancel the import sheet, and relaunch the app a few minutes later: the pair count is still positive and `snoozedUntil` is unchanged, so the new root displays the alert again after two seconds. Repeating this can display it on every launch that day.

   Suggested fix: persist the next eligible prompt time when the alert is shown, or on both buttons. Cancelling the subsequently opened import sheet should not remove the daily limit.

Checked and found correct within the reviewed scope:

- **Environment reset:** records/device identity survive; pending is sorted, unique and excludes local issues, satisfying `validateLocalBounds`. `receive` acknowledges exact fetched values and `commit` recalculates pending against staged records. The persisted environment tag prevents repeated resets. The iOS legacy condition and Mac adoption match the stated policy; no supported data-loss/reset-loop finding here.
- **Detached passes:** all fetch/send calls route through detached tasks, while the helpers and bookkeeping remain `@MainActor`. Stop/account transitions invalidate the generation/engine and drain existing work before restart. No supported bookkeeping race found.
- **Poll ownership:** replacement cancels the old timer, which checks cancellation after sleeping. The loop holds only a weak reference across sleeps and checks `isEnabled` before starting the serialized worker; disabled polling makes no CloudKit calls.
- **Import boundaries:** with unchanged data, removal IDs come only from reviewed leftovers; manually chosen removal IDs are intersected with that list. The running timer is preserved. Scope follows start days: a shift starting before the first day stays, while one starting on the final day is wholly in scope even if it ends tomorrow. CSV instants use the store's current calendar; the exporter’s original calendar day is not retained.
- **Overlap/cache:** conflict-sweep pruning preserves every potentially overlapping interval, including long intervals across gaps. The five-minute/half-shorter thresholds and timecard exemption pass. `data` mutations invalidate the duplicate cache; a deletion probe confirmed this.
- **Sheet environment:** both roots supply the environment objects and palette required by the new import sheet.

Limits: independent root sheet bindings were inspected, but no platform-specific presentation collision is claimed without UI evidence. `cancelOperations()` still appears in `handleEvent` at lines 340 and 408; its contract permits operations to finish after cancellation returns and does not establish a wait for delegate completion, so this review does not claim the same trap as fetch/send. [Apple cancellation contract](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/canceloperations%28%29).

Validation performed without `xcodebuild`:

- `Tests/manual/sync/run`: **268 passed**.
- `Tests/manual/sync/run send`: **37 passed**.
- `Tests/manual/sync/run codec`: **33 passed**.
- `Tests/manual/syncapp/run`: **50 passed**.
- README import and overlap `swiftc` commands, with a module cache under `/tmp`: **30 and 42 passed**.
- `Tests/manual/sync/run typecheck` and `Tests/manual/syncapp/run typecheck`: **macOS and iOS Simulator passed**, Swift 6 strict concurrency with warnings as errors.
- Throwaway probes under `/tmp/clockin-review09-probes` reproduced findings 1–4 (finding 3's published-state transitions) and checked running-session, boundary, threshold and cache behavior. Findings 5–6 follow directly from the task identity and the only snooze write. These checks do not establish signed-device CloudKit or native sheet behavior.
