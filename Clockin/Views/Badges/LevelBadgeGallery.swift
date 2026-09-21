import SwiftUI

struct LevelBadgeGallery: View {
    let currentLevel: Int
    let xp: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var previewVisible = true
    @State private var selection: Int
    init(currentLevel: Int, xp: Int) {
        self.currentLevel = currentLevel; self.xp = xp
        _selection = State(initialValue: LevelPrestige.unlockLevels[LevelPrestige(level: currentLevel).stage])
    }
    private var selected: LevelPrestige { .init(level: selection) }
    private var current: LevelPrestige { .init(level: currentLevel) }
    private var isCurrent: Bool { current.stage == selected.stage }
    private var previewLevel: Int { isCurrent ? currentLevel : selection }
    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
            let viewportHeight = viewport.size.height
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    preview
                        .onGeometryChange(for: Bool.self) { proxy in
                            let rect = proxy.frame(in: .named("rankGallery"))
                            return rect.maxY > 0 && rect.minY < viewportHeight
                        } action: { previewVisible = $0 }
                    Text("Every 75 levels, your badge gains a new design. Tap any rank to preview it.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 155), spacing: 12)], spacing: 12) {
                        ForEach(LevelPrestige.unlockLevels, id: \.self) { level in rankTile(level) }
                    }
                    Text("Eternal is the final design. Your level keeps growing beyond 600.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(16)
            }
            .coordinateSpace(name: "rankGallery")
            }
            .background(palette.background)
            .navigationTitle("Level badges").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .environment(\.clockinContentActive, true)
        .tint(palette.accent).fontDesign(palette.fontDesign).preferredColorScheme(palette.colorScheme)
    }
    private var preview: some View {
        VStack(spacing: 12) {
            LevelBadge(level: previewLevel, xp: isCurrent ? xp : 0, active: previewVisible)
                .scaleEffect(1.5).frame(height: 108).id(selection)
            Text(selected.name).font(.title2.bold())
            Text(isCurrent ? "Your current badge · Level \(currentLevel)" : currentLevel >= selection ? "Unlocked at level \(selection)" : "Unlocks at level \(selection)")
                .font(.subheadline).foregroundStyle(.secondary)
            if currentLevel < selection {
                Text("\(selection - currentLevel) levels to go").font(.caption.weight(.medium)).foregroundStyle(palette.accent)
            }
        }.frame(maxWidth: .infinity).padding(20).card(palette)
        .accessibilityIdentifier("badges.rankPreview")
    }
    private func rankTile(_ level: Int) -> some View {
        let style = LevelPrestige(level: level)
        let unlocked = currentLevel >= level
        return Button {
            selection = level
            Haptics.play(.selection)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // A single animated preview, with static catalog rows for smooth scrolling.
                LevelBadge(level: level, xp: 0, active: false)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .accessibilityHidden(true)
                Text(style.name).font(.subheadline.weight(.semibold))
                Text(level == 600 ? "Level 600+" : "Level \(level)–\(level == 1 ? 74 : level + 74)")
                    .font(.caption).foregroundStyle(.secondary)
                Label(style.stage == current.stage ? "Current" : unlocked ? "Unlocked" : "Locked",
                      systemImage: unlocked ? "checkmark.circle.fill" : "lock")
                    .font(.caption2.weight(.medium)).foregroundStyle(unlocked ? palette.accent : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selection == level ? palette.accent : palette.surfaceStroke, lineWidth: selection == level ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.name), level \(level), \(unlocked ? "unlocked" : "locked")")
        .accessibilityHint("Previews this badge; your level stays the same")
        .accessibilityIdentifier("badges.rank.\(level)")
    }
}
