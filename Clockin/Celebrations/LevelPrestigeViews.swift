import SwiftUI

extension LevelPrestige {
    var tint: Color { Color(hue: hue, saturation: 0.62, brightness: 0.96) }
    var highlight: Color { Color(hue: hue, saturation: 0.18, brightness: 1) }
    var shade: Color { Color(hue: hue, saturation: 0.75, brightness: 0.43) }
}

/// Shared by the dashboard, Badges and the level-up card.
struct PrestigeProgressBar: View {
    let level: Int
    let progress: Double
    var active = true
    var height: CGFloat = 14
    private var style: LevelPrestige { .init(level: level) }
    private var fraction: Double { progress.isFinite ? min(1, max(0, progress)) : 0 }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * fraction
            ZStack(alignment: .leading) {
                Capsule().fill(style.shade.opacity(0.16))
                Capsule().fill(LinearGradient(colors: [style.shade, style.tint, style.highlight],
                    startPoint: .leading, endPoint: .trailing))
                    .frame(width: width)
            }
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(style.tint.opacity(0.22), lineWidth: 1))
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress to next level")
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

/// A single continuous body, with earned bevels and inset metal layers.
struct PrestigePlate: Shape {
    let stage: Int
    func path(in r: CGRect) -> Path {
        if stage == 0 { return Path(roundedRect: r, cornerRadius: min(13, r.height / 2)) }
        let cut = min(stage >= 4 ? 13.0 : (stage >= 3 ? 10.0 : 6.0), r.height * 0.3)
        var p = Path()
        let points = [CGPoint(x: r.minX + cut, y: r.minY), CGPoint(x: r.maxX - cut, y: r.minY),
                      CGPoint(x: r.maxX, y: r.minY + cut), CGPoint(x: r.maxX, y: r.maxY - cut),
                      CGPoint(x: r.maxX - cut, y: r.maxY), CGPoint(x: r.minX + cut, y: r.maxY),
                      CGPoint(x: r.minX, y: r.maxY - cut), CGPoint(x: r.minX, y: r.minY + cut)]
        p.addLines(points); p.closeSubpath(); return p
    }
}

/// Static forged geometry remains legible even with motion and color removed.
struct PrestigeMetalFrame: View {
    let style: LevelPrestige
    var body: some View {
        Canvas { original, fullSize in
            // Canvas clips at its bounds: reserve room for the earned silhouette.
            var context = original
            context.translateBy(x: 22, y: 22)
            let size = CGSize(width: fullSize.width - 44, height: fullSize.height - 44)
            let rect = CGRect(origin: .zero, size: size)
            let metal = Gradient(colors: [style.highlight, style.tint.opacity(0.8), style.shade, style.highlight.opacity(0.7)])
            func plate(_ p: Path) {
                context.fill(p, with: .linearGradient(metal, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                context.stroke(p, with: .color(style.highlight.opacity(0.65)), lineWidth: 0.6)
            }
            if style.stage >= 2 {
                let inset = rect.insetBy(dx: 3, dy: 3)
                context.stroke(PrestigePlate(stage: style.stage).path(in: inset), with: .color(style.highlight.opacity(0.38)), lineWidth: 0.7)
            }
            // Beveled facets are cut into the existing body, never attached outside.
            if style.stage >= 3 {
                let cut = min(style.stage >= 4 ? 13.0 : 10.0, size.height * 0.3)
                for side in [-1.0, 1.0] {
                    let edge = side < 0 ? 0.0 : size.width
                    let inward = -side
                    var bevel = Path()
                    bevel.addLines([
                        CGPoint(x: edge + inward * cut, y: 0.7),
                        CGPoint(x: edge + inward * 0.7, y: cut),
                        CGPoint(x: edge + inward * 0.7, y: size.height - cut),
                        CGPoint(x: edge + inward * cut, y: size.height - 0.7),
                        CGPoint(x: edge + inward * (cut + 1.5), y: size.height - 3),
                        CGPoint(x: edge + inward * 3, y: size.height - cut - 1),
                        CGPoint(x: edge + inward * 3, y: cut + 1),
                        CGPoint(x: edge + inward * (cut + 1.5), y: 3)])
                    bevel.closeSubpath(); plate(bevel)
                }
            }
            if style.stage >= 5 {
                // A recessed satin rail follows the top and bottom of the frame.
                let inset = min(16.0, size.width * 0.2)
                for y in [2.5, size.height - 2.5] {
                    var rail = Path()
                    rail.move(to: CGPoint(x: inset, y: y))
                    rail.addLine(to: CGPoint(x: size.width - inset, y: y))
                    context.stroke(rail, with: .linearGradient(Gradient(colors: [style.shade, style.highlight.opacity(0.8), style.shade]), startPoint: CGPoint(x: inset, y: y), endPoint: CGPoint(x: size.width - inset, y: y)), lineWidth: 1)
                }
            }
            if style.stage >= 6 {
                let x = size.width / 2
                var crown = Path()
                crown.addLines([CGPoint(x: x - 11, y: 0), CGPoint(x: x - 14, y: -6),
                                CGPoint(x: x - 6, y: -4), CGPoint(x: x, y: -11),
                                CGPoint(x: x + 6, y: -4), CGPoint(x: x + 14, y: -6), CGPoint(x: x + 11, y: 0)])
                crown.closeSubpath(); plate(crown)
            }
            if style.stage >= 7 {
                var arch = Path()
                arch.move(to: CGPoint(x: size.width * 0.18, y: -2))
                arch.addQuadCurve(to: CGPoint(x: size.width * 0.82, y: -2), control: CGPoint(x: size.width / 2, y: -23))
                context.stroke(arch, with: .color(style.highlight.opacity(0.7)), lineWidth: 0.8)
            }
            if style.stage >= 8 {
                // Apex stays apex at 675+; the core retains its platinum inner cut.
                let x = size.width / 2, y = size.height + 3
                var seal = Path()
                seal.addLines([CGPoint(x: x - 6, y: y), CGPoint(x: x, y: y + 5), CGPoint(x: x + 6, y: y), CGPoint(x: x, y: y - 3)])
                seal.closeSubpath(); plate(seal)
            }
        }.padding(-22).allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Faceted luminous core: rank is communicated by the surrounding metalwork,
/// not a second numeric label competing with the actual level.
struct PrestigeInsignia: View {
    let style: LevelPrestige
    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2, cy = size.height / 2
            let rx = style.stage >= 4 ? 10.0 : 8.0
            let ry = style.stage >= 4 ? 12.0 : 10.0
            let top = CGPoint(x: cx, y: cy - ry)
            let right = CGPoint(x: cx + rx, y: cy - 2)
            let bottom = CGPoint(x: cx, y: cy + ry)
            let left = CGPoint(x: cx - rx, y: cy - 2)
            let core = CGPoint(x: cx - 1.5, y: cy - 1)
            var outline = Path()
            outline.addLines([top, right, bottom, left]); outline.closeSubpath()
            // Quiet socket and cast shadow let the crystal sit inside the frame.
            let socket = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            context.fill(Path(ellipseIn: socket), with: .radialGradient(Gradient(colors: [style.tint.opacity(0.28), .clear]), center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: size.width / 2))
            context.fill(outline, with: .linearGradient(Gradient(colors: [style.highlight, style.tint, style.shade]), startPoint: top, endPoint: bottom))
            func facet(_ points: [CGPoint], _ color: Color) {
                var p = Path(); p.addLines(points); p.closeSubpath()
                context.fill(p, with: .color(color))
            }
            facet([top, core, left], style.highlight.opacity(0.9))
            facet([top, right, core], style.tint.opacity(0.85))
            facet([left, core, bottom], style.tint.opacity(0.65))
            facet([core, right, bottom], style.shade.opacity(0.8))
            context.stroke(outline, with: .linearGradient(Gradient(colors: [.white.opacity(0.9), style.tint.opacity(0.15)]), startPoint: top, endPoint: bottom), lineWidth: 0.7)
            var reflection = Path()
            reflection.move(to: CGPoint(x: left.x + 2, y: left.y))
            reflection.addLine(to: CGPoint(x: top.x, y: top.y + 3))
            context.stroke(reflection, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            if style.stage >= 6 {
                // A platinum inner cut distinguishes the highest cores.
                var cut = Path()
                cut.addLines([CGPoint(x: cx, y: cy - 5), CGPoint(x: cx + 3, y: cy - 1), CGPoint(x: cx, y: cy + 4), CGPoint(x: cx - 3, y: cy - 1)])
                cut.closeSubpath()
                context.fill(cut, with: .linearGradient(Gradient(colors: [.white, style.highlight.opacity(0.4)]), startPoint: top, endPoint: bottom))
            }
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
