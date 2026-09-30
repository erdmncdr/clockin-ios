import AppKit

// Kahve molasi animasyonu icin ara kareler uretir.
//
// Kaynak dort cizimdir (coffee1-4). Yeni cizim yapilmaz; yalnizca piksel tam
// duzenlemeler: goz kirpma (goz rengi ekran rengiyle boyanir, ince bir cizgi
// cizilir), antenin satir satir kaydirilarak sallanmasi ve kupanin buharinin
// tam piksel yukari tasinmasi. Olcekleme, dondurme ya da yumusatma yok.
//
// Kullanim: swiftc -O tools/coffee/main.swift -o /tmp/clockin-coffee
//           /tmp/clockin-coffee dist/assets/companion tools/coffee

struct Sprite {
    let width: Int, height: Int
    var px: [UInt8]

    init(path: String) {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("cannot read \(path)") }
        width = image.width; height = image.height
        px = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &px, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func pixel(_ x: Int, _ y: Int) -> [UInt8] { let i = (y * width + x) * 4; return Array(px[i..<i + 4]) }
    mutating func set(_ x: Int, _ y: Int, _ c: [UInt8]) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let i = (y * width + x) * 4; px[i] = c[0]; px[i + 1] = c[1]; px[i + 2] = c[2]; px[i + 3] = c[3]
    }
    func alpha(_ x: Int, _ y: Int) -> UInt8 { px[(y * width + x) * 4 + 3] }
    var opaqueCount: Int { stride(from: 3, to: px.count, by: 4).reduce(0) { $0 + (px[$1] > 32 ? 1 : 0) } }
    var bottom: Int { (0..<height).last { y in (0..<width).contains { alpha($0, y) > 32 } } ?? 0 }

    func save(_ path: String) {
        let data = Data(px)
        let provider = CGDataProvider(data: data as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(path)") }
    }

    struct Component { var points: [(Int, Int)]; var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
        var w: Int { maxX - minX + 1 }; var h: Int { maxY - minY + 1 } }

    /// 8-connected components of pixels matching `match`, largest first.
    func components(_ match: ([UInt8]) -> Bool) -> [Component] {
        var seen = [Bool](repeating: false, count: width * height)
        var result: [Component] = []
        for start in 0..<(width * height) where !seen[start] && match(pixel(start % width, start / width)) {
            var c = Component(points: []); var stack = [start]; seen[start] = true
            while let i = stack.popLast() {
                let x = i % width, y = i / width
                c.points.append((x, y)); c.minX = min(c.minX, x); c.maxX = max(c.maxX, x); c.minY = min(c.minY, y); c.maxY = max(c.maxY, y)
                for dy in -1...1 { for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    let j = ny * width + nx
                    if !seen[j] && match(pixel(nx, ny)) { seen[j] = true; stack.append(j) }
                } }
            }
            result.append(c)
        }
        return result.sorted { $0.points.count > $1.points.count }
    }
}

let isCyan: ([UInt8]) -> Bool = { $0[3] > 200 && $0[2] > 190 && $0[1] > 150 && $0[0] < 150 }
let isOrange: ([UInt8]) -> Bool = { $0[3] > 200 && $0[0] > 200 && $0[1] > 80 && $0[1] < 180 && $0[2] < 90 }

/// First row, from the top, where the head is wider than `minWidth` opaque pixels.
func headTop(_ s: Sprite, minWidth: Int = 80) -> Int {
    for y in 0..<s.height {
        var run = 0, best = 0
        for x in 0..<s.width { if s.alpha(x, y) > 32 { run += 1; best = max(best, run) } else { run = 0 } }
        if best >= minWidth { return y }
    }
    return 0
}

/// Antenna "spring": the ball dips `dy` pixels (a multiple of 6, one art
/// pixel) into the top of its stem and back. Swaying sideways needed sub-art-
/// pixel shifts on these short stems and always left a jag or a broken stem;
/// a straight vertical move keeps every outline clean.
func springAntenna(_ s: Sprite, dy: Int) -> Sprite {
    guard dy > 0, let ball = s.components(isOrange).min(by: { $0.minY < $1.minY }) else { return s }
    var out = s
    let x0 = max(0, ball.minX - 8), x1 = min(s.width - 1, ball.maxX + 8)
    var top = ball.minY
    while top > 0 && (x0...x1).contains(where: { s.alpha($0, top - 1) > 0 }) { top -= 1 }
    // Include the dark collar under the ball (one art pixel), but never reach
    // the head: the moved rows must land above the head's top outline.
    let bottom = min(ball.maxY + 8, headTop(s) - 2 - dy)
    precondition(bottom > ball.minY, "antenna too short to dip")
    // Clear the ball's old rows and the stem rows it now covers; leaving any of
    // them would show a ghost of the old outline beside the moved ball.
    for y in top...(bottom + dy) { for x in x0...x1 { out.set(x, y, [0, 0, 0, 0]) } }
    for y in stride(from: bottom, through: top, by: -1) {
        for x in x0...x1 where s.alpha(x, y) > 0 { out.set(x, y + dy, s.pixel(x, y)) }
    }
    return out
}

/// Sways the antenna: see the comment inside.
func swayAntenna(_ s: Sprite, dx: Int) -> Sprite {
    var out = s
    var top = 0
    for y in 0..<s.height where (0..<s.width).contains(where: { s.alpha($0, y) > 32 }) { top = y; break }
    let base = headTop(s) - 1
    guard base > top, dx != 0 else { return s }
    // One art pixel here is about 6 px, and anything that moves by less shows
    // as a jagged outline. So the ball and the upper half of the stem move by
    // `dx` (use multiples of 6) and the lower half stays: one clean jog, like
    // a hand-drawn bend, and the head outline below is never touched.
    let ball = s.components(isOrange).min { $0.minY < $1.minY }
    let ballBottom = min(base - 1, (ball?.maxY ?? top) + 2)
    let jog = (ballBottom + base) / 2
    for y in top...jog {
        let shift = dx
        let row = (0..<s.width).map { s.pixel($0, y) }
        for x in 0..<s.width { out.set(x, y, [0, 0, 0, 0]) }
        for x in 0..<s.width where row[x][3] > 0 { out.set(x + shift, y, row[x]) }
    }
    return out
}

/// Closes the oval eyes: paints them with the screen colour and draws a thin
/// line across their lower middle. Frames whose eyes are already arcs are
/// returned unchanged (nil).
func blink(_ s: Sprite) -> Sprite? {
    let eyes = s.components(isCyan).filter { $0.points.count > 150 && Double($0.h) >= Double($0.w) * 1.3 }
    guard eyes.count == 2 else { return nil }
    var out = s
    for eye in eyes {
        let screen = s.pixel(eye.minX - 6, (eye.minY + eye.maxY) / 2)
        let lineColor = s.pixel((eye.minX + eye.maxX) / 2, (eye.minY + eye.maxY) / 2)
        // The oval's anti-aliased rim differs slightly from the screen too, so the
        // whole box around the eye is repainted; the eyes sit well inside the screen.
        for y in (eye.minY - 4)...(eye.maxY + 4) { for x in (eye.minX - 4)...(eye.maxX + 4) { out.set(x, y, screen) } }
        let thickness = max(6, eye.h / 5)
        let lineTop = eye.minY + eye.h * 5 / 8 - thickness / 2
        for y in lineTop..<(lineTop + thickness) { for x in (eye.minX - 1)...(eye.maxX + 1) { out.set(x, y, lineColor) } }
    }
    return out
}

/// Moves the faint steam above the mug up by `dy` pixels. Steam is the pale,
/// low-saturation pixels above the mug rim on the robot's left.
func riseSteam(_ s: Sprite, dy: Int) -> Sprite? {
    let mug = s.components { $0[3] > 32 }.dropFirst().first { $0.maxY > s.bottom - 20 && $0.points.count > 3000 }
    guard let mug else { return nil }
    var steam: [(Int, Int, [UInt8])] = []
    for y in max(0, mug.minY - 120)..<(mug.minY - 2) {
        for x in (mug.minX - 10)...(mug.maxX + 10) where s.alpha(x, y) > 0 {
            let c = s.pixel(x, y)
            steam.append((x, y, c))
        }
    }
    guard !steam.isEmpty else { return nil }
    var out = s
    for (x, y, _) in steam { out.set(x, y, [0, 0, 0, 0]) }
    for (x, y, c) in steam { out.set(x, y - dy, c) }
    return out
}

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: clockin-coffee <companion-dir> <tools-out-dir>"); exit(2) }
let dir = args[1], toolsDir = args[2]
let src = (1...4).map { Sprite(path: "\(dir)/coffee\($0).png") }
let outDir = "\(dir)/coffee-loop"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// The loop. Each entry: description, frame, ms.
var loop: [(String, Sprite, Int)] = []
func add(_ name: String, _ s: Sprite?, _ ms: Int) { if let s { loop.append((name, s, ms)) } else { print("skipped: \(name)") } }

add("sit", src[0], 260)
add("sit, steam up 6", riseSteam(src[0], dy: 6), 220)
add("sit, steam up 12, antenna dips", riseSteam(springAntenna(src[0], dy: 6), dy: 12), 220)
add("sit, blink", blink(springAntenna(src[0], dy: 6)), 110)
add("sit, steam up 6, antenna up", riseSteam(src[0], dy: 6), 220)
add("reach", src[1], 340)
add("drink", src[2], 300)
add("drink, antenna dips", springAntenna(src[2], dy: 6), 300)
add("drink", src[2], 540)
add("smile", src[3], 330)
add("smile, antenna dips", springAntenna(src[3], dy: 6), 330)
add("drink again", src[2], 380)
add("reach back", src[1], 320)

// Verification.
var failures = 0
func check(_ ok: Bool, _ message: String) { if !ok { failures += 1; print("FAILED: \(message)") } }
let sources: [String: Int] = ["sit": 0, "reach": 1, "drink": 2, "smile": 3]
for (i, (name, frame, _)) in loop.enumerated() {
    let base = src[sources.first { name.hasPrefix($0.key) }?.value ?? (name.contains("drink") ? 2 : 1)]
    check(frame.width == 627 && frame.height == 627, "\(name): size")
    check(frame.bottom == base.bottom, "\(name): bottom \(frame.bottom) != \(base.bottom)")
    let change = abs(Double(frame.opaqueCount - base.opaqueCount)) / Double(base.opaqueCount)
    check(change < 0.01, "\(name): opaque pixels changed \(String(format: "%.2f", change * 100))%")
    if i > 0 { check(frame.px != loop[i - 1].1.px, "\(name): identical to previous frame") }
}

var manifest: [[String: Any]] = []
for (i, (name, frame, ms)) in loop.enumerated() {
    let file = String(format: "c%02d.png", i + 1)
    frame.save("\(outDir)/\(file)")
    manifest.append(["file": file, "ms": ms])
    print("\(file)  \(ms) ms  \(name)")
}
let json = try! JSONSerialization.data(withJSONObject: ["frames": manifest], options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(outDir)/sequence.json"))
print("loop: \(loop.count) frames, \(loop.reduce(0) { $0 + $1.2 }) ms")

// Contact sheet at 25%, nearest neighbour, red line at the common bottom.
let cell = 157, sheetW = cell * loop.count
var sheet = [UInt8](repeating: 215, count: sheetW * cell * 4)
for (i, (_, frame, _)) in loop.enumerated() {
    for y in 0..<cell { for x in 0..<cell {
        let p = frame.pixel(x * 4, y * 4); let a = Double(p[3]) / 255
        let o = (y * sheetW + i * cell + x) * 4
        for k in 0..<3 { sheet[o + k] = UInt8(Double(p[k]) + 215 * (1 - a)) }
        sheet[o + 3] = 255
    } }
}
let line = src[0].bottom / 4
for x in 0..<sheetW { let o = (line * sheetW + x) * 4; sheet[o] = 230; sheet[o + 1] = 30; sheet[o + 2] = 30 }
var sheetSprite = Sprite(path: "\(dir)/coffee1.png")
sheetSprite = Sprite(width: sheetW, height: cell, px: sheet)
sheetSprite.save("\(toolsDir)/sheet.png")

if failures > 0 { print("\(failures) checks failed"); exit(1) }
print("all checks passed")

extension Sprite {
    init(width: Int, height: Int, px: [UInt8]) { self.width = width; self.height = height; self.px = px }
}
