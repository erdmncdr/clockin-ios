import SwiftUI

/// The rank crown, cast in the rank's metal and seen a little from above:
/// the back of the rim and its points through the opening, then the front
/// band set with stones and five points, the middle three tipped with the
/// rank's stone and the outer two with pearls. The badge and the level-up
/// stage draw the same crown; at badge size it keeps three broad points so
/// it reads as a crown rather than a row of spikes.
enum ForgedCrown {
    /// Where the crown sits: centred on `x`, its band resting on `base`.
    struct Frame {
        let x: CGFloat
        let base: CGFloat
        let width: CGFloat
        let height: CGFloat
        /// Three broad points instead of five, for small sizes.
        var simple = false

        var bandHeight: CGFloat { height * 0.28 }
        /// How far the band's front bows toward the viewer at its middle.
        var sag: CGFloat { height * 0.08 }

        func u(_ px: CGFloat) -> CGFloat { (px - x) / (width / 2) }
        func bandTop(_ px: CGFloat) -> CGFloat { base - bandHeight + sag * (1 - u(px) * u(px)) }
        func bandBottom(_ px: CGFloat) -> CGFloat { base + sag * (1 - u(px) * u(px)) }
        /// The back rim's upper edge, seen through the opening: it arcs away.
        func backTop(_ px: CGFloat) -> CGFloat { base - bandHeight - sag * 1.3 * (1 - u(px) * u(px)) }

        struct Point { let u: CGFloat; let rise: CGFloat; let half: CGFloat }
        var front: [Point] {
            simple
                ? [Point(u: -0.6, rise: 0.46, half: 0.15), Point(u: 0, rise: 0.64, half: 0.17), Point(u: 0.6, rise: 0.46, half: 0.15)]
                : [Point(u: -0.88, rise: 0.34, half: 0.075), Point(u: -0.44, rise: 0.5, half: 0.1), Point(u: 0, rise: 0.64, half: 0.105),
                   Point(u: 0.44, rise: 0.5, half: 0.1), Point(u: 0.88, rise: 0.34, half: 0.075)]
        }
        var back: [Point] {
            simple
                ? [Point(u: -0.3, rise: 0.32, half: 0.1), Point(u: 0.3, rise: 0.32, half: 0.1)]
                : [Point(u: -0.66, rise: 0.28, half: 0.08), Point(u: -0.22, rise: 0.36, half: 0.09),
                   Point(u: 0.22, rise: 0.36, half: 0.09), Point(u: 0.66, rise: 0.28, half: 0.08)]
        }
        /// Band stones sit under the stone-tipped points.
        var bandStones: [CGFloat] { simple ? [-0.6, 0, 0.6] : [-0.44, 0, 0.44] }

        func tip(_ p: Point) -> CGPoint {
            let px = x + p.u * width / 2
            return CGPoint(x: px, y: bandTop(px) - p.rise * height)
        }

        /// The stones on the three tall points: left, centre, right.
        var jewels: [CGPoint] { simple ? front.map(tip) : front[1...3].map(tip) }
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: Frame, material m: RankMaterial, detail: Bool = true) {
        let tone = m.metal
        let line = max(0.5, f.width / 60)
        let left = f.x - f.width / 2, right = f.x + f.width / 2
        let samples = 24

        // The back of the rim: its inner face, lit less, and its points.
        var back = Path()
        back.move(to: CGPoint(x: left, y: f.bandTop(left)))
        rim(&back, f, points: f.back, top: f.backTop, from: left, to: right)
        for i in (0...samples).reversed() {
            let px = left + (right - left) * CGFloat(i) / CGFloat(samples)
            back.addLine(to: CGPoint(x: px, y: f.bandTop(px)))
        }
        back.closeSubpath()
        ctx.fill(back, with: .linearGradient(Gradient(colors: [tone.metal(0.55), tone.metal(0.3), tone.metal(0.08)]),
                                             startPoint: CGPoint(x: f.x, y: f.backTop(f.x) - f.height * 0.46),
                                             endPoint: CGPoint(x: f.x, y: f.bandTop(f.x))))
        ctx.stroke(back, with: .color(.black.opacity(0.55)), lineWidth: line * 0.8)

        // The front: band and points as one casting.
        var front = Path()
        front.move(to: CGPoint(x: left, y: f.bandBottom(left)))
        front.addLine(to: CGPoint(x: left, y: f.bandTop(left)))
        rim(&front, f, points: f.front, top: f.bandTop, from: left, to: right)
        front.addLine(to: CGPoint(x: right, y: f.bandBottom(right)))
        for i in (0...samples).reversed() {
            let px = left + (right - left) * CGFloat(i) / CGFloat(samples)
            front.addLine(to: CGPoint(x: px, y: f.bandBottom(px)))
        }
        front.closeSubpath()

        var shadow = ctx
        shadow.addFilter(.blur(radius: max(0.8, f.width * 0.025)))
        shadow.fill(front.offsetBy(dx: f.width * 0.015, dy: f.height * 0.05), with: .color(.black.opacity(0.55)))

        // Turned metal: bright where the round faces the light at the upper left.
        let turned = Gradient(stops: [
            .init(color: tone.metal(0.4), location: 0), .init(color: tone.metal(0.85), location: 0.16),
            .init(color: tone.metal(1), location: 0.3), .init(color: tone.metal(0.72), location: 0.5),
            .init(color: tone.metal(0.32), location: 0.82), .init(color: tone.metal(0.52), location: 1),
        ])
        ctx.fill(front, with: .linearGradient(turned, startPoint: CGPoint(x: left, y: 0), endPoint: CGPoint(x: right, y: 0)))
        var inside = ctx
        inside.clip(to: front)
        inside.fill(front, with: .linearGradient(Gradient(colors: [.white.opacity(0.22), .clear]),
                                                 startPoint: CGPoint(x: f.x, y: f.bandTop(f.x) - f.height * 0.72),
                                                 endPoint: CGPoint(x: f.x, y: f.bandTop(f.x))))

        // Each point: a lit left edge and, when there is room, a chased line.
        for p in f.front {
            let px = f.x + p.u * f.width / 2, t = f.tip(p), hw = p.half * f.width
            let baseLeft = CGPoint(x: px - hw, y: f.bandTop(px - hw))
            var edge = Path()
            edge.move(to: baseLeft)
            edge.addQuadCurve(to: t, control: CGPoint(x: px - hw * 0.5, y: f.bandTop(px) - p.rise * f.height * 0.35))
            inside.stroke(edge.offsetBy(dx: line * 0.9, dy: 0), with: .color(.white.opacity(0.5)), lineWidth: line)
            if detail {
                let chase = Path { $0.move(to: CGPoint(x: px, y: f.bandTop(px) - f.height * 0.03)); $0.addLine(to: CGPoint(x: px, y: t.y + p.rise * f.height * 0.45)) }
                inside.stroke(chase, with: .color(.black.opacity(0.3)), lineWidth: line * 0.9)
                inside.stroke(chase.offsetBy(dx: -line * 0.7, dy: 0), with: .color(.white.opacity(0.28)), lineWidth: line * 0.6)
            }
        }

        // The band stands proud of the points: a lit upper lip, a dark lower one.
        var lip = Path()
        var foot = Path()
        for i in 0...samples {
            let px = left + (right - left) * CGFloat(i) / CGFloat(samples)
            let upper = CGPoint(x: px, y: f.bandTop(px) + line * 0.4), lower = CGPoint(x: px, y: f.bandBottom(px) - line * 0.6)
            if i == 0 { lip.move(to: upper); foot.move(to: lower) } else { lip.addLine(to: upper); foot.addLine(to: lower) }
        }
        inside.stroke(lip.offsetBy(dx: 0, dy: line * 0.9), with: .color(.black.opacity(0.35)), lineWidth: line * 0.9)
        inside.stroke(lip, with: .color(.white.opacity(0.55)), lineWidth: line * 0.8)
        inside.stroke(foot, with: .color(.black.opacity(0.4)), lineWidth: line)
        ctx.stroke(front, with: .color(.black.opacity(0.6)), lineWidth: line)

        // Stones set in the band, a large one in the middle.
        for u in f.bandStones {
            let scale: CGFloat = u == 0 ? 0.82 : 0.62
            let px = f.x + u * f.width / 2
            let c = CGPoint(x: px, y: (f.bandTop(px) + f.bandBottom(px)) / 2)
            let s = f.bandHeight * scale
            let seat = Path(ellipseIn: CGRect(x: c.x - s * 0.62, y: c.y - s * 0.62, width: s * 1.24, height: s * 1.24))
            ctx.fill(seat, with: .color(tone.metal(0.2)))
            ctx.stroke(seat, with: .linearGradient(Gradient(colors: [tone.metal(1), tone.metal(0.3)]),
                                                   startPoint: CGPoint(x: c.x, y: c.y - s), endPoint: CGPoint(x: c.x, y: c.y + s)),
                       lineWidth: line * 0.9)
            RankGem.cabochon(&ctx, in: CGRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s), tone: m.stone)
        }

        // The tips: the rank's stone on the tall three, pearls on the outer two.
        for (i, p) in f.front.enumerated() {
            let t = f.tip(p)
            let outer = !f.simple && (i == 0 || i == 4)
            let middle = p.u == 0
            let s = f.width * (outer ? 0.05 : (middle ? (f.simple ? 0.14 : 0.085) : (f.simple ? 0.11 : 0.07)))
            let r = CGRect(x: t.x - s / 2, y: t.y - s * 0.62, width: s, height: s)
            if outer {
                let pearl = Path(ellipseIn: r)
                ctx.fill(pearl, with: .radialGradient(Gradient(colors: [.white, Color(white: 0.84), Color(white: 0.5)]),
                                                      center: CGPoint(x: r.minX + s * 0.35, y: r.minY + s * 0.3), startRadius: 0, endRadius: s * 0.75))
                ctx.stroke(pearl, with: .color(.black.opacity(0.4)), lineWidth: line * 0.6)
            } else {
                RankGem.cabochon(&ctx, in: r, tone: m.stone)
            }
        }
    }

    /// The top edge along a rim: straight between points, each point rising
    /// on slightly hollow sides from a flared base.
    private static func rim(_ path: inout Path, _ f: Frame, points: [Frame.Point], top: (CGFloat) -> CGFloat,
                            from left: CGFloat, to right: CGFloat) {
        for p in points {
            let px = f.x + p.u * f.width / 2, hw = p.half * f.width
            let y = top(px), tip = CGPoint(x: px, y: y - p.rise * f.height)
            path.addLine(to: CGPoint(x: px - hw, y: top(px - hw)))
            path.addQuadCurve(to: tip, control: CGPoint(x: px - hw * 0.5, y: y - p.rise * f.height * 0.35))
            path.addQuadCurve(to: CGPoint(x: px + hw, y: top(px + hw)), control: CGPoint(x: px + hw * 0.5, y: y - p.rise * f.height * 0.35))
        }
        path.addLine(to: CGPoint(x: right, y: top(right)))
    }
}
