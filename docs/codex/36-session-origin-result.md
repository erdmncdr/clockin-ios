# 36 result: manual entries are told apart from timer sessions

Manual entries no longer collapse with each other or with a timer session that shares
their start. The import-key relation, the legacy behaviour for existing data and
`SyncSessionFact` are unchanged; no sync record type, name, zone or schema number
changed.

Changes by file:

| File | Change |
| --- | --- |
| `Shared/Core/Models.swift` | `SessionOrigin` (`timer`, `manual`) and `WorkSession.origin: SessionOrigin? = nil`. The source label shows "Manual entry" for manual sessions without a note. |
| `Shared/Core/ClockStore.swift` | `clockOut` writes `.timer`, `addManualSession` writes `.manual`. Edits (`updateSession`) and import matching modify the stored struct in place, so the origin is kept. |
| `Shared/Core/SessionOverlap.swift` | The overlap candidate carries the edited session's origin (`.manual` for a new entry); detection itself ignores it. |
| `Shared/Sync/Cloud/SyncMerge.swift` | `clockinStart` yields a timer identity only for `source == "Clockin"` and `origin != .manual`. |
| `Shared/Localizable.xcstrings` | "Manual entry" / "Elle girilen kayıt". |
| `docs/sync-design.md` | The duplicate paragraph names the origin field and the mixed-version rule. |
| Tests | `sync` (354 checks), `syncapp` (128), `timerlog` (61), `sessiondisplay` (66). |

Rule: two sessions share a timer when both have source `Clockin`, neither is `.manual`,
and their `sessionFact.clockinStart` (or `start` when not yet captured) is the same
exact `Date`. `nil` origin is "legacy, unknown" and stays collapsible, so the fix from 35
keeps applying to sessions created before this build. Import-key duplicates
(`Int(start)|Int(end)|Int(duration)`) still collapse regardless of origin.

Mixed versions: Mac 2.0.29 (40) and iOS 0.2 (58) ignore the new key when decoding and a
`nil` origin encodes to the same bytes as before (verified byte for byte), so
`clockin.json`, the App Group snapshot and sync payloads stay compatible. An old build
that edits a manual entry made by a new build re-encodes it without `origin`; the
entry becomes legacy and collapsible again. Accepted; it ends once all devices update.
The CSV timecard importer leaves origin `nil` (it is not a Clockin source anyway);
backup export and restore carry the field.

Verification: `Tests/manual/sync/run` 354, `sync/run typecheck` (macOS, iOS Simulator),
`Tests/manual/syncapp/run` 128 and its typecheck, timerlog 61, sessiondisplay 66; Mac
and iOS Debug builds (see the release record). Not verified on devices.
