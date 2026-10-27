# 34: Security review result

Codex ran read-only on 2026-10-28 and could not write this file itself; the report below is its output, unedited.

---

**34 — Security review result**

Reviewed the current checkout, including the extension, receiver, static website/deployer, and both apps’ persistence. `services/live-activity` was excluded.

No High finding was established. Verification included source inspection, filesystem metadata inspection without reading personal data, and an in-memory JavaScript harness. No real timer commands, deployments, credential reads, or device-lock tests ran.

**1. Pulse Chrome extension**

**Medium — Another process running as the same user can bypass command confirmation.**  
`ClockinMac/ChromeNativeHost.swift:16–24`, `ClockinMac/ExternalClockCommand.swift:57–77,103–110`, `Shared/Sync/AppGroup.swift:19–30`.

Any local process can launch the app executable with a `chrome-extension://…` argument and supply framed command JSON; the host does not authenticate its launcher. Separately, the same user can read or pre-plant `pulse-pass`: on Mac it resides in ordinary `~/Library/Application Support/Clockin`, not an App Group container, and `0600` does not isolate processes sharing a UID.

Smallest safe fix: require confirmation for these externally initiated commands until an authenticated helper channel replaces file/argument-based trust. Checking the origin argument alone does not authenticate Chrome.

The inspected installation had `Library` and `Application Support` at `0700`, protecting these paths from ordinary different-UID users. `Clockin` was `0755`; `clockin.json` was `0644`; no `pulse-pass` existed. These observations do not establish same-user protection.

**Medium — The page can poison button selection with synthetic clicks.**  
`ClockinMac/ChromeExtension/picker.js:117–132,149–154`.

While picking is active, page JavaScript can dispatch two untrusted clicks and cause attacker-selected descriptors to be saved. Synthetic Escape or a click on the injected Cancel control can also cancel selection; the advertised ten-minute expiry is checked only at script initialization (`:25–30`).

Smallest fix: reject untrusted click/key/cancel events and enforce expiry when handling selections. The in-memory harness confirmed that two untrusted clicks produce a `save` message.

**Medium — “Remove” does not stop watchers already running in open tabs.**  
`ClockinMac/ChromeExtension/background.js:66–77`, `watch.js:5–8,129–139`.

Reset deletes storage and unregisters future injections, but an existing watcher retains its captured setup and listeners. Its later commands still pass through the background handler, so timer control continues after the user removes the integration; changing sites also leaves old tabs active.

Smallest fix: validate current setup, sender origin/frame, and setup generation in the background before forwarding every command; notify existing scripts to stop on reset/reconfiguration. Chrome documents that unregistering scripts does not remove already-injected code. [Chrome scripting documentation](https://developer.chrome.com/docs/extensions/reference/api/scripting)

The harness confirmed a command reaching the mocked native transport after reset.

**Low — Unknown labels can become clock-out commands.**  
`ClockinMac/ChromeExtension/watch.js:28–41,54–65,123–135`.

In same-button mode, a sufficiently similar element with any non-start label becomes `clock-out`, even when its label matches neither selection. A page controls all scored attributes and can relabel, duplicate, overlay, or remove elements to misdirect genuine clicks or suppress commands.

Smallest fix: require an explicit recognized start/stop label and fail closed on unknown labels. A genuine click proves interaction, not that the page faithfully represents the intended command.

**Low — Granted site permissions accumulate.**  
`ClockinMac/ChromeExtension/popup.js:60–67`, `background.js:55–69`.

Selecting another site or removing setup never calls `chrome.permissions.remove`, leaving access to previously approved origins. This exceeds the extension’s stated one-site scope.

Smallest fix: revoke obsolete origin grants on replacement/reset and expire abandoned picking grants.

**Low — Pass deletion and expiry are incomplete.**  
`ClockinMac/ExternalClockCommand.swift:65–77,100–109`.

An already-satisfied command returns before redemption, and the `ownProcess || redeem(...)` short circuit skips redemption for the expected sender. Delivery failures also leave the pass behind; there is no expiry or command binding, and permission/deletion errors are ignored.

Smallest fix, if the pass remains: bind it to the command and short expiry, consume it even on no-op/trusted-sender paths, and fail closed on protection/removal failure. This does not resolve same-user forgery.

**Note — Native-host registration and unpacked installation trust the local account.**  
`ClockinMac/ChromeNativeHost.swift:83–101`, `ChromeExtensionInstaller.swift:12–22,49–60`.

The host manifest contains exactly `chrome-extension://iaikoicampaamoakicipdacniaaonkpc/` and an absolute `Bundle.main.executablePath`, avoiding PATH lookup. However, the per-user manifest and unpacked extension files are writable by the same account, allowing local substitution; the public manifest key fixes an ID, not code authenticity.

Smallest fix: document this trust boundary; use signed extension distribution if resistance to unpacked-file tampering is required. Browser-origin restrictions are enforced by Chrome, not by arbitrary direct execution of the host. [Chrome native messaging documentation](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)

**Checked and fine**

- No `externally_connectable`, external-message listener, or page-to-extension `postMessage`/custom-event bridge exists. `pulse:command` is outbound only (`watch.js:110`). Ordinary page JavaScript cannot directly call this extension’s internal message handler; content scripts use an isolated world. [Chrome isolation](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts), [external connectivity](https://developer.chrome.com/docs/extensions/reference/manifest/externally-connectable)
- `watch.js:124,132` rejects untrusted events; the harness verified synthetic-click rejection. No page-only, zero-interaction command path was established.
- Native payload is only `{action}` (`background.js:32`). Page titles, URLs and text are not forwarded to the Mac app.
- Browser-local storage retains origin, selectors, button text/attributes, pending selections, last action/time/result, and near-miss text (`picker.js:81–88,123–131`; `background.js:37–58`). Labels are bounded to 80/60 characters; other descriptor strings are not similarly bounded.
- Popup values use `textContent` (`popup.js:25–49`); no HTML injection sink was found.
- All four declared permissions have uses: storage, scripting, active-tab URL access, and native messaging. Broad host patterns are optional, requested for a selected origin; injection is top-frame only (`background.js:18`).
- Native framing is bounded below 1 MiB, and receiver parsing permits only clock-in/clock-out command hosts (`ChromeNativeHost.swift:68–72`; `ExternalClockCommand.swift:16–22`).

**2. Static website**

**Medium — A website deploy can restore stale relay functions over a newer deployment.**  
`website/tools/deploy:179–191`.

Relay digests/routes/schedules are captured once, before the draft is created and checked. If another deployment updates the relay meanwhile, publishing the website reuses the old snapshot and can undo that update, including a security fix.

Smallest fix: serialize website/relay deployments and reject publication if the published deployment ID changed since capture. Promote the verified draft rather than constructing a second independent production deployment where supported.

**Low — Draft verification does not establish exact relay preservation.**  
`website/tools/deploy:155–172`.

Post-deploy checks compare function names and schedules, then inspect download/privacy markers and a health response. They do not compare returned function digests/routes/configuration with the captured values or exercise `admin` and the scheduled function; production APNs configuration is checked only after publication.

Smallest fix: compare returned digests and preserved routing/configuration before publication, alongside the existing checks. Treat these checks as preservation/health checks, not functional relay verification.

**Low — Security-header policy is absent from the static deployment input.**  
`website/netlify.toml:1–2`, `website/tools/deploy:80–99,135–139`.

The TOML only specifies `publish`; there is no checked-in `_headers` file or explicit CSP, framing policy, Referrer-Policy, or HSTS. The custom digest deploy does not read the TOML, so adding headers there alone would not configure this deployment path.

Smallest fix: ship a `website/dist/_headers` policy covering same-origin scripts, `object-src 'none'`, `base-uri 'self'`, framing restrictions and referrers; verify effective HTTPS/HSTS headers before changing transport policy. Live response headers were not inspected, so this is not a claim that Netlify supplies none.

**Checked and fine**

- Reviewed all eight requested HTML/JavaScript files. No URL parameters, `location.hash`, fetched JSON, or arbitrary local-storage value reaches an HTML sink.
- `locale.js:457` and `journey.js:44,59` use `innerHTML`, but their current inputs are bundled translations/fixed SVG strings. Language/theme storage is constrained to supported values (`preferences.js:7–15`).
- `companion.js` performs presentation work; it neither stores personal data nor calls an endpoint. Preferences store only `clockin-theme` and `clockin-language`.
- The demo retains simulated time/earnings in memory. No relay request, analytics submission, user identifier, or credential-bearing URL was found.
- Scripts/styles/images are local; no third-party CDN script/font dependency requiring integrity was found (`index.html:9–23`; CSS dependency scan).
- No checked-in redirect rules or attacker-controlled redirect target exists. Function exposure is inherited from published metadata, including the named `admin`, `live-activity`, and `live-activity-tick` functions (`deploy:75,102–132`); `/api/v1/live-activity` is checked explicitly. Exact live admin routing was not retrieved.
- Netlify credentials come only from `security find-generic-password`, captured in memory (`deploy:37–43`). No environment-token fallback, intentional token printing, or token disk write exists. The tool was not executed.
- Ordinary deployments preserve existing function digests/configuration, schedule and privacy page; unexpected inventories and requested function uploads abort. The concurrent-deployment limitation remains.
- Website downloads use HTTPS and the fixed GitHub `Clockin.zip` asset. `Config/ClockinMac-Info.plist:26–37` references the matching HTTPS `appcast.xml`, requires signed feeds and verifies updates before extraction. Release packaging uses versioned HTTPS DMG URLs (`Tools/mac-release/package.sh:57–60`). Live assets/signatures were not downloaded; keys were untouched.

**3. Local data at rest**

**Medium — Relay bearer credentials are persisted in ordinary preferences.**  
`Shared/Sync/LiveActivityPush.swift:27–35,247–253`.

The registration and pending-deletion dictionaries use the ActivityKit push token as their key, and that same token is the HTTP bearer credential. Anyone obtaining the preferences through an accessible device/container or backup can recover credentials while they remain valid.

Smallest fix: migrate these dictionaries to non-synchronizing Keychain storage using `AfterFirstUnlockThisDeviceOnly`, retaining expiry/retry behavior, then remove the old preferences.

There is no separate app-generated relay password: ActivityKit supplies tokens (`:70–87,96–105`), token updates queue deletion of the previous token, and stop/reconciliation/deletion retries remove obsolete registrations (`:160–238`). Activity registration requests an eight-hour lifetime (`SessionMirror.swift:235–239`). No Keychain implementation currently exists in the reviewed app sources.

**Low — Public CloudKit error logging exposes record identifiers and uncontrolled error details.**  
`Shared/Sync/Cloud/CloudKitAdapter.swift:311,492`.

The encode-failure line explicitly logs a record key with `.public`; both lines publish complete error descriptions, potentially including additional record identifiers and server diagnostic information. Exact contents depend on the error.

Smallest fix: log stable error domains/codes publicly and mark record keys private; omit unrestricted error descriptions from production logs.

**Low — Support diagnostics can include earnings and a user-identifying filesystem path.**  
`ClockinMac/MenuBarController.swift:158–173`, `MenuBarStatus.swift:42–46`.

“Copy details” includes the current menu-bar title, which can contain earnings, and the application path, which can contain the account name. These details can leave the device when pasted into a support report.

Smallest fix: replace title contents with presence/length and report only the installation category. The debug file-writing path is `MenuBarProbe.swift:166`; user-facing copies occur at `MacSettingsSection.swift:54` and `MenuBarHiddenCard.swift:55`.

**Low — Export cleanup misses failure paths.**  
`Clockin/Views/SettingsView.swift:552–558`, `Shared/Core/ClockStore.swift:586–589`.

A complete financial JSON backup is written temporarily and deleted only after a successful read; read failure or process termination can leave it behind. File permissions are not explicitly restricted at creation.

Smallest fix: encode directly into the document’s in-memory data, eliminating the intermediate file. If retained, use a private directory, guaranteed cleanup and startup removal of stale exports.

The code uses `FileManager.temporaryDirectory`, not a hard-coded shared `/tmp` path. World readability was not demonstrated; it depends on the actual parent directory permissions.

**Low — The widget snapshot unnecessarily duplicates session notes.**  
`Shared/Sync/ClockinSnapshot+Store.swift:14`, `ClockinSnapshot.swift:14,100–102`, `Shared/Core/Models.swift:99–103`.

Copying the entire `RunningSession` includes its free-text note in the shared snapshot. Today/control widgets use timing fields but do not display that note, creating an unnecessary additional persisted copy.

Smallest fix: serialize only the running timing fields needed by those widgets, or clear the note in the snapshot copy. Live Activity note handling is separate.

**Note — Financial archives are plaintext at the application layer; iOS uses default file protection.**  
`ClockStore.swift:1114–1117`, `SyncSidecar.swift:389–405`, `ClockinSnapshot.swift:100–102`.

No explicit file-protection class or default-data-protection entitlement was found. Newly created iOS files therefore rely on the default `NSFileProtectionCompleteUntilFirstUserAuthentication`; existing/migrated files’ effective attributes require device inspection. [Apple Data Protection documentation](https://support.apple.com/en-gb/guide/security/sec1a976c067/1/web/1)

This permits access after first unlock while subsequently locked, supporting widgets, background sync and external timer actions. Do not blindly change the primary store to `.complete`; consider stronger protection for archival/export copies independently, and make the operational store’s required class explicit.

On the inspected Mac, `clockin.json` was `0644` beneath `0700` ancestors. Other ordinary users could not traverse those ancestors; same-user processes remain within the trust boundary.

**Note — Backup policy includes sensitive history and redundant copies.**  
`AppGroup.swift:55–67`, `ClockStore.swift:81–111,638–646,1134–1144`, `SyncSidecar.swift:400–405`.

No explicit backup-exclusion attribute exists. Primary archives and durable preferences remain backup-eligible; legacy migration retains its original, and quarantine/pre-sync copies have no corresponding retention limit, while ordinary automatic backups retain up to 30 files.

Smallest fix: keep intentional user-data backups, exclude regenerable snapshots/transport-only state, and define cleanup for redundant migration/recovery copies. Do not exclude the whole sync sidecar indiscriminately: it also contains pending changes and recovery data.

Caches and temporary directories are excluded from iOS backup by their location; exclusion is not an encryption mechanism. [Apple backup guidance](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)

**Persistence inventory**

| Store | Contents / exposure |
|---|---|
| `AppGroup.directory/clockin.json` | Sessions, dates, notes, source strings, hourly rates/rate history, currency and running session. Earnings are derivable. `Models.swift:3–13,99–127`. |
| `sync-state.json` | Device/account identifiers, CloudKit system fields/engine state, record payloads, pending/staged changes and recoveries. These sync tokens are not standalone CloudKit login credentials. `SyncSidecar.swift:3–28,350–351`. |
| `Backups/`, unreadable/quarantine and pre-sync JSON | Additional complete or partial financial-history copies. |
| `widget-snapshot.json` | Today’s earnings, rate, currency, running session, appearance and companion state. Mac normally uses its separate widget App Group. `AppGroup.swift:35–52`. |
| `pulse-pass`, `Chrome Extension/` | Mac capability file and unpacked extension assets; findings above. |
| Standard `UserDefaults` | UI/goals, wardrobe/ledger, reminder/nudge state, celebration history, exchange-rate cache, timer-start history and relay-token dictionaries. No current primary hourly-rate store in defaults was found. |
| App Group defaults | Shared language preference: iOS `group.com.erdmncdr.clockin`; Mac `LU36PKDPT3.com.ismailakdag.clockin`. `AppLanguage.swift:15–24`. |
| Caches | Armor PNGs (`ArmorHDCache.swift:13–16,37–41`), bundled mascot notification attachments (`NudgeController.swift:139–148`), debug sync diagnostics (`SyncCoordinator.swift:394–410`). |
| ActivityKit-managed storage | Local Live Activity calculation state, including rate/earnings/note; not sent in relay registration. `ClockinActivityAttributes.swift:8–9`. |

No SwiftData/Core Data store was found; persistence is JSON, preferences and system-managed activity/notification storage.

**Logging check**

- Sensitive identifier logging: `CloudKitAdapter.swift:311`; unrestricted error details: `:311,492`.
- No direct production `print`, `Logger` or `os_log` statement logging hourly rates, earnings, notes, or relay bearer values was found.
- `CloudKitAdapter.swift:142,510`, `SyncCoordinator.swift:153`, `ClockinAppDelegate.swift:65,74`, and `ClockinMacApp.swift:131` log environment/status/delivery outcomes.
- `LiveActivityPush.swift:145` logs a constant failure message.
- Debug prints in `LevelFrameDiagnostics.swift:28`, `LevelFrameBenchmark.swift:34,54`, `LevelFeedbackReview.swift:70`, and `LevelShareCard.swift:155,159` contain benchmark/fixture output, not actual financial records.
- Debug `sync-diagnostics.txt` includes work-start timing, counts and issue messages; the account is represented only as “set/none” (`SyncCoordinator.swift:399–410`).
- Earnings in copied support diagnostics are covered separately above.

**Checked and fine**

- JSON export includes financial history, notes, IDs, rate rules, running state and wardrobe data; it excludes relay tokens, CloudKit account/engine state and timer-start logs (`ClockStore.swift:586–589`; `WardrobeBackup.swift:8–27`). CSV is import-only in this checkout; no CSV export implementation exists.
- Normal level-up sharing produces PNG data in memory, containing level/rank, optional focus hours, streak/date and branding—not rates, earnings, notes or tokens (`LevelShareCard.swift:53–55,91–113,120–135`). App-written image files occur only in the explicit debug fixture.
- `ShareLevelView.swift:11–15,55,134–145` uses `DataRepresentation` and Photos add-only access. System sharing may materialize its own files; no app-created production share-image temporary file was found.
- Stats sharing separately includes earnings by default; its preview and explicit privacy selection govern output. Private mode omits headline earnings/time but clearly states that remaining statistics are not anonymous (`ShareStatsView.swift:54–75`; `ShareStatsFields.swift:48–60`).
- Relay registration body contains only environment, expiry and protocol version; the token goes in the Authorization header, not the URL (`LiveActivityPrivacy.swift:14–18`; `LiveActivityPush.swift:247–253`). No bearer value was found in exports or logging.
- iOS Photos add-only description, audio background mode, remote notifications, CloudKit and App Group entitlements correspond to implemented features (`Config/Clockin-Info.plist:20–25`; `Config/Clockin.entitlements:5–17`). No unused broad usage description was found. Signed release entitlements were not inspected.


---

## Owner follow-up (2026-10-28)

Applied, reviewed by a second read-only pass, and released as Mac 2.0.27 (38), iOS 0.2 (55) and a website deploy:

- `picker.js`: untrusted click/key/cancel events ignored; the ten-minute limit also checked at the click.
- `background.js`: a command is forwarded only while a setup exists, from the picked origin's top frame, and only with the id of the current setup (new on every save), so watchers left in open tabs after Remove or a repick are refused. `watch.js` sends that id. Extension 1.4.
- `website/dist/_headers`: CSP (same-origin scripts/styles, `data:` images for the AVIF probe, the hash of the privacy page's one inline style), `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`. HSTS already comes from Netlify.
- `CloudKitAdapter.swift:311`: record key `.private`.
- `MenuBarController` / `MenuBarProbe`: Copy details reports the title length and the bundle name, not the title text or full paths.
- `ClockStore.exportBackup() -> Data?`: the iOS backup goes straight to the exporter; no temporary file.

Accepted as is: the relay token in `UserDefaults` (an eight-hour ActivityKit token inside the sandbox); same-user process impersonation of the native host (inside the macOS trust boundary); the deploy race (single operator); default iOS file protection (widgets need it); public error descriptions in sync logs (needed for diagnosis, no record contents).
