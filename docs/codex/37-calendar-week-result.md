# 37 result: weeks run Monday to Sunday

Review of the working tree that replaced the month-bounded "week" slices with calendar
weeks starting on Monday (`CalendarWeek`, used by History's Week range and Reports'
weekly cells).

Findings:

1. Midnight DST transitions (for example America/Santiago, 6 September 2026) made
   `startOfDay` return 01:00, and subtracting days kept that hour, so a week ran
   31 August 01:00 to 7 September 01:00. History's paging round trip then returned a
   different interval and Reports split one week into two cells. Fixed: both Monday
   boundaries are normalized with `startOfDay` after the day arithmetic. Regression in
   `Tests/manual/earnings`: every September 2026 day in America/Santiago keeps start-of-day
   Monday boundaries, seven calendar days, and a paging round trip; the check fails
   against the unfixed code.
2. A comment in `InsightsPeriods.buckets` still described the month-bounded slices.
   Rewritten.

Clean areas: month totals and `MonthPerformance`, `EarningsSnapshot.calendarDays`,
chart axes, the 6-month range, year boundaries and titles, `firstWeekday` (Monday is
fixed explicitly), Mac keyboard paging, widgets, the Mac guide text, the changed
English and Turkish strings, README and user docs.

Verification after the fix: earnings 287, insights 148, crash audit 206; Mac and iOS
Debug builds.
