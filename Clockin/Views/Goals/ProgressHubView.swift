import SwiftUI

enum ProgressSection: String, CaseIterable, Identifiable {
    case goals = "Goals"
    case reports = "Reports"
    case badges = "Badges"

    var id: Self { self }
}

/// One home for planning, analysis and achievements, with one navigation owner.
struct ProgressHubView: View {
    @Environment(\.palette) private var palette
    @Binding var section: ProgressSection
    @Binding var openGoalEditor: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Progress section", selection: $section) {
                    ForEach(ProgressSection.allCases) { section in
                        Text(LocalizedStringKey(section.rawValue)).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityIdentifier("progress.sections")
                .hapticFeedback(.selection, trigger: section)

                Group {
                    switch section {
                    case .goals: GoalsPaceView(openGoalEditor: $openGoalEditor)
                    case .reports: InsightsView()
                    case .badges: BadgesView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(palette.background)
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
    }
}
