import SwiftUI

@main
struct ClockinApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// Veri widget ile paylasilan grup klasorunde; Mac ile paylasilmiyor.
    /// Kisayollar da ayni ornegi kullansin diye `SharedStore`'dan gelir.
    @StateObject private var store = SharedStore.clock
    @StateObject private var exchangeRates = SharedStore.exchangeRates

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(exchangeRates)
                .task(id: store.sessions.count) {
                    await exchangeRates.refresh(sessionDates: store.sessions.map(\.start))
                    guard !Task.isCancelled, !exchangeRates.liveCheckFailed,
                          exchangeRates.latestRate != nil else { return }
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
