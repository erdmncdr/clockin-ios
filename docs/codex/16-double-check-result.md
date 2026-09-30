Independent review of `5359c91..048a55f`, completed 2026-09-30. HEAD `64db3e8` adds only the review brief; its source matches `048a55f`. Documentation was context, not implementation evidence. No source files were edited; probes and their output are under `/tmp/clockin-review16/`.

I would hold Mac 2.0.6 / iOS 0.2 (51) for findings 1–3. Finding 4 is recoverable review friction, not a permanent import lockout. Findings apply to both platforms.

1. **[P2] A failed fetch can disable polling indefinitely when there is no first-merge preview to approve.**

   Location: `Shared/Sync/SyncCoordinator.swift:101-105`. Supporting paths: `Shared/Sync/Cloud/SyncBridge.swift:73-77`, `Shared/Sync/Cloud/CloudKitAdapter.swift:199-208,483-500`, `Clockin/Views/Sync/SyncViews.swift:27-29`.

   The new guard suppresses polling on `needsFirstMergeReview`, even when `pendingFirstMerge` is nil. After a foreign-data preview is postponed, an explicit foreground/push/local-save trigger can start another fetch and set `fetchComplete = false`. If that fetch fails without scheduling an adapter retry—for example, `CKError.operationCancelled`—foreign staged data still requires review, but `firstPreview()` cannot publish a preview until another fetch completes. Every subsequent poll returns nil. Settings also loses its “Review the first merge” link, and approval returns immediately because there is no preview. The same state can arise after a partially received first fetch fails.

   Reproduced with the production coordinator/bridge and a throwaway transport using the adapter's fetch-incomplete/failure transitions: `pending=false`, `needsReview=true`, **10/10 polls skipped, zero fetch calls**. An explicit `start()` recovered the preview. Thus this can remain stalled while the Mac stays open with no further local edits or delivered pushes; it is not unrecoverable across all external triggers. Ordinary network errors with the adapter's scheduled retry are not this failure case.

   Suggested fix: suspend polling while there is a usable preview awaiting review, but allow fetch recovery when the preview is unavailable after an incomplete/failed pass. Retain the revision checks when approving the merge.

2. **[P2] Pasted rows are split inside valid source names, and weekday-bearing headers falsely count as rejected rows.**

   Location: `Shared/Core/PastedTextImporter.swift:23-35`.

   The new splitter treats any weekday substring at a word boundary as a new row; the date after the weekday is optional, and the weekday itself has no trailing word boundary. `Monday September 14 Approved Monday 09:00 10:00` previously produced one valid session with source `Monday`; now the second `Monday` splits the row before its times, and parsing throws `noEntries`. `SundayService` and `September 15 Launch` as source names also fail. In a three-row paste with a middle source of `Monday Review`, the old parser returns three sessions and the new parser returns only two, reporting two skipped fragments. Valid pasted work is refused or omitted, although the skipped-row protection prevents reference deletion in this case.

   The same boundary rule misclassifies a header such as `Tuesday September 1, 2026 - Wednesday September 30, 2026`: adding it before an otherwise valid row leaves the session unchanged but reports two skipped rows and disables deletion. The year exclusion only protects the standalone month alternative, not the weekday alternative.

   Reproduced by compiling both the `5359c91` and current parsers against identical inputs; see `parser-probe.log`.

   Suggested fix: recognize entry boundaries from the row grammar/context, excluding page headers and source text, instead of searching for unqualified weekday/month fragments throughout the paste. Preserve malformed-row isolation and add regressions for weekday/date-bearing source names and weekday-bearing date-range headers.

3. **[P2] A complete mixed-status paste cannot clean up duplicates because an Approved subtotal is compared with all rows.**

   Location: `Clockin/Views/Import/TimecardImportView.swift:525-526`. Supporting paths: `Shared/Core/PastedTextImporter.swift:49,122-131`, `Clockin/Views/Import/TimecardImportView.swift:354-355,377-378,545-546`.

   `duration` includes Approved, Submitted, Draft and Unapproved sessions, but `approvedDuration` is specifically the page's Approved subtotal. The new deletion gate requires those different totals to agree. A complete September paste containing `1h 00m Approved`, a one-hour Approved row and a one-hour Submitted row parses both sessions with **zero skipped rows**, yet `allowsDeletions` is false because 3,600 seconds is compared with 7,200 seconds.

   Reproduced with the production parser, store comparison, and an unchanged extraction of `TimecardImportReview`: when both rows are already stored alongside one extra near-duplicate, there are **zero actionable rows and one leftover**, but deletion is forbidden. Both Import buttons therefore remain disabled, and the deletion picker is disabled too. Reopening or reviewing the same complete paste again cannot complete the requested cleanup. Before this diff the mismatch was a warning, not a deletion prohibition.

   Suggested fix: preserve parsed status and compare the Approved subtotal only with parsed Approved work, using consistent duration semantics. Keep the rejected-row guard, but do not classify complete non-Approved rows as evidence of missing input.

4. **[P3] An unrelated sync can invalidate a review solely by reordering the same sessions.**

   Location: `Shared/Core/ImportComparison.swift:84`; consequence at `Clockin/Views/Import/TimecardImportView.swift:486-493`. Ordering source: `Shared/Sync/Cloud/SyncMerge.swift:297-300`.

   `reviewedSessions == sessions` compares array order as well as every field. Local imports append sessions, whereas sync materialization sorts them by UUID. Preview an archive whose insertion order differs from UUID order, then receive only a remote theme change: the same session values are republished in canonical order, and Import refuses the review, clears chosen leftovers and switches deletion to Keep all despite no session having changed.

   Reproduced through the real coordinator/store apply path: `Set(before) == Set(after)` is true while array equality and `isCurrent` are false. Rebuilding the review and delivering another unchanged sync succeeds, so this is a spurious rejection and selection reset, not an endless loop. A changed note on a session outside the imported period is also conservatively treated as invalidating the entire review by this comparison.

   Suggested fix: compare reviewed session values independently of incidental array order, and use deterministic match tie-breaking if order currently selects among equivalent candidates. For narrower invalidation, compare the recomputed import plan and its actual update/removal targets; retain exact checks against meaningful target edits.

Checked without an additional blocking finding:

- **Import safety and stability:** stale moved/edited removal targets are refused before mutation. Starting a timer and editing the rate leave the reviewed session array current. The sync codec preserved exact equality in 1,000 fractional-date round trips; no floating-point self-invalidating loop was reproduced. The ordering rejection above becomes stable after rebuilding.
- **Parser compatibility:** ordinary CSV, trailing commas including at EOF, UTF-8 BOM, CR-only and CRLF endings, blank/whitespace-only lines, escaped quotes and quoted multiline fields retained the baseline sessions. Header-only CSV still produces no valid entries, as before. Empty-field records and repeated CSV headers now count as skipped logical records; readable rows still import. The existing session-display pasted format and joined weekday/month format remain valid. Mixed inline/block input now recovers a block that the old whole-document fast path omitted, consistent with the intended fix.
- **Other 09 fixes:** intact postponed previews remain available for approval; successful approval resumes polling. Duplicate groups count redundant entries once and use stored duration. The re-import task includes merge eligibility, checks cancellation after its delay, and stores the 24-hour snooze before showing the alert, covering Import followed by cancellation. Native alert presentation was not exercised.
- **Mac root/navigation:** all four destinations retain their own `NavigationStack`. Root sheets, celebration blocking/overlay, palette and scene-phase environment remain outside the tab switch. `nudges.openToday`, reminder routing, Settings commands and tab buttons still use `MacNavigation`. Window autosave/restoration remains owned by the unchanged `MainWindowController`; the new tab file is included by the synchronized Mac source group. No source-supported broken route was found.
- **Menu bar:** the extracted production status closure passed idle/running/paused checks with the details preference absent, false and true; saved minimal-mode/field choices stayed unchanged. The existing controller still shows text only in minimal mode. All three production icons rendered as 20 × 18-point template images.
- **Chime/radio:** the Mac chime retains the shared permission-aware toggle, saved interval/sound keys, 1–120 interval bounds, adjust callback and pin action. The phone branch retains its previous controls and interval normalization. Mac-only borderless/hidden-indicator radio modifiers do not change the iOS branch.

Validation:

- **All 42 README Checks commands passed**, including `sync` **268**, `sync send` **37**, `sync codec` **33**, `syncapp` **52**, import **56**, overlap **47**, and session-display **61**. Both README typecheck commands passed for macOS and iOS Simulator with Swift 6 complete concurrency checking and warnings as errors. Every other README suite also exited zero; the complete command/result manifest is `/tmp/clockin-review16/readme-results.json`.
- Commands lacking a module-cache path received one under `/tmp`. The skin/armour runner copies changed only artifact output locations to `/tmp`; production sources and test assertions were unchanged.
- Changed shared SwiftUI files passed syntax parsing for both platforms; changed Mac UI/menu files passed Mac syntax parsing. These are syntax checks, not whole-app typechecks.
- Additional probes: `/tmp/clockin-review16/parser-probe.log`, `state-probe.log`, and `menu-probe.log`, with their source/harnesses alongside them. The state probe used production core/coordinator code, a fake transport, and the review value type extracted unchanged except for private visibility.

No `xcodebuild`, release upload, live CloudKit call, or native app interaction was performed. Window resizing/restoration, actual sheet/alert presentation, celebration animation/hit testing, keyboard/VoiceOver tab use, and chime/radio menu layout therefore remain runtime validation limits. The offscreen icon and status probes do not establish those UI behaviors.
