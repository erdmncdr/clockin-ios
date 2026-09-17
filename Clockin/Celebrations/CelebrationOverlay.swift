import SwiftUI

struct CelebrationOverlay: View {
    @ObservedObject var center: CelebrationCenter
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("Clockin.MascotEnabled") private var companionEnabled = true
    @ScaledMetric(relativeTo: .largeTitle) private var levelFontSize = 44
    let share: () -> Void
    let openBadges: () -> Void

    private var policy: CelebrationPresentation {
        CelebrationPresentation(reduceMotion: reduceMotion, companionEnabled: companionEnabled)
    }

    private var cardTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity)
    }

    var body: some View {
        ZStack {
            if let event = center.event, !event.isReaction {
                Color.black.opacity(event.isLevel ? 0.45 : 0.15)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { center.dismiss() }
                    .accessibilityHidden(true)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))

                Group {
                    switch event {
                    case .levelUp(let level, let hours):
                        levelMoment(level: level, hours: hours)
                    case .badge(let badge):
                        banner(title: badge.title, icon: badge.icon)
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

    private func levelMoment(level: Int, hours: Int) -> some View {
        ViewThatFits(in: .vertical) {
            levelContent(level: level, hours: hours)
            // Buyuk metin ve yatay ekranda kartin tamami erisilebilir kalir.
            ScrollView {
                levelContent(level: level, hours: hours)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: 440)
        .background {
            if policy.confetti {
                CelebrationConfetti()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .card(palette, cornerRadius: 24)
        .background(palette.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { center.dismiss() }
        .padding(16)
    }

    private func levelContent(level: Int, hours: Int) -> some View {
        VStack(spacing: 20) {
            if policy.companion {
                CelebrationMascot(mood: .celebrate, reaction: .cheer, moving: policy.motion)
                    .frame(width: 120, height: 120)
                    // Ziplama da kartin icinde kalir.
                    .padding(.top, policy.motion ? 72 : 0)
            }
            Text("LEVEL \(level)")
                .font(.system(size: levelFontSize, weight: .black, design: .rounded))
                .foregroundStyle(palette.accent)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(hours) \(hours == 1 ? "hour" : "hours") of focus")
                .font(.headline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: 12) {
                Button(action: { center.dismiss() }) {
                    actionLabel("Dismiss")
                }
                Button(action: share) {
                    actionLabel("Share")
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .buttonPressHaptic(false)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44)
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
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if policy.companion {
                    CelebrationMascot(mood: .hello, reaction: .wiggle, moving: policy.motion)
                        .frame(width: 48, height: 48)
                }
            }
            .padding(16)
            .card(palette, cornerRadius: 20)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .buttonPressHaptic(false)
        .accessibilityHint("Opens Badges")
        .padding(.horizontal, 16).padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension CelebrationEvent {
    var isLevel: Bool { if case .levelUp = self { return true }; return false }
}
