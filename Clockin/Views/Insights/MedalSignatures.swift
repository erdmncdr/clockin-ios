import SwiftUI

private enum MedalMotion {
    static func ease(_ value: Double) -> Double {
        let t = max(0, min(1, value))
        return t * t * (3 - 2 * t)
    }

    static func bell(_ value: Double) -> Double {
        let t = max(0, min(1, value))
        return pow(sin(t * .pi), 2)
    }
}

/// Only the effect enters the clock, so the forged surfaces remain cached.
struct MedalSignature: View {
    let tier: BadgeTier
    var phase: Double
    var continuous: Bool
    var still: Bool
    var motionVisible: Bool
    @State private var visible = false
    @State private var ready = false
    @State private var epoch = Date.now

    private var paused: Bool { still || !visible || !motionVisible || !ready || tier == .launch }

    var body: some View {
        Group {
            if continuous {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { clock in
                    MedalSignatureDrawing(tier: tier, phase: still ? 0.46 : phase,
                                          time: ready && !still ? max(0, clock.date.timeIntervalSince(epoch)) : 0,
                                          continuous: ready && tier != .launch, still: still)
                }
            } else {
                MedalSignatureDrawing(tier: tier, phase: still ? 0.46 : phase,
                                      time: 0, continuous: false, still: still)
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .task(id: phase) {
            ready = false
            guard continuous, !still, tier != .launch else { return }
            do { try await Task.sleep(for: .seconds(1.8)) } catch { return }
            epoch = .now
            ready = true
        }
        .onChange(of: still) { _, frozen in
            if !frozen { epoch = .now; ready = continuous }
        }
        .onChange(of: motionVisible) { _, shown in
            if shown { epoch = .now }
        }
    }
}

struct MedalSignatureDrawing: View, Animatable {
    let tier: BadgeTier
    nonisolated var phase: Double
    var time: Double
    var continuous: Bool
    var still: Bool
    nonisolated var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            guard side > 0 else { return }
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: side, y: side)
            // Even blurred light stays within the allowed physical footprint.
            let radius = tier == .solar || tier == .launch ? 0.44 * 1.12 : 0.44
            context.clip(to: circle(radius))
            if continuous && !still {
                let blend = MedalMotion.ease(time / 0.9)
                var reveal = context
                reveal.opacity = 1 - blend
                draw(&reveal, progress: phase, drift: 0, looping: false)
                context.opacity = blend
                draw(&context, progress: 0.46, drift: time, looping: true)
            } else {
                draw(&context, progress: phase, drift: 0, looping: still)
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, progress: Double, drift: Double, looping: Bool) {
        let p = max(0, min(1, progress))
        switch tier {
        case .launch: launch(&context, p: p, still: looping)
        case .orbit: orbit(&context, p: p, time: drift, looping: looping)
        case .lunar: lunar(&context, p: p, time: drift, looping: looping)
        case .solar: solar(&context, p: p, time: drift, looping: looping)
        case .galactic: galactic(&context, p: p, time: drift, looping: looping)
        case .eternal: eternal(&context, p: p, time: drift, looping: looping)
        }
    }

    private func circle(_ radius: Double, x: Double = 0, y: Double = 0) -> Path {
        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    private func glow(_ context: inout GraphicsContext, at point: CGPoint,
                      radius: Double, color: Color, opacity: Double) {
        guard opacity > 0.001 else { return }
        context.fill(circle(radius, x: point.x, y: point.y), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.28), .clear]),
            center: point, startRadius: 0, endRadius: radius))
    }

    private func launch(_ context: inout GraphicsContext, p: Double, still: Bool) {
        // Staggered grains leave the stone, cool and disappear with distance.
        for i in 0..<9 {
            let age = still ? 0.2 + Double(i) * 0.055 : (p - Double(i) * 0.038) / 0.67
            guard age > 0, age < 1 else { continue }
            let travel = MedalMotion.ease(age)
            let spread = Double((i * 7) % 9 - 4) * 0.022
            let x = spread * (0.2 + travel)
            let y = 0.3975 - travel * (0.57 + Double(i % 3) * 0.065)
            let alpha = MedalMotion.ease(age / 0.14) * pow(1 - age, 1.5)
            glow(&context, at: CGPoint(x: x, y: y), radius: 0.018,
                 color: tier.tint, opacity: alpha * 0.5)
            glow(&context, at: CGPoint(x: x - 0.001, y: y - 0.002), radius: 0.006,
                 color: .white, opacity: alpha * 0.7)
        }
    }

    private func orbit(_ context: inout GraphicsContext, p: Double, time: Double, looping: Bool) {
        let angle = (looping ? time / 12 + 0.12 : MedalMotion.ease(p)) * .pi * 2 + .pi / 2
        let alpha = looping ? 1 : MedalMotion.ease(p / 0.12) * MedalMotion.ease((1 - p) / 0.12)
        // The far half is hidden by the ring; the near half rides its inner lip.
        let depth = sin(angle)
        let visibility = MedalMotion.ease((depth + 0.18) / 0.38)
        guard visibility > 0 else { return }
        let point = CGPoint(x: cos(angle) * 0.372, y: depth * 0.32)
        context.opacity *= alpha * visibility
        glow(&context, at: point, radius: 0.041, color: tier.tint, opacity: 0.27)
        let moon = circle(0.014, x: point.x, y: point.y)
        context.fill(moon, with: .radialGradient(Gradient(colors: [.white.opacity(0.9), tier.tone.metal(0.7), tier.tone.metal(0.18)]),
                                                center: CGPoint(x: point.x - 0.005, y: point.y - 0.006),
                                                startRadius: 0, endRadius: 0.025))
    }

    private func lunar(_ context: inout GraphicsContext, p: Double, time: Double, looping: Bool) {
        let travel = looping ? 0.5 + 0.45 * sin(time * .pi / 9 - 0.4) : MedalMotion.ease(p)
        let alpha = looping ? 0.46 : 0.62 * MedalMotion.bell(p)
        context.clip(to: circle(0.338))
        context.drawLayer { shadow in
            shadow.addFilter(.blur(radius: 0.022))
            let x = -0.64 + travel * 1.28
            shadow.fill(circle(0.37, x: x, y: 0.025), with: .color(.black.opacity(alpha)))
            // A cool, broad penumbra catches the top-left light.
            shadow.stroke(circle(0.37, x: x - 0.01, y: 0.025),
                          with: .color(tier.tint.opacity(alpha * 0.16)), lineWidth: 0.025)
        }
    }

    private func solar(_ context: inout GraphicsContext, p: Double, time: Double, looping: Bool) {
        let opening = looping ? 1 : MedalMotion.ease(p / 0.8)
        guard opening > 0 else { return }
        let turn = time * .pi / 32
        // The solid medal occludes the roots, leaving soft tapered rays outside.
        context.drawLayer { halo in
            halo.addFilter(.blur(radius: 0.012))
            halo.blendMode = .plusLighter
            halo.stroke(circle(0.45), with: .color(Color(hue: 0.1, saturation: 0.6, brightness: 1).opacity(0.3 * opening)), lineWidth: 0.03)
        }
        context.drawLayer { corona in
            // Rays are light, so they add to what is behind them instead of covering it.
            corona.blendMode = .plusLighter
            corona.addFilter(.blur(radius: 0.006))
            for i in 0..<16 {
                let angle = Double(i) * .pi / 8 + turn
                let exposure = PrestigeLight.exposure(CGVector(dx: cos(angle), dy: sin(angle)))
                let breathe = looping ? 0.97 + 0.03 * sin(time * .pi / 5) : 1
                let radius = 0.42 + (i.isMultiple(of: 2) ? 0.069 : 0.044) * opening * breathe
                var ray = Path()
                ray.move(to: CGPoint(x: cos(angle - 0.07) * 0.405, y: sin(angle - 0.07) * 0.405))
                ray.addQuadCurve(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius),
                                 control: CGPoint(x: cos(angle - 0.028) * radius, y: sin(angle - 0.028) * radius))
                ray.addQuadCurve(to: CGPoint(x: cos(angle + 0.07) * 0.405, y: sin(angle + 0.07) * 0.405),
                                 control: CGPoint(x: cos(angle + 0.028) * radius, y: sin(angle + 0.028) * radius))
                ray.closeSubpath()
                let warm = Color(hue: 0.11, saturation: 0.45, brightness: 1)
                corona.fill(ray, with: .radialGradient(Gradient(colors: [warm.opacity((0.55 + 0.35 * exposure) * opening),
                    tier.tint.opacity((0.3 + 0.2 * exposure) * opening), .clear]),
                    center: .zero, startRadius: 0.438, endRadius: max(0.439, radius)))
            }
        }
    }

    private func galactic(_ context: inout GraphicsContext, p: Double, time: Double, looping: Bool) {
        context.clip(to: circle(0.337))
        for arm in 0..<3 {
            for i in 0..<18 {
                let seed = Double(i) / 18
                let age = looping ? seed : (p - seed * 0.23) / 0.77
                guard age >= 0, age <= 1 else { continue }
                let travel = looping ? seed : MedalMotion.ease(age)
                let r = 0.315 * (1 - travel) + 0.012
                let angle = Double(arm) * .pi * 2 / 3 + travel * .pi * 2.1 + time * .pi / 18
                let alpha = looping ? 0.16 * sin(seed * .pi) : 0.5 * MedalMotion.bell(age)
                let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r * 0.86)
                glow(&context, at: point, radius: looping ? 0.024 : 0.012,
                     color: i.isMultiple(of: 4) ? .white : tier.tint, opacity: alpha)
            }
        }
    }

    private func eternal(_ context: inout GraphicsContext, p: Double, time: Double, looping: Bool) {
        let alpha = looping ? 0.65 : MedalMotion.bell(p)
        guard alpha > 0.001 else { return }
        context.opacity *= alpha
        // Broken specular reflections make the two circular bands' rotation legible.
        for band in 0..<2 {
            let radius = band == 0 ? 0.424 : 0.367
            let angle = (band == 0 ? 1.0 : -1.0) * (looping ? time * .pi / 22 : MedalMotion.ease(p) * .pi * 1.3)
            context.drawLayer { ring in
                ring.addFilter(.blur(radius: 0.004))
                for i in 0..<5 {
                    let a = angle + Double(i) * .pi * 2 / 5
                    var arc = Path()
                    arc.addArc(center: .zero, radius: radius, startAngle: .radians(a), endAngle: .radians(a + 0.24), clockwise: false)
                    let light = PrestigeLight.exposure(CGVector(dx: cos(a), dy: sin(a)))
                    ring.stroke(arc, with: .color(tier.tone.metal(0.95).opacity(0.1 + light * 0.3)),
                                style: StrokeStyle(lineWidth: band == 0 ? 0.013 : 0.019, lineCap: .round))
                }
            }
        }
        context.drawLayer { sheen in
            sheen.addFilter(.blur(radius: 0.032))
            let x = looping ? sin(time * .pi / 10) * 0.35 : -0.6 + MedalMotion.ease(p) * 1.2
            var band = Path()
            band.addLines([CGPoint(x: x - 0.19, y: 0.5), CGPoint(x: x + 0.03, y: -0.5),
                           CGPoint(x: x + 0.23, y: -0.5), CGPoint(x: x + 0.01, y: 0.5)])
            band.closeSubpath()
            sheen.fill(band, with: .linearGradient(Gradient(colors: [Color.cyan.opacity(0.04),
                .white.opacity(0.18), Color(red: 1, green: 0.68, blue: 0.8).opacity(0.13), .clear]),
                startPoint: CGPoint(x: x - 0.1, y: -0.1), endPoint: CGPoint(x: x + 0.2, y: 0.05)))
        }
    }
}

/// Metal is rendered independently of the transform applied during a reveal.
struct MedalEmblem: View, Animatable {
    let emblem: CGPath
    let tier: BadgeTier
    let lit: Bool
    let mission: BadgeMission?
    nonisolated var phase: Double
    nonisolated var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    private var p: Double { lit ? max(0, min(1, phase)) : 1 }

    var body: some View {
        GeometryReader { geometry in
            let s = min(geometry.size.width, geometry.size.height)
            ZStack {
                if mission == .archive && lit && p < 1 {
                    ZStack {
                        ForEach(0..<3) { index in
                            MedalEmblemMetal(emblem: archiveLayer(index), tier: tier, lit: lit)
                                .equatable()
                                .offset(y: -s * 0.065 * (1 - MedalMotion.ease((p - Double(2 - index) * 0.16) / 0.52)))
                                .opacity(MedalMotion.ease((p - Double(2 - index) * 0.16) / 0.3))
                        }
                    }
                    .opacity(1 - MedalMotion.ease((p - 0.82) / 0.18))
                    MedalEmblemMetal(emblem: emblem, tier: tier, lit: lit)
                        .equatable()
                        .opacity(MedalMotion.ease((p - 0.82) / 0.18))
                } else {
                    MedalEmblemMetal(emblem: emblem, tier: tier, lit: lit)
                        .equatable()
                        .offset(y: mission == .flight ? -s * 0.05 * MedalMotion.bell(p) : 0)
                        .rotationEffect(.degrees(mission == .orbit ? -9 * MedalMotion.bell(p) : 0))
                        .mask(alignment: .bottom) {
                            LinearGradient(stops: [.init(color: .clear, location: 0),
                                                   .init(color: .white, location: 0.04),
                                                   .init(color: .white, location: 1)],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: mission == .habitat && lit ?
                                    geometry.size.height * (0.23 + 0.77 * MedalMotion.ease(p / 0.88)) : geometry.size.height)
                        }
                }
                if lit && (mission == .signal || mission == .suit) {
                    MedalEmblemGlint(emblem: emblem, tier: tier, mission: mission, phase: p)
                }
            }
            .clipShape(Circle().scale(0.88))
        }
    }

    private func archiveLayer(_ index: Int) -> CGPath {
        let path = CGMutablePath()
        let y = 33.0 + Double(index) * 16
        path.addLines(between: [CGPoint(x: 19, y: y), CGPoint(x: 50, y: y + 17),
                               CGPoint(x: 81, y: y), CGPoint(x: 50, y: y - 17)])
        path.closeSubpath()
        return path
    }
}

private struct MedalEmblemMetal: View, @MainActor Equatable {
    let emblem: CGPath
    let tier: BadgeTier
    let lit: Bool

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let tone = lit ? tier.tone : ForgeTone(hue: tier.tone.hue, saturation: 0.1, brightness: 0.42)
            let fr = s * (tier == .eternal ? 0.29 : tier.rawValue >= 3 ? 0.34 : 0.355)
            let box = fr * 1.18
            let scale = box / 100
            let transform = CGAffineTransform(translationX: c.x - box / 2, y: c.y - box / 2 - fr * 0.04).scaledBy(x: scale, y: scale)
            let mark = Path(emblem).applying(transform)
            let w = max(1.2, s * 0.042)
            let round = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
            if lit {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: max(0.5, s * 0.012)))
                    layer.stroke(mark.offsetBy(dx: 0, dy: s * 0.016), with: .color(.black.opacity(0.75)), style: round)
                }
                context.stroke(mark, with: .linearGradient(Gradient(colors: [tone.metal(1), tone.metal(0.72), tone.metal(0.42)]),
                                                           startPoint: CGPoint(x: c.x, y: c.y - box / 2), endPoint: CGPoint(x: c.x, y: c.y + box / 2)),
                               style: round)
                context.stroke(mark.offsetBy(dx: 0, dy: -w * 0.22), with: .color(.white.opacity(0.4)),
                               style: StrokeStyle(lineWidth: w * 0.3, lineCap: .round, lineJoin: .round))
            } else {
                context.stroke(mark.offsetBy(dx: 0, dy: w * 0.25), with: .color(.white.opacity(0.1)), style: round)
                context.stroke(mark, with: .color(.black.opacity(0.55)), style: round)
            }

        }
    }
}

private struct MedalEmblemGlint: View {
    let emblem: CGPath
    let tier: BadgeTier
    let mission: BadgeMission?
    let phase: Double

    var body: some View {
        Canvas { context, size in
            guard phase > 0, phase < 1 else { return }
            let s = min(size.width, size.height)
            let fr = s * (tier == .eternal ? 0.29 : tier.rawValue >= 3 ? 0.34 : 0.355)
            let box = fr * 1.18
            let origin = CGPoint(x: size.width / 2 - box / 2, y: size.height / 2 - box / 2 - fr * 0.04)
            let transform = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: box / 100, y: box / 100)
            let mark = Path(emblem).applying(transform)
            let pulse = mission == .signal ? (phase * 2).truncatingRemainder(dividingBy: 1) : phase
            let alpha = MedalMotion.bell(pulse)
            if mission == .signal {
                context.clip(to: mark.strokedPath(StrokeStyle(lineWidth: max(1.2, s * 0.042), lineCap: .round, lineJoin: .round)))
            } else {
                let visor = CGRect(x: origin.x + box * 0.28, y: origin.y + box * 0.35,
                                   width: box * 0.44, height: box * 0.25)
                context.clip(to: Path(roundedRect: visor, cornerRadius: box * 0.1))
            }
            context.addFilter(.blur(radius: s * 0.013))
            let x = origin.x + box * MedalMotion.ease(pulse)
            let rect = CGRect(x: x - s * 0.035, y: origin.y, width: s * 0.07, height: box)
            context.fill(Path(rect), with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.45 * alpha), .clear]),
                                                          startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                                          endPoint: CGPoint(x: rect.maxX, y: rect.minY)))
        }
    }
}
