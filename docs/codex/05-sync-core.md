# Brief 05: the sync core (CloudKit, CKSyncEngine)

Read `docs/mac-plan.md` (phase 5, in Turkish; the design there is the
starting point, not a fixed spec), `docs/mac-port-inventory.md` section C
(every UserDefaults key with a `sync` / `device` class),
`Shared/Core/Models.swift`, `Shared/Core/ClockStore.swift` (including the new
`ClockinArchive` recovery reader), `Shared/Mascot/Wardrobe.swift`,
`Clockin/Views/Companion/WardrobeStore.swift` and
`Shared/Sync/SessionMirror.swift`.

Clockin now runs on the iPhone (`Clockin` target, iOS 17) and the Mac
(`ClockinMac` target, macOS 14) from one code base. The user wants everything
that is a user choice to follow them between devices: work data, goals,
companion/wardrobe/room/coins, appearance and sounds. There is no server and
no account system; sync goes through the user's private iCloud database.

This brief builds the sync core and its CloudKit adapter so they can be
reviewed and tested on their own. **Do not wire anything into the apps yet**:
no changes to `ClockStore` beyond a small, inert hook if you need one, no
changes to app entry points, entitlements or the Xcode project. The iCloud
container and capabilities do not exist yet.

## Goals

1. Two devices that edit offline and reconnect converge to the same state,
   whatever order their changes arrive in.
2. No user data is lost silently. When a conflict has to drop something (for
   example two different timers started on two devices), the losing side is
   kept somewhere recoverable and the user can be told once.
3. The existing archive format (`clockin.json`, backups, the old Mac app's
   ability to read it) does not change. Sync metadata lives beside it.
4. A bad record from another device never empties the store (reuse the
   per-entry validation that `ClockinArchive` introduced).
5. Nothing device-specific syncs: Live Activity tokens and consent, window
   frames, notification bookkeeping, setup flags, caches such as exchange
   rates, `pinVisible` (Mac window state), anything section C marks `device`.

## Design to implement (improve it where you find a real problem, and say why)

**Transport:** `CKSyncEngine` (iOS 17 / macOS 14), private database, one custom
zone `Clockin`, container `iCloud.com.erdmncdr.clockin`. Engine state
serialization is persisted and restored.

**Record types** (names are yours to refine; keep them stable once chosen):

- `Session` — one per `WorkSession`, record name = session UUID.
- `RateRule` — one per `RateRule`, record name = rule UUID.
- `Profile` — singleton: hourly rate, currency.
- `Running` — singleton describing the timer, including an explicit idle
  state, so that "clocked out" is ordered against "paused" by time instead of
  being a deletion.
- `Preference` — one per synced UserDefaults key, value plus type.
- `WardrobePurchase` — one per ledger purchase; append-only.
- `WardrobeState` — equipped items, colorway, room, furniture, home layout,
  lamp, arrangement; `owned` merges as a set union.

**Change tracking:** a pure function computes the set of record changes
between two local states (previous and current `ClockinData`, synced
preferences, wardrobe state and ledger). Each record carries a
`modifiedAt` (device clock) and `modifiedBy` (a stable per-install device id).
Remote changes are applied to the local state by a pure merge function that
returns the new local state, the records that must be re-sent (when local
wins a conflict), and user-facing notices. Applying a remote change must not
produce an echo upload.

**Conflict rules:**

- Session, RateRule, Profile, Preference, WardrobeState (except `owned`):
  last writer wins by `modifiedAt`, ties broken deterministically (for
  example by `modifiedBy`).
- Deletion wins over a concurrent edit of the same session/rule.
- WardrobePurchase: union; the same purchase from two devices is one
  purchase (define its identity); coins are derived, never synced.
- Running: last writer wins, **except** that a run that has already been
  clocked out anywhere is never resurrected (a completed `Clockin`-source
  session whose `start` equals the run's `start` means that run is over). If
  two devices start different runs, the later one wins and the other run is
  preserved (as a recoverable record, not silently dropped) with a notice.
- First sync between two devices that already both have history (the user's
  iPhone and Mac do): union of sessions, then collapse exact duplicates with
  the same key `ClockStore` uses for imports; report counts
  (from this device, from the other, duplicates) so the app can show a
  one-time confirmation before the merge is committed. Take a backup of the
  local archive before the first merge.
- Validation: records that fail the same validation `ClockinArchive` applies
  are quarantined, not applied, and not deleted from the server.

**Persistence:** a sidecar next to `clockin.json` (for example
`sync-state.json`) holding the engine state serialization, per-record
`modifiedAt`/`modifiedBy`, CloudKit system fields for records we have seen,
the device id and pending changes. Writing it must never block or roll back
the primary archive save.

## Deliverables

- `Shared/Sync/Cloud/` (new): the pure model, diff, merge and sidecar code
  (Foundation only, no CloudKit import) and a separate CloudKit adapter file
  (`CKSyncEngine` delegate, `CKRecord` ⇄ record conversion, error handling for
  `serverRecordChanged`, `zoneNotFound`, `unknownItem`, account changes,
  quota and network errors, batch building). The adapter must compile for both
  iOS 17 and macOS 14 but will not run until entitlements exist.
- A tiny inert integration surface that I will call later, documented in the
  result: what the apps must call on save, on preference change, on wardrobe
  change, on launch, on remote notification, and what callback applies a
  merged state back into `ClockStore` / `UserDefaults` / `WardrobeStore`.
- `Tests/manual/sync/main.swift`: dependency-free checks of the pure layer,
  in the style of the other checks. At least: diff correctness; LWW with ties;
  delete-vs-edit; running-timer scenarios (pause vs clock-out across devices,
  two starts, resurrection guard, resume after remote pause); wardrobe union
  and purchase identity; preference LWW and the device-key exclusion list;
  first-sync union and duplicate collapse with the reported counts; invalid
  remote records quarantined; no echo after applying remote changes; and a
  **convergence property test**: two or three simulated replicas making
  random offline edits (seeded RNG), exchanging changes in random orders and
  batches, must end byte-identical. Add its command to README's Checks block.
- `docs/sync-design.md` (English): the record schema, rules, sidecar format,
  integration surface, what the user must set up in the developer portal and
  CloudKit Dashboard (container, capabilities on both App IDs
  `com.erdmncdr.clockin` and `com.ismailakdag.clockin`, push, Developer ID
  provisioning profile for the Mac, schema deploy to production), and the
  failure modes you considered.

## Rules

- Swift 6, strict concurrency. The pure layer is `Sendable` value types.
- Do not change existing behavior of either app. Do not edit
  `Clockin.xcodeproj`, entitlements, `ClockinMac/*` or the app entry points.
  If `ClockStore` needs a hook, keep it minimal, default-off and covered by the
  existing checks.
- Comments short; English in new files.
- Do not commit.

## Verification

Run the new `sync` check and the existing `sessions`, `backups`, `import`,
`maccompat`, `rates`, `feedback`, `celebrations` and `wardrobe` checks; paste
their tails. Type-check the CloudKit adapter against the macOS 14 and iOS 17
simulator SDKs and say exactly what you could not check.

## Result

Write `docs/codex/05-sync-core-result.md`: design decisions (especially where
you departed from the design above), the integration surface, test coverage,
and open questions for me.
