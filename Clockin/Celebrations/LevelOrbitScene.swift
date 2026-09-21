import SwiftUI

struct LevelOrbitScene: View {
    let moving: Bool
    let companionEnabled: Bool
    var level = 1
    @State private var began = Date()
    private var style: LevelPrestige { .init(level: level) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !moving)) { clock in
            let t = moving ? max(0, clock.date.timeIntervalSince(began)) : 2.0
            ZStack {
                Canvas { context, size in
                    for i in 0..<28 {
                        let x = CGFloat((i * 73 + 19) % 307) / 307 * size.width
                        let y = CGFloat((i * 47 + 11) % 173) / 173 * size.height
                        let pulse = 0.2 + 0.12 * sin(t * 0.8 + Double(i))
                        let r: CGFloat = i.isMultiple(of: 7) ? 1.5 : 0.7
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(style.highlight.opacity(pulse)))
                    }
                }
                Circle().fill(RadialGradient(colors: [style.tint.opacity(0.24), style.shade.opacity(0.08), .clear], center: .center, startRadius: 5, endRadius: 135))
                    .frame(width: 280, height: 280)
                if moving {
                    // A short pulse is timed after the card has settled into place.
                    PrestigeUnlockBurst(style: style, elapsed: t - 0.3)
                        .opacity(style.isMilestone ? 1 : 0.28)
                }
                OrbitComets(time: t, style: style, front: false)
                if companionEnabled {
                    OrbitAstronaut()
                        .scaleEffect(0.86)
                        .rotationEffect(.degrees(-5 + sin(t * 0.7) * 1.4))
                        .offset(y: -4 + sin(t * 0.7) * 3)
                        .shadow(color: style.tint.opacity(0.2), radius: 14, x: -8, y: -3)
                } else {
                    PrestigeInsignia(style: style).frame(width: 26, height: 28)
                        .scaleEffect(2.8).frame(width: 76, height: 86)
                        .shadow(color: style.tint.opacity(0.35), radius: 20)
                }
                OrbitComets(time: t, style: style, front: true)
                Circle().fill(RadialGradient(colors: [style.tint.opacity(0.6), Color(red: 0.09, green: 0.18, blue: 0.28), Color(red: 0.025, green: 0.045, blue: 0.09)], center: .topLeading, startRadius: 0, endRadius: 340))
                    .overlay(Circle().stroke(style.highlight.opacity(0.38), lineWidth: 1))
                    .overlay(alignment: .top) {
                        Ellipse().fill(style.tint.opacity(0.35)).frame(width: 230, height: 14).blur(radius: 8).offset(y: -2)
                    }
                    .frame(width: 380, height: 380).offset(y: 296)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 226).clipped().accessibilityHidden(true)
        .onAppear { began = .now }
        .onChange(of: level) { _, _ in began = .now }
    }
}

/// The rear and front passes let the comet orbit behind and in front of the suit.
private struct OrbitComets: View {
    let time: Double
    let style: LevelPrestige
    let front: Bool
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
            let rx = min(size.width * 0.39, 139.0), ry = 42.0
            func point(_ angle: Double) -> CGPoint {
                let x = cos(angle) * rx, y = sin(angle) * ry
                return CGPoint(x: center.x + x * 0.94 + y * 0.34,
                               y: center.y - x * 0.34 + y * 0.94)
            }
            var orbit = Path()
            for i in 0...120 {
                let a = Double(i) / 120 * .pi * 2
                if (sin(a) >= 0) == front {
                    let p = point(a)
                    if orbit.isEmpty { orbit.move(to: p) } else { orbit.addLine(to: p) }
                }
            }
            context.stroke(orbit, with: .color(style.tint.opacity(front ? 0.22 : 0.1)), lineWidth: 1)
            let count = style.stage >= 4 ? 2 : 1
            for comet in 0..<count {
                let head = time * 0.65 + Double(comet) * .pi * 2 / Double(count)
                for segment in (0..<48).reversed() {
                    let angle = head - Double(segment) * 0.017
                    guard (sin(angle) >= 0) == front else { continue }
                    let p = point(angle), fade = 1 - Double(segment) / 48
                    let radius = 0.8 + fade * 2.4
                    let dot = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
                    context.fill(dot, with: .color(style.tint.opacity(fade * fade * (front ? 0.8 : 0.4))))
                }
                if (sin(head) >= 0) == front {
                    let p = point(head)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                        with: .radialGradient(Gradient(colors: [style.tint.opacity(0.75), .clear]), center: p, startRadius: 0, endRadius: 12))
                    var star = Path()
                    star.move(to: CGPoint(x: p.x, y: p.y - 7))
                    star.addLine(to: CGPoint(x: p.x + 2, y: p.y - 2))
                    star.addLine(to: CGPoint(x: p.x + 7, y: p.y))
                    star.addLine(to: CGPoint(x: p.x + 2, y: p.y + 2))
                    star.addLine(to: CGPoint(x: p.x, y: p.y + 7))
                    star.addLine(to: CGPoint(x: p.x - 2, y: p.y + 2))
                    star.addLine(to: CGPoint(x: p.x - 7, y: p.y))
                    star.addLine(to: CGPoint(x: p.x - 2, y: p.y - 2)); star.closeSubpath()
                    context.fill(star, with: .color(.white.opacity(front ? 1 : 0.65)))
                }
            }
        }
    }
}

/// Vector suit with the companion's original pixel face behind the visor.
private struct OrbitAstronaut: View {
    private let rim = Color(red: 0.65, green: 0.75, blue: 0.84)
    private let suit = LinearGradient(colors: [.white, Color(red: 0.71, green: 0.81, blue: 0.9)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17).fill(Color(red: 0.30, green: 0.43, blue: 0.58))
                .frame(width: 88, height: 76).offset(y: 25)
            Capsule().fill(suit).frame(width: 23, height: 58).rotationEffect(.degrees(36)).offset(x: -46, y: 23)
            Capsule().fill(suit).frame(width: 23, height: 58).rotationEffect(.degrees(-48)).offset(x: 47, y: 16)
            Capsule().fill(suit).frame(width: 28, height: 46).rotationEffect(.degrees(14)).offset(x: -21, y: 77)
            Capsule().fill(suit).frame(width: 28, height: 46).rotationEffect(.degrees(-12)).offset(x: 23, y: 75)
            RoundedRectangle(cornerRadius: 24).fill(suit).frame(width: 77, height: 83).offset(y: 31)
            RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.18, green: 0.29, blue: 0.43))
                .frame(width: 38, height: 28).offset(y: 39)
            HStack(spacing: 5) {
                Circle().fill(.cyan).frame(width: 5, height: 5)
                Capsule().fill(.white.opacity(0.55)).frame(width: 14, height: 3)
            }.offset(y: 39)
            Circle().fill(suit).frame(width: 111, height: 111).offset(y: -32)
            Circle().fill(Color(red: 0.035, green: 0.09, blue: 0.16))
                .overlay(Circle().stroke(rim, lineWidth: 3))
                .frame(width: 91, height: 91).offset(y: -32)
            ClockinMascotStill(mood: .hello, maxPixelSize: 314)
                .frame(width: 330, height: 330).offset(x: -9, y: 15)
                .mask(Circle().frame(width: 84, height: 84).offset(y: -32))
            Circle().trim(from: 0.55, to: 0.73).stroke(.white.opacity(0.58), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 73, height: 73).offset(y: -32)
            Capsule().fill(rim).frame(width: 64, height: 8).offset(y: 20)
        }
        .frame(width: 180, height: 210)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 8)
    }
}
