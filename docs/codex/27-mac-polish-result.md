# 27 — Mac polish result

Base: `6546b420b3ee81f8bdf43c61daef4404b2b00ffd` (this worktree's starting main commit).

Mac presentation and input changes only. Existing theme colors are retained; select Electric Blue for the user's blue accent. No screenshots were taken, app launched, archive/release produced, or CloudKit/relay request made. The supplied History and Settings captures and original room artwork were inspected as files.

## 1. Three-tab floating glass bar

`ClockinMac/MacTabBar.swift`, `MacRootView.swift`, `MacCommands.swift`; scroll clearance in `Clockin/Views/Components/PlatformModifiers.swift`, `DashboardView.swift`, `HistoryView.swift`, `Goals/GoalsPaceView.swift`, `Insights/InsightsView.swift`, `Badges/BadgesView.swift`.

- Today / History / Progress only; Cmd-1/2/3 remain, Cmd-4 removed. Settings remains a navigation destination.
- macOS 26+: `GlassEffectContainer`, interactive regular capsule glass, accent-tinted selection with a shared `glassEffectID`. Older systems: ultra-thin material, hairline highlight, soft shadow, and matched selection geometry. Selected text and symbol use the palette accent; hover is subtle; Reduce Motion removes selection movement.
- The 64 pt bar overlays the scrolling content, without a solid backing strip or a root safe-area inset. Each primary vertical scroller reserves 80 pt at the end (bar plus surrounding clearance). Padding is scroll content margin, not a permanent empty viewport band.

Verify at **960 × 860 pt**, Turkish / Electric Blue, then Carbon: scroll Today, History and all three Progress sections to the bottom. The last row must be fully reachable above the bar, with moving content visible behind the material. At the top, check the timer and earnings remain clear. Switch tabs using clicks and Cmd-1/2/3, with Reduce Motion on/off. Compare macOS 26+ glass with the fallback on macOS 14/15. OS Reduce Transparency may intentionally make the material more opaque.

## 2. Settings as a categorized main-window page

`Clockin/Views/SettingsView.swift`, `ClockinMac/MacSettingsCategory.swift`, `MacSettingsSection.swift`, `MacCommands.swift`, `MacRootView.swift`, `Clockin/Views/DashboardView.swift`.

- A 190 pt native sidebar selects General, Timer & goals, Pay & currency, Menu bar, Notifications, iCloud, Data & import, or Help & about. The right pane is a grouped native Form, capped at 720 pt; Settings has a 700 pt minimum content width to keep both columns readable.
- The tab bar hides. Done with a back chevron returns to the previously selected main section. Reopening Settings while it is already visible does not overwrite that return destination. Language changes do not reopen Settings after Done.
- Existing help, Today, appearance, language/theme, pay, data and about sections are reused. Rate editing, confirmation, import/export, backup and other actions use the existing state/bindings and handlers. The companion behavior picker is extracted once for both platforms.
- iPhone Settings retains the same section order, navigation stack and sheet. Mac-specific sections are selected by category. The iPhone notification-settings button has its own notification section and explanatory footer, outside the menu-bar toggles.
- Settings sheets keep `macSheetFrame`, including the rate-change prompt. The Timer & goals category opens the existing Goals editor rather than a second set of goal bindings.

Verify at **960 × 860**, then **700 × 650 pt**: open Ayarlar through the Today gear, Cmd-,, the menu-panel settings action, and `MacNavigation.open(.settings)`/the existing debug section fixture. There must be no bottom bar. Visit all eight categories and check Turkish labels, right-side native controls, footer wrapping and section gaps. Return with Done from both Geçmiş and İlerleme; verify the prior section returns. Change EN ↔ TR, then Done, and confirm Settings stays closed. In Pay, edit a rate, switch category and cancel the existing impact prompt; make sure edits are not silently lost or applied twice. Open Rate schedule, Import timecards, Automatic backups, Companion and Help; verify the sheets fit, scroll and dismiss. These checks can use disposable data; no real import, restore, deletion or sync is needed for layout review.

## 3. Native control inventory

The Mac root and Mac sheets now default to `.menu` pickers, bordered buttons and regular control size. Per-control styles remain explicit where selection or primary actions need different treatment. All accent color comes from the current palette.

| Style / surface inventoried | Mac disposition and files |
| --- | --- |
| `PrimaryActionButtonStyle` | Native `.borderedProminent`, large. TimerCard, SessionSummaryView, ShareStatsView, TimecardImportView, CompanionHomePreview and MenuBarPanelView keep their existing actions. |
| `SecondaryActionButtonStyle` | Native `.bordered`, large. TimerCard, TimecardImportView and menu-panel pause/resume. |
| `DangerActionButtonStyle` | Native red `.bordered`, large. TimerCard clock-out. Existing destructive confirmations are untouched. |
| `ClockinAccentButtonStyle` | Native small prominent Mac style; inventory found no current call sites. |
| `.pressable` | Today toolbar, radio playback and Desk Mode actions use native bordered controls on Mac. Intentionally custom cards/artwork retain their drawn content and gain hover through `MacControlHover`: Today quick links/goals, level badge, companion card, report cells and badge art. |
| `.hitTarget` | Recent-session and pinned-window icon hit targets stay plain, with Mac hover. `Shared/Theme/ButtonStyles.swift`. |
| `.plain` artwork/list buttons | Hover added without replacing artwork in BackupsView, RateScheduleView, TimecardImportView, CompanionView, MascotCard, InsightsBadgesView, LevelBadgeGallery. History session rows use their own hover fill and existing list selection. Day disclosure headers remain native plain disclosure actions. |
| Tab buttons | Custom plain labels inside glass, accent selection and hover; three tabs only. |
| Companion category capsules | Replaced on Mac with a content-sized native menu picker in CompanionCategoryTabs. |
| History Week/Month/6 months/All, USD/TRY, By day/Sessions | Already native `.segmented`; retained. Period arrows now bordered, compact controls. |
| Progress Goals/Reports/Badges | Already native `.segmented`; capped at 360 pt on Mac. |
| Report grouping/range, room layout/light, share privacy/page/export, import scope/leftover choices | Already native segmented controls; retained, including their existing bindings. |
| Theme, language, currency, companion behavior, menu-bar layout, chime sound, nudge tone, reminder duration | Native `.menu` through the Mac Form/root/sheet environment. Pay text fields have bounded widths and rounded native borders. |
| Workdays / radio station / room item / companion activity | Native menus; workdays and radio station explicitly size to content. Room editor and preview keep existing selection logic. |
| Menus and text actions | Ellipsis menus, context menus, panel links, Today cancel/start-with-elapsed links, cancel/not-now and toolbar actions retain their native borderless/plain idiom. The rate prompt's date-specific action is secondary, leaving one prominent action in that area. |
| Manual entry/start, reminder end, settings sub-sheets and sync presentation controls | Inherit native Mac sheet defaults; their date pickers, save/cancel actions and confirmation logic remain unchanged. |

Main style definitions are in `Shared/Theme/ActionButtonStyles.swift`, `ButtonStyles.swift`, `Themes.swift`. Direct control changes are in `DashboardView.swift`, `DashboardShortcuts.swift`, `TimerCard.swift`, `Clockin/Audio/FocusRadioCard.swift`, `Companion/CompanionCategoryTabs.swift`, `Goals/GoalsPaceView.swift`, `HistoryView.swift`, `SettingsView.swift`, and `DeskMode/DeskModeView.swift`.

Verify **Today at 960 × 860**, **menu panel at its normal 320 pt width**, and **sheets around 560 × 680**: idle/working/paused actions, toolbar gear/add/customize, pinned radio, chime options, Settings menus and text fields. Open import and companion previews without committing changes. Check keyboard focus rings, enabled/disabled styles, hover, selected blue accent and long Turkish menu titles. Keep the iPhone comparison at the same existing device size; there should be no control or spacing change.

## 4. History and Progress layout and copy

- History's List has 28 pt internal horizontal margins, a 16 pt top margin and an 840 pt centered maximum column.
- Goals, Reports and Badges have 28 pt combined internal horizontal padding and an 800 pt centered maximum column. Today retains its established readable column.
- Mac chart instructions, radio retry text, companion/badge preview tips and applicable Help text say Click / tıkla. `Shared/Localizable.xcstrings` contains English and Turkish for new keys, canonically serialized with sorted keys. Existing keys and translations are unchanged.
- `ClockinMac/MacChartInspection.swift` rejects future days and out-of-domain coordinates for hover and clicks. Monthly coordinates normalize to the start of the month, so the current month remains inspectable on October 1. Report day cells already disabled future days and retain that guard.

Verify **960 × 860**, **700 × 650**, and **1440 × 900 pt**: History earnings must have a visible gutter; Progress cards must stop expanding at their readable maximum. Select current Month, hover/click tomorrow and later empty days: no future “No work on…” detail may appear. Click an earlier empty day, today, and the current month in 6 months; valid details must still work. Repeat USD/TRY and EN/TR.

## 5. Trackpad, keys, hover and session rows

`ClockinMac/MacPeriodNavigation.swift`, `MacPeriodScroll.swift`, `MacChartReadout.swift`, `MacChartInspection.swift`; shared Mac branches in `EarningsChartView`, `ChartInteraction`, `MonthPerformanceView`, `InsightsHeatmapView`, `InsightsAggregateHeatmapView`, `GoalsPaceView`, and `HistoryView`.

- History earnings and monthly-hours charts have a local AppKit event region. Precise horizontal scrolls accumulate a 50 pt threshold, lock the starting axis, and issue at most one page action per gesture. Momentum never issues another action. `scrollingDeltaX` already includes the system's natural-scrolling preference; it is not inverted a second time.
- The region must belong to the key window, have no attached sheet and contain the pointer in its visible bounds. It does not hit-test over SwiftUI content. Monitors are removed on detachment/dismantle. Vertical scroll and ordinary wheel input pass through; entering a graph midway through a gesture cannot start paging.
- Left/Right work with chart focus or pointer hover. Hover shortcuts do not steal arrows from text editing or modified key combinations. The existing History paging function supplies animation and the forward boundary.
- Earnings hover uses a temporary inline inspection value; moving out restores the clicked selection. Other hour charts show an inline readout; report cells show native tooltips. Future dates do not yield an inspection value.
- Reports contains horizontally scrolling archive timelines, rather than a previous/next period pager. Those retain native continuous two-finger scrolling. Left/Right additionally select/reveal adjacent days or periods with animation. Today goals has no period pager in this base.
- History rows highlight on hover. Double-click/Edit opens the existing editor; right-click Delete and the Delete key use the existing confirmation. There is no existing duplicate-session action in this codebase, so no new data operation was invented.

Verify **History at 960 × 860**: Week, Month, 6 months, populated/empty page transitions, and All. Swipe slowly below threshold, cross threshold, continue moving, release into momentum, reverse direction, and start a second gesture. Expect one step per gesture; All must not page; next may never move beyond the current period. Repeat with Natural scrolling enabled and disabled. Start a vertical or diagonal vertical-dominant scroll over each chart and verify the page scrolls. Focus a chart with the keyboard, test Left/Right, then test with only hover. Move the pointer away and edit a note/rate: arrows must belong to the editor. Open a sheet and ensure the background cannot page. Hover/click bars, change periods, and confirm stale readouts clear. In Reports, scroll both horizontal timelines, hover cells, and use arrows. For History rows, inspect context menus and cancel Delete; selected and hovered rows should be distinguishable.

## 6. Desk Mode

`Clockin/Views/DeskMode/DeskModeView.swift`, `ClockinMac/DeskModeWindow.swift`, `MacDeskFraming.swift`.

- Mac room uses true aspect fill without the phone's 25% downward offset, 30% opacity or edge masks. A light 12% palette overlay preserves the artwork while improving contrast.
- Framing preserves the room's 3:2 proportions and crops at most 26 source pixels from the ceiling. At 16:9, source y=26…228.5 remains visible: the round window begins at y=30 and the default companion's feet at y=224 stay in frame. 16:10 and 3:2 show more vertical artwork. User-arranged furniture still follows its saved placement.
- Timer and earnings are centered in a bounded translucent panel; today's total and native work controls are in the bottom corners. A top-right close button complements Escape. Summary sheets use `macSheetFrame`. Fullscreen/window lifecycle and display-awake behavior are unchanged.
- The iPhone desk layout and room rendering path are unchanged. `CompanionHomeView` and all art assets are unchanged.

Verify full screen at **1440 × 900 (16:10)**, **1920 × 1080 (16:9)** and **1440 × 960 (3:2)**: no top band, full visible room width, visible round window and companion feet, centered legible money/time, and unobstructed corner controls. Try ready/working/paused, show-home off/on, both room directions, and sleeping/relaxing companion layouts. Check Carbon, Electric Blue and Daylight, a long timer/earnings amount, Escape, close button and reopening. Custom arrangements at extreme room edges also need visual checking.

## Verification

- All **49 non-xcodebuild commands from README's Checks block passed** (table below). Their logs are in `/tmp/clockin27-suites/`; machine-readable results are `results.json`. Test runners use fake/local sync transports; no CloudKit/relay call is made.
- `Tests/manual/macpolish/run`: **33 checks passed**, covering scroll threshold, one-step/momentum/direction/axis/cancel behavior, phase-less precise bursts, mid-gesture entry, future-day/month inspection and three screen framing ratios.
- `python3 Tests/manual/macpolish/ios_paths.py`: **30 shared Swift files match the base's active iOS source in both release and DEBUG**, after expanding the explicitly extracted Settings views/picker and removing verified identity Mac modifiers. It also verifies all old localization entries are unchanged and all 29 added keys have English and Turkish. This is a source-path check, not a screenshot comparison.
- Final SDK result: **all six target/platform checks passed**. `python3 Tests/manual/crashaudit/typecheck.py` checks iPhone + iPhone widgets at iOS 17 and Mac + Mac widgets at macOS 14 and 15 with Swift 6 strict concurrency and warnings as errors. It also compiles the availability-gated glass APIs against the installed SDK. Final log: `/tmp/clockin27-typecheck-final.log`. The harness uses its documented palette/State/LanguageSwitch macro substitutions because this host cannot run nested macro-plugin sandboxes.
- `git diff --check`: **passed**.

| README command / suite | Result |
| --- | --- |
| `Tests/manual/sync/run` | PASS |
| `Tests/manual/sync/run persistence` | PASS |
| `Tests/manual/sync/run capability` | PASS |
| `Tests/manual/crashaudit/run` | PASS |
| `Tests/manual/crashaudit/platform-run` | PASS |
| `Tests/manual/sync/run typecheck` | PASS |
| `Tests/manual/sync/run codec` | PASS |
| `Tests/manual/sync/run send` | PASS |
| `Tests/manual/syncapp/run` | PASS |
| `Tests/manual/syncapp/run typecheck` | PASS |
| `Tests/manual/macliveactivitytip/run` | PASS |
| `Tests/manual/iphonefollowsmac/run` | PASS |
| `Tests/manual/iphonefollowsmac/run typecheck` | PASS |
| `wardrobe` | PASS |
| `skins` | PASS |
| `armorhd` | PASS |
| `radio` | PASS |
| `celebrations` | PASS |
| `rolling` | PASS |
| `haptics` | PASS |
| `levelup` | PASS |
| `levelprestige` | PASS |
| `snapshot` | PASS |
| `import` | PASS |
| `backups` | PASS |
| `overlap` | PASS |
| `raterange` | PASS |
| `earnings` | PASS |
| `historytry` | PASS |
| `insights` | PASS |
| `mascot` | PASS |
| `companion2` | PASS |
| `companion` | PASS |
| `momentum` | PASS |
| `share` | PASS |
| `widgettheme` | PASS |
| `chime` | PASS |
| `chimesound` | PASS |
| `controls` | PASS |
| `reminder` | PASS |
| `nudges` | PASS |
| `goals` | PASS |
| `sessions` | PASS |
| `maccompat` | PASS |
| `macmigration` | PASS |
| `rates` | PASS |
| `feedback` | PASS |
| `sessiondisplay` | PASS |
| `liveactivityregistry` | PASS |

No xcodebuild, signed launch, GUI interaction, image recapture or distribution was performed. The chime README's notification-delivery procedure requires a running disposable simulator, and the screenshot workflow requires a GUI/build; neither was run. The website image optimizer is an asset-generation workflow, not an app check suite, and was not run because no website/art changes were requested. Actual glass translucency, animation, pointer/trackpad delivery, fullscreen composition, Turkish truncation and iPhone visual parity remain for the manual checks above.

API references consulted: [Apple: building with Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/323/) and [NSEvent](https://developer.apple.com/documentation/appkit/nsevent). SDK compilation, not web examples, determined supported signatures and availability.
