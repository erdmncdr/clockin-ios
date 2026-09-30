# 17: Fix the findings of 16

Fix all four findings in `docs/codex/16-double-check-result.md` (you wrote
it; probes are under `/tmp/clockin-review16/`). Base: main at this worktree's
start commit.

1. Polling (P2): skip polls only while a usable first-merge preview is waiting
   for review; when review is needed but no preview can be published (fetch
   incomplete/failed), polls must fetch again so the preview comes back.
   Regression in `Tests/manual/syncapp` using your failed/incomplete fetch
   transport.
2. Pasted parser (P2): detect entry boundaries from the row grammar, not from
   any weekday/month fragment. Source names like "Monday", "Monday Review",
   "SundayService", "September 15 Launch" must parse as before; date-range
   headers with weekdays must not count as skipped rows; keep isolating a
   malformed row so it cannot borrow the next row's times. Regressions in
   `Tests/manual/import` and keep `Tests/manual/sessiondisplay` passing; compare
   against the `5359c91` parser on your probe inputs.
3. Approved subtotal (P2): keep parsed status; compare the page's Approved
   total only with parsed Approved rows (same duration semantics). A complete
   mixed-status paste with zero skipped rows must allow deletions. Keep the
   skipped-row guard.
4. Review ordering (P3): compare reviewed sessions independent of array
   order (e.g. by id -> value), still exact on every field of each session.

Same rules as 15: focused tests, run every README suite that does not need
xcodebuild and report counts, new strings (if any) with Turkish in the
catalog using the usual serialization, ASCII Turkish comments. Write
`docs/codex/17-double-check-fixes-result.md`.
