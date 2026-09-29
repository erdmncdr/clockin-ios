import SwiftUI

struct MacRootView: View {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var tab: AppTab? = .today
    @State private var progressSection: ProgressSection = .goals
    @State private var goalEditorRequest = false

    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        NavigationSplitView {
            List(selection: $tab) {
                Label("Today", systemImage: "timer").tag(AppTab.today)
                Label("History", systemImage: "chart.bar.xaxis").tag(AppTab.history)
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis").tag(AppTab.progress)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch tab ?? .today {
            case .today:
                DashboardView(isSelected: tab == .today, showHistory: { tab = .history }, showInsights: {
                    progressSection = .goals
                    tab = .progress
                }, setGoals: {
                    goalEditorRequest = true
                    progressSection = .goals
                    tab = .progress
                }, showProgress: {
                    progressSection = .badges
                    tab = .progress
                })
            case .history:
                HistoryView()
            case .progress:
                ProgressHubView(section: $progressSection, openGoalEditor: $goalEditorRequest)
            }
        }
        .environment(\.palette, palette)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
    }
}
