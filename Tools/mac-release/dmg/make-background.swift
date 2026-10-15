// Draws the DMG window background: a soft light field, an arrow from the
// Clockin icon to the Applications folder, and one line telling people what to
// do. Writes a 1x and a 2x PNG and combines them into background.tiff, which
// package.sh hands to dmgbuild.
//
//   swift Tools/mac-release/dmg/make-background.swift
//
// The geometry matches dmg-settings.py: a 640 x 400 pt window with 128 pt icons
// centred at (160, 180) and (480, 180), measured from the top left.
import AppKit
import CoreGraphics

let width: CGFloat = 640
let height: CGFloat = 400
let leftIcon = CGPoint(x: 160, y: 180)
let rightIcon = CGPoint(x: 480, y: 180)
let directory = URL(fileURLWithPath: CommandLine.arguments.first.map { ($0 as NSString).deletingLastPathComponent } ?? ".")
    .standardizedFileURL

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    // Flip so y runs down, like Finder's icon positions.
    context.translateBy(x: 0, y: height)
    context.scaleBy(x: 1, y: -1)

    // A light field with a faint vertical falloff, the website's paper color.
    let field = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [color(0xF7F8FA), color(0xECEEF2)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(field, start: .zero, end: CGPoint(x: 0, y: height), options: [])

    // Two soft wells the icons sit in, so the eye reads "from here to there".
    for center in [leftIcon, rightIcon] {
        let well = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [color(0xFFFFFF, 0.95), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(well, startCenter: center, startRadius: 0, endCenter: center, endRadius: 108, options: [])
    }

    // The arrow: a gentle arc between the icons, in the site's orange.
    let start = CGPoint(x: leftIcon.x + 92, y: leftIcon.y - 4)
    let end = CGPoint(x: rightIcon.x - 98, y: rightIcon.y - 4)
    let control = CGPoint(x: (start.x + end.x) / 2, y: start.y - 34)
    context.setStrokeColor(color(0xF78A18))
    context.setLineWidth(5)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: start)
    context.addQuadCurve(to: end, control: control)
    context.strokePath()
    // Arrowhead along the curve's final direction.
    let angle = atan2(end.y - control.y, end.x - control.x)
    let head: CGFloat = 17
    for side in [-1.0, 1.0] as [CGFloat] {
        let wing = angle + .pi + side * .pi / 5.2
        context.move(to: end)
        context.addLine(to: CGPoint(x: end.x + cos(wing) * head, y: end.y + sin(wing) * head))
    }
    context.strokePath()

    // The instruction, English and Turkish, centred under the icons.
    NSGraphicsContext.current = graphics
    context.saveGState()
    context.translateBy(x: 0, y: height)
    context.scaleBy(x: 1, y: -1)
    func line(_ text: String, size: CGFloat, weight: NSFont.Weight, hex: UInt32, baseline: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(cgColor: color(hex))!,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let measured = string.size()
        string.draw(at: CGPoint(x: (width - measured.width) / 2, y: height - baseline))
    }
    line("Drag Clockin into the Applications folder", size: 15, weight: .semibold, hex: 0x20242B, baseline: 318)
    line("Kurmak için Clockin’i Applications klasörüne sürükleyin", size: 12.5, weight: .regular, hex: 0x626873, baseline: 342)
    context.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let one = directory.appendingPathComponent("background.png")
let two = directory.appendingPathComponent("background@2x.png")
try render(scale: 1).write(to: one)
try render(scale: 2).write(to: two)
let tiff = directory.appendingPathComponent("background.tiff")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
process.arguments = ["-cathidpicheck", one.path, two.path, "-out", tiff.path]
try process.run()
process.waitUntilExit()
precondition(process.terminationStatus == 0, "tiffutil failed")
print("wrote \(tiff.path)")
