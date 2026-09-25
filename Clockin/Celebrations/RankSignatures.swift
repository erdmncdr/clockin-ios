import SwiftUI

/// Each rank's one signature motion (see docs/rank-and-medal-design.md). The
/// under layer sits on the face, beneath the gem and the level; the over layer
/// sits on top. With `time == nil` a still frame is drawn that still shows the
/// signature, for Reduce Motion, Low Power Mode and off-screen badges.
struct RankSignature: View {
    enum Layer { case under, over }
    let style: LevelPrestige
    let layer: Layer
    let time: Double?
    private static let margin: CGFloat = 22

    var body: some View {
        Canvas { original, fullSize in
            var context = original
            context.translateBy(x: Self.margin, y: Self.margin)
            let size = CGSize(width: fullSize.width - Self.margin * 2, height: fullSize.height - Self.margin * 2)
            #if DEBUG
            if layer == .over, let time { LevelFrameDiagnostics.record(time) }
            #endif
            RankSignatureArt(style: style, size: size, time: time).draw(&context, layer: layer)
        }
        .padding(-Self.margin).allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct RankSignatureArt {
    let style: LevelPrestige
    let size: CGSize
    let time: Double?

    private var m: RankMaterial { style.material }
    private var gem: CGPoint { RankLayout.gemCenter(in: size) }
    private var outline: [CGPoint] { PrestigeOutline.rankPlate(stage: style.stage, in: CGRect(origin: .zero, size: size)) }
    private var plate: Path { PrestigeOutline.path(outline) }
    private var face: Path { PrestigeOutline.path(PrestigeOutline.inset(outline, by: PrestigeMetalFrame.rimWidth(style.stage))) }
    /// Seconds into a repeating cycle, or the given still moment.
    private func cycle(_ period: Double, still: Double) -> Double {
        guard let time else { return still }
        return time.truncatingRemainder(dividingBy: period)
    }
    private func smooth(_ x: Double) -> Double { let c = min(1, max(0, x)); return c * c * (3 - 2 * c) }
    /// 0 outside [start, end], rising and falling smoothly inside it.
    private func pulse(_ u: Double, _ start: Double, _ end: Double) -> Double {
        guard u > start, u < end else { return 0 }
        return sin((u - start) / (end - start) * .pi)
    }

    func draw(_ context: inout GraphicsContext, layer: RankSignature.Layer) {
        switch (style.stage, layer) {
        case (0, .over): spark(&context)
        case (1, .over): moon(&context)
        case (2, .under): faceTwinkle(&context)
        case (2, .over): nebula(&context)
        case (3, .under): corona(&context)
        case (4, .over): nova(&context)
        case (5, .under): aurora(&context)
        case (6, .over): crown(&context)
        case (7, .under): constellation(&context)
        case (8, .over): iridescence(&context)
        default: break
        }
    }

    // MARK: Spark: a single spark leaps off the stone now and then.

    private func spark(_ context: inout GraphicsContext) {
        guard time != nil else { return }
        let u = cycle(7, still: 0)
        guard u < 0.8 else { return }
        let p = u / 0.8
        func along(_ q: Double) -> CGPoint {
            // A short ballistic arc up and to the right of the stone.
            let x = gem.x + 6 + 18 * q, y = gem.y - 7 - 16 * q + 22 * q * q
            return CGPoint(x: x, y: y)
        }
        let fade = pow(1 - p, 1.4)
        for step in 0..<7 {
            let q = max(0, p - Double(step) * 0.035)
            let point = along(q)
            let r = step == 0 ? 1.3 : 0.9 - Double(step) * 0.08
            let a = fade * (1 - Double(step) / 7)
            context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                         with: .color(Color(hue: 0.1, saturation: 0.35, brightness: 1).opacity(a)))
        }
        let head = along(p)
        context.fill(Path(ellipseIn: CGRect(x: head.x - 4, y: head.y - 4, width: 8, height: 8)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.5 * fade), .clear]), center: head, startRadius: 0, endRadius: 4))
    }

    // MARK: Orbit: a moon rides the ring, passing behind the stone.

    private func moon(_ context: inout GraphicsContext) {
        let theta = time.map { $0 / 8 * .pi * 2 } ?? .pi * 0.55
        let r = RankOrnaments.orbitRadii
        let local = CGPoint(x: cos(theta) * r.width, y: sin(theta) * r.height)
        let tilt = RankOrnaments.orbitTilt
        let p = CGPoint(x: gem.x + local.x * cos(tilt) - local.y * sin(tilt),
                        y: gem.y + local.x * sin(tilt) + local.y * cos(tilt))
        let behind = sin(theta) < 0
        let radius: CGFloat = 2.7
        let body = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
        context.drawLayer { layer in
            if behind {
                // Hidden where it passes behind the stone.
                var outside = Path(CGRect(x: -40, y: -40, width: size.width + 80, height: size.height + 80))
                outside.addEllipse(in: CGRect(x: gem.x - RankLayout.socketRadius, y: gem.y - RankLayout.socketRadius,
                                              width: RankLayout.socketRadius * 2, height: RankLayout.socketRadius * 2))
                layer.clip(to: outside, style: FillStyle(eoFill: true))
                layer.opacity = 0.75
            }
            layer.fill(body.offsetBy(dx: 0, dy: 0.8), with: .color(.black.opacity(0.4)))
            layer.fill(body, with: .radialGradient(Gradient(colors: [m.metal.metal(1), m.metal.metal(0.55), m.metal.metal(0.15)]),
                                                   center: CGPoint(x: p.x - radius * 0.4, y: p.y - radius * 0.45), startRadius: 0, endRadius: radius * 1.6))
            layer.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)),
                       with: .radialGradient(Gradient(colors: [style.tint.opacity(0.25), .clear]), center: p, startRadius: radius, endRadius: 7))
        }
    }

    // MARK: Nebula: clouds drift inside the dome; a star in the face twinkles.

    private func nebula(_ context: inout GraphicsContext) {
        let t = time ?? 2
        let r: CGFloat = 26 * 0.78 / 2
        let dome = Path(ellipseIn: CGRect(x: gem.x - r, y: gem.y - r, width: r * 2, height: r * 2))
        context.drawLayer { layer in
            layer.clip(to: dome)
            // Deep space first, so the clouds read as light inside the stone.
            layer.fill(dome, with: .radialGradient(Gradient(colors: [Color(hue: 0.74, saturation: 0.8, brightness: 0.35), Color(hue: 0.72, saturation: 0.9, brightness: 0.1)]),
                                                   center: gem, startRadius: 0, endRadius: r))
            var clouds = layer
            clouds.blendMode = .screen
            clouds.addFilter(.blur(radius: 1.6))
            let puffs: [(Double, Double, CGFloat, Double)] = [(0.0, 0.86, 5.5, 0.26), (2.1, 0.55, 4.5, 0.21), (4.2, 0.76, 4.8, 0.31)]
            for (offset, hue, radius, speed) in puffs {
                let c = CGPoint(x: gem.x + cos(t * speed + offset) * 4.2, y: gem.y + sin(t * speed * 1.3 + offset) * 3.4)
                clouds.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius * 0.7, width: radius * 2, height: radius * 1.4)),
                            with: .radialGradient(Gradient(colors: [Color(hue: hue, saturation: 0.7, brightness: 1).opacity(0.85), .clear]),
                                                  center: c, startRadius: 0, endRadius: radius))
            }
            for (i, spot) in [CGPoint(x: -3.5, y: -2.5), CGPoint(x: 4, y: 3), CGPoint(x: 1.5, y: -5)].enumerated() {
                let a = time.map { 0.5 + 0.5 * sin($0 * 1.9 + Double(i) * 2) } ?? 0.8
                layer.fill(Path(ellipseIn: CGRect(x: gem.x + spot.x - 0.5, y: gem.y + spot.y - 0.5, width: 1, height: 1)),
                           with: .color(.white.opacity(0.9 * a)))
            }
            // The dome's own highlight stays on top.
            let spec = CGRect(x: gem.x - r * 0.6, y: gem.y - r * 0.72, width: r * 0.6, height: r * 0.4)
            layer.fill(Path(ellipseIn: spec), with: .radialGradient(Gradient(colors: [.white.opacity(0.75), .white.opacity(0)]),
                                                                    center: CGPoint(x: spec.midX, y: spec.midY), startRadius: 0, endRadius: spec.width * 0.6))
        }
    }

    private func faceTwinkle(_ context: inout GraphicsContext) {
        let u = cycle(4.5, still: 0.75)
        let spots = [CGPoint(x: size.width * 0.5, y: 8.5), CGPoint(x: size.width * 0.9, y: size.height - 9),
                     CGPoint(x: size.width * 0.36, y: size.height - 7.5)]
        for (i, spot) in spots.enumerated() {
            let a = pulse(u, Double(i) * 1.5, Double(i) * 1.5 + 1.5)
            PrestigeGem.glint(&context, at: spot, size: 2.8, opacity: 0.8 * a)
        }
    }

    // MARK: Solar: a corona turns slowly behind the stone and breathes.

    private func corona(_ context: inout GraphicsContext) {
        let t = time ?? 0
        let turn = t * 0.12
        let breathe = time == nil ? 0 : sin(t * 1.1) * 1.4
        context.drawLayer { layer in
            layer.clip(to: face)
            layer.fill(Path(ellipseIn: CGRect(x: gem.x - 19, y: gem.y - 19, width: 38, height: 38)),
                       with: .radialGradient(Gradient(colors: [style.tint.opacity(0.35), .clear]), center: gem, startRadius: 9, endRadius: 19))
            layer.addFilter(.blur(radius: 0.6))
            let count = 14
            for i in 0..<count {
                let a = turn + Double(i) / Double(count) * .pi * 2
                let long = i.isMultiple(of: 2)
                let inner: CGFloat = 12, outer = (long ? 19.5 : 16.5) + breathe
                let half = 0.09
                var ray = Path()
                ray.addLines([CGPoint(x: gem.x + cos(a - half) * inner, y: gem.y + sin(a - half) * inner),
                              CGPoint(x: gem.x + cos(a) * outer, y: gem.y + sin(a) * outer),
                              CGPoint(x: gem.x + cos(a + half) * inner, y: gem.y + sin(a + half) * inner)])
                ray.closeSubpath()
                layer.fill(ray, with: .linearGradient(Gradient(colors: [m.stone.gem(0.95).opacity(0.75), m.stone.gem(0.7).opacity(0)]),
                                                      startPoint: CGPoint(x: gem.x + cos(a) * inner, y: gem.y + sin(a) * inner),
                                                      endPoint: CGPoint(x: gem.x + cos(a) * outer, y: gem.y + sin(a) * outer)))
            }
        }
    }

    // MARK: Nova: the stone charges, then a shock ring crosses the plate.

    private func nova(_ context: inout GraphicsContext) {
        let u = cycle(6, still: 0.9)
        let charge = time == nil ? 0.45 : (u < 1.2 ? smooth(u / 1.2) : max(0, 1 - (u - 1.2) / 0.5))
        if charge > 0.01 {
            context.fill(Path(ellipseIn: CGRect(x: gem.x - 16, y: gem.y - 16, width: 32, height: 32)),
                         with: .radialGradient(Gradient(colors: [.white.opacity(0.45 * charge), style.tint.opacity(0.35 * charge), .clear]),
                                               center: gem, startRadius: 2, endRadius: 16))
            PrestigeGem.glint(&context, at: CGPoint(x: gem.x - 3, y: gem.y - 4), size: 5 * charge + 1, opacity: 0.9 * charge)
        }
        guard time != nil, u > 1.2, u < 2.6 else { return }
        let p = (u - 1.2) / 1.4
        let radius = 12 + (size.width + 10) * (1 - pow(1 - p, 2.2))
        context.drawLayer { layer in
            layer.clip(to: plate)
            layer.addFilter(.blur(radius: 1.2))
            layer.stroke(Path(ellipseIn: CGRect(x: gem.x - radius, y: gem.y - radius * 0.7, width: radius * 2, height: radius * 1.4)),
                         with: .color(style.highlight.opacity(0.6 * (1 - p))), lineWidth: 3 * (1 - p) + 0.6)
        }
    }

    // MARK: Aurora: ribbons of light flow slowly across the face.

    private func aurora(_ context: inout GraphicsContext) {
        let t = time ?? 3
        context.drawLayer { layer in
            layer.clip(to: face)
            layer.blendMode = .screen
            layer.addFilter(.blur(radius: 2.6))
            let ribbons: [(CGFloat, Double, Double, CGFloat)] = [(0.36, 0.35, 0.0, 5), (0.62, -0.26, 1.7, 4)]
            for (row, speed, offset, thickness) in ribbons {
                var band = Path()
                let steps = 24
                var top: [CGPoint] = [], bottom: [CGPoint] = []
                for i in 0...steps {
                    let x = CGFloat(i) / CGFloat(steps) * size.width
                    let wave = sin(Double(x) / 22 + t * speed + offset) * 4 + sin(Double(x) / 9 - t * speed * 1.7) * 1.2
                    let y = size.height * row + CGFloat(wave)
                    let swell = thickness * CGFloat(0.6 + 0.4 * sin(Double(x) / 30 + t * 0.4 + offset))
                    top.append(CGPoint(x: x, y: y - swell)); bottom.append(CGPoint(x: x, y: y + swell))
                }
                band.addLines(top + bottom.reversed()); band.closeSubpath()
                layer.fill(band, with: .linearGradient(Gradient(colors: [Color(hue: 0.38, saturation: 0.8, brightness: 1).opacity(0.05),
                                                                         Color(hue: 0.42, saturation: 0.75, brightness: 1).opacity(0.4),
                                                                         Color(hue: 0.52, saturation: 0.6, brightness: 1).opacity(0.3),
                                                                         Color(hue: 0.78, saturation: 0.55, brightness: 1).opacity(0.08)]),
                                                       startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
            }
        }
    }

    // MARK: Sovereign: the crown's stones light in turn, then the rim gleams.

    private func crown(_ context: inout GraphicsContext) {
        let u = cycle(6, still: -1)
        let tips = PrestigeOutline.crownPoints(centerX: size.width / 2, top: 0, width: 34, height: 15).prefix(3).map { $0[1] }
        let order = [0, 2, 1] // left, centre, right
        for (step, index) in order.enumerated() {
            let apex = tips[index]
            let stone = CGPoint(x: apex.x, y: apex.y + 0.5)
            let a = time == nil ? 0.55 : pulse(u, Double(step) * 0.45, Double(step) * 0.45 + 1)
            guard a > 0.01 else { continue }
            context.fill(Path(ellipseIn: CGRect(x: stone.x - 6, y: stone.y - 6, width: 12, height: 12)),
                         with: .radialGradient(Gradient(colors: [style.tint.opacity(0.55 * a), .clear]), center: stone, startRadius: 0, endRadius: 6))
            PrestigeGem.glint(&context, at: stone, size: 4, opacity: 0.95 * a)
        }
        guard time != nil else { return }
        let g = pulse(u, 1.8, 3.1)
        guard g > 0.01 else { return }
        let x = (u - 1.8) / 1.3 * size.width
        context.drawLayer { layer in
            layer.clip(to: plate)
            layer.addFilter(.blur(radius: 1.5))
            var sweep = Path()
            sweep.move(to: CGPoint(x: x - 8, y: 1.2)); sweep.addLine(to: CGPoint(x: x + 8, y: 1.2))
            layer.stroke(sweep, with: .color(.white.opacity(0.75 * g)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    // MARK: Celestial: constellations draw themselves in the sky under the arch.

    private func constellation(_ context: inout GraphicsContext) {
        let u = cycle(8, still: 4)
        let w = size.width
        // Two small figures either side of the crown, clear of the level number.
        let left: [CGPoint] = [CGPoint(x: w * 0.25, y: -3), CGPoint(x: w * 0.31, y: -10), CGPoint(x: w * 0.39, y: -6.5)]
        let right: [CGPoint] = [CGPoint(x: w * 0.61, y: -6.5), CGPoint(x: w * 0.69, y: -10), CGPoint(x: w * 0.75, y: -3)]
        let figures: [[CGPoint]] = [left, right]
        let draw = smooth(u / 2.6), fade = u < 5.5 ? 1 : max(0, 1 - (u - 5.5) / 1.5)
        let segments = left.count + right.count - 2
        let reach = draw * Double(segments)
        var index = 0.0
        for stars in figures {
            for i in 0..<(stars.count - 1) {
                let part = min(1, max(0, reach - index)); index += 1
                guard part > 0 else { continue }
                let a = stars[i], b = stars[i + 1]
                var line = Path()
                line.move(to: a); line.addLine(to: CGPoint(x: a.x + (b.x - a.x) * part, y: a.y + (b.y - a.y) * part))
                context.stroke(line, with: .color(style.highlight.opacity(0.45 * fade)), lineWidth: 0.5)
            }
        }
        for (f, stars) in figures.enumerated() {
            for (i, star) in stars.enumerated() {
                let seed = Double(i + f * 3) * 1.7
                let twinkle: Double = time.map { 0.7 + 0.3 * sin($0 * 2.2 + seed) } ?? 1
                let strength: Double = (0.45 + 0.45 * fade) * twinkle
                PrestigeGem.glint(&context, at: star, size: 2.4, opacity: strength)
            }
        }
    }

    // MARK: Eternal: iridescence travels across the whole piece.

    private func iridescence(_ context: inout GraphicsContext) {
        let t = time ?? 1.5
        var body = plate
        for side: CGFloat in [-1, 1] {
            let anchor = CGPoint(x: side < 0 ? 7 : size.width - 7, y: size.height * 0.4)
            for feather in PrestigeOutline.wing(at: anchor, side: side, length: RankOrnaments.wingLength(8), feathers: 4) {
                body.addPath(PrestigeOutline.path(feather))
            }
        }
        // A spectrum that repeats along a diagonal and drifts by exactly one
        // repeat per cycle. Its first and last hue are the same, so the colour
        // keeps travelling with no seam and nothing ever starts over.
        let repeatLength = CGVector(dx: 70, dy: 22)
        let drift = CGFloat((t / 6).truncatingRemainder(dividingBy: 1))
        let start = CGPoint(x: repeatLength.dx * drift, y: repeatLength.dy * drift)
        context.drawLayer { layer in
            layer.clip(to: body)
            layer.blendMode = .screen
            let hues = [0.0, 0.14, 0.3, 0.5, 0.66, 0.82, 1.0]
            let colors = hues.map { Color(hue: $0, saturation: 0.55, brightness: 1).opacity(0.19) }
            layer.fill(Path(CGRect(x: -40, y: -40, width: size.width + 80, height: size.height + 80)),
                       with: .linearGradient(Gradient(colors: colors), startPoint: start,
                                             endPoint: CGPoint(x: start.x + repeatLength.dx, y: start.y + repeatLength.dy),
                                             options: .repeat))
        }
        // Fire in the diamond: a coloured point of light every so often.
        let u = cycle(1.7, still: 0.5)
        let a = time == nil ? 0.6 : pulse(u, 0, 0.9)
        guard a > 0.01 else { return }
        let turn = (time ?? 0) / 1.7
        let spot = CGPoint(x: gem.x + CGFloat(cos(turn * 2.4)) * 4, y: gem.y - 2 + CGFloat(sin(turn * 3.1)) * 3)
        context.fill(Path(ellipseIn: CGRect(x: spot.x - 3, y: spot.y - 3, width: 6, height: 6)),
                     with: .radialGradient(Gradient(colors: [Color(hue: turn.truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 1).opacity(0.8 * a), .clear]),
                                           center: spot, startRadius: 0, endRadius: 3))
        PrestigeGem.glint(&context, at: spot, size: 3.2, opacity: 0.9 * a)
    }
}
