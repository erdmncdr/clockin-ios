# Brief 03: first launch of Clockin 2.0 on a Mac that ran 1.1.6

Read `docs/mac-plan.md`, `docs/mac-port-inventory.md` (sections C and D) and
`docs/codex/00-inventory-result.md`. Existing Mac users will update from the old
app to the new `ClockinMac` target in place: same bundle id, same
`~/Library/Application Support/Clockin/clockin.json`, same `Backups/`, same
UserDefaults domain. This brief makes that first launch safe. Another task is
writing the Mac shell in `ClockinMac/` (app delegate, windows, menu bar) at the
same time; do not edit existing files there.

## 1. Stop rejecting a whole archive for one bad entry

Today `ClockinData.init(from:)` throws when any session or the running timer
fails validation, and `ClockStore` then copies the file aside and starts
empty. `docs/codex/00-inventory-result.md` lists 20 shapes the old Mac app can
really write that trigger this. The same will matter for sync later: one bad
record from another device must not empty the store.

Change the load path so that:

- a file that is valid JSON with the expected top-level shape loads, and only
  the entries that fail `hasValidDuration` (sessions) or
  `hasValidDuration(at:)` (running timer) are set aside;
- set-aside entries are written, untouched, to
  `clockin-quarantine-<millis>.json` next to the data file (same directory as
  the existing `clockin-unreadable-*` copies), together with a byte-for-byte
  copy of the original file as today, before anything is saved over it;
- the store shows one `statusMessage` saying how many entries were set aside
  and the file name, localized like the neighboring messages (add English and
  Turkish to `Shared/Localizable.xcstrings`);
- if the quarantine copy cannot be written, behave exactly like today's
  `mustNotOverwrite` path: load nothing and never save over the original;
- a file that is not JSON, or lacks required top-level keys, keeps today's
  behavior (unreadable copy, empty store);
- `restoreBackup` / `importBackup` get the same per-entry treatment, or, if
  that changes their contract too much, keep rejecting and say why.

Keep `ClockinData`'s strict decoder available for places that must stay
strict (for example the widget snapshot, if it decodes `ClockinData`); decide
per call site and list them. This code is shared with the iPhone app and its
widget extension; iPhone behavior changes only in that a corrupt entry no
longer empties the store.

Update `Tests/manual/maccompat/main.swift`: every "known incompatibility"
fixture should now load the valid entries, write exactly one quarantine file
containing exactly the rejected entries, keep the unreadable/original copy,
and report the count. Add fixtures for a mixed file (valid + invalid
sessions + invalid running timer) and for a quarantine write failure. Keep
the `sessions`, `backups`, `import`, `rates` and `feedback` checks passing,
changing their expectations only where the old whole-archive rejection was
the thing being asserted, and say which.

## 2. Translate old Mac preferences once

Write `ClockinMac/MacLegacyMigration.swift`: a pure, idempotent migration over
a `UserDefaults` instance, run once per version key
(`Clockin.MacMigration.v2`), that the app delegate will call before any view
reads defaults. It must:

- `Clockin.ChimeSound`: map every old NSSound name the old app offered
  (Glass, Ping, Pop, Tink, Funk, Submarine, Sosumi, and anything else in
  `../clockin-main/Sources/Clockin/FocusChime.swift`) to the closest bundled
  `FocusChimeSound` by character (bright/short vs. soft/low); explain each
  choice in one line. Keep the old value under
  `Clockin.Legacy.ChimeSound` so a downgrade could restore it.
- `Clockin.HistoryRange`: Month→M, 7D→W, 30D→M, 3M→6M, ALL→All, and keep the
  old value under `Clockin.Legacy.HistoryRange`.
- `Clockin.HeatmapRange`: translate to the new Insights heatmap keys
  (`Clockin.InsightsHeatmapDayRange` / `Clockin.InsightsHeatmapGrouping`) by
  meaning; read `Clockin/Views/Insights/*` to get the raw values right.
- `Clockin.AutoCheckUpdates` and `Clockin.UIScale`: leave them; the shell task
  ports their own migrations.
- Anything else inventory section C marks as needing a first-launch
  migration. Do not touch keys marked `same`.
- Never read another app's domain or the App Group suite.

Add `Tests/manual/macmigration/main.swift` (dependency-free, synthetic,
style of the other checks) covering each mapping, idempotence, an unknown
old value, a fresh install with no old keys, and a second run after the user
changed a value. Add its command to the README Checks block.

## 3. No replay of the archive's history

A 1.1.6 user opening 2.0 has months of work but no
`Clockin.LastCelebratedLevel` / `Clockin.SeenBadgeIDs` / wardrobe ledger. Read
`Clockin/Celebrations/CelebrationRules.swift` (`CelebrationQueue`),
`CelebrationCenter.swift`, `Shared/Mascot/Wardrobe.swift` and the nudge and
goal-prompt code, and establish, with a check, what happens on the first
refresh with a large existing archive: level-up cards, a stack of badge
banners, wardrobe unlock notices, the goal prompt, nudges. If anything
would replay, seed the baseline silently on the first Mac launch (inside the
migration above if it is Mac-specific, in shared code if an iPhone restoring
a backup has the same problem), and extend the `celebrations` check to prove
it. Existing goals (`Clockin.GoalDailyHours` / `Clockin.GoalMonthlyHours`)
count as "a goal was configured" (`Clockin.HasConfiguredGoal`).

## Rules

- Do not change `Clockin.xcodeproj`. Files in `ClockinMac/` are compiled only
  into the Mac target automatically.
- Do not edit files in `ClockinMac/` other than the one you create.
- Keep comments short, matching the file (Turkish without diacritics in files
  that already use it).
- Do not commit.

## Verification

Run every check you changed or added, plus `sessions`, `backups`, `import`,
`rates`, `feedback`, `celebrations`, `snapshot` and `maccompat`, and paste
their tails. Type-check `ClockinMac/MacLegacyMigration.swift` with the macOS
SDK and anything it needs.

## Result

Write `docs/codex/03-first-launch-result.md`: the load-path change and every
call site decision, the mapping tables with reasons, what the first refresh
does with a large archive before and after, and anything left open.
