# 24: Crash and resource audit result

Date: 2026-10-01. Baseline: `9c2ed53`. This worktree started at `ec9a820`, whose only additional change was the audit request document. Scope: iOS app, macOS app, and both widget extensions. No archive, release, upload, CloudKit network operation, or relay request was performed. Local `CKRecord` encoding/decoding is exercised by the existing offline codec tests.

## Findings, most severe first

Locations below refer to the resulting source unless an old location is explicitly identified. “Release reachable” describes the code path, not proof that it caused the uncollected reports from other Macs.

| Severity / finding | File:line | Scenario and release reachability | Change and evidence |
|---|---|---|---|
| High: repeated multi-megabyte sidecar replacement | `Shared/Sync/Cloud/SyncSidecar.swift:364`, `SyncBridge.swift:29`, `CloudKitAdapter.swift:195,409` | Observed in release 2.0.6 (17). Unchanged account/checkpoint/empty fetch events advanced state and repeated `.atomic` replacements during every poll. Large histories multiply the I/O cost. | Idempotent mutations, state/encoded-byte deduplication, pass batching and a 250 ms debounce outside passes. Explicit durability barriers remain. A bridge-level simulated pass with a 1,321-record fixture over 5 MB verifies **one changed fetch-pass write, zero quiet-poll writes**, off-main-thread file work, pre-send persistence, acknowledgment flush, restart, stale revisions and retry after disk failure. |
| High: launch trap without signed CloudKit capability | `Shared/Sync/Cloud/CloudSyncCapability.swift:5`, `CloudKitAdapter.swift:91,113`, `Shared/Sync/SyncCoordinator.swift:59` | Observed in development; equally reachable in a mis-signed release because the old adapter initializer unconditionally constructed `CKContainer`. A Swift `catch` cannot recover that Objective-C exception. | Adapter construction is inert. Both the default coordinator capability gate and the adapter check actual executable entitlements. Seven consecutive launches of the unentitled offline harness return `.off`; no container is constructed. Account handling is explained below. |
| High: duplicate identifiers and incomplete projections trap | `Shared/Core/Models.swift:167`, `Clockin/Views/Earnings/EarningsSnapshot.swift:74`, `Clockin/Views/Insights/InsightsSnapshot.swift:73`, `Clockin/Views/Earnings/MonthPerformance.swift:76` | Release code. Duplicate session IDs in imported/corrupt archives reached `Dictionary(uniqueKeysWithValues:)`. The Insights precondition at old line 61 trapped on an incomplete earnings map, although the ordinary view currently builds a complete map. | Retain the first valid archive identity and quarantine later duplicate rows, preserving their original bytes. Dictionary reducers tolerate duplicate keys. Missing earnings use the session's stored rate; invalid sessions are excluded. Optimized baseline harnesses trap on duplicate IDs and missing earnings; the same inputs now return. Archive quarantine and earnings fixtures cover the results. |
| High: font recipe precondition | `Clockin/Views/Components/RollingNumberFont.swift:31,109` | Observed in development; release-enabled precondition for any SwiftUI font outside the lookup table, including `.body`. | Both UIKit and AppKit implementations use a regular body fallback for unknown recipes. The optimized baseline `.body` fixture traps; the fixed fixture succeeds. Native checks cover six recipes and four designs; the UIKit branch is SDK checked. |
| High: implicit environment dependency in save-error alert | `Clockin/Privacy/TimerPersistenceAlert.swift:3`, `ClockinMac/MacShellSupport.swift:47`, `MenuBarHost.swift:64`, `DeskModeWindow.swift:111`, `Clockin/ClockinApp.swift:51` | Observed in development; the modifier could be evaluated outside an injected `ClockStore` in release-hosted surfaces. | The modifier requires an explicit observed store. Every call site supplies it. A real AppKit `NSHostingView` lays out the modifier with no environment object and no trap. Host/dependency review is recorded below. |
| High: Swift 6 dynamic isolation at external callbacks | `ClockinMac/MacAppServices.swift:47`, `MenuBarController.swift:57,177,273`, `KeyboardShortcuts.swift:21`, `UpdateChecker.swift:46,109`, `MenuBarIcon.swift:18`, `Shared/Sync/SyncCoordinator.swift:301` | Release reachable when defaults, KVO, notifications, image drawing, or framework completion handlers execute outside the main actor. An inner `Task` does not by itself prevent an inherited actor check at entry to the outer closure. | External closures are explicitly `@Sendable`, then hop to `MainActor` for UI/state work. All `MainActor.assumeIsolated` sites were removed. Sparkle delegate entry points are nonisolated and transfer only copied values. Native background icon rasterization and a detached defaults notification pass. All four target source sets are checked with Swift 6 complete concurrency and warnings as errors; framework-by-framework runtime exercise remains outstanding. |
| High: numeric conversion and arithmetic overflow | `Shared/Core/Models.swift:378`, `PastedTextImporter.swift:141`, `Shared/Sync/Cloud/SyncMerge.swift:5`, `ClockinMac/MenuBarStatus.swift:55`, `Clockin/Views/Insights/InsightsSnapshot.swift:142,201`, `Clockin/Celebrations/LevelPrestige.swift:19` | Release reachable through pasted huge hour totals, corrupt preferences, extreme finite values, or tiny nonzero pace. Converting to `Int` before clamping is too late. | Bound/check floating-point values before conversion; use Double arithmetic for imported durations and reject invalid totals; guard XP/unlock arithmetic and overflowing goal seconds. Optimized baseline import fixture traps on `Int.max` hours; fixed code rejects it. Focused NaN, infinity, greatest-finite, Int boundary and tiny-pace checks pass. |
| Medium: widget CPU / retained bitmap load | `Shared/Sync/ClockinSnapshot.swift:88`, `ClockinWidgets/TodayWidget.swift:23,50,309`, `Shared/Mascot/WardrobeArt.swift:210,221` | Observed release widget CPU reports. The same provider is included in the iOS extension with a tighter process memory budget. | Running entries decrease **74 to 33** per hour, plus at most one pride-expiry entry. Clock remains system-driven `Text(timerInterval:)`. Money is recomputed at each entry, first after 30 s and then with at most a 120 s scheduled gap. Provider decodes the outfit once and shares one 160 px image per distinct mood/frame, including cached failed attempts. Cache bitmap retention is capped at 4 MiB for widgets / 32 MiB for apps while retaining the newest fitting image. Snapshot arithmetic, image identity and cache budget tests pass; actual WidgetKit host CPU/RSS remains unmeasured. |
| Medium: reversed / unbounded calendar work | `Clockin/Views/Earnings/MonthPerformance.swift:68,72`, `EarningsPeriod.swift:28`, `Clockin/Views/Insights/MonthWeek.swift:7`, `InsightsPeriods.swift:29,57`, `Clockin/Companion/NudgePlanner.swift:80`, `Shared/Core/ClockStore.swift:1028` | Release reachable with future periods after a clock change, very old imported dates, or corrupt saved ranges. Reversed session ends already had archive validation, which remains in place. | Order date-interval endpoints; use fallbacks for optional calendar results; require advancing loop cursors. Cap generated heatmap buckets at 5,200, retaining the most recent/current bucket for every grouping. Bound import year scans. Invalid dates are rejected before widget timer/calendar use. DST, overnight, backwards-clock and huge-range fixtures pass. These caps change only displayed/generated calendar cells, not the stored archive. |
| Medium: duplicate notification identifiers | `Clockin/Audio/FocusChimeController.swift:142`, `Clockin/Companion/NudgeController.swift:71,82` | Release-enabled dictionary traps on unexpected repeated keys from scheduling inputs/system requests; not identified in the collected reports. | Deterministic last-value reducers replace unique-key initializers. `ChimeSchedule.swift:45` remains safe: its keys come from a filtered unique `0..<maximumCount` slot sequence, not dates. Existing scheduling suites and repeated-date/bounded-slot tests pass. System notification-center duplicate delivery itself was not injected. |
| Medium: corrupt archived CloudKit fields | `Shared/Sync/Cloud/CloudKitAdapter.swift:42` | Release path when a sidecar contains malformed archived record metadata. | Secure unarchiver uses `.setErrorAndReturn` and checks `decoder.error`; invalid metadata becomes a sync error instead of an Objective-C decoding exception. Two new malformed-field cases pass in the 35-check offline codec suite. |
| Medium: widget-control literal localization initializer | `ClockinWidgets/ClockinControls.swift:21,25,26,41,42` | Two inspected simulator reports (`ClockinWidgets-2026-09-26-024859.ips` and `153523.ips`) trap in `LocalizedStringResource(stringLiteral:)`; affects platform control construction, with exact release-device reachability unconfirmed. | Explicit `String.LocalizationValue` plus explicit extension bundle URL avoids the failing string-literal/default-bundle initializer. Catalog and keys are unchanged. Availability/type checks pass; simulator/device construction has **not** been proven in this environment. |
| Medium: termination waits and persistence lifecycle | `Shared/Sync/SyncCoordinator.swift:137,142,251`, `ClockinMac/ClockinMacApp.swift:15`, `Clockin/ClockinAppDelegate.swift:10` | Coalescing requires a durable lifecycle boundary. Waiting for network cancellation during Mac termination would introduce a new quit hang. Old callbacks must not apply to a replacement coordinator generation. | Capture pending preference debounce and flush locally. Mac defers quit until local disk flush, starts transport shutdown without awaiting its network completion, and rejects stale-generation applies. Repeated quit remains deferred. iOS uses an expiring background task with generation checks and one-time ending. Fake transport deliberately suspends stop: termination still returns with durable state. OS expiry/real app termination are not device-tested. |
| Low: allocation failure and cache/sample growth | `Shared/Mascot/ArmorHDPixels.swift:14`, `ArmorHD.swift:328`, `ArmorHDParts.swift:65`, `MascotMotion.swift:350`, `ClockinMac/MenuBarStatus.swift:79` | Release graphics paths; allocation failure is especially relevant in widgets. Very large sample counts/formatter-key churn are defensive cases, not observed field failures. | Bitmap context creation is failable, raster size is bounded before multiplication, gradients/path copies have safe failure paths, motion sampling is bounded, and formatter cache holds at most 16 keys. Existing full art/skin tests preserve output and cache identity; invalid raster-size checks pass. Actual OS memory-pressure failure was not injected. |

## Sidecar safety and resource result

The supplied disk report was independently read: `/Library/Logs/DiagnosticReports/Clockin_2026-09-30-220459_Erdem-MacBook-Pro.diag`, release 2.0.6 (17), **8,590.18 MB / 9,991 s**. It reports **“Action taken: none”**. This proves sustained resource abuse, not a process termination. The installed sidecar was read only: **5,176,421 bytes**. No user archive or sidecar was rewritten by this audit.

Encoding and atomic I/O were already implemented in the `SyncSidecarStore` actor at baseline. They stay there; this change does not falsely attribute a main-thread-to-background migration. Bridge/merge logic remains main-actor isolated. The new write test verifies that the actor's actual write runs off the main thread.

Safety boundaries retained:

- A disk actor serializes saves and rejects a captured revision older than the last persisted revision. `.atomic` replacement is unchanged. Failed writes do not update the success cache and remain retryable.
- No-op account, engine-state, empty receive, acknowledgment, initial-upload and system-field changes no longer create artificial revisions. Loaded state is cached, but a migrated sidecar is still written on the next flush.
- A changed fetch pass coalesces event writes to the final pass flush. Uploads can require **additional** writes: pending edits must be durable before sending, and acknowledgments must be durable afterward. The “one write” result is not a promise to remove those barriers.
- Existing pre-send and `nextRecordZoneChangeBatch` barriers remain. First-merge backup/approval, pending outbox, recovery inbox, quarantine, primary-apply-before-checkpoint and conflict history behavior remain covered by the sync suites.
- Outside a pass, changes schedule one short 250 ms flush. Background/termination explicitly flush immediately; cancellation of the scheduled task cannot create a second later write.
- Exhausted sidecar counters reject capture/persistence without wrapping. The five-year, three-replica simulation and bounded-history algebra pass.

`systemFields` are deliberately retained for every known record in this change. They carry conditional-save identity/change tags. Dropping clean-record fields would require another fetch or conflict-driven reconstruction on a future local edit; introducing a new compressed encoding also changes migration/rollback compatibility. The JSON sidecar remains compatible with the prior release. This audit attacks **write frequency** first, without weakening those invariants. A genuinely changed large checkpoint still writes the large atomic file; compression/delta storage and a signed 24-hour trace are future measurement work, not claimed results here.

## Widget behavior and evidence limits

Three release widget CPU reports were found. The independently inspected `ClockinMacWidgets_2026-10-01-035659_Erdem-MacBook-Pro.cpu_resource.diag` reports 16 CPU seconds over 20 seconds (80%) and no termination action. The reported archive/text stack matches the expensive timeline path.

There was already a shared wardrobe frame cache at baseline; the change adds explicit provider-level sharing and a byte budget rather than claiming there was no caching. The bitmap budget is **cache retention after an operation**, not the extension's total RSS or peak allocation. Views, WidgetKit archive storage and images currently in use can retain additional memory. Timeline entry count drops about 55%; a 160 px RGBA output is about 100 KiB versus 225 KiB at 240 px, before archive/compression overhead.

Money continues to advance at scheduled entries across the full hour. The OS controls actual delivery/refresh timing; a two-minute scheduled gap is not a promise of a two-minute OS refresh. Real `_ArchivedViewHost` CPU, iOS jetsam headroom and control-widget rendering still require a signed extension/device run.

## Capability, clean launch and platform compatibility

`ClockinCloudAdapter.init` performs no CloudKit container or account operation. On macOS, signed entitlements are read with public `SecTask` APIs. iOS does not expose these APIs in its public SDK; the shared gate reads the loaded thin arm64 Mach-O's signed XML entitlement slot with bounded command/offset parsing. Missing or unsupported signatures fail closed. Tests cover valid XML capability values, 128 truncated inputs and malformed offsets/lengths. The final App Store-signed iOS executable has not been inspected or launched; confirming its entitlement slot is a remaining release check, because a fail-closed result would disable sync.

There is a necessary distinction for a signed-out account: after valid entitlements, a lightweight container is constructed **only to query `accountStatus`**. Database/user identity/engine construction is gated on an available account. Apple documents account status on the container and explicitly says CloudKit clients should not use `ubiquityIdentityToken` to decide account availability. Therefore this does not claim literally zero container construction for a signed-out, correctly entitled user. See [CKContainer initializer](https://developer.apple.com/documentation/cloudkit/ckcontainer/init(identifier:)), [account status](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:)), and [ubiquity identity token guidance](https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken). No account-status request was executed during this audit.

The unentitled harness proves clean local adapter construction and seven safe launches. Existing temporary-directory store fixtures prove empty/corrupt archive behavior without touching the installed app's data. They do not constitute a signed, clean-machine app launch.

All four source memberships are collected from the Xcode project. Release source branches are checked with macOS 14 and 15 deployment targets for app/widgets, and iOS 17 for app/widgets. `MacTabBar.swift:63` already guards `glassEffect` with macOS 26 availability and retains its older material fallback. Control types are availability annotated, and `ClockinWidgetsBundle.swift:11` already conditionally includes them for iOS 18/macOS 26. These guards remain intact.

Execution host: macOS 27.0 (26A428), Apple Swift 6.4. The SDK harness uses the installed SDK, **not** separate macOS 14/15 SDKs or running OS versions. In this sandbox SwiftUI macro subprocesses cannot start. It therefore uses temporary explicit `EnvironmentKey` / public `SwiftUI.State` wrapper equivalents and omits `LanguageSwitch`'s observation macro. The production files are not changed for this workaround. This checks availability and type/isolation boundaries, not macro expansion, linking, signing, or runtime Observation behavior. Existing local Sparkle artifacts are used; nothing is downloaded.

## Remaining trap and host review

- `ChimeSchedule`'s remaining unique-key dictionary has mechanically unique integer slot keys. No other production `Dictionary(uniqueKeysWithValues:)` remains. No production `try!` or `MainActor.assumeIsolated` remains.
- Remaining `fatalError` calls are required `init(coder:)` implementations on programmatically constructed views/menu items (`ClosureMenuItem`, mascot/atmosphere/confetti views) and DEBUG-only feedback fixtures. There is no nib/storyboard/restoration entry path to those constructors in the reviewed project. They are not presented as observed user crashes.
- Remaining CoreText forced casts in `LevelUpCrest` consume `CTLineGetGlyphRuns` and this renderer's explicitly supplied font attributes. Remaining mascot mood, polygon, layer and collection unwraps have validated bundled assets, construction invariants or preceding emptiness/presence guards. They do not index synced session data. Calendar and imported-data arithmetic received separate boundary checks.
- UserNotifications and AVAudio delegate entry points already use nonisolated methods and explicit main-actor hops; they were retained. ActivityKit update/end work uses async methods and main-actor-owned tasks rather than an unsafely inherited completion closure. CloudKit's delegate is actor-isolated in the SDK and passes strict checks. Local `ClockStore`/wardrobe/celebration publishers remain synchronous on their owning main actor.
- Main window: `MainWindow.swift:32` injects clock and exchange-rate stores. Its sheets inherit that host environment. Menu panel: `MenuBarHost.swift:65` additionally injects radio and updater. Pinned window: `PinnedWindow.swift:114` injects clock, rates and radio. Desk mode: `DeskModeWindow.swift:26` injects clock/rates and its summary sheet inherits them. Settings is a redirect into the main window (`ClockinMacApp.swift:160`), not a second unseeded settings view. The save-error modifier now takes its store explicitly at all four call sites. This is source review plus isolated hosting proof; a full interactive sweep of all windows/sheets was not performed.
- No unbounded data-driven recursion was found. Heatmap bucket generation, samples, image/formatter caches, import year iteration and sync history/diagnostic retention are bounded. Existing fixed bundled-art traversal and finite session aggregation remain.

## Validation

Five new README commands cover sidecar write counts, inert capability launch, numeric/data/signature boundaries, native UI primitives, and four-target SDK checks. Existing suites gained malformed CloudKit metadata, preference/background/termination, snapshot-money progression, cache-budget and invalid-raster/nudge cases.

An additional optimized (`swiftc -O`, Swift 6) paired experiment compiled baseline files directly from `git show 9c2ed53:<path>` and the current files with the same input program:

| Fixture | Baseline | Fixed |
|---|---|---|
| Duplicate session ID in `EarningsSnapshot` | SIGTRAP, exit -5 | exit 0 |
| Missing earnings map in `InsightsSnapshot` | SIGTRAP, exit -5 | exit 0 |
| Pasted `9223372036854775807h 59m Approved` | SIGTRAP, exit -5 | exit 0; rejected duration |
| Rolling `.body` font | SIGTRAP, exit -5 | exit 0; valid native font |

The complete README command results and counts follow. A count is the command's emitted `ok`/`PASS` lines; for grouped art checks, underlying matrix sizes are stated separately. SDK checks are not counted as runtime assertions. Initial failures (oversized-checkpoint warning regression, cache eviction losing immediate image identity, an async test autoclosure, and files changing during typecheck) were corrected or rerun; only final results belong in the table.

**Final: 50/50 README commands exited 0.** Commands use only local fixtures. The table abbreviates long `swiftc` invocations by their test directory; the exact reproducible commands are in `README.md`.

| # | README suite | Emitted success markers | Result / detail |
|---:|---|---:|---|
| 1 | `sync core, bounded history and five-year simulation` | 268 | PASS; 268 checks; five simulation years completed; 3,500 register triples and 30 convergence seeds included |
| 2 | `sync persistence` | 26 | PASS; 26 write/order/failure/lifecycle/counter checks |
| 3 | `sync capability` | 2 | PASS; 2 checks covering seven launches |
| 4 | `crashaudit data/signature` | 206 | PASS; 206 checks |
| 5 | `crashaudit native platform + iOS SDK` | 34 | PASS; 33 native runtime checks + 1 iOS SDK pass |
| 6 | `crashaudit all target source sets` | 6 | PASS; 6 SDK passes: iOS app/widget 17.0, Mac app/widget 14.0 and 15.0; macro substitutes |
| 7 | `sync adapter typecheck` | 2 | PASS; 2 SDK passes |
| 8 | `sync codec` | 35 | PASS; 35 checks |
| 9 | `sync send` | 37 | PASS; 37 checks |
| 10 | `syncapp` | 104 | PASS; 104 checks |
| 11 | `syncapp typecheck` | 2 | PASS; 2 SDK passes |
| 12 | `macliveactivitytip` | 27 | PASS; 27 checks |
| 13 | `iphonefollowsmac` | 51 | PASS; 34 notification + 8 decision + 16 lifecycle assertions; 51 emitted markers |
| 14 | `iphonefollowsmac typecheck` | 2 | PASS; 2 SDK passes |
| 15 | `wardrobe` | 2914 | PASS; 2914 checks |
| 16 | `skins` | 6 | PASS; 6 groups; 396 legacy SHA matches, 924 HD frame/style cases, 14 skins, concurrent reuse |
| 17 | `armorhd` | 7 | PASS; 7 groups; 66 measured frame ratios, 924 silhouettes and 330 design/pose pairs |
| 18 | `radio` | 109 | PASS; 109 checks |
| 19 | `celebrations` | 125 | PASS; 125 checks |
| 20 | `rolling` | 197 | PASS; 197 checks |
| 21 | `haptics` | 61 | PASS; 61 checks |
| 22 | `levelup` | 27 | PASS; 27 checks |
| 23 | `levelprestige` | 1 | PASS; 1 checks |
| 24 | `snapshot` | 125 | PASS; 125 checks |
| 25 | `import` | 102 | PASS; 102 checks |
| 26 | `backups` | 38 | PASS; 38 checks |
| 27 | `overlap` | 47 | PASS; 47 checks |
| 28 | `raterange` | 9 | PASS; 9 checks |
| 29 | `earnings` | 284 | PASS; 284 checks |
| 30 | `historytry` | 87 | PASS; 87 checks |
| 31 | `insights` | 148 | PASS; 148 checks |
| 32 | `mascot` | 270 | PASS; 270 checks |
| 33 | `companion2` | 694 | PASS; 694 checks |
| 34 | `companion` | 17 | PASS; 17 checks |
| 35 | `momentum` | 17 | PASS; 17 checks |
| 36 | `share` | 27 | PASS; 27 checks |
| 37 | `widgettheme` | 30 | PASS; 30 checks |
| 38 | `chime` | 29 | PASS; 29 checks |
| 39 | `chimesound` | 96 | PASS; 96 checks |
| 40 | `controls` | 13 | PASS; 13 checks |
| 41 | `reminder` | 44 | PASS; 44 checks |
| 42 | `nudges` | 100 | PASS; 100 checks |
| 43 | `goals` | 42 | PASS; 42 checks |
| 44 | `sessions` | 20 | PASS; 20 checks |
| 45 | `maccompat` | 375 | PASS; 375 checks |
| 46 | `macmigration` | 51 | PASS; 51 checks |
| 47 | `rates` | 84 | PASS; 84 checks |
| 48 | `feedback` | 22 | PASS; 22 checks |
| 49 | `sessiondisplay` | 61 | PASS; 61 checks |
| 50 | `liveactivityregistry` | 11 | PASS; 11 checks |

The final four-target SDK pass occurred after the production edits. Later edits affected only the syncapp test and this report; that test was rerun and passed 104 checks. All changed production Swift files were included in the final SDK pass. The complete 219-file Swift syntax parse and `git diff --check` also passed. Catalog diff: zero files. Raw command outputs for this run are in `/tmp/clockin24-readme/01.log` through `50.log`, with command/exit/count data in `results.json`; paired baseline outputs are in `/tmp/clockin24-regressions/`. These temporary logs are local evidence, not committed user diagnostic data.

## What remains before release confidence

1. Obtain `.ips` crash reports from the affected other Macs. These fixes address demonstrated resource waste and reachable traps; their missing crashes cannot be assigned a cause from this Mac's resource reports.
2. Run the actual signed applications on clean macOS 14 and 15 systems, including first launch signed out of iCloud, Sparkle launch/update integration and every window/sheet. No full app build, archive, linking or runtime launch was claimed here.
3. Validate the final signed iOS entitlement gate on a device and exercise account transitions/two-device CloudKit sync. This was excluded by the no-network rule. Local convergence and persistence tests do not prove live service behavior.
4. Repeat the Mac resource trace over a quiet day and an edit/import burst. Measure main-thread stalls and actual bytes written, rather than extrapolating the synthetic write counter.
5. Exercise control-widget construction and widget archive/CPU/RSS on macOS and iOS. CoreSimulator service access was unavailable in this restricted environment; SDK success is not simulator proof. The explicit localization initializer change remains runtime-unverified.
6. Exercise real background-task expiry, app termination and memory pressure. Allocation failure paths are defensive source changes; art output/budget tests do not simulate an OS jetsam event. Forced process kill cannot guarantee a final async flush, so existing durable primary data and pre-send barriers remain essential.

The string catalog, version/build numbers, signing configuration, installed applications and real user data were left untouched.
