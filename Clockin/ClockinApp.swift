import SwiftUI

@main
struct ClockinApp: App {
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

    var body: some Scene {
        WindowGroup {
            RootView()
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
