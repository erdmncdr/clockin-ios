import SwiftUI

/// Curves for the level-up card. `t` is seconds since the card appeared; a
/// still card (Reduce Motion, Low Power Mode) is drawn at `still`, where every
/// entrance has finished and only the resting light is left.
enum LevelUpCurve {
    static let still = 7.0
    static func ramp(_ t: Double, _ from: Double, _ to: Double) -> Double {
        max(0, min(1, (t - from) / (to - from)))
    }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func easeIn(_ x: Double) -> Double { x * x * x }
    static func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    /// Overshoots a little before settling, for things that land.
    static func land(_ x: Double) -> Double {
        let c = 1.7
        return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2)
    }
    /// How far into the hush before the impact, 0 to 1; 0 once it has landed.
    static func hush(_ t: Double) -> Double {
        t < LevelUpTiming.impact ? ramp(t, LevelUpTiming.impact - LevelUpTiming.hush, LevelUpTiming.impact) : 0
    }
    /// The charge's pulse: a kick on each beat that dies away, harder as the
    /// beats quicken.
    static func pulse(_ t: Double) -> Double {
        let beats = LevelUpTiming.pulses
        var sum = 0.0
        for (i, beat) in beats.enumerated() where t >= beat && t < LevelUpTiming.impact {
            sum += (0.5 + 0.5 * Double(i) / Double(beats.count - 1)) * exp(-(t - beat) * 12)
        }
        return sum
    }
    /// The stage's jolt after a strike: down first, then a shake that is gone
    /// in half a second.
    static func shake(after post: Double, strength: Double) -> CGSize {
        guard post >= 0, post < 0.7 else { return .zero }
        let decay = strength * exp(-post * 6.5)
        return CGSize(width: 10 * decay * sin(post * 52), height: 7 * decay * cos(post * 39))
    }
    /// How dark the screen has gone round the crest, 0 to 1. It closes in
    /// through the second half of the charge, is deepest at the end of the
    /// hush and is gone the moment the strike lands.
    static func dark(_ t: Double) -> Double {
        guard t < LevelUpTiming.impact else { return 0 }
        let closing = ramp(t, LevelUpTiming.impact * 0.25, LevelUpTiming.impact - LevelUpTiming.hush)
        return 0.65 * easeInOut(closing) + 0.35 * easeIn(hush(t))
    }
    /// The stage trembling under the charge: a jitter that grows as it
    /// builds and stops dead for the hush.
    static func rumble(_ t: Double) -> CGSize {
        let build = ramp(t, 0.4, LevelUpTiming.impact - LevelUpTiming.hush)
        guard build > 0, build < 1 else { return .zero }
        let step = Int(t * 30), reach = 3.2 * build * build
        return CGSize(width: (noise(step, 71) - 0.5) * 2 * reach, height: (noise(step, 72) - 0.5) * 1.2 * reach)
    }
    /// The camera: it pushes slowly in on the crest through the charge, is
    /// knocked back by the strike and springs home.
    static func zoom(_ t: Double) -> Double {
        let post = t - LevelUpTiming.impact
        guard post >= 0 else {
            return 1 + 0.045 * easeIn(ramp(t, 0.1, LevelUpTiming.impact - LevelUpTiming.hush)) + 0.015 * easeIn(hush(t))
        }
        return 1 - 0.04 * exp(-post * 6) * cos(post * 10)
    }
    /// The same scatter on every run, so a replay looks identical.
    static func noise(_ i: Int, _ salt: Int) -> Double { LevelUpTiming.scatter(i, salt) }
}

/// Where the stage's pieces sit. The crest floats over a sigil on the floor;
/// with the companion shown, it stands in the light below the crest.
struct LevelUpStageLayout {
    let size: CGSize
    let companion: Bool
    var floor: CGPoint { CGPoint(x: size.width / 2, y: size.height - sigil.height - 10) }
    /// Room above the crest for what the upper ranks raise over it.
    var crest: CGPoint { CGPoint(x: size.width / 2, y: companion ? 94 : size.height * 0.44) }
    var crestRadius: CGFloat { companion ? 54 : 72 }
    /// The sigil's outer radii: the floor is seen at a low angle.
    var sigil: CGSize {
        let r = min(size.width * 0.4, 150)
        return CGSize(width: r, height: r * 0.22)
    }
    var pillarWidth: CGFloat { crestRadius * 1.2 }
}

/// The level-up stage: a sigil on the floor, a column of light, the crest and,
/// when enabled, the companion standing in the light. Drawn from `t` alone.
struct LevelUpStage: View {
    let level: Int
    let t: Double
    let companion: Bool
    let moving: Bool
    private var style: LevelPrestige { .init(level: level) }
    /// A new rank levels up in the old rank's light; the new light floods in
    /// on the second beat, under its flash.
    private var light: LevelPrestige {
        style.isMilestone && t < LevelUpTiming.rankReveal ? .init(level: max(1, level - 1)) : style
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = LevelUpStageLayout(size: proxy.size, companion: companion)
            let post = t - LevelUpTiming.impact
            let jolt = LevelUpCurve.shake(after: post, strength: 1)
            let second = style.isMilestone ? LevelUpCurve.shake(after: t - LevelUpTiming.rankReveal, strength: 0.6) : .zero
            let rumble = LevelUpCurve.rumble(t)
            ZStack {
                Canvas { context, _ in LevelUpStageArt.back(&context, layout, t: t, style: light) }
                    .modifier(StageLightBounds())
                if companion {
                    // Standing on the sigil, backlit by the column.
                    LevelUpWarrior(style: light, t: t)
                        .scaleEffect(0.86)
                        .shadow(color: light.tint.opacity(post < 0 ? 0.15 : 0.45), radius: 14)
                        .position(x: layout.floor.x, y: layout.floor.y - 81)
                }
                LevelUpCrest(level: level, t: t, radius: layout.crestRadius, moving: moving)
                    // Where the card's own light (the darkening, the flash)
                    // is centred.
                    .anchorPreference(key: LevelUpCrestAnchor.self, value: .center) {
                        LevelUpCrestAnchor.Crest(center: $0, radius: layout.crestRadius)
                    }
                    .position(layout.crest)
                Canvas { context, _ in
                    LevelUpStageArt.front(&context, layout, t: t, style: light, milestone: style.isMilestone)
                }
                .modifier(StageLightBounds())
            }
            .scaleEffect(LevelUpCurve.zoom(t), anchor: UnitPoint(x: 0.5, y: layout.crest.y / max(1, proxy.size.height)))
            .offset(x: jolt.width + second.width + rumble.width, y: jolt.height + second.height + rumble.height)
        }
        .frame(height: companion ? 396 : 300)
        .accessibilityHidden(true)
    }
}

/// The crest's centre and radius, for light the card draws over the stage.
struct LevelUpCrestAnchor: PreferenceKey {
    struct Crest {
        let center: Anchor<CGPoint>
        let radius: CGFloat
    }
    static let defaultValue: Crest? = nil
    static func reduce(value: inout Crest?, nextValue: () -> Crest?) { value = value ?? nextValue() }
}

/// Where the stage's light may reach. Rays and shock rings run past the top
/// of the stage, where the card begins; they fade out before that edge
/// instead of ending in a straight line. Below, the canvas reaches into the
/// title so sparks and the floor ring are not cut off either.
private struct StageLightBounds: ViewModifier {
    static let fade: CGFloat = 34
    static let below: CGFloat = 44
    func body(content: Content) -> some View {
        content
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: Self.fade)
                    Color.black
                }
            }
            .padding(.bottom, -Self.below)
            .allowsHitTesting(false)
    }
}

/// Everything on the stage that is light rather than metal. All of it is
/// added onto what is behind it, so overlapping light brightens instead of
/// covering.
enum LevelUpStageArt {
    private typealias C = LevelUpCurve

    static func back(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, style: LevelPrestige) {
        let post = t - LevelUpTiming.impact
        let charge = C.ramp(t, 0.05, LevelUpTiming.impact)
        ctx.blendMode = .plusLighter
        // Energy gathering where the crest is about to light, kicking on each
        // pulse; in the hush it is drawn in tight round the rim.
        if post < 0.35 {
            let hush = C.easeIn(C.hush(t))
            let g = post < 0 ? min(1, charge * charge + 0.3 * C.pulse(t) + hush) : pow(1 - post / 0.35, 2)
            let r = l.crestRadius * ((1.1 + 0.9 * charge) * (1 - hush) + 1.12 * hush)
            ctx.fill(circle(l.crest, r), with: .radialGradient(
                Gradient(colors: [style.tint.opacity(0.5 * g), style.tint.opacity(0.12 * g), .clear]),
                center: l.crest, startRadius: 0, endRadius: r))
        }
        floorGlow(&ctx, l, t: t, post: post, charge: charge, style: style)
        rays(&ctx, l, t: t, post: post, style: style)
        LevelUpAura.draw(&ctx, .under, l, t: t, since: since(t, style), style: style)
        pillar(&ctx, l, t: t, post: post, charge: charge, style: style)
        arcs(&ctx, l, t: t, style: style)
        sigil(&ctx, l, t: t, post: post, style: style, front: false)
    }

    static func front(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, style: LevelPrestige, milestone: Bool) {
        let post = t - LevelUpTiming.impact
        ctx.blendMode = .plusLighter
        sigil(&ctx, l, t: t, post: post, style: style, front: true)
        gather(&ctx, l, t: t, style: style)
        embers(&ctx, l, t: t, post: post, style: style)
        LevelUpAura.draw(&ctx, .over, l, t: t, since: since(t, style), style: style)
        burst(&ctx, l, after: post, style: style, sparks: 60, strength: 1, salt: 0)
        if milestone {
            burst(&ctx, l, after: t - LevelUpTiming.rankReveal, style: style, sparks: 32, strength: 0.8, salt: 100)
        }
    }

    /// Seconds since the rank being shown took over the stage: the impact
    /// for a level, the second beat for a new rank. Negative before that.
    private static func since(_ t: Double, _ style: LevelPrestige) -> Double {
        let milestone = style.isMilestone && t >= LevelUpTiming.rankReveal
        return t - (milestone ? LevelUpTiming.rankReveal : LevelUpTiming.impact)
    }

    // MARK: Behind the crest

    private static func floorGlow(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, post: Double, charge: Double,
                                  style: LevelPrestige) {
        // The floor's light is pulled up into the crest during the hush.
        let heat = post < 0 ? (0.2 + 0.5 * charge) * (1 - 0.8 * C.hush(t))
            : 0.45 + 0.55 * exp(-post * 1.5)
        ellipseGlow(&ctx, center: l.floor, radius: l.sigil.width * 1.25, squash: 0.24,
                    colors: [style.tint.opacity(0.4 * heat), style.tint.opacity(0.12 * heat), .clear])
    }

    /// Rays behind the crest; they spin up at the impact and then turn slowly,
    /// dimming so the rank's own light is what stays.
    private static func rays(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, post: Double, style: LevelPrestige) {
        let appear = C.easeOut(C.ramp(post, 0, 0.5))
        guard appear > 0 else { return }
        let spin = 0.05 * t + 0.8 * (1 - exp(-post * 2.2))
        let flare = 0.45 + 1.85 * exp(-post * 2.2)
        let count = 16, r0 = l.crestRadius * 0.6
        for i in 0..<count {
            let long = i.isMultiple(of: 2)
            let a = spin + Double(i) / Double(count) * 2 * .pi
            let length = l.crestRadius * (long ? 2.4 : 1.7) * appear * (1 + 0.08 * sin(t * 1.3 + Double(i) * 1.7))
            let half = long ? 0.05 : 0.032
            var ray = Path()
            ray.move(to: point(l.crest, a - half, r0))
            ray.addLine(to: point(l.crest, a - half * 1.5, r0 + length))
            ray.addLine(to: point(l.crest, a + half * 1.5, r0 + length))
            ray.addLine(to: point(l.crest, a + half, r0))
            ray.closeSubpath()
            ctx.fill(ray, with: .radialGradient(
                Gradient(colors: [style.tint.opacity(0.28 * flare * appear), style.tint.opacity(0.07 * appear), .clear]),
                center: l.crest, startRadius: r0, endRadius: r0 + length))
        }
    }

    /// A thread of light finds the crest during the charge; at the impact it
    /// opens into a column that shoots off the top of the stage.
    private static func pillar(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, post: Double, charge: Double, style: LevelPrestige) {
        let floorY = l.floor.y
        if post < 0 {
            let a = C.ramp(charge, 0.45, 1)
            guard a > 0 else { return }
            let flicker = 0.7 + 0.3 * sin(t * 70)
            // In the hush the thread pulls taut: thicker and steady.
            let hush = C.hush(t)
            var line = Path()
            line.move(to: CGPoint(x: l.floor.x, y: floorY))
            line.addLine(to: CGPoint(x: l.floor.x, y: l.crest.y))
            ctx.stroke(line, with: .color(style.highlight.opacity(min(1, 0.75 * a * (flicker * (1 - hush) + hush) + 0.25 * hush))),
                       lineWidth: 1 + 1.6 * a + 1.8 * hush)
            return
        }
        let rise = C.easeOut(C.ramp(post, 0, 0.2))
        let top = floorY - (floorY + 10) * rise
        let width = l.pillarWidth * (0.3 + 0.7 * rise) * (1 + 0.8 * exp(-post * 4)) * (1 + 0.05 * sin(t * 1.8))
        let glow = 0.62 + 0.38 * exp(-post * 1.4)
        let rect = CGRect(x: l.floor.x - width / 2, y: top, width: width, height: floorY - top)
        let fade = { (layer: inout GraphicsContext, r: CGRect) in
            // The column thins out toward the top of the stage.
            layer.blendMode = .destinationOut
            layer.fill(Path(r), with: .linearGradient(Gradient(colors: [.black, .clear]),
                                                      startPoint: CGPoint(x: 0, y: -10),
                                                      endPoint: CGPoint(x: 0, y: floorY * 0.42)))
        }
        ctx.drawLayer { layer in
            let halo = rect.insetBy(dx: -width * 0.7, dy: 0)
            layer.fill(Path(halo), with: .linearGradient(Gradient(colors: [.clear, style.tint.opacity(0.1 * glow), .clear]),
                                                         startPoint: CGPoint(x: halo.minX, y: 0), endPoint: CGPoint(x: halo.maxX, y: 0)))
            fade(&layer, halo)
        }
        ctx.drawLayer { layer in
            layer.fill(Path(rect), with: .linearGradient(Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: style.tint.opacity(0.13 * glow), location: 0.18),
                .init(color: style.tint.opacity(0.36 * glow), location: 0.4),
                .init(color: .white.opacity(0.62 * glow), location: 0.5),
                .init(color: style.tint.opacity(0.36 * glow), location: 0.6),
                .init(color: style.tint.opacity(0.13 * glow), location: 0.82),
                .init(color: .clear, location: 1),
            ]), startPoint: CGPoint(x: rect.minX, y: 0), endPoint: CGPoint(x: rect.maxX, y: 0)))
            fade(&layer, rect)
        }
    }

    /// Arcs of energy that crack into the crest during the charge, from the
    /// sigil and out of the air round it: one on every pulse and ever more as
    /// it builds, some of them forking, none in the hush.
    private static func arcs(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, style: LevelPrestige) {
        let end = LevelUpTiming.impact - LevelUpTiming.hush, life = 0.1
        guard t > LevelUpTiming.pulses[0], t < end + life else { return }
        // The bolts fork afresh every 25 ms, so they crackle while they live.
        let fork = Int(t * 40)
        for (i, start) in LevelUpTiming.strikes.enumerated() where start < end {
            let age = t - start
            guard age >= 0, age < life else { continue }
            let fade = 1 - age / life
            let a = C.noise(i, 42) * 2 * .pi
            // Every third bolt cracks out of the air onto the crest's rim.
            let fromAir = i % 3 == 2
            let from = fromAir
                ? CGPoint(x: l.crest.x + cos(a) * l.crestRadius * 2.2, y: l.crest.y + sin(a) * l.crestRadius * 2.2)
                : CGPoint(x: l.floor.x + cos(a) * l.sigil.width, y: l.floor.y + sin(a) * l.sigil.height)
            let target = fromAir
                ? CGPoint(x: l.crest.x + cos(a) * l.crestRadius * 1.05, y: l.crest.y + sin(a) * l.crestRadius * 1.05)
                : CGPoint(x: l.crest.x, y: l.crest.y + l.crestRadius * 0.7)
            let dx = target.x - from.x, dy = target.y - from.y
            let length = max(1, hypot(dx, dy))
            var bolt = Path()
            bolt.move(to: from)
            for k in 1..<8 {
                let f = CGFloat(k) / 8
                let jitter = (CGFloat(C.noise(i * 31 + k, fork)) - 0.5) * 24 * sin(f * .pi)
                bolt.addLine(to: CGPoint(x: from.x + dx * f - dy / length * jitter, y: from.y + dy * f + dx / length * jitter))
            }
            bolt.addLine(to: target)
            // Half of the long bolts throw a short fork off their middle.
            if !fromAir, i.isMultiple(of: 2) {
                let f: CGFloat = 0.45, side: CGFloat = C.noise(i, 43) > 0.5 ? 1 : -1
                var p = CGPoint(x: from.x + dx * f, y: from.y + dy * f)
                bolt.move(to: p)
                for k in 1...3 {
                    let jitter = (CGFloat(C.noise(i * 17 + k, fork)) - 0.5) * 10
                    p = CGPoint(x: p.x - dy / length * 9 * side + dx / length * (7 + jitter),
                                y: p.y + dx / length * 9 * side + dy / length * (7 + jitter))
                    bolt.addLine(to: p)
                }
            }
            ctx.stroke(bolt, with: .color(style.tint.opacity(0.4 * fade)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            ctx.stroke(bolt, with: .color(.white.opacity(0.9 * fade)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
    }

    /// An astrolabe drawn on the floor: a ticked outer ring, a dashed ring of
    /// star marks turning the other way and an inner ring, joined by spokes.
    /// It draws itself round during the charge and flares at the impact.
    private static func sigil(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, post: Double, style: LevelPrestige, front: Bool) {
        let drawn = C.easeInOut(C.ramp(t, 0.02, LevelUpTiming.impact - LevelUpTiming.hush))
        guard drawn > 0 else { return }
        // It beats with the pulse and dims in the hush.
        let lit = post < 0 ? (0.5 + 0.2 * min(1, C.pulse(t))) * (1 - 0.6 * C.hush(t)) : 0.5 + 0.5 * exp(-post * 1.8)
        let depth = front ? 1.0 : 0.5
        let color = style.highlight.opacity(0.6 * lit * depth)
        let glow = style.tint.opacity(0.22 * lit * depth)
        let rx = l.sigil.width, squash = l.sigil.height / l.sigil.width
        func p(_ a: Double, _ r: CGFloat) -> CGPoint {
            CGPoint(x: l.floor.x + cos(a) * r, y: l.floor.y + sin(a) * r * squash)
        }
        func visible(_ a: Double) -> Bool { (sin(a) >= 0) == front }
        let start = -Double.pi / 2
        func ring(_ r: CGFloat, width: CGFloat, keep: ((Double) -> Bool)? = nil) {
            let path: Path
            if let keep {
                var dashes = Path()
                var open = false
                let end = Int(720 * drawn)
                for sample in LevelUpSigilGeometry.dashSamples.prefix(end + 1) {
                    if (sample.point.y >= 0) == front && keep(sample.angle) {
                        let point = CGPoint(x: l.floor.x + sample.point.x * r,
                                            y: l.floor.y + sample.point.y * r * squash)
                        if open { dashes.addLine(to: point) } else { dashes.move(to: point); open = true }
                    } else {
                        open = false
                    }
                }
                path = dashes
            } else {
                path = LevelUpSigilGeometry.ring(drawn: drawn, front: front)
                    .applying(CGAffineTransform(a: r, b: 0, c: 0, d: r * squash, tx: l.floor.x, ty: l.floor.y))
            }
            ctx.stroke(path, with: .color(glow), lineWidth: width * 4)
            ctx.stroke(path, with: .color(color), lineWidth: width)
        }
        let outerTurn = 0.1 * t, innerTurn = -0.16 * t
        // The star marks on the dashed ring: twelve, a larger one every third.
        let markCount = 12
        let markAngles = (0..<markCount).map { start + innerTurn + Double($0) / Double(markCount) * 2 * .pi }
        func markSize(_ k: Int) -> CGFloat { k.isMultiple(of: 3) ? 3.4 : 2.2 }
        let markCenters = markAngles.map { p($0, rx * 0.7) }
        /// How close a line may come to a mark, on screen, so marks always sit
        /// in clear space even where the floor's perspective squeezes the ring.
        func clear(of point: CGPoint) -> Bool {
            for (k, c) in markCenters.enumerated() {
                let d = hypot(point.x - c.x, point.y - c.y)
                if d < markSize(k) + 2.2 { return false }
            }
            return true
        }
        // Every sample in a dash has the same clearance decision. Keep the
        // exact turn and screen-space test, but do it only once per dash.
        var dashClearance: [Double: Bool] = [:]
        ring(rx, width: front ? 1.3 : 1)
        // Dashes every tenth of a mark step, with a gap centred on every
        // multiple of ten degrees, so each mark (every thirty) sits in the
        // middle of a gap rather than on a dash.
        ring(rx * 0.7, width: front ? 1 : 0.8) { a in
            let degrees = (a - start - innerTurn) * 180 / .pi
            let phase = (degrees.truncatingRemainder(dividingBy: 10) + 10).truncatingRemainder(dividingBy: 10)
            guard phase >= 3, phase <= 7 else { return false }
            // A dash is kept or dropped whole, so none is left as a sliver
            // beside a mark.
            let dash = (degrees / 10).rounded(.down) * 10
            if let clear = dashClearance[dash] { return clear }
            let ends = [3.0, 5.0, 7.0].map { start + innerTurn + (dash + $0) * .pi / 180 }
            let clear = ends.allSatisfy { clear(of: p($0, rx * 0.7)) }
            dashClearance[dash] = clear
            return clear
        }
        ring(rx * 0.38, width: front ? 1.1 : 0.9)
        var ticks = Path()
        for k in 0..<72 where Double(k) / 72 <= drawn {
            let a = start + outerTurn + Double(k) / 72 * 2 * .pi
            guard visible(a) else { continue }
            let long = k.isMultiple(of: 6)
            ticks.move(to: p(a, rx * (long ? 1.08 : 1.0)))
            ticks.addLine(to: p(a, rx * (long ? 0.86 : 0.93)))
        }
        ctx.stroke(ticks, with: .color(color), lineWidth: 0.8)
        var marks = Path()
        for k in 0..<markCount where Double(k) / Double(markCount) <= drawn {
            let a = markAngles[k]
            guard visible(a) else { continue }
            let c = p(a, rx * 0.7), s = markSize(k)
            marks.move(to: CGPoint(x: c.x, y: c.y - s))
            marks.addLine(to: CGPoint(x: c.x + s * 0.55, y: c.y))
            marks.addLine(to: CGPoint(x: c.x, y: c.y + s))
            marks.addLine(to: CGPoint(x: c.x - s * 0.55, y: c.y))
            marks.closeSubpath()
            if k.isMultiple(of: 2) {
                // Spokes of the rete, from the inner ring to just short of the
                // mark: where perspective squeezes the ring they stop sooner.
                var reach: CGFloat = 0.66
                while reach > 0.45, !clear(of: p(a, rx * reach)) { reach -= 0.01 }
                marks.move(to: p(a, rx * 0.4))
                marks.addLine(to: p(a, rx * reach))
            }
        }
        ctx.fill(marks, with: .color(color))
        ctx.stroke(marks, with: .color(color), lineWidth: 0.7)
    }

    // MARK: In front of the crest

    /// Stardust spiralling in to the crest during the charge, speeding up as
    /// it arrives. The last of it is swallowed halfway through the hush.
    private static func gather(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, style: LevelPrestige) {
        let end = LevelUpTiming.impact - LevelUpTiming.hush / 2
        guard t < end else { return }
        for i in 0..<80 {
            let p = C.ramp(t, 0.5 * end * C.noise(i, 1), end)
            guard p > 0, p < 1 else { continue }
            let r0 = l.crestRadius * (1.6 + 1.5 * C.noise(i, 2))
            let a0 = C.noise(i, 3) * 2 * .pi
            func at(_ q: Double) -> CGPoint {
                let e = C.easeIn(q)
                let r = r0 * (1 - e) + l.crestRadius * 0.2 * e
                let a = a0 + 1.5 * e
                return CGPoint(x: l.crest.x + cos(a) * r, y: l.crest.y + sin(a) * r * 0.85)
            }
            var streak = Path()
            streak.move(to: at(max(0, p - 0.1)))
            streak.addLine(to: at(p))
            let bright = C.noise(i, 4) > 0.7
            ctx.stroke(streak, with: .color((bright ? Color.white : style.tint).opacity(min(1, p * 4) * (bright ? 1 : 0.75))),
                       style: StrokeStyle(lineWidth: bright ? 1.8 : 1.2, lineCap: .round))
        }
    }

    /// The impact: one soft bloom (never a strobe), a shock ring, a ring on
    /// the floor and sparks thrown out with drag.
    private static func burst(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, after post: Double, style: LevelPrestige,
                              sparks: Int, strength: Double, salt: Int) {
        guard post >= 0, post < 1.6 else { return }
        let c = l.crest
        let f = C.ramp(post, 0, 0.35)
        if f < 1 {
            let r = l.crestRadius * (0.9 + 2.8 * C.easeOut(f))
            let a = strength * pow(1 - f, 2)
            ctx.fill(circle(c, r), with: .radialGradient(
                Gradient(colors: [.white.opacity(0.85 * a), style.tint.opacity(0.4 * a), .clear]),
                center: c, startRadius: 0, endRadius: r))
        }
        let s = C.ramp(post, 0, 0.75)
        if s < 1 {
            let r = l.crestRadius * (0.95 + 3.1 * C.easeOut(s))
            let a = strength * pow(1 - s, 1.6)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .color(style.tint.opacity(0.75 * a)), lineWidth: 1 + 8 * pow(1 - s, 2))
            let inner = r * 0.97
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - inner, y: c.y - inner, width: inner * 2, height: inner * 2)),
                       with: .color(.white.opacity(0.55 * a)), lineWidth: 1)
        }
        let g = C.ramp(post, 0.03, 0.85)
        if g < 1 {
            let rx = l.sigil.width * (0.2 + 1.3 * C.easeOut(g))
            let ry = rx * l.sigil.height / l.sigil.width
            ctx.stroke(Path(ellipseIn: CGRect(x: l.floor.x - rx, y: l.floor.y - ry, width: rx * 2, height: ry * 2)),
                       with: .color(style.highlight.opacity(0.7 * strength * pow(1 - g, 1.5))), lineWidth: 1 + 3 * (1 - g))
        }
        for i in 0..<sparks {
            let life = 0.5 + 0.75 * C.noise(i, salt + 5)
            let tau = post - 0.03 * C.noise(i, salt + 6)
            guard tau > 0, tau < life else { continue }
            let a = C.noise(i, salt + 7) * 2 * .pi
            let speed = 260 + 420 * C.noise(i, salt + 8), k = 3.4
            func at(_ q: Double) -> CGPoint {
                let d = l.crestRadius * 0.5 + speed * (1 - exp(-k * q)) / k
                return CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d + 70 * q * q)
            }
            let fade = 1 - tau / life
            var streak = Path()
            streak.move(to: at(max(0, tau - 0.045)))
            streak.addLine(to: at(tau))
            let hot = C.noise(i, salt + 9) > 0.6
            ctx.stroke(streak, with: .color((hot ? Color.white : style.tint).opacity(fade * strength)),
                       style: StrokeStyle(lineWidth: 0.6 + 2 * fade, lineCap: .round))
        }
    }

    /// Motes rising through the column and off the sigil: dragged up fast
    /// through the charge, gone in the hush, then drifting after the impact.
    private static func embers(_ ctx: inout GraphicsContext, _ l: LevelUpStageLayout, t: Double, post: Double, style: LevelPrestige) {
        let fade = post < 0 ? 0.8 * C.ramp(t, 0.5, LevelUpTiming.impact - LevelUpTiming.hush) * (1 - C.hush(t))
            : C.ramp(post, 0.15, 0.9)
        guard fade > 0 else { return }
        let pace = post < 0 ? 2.4 : 1
        let bottom = l.floor.y - 4
        for i in 0..<32 {
            let period = 2.4 + 2.2 * C.noise(i, 11)
            let phase = (t * pace / period + C.noise(i, 12)).truncatingRemainder(dividingBy: 1)
            // Motes near the middle rise the whole height; outer ones stay low.
            let spread = pow(C.noise(i, 13), 1.6)
            let side = C.noise(i, 14) > 0.5 ? 1.0 : -1.0
            let height = (bottom + 10) * (1 - 0.7 * spread)
            let x = l.floor.x + side * spread * l.sigil.width * 0.9 + sin(t * 1.1 + Double(i)) * 5
            let y = bottom - height * phase
            let size = 0.7 + 1.6 * C.noise(i, 15)
            let a = sin(phase * .pi) * fade * (0.45 + 0.55 * C.noise(i, 16))
            let p = CGPoint(x: x, y: y)
            if size > 1.7 {
                ctx.fill(circle(p, size * 3.5), with: .radialGradient(Gradient(colors: [style.tint.opacity(0.35 * a), .clear]),
                                                                      center: p, startRadius: 0, endRadius: size * 3.5))
            }
            ctx.fill(circle(p, size), with: .color(style.highlight.opacity(a)))
        }
    }

    // MARK: Helpers

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private static func point(_ c: CGPoint, _ angle: Double, _ r: CGFloat) -> CGPoint {
        CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
    }

    /// A radial glow flattened into an ellipse, so it lies on the floor
    /// without a hard edge.
    private static func ellipseGlow(_ ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, squash: CGFloat, colors: [Color]) {
        var layer = ctx
        layer.translateBy(x: center.x, y: center.y)
        layer.scaleBy(x: 1, y: squash)
        layer.fill(circle(.zero, radius), with: .radialGradient(Gradient(colors: colors), center: .zero,
                                                                startRadius: 0, endRadius: radius))
    }
}
