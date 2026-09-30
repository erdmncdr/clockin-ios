Implemented all four findings from `16-double-check-result.md` on 2026-09-30. Base is this worktree's starting main commit, `023d58a5b757fbb8754a03356c0ccf3b29917453`. No release or `xcodebuild` was run.

1. **Polling recovery (P2).** `SyncCoordinator.pollIfNeeded()` suspends polling only when `pendingFirstMerge` contains a usable preview. Foreign staged data with an incomplete/failed fetch can now be fetched again by the next poll. Explicit triggers and approval revision checks retain their existing behavior. The `syncapp` fake transport incorporates the review-16 failure transition: withdraw the preview with `markFetchComplete(false)`, optionally receive a partial batch, then fail without scheduling a retry. Regressions cover a failed refresh after postponing, an incomplete first fetch, recovery by polling alone, intact/postponed preview preservation, no application/upload before approval, stale approval refusal, and polling after approval.

2. **Pasted row boundaries (P2).** Boundaries require the date/status row prefix or a weekday/date block prefix. Bare weekday/month fragments inside a source or page labels no longer split entries. `Monday`, `Monday Review`, `SundayService`, `September 15 Launch`, and `Monday September 15 Launch` remain intact in both inline and block layouts. Weekday-bearing date-range headers do not increase the skipped count. Existing malformed-middle-row, invalid-time, missing-weekday and mixed-format checks still pass; a final block truncated immediately after its date is also counted as skipped. A malformed row remains isolated from the next row's times.

3. **Approved subtotal (P2).** `TimecardParseResult` retains typed status by parsed session ID, including fallback block parsing. Its Approved subtotal sums only Approved sessions using their stored `duration`, the same duration used by the overall import total. Submitted, Draft and Unapproved rows remain importable. `TimecardImportReview` now lives alongside the core comparison types so the manual suite exercises the production deletion gate directly. It computes the Approved-total match once at review creation; the UI warning and deletion eligibility use that same result. The one-minute tolerance and skipped-row guard remain. Regressions cover all four statuses, case normalization, block parsing, overnight duration semantics, a zero Approved subtotal, a missing subtotal, genuine subtotal mismatch, tolerance boundaries, and a matching subtotal with a rejected row. The complete mixed-status fixture has zero actionable rows and one leftover, allows deletion, and removes that leftover through the real store.

4. **Review ordering (P3).** Review currency compares session values by ID, independently of array order, with exact `WorkSession` equality. Added/removed entries, changes to every stored field (including fractional time/duration/rate changes), and duplicate-ID ambiguity still invalidate review. Equal-overlap matching and exact-duplicate representative selection now use UUID tie-breaking in both preview and import, so reordering cannot change the correction or duplicate target. Regressions verify the selected IDs and actual imported changes. The `syncapp` suite also delivers a theme-only remote change through the production coordinator/bridge/store path, proves that the session array really reordered without value changes, and verifies that the existing review remains current.

The four original regressions were observed failing before their corresponding fixes. The deterministic-match and truncated-final-block checks also failed before their corrections. Evidence is in `/tmp/clockin-fixes17/`: `syncapp-red.log`, `import-parser-red.log`, `import-approved-red.log`, `import-order-red.log`, `import-tie-red.log`, and `import-truncated-red.log`. Final green evidence is the README run below. Import increased from **56 to 102** checks; syncapp increased from **52 to 62**.

The unchanged review-16 parser probe inputs were compiled against both the fixed parser and parser sources read directly from `5359c91`. All **12 CSV cases** retained baseline results, including the same header-only rejection. **12 of 13 pasted cases** have identical session signatures, ignoring generated UUIDs. Those include all reported source-name regressions and the weekday-bearing header, now with zero skipped rows. The sole intentional difference is `mixed-valid`: the fixed parser preserves both valid rows, including the block that the baseline whole-document fast path omitted. This recovery already existed at the starting commit. Probe sources, baseline copies and output are retained in `/tmp/clockin-fixes17/parser-probe.log` and the neighboring Swift files.

All **42 README Checks commands passed** on the final source. The command/result manifest is `/tmp/clockin-fixes17/readme-results.json`; each entry points to its complete log. Counts below are the suites' reported checks, or explicitly labeled output groups where the suite does not report an assertion total.

| README suite | Passing checks |
| --- | ---: |
| sync | 268 |
| sync typecheck | 2 platform targets |
| sync codec | 33 |
| sync send | 37 |
| syncapp | 62 |
| syncapp typecheck | 2 platform targets |
| wardrobe | 2,898 |
| skins | 6 groups; 396 legacy hashes, 924 HD frame/style cases |
| armorhd | 7 groups; 924 renders and 330 design/pose pairs |
| radio | 109 |
| celebrations | 125 |
| rolling | 197 |
| haptics | 61 |
| levelup | 27 |
| levelprestige | 1 group; 42 rank boundaries and 500-level identity |
| snapshot | 124 |
| import | 102 |
| backups | 38 |
| overlap | 47 |
| raterange | 9 |
| earnings | 284 |
| historytry | 87 |
| insights | 148 |
| mascot | 270 |
| companion2 | 694 |
| companion | 17 |
| momentum | 17 |
| share | 27 |
| widgettheme | 30 |
| chime | 29 |
| chimesound | 96 |
| controls | 13 |
| reminder | 44 |
| nudges | 93 |
| goals | 42 |
| sessions | 20 |
| maccompat | 375 |
| macmigration | 51 |
| rates | 84 |
| feedback | 22 |
| sessiondisplay | 61 |
| liveactivityregistry | 11 |

Both README typecheck commands passed for macOS and iOS Simulator with Swift 6 complete concurrency checking and warnings as errors. The changed import view also passed syntax parsing for both platforms. `git diff --check` passed. All added Swift comment lines are ASCII. No user-facing strings were added or changed, so `Shared/Localizable.xcstrings` is unchanged.

As in review 16, commands missing a module-cache path received one under `/tmp`. Copies of the skin/armour runners changed only artifact destinations to `/tmp`; production sources and test assertions were unchanged. The runner and logs remain under `/tmp/clockin-fixes17/`.

No requested finding remains open. Validation covers local production logic with fake sync transport, dependency-free suites and the stated typechecks. Live CloudKit recovery, native import controls and whole-app build/runtime behavior were not exercised; syntax parsing is not a whole-app typecheck.
