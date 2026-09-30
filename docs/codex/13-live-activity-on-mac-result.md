# 13: Live Activities and the Mac menu bar

Research date: 2026-09-30. Ideas only; no implementation or device testing.

**Recommendation:** keep the iPhone Live Activity and offer an explicit, device-local way to make Clockin’s Mac status item icon-only, including in Minimal mode. Preserve existing defaults and user choices. Do not infer which display the user wants from a Mac heartbeat.

## 1. Public API answer

**I found no documented public iOS 26 / macOS 26 API that excludes only the Mac presentation while retaining the iPhone Live Activity, or reports that an activity is currently visible on a particular Mac. Confidence: high, bounded to the documented API surface.** This is an inference from Apple’s API documentation and automatic-mirroring description, not an explicit Apple guarantee of impossibility, a private-API investigation, or proof about future SDKs.

The contemporaneous evidence is [WWDC25: What’s new in widgets](https://developer.apple.com/videos/play/wwdc2025/278/): Tahoe automatically presents paired-iPhone Live Activities, including from iOS 18, without app code changes. The menu bar reuses the Dynamic Island leading/trailing views. Installing a native Mac status item does not give Clockin an API to replace that mirrored presentation.

| Candidate | Documented purpose and implication |
| --- | --- |
| `ActivityContent` | Carries state, freshness (`staleDate`) and ordering (`relevanceScore`). Neither freshness nor ranking selects a destination or guarantees suppression. [Initializer](https://developer.apple.com/documentation/activitykit/activitycontent/init%28state%3Astaledate%3Arelevancescore%3A%29), [freshness](https://developer.apple.com/documentation/activitykit/activitycontent/staledate), [ranking](https://developer.apple.com/documentation/activitykit/activitycontent/relevancescore). |
| Info.plist | `NSSupportsLiveActivities` enables the feature; `NSSupportsLiveActivitiesFrequentUpdates` enables frequent remote updates. Neither is a Mac exclusion key. Disabling support sacrifices the iPhone feature. [Support key](https://developer.apple.com/documentation/bundleresources/information-property-list/nssupportsliveactivities), [frequent updates key](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSSupportsLiveActivitiesFrequentUpdates). |
| `ActivityAuthorizationInfo` | Reports authorization to start activities and receive frequent pushes, not whether a particular presentation is visible or whether Mac mirroring is enabled. [Authorization](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo?changes=_3). |
| `activityFamily` / `supplementalActivityFamilies` | A view can learn its size family and supply an appropriate layout. That is limited rendering context, not a host-device identifier or a list of visible surfaces. Apple describes `.medium` as shared by iOS and macOS; `.small` customization also serves Watch/CarPlay. Omitting a supplemental size is not a Mac opt-out. [ActivityFamily](https://developer.apple.com/documentation/widgetkit/activityfamily), [WWDC25](https://developer.apple.com/videos/play/wwdc2025/278/). |
| `disfavoredLocations(_:for:)` | Applies to widget families and gallery placement; it moves widgets into the gallery’s Other section. Even `WidgetLocation.iPhoneWidgetsOnMac` is a widget location, not a Live Activity exclusion. [Modifier](https://developer.apple.com/documentation/swiftui/widgetconfiguration/disfavoredlocations%28_%3Afor%3A%29?changes=_1), [location](https://developer.apple.com/documentation/widgetkit/widgetlocation/iphonewidgetsonmac). |

Do not treat a compact/minimal view callback, an active activity, a recent sync, or a Mac process being alive as evidence that the user can see the mirrored clock. There is no documented visibility signal here on which to base automatic deduplication.

Apple’s user controls are more useful than a developer workaround:

- On Mac: System Settings → Notifications → Allow notifications from iPhone → **Allow Live Activities from iPhone** disables all mirrored Live Activities.
- For one session: open the mirrored activity, hover over its expanded presentation and use its close button. Apple says this hides that activity for its duration.
- The iPhone app’s Live Activities setting affects both iPhone and Mac. Per-app **Show on Mac** is documented for notifications, not as a persistent Mac-only Live Activity switch.

These distinctions are documented in [Apple Support: Manage iPhone notifications and Live Activities on Mac](https://support.apple.com/en-us/120684). That page also corrects one premise: after iPhone Mirroring setup, the powered-on phone need not remain nearby to deliver activities; proximity matters for opening iPhone Mirroring. A proximity or recent-use heuristic is therefore especially weak.

## 2. What this checkout already does

- [MenuBarController.swift](../../ClockinMac/MenuBarController.swift), `refreshLabel()`: the native item always keeps its stateful icon; text appears only when `host.minimalMode()` is true. Running, paused and idle have distinct states and accessibility values. The item remains the entry point to the native Mac panel.
- [MenuBarStatus.swift](../../ClockinMac/MenuBarStatus.swift), `make(...)`: idle has no text. Running/paused text is assembled independently from time, earnings, TRY equivalent and goals. Turning off hours removes the whole duration, including seconds. Turning off every text field already produces icon-only output without losing the running/paused state.
- [MenuBarHost.swift](../../ClockinMac/MenuBarHost.swift) defaults Minimal mode to false, so a fresh default configuration is already icon-only. Minimal mode defaults to time, earnings and TRY text. Defaults changes already refresh the label.
- [MacSettingsSection.swift](../../ClockinMac/MacSettingsSection.swift) already exposes Show hours and the other fields. However, Minimal mode is not merely a text switch: [MenuBarPanelView.swift](../../ClockinMac/MenuBarPanelView.swift), `setMinimalMode`, also hides the main window, changes activation policy and manages the pinned timer. Reusing that switch as a simple “Show time” preference would be misleading.
- [SessionMirror.swift](../../Shared/Sync/SessionMirror.swift), `syncActivity`: a running session, including a paused one, requests or updates an activity; no running session ends all activities. Operations are serialized, with state rechecks around replacement. There is no Mac-presence condition. Ending uses immediate dismissal and cleans up remote registrations.
- [LiveActivityPrivacySection.swift](../../Clockin/Privacy/LiveActivityPrivacySection.swift), [LiveActivitySetupView.swift](../../Clockin/Privacy/LiveActivitySetupView.swift) and [LiveActivityPrivacy.swift](../../Shared/Sync/LiveActivityPrivacy.swift): the in-app consent controls remote earnings updates. `SessionMirror` can still request a local activity with no push token when consent is off. This preference must not be presented as a solution to duplicated clocks.
- [ClockinLiveActivity.swift](../../ClockinWidgets/ClockinLiveActivity.swift) puts elapsed time in the compact leading view, earnings in trailing, and a timer icon in minimal. Altering those shared views to remove the Mac clock would also alter the iPhone presentation.
- [SyncPreferences.swift](../../Shared/Sync/Cloud/SyncPreferences.swift) allowlists `Clockin.MinimalMode` and all `Clockin.MinimalShow…` keys for sync. Despite being read from standard defaults, these are not guaranteed device-local preferences.

These observations come from the current source, not older sync design notes or a claim of hardware validation.

## Product choice and trade-offs

| Option | Assessment |
| --- | --- |
| Always show only the native Mac icon while running | Compact and reliable, but forcing it removes useful glanceable time for Mac-only users and people who disable mirroring. Also removes their earnings/goal text. Keep it available, not mandatory. |
| Mac setting “Show time in the menu bar” | A good narrow control; essentially the existing Show hours field. Off still leaves earnings/TRY/goals, so it must not promise icon-only mode. Renaming the existing control improves clarity but does not make its synced value local. |
| Explicit Mac icon-only choice | Recommended. A local “Show details in the menu bar” master switch can hide all native text without changing Minimal mode, pinning, field selections or iPhone behavior. Two icons may remain: this removes repeated information, not the system’s second item. |
| Skip/end the iPhone activity after a Mac heartbeat | Reject. Recent Mac activity neither proves visibility nor proves the user is still there. Ending removes the phone’s Lock Screen/Dynamic Island experience and other mirrored presentations as well. |
| Rely only on macOS settings | Valid user choice and zero Clockin code, especially for users who want native Mac time. The global switch also removes other apps’ useful activities; dismissing one session must be repeated. Provide guidance, not a required setup step. |

For a person using both apps, recommend turning **Show details in the menu bar** off on that Mac. Keep the stateful Clockin icon and native panel controls; leave the iPhone activity following its normal session lifecycle. A person who prefers the native Mac timer can keep details on and use Apple’s controls instead. Put brief help beside the Mac preference, not in the iPhone first-launch flow.

Preserve current behavior on upgrade. Keep the new master switch on by default; the existing default of Minimal mode off still yields icon-only. Existing Minimal-mode users retain their selected text until they choose otherwise. This avoids assuming that owning both apps means mirroring is enabled or desired. iPhone-only users see no change; Mac-only users retain their timer choice. If the mirrored activity later disappears, the native panel still shows the timer, and the user can restore native text explicitly.

A heartbeat would add failure modes rather than resolve the missing visibility signal: delayed/offline CloudKit delivery, clock skew, sleep/crashes leaving stale presence, several Macs, a Mac app running unattended, and expiration while iOS is suspended. This checkout polls sync every 60 seconds when enabled ([SyncCoordinator.swift](../../Shared/Sync/SyncCoordinator.swift)), with iPhone polling tied to foreground activity ([ClockinApp.swift](../../Clockin/ClockinApp.swift)); it is not an immediate presence service. Short expiry risks flicker; long expiry can suppress the phone after the user leaves the desk. Restarting an ended activity also cannot assume arbitrary background execution: Apple restricts local starts, with specific intent exceptions and a separate push-start mechanism. [Activity request documentation](https://developer.apple.com/documentation/activitykit/activity/request%28attributes%3Acontent%3Apushtype%3Astyle%3A%29?changes=_2). This source is used for the lifecycle restriction, not to claim every current request overload existed in iOS 26.

## Smallest change to implement the recommendation

No source change is needed for a workaround today: disable the existing text fields in Mac settings, or use Apple’s per-session dismissal. The field choices currently participate in sync, and turning Minimal mode off has window/pinning effects, so neither is as clean as a local master switch.

The smallest product implementation is **two Mac source files plus localized strings**:

1. In `MacSettingsSection.swift`, add a standard-defaults Boolean such as `Clockin.MacShowMenuBarDetails`, default true, labelled “Show details in the menu bar.” Help: “Turn off to show only the Clockin icon. Your iPhone Live Activity stays on.” Explain that details appear in Minimal mode; disable the master control outside that mode and disable its subordinate field controls when details are off, retaining their stored values.
2. In `MenuBarHost.swift`, read the same local key. When off, return `MenuBarStatus` with the correct running/paused state and `text: nil`, ideally before computing display-only totals. When on, keep the current `MenuBarStatus.make` path. The existing defaults publisher and controller already update/clear the title. No new controller API or `MenuBarStatus` field is needed.
3. Add the new UI strings to `Shared/Localizable.xcstrings`. Keep the new key outside `SyncPreferences.types`: new keys are explicitly local unless allowlisted. Do not repurpose or reset the existing synced field keys.

“Show time in the menu bar” remains an optional clearer label for Show hours, not the name of a switch that also hides earnings. No `SessionMirror`, iPhone privacy, Live Activity view, plist, heartbeat or cloud-schema change is needed.

Before shipping an implementation, verify running/paused/idle icons; immediate text removal/restoration; persistence after relaunch; retained field values and pinning behavior; no new synced preference; and unchanged iPhone activity behavior. Check a real iPhone/Mac pair with mirroring on and off, plus Mac-only and iPhone-only use. This report verifies documentation and source relationships only; it does not claim those device checks were run.
