import SwiftUI

/// Unit geometry keeps the original sample endpoints and centre-line split.
/// Transform the paths, not the context, so strokes keep their screen width.
enum LevelUpSigilGeometry {
    struct Sample: Sendable {
        let angle: Double
        let point: CGPoint
    }

    static let dashSamples = samples(steps: 720)
    private static let rings = [prefixes(front: false), prefixes(front: true)]

    static func ring(drawn: Double, front: Bool) -> Path {
        rings[front ? 1 : 0][Int(180 * drawn)]
    }

    private static func samples(steps: Int) -> [Sample] {
        (0...steps).map { i in
            let angle = -Double.pi / 2 + Double(i) / Double(steps) * 2 * .pi
            return Sample(angle: angle, point: CGPoint(x: cos(angle), y: sin(angle)))
        }
    }

    private static func prefixes(front: Bool) -> [Path] {
        var path = Path()
        var open = false
        return samples(steps: 180).map { sample in
            if (sample.point.y >= 0) == front {
                if open { path.addLine(to: sample.point) } else { path.move(to: sample.point); open = true }
            } else {
                open = false
            }
            return path
        }
    }
}
