import SwiftUI

/// One light, above and to the left, for every surface of the rank badge.
/// Each face is shaded by how directly it looks at that light, so the frame
/// reads as machined metal rather than as outlines.
enum PrestigeLight {
    /// Unit vector pointing toward the light, in screen space (y down).
    static let toward = CGVector(dx: -0.45, dy: -0.89)

    /// 0 when a face points away from the light, 1 when it faces it.
    static func exposure(_ normal: CGVector) -> Double {
        max(0, min(1, 0.5 + 0.5 * Double(normal.dx * toward.dx + normal.dy * toward.dy)))
    }
}

/// The metal and stone of one forged piece. Rank badges and mission medals
/// share it, so both families are cut from the same material.
struct ForgeTone {
    let hue: Double
    /// 1 for full colour; 0 turns the piece to plain steel (locked medals).
    var saturation = 1.0
    /// Below 1 for matte, unlit pieces such as locked medals.
    var brightness = 1.0

    /// Anodised metal at a given exposure. Lit faces lose saturation the way a
    /// real highlight does; faces in shadow deepen toward the hue.
    func metal(_ exposure: Double) -> Color {
        let e = max(0, min(1, exposure))
        return Color(hue: hue, saturation: (0.8 - 0.62 * e) * saturation, brightness: (0.16 + 0.84 * e) * brightness)
    }
    /// Stone colour for a facet of the given brightness: glassier and more
    /// saturated than the metal, bright facets nearly white.
    func gem(_ light: Double) -> Color {
        let e = max(0, min(1, light))
        return Color(hue: hue, saturation: (0.9 - 0.72 * e * e) * saturation, brightness: (0.36 + 0.64 * e) * brightness)
    }
    var tint: Color { Color(hue: hue, saturation: 0.62 * saturation, brightness: 0.96) }
    /// The recessed face behind the gem or emblem.
    var faceTop: Color { Color(hue: hue, saturation: 0.7 * saturation, brightness: 0.2) }
    var faceBottom: Color { Color(hue: hue, saturation: 0.6 * saturation, brightness: 0.05) }
}

extension LevelPrestige {
    var tone: ForgeTone { ForgeTone(hue: hue) }
    func metal(_ exposure: Double) -> Color { tone.metal(exposure) }
    func gemTone(_ light: Double) -> Color { tone.gem(light) }
    var faceTop: Color { tone.faceTop }
    var faceBottom: Color { tone.faceBottom }
}

/// Convex outlines as point lists, clockwise from the top-left, so every edge
/// has an outward normal the light can be measured against.
enum PrestigeOutline {
    static func plate(stage: Int, in r: CGRect) -> [CGPoint] {
        if stage == 0 { return rounded(r, radius: min(12, r.height / 2)) }
        // Two cut depths only, proportional to the height, so every rank of
        // the same family has identical corners.
        let cut = r.height * (stage >= 3 ? 0.27 : 0.17)
        return [CGPoint(x: r.minX + cut, y: r.minY), CGPoint(x: r.maxX - cut, y: r.minY),
                CGPoint(x: r.maxX, y: r.minY + cut), CGPoint(x: r.maxX, y: r.maxY - cut),
                CGPoint(x: r.maxX - cut, y: r.maxY), CGPoint(x: r.minX + cut, y: r.maxY),
                CGPoint(x: r.minX, y: r.maxY - cut), CGPoint(x: r.minX, y: r.minY + cut)]
    }

    /// The crest that rises from the top edge of the crowned ranks.
    static func crest(centerX x: CGFloat, top y: CGFloat, width w: CGFloat, height h: CGFloat) -> [CGPoint] {
        [CGPoint(x: x - w / 2, y: y + 2), CGPoint(x: x - w * 0.34, y: y - h * 0.62),
         CGPoint(x: x, y: y - h), CGPoint(x: x + w * 0.34, y: y - h * 0.62),
         CGPoint(x: x + w / 2, y: y + 2)]
    }

    /// The seal that hangs below the bottom edge of the final rank.
    static func seal(centerX x: CGFloat, bottom y: CGFloat, width w: CGFloat, height h: CGFloat) -> [CGPoint] {
        [CGPoint(x: x - w / 2, y: y - 2), CGPoint(x: x + w / 2, y: y - 2),
         CGPoint(x: x + w * 0.3, y: y + h * 0.55), CGPoint(x: x, y: y + h),
         CGPoint(x: x - w * 0.3, y: y + h * 0.55)]
    }

    static func rounded(_ r: CGRect, radius: CGFloat, steps: Int = 7) -> [CGPoint] {
        let centers = [CGPoint(x: r.maxX - radius, y: r.minY + radius), CGPoint(x: r.maxX - radius, y: r.maxY - radius),
                       CGPoint(x: r.minX + radius, y: r.maxY - radius), CGPoint(x: r.minX + radius, y: r.minY + radius)]
        var points: [CGPoint] = []
        for (corner, c) in centers.enumerated() {
            let start = -Double.pi / 2 + Double(corner) * .pi / 2
            for s in 0...steps {
                let a = start + Double(s) / Double(steps) * .pi / 2
                points.append(CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius))
            }
        }
        return points
    }

    static func normal(_ a: CGPoint, _ b: CGPoint) -> CGVector {
        let dx = b.x - a.x, dy = b.y - a.y, l = max(0.0001, sqrt(dx * dx + dy * dy))
        return CGVector(dx: dy / l, dy: -dx / l)
    }

    /// Moves every edge of a convex outline inward by `d`.
    static func inset(_ p: [CGPoint], by d: CGFloat) -> [CGPoint] {
        p.indices.map { i in
            let prev = p[(i + p.count - 1) % p.count], c = p[i], next = p[(i + 1) % p.count]
            let n1 = normal(prev, c), n2 = normal(c, next)
            var m = CGVector(dx: n1.dx + n2.dx, dy: n1.dy + n2.dy)
            let ml = max(0.0001, sqrt(m.dx * m.dx + m.dy * m.dy))
            m = CGVector(dx: m.dx / ml, dy: m.dy / ml)
            let len = d / max(0.3, m.dx * n1.dx + m.dy * n1.dy)
            return CGPoint(x: c.x - m.dx * len, y: c.y - m.dy * len)
        }
    }

    static func path(_ p: [CGPoint]) -> Path {
        var path = Path(); path.addLines(p); path.closeSubpath(); return path
    }
}

/// Draws a beveled metal band between an outline and its inset. Each edge is
/// one flat face lit by `PrestigeLight`; `sloping` flips the face so it runs
/// down into the recess, which is what makes a two-tier molding.
enum PrestigeBevel {
    static func band(_ context: inout GraphicsContext, outer: [CGPoint], inner: [CGPoint],
                     style: ForgeTone, sloping: Bool = false, lift: Double = 0) {
        for i in outer.indices {
            let j = (i + 1) % outer.count
            let n = PrestigeOutline.normal(outer[i], outer[j])
            let facing = sloping ? CGVector(dx: -n.dx, dy: -n.dy) : n
            let e = min(1, PrestigeLight.exposure(facing) * (1 - lift) + lift)
            let quad = PrestigeOutline.path([outer[i], outer[j], inner[j], inner[i]])
            context.fill(quad, with: .color(style.metal(e)))
            // A hairline along the same face keeps neighbouring facets from
            // merging into one flat colour at small sizes.
            context.stroke(quad, with: .color(style.metal(e)), lineWidth: 0.35)
        }
    }

    /// A thin specular line on the edges that face the light.
    static func glint(_ context: inout GraphicsContext, _ outline: [CGPoint], inset: CGFloat, strength: Double = 1) {
        let line = PrestigeOutline.inset(outline, by: inset)
        for i in line.indices {
            let j = (i + 1) % line.count
            let e = PrestigeLight.exposure(PrestigeOutline.normal(outline[i], outline[(i + 1) % outline.count]))
            guard e > 0.72 else { continue }
            var p = Path(); p.move(to: line[i]); p.addLine(to: line[j])
            context.stroke(p, with: .color(.white.opacity((e - 0.72) * 2.4 * strength)),
                           style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        }
    }

    /// A small raised piece (crest or seal): solid beveled metal with a gem
    /// set into a socket, so it reads as one forged part rising from the rim.
    static func ornament(_ context: inout GraphicsContext, outline: [CGPoint], style: ForgeTone) {
        let inner = PrestigeOutline.inset(outline, by: 2.4)
        let top = inner.map(\.y).min() ?? 0, bottom = inner.map(\.y).max() ?? 0
        band(&context, outer: outline, inner: inner, style: style)
        context.fill(PrestigeOutline.path(inner), with: .linearGradient(
            Gradient(colors: [style.metal(0.82), style.metal(0.58), style.metal(0.4)]),
            startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
        context.stroke(PrestigeOutline.path(outline), with: .color(.black.opacity(0.55)), lineWidth: 0.6)
        glint(&context, outline, inset: 0.6)
        let xs = inner.map(\.x)
        let side = min(xs.max()! - xs.min()!, bottom - top) * 0.78
        let c = CGPoint(x: (xs.min()! + xs.max()!) / 2, y: bottom - side / 2 - 0.4)
        let socket = Path(ellipseIn: CGRect(x: c.x - side / 2, y: c.y - side / 2, width: side, height: side))
        context.fill(socket, with: .radialGradient(Gradient(colors: [style.tint.opacity(0.5), style.faceBottom]),
                                                   center: c, startRadius: 0, endRadius: side / 2))
        context.stroke(socket, with: .linearGradient(Gradient(colors: [.black.opacity(0.7), style.metal(0.95)]),
                                                     startPoint: CGPoint(x: c.x, y: c.y - side / 2), endPoint: CGPoint(x: c.x, y: c.y + side / 2)),
                       lineWidth: 0.7)
        let g = side * 0.86
        PrestigeGem.draw(&context, in: CGRect(x: c.x - g / 2, y: c.y - g / 2, width: g, height: g), style: style, detail: false)
    }
}

/// A brilliant seen from the front: three crown facets over the girdle, a
/// split table and three pavilion facets, each shaded by its own angle.
enum PrestigeGem {
    static func draw(_ context: inout GraphicsContext, in r: CGRect, style: ForgeTone, detail: Bool = true) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        let a = p(0.27, 0.12), b = p(0.5, 0.12), c = p(0.73, 0.12)
        let l = p(0.04, 0.37), lp = p(0.33, 0.37), rq = p(0.67, 0.37), rr = p(0.96, 0.37)
        let k = p(0.5, 0.95)
        let outline = [a, c, rr, k, l]

        // Cast shadow on the face beneath the stone.
        context.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.18, y: r.maxY - r.height * 0.06,
                                            width: r.width * 0.64, height: r.height * 0.14)),
                     with: .radialGradient(Gradient(colors: [.black.opacity(0.55), .clear]),
                                           center: p(0.5, 1.0), startRadius: 0, endRadius: r.width * 0.34))

        let facets: [([CGPoint], Double)] = [
            ([l, a, lp], 0.9), ([a, b, lp], 1.0), ([b, rq, lp], 0.8), ([b, c, rq], 0.68),
            ([c, rr, rq], 0.55), ([l, lp, k], 0.7), ([lp, rq, k], 0.52), ([rq, rr, k], 0.34)]
        for (points, light) in facets {
            let facet = PrestigeOutline.path(points)
            context.fill(facet, with: .color(style.gem(light)))
            if detail {
                context.stroke(facet, with: .color(.white.opacity(0.1 + light * 0.18)), lineWidth: 0.4)
            }
        }
        context.stroke(PrestigeOutline.path(outline), with: .linearGradient(
            Gradient(colors: [.white.opacity(0.85), style.metal(0.3).opacity(0.9)]),
            startPoint: a, endPoint: k), lineWidth: detail ? 0.7 : 0.5)
        // The table catches the light as one soft bloom, not a drawn line.
        let bloom = CGRect(x: r.minX + r.width * 0.3, y: r.minY + r.height * 0.14, width: r.width * 0.26, height: r.height * 0.16)
        context.fill(Path(ellipseIn: bloom), with: .radialGradient(
            Gradient(colors: [.white.opacity(0.9), .white.opacity(0)]),
            center: CGPoint(x: bloom.midX, y: bloom.midY), startRadius: 0, endRadius: bloom.width * 0.6))
    }

    /// A four-point glint; `size` is the half length of its long arms.
    static func glint(_ context: inout GraphicsContext, at c: CGPoint, size s: CGFloat, opacity: Double) {
        guard opacity > 0.01 else { return }
        var star = Path()
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4 - .pi / 2
            let r = i.isMultiple(of: 2) ? s * (i % 4 == 0 ? 1 : 0.62) : s * 0.14
            let point = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
            if i == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        context.fill(star, with: .color(.white.opacity(opacity)))
        context.fill(Path(ellipseIn: CGRect(x: c.x - s * 0.45, y: c.y - s * 0.45, width: s * 0.9, height: s * 0.9)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(opacity * 0.5), .clear]),
                                           center: c, startRadius: 0, endRadius: s * 0.45))
    }
}
