import SwiftUI

@main
struct ClockinApp: App {
    /// Veri widget ile paylasilan grup klasorunde; Mac ile paylasilmiyor.
    /// Kisayollar da ayni ornegi kullansin diye `SharedStore`'dan gelir.
    @StateObject private var store = SharedStore.clock

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
