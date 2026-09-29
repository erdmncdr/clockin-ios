import SwiftUI

@main
struct ClockinMacApp: App {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var languages = LanguageSwitch.shared

    init() { AppLanguage.applyToSystem() }

    @StateObject private var store = SharedStore.clock
    @StateObject private var exchangeRates = SharedStore.exchangeRates

    private var rateDates: [Date] {
        let dates = store.sessions.map(\.start) + (store.running.map { [$0.start] } ?? [])
        return Array(Set(dates.map { ExchangeRateStore.calendarRateDate($0) })).sorted()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MacRootView()
                .id(languages.language)
                .environment(\.locale, AppLanguage.locale)
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
        }
    }
}
