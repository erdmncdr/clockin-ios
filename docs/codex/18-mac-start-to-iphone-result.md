# 18: Mac clock-in → iPhone, without opening Clockin

Design reviewed 2026-09-30. No implementation, deployment, system-setting change, or real-device test was performed.

**Recommendation:** retain CloudKit as the source of timer data and add a separate, default-off push-to-start feature for iOS 17.2+. The Mac sends an authenticated start command to the relay; ActivityKit creates the iPhone activity; the iPhone fetches CloudKit and supplies private display data locally. Keep the existing protocol-2 minute-update contract unchanged. A minimal activity can appear before the CloudKit fetch finishes, but full timer/earnings details still depend on successful local hydration. Neither APNs nor CloudKit provides an immediate-delivery guarantee.

For the unwanted second item on Mac, recommend **System Settings → Notifications → Allow notifications from iPhone → Allow Live Activities from iPhone: Off**. This is the global control on macOS Tahoe 26+, affecting other apps too. It preserves Clockin’s native Mac item and the iPhone activity. Closing an individual mirrored activity lasts only for that activity; the per-app notification controls are a separate feature. Do not change this setting automatically. [Apple’s Mac instructions](https://support.apple.com/en-us/120684)

## 1. What happens today

The application source examined is this worktree at `9fff6daab96673e3a4fe5ff322e29ade85815f9b`, with both iPhone and native `ClockinMac` targets. The relay lives in `/Users/erdemincedere/Clockin/clockin-main/services/live-activity`; that checkout’s HEAD is `f0310471beb522cc2ef8e81d631107fd3b372e8c`. This distinction matters: the new Mac app shares this worktree’s `Shared/` implementation; the older Swift-package Mac sources in `clockin-main/Sources/Clockin` are not the implementation target for this plan. Relay README deployment statements are historical evidence, not a fresh check of production.

| Stage | Actual source behavior | Background implication |
| --- | --- | --- |
| Mac clock-in | [`ClockStore.clockIn`](../../Shared/Core/ClockStore.swift) creates `RunningSession`, saves atomically, and emits `didPersist` only after success. `SyncCoordinator.localDidPersist` captures the change in the durable sync sidecar and starts synchronization. | A failed local save must never produce a remote start. The Mac’s own timer remains usable during network failure. |
| CloudKit | [`CloudKitAdapter`](../../Shared/Sync/Cloud/CloudKitAdapter.swift) uses `iCloud.com.erdmncdr.clockin`, private database, `Clockin` zone, schema-2 envelopes, and `CKSyncEngine` with `automaticallySync = false`. Explicit passes fetch changes and send pending records. [`SyncMerge`](../../Shared/Sync/Cloud/SyncMerge.swift) projects the winning `Running` value. | CloudKit notification is a change hint, not a timer payload or a Live Activity start command. Offline work, account problems, first-merge review and invalid records can delay application. |
| iPhone launch/wake | [`ClockinAppDelegate`](../../Clockin/ClockinAppDelegate.swift), lines 8–35, starts sync during `willFinishLaunching`, including headless launches, and registers for remote notifications when enabled. The plist includes `remote-notification`. | Background initialization already exists; it is not confined to a visible screen. |
| Silent push | The delegate’s `didReceiveRemoteNotification`, lines 40–50, accepts only a matching private `CKDatabaseNotification`, awaits `handleRemoteNotification()`, then awaits `SessionMirror.finishPendingUpdates()`. | If iOS grants execution, the app fetches without being opened. The method always returns `.noData`, even after an applied change; improve result reporting/diagnostics later, but this is not a workaround for ActivityKit’s start restriction. |
| Fetch → apply | [`SyncCoordinator`](../../Shared/Sync/SyncCoordinator.swift), lines 206–264 and 309–330, builds the bridge, validates and applies the merged snapshot, saves the primary store, applies preferences/wardrobe, then calls `refreshServices()` → `SessionMirror.refresh()`. | Only accepted, successfully persisted data should reach the mirrors. A postponed merge is not a completed timer update. |
| Store → mirror | [`SharedStore`](../../Shared/Sync/SharedStore.swift) creates the single app-process `ClockStore` and starts [`SessionMirror`](../../Shared/Sync/SessionMirror.swift) before returning it. Mirror also observes store changes and serializes ActivityKit operations. | Intents, background fetches and UI changes share the same path. No new view-only hook is needed. |
| Ordinary widgets | `SessionMirror.syncSnapshot`, lines 102–128, atomically writes a changed [`ClockinSnapshot`](../../Shared/Sync/ClockinSnapshot.swift) into the iPhone app group and calls `WidgetCenter.reloadAllTimelines()`; iOS 18+ also reloads controls. [`TodayProvider`](../../ClockinWidgets/TodayWidget.swift) reads the snapshot and builds its timeline. | This already works during granted background execution. The reload is a request, not proof of immediate visible refresh. Without a fetch, the snapshot remains old. |
| Live Activity | `syncActivity`, lines 150–184, ends all activities when idle; otherwise updates existing activities or calls `Activity.request` when none exist. | Updating/ending an existing activity is possible in background runtime. A silent-push callback cannot ordinarily create a new activity with `Activity.request`. Its `try?` hides the thrown detail; remote mode may show `activityUnavailable` later. |
| App opened | [`ClockinApp`](../../Clockin/ClockinApp.swift), lines 63–68, refreshes the mirror on scene changes, starts sync on activation and enables 60-second polling only while active. | Foreground sync catches up and `Activity.request` becomes legal. This explains why opening the app can make the activity appear. There is no suspended 60-second poller. |

Apple permits foreground starts, plus the specific user-invoked `LiveActivityIntent` route; a CloudKit background callback is not that exception. Existing activities can be updated or ended during background execution. [Activity API](https://developer.apple.com/documentation/activitykit/activity)

There is a second current limitation: when currency, calculation inputs, pause state, or remote consent require replacement, `SessionMirror` ends the old activity **before requesting another one**. A background pause or other replacement-triggering change can therefore remove the existing card without creating its replacement. Do not describe every current Live Activity change as a successful background update.

Ordinary widget timelines can continue displaying a known timer baseline without the app running, but cannot discover a new Mac session from an old local file. WidgetKit schedules and budgets refreshes. The source’s dense precomputed earnings entries should not be treated as a promised system cadence. [Widget refresh behavior](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)

Silent notifications may be delayed, coalesced or dropped; Apple gives delivered background work a limited execution window. Foreground polling improves recovery, not suspended reliability. Force quit deserves a separate test: background app launch is normally suppressed until reopening, so hydration and token upload cannot be promised. That does not establish that the OS itself can never show a push-started card. [Background notifications](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app), [Apple DTS: background execution limits](https://developer.apple.com/forums/thread/685525)

Thus there are two independent causes of the reported symptom: **the phone may not receive/apply CloudKit promptly, and even a successful background fetch cannot use the current creation path to start a new Live Activity.** Source inspection establishes these paths; it does not identify which stage failed on the user’s last clock-in.

## 2. Preserve protocol 2; introduce a separate start lifecycle

The relay’s [README](../../../clockin-main/services/live-activity/README.md), [`lib/activity.mjs`](../../../clockin-main/services/live-activity/lib/activity.mjs), [`lib/relay.mjs`](../../../clockin-main/services/live-activity/lib/relay.mjs) and [`lib/apns.mjs`](../../../clockin-main/services/live-activity/lib/apns.mjs) establish the current boundary:

- `PUT /api/v1/live-activity`: per-activity **update token** in `Authorization`, body exactly `{protocol: 2, environment, expiresAt}`; extra fields rejected.
- Registration sends a timestamp update to APNs before retaining the raw token. Conditional writes and token-free stop markers protect registration/deletion races. Expiry cannot be extended beyond the original eight-hour registration.
- Scheduled pushes contain `remoteTick` and `updatedAt`, not work content. APNs metadata uses Unix seconds; current Swift `Date` content uses the 2001 epoch.
- `DELETE` stops relay ticks and removes the raw routing token. It does **not** send ActivityKit `event: end`; today the app ends its local activity separately.
- The adapter fixes Clockin’s APNs topic, uses priority 10, expiration 0 and `clockin-earnings` as its collapse identifier. Requests are capped at 4 KiB and 30/minute per IP/domain.
- [`LiveActivityPrivacy`](../../Shared/Sync/LiveActivityPrivacy.swift) and [`LiveActivityPush`](../../Shared/Sync/LiveActivityPush.swift) require default-off v2 consent. Current uploads require `localState` and `remoteUpdatesUntil`. There is no push-to-start observer or new-activity discovery stream.

Do not add start fields to that allowlist or turn v2 consent into permission to retain an installation token. Proposed `/api/v3/...` resources and a new attributes type coexist with v2. Naming below is illustrative; the data and authorization boundaries are the design contract.

```mermaid
sequenceDiagram
    participant Mac
    participant CK as Private CloudKit
    participant Relay
    participant AK as iPhone ActivityKit
    participant App as iPhone app
    participant Group as Local app group
    App->>Relay: Opt in; register installation start token
    App->>CK: Publish phone-scoped trigger capability
    Mac->>CK: Persist and synchronize clock-in
    Mac->>Relay: Authenticated start for opaque lifecycle
    Relay->>AK: APNs event=start, minimal content
    AK->>AK: Render card with safe initial state
    AK-->>App: Activity discovery and background execution
    App->>Relay: Bind per-activity update token
    App->>CK: Fetch authoritative timer
    App->>Group: Write matching private display snapshot
    App->>AK: Update existing activity to redraw
    App->>App: Request ordinary widget reloads
    Mac->>Relay: End same lifecycle on clock-out
    Relay->>AK: APNs event=end using update token
```

CloudKit’s silent-push path remains active alongside this flow. Neither arrival order is assumed. The relay cannot subscribe to or fetch the user’s private work database.

### Registration and proof that this Mac may trigger this phone

Use **phone-scoped capabilities distributed through the user’s private CloudKit database**, rather than one app-wide API secret or a bearer token compiled into the Mac. A single per-user secret would work as a capability, but compromise/revocation would affect every phone. Per-install scope limits that impact and avoids needing a global user identifier on the relay.

1. After explicit consent, an eligible iPhone generates a random installation identifier, a 256-bit management capability, a separate 256-bit trigger capability, and a separate local correlation key. Management is for token replacement, binding update tokens and deletion; trigger permits only bounded start/state/end commands for that phone. Keep management material device-local in Keychain. Choose protected storage that can support legitimate execution after first unlock; test locked-device access rather than weakening all app data protection.
2. Observe `Activity<ClockinRemoteActivityAttributes>.pushToStartTokenUpdates` on iOS 17.2+, plus any current token. Register the latest token, environment, supported payload variant, consent version, generation and lease expiry over HTTPS. Include a default-false `minuteUpdatesEnabled` preference, writable only by the phone’s management capability and true only with the separate earnings consent. Keep tokens/capabilities in explicitly redacted headers; no secret URLs. Bind the entire enrollment request to a one-time challenge and an App Attest proof for the genuine iPhone app. Store capability hashes, the required raw APNs token, and the minimum attestation verifier material; never an Apple account identifier.
3. Bootstrap is a new security boundary. A random management secret proves continuity only after enrollment. Unlike v2, a test start has visible side effects, so there is no harmless APNs validation tick for a start token. Do not silently create a test activity while registering. Verify attestation and syntax, enforce enrollment quotas, bind each token hash to its owner, and validate actual delivery on the next authorized start. Attestation establishes app integrity, **not** proof of an iCloud account or cryptographic ownership of a supplied APNs token. Treat token theft as credential compromise. If attestation is unavailable, leave remote starts unavailable/retryable rather than introducing an unrestricted public enrollment fallback. [App Attest validation](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
4. Once enrollment succeeds, publish a private phone registration containing the opaque target ID, trigger capability, correlation key, generation, advertised lease expiry and schema support. Use newly introduced encrypted CloudKit fields for secrets; do not put them into the generic synced-preference allowlist, diagnostics, exports, recovery previews or widget snapshots. Apple requires new encrypted fields and production schema promotion before clients depend on them. [CloudKit encryption](https://developer.apple.com/documentation/cloudkit/encrypting-user-data)
5. Put these registration/control records in a separate private zone with a narrowly scoped coordinator. The current `Clockin` zone decoder only accepts its known schema-2 `SyncKind` records; introducing unrelated records there would enter quarantine. Reuse account/environment checks, durable work and cancellation conventions; do not feed credentials through work-record conflict UI. The new zone must actually be fetched on app startup/activation and relevant background wakes. Account change invalidates cached pairing and queued commands.
6. The Mac fetches this registration with the same private iCloud account. It authenticates relay commands using the phone-specific trigger capability in `Authorization`. The server compares its hash and checks scope, generation, lease and quotas. Possession is the authorization proof; a submitted account ID, device name or CloudKit record name alone proves nothing. The Mac never needs the APNs signing key, phone management capability or raw start token.

Any device able to read that user’s private pairing records is in the trust boundary. A stolen trigger capability remains usable until relay revocation/expiry; merely signing a Mac out of iCloud cannot retract an already copied credential. Provide a phone control to revoke/re-pair trusted starts and rotate the trigger generation. If individual-Mac revocation becomes a requirement, add separately scoped Mac grants instead of claiming the shared private record provides it.

### Identity, trigger timing and ordering

The current `RunningSession` has **no UUID**; sync already identifies continuity/completed overlap using `running.start`. Do not use ActivityKit’s generated activity ID or an arbitrary new UUID on every retry as cross-device identity.

For this design, derive a phone-specific `activityKey = HMAC(correlationKey, versioned canonical running.start)` using an exact documented encoding, matching today’s timer identity semantics. Keep the correlation key out of relay requests; using a trigger secret visible to the server would let it guess start dates. Different phones then receive different opaque keys. If the app’s timer identity later changes to a durable generation UUID, migrate this derivation explicitly. Reusing the same exact start value inherits the existing sync identity assumption and needs a regression fixture.

Maintain a separate, small private control record for the lifecycle’s current opaque key and monotonic presentation revision. Allocate revisions with CloudKit conditional writes after resolving the corresponding timer transition; never order multi-device commands solely by each client’s clock or an in-memory counter. Bind the revision to the authoritative timer version locally. The relay only sees the opaque key, revision and coarse phase, not the underlying work record or device identity. Rate/theme edits can refresh local rendering without sending their values.

Trigger once after the Mac’s local save succeeds **and the relevant running state is acknowledged by CloudKit**, with first-merge/account gates satisfied. Hook persisted transitions and acknowledgments, not a menu button, so keyboard commands follow the same behavior. A fetched iPhone-originated clock-in must not echo into a new Mac start. Recheck current running state after awaits. A conflicting winner produces a corrective reconciliation, not a second card for the losing timer.

Use a durable, coalescing outbox. When offline, retain the desired current state; do not replay every historic clock-in. On reconnect, start only if the same lifecycle is still active and eligible, then reconcile the phone. Clock-out/cancel can send terminal end immediately after successful local persistence, even while the CloudKit stop is pending; end dominates later messages for the same lifecycle. Local timer success must not depend on relay availability.

### Payload and on-device rendering

Apple’s contract: push-to-start uses the **start token**, `apns-push-type: liveactivity`, Clockin’s `.push-type.liveactivity` topic, and `aps` containing `event`, Unix `timestamp`, `attributes-type`, `attributes`, `content-state` and `alert`. The attributes/type and content must decode with ActivityKit’s default Codable strategies. The system starts the activity and grants app background execution; capture its separate update token. Advertise iOS 18+ support at registration and include `input-push-token: 1` on that variant; omit it for iOS 17.2. [ActivityKit push contract](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)

Example **proposed v3** start, with illustrative times and opaque identifiers:

```http
POST /3/device/<push-to-start-token>
authorization: bearer <server APNs JWT>
apns-topic: com.erdmncdr.clockin.push-type.liveactivity
apns-push-type: liveactivity
apns-priority: 10
apns-expiration: 0
```

```json
{
  "aps": {
    "timestamp": 1790787600,
    "event": "start",
    "attributes-type": "ClockinRemoteActivityAttributes",
    "attributes": {
      "schemaVersion": 3,
      "activityKey": "opaque-phone-specific-lifecycle",
      "expiresAtUnix": 1790816400
    },
    "content-state": {
      "phase": "running",
      "revision": 1,
      "updatedAtUnix": 1790787600
    },
    "alert": {
      "title": "Clockin",
      "body": "Timer started on your Mac."
    },
    "stale-date": 1790787690,
    "input-push-token": 1
  }
}
```

These numeric `...Unix` fields are explicitly defined `TimeInterval` values in the new Codable types; do not accidentally decode them as default Swift `Date`. Do not copy protocol-2’s 2001-epoch `updatedAt` into this schema. Generate fixtures with the shipping Swift encoder. Omit sound by default; use fixed localized alert strings/keys, never arbitrary Mac-supplied text. The start is user-visible and must be described that way in consent.

The server constructs this payload from strict DTOs; it must not accept arbitrary `aps`, a bundle/topic, an attributes-type string, text, or a destination token from the triggering Mac. Bound combined attributes/content to ActivityKit’s 4 KB limit. An activity lasts at most eight hours; its ended Lock Screen presentation may persist longer. A work session may continue beyond that, so do not automatically restart cards forever. [Live Activity limits](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

The existing [`ClockinActivityAttributes`](../../Shared/Sync/ClockinActivityAttributes.swift) requires a currency and stores `localState` in immutable attributes. [`ClockinActivityState`](../../Shared/Sync/ClockinActivityState.swift) decodes a v2 `remoteTick` into placeholders that only become meaningful when combined with those local attributes. Sending that tick as a start would not produce a useful safe timer. Introduce the separate v3 type and configuration, leaving v2 decoding intact for older installations/activities.

For v3, maintain a small atomic app-group display cache keyed by `activityKey`, with account generation, applied presentation revision, running/paused state, timer baseline, accumulated time, calculation baseline/rate, currency, exchange rate, theme, note and freshness. Derive its values through the existing store/calculation path. This is local content, not the relay registration. The ordinary widget can continue using `ClockinSnapshot`; the Live Activity resolver uses the stricter lifecycle cache.

At render time, use only matching, sufficiently current cache data. A missing file, locked file, stale revision, different lifecycle or unavailable account must render **“Syncing timer…”**, with no amount, fabricated `00:00`, or working pause/stop control. Never display the previous session as the new one. After the app fetches and persists CloudKit data, it writes the cache and explicitly updates the existing activity to trigger rendering; it also reloads ordinary widgets. An app-group write or `reloadAllTimelines()` alone is not a Live Activity update. The Live Activity renderer cannot fetch CloudKit over the network itself. [Shared containers and Live Activity constraints](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy)

The example’s 90-second `stale-date` applies to bootstrap: if hydration is still missing, show “Waiting for iCloud” rather than leaving an apparently fresh card. On successful hydration, explicitly replace that stale date. With minute earnings updates enabled, advance it with valid ticks and show the amount’s freshness. Without that consent, clear the bootstrap stale date for the system-rendered elapsed timer, show when the session last synced, and either omit earnings or label the locally calculated amount “as of” its calculation time. Do not imply that time passing locally proves a fresh remote session state.

This minimal start intentionally contains no historical timer origin: its APNs timestamp is the event-send time, not necessarily `running.start` (Clockin supports elapsed time at clock-in). Accurate elapsed time and earnings require the local cache. If the product requires an accurate numeric timer **even when the phone cannot fetch**, approve a broader variant carrying the real timer anchor/accumulated pause state and disclose those extra session facts. A generic bootstrap is the recommended privacy tradeoff, not a guarantee of full details before hydration.

For v3 minute updates, retain timestamp-only arithmetic input plus the already-known lifecycle phase/revision. Cache data can supply calculation values; paused/newer local state must override an older tick. Mac pause/resume sends only phase/revision changes. When the cache is behind such a transition, hide numeric details until hydration; never keep extrapolating stale earnings through a remote pause. Stop minute ticks while paused. Resume updates the same lifecycle rather than issuing another start. Permit minute ticks only if the existing live-earnings consent is also on; automatic-start consent alone enables lifecycle start/state/end, not earnings ticks.

### End, deduplication and token handoff

Install app-process observers early, including background launches: current activities plus `activityUpdates`, each activity’s `pushTokenUpdates`, and its activity-state stream. Retain/cancel tasks by account/consent generation, and revalidate state after awaits. Token attachment and authoritative CloudKit fetch should proceed independently; do not delay the end-capable token upload while fetching history. The current observer’s `localState != nil` guard must not block v3 activities. [Activity discovery APIs](https://developer.apple.com/documentation/activitykit/activity)

The phone authenticates update-token binding with its management capability and supplies the opaque lifecycle key. Support more than one bound token temporarily for duplicate reconciliation. Validate the token against the fixed topic with a schema-safe update (or end if already stopped) before storing it; an APNs success still does not prove the client rendered it.

End example, sent to **each bound update token**, not the start token:

```json
{
  "aps": {
    "timestamp": 1790788200,
    "event": "end",
    "content-state": {
      "phase": "ended",
      "revision": 2,
      "updatedAtUnix": 1790788200
    },
    "dismissal-date": 1790788199
  }
}
```

`content-state` remains a complete valid v3 state; ended UI never depends on a remaining private cache. A past dismissal date requests removal. `stale-date` merely marks stale content and is not an end/expiry mechanism. [ActivityKit end payload](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)

Use a per-target/per-lifecycle state machine: `reserved → start-submitted → token-bound → ended`, with `dismissed`, `uncertain` and expiry as explicit cases. Conditional storage writes/leases serialize requests; a terminal marker always wins, including when **end arrives before any start record exists**. Reserve before sending APNs. This needs stronger rules than simply copying v2 DELETE.

| Race/failure | Required behavior |
| --- | --- |
| Duplicate Mac command or retry | Same lifecycle/idempotency key returns its existing outcome; no second start push. |
| APNs accepts but relay loses response/crashes | Mark uncertain; do not blindly retry a start that may already be visible. Reconcile phone acknowledgment/current activities. Choosing a possibly missed card is safer than repeated visible starts. |
| iPhone foreground creates one while Mac pushes | Before a local request, reconcile both attribute types and claim the same lifecycle when online. If a push is pending, adopt it. Offline local creation remains possible; on discovery, keep one matching activity deterministically, end extras and clean up every extra token. A brief duplicate cannot be ruled out across disconnected actors. |
| Successful CloudKit fetch sees no local activity in background | Await/adopt push-start discovery. Do not repeatedly call `Activity.request`. Foreground or a legitimate user intent can still use the local path. |
| Push start arrives before CloudKit | Preserve the new activity while authoritative state is unknown; render syncing. Do not let today’s `running == nil → endAll` kill it just because the local store is stale. End only after authoritative stop/mismatch or bounded stale handling. |
| Clock-out before update token | Store terminal marker and cancel unsent start. Immediately end when a token later binds; awakened app also reconciles and ends locally. Without token/app execution, immediate remote removal is impossible. |
| Late start after clock-out | Reject queued commands against the terminal marker; if APNs already holds the start, discovery/token attachment ends it. Never claim zero transient stale cards. |
| Out-of-order pause/resume/tick | Ignore older lifecycle revisions; server serializes accepted updates and emits increasing APNs timestamps. Terminal end is never superseded by update. |
| Manual dismissal | Observe dismissal when runtime permits, retain a suppression marker for that lifecycle, stop ticks and do not recreate it on the next poll. A later, genuinely new clock-in is eligible. |
| Long session reaches eight hours | Stop relay work at the activity deadline; native timers and widgets continue. No automatic repeated alerts to evade lifetime limits. |

APNs is best effort and can reorder/delay delivery. Expiration 0 reduces queued obsolete starts but is not a strict deadline. Collapse IDs and APNs request IDs are not an exactly-once start guarantee. Do not reuse the current constant `clockin-earnings` across new lifecycle event types; define separate safe update collapsing and avoid depending on start collapsing for correctness. [APNs request semantics](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)

### Rotation, retention and abuse controls

Proposed policy values below are Clockin choices, not documented Apple token lifetimes:

| Record/control | Proposed bound |
| --- | --- |
| Installation registration | Renewable 30-day lease from a successful phone-authorized registration/renewal. Only the phone can renew; Mac triggers cannot keep a forgotten install alive. Show renewal-needed status after expiry. |
| Active lifecycle/update tokens | At most eight hours from the activity’s initial start, never extended by retries. End/revoke removes raw update tokens after bounded end delivery attempts. |
| Lifecycle terminal/idempotency marker | Token-free through the original lifecycle expiry plus 24 hours to reject delayed work. Unknown late token attachment receives an end response, never creates an activity. |
| Revoked installation generation | Remove raw start token immediately; retain only the minimum token-free generation/capability-hash marker through the old lease/replay window. Re-enrollment requires a fresh challenge/generation. |
| Enrollment challenges | Single use; expire after five minutes. Bound challenge storage even for unauthenticated traffic. |

Reject fresh start submissions more than two minutes after their signed request time; a reconnecting Mac must re-evaluate current authoritative state before creating a new request. Idempotent acknowledgment of an already-known request must not send it again. Never send from expired registrations even if cleanup is unavailable; remove expired records on the next successful cleanup. Retain attestation verification keys only while the associated installation or necessary revocation marker remains. Application retention promises do not cover provider logs/backups.

Observe start-token rotation continuously while permitted, atomically replace the old token/generation and stop selecting the old token for new sends. APNs update tokens rotate independently: attach new token, retire old, preserve the lifecycle and its end state. Reinstall does not inherit permission merely because Keychain data survived; require local consent/enrollment state for the new install. On account change, revoke old pairing where possible, clear cached grants and never transfer an old account’s queue to a new one. On iCloud sign-out or sync disabled, remote starts become unavailable; local timer functionality continues.

Consent withdrawal cancels observers/new work immediately, ends the relevant remote activities locally, revokes the relay installation and publishes a private pairing tombstone. Keep failed deletion/revocation in a durable queue with “Server cleanup pending.” An offline phone cannot immediately erase a server registration or prevent a Mac using a cached capability until revocation/expiry reaches the server; do not promise otherwise. Independent v2 consent remains independent, so disabling automatic starts need not silently revoke separately chosen earnings updates.

Delete/disable tokens for permanent APNs responses such as `Unregistered`; check topic/environment for `BadDeviceToken`. Retry 429 and transient 5xx failures with bounded backoff/jitter, honoring server guidance. Do not retry invalid payloads or credentials in a loop. A start whose outcome is unknown uses the stricter uncertainty rule above. [APNs response handling](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns)

Keep the existing IP/domain limiter, add durable per-target quotas and an overall service budget. Initial conservative limits: one outstanding/active lifecycle per phone, at most three new starts per ten minutes and twenty per day; burst allowance for state changes with coalescing to the latest revision. Normal duplicate requests should not consume another start. Reserve capacity for end/revoke so the start quota cannot trap a card. Rate-limit enrollment by IP and attested installation, cap registered targets per attested install, and use a global circuit breaker for new starts while preserving cleanup.

Use 4 KiB limits for lifecycle DTOs/APNs payloads; an attestation endpoint may need its own measured, finite larger envelope. Reject unknown fields, oversized identifiers, stale/future request timestamps and invalid lease/environment combinations. Bind challenge/assertion and idempotency to method, route, generation and body hash. Set `Cache-Control: no-store`; provide no public list/read API. Application logs must redact all credentials and content, including custom token headers. Store APNs credentials only in relay configuration. Aggregate counters should distinguish accepted, rejected and acknowledged events; label `APNs 200` as accepted, not displayed. Validate the storage adapter’s conditional-write semantics in concurrency tests before release.

## 3. Consent and what the server newly learns

Add a new device-local setting, **“Show Mac timers on this iPhone”**, default off, with a new versioned consent key outside `SyncPreferences.types`. Existing v2 opt-in is insufficient. Setup requires a prior iPhone launch, available iCloud pairing, iOS 17.2+, system Live Activities permission and successful enrollment. Check `areActivitiesEnabled`; do not make “More Frequent Updates” a prerequisite for a single start/end. Explain minute updates separately.

Suggested consent copy:

> When you clock in on your Mac, Clockin can start a Live Activity on this iPhone, even while the app is closed. A short alert may appear. Our Netlify service in the US stores this phone’s notification address for up to 30 days after renewal and handles start, pause, resume and end times. Pay, earnings and notes are not sent to this service. Apple delivers the activity; timer details may appear after iCloud sync. Turn this off to stop new starts and request deletion.

Offer **“Not now”** and **“Enable”**, a privacy-policy link, enrollment/expiry status and pending-cleanup status. “Closed” must not be expanded into a promise after force quit. Localize the new setting, consent, fallback and alert in the existing localization catalog. Mac settings should show whether an opted-in phone is available and explain the global mirroring control separately.

| Data | Protocol 2 today | Additional v3 exposure |
| --- | --- | --- |
| Routing | Temporary update token, environment, expiry; registration time can already suggest activity timing. | Installation start token, stable target/attestation identifier, token generations and update-token-to-lifecycle links. This is more linkable across sessions. |
| Timing | Minute tick times and bounded per-activity registration. | Explicit Mac start requests, pause/resume/end events, durations inferable between them, acknowledgment timing and recurrence per phone. **The relay newly learns clock-in times operationally**, even if the actual historical `running.start` is omitted. |
| Work content | No rate, earnings, note, currency, exchange rate, theme or session start in payload. | Keep financial/text content off relay. Minimal v3 adds opaque lifecycle identity/revision and coarse phase; therefore “no session-related information” is no longer accurate. |
| Identity/network | Routing token and provider connection metadata. | Phone-scoped linkage and Mac/phone request IP/timing correlation, even without name, email or Apple account ID. Hashing does not make these anonymous. |
| Retention | Eight-hour application registration; provider logs separate. | Separate installation, active lifecycle, anti-replay and attestation retention above. Provider security logs/backups have their own policies. |

Update both languages in [`docs/privacy/privacy-policy-draft.md`](../../../clockin-main/docs/privacy/privacy-policy-draft.md), the rendered published privacy page, [`app-store-disclosure-draft.md`](../../../clockin-main/docs/privacy/app-store-disclosure-draft.md), and the app’s setup/privacy text. Distinguish **not sent to Clockin’s relay** from **never leaves the device**: authorized work sync already uses Apple’s private CloudKit database. Remove the blanket claims that the feature uses only an eight-hour per-activity address and that no start/session timing is processed. Explain installation linking, purpose, retention, deletion retries, US hosting, Apple delivery and separately retained provider data. Review final App Store privacy disclosures against the shipped flow; this design does not assert a legal compliance determination.

## 4. Alternatives

| Option | Benefit | Limitation / decision |
| --- | --- | --- |
| Keep server unchanged; diagnose silent push and widget reload | Smallest privacy and implementation change. Add stage diagnostics and fix any demonstrated fetch/apply/snapshot failures. Existing background widget support is already present. | Useful first step, but cannot make a new Live Activity appear through an ordinary background `Activity.request`; no immediate widget guarantee. |
| Silent push → local notification | After an accepted Mac transition, request a generic “Timer started on Mac” notification and reload widgets. Deduplicate per lifecycle; require normal notification permission, no salary/note in text. | It depends on the same silent push being delivered. The notification itself does not authorize a background activity request; tapping opens the app. Add as a separate optional feature, not a reliable substitute. |
| Foreground/local Live Activity only | No new relay data or longer-lived token. User opens phone or uses a supported intent; v2 can then refresh it. | Clearly communicate the limitation. It does not satisfy automatic remote start. |
| Minimal push-to-start, local hydration (recommended) | Creates a card independently of CloudKit silent-push delivery while keeping work content local. | Adds install registration, event timing, authentication and lifecycle complexity; generic state can persist when hydration fails. |
| Self-contained rich start payload | Immediate correct timer/amount without a CloudKit fetch. | Sends calculation/session content to relay/APNs, contradicting current privacy promises. Do not select implicitly. A narrower timer-anchor-only variant is possible with explicit disclosure. |
| WidgetKit push notifications on supported OS versions | Apple also documents direct widget-refresh pushes; could improve a widget-focused future path. | Separate token/capability/availability work; still budgeted/opportunistic, does not start a Live Activity or itself populate the app-group snapshot. Verify SDK availability for supported releases before adopting. [Apple widget-push documentation](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications) |

Do not embed the APNs signing key in Mac/iPhone code, run background polling every minute, or add fake audio/location work to keep iOS alive. CloudKit silent pushes do not turn the existing relay into an authenticated private-database event listener. A backend that reads users’ work records would be a different privacy design.

## 5. Implementation order and repository split

All items below are future work. The result of this task is this document only.

### A. App repository: this worktree’s iPhone + Mac targets

1. **Measure the existing path.** Add redacted diagnostics for push receipt, fetch/apply outcome, mirror write/reload, ActivityKit request failure and replacement reason. Return meaningful background fetch outcomes. Reproduce on a signed iPhone before assigning the entire symptom to ActivityKit. Preserve first-merge/account gates and foreground recovery.
2. **Define contracts and test fixtures first.** Add versioned remote attributes/state, stable activity-key derivation, ordered lifecycle metadata, safe cache resolver and request DTOs under `Shared/Sync/`. Specify old/new decoding, epoch handling, unknown/missing cache behavior and eight-hour expiry. Keep v2 unchanged.
3. **Add private pairing/control storage.** Create the separate private zone, encrypted secret fields, Keychain storage and account-bound sidecar/outbox. Extend background orchestration to fetch it without routing records through `SyncKind`. Implement generation revocation and lost-key/reinstall behavior. Stage and test CloudKit schema before promoting it.
4. **Implement iPhone enrollment and observers.** Add a dedicated start-registration/lifecycle coordinator alongside `LiveActivityPush`; initialize from `ClockinAppDelegate` rather than a SwiftUI screen. Register start tokens only after new consent. Implement attestation, renewals, activity discovery, update-token binding, rotation and durable cleanup with bounded background work.
5. **Refactor mirror/rendering.** Add v3 configuration in `ClockinWidgets`, local display cache and honest syncing/ended states. Refactor `SessionMirror` to adopt new activities, distinguish unknown local state from authoritative idle, update in place for v3, suppress duplicates/dismissed lifecycles, and reconcile both old/new activity types. Scope controls to the displayed lifecycle and revalidate it before mutating the store.
6. **Implement native Mac triggers.** An app-process service observes successful persisted transitions and CloudKit acknowledgments. Wire it from `ClockinMac/ClockinMacApp.swift`; do not tie it to a window or menu view. Fetch opted-in targets, coalesce durable requests, send authenticated start/state/end and handle expiry/quota responses. Suppress fetch echoes and stale outbox work.
7. **Consent, setup and compatibility.** Update `Clockin/Privacy/LiveActivity*`, registration-status UI and `Shared/Localizable.xcstrings`; add separate automatic-start and earnings-update state. Keep pre-17.2 phones and v2-only clients on existing behavior. New schema feature negotiation prevents sending an unknown attributes type to an old installation. Add Mac mirroring guidance without changing system settings.
8. **Local validation.** Extend `Tests/manual/sync`, `syncapp` and `liveactivityregistry` where appropriate; add focused lifecycle/DTO/cache fixtures. Build iPhone app/widget and native Mac when implementation exists. No build is needed to validate this design-only change.

### B. Relay repository: `clockin-main/services/live-activity`

1. Add versioned enrollment, renewal/revoke, start/state/end and update-token attachment endpoints in new functions/modules. Preserve `/api/v1/live-activity` and its strict protocol-2 body. Define authenticated status responses that reveal only the caller’s resource, if needed; never add a public token inventory.
2. Implement attestation challenge/verification, capability scopes/hashes, per-install lease and conditional lifecycle state machine. Include unknown-end tombstones, uncertain APNs outcomes, token attachment after stop and per-target/global limits.
3. Split payload construction and APNs options by protocol/event. Use the fixed app topic and tested OS variant, bounded attributes/state, alert only for start, and terminal `event: end`. Keep APNs acceptance distinct from phone acknowledgment.
4. Extend scheduled cleanup/ticks with isolated v3 prefixes/store configuration, hard expiry and revocation. Preserve v2 scheduled behavior. Provide a kill switch that blocks new v3 enrollment/starts while continuing end/revoke/cleanup and v2 service.
5. Add in-memory tests and a truly isolated integration environment. The existing README warns that previews share site-wide Blobs: **do not test mutating requests or manual ticks against a normal preview**. Use a separate store/site and controlled APNs environment; verify isolation before any mutation.
6. Update relay README, privacy source/rendered policy and disclosure draft; verify the exact data actually stored/logged, cleanup bounds, rate limits and costs. Run relay tests and a functions build; prepare a reviewable deployment diff and rollback plan preserving the published website and existing functions.

### Production approval boundary

**A production relay deployment requires the user’s explicit approval. This design request authorizes no deployment.** The new functions, storage behavior, APNs payload handling, scheduler, published privacy page and production configuration require that deployment. A CloudKit production schema promotion and app distribution are separate release actions, not effects of writing this document. No new APNs key or paid service is assumed; the relay README records a production-only key, so development APNs may need an independently approved sandbox setup.

Prepare and validate the concrete function/policy artifacts, isolated-test results, migration order and rollback first; then ask for approval as the final production step. Deploy compatible relay/policy/schema support before enabling the corresponding client feature. Release the iPhone receiver/enrollment before depending on Mac triggers. Old v2 clients remain supported. Rollback disables new starts but continues termination/cleanup until outstanding v3 leases and activities are dealt with; it must not orphan active cards or restore the old privacy text while v3 data remains.

## 6. Real-device proof required before release

Use a signed Mac and physical iPhone on the same intended iCloud environment, with first merge completed. Record app builds/OS versions, APNs environment, CloudKit environment, consent/permission states and network condition. Test iOS 17.2 and an iOS 18+ payload variant where supported devices are available; include the current shipping OS. TestFlight uses production APNs, so a sandbox-only success is insufficient. Enroll once, then leave the iPhone app unopened for the core scenarios.

| Scenario | Evidence/pass criterion |
| --- | --- |
| Baseline without new opt-in | Mac clock-in, phone background/locked: distinguish push delivery, applied snapshot, widget reload and missing new activity. No v3 token enrollment occurs. |
| Ordinary suspension and OS termination | Mac clock-in produces one visible Lock Screen/Dynamic Island activity without opening the phone app. Record generic-card and hydrated-detail times separately; verify correct elapsed time, rate/currency and note locally. |
| CloudKit delayed/unavailable | Push start still has a usable generic presentation; no old session/amount leaks into it. Restoring CloudKit hydrates the same activity and refreshes widgets. |
| Phone offline/reconnect; Mac offline/reconnect | No burst of past sessions. Ended offline lifecycles are never deliberately restarted. Late APNs delivery is reconciled; document transient stale display if observed. |
| Pause/resume and backdated clock-in | Correct baseline and paused amount after hydration; generic paused state while behind; no endless replacement loop or counting from APNs send time. |
| Clock-out/cancel | Relay end removes the card without opening the app when an update token is available. Repeat stop before token, before start submission, and immediately after start acceptance. Verify terminal markers and eventual cleanup. |
| Simultaneous phone/Mac start | Foreground local request, pushed start and repeated requests converge to one correct lifecycle. Record any transient duplicate, then verify all extra tokens are retired. |
| Dismissal, expiry, long session | Manual dismissal is respected for that lifecycle; next new session can start. Eight-hour cleanup does not end the underlying work session or cause restart alerts. |
| Rotation and identity | Exercise start-token replacement, update-token replacement, app upgrade, reinstall, iCloud sign-out/account switch and two opted-in phones. No cross-account targeting or lost end state. |
| Opt-out and OS permissions | Start feature off/v2 on and start on/v2 off both behave independently. Withdraw consent online/offline; inspect pending cleanup and revoked-grant rejection. Live Activities disabled and frequent updates disabled are tested independently. |
| Force quit/reboot/power restrictions | Test user force quit separately from OS termination, locked reboot before first unlock, Low Power Mode, Background App Refresh off, Focus and denied notification alerts. Report actual card/hydration/token behavior; do not convert one successful observation into an OS guarantee. |
| Mac mirroring | With the global iPhone Live Activities switch off, native Mac item stays, iPhone card stays and mirrored Mac card disappears. Verify without disabling iPhone Live Activities. |

In development, log redacted correlation identifiers and monotonic measurements for **Mac persisted → CloudKit acknowledged → relay accepted → APNs accepted → phone activity observed → data hydrated → visibly ended**. Capture actual device screen evidence and widget state; an `APNs 200`, a simulator notification, a build, or relay counters alone are not proof. Use [Apple’s Push Notification Console](https://developer.apple.com/documentation/usernotifications/testing-notifications-using-the-push-notification-console) for controlled delivery investigation, not as a substitute for the real Mac trigger flow.

Local tests must cover Codable golden start/update/end payloads; v2 rejection of new fields; credential scope/replay; expired leases; delete-versus-register and stop-versus-start races; concurrent writers; timeout-after-APNs-acceptance; reverse revisions; local-cache lifecycle mismatch; stale nil-store versus authoritative idle; duplicate discovery; token rotation; and opt-out during in-flight enrollment. Verify HTTP bodies and stored records contain no rates, amounts, notes, currency, theme or work-history data. Use synthetic fixtures and isolated stores.

The remaining platform limitation is explicit: push-to-start improves automatic appearance, but does not guarantee immediate delivery, CloudKit hydration, or immediate clock-out cleanup without an update token. The proposed fallback and lifecycle rules make those failures understandable and bounded instead of displaying fabricated work data.

## Verification of this deliverable

Source paths above and Apple primary documentation were reviewed. Local-link existence, JSON payload syntax, Markdown fence balance and whitespace were checked. The worktree status contains only this new result document; the relay checkout’s pre-existing status is unchanged. This report distinguishes current behavior, proposed contracts and unperformed device checks. No source implementation or production state was changed.
