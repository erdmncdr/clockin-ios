# Mac port inventory and data compatibility

Source snapshot: 2026-09-29. Scope: this worktree and `../clockin-main` only. Read `docs/mac-plan.md` first. This is a source audit, not a macOS target build; no SDK headers or external documentation were read. Availability uncertainties are explicitly marked for phase 1 verification. No production Swift or project file was changed.

## A. iPhone Swift files

`as-is` means the file has no identified macOS 14 source-level obstacle, once its referenced shared types are present. It does **not** mean its transitive dependencies already compile. `guard` means local conditional code or a small platform implementation; `ios-only` means exclude this implementation; `mac-rewrite` means provide a Mac equivalent while retaining reusable logic. Line numbers are in the named source file. The API column includes availability-sensitive APIs as well as known iOS-only APIs; a listed API is not automatically unavailable.

SwiftUI `onChange(of:initial:)`, Canvas, Charts, NavigationStack, ShareLink, fileImporter/fileExporter, confirmation/cancellation toolbar placements, and spatial gestures are not inherently iOS-only on macOS 14. `tabItem` also exists on Mac, but the requested sidebar replaces that navigation. `presentationDetents`, `scrollDismissesKeyboard`, and separator alignment availability/behavior have not been SDK-verified here: guard or replace these call sites pending the Mac build. UserNotifications, AVPlayer/AVAudioPlayer, Core Animation, CoreText, CoreGraphics, ImageIO, CryptoKit and AppIntents are usable on Mac; AVAudioSession, UIKit, ActivityKit, iPhone rotation and Control Center controls are separate concerns.


### `Clockin/Audio/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ChimeSchedule.swift` | as-is | — | `ChimeSchedule`; no direct iOS-only API found. |
| `FocusChimeController.swift` | guard | `UIKit` 2; `AVAudioSession` 39, 45, 48, 192, 220, 229; `UIApplication` 40; `AVAudioSessionRouteChangeReasonKey` 47 | Guard AVAudioSession observers/configuration and UIApplication background event; retain worked-time scheduler and notification delegate. |
| `FocusChimeSound.swift` | as-is | — | `FocusChimeSound`, `FocusChimeVolume`; no direct iOS-only API found. |
| `FocusRadioCard.swift` | as-is | — | `FocusRadioCard`, `FocusRadioStationPicker`; no direct iOS-only API found. |
| `FocusRadioController.swift` | guard | `AVAudioSession` 29, 34, 40, 46, 51, 54, 95, 201; `AVAudioSessionInterruptionTypeKey` 31; `AVAudioSessionRouteChangeReasonKey` 48 | Guard AVAudioSession routes/interruptions/configuration; retain AVPlayer and Mac-supported MediaPlayer commands/Now Playing. |
| `FocusSettingsSection.swift` | guard | `UIApplication` 55 | Replace iOS notification-settings deep link at call site; preserve preference controls. |
| `LongSessionReminderController.swift` | as-is | — | UserNotifications scheduling/actions are cross-platform; requires app notification delegate/service wiring. |
| `LongSessionReminderSchedule.swift` | as-is | — | `LongSessionReminderSchedule`, `LongSessionReminderState`; no direct iOS-only API found. |
| `LongSessionReminderSettingsSection.swift` | guard | `UIApplication` 31 | Replace iOS notification-settings deep link at call site; preserve preference controls. |
| `RadioStation.swift` | as-is | — | `RadioStation`, `RadioPlaybackState`; no direct iOS-only API found. |

### `Clockin/Celebrations/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `CelebrationCenter.swift` | mac-rewrite | `UIKit` 3; `UIWindow` 20; `UIAccessibility` 27, 222; `UIApplication` 108, 207; `UIViewController` 238 | Keep rules and persistence; replace UIWindow/presented-controller traversal with Mac window/presentation state. |
| `CelebrationConfetti.swift` | mac-rewrite | `UIKit` 2; `UIViewRepresentable` 4; `UIView` 10; `UIGraphicsImageRenderer` 35; `UIColor` 36, 39 | NSView/Core Animation emitter; create chips through CoreGraphics. |
| `CelebrationMascot.swift` | guard | `UIKit` 2 | UIKit import is unused; guard it. Reuses adapted mascot host. |
| `CelebrationOverlay.swift` | as-is | — | `CelebrationOverlay`; no direct iOS-only API found. |
| `CelebrationPresentation.swift` | mac-rewrite | `UIViewRepresentable` 34, 65; `UIView` 50, 70 | Replace UIView visibility/window probes with NSView probes; keep blocker leases. |
| `CelebrationRules.swift` | as-is | — | `CelebrationBadge`, `CelebrationReaction`; no direct iOS-only API found. |
| `ForgedCrown.swift` | as-is | — | `ForgedCrown`; no direct iOS-only API found. |
| `LevelEffectsPreview.swift` | as-is | — | `LevelEffectsPreview`; no direct iOS-only API found. |
| `LevelFeedbackReview.swift` | ios-only | `UIKit` 3; `UIViewRepresentable` 74; `UIView` 79 | Debug UIKit review harness; exclude from shipping Mac target. |
| `LevelFrameBenchmark.swift` | as-is | — | SwiftUI/Darwin benchmark; development-only target membership recommended. |
| `LevelFrameDiagnostics.swift` | as-is | — | `LevelFrameDiagnostics`; no direct iOS-only API found. |
| `LevelPrestige.swift` | as-is | — | `LevelPrestige`; no direct iOS-only API found. |
| `LevelPrestigeViews.swift` | as-is | — | `PrestigeProgressBar`, `PrestigeGroove`; no direct iOS-only API found. |
| `LevelUpAura.swift` | as-is | — | `LevelUpAura`; no direct iOS-only API found. |
| `LevelUpBlast.swift` | as-is | — | `LevelUpBlast`, `LevelUpBlastArt`; no direct iOS-only API found. |
| `LevelUpCard.swift` | as-is | — | `LevelUpCard`, `LevelUpRule`; no direct iOS-only API found. |
| `LevelUpCrest.swift` | guard | `UIKit` 3; `UIFont` 248, 249 | Local NSFont/CoreText branch for serif numeral outlines. |
| `LevelUpHaptics.swift` | guard | `UIKit` 2; `UIApplication` 14; `UIAccessibility` 17 | Retain public play/cancel API with no-op Mac branch; UIKit and hardware pattern execution stay iOS. |
| `LevelUpSigilGeometry.swift` | as-is | — | `LevelUpSigilGeometry`; no direct iOS-only API found. |
| `LevelUpSound.swift` | guard | `UIKit` 2; `UIApplication` 22; `AVAudioSession` 29 | Guard audio session configuration; replace active-app test with Mac application state; preserve bundled cues. |
| `LevelUpStage.swift` | as-is | — | `LevelUpCurve`, `LevelUpStageLayout`; no direct iOS-only API found. |
| `LevelUpTiming.swift` | as-is | — | `LevelUpTiming`, `LevelUpHapticBeat`; no direct iOS-only API found. |
| `LevelUpWarrior.swift` | as-is | — | `LevelUpWarrior`, `WarriorArmor`; no direct iOS-only API found. |
| `PrestigeForge.swift` | as-is | — | `PrestigeLight`, `ForgeTone`; no direct iOS-only API found. |
| `RankMaterial.swift` | as-is | — | `RankMaterial`, `GemCut`; no direct iOS-only API found. |
| `RankSignatures.swift` | as-is | — | `RankSignature`, `RankSignatureArt`; no direct iOS-only API found. |

### `Clockin/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ClockinApp.swift` | mac-rewrite | `UIApplicationDelegateAdaptor` 5 | New ClockinMac App: scenes, old identity, dependencies, menu/Settings lifecycle. |
| `ClockinAppDelegate.swift` | ios-only | `UIKit` 1; `UIApplicationDelegate` 3; `UIApplication` 4, 5, 11; `UIWindow` 12; `UIInterfaceOrientationMask` 12 | iOS launch/orientation delegate; supply Mac delegate independently. |

### `Clockin/Companion/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `NudgeController.swift` | as-is | — | UserNotifications and persisted scheduling; retain cross-platform notification response wiring. |
| `NudgeCopy.swift` | as-is | — | `NudgeCopy`; no direct iOS-only API found. |
| `NudgePlanner.swift` | as-is | — | `NudgeTone`, `NudgeKind`; no direct iOS-only API found. |
| `NudgeSettingsSection.swift` | guard | `UIApplication` 30 | Replace iOS notification-settings deep link at call site; preserve preference controls. |

### `Clockin/Intents/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ClockinShortcuts.swift` | as-is | — | AppShortcutsProvider is cross-platform; depends on adapted ClockIntents. |

### `Clockin/Privacy/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `LiveActivityPrivacySection.swift` | ios-only | — | Live Activity consent UI; exclude from Mac settings. |
| `LiveActivitySetupView.swift` | ios-only | `ActivityKit` 1; `.fullScreenCover` 12; `.topBarLeading` 84; `.topBarTrailing` 87; `UIApplication` 127; `ActivityAuthorizationInfo` 166 | iPhone onboarding/permission connection UI only. |
| `PrivacyPolicyBrowser.swift` | mac-rewrite | `SafariServices` 1; `UIViewControllerRepresentable` 5; `SFSafariViewController` 8, 9, 15, 24; `SFSafariViewControllerDelegate` 21 | Replace SFSafariViewController with openURL/browser or a Mac web presentation. |
| `TimerPersistenceAlert.swift` | as-is | — | `TimerPersistenceAlert`; no direct iOS-only API found. |

### `Clockin/Views/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `BackupsView.swift` | guard | `.navigationBarTitleDisplayMode` 45 | `BackupsView`. Keep logic; guard the listed presentation/input calls. |

### `Clockin/Views/Badges/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `BadgesView.swift` | as-is | — | `BadgesView`; no direct iOS-only API found. |
| `LevelBadgeGallery.swift` | guard | `.navigationBarTitleDisplayMode` 42 | `LevelBadgeGallery`. Keep logic; guard the listed presentation/input calls. |

### `Clockin/Views/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `CompactChimeCard.swift` | as-is | — | `CompactChimeCard`; no direct iOS-only API found. |

### `Clockin/Views/Companion/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `CompanionCategoryTabs.swift` | as-is | — | `CompanionCategoryTabs`, `CompanionPreviewFrame`; no direct iOS-only API found. |
| `CompanionHomeAtmosphere.swift` | mac-rewrite | `UIKit` 2; `UIViewRepresentable` 4, 45; `UIView` 13, 55; `UIColor` 75, 109; `UIBezierPath` 106 | NSView layer host for furniture/steam/light; retain layer animation geometry. |
| `CompanionHomePreview.swift` | guard | `UIKit` 2; `.navigationBarTitleDisplayMode` 109; `UIAccessibility` 146 | Guard navigation title mode and replace accessibility purchase announcement with Mac equivalent. |
| `CompanionHomeView.swift` | as-is | — | `CompanionHomeView`, `CompanionBreathing`; no direct iOS-only API found. |
| `CompanionProductTile.swift` | as-is | — | `CompanionProductTile`; no direct iOS-only API found. |
| `CompanionSkinPreview.swift` | as-is | — | `CompanionSkinPreview`; no direct iOS-only API found. |
| `CompanionSleepPreview.swift` | as-is | — | `CompanionSleepPreview`; no direct iOS-only API found. |
| `CompanionView.swift` | guard | `.navigationBarTitleDisplayMode` 81; `.fullScreenCover` 84 | Room editor should open a Mac sheet/window rather than fullScreenCover. |
| `RoomEditorCanvas.swift` | as-is | — | `RoomEditorCanvas`; no direct iOS-only API found. |
| `RoomEditorView.swift` | guard | `.navigationBarTitleDisplayMode` 67 | `RoomEditorSession`, `RoomEditorView`. Keep logic; guard the listed presentation/input calls. |
| `WardrobeEarnings.swift` | as-is | — | `WardrobeEarnings`; no direct iOS-only API found. |
| `WardrobeStore.swift` | as-is | — | `WardrobeStore`; no direct iOS-only API found. |

### `Clockin/Views/Components/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `RollingAnimationPolicy.swift` | as-is | — | ProcessInfo low-power/thermal gating is also available on macOS 14. |
| `RollingNumber.swift` | as-is | — | `RollDirection`, `RollingNumberSample`; no direct iOS-only API found. |
| `RollingNumberFont.swift` | mac-rewrite | `UIKit` 2; `UIFont` 8, 10, 26, 37, 43, 50; `UIFontDescriptor` 30, 40, 41; `UIFontMetrics` 46; `UITraitCollection` 47; `UIContentSizeCategory` 64 | NSFont/CoreText metrics and font-design mapping; no UIFontMetrics on Mac. |
| `RollingNumberText.swift` | mac-rewrite | `UIKit` 2; `UIColor` 37, 70; `UIViewRepresentable` 67; `UIFont` 69 | NSViewRepresentable branch matching existing public view API. |
| `RollingNumberUIView.swift` | mac-rewrite | `UIKit` 1; `UIView` 3, 4, 108; `UIFont` 7, 38, 130; `UIColor` 8, 38, 130; `UILabel` 109, 110 | NSView/Core Animation digit renderer; reuse RollingNumber diff engine. |

### `Clockin/Views/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `DashboardShortcuts.swift` | guard | `.navigationBarTitleDisplayMode` 48, 89 | `DashboardShortcut`, `DashboardPinButton`. Keep logic; guard the listed presentation/input calls. |
| `DashboardView.swift` | guard | `.navigationBar` 93 | `DashboardSheet`, `DashboardView`. Keep logic; guard the listed presentation/input calls. |

### `Clockin/Views/DeskMode/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `DeskModeOrientation.swift` | mac-rewrite | `UIKit` 2; `UIInterfaceOrientationMask` 16; `UIApplication` 24; `UIWindowScene` 25 | Mac full-screen/pinned-window activation; no orientation or iOS idle timer. |
| `DeskModeView.swift` | as-is | — | SwiftUI content can be reused inside a Mac fullscreen/pinned window; activation belongs to Mac shell. |

### `Clockin/Views/Earnings/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ChartInteraction.swift` | mac-rewrite | `UIKit` 2; `UIViewRepresentable` 4; `UIView` 11, 12, 23; `UITapGestureRecognizer` 13, 42; `UIPanGestureRecognizer` 14, 31, 39, 47; `UIGestureRecognizerDelegate` 26; `UIGestureRecognizer` 30, 36, 37 | Use Mac hover/scrub, clicks and paging; retain EarningsSwipe thresholds where useful. |
| `EarningsChartView.swift` | as-is | — | Charts view depends on Mac replacement ChartInteraction; data/selection code otherwise shared. |
| `EarningsPeriod.swift` | as-is | — | `EarningsRange`, `EarningsPeriod`; no direct iOS-only API found. |
| `EarningsSnapshot.swift` | as-is | — | `EarningsDay`, `EarningsSnapshot`; no direct iOS-only API found. |
| `MonthPerformance.swift` | as-is | — | `MonthRunningPoint`, `MonthTargetPoint`; no direct iOS-only API found. |
| `MonthPerformanceView.swift` | as-is | — | `MonthPerformanceView`; no direct iOS-only API found. |

### `Clockin/Views/Goals/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `DecimalEditing.swift` | as-is | — | `GoalField`, `DecimalEditingSession`; no direct iOS-only API found. |
| `DecimalKeyboardDismissal.swift` | as-is | — | Uses SwiftUI spatial taps/preferences, no UIKit keyboard API despite filename. |
| `GoalHoursField.swift` | guard | `.keyboardType` 27 | `GoalHoursField`. Keep logic; guard the listed presentation/input calls. |
| `GoalProgress.swift` | as-is | — | `GoalProgress`, `MonthlyGoalPace`; no direct iOS-only API found. |
| `GoalsPaceView.swift` | guard | `.scrollDismissesKeyboard` 40; `UIResponder` 45 | Guard keyboard notification and phone dismissal behavior; retain goal editor/scroll focus. Modifier availability on macOS 14 is unverified; keep conditional pending build. |
| `MonthlyWorkPlan.swift` | as-is | — | `MonthlyWorkPlan`; no direct iOS-only API found. |
| `ProgressHubView.swift` | guard | `.navigationBarTitleDisplayMode` 42 | `ProgressSection`, `ProgressHubView`. Keep logic; guard the listed presentation/input calls. |
| `TodayGoalsCard.swift` | as-is | — | `TodayGoalsCard`; no direct iOS-only API found. |
| `TodayPaceSummary.swift` | as-is | — | `TodayPaceSummary`; no direct iOS-only API found. |

### `Clockin/Views/Guide/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `UsageGuideView.swift` | guard | `.navigationBarTitleDisplayMode` 85 | `UsageGuideView`. Keep logic; guard the listed presentation/input calls. |

### `Clockin/Views/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `HistoryView.swift` | guard | `.insetGrouped` 89; `.topBarTrailing` 94; `.listRowSeparatorLeading` 135 | Replace insetGrouped and top-bar placement; separator alignment availability unverified; retain Mac grouping/collapse controls. |

### `Clockin/Views/Import/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `TimecardImportView.swift` | guard | `.scrollDismissesKeyboard` 69; `.navigationBarTitleDisplayMode` 72; `.textInputAutocapitalization` 179 | `TimecardImportView`, `TimecardImportReview`. Keep logic; guard the listed presentation/input calls. Modifier availability on macOS 14 is unverified; keep conditional pending build. |

### `Clockin/Views/Insights/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `BadgeTier.swift` | as-is | — | `BadgeTier`, `BadgeMission`; no direct iOS-only API found. |
| `InsightsAggregateHeatmapView.swift` | as-is | — | `InsightsAggregateHeatmapView`; no direct iOS-only API found. |
| `InsightsBadges.swift` | as-is | — | `InsightsBadge`; no direct iOS-only API found. |
| `InsightsBadgesView.swift` | guard | `.navigationBarTitleDisplayMode` 187; `.presentationDetents` 190 | Guard inline navigation title; detent availability unverified. Low-power state itself is available on Mac. |
| `InsightsHeatmapView.swift` | as-is | — | `InsightsHeatmapView`; no direct iOS-only API found. |
| `InsightsPeriods.swift` | as-is | — | `InsightsGrouping`, `InsightsPeriod`; no direct iOS-only API found. |
| `InsightsSnapshot.swift` | as-is | — | `InsightsSnapshot`, `InsightsGoalEstimate`; no direct iOS-only API found. |
| `InsightsView.swift` | guard | `.topBarTrailing` 20 | `InsightsView`. Keep logic; guard the listed presentation/input calls. |
| `MedalSignatures.swift` | as-is | — | `MedalMotion`, `MedalSignature`; no direct iOS-only API found. |
| `MonthWeek.swift` | as-is | — | `MonthWeek`; no direct iOS-only API found. |
| `PurchaseBadges.swift` | as-is | — | `PurchaseBadges`; no direct iOS-only API found. |
| `SpaceBadgeArt.swift` | as-is | — | `ForgedMedal`, `ForgedMedalBody`; no direct iOS-only API found. |
| `SpaceBadgeGeometry.swift` | as-is | — | `SpaceBadgeGeometry`; no direct iOS-only API found. |

### `Clockin/Views/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `LanguageSwitch.swift` | as-is | — | `LanguageSwitch`; no direct iOS-only API found. |
| `ManualEntryView.swift` | guard | `.navigationBarTitleDisplayMode` 126 | `ManualEntryView`. Keep logic; guard the listed presentation/input calls. |
| `ManualStartView.swift` | guard | `.navigationBarTitleDisplayMode` 74 | `ManualStartView`. Keep logic; guard the listed presentation/input calls. |

### `Clockin/Views/Mascot/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `CompanionMode.swift` | as-is | — | `CompanionMode`; no direct iOS-only API found. |
| `LevelBadge.swift` | guard | `UIKit` 2 | UIKit import is unused; remove/guard it. Shared badge UI depends on adapted celebration center. |
| `MascotAsset.swift` | mac-rewrite | `UIKit` 2; `UIViewRepresentable` 283; `UIView` 314; `UIColor` 415 | Port NSView layer hosting from old MascotAsset and keep new wardrobe/tired/proud/motion logic. |
| `MascotCard.swift` | as-is | — | `MascotCard`; no direct iOS-only API found. |
| `MascotSkinEffects.swift` | guard | `UIKit` 1; `UIColor` 200, 209, 211 | Only UIKit color helpers need NSColor or CGColor equivalents; keep CALayer effects. |

### `Clockin/Views/Momentum/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `MoneyMomentum.swift` | as-is | — | `MoneyMomentum`; no direct iOS-only API found. |
| `MoneyMomentumView.swift` | as-is | — | `MoneyMomentumView`, `MomentumMilestoneLabels`; no direct iOS-only API found. |

### `Clockin/Views/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `RateScheduleView.swift` | guard | `.insetGrouped` 74; `.navigationBarTitleDisplayMode` 78, 199; `.keyboardType` 175; `.scrollDismissesKeyboard` 195 | `RateScheduleView`, `RateEditorDestination`. Keep logic; guard the listed presentation/input calls. Modifier availability on macOS 14 is unverified; keep conditional pending build. |
| `ReminderEndTimeView.swift` | guard | `.navigationBarTitleDisplayMode` 35 | `ReminderEndTimeView`. Keep logic; guard the listed presentation/input calls. |
| `RootView.swift` | mac-rewrite | `.verticalSizeClass` 13, 94; `.statusBarHidden` 100; `UIApplication` 157; `.tabItem` 225, 228, 232 | Build sidebar/window navigation and Mac desk presentation; retain service wiring and overlays. |
| `SessionRow.swift` | as-is | — | `SessionRow`; no direct iOS-only API found. |
| `SessionSheets.swift` | as-is | — | `SessionSheet`, `SessionSheetsModifier`; no direct iOS-only API found. |
| `SessionSummaryView.swift` | guard | `.presentationDetents` 47 | Sheet detent availability/behavior unverified on macOS 14; choose explicit Mac sheet sizing. |
| `SettingsView.swift` | guard | `.scrollDismissesKeyboard` 119; `.navigationBarTitleDisplayMode` 123; `.keyboard` 135; `.keyboardType` 229, 244 | Guard phone keyboard/orientation/Live Activity settings; host content in Settings scene, add Mac sections. Modifier availability on macOS 14 is unverified; keep conditional pending build. |

### `Clockin/Views/Share/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ShareStatsFields.swift` | as-is | — | `StatsSharePrivacy`, `StatsSharePage`; no direct iOS-only API found. |
| `ShareStatsView.swift` | guard | `UIKit` 2; `UIImage` 54; `UIPasteboard` 87; `.navigationBarTitleDisplayMode` 102; `.uiImage` 145 | Local NSImage/ImageRenderer.nsImage PNG encoding and NSPasteboard branch; shared ShareLink and stats card can stay. |

### `Clockin/Views/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `TimerCard.swift` | as-is | — | `TimerCard`, `ClockinContentActiveKey`; no direct iOS-only API found. |
| `TodayLayout.swift` | guard | `.navigationBarTitleDisplayMode` 94 | `TodaySection`, `TodayQuickLink`. Keep logic; guard the listed presentation/input calls. |

### `ClockinWidgets/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ClockinControlState.swift` | as-is | — | `ClockinControlState`; no direct iOS-only API found. |
| `ClockinControls.swift` | ios-only | `ControlWidget` 15, 31; `ControlWidgetConfiguration` 16, 32; `ControlWidgetToggle` 21; `ControlWidgetButton` 37; `ControlValueProvider` 6; `StaticControlConfiguration` 17, 33 | iOS 18 control extension; availability annotation is not an os(iOS) guard. |
| `ClockinLiveActivity.swift` | ios-only | `ActivityKit` 1; `ActivityConfiguration` 8; `DynamicIsland` 20; `DynamicIslandExpandedRegion` 21, 37, 43; `.activityBackgroundTint` 15; `.activitySystemActionForegroundColor` 16 | Lock Screen/Dynamic Island Live Activity implementation. |
| `ClockinWidgetsBundle.swift` | ios-only | — | iPhone extension entry point references iOS-only widgets; own Mac extension later. |
| `ReadyWidgetPlacement.swift` | as-is | — | `ReadyWidgetPlacement`; no direct iOS-only API found. |
| `TodayWidget.swift` | guard | `.accessoryRectangular` 73, 94, 100, 103 | Keep desktop small/medium families; guard accessoryRectangular Lock Screen branches. Separate Mac widget target deferred. |

### `Shared/Core/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `AppLanguage.swift` | guard | — | Foundation compiles, but route language preferences to standard Mac defaults until widget phase; current suite at line 17 violates storage plan. |
| `CSVImporter.swift` | as-is | — | `CSVImportError`, `CSVImporter`; no direct iOS-only API found. |
| `ClockStore.swift` | as-is | — | `ClockStore`, `AutomaticBackup`; no direct iOS-only API found. |
| `ExchangeRates.swift` | as-is | — | `SingleRateResponse`, `ExchangeRateStore`; no direct iOS-only API found. |
| `ImportComparison.swift` | as-is | — | `ImportMatchKind`, `ImportComparisonItem`; no direct iOS-only API found. |
| `Models.swift` | as-is | — | `WorkSession`, `SessionDisplay`; no direct iOS-only API found. |
| `PastedTextImporter.swift` | as-is | — | `PastedImportError`, `PastedTextImporter`; no direct iOS-only API found. |
| `SessionOverlap.swift` | as-is | — | `SessionOverlap`; no direct iOS-only API found. |
| `WardrobeBackup.swift` | as-is | — | `WardrobeBackupSection`; no direct iOS-only API found. |

### `Shared/Intents/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ClockIntents.swift` | guard | `LiveActivityIntent` 9, 43, 66 | Use AppIntent on macOS 14 instead of LiveActivityIntent; keep actions and saved-state checks via adapted SharedStore/SessionMirror. |
| `SetClockedInIntent.swift` | ios-only | `LiveActivityIntent` 5; `SetValueIntent` 5 | iOS 18 SetValueIntent for Control Center; exclude on macOS 14. |

### `Shared/Mascot/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ArmorHD.swift` | as-is | — | `ArmorHDColor`, `ArmorHDTone`; no direct iOS-only API found. |
| `ArmorHDCache.swift` | as-is | — | `ArmorHDCache`; no direct iOS-only API found. |
| `ArmorHDParts.swift` | as-is | — | `ArmorHDShape`, `ArmorHDShade`; no direct iOS-only API found. |
| `ArmorHDPixels.swift` | as-is | — | `ArmorHDPixels`, `ArmorHDGeometry`; no direct iOS-only API found. |
| `CompanionAccessory.swift` | as-is | — | `CompanionAccessory`; no direct iOS-only API found. |
| `HeritageArt.swift` | as-is | — | `HeritageArt`; no direct iOS-only API found. |
| `HomeSceneLayout.swift` | as-is | — | `HomeSceneLayout`; no direct iOS-only API found. |
| `MascotFrames.swift` | as-is | — | `MascotResources`, `ClockinMascotStill`; no direct iOS-only API found. |
| `MascotMotion.swift` | as-is | — | `MascotMood`, `MascotStep`; no direct iOS-only API found. |
| `MascotState.swift` | as-is | — | `MascotAsset`; no direct iOS-only API found. |
| `RoomArrangement.swift` | as-is | — | `RoomArrangement`; no direct iOS-only API found. |
| `RoomPlacement.swift` | as-is | — | `RoomPlacedItem`, `RoomPlacement`; no direct iOS-only API found. |
| `Wardrobe.swift` | as-is | — | `WardrobeSlot`, `WardrobeUnlock`; no direct iOS-only API found. |
| `WardrobeArt.swift` | as-is | `UIKit` 4, 5, 212; `UIImage` 213 | UIKit is already canImport-guarded (4–6, 212–216); compiles, but fixed-pose decoder returns nil on Mac: add NSImage/CGImage path for parity. |
| `WardrobeCatalog.swift` | as-is | — | `WardrobeCatalog`, `WardrobeCategory`; no direct iOS-only API found. |
| `WardrobePalette.swift` | as-is | — | `WardrobeColorRule`, `WardrobeColorway`; no direct iOS-only API found. |
| `WardrobeSkins.swift` | as-is | — | `WardrobeSkinEffects`, `WardrobeSkin`; no direct iOS-only API found. |

### `Shared/Sync/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `AppGroup.swift` | guard | — | containerURL is also Mac API; explicitly choose legacy directory on Mac at lines 15–19, do not rely on entitlement failure. |
| `ClockinActivityAttributes.swift` | ios-only | `ActivityKit` 1; `ActivityAttributes` 4 | ActivityKit attributes only; keep Foundation state model separately. |
| `ClockinActivityState.swift` | as-is | — | `ClockinActivityState`; no direct iOS-only API found. |
| `ClockinSnapshot+Store.swift` | as-is | — | Shared extension; no direct iOS-only API found. |
| `ClockinSnapshot.swift` | as-is | — | `ClockinSnapshot`; no direct iOS-only API found. |
| `LiveActivityPrivacy.swift` | as-is | — | Foundation keys/registration payload compile; unused in Mac UI until a relevant service exists. |
| `LiveActivityPush.swift` | ios-only | `ActivityKit` 2; `UIKit` 6; `UIApplication` 78, 82, 89, 115, 119, 219, 223; `Activity` 66, 96, 201 | iPhone APNs activity token lifecycle/background tasks only. |
| `LiveActivityRegistrationStatus.swift` | as-is | — | Foundation connection status values; not the ActivityKit runtime. |
| `LiveActivityRegistry.swift` | as-is | — | Pure token bookkeeping model; keep off Mac runtime call graph until needed. |
| `SessionMirror.swift` | guard | `ActivityKit` 2; `ControlCenter` 108; `ActivityContent` 149, 180, 210; `ActivityAuthorizationInfo` 182; `Activity` 148, 160, 164, 186, 201, 211 | Separate activity/control branches from snapshot, chime, reminder, nudge and celebration updates; do not no-op the whole coordinator. |
| `SharedStore.swift` | guard | — | Lines 14–17 select App Group and start SessionMirror; select defaultFileURL on Mac and retain shared store ownership. |

### `Shared/Theme/`

| File | Verdict | iOS-only / availability-sensitive API (lines) | Note |
|---|---|---|---|
| `ActionButtonStyles.swift` | as-is | — | `PrimaryActionButtonStyle`, `SecondaryActionButtonStyle`; no direct iOS-only API found. |
| `ButtonStyles.swift` | as-is | — | `HitTargetButtonStyle`; no direct iOS-only API found. |
| `ClockinThemeChoice.swift` | as-is | — | `ClockinThemeChoice`; no direct iOS-only API found. |
| `HapticEvent.swift` | as-is | — | `HapticEvent`, `HapticFeedback`; no direct iOS-only API found. |
| `Haptics.swift` | guard | `UIKit` 4; `UIImpactFeedbackGenerator` 12, 13, 22, 26; `UISelectionFeedbackGenerator` 14, 30; `UINotificationFeedbackGenerator` 15, 34; `UIApplication` 18; `SensoryFeedback` 47; `.sensoryFeedback` 69 | Current !WIDGET_EXTENSION guard does not protect Mac app. Provide same Haptics/View/Binding APIs as no-ops on Mac. |
| `PaletteEnvironment.swift` | as-is | — | `SectionTitle`; no direct iOS-only API found. |
| `Themes.swift` | as-is | — | `ClockinPalette`, `ClockinAccentButtonStyle`; no direct iOS-only API found. |

Coverage: **176 Swift files**; 112 as-is, 41 guard, 10 ios-only, 13 mac-rewrite. Every path appears once above.

Search also covered UIKit identifiers, ActivityKit, UIApplication/UIScreen, keyboard/input/navigation/list/toolbar APIs, haptic calls, orientation, sharing and extension entry points. No direct `PhotosUI`, `UIActivityViewController`, `EditMode`, or `UIScreen` use was found in these roots; do not invent a migration for absent APIs. `Image(uiImage:)`, renderer `.uiImage`, and `pngData()` in ShareStatsView (77, 82, 145) need the Mac image branch even though ShareLink itself is shared.

### Non-Swift target resources

| Resource | Neutral? | Mac target action |
|---|---|---|
| `Clockin/Assets.xcassets` (AppIcon, AccentColor, pose1–pose4 imagesets and Contents.json) | Images/colors yes; AppIcon idiom/configuration needs Mac review | Include poses/colors; supply macOS AppIcon sizes/idiom and retain old app visual identity. |
| `Shared/Localizable.xcstrings` | Yes | Include in Mac target and use `Bundle.app`; add new Mac-only strings during UI port. |
| `Clockin/AppShortcuts.xcstrings` | Yes, with adapted intent provider | Include when enabling Mac Shortcuts; inspect phone-specific wording. |
| `Clockin/Audio/Sounds/*.caf` | Yes, audio bytes | All eight focus cues plus `clockin-levelup.caf`, `clockin-levelup-rank.caf`, `clockin-levelup-still.caf` (11 files); bundle lookup must preserve names. |
| `Shared/Mascot/Frames/` | Yes | Include all PNGs and `mascot-clips.json`, `mascot-anchors.json`, `fixed-pose-anchors.json`, `colorways.json`; preserve folder/search fallback layout. |
| `Shared/Mascot/Wardrobe/` | Yes | Include PNG accessories and `wardrobe-sprites.json`. |
| `Shared/Mascot/Skins/skins.json` | Yes | Include HD skin manifest; procedural art uses it and frame anchors. |
| `Shared/Mascot/Home/` | Yes, data/art | Include room/furniture PNGs, portrait JPG, flag SVG and `home-items.json`. HeritageArt also draws the flag; SVG is not a UIKit dependency. |
| `Clockin/PrivacyInfo.xcprivacy` | Format yes | Include and review declarations for new Mac target APIs; widget manifest belongs to future extension. |
| `ClockinWidgets/PrivacyInfo.xcprivacy` | Format yes | Future Mac widget only. |
| Fonts | No bundled `.ttf`, `.otf`, `.ttc` found | Uses system SwiftUI/CoreText fonts; UIKit font metrics need the branch listed above, no font-copy step. |
| `Config/Clockin-Info.plist`, entitlements | Platform configuration, not neutral resources | Do not copy iPhone background/orientation/App Group identity as Mac defaults; use identity/Sparkle table below. |

Bundle resource inclusion is an Xcode target task, not accomplished by this inventory. Named images and fixed-pose loading need runtime verification after compilation.



## B. Old Mac files

All paths in the next tables are relative to `../clockin-main/Sources/Clockin/`. Counterparts are paths in this worktree; “none” means no direct implementation. `merge` retains the specified Mac behavior while taking the new shared implementation. Do not copy duplicate store/model types into the new target.

| Old file | Responsibility | Counterpart | Verdict and Mac behavior |
|---|---|---|---|

| `ApplicationMover.swift` | Translocation-aware application relocation engine. | `none` | **port** — Keep Applications relocation and original-path handling. |
| `ButtonStyles.swift` | Enlarges button hit regions. | `Shared/Theme/ButtonStyles.swift` | **superseded** — Shared hit targets. |
| `CSVImporter.swift` | Parses timecard CSV rows and durations. | `Shared/Core/CSVImporter.swift` | **superseded** — Keep stricter validation; audit rejected legacy data below. |
| `ClockStore.swift` | Persists archive, timer, rates, imports and backups. | `Shared/Core/ClockStore.swift` | **merge** — Retain old path and pinned-window update wiring; use shared transactional session operations. |
| `ClockinApp.swift` | App/delegate lifecycle, dependencies, menus and status updates. | `Clockin/ClockinApp.swift`; `Clockin/ClockinAppDelegate.swift` | **merge** — Retain LSUIElement, menu/status/pinned lifecycle, reopen and menu commands in new Mac entry point. |
| `ClockinControls.swift` | Mac field/button/picker chrome and AppKit interactions. | `Shared/Theme/ActionButtonStyles.swift`; `Shared/Theme/PaletteEnvironment.swift` | **merge** — Keep keyboard/focus, pointer and desktop field behavior where shared SwiftUI controls need it. |
| `CompanionMode.swift` | Stored default companion pose/mode. | `Clockin/Views/Mascot/CompanionMode.swift` | **superseded** — Same user choice; new moods/features in shared implementation. |
| `ExchangeRates.swift` | Fetches/caches daily USD–TRY rates. | `Shared/Core/ExchangeRates.swift` | **superseded** — Keep cache keys; newer lookup/failure handling. |
| `FocusChime.swift` | In-process worked-time timer and NSSound player. | `Clockin/Audio/FocusChimeController.swift`; `Clockin/Audio/ChimeSchedule.swift` | **merge** — Keep desktop foreground playback/volume and decide legacy NSSound compatibility; adopt scheduler. |
| `GuideView.swift` | Desktop usage guide. | `Clockin/Views/Guide/UsageGuideView.swift` | **merge** — Retain menu bar, pin, minimal mode and keyboard shortcut instructions. |
| `HeatmapView.swift` | History heatmap with saved range. | `Clockin/Views/Insights/InsightsHeatmapView.swift`; `Clockin/Views/Insights/InsightsAggregateHeatmapView.swift` | **merge** — Keep existing range intent through explicit preference mapping; new grouped insights. |
| `HistoryView.swift` | Charts and flat/collapsible-day history. | `Clockin/Views/HistoryView.swift`; `Clockin/Views/Earnings/EarningsChartView.swift` | **merge** — Keep day-collapse/flat switch, hover/scrub; adopt pageable ranges and shared calculations. |
| `ImportComparison.swift` | Classifies imported rows and matches. | `Shared/Core/ImportComparison.swift` | **superseded** — New scope/leftover review is richer. |
| `ImportComparisonView.swift` | CSV comparison and selectable import review. | `Clockin/Views/Import/TimecardImportView.swift` | **superseded** — Shared review after presentation guards. |
| `KeyboardShortcuts.swift` | Registers global Carbon hotkeys. | `none` | **port** — Keep global clock in/out/pause/open behavior and registration lifetime. |
| `MainTabBar.swift` | Desktop section selector. | `Clockin/Views/RootView.swift` | **merge** — Replace tabs with planned sidebar; retain keyboard/navigation reachability. |
| `MainView.swift` | Desktop dashboard, sheets and toolbar orchestration. | `Clockin/Views/DashboardView.swift`; `Clockin/Views/RootView.swift` | **merge** — Retain desktop commands, pin/minimal access and native window sizing. |
| `MainWindow.swift` | NSWindow lifecycle, restoration and scaled minimum size. | `none` | **port** — Keep frame autosave name, reopen behavior and interface-size response. |
| `ManualEntryView.swift` | Creates/edits completed work. | `Clockin/Views/ManualEntryView.swift` | **merge** — Keep desktop keyboard/focus sizing; take exact timestamp and explicit end-date improvements. |
| `ManualStartView.swift` | Starts timer with existing elapsed duration. | `Clockin/Views/ManualStartView.swift` | **merge** — Keep desktop sheet/keyboard interaction; new validation. |
| `MascotAsset.swift` | NSView/CALayer mascot host and asset loading. | `Clockin/Views/Mascot/MascotAsset.swift`; `Shared/Mascot/MascotFrames.swift` | **merge** — Port AppKit host; retain new outfits, finite sway, tired/proud moods and visibility gates. |
| `MascotMotion.swift` | Companion clip director and pose interpolation. | `Shared/Mascot/MascotMotion.swift` | **superseded** — New engine includes fallback frames and finite motion. |
| `MenuBarController.swift` | Status item, custom panel and event tracking. | `none` | **port** — Keep menu bar and minimal-mode status lifecycle. |
| `MenuBarIcon.swift` | Draws status-item clock icon. | `none` | **port** — Keep template/status icon drawing. |
| `MenuBarPanelView.swift` | Compact desktop timer/actions/goals and minimal toggle. | `Clockin/Views/TimerCard.swift`; `Clockin/Views/Goals/TodayGoalsCard.swift` | **port** — Reuse shared state but preserve dedicated desktop panel and minimal/pin restore behavior. |
| `MenuBarStatus.swift` | Formats minimal-mode hours/money/TRY/goal status. | `none` | **port** — Keep toggles and compact no-seconds formatting. |
| `Models.swift` | Archive schema, entry times and format helpers. | `Shared/Core/Models.swift` | **merge** — Use stricter shared schema; retain DurationText.clock(includeSeconds:) seam for menu bar. |
| `MoveToApplications.swift` | Prompts/suppresses application relocation. | `none` | **port** — Keep first-launch prompt and suppression preference. |
| `PasteImportView.swift` | Pasted timecard input/review surface. | `Clockin/Views/Import/TimecardImportView.swift` | **superseded** — Unified import screen supports pasted text and CSV. |
| `PastedTextImporter.swift` | Parses browser-copied timecards and date ranges. | `Shared/Core/PastedTextImporter.swift` | **superseded** — Shared parser with validation. |
| `PinnedWindow.swift` | Floating nonactivating timer panel with five layouts. | `none` | **port** — Keep Money/Compact/Goal/All/Total, Spaces behavior, frame/size prefs and pinVisible wiring. |
| `ProgressView.swift` | Level, streak, badges, reports and goals. | `Clockin/Views/Insights/InsightsSnapshot.swift`; `Clockin/Views/Insights/InsightsView.swift`; `Clockin/Views/Goals/GoalsPaceView.swift` | **superseded** — Deliberate XP/badge/pace change needs announcement, not old goal-XP preservation. |
| `RadioController.swift` | AVPlayer station playback and timeout/error handling. | `Clockin/Audio/FocusRadioController.swift`; `Clockin/Audio/RadioStation.swift` | **merge** — Use richer remembered station/pause behavior; preserve session-free Mac AVPlayer setup. |
| `RateScheduleView.swift` | Rate period list/editor. | `Clockin/Views/RateScheduleView.swift` | **merge** — Keep desktop editor interaction; use new same-start-day rejection and shared schedule. |
| `RollingText.swift` | NSView/Core Animation rolling text renderer. | `Clockin/Views/Components/RollingNumberText.swift`; `Clockin/Views/Components/RollingNumber.swift` | **merge** — Reuse AppKit host approach, new diff/visibility/accessibility policy. |
| `SessionSummaryView.swift` | Post-clock-out duration/earnings summary. | `Clockin/Views/SessionSummaryView.swift` | **superseded** — Shared summary plus celebrations; Mac sheet sizing. |
| `SettingsView.swift` | Preferences, rates, backup/import and desktop controls. | `Clockin/Views/SettingsView.swift` | **merge** — Keep interface size, pin/minimal toggles, updater and Mac chime choices in Settings scene. |
| `ShareStatsView.swift` | Renders and exports stats images via Mac UI. | `Clockin/Views/Share/ShareStatsView.swift` | **merge** — Keep NSImage/PNG and pasteboard/export behavior while using shared cards/privacy choices. |
| `Themes.swift` | Eight palettes and theme choice. | `Shared/Theme/Themes.swift`; `Shared/Theme/ClockinThemeChoice.swift` | **superseded** — Same names; retain preference and sync it. |
| `UIScale.swift` | Discrete interface size and old fraction migration. | `none` | **port** — Keep 100/115/130/150 percent preference, legacy migration and scaled desktop dimensions. |
| `UpdateChecker.swift` | Sparkle updater and unobtrusive reminders. | `none` | **port** — Keep feed/key, manual checks and legacy automatic-check preference migration. |

### Old non-Swift files (one row per file)

Assets are superseded by the new resource set and fallback-aware loader. Missing exact frame names are intentionally identified, not silently equated to another PNG.

| Old file | Responsibility | Counterpart | Verdict |
|---|---|---|---|
| `Assets/Mascot/loops/celebrate/e01.png` | Companion celebrate animation frame e01. | `Shared/Mascot/Frames/e01.png` | superseded |
| `Assets/Mascot/loops/celebrate/e02.png` | Companion celebrate animation frame e02. | `Shared/Mascot/Frames/e02.png` | superseded |
| `Assets/Mascot/loops/celebrate/e06.png` | Companion celebrate animation frame e06. | `Shared/Mascot/Frames/e06.png` | superseded |
| `Assets/Mascot/loops/celebrate/e07.png` | Companion celebrate animation frame e07. | `Shared/Mascot/Frames/e07.png` | superseded |
| `Assets/Mascot/loops/celebrate/e08.png` | Companion celebrate animation frame e08. | `Shared/Mascot/Frames/e08.png` | superseded |
| `Assets/Mascot/loops/celebrate/e09.png` | Companion celebrate animation frame e09. | `Shared/Mascot/Frames/e09.png` | superseded |
| `Assets/Mascot/loops/celebrate/e15.png` | Companion celebrate animation frame e15. | `Shared/Mascot/Frames/e15.png` | superseded |
| `Assets/Mascot/loops/coffee/c01.png` | Companion coffee animation frame c01. | `Shared/Mascot/Frames/c01.png` | superseded |
| `Assets/Mascot/loops/coffee/c02.png` | Companion coffee animation frame c02. | `Shared/Mascot/Frames/c02.png` | superseded |
| `Assets/Mascot/loops/coffee/c03.png` | Companion coffee animation frame c03. | `Shared/Mascot/Frames/c03.png` | superseded |
| `Assets/Mascot/loops/coffee/c04.png` | Companion coffee animation frame c04. | `Shared/Mascot/Frames/c04.png` | superseded |
| `Assets/Mascot/loops/coffee/c05.png` | Companion coffee animation frame c05. | `Shared/Mascot/Frames/c05.png` | superseded |
| `Assets/Mascot/loops/coffee/c06.png` | Companion coffee animation frame c06. | `Shared/Mascot/Frames/c06.png` | superseded |
| `Assets/Mascot/loops/coffee/c07.png` | Companion coffee animation frame c07. | `Shared/Mascot/Frames/c07.png` | superseded |
| `Assets/Mascot/loops/coffee/c08.png` | Companion coffee animation frame c08. | `Shared/Mascot/Frames/c08.png` | superseded |
| `Assets/Mascot/loops/coffee/c09.png` | Companion coffee animation frame c09. | `Shared/Mascot/Frames/c09.png` | superseded |
| `Assets/Mascot/loops/coffee/c10.png` | Companion coffee animation frame c10. | `Shared/Mascot/Frames/c10.png` | superseded |
| `Assets/Mascot/loops/coffee/c11.png` | Companion coffee animation frame c11. | `Shared/Mascot/Frames/c11.png` | superseded |
| `Assets/Mascot/loops/coffee/c12.png` | Companion coffee animation frame c12. | `Shared/Mascot/Frames/c12.png` | superseded |
| `Assets/Mascot/loops/coffee/c13.png` | Companion coffee animation frame c13. | `Shared/Mascot/Frames/c13.png` | superseded |
| `Assets/Mascot/loops/hello/h01.png` | Companion hello animation frame h01. | `Shared/Mascot/Frames/h01.png` | superseded |
| `Assets/Mascot/loops/hello/h02.png` | Companion hello animation frame h02. | `Shared/Mascot/Frames/h02.png` | superseded |
| `Assets/Mascot/loops/hello/h06.png` | Companion hello animation frame h06. | `Shared/Mascot/Frames/h06.png` | superseded |
| `Assets/Mascot/loops/hello/h07.png` | Companion hello animation frame h07. | `Shared/Mascot/Frames/h07.png` | superseded |
| `Assets/Mascot/loops/hello/h08.png` | Companion hello animation frame h08. | `Shared/Mascot/Frames/h08.png` | superseded |
| `Assets/Mascot/loops/hello/h10.png` | Companion hello animation frame h10. | `Shared/Mascot/Frames/h10.png` | superseded |
| `Assets/Mascot/loops/hello/h11.png` | Companion hello animation frame h11. | `Shared/Mascot/Frames/h11.png` | superseded |
| `Assets/Mascot/loops/mascot-clips.json` | Animation clip manifest. | `Shared/Mascot/Frames/mascot-clips.json` | superseded |
| `Assets/Mascot/loops/working/t01.png` | Companion working animation frame t01. | `Shared/Mascot/Frames/t01.png` | superseded |
| `Assets/Mascot/loops/working/t02.png` | Companion working animation frame t02. | `Shared/Mascot/Frames/t02.png` | superseded |
| `Assets/Mascot/loops/working/t03.png` | Companion working animation frame t03. | `Shared/Mascot/Frames/t03.png` | superseded |
| `Assets/Mascot/loops/working/t04.png` | Companion working animation frame t04. | `Shared/Mascot/Frames/t04.png` | superseded |
| `Assets/Mascot/loops/working/t05.png` | Companion working animation frame t05. | `Shared/Mascot/Frames/t05.png` | superseded |
| `Assets/Mascot/loops/working/t06.png` | Companion working animation frame t06. | `Shared/Mascot/Frames/t06.png` | superseded |
| `Assets/Mascot/loops/working/t07.png` | Companion working animation frame t07. | `Shared/Mascot/Frames/t07.png` | superseded |
| `Assets/Mascot/loops/working/t08.png` | Companion working animation frame t08. | `Shared/Mascot/Frames/t08.png` | superseded |
| `Assets/Mascot/loops/working/t09.png` | Companion working animation frame t09. | `Shared/Mascot/Frames/t09.png` | superseded |
| `Assets/Mascot/loops/working/t11.png` | Companion working animation frame t11. | `Shared/Mascot/Frames/t11.png` | superseded |
| `Assets/Mascot/loops/working/t14.png` | Companion working animation frame t14. | `Shared/Mascot/Frames/t14.png` | superseded |
| `Assets/Mascot/poses/pose1.png` | Fixed companion pose pose1. | `Clockin/Assets.xcassets/pose1.imageset/pose1.png` | superseded |
| `Assets/Mascot/poses/pose2.png` | Fixed companion pose pose2. | `Clockin/Assets.xcassets/pose2.imageset/pose2.png` | superseded |
| `Assets/Mascot/poses/pose3.png` | Fixed companion pose pose3. | `Clockin/Assets.xcassets/pose3.imageset/pose3.png` | superseded |
| `Assets/Mascot/poses/pose4.png` | Fixed companion pose pose4. | `Clockin/Assets.xcassets/pose4.imageset/pose4.png` | superseded |

Coverage: **41 Swift + 43 resource files = 84 old Mac files**.

### Old `Resources/Info.plist` contract

| Key | Old value | New Mac action |
|---|---|---|
| `CFBundleDisplayName` | `Clockin` | Keep. |
| `CFBundleExecutable` | `Clockin` | Match built executable name (ClockinMac if target default); retain app display name, not a stale binary path. |
| `CFBundleIconFile` | `Clockin` | Retain icon identity; use equivalent Mac asset catalog/icon configuration. |
| `CFBundleIdentifier` | `com.ismailakdag.clockin` | Keep exactly; selects existing UserDefaults domain and update identity. |
| `CFBundleName` | `Clockin` | Keep. |
| `CFBundlePackageType` | `APPL` | Keep. |
| `CFBundleShortVersionString` | `1.1.6` | Advance for 2.0 release; do not retain old version/build. |
| `CFBundleVersion` | `10` | Advance for 2.0 release; do not retain old version/build. |
| `LSMinimumSystemVersion` | `14.0` | Keep. |
| `LSUIElement` | `true` | Keep true plus old activation/reopen/window policy. |
| `NSHighResolutionCapable` | `true` | Keep. |
| `NSPrincipalClass` | `NSApplication` | Keep. |
| `SUAutomaticallyUpdate` | `false` | Keep. |
| `SUEnableAutomaticChecks` | `true` | Keep. |
| `SUEnableSystemProfiling` | `false` | Keep. |
| `SUFeedURL` | `https://github.com/ismailakdag/clockin/releases/download/macos-updates/appcast.xml` | Keep. |
| `SUPublicEDKey` | `vsxEtDN88GYSuw5+GGeCk3eEvZxlDEalz1icmMBCvh8=` | Keep. |
| `SURequireSignedFeed` | `true` | Keep. |
| `SUScheduledCheckInterval` | `21600` | Keep. |
| `SUSignedFeedFailureExpirationInterval` | `0` | Keep. |
| `SUVerifyUpdateBeforeExtraction` | `true` | Keep. |

Also retain Developer ID team `LU36PKDPT3`, universal macOS 14, hardened runtime and unsandboxed distribution per plan. Sparkle package belongs only to ClockinMac. `NOTICE.md` must retain the old MIT notice. Keep `~/Library/Application Support/Clockin/clockin.json` and sibling `Backups/`; no App Group migration in phase 1. Signing secrets were neither needed nor read.

## C. UserDefaults key map and phase 5 classification

Inventory covers every production key explicitly read/written under old `Sources/` and current `Clockin/`, `Shared/`, `ClockinWidgets/`, including constant-defined and dynamically expanded keys, plus AppKit frame autosave keys. Suite names, notification identifiers (`Clockin.FocusChime.*`, `Clockin.Nudge.*`, `Clockin.LongSessionReminder.*`, `sessionStart`), animation `forKey:` strings, Codable keys and debug/test suite names are not preference keys. Sparkle's internal defaults beyond the application's explicit access are not guessed; carry the existing Mac domain intact rather than enumerate undocumented framework storage.

`sync` is the future policy, not existing functionality. **Every user choice, including theme, sounds, haptics and Mac-only display choices, is sync-class.** Other platforms may retain unsupported values without applying them. Frames, interface size, tokens, caches and setup/notification/presentation bookkeeping are `device`. Wardrobe ownership is synced user data even where earned rather than selected. No preferences are migrated by this task.

Keep the `com.ismailakdag.clockin` standard domain on Mac; never read the iPhone app domain as a first-launch migration. Language is the one current preference explicitly stored in the App Group suite. `pinVisible`, `hourlyRate`, `currencyCode`, sessions, running and rateRules are **JSON fields, not UserDefaults keys**. Under the requested all-user-choices policy, the stored `pinVisible` choice should follow the user where supported, while actual window instances and geometry remain device-local. Profile rate/currency and work records follow the phase 5 record model.

| Key | Mac type / meaning | iPhone type / meaning | Status | First new Mac launch | Phase 5 |
|---|---|---|---|---|---|
| `AppleLanguages` | No explicit Mac source access; OS may supply it | [String], derived app language override in standard defaults | iphone-only | Preserve existing OS preference until explicit language migration chosen; derive locally from synced Clockin.Language, do not sync separately.<br>Source: `Shared/Core/AppLanguage.swift:58` | device |
| `Clockin.AutoCheckUpdates` | Bool, legacy updater preference | — | renamed | Port existing migration to SUEnableAutomaticChecks if destination absent; remove legacy.<br>Source: `../clockin-main/Sources/Clockin/UpdateChecker.swift:36` | sync |
| `Clockin.ChimeEnabled` | Bool, focus chime enabled (false) | Bool, focus chime enabled (false) | same | Keep existing value in old Mac domain; no copy to iPhone domain.<br>Source: `../clockin-main/Sources/Clockin/FocusChime.swift:27`; `Clockin/Audio/FocusSettingsSection.swift:12` | sync |
| `Clockin.ChimeIntervalMinutes` | Int, worked-time interval (10 default) | Int, worked-time interval (10 default) | same | Keep existing value in old Mac domain; no copy to iPhone domain.<br>Source: `../clockin-main/Sources/Clockin/FocusChime.swift:70`; `Clockin/Audio/FocusSettingsSection.swift:13` | sync |
| `Clockin.ChimeSound` | String NSSound name: Glass, Ping, Pop, Tink, Funk, Submarine, Sosumi | String bundled id: soft-bell/glass/marimba/chime/pop/wood-block/singing-bowl/tiny-ping | same name different meaning | Existing migrate() maps only Glass → glass; all other old names fall back to chime (including Pop). Decide explicit mapping or retain Mac system sounds; do not silently overwrite an unsupported selection.<br>Source: `../clockin-main/Sources/Clockin/FocusChime.swift:36`; `Clockin/Audio/FocusChimeSound.swift:14` | sync |
| `Clockin.ChimeVolume` | Double, selected volume (0.75; clamped 0.1–1) | Double, selected volume (0.75; clamped 0.1–1) | same | Keep existing value in old Mac domain; no copy to iPhone domain.<br>Source: `../clockin-main/Sources/Clockin/FocusChime.swift:37`; `Clockin/Audio/FocusChimeSound.swift:45` | sync |
| `Clockin.CompanionAccessory` | — | String, legacy accessory selection (Auto) | iphone-only | No old Mac wardrobe; keep legacy choice until WardrobeStore seeds equipped slots.<br>Source: `Shared/Mascot/CompanionAccessory.swift:6` | sync |
| `Clockin.Dashboard.Pin.chime` | — | Bool, chime quick control visibility (false) | iphone-only | No predecessor; default false, sync user layout choice.<br>Source: `Clockin/Views/DashboardShortcuts.swift:6` | sync |
| `Clockin.Dashboard.Pin.radio` | — | Bool, radio quick control visibility (false) | iphone-only | No predecessor; default false, sync user layout choice.<br>Source: `Clockin/Views/DashboardShortcuts.swift:6` | sync |
| `Clockin.Dashboard.Pin.reminder` | — | Bool, reminder quick control visibility (false) | iphone-only | No predecessor; default false, sync user layout choice.<br>Source: `Clockin/Views/DashboardShortcuts.swift:6` | sync |
| `Clockin.DeskModeEnabled` | — | Bool, automatic desk mode (true) | iphone-only | Keep preference; map meaning to Mac fullscreen/pinned entry behavior, not device rotation.<br>Source: `Clockin/Views/DeskMode/DeskModeOrientation.swift:10` | sync |
| `Clockin.GoalDailyHours` | Double, daily target hours (0 = off) | Double, daily target hours (0 = off) | same | Keep existing value in old Mac domain; no copy to iPhone domain.<br>Source: `../clockin-main/Sources/Clockin/ClockinApp.swift:136`; `Clockin/Celebrations/CelebrationCenter.swift:71` | sync |
| `Clockin.GoalMonthlyHours` | Double, monthly target hours (0 = off) | Double, monthly target hours (0 = off) | same | Keep existing value in old Mac domain; no copy to iPhone domain.<br>Source: `../clockin-main/Sources/Clockin/ClockinApp.swift:137`; `Clockin/Celebrations/CelebrationCenter.swift:75` | sync |
| `Clockin.GoalPromptDismissedAt` | — | Double, seconds since epoch for 7-day snooze | iphone-only | Start absent; local onboarding bookkeeping.<br>Source: `Clockin/Views/Goals/GoalProgress.swift:74` | device |
| `Clockin.HapticsEnabled` | — | Bool, haptic feedback (true) | iphone-only | Sync choice; ignored by Mac no-op implementation.<br>Source: `Shared/Theme/HapticEvent.swift:17` | sync |
| `Clockin.HasConfiguredGoal` | — | Bool, one-time goal onboarding completion | iphone-only | Seed true if existing Mac daily or monthly goal is positive; otherwise existing configured-then-cleared history cannot be inferred.<br>Source: `Clockin/Views/Goals/GoalProgress.swift:75` | device |
| `Clockin.HeatmapRange` | String: Week, Month, All (aggregation modes) | —; related split controls below | renamed | Semantic split, not implemented rename: map Week→Week, Month→Month, All→Day after reviewing range semantics; keep original until decision. No one-to-one raw-value copy.<br>Source: `../clockin-main/Sources/Clockin/HeatmapView.swift:20` | sync |
| `Clockin.HistoryGroupByDay` | Bool, grouped versus flat history (true) | — | mac-only | Retain and reconnect flat/grouped presentation; day expansion itself is view state.<br>Source: `../clockin-main/Sources/Clockin/HistoryView.swift:67` | sync |
| `Clockin.HistoryRange` | String: Month, 7D, 30D, 3M, ALL | String: M, W, 6M, All | same name different meaning | Propose Month→M, 7D→W, 30D→M, 3M→6M, ALL→All; announce changed boundaries. Preserve original for downgrade; new raw values are not understood by old Mac.<br>Source: `../clockin-main/Sources/Clockin/HistoryView.swift:57`; `Clockin/Views/HistoryView.swift:7` | sync |
| `Clockin.HistoryShowsTRY` | — | Bool, History display currency (false) | iphone-only | No Mac predecessor; use default without changing archive currency.<br>Source: `Clockin/Views/HistoryView.swift:10` | sync |
| `Clockin.InsightsHeatmapDayRange` | — | Int, day-grid week span (4/12/0 = all; 12 default) | iphone-only | No exact old equivalent; retain default unless explicit heatmap mapping chosen.<br>Source: `Clockin/Views/Insights/InsightsHeatmapView.swift:11` | sync |
| `Clockin.InsightsHeatmapGrouping` | — | String enum raw values: Day/Week/Month | iphone-only | Related old HeatmapRange; see semantic split row, preserve original.<br>Source: `Clockin/Views/Insights/InsightsHeatmapView.swift:12` | sync |
| `Clockin.Language` | — | String automatic/en/tr, stored in group.com.erdmncdr.clockin suite | iphone-only | On Mac route to standard old domain before first lookup; choose whether old English-only users should start in English or system language.<br>Source: `Shared/Core/AppLanguage.swift:15` | sync |
| `Clockin.LastCelebratedLevel` | — | Int, last presented level | iphone-only | Seed from newly computed level without replaying whole archive on upgrade.<br>Source: `Clockin/Celebrations/CelebrationRules.swift:77` | device |
| `Clockin.LevelUpSoundEnabled` | — | Bool, level-up cues (true) | iphone-only | New default; applies to Mac audio after port.<br>Source: `Clockin/Celebrations/LevelUpSound.swift:11` | sync |
| `Clockin.LiveActivitySetupSeen.v1` | — | Bool, one-time onboarding shown | iphone-only | No Mac migration; device capability onboarding.<br>Source: `Shared/Sync/LiveActivityPrivacy.swift:8` | device |
| `Clockin.LongSessionReminderHours` | — | Int, reminder threshold hours (0 = off; default 10; choices 0/8/10/12) | iphone-only | Use default; schedule per device.<br>Source: `Clockin/Audio/LongSessionReminderSchedule.swift:4` | sync |
| `Clockin.LongSessionReminderState` | — | Data, active-session reminder/snooze bookkeeping | iphone-only | Start fresh; do not import another device notification schedule.<br>Source: `Clockin/Audio/LongSessionReminderController.swift:28` | device |
| `Clockin.MascotDefault` | String, default mode (Auto) | String, default mode (Auto) | same | Keep existing value in old Mac domain; no copy to iPhone domain.<br>Source: `../clockin-main/Sources/Clockin/MascotAsset.swift:38`; `Clockin/Views/Mascot/MascotAsset.swift:41` | sync |
| `Clockin.MascotEnabled` | Bool, companion visibility (true) | Bool, companion visibility (true) | same | Keep existing value in old Mac domain; no copy to iPhone domain.<br>Source: `../clockin-main/Sources/Clockin/MainView.swift:27`; `Clockin/Celebrations/CelebrationCenter.swift:26` | sync |
| `Clockin.MinimalMode` | Bool, menu-bar-only minimal mode | — | mac-only | Preserve in old domain; unsupported devices can store choice without displaying it.<br>Source: `../clockin-main/Sources/Clockin/ClockinApp.swift:29` | sync |
| `Clockin.MinimalShowEarnings` | Bool, status money (true) | — | mac-only | Preserve in old domain; unsupported devices can store choice without displaying it.<br>Source: `../clockin-main/Sources/Clockin/ClockinApp.swift:141` | sync |
| `Clockin.MinimalShowGoal` | Bool, status daily goal (false) | — | mac-only | Preserve in old domain; unsupported devices can store choice without displaying it.<br>Source: `../clockin-main/Sources/Clockin/ClockinApp.swift:143` | sync |
| `Clockin.MinimalShowHours` | Bool, status hours (true) | — | mac-only | Preserve in old domain; unsupported devices can store choice without displaying it.<br>Source: `../clockin-main/Sources/Clockin/ClockinApp.swift:139` | sync |
| `Clockin.MinimalShowSeconds` | Bool, status timer seconds (false) | — | mac-only | Preserve in old domain; unsupported devices can store choice without displaying it.<br>Source: `../clockin-main/Sources/Clockin/ClockinApp.swift:140` | sync |
| `Clockin.MinimalShowTRY` | Bool, status TRY equivalent (true) | — | mac-only | Preserve in old domain; unsupported devices can store choice without displaying it.<br>Source: `../clockin-main/Sources/Clockin/ClockinApp.swift:142` | sync |
| `Clockin.MoveToApplicationsSuppressed` | Bool, suppress first-launch move prompt | — | mac-only | Keep local setup decision.<br>Source: `../clockin-main/Sources/Clockin/MoveToApplications.swift:12` | device |
| `Clockin.NudgeState` | — | Data, encoded delivered/scheduled nudge bookkeeping | iphone-only | Start fresh and schedule on this Mac only.<br>Source: `Clockin/Companion/NudgeController.swift:13` | device |
| `Clockin.NudgeTone` | — | String raw values: Grumpy/Friendly | iphone-only | Use grumpy default unless user changes.<br>Source: `Clockin/Companion/NudgePlanner.swift:52` | sync |
| `Clockin.NudgesEnabled` | — | Bool, companion nudges (true) | iphone-only | Use default; notification permission/schedule remains local.<br>Source: `Clockin/Companion/NudgePlanner.swift:51` | sync |
| `Clockin.PinVisibleBeforeMinimal` | Bool, temporary previous pin visibility | — | mac-only | Keep if minimal mode is active; consume on exit as old controller does.<br>Source: `../clockin-main/Sources/Clockin/MenuBarPanelView.swift:283` | device |
| `Clockin.PinnedHeight.All` | Double, saved panel height in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedHeight.Compact` | Double, saved panel height in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedHeight.Goal` | Double, saved panel height in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedHeight.Money` | Double, saved panel height in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedHeight.Total` | Double, saved panel height in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedMode` | String: Money, Compact, Goal, All, Total | — | mac-only | Preserve in old domain; unsupported devices can store choice without displaying it.<br>Source: `../clockin-main/Sources/Clockin/MainView.swift:22` | sync |
| `Clockin.PinnedWidth.All` | Double, saved panel width in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedWidth.Compact` | Double, saved panel width in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedWidth.Goal` | Double, saved panel width in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedWidth.Money` | Double, saved panel width in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.PinnedWidth.Total` | Double, saved panel width in points | — | mac-only | Keep; generated from mode string in PinnedWindow.swift:66–79.<br>Source: `../clockin-main/Sources/Clockin/PinnedWindow.swift:66` | device |
| `Clockin.RadioStation` | — | String, rp/rp-mellow/rp-global/rp-serenity station id | iphone-only | Old station was view state, so no stored choice to recover; default rp.<br>Source: `Clockin/Audio/RadioStation.swift:19` | sync |
| `Clockin.RemoteActivityConsent.v2` | — | Bool, remote Live Activity updates choice (false) | iphone-only | User choice is sync-class per plan; tokens, OS authorization and per-device registration remain local. Mac has no direct Live Activity UI.<br>Source: `Shared/Sync/LiveActivityPrivacy.swift:5` | sync |
| `Clockin.RemoteActivityPendingDeletions.v2` | — | [String: Double], token→expiry deletion queue | iphone-only | No Mac migration; never sync tokens.<br>Source: `Shared/Sync/LiveActivityPrivacy.swift:6` | device |
| `Clockin.RemoteActivityRegisteredTokens.v1` | — | [String: Double], token→expiry registry | iphone-only | No Mac migration; never sync tokens.<br>Source: `Shared/Sync/LiveActivityPrivacy.swift:7` | device |
| `Clockin.SeenAccessoryIDs` | — | [String], permanently unlocked legacy accessory ids | iphone-only | Input to wardrobe ownership migration, not merely notification bookkeeping; union into ownership.<br>Source: `Shared/Mascot/CompanionAccessory.swift:7` | sync |
| `Clockin.SeenBadgeIDs` | — | [String], already presented badge ids | iphone-only | Seed current unlocks on first Mac launch; not the award source of truth.<br>Source: `Clockin/Celebrations/CelebrationRules.swift:78` | device |
| `Clockin.Theme` | String, one of eight named palettes (Carbon default) | String, one of eight named palettes (Carbon default) | same | Keep existing value in old Mac domain; no copy to iPhone domain.<br>Source: `../clockin-main/Sources/Clockin/ClockinControls.swift:54`; `Clockin/ClockinApp.swift:6` | sync |
| `Clockin.Today.Link.goals` | — | Bool, goals quick link visibility (false) | iphone-only | No predecessor; default false; unsupported platform hides link without erasing choice.<br>Source: `Clockin/Views/TodayLayout.swift:104` | sync |
| `Clockin.Today.Link.history` | — | Bool, history quick link visibility (false) | iphone-only | No predecessor; default false; unsupported platform hides link without erasing choice.<br>Source: `Clockin/Views/TodayLayout.swift:105` | sync |
| `Clockin.Today.Link.liveUpdates` | — | Bool, liveUpdates quick link visibility (false) | iphone-only | No predecessor; default false; unsupported platform hides link without erasing choice.<br>Source: `Clockin/Views/TodayLayout.swift:107` | sync |
| `Clockin.Today.Link.newEntry` | — | Bool, newEntry quick link visibility (false) | iphone-only | No predecessor; default false; unsupported platform hides link without erasing choice.<br>Source: `Clockin/Views/TodayLayout.swift:106` | sync |
| `Clockin.Today.Show.companion` | — | Bool, companion card visibility (true) | iphone-only | No predecessor; default true, sync user layout choice.<br>Source: `Clockin/Views/DashboardView.swift:43` | sync |
| `Clockin.Today.Show.exchange` | — | Bool, exchange card visibility (true) | iphone-only | No predecessor; default true, sync user layout choice.<br>Source: `Clockin/Views/DashboardView.swift:47` | sync |
| `Clockin.Today.Show.goals` | — | Bool, goals card visibility (true) | iphone-only | No predecessor; default true, sync user layout choice.<br>Source: `Clockin/Views/DashboardView.swift:44` | sync |
| `Clockin.Today.Show.momentum` | — | Bool, momentum card visibility (true) | iphone-only | No predecessor; default true, sync user layout choice.<br>Source: `Clockin/Views/DashboardView.swift:45` | sync |
| `Clockin.Today.Show.recent` | — | Bool, recent card visibility (true) | iphone-only | No predecessor; default true, sync user layout choice.<br>Source: `Clockin/Views/DashboardView.swift:46` | sync |
| `Clockin.Today.Show.summary` | — | Bool, summary card visibility (true) | iphone-only | No predecessor; default true, sync user layout choice.<br>Source: `Clockin/Views/DashboardView.swift:42` | sync |
| `Clockin.UIScale` | Double, legacy interface fraction | — | renamed | Port UIScale.migrateLegacyValueIfNeeded: nearest 100/115/130/150; only when UIScalePercent absent, then remove legacy.<br>Source: `../clockin-main/Sources/Clockin/UIScale.swift:15` | device |
| `Clockin.UIScalePercent` | Int, interface size 100/115/130/150 | — | mac-only | Keep; port desktop scaling, not iPhone Dynamic Type.<br>Source: `../clockin-main/Sources/Clockin/UIScale.swift:14` | device |
| `Clockin.USDTRYRates.v1` | Data, JSON day→Double exchange-rate cache | Data, JSON day→Double exchange-rate cache | same | Cache may be retained/rebuilt; never sync.<br>Source: `../clockin-main/Sources/Clockin/ExchangeRates.swift:17`; `Shared/Core/ExchangeRates.swift:25` | device |
| `Clockin.USDTRYRatesUpdated.v1` | Date, last successful rate check | Date, last successful rate check | same | Cache may be retained/rebuilt; never sync.<br>Source: `../clockin-main/Sources/Clockin/ExchangeRates.swift:18`; `Shared/Core/ExchangeRates.swift:26` | device |
| `Clockin.WardrobeLedger` | — | String JSON array of WardrobePurchase (itemID/cost/date; no purchase UUID) | iphone-only | No Mac predecessor; sync append-only purchases, not a last-writer-wins JSON blob. Phase 5 must choose a stable purchase record identity; current struct has no UUID.<br>Source: `Shared/Core/WardrobeBackup.swift:10` | sync |
| `Clockin.WardrobeShowHomeInDeskMode` | — | Bool, home scene in desk mode (true) | iphone-only | Use default; preserve optional wardrobe backup section.<br>Source: `Shared/Core/WardrobeBackup.swift:11` | sync |
| `Clockin.WardrobeState` | — | String JSON, owned/equipped/colorway/room/furniture/arrangement plus seeded flag | iphone-only | Initialize from archive-derived milestones and legacy accessory preferences; sync ownership/choices, treat internal seeding metadata separately.<br>Source: `Shared/Core/WardrobeBackup.swift:9` | sync |
| `Clockin.WorkdaysPerWeek` | — | Int, work plan (0 automatic, 1–7 explicit) | iphone-only | Use automatic default; no old stored plan.<br>Source: `Clockin/Views/Goals/MonthlyWorkPlan.swift:6` | sync |
| `NSWindow Frame ClockinMainWindow` | String, AppKit autosaved frame/screen geometry | — | mac-only | Keep same autosave name (MainWindow.swift:46,55); revalidate screen placement. | device |
| `NSWindow Frame ClockinPinnedTimer` | String, AppKit autosaved frame/screen geometry | — | mac-only | Keep same autosave name (PinnedWindow.swift:32,80,101,110); revalidate screen placement. | device |
| `SUEnableAutomaticChecks` | Bool, Sparkle automatic checking | — | mac-only | Preserve current value; fallback Info.plist true. Sync choice to other Macs; never copy updater bookkeeping.<br>Source: `../clockin-main/Sources/Clockin/UpdateChecker.swift:35` | sync |

Coverage: **80 concrete keys**, with each of the five pinned width/height pairs and each dynamic Today/dashboard choice expanded separately. The old code can construct other `PinnedWidth.<mode>`/`PinnedHeight.<mode>` suffixes if a hand-edited mode string exists; preserve these unknown geometry keys locally too.

Radio volume is a user choice held only in memory (`RadioController.volume` / `FocusRadioController.volume`, both 0.7 default), not a missing persisted key. Phase 5 needs a persisted sync preference if “all user choices” includes remembering that volume; do not invent an existing key. OS Reduce Motion, per-device notification authorization, and current audio playback state are not app UserDefaults choices. Desktop global shortcuts are hard-coded, so there is no shortcut preference key to migrate.

## D. Behavior changes for existing Mac users

These are what adopting the current shared code would do, not changes implemented by this brief. Sources are `PARITY.md` plus both stores/models and their callers. All paths without the old prefix refer to this worktree.

### Every “Different on purpose” item

| Area | Old → new behavior | Migration / announcement |
|---|---|---|
| Level / XP | Old `ProgressView.swift:33–79`: 100 XP/hour + goal days ×100 + double-goal days ×250 + goal months ×500 + longest-streak milestones. New `InsightsSnapshot.swift:22–38,144–147`: 100 XP/hour + same streak bonuses; no goal XP. Both use level = max(1, XP/500+1). | Recompute from archive; do not alter sessions or carry a fabricated XP balance. Announce level may decrease; seed celebration markers at the recomputed baseline. |
| Goal badges | Old goal-day/double-goal/month badges rescore when personal goals change. New full-day/long-day/big-month badges use fixed 8h/10h/100h thresholds and new ids (`InsightsBadges.swift`). | Announce requirements/unlock differences; old Mac has no persisted badge ownership to migrate. Keep earned wardrobe ownership permanent independently of recomputed badges. |
| Restore | Old `ClockStore.swift:458–486` replaces data directly. New `Shared/Core/ClockStore.swift:576–606` saves `clockin-before-restore-*` first, aborts if it cannot, rolls data back on failed save, optionally restores wardrobe. | No archive migration. Explain undo via backup list and that legacy backups without wardrobe leave current outfit/ownership untouched. |
| Failed save | Old timer, manual-add, edit/delete/import can stay changed in memory after write failure; cancellation/manual-add can overwrite the error status. New session mutations roll back, timer changes raise `timerPersistenceError`, and failed clock-out returns nil. | No migration; report improved reliability. This is **not universal rollback**: `updateRate`, add/update/deleteRateRule, updateCurrency, setPinned still call save without rollback in the current shared store. `applyRateHistory` already rolled back in old Mac too. |
| Daily goal estimate | Idle old estimate can say “N days away”; new Insights gives finish/start-now clock time (`InsightsSnapshot.swift:180–207`). | No migration; explain estimate assumes uninterrupted remaining work. |
| 30-day trend | Old `ProgressView.swift:246` uses rolling 30×24h cutoffs; new `InsightsSnapshot.swift:71–73` uses today plus 29 prior calendar days and preceding 30 days. | No migration; totals/trends at day/DST boundaries can differ. |
| Focus radio | Old Settings-local station selection, play/stop, stop before changing station. New persists station, switches immediately, has connecting/playing/paused/stopped states, Today controls and Now Playing resume/stop cleanup. | No old saved station to recover; default rp. Announce remembered selection and pause. AVAudioSession implementation must be guarded on Mac. Volume remains in memory in both apps. |
| Focus chime | Old process Timer + NSSound; new bundled cues and worked-time local-notification schedule with foreground playback. Phone background notifications use system volume. | Sound mapping decision required; only Glass is currently mapped. On Mac decide system sounds versus bundled replacement and verify notification/background delivery semantics; do not promise iOS background behavior. |
| History ranges | Old Month/7D/30D/3M/ALL; new calendar W/M/6M pages and nonpageable All, saved range but reopened current page, anchor retained when switching ranges. | Explicit raw-value mapping in C; announce calendar boundaries and 6-month replacement. Same-key rewrite can reset range on downgrade. |
| Chart selection | Old hover/drag scrub; current shared UI tap selection and direction-checked horizontal paging, chevrons. | Preserve Mac hover/scrub in replacement ChartInteraction; add paging/keyboard. No data migration. |
| Month performance | Old this-month totals/averages; new worked-day averages, cumulative hours/current-goal line, same-point previous month comparison and completed-work 7-day projection; past months final. | No data migration; explain averages and projection changes. |
| Goal reminder | New Set goals card after first completed session; opens/focuses Insights editor. Not now snoozes 7 days, ever-configured flag hides permanently. | Seed configured flag if either old goal is positive. A previously configured then cleared goal cannot be inferred from old persisted state. |
| Widget theme | New snapshot carries theme to widgets/activity; no old Mac widget. | Theme choice is sync-class. Mac widget target deferred; do not introduce App Group relocation now. |

### Every “Mac only” item

| Feature | If shared iPhone code is used unchanged | Required parity action |
|---|---|---|
| Menu bar status/minimal mode | Absent; TabView is not a replacement. | Port MenuBarController/Icon/Status/PanelView; preserve all minimal flags and pin restoration. |
| Pinned window, five layouts | JSON `pinVisible` survives but `Shared/Core/ClockStore.swift:510–514` intentionally has no controller update. | Port PinnedWindow, reconnect persisted state on startup and on changes, preserve modes/frame/sizes. |
| Global shortcuts | Siri/AppIntents do not install desktop global keys. | Port KeyboardShortcuts and command routing to the same SharedStore instance. |
| Interface size | Shared views do not use old `S()`/UIScale. | Port scaling policy and apply it to desktop layouts; retain local percent/legacy fraction migration. |
| Update checks | iPhone has no Sparkle lifecycle. | Port UpdateChecker and Mac menu action, feed/identity/plist contract. PARITY's “GitHub check” is now specifically Sparkle in the checked-out old source. |
| Collapsible day groups / flat list | New History shows day sections with swipe actions, no old grouping toggle/collapse state. | Retain `HistoryGroupByDay`, disclosure/collapse and flat option in Mac presentation; shared page calculations can stay. |

### Additional store/model differences found beyond PARITY

| Evidence | User-visible difference | Migration / action |
|---|---|---|
| Old load 51–75; new load 69–95 and `Models.swift:124–139,216–238` | New decoder rejects entire archive for any invalid completed/running session; old accepted structurally valid JSON. A safety copy is made, then empty data with default rates can be written at the original path. | Release-blocking compatibility decision for rejected cases in F. Preserve original and decide recovery before first production launch; do not call a successful compatibility test universal compatibility. |
| Timer methods old 158–203, new 201–270 | New finite/100-year/date checks refuse impossible starts/resumes/pauses/clock-outs; elapsed display clamps values. Clock rollback cannot save a negative-order session anymore. | No rewrite for valid running sessions. Existing invalid ones need explicit recovery policy. |
| Manual add/edit old 212–232,522–544; new 279–307,696–732; `EntryTimes.editorTimes` | New edits preserve minute-unchanged timestamps and explicit end date for existing multi-day entries; new entries still infer overnight. New store rejects excessive duration/out-of-range dates. | No automatic duration correction. UI shows validation failures instead of persisting bad data; disclose legacy rejected records. |
| `SessionDisplay` in new Models 21–54 | Imported source/status suffixes get cleaned for display; “Matched timecard” labels reflect provenance without rewriting stored notes. | No data migration; preserve raw notes and matchedExternalSource for downgrade. |
| New overlap APIs 136–148 / `SessionOverlap.swift` | Editor/history warn about overlapping work without blocking a valid save. | No automatic merge/delete; existing overlaps may become newly visible. |
| Old compare/import 493–618; new 638–829 | Preview additionally shows untouched local Clockin records in imported days/whole range; explicit selected ids can be removed during import. Incoming durations/dates validated before mutations; import rollback on failure. | No automatic deletion; preserve matching/dedup and external-source markers. Explain reconciliation choices. |
| Old rate label 124; new 157,187–195 | Same-start rules use consistent first-winner selection for label and earnings rather than potentially differing tie selection. | Do not discard duplicate legacy rules silently. |
| Old add/update rate 358–392; new 431–477 | New rules cannot start on a calendar day already used by another rule; legacy duplicate-start archives still load. | No first-launch dedup. User must edit an existing rule; explain new validation if editing a custom schedule. |
| Old currentRate 136–138; new 171–177 | New current rate normalizes running/start date to start-of-day and caches by day; old compares exact timestamp. | Normal Mac UI creates day-normalized rules. A restored legacy rule with an intraday `effectiveFrom` may change live displayed earnings; final session earnings still uses exact start. Audit before normalizing such custom data. |
| New calendar caches 34–44,903,925,954,969 | Day/month/earnings caches invalidate when timezone id changes. Old caches can remain grouped in former timezone until data mutation/relaunch. | No migration; date grouping may refresh earlier/correctly when travelling. |
| Old todayDuration/todayEarnings 670–676 delegate to helpers using `.now`; new 891–898 | New Today queries use the passed instant for active time. `runningDayIfNotToday` explains start-day attribution of overnight sessions. | No migration; work still belongs to start day, not split at midnight. |
| Old backup stats/restore 89–105,472–486; new readBackups 609–632 | New list reads JSON metadata, shows unreadable backups but disables restore, filters `.json`, labels before-restore copies. | Keep Backups directory. Raw backupCount/date still scans directory contents; don't describe all stats as JSON-only. |
| Old export/auto backup 448–455,773–795; new 539–547,1018–1040 | New exported/automatic backups include optional wardrobe state from defaults. Ordinary clockin.json still uses ClockinData only. | Old Mac decoder ignores extra section and can read core fields; an old re-save/export drops wardrobe extras. Keep separate before-upgrade backup for downgrade. Daily backup interval and 30-file pruning remain (safety copies share the directory/pruning). |
| Both initializers' `rateRules == nil` migration | Still seeds a rule effective July 1, 2026, at stored base hourlyRate. Empty `[]` is preserved. Both synthesized Mac nil and legacy missing field lead to this; manually authored JSON null also decodes nil. | **No change**, but first open of pre-schedule data writes this migration and backup. Preserve intended historical rate semantics; do not move epoch to first session. Restore of a missing-rates backup does not run init migration until reopening. |
| Both JSON schema/date strategy and defaultFileURL | Default Date encoding remains seconds since Apple's reference date; same keys/UUIDs/optional fields and legacy path. | No JSON schema conversion needed for accepted data. Override SharedStore/AppGroup routing on Mac before use; defaultFileURL alone does not prove runtime path correctness. |

### Other visible additions and details to announce

The iPhone-only section of PARITY becomes Mac feature work: companion wardrobe/coins/home/shop and room editor; permanent milestone ownership at 25/50/100/250 completed hours; tired/proud/grumpy/friendly moods; finite sway and visibility/Reduce Motion/power/thermal gates; level-up overlays/share/confetti and queued badge/reaction events; nudges (at most two daytime notifications); long-session notification actions (default 10h, choices off/8/10/12); Shortcuts; overlap warnings; customizable Today cards and quick links. Haptics become no-ops on Mac. Live Activity, Dynamic Island, iOS controls, and phone orientation remain iOS-specific; Mac widgets are deferred, not achieved here.

The new Insights record tie-breaks use sorted calendar keys rather than dictionary iteration (`InsightsSnapshot.swift:92–98`), making tied weekday/hour/day choices deterministic. Shared level totals include the active session as old Mac did; longest-session/average-session records remain based on completed sessions. Badge ids, titles and presentation art differ, so old goal badge labels must not be treated as durable ownership. Language switching adds English/Turkish; decide the first-launch language for existing English-only Mac users rather than accidentally adopting a different system language.

## E. Small phase 1 seams proposed

These are proposals only. Keep business models/importers/calculations shared. Do not build a generic platform service framework.

| Seam | Proposed file / call sites | Smallest responsibility |
|---|---|---|
| Platform storage routing | `Shared/Sync/AppGroup.swift`, `Shared/Sync/SharedStore.swift`, `Shared/Core/AppLanguage.swift` | `#if os(macOS)` selects ClockStore.defaultFileURL and standard Mac defaults; iOS retains App Group migration. No new abstraction needed. |
| Haptic no-op | Existing `Shared/Theme/Haptics.swift`; `Clockin/Celebrations/LevelUpHaptics.swift` | Preserve Haptics.play/enabled, View feedback and Binding helpers for many callers; Mac branches do nothing. WIDGET_EXTENSION is not a platform guard. |
| Inline navigation title | Proposed `Shared/Theme/PlatformViewModifiers.swift` | One tiny `clockinInlineNavigationTitle()` View helper used by >3 files, applying navigationBarTitleDisplayMode only on iOS. Avoid wrapping every SwiftUI modifier. |
| Notification settings link | Proposed `Shared/Theme/NotificationSettingsLink.swift` | Shared by FocusSettingsSection, LongSessionReminderSettingsSection and NudgeSettingsSection; iOS opens its settings URL, Mac presents appropriate notification-settings guidance/link after verification. |
| Application activity/accessibility | Proposed `Shared/Theme/PlatformPresentationState.swift`, only if useful across CelebrationCenter, LevelUpSound, LevelUpHaptics | Tiny active/reduce-motion queries backed by UIKit/AppKit. Keep window/modal traversal in platform-specific celebration probes, not in this helper. |
| Session fan-out | `Shared/Sync/SessionMirror.swift` | Guard ActivityKit members/methods and ControlCenter calls, retaining chime/reminder/nudge/celebration updates. Stub only Live Activity operations on Mac. Widget snapshot publication can wait for widget phase. |
| Intents conformance | `Shared/Intents/ClockIntents.swift` | Conditional typealias/protocol choice for the three intents (AppIntent Mac / LiveActivityIntent iOS); leave saved-state checks/action bodies shared. Exclude SetClockedInIntent on macOS 14. |
| Audio sessions | FocusChimeController, FocusRadioController, LevelUpSound | Local `#if os(iOS)` around AVAudioSession setup/observers. AVPlayer/AVAudioPlayer remain shared; add Mac interruption/device policy only when needed. |
| AppKit view hosts | Proposed `ClockinMac/Rendering/` counterparts for mascot, rolling numbers, confetti, home atmosphere and celebration probes | Use NSViewRepresentable/NSView branches at existing view boundaries; reuse CGImage/CALayer/data logic. These are real native equivalents, not giant typealiases of UIView to NSView. |
| Image/font one-offs | ShareStatsView, LevelUpCrest, MascotSkinEffects; WardrobeFrameCache fixed-pose decode | Local NSImage/NSFont/CGColor/NSPasteboard branches; preserve neutral CGImage assets. Only introduce a shared image/font helper if ≥3 actual files need the identical operation. |
| One-off presentation/input | History topBarTrailing, Insights toolbar, settings keyboard toolbar, GoalHoursField keyboardType, GoalsPaceView keyboard notifications, room editor fullScreenCover, navigation/status hiding | Call-site iOS guards and Mac sheet/window/list/toolbar alternatives. Verify uncertain detent/separator/keyboard-dismiss availability in real macOS build. |
| Mac app shell | Proposed `ClockinMac/ClockinMacApp.swift`, `ClockinMac/RootView.swift`, Mac delegate | Native sidebar + Settings + Commands; port old menu/pin/update/relocation ownership; ensure every entry point uses same ClockStore. This is not a shared shim. |

A UIKit-free compile is only phase 1 evidence. Phase 2/3 still needs parity verification for window interactions, asset fallback, audio, notifications and persisted preferences. No CloudKit engine or active timer sync is introduced in this phase.

## F. Mac-writable data rejected by current decoder

Current `SessionDuration` allows finite duration/accumulated values in `0...3_153_600_000` seconds (100×365 days), dates within `.distantPast ... .distantFuture`, completed end ≥ start, and running resumedAt ≥ start. An active running session is additionally checked for accumulated + elapsed **at decode wall-clock time**. It does not enforce completed duration ≤ end−start, nor validate rate dates/negative finite monetary fields. Zero-duration completed sessions are accepted.

All fixtures in `Tests/manual/maccompat/main.swift` are synthetic. Mac model structs are exact renamed/private copies; the old CSV and pasted-text parsers are also copied under private names to prove external-input reachability. The Mac AppKit store itself is **not executed**: its mutation/guard expressions and paths are audited, and their resulting model values are encoded with the old default JSONEncoder. API-only and inherited malformed-file cases are explicitly separated below from ordinary input/clock-change paths.

| Old Mac writer/path | Reachability and possible rejected data | Fixture / result |
|---|---|---|
| `clockOut`, ClockStore 192–202 | Start a timer, then clock/system time moves before its start; clamps added elapsed to zero but writes end < start. Forward jump/long elapsed can exceed cap. | `clock-out-after-clock-rollback`, `clock-out-over-cap`: rejected, unreadable original copied, store empty. |
| `resume`, 183–188 | Pause, system clock moves before start, resume; no validation of resumedAt. API/restored extreme date can also be outside bounds. | `resume-before-start`, `resume-out-of-range-date`: rejected with preserved unreadable copy. |
| `clockIn`, 158–168 | Finite elapsed has no cap; API accepts >100 years or out-of-bounds date. UI clamps manual elapsed to 999h59m (`ManualStartView:27–28,77–79`), so UI cannot directly enter the oversized value. Later time/clock advance can invalidate an originally valid running archive at decode. | `clock-in-over-cap`, `running-elapsed-over-cap-at-read`: rejected. Out-of-range running date covered by restore fixture; same model validation. |
| `pause`, 175–180 | Adds nonnegative elapsed without cap; forward clock jump or inherited corrupt accumulated value persists invalid accumulated. | `pause-over-cap`: rejected. Negative accumulated requires preexisting corrupt running data, not normal pause arithmetic. |
| CSV parse 34–40 → importCSV 428–433 → importSessions 553–610 | Finite external milliseconds can exceed 100 years; ISO date year 5000 parses outside bounds. Same unvalidated row can append or correct an existing local entry. | `csv-over-100-years`, `csv-correction-over-100-years`, `csv-out-of-range-date`: actual copied old parser accepts; current decoder rejects. |
| PastedTextImporter parse/resolveDate/makeSession → importPastedText 439–442 → importSessions | Explicit four-digit date range can contain year 5000; parser accepts and builds normal one-hour session. Usual midnight rollover itself produces valid nonnegative intervals. | `pasted-out-of-range-date`: actual copied parser accepts year 5000; current decoder rejects. |
| `addManualSession`, 212–232 | Only end > start; API allows >cap or bounded-duration out-of-range dates (Int dedup remains representable in these fixtures). Normal UI combines times into one day/overnight, so >100-year span is API-level, not normal manual UI. | `manual-over-cap`, `before-distant-past`, `after-distant-future`: rejected. |
| `updateSession`, 522–544 | Positive calculated duration is unbounded; note-only edit retains existing oversized imported duration. Unrestricted date arguments can be out of bounds. | `edited-over-cap` plus date-bound fixtures: rejected. A new negative calculated duration/end ≤ start is blocked; unchanged negative duration can survive a note edit only if already loaded from malformed JSON. |
| `importSessions`, 553–610 | No per-row validity guard. Direct API can write negative duration or inverted dates; ordinary CSV rejects inverted dates and falls back from negative/NaN duration to measured interval. Imported correction assigns start/end/duration verbatim. | `direct-import-negative-duration`: rejected; explicitly API-only negative input. Inverted end has same rejection as rollback fixture, not claimed as ordinary CSV input. |
| `importBackup`, 458–466 / restoreLatestBackup 472–486 | Supplied JSON only checks completed duration ≥ 0 and end ≥ start. Oversized/finite out-of-bounds completed records and **all** invalid running values pass. | `restore-over-cap`, `restore-negative-running`, `restore-out-of-range-running-date` (also invalid resume fixtures): rejected. A corrupt supplied backup is required for negative accumulated; no normal timer path creates it from valid state. |
| Init 51–75, then any save 760–765 | Old decoder can load negative completed duration/inverted dates/bad running values. Missing-rates migration or later updateRate/add/update/deleteRule/updateCurrency/setPinned/cancel/delete/import/edit re-encodes remaining invalid records. | `load-and-resave-negative-duration` proves encodable old shape rejected by current store. Requires preexisting malformed archive; these preference/rate writes do not create invalid sessions from clean data. |
| ExportBackup 448–455 | Encodes current in-memory data with no validity guard; can export any finite invalid cases above, including data left in memory after failed save. | Same old-model encoder fixtures; no separate archive format. |
| Automatic backup 773–795, unreadable copy 59–67 | Byte-copies existing file, so can preserve any malformed input even when a new JSON encode would fail. It does not synthesize session fields. | New check asserts exact preserved bytes for every rejected fixture; corrupt-file byte copy is not evidence that default encoder can emit NaN. |
| All default JSONEncoder paths | NaN/±infinity duration, accumulated, date or monetary value cannot be JSON-encoded with Mac defaults. Import's `Int` dedup may trap first for infinity/overflow; huge finite fixture values are deliberately Int-safe. | Nonfinite duration/accumulated/date checks confirm encoder failure. No claim of a reachable newly written NaN JSON file. Negative CSV milliseconds fall back; NaN CSV comparison fails; +infinity may reach Int trap, not saved valid JSON. |
| Rate setters/proposals 260–415 | Normal setters reject negative/nonfinite rate; rate dates normalize but have no SessionDuration bounds. Restored negative finite rates or out-of-range rule dates are not rejected by either decoder. | `unvalidated-rate-fields`: accepted and downgrade round-trips. Not a duration/date validation mismatch to “fix” here. |

Each rejected fixture is an expected regression assertion: it passes the check only if the old model encoder/decoder succeeds, the current decoder rejects with dataCorrupted, and ClockStore saves exactly one byte-identical unreadable copy while reporting failure and presenting empty sessions/no timer. These outcomes are unresolved compatibility issues, not successful migration. See the result report for executed output and decisions needed.
