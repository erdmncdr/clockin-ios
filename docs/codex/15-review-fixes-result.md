# 15: Sep 30 review fixes

Base: `5a125c6` (this worktree's starting commit). All six findings from
`09-review-sep30-result.md` and the pinned Mac radio menu change are implemented.

## 1. Stale reference preview (P1)

`ImportComparisonSummary` retains the complete session snapshot used to build the
comparison. Both the initial Import action and the final destructive confirmation
compare that snapshot with the current store. A change rebuilds the review,
clears removal selections, keeps all leftovers, and returns without importing.
The inline notice says “Entries changed. Review the updated import again.”
There is no suspension between the final check and the store mutation on the main actor.

`importSessions(_:removing:)` now accepts the reviewed `WorkSession` values instead
of bare UUIDs. Before any mutation it requires every removal to still match its
current stored value, including start/end, duration, and metadata. A stale or
missing removal rejects the entire operation, including incoming additions.

Validation: import checks reproduce a reviewed entry moved to another day under
the same ID, an end-only edit, and a note-only edit. They verify refusal, an
unchanged in-memory and on-disk archive, snapshot invalidation, and successful
deletion with freshly reviewed values. The original store failed the moved-entry
regression before the fix. Native inline-notice presentation was not exercised.

## 2. Partially parsed CSV and pasted timecards (P1)

Both parsers return `TimecardParseResult` with recognized sessions and a skipped-row
count. CSV diagnostics include missing fields, unreadable timestamps, empty data
records, and an unfinished quoted record; blank lines are ignored and valid
multiline quoted fields remain supported. Counts refer to logical CSV records.

Pasted input is split at timecard row markers before parsing each entry. This
prevents a malformed row from borrowing the next row's times and avoids the old
whole-document fast path dropping otherwise readable block-format rows. A date
row missing its weekday is reported too; the page's dated range is excluded from
row detection. The existing supported English weekday/month formats remain in use.

The review displays the skipped count. If any row was skipped, leftovers start at
Keep all, the deletion picker and row actions are disabled, and the removal-ID
calculation returns an empty set. Scope changes preserve this restriction. A
pasted page whose Approved total differs by more than the existing one-minute
tolerance also cannot authorize deletions. Readable incoming rows can still be
reviewed and imported.

Validation: import checks cover an invalid middle CSV row, missing fields, CRLF,
blank versus empty data records, multiline CSV fields, unfinished/empty quoting,
malformed pasted middle rows, mixed inline/block formats, invalid times, joined
weekday/month text, and missing weekdays. They assert the count and shared
`allowsDeletions` policy. Disabled controls and the final removal guard were
source-reviewed; native interaction was not exercised. Session-display checks
continue to exercise both real parsers through the new result type.

## 3. Polling versus first merge (P2)

The timer calls `pollIfNeeded()`. This skips polling while a first-merge preview
is published or the bridge still requires first-merge review, including a
postponed review. Explicit sync/account/local-save triggers retain their existing
behavior. Approval still uses the bridge's revision checks before and after its
backup suspension; no stale-approval bypass was added.

Validation: the syncapp fake transport now models fetch-incomplete/fetch-complete
transitions. Its polling regression observes preview publications and verifies
that a poll neither fetches nor withdraws/changes the pending preview. Another
check verifies polling resumes after approval. Existing checks still reject a
stale approval after a pending preference edit. The preview-stability regression
failed with the original unguarded poll path.

## 4. Duplicate warning numbers (P2)

Near-copy matches form connected groups under the existing start/end tolerance
and overlap requirement. Each group contributes `count - 1` redundant entries.
Extra time is the sum of stored worked durations minus the group's longest
worked duration. Pairwise wall-clock intersections are no longer summed.

Validation: overlap checks cover three eight-hour copies (2 redundant entries,
16 extra hours), six-hour worked durations inside eight-hour spans, retaining the
longest worked duration, reversed input order, and independent copy groups.
Existing timecard/source/day-boundary checks continue to pass. The three-copy
regression failed with the original pairwise calculation.

## 5. Prompt re-evaluation (P2)

The prompt task identity now includes both the redundant-entry count and whether
a first merge is pending. A newly pending merge immediately withdraws an alert;
the task also clears it before checking eligibility. Completing the merge
restarts the check even if the copy count is unchanged. Cancellation and current
merge state are checked after the opening delay.

Validation: source review of both merge-state transitions and cancellation guards;
the changed SwiftUI files parse for both platform targets. Native alert/sheet
presentation remains unverified in this environment.

## 6. Daily limit (P3)

The existing persisted snooze key is set to 24 hours after the current time when
the alert is shown, before either button can be chosen. Import followed by cancel
therefore leaves the same daily limit as Later. An eligibility check suppressed
by a pending merge does not consume the daily allowance.

Validation: source review confirms the only eligibility success path persists
the deadline before presenting, and neither button nor the import sheet clears
it. Native relaunch/alert timing remains unverified in this environment.

## 7. Pinned Mac radio menu

The pinned ellipsis menu uses `.menuStyle(.borderlessButton)`,
`.menuIndicator(.hidden)`, and `.fixedSize()` under `#if os(macOS)`, keeping the
existing 44-by-44 label. The iPhone branch has no menu-style change.

Validation: two-platform Swift syntax parsing passed. Native menu rendering was
not exercised; see the full-build limitations below.

## Localization and scope

Added exactly three English keys with Turkish translations in
`Shared/Localizable.xcstrings`, using “puantaj.” A structural comparison against
HEAD confirms zero existing keys changed. The catalog was serialized with
`json.dumps(indent=2, ensure_ascii=False, separators=(',', ': '), sort_keys=True)`
and its trailing newline retained. No Mac menu-bar string keys were edited.
New Turkish comments use ASCII, matching the affected files.

## README validation

All **42 README check commands exited 0**: 40 executable suites and two
cross-platform typecheck commands. Commands were taken from the README Checks
block. Commands lacking an explicit module cache used one under `/tmp`;
`raterange` retained `TZ=Europe/Istanbul`. No README check requires xcodebuild.
The session-display README command now includes `ImportComparison.swift`, which
owns the parsers' shared result type.

Counts below are each suite's reported assertions, except where a suite reports
groups or rank boundaries instead of a scalar assertion total.

| Suite / command | Passed |
| --- | --- |
| `sync` | 268 |
| `sync-typecheck` | macOS + iOS Simulator passed (2 targets) |
| `sync-codec` | 33 |
| `sync-send` | 37 |
| `syncapp` | 52 |
| `syncapp-typecheck` | macOS + iOS Simulator passed (2 targets) |
| `wardrobe` | 2898 |
| `skins` | 6 reported check groups; 396 legacy hashes and 924 HD frame/style combinations |
| `armorhd` | 7 reported check groups; includes 924 renders and 330 design/pose pairs |
| `radio` | 109 |
| `celebrations` | 125 |
| `rolling` | 197 |
| `haptics` | 61 |
| `levelup` | 27 |
| `levelprestige` | 42 rank boundaries, plus identity/milestone/XP assertions |
| `snapshot` | 124 |
| `import` | 56 |
| `backups` | 38 |
| `overlap` | 47 |
| `raterange` | 9 |
| `earnings` | 284 |
| `historytry` | 87 |
| `insights` | 148 |
| `mascot` | 270 |
| `companion2` | 694 |
| `companion` | 17 |
| `momentum` | 17 |
| `share` | 27 |
| `widgettheme` | 30 |
| `chime` | 29 |
| `chimesound` | 96 |
| `controls` | 13 |
| `reminder` | 44 |
| `nudges` | 93 |
| `goals` | 42 |
| `sessions` | 20 |
| `maccompat` | 375 |
| `macmigration` | 51 |
| `rates` | 84 |
| `feedback` | 22 |
| `sessiondisplay` | 61 |
| `liveactivityregistry` | 11 |

Both typecheck commands use Swift 6 complete concurrency checking and warnings as
errors for macOS 14 and iOS 17 Simulator. The sync checks are offline; they do not
establish signed-device CloudKit behavior.

Additional checks: `git diff --check`, exact catalog serialization/key-scope
validation, and `swiftc -frontend -parse` for the three changed SwiftUI files on
macOS and iOS Simulator all passed. Raw suite logs and the command/result manifest
for this run are under `/tmp/clockin-review15-checks/` (temporary local artifacts).

## Remaining validation limits

No requested source fix is left open. Full application build and native UI
validation are not claimed:

- The extra unsigned Mac xcodebuild attempt failed during Sparkle dependency
  resolution because the sandbox could not resolve `github.com`; it did not
  reach application compilation.
- The extra full iOS source typecheck could not launch the SwiftUI macro plugin:
  `sandbox-exec: sandbox_apply: Operation not permitted`. This is distinct from
  the passing README core/sync typechecks and the passing SwiftUI syntax checks.
- Native stale-review notice, disabled deletion controls, merge/prompt presentation,
  Import + cancel + relaunch, and Mac menu rendering still need an interactive
  check in a build-capable environment. No distribution or live CloudKit test
  was performed.
