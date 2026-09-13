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
    @AppStorage("Clockin.ChimeEnabled") private var chimeEnabled = false
    @AppStorage("Clockin.ChimeIntervalMinutes") private var chimeInterval = 10
    @AppStorage("Clockin.ChimeSound") private var chimeSound = FocusChimeSound.notification.rawValue
    @State private var tab: AppTab = .today

    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        TabView(selection: $tab) {
            DashboardView(showHistory: { tab = .history }, showInsights: { tab = .insights }, showProgress: { tab = .badges })
                .tabItem { Label("Today", systemImage: "timer") }
                .tag(AppTab.today)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.insights)
            // Ayarlar alt sekmede degil, Bugun ekraninin ust cubugunda. Sik
            // acilan bir yer degil; sekmeyi ilerleme icin kullanmak sayfalari
            // daha anlasilir boluyor.
            BadgesView()
                .tabItem { Label("Badges", systemImage: "rosette") }
                .tag(AppTab.badges)
        }
        // Mac'te her gorunum temayi `@AppStorage`'dan kendisi okuyordu.
        // Burada bir kez okunup ortamla asagi iniyor.
        .environment(\.palette, palette)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
        // Oturum degisiklikleri `SessionMirror`'dan gelir; o ekran yokken de
        // calisir. Burada yalnizca uygulama acikken degisen tercihler izlenir.
        .onChange(of: chimeEnabled) { _, _ in updateChimes() }
        .onChange(of: chimeInterval) { _, _ in updateChimes() }
        .onChange(of: chimeSound) { _, _ in updateChimes() }
        .task(id: scenePhase) {
            // Arka plana gecerken hazir kuyrugu silme; uygulama eklerken askiya alinabilir.
            guard scenePhase == .active else { return }
            updateChimes(force: true)
            // On planda uzun oturumlarda da kuyruk bitmesin. Arka planda iOS teslim eder.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
                updateChimes(force: true)
            }
        }
    }

    private func updateChimes(force: Bool = false) {
        FocusChimeController.shared.update(running: store.running, enabled: chimeEnabled,
            interval: chimeInterval, sound: chimeSound, force: force)
    }
}
