# Brief 03 result: safe first launch from Mac 1.1.6

Completed 2026-09-29. No commit. No Xcode project changes and no edits to existing `ClockinMac/` files. The only new Mac source is `MacLegacyMigration.swift`. All archives and defaults used by the checks are synthetic; no production archive or other app's defaults domain was opened.

## Load and preservation

`ClockinData.init(from:)` remains strict. `ClockinArchive.read(_:at:)` shares its structural decoder, then partitions sessions by `hasValidDuration` and the running timer by `hasValidDuration(at:)`. It does not clamp, repair, deduplicate or reinterpret records. The store passes its injected clock for running-timer validation.

On a partially invalid archive, `ClockStore.init` now:

1. Decodes the required archive shape (`hourlyRate`, `currencyCode`, `sessions`, `pinVisible`; `running` and `rateRules` remain optional).
2. Writes the original input bytes to `clockin-unreadable-<millis>.json` beside `clockin.json`.
3. Writes `clockin-quarantine-<same millis>.json` beside it. Its shape is `{"sessions":[rejected entries],"running":rejected timer or null}`. Only rejected entries appear, in their original order. Their JSON value bytes are copied verbatim, including unknown fields, whitespace, escaped strings, large integers and numeric spelling. A small slicer runs only after structural decoding; values are not round-tripped through model encoding or `JSONSerialization`.
4. Publishes only valid entries, preserves the profile/pin/rate schedule, performs the existing missing-rate migration if needed, and saves the recovered archive. Saving even when rates were already present prevents another quarantine on the next successful launch.
5. Shows one localized status: “N invalid entries were set aside in filename. The original file was also kept.” English and Turkish entries were added to `Shared/Localizable.xcstrings`.

Both safety files must succeed before any replacement save. Names advance past existing unreadable/quarantine names, and new-file writes refuse to overwrite an existing file. Failure of either preservation write leaves the store empty and the original untouched. `mustNotOverwrite` is now a stored guard on **every `save()`**, rather than a local initializer flag. Rate initialization and later timer/currency writes cannot bypass it. Reopen after storage is repaired to retry recovery; the injected quarantine-write failure fixture verifies this flow. Existing safety copies are never pruned by this recovery path.

Non-JSON, missing required top-level keys, wrong field types or structurally undecodable records retain the existing whole-file unreadable-copy/empty-store behavior. This is duration/date recovery, not a new arbitrary-schema repair policy. Ambiguous duplicate top-level keys are not recovered when raw entry extraction is required. Archives emitted by the old default `JSONEncoder` use the UTF-8 format exercised here.

The byte-identical original copy is distinct from the normal `Backups/` copy, which can include wardrobe metadata. `Backups/`, the July 1, 2026 missing-rate migration and the existing archive format are unchanged.

## Decoder call-site decisions

| Call site | Decision and reason |
|---|---|
| `ClockStore.init` | Recovery reader; one invalid duration must not discard valid work. Both preservation writes gate publication/save. Shared by Mac and iPhone. |
| `ClockinData.init(from:)` | Strict by default, including any future direct `JSONDecoder.decode(ClockinData.self, ...)` caller. The unchecked initializer is file-private and used only by the recovery wrapper. |
| `ClockStore.restoreBackup(from:)` | Strict. This operation replaces the entire current archive, including optional wardrobe data, and its preview/list currently promises a complete backup. Partially applying it would silently change that contract. A recovery preflight detects invalid durations/dates and returns a specific localized explanation that nothing was restored and a complete valid archive is required. Neither file nor wardrobe is changed. |
| `ClockStore.importBackup(from:)` | Delegates to strict restore; same explanation and no mutation. |
| `ClockStore.restoreLatestBackup()` | Selects from `readBackups`, then delegates to strict restore. |
| `ClockStore.readBackups(in:)` | Strict `ClockinData` decoder. Invalid backups remain visible with `sessionCount == nil` / `isReadable == false`, consistent with the restore contract. |
| `ClockinSnapshot.read(from:)` / snapshot decoder | Unchanged. Decodes **`ClockinSnapshot`**, not `ClockinData`; it has its own widget schema. No recovery writes are introduced into snapshot reads. |
| `AppGroup.migrateLegacyDataIfNeeded()` / `SharedStore.clock` | No additional decoder. iOS byte-copy routing is unchanged; the store handles recovery. The existing Mac `AppGroup` branch already keeps Release data in Application Support/Clockin and skips group migration (Debug uses Clockin Debug). |
| CSV/pasted/session import | No `ClockinData` archive decode; existing per-session validation and reconciliation stay unchanged. |
| Manual compatibility checks | Direct `ClockinData` decode still must throw `dataCorrupted` for all 20 old incompatibilities. Store assertions now require selective recovery instead of an empty archive. |

There are no other production direct `ClockinData` decode call sites in this checkout. Future sync can use `ClockinArchive` for archive-shaped input but must retain the preservation gate; this change does not implement sync record handling.

## One-time Mac preferences

Shell integration API:

```swift
MacLegacyMigration.migrate(in: .standard)
```

Call it before initializing views, `SharedStore.clock` / `SessionMirror`, `CelebrationCenter`, or focus-chime controllers. The latter can run their own sound normalization; calling this first retains the old NSSound choice. The shell task owns this wiring. No existing Mac app/delegate file was edited.

The function operates only on the passed `UserDefaults`, writes `Clockin.MacMigration.v2` last, and becomes a no-op afterward. It never opens a suite/domain itself, reads an archive, accesses the network or requests notification permission. Already-modern values are kept. Unknown old strings are retained and copied to the legacy keys, without inventing a translation. Legacy copies are never replaced on a retry. Later user edits are untouched on a second run.

### Chime mapping

The old `FocusChimeController.availableSounds` contains exactly these seven names. Choices approximate their character rather than claim identical recordings.

| Old NSSound | Bundled raw value | Reason |
|---|---|---|
| Glass | `glass` | Bright glass strike with a ringing tail. |
| Ping | `tiny-ping` | Short, high-pitched single ping. |
| Pop | `pop` | Brief, rounded pop with little sustain. |
| Tink | `tiny-ping` | Tiny, bright metallic tap. |
| Funk | `wood-block` | Low, short percussive knock. |
| Submarine | `singing-bowl` | Soft, low resonant tone with a longer tail. |
| Sosumi | `soft-bell` | Rounded, mellow struck tone. |

Old strings are retained as `Clockin.Legacy.ChimeSound`; unknown names are also backed up. The existing general chime selector may later fall back for unsupported names, but the original remains recoverable.

### History mapping

Old strings are retained as `Clockin.Legacy.HistoryRange`.

| Old | New | Meaning / boundary change |
|---|---|---|
| Month | `M` | Current calendar month remains the default month page. |
| 7D | `W` | Calendar week replaces the rolling seven-day range. |
| 30D | `M` | Calendar month replaces rolling thirty days. |
| 3M | `6M` | Available six-month page replaces the old three-month range. |
| ALL | `All` | Full history remains full history. |

### Heatmap mapping

The old selector changes aggregation over the **whole archive**, not a limited lookback. `InsightsGrouping` uses `Day`, `Week`, `Month`; the day-grid range is **an integer week span**, with `0` meaning all.

| Old `Clockin.HeatmapRange` | `Clockin.InsightsHeatmapGrouping` | `Clockin.InsightsHeatmapDayRange` | Reason |
|---|---|---|---|
| Week | `Week` | `0` | Preserve week buckets; whole archive when returning to day view. |
| Month | `Month` | `0` | Preserve month buckets; whole archive when returning to day view. |
| All | `Day` | `0` | Preserve the full-history daily grid. |

Each existing destination key wins independently. The old heatmap key remains intact and is also saved as `Clockin.Legacy.HeatmapRange`.

### Remaining preferences

- A positive old daily **or** monthly goal sets `Clockin.HasConfiguredGoal = true`. Goal values are not rewritten. Zero/absent goals do not imply historical configuration; configured-then-cleared state cannot be inferred from 1.1.6.
- `Clockin.AutoCheckUpdates` and `Clockin.UIScale` are untouched; their migrations belong to the shell task.
- All other inventory keys marked `same`, old Mac-only window/menu preferences, wardrobe ownership and notification bookkeeping are left intact.
- `AppLanguage.shared` now uses standard defaults on macOS and retains the App Group only on iOS. This implements the inventory's Mac domain requirement before the first language lookup. The migration keeps an explicit `Clockin.Language`; absence means the existing `automatic` default. It does not force English or write `AppleLanguages`. Existing `applyToSystem()` behavior is unchanged.
- No upfront level/badge/wardrobe guessing is needed in the defaults migration: their existing calculation paths seed from the successfully loaded archive, as verified below.

## First refresh of a large archive

The expanded celebrations check builds **120 daily sessions / 960 hours**, computes real Insights badges/level and wardrobe earnings, and runs the actual `WardrobeStore.refresh` plus the same queue operations as `CelebrationCenter.refresh`. Only the unrelated `SessionMirror` publication boundary is stubbed; no UI or notification-center behavior is simulated as native proof.

| Surface | Before | After |
|---|---|---|
| Level-up cards | None: absent `lastLevel` seeds the computed level. | Unchanged; exact computed baseline is verified. New work afterward still celebrates. |
| Badge banners | None: absent seen IDs seed every currently unlocked badge. | Unchanged; all IDs and second-launch silence are verified. |
| Accessory banners | Missing seen IDs seed unlocked accessories; Center uses `includeAccessories: false`. | Unchanged. |
| Wardrobe notices | `WardrobeState.unlock` already granted ownership silently, but `WardrobeStore.refresh` returned `first: true`; Center queued **one wardrobe introduction**, not a historical stack. | `first` is true only for an unseeded **empty** archive. Existing work seeds ownership/ledger/coins with no introduction or item banners. Applies to iPhone first refresh of an existing/restored archive too. A fresh empty install still gets one introduction. |
| Coins and ownership | Derived from completed work; missing ledger means no purchases. | Same earned balance, all earned items and persisted seeded state; no fabricated spending. |
| Goal prompt | Positive goals already hide it, but the missing ever-configured flag could show it after clearing the goal. No goals plus completed work shows one card. | Migrated positive goals permanently count as configured. Users with no known prior goal still get the ordinary single goal prompt. |
| Nudges | Planner filters every scheduled request to `fireDate > now`; no historical delivery backlog. Current mood can reflect a quiet archive. | Unchanged and checked: bounded future plan, no expired day-3/day-7 reminders, paused timer observation starts now. Actual delivery still requires permission. |
| Live reactions / pride | No previous snapshot, therefore no historical reaction or pride. | Unchanged; initial queue remains empty. |

`CelebrationCenter.persist()` already stores the initial queue level/badge/accessory values. `WardrobeStore.persist()` already stores the seeded wardrobe and empty ledger. The check reopens the wardrobe and reconstructs the queue from those baselines to verify silence on another launch.

This is a first-refresh baseline policy. It does not reset an already-initialized celebration queue when a user deliberately replaces an archive later within a running app. Such live restore catch-up behavior is unchanged; it is separate from opening an existing archive with absent baseline keys.

## Verification and changed expectations

The original maccompat suite passed **171** checks before changes, reproducing the known failures. The updated test first failed on the missing quarantine file. The new celebration integration assertion first failed because the existing archive received the wardrobe introduction. Both now pass.

Only `maccompat` replaces old whole-archive-rejection assertions: all 20 fixtures retain strict-decoder rejection, add an explicitly valid companion entry, assert the exact rejected set, one quarantine, byte-identical original copy, count/name status, preserved profile/rates and clean reopen. Added coverage includes mixed valid/invalid sessions and timer, missing-rate migration ordering, preservation write failure and later save protection, exact raw session/timer bytes including unknown fields, malformed JSON/required keys, and the strict restore/import/listing contract.

`sessions`, `backups`, `import`, `rates` and `feedback` were **not edited**. `celebrations` retains its existing assertions and adds the full first-refresh checks. New `macmigration` checks all mappings, unknown/modern values, fresh install, destination preference priority, idempotence, saved legacy strings, goal migration and subsequent user edits. Its command and the expanded celebrations source list are in README's Checks block.

All commands use the README source lists. Commands without a cache argument were given `-module-cache-path /tmp/clockin-first-launch-cache` because the sandbox disallows Swift's default home-cache write. The initial default-cache attempt failed before compilation; rerunning with the temporary cache succeeded. Logs are in `.build/first-launch/` (untracked build output).

Migration SDK check, exit **0**, no diagnostics:

```bash
xcrun --sdk macosx swiftc -target arm64-apple-macosx14.0 -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-first-launch-cache -typecheck Shared/Core/AppLanguage.swift Clockin/Audio/FocusChimeSound.swift ClockinMac/MacLegacyMigration.swift
```

The string catalog parses as JSON and all three added messages contain English and Turkish translations. `git diff --check` passes.

### Executed check tails

**sessions: exit 0**

```text
ok: importing corrects both entries without adding one
ok: each entry takes the times of the row it was previewed with
ok: the second writing of a correcting row is previewed as a duplicate
ok: and importing does not add it as new work once the entry is taken
20 session checks passed
```

**backups: exit 0**

```text
ok: failed resume keeps the persisted paused state
ok: clock out succeeds once storage recovers
ok: successful clock out stays stopped after relaunch
ok: failed start does not create a memory-only timer
38 backup checks passed
```

**import: exit 0**

```text
ok: a new row that was left out is not added
ok: the in-file twin is previewed as a duplicate
ok: leaving out a row does not let its duplicate through instead
ok: nothing is imported when the only real row was left out
26 import checks passed
```

**rates: exit 0**

```text
ok: subsecond time never changes completed snapshot values
ok: clock out updates completed snapshot totals
ok: brand-new user has no earlier work
ok: new user has no completed-session impact
84 rate checks passed
```

**feedback: exit 0**

```text
ok: the changed note persists
ok: editing the end time preserves its explicit end date
ok: new time-only entries still infer overnight shifts
ok: equal new times do not silently turn into 24 hours
22 feedback checks passed
```

**celebrations: exit 0**

```text
ok large archive respects pending nudge limit
ok past 3-day and 7-day nudges are never replayed
ok quiet archive may show a current mood, not a notification backlog
ok old paused timer starts its nudge observation at first launch
125 celebration checks passed
```

**snapshot: exit 0**

```text
ok: the first two minutes update every fifteen seconds
ok: until ten minutes, every thirty seconds
ok: then every minute, ending inside the hour
ok: entries are strictly increasing and 74 in total
snapshot checks passed
```

**maccompat: exit 0**

```text
ok: restore explains its all-or-nothing contract
ok: importBackup also leaves existing archive untouched
ok: strict restore and import never modify supplied backup
ok: backup listing stays strict, matching restore
375 maccompat checks passed; legacy invalid entries quarantined without losing valid work
```

**macmigration: exit 0**

```text
ok: monthly-only goal counts as configured
ok: existing new heatmap preferences win
ok: already-modern preferences preserved
ok: modern preferences not mislabeled legacy
51 macmigration checks passed
```

**nudges: exit 0**

```text
ok: evening streak risk takes precedence over no-work mood
ok: overnight active session always uses working companion
ok: injected timezone preserves anchor across daylight saving
ok: calendar-day planning avoids fixed twenty-four-hour drift
93 nudge checks passed
```

**goals: exit 0**

```text
ok: another card or control dismisses editing
ok: stepper handles its own edit without a second focus commit
ok: empty space inside a goal row also dismisses editing
ok: field hit regions follow scrolling and keyboard layout
42 goal checks passed
```

**chimesound: exit 0**

```text
ok: 16-bit linear PCM: tiny-ping
ok: unclipped -3 dBFS peak: tiny-ping
ok: zero endpoints: tiny-ping
ok: RMS levels within 3 dB
96 chime sound checks passed
```

**wardrobe: exit 0**

```text
ok PNG proof /tmp/clockin-wing-fold.png
ok animated wing composition proof
ok invalid seated source safely ignored
ok concurrent frame requests share cached image off main thread
2898 wardrobe checks passed including real art integration and cache
```

## Handoff / remaining verification

- The shell task must call `MacLegacyMigration.migrate(in: .standard)` **before** creating `SharedStore.clock` or any views/controllers that read defaults. This brief intentionally leaves the existing Mac shell untouched; the currently inspected shell has not been wired to call it.
- A real 1.1.6 update-in-place rehearsal, signed Mac/iPhone/widget target builds, visible status rendering and actual notification delivery were not run. The checks prove synthetic store/defaults/rules behavior and migration type correctness, not packaged application startup.
- Sound mappings are character-based approximations. Calendar history boundaries and the 3M-to-6M change should be included in release notes. Stored legacy preferences make a manual downgrade restoration possible; an automatic downgrade mechanism is not implemented.
- Quarantine is a recovery artifact beside the original, not an importable complete backup or an automatic repair UI. Backup restore intentionally remains strict, with the explicit reason above. Sync integration remains future work.
