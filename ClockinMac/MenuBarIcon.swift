import AppKit

/// The menu-bar icon: the Clockin mascot's head, so it reads as Clockin rather
/// than a generic stopwatch.
///
/// - idle: an outlined head with closed eyes, asleep while you are not working;
/// - running: a solid head with the mascot's happy eyes in its visor;
/// - paused: an outlined head with pause bars for eyes.
///
/// Drawn as a vector template image on a 20 × 18 pt canvas, so macOS tints it for
/// light and dark menu bars and it stays crisp at every scale.
enum MenuBarIcon {
    enum State: Sendable { case idle, running, paused }

    /// A template image whose height is `pointSize` (default size 20 × 18 pt).
    @MainActor static func image(_ state: State, pointSize: CGFloat = 18) -> NSImage {
        let pointSize = pointSize.isFinite && pointSize > 0 ? min(pointSize, 256) : 18
        let image = NSImage(size: NSSize(width: pointSize * 20 / 18, height: pointSize), flipped: false) { @Sendable rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }
            context.translateBy(x: rect.minX, y: rect.minY)
            context.scaleBy(x: rect.width / 20, y: rect.height / 18)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.setStrokeColor(CGColor(gray: 0, alpha: 1))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            // Knockouts must only clear this icon's own pixels.
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            defer { context.endTransparencyLayer() }
            draw(state, in: context)
            return true
        }
        image.isTemplate = true
        return image
    }

    // Unflipped 20 × 18 pt coordinates. A 17 × 15 pt helmet, with small ear
    // tabs, gives 19 × 15 pt of ink. No antenna competes with the face for height.
    private static let head = CGRect(x: 1.5, y: 1.5, width: 17, height: 15)
    private static let visor = CGRect(x: 4, y: 5, width: 12, height: 8)
    private static let line: CGFloat = 1.5

    // Broad domed crown and a tighter jaw retain the mascot's helmet silhouette.
    // Insetting both the bounds and radii keeps filled/outlined silhouettes equal.
    private static func helmet(in rect: CGRect, inset: CGFloat) -> CGPath {
        let top: CGFloat = 5.5 - inset
        let bottom: CGFloat = 3.5 - inset
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + bottom, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: bottom)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: top)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: top)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: bottom)
        path.closeSubpath()
        return path
    }

    private static func draw(_ state: State, in context: CGContext) {
        let solid = state == .running
        let outline = solid ? head : head.insetBy(dx: line / 2, dy: line / 2)
        let headPath = helmet(in: outline, inset: solid ? 0 : line / 2)

        // Ears, as on the mascot's helmet.
        for x in [head.minX - 1, head.maxX - 1] {
            context.addPath(CGPath(roundedRect: CGRect(x: x, y: 7, width: 2, height: 4),
                                   cornerWidth: 0.75, cornerHeight: 0.75, transform: nil))
        }
        context.fillPath()

        context.setLineWidth(line)
        context.addPath(headPath)
        if solid { context.fillPath() } else { context.strokePath() }

        switch state {
        case .running:
            // The visor is cut out of the solid head and the eyes sit in it.
            context.setBlendMode(.clear)
            context.addPath(CGPath(roundedRect: visor, cornerWidth: 3, cornerHeight: 3, transform: nil))
            context.fillPath()
            context.setBlendMode(.normal)
            context.setLineWidth(line)
            for x in [7.5, 12.5] {
                // Happy, upturned arcs like the mascot's eyes.
                context.addArc(center: CGPoint(x: x, y: 7.5), radius: 1.4,
                               startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
                context.strokePath()
            }
        case .idle:
            context.setLineWidth(line)
            for x in [6.5, 11.5] {
                context.move(to: CGPoint(x: x, y: 8.5))
                context.addLine(to: CGPoint(x: x + 2, y: 8.5))
            }
            context.strokePath()
        case .paused:
            for x in [7.0, 11.5] {
                context.addPath(CGPath(roundedRect: CGRect(x: x, y: 6.5, width: 1.5, height: 4),
                                       cornerWidth: 0.5, cornerHeight: 0.5, transform: nil))
            }
            context.fillPath()
        }
    }
}
