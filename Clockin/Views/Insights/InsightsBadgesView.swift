import SwiftUI

@MainActor
struct InsightsBadgesView: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let badges: [InsightsBadge]
    @State private var selectedBadge: InsightsBadge?

    var body: some View {
        let unlocked = badges.filter(\.unlocked)
        let locked = badges.filter { !$0.unlocked }
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("BADGES")
            Text("\(unlocked.count) of \(badges.count) unlocked")
                .font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: Double(unlocked.count), total: Double(max(badges.count, 1)))
                .tint(palette.accent)
            // Kendi sekmesinde oldugu icin rozetler adlariyla gorunur; acilanlar
            // ve kilitliler ayri gruplarda, boylece hangisinin sirada oldugu
            // karisik bir izgarada aranmaz.
            if !unlocked.isEmpty { group("Unlocked", unlocked) }
            if !locked.isEmpty { group("Still to unlock", locked) }
            Text("Tap a badge for its requirement and progress. Current-streak badges lock again when a streak ends.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
        .hapticFeedback(.selection, trigger: selectedBadge?.id) { _, new in new != nil }
        .transaction { if reduceMotion { $0.animation = nil } }
        .sheet(item: $selectedBadge) { selected in
            InsightsBadgeDetail(badge: badges.first { $0.id == selected.id } ?? selected)
        }
    }
    private func group(_ title: String, _ items: [InsightsBadge]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) · \(items.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(items) { badge in
                    Button { selectedBadge = badge } label: {
                        VStack(spacing: 6) {
                            Image(systemName: badge.icon)
                                .font(.title3)
                                .frame(height: 26)
                            Text(badge.title)
                                .font(.caption2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(badge.unlocked ? palette.accent : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(badge.unlocked ? palette.accent.opacity(0.12) : palette.surface)
                        )
                        .opacity(badge.unlocked ? 1 : 0.6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .buttonPressHaptic(false)
                    .accessibilityLabel(badge.title)
                    .accessibilityValue(badge.unlocked ? "Unlocked" : "Locked")
                    .accessibilityHint("Opens requirement and current progress")
                }
            }
        }
    }
}

@MainActor
private struct InsightsBadgeDetail: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let badge: InsightsBadge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(badge.title, systemImage: badge.icon).font(.title2.bold())
                        .foregroundStyle(badge.unlocked ? palette.accent : Color.secondary)
                        // Acilmis rozet sayfa acilinca bir kez sekip dikkat ceker;
                        // kilitli olan hareketsiz kalir, kutlanacak bir sey yok.
                        .symbolEffect(.bounce, value: appeared && badge.unlocked && !reduceMotion)
                    Label(badge.unlocked ? "Unlocked" : "Locked",
                          systemImage: badge.unlocked ? "checkmark.seal.fill" : "lock.fill")
                        .font(.headline)
                        .foregroundStyle(badge.unlocked ? palette.accent : Color.secondary)
                    SectionTitle("REQUIREMENT")
                    Text(badge.requirement)
                    SectionTitle("CURRENT PROGRESS")
                    Text(badge.progress).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(palette.background)
            .navigationTitle("Badge details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .presentationDetents([.medium, .large])
        .task { appeared = true }
    }
}
