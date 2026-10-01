# 25: Review the crash fixes before Mac 2.0.7 / iOS 0.2 (52)

Fresh reviewer pass over the source in `git diff 9c2ed53..HEAD` (docs are
context). It contains:

- `f3977ed`: the field crash. TestFlight reports from 0.2 (43) and (51) trap 0.3 s
  after launch in `SyncCoordinator.observe` closure #3: CloudKit posts
  `UserDefaults.didChangeNotification` on an XPC thread while caching account
  info, and the Combine sink closure inherited main-actor isolation. Fixed with
  `@Sendable` (also `ClockinMac/PinnedWindow.swift`).
- `958a091` (your audit 24) merged in `25e2a20`.
- `1f287c7`: iOS skips the Mach-O entitlement parser (always entitled); widget
  mascot back to 240 px.

Look hardest for regressions this release could ship:
- Sync durability with batched/deduplicated sidecar writes: any path where a
  local edit, acknowledgment, first-merge approval, recovery or quarantine change
  is sent or acknowledged before it is on disk, or never written; the 250 ms
  scheduled flush racing a pass, `turnOff`, account change or generation change.
- Mac quit: `applicationShouldTerminate` -> `.terminateLater`; can quit hang
  (bridge nil, disk error, Sparkle relaunch, logout/restart), or reply twice?
- iOS background checkpoint task: always ended exactly once?
- Remaining Swift 6 isolation traps anywhere a closure formed in a main-actor
  context can be invoked off the main thread (Combine sinks, KVO, NotificationCenter,
  framework completion handlers, delegates), on iOS, macOS and both widgets.
- Archive load: duplicate session IDs now quarantined; any chance an ordinary
  user archive (or one written by Mac 1.x migration, imports, sync) loses rows or
  shows a recovery notice it did not before?
- Widget: timeline/snapshot changes; can a valid snapshot now fail to decode
  (and show an empty widget) or money stop advancing?
- Anything else that would make 2.0.7 / (52) worse than 2.0.6 / (51).

Rules: no source edits; probes under `/tmp`; run the README suites that do not
need xcodebuild. Write `docs/codex/25-crash-fix-review-result.md` (most severe
first, file:line, scenario, fix) or say plainly that nothing should block.
