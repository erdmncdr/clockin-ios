# Brief 07b: bounded history — decisions, now implement

Read `docs/codex/07-bounded-history.md` and your own
`docs/codex/07-bounded-history-result.md`. You were right: "recoverable until
acknowledged" and "hard bound" cannot both hold for an unlimited stream of
unacknowledged conflicts. Here are the decisions. Implement them.

## Decisions

1. **Recovery is device-local and capped.** Losing payloads (a displaced
   unfinished timer, a losing concurrent edit) are captured into a local
   recovery inbox in the sidecar at the moment this device's projection moves
   away from a value it had applied, or when a remote winner displaces a
   revision this device authored. The inbox holds at most **50 entries and
   256 KB**; when full, the oldest unacknowledged entry is evicted and an
   overflow notice is raised (one notice per overflow episode, not per
   eviction). Acknowledged entries are removed. The inbox and acknowledgments
   are device-local: excluded from synchronized-register equality, counted
   in the sidecar budget. Synchronized registers no longer need to carry
   losers for recovery.
2. **Synchronized registers keep the greatest K revisions** under one fixed
   total order per record kind, plus whatever monotone metadata the order
   needs (for example the maximum stamp). Choose K per kind (suggestion: 8
   for Running, Preference and WardrobeState; 4 for Session, RateRule,
   Profile; purchases as below) and justify it. Prove and test
   `P(A ⊔ B) = P(P(A) ⊔ P(B))`.
3. **Deletion outranks every live revision** in the Session/RateRule order,
   so the tombstone is always the winner and is always retained. Tombstones
   are permanent, one small record per deleted identity (sidecar size is
   proportional to retained identities; state that in the design).
4. **Resurrection guard from durable facts, not history.** Every Session
   record carries an immutable `clockinStart` fact (set at creation for
   `Clockin`-source sessions, never changed by edits, kept in the tombstone).
   A run whose start equals any known `clockinStart` is closed. Define how the
   fact merges when two revisions disagree (it cannot, for a valid register;
   quarantine if it does).
5. **Purchases:** order puts the earliest purchase date first (then lower
   cost, then stamp); keep the winner plus K=2. Ownership and
   `Clockin.SeenAccessoryIDs` become grow-only set facts merged by union, not
   derived from payload history; their size is bounded by the catalog (validate
   IDs against it, quarantine unknown IDs beyond a small allowance so a future
   catalog item from a newer app version is not lost — decide and document).
6. **Causal parents** reference only retained revisions and are capped at K;
   a sequential edit must not be reported as a conflict because an ancestor
   was pruned. Define conflict detection so it only fires for genuinely
   concurrent revisions the local device observed.
7. **Input limits, enforced on local save and on remote validation:** session
   note ≤ 2,000 characters, preference strings ≤ 256 characters, string
   arrays ≤ 256 entries, other payloads by their type. A local value over a
   limit is not uploaded; the record stays local-only with an explicit,
   localizable error surfaced through the bridge (no silent truncation). A
   remote value over a limit is quarantined.
8. **Other sidecar growth:** quarantine capped at 100 entries / 1 MB with
   oldest eviction and a notice; acknowledged notice IDs dropped once their
   entry is gone; staged records bounded by the same per-record rules.
9. **Schema:** no production data exists, so move to schema 2 freely; keep
   record types and names stable.

## Deliverables

Implement in `Shared/Sync/Cloud/*`, extend `Tests/manual/sync/*` with the
tests listed in brief 07 (prune/join property over random registers; five
simulated years of daily use on two or three replicas with random offline
periods, some longer than any window; old-replica return; recovery inbox
capture, cap, overflow notice and acknowledgment), update
`docs/sync-design.md` with the rules, worst-case envelope size per record kind
and the sidecar formula (fixed part + per-identity part + capped local part),
replace the 750,000-byte refusal with a documented limit a valid register
cannot reach (keep a defensive check), and keep all existing checks passing,
listing any whose premise changed.

## Rules

As in brief 07: only `Shared/Sync/Cloud/*`, `Tests/manual/sync/*`,
`docs/sync-design.md` and README Checks; inert core; Swift 6 strict,
warnings as errors; do not commit.

## Result

Overwrite `docs/codex/07-bounded-history-result.md` with the implementation
result: rules, proofs sketch, worst cases, long-run numbers (max envelope and
sidecar sizes observed vs. documented bound), changed checks, open items.
