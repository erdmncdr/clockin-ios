import SwiftUI

enum MacSection: Hashable {
    case today
    case history
    case progress
    case settings
}

struct MacRootView: View {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @ObservedObject private var navigation = MacNavigation.shared
    @State private var progressSection: ProgressSection = .goals
    @State private var goalEditorRequest = false

    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.section) {
                Label("Today", systemImage: "timer").tag(MacSection.today)
                Label("History", systemImage: "chart.bar.xaxis").tag(MacSection.history)
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis").tag(MacSection.progress)
                Label("Settings", systemImage: "gearshape").tag(MacSection.settings)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch navigation.section ?? .today {
            case .today:
                DashboardView(isSelected: navigation.section == .today, showHistory: { navigation.section = .history }, showInsights: {
                    progressSection = .goals
                    navigation.section = .progress
                }, setGoals: {
                    goalEditorRequest = true
                    progressSection = .goals
                    navigation.section = .progress
                }, showProgress: {
                    progressSection = .badges
                    navigation.section = .progress
                })
            case .history:
                HistoryView()
            case .progress:
                ProgressHubView(section: $progressSection, openGoalEditor: $goalEditorRequest)
            case .settings:
                SettingsView()
            }
        }
        .sheet(item: $navigation.sheet) { destination in
            Group {
                switch destination {
                case .manualStart: ManualStartView()
                case .newEntry: ManualEntryView()
                }
            }
            .frame(minWidth: 440, minHeight: 420)
            .environment(\.palette, palette)
            .preferredColorScheme(palette.colorScheme)
        }
        .environment(\.palette, palette)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
    }
}
