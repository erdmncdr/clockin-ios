# 22: Fix the findings of 21

Fix all four findings in `docs/codex/21-double-check-result.md` (probes under
`/tmp/clockin-21-review/`). Base: this worktree's start commit.

1. P1, Live Activity recovery: reconcile existing activities before requesting.
   If one already carries the desired immutable attributes, keep/update/observe
   it and end the others (and their relay registrations) without another
   request; otherwise keep one fallback while replacing, and make an
   interrupted cleanup recover on the next foreground refresh. Regressions:
   interruption right after request then recovery with requests denied;
   ordinary request failure with one old card; no duplicates left.
2. P2, notification baseline: the timer present when the detector attaches,
   successful restores, and same-start sync arrivals are remembered silently;
   only a genuinely new remote start may notify. Regressions: upgrade/load ->
   discard -> later remote edit; restore -> discard -> later remote edit.
3. P2, first merge: applies that come from approving the first merge (or any
   initial import/recovery) never notify, regardless of app state changes
   during the backup await. Carry provenance rather than an age cutoff.
4. P3, bounded history: a bounded recent set plus a persisted cutoff/watermark
   so forgotten old starts cannot notify again; prune also while the setting is
   off.

Same rules as 20: focused tests in `Tests/manual/iphonefollowsmac` (and
`syncapp` where the coordinator is involved), run every README suite that does
not need xcodebuild and report counts, keep the Mac tip behaviour identical, ASCII
Turkish comments, catalog untouched unless new text is needed. Write
`docs/codex/22-double-check-fixes-result.md`.
