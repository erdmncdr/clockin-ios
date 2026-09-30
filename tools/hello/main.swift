import AppKit

// Merhaba (tezahurat) animasyonu icin ara kareler: mascot-hello.png tek
// cizimdir. Piksel tam duzenlemeler: goz kirpma, anten sallanmasi, gogus
// isiginin parlayip sonmesi ve kucuk bir sevinc ziplamasi. Olcekleme,
// dondurme ya da yumusatma yok. Yardimcilar tools/coffee/main.swift ile ayni.
//
// Kullanim: swiftc -O tools/hello/main.swift -o /tmp/clockin-hello
//           /tmp/clockin-hello dist/assets tools/hello

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

/// Sways the antenna above the head (only its own columns): the top row moves `dx` pixels, rows closer
/// to the head move proportionally less, in whole pixels.
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
        let x0 = max(0, (ball?.minX ?? 0) - 14), x1 = min(s.width - 1, (ball?.maxX ?? s.width - 1) + 14)
        let row = (x0...x1).map { s.pixel($0, y) }
        for x in x0...x1 { out.set(x, y, [0, 0, 0, 0]) }
        for (k, x) in (x0...x1).enumerated() where row[k][3] > 0 { out.set(x + shift, y, row[k]) }
    }
    return out
}


/// The two happy arc eyes: the highest two cyan shapes of eye size.
func eyeArcs(_ s: Sprite) -> [Sprite.Component] {
    let shapes = s.components(isCyan).filter { $0.points.count > 60 && $0.h < 60 && $0.w < 80 }
    return Array(shapes.sorted { $0.minY < $1.minY }.prefix(2))
}

/// Closes the arc eyes into flat lines about one art pixel thick.
func blinkArcs(_ s: Sprite) -> Sprite? {
    let eyes = eyeArcs(s)
    guard eyes.count == 2, abs(eyes[0].minY - eyes[1].minY) < 12 else { return nil }
    var out = s
    // One shared height: the arcs are drawn a few pixels apart, and separate
    // lines looked lopsided.
    let mid = (eyes[0].minY + eyes[0].maxY + eyes[1].minY + eyes[1].maxY) / 4 + 2
    for eye in eyes {
        let screen = s.pixel(eye.minX - 6, eye.maxY + 6)
        let cyan = s.pixel(eye.points[eye.points.count / 2].0, eye.points[eye.points.count / 2].1)
        for y in (eye.minY - 4)...(eye.maxY + 4) { for x in (eye.minX - 4)...(eye.maxX + 4) { out.set(x, y, screen) } }
        for y in (mid - 3)..<(mid + 3) { for x in eye.minX...eye.maxX { out.set(x, y, cyan) } }
    }
    return out
}

/// Brightens (or dims) the glowing chest core along its own tone ramp: the
/// core's distinct colours, sorted by lightness, each move `steps` places up
/// (or down). Replacing tones with one colour erased the core's shading.
func pulseCore(_ s: Sprite, steps: Int) -> Sprite? {
    let eyesBottom = eyeArcs(s).map(\.maxY).max() ?? 0
    guard let core = s.components(isCyan).filter({ $0.minY > eyesBottom + 20 }).first else { return nil }
    let cx = (core.minX + core.maxX) / 2, cy = (core.minY + core.maxY) / 2, r = max(core.w, core.h) / 2 + 6
    var area: [(Int, Int)] = []
    for y in (cy - r)...(cy + r) { for x in (cx - r)...(cx + r) where (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r {
        let p = s.pixel(x, y); if p[3] > 200 && p[2] > 150 && Int(p[2]) > Int(p[0]) + 30 { area.append((x, y)) }
    } }
    guard area.count > 40 else { return nil }
    let light = { (p: [UInt8]) in Int(p[0]) * 3 + Int(p[1]) * 6 + Int(p[2]) }
    let ramp = Array(Set(area.map { s.pixel($0.0, $0.1) })).sorted { light($0) == light($1) ? $0.lexicographicallyPrecedes($1) : light($0) < light($1) }
    guard ramp.count >= 3 else { return nil }
    var index: [[UInt8]: Int] = [:]
    for (i, c) in ramp.enumerated() { index[c] = i }
    var out = s
    // The core has dozens of near-identical anti-aliased tones, so one place
    // up the ramp is invisible; each step jumps a fifth of the ramp instead,
    // which still keeps every tone's order and so the shading.
    let stride = max(1, ramp.count / 5)
    for (x, y) in area {
        let i = index[s.pixel(x, y)]!
        out.set(x, y, ramp[min(ramp.count - 1, max(0, i + steps * stride))])
    }
    return out
}

/// Moves the whole robot up by `dy` whole pixels (a cheering hop).
func hop(_ s: Sprite, dy: Int) -> Sprite {
    var out = Sprite(width: s.width, height: s.height, px: [UInt8](repeating: 0, count: s.px.count))
    for y in dy..<s.height { for x in 0..<s.width where s.alpha(x, y) > 0 { out.set(x, y - dy, s.pixel(x, y)) } }
    return out
}

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: clockin-hello <assets-dir> <tools-out-dir>"); exit(2) }
let dir = args[1], toolsDir = args[2]
let base = Sprite(path: "\(dir)/mascot-hello.png")
let outDir = "\(dir)/companion/hello-loop"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

var loop: [(String, Sprite, Int, Int)] = []   // name, frame, ms, expected hop
func add(_ name: String, _ s: Sprite?, _ ms: Int, hop: Int = 0) { if let s { loop.append((name, s, ms, hop)) } else { print("skipped: \(name)") } }
let sway = { (s: Sprite, dx: Int) in swayAntenna(s, dx: dx) }

add("cheer", base, 240)
add("crouch: antenna dips", springAntenna(base, dy: 6), 120)
add("hop 6", hop(base, dy: 6), 110, hop: 6)
add("hop 12, antenna trails", hop(springAntenna(base, dy: 6), dy: 12), 130, hop: 12)
add("hop 6", hop(base, dy: 6), 110, hop: 6)
add("land: antenna dips, core glow", springAntenna(pulseCore(base, steps: 1)!, dy: 6), 150)
add("core bright", pulseCore(base, steps: 2), 200)
add("core glow fades", pulseCore(base, steps: 1), 200)
add("cheer", base, 240)
add("blink", blinkArcs(base), 100)
add("blink, antenna dips", springAntenna(blinkArcs(base)!, dy: 6), 90)
add("cheer", base, 260)
add("crouch: antenna dips", springAntenna(base, dy: 6), 120)
add("hop 6", hop(base, dy: 6), 110, hop: 6)
add("hop 12, antenna trails", hop(springAntenna(base, dy: 6), dy: 12), 130, hop: 12)
add("hop 6", hop(base, dy: 6), 110, hop: 6)

var failures = 0
func check(_ ok: Bool, _ message: String) { if !ok { failures += 1; print("FAILED: \(message)") } }
let palette = Set(stride(from: 0, to: base.px.count, by: 4).map { i in base.px[i..<i + 4].map { $0 } })
for (i, (name, frame, _, lift)) in loop.enumerated() {
    check(frame.width == 627 && frame.height == 627, "\(name): size")
    check(frame.bottom == base.bottom - lift, "\(name): bottom \(frame.bottom), expected \(base.bottom - lift)")
    let change = abs(Double(frame.opaqueCount - base.opaqueCount)) / Double(base.opaqueCount)
    check(change < 0.01, "\(name): opaque pixels changed \(String(format: "%.2f", change * 100))%")
    if i > 0 { check(frame.px != loop[i - 1].1.px, "\(name): identical to previous frame") }
    let colors = Set(stride(from: 0, to: frame.px.count, by: 4).map { j in frame.px[j..<j + 4].map { $0 } })
    check(colors.isSubset(of: palette), "\(name): new colours introduced")
}
check(loop.first!.3 == 0 && loop.last!.3 <= 6, "loop wraps from a small hop to standing")

var manifest: [[String: Any]] = []
for (i, (name, frame, ms, _)) in loop.enumerated() {
    let file = String(format: "h%02d.png", i + 1)
    frame.save("\(outDir)/\(file)")
    manifest.append(["file": file, "ms": ms])
    print("\(file)  \(ms) ms  \(name)")
}
let json = try! JSONSerialization.data(withJSONObject: ["frames": manifest], options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(outDir)/sequence.json"))
print("loop: \(loop.count) frames, \(loop.reduce(0) { $0 + $1.2 }) ms")

let cell = 157, sheetW = cell * loop.count
var sheet = [UInt8](repeating: 215, count: sheetW * cell * 4)
for (i, (_, frame, _, _)) in loop.enumerated() {
    for y in 0..<cell { for x in 0..<cell {
        let p = frame.pixel(x * 4, y * 4); let a = Double(p[3]) / 255
        let o = (y * sheetW + i * cell + x) * 4
        for k in 0..<3 { sheet[o + k] = UInt8(Double(p[k]) + 215 * (1 - a)) }
        sheet[o + 3] = 255
    } }
}
for x in 0..<sheetW { let o = ((base.bottom / 4) * sheetW + x) * 4; sheet[o] = 230; sheet[o + 1] = 30; sheet[o + 2] = 30 }
Sprite(width: sheetW, height: cell, px: sheet).save("\(toolsDir)/sheet.png")

if failures > 0 { print("\(failures) checks failed"); exit(1) }
print("all checks passed")

extension Sprite {
    init(width: Int, height: Int, px: [UInt8]) { self.width = width; self.height = height; self.px = px }
}
