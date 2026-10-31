# 36: Tell manual entries from timer sessions

Follow-up to 35. The same-timer collapse (`SyncMerge.sessionAliases`) treats every
session whose `source == "Clockin"` as a timer session, so two manual entries
(`ClockStore.addManualSession`) with the identical start on the same day collapse
into one after sync, and a manual entry that happens to share a timer's exact start
collapses with it. Fix that with a small, backward-compatible model addition.

Work in this worktree (branch `codex-36`). Do not commit; I commit. Swift 6 strict
concurrency clean; no new dependencies; do not change sync record types, names,
zone or the schema number; do not touch the website or the relay.

## The field

Add to `WorkSession` (`Shared/Core/Models.swift`) an optional origin, for example

```swift
enum SessionOrigin: String, Codable, Sendable { case timer, manual }
var origin: SessionOrigin? = nil
```

Requirements:

- **Wire and disk compatibility.** Mac 2.0.29 (40) and iOS 0.2 (58) are in the
  field and will coexist with the new build for a while. They decode `WorkSession`
  from `clockin.json`, from the App Group snapshot and from sync payloads. The new
  key must be ignored by them (synthesized Codable does that) and a `nil` origin must
  encode to exactly the bytes the old build produces (synthesized `encodeIfPresent`
  omits it; verify with a byte comparison in the test). `nil` means "legacy, unknown".
- **Setting it.** `clockOut` → `.timer`; `addManualSession` → `.manual`. Find every
  other place that builds a `WorkSession` with source "Clockin" (`grep -rn '"Clockin"'`
  and `grep -rn 'WorkSession('` outside Tests): edits must keep the existing origin
  (`SessionOverlap.swift` around line 71 builds an edited copy; check the Mac and iOS
  edit sheets), imports must leave it `nil`, the sync projection must not touch it.
  Backup import / CSV import of own data: keep whatever the file says.
- **The collapse rule.** In `SyncMerge.clockinStart` (or wherever it fits best), a
  session has a timer identity only when `source == "Clockin"` and
  `origin != .manual`. `nil` keeps today's behaviour (collapsible), so the fix shipped
  in 35 still applies to existing data. Two manual entries never collapse by start;
  a manual entry never collapses with a timer session. The import-key relation
  (`Int(start)|Int(end)|Int(duration)`) is unchanged and still applies to all sources.
- **Do not change `SyncSessionFact`.** Its `clockinStart` is compared for equality in
  `SyncRecord.joined`, and an old build re-creating a record would compute it the old
  way; adding a field there or setting it `nil` for manual entries would make an old
  device's record join fail ("immutable clockinStart changed") during the mixed
  window. Read the origin from the materialized `WorkSession` payload instead.
  Explain in the result what happens when an old build edits a manual entry created
  by a new build (it drops the key; the entry becomes legacy `nil` and is collapsible
  again; acceptable, document it).
- **Display.** `Models.swift` around line 53 labels the source "Clockin" or "Imported
  timecard". Label `.manual` as "Manual entry" (English and Turkish, "Elle girilen
  kayıt") in `Shared/Localizable.xcstrings`, keeping the file's formatting (sorted
  keys, 2-space indent). Nothing else in the UI changes.

## Verification

- `Tests/manual/sync/run`: add (a) two Clockin sessions, same start, one `.manual`
  → not collapsed; (b) two `.manual` with the same start → not collapsed;
  (c) `.timer` + `.timer`, same start → collapsed as in 35; (d) `.timer` + `nil`
  and `nil` + `nil`, same start → collapsed; (e) `.manual` + `.manual` with identical
  start, end and duration → still collapsed by import key; (f) a Codable round trip:
  a session with `origin == nil` encodes to the same bytes as before the change
  (encode the struct, assert the JSON has no `origin` key), and a payload without
  the key decodes to `nil`; (g) the five-year simulation and every existing check
  still pass (296 today).
- `Tests/manual/syncapp/run`: a manual entry on the Mac and a timer clock-out on the
  phone with the same exact start remain two entries on both devices.
- `Tests/manual/timerlog/run` (or the nearest `ClockStore` harness): `clockOut` sets
  `.timer`, `addManualSession` sets `.manual`.
- `Tests/manual/sync/run typecheck` and `Tests/manual/syncapp/run typecheck`
  (macOS and iOS Simulator SDKs). xcodebuild is not available to you; I build.
- `docs/sync-design.md`: one or two sentences on the origin field in the duplicate
  paragraph.

Write `docs/codex/36-session-origin-result.md`: what changed per file, the final
rule, the mixed-version behaviour, what was verified and what I should check in the
apps. No Codex/Claude names in code, comments, docs or suggested commit messages.
