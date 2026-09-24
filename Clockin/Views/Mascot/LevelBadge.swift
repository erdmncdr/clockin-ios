import SwiftUI
import UIKit

@MainActor
struct DashboardLevelBadge: View {
    @Environment(\.clockinContentActive) private var contentActive
    @Environment(\.scenePhase) private var scenePhase
    @State private var appeared = false
    private var active: Bool { appeared && contentActive && scenePhase == .active }
    let showInsights: () -> Void
    @ObservedObject private var celebrations = CelebrationCenter.shared
    private var level: Int { celebrations.snapshot?.level ?? 1 }
    private var xp: Int { celebrations.snapshot?.xp ?? 0 }

    var body: some View {
        Button(action: showInsights) {
            LevelBadge(level: level, xp: xp, active: active)
                .scaleEffect(0.86)
                .frame(width: 106, height: 44)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Level \(level), \(xp) XP")
        .accessibilityValue("\(500 - xp % 500) XP to next level")
        .accessibilityHint("Opens your level and badges")
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

/// Compact dashboard badge has its own effects: a 5 pt XP track cannot carry
/// the full-size bar's particles legibly. Keep all motion on one 60 fps timeline.
struct LevelBadge: View {
    let level: Int
    let xp: Int
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.clockinContentActive) private var contentActive
    @ObservedObject private var policy = RollingAnimationPolicy.shared
    @State private var visible = false
    @State private var burstBegan: Date?
    private var style: LevelPrestige { .init(level: level) }
    private var progress: Double { LevelPrestige.progress(xp: xp) }
    private var moving: Bool {
        policy.allowsAnimation(reduceMotion: reduceMotion, contentActive: active && contentActive,
                               sceneActive: scenePhase == .active, visible: visible)
    }
    var body: some View {
        HStack(spacing: 9) {
            PrestigeInsignia(style: style)
                .frame(width: 26, height: 28)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("LV")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    // Reserve a three-digit column so short levels don't shift
                    // the LV prefix or first digit toward the right edge.
                    ZStack(alignment: .leading) {
                        Text("888").hidden().accessibilityHidden(true)
                        Text("\(level)")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                }.frame(minWidth: 66, alignment: .center)
                PrestigeGroove(style: style, fraction: progress).frame(width: 66, height: 5)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        // The forged body is drawn once; only the rank's signature layers are
        // redrawn while it moves, one beneath the stone and one above it.
        .background {
            ZStack {
                PrestigeMetalFrame(style: style)
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !moving)) { clock in
                    RankSignature(style: style, layer: .under, time: moving ? clock.date.timeIntervalSinceReferenceDate : nil)
                }
            }
        }
        .overlay {
            ZStack {
                PrestigeFrontOrnaments(style: style)
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !moving)) { clock in
                    ZStack {
                        RankSignature(style: style, layer: .over, time: moving ? clock.date.timeIntervalSinceReferenceDate : nil)
                        if moving, let burstBegan {
                            PrestigeUnlockBurst(style: style, elapsed: clock.date.timeIntervalSince(burstBegan))
                        }
                    }
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .shadow(color: style.tint.opacity(style.index >= 3 ? 0.18 : 0.1), radius: 8, y: 3)
        // Room for what each rank grows past the plate: flares, wings, crown.
        .padding(.vertical, style.stage >= 6 ? 12 : (style.stage == 4 ? 8 : 0))
        .padding(.horizontal, style.stage == 8 ? 18 : (style.stage == 7 ? 10 : (style.stage == 3 ? 6 : 0)))
        .onChange(of: style.index) { old, new in
            burstBegan = new > old && moving ? .now : nil
        }
        .onAppear { visible = true }.onDisappear { visible = false; burstBegan = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level), \(style.name)")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
