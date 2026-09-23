# Mac and iPhone

How the two apps compare. Both store sessions in the same `ClockinData` JSON format, but each keeps its own data and they do not sync.

## Shared

Timer with pause, cancel and start with elapsed time; manual entries, editing and deleting; rate schedules; USD/TRY with historical rates; earnings history with a calendar month starting on the 1st; CSV and pasted timecard import with row selection; automatic backups with restore; goals; day, week and month heatmaps; reports and records; level, streaks and 46 badges; shareable stats images; the focus companion with drawn clips, smooth motion, tap reactions and default modes; focus chime and focus radio; eight themes; the usage guide.

Both apps offer Radio Paradise (Main Mix), Mellow Mix, Global Mix and Serenity
with matching station ids and names.

## iPhone only

- Home screen and lock screen widgets, with a companion still in the medium Home screen widget
- Live Activity and Dynamic Island, with pause and clock out
- Shortcuts and Siri actions: Clock In, Clock Out, Pause or Resume
- iOS 18 controls for clock in/out and pause/resume in Control Center, Lock Screen slots, and the Action Button on supported iPhones
- Companion nudges with Grumpy or Friendly tone and at most two daytime notifications per day
- Tired idle mood after two quiet calendar days (including a streak broken yesterday), with existing Grumpy anger taking priority; four-second proud mood for levels, badges, daily goals and saved sessions longer than two hours
- Layered wardrobe with permanent milestone ownership at 25/50/100/250 completed hours, coin purchases, migrated accessory choices and Companion navigation
- Companion home in desk mode and matching layered medium-widget mood/outfit stills
- Finite standing sway bursts with animation-free rests, slower tired motion, and shared Reduce Motion, visibility, power and thermal gates
- Long session reminder with Clock out, Set end time, and Remind in 1 hour actions
- Haptics on timer actions, a celebration on the clock-out summary
- Companion level-up overlays with Share and finite confetti, queued badge-unlock banners, and brief goal, money, streak and session reactions; persisted progress, Reduce Motion and companion-off variants
- Overlap warnings in History and in the entry editor
- Desk mode: a full-screen timer in landscape that keeps the screen on while a session runs

## Mac only

These are desktop features with no direct phone equivalent; widgets, the Live Activity and Shortcuts cover the same needs.

- Menu bar status and minimal mode
- The pinned window and its five layouts
- Global keyboard shortcuts
- Interface size setting
- Update check against GitHub
- History's collapsible day groups and flat session list

## Different on purpose

| | Mac | iPhone | Why |
|---|---|---|---|
| Level | Goals add XP, and changing a goal rescores the archive | Only hours and streaks add XP; goal badges use fixed thresholds (8- and 10-hour days, 100-hour months) | A goal lowered to a few minutes should not raise the level |
| Restore | Replaces the data | Saves the current data as a backup first, so a restore can be undone | |
| Failed save | Reported | Rolled back in memory as well | Nothing unsaved stays on screen |
| Daily goal estimate | "N days away" | A clock time | For a daily goal the Mac's count can only be 1 |
| 30-day trend | Last 30 × 24 hours | Last 30 calendar days | Insights keeps its rolling comparison independently of History |
| Focus radio controls | Play/stop and station picker in Settings; stop before playing a different station; selection lasts while Settings stays open | Remembers the station and switches immediately while playing; Today card with station menu, play/pause and stop; Lock Screen resume while paused; stop clears Now Playing | Volume stays in Settings on both apps |
| Focus chime | Timer inside the running app, macOS system sounds and volume | Original bundled sounds; local notifications scheduled from worked time; selected volume only while Clockin is open | Background notifications use the iOS system volume |
| History ranges | This month (default), rolling 7D, 30D, 3M, ALL | Pageable calendar W, M (default), 6M; nonpageable All | iPhone remembers the range, reopens on the current period, and filters totals and sessions by page; 6M has monthly bars |
| Chart selection | Drag to scrub, hover for details | Tap a day (month in 6M); horizontal swipe or chevrons to page | Direction-checked paging allows vertical History scrolling |
| Month performance | This month totals and averages | Worked-day averages, cumulative hours, dashed current goal, same-point previous month comparison, current-month projection | Projection shares Insights' completed-work 7-day pace; past months show final numbers |
| Goal reminder | No matching onboarding card | After first completed session, Set goals opens and focuses the Insights editor; Not now snoozes 7 days | Permanently hidden once any goal has been configured, even if later turned off |
| Widget theme | Not applicable | Widgets and the Live Activity follow the app theme | |

## Shared logic

`Shared/Core` started as a copy of the Mac app's `Sources/Clockin`, which lives in
its own repository (see `NOTICE.md`). Fixes to the store, models or importers have
to be made in both places. With the Mac app checked out next to this repository:

```bash
MAC=../clockin-main
diff "$MAC/Sources/Clockin/ClockStore.swift" Shared/Core/ClockStore.swift
```

The companion motion engine started as a copy. iPhone now adds tired/proud moods,
frame fallbacks and a finite sway schedule. Port relevant common fixes deliberately;
do not overwrite the platform-specific behavior:

```bash
diff "$MAC/Sources/Clockin/MascotMotion.swift" Shared/Mascot/MascotMotion.swift
```

## iPhone wardrobe, focus coins and companion home

The iPhone has a layered outfit with head, face, neck, back, hand and colorway slots,
a Companion screen (Outfit / Home / Shop), deterministic archive-derived focus
coins, milestone ownership, confirmed purchases and room/furniture placement.
Today's companion opens this screen; its text row opens Insights. Badges and
Settings also link to Companion. Landscape desk mode can show a dimmed home.

Ownership and purchases live in `Clockin.Wardrobe*` UserDefaults, not ClockinData.
The four original accessory thresholds and stored selection migrate. Widget and
celebration companions share the composition. Exported/automatic iPhone backups
carry an optional `wardrobe` JSON section; Mac archive schema and Mac behavior are
unchanged. Older backups without the section preserve the iPhone's wardrobe.
