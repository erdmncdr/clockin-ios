import SwiftUI

/// What each rank is made of. Metal, face and stone are chosen separately so
/// neighbouring ranks differ in material, not only in hue, and the upper ranks
/// can pair two metals or a metal with an enamel.
struct RankMaterial {
    let metal: ForgeTone
    let face: ForgeTone
    let stone: ForgeTone
    let cut: GemCut
}

enum GemCut { case cabochon, brilliant, step, kite, starSapphire, diamond }

extension LevelPrestige {
    var material: RankMaterial {
        switch stage {
        // Spark: blued steel and a smooth grey-blue stone.
        case 0: RankMaterial(metal: ForgeTone(hue: 0.6, saturation: 0.2), face: ForgeTone(hue: 0.6, saturation: 0.35),
                             stone: ForgeTone(hue: 0.57, saturation: 0.45), cut: .cabochon)
        // Orbit: bronze with an aquamarine, like a patinated instrument.
        case 1: RankMaterial(metal: ForgeTone(hue: 0.075, saturation: 0.85), face: ForgeTone(hue: 0.06, saturation: 0.55),
                             stone: ForgeTone(hue: 0.48, saturation: 0.7), cut: .brilliant)
        // Nebula: violet-cast silver around a cloudy amethyst dome.
        case 2: RankMaterial(metal: ForgeTone(hue: 0.72, saturation: 0.25), face: ForgeTone(hue: 0.74, saturation: 0.75),
                             stone: ForgeTone(hue: 0.8, saturation: 0.8), cut: .cabochon)
        // Solar: gold and citrine.
        case 3: RankMaterial(metal: ForgeTone(hue: 0.12, saturation: 0.9), face: ForgeTone(hue: 0.07, saturation: 0.85),
                             stone: ForgeTone(hue: 0.08, saturation: 1), cut: .brilliant)
        // Nova: platinum and ice.
        case 4: RankMaterial(metal: ForgeTone(hue: 0.55, saturation: 0.12), face: ForgeTone(hue: 0.55, saturation: 0.85),
                             stone: ForgeTone(hue: 0.52, saturation: 0.85), cut: .brilliant)
        // Aurora: green enamel and an emerald.
        case 5: RankMaterial(metal: ForgeTone(hue: 0.42, saturation: 0.45), face: ForgeTone(hue: 0.44, saturation: 0.85),
                             stone: ForgeTone(hue: 0.38, saturation: 0.95), cut: .step)
        // Sovereign: gold metal over a ruby face.
        case 6: RankMaterial(metal: ForgeTone(hue: 0.12, saturation: 0.85), face: ForgeTone(hue: 0.985, saturation: 0.85),
                             stone: ForgeTone(hue: 0.985, saturation: 1), cut: .kite)
        // Celestial: silver over a midnight face, a star sapphire.
        case 7: RankMaterial(metal: ForgeTone(hue: 0.62, saturation: 0.1), face: ForgeTone(hue: 0.67, saturation: 0.85),
                             stone: ForgeTone(hue: 0.63, saturation: 0.95), cut: .starSapphire)
        // Eternal: white gold, a diamond; its colour comes from iridescence.
        default: RankMaterial(metal: ForgeTone(hue: 0.12, saturation: 0.28), face: ForgeTone(hue: 0.72, saturation: 0.3),
                              stone: ForgeTone(hue: 0.58, saturation: 0.08), cut: .diamond)
        }
    }
}

/// Where things sit on the compact badge (in points, before any scaling): the
/// gem's centre and the socket's radius, shared by the frame and the effects.
enum RankLayout {
    static func gemCenter(in size: CGSize) -> CGPoint { CGPoint(x: 23, y: size.height / 2) }
    static let socketRadius: CGFloat = 13
}

/// Silhouettes. Every rank's outline differs, so ranks can be told apart in
/// grey scale. All plates are convex so the bevel can be cut along them.
extension PrestigeOutline {
    static func rankPlate(stage: Int, in r: CGRect) -> [CGPoint] {
        switch stage {
        case 0, 1:
            return rounded(r, radius: min(12, r.height / 2))
        case 3, 8:
            // Flares: the ends come to points outside the box.
            let reach: CGFloat = stage == 8 ? 5 : 7
            return [CGPoint(x: r.minX + 2, y: r.minY), CGPoint(x: r.maxX - 2, y: r.minY),
                    CGPoint(x: r.maxX + reach, y: r.midY), CGPoint(x: r.maxX - 2, y: r.maxY),
                    CGPoint(x: r.minX + 2, y: r.maxY), CGPoint(x: r.minX - reach, y: r.midY)]
        case 5:
            // An arched top edge over chamfered lower corners.
            let c = r.height * 0.22, shoulder = r.minY + r.height * 0.2, rise: CGFloat = 4
            var points = [CGPoint(x: r.minX, y: r.maxY - c), CGPoint(x: r.minX, y: shoulder)]
            for i in 1..<12 {
                let t = Double(i) / 12
                points.append(CGPoint(x: r.minX + r.width * t, y: shoulder - (shoulder - r.minY + rise) * sin(t * .pi)))
            }
            points += [CGPoint(x: r.maxX, y: shoulder), CGPoint(x: r.maxX, y: r.maxY - c),
                       CGPoint(x: r.maxX - c, y: r.maxY), CGPoint(x: r.minX + c, y: r.maxY)]
            return points
        default:
            return plate(stage: stage, in: r)
        }
    }

    /// The bevel reads each edge's outward side from the point order, which
    /// must run clockwise on screen (y down): a positive shoelace sum.
    static func clockwise(_ p: [CGPoint]) -> [CGPoint] {
        let sum = p.indices.reduce(0.0) { acc, i in
            let a = p[i], b = p[(i + 1) % p.count]
            return acc + Double(a.x * b.y - b.x * a.y)
        }
        return sum < 0 ? p.reversed() : p
    }

    /// Feathers of a wing on one side, fanned from a root hidden behind the
    /// plate; `side` is -1 for the left, +1 for the right. Each feather is
    /// narrow at the root, full in the middle and blunt at the tip.
    static func wing(at anchor: CGPoint, side: CGFloat, length: CGFloat, feathers: Int) -> [[CGPoint]] {
        (0..<feathers).map { i in
            let t = Double(i) / Double(max(1, feathers - 1))
            let angle = -0.95 + 1.05 * t                      // from steeply up to just below level
            let len = length * CGFloat(1 - 0.32 * t)
            let dir = CGVector(dx: cos(angle) * side, dy: sin(angle))
            let n = CGVector(dx: -dir.dy, dy: dir.dx)
            let root = CGPoint(x: anchor.x, y: anchor.y + CGFloat(t) * 6 - 2)
            let wide = length * 0.17, rootWidth = wide * 0.35
            func at(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
                CGPoint(x: root.x + dir.dx * along + n.dx * across, y: root.y + dir.dy * along + n.dy * across)
            }
            return clockwise([at(0, rootWidth), at(len * 0.58, wide), at(len * 0.9, wide * 0.62), at(len, 0),
                              at(len * 0.9, -wide * 0.62), at(len * 0.58, -wide), at(0, -rootWidth)])
        }
    }

    /// A four-point star; each arm is two facets.
    static func star(center c: CGPoint, long: CGFloat, short: CGFloat, waist: CGFloat) -> [(CGPoint, CGPoint, CGPoint)] {
        let tips = [CGPoint(x: c.x, y: c.y - long), CGPoint(x: c.x + short, y: c.y),
                    CGPoint(x: c.x, y: c.y + long), CGPoint(x: c.x - short, y: c.y)]
        var facets: [(CGPoint, CGPoint, CGPoint)] = []
        for i in 0..<4 {
            let tip = tips[i]
            let a = Double(i) * .pi / 2 - .pi / 2
            let left = CGPoint(x: c.x + cos(a - .pi / 4) * waist, y: c.y + sin(a - .pi / 4) * waist)
            let right = CGPoint(x: c.x + cos(a + .pi / 4) * waist, y: c.y + sin(a + .pi / 4) * waist)
            facets.append((c, left, tip)); facets.append((c, tip, right))
        }
        return facets
    }
}

/// Stones, each cut shaded facet by facet by the same light as the metal.
enum RankGem {
    static func draw(_ context: inout GraphicsContext, in r: CGRect, material: RankMaterial, detail: Bool = true) {
        switch material.cut {
        case .cabochon: cabochon(&context, in: r, tone: material.stone)
        case .brilliant: brilliant(&context, in: r, tone: material.stone, detail: detail, fire: false)
        case .diamond: brilliant(&context, in: r, tone: material.stone, detail: detail, fire: true)
        case .step: step(&context, in: r, tone: material.stone)
        case .kite: PrestigeGem.draw(&context, in: r, style: material.stone, detail: detail)
        case .starSapphire:
            cabochon(&context, in: r, tone: material.stone)
            asterism(&context, in: r, angle: 0.3, strength: 1)
        }
    }

    private static func shadow(_ context: inout GraphicsContext, under r: CGRect) {
        context.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.15, y: r.maxY - r.height * 0.1, width: r.width * 0.7, height: r.height * 0.16)),
                     with: .radialGradient(Gradient(colors: [.black.opacity(0.55), .clear]),
                                           center: CGPoint(x: r.midX, y: r.maxY), startRadius: 0, endRadius: r.width * 0.36))
    }

    /// A polished dome: light pools at the top left, the colour deepens toward
    /// the far edge, and a bright crescent of light returns at the lower rim.
    static func cabochon(_ context: inout GraphicsContext, in r: CGRect, tone: ForgeTone) {
        shadow(&context, under: r)
        let dome = Path(ellipseIn: r)
        context.fill(dome, with: .radialGradient(Gradient(colors: [tone.gem(0.95), tone.gem(0.6), tone.gem(0.22)]),
                                                 center: CGPoint(x: r.minX + r.width * 0.36, y: r.minY + r.height * 0.32),
                                                 startRadius: 0, endRadius: r.width * 0.8))
        context.drawLayer { layer in
            layer.clip(to: dome)
            layer.addFilter(.blur(radius: r.width * 0.06))
            layer.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.2, y: r.maxY - r.height * 0.28, width: r.width * 0.6, height: r.height * 0.3)),
                       with: .color(tone.gem(0.85).opacity(0.55)))
        }
        context.stroke(dome, with: .linearGradient(Gradient(colors: [.white.opacity(0.5), .black.opacity(0.45)]),
                                                   startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)),
                       lineWidth: 0.6)
        let spec = CGRect(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.16, width: r.width * 0.3, height: r.height * 0.2)
        context.fill(Path(ellipseIn: spec), with: .radialGradient(Gradient(colors: [.white.opacity(0.9), .white.opacity(0)]),
                                                                  center: CGPoint(x: spec.midX, y: spec.midY), startRadius: 0, endRadius: spec.width * 0.6))
    }

    /// The six-ray star of a star sapphire, which floats on the dome.
    static func asterism(_ context: inout GraphicsContext, in r: CGRect, angle: Double, strength: Double) {
        let c = CGPoint(x: r.midX - r.width * 0.04, y: r.midY - r.height * 0.06)
        context.drawLayer { layer in
            layer.clip(to: Path(ellipseIn: r))
            layer.addFilter(.blur(radius: max(0.3, r.width * 0.02)))
            for i in 0..<3 {
                let a = angle + Double(i) * .pi / 3
                let d = CGVector(dx: cos(a) * r.width * 0.46, dy: sin(a) * r.height * 0.46)
                var ray = Path()
                ray.move(to: CGPoint(x: c.x - d.dx, y: c.y - d.dy)); ray.addLine(to: CGPoint(x: c.x + d.dx, y: c.y + d.dy))
                layer.stroke(ray, with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.75 * strength), .white.opacity(0)]),
                                                        startPoint: CGPoint(x: c.x - d.dx, y: c.y - d.dy), endPoint: CGPoint(x: c.x + d.dx, y: c.y + d.dy)),
                             lineWidth: max(0.5, r.width * 0.05))
            }
        }
        context.fill(Path(ellipseIn: CGRect(x: c.x - r.width * 0.08, y: c.y - r.width * 0.08, width: r.width * 0.16, height: r.width * 0.16)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.9 * strength), .clear]), center: c, startRadius: 0, endRadius: r.width * 0.08))
    }

    /// A round brilliant from above: an octagonal table, eight star facets and
    /// eight girdle facets, each lit by the direction it faces.
    static func brilliant(_ context: inout GraphicsContext, in r: CGRect, tone: ForgeTone, detail: Bool, fire: Bool) {
        shadow(&context, under: r)
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = r.width / 2, table = outer * 0.52, star = outer * 0.8
        func point(_ radius: CGFloat, _ a: Double) -> CGPoint { CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius) }
        let n = 8
        for i in 0..<n {
            let a0 = Double(i) / Double(n) * .pi * 2 - .pi / 2 - .pi / 8
            let a1 = a0 + .pi * 2 / Double(n), mid = (a0 + a1) / 2
            let facing = CGVector(dx: cos(mid), dy: sin(mid))
            let light = PrestigeLight.exposure(facing)
            // Crown facet from the table edge out to the girdle.
            var crown = Path()
            crown.addLines([point(table, a0), point(table, a1), point(outer, a1), point(star, mid), point(outer, a0)])
            crown.closeSubpath()
            context.fill(crown, with: .color(tone.gem(0.25 + 0.6 * light)))
            // Star facet: a smaller triangle catching more light.
            var starFacet = Path()
            starFacet.addLines([point(table, a0), point(table, a1), point(star, mid)]); starFacet.closeSubpath()
            context.fill(starFacet, with: .color(tone.gem(0.4 + 0.55 * light)))
            if detail {
                context.stroke(crown, with: .color(.white.opacity(0.08 + 0.16 * light)), lineWidth: 0.35)
            }
            if fire && i % 3 == 1 {
                // Dispersion: a sliver of spectral colour on a few facets.
                context.fill(starFacet, with: .color(Color(hue: Double(i) / Double(n), saturation: 0.7, brightness: 1).opacity(0.45)))
            }
        }
        var tablePath = Path()
        tablePath.addLines((0..<n).map { point(table, Double($0) / Double(n) * .pi * 2 - .pi / 2 - .pi / 8) })
        tablePath.closeSubpath()
        context.fill(tablePath, with: .linearGradient(Gradient(colors: [tone.gem(0.98), tone.gem(0.62)]),
                                                      startPoint: CGPoint(x: c.x - table, y: c.y - table), endPoint: CGPoint(x: c.x + table, y: c.y + table)))
        context.stroke(Path(ellipseIn: r), with: .linearGradient(Gradient(colors: [.white.opacity(0.7), tone.gem(0.2)]),
                                                                  startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)),
                       lineWidth: 0.5)
        let bloom = CGRect(x: c.x - table * 0.9, y: c.y - table * 0.95, width: table * 0.9, height: table * 0.6)
        context.fill(Path(ellipseIn: bloom), with: .radialGradient(Gradient(colors: [.white.opacity(0.85), .white.opacity(0)]),
                                                                   center: CGPoint(x: bloom.midX, y: bloom.midY), startRadius: 0, endRadius: bloom.width * 0.6))
    }

    /// An emerald cut: a cut-corner rectangle stepped down in three rings to a
    /// flat table, each step lit by its own edge.
    static func step(_ context: inout GraphicsContext, in r: CGRect, tone: ForgeTone) {
        shadow(&context, under: r)
        let body = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.14)
        let corner = body.height * 0.26
        let outline = [CGPoint(x: body.minX + corner, y: body.minY), CGPoint(x: body.maxX - corner, y: body.minY),
                       CGPoint(x: body.maxX, y: body.minY + corner), CGPoint(x: body.maxX, y: body.maxY - corner),
                       CGPoint(x: body.maxX - corner, y: body.maxY), CGPoint(x: body.minX + corner, y: body.maxY),
                       CGPoint(x: body.minX, y: body.maxY - corner), CGPoint(x: body.minX, y: body.minY + corner)]
        var ring = outline
        let steps = 3, depth = body.height * 0.11
        for s in 0..<steps {
            let next = PrestigeOutline.inset(ring, by: depth)
            for i in ring.indices {
                let j = (i + 1) % ring.count
                let e = PrestigeLight.exposure(PrestigeOutline.normal(ring[i], ring[j]))
                // Steps face down into the stone, so the lit side is the far one.
                let light = (1 - e) * 0.7 + 0.12 + Double(s) * 0.06
                context.fill(PrestigeOutline.path([ring[i], ring[j], next[j], next[i]]), with: .color(tone.gem(light)))
            }
            ring = next
        }
        context.fill(PrestigeOutline.path(ring), with: .linearGradient(Gradient(colors: [tone.gem(0.92), tone.gem(0.55)]),
                                                                        startPoint: CGPoint(x: body.minX, y: body.minY), endPoint: CGPoint(x: body.maxX, y: body.maxY)))
        context.stroke(PrestigeOutline.path(outline), with: .color(.white.opacity(0.35)), lineWidth: 0.5)
    }
}

/// The rank's ornaments: parts that sit behind the plate (so only what
/// reaches past it shows) and parts that sit in front of the gem.
enum RankOrnaments {
    static func back(_ context: inout GraphicsContext, size: CGSize, style: LevelPrestige) {
        let m = style.material, stage = style.stage
        let gem = RankLayout.gemCenter(in: size)
        switch stage {
        case 4:
            // Nova: a four-point star whose points pass the rim.
            for (a, b, c) in PrestigeOutline.star(center: gem, long: size.height * 0.5 + 13, short: 36, waist: 10) {
                var facet = Path(); facet.addLines([a, b, c]); facet.closeSubpath()
                let mid = CGPoint(x: (b.x + c.x) / 2 - a.x, y: (b.y + c.y) / 2 - a.y)
                let l = max(0.001, hypot(mid.x, mid.y))
                context.fill(facet, with: .color(m.metal.metal(PrestigeLight.exposure(CGVector(dx: mid.x / l, dy: mid.y / l)))))
            }
        case 7, 8:
            // Wings: small on Celestial, swept on Eternal.
            let length = RankOrnaments.wingLength(stage), count = stage == 8 ? 4 : 3
            for side: CGFloat in [-1, 1] {
                let anchor = CGPoint(x: side < 0 ? 7 : size.width - 7, y: size.height * 0.4)
                for feather in PrestigeOutline.wing(at: anchor, side: side, length: length, feathers: count).reversed() {
                    forged(&context, outline: feather, tone: m.metal, inset: stage == 8 ? 1.3 : 1)
                }
            }
        default: break
        }
        if stage >= 6 {
            // Crown on the top edge; the Celestial arch rises behind it.
            let x = size.width / 2
            if stage >= 7 {
                var band = Path()
                band.move(to: CGPoint(x: size.width * 0.22, y: 2))
                band.addQuadCurve(to: CGPoint(x: size.width * 0.78, y: 2), control: CGPoint(x: x, y: -21))
                context.stroke(band.offsetBy(dx: 0, dy: 1), with: .color(.black.opacity(0.5)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
                context.stroke(band, with: .linearGradient(Gradient(colors: [m.metal.metal(0.95), m.metal.metal(0.55), m.metal.metal(0.3)]),
                                                          startPoint: CGPoint(x: x, y: -12), endPoint: CGPoint(x: x, y: 2)),
                               style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                context.stroke(band.offsetBy(dx: 0, dy: -0.6), with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
            }
            ForgedCrown.draw(&context, crown(in: size), material: m, detail: false)
        }
        if stage == 1 {
            orbitRing(&context, center: gem, material: m, front: false)
        }
    }

    static func front(_ context: inout GraphicsContext, size: CGSize, style: LevelPrestige) {
        if style.stage == 1 {
            orbitRing(&context, center: RankLayout.gemCenter(in: size), material: style.material, front: true)
        }
    }

    static func wingLength(_ stage: Int) -> CGFloat { stage == 8 ? 27 : 17 }

    /// The crown on the top edge of the compact badge, shared with its signature.
    static func crown(in size: CGSize) -> ForgedCrown.Frame {
        ForgedCrown.Frame(x: size.width / 2, base: 2, width: 32, height: 20, simple: true)
    }

    /// Orbit's ring, tilted around the gem; its near half crosses over the gem.
    static let orbitTilt = -0.32
    static let orbitRadii = CGSize(width: 27, height: 8.5)
    static func orbitRing(_ context: inout GraphicsContext, center c: CGPoint, material m: RankMaterial, front: Bool) {
        var ring = context
        ring.translateBy(x: c.x, y: c.y)
        ring.rotate(by: .radians(orbitTilt))
        var arc = Path()
        let rect = CGRect(x: -orbitRadii.width, y: -orbitRadii.height, width: orbitRadii.width * 2, height: orbitRadii.height * 2)
        // The near half is the lower one.
        arc.addArc(center: .zero, radius: 1, startAngle: .degrees(front ? 0 : 180), endAngle: .degrees(front ? 180 : 360), clockwise: false)
        arc = arc.applying(CGAffineTransform(scaleX: rect.width / 2, y: rect.height / 2))
        ring.stroke(arc.offsetBy(dx: 0, dy: 0.8), with: .color(.black.opacity(0.45)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        ring.stroke(arc, with: .linearGradient(Gradient(colors: [m.metal.metal(0.9), m.metal.metal(0.45)]),
                                               startPoint: CGPoint(x: 0, y: -rect.height / 2), endPoint: CGPoint(x: 0, y: rect.height / 2)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
        ring.stroke(arc.offsetBy(dx: 0, dy: -0.5), with: .color(.white.opacity(front ? 0.35 : 0.2)), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
    }

    /// A small solid piece of metal: beveled edge, lit face.
    static func forged(_ context: inout GraphicsContext, outline: [CGPoint], tone: ForgeTone, inset: CGFloat) {
        let inner = PrestigeOutline.inset(outline, by: inset)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.2))
            layer.fill(PrestigeOutline.path(outline).offsetBy(dx: 0, dy: 1), with: .color(.black.opacity(0.45)))
        }
        PrestigeBevel.band(&context, outer: outline, inner: inner, style: tone)
        let ys = inner.map(\.y)
        context.fill(PrestigeOutline.path(inner), with: .linearGradient(Gradient(colors: [tone.metal(0.85), tone.metal(0.45)]),
                                                                         startPoint: CGPoint(x: 0, y: ys.min() ?? 0), endPoint: CGPoint(x: 0, y: ys.max() ?? 0)))
        context.stroke(PrestigeOutline.path(outline), with: .color(.black.opacity(0.45)), lineWidth: 0.5)
        PrestigeBevel.glint(&context, outline, inset: 0.4, strength: 0.8)
    }
}
