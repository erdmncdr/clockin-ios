import SwiftUI

/// The new level struck into a forged ring of the rank's metal. During the
/// charge it is dark steel holding the old level and it trembles; at the
/// impact it lights and the new number lands. On a new rank it re-forges in
/// the new rank's metal and stone on the second beat.
struct LevelUpCrest: View {
    let level: Int
    let t: Double
    let radius: CGFloat
    let moving: Bool
    private typealias C = LevelUpCurve
    private var style: LevelPrestige { .init(level: level) }
    private var previous: LevelPrestige { .init(level: max(1, level - 1)) }

    var body: some View {
        let post = t - LevelUpTiming.impact
        let reveal = t - LevelUpTiming.rankReveal
        let milestone = style.isMilestone
        let charge = C.ramp(t, 0.05, LevelUpTiming.impact)
        let lit = C.ramp(post, 0, 0.12)
        let reforged = milestone ? C.ramp(reveal, 0, 0.15) : 1
        let tremble = post < 0 ? sin(t * 63) * 1.3 * charge * charge : 0
        let slam = post < 0 ? 0.86 + 0.06 * charge : 1 + 0.28 * exp(-post * 7) * cos(post * 13)
        let second = milestone && reveal >= 0 ? 0.14 * exp(-reveal * 7) * cos(reveal * 13) : 0
        ZStack {
            LevelUpCrestFrame(stage: previous.stage, lit: false).equatable()
                .opacity(1 - lit)
            if milestone {
                LevelUpCrestFrame(stage: previous.stage, lit: true).equatable()
                    .opacity(lit * (1 - reforged))
            }
            LevelUpCrestFrame(stage: style.stage, lit: true).equatable()
                .opacity(lit * reforged)
            number(post: post)
        }
        .frame(width: radius * LevelUpCrestFrame.span, height: radius * LevelUpCrestFrame.span)
        .scaleEffect(slam + second)
        .offset(x: tremble)
    }

    private func number(post: Double) -> some View {
        let landed = post >= 0
        let p = C.ramp(post, 0, 0.32)
        let hot = landed ? exp(-post * 3.2) : 0
        let size = radius * 0.7
        // Serif numerals cast in the rank's metal, like the lettering on a
        // ranked emblem, rather than a rounded display face.
        let face = Text(verbatim: "\(landed ? level : max(1, level - 1))")
            .font(.system(size: size, weight: .bold, design: .serif))
            .monospacedDigit()
            .tracking(-size * 0.03)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(width: radius * 1.34)
        let metal = LinearGradient(stops: [.init(color: style.metal(1), location: 0), .init(color: style.metal(0.86), location: 0.42),
                                           .init(color: style.metal(0.5), location: 0.58), .init(color: style.metal(0.74), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
        return ZStack {
            // Struck into the face: a shadow below, a lit lip above, then the metal.
            face.foregroundStyle(.black.opacity(landed ? 0.75 : 0.5)).offset(y: size * 0.035).blur(radius: 0.8)
            face.foregroundStyle(.white.opacity(landed ? 0.45 : 0.1)).offset(y: -size * 0.02)
            face.foregroundStyle(landed ? AnyShapeStyle(metal) : AnyShapeStyle(Color.white.opacity(0.3)))
            face.foregroundStyle(.white).opacity(hot)
            if landed && moving { sheen(post: post, face: face) }
        }
        .shadow(color: style.tint.opacity(landed ? 0.25 + 0.55 * hot : 0), radius: 4 + 14 * hot)
        .scaleEffect(landed ? 1.9 - 0.9 * C.land(p) : 1)
        .opacity(landed ? min(1, p * 5) : 1)
    }

    /// A band of light crossing the digits every few seconds.
    private func sheen(post: Double, face: some View) -> some View {
        let cycle = 4.5, sweep = 0.8
        let s = post < 0.35 ? -1 : (post - 0.35).truncatingRemainder(dividingBy: cycle) / sweep
        let width = radius * 1.3
        return LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(width: width * 0.3)
            .rotationEffect(.degrees(18))
            .offset(x: (-0.8 + 1.6 * s) * width)
            .opacity(s >= 0 && s <= 1 ? 1 : 0)
            .frame(width: width, height: radius)
            .mask(face)
            .blendMode(.plusLighter)
    }
}

/// The forged ring: a two-tier bevelled rim of the rank's metal, points that
/// grow with the rank, a face engraved like an astrolabe and the rank's stone
/// at the top. Unlit it is plain steel; the number is drawn over it.
struct LevelUpCrestFrame: View, Equatable {
    /// The frame's side as a multiple of the ring's radius, leaving room for
    /// the points and the stone.
    static let span: CGFloat = 2.8
    let stage: Int
    let lit: Bool

    var body: some View {
        Canvas { context, size in
            let rank = LevelPrestige(level: max(1, stage * LevelPrestige.interval))
            let m = rank.material
            let metal = lit ? m.metal : ForgeTone(hue: m.metal.hue, saturation: 0.08, brightness: 0.5)
            let face = lit ? m.face : ForgeTone(hue: m.face.hue, saturation: 0.15, brightness: 0.7)
            let side = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = side / Self.span
            let rim = r * 0.21
            let segments = 144
            func ring(_ radius: CGFloat) -> [CGPoint] {
                (0..<segments).map { i in
                    let a = Double(i) / Double(segments) * 2 * .pi - .pi / 2
                    return CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
                }
            }

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: side * 0.03))
                layer.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r + side * 0.03, width: r * 2, height: r * 2)),
                           with: .color(.black.opacity(0.6)))
            }

            for point in Self.points(stage) {
                let dir = CGVector(dx: sin(point.angle), dy: -cos(point.angle))
                func at(_ a: Double, _ d: CGFloat) -> CGPoint {
                    CGPoint(x: c.x + sin(a) * d, y: c.y - cos(a) * d)
                }
                let tip = CGPoint(x: c.x + dir.dx * r * (1 + point.length), y: c.y + dir.dy * r * (1 + point.length))
                let kite = PrestigeOutline.clockwise([tip, at(point.angle + point.width, r * 0.97),
                                                      at(point.angle, r * 0.8), at(point.angle - point.width, r * 0.97)])
                let inner = PrestigeOutline.inset(kite, by: max(1.2, r * 0.04))
                PrestigeBevel.band(&context, outer: kite, inner: inner, style: metal)
                context.fill(PrestigeOutline.path(inner), with: .linearGradient(
                    Gradient(colors: [metal.metal(0.85), metal.metal(0.45)]),
                    startPoint: CGPoint(x: c.x, y: c.y - r * 1.5), endPoint: CGPoint(x: c.x, y: c.y + r * 1.5)))
                context.stroke(PrestigeOutline.path(kite), with: .color(.black.opacity(0.5)), lineWidth: 0.7)
                PrestigeBevel.glint(&context, kite, inset: 0.6, strength: lit ? 1 : 0.3)
            }

            let outer = ring(r), mid = ring(r - rim * 0.55), inner = ring(r - rim)
            PrestigeBevel.band(&context, outer: outer, inner: mid, style: metal)
            PrestigeBevel.band(&context, outer: mid, inner: inner, style: metal, sloping: true)

            let fr = r - rim
            let facePath = PrestigeOutline.path(inner)
            context.fill(facePath, with: .linearGradient(Gradient(colors: [face.faceTop, face.faceBottom]),
                                                         startPoint: CGPoint(x: c.x, y: c.y - fr), endPoint: CGPoint(x: c.x, y: c.y + fr)))
            if lit {
                context.fill(facePath, with: .radialGradient(Gradient(colors: [m.stone.tint.opacity(0.3), .clear]),
                                                             center: CGPoint(x: c.x, y: c.y - fr * 0.2), startRadius: 0, endRadius: fr))
            }
            context.drawLayer { layer in
                layer.clip(to: facePath)
                layer.addFilter(.blur(radius: side * 0.018))
                layer.stroke(facePath.offsetBy(dx: 0, dy: side * 0.014), with: .color(.black.opacity(0.75)), lineWidth: side * 0.04)
            }
            // Astrolabe divisions engraved round the edge of the face.
            var ticks = Path()
            for k in 0..<48 {
                let a = Double(k) / 48 * 2 * .pi
                let long = k.isMultiple(of: 4)
                ticks.move(to: CGPoint(x: c.x + sin(a) * (fr - r * 0.05), y: c.y - cos(a) * (fr - r * 0.05)))
                ticks.addLine(to: CGPoint(x: c.x + sin(a) * (fr - r * (long ? 0.17 : 0.11)), y: c.y - cos(a) * (fr - r * (long ? 0.17 : 0.11))))
            }
            context.stroke(ticks, with: .color(.black.opacity(0.55)), lineWidth: max(0.7, r * 0.018))
            context.stroke(ticks.offsetBy(dx: 0, dy: 0.6), with: .color(m.stone.tint.opacity(lit ? 0.2 : 0.06)), lineWidth: max(0.5, r * 0.012))

            context.stroke(PrestigeOutline.path(outer), with: .color(.black.opacity(0.55)), lineWidth: 0.8)
            PrestigeBevel.glint(&context, outer, inset: 0.6, strength: lit ? 1 : 0.35)

            // The rank's stone, set into the top of the ring.
            let g = r * 0.42
            let seat = CGPoint(x: c.x, y: c.y - r + rim * 0.5)
            let socket = Path(ellipseIn: CGRect(x: seat.x - g * 0.64, y: seat.y - g * 0.64, width: g * 1.28, height: g * 1.28))
            context.fill(socket, with: .radialGradient(Gradient(colors: [metal.metal(0.35), metal.metal(0.1)]),
                                                       center: seat, startRadius: 0, endRadius: g * 0.64))
            context.stroke(socket, with: .linearGradient(Gradient(colors: [metal.metal(0.95), metal.metal(0.25)]),
                                                         startPoint: CGPoint(x: seat.x, y: seat.y - g * 0.64),
                                                         endPoint: CGPoint(x: seat.x, y: seat.y + g * 0.64)),
                           lineWidth: max(0.8, r * 0.025))
            let stone = lit ? m : RankMaterial(metal: metal, face: face,
                                               stone: ForgeTone(hue: m.stone.hue, saturation: 0.1, brightness: 0.55), cut: m.cut)
            RankGem.draw(&context, in: CGRect(x: seat.x - g / 2, y: seat.y - g / 2, width: g, height: g), material: stone)
        }
    }

    struct Point { let angle: Double; let length: CGFloat; let width: Double }

    /// Points around the ring, clockwise from the top. Higher ranks grow more
    /// and longer ones, the way ranked emblems gain structure as they climb.
    static func points(_ stage: Int) -> [Point] {
        let sides = [90.0, 270].map { $0 * .pi / 180 }
        let diagonals = [135.0, 225, 45, 315].map { $0 * .pi / 180 }
        let foot = [180.0 * .pi / 180]
        switch stage {
        case 0: return []
        case 1, 2: return sides.map { Point(angle: $0, length: 0.3, width: 0.17) }
        case 3, 4: return sides.map { Point(angle: $0, length: 0.4, width: 0.16) }
            + diagonals.prefix(2).map { Point(angle: $0, length: 0.24, width: 0.13) }
        case 5, 6: return (sides + foot).map { Point(angle: $0, length: 0.44, width: 0.15) }
            + diagonals.map { Point(angle: $0, length: 0.26, width: 0.12) }
        default: return (sides + foot).map { Point(angle: $0, length: 0.55, width: 0.14) }
            + diagonals.map { Point(angle: $0, length: 0.34, width: 0.12) }
        }
    }
}
