# Brief 07: bound the sync history before it can ship

Read `docs/sync-design.md` and `docs/codex/05-sync-core-result.md` (your own
previous work), then `Shared/Sync/Cloud/*` and `Tests/manual/sync/*`.

The core keeps every revision of every record forever and refuses envelopes
over 750,000 bytes. That is a production blocker, not a later concern:

- `Running:Running` gets a revision on every clock in, pause, resume and clock
  out. At ~250 bytes each and 4–8 operations a day it reaches the cap in one
  and a half to two years of normal use, after which that user's timer stops
  syncing. The sidecar grows the same way.
- Preference and `WardrobeState` registers grow with every change (a theme
  or room tweak, a chime interval dragged through values).
- Session and rate-rule registers are fine: they are edited rarely and their
  tombstones are small, one record each.

## Goal

Every record envelope and the sidecar stay bounded under indefinite use,
while keeping everything the design relies on:

1. Convergence: replicas that exchange all records in any order, with
   duplication and delay, end in the same projected state and — define this
   precisely — the same retained registers.
2. No resurrection: a clocked-out run never comes back, a deleted session or
   rule never comes back, whatever an old offline replica later sends.
3. Recoverability where it matters: a displaced unfinished timer and a losing
   concurrent edit stay recoverable at least until the user has been able to
   see the notice (define the rule, for example "for N days after the
   revision that displaced it, and until acknowledged on this device").
4. Old replicas: a device that was offline for longer than the retention
   window and then sends pruned revisions must not change the winner, must not
   create notices for long-settled conflicts, and must not grow registers
   again beyond the bound.

## Direction (improve it if you find a better one, and say why)

- Pruning must be a deterministic function of the joined register
  (for example of the winning revision's stamp and the revisions' own stamps
  and causal parents), never of the receiving device's clock or arrival
  order, so that `prune(join(a, b)) == prune(join(prune(a), prune(b)))`. State
  and test that property.
- Keep compact durable facts separate from revision history where history
  was only kept as evidence: for example the set of closed run starts
  (bounded by keeping only starts that could still be displaced, or
  derivable from `Session` records and session tombstones that keep their
  start), rather than every `Running` revision.
- Keep the winner, its causal ancestry only as far as needed, recent losing
  revisions inside the recovery window, and hard caps per record type (count
  and bytes) with a deterministic tie rule, so the worst case is computable.
- Document the worst-case envelope and sidecar size per record type after the
  change, and replace the 750,000-byte refusal with a limit that cannot be
  reached by a valid register (keep a defensive check).
- If the schema version must change, handle schema 1 envelopes that already
  exist nowhere in production: none exist, so changing the schema number and
  the record contents is allowed, but keep the record types and names stable
  unless there is a strong reason.

## Tests

Extend `Tests/manual/sync/main.swift`:

- the prune/join property above, over random registers;
- long-run simulation: at least five simulated years of daily timer use and
  preference edits on two or three replicas with random offline periods
  (some longer than the retention window), asserting convergence, no
  resurrection, bounded envelope and sidecar sizes at every step, and that the
  maximum observed sizes stay under your documented worst case;
- an old replica returning after a long offline period with pruned-away
  revisions: no winner change, no stale notices, no register regrowth;
- recovery window behavior: a displaced timer stays recoverable inside the
  window and until acknowledged, and disappears deterministically after.

Keep the existing 196 checks passing (update only those whose premise was
"history is kept forever", and list them).

## Rules

- Only `Shared/Sync/Cloud/*`, `Tests/manual/sync/*`, `docs/sync-design.md` and
  the README Checks block may change. The core stays inert: no app wiring.
- Swift 6, strict concurrency, warnings as errors in the sync checks.
- Do not commit.

## Result

Write `docs/codex/07-bounded-history-result.md`: the pruning rule and why it
converges, the retention/recovery rules, worst-case sizes, which old checks
changed and why, the long-run numbers, and anything still open.
