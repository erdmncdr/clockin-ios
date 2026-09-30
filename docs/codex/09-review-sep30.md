# 09: Independent review of the 2026-09-30 sync and timecard changes

You are reviewing code that is already released (iOS TestFlight 0.2 (45)-(50),
Clockin for Mac 2.0.1-2.0.5). Find real defects; do not restyle. Report only
what you can support by reading the code, with file:line and a concrete
failure scenario (inputs/state -> wrong result/crash/data loss).

Range: `git diff 9d74fed..5359c91` in this worktree (docs/ changes are records;
read them for context, do not review them).

## Changes to review

1. `Shared/Sync/Cloud/SyncSidecar.swift` `bindEnvironment`, `CloudKitAdapter`
   `performLaunch` + Info.plist `ClockinCloudEnvironment`: sidecar state from
   another CloudKit environment is reset so the device meets the server as a
   new device with history. Legacy untagged state: reset on iOS only when
   `firstMergeCompleted`; adopted on macOS.
   Check: can a real production device lose data or loop (reset every launch)?
   Is `resetTransport` + clearing `staged`/`firstMergeCompleted` consistent with
   `validateLocalBounds` and with how `receive`/`commit` use `pending`?
2. `CloudKitAdapter.launch`/`synchronize`: launches and passes run in
   `Task.detached` via `runLaunch`/`runPasses` so CloudKit never sees a pass as
   running inside a `CKSyncEngine` delegate callback (iOS 27 trapped with
   "Cannot await a call into CKSyncEngine from within a delegate callback").
   Check: every path to `engine.fetchChanges`/`sendChanges`; any other awaited
   CKSyncEngine call that could still run in a task created inside
   `handleEvent`/`nextRecordZoneChangeBatch`; races introduced by detaching
   (main-actor isolation of `runPasses`, `syncTask` bookkeeping, `pass`
   request/finish, `stop()` and `accountMayHaveChanged()` while a detached pass
   runs).
3. `SyncCoordinator.setPolling` (60 s poll while the Mac runs / while an iPhone
   scene is active), `ClockinApp` scenePhase wiring, `ClockinMacApp`.
   Check: task lifetime, double timers, interaction with `start()`/`turnOff()`,
   first-merge pause, account change, and polling when sync is disabled.
4. Timecard import (`Shared/Core/ClockStore.swift` `compareImportedSessions`
   `fileIsReference`, `leftoverSessions(anySource:)`, `importSessions(removing:)`;
   `Clockin/Views/Import/TimecardImportView.swift`): every import is the
   reference for its period; leftovers of any source are preselected for
   deletion (CSV: whole range; pasted: days in file).
   Check: can the preview and the actual import disagree (an entry shown as kept
   but deleted, or a row shown as matched but added twice)? Can an entry
   outside the file's range be deleted? What happens to the running session,
   to entries crossing midnight at the range edges, and across time zones?
5. `Shared/Core/SessionOverlap.swift` `conflicts` (no warning between two
   timecard entries; ignore <= 5 min unless >= half of the shorter) and
   `importedTwice` (timecard pairs whose start and end are each within 15 min),
   `ClockStore.importedTwice` cache, `Clockin/Views/Import/TimecardReimportPrompt.swift`
   (alert at most daily, opens the import sheet, skipped while a first merge is
   pending).
   Check: sweep correctness (the `open` list pruning), cache invalidation, the
   prompt's `.task(id:)` behavior, presenting a sheet from the root modifier on
   iOS and macOS alongside existing sheets.

## Rules

- Do not edit source files. You may run the manual checks listed in README.md
  that do not need xcodebuild (e.g. `Tests/manual/sync/run`, `run send`,
  `run codec`, `Tests/manual/syncapp/run`, the overlap and import `swiftc`
  commands) and write small throwaway probes under `/tmp` if a claim needs
  evidence.
- Write your findings to `docs/codex/09-review-sep30-result.md`: most severe
  first; for each: file:line, what is wrong, a concrete scenario, and a
  suggested fix in one or two sentences. Then a short list of things you
  checked and found correct. If you find nothing serious, say so plainly.
