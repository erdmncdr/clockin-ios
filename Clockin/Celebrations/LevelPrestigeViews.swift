import SwiftUI

extension LevelPrestige {
    var tint: Color { Color(hue: hue, saturation: 0.62, brightness: 0.96) }
    var highlight: Color { Color(hue: hue, saturation: 0.18, brightness: 1) }
    var shade: Color { Color(hue: hue, saturation: 0.75, brightness: 0.43) }
}

/// Shared by the dashboard, Badges and the level-up card: a groove cut into
/// the surface with a glossy fill, lit from the same side as the badge.
struct PrestigeProgressBar: View {
    let level: Int
    let progress: Double
    var active = true
    var height: CGFloat = 14
    private var style: LevelPrestige { .init(level: level) }
    private var fraction: Double { progress.isFinite ? min(1, max(0, progress)) : 0 }

    var body: some View {
        GeometryReader { geometry in
            PrestigeGroove(style: style, fraction: fraction)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress to next level")
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

/// The recessed track and its fill, used at every size.
struct PrestigeGroove: View {
    let style: LevelPrestige
    let fraction: Double
    var body: some View {
        Canvas { context, size in
            let h = size.height, track = CGRect(origin: .zero, size: size)
            let groove = Path(roundedRect: track, cornerRadius: h / 2)
            context.fill(groove, with: .linearGradient(Gradient(colors: [.black.opacity(0.75), style.faceBottom.opacity(0.9)]),
                                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            // Shadow thrown by the upper lip of the groove.
            context.drawLayer { layer in
                layer.clip(to: groove)
                layer.addFilter(.blur(radius: max(0.6, h * 0.18)))
                layer.stroke(groove.offsetBy(dx: 0, dy: h * 0.18), with: .color(.black.opacity(0.8)), lineWidth: max(1, h * 0.3))
            }
            let width = size.width * fraction
            if width > 0.5 {
                let fill = Path(roundedRect: CGRect(x: 0, y: 0, width: max(width, h), height: h).insetBy(dx: 0.5, dy: 0.5),
                                cornerRadius: h / 2)
                context.drawLayer { layer in
                    layer.clip(to: groove)
                    layer.fill(fill, with: .linearGradient(Gradient(colors: [style.gemTone(0.95), style.gemTone(0.62), style.gemTone(0.42)]),
                                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                    // Gloss on the upper half, as on a rounded glass rod.
                    let gloss = Path(roundedRect: CGRect(x: h * 0.3, y: h * 0.12, width: max(0, max(width, h) - h * 0.6), height: h * 0.34),
                                     cornerRadius: h * 0.17)
                    layer.fill(gloss, with: .color(.white.opacity(0.42)))
                }
            }
            // Lower lip catches the light.
            var lip = Path()
            lip.move(to: CGPoint(x: h / 2, y: h - 0.4)); lip.addLine(to: CGPoint(x: size.width - h / 2, y: h - 0.4))
            context.stroke(lip, with: .color(.white.opacity(0.14)), lineWidth: 0.6)
        }
    }
}

/// The badge body's silhouette, for backgrounds and hit areas.
struct PrestigePlate: Shape {
    let stage: Int
    func path(in r: CGRect) -> Path { PrestigeOutline.path(PrestigeOutline.plate(stage: stage, in: r)) }
}

/// The forged body behind the badge content: beveled metal rim, recessed
/// face, and the ornaments each rank earns. Ranks add structure, never loose
/// decoration, and all of it is lit from the same side.
struct PrestigeMetalFrame: View {
    let style: LevelPrestige
    private static let margin: CGFloat = 22

    var body: some View {
        Canvas { original, fullSize in
            var context = original
            context.translateBy(x: Self.margin, y: Self.margin)
            let size = CGSize(width: fullSize.width - Self.margin * 2, height: fullSize.height - Self.margin * 2)
            Self.draw(&context, size: size, style: style)
        }
        .padding(-Self.margin).allowsHitTesting(false).accessibilityHidden(true)
    }

    static func rimWidth(_ stage: Int) -> CGFloat { stage == 0 ? 2.4 : (stage >= 4 ? 3.6 : 3) }

    static func draw(_ context: inout GraphicsContext, size: CGSize, style: LevelPrestige) {
        let stage = style.stage
        let outer = PrestigeOutline.plate(stage: stage, in: CGRect(origin: .zero, size: size))
        let rim = rimWidth(stage)
        let inner = PrestigeOutline.inset(outer, by: rim)
        let face = PrestigeOutline.path(inner)

        // Soft contact shadow under the whole piece.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            layer.fill(PrestigeOutline.path(outer).offsetBy(dx: 0, dy: 1.5), with: .color(.black.opacity(0.55)))
        }
        if stage >= 6 { crest(&context, size: size, style: style, arch: stage >= 7) }

        // Rim: one face per edge; the higher ranks cut it into two tiers.
        if stage >= 4 {
            let mid = PrestigeOutline.inset(outer, by: rim * 0.55)
            PrestigeBevel.band(&context, outer: outer, inner: mid, style: style.tone)
            PrestigeBevel.band(&context, outer: mid, inner: inner, style: style.tone, sloping: true)
        } else {
            PrestigeBevel.band(&context, outer: outer, inner: inner, style: style.tone)
        }

        // Recessed face with the shadow of the upper rim falling into it.
        let top = inner.map(\.y).min() ?? 0, bottom = inner.map(\.y).max() ?? size.height
        context.fill(face, with: .linearGradient(Gradient(colors: [style.faceTop, style.faceBottom]),
                                                 startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
        context.fill(face, with: .radialGradient(Gradient(colors: [style.tint.opacity(0.22), .clear]),
                                                 center: CGPoint(x: 23, y: size.height / 2), startRadius: 0, endRadius: size.height * 0.75))
        context.drawLayer { layer in
            layer.clip(to: face)
            layer.addFilter(.blur(radius: 2.2))
            layer.stroke(face.offsetBy(dx: 0, dy: 1.8), with: .color(.black.opacity(0.75)), lineWidth: 4)
        }
        if stage >= 2 {
            // Double rim: a fine engraved line a little inside the face.
            let groove = PrestigeOutline.path(PrestigeOutline.inset(inner, by: 2.4))
            context.stroke(groove, with: .color(.black.opacity(0.55)), lineWidth: 0.8)
            context.stroke(groove.offsetBy(dx: 0, dy: 0.6), with: .color(style.highlight.opacity(0.16)), lineWidth: 0.5)
        }
        // Silhouette and the light catching the rim's upper edges.
        context.stroke(PrestigeOutline.path(outer), with: .color(.black.opacity(0.55)), lineWidth: 0.7)
        PrestigeBevel.glint(&context, outer, inset: 0.55)
        if stage >= 8 {
            let seal = PrestigeOutline.seal(centerX: size.width / 2, bottom: size.height, width: 16, height: 10)
            PrestigeBevel.ornament(&context, outline: seal, style: style.tone)
        }
    }

    private static func crest(_ context: inout GraphicsContext, size: CGSize, style: LevelPrestige, arch: Bool) {
        let x = size.width / 2
        if arch {
            // Celestial arch: a beveled band springing from the crest's shoulders.
            var band = Path()
            band.move(to: CGPoint(x: size.width * 0.2, y: 1))
            band.addQuadCurve(to: CGPoint(x: size.width * 0.8, y: 1), control: CGPoint(x: x, y: -20))
            context.stroke(band.offsetBy(dx: 0, dy: 1), with: .color(.black.opacity(0.5)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            context.stroke(band, with: .linearGradient(Gradient(colors: [style.metal(0.95), style.metal(0.55), style.metal(0.3)]),
                                                      startPoint: CGPoint(x: x, y: -12), endPoint: CGPoint(x: x, y: 2)),
                           style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            context.stroke(band.offsetBy(dx: 0, dy: -0.7), with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }
        PrestigeBevel.ornament(&context, outline: PrestigeOutline.crest(centerX: x, top: 0, width: 34, height: 16), style: style.tone)
    }
}

/// The rank's gem, set in a socket cut into the face. Rank is carried by the
/// metalwork around it, not by a second label competing with the level.
struct PrestigeInsignia: View {
    let style: LevelPrestige
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let socket = CGRect(x: c.x - side / 2 + 0.5, y: c.y - side / 2 + 0.5, width: side - 1, height: side - 1)
            let well = Path(ellipseIn: socket)
            context.fill(well, with: .radialGradient(Gradient(colors: [style.tint.opacity(0.55), style.tint.opacity(0.12), style.faceBottom.opacity(0.9)]),
                                                     center: CGPoint(x: c.x, y: c.y - side * 0.04), startRadius: 0, endRadius: side / 2))
            context.drawLayer { layer in
                layer.clip(to: well)
                layer.addFilter(.blur(radius: 1.4))
                layer.stroke(well.offsetBy(dx: 0, dy: 1.2), with: .color(.black.opacity(0.8)), lineWidth: 2.4)
            }
            if style.stage >= 5 {
                // Satin halo: a thin polished ring around the socket.
                let ring = Path(ellipseIn: socket)
                context.stroke(ring, with: .linearGradient(Gradient(colors: [style.metal(0.98), style.metal(0.45), style.metal(0.2), style.metal(0.6)]),
                                                           startPoint: CGPoint(x: socket.minX, y: socket.minY), endPoint: CGPoint(x: socket.maxX, y: socket.maxY)),
                               lineWidth: 1.3)
            } else {
                // The socket's lower lip catches the light; its upper lip is in shadow.
                context.stroke(well, with: .linearGradient(Gradient(colors: [.black.opacity(0.7), style.metal(0.75).opacity(0.7)]),
                                                           startPoint: CGPoint(x: c.x, y: socket.minY), endPoint: CGPoint(x: c.x, y: socket.maxY)),
                               lineWidth: 0.9)
            }
            let g = side * (style.stage >= 4 ? 0.9 : 0.84)
            PrestigeGem.draw(&context, in: CGRect(x: c.x - g / 2, y: c.y - g / 2 - side * 0.03, width: g, height: g), style: style.tone)
        }.accessibilityHidden(true)
    }
}

/// Brief, bounded unlock event. No full-screen flash, no looping explosion.
struct PrestigeUnlockBurst: View {
    let style: LevelPrestige
    let elapsed: Double
    var body: some View {
        Canvas { context, size in
            guard elapsed >= 0, elapsed < 2.4 else { return }
            let progress = min(1, elapsed / 2.4)
            let fade = pow(1 - progress, 2)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = 18 + (1 - pow(1 - progress, 3)) * min(size.width * 0.48, 160)
            for ring in 0..<(style.stage >= 4 ? 2 : 1) {
                let r = max(0, radius - Double(ring) * 14)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(style.highlight.opacity(fade * 0.65)), lineWidth: 1.5)
            }
            let count = 12 + style.stage * 3
            for i in 0..<count {
                let angle = Double(i) * .pi * 2 / Double(count)
                let r = radius * (0.7 + Double(i % 3) * 0.14)
                let length = (4 + Double(style.stage)) * (1 - progress)
                var ray = Path()
                ray.move(to: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r))
                ray.addLine(to: CGPoint(x: center.x + cos(angle) * (r + length), y: center.y + sin(angle) * (r + length)))
                context.stroke(ray, with: .color(style.highlight.opacity(fade)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
