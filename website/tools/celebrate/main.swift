import AppKit

// Celebrate: integer translations and source-palette recolouring only.
// Build: swiftc -O tools/celebrate/main.swift -o /tmp/clockin-celebrate
// Run: /tmp/clockin-celebrate dist/assets/companion tools/celebrate
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
        precondition(x >= 0 && y >= 0 && x < width && y < height, "translation would crop")
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

extension Sprite {
    init(width: Int, height: Int, px: [UInt8]) { self.width = width; self.height = height; self.px = px }
    var palette: Set<UInt32> {
        var colors = Set<UInt32>()
        for i in stride(from:0,to:px.count,by:4) where px[i+3] > 0 {
            let r = UInt32(px[i]) << 24, g = UInt32(px[i+1]) << 16
            let b = UInt32(px[i+2]) << 8, a = UInt32(px[i+3])
            colors.insert(r | g | b | a)
        }
        return colors
    }
}
// Independent topology check: flood exterior transparency with four neighbours.
// Any unreachable transparent pixel is a hole, including holes opened at a joint.
func enclosedTransparentPixels(_ image: Sprite) -> Int {
    let w=image.width, h=image.height
    var seen=[Bool](repeating:false,count:w*h), queue=[Int]()
    func add(_ i: Int) {
        if !seen[i] && image.alpha(i%w,i/w)==0 { seen[i]=true; queue.append(i) }
    }
    for x in 0..<w { add(x); add((h-1)*w+x) }
    for y in 0..<h { add(y*w); add(y*w+w-1) }
    var cursor=0
    while cursor<queue.count {
        let i=queue[cursor]; cursor += 1
        let x=i%w, y=i/w
        if x>0 { add(i-1) }; if x+1<w { add(i+1) }
        if y>0 { add(i-w) }; if y+1<h { add(i+w) }
    }
    return (0..<w*h).filter { !seen[$0] && image.alpha($0%w,$0/w)==0 }.count
}
let args = CommandLine.arguments
guard args.count == 3 else { fatalError("usage: clockin-celebrate <companion-dir> <tools-out-dir>") }
let dir = args[1], toolsDir = args[2], outDir = "\(args[1])/celebrate-loop"
let sourceData = try! Data(contentsOf: URL(fileURLWithPath: "\(dir)/celebrate.png"))
let src = Sprite(path: "\(dir)/celebrate.png")
let cyan: ([UInt8]) -> Bool = { $0[3] == 255 && $0[2] > 190 && $0[1] > 150 && $0[0] < 150 }
let eyes = src.components(cyan).filter { $0.minY > 140 && $0.maxY < 220 && $0.points.count > 150 }.sorted { $0.minX < $1.minX }
precondition(eyes.count == 2)
let core = src.components(cyan).first!
precondition(core.minY > 250 && core.maxY < 320)
// Include pale highlights inside the core, but retain its dark border and halo.
let corePoints = (core.minY...core.maxY).flatMap { y in (core.minX...core.maxX).compactMap { x -> (Int,Int)? in
    let p = src.pixel(x,y)
    return p[3] == 255 && p[1] > 180 && p[2] > 210 ? (x,y) : nil
} }
// A stable luminance-ordered ramp preserves the source's fine shading.
func luminance(_ c: [UInt8]) -> Int { 2126*Int(c[0]) + 7152*Int(c[1]) + 722*Int(c[2]) }
let ramp = Array(Set(corePoints.map { src.pixel($0.0,$0.1) })).sorted {
    luminance($0) == luminance($1) ? $0.lexicographicallyPrecedes($1) : luminance($0) < luminance($1)
}
let waistCut = 340 // Bottom of the dark belt; all lower-body rows remain source-exact.
// Below the cut, only the legs stay. The right forearm's tip also reaches below
// the belt line, and leaving it behind showed a stub beside the moved arm. The
// legs are what is connected to the ground within the rows below the cut.
let lowerBody: Set<Int> = {
    var seen = Set<Int>(), stack: [Int] = []
    for x in 0..<src.width where src.alpha(x, src.bottom) > 32 { stack.append(src.bottom*src.width+x) }
    for y in (src.bottom-40)...src.bottom { for x in 0..<src.width where src.alpha(x,y) > 32 && y == src.bottom { stack.append(y*src.width+x) } }
    while let i = stack.popLast() {
        guard !seen.contains(i) else { continue }
        seen.insert(i)
        let x = i % src.width, y = i / src.width
        for dy in -1...1 { for dx in -1...1 {
            let nx = x+dx, ny = y+dy
            guard nx >= 0, nx < src.width, ny >= waistCut, ny < src.height, src.alpha(nx,ny) > 0 else { continue }
            let j = ny*src.width+nx
            if !seen.contains(j) { stack.append(j) }
        } }
    }
    return seen
}()
func movesWithUpperBody(_ x: Int, _ y: Int) -> Bool { y < waistCut || !lowerBody.contains(y*src.width+x) }
let antennaCut = 94 // Stem base where it meets the head; this row and below stay fixed.
let pulseStride = max(1, ramp.count / 5)
let ball = src.components { $0[3] > 200 && $0[0] > 200 && $0[1] > 80 && $0[1] < 180 && $0[2] < 90 }.min { $0.minY < $1.minY }!
let antennaX = max(0,ball.minX-8)...min(src.width-1,ball.maxX+8)
var antennaTop = ball.minY
while antennaTop > 0 && antennaX.contains(where: { src.alpha($0,antennaTop-1)>0 }) { antennaTop -= 1 }
let antennaBottom = min(ball.maxY+8,antennaCut-1-6)
precondition(antennaBottom > ball.minY && antennaBottom+6 < antennaCut)
// Like coffee's springAntenna: clear the old outline and covered stem first,
// then move the ball and collar down one art pixel. The remaining stem stays.
func springAntenna(_ input: Sprite, dy: Int) -> Sprite {
    precondition(dy == 0 || dy == 6)
    guard dy != 0 else { return input }
    var out = input
    for y in antennaTop...(antennaBottom+dy) { for x in antennaX { out.set(x,y,[0,0,0,0]) } }
    for y in antennaTop...antennaBottom { for x in antennaX where input.alpha(x,y)>0 {
        out.set(x,y+dy,input.pixel(x,y))
    } }
    return out
}
let eyeCenters = eyes.map { (Double($0.minX+$0.maxX)/2, Double($0.minY+$0.maxY)/2) }
let eyeSlope = (eyeCenters[1].1-eyeCenters[0].1)/(eyeCenters[1].0-eyeCenters[0].0)
print("regions: eyes", eyes.map { "\($0.minX),\($0.minY)..\($0.maxX),\($0.maxY)" })
print("regions: core \(core.minX),\(core.minY)..\(core.maxX),\(core.maxY); \(ramp.count) luminance tones")
print("regions: antenna x=\(antennaX) rows=\(antennaTop)...\(antennaBottom) dip=6 destination bottom=\(antennaBottom+6); stem base=\(antennaCut); waist cut=\(waistCut); original bottom \(src.bottom); pulse stride=\(pulseStride)")
struct Pose { let hop: Int; let hip: Int; let antenna: Int; let blink: Bool; let pulse: Int }
// Two hops, with all displacements returning through neutral on loop closure.
let poses = [
 Pose(hop:0,hip:0,antenna:0,blink:false,pulse:0),
 Pose(hop:0,hip:1,antenna:6,blink:false,pulse:0), // Dance accent.
 Pose(hop:6,hip:1,antenna:0,blink:false,pulse:1),
 Pose(hop:12,hip:1,antenna:0,blink:false,pulse:2),
 Pose(hop:6,hip:1,antenna:0,blink:false,pulse:1),
 Pose(hop:0,hip:0,antenna:6,blink:false,pulse:0), // First landing.
 Pose(hop:0,hip:-1,antenna:0,blink:false,pulse:0),
 Pose(hop:0,hip:-1,antenna:0,blink:true,pulse:0),
 Pose(hop:0,hip:-1,antenna:6,blink:true,pulse:0),
 Pose(hop:0,hip:0,antenna:0,blink:false,pulse:0),
 Pose(hop:6,hip:0,antenna:0,blink:false,pulse:1),
 Pose(hop:12,hip:0,antenna:0,blink:false,pulse:2),
 Pose(hop:6,hip:0,antenna:0,blink:false,pulse:1),
 Pose(hop:0,hip:0,antenna:6,blink:false,pulse:0), // Second landing.
 Pose(hop:0,hip:0,antenna:0,blink:false,pulse:-1),
 Pose(hop:0,hip:0,antenna:6,blink:false,pulse:0) // Settle; antenna-only wrap.
]
func render(_ p: Pose) -> Sprite {
    var painted = src
    if p.blink {
        for eye in eyes {
            let screen = src.pixel(eye.minX-6, (eye.minY+eye.maxY)/2)
            let eyeColors: [[UInt8]] = eye.points.map { src.pixel($0.0,$0.1) }
            let ink = eyeColors.max { $0[1] < $1[1] }!
            for y in (eye.minY-4)...(eye.maxY+4) { for x in (eye.minX-4)...(eye.maxX+4) { painted.set(x,y,screen) } }
            // Each closed eye is a flat line, one art pixel tall, at its own centre.
            // A stepped line that followed the face tilt read as a glitch.
            let cy = (eye.minY+eye.maxY)/2
            for y in (cy-3)..<(cy+3) { for x in (eye.minX+1)...(eye.maxX-1) { painted.set(x,y,ink) } }
        }
    }
    if p.pulse != 0 {
        for (x,y) in corePoints {
            let index = ramp.firstIndex(of: src.pixel(x,y))!
            painted.set(x,y,ramp[max(0,min(ramp.count-1,index+p.pulse*pulseStride))])
        }
    }
    return translate(painted,p)
}
// Partition by rows, never clear a translated overlay: lower-body source pixels
// are copied exactly once, so uncovered hip pixels cannot become holes or ghosts.
func translate(_ input: Sprite, _ p: Pose, antenna: Bool = true) -> Sprite {
    let input = antenna ? springAntenna(input,dy:p.antenna) : input
    var out = Sprite(width:src.width,height:src.height,px:[UInt8](repeating:0,count:src.px.count))
    for y in 0..<src.height { for x in 0..<src.width where input.alpha(x,y)>0 {
        let dx = (movesWithUpperBody(x,y) ? p.hip*6 : 0)
        out.set(x+dx,y-p.hop,input.pixel(x,y))
    } }
    return out
}
try! FileManager.default.createDirectory(atPath:outDir,withIntermediateDirectories:true)
try! FileManager.default.createDirectory(atPath:toolsDir,withIntermediateDirectories:true)
var failures = 0
func check(_ ok: Bool,_ message: String) { if !ok { failures += 1; print("FAILED: \(message)") } }
let sourceHoles = enclosedTransparentPixels(src)
var maxHoles = 0, minimumJointOverlap = Int.max
var frames: [Sprite] = [], manifest: [[String:Any]] = []
for (i,p) in poses.enumerated() {
    let file = String(format:"e%02d.png",i+1), ms = (i == 15 ? 120 : (i == 0 ? 200 : 160))
    let frame = render(p)
    frame.save("\(outDir)/\(file)")
    let decoded = Sprite(path:"\(outDir)/\(file)")
    check(decoded.width == 627 && decoded.height == 627,"\(file) dimensions")
    check(decoded.bottom == src.bottom-p.hop,"\(file) ground")
    check(abs(decoded.opaqueCount-src.opaqueCount)*100 < src.opaqueCount,"\(file) opaque count")
    check(decoded.palette.isSubset(of:src.palette),"\(file) introduced colors")
    check(decoded.px == frame.px,"\(file) PNG round trip")
    let baseline = translate(src,p,antenna:false)
    let silhouette = translate(src,p)
    var outsideChanges = 0, lostOpaque = 0, lowerChanges = 0, headChanges = 0
    for y in 0..<src.height { for x in 0..<src.width {
        let sy = y+p.hop, sx = x-(sy < waistCut ? p.hip*6 : 0)
        let antennaWindow = antennaX.contains(sx) && (antennaTop...(antennaBottom+6)).contains(sy)
        let eyeWindow = eyes.contains { ( $0.minX-4 ... $0.maxX+4 ).contains(sx) && ( $0.minY-4 ... $0.maxY+4 ).contains(sy) }
        let coreWindow = (core.minX...core.maxX).contains(sx) && (core.minY...core.maxY).contains(sy)
        if !antennaWindow && !eyeWindow && !coreWindow && decoded.pixel(x,y) != baseline.pixel(x,y) { outsideChanges += 1 }
        if silhouette.alpha(x,y) == 255 && decoded.alpha(x,y) != 255 { lostOpaque += 1 }
        if sy >= waistCut && sy < src.height && lowerBody.contains(sy*src.width+x) && decoded.pixel(x,y) != src.pixel(x,sy) { lowerChanges += 1 }
        if (94...120).contains(sy) && decoded.pixel(x,y) != baseline.pixel(x,y) { headChanges += 1 }
    } }
    let holes = enclosedTransparentPixels(decoded)
    maxHoles = max(maxHoles,holes)
    check(holes == 0,"\(file) enclosed transparent holes: \(holes)")
    check(outsideChanges == 0,"\(file) outside edit regions: \(outsideChanges)")
    check(lostOpaque == 0,"\(file) lost source silhouette pixels: \(lostOpaque)")
    check(lowerChanges == 0,"\(file) lower body changed")
    check(headChanges == 0,"\(file) head top changed")
    // Check each joint has real opaque overlap across adjacent rows.
    for joint in [antennaCut,waistCut] {
        let range = joint == antennaCut ? 350...390 : 255...355
        let overlap = range.filter { x in
            let dx=p.hip*6
            return decoded.alpha(x+dx,joint-1-p.hop)==255 && decoded.alpha(x+dx,joint-p.hop)==255
        }.count
        minimumJointOverlap = min(minimumJointOverlap,overlap)
        check(overlap >= 1,"\(file) disconnected joint y=\(joint), overlap=\(overlap)")
    }
    frames.append(decoded); manifest.append(["file":file,"ms":ms])
    print("\(file) \(ms)ms hop=\(p.hop) hip=\(p.hip*6) antennaDy=\(p.antenna) blink=\(p.blink) pulse=\(p.pulse) bottom=\(decoded.bottom) opaque=\(decoded.opaqueCount)")
}
func difference(_ a: Sprite,_ b: Sprite) -> Int {
    stride(from:0,to:a.px.count,by:4).reduce(0) { count,i in
        count + (a.px[i..<i+4].elementsEqual(b.px[i..<i+4]) ? 0 : 1)
    }
}
let differences = frames.indices.map { difference(frames[$0],frames[($0+1)%frames.count]) }
check(differences.allSatisfy {$0 > 0},"consecutive or wrap duplicate")
check(differences.last! <= differences.dropLast().max()!,"wrap jump")
let wrapOutsideAntenna = (0..<src.height).reduce(0) { count,y in
    count + (0..<src.width).filter { x in
        !(antennaX.contains(x) && (antennaTop...(antennaBottom+6)).contains(y)) && frames.last!.pixel(x,y) != frames[0].pixel(x,y)
    }.count
}
check(wrapOutsideAntenna == 0,"wrap changes outside antenna")
check(differences.last! == difference(src,springAntenna(src,dy:6)),"wrap differs from a single antenna dip")
for level in [-1,0,1,2] {
    let indices = ramp.indices.map { max(0,min(ramp.count-1,$0+level*pulseStride)) }
    check(zip(indices,indices.dropFirst()).allSatisfy { $0 <= $1 },"pulse tone ordering level \(level)")
}
check(sourceData == (try! Data(contentsOf:URL(fileURLWithPath:"\(dir)/celebrate.png"))),"source modified")
let json = try! JSONSerialization.data(withJSONObject:["frames":manifest],options:[.prettyPrinted,.sortedKeys])
try! json.write(to:URL(fileURLWithPath:"\(outDir)/sequence.json"))
// 4x4 contact sheet. Exact nearest-neighbour sampling, matching the coffee helper.
let cell = 157, w = cell*4, h = cell*4
var sheet = Sprite(width:w,height:h,px:[UInt8](repeating:255,count:w*h*4))
for (i,frame) in frames.enumerated() {
    for y in 0..<cell { for x in 0..<cell {
        let p = frame.pixel(x*4,y*4), a = Double(p[3])/255
        sheet.set(i%4*cell+x,i/4*cell+y,(0..<3).map { UInt8(min(255,Double(p[$0])+215*(1-a))) } + [255])
    } }
    for x in 0..<cell { sheet.set(i%4*cell+x,i/4*cell+src.bottom/4,[230,30,30,255]) }
}
sheet.save("\(toolsDir)/sheet.png")
print("verification: 16 frames 627x627; 2560ms; ground rest=515 hop=509/503; opaque source=\(src.opaqueCount), max delta=\(frames.map {abs($0.opaqueCount-src.opaqueCount)}.max()!)")
print("verification: consecutive changed pixels \(differences); wrap=\(differences.last!); palette source-only; PNG round trips; source unchanged")
// Full-resolution crops, aligned back to source coordinates for review.
func crop(_ frame: Sprite, _ x0: Int, _ y0: Int, _ w: Int, _ h: Int, _ name: String) {
    var result = Sprite(width:w,height:h,px:[UInt8](repeating:0,count:w*h*4))
    for y in 0..<h { for x in 0..<w { result.set(x,y,frame.pixel(x+x0,y+y0)) } }
    result.save("\(toolsDir)/\(name).png")
}
for (i,name) in [(1,"plus"),(6,"minus")] {
    crop(frames[i],230,315,150,50,"waist-\(name)")
}
crop(frames[7],270-6,155,115,60,"blink")
for (i,name) in [(0,"rest"),(5,"dip")] {
    crop(frames[i],330,50,75,75,"antenna-\(name)")
}
for (i,name) in [(14,"dim"),(0,"rest"),(2,"mid"),(3,"peak")] {
    crop(frames[i],265+poses[i].hip*6,270-poses[i].hop,60,50,"core-\(name)")
}
if failures > 0 { print("\(failures) checks failed"); exit(1) }
print("verification: outside-region changes=0; lost opaque silhouette pixels=0; lower-body changes=0; head-top changes=0; minimum joint overlap=\(minimumJointOverlap) opaque pixels; enclosed transparent holes=\(maxHoles) (source=\(sourceHoles))")
print("verification: pulse levels=-1/0/1/2 stride=\(pulseStride), tone ordering preserved; wrap outside antenna=\(wrapOutsideAntenna)")
print("all checks passed")
