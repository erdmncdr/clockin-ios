# Mac and iPhone

How the two apps compare. Both store sessions in the same `ClockinData` JSON format, but each keeps its own data and they do not sync.

## Shared

Timer with pause, cancel and start with elapsed time; manual entries, editing and deleting; rate schedules; USD/TRY with historical rates; earnings history with 7D, 30D, 3M and ALL; CSV and pasted timecard import with row selection; automatic backups with restore; goals; day, week and month heatmaps; reports and records; level, streaks and 46 badges; shareable stats images; the focus companion and its default mode; focus chime and focus radio; eight themes; the usage guide.

## iPhone only

- Home screen and lock screen widgets
- Live Activity and Dynamic Island, with pause and clock out
- Shortcuts and Siri actions: Clock In, Clock Out, Pause or Resume
- Companion nudges with Grumpy or Friendly tone, companion moods, and at most two daytime notifications per day
- Long session reminder with Clock out, Set end time, and Remind in 1 hour actions
- Haptics on timer actions, a celebration on the clock-out summary
- Overlap warnings in History and in the entry editor

## Mac only

These are desktop features with no direct phone equivalent; widgets, the Live Activity and Shortcuts cover the same needs.

- Menu bar status and minimal mode
- The pinned window and its five layouts
- Global keyboard shortcuts
- Interface size setting
- Update check against GitHub
- Chime sound choice and volume (iOS plays notifications at the system volume)
- History's collapsible day groups and flat session list

## Different on purpose

| | Mac | iPhone | Why |
|---|---|---|---|
| Level | Goals add XP, and changing a goal rescores the archive | Only hours and streaks add XP; goal badges use fixed thresholds (8- and 10-hour days, 100-hour months) | A goal lowered to a few minutes should not raise the level |
| Restore | Replaces the data | Saves the current data as a backup first, so a restore can be undone | |
| Failed save | Reported | Rolled back in memory as well | Nothing unsaved stays on screen |
| Daily goal estimate | "N days away" | A clock time | For a daily goal the Mac's count can only be 1 |
| 30-day trend | Last 30 × 24 hours | Last 30 calendar days | Matches History's 30D |
| Focus chime | Timer inside the running app | Local notifications scheduled from worked time | An iPhone app is usually suspended |
| Chart selection | Drag to scrub, hover for details | Tap a day | Dragging over the chart blocked scrolling History |
| Widget theme | Not applicable | Widgets and the Live Activity follow the app theme | |

## Shared logic

`Shared/Core` started as a copy of `../Sources/Clockin`. Fixes to the store, models or importers have to be made in both places:

```bash
diff ../Sources/Clockin/ClockStore.swift Shared/Core/ClockStore.swift
```

## Open Mac issues

Found while comparing the apps and still present in the Mac sources. None of them affect the iPhone app unless noted.

1. **Non-USD history chart.** The chart's toggle, labels and TRY conversion assume USD, so an EUR, GBP or TRY account sees mislabeled amounts (`HistoryView.swift`).
2. **Competing import matches.** When two incoming rows match the same entry, the preview calls the second one new, but importing silently skips it instead of trying the next best match (`ClockStore.swift`). Shared with iPhone.
3. **Backup wording.** Settings says backups are "Created automatically before each save"; they are made at most once a day.
4. **Editor edge cases.** The duration preview ignores a preserved break, and an overnight end adds a fixed 24 hours, which is off by an hour across a DST change (`ManualEntryView.swift`). Shared with iPhone.
5. **Rate change during a session.** A running session is priced at today's rate, a saved one at its start date's rate, so a session crossing a rate change can change value at clock-out. Shared with iPhone.
6. **Money milestone.** At exactly 10, 20 and so on, the target shows zero to go while the progress bar resets to empty (`MainView.swift`).
7. **Radio state.** "Playing" is set as soon as playback is requested, so a dead stream still looks on (`RadioController.swift`).
8. **Heatmap refresh.** The heatmap refreshes on a 20-second timer and on session count, so an edit that keeps the count can show stale values for a while (`HeatmapView.swift`).
9. **Update check interval.** The last check time lives only in memory, so restarts and failures can check more often than every six hours (`UpdateChecker.swift`).
10. **Unused code.** `MainView.settingsSection` and `ShareStatsCard` are never shown.
