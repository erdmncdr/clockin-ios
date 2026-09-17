import SwiftUI

enum AppTab: Hashable {
    case today
    case history
    case insights
    case badges
}

struct RootView: View {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @EnvironmentObject private var store: ClockStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("Clockin.ChimeEnabled") private var chimeEnabled = false
    @AppStorage("Clockin.ChimeIntervalMinutes") private var chimeInterval = 10
    @AppStorage("Clockin.ChimeSound") private var chimeSound = FocusChimeSound.defaultSound.rawValue
    @AppStorage(DeskMode.enabledKey) private var deskModeEnabled = true
    @AppStorage(NudgePlanner.enabledKey) private var nudgesEnabled = true
    @AppStorage(NudgePlanner.toneKey) private var nudgeTone = NudgeTone.grumpy.rawValue
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @AppStorage(GoalPrompt.configuredKey) private var everConfiguredGoal = false
    @State private var goalEditorRequest = false
    @ObservedObject private var nudges = NudgeController.shared
    @ObservedObject private var reminder = LongSessionReminderController.shared
    @State private var tab: AppTab = .today
    @State private var deskSummary: WorkSession?
    @State private var celebrationShare: StatsShareSnapshot?
    @State private var shareBlocker = UUID()
    @State private var deskSuppressed = false
    @ObservedObject private var celebrations = CelebrationCenter.shared

    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    /// iPhone'da yatay tutulunca dikey boyut sinifi kucuk olur.
    private var showsDeskMode: Bool { deskModeEnabled && verticalSizeClass == .compact && !deskSuppressed }

    /// Masada duran telefon oturum surerken kararmasin. Duraklatilmis ya da
    /// bos oturumda ekran normal kapansin, pil bosuna gitmesin.
    private var keepsScreenOn: Bool {
        showsDeskMode && scenePhase == .active && store.running?.isPaused == false
    }

    @State private var selectionFeedback = HapticSignal()

    var body: some View {
        ZStack {
            // Sekmeler masa modunun altinda yasamaya devam eder; dik cevirince
            // acik ekran ve kaydirma yeri kaybolmaz.
            tabs
                .accessibilityHidden(showsDeskMode)
            if showsDeskMode {
                DeskModeView(onClockOut: { deskSummary = $0 })
                    .environment(\.clockinContentActive, deskSummary == nil && celebrations.event == nil)
                    .statusBarHidden()
                    .persistentSystemOverlays(.hidden)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            CelebrationOverlay(center: celebrations, share: {
                celebrations.dismiss()
                celebrations.setBlocked(shareBlocker, true)
                celebrationShare = StatsShareSnapshot(store: store, dailyGoal: dailyGoalHours, monthlyGoal: monthlyGoalHours)
            }, openBadges: {
                deskSuppressed = true
                tab = .badges
            })
        }
        .background(CelebrationWindowProbe())
        .onChange(of: verticalSizeClass) { _, _ in deskSuppressed = false }
        .hapticFeedback(selectionFeedback)
        .animation(.easeInOut(duration: 0.25), value: showsDeskMode)
        // Mac'te her gorunum temayi `@AppStorage`'dan kendisi okuyordu.
        // Burada bir kez okunup ortamla asagi iniyor.
        .environment(\.palette, palette)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
        .sheet(item: $celebrationShare, onDismiss: {
            celebrations.setBlocked(shareBlocker, false, waitForDismissal: false)
        }) { snapshot in
            ShareStatsView(snapshot: snapshot)
                .preferredColorScheme(palette.colorScheme)
        }
        .celebrationBlocked(by: deskSummary != nil)
        .sheet(item: $deskSummary) { session in
            SessionSummaryView(session: session)
                .preferredColorScheme(palette.colorScheme)
        }
        .onChange(of: keepsScreenOn, initial: true) { _, keepOn in
            UIApplication.shared.isIdleTimerDisabled = keepOn
        }
        // Oturum degisiklikleri `SessionMirror`'dan gelir; o ekran yokken de
        // calisir. Burada yalnizca uygulama acikken degisen tercihler izlenir.
        .onChange(of: nudgesEnabled) { _, _ in nudges.update(store: store) }
        .onChange(of: nudgeTone) { _, _ in nudges.update(store: store) }
        .onChange(of: dailyGoalHours) { _, _ in
            nudges.update(store: store)
            celebrations.refresh(store: store)
        }
        .onChange(of: monthlyGoalHours) { _, _ in celebrations.refresh(store: store) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            celebrations.setActive(false)
            if phase == .active {
                celebrations.refresh(store: store)
                celebrations.setActive(true)
            }
        }
        .onChange(of: GoalPrompt.hasGoal(daily: dailyGoalHours, monthly: monthlyGoalHours), initial: true) { _, hasGoal in
            if hasGoal { everConfiguredGoal = true }
        }
        .onChange(of: nudges.openToday, initial: true) { _, requested in
            if requested {
                tab = .today
                nudges.openToday = false
            }
        }
        .onChange(of: chimeEnabled) { _, _ in updateChimes() }
        .onChange(of: chimeInterval) { _, _ in updateChimes() }
        .onChange(of: chimeSound) { _, _ in updateChimes() }
        .onChange(of: reminder.pendingEndTime, initial: true) { _, start in
            if start != nil { tab = .today }
        }
        .task(id: scenePhase) {
            // Arka plana gecerken hazir kuyrugu silme; uygulama eklerken askiya alinabilir.
            guard scenePhase == .active else { return }
            reminder.update(running: store.running, force: true)
            nudges.update(store: store)
            updateChimes(force: true)
            // On planda uzun oturumlarda da kuyruk bitmesin. Arka planda iOS teslim eder.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
                updateChimes(force: true)
                nudges.update(store: store)
                celebrations.refresh(store: store)
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab.hapticSelection($selectionFeedback)) {
            DashboardView(isSelected: tab == .today && !showsDeskMode && deskSummary == nil && (celebrations.event == nil || celebrations.event?.isReaction == true), showHistory: { tab = .history }, showInsights: { tab = .insights }, setGoals: {
                goalEditorRequest = true
                tab = .insights
            }, showProgress: { tab = .badges })
                .tabItem { Label("Today", systemImage: "timer") }
                .tag(AppTab.today)
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.history)
            InsightsView(openGoalEditor: $goalEditorRequest)
                .tabItem { Label("Insights", systemImage: "target") }
                .tag(AppTab.insights)
            // Ayarlar alt sekmede degil, Bugun ekraninin ust cubugunda. Sik
            // acilan bir yer degil; sekmeyi ilerleme icin kullanmak sayfalari
            // daha anlasilir boluyor.
            BadgesView()
                .tabItem { Label("Badges", systemImage: "rosette") }
                .tag(AppTab.badges)
        }
    }

    private func updateChimes(force: Bool = false) {
        SessionMirror.shared.refreshChimes(force: force)
    }
}
