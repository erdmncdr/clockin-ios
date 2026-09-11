import SwiftUI

enum AppTab: Hashable {
    case today
    case history
}

struct RootView: View {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var tab: AppTab = .today

    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        TabView(selection: $tab) {
            DashboardView(showHistory: { tab = .history })
                .tabItem { Label("Today", systemImage: "timer") }
                .tag(AppTab.today)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)
        }
        // Mac'te her gorunum temayi `@AppStorage`'dan kendisi okuyordu.
        // Burada bir kez okunup ortamla asagi iniyor.
        .environment(\.palette, palette)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
    }
}
