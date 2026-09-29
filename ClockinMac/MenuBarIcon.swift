import AppKit

/// The menu-bar icon: the Clockin mascot's head, so it reads as Clockin rather
/// than a generic stopwatch.
///
/// - idle: an outlined head with closed eyes, asleep while you are not working;
/// - running: a solid head with the mascot's happy eyes in its visor;
/// - paused: an outlined head with pause bars for eyes.
///
/// Drawn as a vector template image on an 18 pt canvas, so macOS tints it for
/// light and dark menu bars and it stays crisp at every scale.
enum MenuBarIcon {
    enum State: Sendable { case idle, running, paused }

    /// A template image for the menu bar, sized in points (default 18×18).
    @MainActor static func image(_ state: State, pointSize: CGFloat = 18) -> NSImage {
        precondition(pointSize.isFinite && pointSize > 0)
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }
            context.translateBy(x: rect.minX, y: rect.minY)
            context.scaleBy(x: rect.width / 18, y: rect.height / 18)
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

    // Coordinates are an unflipped 18 pt canvas: y grows upwards. The artwork
    // spans about 14.6 x 13.5 pt around the centre, with SF Symbols' regular
    // stroke weight, so it sits level with the system's menu-bar icons.
    private static let head = CGRect(x: 2.75, y: 2.3, width: 12.5, height: 10)
    private static let headRadius: CGFloat = 4
    private static let visor = CGRect(x: 4.8, y: 4.3, width: 8.4, height: 5.6)
    private static let line: CGFloat = 1.4

    private static func draw(_ state: State, in context: CGContext) {
        let solid = state == .running
        let outline = solid ? head : head.insetBy(dx: line / 2, dy: line / 2)
        let headPath = CGPath(roundedRect: outline, cornerWidth: headRadius, cornerHeight: headRadius, transform: nil)

        // Ears, as on the mascot's helmet.
        for x in [head.minX - 1.05, head.maxX - 0.15] {
            context.addPath(CGPath(roundedRect: CGRect(x: x, y: 5.4, width: 1.2, height: 3.2),
                                   cornerWidth: 0.6, cornerHeight: 0.6, transform: nil))
        }
        context.fillPath()

        // Antenna: a short stem and the ball, hollow while asleep.
        context.setLineWidth(1.1)
        context.move(to: CGPoint(x: 9, y: head.maxY - 0.2))
        context.addLine(to: CGPoint(x: 9, y: 13.9))
        context.strokePath()
        let ball = CGRect(x: 7.95, y: 13.75, width: 2.1, height: 2.1)
        if state == .idle {
            context.setLineWidth(0.9)
            context.strokeEllipse(in: ball.insetBy(dx: 0.45, dy: 0.45))
        } else {
            context.fillEllipse(in: ball)
        }

        context.setLineWidth(line)
        context.addPath(headPath)
        if solid { context.fillPath() } else { context.strokePath() }

        switch state {
        case .running:
            // The visor is cut out of the solid head and the eyes sit in it.
            context.setBlendMode(.clear)
            context.addPath(CGPath(roundedRect: visor, cornerWidth: 2.3, cornerHeight: 2.3, transform: nil))
            context.fillPath()
            context.setBlendMode(.normal)
            context.setLineWidth(1.25)
            for x in [7.3, 10.7] {
                // Happy, upturned arcs like the mascot's eyes.
                context.addArc(center: CGPoint(x: x, y: 6.5), radius: 1,
                               startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
                context.strokePath()
            }
        case .idle:
            context.setLineWidth(1.25)
            for x in [6.9, 10.1] {
                context.move(to: CGPoint(x: x, y: 7))
                context.addLine(to: CGPoint(x: x + 1, y: 7))
            }
            context.strokePath()
        case .paused:
            for x in [7.0, 9.8] {
                context.addPath(CGPath(roundedRect: CGRect(x: x, y: 5.4, width: 1.2, height: 3.4),
                                       cornerWidth: 0.6, cornerHeight: 0.6, transform: nil))
            }
            context.fillPath()
        }
    }
}
