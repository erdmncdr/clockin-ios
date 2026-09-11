import SwiftUI

@main
struct ClockinApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// Veri widget ile paylasilan grup klasorunde; Mac ile paylasilmiyor.
    /// Kisayollar da ayni ornegi kullansin diye `SharedStore`'dan gelir.
    @StateObject private var store = SharedStore.clock

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active || phase == .background {
                        SessionMirror.shared.refresh()
                    }
                }
        }
    }
}
