# Brief 00 result: Mac inventory and data compatibility

Completed 2026-09-29 in `clockin-mac-inventory`.

## Produced

- [`../mac-port-inventory.md`](../mac-port-inventory.md): English inventory of all **176** Swift files under Clockin, Shared and ClockinWidgets (112 as-is, 41 guard, 10 ios-only, 13 mac-rewrite); all **84** old Mac files (41 Swift, 43 resources); non-Swift resources; every old Info.plist key; **80** concrete UserDefaults keys with migration and sync/device classification; behavior changes, writer-path audit and proposed phase 1 seams.
- [`../../Tests/manual/maccompat/main.swift`](../../Tests/manual/maccompat/main.swift): dependency-free synthetic compatibility check. Exact private/renamed copies of the four archived Mac structs and two old parsers; no production Swift changes. Eleven accepted fixtures exercise field-preserving decoding/loading/saving/downgrade and one-time missing-rate migration. Twenty expected rejection fixtures demonstrate incompatible Mac-writable shapes; nonfinite-value assertions distinguish encoder failure from saved JSON.
- [`../../README.md`](../../README.md): one compile/run command added immediately after sessions in the Checks block.

Read `docs/mac-plan.md` first. Only this worktree and the read-only `../clockin-main` were inspected. No real user's clockin.json was opened. No existing Swift file, Xcode project or old Mac file was edited; no commit was made. The pre-existing `docs/codex/00-inventory.md` brief was left alone. The phase 0 checkbox remains unchanged: this brief is synthetic-only and there is no production-data or native-Mac validation yet.

## Verification

All four checks completed with exit status **0** from the worktree root. Commands use the README source lists and Swift 6 compiler. To keep explicit scratch writes inside this worktree, their `/tmp/` binary paths were relocated to `$PWD/.build/mac-inventory/`; `TMPDIR`, `CLANG_MODULE_CACHE_PATH`, `SWIFT_MODULECACHE_PATH` and an explicit `-module-cache-path` also pointed under that directory. These are path-only changes, not alternate source lists or skipped assertions. No xcodebuild target build was run. Initial Swift toolchain discovery emitted a cache-location diagnostic naming xcodebuild; no Xcode build command was issued.

Reproduce the same worktree-local execution with this wrapper (or use the normal commands in README):

```bash
mkdir -p .build/mac-inventory/tmp .build/mac-inventory/cache
python3 - <<'PY'
from pathlib import Path
import os, subprocess
out = Path.cwd() / '.build/mac-inventory'
env = os.environ.copy()
env['TMPDIR'] = str(out / 'tmp')
env['CLANG_MODULE_CACHE_PATH'] = str(out / 'cache')
env['SWIFT_MODULECACHE_PATH'] = str(out / 'cache')
for name in ['maccompat', 'sessions', 'backups', 'import']:
    command = next(line for line in Path('README.md').read_text().splitlines()
                   if line.startswith('swiftc ') and f'Tests/manual/{name}/main.swift' in line)
    command = command.replace('/tmp/', str(out) + '/')
    command = command.replace('swiftc ', f'swiftc -module-cache-path {out / "cache"} ', 1)
    with (out / f'{name}.log').open('w') as output:
        result = subprocess.run(command, shell=True, env=env, stdout=output, stderr=subprocess.STDOUT)
    print(name, 'exit', result.returncode)
    print('\n'.join((out / f'{name}.log').read_text().splitlines()[-9:]))
    if result.returncode:
        raise SystemExit(result.returncode)
PY
```

### maccompat: exit 0

```text
ok: negative-infinity date: old default encoder rejects before disk write
ok: unvalidated-rate-fields: decoder preserves every Mac field
ok: unvalidated-rate-fields: store loads without unreadable copy
ok: unvalidated-rate-fields: present rateRules stays unchanged, including empty array
ok: unvalidated-rate-fields: initialization does not rewrite scheduled archive
ok: unvalidated-rate-fields: store save is lossless for downgrade decoder
ok: unvalidated-rate-fields: second launch does not repeat rate migration
ok: unvalidated-rate-fields: save and reopen leave no unreadable copy
171 maccompat checks passed; known decoder incompatibilities reproduced, not fixed
```

### sessions: exit 0

```text
ok: the per-second rate shown matches the rate the session earns
ok: clocking out does not change what the session earned
ok: both rows are previewed as corrections
ok: the second row falls back to the next best entry the first did not take
ok: importing corrects both entries without adding one
ok: each entry takes the times of the row it was previewed with
ok: the second writing of a correcting row is previewed as a duplicate
ok: and importing does not add it as new work once the entry is taken
20 session checks passed
```

### backups: exit 0

```text
ok: failed clock out preserves the running session without phantom history
ok: relaunch cannot resurrect a session that the screen claimed was stopped
ok: failed pause does not claim the timer is paused
ok: failed cancellation does not hide a persisted timer
ok: failed resume keeps the persisted paused state
ok: clock out succeeds once storage recovers
ok: successful clock out stays stopped after relaunch
ok: failed start does not create a memory-only timer
38 backup checks passed
```

### import: exit 0

```text
ok: new rows and corrections are both selectable
ok: everything selectable is selected by default
ok: leaving out a correction still imports the selected new row
ok: a correction that was left out does not touch the timer entry
ok: a new row that was left out is not added
ok: the in-file twin is previewed as a duplicate
ok: leaving out a row does not let its duplicate through instead
ok: nothing is imported when the only real row was left out
26 import checks passed
```

Additional audit verification: exact path-set comparison found all 176 requested Swift files once, with no extras; every one of the 84 old files has exactly one row. Four Mac model copies were compared to old declarations after only permitted type-name/access changes: all exact. `git diff --check` passed. No SwiftUI compilation or macOS 14 SDK availability claim is inferred from Foundation checks.

## Confirmed compatibility and surprises

- Accepted fixtures: pre-schedule file truly omitting rateRules; scheduled TRY/pinVisible; active and paused timer; actual old-CSV-imported and matched local sessions with provenance; empty scheduled and pre-schedule archives; zero duration; worked duration exceeding wall span; odd rate fields. Default JSON date strategy round-trips, every model field is structurally compared, and every saved archive re-decodes using old Mac models.
- Missing rateRules causes the same July 1, 2026 base-rate migration as old Mac. Explicit empty `[]` and existing schedules stay unchanged. Reopening preserves migrated rule ids; there is no repeated migration. Nil properties in Mac's synthesized encoder are omitted; hand-authored null also decodes nil, so “missing only” means missing versus present arrays in Mac-produced fixtures.
- Invalid input is an **archive-wide** failure. For every expected rejection, the current store creates exactly one byte-identical `clockin-unreadable-*.json`, reports failure and presents empty history/no running timer. This is not a safe transparent import. Passing this test means the risk is reproduced, not resolved.
- Old CSV can write a finite duration above 100 years. Both old CSV and pasted-text importers accept an explicit year 5000 even though current session date validation rejects it. These are external-input paths, not merely arbitrary model construction.
- Backwards system clock plus clock-out/resume creates end-before-start or resume-before-start. Negative accumulated requires supplied malformed backup/previous malformed archive; normal clockIn clamps negative elapsed and normal pause arithmetic cannot create it from valid state.
- NaN/infinity are not emitted by old default JSONEncoder. Negative CSV duration falls back to measured time. Positive infinity may hit the old Int dedup conversion before encoding, so it is not reported as successfully saved Mac JSON.
- `ClockStore.defaultFileURL` matches the old location, but current SharedStore explicitly uses AppGroup and migration. Mac needs its branch before launch. Language also currently uses group-suite defaults. A matching default path alone is not proof of in-place operation.
- `WardrobeArt.swift` already conditionally imports UIKit and compiles without it, yet fixed-pose loading returns nil on Mac. A compile-only check would miss absent art.
- `Clockin.ChimeSound` and `Clockin.HistoryRange` are same-name/different-value preferences. Only Glass has an implemented legacy sound mapping; even old Pop otherwise falls back to the default chime. Persisting new history raw values also affects downgrade preferences.
- PARITY's failed-save statement is broader than actual implementation: session/timer changes roll back, but several direct rate/currency/pin setters still do not. Existing applyRateHistory rollback already exists in both apps.

## Rejected Mac data: executed fixtures

All rows below printed a KNOWN INCOMPATIBILITY line, passed old encode/decode, failed current ClockinData decoding, and passed current store's unreadable-copy/empty-state assertions. Refer to inventory section F for the complete writer-path audit and UI/API reachability distinctions.

| Fixture | Old code path from executed check | Result |
|---|---|---|
| `clock-out-after-clock-rollback` | Mac ClockStore.swift:192-202 clockOut | Rejected; preserved unreadable copy; empty store. |
| `resume-before-start` | Mac ClockStore.swift:183-188 resume | Rejected; preserved unreadable copy; empty store. |
| `csv-over-100-years` | Mac CSVImporter.swift:38-39 -> ClockStore.swift:553-610 importSessions | Rejected; preserved unreadable copy; empty store. |
| `csv-correction-over-100-years` | Mac ClockStore.swift:595-599 matched row | Rejected; preserved unreadable copy; empty store. |
| `csv-out-of-range-date` | Mac CSVImporter.swift:34-35 -> ClockStore.swift:428-433/553-610 | Rejected; preserved unreadable copy; empty store. |
| `pasted-out-of-range-date` | Mac PastedTextImporter.swift:31-35/105-122 -> ClockStore.swift:439-442/553-610 | Rejected; preserved unreadable copy; empty store. |
| `clock-in-over-cap` | Mac ClockStore.swift:158-168 clockIn; API/system-date boundary | Rejected; preserved unreadable copy; empty store. |
| `pause-over-cap` | Mac ClockStore.swift:175-180 pause after long elapsed/system-clock jump | Rejected; preserved unreadable copy; empty store. |
| `manual-over-cap` | Mac ClockStore.swift:212-232 addManualSession API; UI usually one day | Rejected; preserved unreadable copy; empty store. |
| `edited-over-cap` | Mac ClockStore.swift:522-544 updateSession; oversized imported duration retained on note edit | Rejected; preserved unreadable copy; empty store. |
| `clock-out-over-cap` | Mac ClockStore.swift:192-202 clockOut after forward clock jump | Rejected; preserved unreadable copy; empty store. |
| `restore-over-cap` | Mac ClockStore.swift:458-466 importBackup | Rejected; preserved unreadable copy; empty store. |
| `restore-negative-running` | Mac ClockStore.swift:458-466 importBackup of supplied JSON | Rejected; preserved unreadable copy; empty store. |
| `load-and-resave-negative-duration` | Mac ClockStore.swift:51-53 load then 419-422 updateCurrency; requires preexisting malformed file | Rejected; preserved unreadable copy; empty store. |
| `direct-import-negative-duration` | Mac ClockStore.swift:553-610 importSessions API; CSV parser itself falls back to measured duration | Rejected; preserved unreadable copy; empty store. |
| `before-distant-past` | Mac ClockStore.swift:212-232 / 522-544 / 458-466: no date bounds in add/edit/restore | Rejected; preserved unreadable copy; empty store. |
| `after-distant-future` | Mac ClockStore.swift:212-232 / 522-544 / 458-466: no date bounds in add/edit/restore | Rejected; preserved unreadable copy; empty store. |
| `restore-out-of-range-running-date` | Mac ClockStore.swift:458-466 restore has no running validation | Rejected; preserved unreadable copy; empty store. |
| `resume-out-of-range-date` | Mac ClockStore.swift:183-188 resume / 458-466 restore | Rejected; preserved unreadable copy; empty store. |
| `running-elapsed-over-cap-at-read` | Mac clockIn then passage of time/system-clock jump; current Models.swift:135 validates at wall-clock now | Rejected; preserved unreadable copy; empty store. |

The old AppKit ClockStore was read, not compiled/executed. Store-path fixtures encode the audited resulting model state; the old CSV/pasted parsers actually execute as exact renamed copies. `manual-over-cap`, direct negative import and extreme clockIn argument are store-API cases, not assertions that normal UI controls allow those values. `load-and-resave-negative-duration` and negative running restore require malformed supplied JSON. Date-bound and oversized restore fixtures are accepted by the old restore guards. JSON key compatibility does not imply preference/wardrobe downgrade parity: old code ignores wardrobe backup extras and can drop them when rewriting/exporting.

## Open decisions for the next brief

1. **Rejecting real Mac-writable archives is unresolved.** Choose a reviewed recovery/migration policy before release (preserve original plus explicit repair/review, or a deliberately compatible reader). This brief makes no decoder/store fix and does not silently clamp/delete sessions.
2. Decide legacy NSSound mapping versus retaining Mac system sounds, and approve the proposed history-range and heatmap preference translations. All user choices, including sounds/theme, are sync-class; frames/interface size/token/cache/setup state stay local.
3. Decide first-launch language for old English-only Mac users. Preserve old goal choices and seed onboarding/celebration markers without replaying the archive. Radio volume needs a future persisted key if it is to follow the user; neither current app persists it.
4. Verify marked SwiftUI availability uncertainties in the real macOS 14 target; implement AppKit hosts and test asset loading, hover/keyboard/sheet/window behavior. Full parity requires every Mac-only feature in section D, including collapsed/flat history.
5. Later validate an authorized real-data copy and a signed update-in-place rehearsal. This task's synthetic checks prove schema behavior only; no native app, release, Sparkle delivery or CloudKit sync was exercised.
