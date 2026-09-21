import SwiftUI

struct CelebrationOverlay: View {
    @ObservedObject var center: CelebrationCenter
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var animationPolicy = RollingAnimationPolicy.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("Clockin.MascotEnabled") private var companionEnabled = true
    let share: () -> Void
    let openBadges: () -> Void
    let openCompanion: () -> Void

    private var policy: CelebrationPresentation {
        CelebrationPresentation(reduceMotion: !animationPolicy.allowsAnimation(
            reduceMotion: reduceMotion, contentActive: true, sceneActive: scenePhase == .active, visible: true),
            companionEnabled: companionEnabled)
    }

    private var cardTransition: AnyTransition {
        !policy.motion ? .opacity : .scale(scale: 0.96).combined(with: .opacity)
    }

    var body: some View {
        ZStack {
            if let event = center.event, !event.isReaction {
                Color.black.opacity(event.isLevel ? 0.58 : 0.15)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { if !event.isLevel { center.dismiss() } }
                    .accessibilityHidden(true)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))

                Group {
                    switch event {
                    case .levelUp(let level, let hours):
                        LevelOrbitCard(level: level, hours: hours, xp: center.snapshot?.level == level ? (center.snapshot?.xp ?? 0) : 0, moving: policy.motion, companionEnabled: policy.companion,
                                       dismiss: { center.dismiss() }, share: share)
                    case .badge(let badge):
                        banner(title: badge.title, icon: badge.icon)
                    case .accessory(let accessory):
                        banner(title: accessory.name, icon: accessory.symbol, accessory: accessory)
                    case .wardrobe(let name, let introductory):
                        banner(title: name, icon: "tshirt.fill", wardrobeTitle: introductory ? "Wardrobe unlocked" : "New item")
                    case .moreBadges(let ids):
                        banner(title: "and \(ids.count) more", icon: "rosette")
                    case .reaction: EmptyView()
                    }
                }
                .id(center.presentationID)
                .transition(event.isLevel ? cardTransition : .opacity)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { center.dismiss() }
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: center.event)
        .animation(.easeInOut(duration: 0.2), value: center.presentationID)
    }

    private func banner(title: String, icon: String, accessory: CompanionAccessory? = nil, wardrobeTitle: String? = nil) -> some View {
        Button {
            center.dismiss()
            if wardrobeTitle != nil { openCompanion() } else { openBadges() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(wardrobeTitle ?? (accessory == nil ? "Badge unlocked" : "New accessory")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if policy.companion {
                    if let accessory {
                        ClockinMascotStill(mood: .hello, accessory: accessory, outfit: WardrobeStore.shared.state)
                            .frame(width: 48, height: 48)
                    } else {
                        CelebrationMascot(mood: .proud, reaction: .wiggle, moving: policy.motion)
                            .frame(width: 48, height: 48)
                    }
                }
            }
            .padding(16)
            .card(palette, cornerRadius: 20)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .buttonPressHaptic(false)
        .accessibilityHint(wardrobeTitle == nil ? "Opens Badges" : "Opens Companion")
        .padding(.horizontal, 16).padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension CelebrationEvent {
    var isLevel: Bool { if case .levelUp = self { return true }; return false }
}
