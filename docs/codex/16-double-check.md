# 16: Double-check before Mac 2.0.6 / iOS 0.2 (51)

Review `git diff 5359c91..048a55f` (source only; docs are context) as a fresh
reviewer. It contains the Mac UI changes (menu bar icon, bottom tabs in
`MacRootView`/`MacTabBar`, the Mac chime card, the menu bar details switch) and
the fixes for your 09 findings (stale import preview, partial parse, polling vs
first merge, duplicate counts, prompt re-evaluation, daily limit, radio menu).

Look for regressions the fixes may have introduced and anything the UI changes
break on either platform:
- import: can a valid, complete file now be refused, or can the user end up
  unable to import at all (e.g. the snapshot compare failing because of a
  harmless change such as a running session, a rate edit or a sync of an
  unrelated field)? Is `reviewedSessions` compared in a way that is stable
  (ordering, floating-point dates)?
- parsers: any file that used to import correctly and now reports skipped rows
  or different sessions (header-only lines, trailing commas, BOM, CR-only, the
  pasted formats in `Tests/manual/sessiondisplay` and `Tests/manual/import`)?
- polling: can sync stall permanently (poll skipped forever) after a postponed
  or failed first merge?
- Mac UI: `MacRootView` without the split view - sheets, celebration overlay,
  `nudges.openToday`, reminders, Settings navigation, window restoration;
  `MenuBarHost` details switch with idle/running/paused; the chime/radio card
  `#if os(macOS)` branches.

Same rules as 09: no source edits; probes under `/tmp`; run the README suites
that do not need xcodebuild. Write `docs/codex/16-double-check-result.md`
(most severe first, file:line, scenario, fix), or say plainly that you found
nothing that should block the release.
