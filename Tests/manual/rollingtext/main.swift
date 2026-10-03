import AppKit
import SwiftUI

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
}

// The original Mac overlay proposed 64 x 13 for a 67 x 15 rolling caption.
let font = RollingNumberFont.resolve(.caption.weight(.semibold), design: .default, sizeCategory: .large)
let sample = RollingNumberSample(text: "$1,36 kaldı", value: 1.36)
let layout = RollingNumberFont.layout(sample.text, font: font)
let view = RollingNumberUIView()
view.update(sample: sample, font: font, color: .orange, layout: layout,
            canAnimate: false, minimumScaleFactor: 1)
check(view.fittingSize(width: 64).width >= layout.naturalSize.width,
      "a narrow placeholder cannot clip the final Turkish letter with scaling disabled")

@MainActor func inkPixels(in glyph: NSView) -> Int {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: max(1, Int(ceil(glyph.bounds.width * 2))),
        pixelsHigh: max(1, Int(ceil(glyph.bounds.height * 2))),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: 2, y: 2)
    // Exercise the production AppKit glyph drawing, without a window/server.
    glyph.draw(glyph.bounds)
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.bitmapData!
    return (0..<bitmap.pixelsHigh).reduce(0) { count, y in
        count + (0..<bitmap.pixelsWide).filter { x in
            data[y * bitmap.bytesPerRow + x * 4 + 3] > 0
        }.count
    }
}

let strings = [
    "$1,36 kaldı", "$10,00 kaldı", "₺1.234.567.890,99 kaldı",
    "1 sa 09 dk kaldı", "Hedefe ulaşıldı", "ı ğ ş ç İ", "g\u{306} s\u{327} I\u{307}",
    "$1.36 to go", "$10.00 to go", "$1,234,567,890.99 to go",
    "1h 09m to go", "Goal reached", "$1,234,567,890.99", "1.234.567.890,99 ₺"
]
// Includes every shared recipe and the explicit Mac money sizes, plus 120 pt.
let sizes: [CGFloat] = [9, 12, 13, 14, 15, 16, 17, 20, 21, 23, 24, 28, 30, 60, 120]
let designs: [Font.Design] = [.default, .rounded, .serif, .monospaced]
var cases = 0
for design in designs {
    for size in sizes {
        let font = RollingNumberFont.resolve(size: size, weight: .semibold, design: design)
        for text in strings {
            cases += 1
            let label = "\(design)/\(size)/\(text)"
            let layout = RollingNumberFont.layout(text, font: font)
            let diff = RollingNumberUpdate(from: .init(text: "", value: 0), to: .init(text: text, value: 1))
            check(layout.widths.count == text.count && diff.cells.count == text.count,
                  "\(label): one width and rendered cell per grapheme")
            check(String(diff.cells.map(\.character)) == text && layout.widths.allSatisfy { $0 > 0 },
                  "\(label): every Turkish character survives with positive advance")
            let shaped = (text as NSString).size(withAttributes: [.font: font]).width
            check(layout.naturalSize.width + 0.01 >= shaped,
                  "\(label): separately measured cells contain the shaped string")
            view.update(sample: .init(text: text, value: 1), font: font, color: .orange,
                        layout: layout, canAnimate: false, minimumScaleFactor: 1)
            view.frame = CGRect(origin: .zero, size: view.fittingSize(width: nil))
            view.layoutSubtreeIfNeeded()
            let cells = view.subviews[0].subviews.sorted { $0.frame.minX < $1.frame.minX }
            check(cells.count == text.count && view.accessibilityLabel() == text,
                  "\(label): native renderer retains all cells and accessible text")
            var rendered = 0
            for (character, cell) in zip(text, cells) {
                let visible = cell.subviews.filter { $0.layer?.opacity == 1 }
                check(visible.count == 1, "\(label): one settled glyph per cell")
                if inkPixels(in: visible[0]) > 0 { rendered += 1 }
                if !character.isWhitespace {
                    // Check actual font glyph coverage separately from a visible .notdef box.
                    let line = CTLineCreateWithAttributedString(NSAttributedString(
                        string: String(character), attributes: [.font: font]))
                    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
                    check(!runs.isEmpty && runs.allSatisfy { run in
                        var glyphs = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
                        CTRunGetGlyphs(run, CFRange(), &glyphs)
                        return !glyphs.isEmpty && glyphs.allSatisfy { $0 != 0 }
                    }, "\(label): \(character) has font glyph coverage")
                }
            }
            check(rendered == text.filter { !$0.isWhitespace }.count,
                  "\(label): every non-space character paints pixels, including the suffix")
            for minimum: CGFloat in [1, 0.7, 0.5, 0.4] {
                view.update(sample: .init(text: text, value: 1), font: font, color: .orange,
                            layout: layout, canAnimate: false, minimumScaleFactor: minimum)
                for width: CGFloat in [0, 64, 120, 320, 700, 1920] {
                    let fitted = view.fittingSize(width: width)
                    view.frame = CGRect(origin: .zero, size: fitted)
                    view.layoutSubtreeIfNeeded()
                    let content = view.subviews[0]
                    let scale = content.layer!.affineTransform().a
                    check(scale >= minimum && scale <= 1,
                          "\(label): actual native scale respects caller's floor")
                    check((cells.last?.frame.maxX ?? 0) * scale <= fitted.width + 0.01,
                          "\(label): trailing glyph is inside native clipping bounds at \(width)/\(minimum)")
                    check(fitted.height >= layout.naturalSize.height,
                          "\(label): full line height reserved for accents and descenders")
                }
            }
        }
    }
}
// Unbounded, empty, and non-finite proposals use the natural geometry.
for width: CGFloat? in [nil, .infinity, .nan] {
    check(layout.fittingSize(width: width, minimum: 1) == layout.naturalSize, "unbounded proposal")
}
let empty = RollingNumberLayout(widths: [], lineHeight: 15, ascender: 12)
check(empty.fittingSize(width: 0, minimum: 1) == .zero, "empty text has no reserved bounds")
print("\(checks) rolling text checks passed; \(cases) native font/string cases")
