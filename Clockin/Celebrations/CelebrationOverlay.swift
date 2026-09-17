import SwiftUI
import UIKit

struct CelebrationOverlay: View {
    @ObservedObject var center: CelebrationCenter
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("Clockin.MascotEnabled") private var companionEnabled = true
    let share: () -> Void
    let openBadges: () -> Void

    private var policy: CelebrationPresentation {
        CelebrationPresentation(reduceMotion: reduceMotion, companionEnabled: companionEnabled)
    }

    var body: some View {
        if let event = center.event, !event.isReaction {
            CelebrationSurface(reduceMotion: reduceMotion) {
                Group {
                    switch event {
                    case .levelUp(let level, let hours): levelMoment(level: level, hours: hours)
                    case .badge(let badge): banner(title: badge.title, icon: badge.icon)
                    case .moreBadges(let ids): banner(title: "and \(ids.count) more", icon: "rosette")
                    case .reaction: EmptyView()
                    }
                }
                .environment(\.palette, palette)
                .environment(\.colorScheme, palette.colorScheme)
                .fontDesign(palette.fontDesign)
                .tint(palette.accent)
            }
            .id(center.presentationID)
            .frame(maxWidth: .infinity, maxHeight: event.isLevel ? .infinity : nil)
        }
    }

    private func levelMoment(level: Int, hours: Int) -> some View {
        ZStack {
            palette.background.opacity(0.96)
                .onTapGesture { center.dismiss() }
            if policy.confetti { CelebrationConfetti().allowsHitTesting(false) }
            ViewThatFits(in: .vertical) {
                levelContent(level: level, hours: hours, compact: false)
                levelContent(level: level, hours: hours, compact: true)
            }
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { center.dismiss() }
    }

    private func levelContent(level: Int, hours: Int, compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 16) {
            if policy.companion {
                CelebrationMascot(mood: .celebrate, reaction: .cheer, moving: policy.motion)
                    .frame(width: compact ? 80 : 160, height: compact ? 80 : 160)
            }
            Text("LEVEL \(level)")
                .font(.system(size: compact ? 36 : 52, weight: .black, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(1)
                .foregroundStyle(palette.accent)
            Text("\(hours) \(hours == 1 ? "hour" : "hours") of focus")
                .font(.headline).foregroundStyle(.secondary)
            HStack(spacing: 24) {
                Button("Dismiss") { center.dismiss() }
                Button(action: share) { Label("Share", systemImage: "square.and.arrow.up") }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .buttonPressHaptic(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { center.dismiss() }
    }

    private func banner(title: String, icon: String) -> some View {
        Button {
            center.dismiss()
            openBadges()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Badge unlocked").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                if policy.companion {
                    CelebrationMascot(mood: .hello, reaction: .wiggle, moving: policy.motion)
                        .frame(width: 48, height: 48)
                }
            }
            .padding(16)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(palette.surfaceStroke) }
            .padding(.horizontal, 16).padding(.top, 8)
        }
        .buttonStyle(.plain)
        .buttonPressHaptic(false)
        .accessibilityHint("Opens Badges")
    }
}

private extension CelebrationEvent {
    var isLevel: Bool { if case .levelUp = self { return true }; return false }
}

// SwiftUI opacity interpolasyonu yerine hazir katman render sunucusunda solar.
private struct CelebrationSurface<Content: View>: UIViewControllerRepresentable {
    let reduceMotion: Bool
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: content())
        controller.view.backgroundColor = .clear
        if !reduceMotion {
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.08, 0.88, 1]
            fade.duration = 2.5
            // Model opak kalir; UIKit dugmelerin hit-test alanini kapatmaz.
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false
            controller.view.layer.add(fade, forKey: "celebrationFade")
        }
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<Content>, context: Context) {
        controller.rootView = content()
        if reduceMotion {
            controller.view.layer.removeAllAnimations()
            controller.view.layer.opacity = 1
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIHostingController<Content>, context: Context) -> CGSize? {
        uiViewController.sizeThatFits(in: CGSize(width: proposal.width ?? 360, height: proposal.height ?? 1000))
    }

    static func dismantleUIViewController(_ controller: UIHostingController<Content>, coordinator: ()) {
        controller.view.layer.removeAllAnimations()
    }
}
