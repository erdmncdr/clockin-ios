# iOS 0.2 (15): Goals & Pace

Entry: Insights → Goals & Pace. Existing daily/monthly goals remain the source of
truth. A new local `Clockin.WorkdaysPerWeek` preference requires a choice of 1–7;
there is no assumed weekday schedule. The user explicitly requested a count,
not individual weekday selection.

## Calculation contract

- Work is assigned to session start dates, consistent with the existing app.
  Active elapsed time is included; pause elapsed time does not grow.
- Remaining workdays are an estimate: ceil(remaining calendar days including
  today × weekly days / 7). Today is treated as a possible workday. This is
  explained in the UI; the app cannot know actual days off from a weekly count.
- Full-day recommendation distributes the outstanding target plus today's
  already completed work over those days. Once today's work exceeds that target,
  distribute just the remaining hours over subsequent estimated workdays.
- Apply rounds up to a quarter hour. Targets above 24 hours are never offered;
  instead the UI suggests revising the month goal or schedule. No automatic goal
  changes. The existing daily target, badges and history semantics remain intact.
- Actual-pace forecast uses at most seven finished calendar days before today,
  starting no earlier than the first recorded work. Zero-work days are included.
  Divide by the expected workday equivalents (sample days × weekly days / 7).
  Today's actual hours count toward progress, not the finished-day sample.
- Forecast credits actual progress, adds any expected remaining hours today,
  then the expected future estimated workdays. Forecast is independent of the
  saved daily goal; a separate figure previews that goal's outcome.
- No history or only today's work: no fabricated forecast. A short sample is
  marked as an early estimate. Seven quiet days predict no additional work.
- Pure Foundation calculation, calendar arithmetic for month lengths/DST,
  finite positive inputs, future entries excluded. All processing is on device.

## UI

Monthly progress, workday picker, shared goal fields, a daily recommendation with
an explicit Apply button, conditional encouragement, cumulative actual/forecast
chart with monthly target, and daily bars with the saved daily goal. All use the
existing theme, card styling and adaptive metric layouts. Updates once a minute
and on store/settings changes. The obsolete monthly estimate in the Insights
summary is removed; History retains its separately explained historical model.

## Verification

- 28 planning checks pass; existing 42 goal checks pass.
- Release uses companion-art UI with owned changes merged by the release script.
- Signed Release archive succeeds; app and widget are 0.2 (15), deep strict
  codesign verification succeeds and all 334 source manifest hashes match.
- Device interaction and visual acceptance remain unverified: the computer-use
  tool cannot access Simulator in this session. Do not infer UI proof from build.
- Check on device: change weekly days, decimal goals and Apply; start/pause/stop
  a session; inspect both charts and Dynamic Type; revisit the page after edits.

## Distribution

Archive: `/tmp/clockin-goals-pace-15-final/Clockin.xcarchive`.
TestFlight upload succeeded on 2026-09-21 at 14:04 Europe/Istanbul.
Build ID: `3dbfadd3-533e-42c1-97d7-8cd98412fb1c`. English and Turkish notes saved;
automatic tester notification enabled at submission. Verified **Testing** on
the Clockin Public Beta and Clockin Internal group Builds pages on 2026-09-21.
