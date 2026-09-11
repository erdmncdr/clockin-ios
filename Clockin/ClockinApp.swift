import SwiftUI

@main
struct ClockinApp: App {
    /// Mac'teki `ClockStore`'un kopyasi; veri uygulamanin kendi
    /// Application Support klasorunde duruyor, Mac ile paylasilmiyor.
    @StateObject private var store = ClockStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
