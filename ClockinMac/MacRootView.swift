import SwiftUI

enum MacSection: Hashable {
    case today
    case history
    case progress
}

struct MacRootView: View {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var section: MacSection? = .today
    @State private var progressSection: ProgressSection = .goals
    @State private var goalEditorRequest = false

    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                Label("Today", systemImage: "timer").tag(MacSection.today)
                Label("History", systemImage: "chart.bar.xaxis").tag(MacSection.history)
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis").tag(MacSection.progress)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch section ?? .today {
            case .today:
                DashboardView(isSelected: section == .today, showHistory: { section = .history }, showInsights: {
                    progressSection = .goals
                    section = .progress
                }, setGoals: {
                    goalEditorRequest = true
                    progressSection = .goals
                    section = .progress
                }, showProgress: {
                    progressSection = .badges
                    section = .progress
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
