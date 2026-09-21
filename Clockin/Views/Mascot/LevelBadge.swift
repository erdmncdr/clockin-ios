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
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.5))
                    Capsule().fill(LinearGradient(colors: [style.tint, style.highlight], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 66 * progress)
                        .shadow(color: style.tint.opacity(0.65), radius: 3)
                }.frame(width: 66, height: 5)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(LinearGradient(colors: [style.shade.opacity(0.8), Color(red: 0.025, green: 0.04, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: PrestigePlate(stage: style.stage))
        .overlay(PrestigePlate(stage: style.stage).stroke(style.tint.opacity(0.6), lineWidth: 1))
        .overlay { PrestigeMetalFrame(style: style) }
        .overlay {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !moving)) { clock in
                ZStack {
                    BadgeRankEffects(style: style, progress: progress, time: moving ? clock.date.timeIntervalSinceReferenceDate : 2)
                    if moving, let burstBegan {
                        PrestigeUnlockBurst(style: style, elapsed: clock.date.timeIntervalSince(burstBegan))
                    }
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .shadow(color: style.tint.opacity(style.index >= 3 ? 0.24 : 0.12), radius: 7, y: 2)
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

private struct BadgeRankEffects: View {
    let style: LevelPrestige
    let progress: Double
    let time: Double

    var body: some View {
        Canvas { original, fullSize in
            #if DEBUG
            LevelFrameDiagnostics.record(time)
            #endif
            var context = original
            context.translateBy(x: 16, y: 16)
            let size = CGSize(width: fullSize.width - 32, height: fullSize.height - 32)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let rim = BadgeOrbitGeometry(size: size, stage: style.stage)
            let center = CGPoint(x: 23, y: size.height / 2)
            let phase = (time / 5).truncatingRemainder(dividingBy: 1)
            if style.stage >= 2 {
                // All core effects stay inside the inset frame.
                context.clip(to: PrestigePlate(stage: style.stage).path(in: rect.insetBy(dx: 0.5, dy: 0.5)))
            }
            // Readable perimeter comet, also present in the starting tier.
            let count = style.stage >= 4 ? 2 : 1
            for comet in 0..<count {
                let lead = phase + Double(comet) / Double(count)
                for step in (0..<32).reversed() {
                    let fraction = (lead - Double(step) * 0.005 + 1).truncatingRemainder(dividingBy: 1)
                    let point = rim.point(at: fraction)
                    let strength = 1 - Double(step) / 32
                    let radius = step == 0 ? 2.1 : 1.3
                    dot(&context, at: point, radius: radius, color: style.highlight.opacity(strength * 0.9))
                    if step == 0 { star(&context, at: point, radius: 3.5, opacity: 0.95) }
                }
            }
            switch style.stage {
            case 0:
                // Spark: a broad traveling glint beneath the XP track.
                let x = 45 + phase * 66 * progress
                if progress > 0 { dot(&context, at: CGPoint(x: x, y: size.height - 9), radius: 2, color: style.highlight.opacity(0.8)) }
            case 1:
                // Orbit: tilted planetary ring around the rank emblem.
                var orbit = context
                orbit.translateBy(x: center.x, y: center.y)
                orbit.rotate(by: .degrees(-28))
                orbit.stroke(Path(ellipseIn: CGRect(x: -18, y: -7, width: 36, height: 14)), with: .color(style.tint.opacity(0.75)), lineWidth: 1)
                let angle = time * 1.6
                dot(&orbit, at: CGPoint(x: cos(angle) * 18, y: sin(angle) * 7), radius: 2, color: .white)
            case 2:
                // Nebula: drifting star cluster on the left crest.
                for i in 0..<6 {
                    let angle = Double(i) * .pi / 3 + time * 0.2
                    let r = min(16.0, size.height / 2 - 6) + sin(time + Double(i))
                    star(&context, at: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r), radius: i % 2 == 0 ? 3 : 1.8, opacity: 0.5 + 0.4 * abs(sin(time + Double(i))))
                }
            case 3:
                // Solar: rotating radial crown with a slow breathing halo.
                for i in 0..<12 {
                    let angle = Double(i) * .pi / 6 + time * 0.16
                    let inner = min(13.0, size.height / 2 - 8)
                    let outer = inner + 3 + sin(time * 1.4 + Double(i))
                    var ray = Path()
                    ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                    ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                    context.stroke(ray, with: .color(style.highlight.opacity(0.8)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                }
            case 4:
                // Nova: two orbiting four-point stars and a double comet rim.
                for i in 0..<2 {
                    let angle = time * 0.9 + Double(i) * .pi
                    star(&context, at: CGPoint(x: center.x + cos(angle) * 17, y: center.y + sin(angle) * 16), radius: 4.5, opacity: 0.95)
                }
            case 5:
                // Aurora takes the twin orbiting lights previously used by Sovereign.
                let r = 14.5
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .color(style.highlight.opacity(0.27)), lineWidth: 0.8)
                for i in 0..<2 {
                    let a = time * 0.45 + Double(i) * .pi
                    star(&context, at: CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r), radius: 1.8, opacity: 0.85)
                }
            default:
                // Sovereign takes Aurora's two soft arcs, tucked toward the crystal.
                let r = 14.5
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .color(style.tint.opacity(0.14)), lineWidth: 2)
                for arc in 0..<2 {
                    let angle = time * 0.3 + Double(arc) * .pi
                    var light = Path()
                    light.addArc(center: center, radius: r, startAngle: .radians(angle), endAngle: .radians(angle + 0.85), clockwise: false)
                    context.stroke(light, with: .color(style.tint.opacity(0.18)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    context.stroke(light, with: .color(style.highlight.opacity(0.9)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                }

            }
        }.padding(-16)
    }

    private func dot(_ context: inout GraphicsContext, at p: CGPoint, radius: Double, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }

    private func star(_ context: inout GraphicsContext, at p: CGPoint, radius: Double, opacity: Double) {
        var path = Path()
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let r = i.isMultiple(of: 2) ? radius : radius * 0.25
            let point = CGPoint(x: p.x + cos(angle) * r, y: p.y + sin(angle) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(style.highlight.opacity(opacity)))
    }
}
