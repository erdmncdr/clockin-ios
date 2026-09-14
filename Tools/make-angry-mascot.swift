#!/usr/bin/env swift
// Run from the repository root:
// swift -module-cache-path /tmp/clockin-art-module-cache iOS/Tools/make-angry-mascot.swift
// Coordinates use the top-left image origin. All edits are integer pixel copies.
import Foundation
import CoreGraphics
import ImageIO

struct Pixel: Equatable {
    var r: UInt8, g: UInt8, b: UInt8, a: UInt8
    static let clear = Pixel(r: 0, g: 0, b: 0, a: 0)
}

struct Bounds {
    var x0: Int, y0: Int, x1: Int, y1: Int
    var width: Int { x1 - x0 + 1 }
    var height: Int { y1 - y0 + 1 }
    var midX: Int { (x0 + x1) / 2 }
    var midY: Int { (y0 + y1) / 2 }
    func contains(_ x: Int, _ y: Int) -> Bool {
        x >= x0 && x <= x1 && y >= y0 && y <= y1
    }
    func padded(_ n: Int) -> Bounds {
        Bounds(x0: x0 - n, y0: y0 - n, x1: x1 + n, y1: y1 + n)
    }
}

struct Bitmap {
    let width: Int, height: Int
    var bytes: [UInt8]
    init(width: Int, height: Int, fill: Pixel = .clear) {
        self.width = width
        self.height = height
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<width { self[x, y] = fill } }
    }
    init(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Cannot read \(url.path)")
        }
        self.init(width: image.width, height: image.height)
        bytes.withUnsafeMutableBytes { storage in
            let context = CGContext(data: storage.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                    CGBitmapInfo.byteOrder32Big.rawValue)!
            context.interpolationQuality = .none
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
    subscript(x: Int, y: Int) -> Pixel {
        get {
            let i = (y * width + x) * 4
            return Pixel(r: bytes[i], g: bytes[i+1], b: bytes[i+2], a: bytes[i+3])
        }
        set {
            let i = (y * width + x) * 4
            bytes[i] = newValue.r; bytes[i+1] = newValue.g
            bytes[i+2] = newValue.b; bytes[i+3] = newValue.a
        }
    }
    func write(_ url: URL) {
        let data = Data(bytes) as CFData
        let image = CGImage(width: width, height: height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue),
            provider: CGDataProvider(data: data)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent)!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination), "PNG encoding failed")
    }
}

func isCyan(_ p: Pixel) -> Bool {
    p.a > 100 && p.g > 80 && p.b > 90 &&
        Int(p.g) - Int(p.r) > 30 && Int(p.b) - Int(p.r) > 30
}
func isDark(_ p: Pixel) -> Bool { p.a > 240 && max(p.r, p.g, p.b) < 80 }

func components(_ bitmap: Bitmap, matching predicate: (Pixel) -> Bool) -> [[Int]] {
    let w = bitmap.width, h = bitmap.height
    var seen = [Bool](repeating: false, count: w * h)
    var result = [[Int]]()
    for start in 0..<(w * h) where !seen[start] {
        seen[start] = true
        guard predicate(bitmap[start % w, start / w]) else { continue }
        var queue = [start], cursor = 0
        while cursor < queue.count {
            let i = queue[cursor]; cursor += 1
            for n in [i-1, i+1, i-w, i+w] where n >= 0 && n < w*h && abs(n % w - i % w) <= 1 {
                if !seen[n] && predicate(bitmap[n % w, n / w]) {
                    seen[n] = true; queue.append(n)
                }
            }
        }
        result.append(queue)
    }
    return result
}
func bounds(_ pixels: [Int], width: Int) -> Bounds {
    Bounds(x0: pixels.map { $0 % width }.min()!, y0: pixels.map { $0 / width }.min()!,
           x1: pixels.map { $0 % width }.max()!, y1: pixels.map { $0 / width }.max()!)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("iOS/Clockin/Assets.xcassets")
let source = Bitmap(url: assets.appendingPathComponent("pose1.imageset/pose1.png"))
let w = source.width, h = source.height
precondition(w == 627 && h == 627, "Expected the original 627 x 627 pose1")
let cyan = components(source, matching: isCyan).filter { $0.count > 100 }
    .sorted { bounds($0, width: w).midY < bounds($1, width: w).midY }
precondition(cyan.count == 3, "Expected two eyes and one chest core")
let eyes = Array(cyan.prefix(2)).map { bounds($0, width: w) }.sorted { $0.x0 < $1.x0 }
let core = bounds(cyan[2], width: w)
precondition(abs(eyes[0].midY - eyes[1].midY) < 5 && core.y0 > eyes[0].y1)
let seedX = (eyes[0].x1 + eyes[1].x0) / 2, seedY = eyes[0].midY
let visorPixels = components(source, matching: isDark).first { $0.contains(seedY * w + seedX) }!
let visor = bounds(visorPixels, width: w)
precondition(visor.width < w / 3 && visor.height < h / 3, "Visor detection escaped the helmet")

// Estimate the effective art pixel from repeated vertical plateaus of both visor
// contours. The source has one-pixel color noise, so ignore 1-2 px runs and long
// straight sections. The modal short plateau is the underlying chunky step.
var left = [Int: Int](), right = [Int: Int]()
for i in visorPixels {
    let x = i % w, y = i / w
    left[y] = min(left[y] ?? w, x); right[y] = max(right[y] ?? 0, x)
}
var histogram = [Int: Int]()
for contour in [left, right] {
    var length = 0, previous = -1
    for y in visor.y0...(visor.y1 + 1) {
        let x = contour[y] ?? -2
        if x == previous { length += 1 } else {
            if (3...8).contains(length) { histogram[length, default: 0] += 1 }
            previous = x; length = 1
        }
    }
}
let unit = histogram.keys.sorted {
    histogram[$0]! == histogram[$1]! ? $0 < $1 : histogram[$0]! > histogram[$1]!
}.first!
precondition((3...6).contains(unit), "Unexpected art pixel size")
print("Art pixel: \(unit) px; contour plateau counts: \(histogram.sorted { $0.key < $1.key })")
print("Visor, inclusive top-left coordinates: (\(visor.x0), \(visor.y0))...(\(visor.x1), \(visor.y1)); \(visor.width) x \(visor.height)")

var angry = source
var allowed = Set<Int>()
// Replace the eye displays, including their cyan fringe and white highlights,
// with nearby unlit visor samples. Copying pixels avoids a blurred repair.
for eye in eyes {
    let repair = eye.padded(unit)
    for y in repair.y0...repair.y1 { for x in repair.x0...repair.x1 {
        precondition(visor.contains(x, y) && source[x, y].a == 255)
        let sample = source[x, repair.y0 - unit]
        precondition(isDark(sample), "Eye repair sample must be unlit visor")
        angry[x, y] = sample
        allowed.insert(y * w + x)
    } }
}

let red = Pixel(r: 255, g: 59, b: 48, a: 255)
let lightRed = Pixel(r: 255, g: 112, b: 83, a: 255)
func rectangle(_ image: inout Bitmap, x: Int, y: Int, width: Int, height: Int,
               color: Pixel, mask: inout Set<Int>) {
    precondition(x >= 0 && y >= 0 && x + width <= image.width && y + height <= image.height)
    for py in y..<(y + height) { for px in x..<(x + width) {
        image[px, py] = color; mask.insert(py * image.width + px)
    } }
}
// Two mirrored, thick eye bars descend toward the nose, on a visor-relative grid.
let eyePattern = ["###......", "######...", ".########", "...######", "......###"]
let eyeY = visor.y0 + 10 * unit
for (side, originX) in [visor.x0 + 4 * unit, visor.x0 + 19 * unit].enumerated() {
    for (row, line) in eyePattern.enumerated() {
        let cells = Array(line)
        for col in 0..<cells.count where cells[col] == "#" {
            let mirroredCol = side == 0 ? col : cells.count - 1 - col
            rectangle(&angry, x: originX + mirroredCol * unit, y: eyeY + row * unit,
                      width: unit, height: unit, color: row == 0 ? lightRed : red, mask: &allowed)
        }
    }
}
// A short, inverted U frown beneath the eyes.
let mouthX = visor.midX - 3 * unit, mouthY = visor.y0 + 17 * unit
for (row, line) in ["..###..", ".##.##.", "##...##"].enumerated() {
    for (col, cell) in line.enumerated() where cell == "#" {
        rectangle(&angry, x: mouthX + col * unit, y: mouthY + row * unit,
                  width: unit, height: unit, color: red, mask: &allowed)
    }
}

// Keep the core's existing pixel geometry and luminance detail. A channel
// permutation turns cyan into red/orange and keeps near-white glints bright.
// A relaxed cyan test captures the dim fringe within the detected core bounds.
let coreArea = core.padded(unit)
for y in coreArea.y0...coreArea.y1 { for x in coreArea.x0...coreArea.x1 {
    let p = source[x, y]
    if p.a > 100 && Int(p.g) - Int(p.r) > 8 && Int(p.b) - Int(p.r) > 8 {
        angry[x, y] = Pixel(r: max(p.g, p.b),
            g: UInt8(min(255, Int(p.r) + (Int(p.g) - Int(p.r)) / 4)), b: p.r, a: p.a)
        allowed.insert(y * w + x)
    }
} }

// Keep the pose intact. The second animation frame is a lossless 1-unit shake.
func shifted(_ bitmap: Bitmap, dx: Int) -> Bitmap {
    var result = Bitmap(width: w, height: h)
    for y in 0..<h { for x in 0..<w {
        let nx = x + dx
        if (0..<w).contains(nx) { result[nx, y] = bitmap[x, y] }
        else { precondition(bitmap[x, y].a == 0, "Shake would crop the robot") }
    } }
    return result
}
func addAngerMark(_ bitmap: inout Bitmap, dx: Int, dy: Int) -> Set<Int> {
    var mark = Set<Int>()
    let x = visor.x1 + 2 * unit + dx, y = visor.y0 - 14 * unit + dy
    // Four separated bent arms, with chunky 2-unit strokes.
    for (gx, gy, gw, gh) in [(0,3,5,2), (3,0,2,5), (6,0,2,5), (6,3,5,2),
                              (0,6,5,2), (3,6,2,5), (6,6,5,2), (6,6,2,5)] {
        for py in (y + gy * unit)..<(y + (gy + gh) * unit) {
            for px in (x + gx * unit)..<(x + (gx + gw) * unit) {
                precondition(bitmap[px, py].a == 0 || mark.contains(py * w + px),
                             "Anger mark must not cover the original art")
            }
        }
        rectangle(&bitmap, x: x + gx * unit, y: y + gy * unit,
                  width: gw * unit, height: gh * unit, color: red, mask: &mark)
    }
    return mark
}
var frame1 = angry, frame2 = shifted(angry, dx: unit)
let mark1 = addAngerMark(&frame1, dx: 0, dy: 0)
let mark2 = addAngerMark(&frame2, dx: 2 * unit, dy: -unit)

// Verify the entire canvas, aligning frame 2 by its declared shake offset.
for (frame, dx, mark) in [(frame1, 0, mark1), (frame2, unit, mark2)] {
    var changes = 0
    for y in 0..<h { for x in 0..<w {
        let sx = x - dx
        let original = (0..<w).contains(sx) ? source[sx, y] : .clear
        let index = y * w + x
        if frame[x, y] != original {
            precondition(mark.contains(index) || ((0..<w).contains(sx) && allowed.contains(y*w+sx)),
                         "Unexpected edit outside the face, core or mark")
            changes += 1
        }
        if !mark.contains(index) { precondition(frame[x, y].a == original.a, "Robot alpha changed") }
    } }
    print("Verified frame shift \(dx) px: \(changes) changed pixels, unchanged robot alpha")
}

let template = try String(contentsOf: assets.appendingPathComponent("pose1.imageset/Contents.json"), encoding: .utf8)
for (name, frame) in [("angry1", frame1), ("angry2", frame2)] {
    let directory = assets.appendingPathComponent("\(name).imageset")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let png = directory.appendingPathComponent("\(name).png")
    frame.write(png)
    try template.replacingOccurrences(of: "pose1.png", with: "\(name).png")
        .write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    precondition(Bitmap(url: png).bytes == frame.bytes, "PNG round trip changed pixels")
    print("Wrote and decoded \(png.path)")
}

// 4x preview, left to right: pose1, angry1, angry2. Composite premultiplied
// source pixels onto charcoal, then duplicate each pixel in a 4x4 rectangle.
let scale = 4
let background = Pixel(r: 24, g: 28, b: 36, a: 255)
var preview = Bitmap(width: w * 3 * scale, height: h * scale, fill: background)
for (column, frame) in [source, frame1, frame2].enumerated() {
    for y in 0..<h { for x in 0..<w {
        let p = frame[x, y], inverseAlpha = 255 - Int(frame[x, y].a)
        let composite = Pixel(r: UInt8(min(255, Int(p.r) + Int(background.r) * inverseAlpha / 255)),
            g: UInt8(min(255, Int(p.g) + Int(background.g) * inverseAlpha / 255)),
            b: UInt8(min(255, Int(p.b) + Int(background.b) * inverseAlpha / 255)), a: 255)
        for sy in 0..<scale { for sx in 0..<scale {
            preview[(column*w+x)*scale+sx, y*scale+sy] = composite
        } }
    } }
}
let previewURL = URL(fileURLWithPath: "/tmp/clockin-angry-preview.png")
preview.write(previewURL)
print("Preview: \(previewURL.path), \(preview.width) x \(preview.height), nearest-neighbor 4x")
