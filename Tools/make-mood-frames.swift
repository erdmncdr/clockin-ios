#!/usr/bin/env swift
// Kok dizinden: swift iOS/Tools/make-mood-frames.swift
// Ham RGBA okuma, kaynak kenar renklerini korur.
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

func cyanFringe(_ p: Pixel) -> Bool {
    p.a > 100 && Int(p.g) - Int(p.r) > 8 && Int(p.b) - Int(p.r) > 8
}
func isOrange(_ p: Pixel) -> Bool {
    p.a > 100 && p.r > 150 && Int(p.r) - Int(p.g) > 40
}
func rgb(_ r: Int, _ g: Int, _ b: Int) -> Pixel {
    Pixel(r: UInt8(r), g: UInt8(g), b: UInt8(b), a: 255)
}

struct Features {
    let eyes: [Bounds], core: Bounds, visor: Bounds, unit: Int, closed: Bool
    init(_ source: Bitmap) {
        let w = source.width
        let cyan = components(source, matching: isCyan).filter { $0.count > 4 }
            .sorted { bounds($0, width: w).midY < bounds($1, width: w).midY }
        precondition(cyan.count == 3, "Expected two eyes and one core")
        eyes = cyan.prefix(2).map { bounds($0, width: w) }.sorted { $0.x0 < $1.x0 }
        core = bounds(cyan[2], width: w)
        precondition(abs(eyes[0].midY - eyes[1].midY) <= 2 && core.y0 > eyes[0].y1)
        let seed = eyes[0].midY * w + (eyes[0].x1 + eyes[1].x0) / 2
        guard let pixels = components(source, matching: isDark).first(where: { $0.contains(seed) })
        else { fatalError("Cannot detect visor") }
        visor = bounds(pixels, width: w)
        unit = pixelUnit(pixels, width: w)
        let detectedUnit = unit
        closed = eyes.allSatisfy { $0.height <= 2 * detectedUnit && $0.width >= 4 * detectedUnit }
    }
}

struct Drawing {
    let source: Bitmap
    var result: Bitmap
    var edited = Set<Int>()
    init(_ source: Bitmap) { self.source = source; result = source }
    mutating func dot(_ x: Int, _ y: Int, _ color: Pixel) {
        precondition(x >= 0 && y >= 0 && x < source.width && y < source.height)
        result[x, y] = color
        edited.insert(y * source.width + x)
    }
    mutating func rect(_ box: Bounds, _ color: Pixel, behind: Bool = false) {
        for y in box.y0...box.y1 { for x in box.x0...box.x1 {
            // Arkadaki aksesuar, govdenin hicbir pikselini degistirmez.
            if !behind || source[x, y].a == 0 { dot(x, y, color) }
        } }
    }
    mutating func pattern(_ rows: [String], x: Int, y: Int, unit: Int,
                          palette: [Character: Pixel], behind: Bool = false) {
        for (row, line) in rows.enumerated() { for (col, cell) in line.enumerated() {
            if let color = palette[cell] {
                rect(Bounds(x0: x + col * unit, y0: y + row * unit,
                            x1: x + (col + 1) * unit - 1, y1: y + (row + 1) * unit - 1),
                     color, behind: behind)
            }
        } }
    }
    func save(_ name: String, to directory: URL, unit: Int, regions: [Bounds],
              semantic: (Int, Int) -> Bool) -> Bitmap {
        let url = directory.appendingPathComponent(name + ".png")
        result.write(url)
        let decoded = Bitmap(url: url)
        precondition(decoded.width == 314 && decoded.height == 314 && decoded.bytes == result.bytes,
                     "PNG round trip changed RGBA")
        var changed = 0, cells = Set<Int>()
        var alphaMatches = true
        for y in 0..<source.height { for x in 0..<source.width {
            let i = y * source.width + x
            if !regions.contains(where: { $0.contains(x, y) }) {
                alphaMatches = alphaMatches && decoded[x, y].a == source[x, y].a
                precondition(decoded[x, y] == source[x, y], "RGBA changed outside edit regions")
            }
            if decoded[x, y] != source[x, y] {
                precondition(edited.contains(i) && semantic(x, y), "Unexpected semantic edit")
                changed += 1
                cells.insert((y / unit) * ((source.width + unit - 1) / unit) + x / unit)
            }
        } }
        precondition(alphaMatches && changed > 0)
        print("\(name).png: 314x314; alpha outside regions: MATCH; changed pixels: \(changed); touched \(unit)x\(unit) art cells: \(cells.count)")
        return decoded
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let directory = root.appendingPathComponent("iOS/Shared/Mascot/Frames")
let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.range(of: "^h[0-9]{2}\\.png$", options: .regularExpression) != nil }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
precondition(!files.isEmpty, "No hello frames")
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf:
    directory.appendingPathComponent("mascot-clips.json"))) as! [String: Any]
let hello = manifest["hello"] as! [String: Any]
let clips = hello["clips"] as! [String: [[Any]]]
let required = Set(clips.values.flatMap { $0 }.map { $0[0] as! String } + [hello["rest"] as! String])
precondition(required == Set(files.map { $0.deletingPathExtension().lastPathComponent }))
let sleepy = rgb(105, 146, 168), bright = rgb(73, 235, 255), glint = rgb(219, 255, 255)
let outline = rgb(25, 29, 36), shadow = rgb(65, 72, 87)
let orange = rgb(255, 119, 26), amber = rgb(195, 75, 20)
var previews = [(String, Bitmap)]()
var blinks = [(String, Bitmap)]()

for file in files {
    let source = Bitmap(url: file)
    precondition(source.width == 314 && source.height == 314)
    let f = Features(source), u = f.unit, v = f.visor
    print("\(file.lastPathComponent): unit \(u); eyes \(f.eyes); core \(f.core); visor \(v); blink \(f.closed)")
    if file.lastPathComponent == "h01.png" { previews.append(("HELLO", source)) }
    for proud in [false, true] {
        var d = Drawing(source)
        let eyeColor = proud ? bright : sleepy
        let eyeAreas = f.eyes.map { $0.padded(u) }
        for (side, eye) in f.eyes.enumerated() {
            let area = eyeAreas[side]
            if f.closed {
                for y in area.y0...area.y1 { for x in area.x0...area.x1 where cyanFringe(source[x, y]) {
                    let p = source[x, y]
                    let factor = Double(max(p.g, p.b)) / 255
                    d.dot(x, y, Pixel(r: UInt8(Double(eyeColor.r) * factor),
                        g: UInt8(Double(eyeColor.g) * factor), b: UInt8(Double(eyeColor.b) * factor), a: p.a))
                } }
            } else {
                for y in area.y0...area.y1 { for x in area.x0...area.x1 {
                    let sample = source[x, area.y0 - u]
                    precondition(isDark(sample) && v.contains(x, y) && source[x, y].a == 255)
                    d.dot(x, y, sample)
                } }
                if proud {
                    d.pattern(["..#####..", ".#######.", "##oo#####", "##oo#####", ".#######.", "..#####.."],
                              x: eye.x0, y: eye.y0, unit: u, palette: ["#": bright, "o": glint])
                } else {
                    let shape = ["..#######", "#########", ".######.."]
                    d.pattern(side == 0 ? shape.map { String($0.reversed()) } : shape,
                              x: eye.x0, y: eye.y0 + 3 * u, unit: u, palette: ["#": sleepy])
                }
            }
        }
        let mouth = Bounds(x0: v.midX - 3 * u, y0: f.eyes[0].midY + 5 * u,
                           x1: v.midX + 4 * u - 1, y1: f.eyes[0].midY + 8 * u - 1)
        if proud {
            for y in mouth.y0...mouth.y1 { for x in mouth.x0...mouth.x1 {
                precondition(v.contains(x, y) && isDark(source[x, y]), "Mouth must fit visor")
            } }
            d.pattern(["#.....#", ".#...#.", "..###.."], x: mouth.x0, y: mouth.y0, unit: u, palette: ["#": bright])
        }
        // Beyaz merkez de kisilir; cekirdegin cercevesi ve sekli korunur.
        let coreArea = f.core.padded(u)
        for y in coreArea.y0...coreArea.y1 { for x in coreArea.x0...coreArea.x1 {
            let p = source[x, y]
            let insideCore = f.core.contains(x, y) && p.a > 100 && min(p.r, p.g, p.b) > 140
            if cyanFringe(p) || insideCore {
                if proud {
                    d.dot(x, y, Pixel(r: UInt8(min(255, Int(p.r) + 44)),
                        g: UInt8(min(255, Int(p.g) + 28)), b: UInt8(min(255, Int(p.b) + 18)), a: p.a))
                } else {
                    let light = Double(max(p.g, p.b)) / 255
                    d.dot(x, y, Pixel(r: UInt8(66 * light), g: UInt8(101 * light), b: UInt8(123 * light), a: p.a))
                }
            }
        } }
        let markX = v.x1 + 1 + 4 * u, markY = v.y0 - 12 * u
        let mark: Bounds
        if proud {
            let star = ["....#....", "....#....", "...###...", "..##o##..", "###ooo###", "..##o##..", "...###...", "....#....", "....#...."]
            mark = Bounds(x0: markX, y0: markY, x1: markX + 9 * u - 1, y1: markY + 9 * u - 1)
            d.pattern(star, x: markX, y: markY, unit: u, palette: ["#": bright, "o": glint])
        } else {
            mark = Bounds(x0: markX, y0: markY - u, x1: markX + 11 * u - 1, y1: markY + 10 * u - 1)
            for n in 0..<3 {
                d.pattern(["###", "..#", ".#.", "#..", "###"],
                          x: markX + n * 4 * u, y: markY + (5 - n * 3) * u, unit: u, palette: ["#": sleepy])
            }
        }
        let name = (proud ? "p" : "z") + file.deletingPathExtension().lastPathComponent.dropFirst()
        let regions = eyeAreas + [coreArea, mark] + (proud ? [mouth] : [])
        let result = d.save(name, to: directory, unit: u, regions: regions) { x, y in
            let eye = eyeAreas.contains { $0.contains(x, y) }
            if eye && f.closed {
                precondition(cyanFringe(source[x, y]) && d.result[x, y].a == source[x, y].a,
                             "Blink silhouette changed")
            }
            if mark.contains(x, y) { return source[x, y].a == 0 }
            precondition(source[x, y].a == d.result[x, y].a, "Mood alpha changed on companion")
            return eye || (proud && mouth.contains(x, y)) || coreArea.contains(x, y)
        }
        if file.lastPathComponent == "h01.png" { previews.append((proud ? "PROUD" : "TIRED", result)) }
        if f.closed { blinks.append((name.uppercased(), result)) }
    }
}

let source = Bitmap(url: directory.appendingPathComponent("h01.png"))
let f = Features(source), u = f.unit, v = f.visor
var headTop = v.y0
while source[v.midX, headTop - 1].a > 128 { headTop -= 1 }
// Kulaklarin turuncu parcalari, bitisik kollari bas sinirindan ayirir.
let ears = components(source, matching: isOrange).map { bounds($0, width: source.width) }.filter {
    $0.y0 >= v.y0 && $0.y1 <= v.y1 && ($0.x1 < v.x0 || $0.x0 > v.x1)
}
let headLeft = ears.filter { $0.x1 < v.x0 }.map { $0.x0 }.min()!
let headRight = ears.filter { $0.x0 > v.x1 }.map { $0.x1 }.max()!
precondition(headRight - headLeft < 2 * v.width, "Head detection includes arms")
let head = Bounds(x0: headLeft, y0: headTop, x1: headRight, y1: v.y1 + 4 * u)
print("Accessory head: \(head)")

// Kalin bas bandi ve kulak kaplari, sanat pikseliyle tek bir siluet olusturur.
do {
    var d = Drawing(source)
    let left = v.x0 - 10 * u, top = head.y0
    let columns = 53, rows = 33
    let region = Bounds(x0: left, y0: top,
                        x1: left + columns * u - 1, y1: top + rows * u - 1)
    var silhouette = Set<Int>()
    for row in 0..<rows {
        let inset: Int
        switch row {
        case 0..<2: inset = 16
        case 2..<4: inset = 11
        case 4..<6: inset = 8
        case 6..<10: inset = 6
        case 10..<15: inset = 4
        default: inset = 3
        }
        for col in inset..<(columns - inset) {
            if row < 6 || col < inset + 6 || col >= columns - inset - 6 {
                silhouette.insert(row * columns + col)
            }
        }
        if row >= 15 {
            let corner = row == 15 || row == rows - 1 ? 1 : 0
            for col in corner..<(10 - corner) {
                silhouette.insert(row * columns + col)
                silhouette.insert(row * columns + columns - 1 - col)
            }
        }
    }
    for cell in silhouette {
        let col = cell % columns, row = cell / columns
        let edge = [(col - 1, row), (col + 1, row), (col, row - 1), (col, row + 1)]
            .contains { x, y in
                x < 0 || x >= columns || y < 0 || y >= rows || !silhouette.contains(y * columns + x)
            }
        let accent = (row >= 18 && row < 30 && (3...5 ~= col || 47...49 ~= col)) ||
            (row == 2 && (17...35).contains(col))
        d.rect(Bounds(x0: left + col * u, y0: top + row * u,
                      x1: left + (col + 1) * u - 1, y1: top + (row + 1) * u - 1),
               edge ? outline : (accent ? orange : shadow))
    }
    let result = d.save("acc-headphones", to: directory, unit: u, regions: [region]) { x, y in
        precondition(!v.contains(x, y) && y >= head.y0, "Headphones cover visor or antenna")
        return region.contains(x, y)
    }
    previews.append(("HEADPHONES", result))
}

// c01 kupasi, ayri opak bileseni ve turuncu amblemiyle bulunur.
do {
    let coffee = Bitmap(url: directory.appendingPathComponent("c01.png"))
    let orangeParts = components(coffee, matching: isOrange).filter { $0.count > 20 }
    let emblem = orangeParts.filter {
        let b = bounds($0, width: coffee.width)
        return b.midX < coffee.width / 3 && b.midY > coffee.height / 2 && b.height > b.width / 2
    }.max { $0.count < $1.count }!
    let seed = emblem[emblem.count / 2]
    let mugPixels = components(coffee, matching: { $0.a > 0 }).first { $0.contains(seed) }!
    let completeMug = bounds(mugPixels, width: coffee.width)
    let emblemBox = bounds(emblem, width: coffee.width)
    let rim = orangeParts.map { bounds($0, width: coffee.width) }.filter {
        $0.midX < coffee.width / 3 && $0.y1 < emblemBox.y0 && $0.width > 3 * $0.height
    }.max { $0.y1 < $1.y1 }!
    let mug = Bounds(x0: completeMug.x0, y0: rim.y0 - u,
                     x1: completeMug.x1, y1: completeMug.y1)
    precondition(mug.width < coffee.width / 3 && mug.height < coffee.height / 3, "Mug extraction includes companion")
    let mask = Set(mugPixels)
    // Sol el, bas solundaki en ust opak siralardan bulunur.
    let handPixels = (0..<(source.width * source.height)).filter {
        let x = $0 % source.width, y = $0 / source.width
        return x < head.x0 - 4 * u && y >= head.y0 && y < v.midY && source[x, y].a > 200
    }
    let hand = bounds(handPixels, width: source.width)
    let sizeW = ((mug.width * 2 / 3) / u) * u
    let sizeH = ((mug.height * 2 / 3) / u) * u
    let target = Bounds(x0: hand.midX - sizeW + 5 * u, y0: hand.y0 - 2 * u,
                        x1: hand.midX + 5 * u - 1, y1: hand.y0 - 2 * u + sizeH - 1)
    var d = Drawing(source)
    for dy in stride(from: 0, to: sizeH, by: u) { for dx in stride(from: 0, to: sizeW, by: u) {
        let sx = mug.x0 + (dx + u / 2) * mug.width / sizeW
        let sy = mug.y0 + (dy + u / 2) * mug.height / sizeH
        if mask.contains(sy * coffee.width + sx) {
            let p = coffee[sx, sy]
            // Yeni aksesuar kenarlari tam opak sanat pikselleridir.
            if p.a > 128 {
                d.rect(Bounds(x0: target.x0 + dx, y0: target.y0 + dy,
                              x1: target.x0 + dx + u - 1, y1: target.y0 + dy + u - 1),
                       Pixel(r: p.r, g: p.g, b: p.b, a: 255))
            }
        }
    } }
    // Kulpu kavrayan eldiven, kaynak kareden ustte tutulur.
    for y in target.y0...target.y1 { for x in (target.x1 - 5 * u)...target.x1 {
        if source[x, y].a > 128 { d.dot(x, y, source[x, y]) }
    } }
    print("Coffee mug: \(mug); hello hand: \(hand); mug target: \(target)")
    let result = d.save("acc-mug", to: directory, unit: u, regions: [target]) { x, y in target.contains(x, y) }
    previews.append(("MUG", result))
}

// Tek parca pelerin omuzlardan diz altina iner; robotun tum pikselleri onde kalir.
do {
    var d = Drawing(source)
    let top = v.y1 + 4 * u, rows = 60
    let center = f.core.midX, half = (head.width / u) / 2 - 5
    let capeOrange = rgb(218, 91, 23)
    let region = Bounds(x0: center - (half + 12) * u, y0: top,
                        x1: center + (half + 13) * u - 1, y1: top + rows * u - 1)
    for row in 0..<rows {
        let spread = half + min(row, rows - 5) * 12 / (rows - 5)
        for col in -spread...spread {
            let edge = abs(col) == spread || row == 0 || row == rows - 1
            let fold = abs(col) == half + row * 6 / rows
            let color = edge ? outline : (fold ? amber : capeOrange)
            d.rect(Bounds(x0: center + col * u, y0: top + row * u,
                          x1: center + (col + 1) * u - 1, y1: top + (row + 1) * u - 1), color, behind: true)
        }
    }
    let result = d.save("acc-cape", to: directory, unit: u, regions: [region]) { x, y in
        region.contains(x, y) && source[x, y].a == 0
    }
    previews.append(("CAPE", result))
}

// Anten topunun turuncu dolgusu altina doner; dis hat sabit kalir.
do {
    var d = Drawing(source)
    let ballPixels = components(source, matching: isOrange).filter { $0.count > 5 }
        .min { bounds($0, width: source.width).midY < bounds($1, width: source.width).midY }!
    let ball = bounds(ballPixels, width: source.width), region = ball.padded(u)
    for y in region.y0...region.y1 { for x in region.x0...region.x1 {
        let p = source[x, y]
        if p.a > 100 && Int(p.r) - Int(p.b) > 25 {
            d.dot(x, y, Pixel(r: p.r, g: UInt8(min(255, Int(p.g) + (Int(p.r) - Int(p.g)) * 2 / 3)),
                             b: UInt8(min(255, Int(p.b) + 22)), a: p.a))
        }
    } }
    let shine = Bounds(x0: ball.x0 + u, y0: ball.y0 + u, x1: ball.x0 + 3 * u - 1, y1: ball.y0 + 2 * u - 1)
    for y in shine.y0...shine.y1 { for x in shine.x0...shine.x1 {
        let p = source[x, y]
        precondition(p.a == 255)
        d.dot(x, y, rgb(255, 247, 187))
    } }
    print("Antenna ball: \(ball); shine: \(shine)")
    let result = d.save("acc-antenna", to: directory, unit: u, regions: [region]) { x, y in
        precondition(source[x, y].a == d.result[x, y].a)
        return region.contains(x, y)
    }
    previews.append(("ANTENNA", result))
}

// Etiketler de bitmap harflerle, yalnizca en yakin komsuyla cizilir.
let glyphs: [Character: [String]] = [
    "A":[".##.","#..#","####","#..#","#..#"], "C":[".###","#...","#...","#...",".###"],
    "D":["###.","#..#","#..#","#..#","###."], "E":["####","#...","###.","#...","####"],
    "H":["#..#","#..#","####","#..#","#..#"], "I":["###",".#.",".#.",".#.","###"],
    "L":["#...","#...","#...","#...","####"], "M":["#...#","##.##","#.#.#","#...#","#...#"],
    "N":["#..#","##.#","#.##","#..#","#..#"], "O":[".##.","#..#","#..#","#..#",".##."],
    "P":["###.","#..#","###.","#...","#..."], "R":["###.","#..#","###.","#.#.","#..#"],
    "S":[".###","#...",".##.","...#","###."], "T":["#####","..#..","..#..","..#..","..#.."],
    "U":["#..#","#..#","#..#","#..#",".##."], "G":[".###","#...","#.##","#..#",".###"],
    "B":["###.","#..#","###.","#..#","###."], "K":["#..#","#.#.","##..","#.#.","#..#"],
    "V":["#...#","#...#",".#.#.",".#.#.","..#.."], "Z":["####","...#","..#.",".#..","####"],
    "X":["#.#","#.#",".#.","#.#","#.#"], "0":["###","#.#","#.#","#.#","###"],
    "1":[".#.","##.",".#.",".#.","###"], "2":["###","..#","###","#..","###"],
    "3":["###","..#","###","..#","###"], "4":["#.#","#.#","###","..#","..#"],
    "6":["###","#..","###","#.#","###"], " ":["..","..","..","..",".."]
]
let background = rgb(24, 28, 36)
func label(_ text: String, on sheet: inout Bitmap, x: Int, y: Int, scale: Int = 2) {
    var cursor = x
    for char in text {
        guard let shape = glyphs[char] else { fatalError("Missing glyph \(char)") }
        for (dy, row) in shape.enumerated() { for (dx, cell) in row.enumerated() where cell == "#" {
            for sy in 0..<scale { for sx in 0..<scale {
                sheet[cursor + dx * scale + sx, y + dy * scale + sy] = rgb(195, 207, 222)
            } }
        } }
        cursor += (shape[0].count + 1) * scale
    }
}
func composite(_ frame: Bitmap, on sheet: inout Bitmap, x: Int, y: Int, size: Int) {
    for dy in 0..<size { for dx in 0..<size {
        let p = frame[min(frame.width - 1, (2 * dx + 1) * frame.width / (2 * size)),
                      min(frame.height - 1, (2 * dy + 1) * frame.height / (2 * size))]
        let a = Int(p.a), bg = sheet[x + dx, y + dy]
        sheet[x + dx, y + dy] = rgb((Int(p.r) * a + Int(bg.r) * (255 - a)) / 255,
                                  (Int(p.g) * a + Int(bg.g) * (255 - a)) / 255,
                                  (Int(p.b) * a + Int(bg.b) * (255 - a)) / 255)
    } }
}
var sheet = Bitmap(width: 1440, height: 1040, fill: background)
for (i, item) in previews.enumerated() {
    let x = (i % 4) * 360, y = (i / 4) * 520
    label(item.0, on: &sheet, x: x + 20, y: y + 16)
    composite(item.1, on: &sheet, x: x + 23, y: y + 34, size: 314)
    for (offset, size, title) in [(12, 62, "62"), (86, 32, "32"), (130, 124, "62 2X"), (266, 64, "32 2X")] {
        label(title, on: &sheet, x: x + offset, y: y + 360)
        composite(item.1, on: &sheet, x: x + offset, y: y + 382 + (124 - size) / 2, size: size)
    }
}
label("BLINKS", on: &sheet, x: 1100, y: 536)
for (i, item) in blinks.enumerated() {
    let x = 1090 + (i % 2) * 170, y = 570 + (i / 2) * 206
    label(item.0, on: &sheet, x: x + 20, y: y)
    composite(item.1, on: &sheet, x: x + 10, y: y + 18, size: 124)
    composite(item.1, on: &sheet, x: x + 24, y: y + 148, size: 32)
}
let previewURL = URL(fileURLWithPath: "/tmp/clockin-mood-frames.png")
sheet.write(previewURL)
print("Preview: \(previewURL.path); native, 62/32 px, 62/32 pt @2x; blink checks")
