# 37: Review: History and Reports weeks run Monday to Sunday

Read-only review of the uncommitted working tree (`git diff HEAD`, plus the renamed
`Clockin/Views/Insights/CalendarWeek.swift`). Do not edit files.

Until now History's "Week" range and Reports' weekly cells used month-bounded slices
(days 1–7, 8–14, 15–21, 22–28, then the rest of the month; `MonthWeek`). The owner wants
ordinary calendar weeks that start on Monday on every device, whatever the device's
first weekday. The change:

- `CalendarWeek.interval(containing:calendar:)` replaces `MonthWeek`: Monday 00:00 to
  the next Monday 00:00 in the given calendar (DST-aware through `Calendar` arithmetic).
- `EarningsPeriod` (History paging, titles, `isCurrent`) and `InsightsPeriods.buckets`
  (Reports weekly heatmap) use it. Weeks now cross month and year boundaries.
- Two user-facing strings changed in `UsageGuideView` and
  `InsightsAggregateHeatmapView`, with Turkish values in `Shared/Localizable.xcstrings`.
- Tests updated: `Tests/manual/earnings` (227), `insights` (148), `crashaudit` (206).

Check for: anything else that assumed a week never leaves its month (month totals,
`MonthPerformance`, `EarningsSnapshot.calendarDays`, chart axes, the "6 months" range,
Mac keyboard paging, widgets, the Mac guide text); week paging near DST and year
boundaries; `firstWeekday` leaks (should be Monday regardless); leftover wording that
still describes the old slices in Swift, string catalog, README or user docs (release
records are history and stay). Report findings with file and line; say "no issues" per
area if clean. No Codex/Claude names in anything you write.
