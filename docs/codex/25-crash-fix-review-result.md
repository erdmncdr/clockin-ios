# 25: Crash-fix release review

Reviewed `git diff 9c2ed53..79a456c62f78e5d26a1e9d5b0b6760d1f1458a55` on 2026-10-01, including surrounding callers and producers. Documentation was context, not validation evidence. Production source was not edited. All additional probes are under `/tmp/clockin25-review/`.

**Hold Mac 2.0.7 for finding 1.** The same off-main defaults notification still has a reachable Swift 6 trap in the menu-bar publisher. Finding 2 is a separately reproduced, conditional regression in the new termination callback. No additional iOS-specific release blocker was established by this review.

## Findings, most severe first

### 1. P1 — Mac menu-bar `map` still traps on the background defaults notification

**Location:** `ClockinMac/MenuBarHost.swift:50`; subscription at `ClockinMac/MenuBarController.swift:54-58`, installed by `ClockinMac/ClockinMacApp.swift:36` before sync starts.

**Scenario:** `Host.clockin()` is `@MainActor`. Its `NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).map { _ in () }` forms another actor-isolated Combine closure. A notification posted by CloudKit's account-cache work, or any background defaults writer, invokes this transform synchronously on that posting thread. The downstream `.receive(on: RunLoop.main)` does not move an upstream `map` onto the main thread. Making the final sink sendable therefore does not protect this closure.

The menu-bar subscription exists for an ordinary Mac launch, including minimal mode. This is an existing hole left by the crash fixes, not a newly introduced line; it is included because the requested review explicitly covers remaining isolation traps. The `SyncCoordinator` and pinned-window fixes do not cover it.

**Evidence:** A probe extracts the notification publisher expression directly from the production file, creates it in an `@MainActor` function, attaches the downstream main-run-loop scheduler, and posts the notification from `Thread.detachNewThread`. It compiles with Swift 6 complete strict concurrency and warnings as errors. Both `-Onone` and `-O` executables exit with **SIGTRAP (-5)**. Changing only the probe's transform to `@Sendable` makes both exit **0**. No CloudKit service call or installed app is involved.

**Fix:** Make this transform explicitly nonisolated, for example:

```swift
NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
    .map { @Sendable _ in () }
```

Keep the downstream main-actor hop for UI work. Add the background-post regression test for the complete menu-bar publisher chain; a sink-only test misses this fault.

**Reproduction:** `python3 /tmp/clockin25-review/run-map-probes.py`. Source and variant logs: `map-probe.swift`, `map-probe-sendable.swift`, `map-probe-{Onone,O}.log`, and `map-probe-sendable-{Onone,O}.log` in that directory.

### 2. P2 — Termination can deadlock when entered from the main dispatch queue

**Location:** `ClockinMac/ClockinMacApp.swift:15-22`, especially the `Task { @MainActor ... }` at line 18.

**Scenario:** If `NSApp.terminate(nil)` is called from a main-dispatch callback or main-actor task, AppKit enters its nested termination loop after `.terminateLater`. The initiating main-queue job has not returned. The new main-actor task cannot begin, so it never calls `prepareForTermination()` or replies to AppKit. This does not require slow CloudKit or a failed disk write. Repeated requests cannot start another attempt because `finishingTermination` is already true.

**Evidence:** An optimized AppKit probe uses the production termination method, with only `SyncCoordinator` replaced by a logging async stub. Calling `terminate` directly completes the stub and reaches `applicationWillTerminate`, exit **0**. Calling it from `DispatchQueue.main.async` reaches `applicationShouldTerminate` but never enters the stub; a separate thread's five-second watchdog exits **23**. Removing the new termination override, matching the baseline's default termination behavior, makes the same dispatched call exit **0**. Logs are in `quit-results.txt`; rerun with `python3 /tmp/clockin25-review/run-quit-probes.py`.

**Scope of proof:** This is a reproduced callback-level regression. I did **not** establish that Clockin's normal menu action, logout/restart, or Sparkle currently enters through that queue context. In particular, the locally cached Sparkle installer sends an Apple quit event from its helper process; its helper's dispatch queue alone is not proof of this deadlock in Clockin. Do not interpret this finding as an observed Sparkle update failure.

**Fix:** Avoid requiring another main-dispatch job while AppKit is waiting inside the current one. One suitable design is to synchronously capture/freeze the checkpoint on the main actor before returning, perform the disk write off-main, and deliver the single termination reply through a main-run-loop callback explicitly serviced in the termination mode. Keep network shutdown outside the required checkpoint. Preserve exactly-once reply state and logout/restart semantics; merely returning `.terminateCancel` and later quitting the app can cancel the system logout request. Test both direct and main-queue entry, plus real Sparkle and logout/restart.

Apple documents the nested modal run loop for [`terminateLater`](https://developer.apple.com/documentation/appkit/nsapplication/terminatereply/terminatelater). The probe, rather than the documentation alone, establishes the queue starvation here.

## Other requested paths

| Area | Review result and evidence |
|---|---|
| Local edits and upload durability | `CloudKitAdapter.swift:215`, `:223`, and `:326` retain persistence barriers; batch construction follows the `:326` barrier without another suspension. `SyncBridge.persist` detects a changed revision across the disk await. The disk actor rejects older revisions and compares complete state, so write deduplication does not rely solely on the revision number. No additional send-before-persist regression was established. |
| Receive/acknowledgment batching | Callback changes schedule persistence outside a pass. Inside a pass, the batch end at `CloudKitAdapter.swift:197` persists even when the pass returns early. Server acknowledgments and the corresponding engine state share the sidecar; replay from an older durable state remains possible if the process is killed before the checkpoint. `.upToDate` is reached only after the explicit post-send barrier. |
| First merge, recovery and quarantine | Approval still makes its backup, checks the preview revision, applies the primary archive, and persists the candidate. Subsequent upload remains gated by persistence. Recovery acknowledgment enters the serialized coordinator worker. No missing revision update caused by the new equality checks was found. Additional probes verified local edits/quarantine at batch end, subsequent acknowledgment/quarantine removal after the scheduled flush, and retry after a failed scheduled save. |
| 250 ms task, off/on and generations | `beginPersistenceBatch` cancels the pending delayed write; outer batch end persists current state. `turnOff` retains the old bridge until shutdown has drained and persists it; a new worker awaits that shutdown before reopening the sidecar. The generation captured by the apply closure rejects old remote deliveries. Existing coordinator tests exercise fast off/on and late delivery. |
| Mac coordinator shutdown | Apart from finding 2's AppKit entry context, `prepareForTermination` does not await network shutdown. A nil bridge and returned disk error have completion paths. The delegate's guard launches one reply task, not one per repeated request. The README coordinator test confirms shutdown returns while fake transport stop is held. Actual hung filesystem I/O and signed system logout were not simulated. |
| iOS background task | Extracted production checkpoint methods passed a fake-UIKit lifecycle probe: ordinary completion, duplicate begin requests, expiry before completion, completion from an expired generation after a new task begins, stale expiry, and `.invalid` begin result. Every valid identifier ended once. This verifies the state machine, not UIKit suspension/watchdog timing. |
| Other callback isolation | Inspected notification observers, Combine operators/sinks, KVO, timer callbacks, AVAudio/UserNotifications delegates, media commands, CoreHaptics handlers, CloudKit async delegate methods, and widget callbacks. Remaining store/wardrobe/celebration Combine closures have synchronous main-actor-owned producers. No second confirmed off-main isolation trap was found beyond finding 1. Strict SDK checking alone does not detect finding 1. |
| Archive compatibility | The new load filter retains the first duration-valid row per UUID; an invalid row does not consume that UUID. Equal time intervals with different UUIDs are not quarantined by this change. CSV/paste creation uses fresh UUIDs; matching edits update existing rows; sync projects session identities through keyed records. Legacy migration does not regenerate/collide session IDs. No ordinary unique-ID archive regression was established. A duplicate-ID archive intentionally changes behavior: later rows move to quarantine and restore rejects it. The existing safety-copy path preserves the original and raw rejected rows before publishing the reduced archive. |
| Widgets | The schema keys remain compatible and the absent-theme fallback remains. New decode checks reject invalid dates/durations/rates; no ordinary snapshot incompatibility was established. The running timeline has 33 entries through one hour, with a 30-second first update and at most 120 seconds between subsequent entries. Money still computes at each entry date. This is intentionally less frequent than the baseline. Mascot composites are reused per frame at 240 px. Actual WidgetKit archive size, refresh scheduling and jetsam were not measured. |
| Capability and numeric changes | iOS does not execute the Mach-O entitlement parser. Mac checks the signed CloudKit container/services before constructing the container. Defensive numeric/calendar/raster changes were reviewed with the README boundary, compatibility and art suites; no further release regression was established. |

## Verification

**All 50 README Checks commands exited 0 in this review.** Every per-command log was checked for failure markers. This includes the five-year sync simulation, persistence/capability/codec/send checks, real-store coordinator checks, background-notification regression, archive/import/Mac compatibility, snapshot-money progression, and art/cache suites. The SDK commands also passed for the app and widget source memberships, with the harness limitations below. Passing these suites does not override the two additional reproductions above.

Exact commands and per-command output are retained in `/tmp/clockin25-review/commands.txt`, `results.txt`, `summary.json`, and `readme-01.log` through `readme-50.log`. `git diff --check` passed. Workspace status contains only this new report; tracked production and test sources remain unchanged.

Additional probes:

- `run-map-probes.py`: paired Swift 6 background-notification reproducer, both optimization modes.
- `run-quit-probes.py`: paired default/new AppKit termination behavior, direct and main-dispatch entry.
- `run-bridge-probe`: real bridge/sidecar source; batch cancellation, disk reopen after local edit/quarantine/acknowledgment, scheduled disk-error retry.
- `checkpoint-probe.swift`: production iOS checkpoint methods with fake UIApplication and controllable flush completion; valid task identifiers end exactly once.

Host: macOS 27.0 (26A428), Apple Swift 6.4, arm64. No `xcodebuild`, archive, upload, installed-app mutation, or live CloudKit synchronization was performed. The four-target SDK harness uses the README's documented temporary macro substitutes and locally cached Sparkle. Those checks establish type/availability compatibility, not macro expansion, signed launch, actual macOS 14/15 execution, or device/WidgetKit behavior.
