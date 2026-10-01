# 21: Double-check result

Reviewed `ddb33c2..0f4b7ee` on 2026-10-01, concentrating on the app/shared source and the callers named in the brief. HEAD `f7b3e71` adds only the review brief after that range. Documentation was context, not evidence of correct runtime behavior. No source changes were made; additional probes and logs are under `/tmp/clockin-21-review/`.

**I would hold iOS 0.2 (52) for the Live Activity recovery issue below, and fix the two notification false-positive paths before shipping this feature. I found no blocking Mac 2.0.7 regression in the reviewed source.** The unbounded notification history is a lower-priority follow-up. All **45/45 README check commands passed**.

## 1. [P1] An interrupted replacement can leave two cards that foreground refresh does not reconcile

**Location:** `Shared/Sync/SessionMirror.swift:175–190`, particularly the request prerequisite at **189**; cleanup at `244–250`.

**Scenario:** A foreground change requires different immutable attributes, for example USD → EUR. `request` successfully creates the EUR card, then the process is interrupted before the asynchronous `endAll(except:)` completes. ActivityKit can retain both cards across process death. On relaunch, the USD card makes `activities.contains` report that replacement is needed, even though the EUR replacement already exists. The code requests a third card. If that request fails, it never reaches cleanup, and subsequent foreground refreshes repeat the same operation. A matching, usable replacement does not help it recover.

This also leaves the old activity's relay registration live: the stale token is still attached to an existing activity, so registration reconciliation does not identify it as an orphan. An additional request is allowed to fail because of an activity limit; Apple documents both concurrent activities and `targetMaximumExceeded`, without promising a fixed capacity. [ActivityKit lifecycle](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities), [capacity error](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/targetmaximumexceeded).

**Evidence:** The temporary activity probe extracts the production `syncActivity`, serialized queue, request, update and end methods. It substitutes ActivityKit/UIKit/relay boundaries and initializes the post-interruption state with an old USD card and its already-created EUR replacement. With further requests denied, three foreground reconciliations produce:

```text
requests=3, ends=0, alive=["old-USD", "replacement-EUR"]
```

This is a deterministic recovery-logic reproduction, not an on-device process-kill test. The source adaptations are public probe entry access and an explicit generic argument for the fake Activity type; the lifecycle branches are unchanged. Files: `ExtractedMirror.swift`, `activity-probe.swift`, `activity-probe.log` under the probe directory.

**Fix:** Reconcile the existing collection before requesting. If a card already has the desired immutable attributes, retain/update/observe it and end the others without another request. Otherwise retain one fallback while attempting replacement, and make interrupted cleanup recoverable on the next launch. Test interruption immediately after request, then foreground recovery with requests denied, as well as ordinary request failure with only one old card.

## 2. [P2] Loaded and restored phone timers are not added to notification suppression history

**Location:** `Clockin/Notifications/RemoteClockInNotification.swift:27–35` and **47–53**. Related successful restore: `Shared/Core/ClockStore.swift:647–653`.

**Scenario:** A timer was started on the iPhone before installing this version, or was restored there from a backup. Attaching the detector does not remember the loaded timer. Restore calls `save()` but emits no `didClockInLocally` event, so that identity is not remembered either. Even an identical sync apply returns at line 48 before remembering it.

Discard that timer on the phone while a Mac still has its older running copy. If the Mac later pauses/resumes or otherwise changes that copy and its newer revision wins, the phone receives a start it previously knew locally. Because its visible timer is now nil and the handled-start list lacks that start, it posts **“Clocked in on your Mac”**. No new Mac clock-in occurred. This scenario uses **Discard**, not normal clock-out: completed-session facts suppress resurrection after normal clock-out in `SyncMerge.swift:309`.

**Evidence:** `notification-probe.swift` uses the production detector and real store/archive paths. Loading a local timer and applying its identical echo leaves `handled=0`; restoring another timer also leaves its identity absent. `sync-probe.swift` then exercises the real coordinator, sidecar/merge and store with the existing fake-transport fixture. A later Mac edit of the pre-upgrade phone timer produces one notification; the analogous restore/discard/edit case produces a second. All final assertions pass. No CloudKit or notification service is contacted.

**Fix:** Treat the current archive and successful restores as a silent baseline. Remember their running identity before it can disappear; also remember same-start sync arrivals even when they should not alert. Keep this distinct from a genuinely new remote arrival. Add upgrade/load → discard → later remote edit and restore → discard → later remote edit regression cases. This can improve suppression without claiming that a start date proves the sender's hardware.

## 3. [P2] Initial merge can announce an old timer as a new remote clock-in

**Location:** `Clockin/Notifications/RemoteClockInNotification.swift:47–59`; event emission at `Shared/Core/ClockStore.swift:1082–1088`. Initial approval applies through `Shared/Sync/Cloud/SyncBridge.swift:81–86`.

**Scenario:** First merge contains an old running/paused session. The user approves in the foreground and leaves the app while the safety backup is awaited. When approval resumes in the background, applying that initial snapshot emits the same event as an ordinary remote start. The detector only checks the application state at apply/submission time; it has no initial-merge context. It therefore announces a historical timer, potentially an old phone timer recovered through another device, as a Mac clock-in.

**Evidence:** The coordinator probe stages a seven-day-old paused timer and confirms zero notifications before approval. It begins approval, verifies the timer is still unapplied, changes the injected application state to background, and awaits completion. Result:

```text
first-merge staging: notifications=0
first-merge approval completes after backgrounding, 7-day-old paused timer: notifications=1
```

The usual foreground approval is suppressed correctly; the asynchronous transition exposes this path.

**Fix:** Carry apply provenance, or explicitly baseline notification identities during initial merge. Initial import/recovery should consume the identity without notifying, regardless of whether the app changes state during the backup await. Preserve alerts for subsequent new remote starts. A simple age cutoff alone would also suppress legitimate delayed sync or backdated manual starts, so it is not a complete substitute for provenance.

## 4. [P3, nonblocking] Handled starts grow forever, including while notifications are off

**Location:** `Clockin/Notifications/RemoteClockInNotification.swift:38–42`, used before the enabled/active check at **53–54** and on every local clock-in at **30–31**.

**Scenario:** Every unique local or remote start is permanently appended to a UserDefaults array. Each addition reads/scans/rewrites the entire array on MainActor. There is no retention bound, including when the setting is off or permission is denied.

**Evidence:** With the setting off, 1,500 additional local-start events retain all 1,500 dates. The fixture's 1,502-date array serializes to 19,572 bytes. This is modest today and is not a release blocker; the growth and per-event work are unbounded over the lifetime of the installation.

**Fix:** Define a bounded notification eligibility/replay policy, then prune identities outside it while preserving the current/local baseline. Pair a bounded recent set with an appropriate persisted cutoff or watermark. Simply truncating the array would reintroduce old-timer alerts when forgotten starts reappear.

## Other requested checks

- **Background replacement and intents:** `.keep` preserves a card while inactive/background; the initial and subsequent active scene hooks retry reconciliation. With no activity, `.request` remains available to `LiveActivityIntent`. The intent definitions use the app's `SharedStore.clock` and await the mirror; no separate widget-process store was introduced. The accepted stale-presentation behavior while replacement is deferred remains present.
- **Clock-out and pending work:** The idle branch is unconditional and sets `lastState = nil`, invalidating queued running-state work. `finishPendingUpdates()` performs a synchronous reconciliation and awaits the serialized activity tail before notification scheduling/relay cleanup. The extracted probe ends both existing cards on background clock-out. No new logical path that permanently loses a persisted idle state was found. This does **not** establish that ActivityKit receives an end before an arbitrary OS suspension: if suspension precedes the async end, the next granted execution must reconcile the persisted idle store again.
- **Relay cleanup:** The ordinary end path captures token/expiry, ends the activity, then stops observation/uploads and queues deletion. Known registration reconciliation and deletion expiry remain intact. Consent-off `.keep` calls `stop` despite retaining the card. The duplicate-recovery problem above is an exception because neither stale-card end nor stop is reached when the extra request fails.
- **Notification suppression:** New local starts recorded by this version, ordinary same-start pause/resume/rate/note edits, already-handled arrivals across notifier recreation, active-app arrivals, opt-out, denied/not-requested permission, failed persistence and the pre-submission activation/clock-out races pass the existing focused checks. The setting is absent from the sync allowlist. The adapter only reads permission during delivery; prompting remains tied to a settings action. Claim-before-await deliberately means failed/interrupted submissions are not retried; that is the documented at-most-once policy, not an exactly-once delivery guarantee.
- **Fetch result mapping:** The new counter measures actual before/after persisted app-snapshot changes, rather than fetch attempts. The 82-check coordinator suite covers changed running/idle, identical snapshots, repeated empty passes, errors and first-merge/off gates. No new `.newData`-forever or missing return branch was found. Each delegate switch branch returns a result, and irrelevant pushes return early.
- **Fetch duration remains a device-test requirement:** Awaiting the coordinator and mirror does not synchronously block MainActor, but there is no overall wake deadline. The existing relay path can spend roughly 19 seconds on three five-second attempts plus two two-second delays, in addition to CloudKit and notification work. CloudKit waits have no app-level deadline here. This was already on the delegate's awaited path before this diff; the new result enum does not solve it. Apple grants up to 30 seconds for the background notification callback. A slow-service/expiration test is still needed; no bounded-completion claim is supported by the offline suites. [Apple delegate contract](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:didReceiveRemoteNotification:fetchCompletionHandler:)).
- **Mac tip:** Moving the post-persistence events into shared code leaves their Mac timing and the Mac subscriber unchanged. The 27-check Mac suite passes. Local detection still uses only the latest local start, as already specified for that advisory heuristic; it does not prove an iPhone sender or actual mirroring. Dismissal and notification-settings fallback remain device-local.
- **Mac Settings sheets:** The new modifier is applied once outside the destination `Group`, so it reaches the destination's NavigationStack/Form. It applies grouped form style and minimum/ideal sizing, with flexible maxima; it is not a fixed-height content clip. The rate editor keeps its own `macSheetFrame(width: 480, height: 460)`. The modifier is a no-op on iOS. No blocking source regression was found in these paths.

## Verification and limits

- **45/45 README commands passed**, with no `xcodebuild`. Commands lacking an explicit module cache received only `-module-cache-path /tmp/clockin-21-readme-cache`. Commands, exact executed variants, exit codes and individual output are in `/tmp/clockin-21-review/readme/results.json` and `01.log`–`45.log`. This includes the five-year sync simulation, both platform typechecks, **82** coordinator checks, **27** Mac tip checks, **18** notification checks and **8** Activity decision checks.
- Additional detector/archive, real-coordinator/fake-transport and extracted lifecycle probes are under `/tmp/clockin-21-review/`. Their scope is stated alongside each finding; they do not emulate iOS suspension, actual notification presentation or APNs delivery.
- A native AppKit hosting probe used the **production `PlatformModifiers.swift`** with a 500-row Form inside NavigationStack and a nested sheet containing the rate editor's field arrangement. Both sheet contents stayed at **460 × 420 pt** minimum size; fitting sizes were **560 × 680** and **480 × 460**. The captured form viewport and editor fields were inspected. These are isolated content/layout checks, not the actual SwiftUI Settings navigation or toolbar interaction. Artifacts: `mac-layout-probe.swift`, `mac-layout-probe.log`, `layout-form.png`, `layout-editor.png`.
- Compiling the fuller actual rate-sheet harness was blocked by `sandbox-exec: sandbox_apply: Operation not permitted` when the SDK's SwiftUI `@State` macro plugin tried to run. This is an environment limitation, not a reported source defect. Log: `mac-compile.log`. No permission escalation was attempted.
- No signed iPhone/Mac run, ActivityKit runtime test, production relay call, release upload or deployment was performed. The app-source changes were syntax-parsed for both target platforms; final whitespace and source-unchanged checks are recorded with the review artifacts.
