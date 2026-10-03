import SwiftUI

enum MacSection: Hashable {
    case today
    case history
    case progress
    case settings
}

struct MacRootView: View {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage(ClockinFontChoice.preferenceKey) private var fontRaw = ClockinFontChoice.system.rawValue
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var navigation = MacNavigation.shared
    @ObservedObject private var services = MacAppServices.shared
    @ObservedObject private var celebrations = CelebrationCenter.shared
    @ObservedObject private var nudges = NudgeController.shared
    @ObservedObject private var reminder = LongSessionReminderController.shared
    @State private var progressSection: ProgressSection = .goals
    @State private var goalEditorRequest = false
    @State private var showCompanion = false
    @State private var celebrationShare: StatsShareSnapshot?
    @State private var shareBlocker = UUID()
    @State private var celebrationFading = false

    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette(font: .selected(fontRaw)) }

    private var showsCelebration: Bool {
        celebrations.event.map { !$0.isReaction } ?? false
    }

    var body: some View {
        detail
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if navigation.section != .settings {
                    MacTabBar(selection: $navigation.section)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            }
        .allowsHitTesting(!showsCelebration && !celebrationFading)
        .accessibilityHidden(showsCelebration || celebrationFading)
        .task(id: showsCelebration) {
            if showsCelebration {
                celebrationFading = true
            } else {
                // Cikis solarken alttaki kontroller kapali kalir.
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                celebrationFading = false
            }
        }
        .overlay(alignment: .top) {
            CelebrationOverlay(center: celebrations, share: {
                celebrations.dismiss()
                celebrations.setBlocked(shareBlocker, true)
                celebrationShare = StatsShareSnapshot(store: store, dailyGoal: dailyGoalHours, monthlyGoal: monthlyGoalHours)
            }, openBadges: {
                progressSection = .badges
                navigation.section = .progress
            }, openCompanion: {
                showCompanion = true
            })
        }
        .sheet(isPresented: $showCompanion) { CompanionView().macSheetFrame() }
        .celebrationBlocked(by: showCompanion)
        .sheet(item: $celebrationShare, onDismiss: {
            celebrations.setBlocked(shareBlocker, false, waitForDismissal: false)
        }) { snapshot in
            ShareStatsView(snapshot: snapshot)
                .preferredColorScheme(palette.colorScheme)
                .macSheetFrame()
        }
        .sheet(item: $navigation.sheet) { destination in
            Group {
                switch destination {
                case .manualStart: ManualStartView()
                case .newEntry: ManualEntryView()
                }
            }
            .environment(\.palette, palette)
            .preferredColorScheme(palette.colorScheme)
            .macSheetFrame()
        }
        .celebrationBlocked(by: navigation.sheet != nil)
        .syncFirstMergePrompt()
        .timecardReimportPrompt()
        #if DEBUG
        // Review fixture: `--sync-section` shows the iCloud settings section on its own.
        .sheet(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("--sync-section"))) {
            Form { SyncSettingsSection() }.formStyle(.grouped).frame(width: 480, height: 360)
        }
        #endif
        .background(CelebrationWindowProbe())
        // Barindirilan gorunum bir sahnede degil; evre pencereden gelir.
        .environment(\.scenePhase, services.scenePhase)
        .environment(\.palette, palette)
        // iPhone formlari gruplu yazildi; Mac'in varsayilan sutun duzeni
        // etiketleri sola tasiyip kesiyordu.
        .formStyle(.grouped)
        .pickerStyle(.menu)
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
        .onChange(of: navigation.goalRequest) { _, requested in
            if requested {
                progressSection = .goals
                goalEditorRequest = true
                navigation.goalRequest = false
            }
        }
        .onChange(of: nudges.openToday, initial: true) { _, requested in
            guard requested else { return }
            navigation.open(.today)
            nudges.openToday = false
        }
        .onChange(of: reminder.pendingEndTime, initial: true) { _, start in
            if start != nil { navigation.open(.today) }
        }
    }

    @ViewBuilder
    private var detail: some View {
        let contentActive = !celebrations.hasBlockingPresentation && !showsCelebration
        switch navigation.section ?? .today {
        case .today:
            DashboardView(isSelected: navigation.section == .today && contentActive,
                          showHistory: { navigation.section = .history }, showInsights: {
                progressSection = .goals
                navigation.section = .progress
            }, setGoals: {
                goalEditorRequest = true
                progressSection = .goals
                navigation.section = .progress
            }, showProgress: {
                progressSection = .badges
                navigation.section = .progress
            })
        case .history:
            HistoryView()
        case .progress:
            ProgressHubView(section: $progressSection, openGoalEditor: $goalEditorRequest)
                .environment(\.clockinContentActive, contentActive)
        case .settings:
            SettingsView()
        }
    }
}
