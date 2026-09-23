#!/usr/bin/env swift
// Run from the repository root:
// swift -module-cache-path /tmp/clockin-art-module-cache Tools/make-angry-frames.swift
// Coordinates use the top-left image origin. New strokes use detected art pixels.
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
        // Read straight RGBA directly. A drawing context would premultiply and
        // round translucent edge colors, changing pixels outside the edits.
        precondition(image.bitsPerComponent == 8 && image.bitsPerPixel == 32 &&
                     image.alphaInfo == .last && image.bitmapInfo.intersection(.byteOrderMask).isEmpty,
                     "Expected straight 8-bit RGBA PNG")
        let data = image.dataProvider!.data! as Data
        for y in 0..<height {
            bytes.replaceSubrange((y * width * 4)..<((y + 1) * width * 4),
                with: data[(y * image.bytesPerRow)..<(y * image.bytesPerRow + width * 4)])
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
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
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

// Repeated short plateaus on the visor contour reveal the art's pixel unit.
// Ignore single-pixel resampling noise and long straight contour segments.
func pixelUnit(_ pixels: [Int], width: Int) -> Int {
    let box = bounds(pixels, width: width)
    var histogram = [Int: Int]()
    for rightSide in [false, true] {
        var contour = [Int: Int]()
        for i in pixels {
            let x = i % width, y = i / width
            contour[y] = rightSide ? max(contour[y] ?? 0, x) : min(contour[y] ?? width, x)
        }
        var previous = -1, length = 0
        for y in box.y0...(box.y1 + 1) {
            let x = contour[y] ?? -2
            if x == previous { length += 1 } else {
                if (2...8).contains(length) { histogram[length, default: 0] += 1 }
                previous = x; length = 1
            }
        }
    }
    guard let unit = histogram.keys.sorted(by: {
        histogram[$0]! == histogram[$1]! ? $0 < $1 : histogram[$0]! > histogram[$1]!
    }).first else { fatalError("Cannot detect art pixel unit") }
    return unit
}

func warm(_ p: Pixel) -> Pixel {
    Pixel(r: max(p.g, p.b), g: UInt8(Int(p.r) + max(0, Int(p.g) - Int(p.r)) / 5),
          b: p.r, a: p.a)
}
func cyanFringe(_ p: Pixel) -> Bool {
    p.a > 100 && Int(p.g) - Int(p.r) > 8 && Int(p.b) - Int(p.r) > 8
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let directory = root.appendingPathComponent("Shared/Mascot/Frames")
let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.range(of: "^h[0-9]{2}\\.png$", options: .regularExpression) != nil }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
precondition(!files.isEmpty, "No hello frames found")

// Confirm every frame referenced by the hello clips is present, without changing
// the manifest. App wiring belongs to the separate integration task.
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf:
    directory.appendingPathComponent("mascot-clips.json"))) as! [String: Any]
let hello = manifest["hello"] as! [String: Any]
let clips = hello["clips"] as! [String: [[Any]]]
let required = Set(clips.values.flatMap { $0 }.map { $0[0] as! String } + [hello["rest"] as! String])
precondition(required.isSubset(of: Set(files.map { $0.deletingPathExtension().lastPathComponent })))

let red = Pixel(r: 255, g: 57, b: 48, a: 255)
var previews = [(String, Bitmap, Bitmap, Bool)]()
for file in files {
    let source = Bitmap(url: file), w = source.width, h = source.height
    precondition(w == 314 && h == 314, "Expected 314 x 314 frames")
    let cyan = components(source, matching: isCyan).filter { $0.count > 4 }
        .sorted { bounds($0, width: w).midY < bounds($1, width: w).midY }
    precondition(cyan.count == 3, "Expected two cyan eyes and a chest core in \(file.lastPathComponent)")
    let eyes = cyan.prefix(2).map { bounds($0, width: w) }.sorted { $0.x0 < $1.x0 }
    let core = bounds(cyan[2], width: w)
    precondition(abs(eyes[0].midY - eyes[1].midY) <= 2 && core.y0 > eyes[0].y1)
    let seed = eyes[0].midY * w + (eyes[0].x1 + eyes[1].x0) / 2
    guard let visorPixels = components(source, matching: isDark).first(where: { $0.contains(seed) })
    else { fatalError("Cannot detect visor") }
    let visor = bounds(visorPixels, width: w)
    precondition(visor.width < w / 3 && visor.height < h / 3)
    let unit = pixelUnit(visorPixels, width: w)
    let closed = eyes.allSatisfy { $0.height <= 2 * unit && $0.width >= 4 * unit }
    var result = source
    var allowed = Set<Int>(), mark = Set<Int>()

    func paint(_ box: Bounds, _ color: Pixel, isMark: Bool = false) {
        precondition(box.x0 >= 0 && box.y0 >= 0 && box.x1 < w && box.y1 < h)
        for y in box.y0...box.y1 { for x in box.x0...box.x1 {
            if isMark {
                precondition(source[x, y].a == 0, "Mark must not cover original art")
                mark.insert(y * w + x)
            } else {
                precondition(visor.contains(x, y) && source[x, y].a == 255,
                             "Face edit must stay inside the opaque visor")
            }
            result[x, y] = color
            allowed.insert(y * w + x)
        } }
    }
    func pattern(_ rows: [String], x: Int, y: Int, mirrored: Bool = false, isMark: Bool = false) {
        for (row, line) in rows.enumerated() {
            for (col, cell) in line.enumerated() where cell == "#" {
                let column = mirrored ? line.count - 1 - col : col
                paint(Bounds(x0: x + column * unit, y0: y + row * unit,
                             x1: x + (column + 1) * unit - 1, y1: y + (row + 1) * unit - 1),
                      red, isMark: isMark)
            }
        }
    }

    for (side, eye) in eyes.enumerated() {
        let area = eye.padded(unit)
        if closed {
            // Recolor only: retain the exact closed or half-closed silhouette,
            // including its dim cyan edge, instead of redrawing an open eye.
            for y in area.y0...area.y1 { for x in area.x0...area.x1 {
                if cyanFringe(source[x, y]) {
                    result[x, y] = warm(source[x, y]); allowed.insert(y * w + x)
                }
            } }
        } else {
            // Repair the old happy arc and highlights with nearby visor pixels.
            for y in area.y0...area.y1 { for x in area.x0...area.x1 {
                let sample = source[x, area.y0 - unit]
                precondition(isDark(sample))
                paint(Bounds(x0: x, y0: y, x1: x, y1: y), sample)
            } }
            // Mirrored squints with upper edges descending toward the nose.
            // Pattern dimensions follow the detected eye width and art unit.
            let columns = max(5, eye.width / unit), rows = max(3, eye.height / unit)
            let shape = (0..<rows).map { row in
                String((0..<columns).map { col in
                    let top = col * (rows - 2) / columns
                    return row >= top && row <= top + 2 ? Character("#") : Character(".")
                })
            }
            pattern(shape, x: eye.x0, y: eye.y0, mirrored: side == 1)
        }
    }

    // A small inverted U sits below the eyes if the detected visor has room.
    let mouthX = visor.midX - 3 * unit
    let mouthY = max(eyes[0].midY, eyes[1].midY) + 5 * unit
    let mouth = Bounds(x0: mouthX, y0: mouthY, x1: mouthX + 7 * unit - 1, y1: mouthY + 3 * unit - 1)
    let mouthFits = (mouth.y0...mouth.y1).allSatisfy { y in
        (mouth.x0...mouth.x1).allSatisfy { x in visor.contains(x, y) && isDark(source[x, y]) }
    }
    if mouthFits { pattern(["..###..", ".##.##.", "##...##"], x: mouthX, y: mouthY) }

    // Keep the core's geometry, glow intensity and white glints in every frame.
    let coreArea = core.padded(unit)
    for y in coreArea.y0...coreArea.y1 { for x in coreArea.x0...coreArea.x1 {
        if cyanFringe(source[x, y]) {
            result[x, y] = warm(source[x, y]); allowed.insert(y * w + x)
        }
    } }

    // Classic four bent vein strokes, placed on a visor-relative art grid.
    let vein = ["...#.#...", "...#.#...", "...#.#...", "####.####", ".........",
                "####.####", "...#.#...", "...#.#...", "...#.#..."]
    let markX = visor.x1 + 1 + 4 * unit, markY = visor.y0 - 12 * unit
    pattern(vein, x: markX, y: markY, isMark: true)

    let outputName = "a" + file.deletingPathExtension().lastPathComponent.dropFirst()
    let output = directory.appendingPathComponent(outputName + ".png")
    result.write(output)
    let decoded = Bitmap(url: output)
    precondition(decoded.width == w && decoded.height == h && decoded.bytes == result.bytes,
                 "PNG round trip changed RGBA data")
    var changed = 0
    for y in 0..<h { for x in 0..<w {
        let i = y * w + x
        if decoded[x, y] != source[x, y] {
            precondition(allowed.contains(i), "Unexpected pixel change")
            // Independently check semantic regions, not just the paint log.
            let eyeEdit = eyes.contains { $0.padded(unit).contains(x, y) }
            let mouthEdit = mouthFits && mouth.contains(x, y)
            let coreEdit = coreArea.contains(x, y) && cyanFringe(source[x, y])
            let markEdit = x >= markX && x < markX + vein[0].count * unit &&
                y >= markY && y < markY + vein.count * unit && source[x, y].a == 0
            precondition(eyeEdit || mouthEdit || coreEdit || markEdit,
                         "Edit outside eyes, frown, core or anger mark")
            if closed && eyeEdit {
                precondition(cyanFringe(source[x, y]) && decoded[x, y] == warm(source[x, y]),
                             "Blink silhouette changed")
            }
            changed += 1
        }
        if !mark.contains(i) { precondition(decoded[x, y].a == source[x, y].a, "Alpha changed") }
    } }
    print("\(file.lastPathComponent) -> \(outputName).png: unit \(unit) px, \(closed ? "closed eyes preserved" : "angry squints"), frown \(mouthFits), \(changed) changed pixels; RGBA and alpha verified")
    previews.append((outputName, source, decoded, closed))
}

// Preview rows show originals and results at native size, 62 pt at 2x, and
// 32 pt at 2x. Swift/CoreGraphics only; the sheet stays outside the repository.
let background = Pixel(r: 24, g: 28, b: 36, a: 255)
let previewRows = previews.filter { $0.0 == "a01" || $0.3 }
var sheet = Bitmap(width: 1060, height: previewRows.count * 330, fill: background)
func composite(_ frame: Bitmap, x: Int, y: Int, size: Int) {
    // Area averaging models thumbnail downsampling without changing the PNGs.
    for dy in 0..<size { for dx in 0..<size {
        let x0 = dx * frame.width / size, x1 = max(x0 + 1, (dx + 1) * frame.width / size)
        let y0 = dy * frame.height / size, y1 = max(y0 + 1, (dy + 1) * frame.height / size)
        var r = 0, g = 0, b = 0, count = 0
        for sy in y0..<y1 { for sx in x0..<x1 {
            let p = frame[sx, sy], a = Int(frame[sx, sy].a)
            r += (Int(p.r) * a + Int(background.r) * (255 - a)) / 255
            g += (Int(p.g) * a + Int(background.g) * (255 - a)) / 255
            b += (Int(p.b) * a + Int(background.b) * (255 - a)) / 255
            count += 1
        } }
        sheet[x + dx, y + dy] = Pixel(r: UInt8(r/count), g: UInt8(g/count), b: UInt8(b/count), a: 255)
    } }
}
for (row, item) in previewRows.enumerated() {
    let y = row * 330 + 8
    composite(item.1, x: 8, y: y, size: 314)
    composite(item.2, x: 330, y: y, size: 314)
    composite(item.1, x: 658, y: y + 95, size: 124)
    composite(item.2, x: 788, y: y + 95, size: 124)
    composite(item.1, x: 920, y: y + 125, size: 64)
    composite(item.2, x: 988, y: y + 125, size: 64)
}
let previewURL = URL(fileURLWithPath: "/tmp/clockin-angry-frames.png")
sheet.write(previewURL)
print("Preview: \(previewURL.path); rows a01 and blink frames; pairs: native, 62 pt @2x, 32 pt @2x")
