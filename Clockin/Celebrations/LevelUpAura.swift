import SwiftUI

/// Each rank's own light on the level-up stage.
enum LevelUpAura {
    enum Layer { case under, over }
    private typealias C = LevelUpCurve

    static func draw(_ ctx: inout GraphicsContext, _ layer: Layer, _ l: LevelUpStageLayout, t: Double, since: Double,
                     style: LevelPrestige) {
        guard since >= 0, l.size.width > 0, l.size.height > 0 else { return }
        var light = ctx
        light.clip(to: Path(CGRect(origin: .zero, size: l.size)))
        // Light in front keeps off the companion; light behind is covered by it anyway.
        if l.companion && layer == .over {
            let space = CGRect(x: l.floor.x - 38, y: l.crest.y + l.crestRadius,
                               width: 76, height: max(0, l.floor.y - l.crest.y - l.crestRadius + 8))
            light.clip(to: Path(space), options: .inverse)
        }
        if layer == .over {
            light.clip(to: circle(l.crest, l.crestRadius * 0.59), options: .inverse)
        }
        switch (style.stage, layer) {
        case (0, .over): spark(&light, l, t: t, since: since, style: style)
        case (1, _): orbit(&light, layer, l, t: t, since: since, style: style)
        case (2, .under): nebula(&light, l, t: t, since: since, style: style)
        case (3, .under): solar(&light, l, t: t, since: since, style: style)
        case (4, .under): nova(&light, l, t: t, since: since, style: style)
        case (5, .under): aurora(&light, l, t: t, since: since, style: style)
        case (6, .over): sovereign(&light, l, t: t, since: since, style: style)
        case (7, .under): celestial(&light, l, t: t, since: since, style: style)
        case (8, .under): eternal(&light, l, t: t, since: since, style: style)
        default: break
        }
    }

    /// Spark: a brief ballistic crackle keeps the first stone's light small.
    private static func spark(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, since: Double,
                              style: LevelPrestige) {
        let entrance = since < 1
        let u = entrance ? since : cycle(t - C.still + 0.3, 2.5)
        guard u < 0.85 else { return }
        let r = l.crestRadius
        let stone = CGPoint(x: l.crest.x, y: l.crest.y - r * 1.11)
        let strength = entrance ? 1.35 : 1.0
        for i in 0..<(entrance ? 5 : 4) {
            let age = u - Double(i) * 0.025
            guard age > 0 else { continue }
            let p = C.ramp(age, 0, 0.72)
            let fade = C.easeOut(C.ramp(age, 0, 0.09)) * (1 - C.easeIn(p))
            let vx = (Double(i) - (entrance ? 2 : 1.5)) * r * 0.37
            let vy = min(r * (0.5 + 0.22 * C.noise(i, 21)), max(8, stone.y - 5) * 2)
            func at(_ q: Double) -> CGPoint {
                CGPoint(x: stone.x + vx * q * strength, y: stone.y - vy * q + r * 0.7 * q * q)
            }
            for j in 0..<4 {
                let q = max(0, age - Double(j) * 0.035)
                let line = segment(at(max(0, q - 0.035)), at(q))
                ctx.stroke(line, with: .color(style.highlight.opacity(fade * (1 - Double(j) / 4))),
                           style: StrokeStyle(lineWidth: 1.6 - Double(j) * 0.25, lineCap: .round))
            }
            glow(&ctx, at: at(age), radius: 4, color: style.tint, opacity: 0.5 * fade)
        }
    }

    /// Orbit: two moons share a tilted ring, giving the crest a near and far side.
    private static func orbit(_ ctx: inout GraphicsContext, _ layer: Layer, _ l: LevelUpStageLayout,
                              t: Double, since: Double, style: LevelPrestige) {
        let rx = min(l.crestRadius * 1.9, max(1, l.size.width / 2 - 12))
        let ry = rx * 0.55, tilt = -0.3
        func at(_ a: Double) -> CGPoint {
            let x = cos(a) * rx, y = sin(a) * ry
            return CGPoint(x: l.crest.x + x * cos(tilt) - y * sin(tilt),
                           y: l.crest.y + x * sin(tilt) + y * cos(tilt))
        }
        func visible(_ a: Double) -> Bool { (sin(a) >= 0) == (layer == .over) }
        let reach = C.easeInOut(C.ramp(since, 0, 0.8)) * 2 * .pi
        var ring = Path()
        // Separate half arcs include their common endpoints without joining across the crest.
        for half in 0..<2 {
            let start = Double(half) * .pi
            guard visible(start + .pi / 2), reach > start else { continue }
            let end = min(start + .pi, reach)
            ring.move(to: at(start))
            for i in 1...48 { ring.addLine(to: at(start + (end - start) * Double(i) / 48)) }
        }
        let depth = layer == .over ? 1.0 : 0.6
        ctx.stroke(ring, with: .color(style.tint.opacity(0.08 * depth)), lineWidth: 4)
        ctx.stroke(ring, with: .color(style.highlight.opacity(0.3 * depth)), lineWidth: 0.7)
        let appear = C.easeOut(C.ramp(since, 0.8, 1))
        guard appear > 0 else { return }
        for i in 0..<2 {
            let angle = (t - C.still) * 2 * .pi / 9 + 0.64 + Double(i) * .pi
            for j in 0..<8 {
                let a = angle - Double(j) * 0.045
                // Split a sample at the depth seam even when its moon has crossed it.
                let b = a - 0.045, seam = floor(a / .pi) * .pi
                let cuts = b < seam ? [b, seam, a] : [b, a]
                for k in 0..<(cuts.count - 1) where visible((cuts[k] + cuts[k + 1]) / 2) {
                    ctx.stroke(segment(at(cuts[k]), at(cuts[k + 1])),
                               with: .color(style.tint.opacity(appear * depth * 0.42 * (1 - Double(j) / 8))),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            guard visible(angle) else { continue }
            let p = at(angle), radius: CGFloat = i == 0 ? 4.2 : 3.2
            glow(&ctx, at: p, radius: radius * 2.5, color: style.tint, opacity: 0.3 * appear * depth)
            ctx.fill(circle(p, radius), with: .radialGradient(
                Gradient(colors: [style.highlight.opacity(appear), style.tint.opacity(appear * 0.8), style.shade.opacity(appear * 0.4)]),
                center: CGPoint(x: p.x - radius * 0.35, y: p.y - radius * 0.4), startRadius: 0, endRadius: radius * 1.5))
        }
    }

    /// Nebula: drifting clouds carry their own stars, like the amethyst dome.
    private static func nebula(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, since: Double,
                               style: LevelPrestige) {
        let bloom = C.easeOut(C.ramp(since, 0, 0.9)), r = l.crestRadius
        for i in 0..<7 {
            let a = Double(i) * 2 * .pi / 7 + t * 0.055
            let p = around(l, a, r * (1.0 + 0.4 * C.noise(i, 22)) * bloom)
            let radius = r * (0.7 + 0.3 * C.noise(i, 23)) * (0.2 + 0.8 * bloom)
            let color = i.isMultiple(of: 2) ? style.material.face.tint : style.material.stone.tint
            glow(&ctx, at: p, radius: radius, color: color, opacity: 0.34 * bloom)
            glow(&ctx, at: CGPoint(x: p.x + radius * 0.2, y: p.y - radius * 0.15), radius: radius * 0.6,
                 color: style.highlight, opacity: 0.1 * bloom)
            let star = around(l, a + 0.06, r * (1.25 + 0.2 * C.noise(i, 24)) * bloom)
            let twinkle = 0.55 + 0.3 * sin(t * (0.7 + C.noise(i, 25) * 0.4) + Double(i) * 2.1)
            glint(&ctx, at: star, size: 2.6 + C.noise(i, 26) * 1.4, color: style.highlight, opacity: twinkle * bloom)
        }
    }

    /// Solar: a corona of flame tongues, long and short in turn, each licking
    /// at its own rate, over a warm ring of light round the crest.
    private static func solar(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, since: Double,
                              style: LevelPrestige) {
        let grow = C.easeOut(C.ramp(since, 0, 0.85)), r = l.crestRadius
        let white = style.material.metal.gem(1)
        glow(&ctx, at: l.crest, radius: r * (1.2 + 0.4 * grow), color: style.tint, opacity: 0.4 * grow)
        for i in 0..<16 {
            let long = i.isMultiple(of: 2)
            let a = Double(i) * .pi / 8 + t * 0.03
            let lick = 0.5 + 0.5 * sin(t * (1.1 + C.noise(i, 27) * 0.9) + Double(i) * 1.7)
            let outer = r * (1 + grow * ((long ? 0.55 : 0.32) + (long ? 0.35 : 0.18) * lick))
            let lean = 0.1 * sin(t * 0.8 + Double(i))
            let width = long ? 0.085 : 0.065
            let base = around(l, a, r * 0.95), tip = around(l, a + lean, outer)
            var flame = Path()
            flame.move(to: around(l, a - width, r * 0.95))
            flame.addQuadCurve(to: tip, control: around(l, a - width * 0.6 + lean * 0.5, (r * 0.95 + outer) / 2))
            flame.addQuadCurve(to: around(l, a + width, r * 0.95), control: around(l, a + width * 0.9 + lean * 0.5, (r * 0.95 + outer) / 2))
            flame.closeSubpath()
            ctx.fill(flame, with: .linearGradient(
                Gradient(colors: [white.opacity(0.85 * grow), style.tint.opacity(0.5 * grow), style.tint.opacity(0)]),
                startPoint: base, endPoint: tip))
        }
    }

    /// Nova: a steady four-point star releases one soft shock ring per cycle.
    private static func nova(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, since: Double,
                             style: LevelPrestige) {
        let grow = C.easeOut(C.ramp(since, 0, 0.7)), r = l.crestRadius
        let pulse = 0.9 + 0.1 * cos((t - C.still) * 1.1)
        let facets = PrestigeOutline.star(center: .zero, long: r * 2.05, short: r * 2.0, waist: r * 0.32)
        for (a, b, c) in facets {
            let points = [a, b, c].map { fit(l, x: $0.x * grow * pulse, y: $0.y * grow * pulse) }
            let facet = PrestigeOutline.path(points)
            ctx.fill(facet, with: .radialGradient(
                Gradient(colors: [style.highlight.opacity(0.55 * grow), style.tint.opacity(0.27 * grow), .clear]),
                center: l.crest, startRadius: r * 0.65, endRadius: r * 2.05))
            ctx.stroke(segment(points[0], points[2]), with: .color(style.highlight.opacity(0.1 * grow)), lineWidth: 0.65)
        }
        for i in 0..<4 {
            let a = Double(i) * .pi / 2 + .pi / 4
            let tip = around(l, a, r * 1.46 * grow)
            let ray = PrestigeOutline.path([around(l, a - 0.07, r * 0.8), tip, around(l, a + 0.07, r * 0.8)])
            ctx.fill(ray, with: .linearGradient(Gradient(colors: [style.highlight.opacity(0.35 * grow), .clear]),
                                               startPoint: l.crest, endPoint: tip))
        }
        let u = cycle(since, 4.5)
        guard u < 0.8 else { return }
        let p = C.ramp(u, 0, 0.8), radius = r * (1 + 1.4 * C.easeOut(p))
        let fade = (1 - C.easeInOut(p)) * C.ramp(u, 0, 0.06)
        let ring = circle(l.crest, radius)
        ctx.stroke(ring, with: .color(style.tint.opacity(0.16 * fade)), lineWidth: 4)
        ctx.stroke(ring, with: .color(style.highlight.opacity(0.6 * fade)), lineWidth: 1)
    }

    /// Aurora: curtains of light across the sky behind the crest. Each has a
    /// bright, rolling lower edge and rays rising from it in folds that drift.
    private static func aurora(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, since: Double,
                               style: LevelPrestige) {
        let unroll = C.easeInOut(C.ramp(since, 0, 0.9)), r = l.crestRadius
        let half = (l.size.width / 2 - 4) * unroll
        guard half > 1 else { return }
        for curtain in 0..<2 {
            let row = Double(curtain)
            let baseY = l.crest.y - r * (0.25 + 0.55 * row)
            let rise = r * (1.0 - 0.25 * row)
            func edge(_ x: CGFloat) -> CGFloat {
                baseY + sin(x / r * 1.6 + t * 0.35 + row * 2.1) * r * 0.16 + sin(x / r * 3.7 - t * 0.23 + row) * r * 0.05
            }
            let strips = 40
            for strip in 0..<strips {
                let x0 = -half + 2 * half * CGFloat(strip) / CGFloat(strips)
                let x1 = -half + 2 * half * CGFloat(strip + 1) / CGFloat(strips)
                let xm = (x0 + x1) / 2
                let taper = max(0, 1 - pow(abs(xm) / half, 3))
                let fold = max(0, 0.5 + 0.5 * sin(xm / r * 5.3 + t * 0.6 + row * 1.3) * sin(xm / r * 2.2 - t * 0.31 + row))
                let a = unroll * taper * (0.3 + 0.7 * fold) * (row == 0 ? 1 : 0.7)
                let length = rise * (0.6 + 0.4 * fold)
                var ray = Path()
                ray.move(to: CGPoint(x: l.crest.x + x0, y: edge(x0)))
                ray.addLine(to: CGPoint(x: l.crest.x + x1, y: edge(x1)))
                ray.addLine(to: CGPoint(x: l.crest.x + x1, y: edge(x1) - length))
                ray.addLine(to: CGPoint(x: l.crest.x + x0, y: edge(x0) - length))
                ray.closeSubpath()
                let foot = CGPoint(x: l.crest.x + xm, y: edge(xm))
                ctx.fill(ray, with: .linearGradient(
                    Gradient(colors: [style.highlight.opacity(0.32 * a), style.tint.opacity(0.24 * a),
                                      style.material.face.tint.opacity(0.08 * a), .clear]),
                    startPoint: foot, endPoint: CGPoint(x: foot.x, y: foot.y - length)))
            }
        }
    }

    /// Sovereign: a regal gleam rather than more ornament. A band of light
    /// runs once round the crest's rim every few seconds, the ruby at its top
    /// beats warmly, and a few ruby sparks drift round the crest.
    private static func sovereign(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, since: Double,
                                 style: LevelPrestige) {
        let r = l.crestRadius, c = l.crest
        let appear = C.easeOut(C.ramp(since, 0, 0.4))
        let stone = CGPoint(x: c.x, y: c.y - r * 0.9)
        let beat = pow(max(0, sin((t - C.still) * 1.7)), 6)
        glow(&ctx, at: stone, radius: r * 0.38, color: style.tint, opacity: (0.2 + 0.3 * beat) * appear)
        // The gleam: a short arc of light travelling round the rim.
        let u = cycle(since, 4.2)
        if u < 1.3 {
            let p = C.easeInOut(u / 1.3)
            let head = -Double.pi / 2 + p * 2 * .pi
            let a = sin(p * .pi) * appear
            let rim = r * 0.9
            var arc = Path()
            arc.addArc(center: c, radius: rim, startAngle: .radians(head - 0.55), endAngle: .radians(head), clockwise: false)
            var soft = ctx
            soft.addFilter(.blur(radius: r * 0.05))
            soft.stroke(arc, with: .color(style.tint.opacity(0.6 * a)), style: StrokeStyle(lineWidth: r * 0.14, lineCap: .round))
            ctx.stroke(arc, with: .color(style.highlight.opacity(0.7 * a)), style: StrokeStyle(lineWidth: r * 0.035, lineCap: .round))
            glint(&ctx, at: CGPoint(x: c.x + cos(head) * rim, y: c.y + sin(head) * rim), size: r * 0.1, color: .white, opacity: a)
        }
        // Sparks drifting round the crest, each twinkling on its own beat.
        for i in 0..<6 {
            let a = t * 0.18 + Double(i) / 6 * 2 * .pi + 0.3
            let radius = r * (1.32 + 0.1 * sin(t * 0.7 + Double(i)))
            let p = CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius * 0.92)
            let twinkle = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * 2.1 + Double(i) * 2.3), 3)
            glint(&ctx, at: p, size: 2.6, color: style.material.stone.gem(1), opacity: twinkle * appear)
        }
    }

    /// Celestial: a sapphire constellation traces an arch clear of the stone.
    private static func celestial(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, since: Double,
                                  style: LevelPrestige) {
        let r = l.crestRadius
        let u = cycle(since, 6)
        let draw = C.easeInOut(C.ramp(u, 0, 0.95))
        let fade = 1 - C.easeInOut(C.ramp(u, 5.5, 6))
        let rx = min(r * 1.85, max(1, l.size.width / 2 - 12)), ry = min(r * 1.62, l.crest.y - 9)
        let stars = (0..<8).map { i in
            let a = .pi + Double(i) / 7 * .pi
            return CGPoint(x: l.crest.x + cos(a) * rx,
                           y: l.crest.y + sin(a) * ry - (i.isMultiple(of: 2) ? 0 : 3))
        }
        for i in 0..<7 {
            let part = C.ramp(draw * 7, Double(i), Double(i + 1))
            guard part > 0 else { continue }
            let a = stars[i], b = stars[i + 1]
            let line = segment(a, CGPoint(x: a.x + (b.x - a.x) * part, y: a.y + (b.y - a.y) * part))
            ctx.stroke(line, with: .color(style.tint.opacity(0.12 * fade)), lineWidth: 3)
            ctx.stroke(line, with: .color(style.highlight.opacity(0.6 * fade)), lineWidth: 0.7)
        }
        for (i, p) in stars.enumerated() {
            let lit = C.ramp(draw * 8, Double(i), Double(i) + 0.6)
            let a = lit * fade * (0.75 + 0.2 * sin(t * 0.8 + Double(i) * 1.8))
            glint(&ctx, at: p, size: i.isMultiple(of: 3) ? 3.8 : 2.6, color: style.highlight, opacity: a)
        }
    }

    /// Eternal: swept feathers unfold into prismatic light, echoing the diamond's fire.
    private static func eternal(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, since: Double,
                                style: LevelPrestige) {
        let open = C.easeInOut(C.ramp(since, 0, 0.9)), r = l.crestRadius
        let length = min(r * 1.6, max(1, l.size.width / 2 - r * 0.8 - 9))
        for side: CGFloat in [-1, 1] {
            let anchor = CGPoint(x: l.crest.x + side * r * 0.8, y: l.crest.y - r * 0.05)
            let feathers = PrestigeOutline.wing(at: anchor, side: side, length: length, feathers: 5)
            for (i, feather) in feathers.reversed().enumerated() {
                let points = feather.map { p in
                    CGPoint(x: anchor.x + (p.x - anchor.x) * (0.12 + 0.88 * open),
                            y: anchor.y + (p.y - anchor.y) * open + abs(p.x - anchor.x) * 0.38 * (1 - open))
                }
                let path = PrestigeOutline.path(points)
                let hue = style.material.stone.hue + t * 0.035 + Double(i) * 0.12
                let colors = (0..<4).map { j in
                    Color(hue: cycle(hue + Double(j) * 0.18, 1), saturation: 0.48, brightness: 1).opacity(0.28 * open)
                }
                ctx.fill(path, with: .linearGradient(Gradient(colors: [style.highlight.opacity(0.08 * open)] + colors),
                                                    startPoint: anchor, endPoint: points[3]))
                ctx.stroke(path, with: .color(style.material.metal.gem(1).opacity(0.25 * open)), lineWidth: 0.7)
            }
            for i in 0..<3 {
                let phase = t * 0.25 + Double(i) * 2.1
                let p = CGPoint(x: anchor.x + side * length * (0.35 + 0.22 * Double(i)) * open,
                                y: anchor.y - length * (0.45 + 0.13 * Double(i)) + sin(phase) * 4)
                let color = Color(hue: cycle(style.material.stone.hue + Double(i) * 0.24 + t * 0.035, 1),
                                  saturation: 0.5, brightness: 1)
                glint(&ctx, at: p, size: 2.2, color: color, opacity: open * (0.45 + 0.2 * sin(phase)))
            }
        }
    }

    // MARK: Helpers

    private static func cycle(_ t: Double, _ period: Double) -> Double {
        let u = t.truncatingRemainder(dividingBy: period)
        return u < 0 ? u + period : u
    }

    private static func wave(_ t: Double, _ start: Double, _ end: Double) -> Double {
        let p = C.ramp(t, start, end)
        return pow(sin(p * .pi), 2)
    }

    /// Compress the upper reach into the headroom without moving the crest's centre.
    private static func fit(_ l: LevelUpStageLayout, x: CGFloat, y: CGFloat) -> CGPoint {
        let sx = min(1, max(1, l.size.width / 2 - 7) / (l.crestRadius * 2.1))
        let inner = min(l.crestRadius * 0.9, max(1, l.crest.y - 7))
        let headroom = max(0, l.crest.y - 7 - inner)
        let sy = min(1, headroom / max(1, l.crestRadius * 2.1 - inner))
        let dy = y < -inner ? -inner + (y + inner) * sy : y
        return CGPoint(x: l.crest.x + x * sx, y: l.crest.y + dy)
    }

    private static func around(_ l: LevelUpStageLayout, _ angle: Double, _ r: CGFloat) -> CGPoint {
        fit(l, x: cos(angle) * r, y: sin(angle) * r)
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private static func segment(_ a: CGPoint, _ b: CGPoint) -> Path {
        var path = Path(); path.move(to: a); path.addLine(to: b); return path
    }

    private static func glow(_ ctx: inout GraphicsContext, at p: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        ctx.fill(circle(p, radius), with: .radialGradient(Gradient(colors: [color.opacity(opacity), .clear]),
                                                        center: p, startRadius: 0, endRadius: radius))
    }

    private static func glint(_ ctx: inout GraphicsContext, at p: CGPoint, size: CGFloat, color: Color, opacity: Double) {
        guard opacity > 0 else { return }
        let points = [CGPoint(x: p.x, y: p.y - size), CGPoint(x: p.x + size * 0.18, y: p.y - size * 0.18),
                      CGPoint(x: p.x + size * 0.7, y: p.y), CGPoint(x: p.x + size * 0.18, y: p.y + size * 0.18),
                      CGPoint(x: p.x, y: p.y + size), CGPoint(x: p.x - size * 0.18, y: p.y + size * 0.18),
                      CGPoint(x: p.x - size * 0.7, y: p.y), CGPoint(x: p.x - size * 0.18, y: p.y - size * 0.18)]
        glow(&ctx, at: p, radius: size * 2, color: color, opacity: opacity * 0.3)
        ctx.fill(PrestigeOutline.path(points), with: .color(color.opacity(opacity)))
    }
}
