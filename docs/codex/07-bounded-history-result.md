# Brief 07b: bounded-history implementation result

Implemented in the inert sync core, with schema 2 and stable record types/names. No app wiring, project settings, entitlements or primary-storage code changed. No commit was created. The original brief files remain untouched.

## Rules implemented

- **Fixed top K:** Running, Preference and WardrobeState retain 8; Profile retains 4; purchases retain the earliest-date/lower-cost winner plus 2; Session and RateRule retain 1. K=1 is intentional for Session/RateRule: local recovery captures displaced payloads before pruning, their origin/deletion facts no longer depend on history, and a deleted identity stays one small record. The more frequently edited singleton registers keep a modest recent causal context.
- **Permanent deletion:** every Session/RateRule deletion ranks above every live revision, regardless of stamp. Tombstones have empty payloads and are never collected. Each Session has a required immutable origin-fact wrapper: original `clockinStart` for Clockin-source creation, otherwise nil. Edits to source/start never change it; deletion keeps it. Disagreeing facts quarantine the incoming envelope. A known closed start defeats even an arbitrarily newer offline pause, including before a Running register exists locally.
- **Maximum stamp:** retained independently of selected history and joined by max. Local edits advance above observed stamps; pruning an expensive/later purchase cannot lose the logical-clock floor. No clock-based retention window or replica expiration exists.
- **Ownership:** wardrobe and SeenAccessoryIDs are exact grow-only catalog sets independent of payload retention. The current catalog has 67 IDs. Unknown IDs never enter those synchronized sets. Up to **16 opaque future-catalog envelopes** are preserved, unapplied, inside local quarantine for a future compatible version/review. Excess unknown envelopes evict oldest with notice. This deliberately chooses a local compatibility allowance rather than an unbounded synchronized set of unknown IDs.
- **Recovery:** captures applied or locally authored payloads when a remote update replaces them, before pruning. Recovery does not depend on proving concurrency. Only positively certified concurrency gets conflict wording; sequential/uncertain replacements get neutral wording. Local edits that immediately lose to a known tombstone or earlier purchase are captured too. Distinct displaced unfinished timers and locally applied import aliases are captured; same-start pause/resume, completed runs and unseen remote losers do not create timer/conflict recoveries.
- **Local caps:** recovery is at most **50 entries / 256,000 bytes**, quarantine at most **100 entries / 1,000,000 bytes**, including JSON/base64/metadata. Oldest entries are evicted whole. Each queue has one overflow notice per episode; acknowledgment suppresses repeats. An episode ends when acknowledged and drained, removing its acknowledgment. Recovery acknowledgment removes the entry immediately. Acknowledged historical entry IDs do not accumulate. There is no time expiry and no recovery promise beyond these caps.
- **Causality:** new edits reference at most K retained revisions; pruning filters parents to the retained set. Immutable `observed` stamps survive pruning. Concurrency requires different authors and each causal floor below the other's stamp. Missing parents alone never imply conflict. The classifier is conservative; uncertain losses still enter recovery.
- **Input limits:** Session/Running notes ≤2,000 characters; preference strings ≤256 characters; arrays ≤256 entries. Text also has a four-UTF-8-bytes-per-allowed-character ceiling, because grapheme counts alone do not bound combining-scalar storage. Payload, numeric, date, catalog, wardrobe collection/coordinate and metadata limits are enforced locally and remotely. Invalid local values stay local-only with durable, localizable bridge errors; valid sibling edits upload. Merges/previews preserve the invalid local value, and correction resumes upload. Remote violations quarantine without truncation.
- **Ancillary growth:** staged records use the same rules. System fields are capped at 16 KiB per known identity; engine state at 256 KiB, with refetch fallback. Account/backup paths are capped. Save/load validates local budgets. Foreign staged data leaves a durable approval flag even after its revisions disappear. Rejected record keys reach transport directly, so quarantine eviction cannot accidentally permit an overwrite.

Full rules and integration API: [sync-design.md](../sync-design.md).

## Proof sketch and equality

For any fixed total order, an element removed by top-K already has K greater elements in that input. Those witnesses remain in any union, so it cannot re-enter the greatest K:

`T_K(A ∪ B) = T_K(T_K(A) ∪ T_K(B))`.

Deletion-first and earliest-purchase-first are fixed total orders, so the same argument applies. Maximum stamps join by max; catalog facts by exact union; immutable Session facts must agree. Parent relations union before being filtered to retained endpoints. A removed endpoint likewise has K greater witnesses and cannot return. This proves `P(A ⊔ B) = P(P(A) ⊔ P(B))` for valid, fact-compatible registers with no dangling input parents. Common revisions may have different projected parent lists; those lists union, while differences in immutable content quarantine.

Canonical equality includes every retained revision, maximum stamp, Session fact, ownership fact and parent edge, plus the synchronized projection. It excludes only explicitly local state: recovery, acknowledgments, quarantine, issues, queues/transport, account/device identity and already excluded device settings. Session/rule identity growth is permanent and explicitly included in the bound; unlimited creation of identities cannot have a constant-size sidecar.

## Worst-case byte bounds

Let `C = 67`, `B64(n) = 4 × ceil(n / 3)` and

`E(kind) = 2048 + 84C + K × (B64(payloadCap) + 1024 + 152K)`.

These allowances include record headers, catalog IDs, three stamp locations, 128-byte authors, UInt64 counters, base64 and bounded parent IDs. Validation makes them independent of edit count.

| Kind | K | Payload cap | Envelope bound | Adversarial payload fixture observed |
|---|---:|---:|---:|---:|
| Session | 1 | 16,384 | 30,700 | 22,461 |
| RateRule | 1 | 1,024 | 10,220 | 1,941 |
| Profile | 4 | 1,024 | 19,676 | 8,319 |
| Running | 8 | 16,384 | 200,380 | 182,831 |
| Preference | 8 | 32,768 | 375,132 | 358,473 |
| WardrobeState | 8 | 32,768 | 375,132 | 358,465 |
| WardrobePurchase | 3 | 1,024 | 16,220 | 6,039 |

Fixtures fill the raw payload ceiling and K, use 128-byte authors/large counters, retained parents and full catalog facts where applicable. They are concrete stress cases, not claims that every theoretical maximum is simultaneously attained. Tombstoned Session/RateRule registers have a tighter conservative bound of **2,048 bytes** each.

The old 750,000-byte refusal is replaced by a **524,288-byte defensive envelope limit**. The largest valid bound is 375,132, so a valid register cannot reach that refusal.

For local and staged register copies `R` and union of their identities plus local-only issue identities `I`, the implemented serialized sidecar bound is:

`16,384 + B64(262,144) + Σ[r ∈ R](E(r.kind) + 256) + |I| × (B64(16,384) + 2,048) + 256,000 + 1,000,000`.

This is **fixed bookkeeping/checkpoint + per-identity registers/transport/issues + capped local data**. Local/staged copies count separately. It includes JSON keys, queues and base64, not only raw payloads. A simultaneous stress fixture with maximal payload registers, duplicate staging, full engine/system fields, extreme bookkeeping strings and filled recovery/quarantine used **3,630,150 bytes**, below its **3,847,688-byte** formula. Primary archives and explicit first-merge backup files are separate user data.

## Final long-run measurements

Five simulated years: **1,827 daily-use days**, three replicas, **11,416 measured mutations**, **12 random offline episodes**, including **1,200 days offline**. Daily work includes clock-in, four pause/resume operations, clock-out/session creation, preference changes, periodic ownership/seen changes, profile/rule/purchase work, edits/deletes and deliberately abandoned timers. Synthetic store deltas omit unchanged domains from both sides of a save; the older 30-seed tests continue exercising full snapshots.

Every mutation checks per-record and full sidecar bounds, recovery caps and no resurrection. Full sidecar byte size uses exact JSON object additivity with cached record encodings, cross-checked against whole-sidecar serialization every 500 mutations and at the end. Online anti-entropy rounds and final all-replica exchange assert canonical projection/register convergence. Replaying a **1,797-day-old** replica twice at the end changes no winner, retained register, recovery or notice. Shuffled transport can vary local pending/recovery overhead; these are observations from the final verified run, not universal exact sizes.

| Envelope kind | Maximum observed | Documented bound |
|---|---:|---:|
| Session | 623 | 30,700 |
| RateRule | 491 | 10,220 |
| Profile | 1,197 | 19,676 |
| Running | 2,997 | 200,380 |
| Preference | 9,536 | 375,132 |
| WardrobePurchase | 861 | 16,220 |
| WardrobeState | 13,667 | 375,132 |

| Replica | Maximum sidecar observed | Formula bound at that maximum | Final retained identities |
|---|---:|---:|---:|
| long-0 | 1,080,038 | 100,595,340 | 1777 |
| long-1 | 1,082,299 | 100,595,340 | 1777 |
| long-2 | 1,086,601 | 100,595,340 | 1777 |

## Verification and changed premises

Final commands all completed successfully in Swift 6 language mode with complete concurrency checking and warnings as errors:

- `Tests/manual/sync/run`: **262 named checks passed**, including the original 196, 3,500 random register triples checking pruning/associativity/commutativity/idempotence, the five-year run, stale returns, recovery capture/caps/overflow/acknowledgment/restart, limits, transport metadata, staging and simultaneous byte ceilings.
- `Tests/manual/sync/run codec`: **17 offline CloudKit codec checks passed**.
- `Tests/manual/sync/run typecheck`: **macOS arm64 / macOS 14.0** and **iOS Simulator arm64 / iOS 17.0** passed.
- `git diff --check`: passed. No commit.

Changes to old checks/fixtures, rather than removing checks:

1. Delete-conflict and displaced-timer recovery tests now establish an applied local value before receiving its replacement. Arbitrary remote loser history alone is no longer recovery.
2. The two first-preview duplicate checks now assert retention of the unapplied remote alias as its own Session identity and absence of a local recovery notice. Applied alias displacement still uses the recovery path.
3. Notice acknowledgment first populates the device-local inbox, then acknowledges it; it no longer acknowledges a notice synthesized forever from synchronized history.
4. Wardrobe `hat` and randomized `item-*` / `color-*` / `buy-*` fixtures were replaced with actual catalog IDs. The same union/LWW/purchase and 30 randomized convergence checks remain.
5. The codec's deliberately enormous note is now **invalid input**, not a valid record that eventually hits a history refusal. The wrong-record-name fixture uses schema 2 so it still tests identity, not merely schema rejection. All seven kind roundtrips and system-field roundtrips remain.
6. The runner adds the bounded checks and makes log output immediate. Default execution includes five years; `--quick` is only an explicit development shortcut, not the reported final command.

## Open items / explicit limits

No bounded-history implementation item remains open in this scope. The core remains inert: no real iCloud account, device pair, push delivery, first-merge UI or recovery UI was exercised. Those are future integration checks, not proven by these offline results.

Recovery/quarantine overflow intentionally loses oldest payloads and reports that loss. Forward-catalog preservation is local, capped and unapplied until compatible code/review; automatic replay UI is not wired. Conflict labels are conservative, while uncertain replaced payloads remain recoverable. Permanent tombstones mean storage grows with retained identities. No schema-1 migration is provided because no production schema-1 data exists.
