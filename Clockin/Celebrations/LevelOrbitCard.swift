import SwiftUI

struct LevelOrbitCard: View {
    let level: Int
    let hours: Int
    var xp = 0
    let moving: Bool
    let companionEnabled: Bool
    let dismiss: () -> Void
    let share: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var animationPolicy = RollingAnimationPolicy.shared
    @ScaledMetric(relativeTo: .largeTitle) private var levelFontSize = 48
    @State private var entered = false
    private var style: LevelPrestige { .init(level: level) }
    private var nextStyle: LevelPrestige { .init(level: style.nextUnlock) }
    private var motion: Bool {
        animationPolicy.allowsAnimation(reduceMotion: reduceMotion, contentActive: moving,
                                       sceneActive: scenePhase == .active, visible: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }.scrollBounceBehavior(.basedOnSize)
            }
            actions.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 10)
        }
        .frame(maxWidth: 380)
        .background {
            ZStack {
                Color(red: 0.025, green: 0.036, blue: 0.063)
                RadialGradient(colors: [style.shade.opacity(0.36), .clear], center: .top,
                               startRadius: 0, endRadius: 360)
                LinearGradient(colors: [.white.opacity(0.025), .clear, .black.opacity(0.18)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(LinearGradient(colors: [style.highlight.opacity(0.48), .white.opacity(0.07), style.tint.opacity(0.16)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 24, y: 18)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .onAppear { entered = true }
        .onDisappear { entered = false }
    }

    private var content: some View {
        VStack(spacing: 0) {
            heading.padding(.horizontal, 24).padding(.top, 24)
                .modifier(CelebrationReveal(entered: entered, moving: motion, delay: 0.04))
            LevelOrbitScene(moving: motion, companionEnabled: companionEnabled, level: level)
                .padding(.top, 4)
                .modifier(CelebrationReveal(entered: entered, moving: motion, delay: 0.1))
            earnedBadge.padding(.top, 8)
                .modifier(CelebrationReveal(entered: entered, moving: motion, delay: 0.24))
            nextRank.padding(.horizontal, 28).padding(.top, 18)
                .modifier(CelebrationReveal(entered: entered, moving: motion, delay: 0.3))
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var heading: some View {
        VStack(spacing: 8) {
            Text(style.isMilestone ? "New rank unlocked" : "Level up")
                .font(.subheadline.weight(.medium)).foregroundStyle(style.highlight.opacity(0.85))
            Text("Level \(level)")
                .font(.system(size: levelFontSize, weight: .semibold, design: .rounded))
                .tracking(-1)
                .foregroundStyle(LinearGradient(colors: [.white, style.highlight], startPoint: .top, endPoint: .bottom))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("\(hours.formatted()) \(hours == 1 ? "hour" : "hours") of focus")
                .font(.subheadline).foregroundStyle(.white.opacity(0.55))
        }
    }

    private var earnedBadge: some View {
        VStack(spacing: 10) {
            Text(style.isMilestone ? "\(style.name) unlocked" : style.name)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(style.highlight)
            // The exact dashboard component, using real XP rather than a mock bar.
            LevelBadge(level: level, xp: xp, active: motion)
                .padding(.vertical, style.stage >= 6 ? 0 : 4)
                .accessibilityLabel("Your \(style.name) level badge")
        }
        .padding(.horizontal, 24)
    }

    private var nextRank: some View {
        VStack(spacing: 13) {
            Rectangle().fill(LinearGradient(colors: [.clear, style.highlight.opacity(0.18), .clear],
                                            startPoint: .leading, endPoint: .trailing)).frame(height: 1)
            HStack(spacing: 10) {
                PrestigeInsignia(style: nextStyle).frame(width: 19, height: 22).opacity(0.55)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next look · \(nextStyle.name)").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                    Text("\(style.nextUnlock - level) levels to go").font(.caption2).foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 8)
                Text("LV \(style.nextUnlock)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(nextStyle.highlight.opacity(0.75))
            }.multilineTextAlignment(.leading)
        }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button(action: dismiss) {
                Text("Continue").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(Color(red: 0.025, green: 0.04, blue: 0.07))
                    .background(LinearGradient(colors: [style.highlight, style.tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2), lineWidth: 1))
            }.accessibilityIdentifier("celebration.continue")
            Button(action: share) {
                Label("Share milestone", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.accessibilityIdentifier("celebration.share")
        }.buttonStyle(.plain).buttonPressHaptic(false)
    }
}

private struct CelebrationReveal: ViewModifier {
    let entered: Bool
    let moving: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(entered || !moving ? 1 : 0)
            .offset(y: entered || !moving ? 0 : 7)
            .animation(moving ? .easeOut(duration: 0.5).delay(delay) : nil, value: entered)
    }
}
