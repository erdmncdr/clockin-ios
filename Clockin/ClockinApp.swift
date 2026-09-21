import SwiftUI

@main
struct ClockinApp: App {
    @UIApplicationDelegateAdaptor(ClockinAppDelegate.self) private var appDelegate
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @Environment(\.scenePhase) private var scenePhase

    /// Veri widget ile paylasilan grup klasorunde; Mac ile paylasilmiyor.
    /// Kisayollar da ayni ornegi kullansin diye `SharedStore`'dan gelir.
    @StateObject private var store = SharedStore.clock
    @StateObject private var exchangeRates = SharedStore.exchangeRates

    private var rateDates: [Date] {
        let dates = store.sessions.map(\.start) + (store.running.map { [$0.start] } ?? [])
        return Array(Set(dates.map { ExchangeRateStore.calendarRateDate($0) })).sorted()
    }

    @ViewBuilder
    private var entryView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--feedback-review") {
            LevelFeedbackReview()
        } else if ProcessInfo.processInfo.arguments.contains("--level-effects-preview") {
            LevelEffectsPreview()
        } else { RootView() }
        #else
        RootView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            entryView
                .liveActivitySetup()
                .timerPersistenceAlert()
                .environmentObject(store)
                .environmentObject(exchangeRates)
                .task(id: rateDates) {
                    await exchangeRates.refresh(sessionDates: rateDates)
                    guard !Task.isCancelled, !exchangeRates.liveCheckFailed,
                          exchangeRates.latestRate != nil else { return }
                    SessionMirror.shared.refresh()
                }
                .onChange(of: themeRaw) { _, _ in
                    SessionMirror.shared.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active || phase == .background {
                        SessionMirror.shared.refresh()
                    }
                }
        }
    }
}
