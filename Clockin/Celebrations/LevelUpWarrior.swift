import SwiftUI

/// The companion as a paladin for the level-up, in the pose MMORPG heroes
/// strike: a greatsword planted in front, both hands on the grip, wings of
/// light and a halo behind. The plate is the rank's metal made pale, the trim
/// is the rank's metal and the light is the rank's colour, so the gear rises
/// with the rank. The companion's face, a screen with two eyes of light,
/// looks out through the visor, drawn smooth to match the plate.
///
/// The armour is drawn once per rank; only the light and the energy move, so
/// the detail costs nothing while the stage animates.
struct LevelUpWarrior: View {
    let style: LevelPrestige
    let t: Double
    static let size = CGSize(width: 180, height: 210)
    /// Where the face shows, in the warrior's coordinates.
    static let face = CGRect(x: 60, y: 35, width: 60, height: 36)
    /// The helm's opening around it.
    static let visor = CGRect(x: 60, y: 35, width: 60, height: 38)

    var body: some View {
        let lit = LevelUpCurve.ramp(t - LevelUpTiming.impact, 0, 0.15)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in PaladinArt.back(&context, style, t: t, lit: lit) }
            WarriorArmor(stage: style.stage).equatable()
            Canvas { context, _ in WarriorFace.draw(&context, t: t) }
            WarriorGlass(stage: style.stage).equatable()
            Canvas { context, _ in PaladinArt.front(&context, style, t: t, lit: lit) }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

private struct WarriorArmor: View, Equatable {
    let stage: Int
    var body: some View {
        Canvas { context, _ in
            let style = LevelPrestige(level: max(1, stage * LevelPrestige.interval))
            var ground = context
            ground.addFilter(.blur(radius: 3))
            ground.fill(Path(ellipseIn: CGRect(x: 54, y: 201, width: 72, height: 9)), with: .color(.black.opacity(0.6)))
            PaladinArt.armor(&context, style)
        }
    }
}

/// What sits over the face: the visor's reflection and the circlet.
private struct WarriorGlass: View, Equatable {
    let stage: Int
    var body: some View {
        Canvas { context, _ in
            PaladinArt.glass(&context, LevelPrestige(level: max(1, stage * LevelPrestige.interval)))
        }
    }
}

/// The companion's face as the screen behind the visor: two eyes of light cut
/// as hard, level-browed slits, the look of a hero at a level-up. They
/// narrow and gather light during the charge, flare white when the level
/// lands, then burn steady, blinking only rarely.
private enum WarriorFace {
    static let eye = Color(red: 0.36, green: 0.92, blue: 1)

    static func draw(_ ctx: inout GraphicsContext, t: Double) {
        let f = LevelUpWarrior.face.insetBy(dx: 2.5, dy: 2.5)
        let screen = Path(roundedRect: f, cornerRadius: f.height * 0.44, style: .continuous)
        ctx.fill(screen, with: .linearGradient(Gradient(colors: [Color(red: 0.04, green: 0.09, blue: 0.16), Color(red: 0.01, green: 0.02, blue: 0.05)]),
                                               startPoint: CGPoint(x: f.midX, y: f.minY), endPoint: CGPoint(x: f.midX, y: f.maxY)))
        let post = t - LevelUpTiming.impact
        let charge = LevelUpCurve.ramp(t, 0.05, LevelUpTiming.impact)
        // How bright the eyes burn, and a flare that fades after the impact.
        let power = post < 0 ? 0.45 + 0.55 * charge : 0.92 + 0.08 * sin(t * 2.2)
        let flare = post < 0 ? 0 : exp(-post * 5)
        ctx.fill(screen, with: .radialGradient(Gradient(colors: [eye.opacity(0.1 + 0.12 * power + 0.2 * flare), .clear]),
                                               center: CGPoint(x: f.midX, y: f.midY + 2), startRadius: 0, endRadius: f.width * 0.6))
        let cycle = (t + 2.1).truncatingRemainder(dividingBy: 6.5)
        let open = 1 - 0.9 * (cycle < 0.12 ? CGFloat(sin(cycle / 0.12 * .pi)) : 0)
        // Narrow during the charge, full once the level lands.
        let h = (post < 0 ? 3.6 + 1.2 * CGFloat(charge) : 5.2) * open
        var eyes = Path()
        for side: CGFloat in [-1, 1] {
            let cx = f.midX + side * 13.5, cy = f.midY + 0.5
            func q(_ out: CGFloat, _ down: CGFloat) -> CGPoint { CGPoint(x: cx + side * out, y: cy + down) }
            // The top edge falls toward the nose; the lower edge is a shallow curve.
            eyes.addPath(WarriorShape.smooth([q(7, -h * 0.55), q(-6.5, h * 0.2), q(-5.5, h * 0.6), q(0, h * 0.66), q(6.2, h * 0.25)], 0.22))
        }
        var light = ctx
        light.blendMode = .plusLighter
        var soft = light
        soft.addFilter(.blur(radius: 3 + 4 * flare))
        soft.fill(eyes, with: .color(eye.opacity(0.7 * power + 0.3 * flare)))
        light.fill(eyes, with: .color(eye.opacity(power)))
        // A hot core along each slit.
        var core = light
        core.addFilter(.blur(radius: 0.8))
        core.fill(eyes.applying(CGAffineTransform(translationX: f.midX, y: f.midY + 1).scaledBy(x: 0.82, y: 0.45).translatedBy(x: -f.midX, y: -(f.midY + 1))),
                  with: .color(.white.opacity(0.5 * power + 0.5 * flare)))
    }
}

// MARK: - Light

/// Light for the armour: the key light from the upper left, as on the
/// badges; the column behind the figure as a rim light on the right; a
/// shadow cast onto whatever is behind; occlusion where a part turns away.
enum ArmorShade {
    /// A material's colours from the lit highlight to the core shadow, and the
    /// light that bounces back into the far edge.
    struct Ramp {
        let bright: Color
        let lit: Color
        let core: Color
        let bounce: Color

        init(_ bright: Color, _ lit: Color, _ core: Color, _ bounce: Color) {
            self.bright = bright; self.lit = lit; self.core = core; self.bounce = bounce
        }

        init(metal tone: ForgeTone) {
            self.init(tone.metal(0.98), tone.metal(0.66), tone.metal(0.2), tone.metal(0.45))
        }

        static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
    }

    /// A formed part: a bright band where it turns to the light, a dark core
    /// and light bounced back at the far edge. Long parts are shaded across
    /// their width, like a cylinder.
    static func part(_ ctx: inout GraphicsContext, _ path: Path, _ ramp: Ramp, polish: Double = 1,
                     rim: Color? = nil, shadow: CGFloat = 1) {
        let b = path.boundingRect
        guard b.width > 0.5, b.height > 0.5 else { return }
        if shadow > 0 { cast(&ctx, path, shadow) }
        let tall = b.height > b.width * 1.6, wide = b.width > b.height * 1.6
        let start: CGPoint
        let end: CGPoint
        if tall {
            start = CGPoint(x: b.minX, y: b.midY - b.width * 0.3)
            end = CGPoint(x: b.maxX, y: b.midY + b.width * 0.3)
        } else if wide {
            start = CGPoint(x: b.midX - b.height * 0.3, y: b.minY)
            end = CGPoint(x: b.midX + b.height * 0.3, y: b.maxY)
        } else {
            start = CGPoint(x: b.minX, y: b.minY)
            end = CGPoint(x: b.maxX, y: b.maxY)
        }
        let stops: [Gradient.Stop] = [
            .init(color: ramp.lit, location: 0), .init(color: ramp.bright, location: 0.2),
            .init(color: ramp.lit, location: 0.42), .init(color: ramp.core, location: 0.8),
            .init(color: ramp.bounce, location: 1),
        ]
        ctx.fill(path, with: .linearGradient(Gradient(stops: stops), startPoint: start, endPoint: end))
        light(&ctx, path, bounds: b, polish: polish, rim: rim, tall: tall)
    }

    /// Woven cloth: soft folds running down it, darker toward the hem.
    static func cloth(_ ctx: inout GraphicsContext, _ path: Path, dark: Color, light lightColor: Color, folds: Int,
                      drift: CGFloat = 0, rim: Color?, shadow: Bool = true) {
        let b = path.boundingRect
        guard b.width > 0.5, b.height > 0.5 else { return }
        if shadow { cast(&ctx, path, 1) }
        let count = max(1, folds) * 2
        let stops = (0...count).map {
            Gradient.Stop(color: $0.isMultiple(of: 2) ? dark : lightColor, location: Double($0) / Double(count))
        }
        ctx.fill(path, with: .linearGradient(Gradient(stops: stops),
                                             startPoint: CGPoint(x: b.minX + drift, y: b.minY),
                                             endPoint: CGPoint(x: b.maxX + drift, y: b.minY + b.height * 0.12)))
        ctx.fill(path, with: .linearGradient(Gradient(colors: [.black.opacity(0.05), .black.opacity(0.5)]),
                                             startPoint: CGPoint(x: b.minX, y: b.minY), endPoint: CGPoint(x: b.maxX, y: b.maxY)))
        light(&ctx, path, bounds: b, polish: 0, rim: rim, tall: false)
    }

    /// The shadow a part throws onto what is behind it.
    static func cast(_ ctx: inout GraphicsContext, _ path: Path, _ amount: CGFloat) {
        var shadow = ctx
        shadow.addFilter(.blur(radius: 2 * amount))
        shadow.fill(path.offsetBy(dx: 1.3 * amount, dy: 2.4 * amount), with: .color(.black.opacity(0.5)))
    }

    /// Occlusion, a specular spot, the lit top edge, the rim light, then the outline.
    static func light(_ ctx: inout GraphicsContext, _ path: Path, bounds b: CGRect, polish: Double, rim: Color?, tall: Bool) {
        let small = min(b.width, b.height)
        var inside = ctx
        inside.clip(to: path)
        var occlusion = inside
        occlusion.addFilter(.blur(radius: max(1, small * 0.1)))
        occlusion.stroke(path.offsetBy(dx: -1.4, dy: -2.2), with: .color(.black.opacity(0.45)), lineWidth: 3)
        if polish > 0 {
            var spec = inside
            spec.blendMode = .plusLighter
            spec.addFilter(.blur(radius: max(0.7, small * 0.07)))
            let spot = tall
                ? CGRect(x: b.minX + b.width * 0.22, y: b.minY + b.height * 0.12, width: b.width * 0.2, height: b.height * 0.42)
                : CGRect(x: b.minX + b.width * 0.16, y: b.minY + b.height * 0.1, width: b.width * 0.34, height: max(1.5, b.height * 0.16))
            spec.fill(Path(ellipseIn: spot), with: .color(.white.opacity(0.5 * polish)))
        }
        inside.stroke(path.offsetBy(dx: 0.8, dy: 1), with: .color(.white.opacity(0.26)), lineWidth: 0.9)
        if let rim {
            var back = inside
            back.blendMode = .plusLighter
            back.stroke(path.offsetBy(dx: -1.1, dy: 0.2), with: .color(rim.opacity(0.6)), lineWidth: 1.5)
        }
        ctx.stroke(path, with: .color(.black.opacity(0.62)), lineWidth: 0.8)
    }

    /// A band of the trim just inside a part's edge.
    static func edge(_ ctx: inout GraphicsContext, _ path: Path, _ trim: Ramp, width: CGFloat = 3) {
        let b = path.boundingRect
        var band = ctx
        band.clip(to: path)
        band.stroke(path, with: .linearGradient(Gradient(colors: [trim.bright, trim.lit, trim.core]),
                                                startPoint: CGPoint(x: b.minX, y: b.minY), endPoint: CGPoint(x: b.maxX, y: b.maxY)),
                    lineWidth: width)
        ctx.stroke(path, with: .color(.black.opacity(0.62)), lineWidth: 0.8)
    }

    /// Energy along a path: a soft halo, the coloured line and a hot core.
    static func glow(_ ctx: inout GraphicsContext, _ path: Path, _ color: Color, _ strength: Double, width: CGFloat = 1.4) {
        guard strength > 0.01 else { return }
        var light = ctx
        light.blendMode = .plusLighter
        var soft = light
        soft.addFilter(.blur(radius: width * 2.2))
        soft.stroke(path, with: .color(color.opacity(0.9 * strength)), style: StrokeStyle(lineWidth: width * 2.6, lineCap: .round))
        light.stroke(path, with: .color(color.opacity(strength)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        light.stroke(path, with: .color(.white.opacity(0.7 * strength)), style: StrokeStyle(lineWidth: width * 0.4, lineCap: .round))
    }

    /// A round point of light.
    static func spark(_ ctx: inout GraphicsContext, at p: CGPoint, radius: CGFloat, _ color: Color, _ strength: Double) {
        guard strength > 0.01 else { return }
        var light = ctx
        light.blendMode = .plusLighter
        light.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                   with: .radialGradient(Gradient(colors: [.white.opacity(strength), color.opacity(0.8 * strength), .clear]),
                                         center: p, startRadius: 0, endRadius: radius))
    }
}

// MARK: - Shapes

private enum WarriorShape {
    /// A point on one side of the figure's centre line.
    static func p(_ side: CGFloat, _ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 90 + side * x, y: y) }

    static func pts(_ xs: [(CGFloat, CGFloat)]) -> [CGPoint] { xs.map { CGPoint(x: $0.0, y: $0.1) } }

    static func poly(_ points: [CGPoint]) -> Path {
        var path = Path(); path.addLines(points); path.closeSubpath(); return path
    }

    /// A closed curve through the points (Catmull-Rom), for formed plates.
    static func smooth(_ points: [CGPoint], _ tension: CGFloat = 0.5) -> Path {
        let n = points.count
        guard n > 2 else { return poly(points) }
        var path = Path()
        path.move(to: points[0])
        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n], p1 = points[i], p2 = points[(i + 1) % n], p3 = points[(i + 2) % n]
            let k = tension / 3
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) * k, y: p1.y + (p2.y - p0.y) * k)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) * k, y: p2.y - (p3.y - p1.y) * k)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    /// A rounded, tapering segment from one point to another: a limb, a feather.
    static func limb(_ a: CGPoint, _ b: CGPoint, _ wa: CGFloat, _ wb: CGFloat) -> Path {
        let dx = b.x - a.x, dy = b.y - a.y, length = max(0.001, hypot(dx, dy))
        let u = CGVector(dx: dx / length, dy: dy / length), n = CGVector(dx: -u.dy, dy: u.dx)
        func q(_ o: CGPoint, _ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(x: o.x + u.dx * along + n.dx * across, y: o.y + u.dy * along + n.dy * across)
        }
        return smooth([q(a, -wa * 0.4, 0), q(a, 0, wa / 2), q(b, 0, wb / 2), q(b, wb * 0.4, 0),
                       q(b, 0, -wb / 2), q(a, 0, -wa / 2)], 0.6)
    }

    static func oval(_ c: CGPoint, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
    }

    static func line(_ a: CGPoint, _ b: CGPoint) -> Path {
        var path = Path(); path.move(to: a); path.addLine(to: b); return path
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ f: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }
}

// MARK: - Paladin

private enum PaladinArt {
    typealias S = WarriorShape
    typealias R = ArmorShade.Ramp

    /// White gold: the rank's metal, pale, so the trim reads against it.
    static func pale(_ style: LevelPrestige) -> R {
        let tone = style.material.metal
        let pale = ForgeTone(hue: tone.hue, saturation: min(0.32, tone.saturation * 0.4))
        return R(pale.metal(1), pale.metal(0.82), pale.metal(0.4), pale.metal(0.62))
    }

    static func armor(_ ctx: inout GraphicsContext, _ style: LevelPrestige) {
        let trim = R(metal: style.material.metal), rim = style.tint, plate = pale(style)
        let face = style.material.face
        for s: CGFloat in [-1, 1] {
            let skirt = S.smooth([S.p(s, 8, 137), S.p(s, 30, 135), S.p(s, 35, 176), S.p(s, 24, 186), S.p(s, 12, 178)], 0.4)
            ArmorShade.cloth(&ctx, skirt, dark: face.metal(0.18), light: face.metal(0.42), folds: 2, rim: rim)
            ArmorShade.edge(&ctx, skirt, trim, width: 2.6)
        }
        for s: CGFloat in [-1, 1] { leg(&ctx, s, plate: plate, trim: trim, rim: rim) }
        let tabard = S.smooth(S.pts([(75, 134), (105, 134), (108, 176), (101, 199), (90, 205), (79, 199), (72, 176)]), 0.35)
        ArmorShade.cloth(&ctx, tabard, dark: face.metal(0.3), light: face.metal(0.62), folds: 2, rim: rim)
        ArmorShade.edge(&ctx, tabard, trim, width: 3.4)
        for s: CGFloat in [-1, 1] {
            let p: (CGFloat, CGFloat) -> CGPoint = { S.p(s, $0, $1) }
            for lame in [S.smooth([p(6, 150), p(28, 148), p(30, 159), p(8, 162)], 0.3),
                         S.smooth([p(4, 139), p(27, 137), p(29, 150), p(6, 153)], 0.3)] {
                ArmorShade.part(&ctx, lame, plate, polish: 1.3, rim: rim)
                ArmorShade.edge(&ctx, lame, trim, width: 2.4)
            }
        }
        chest(&ctx, style, plate: plate, trim: trim, rim: rim)
        blade(&ctx, plate: plate)
        guardAndGrip(&ctx, style, trim: trim, rim: rim)
        for s: CGFloat in [-1, 1] { arm(&ctx, s, plate: plate, trim: trim, rim: rim) }
        // The lower hand first; the upper one sits over its knuckles.
        hand(&ctx, 1, plate: plate, rim: rim)
        hand(&ctx, -1, plate: plate, rim: rim)
        ArmorShade.part(&ctx, S.oval(Grip.pommel, 11, 11), trim, polish: 1.3, rim: rim)
        RankGem.draw(&ctx, in: CGRect(x: Grip.pommel.x - 3.5, y: Grip.pommel.y - 3.5, width: 7, height: 7), material: style.material, detail: false)
        for s: CGFloat in [-1, 1] { pauldron(&ctx, s, plate: plate, trim: trim, rim: rim) }
        helmet(&ctx, plate: plate, trim: trim, rim: rim)
    }

    static func leg(_ ctx: inout GraphicsContext, _ s: CGFloat, plate: R, trim: R, rim: Color) {
        let p: (CGFloat, CGFloat) -> CGPoint = { S.p(s, $0, $1) }
        ArmorShade.part(&ctx, S.smooth([p(5, 142), p(23, 141), p(22, 158), p(14, 165), p(6, 159)]), plate, polish: 1.3, rim: rim)
        ArmorShade.part(&ctx, S.smooth([p(7, 172), p(21, 172), p(20, 190), p(8, 190)], 0.3), plate, polish: 1.3, rim: rim)
        ArmorShade.part(&ctx, S.limb(p(19, 168), p(32, 156), 5, 1.2), trim, rim: rim, shadow: 0.5)
        ArmorShade.part(&ctx, S.oval(p(14, 168), 14, 12), trim, polish: 1.4, rim: rim)
        ArmorShade.part(&ctx, S.smooth([p(3, 189), p(24, 189), p(31, 204), p(2, 204)], 0.3), plate, polish: 1.2, rim: rim, shadow: 0.6)
    }

    static func chest(_ ctx: inout GraphicsContext, _ style: LevelPrestige, plate: R, trim: R, rim: Color) {
        let shell = S.smooth(S.pts([(60, 79), (90, 83), (120, 79), (125, 97), (119, 118), (104, 128), (90, 130),
                                    (76, 128), (61, 118), (55, 97)]), 0.5)
        ArmorShade.part(&ctx, shell, plate, polish: 1.6, rim: rim)
        for s: CGFloat in [-1, 1] {
            var pec = Path()
            pec.move(to: S.p(s, 27, 95))
            pec.addQuadCurve(to: S.p(s, 2, 111), control: S.p(s, 20, 113))
            ctx.stroke(pec, with: .color(.black.opacity(0.24)), lineWidth: 1)
            ctx.stroke(pec.offsetBy(dx: 0.6, dy: 0.7), with: .color(.white.opacity(0.3)), lineWidth: 0.7)
            // Scrollwork in the trim metal.
            var scroll = Path()
            scroll.move(to: S.p(s, 9, 87))
            scroll.addCurve(to: S.p(s, 27, 91), control1: S.p(s, 13, 83), control2: S.p(s, 24, 84))
            scroll.addCurve(to: S.p(s, 21, 98), control1: S.p(s, 30, 97), control2: S.p(s, 25, 100))
            scroll.addCurve(to: S.p(s, 19, 93), control1: S.p(s, 18, 97), control2: S.p(s, 17, 94))
            ctx.stroke(scroll.offsetBy(dx: 0.5, dy: 0.7), with: .color(.black.opacity(0.4)), lineWidth: 1.4)
            ctx.stroke(scroll, with: .color(trim.bright), lineWidth: 1.1)
        }
        for y: CGFloat in [117, 123] {
            var band = Path()
            band.move(to: CGPoint(x: 78, y: y)); band.addQuadCurve(to: CGPoint(x: 102, y: y), control: CGPoint(x: 90, y: y + 3))
            ctx.stroke(band, with: .color(.black.opacity(0.22)), lineWidth: 0.9)
        }
        var star: [CGPoint] = []
        for i in 0..<8 {
            let a = Double(i) / 8 * 2 * .pi - .pi / 2
            let r: CGFloat = i.isMultiple(of: 2) ? 10 : 4.5
            star.append(CGPoint(x: 90 + CGFloat(cos(a)) * r, y: 96 + CGFloat(sin(a)) * r))
        }
        ArmorShade.part(&ctx, S.poly(star), trim, polish: 1.3, rim: rim, shadow: 0.6)
        RankGem.draw(&ctx, in: CGRect(x: 85.5, y: 91.5, width: 9, height: 9), material: style.material, detail: false)
        ArmorShade.part(&ctx, Path(roundedRect: CGRect(x: 64, y: 130, width: 52, height: 8), cornerRadius: 3), trim, polish: 1.2, rim: rim, shadow: 0.6)
    }

    /// Where the sword and the hands sit: the pommel at the top of the grip,
    /// one hand over the other below it, the guard under the lower hand.
    enum Grip {
        static let pommel = CGPoint(x: 90, y: 110)
        /// The centre line of each hand: the upper for the arm on the left.
        static func hand(_ side: CGFloat) -> CGFloat { side < 0 ? 120 : 131 }
        /// Where each forearm meets its hand.
        static func wrist(_ side: CGFloat) -> CGPoint { CGPoint(x: 90 + side * 12, y: hand(side)) }
    }

    static func blade(_ ctx: inout GraphicsContext, plate: R) {
        let path = S.poly(S.pts([(84, 144), (96, 144), (96.5, 192), (90, 207), (83.5, 192)]))
        ArmorShade.cast(&ctx, path, 1)
        let stops: [Gradient.Stop] = [
            .init(color: plate.core, location: 0), .init(color: plate.bright, location: 0.28),
            .init(color: plate.lit, location: 0.5), .init(color: plate.core, location: 0.78), .init(color: plate.lit, location: 1),
        ]
        ctx.fill(path, with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: 83.5, y: 0), endPoint: CGPoint(x: 96.5, y: 0)))
        ctx.fill(Path(roundedRect: CGRect(x: 88.3, y: 148, width: 3.4, height: 40), cornerRadius: 1.7), with: .color(.black.opacity(0.4)))
        ctx.fill(runes(), with: .color(.black.opacity(0.55)))
        ctx.stroke(path, with: .color(.black.opacity(0.62)), lineWidth: 0.8)
    }

    static func runes() -> Path {
        var path = Path()
        for i in 0..<5 {
            let y = 152 + CGFloat(i) * 8
            path.addPath(S.poly([CGPoint(x: 90, y: y - 2.4), CGPoint(x: 91.4, y: y), CGPoint(x: 90, y: y + 2.4), CGPoint(x: 88.6, y: y)]))
        }
        return path
    }

    static func guardAndGrip(_ ctx: inout GraphicsContext, _ style: LevelPrestige, trim: R, rim: Color) {
        let leather = R(R.rgb(0.42, 0.28, 0.18), R.rgb(0.28, 0.18, 0.11), R.rgb(0.1, 0.06, 0.04), R.rgb(0.18, 0.11, 0.07))
        ArmorShade.part(&ctx, Path(roundedRect: CGRect(x: 86.5, y: 112, width: 7, height: 27), cornerRadius: 2), leather, polish: 0.3, rim: rim, shadow: 0.5)
        for s: CGFloat in [-1, 1] {
            let wing = S.smooth([CGPoint(x: 90, y: 139), S.p(s, 14, 136), S.p(s, 27, 129), S.p(s, 33, 122),
                                 S.p(s, 27, 135), S.p(s, 12, 145), CGPoint(x: 90, y: 146)], 0.4)
            ArmorShade.part(&ctx, wing, trim, polish: 1.3, rim: rim, shadow: 0.7)
        }
        RankGem.draw(&ctx, in: CGRect(x: 86, y: 138, width: 8, height: 8), material: style.material, detail: false)
    }

    /// An arm in plate: the upper arm below the pauldron, a cupped elbow with
    /// a small fan, a tapering vambrace and a gauntlet cuff flaring at the wrist.
    static func arm(_ ctx: inout GraphicsContext, _ s: CGFloat, plate: R, trim: R, rim: Color) {
        let p: (CGFloat, CGFloat) -> CGPoint = { S.p(s, $0, $1) }
        ArmorShade.part(&ctx, S.limb(p(40, 90), p(41, 117), 15, 12.5), plate, polish: 1.4, rim: rim)
        var lame = Path()
        lame.move(to: p(36, 106)); lame.addQuadCurve(to: p(50, 107), control: p(43, 110))
        ctx.stroke(lame, with: .color(.black.opacity(0.3)), lineWidth: 0.9)
        ctx.stroke(lame.offsetBy(dx: 0, dy: 0.8), with: .color(.white.opacity(0.3)), lineWidth: 0.6)
        let wrist = Grip.wrist(s), elbow = p(38, 121)
        ArmorShade.part(&ctx, S.limb(elbow, S.lerp(elbow, wrist, 0.8), 12.5, 10.5), plate, polish: 1.4, rim: rim)
        let cuff = S.limb(S.lerp(elbow, wrist, 0.6), wrist, 10.5, 14)
        ArmorShade.part(&ctx, cuff, plate, polish: 1.4, rim: rim, shadow: 0.6)
        ArmorShade.edge(&ctx, cuff, trim, width: 2.2)
        ArmorShade.part(&ctx, S.smooth([p(44, 115), p(49.5, 118), p(49.5, 123), p(44, 125)], 0.5), trim, polish: 1.1, rim: rim, shadow: 0.4)
        ArmorShade.part(&ctx, S.smooth([p(36, 116), p(42, 114), p(46, 119.5), p(43, 125.5), p(36, 124.5)], 0.55), trim, polish: 1.4, rim: rim, shadow: 0.6)
    }

    /// A gauntlet closed round the grip: the back of the hand toward the
    /// viewer, the thumb over the top, the fingers curling round the far side.
    static func hand(_ ctx: inout GraphicsContext, _ s: CGFloat, plate: R, rim: Color) {
        let y = Grip.hand(s)
        let q: (CGFloat, CGFloat) -> CGPoint = { CGPoint(x: 90 + s * $0, y: y + $1) }
        for i in 0..<4 {
            let fy = y - 4.6 + CGFloat(i) * 3.1
            let x0 = min(90 - s * 6.5, 90 - s * 12.5)
            ArmorShade.part(&ctx, Path(roundedRect: CGRect(x: x0, y: fy - 1.5, width: 6, height: 3), cornerRadius: 1.5),
                            plate, polish: 0.8, rim: rim, shadow: 0.3)
        }
        let back = S.smooth([q(12, -5.5), q(0, -6.5), q(-7, -4.5), q(-8, 4), q(-1, 6.5), q(12, 5.5)], 0.5)
        ArmorShade.part(&ctx, back, plate, polish: 1.3, rim: rim)
        let knuckles = S.line(q(-4, -5), q(-5, 5))
        ctx.stroke(knuckles, with: .color(.black.opacity(0.3)), lineWidth: 0.9)
        ctx.stroke(knuckles.offsetBy(dx: -s * 0.7, dy: 0), with: .color(.white.opacity(0.35)), lineWidth: 0.6)
        ArmorShade.part(&ctx, S.limb(q(7, -5), q(-2, -7.5), 4.6, 3.6), plate, polish: 1.2, rim: rim, shadow: 0.4)
    }

    static func pauldron(_ ctx: inout GraphicsContext, _ s: CGFloat, plate: R, trim: R, rim: Color) {
        let p: (CGFloat, CGFloat) -> CGPoint = { S.p(s, $0, $1) }
        // Feathered plates sweeping up off the shoulder, behind the dome.
        ArmorShade.part(&ctx, S.limb(p(44, 88), p(65, 76), 11, 4.5), trim, polish: 1.2, rim: rim, shadow: 0.6)
        ArmorShade.part(&ctx, S.limb(p(40, 80), p(60, 61), 12, 4.5), trim, polish: 1.2, rim: rim, shadow: 0.6)
        let dome = S.smooth([p(24, 76), p(40, 67), p(56, 72), p(61, 88), p(52, 98), p(31, 94)], 0.5)
        ArmorShade.part(&ctx, dome, plate, polish: 1.6, rim: rim)
        ArmorShade.edge(&ctx, dome, trim, width: 2.8)
    }

    static func helmet(_ ctx: inout GraphicsContext, plate: R, trim: R, rim: Color) {
        ArmorShade.part(&ctx, Path(roundedRect: CGRect(x: 70, y: 77, width: 40, height: 8), cornerRadius: 4), plate, rim: rim)
        ArmorShade.part(&ctx, Path(roundedRect: CGRect(x: 72, y: 71, width: 36, height: 8), cornerRadius: 4), plate, rim: rim)
        for s: CGFloat in [-1, 1] {
            let p: (CGFloat, CGFloat) -> CGPoint = { S.p(s, $0, $1) }
            for (a, b, w) in [(p(30, 54), p(53, 34), CGFloat(10)), (p(29, 46), p(47, 16), CGFloat(11))] {
                ArmorShade.part(&ctx, S.limb(a, b, w, 4), trim, polish: 1.2, rim: rim, shadow: 0.6)
            }
        }
        let shell = S.smooth(S.pts([(56, 54), (58, 26), (74, 10), (90, 6), (106, 10), (122, 26), (124, 54), (121, 68),
                                    (106, 82), (90, 87), (74, 82), (59, 68)]), 0.5)
        ArmorShade.part(&ctx, shell, plate, polish: 1.7, rim: rim)
        for s: CGFloat in [-1, 1] {
            var cheek = Path()
            cheek.move(to: S.p(s, 31, 58)); cheek.addQuadCurve(to: S.p(s, 14, 81), control: S.p(s, 30, 75))
            ctx.stroke(cheek, with: .color(trim.bright), lineWidth: 1.4)
            ctx.stroke(cheek.offsetBy(dx: 0.5, dy: 0.8), with: .color(.black.opacity(0.35)), lineWidth: 0.8)
        }
        let opening = Path(roundedRect: LevelUpWarrior.visor, cornerRadius: 16, style: .continuous)
        ctx.fill(opening, with: .color(Color(red: 0.03, green: 0.05, blue: 0.09)))
        ctx.stroke(opening, with: .color(.black.opacity(0.75)), lineWidth: 1.4)
    }

    static func glass(_ ctx: inout GraphicsContext, _ style: LevelPrestige) {
        let v = LevelUpWarrior.visor
        var arc = Path()
        arc.move(to: CGPoint(x: v.minX + 9, y: v.minY + 17))
        arc.addQuadCurve(to: CGPoint(x: v.minX + 24, y: v.minY + 8), control: CGPoint(x: v.minX + 10, y: v.minY + 8))
        ctx.stroke(arc, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        // A circlet over the brow, its peak set with the rank's stone.
        let circlet = S.poly(S.pts([(70, 36), (76, 29), (82, 33), (90, 20), (98, 33), (104, 29), (110, 36), (106, 40), (90, 38), (74, 40)]))
        ArmorShade.part(&ctx, circlet, R(metal: style.material.metal), polish: 1.3, rim: style.tint, shadow: 0.8)
        RankGem.draw(&ctx, in: CGRect(x: 86.5, y: 26.5, width: 7, height: 7), material: style.material, detail: false)
    }

    static func back(_ ctx: inout GraphicsContext, _ style: LevelPrestige, t: Double, lit: Double) {
        let strength = 0.45 + 0.55 * lit
        var light = ctx
        light.blendMode = .plusLighter
        // A halo behind the helm, with points of light running round it.
        let halo = S.oval(CGPoint(x: 90, y: 46), 88, 88)
        var soft = light
        soft.addFilter(.blur(radius: 5))
        soft.stroke(halo, with: .color(style.tint.opacity(0.7 * strength)), lineWidth: 9)
        light.stroke(halo, with: .color(style.highlight.opacity(0.9 * strength)), lineWidth: 2.2)
        for i in 0..<3 {
            let a = t * 0.6 + Double(i) * 2 * .pi / 3
            let c = CGPoint(x: 90 + CGFloat(cos(a)) * 44, y: 46 + CGFloat(sin(a)) * 44)
            ArmorShade.spark(&ctx, at: c, radius: 4, style.tint, strength)
        }
        // Wings of light from behind the shoulders, breathing slowly.
        let flap = sin(t * 1.3) * 0.05
        for s: CGFloat in [-1, 1] {
            let anchor = S.p(s, 24, 86)
            // Long flight feathers behind, a row of shorter coverts over them.
            for (reach, width, opacity) in [(CGFloat(1), CGFloat(15), 0.42), (CGFloat(0.56), CGFloat(13), 0.58)] {
                for i in (0..<6).reversed() {
                    let f = Double(i) / 5
                    let angle = -1.32 + 1.45 * f + flap
                    let length = CGFloat(84 - 36 * f) * reach
                    let tip = CGPoint(x: anchor.x + CGFloat(cos(angle)) * s * length, y: anchor.y + CGFloat(sin(angle)) * length)
                    let feather = featherPath(anchor, tip, width: width)
                    light.fill(feather, with: .linearGradient(Gradient(colors: [.white.opacity(opacity * strength), style.tint.opacity(opacity * strength),
                                                                                style.tint.opacity(0.35 * opacity * strength)]),
                                                              startPoint: anchor, endPoint: tip))
                    light.stroke(S.line(S.lerp(anchor, tip, 0.1), S.lerp(anchor, tip, 0.85)), with: .color(.white.opacity(0.25 * strength)), lineWidth: 0.7)
                }
            }
        }
    }

    /// A feather: narrow at the quill, widest past the middle, a rounded tip.
    static func featherPath(_ base: CGPoint, _ tip: CGPoint, width: CGFloat) -> Path {
        let dx = tip.x - base.x, dy = tip.y - base.y, length = max(0.001, hypot(dx, dy))
        let n = CGVector(dx: -dy / length, dy: dx / length)
        func at(_ f: CGFloat, _ across: CGFloat) -> CGPoint {
            let c = S.lerp(base, tip, f)
            return CGPoint(x: c.x + n.dx * across, y: c.y + n.dy * across)
        }
        return S.smooth([base, at(0.3, width * 0.36), at(0.62, width / 2), at(0.9, width * 0.34), tip,
                         at(0.9, -width * 0.34), at(0.62, -width / 2), at(0.3, -width * 0.36)], 0.5)
    }

    static func front(_ ctx: inout GraphicsContext, _ style: LevelPrestige, t: Double, lit: Double) {
        guard lit > 0 else { return }
        let pulse = 0.8 + 0.2 * sin(t * 2.4)
        var light = ctx
        light.blendMode = .plusLighter
        var soft = light
        soft.addFilter(.blur(radius: 3))
        soft.fill(runes(), with: .color(style.tint.opacity(lit * pulse)))
        light.fill(runes(), with: .color(.white.opacity(0.9 * lit * pulse)))
        ArmorShade.spark(&ctx, at: CGPoint(x: 90, y: 96), radius: 10, style.tint, lit * 0.7 * pulse)
        ArmorShade.spark(&ctx, at: CGPoint(x: 90, y: 30), radius: 7, style.tint, lit * 0.6 * pulse)
    }
}

#if DEBUG
/// The warrior large on a lit stage, for choosing between looks.
struct WarriorPortrait: View {
    let level: Int
    let t: Double
    var body: some View {
        let style = LevelPrestige(level: level)
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.06)
            RadialGradient(colors: [style.tint.opacity(0.35), style.shade.opacity(0.15), .clear],
                           center: .center, startRadius: 10, endRadius: 280)
            LinearGradient(colors: [.clear, style.tint.opacity(0.22), .white.opacity(0.28), style.tint.opacity(0.22), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 170)
                .blendMode(.plusLighter)
            Ellipse()
                .fill(RadialGradient(colors: [style.tint.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 320, height: 64)
                .offset(y: 205)
            LevelUpWarrior(style: style, t: t).scaleEffect(1.9)
        }
        .ignoresSafeArea()
    }
}
#endif
