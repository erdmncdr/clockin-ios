import SwiftUI

/// Light the card draws over everything, centred on the crest: the screen
/// darkening round it through the charge, then the strike's flash, a shock
/// wave that runs off the screen, a lens streak, beams and sparks thrown to
/// the edges. A new rank's second beat gets a smaller strike of its own.
struct LevelUpBlast: View {
    let t: Double
    let center: CGPoint
    let radius: CGFloat
    /// The colours of the level's strike: the old rank's on a new rank.
    let first: LevelPrestige
    /// The colours of a new rank's second beat, if there is one.
    let second: LevelPrestige?

    /// Whether anything is drawn at `t`, so the canvas can leave the tree
    /// the rest of the time.
    static func active(_ t: Double, secondBeat: Bool) -> Bool {
        let post = t - LevelUpTiming.impact, reveal = t - LevelUpTiming.rankReveal
        return LevelUpCurve.dark(t) > 0 || (post >= 0 && post < LevelUpBlastArt.length)
            || (secondBeat && reveal >= 0 && reveal < LevelUpBlastArt.length)
    }

    var body: some View {
        Canvas { context, size in
            LevelUpBlastArt.darken(&context, size: size, center: center, radius: radius, amount: LevelUpCurve.dark(t))
            var light = context
            light.blendMode = .plusLighter
            LevelUpBlastArt.strike(&light, size: size, center: center, radius: radius, after: t - LevelUpTiming.impact,
                                   style: first, strength: 1, salt: 0)
            if let second {
                LevelUpBlastArt.strike(&light, size: size, center: center, radius: radius,
                                       after: t - LevelUpTiming.rankReveal, style: second, strength: 0.6, salt: 200)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum LevelUpBlastArt {
    private typealias C = LevelUpCurve
    /// Seconds a strike's light lasts.
    static let length = 0.9

    /// A vignette that closes in on the crest, leaving it lit.
    static func darken(_ ctx: inout GraphicsContext, size: CGSize, center: CGPoint, radius: CGFloat, amount: Double) {
        guard amount > 0 else { return }
        let far = farthest(size, center)
        let lit = min(0.4, radius * 1.3 / far), edge = min(0.8, max(lit + 0.05, radius * 3.2 / far))
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .clear, location: lit),
            .init(color: .black.opacity(0.35 * amount), location: edge),
            .init(color: .black.opacity(0.62 * amount), location: 1),
        ]), center: center, startRadius: 0, endRadius: far))
    }

    static func strike(_ ctx: inout GraphicsContext, size: CGSize, center c: CGPoint, radius r: CGFloat, after post: Double,
                       style: LevelPrestige, strength: Double, salt: Int) {
        guard post >= 0, post < length else { return }
        let far = farthest(size, c)
        // The whole screen lights from the crest out and fades at once: one
        // bloom, never a strobe.
        let flash = strength * exp(-post * 7)
        if flash > 0.01 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(Gradient(stops: [
                .init(color: .white.opacity(0.75 * flash), location: 0),
                .init(color: style.tint.opacity(0.5 * flash), location: min(0.5, r * 2.5 / far)),
                .init(color: style.tint.opacity(0.16 * flash), location: 1),
            ]), center: c, startRadius: 0, endRadius: far))
        }
        // A shock wave that runs off the edges of the screen.
        let s = C.ramp(post, 0, 0.7)
        if s < 1 {
            let rr = r * 1.2 + far * 1.05 * C.easeOut(s)
            let a = strength * pow(1 - s, 1.5)
            let ring = Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
            ctx.stroke(ring, with: .color(style.tint.opacity(0.22 * a)), lineWidth: 6 + 30 * (1 - s))
            ctx.stroke(ring, with: .color(style.highlight.opacity(0.5 * a)), lineWidth: 1.5 + 3 * (1 - s))
            ctx.stroke(ring, with: .color(.white.opacity(0.6 * a)), lineWidth: 1)
        }
        // A lens streak across the screen through the crest.
        let streak = strength * exp(-post * 5)
        if streak > 0.01 {
            let w = size.width * (0.5 + 0.8 * C.easeOut(C.ramp(post, 0, 0.15)))
            for (h, o) in [(CGFloat(26), 0.25), (CGFloat(5), 0.6), (CGFloat(1.6), 1.0)] {
                let band = CGRect(x: c.x - w, y: c.y - h / 2, width: w * 2, height: h)
                ctx.fill(Path(ellipseIn: band), with: .linearGradient(Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: style.tint.opacity(0.6 * o * streak), location: 0.3),
                    .init(color: .white.opacity(o * streak), location: 0.5),
                    .init(color: style.tint.opacity(0.6 * o * streak), location: 0.7),
                    .init(color: .clear, location: 1),
                ]), startPoint: CGPoint(x: band.minX, y: c.y), endPoint: CGPoint(x: band.maxX, y: c.y)))
            }
        }
        // Beams that fire out to the edges for an instant.
        let beams = strength * pow(1 - C.ramp(post, 0, 0.4), 2)
        if beams > 0 {
            for i in 0..<10 {
                let a = C.noise(i, salt + 51) * 2 * .pi + post * 0.3
                let half = 0.012 + 0.018 * C.noise(i, salt + 52)
                let reach = far * (0.6 + 0.4 * C.noise(i, salt + 53)) * C.easeOut(C.ramp(post, 0, 0.12))
                var beam = Path()
                beam.move(to: point(c, a - half * 0.4, r * 0.8))
                beam.addLine(to: point(c, a - half, reach))
                beam.addLine(to: point(c, a + half, reach))
                beam.addLine(to: point(c, a + half * 0.4, r * 0.8))
                beam.closeSubpath()
                ctx.fill(beam, with: .radialGradient(Gradient(colors: [.white.opacity(0.4 * beams), style.tint.opacity(0.2 * beams), .clear]),
                                                     center: c, startRadius: r * 0.8, endRadius: max(r, reach)))
            }
        }
        // Sparks thrown out to the edges of the screen, slowed by drag.
        for i in 0..<28 {
            let life = 0.35 + 0.4 * C.noise(i, salt + 61)
            let tau = post - 0.02 * C.noise(i, salt + 62)
            guard tau > 0, tau < life else { continue }
            let a = C.noise(i, salt + 63) * 2 * .pi
            let speed = 900 + 900 * C.noise(i, salt + 64), k = 2.6
            func at(_ q: Double) -> CGPoint {
                let d = r * 0.6 + speed * (1 - exp(-k * q)) / k
                return CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d + 160 * q * q)
            }
            let fade = (1 - tau / life) * strength
            var line = Path()
            line.move(to: at(max(0, tau - 0.05)))
            line.addLine(to: at(tau))
            let hot = C.noise(i, salt + 65) > 0.5
            ctx.stroke(line, with: .color((hot ? Color.white : style.highlight).opacity(fade)),
                       style: StrokeStyle(lineWidth: 1 + 2.4 * fade, lineCap: .round))
        }
    }

    /// The distance from `c` to the farthest corner, so light centred there
    /// reaches every edge.
    private static func farthest(_ size: CGSize, _ c: CGPoint) -> CGFloat {
        max(1, [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            .map { hypot($0.x - c.x, $0.y - c.y) }.max() ?? 1)
    }

    private static func point(_ c: CGPoint, _ angle: Double, _ r: CGFloat) -> CGPoint {
        CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
    }
}
