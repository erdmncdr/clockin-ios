import SwiftUI

extension BadgeTier {
    var tint: Color {
        switch self {
        case .launch: Color(red:0.28,green:0.81,blue:0.64)
        case .orbit: Color(red:0.22,green:0.70,blue:0.95)
        case .lunar: Color(red:0.64,green:0.58,blue:0.98)
        case .solar: Color(red:1,green:0.65,blue:0.25)
        case .galactic: Color(red:0.95,green:0.37,blue:0.70)
        case .eternal: Color(red:0.90,green:0.83,blue:0.61)
        }
    }
    var highlight: Color { self == .eternal ? .white : tint.opacity(0.65) }
    /// The medal metal for this tier; Eternal is a pale champagne gold.
    var tone: ForgeTone {
        switch self {
        case .launch: ForgeTone(hue: 0.45)
        case .orbit: ForgeTone(hue: 0.56)
        case .lunar: ForgeTone(hue: 0.69)
        case .solar: ForgeTone(hue: 0.09)
        case .galactic: ForgeTone(hue: 0.91)
        case .eternal: ForgeTone(hue: 0.12, saturation: 0.45)
        }
    }
}

/// A round medal cast in the same metal as the rank badge: a beveled ring
/// that grows richer with the tier, a recessed enamel face, the emblem raised
/// out of it, and the tier's stone set into the foot of the ring. Locked
/// medals are plain steel with the emblem engraved instead of raised.
struct ForgedMedal: View {
    let emblem: CGPath
    let tier: BadgeTier
    var lit = true
    var phase: Double = 0
    var mission: BadgeMission?
    var continuous = false
    var motionVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var still: Bool { reduceMotion || lowPower || scenePhase != .active }

    var body: some View {
        ForgedMedalBody(tier: tier, lit: lit)
            .equatable()
            .overlay {
                MedalEmblem(emblem: emblem, tier: tier, lit: lit, mission: mission,
                            phase: lit && !still ? phase : 1)
            }
            .background {
                if lit && tier == .solar { signature }
            }
            .overlay {
                if lit && tier != .solar { signature }
            }
            .transaction { if still { $0.animation = nil } }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private var signature: some View {
        MedalSignature(tier: tier, phase: phase, continuous: continuous,
                       still: still, motionVisible: motionVisible)
    }
}

private struct ForgedMedalBody: View, Equatable {
    let tier: BadgeTier
    let lit: Bool

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let tone = lit ? tier.tone : ForgeTone(hue: tier.tone.hue, saturation: 0.1, brightness: 0.42)
            let level = tier.rawValue
            let radius = s * 0.44
            // Enough faces that the ring reads as turned metal at any size.
            let segments = Int(max(72, min(240, s * 1.3)))
            func circle(_ r: CGFloat) -> [CGPoint] {
                (0..<segments).map { i in
                    let a = Double(i) / Double(segments) * .pi * 2 - .pi / 2
                    return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                }
            }

            // Contact shadow beneath the whole medal.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: s * 0.03))
                layer.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius + s * 0.025, width: radius * 2, height: radius * 2)),
                           with: .color(.black.opacity(0.6)))
            }

            var r0 = radius
            if tier == .eternal {
                // A separate thin outer ring, set off by a dark channel.
                let band = circle(radius), bandInner = circle(radius - s * 0.03)
                PrestigeBevel.band(&context, outer: band, inner: bandInner, style: tone)
                context.stroke(PrestigeOutline.path(band), with: .color(.black.opacity(0.5)), lineWidth: 0.6)
                PrestigeBevel.glint(&context, band, inset: 0.5)
                context.fill(PrestigeOutline.path(circle(radius - s * 0.03)), with: .color(.black.opacity(0.7)))
                r0 = radius - s * 0.05
            }
            let outer = circle(r0)
            let rim = s * (level >= 3 ? 0.1 : 0.085)
            let fr = r0 - rim
            let inner = circle(fr)
            if level >= 3 {
                let mid = circle(r0 - rim * 0.55)
                PrestigeBevel.band(&context, outer: outer, inner: mid, style: tone)
                PrestigeBevel.band(&context, outer: mid, inner: inner, style: tone, sloping: true)
            } else {
                PrestigeBevel.band(&context, outer: outer, inner: inner, style: tone)
            }

            // Recessed enamel face and the shadow of the ring falling into it.
            let face = PrestigeOutline.path(inner)
            context.fill(face, with: .linearGradient(Gradient(colors: [tone.faceTop, tone.faceBottom]),
                                                     startPoint: CGPoint(x: c.x, y: c.y - fr), endPoint: CGPoint(x: c.x, y: c.y + fr)))
            if lit {
                context.fill(face, with: .radialGradient(Gradient(colors: [tone.tint.opacity(0.26), .clear]),
                                                         center: CGPoint(x: c.x, y: c.y - fr * 0.2), startRadius: 0, endRadius: fr))
            }
            context.drawLayer { layer in
                layer.clip(to: face)
                layer.addFilter(.blur(radius: s * 0.02))
                layer.stroke(face.offsetBy(dx: 0, dy: s * 0.018), with: .color(.black.opacity(0.75)), lineWidth: s * 0.05)
            }
            if level == 2 || level >= 4 {
                // An engraved line a little inside the ring.
                let groove = PrestigeOutline.path(circle(fr - s * 0.035))
                context.stroke(groove, with: .color(.black.opacity(0.5)), lineWidth: max(0.6, s * 0.008))
                context.stroke(groove.offsetBy(dx: 0, dy: max(0.4, s * 0.005)), with: .color(tone.tint.opacity(0.14)),
                               lineWidth: max(0.4, s * 0.005))
            }

            context.stroke(PrestigeOutline.path(outer), with: .color(.black.opacity(0.55)), lineWidth: max(0.6, s * 0.006))
            PrestigeBevel.glint(&context, outer, inset: max(0.5, s * 0.005), strength: lit ? 1 : 0.3)

            // The tier's stone, set into the foot of the ring.
            let g = s * 0.17
            let seat = CGPoint(x: c.x, y: c.y + r0 - rim * 0.5)
            let setting = Path(ellipseIn: CGRect(x: seat.x - g * 0.62, y: seat.y - g * 0.62, width: g * 1.24, height: g * 1.24))
            context.fill(setting, with: .radialGradient(Gradient(colors: [tone.metal(0.35), tone.metal(0.12)]),
                                                        center: seat, startRadius: 0, endRadius: g * 0.62))
            context.stroke(setting, with: .linearGradient(Gradient(colors: [tone.metal(0.95), tone.metal(0.3)]),
                                                          startPoint: CGPoint(x: seat.x, y: seat.y - g * 0.62),
                                                          endPoint: CGPoint(x: seat.x, y: seat.y + g * 0.62)),
                           lineWidth: max(0.6, s * 0.01))
            PrestigeGem.draw(&context, in: CGRect(x: seat.x - g / 2, y: seat.y - g / 2, width: g, height: g),
                             style: tone, detail: s > 60)
        }
    }
}

/// A mission badge: its family's emblem on its tier's medal.
struct SpaceBadgeSeal: View {
    let badge: InsightsBadge
    let size: CGFloat
    var phase = 0.0
    var preview = false
    var continuous = false
    var motionVisible = true
    var body: some View {
        ForgedMedal(emblem: SpaceBadgeGeometry.mission(badge.mission.rawValue), tier: badge.tier,
                    lit: badge.unlocked || preview, phase: phase, mission: badge.mission,
                    continuous: continuous, motionVisible: motionVisible)
            .frame(width: size, height: size)
    }
}

/// A tier's own medal, for the tier picker and header.
struct TierMedal: View {
    let tier: BadgeTier
    var dimmed = false
    var phase = 0.0
    var body: some View {
        ForgedMedal(emblem: SpaceBadgeGeometry.insignia(tier.rawValue), tier: tier, lit: true, phase: phase)
            .opacity(dimmed ? 0.55 : 1)
    }
}
