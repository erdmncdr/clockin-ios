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
        .background { PrestigeMetalFrame(style: style) }
        .overlay {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !moving)) { clock in
                ZStack {
                    BadgeSheen(style: style, time: moving ? clock.date.timeIntervalSinceReferenceDate : nil)
                    if moving, let burstBegan {
                        PrestigeUnlockBurst(style: style, elapsed: clock.date.timeIntervalSince(burstBegan))
                    }
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .shadow(color: style.tint.opacity(style.index >= 3 ? 0.18 : 0.1), radius: 8, y: 3)
        .padding(.vertical, style.stage >= 6 ? 12 : 0)
        .onChange(of: style.index) { old, new in
            burstBegan = new > old && moving ? .now : nil
        }
        .onAppear { visible = true }.onDisappear { visible = false; burstBegan = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level), \(style.name)")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// The only motion on the badge: a band of light that crosses the metal every
/// few seconds, and a glint that blooms on the gem as it passes. Still when
/// motion is off; the forged body carries the rank on its own.
private struct BadgeSheen: View {
    let style: LevelPrestige
    let time: Double?
    private static let period = 6.0, sweep = 1.3

    var body: some View {
        Canvas { context, size in
            #if DEBUG
            if let time { LevelFrameDiagnostics.record(time) }
            #endif
            guard let time else { return }
            let t = (time + Double(style.stage) * 0.4).truncatingRemainder(dividingBy: Self.period)
            let body = PrestigePlate(stage: style.stage).path(in: CGRect(origin: .zero, size: size))
            if t < Self.sweep {
                let u = t / Self.sweep
                let x = -size.height + u * (size.width + size.height * 2)
                var band = Path()
                band.addLines([CGPoint(x: x, y: size.height), CGPoint(x: x + size.height * 0.55, y: 0),
                               CGPoint(x: x + size.height * 0.95, y: 0), CGPoint(x: x + size.height * 0.4, y: size.height)])
                band.closeSubpath()
                context.drawLayer { layer in
                    layer.clip(to: body)
                    layer.addFilter(.blur(radius: 3))
                    layer.fill(band, with: .color(.white.opacity(0.16 * sin(u * .pi))))
                }
            }
            // The glint follows the sweep across the gem at its left end.
            let gemTime = t - Self.sweep * 0.2
            let bloom = gemTime > 0 && gemTime < 0.9 ? sin(gemTime / 0.9 * .pi) : 0
            PrestigeGem.glint(&context, at: CGPoint(x: 19.5, y: size.height / 2 - 6), size: 5, opacity: bloom * 0.95)
        }
    }
}
