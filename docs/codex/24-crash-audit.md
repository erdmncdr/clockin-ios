# 24: Crash and resource audit before Mac 2.0.7 / iOS 0.2 (52)

People report the Mac app crashing (2.0.6, Sparkle build, other Macs; we have
no logs from them). Audit both apps for crash and hang causes, fix what you find,
and prove each fix. Base: this worktree's start commit (main, `9c2ed53`).

## Evidence from this Mac (`~/Library/Logs/DiagnosticReports`, `/Library/Logs/DiagnosticReports`)

1. Release 2.0.6 (17), `/Applications/Clockin.app`, `Clockin_2026-09-30-220459...diag`:
   **8,590 MB written in 9,991 s** (limit 99 KB/s per day), 303 threads. Every
   sample is `SyncSidecarStore.save` -> `Data.write(.atomic)` from
   `SyncBridge.persist()` (SyncBridge.swift:101), called from
   `ClockinCloudAdapter.handleEvent` (CloudKitAdapter.swift:402),
   `nextRecordZoneChangeBatch` (:319) and `synchronizePass` (:209, :217).
   The real `sync-state.json` here is **5.2 MB** for a 120 KB archive:
   `systemFields` 4.26 MB (1,321 records, about 3.2 KB each), `records` 0.93 MB,
   `engineState` 4 KB, `recoveryInbox` 27 KB. Two earlier reports (2.0.4, 2.0.6)
   show the same. The Mac polls every 60 s, so this runs all day; on the main
   actor it is also a hang source. Users with more history are worse.
2. `ClockinMacWidgets` 2.0.6: three `cpu_resource` reports, 80-97 % CPU for
   about 20 s, in `_ArchivedViewHost.archiveStates` / text resolution. The running
   timeline (`ClockinWidgets/TodayWidget.swift:23-50`,
   `ClockinSnapshot.runningTimelineDates`) builds about an hour of entries, each
   with its own composited mascot image. On iOS the widget extension has a small
   memory limit, so check that too.
3. Debug crashes (development, but show reachable traps):
   - `CKContainer(identifier:)` trap in `ClockinCloudAdapter.init`
     (CloudKitAdapter.swift:93) from `SyncCoordinator.run` (:240) via the default
     `makeTransport` (:64): a build without the iCloud container entitlement
     crashes at launch, seven times in a row. Make sure no shipped path can
     construct the container when the entitlement or account is missing (e.g.
     check the entitlement / `supportsSync` first), and that a sync failure can
     never take the app down.
   - `RollingNumberFont.resolve` `preconditionFailure` (RollingNumberFont.swift:33, :111).
   - Missing `@EnvironmentObject ClockStore` in `TimerPersistenceAlert`.
   - Widget control `LocalizedStringResource(stringLiteral:)` trap at
     `ClockinWidgets/ClockinControls.swift:25` (simulator).

## What to do

A. Fix the sidecar write amplification without weakening sync safety: write only
   when the encoded state actually changed, coalesce bursts (one write per pass /
   short window, flushed at the end of a pass, on background/terminate, before
   anything that relies on it being on disk), keep encoding and writing off the
   main thread where safe, and consider whether `systemFields` needs to be kept for
   every record or can be stored more compactly. Keep the existing ordering
   guarantees (revision check, `.atomic`) and the five-year simulation passing.
   Add a test that counts writes for a typical pass and a quiet poll.
B. Widget: make the running timeline cheap (fewer entries, shared image per mood,
   `Text(timerInterval:)`-style counting where possible) without bringing back the
   "money stops while the clock moves" bug the comment describes.
C. Crash audit on iOS, macOS and both widget extensions. Look at least for:
   `fatalError`/`precondition*`/`try!`/force unwraps/`as!`; `Dictionary(uniqueKeysWithValues:)`
   with keys that synced or imported data can duplicate (ChimeSchedule,
   FocusChimeController, NudgeController, EarningsSnapshot, MonthPerformance);
   ranges built from data where the bound can be reversed (`a...b`, `a..<b`,
   `Calendar` date ranges, `stride`) including sessions whose end precedes start
   or that cross DST/midnight; integer conversion of NaN/infinite/huge doubles;
   array indexing from data; `InsightsSnapshot.swift:61` precondition; Swift 6
   dynamic actor-isolation traps (main-actor closures called on background
   queues by AppKit/UIKit/UserNotifications/CloudKit/ActivityKit/Sparkle
   callbacks, `MainActor.assumeIsolated` sites in ClockinMac, delegates);
   missing environment objects in every Mac window, the menu bar panel, desk
   mode, sheets and `Settings`; recursion or unbounded growth.
   Fix every reachable one, release-safe (no new traps), with a focused test
   where the logic allows.
D. Mac launch on a clean machine and on macOS 14/15 (deployment target 14.0):
   availability checks for macOS 26 APIs (`glassEffect`, controls), and first
   launch without iCloud signed in.

Rules: ASCII Turkish comments, catalog untouched unless new text is needed, no
xcodebuild archive/release, no CloudKit or relay calls. Run every README suite
that does not need xcodebuild and report counts; add new suites to the README.
Write `docs/codex/24-crash-audit-result.md`: findings most severe first
(file:line, scenario, reachable in release or not, fix), what you changed, and
what remains.
