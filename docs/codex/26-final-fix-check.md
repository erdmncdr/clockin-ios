# 26: Check the last three fixes before release

Short focused check of `git diff 79a456c..e24c9ef` (source) on top of your
review 25 (`docs/codex/25-crash-fix-review-result.md`):

1. `ClockinMac/MenuBarHost.swift`: `.map { @Sendable _ in () }` (your finding 1).
   Confirm with your map probe pattern against the real expression.
2. `ClockinMac/ClockinMacApp.swift`: the `.terminateLater` override is removed
   (your finding 2). Confirm nothing else depended on it and launch
   reconciliation (`SyncBridge.reconcileLocalArchive`) covers a missed final write.
3. New: `SyncSidecarStore.save(_:force:)` skips the write for up to 15 minutes when
   only `engineState` (and `revision`) changed since the last write; `force: true`
   from coordinator flush/termination/turn-off and adapter stop. A signed Debug
   run showed every 60 s poll rewrote 5 MB only because CKSyncEngine returns a new
   state serialization per fetch. Look for any path where an older engine state
   on disk (after a kill) can lose or duplicate data, wedge sending, or skip a
   record: pending sends come from the sidecar `pending` list; check zone
   creation, first fetch, account/environment reset, and `persist()` callers that
   treat `true` as durable for something engine-related.

Rules: no source edits; probes under `/tmp`; run `Tests/manual/sync/run`,
`Tests/manual/sync/run persistence`, `Tests/manual/syncapp/run` and both
typechecks. Write `docs/codex/26-final-fix-check-result.md`: blockers first, or
say plainly that nothing should block.
