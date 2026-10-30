# 35: One timer, one session: stop double counting across devices

A tester with Clockin on a Mac and an iPhone (same iCloud account) reports two
things:

1. "When I clock out on the Mac, the iPhone clocks out too, but it counts twice":
   the same work shows up as two entries.
2. "When I press Clock in, sometimes the iPhone does not start."

Work in this worktree (branch `codex-35`). Do not commit; I commit. Keep Swift 6
strict concurrency clean; no new dependencies; do not change record types, names,
zone or the schema number; do not touch the website or the relay.

## 1. The double count (fix this)

`SyncCore.materialize` (`Shared/Sync/Cloud/SyncMerge.swift`) collapses sessions
only by `importKey` = `Int(start)|Int(end)|Int(duration)`. When both devices end
the *same running timer* (the Mac clocks out at 17:00:00, the iPhone still shows
the timer because its fetch has not run and clocks out at 17:00:40, or the long-
session reminder / a widget press ends it there), each `ClockStore.clockOut`
creates a `WorkSession` with a fresh UUID, the same `start`, different `end` and
`duration`. The import keys differ, so after the merge both sessions are visible
and the hours and earnings double. Every Clockin-sourced session already carries
the timer it came from: `sessionFact.clockinStart` (`SyncModel.swift:154`, set
when `source == "Clockin"`), and `materialize` uses it to clear a running timer
that a Session fact has completed (`completed`, line ~309).

Make the rule: **sessions from the same running timer are one session.** Collapse
Clockin-sourced sessions that share the same `start` (exact `Date`, the
`clockinStart` fact) in addition to the import-key collapse. The deterministic
representative is the one with the **earliest `end`** (the first clock-out is the
real one; the later one came from a device that had not yet seen it), ties broken by
the lowest UUID. Apply it:

- in `materialize` (projection after every merge, so later deliveries cannot
  inflate totals again);
- in the first-merge preview counts (`firstPreview`: `duplicates` and
  `mergedCount` must reflect it, `localCount + remoteCount - duplicates =
  mergedCount` keeps holding);
- in the recovery capture that today records an "Import-key duplicate" when a
  visible alias becomes hidden (around line 234): capture the hidden same-timer
  alias with reason "Same timer" so nothing is silently lost;
- in `diff`'s tombstone fan-out for deletions (line ~70): deleting the visible
  session also tombstones its same-timer aliases, like import-key aliases.

Do not collapse sessions whose `source` is not "Clockin" (timecard imports are the
truth and may legitimately share a start), and do not collapse two Clockin sessions
with different starts. Manual entries (`addManualSession`) are also source
"Clockin"; two manual entries with the identical start are collapsed too — note
that in the result as an accepted consequence, or exclude them if the model lets
you tell them apart without a schema change (check `WorkSession` fields first).

Also look at `ClockStore.applySynced` / the local side: after a local clock-out the
local session is in `data.sessions`; when the remote session for the same timer
arrives, `materialize` sees both (local sessions are included), so the projection
collapse is enough. Confirm, and confirm that `completed` (which now may contain
the start from either alias) still clears the running timer.

## 2. "Clock in on the Mac, the iPhone does not start" (analyze, fix only if small)

Read `Shared/Sync/SyncCoordinator.swift` (poll every 60 s, `pollIfNeeded`,
`localDidPersist` debounce) and `Shared/Sync/Cloud/CloudKitAdapter.swift` for
how a device learns about a remote change: CloudKit subscription / silent push
registration on iOS (`SyncPlatform.registerForRemoteNotifications`,
`ClockinAppDelegate`), fetch on foreground (`scenePhase`), and what happens
while the iPhone app is suspended. Write down the realistic propagation delay in
each state (iPhone in foreground, in background with push, killed). If there is a
small, safe improvement (for example a fetch when the app becomes active or when
the Today widget / Live Activity intent runs and finds no timer), implement it;
otherwise describe what it would take. Do not add a server or change the relay.

## Verification

- `Tests/manual/sync/run` (the local harness with the fake transport): add
  scenarios: (a) both devices clock out the same timer at different times → one
  visible session with the earliest end, the other alias hidden, a recovery entry
  with reason "Same timer", totals not doubled; (b) the same through
  `firstPreview` counts; (c) a timecard-imported session sharing a start with a
  Clockin session is NOT collapsed; (d) deleting the visible session tombstones
  the alias; (e) the resurrect guard still clears a running timer completed by
  either alias; (f) the five-year simulation still passes.
- `Tests/manual/syncapp/run` (real stores + coordinator with a fake transport):
  the Mac-clocks-out / iPhone-clocks-out-later race through the real
  `ClockStore` and coordinator: one session afterwards on both.
- `swiftc -typecheck` of the touched files for macOS and iOS Simulator SDKs
  (`Tests/manual/sync/run typecheck`, `Tests/manual/syncapp/run typecheck`).
  xcodebuild is not available to you; I build.
- Update `docs/sync-design.md` (the duplicate paragraph around line 83) with the
  new rule in two or three sentences.

Write `docs/codex/35-same-timer-double-count-result.md`: what changed per file,
the exact collapse rule, the propagation analysis with delays, what was verified
and what the owner should check on two real devices. No Codex/Claude names in
code, comments, docs or suggested commit messages.
