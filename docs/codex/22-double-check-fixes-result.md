# 22: Double-check fixes result

Implemented on 2026-10-01 against this worktree's start commit, `6b7f77fb6de18be7be6cef61db6cd91ec22d12b8`. Addresses all four findings in `21-double-check-result.md`. The review's probes under `/tmp/clockin-21-review/` informed the regressions; fresh evidence is under `/tmp/clockin-22-fixes/`.

## Changes

### 1. Live Activity reconciliation before request

`SessionMirror` first selects an existing card with compatible immutable currency, remote-update consent and frozen calculation inputs. Matching uses the immutable `localState`, not mutable content that a tick or older implementation may have changed. It retains that card, ends every other card through the existing end/relay-stop path, updates the retained card and resumes observation without another request. Selection is deterministic even when several cards match.

If none match, it retains one fallback and removes the other duplicates before attempting replacement. A failed request leaves that fallback alive. If execution stops after a successful request but before cleanup, the next refresh selects the existing replacement and finishes cleanup even when further requests are denied. The serialized queue still invalidates stale running work after idle. Background replacement retains the fallback; an empty slot still reaches the intent-compatible request path. Consent-off cleanup also stops a retained registration when a foreground replacement request fails.

### 2. Silent notification baselines

`RemoteClockInNotification.start` remembers the timer already in the loaded archive. The existing post-persistence `didPersist` event remembers successful local writes, including backup restores, before the timer can be discarded. No restore is misrepresented as a local clock-in, and no new store events were introduced for the Mac subscriber.

Every successful synced-running apply remembers its current identity before checking same-start, application state, preference or notification permission. Thus an identical echo establishes a baseline, while load/restore -> discard -> later remote edit remains silent. A genuinely new remote start remains eligible.

### 3. Initial-merge provenance

`RunningApplyProvenance` travels from `SyncBridge` through `SyncCoordinator.apply` and `ClockStore.applySynced` into the existing synced-running event. First-merge approval always supplies `.initialImport`; ordinary subsequent receives supply `.remoteChange`. Initial imports consume their identity silently regardless of foreground/background changes during the safety-backup await. Archive loading/recovery and backup restoration use the silent baseline paths above.

This does not infer provenance from a timer's age: the coordinator regression imports both a seven-day-old paused timer and a recent timer while transitioning to the background, then confirms that a later, genuinely new remote start older than either can still notify.

The backup operation has an injectable boundary so the coordinator test can suspend approval deterministically, change app state, and release the real safety-backup operation. Production still uses the same `SyncSidecarStore.backup` implementation and revision checks.

### 4. Bounded replay history

The detector retains at most **256 unique start dates**, ordered by start time, plus `Clockin.RemoteClockInHandledCutoff.v1`. Eviction advances the cutoff monotonically to the greatest forgotten start. A start at or below that watermark is permanently ineligible for a new notification; recent known starts remain suppressed by membership. The watermark is written before shortening the array. Existing v1 arrays are pruned when the detector attaches, even with no running timer and notifications disabled.

Pruning also runs on local persistence and synced applies before the notification setting check. Tests cover a 1,500-entry legacy array, another 1,500 local starts and 400 remote arrivals while opted out, recreation/re-enabling, exact cutoff equality and unseen older starts. A current/local identity is covered by either the retained set or the cutoff. As the deliberate bounded eligibility policy, even a previously unseen delayed start at or below the cutoff stays silent; this is separate from initial-import provenance and does not use elapsed wall-clock age.

The notification preference, history and cutoff remain device-local. The catalog and notification text are unchanged. `MacLiveActivityTip.swift` is unchanged; its existing event timing and previous/current values remain identical, and it ignores the additional provenance field. Added code comments use ASCII Turkish.

## Regression evidence

- `Tests/manual/iphonefollowsmac/run`: **34 notification checks**, **8 decision checks**, **16 lifecycle checks**. Real store archives/defaults and detector code are used for notifications. The lifecycle runner extracts the current production `syncActivity`, queue, request, update and end methods on each run; it only exposes the probe entry point, spells out a fake generic type and replaces ActivityKit/UIKit/relay boundaries. The real attributes/state remain in use.
- The interruption test successfully requests a replacement, suspends the first cleanup at the fake `end` boundary, then runs a fresh mirror against the surviving cards with requests denied. Three refreshes retain one updated/observed replacement and remove the old registration without another request. The suspended original operation is released only after those assertions.
- `Tests/manual/syncapp/run`: **97 checks**, including real coordinator/bridge/sidecar/store coverage for load/restore -> discard -> later remote edit, controlled backup-await backgrounding for recent and historical initial imports, subsequent echoes and older genuine remote starts. The fake editor now retains its sender sequence between edits, so successive deliveries cannot accidentally reuse an immutable revision identity.
- Red runs reproduced the requested failures before their fixes: `p1-red.log` (interrupted replacement), `p2-red.log` (loaded baseline), `p3-red.log` (initial approval completing in background), `p4-red.log` (unbounded opt-out history). `p1-attributes-red.log` additionally catches matching against mutable rather than immutable calculation inputs. Passing focused output is in `focused-final.log`; the full README run below is the final verification.

## Full verification

**45/45 README check commands passed**, with no xcodebuild. This includes the five-year sync simulation, both-platform CloudKit/coordinator typechecks, the real iOS notification/ActivityKit/relay source checks, and the unchanged **27-check Mac tip suite**. Commands without a module cache received only `-module-cache-path /tmp/clockin-22-readme-cache` so their cache stays in a writable directory.

Exact README commands, executed variants, exit codes and durations are in `/tmp/clockin-22-fixes/readme/results.json`; individual output is in `01.log` through `45.log`. The run summary is `/tmp/clockin-22-fixes/readme-run.log`. Every command exited zero. Counts below use suite summaries; suites without a numerical summary are labeled with their printed check groups instead of inventing an assertion total.

| Log | Suite | Passing checks / coverage |
| --- | --- | --- |
| 01 | `sync` | 268 |
| 02 | `sync typecheck` | 2 platform targets |
| 03 | `sync codec` | 33 |
| 04 | `sync send` | 37 |
| 05 | `syncapp` | 97 |
| 06 | `syncapp typecheck` | 2 platform targets |
| 07 | `macliveactivitytip` | 27 |
| 08 | `iphonefollowsmac` | 34 detector + 8 decision + 16 lifecycle |
| 09 | `iphonefollowsmac typecheck` | 2 iOS source sets |
| 10 | `wardrobe` | 2898 |
| 11 | `skins` | 6 printed check groups |
| 12 | `armorhd` | 7 printed check groups |
| 13 | `radio` | 109 |
| 14 | `celebrations` | 125 |
| 15 | `rolling` | 197 |
| 16 | `haptics` | 61 |
| 17 | `levelup` | 27 |
| 18 | `levelprestige` | 42 rank boundaries; 500-level identity |
| 19 | `snapshot` | 124 printed checks |
| 20 | `import` | 102 |
| 21 | `backups` | 38 |
| 22 | `overlap` | 47 |
| 23 | `raterange` | 9 |
| 24 | `earnings` | 284 |
| 25 | `historytry` | 87 |
| 26 | `insights` | 148 |
| 27 | `mascot` | 270 |
| 28 | `companion2` | 694 |
| 29 | `companion` | 17 |
| 30 | `momentum` | 17 |
| 31 | `share` | 27 |
| 32 | `widgettheme` | 30 |
| 33 | `chime` | 29 |
| 34 | `chimesound` | 96 |
| 35 | `controls` | 13 |
| 36 | `reminder` | 44 |
| 37 | `nudges` | 93 |
| 38 | `goals` | 42 |
| 39 | `sessions` | 20 |
| 40 | `maccompat` | 375 |
| 41 | `macmigration` | 51 |
| 42 | `rates` | 84 |
| 43 | `feedback` | 22 |
| 44 | `sessiondisplay` | 61 |
| 45 | `liveactivityregistry` | 11 |

`git diff --check` passes. The catalog and `MacLiveActivityTip.swift` are byte-identical to the start commit; the new notification watermark/history keys are absent from the sync allowlist. No localization compilation was necessary because no text/catalog entries changed.

## Physical-device follow-up

These are offline regressions and SDK checks, not a signed ActivityKit/CloudKit/notification-delivery run. Before release:

1. On a signed iPhone, change currency/calculation/consent with an existing activity, interrupt just after replacement request, relaunch with further requests denied, and verify exactly one matching Lock Screen/Dynamic Island card and deletion of the old relay registration. Separately fail a request with only one old card and confirm it remains.
2. Load a pre-upgrade phone timer, discard it, then apply a newer Mac pause/note edit of that same start. Repeat with a restored backup timer. Neither should notify; a new Mac start while the phone is backgrounded should notify once.
3. Approve the first merge with an existing remote timer and background the phone during backup. No notification should appear for the imported timer or a later edit of it. Repeat with both recent and old starts.
4. Recheck background clock-out, foreground recovery, notification tap routing and the unchanged Mac tip/dismissal. Confirm actual silent-push execution separately from app apply behavior.

No xcodebuild, signed-device run, production relay call, release upload or deployment was performed. Existing OS wake/delivery limitations and the previously documented background-fetch deadline validation remain device-test work.
