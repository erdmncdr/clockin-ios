# 15: Fix the findings of 09 (and the Mac radio card menu)

Fix all six findings in `docs/codex/09-review-sep30-result.md`, which you
wrote. Base: main at the commit this worktree starts from (it now also has the
Mac bottom tabs, menu bar icon and chime card).

1. Stale reference preview (P1): the import plan must be bound to the store
   state it was computed from. If sessions changed before confirmation,
   rebuild the review and ask the user to check again instead of importing
   (short inline notice). Also make `importSessions(_:removing:)` refuse to
   delete an ID whose current start/end differ from the reviewed entry, so the
   store itself cannot delete something the user did not see.
2. Partially parsed CSV (P1): the parser must report rows it could not read.
   When any row was skipped, the review says how many and deletions are off
   (leftovers not preselected, deletion controls disabled) - absence from an
   incomplete file is not evidence. Apply the same rule to pasted timecards if
   `PastedTextImporter` can drop rows silently.
3. Polling vs first merge (P2): periodic polls must not withdraw an open
   first-merge preview. Skip poll-triggered passes while a first merge is
   pending (or keep the preview stable during a refresh); approval must still
   validate against the current revision.
4. Duplicate warning numbers (P2): count redundant entries once per group of
   copies (group size - 1) and compute the extra time from stored worked
   durations, keeping the longest entry of each group as the representative.
5. Prompt re-evaluation (P2): include the first-merge state in what triggers
   the check; withdraw the alert while a merge is pending and re-check after.
6. Daily limit (P3): record the next eligible time when the alert is shown,
   so Import + cancel does not bring it back on every launch.
7. Mac only: `Clockin/Audio/FocusRadioCard.swift` pinned-card ellipsis menu
   gets the same treatment as `CompactChimeCard`'s Mac menu (borderless,
   hidden indicator, fixed size). iPhone unchanged.

## Rules

- Tests: add focused checks to the existing manual suites (`Tests/manual/import`,
  `Tests/manual/overlap`, `Tests/manual/syncapp` or `Tests/manual/sync`) for 1
  (store-level refusal), 2, 3, 4; run every suite in README.md that does not
  need xcodebuild and report the counts.
- Strings: new user-facing text in English with Turkish translations in
  `Shared/Localizable.xcstrings` (the app says "puantaj" for timecard). Write
  the catalog with `json.dumps(indent=2, ensure_ascii=False, separators=(',', ': '))`
  and sorted keys. Another task is adding Mac menu bar strings in parallel; keep
  your catalog edits to your own keys.
- Comments follow the file's style (Turkish comments are ASCII in this repo).
- Write `docs/codex/15-review-fixes-result.md`: per finding, what changed and
  how it is tested; anything left open.
