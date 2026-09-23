#!/usr/bin/env swift
// Shared deterministic art engine. Entry points: make-mascot-anchors, make-wardrobe, make-home, make-wardrobe-preview.
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

func color(_ hex: String) -> Pixel {
    let n = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16)!
    return Pixel(r: UInt8((n >> 16) & 255), g: UInt8((n >> 8) & 255), b: UInt8(n & 255), a: 255)
}
func hex(_ p: Pixel) -> String { String(format: "#%02X%02X%02X", Int(p.r), Int(p.g), Int(p.b)) }
let ink = color("191D24"), paper = color("F7F6F5"), steel = color("414857")
let orange = color("FF771A"), gold = color("F2C458"), cyan = color("49EBFF")
let teal = color("459B93"), purple = color("7961A8"), coral = color("DE756B")
let wood = color("A96E48"), woodLight = color("D89C68"), woodDark = color("684739")
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let framesDir = root.appendingPathComponent("Shared/Mascot/Frames")
let wardrobeDir = root.appendingPathComponent("Shared/Mascot/Wardrobe")
let homeDir = root.appendingPathComponent("Shared/Mascot/Home")
let frameFiles = try FileManager.default.contentsOfDirectory(at: framesDir, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.range(of: "^[htceazp].*\\.png$", options: .regularExpression) != nil }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
func saveJSON(_ value: Any, _ url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: url)
}
func json(_ url: URL) throws -> [String: Any] { try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any] }
extension Bitmap {
    mutating func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ p: Pixel) {
        guard w > 0 && h > 0 else { return }
        let x0=max(0,x), y0=max(0,y), x1=min(width,x+w), y1=min(height,y+h)
        guard x0<x1 && y0<y1 else { return }
        for yy in y0..<y1 { for xx in x0..<x1 { self[xx,yy] = p } }
    }
    mutating func blit(_ b: Bitmap, _ x: Int, _ y: Int, width dw: Int? = nil, height dh: Int? = nil) {
        let tw = dw ?? b.width, th = dh ?? b.height
        for dy in 0..<th { for dx in 0..<tw where x+dx >= 0 && x+dx < width && y+dy >= 0 && y+dy < height {
            let p = b[min(b.width-1,(2*dx+1)*b.width/(2*tw)),min(b.height-1,(2*dy+1)*b.height/(2*th))]
            if p.a == 0 { continue }
            let bg = self[x+dx,y+dy], a = Int(p.a), ba = Int(bg.a), oa = a + ba*(255-a)/255
            self[x+dx,y+dy] = Pixel(r: UInt8((Int(p.r)*a+Int(bg.r)*ba*(255-a)/255)/oa),
                g: UInt8((Int(p.g)*a+Int(bg.g)*ba*(255-a)/255)/oa),
                b: UInt8((Int(p.b)*a+Int(bg.b)*ba*(255-a)/255)/oa), a: UInt8(oa))
        } }
    }
}
// Tiny bitmap alphabet keeps labels dependency free and uses nearest neighbor too.
let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789- /."
let letterRows = ["01110/10001/11111/10001/10001","11110/10001/11110/10001/11110","01111/10000/10000/10000/01111","11110/10001/10001/10001/11110","11111/10000/11110/10000/11111","11111/10000/11110/10000/10000","01111/10000/10111/10001/01111","10001/10001/11111/10001/10001","111/010/010/010/111","00111/00010/00010/10010/01100","10001/10010/11100/10010/10001","10000/10000/10000/10000/11111","10001/11011/10101/10001/10001","10001/11001/10101/10011/10001","01110/10001/10001/10001/01110","11110/10001/11110/10000/10000","01110/10001/10101/10010/01101","11110/10001/11110/10010/10001","01111/10000/01110/00001/11110","11111/00100/00100/00100/00100","10001/10001/10001/10001/01110","10001/10001/10001/01010/00100","10001/10001/10101/11011/10001","10001/01010/00100/01010/10001","10001/01010/00100/00100/00100","11111/00010/00100/01000/11111","111/101/101/101/111","010/110/010/010/111","110/001/010/100/111","110/001/010/001/110","101/101/111/001/001","111/100/110/001/110","011/100/111/101/111","111/001/010/010/010","111/101/111/101/111","111/101/111/001/110","000/000/111/000/000","00/00/00/00/00","00001/00010/00100/01000/10000","0/0/0/0/1"]
let font = Dictionary(uniqueKeysWithValues: zip(alphabet, letterRows))
func label(_ text: String, _ b: inout Bitmap, _ x: Int, _ y: Int, _ s: Int = 2, _ p: Pixel = paper) {
    var cx = x
    for c in text.uppercased() {
        let rows = font[c, default: "0/0/0/0/0"].split(separator: "/")
        for (dy,row) in rows.enumerated() { for (dx,v) in row.enumerated() where v == "1" { b.rect(cx+dx*s,y+dy*s,s,s,p) } }
        cx += (rows[0].count+1)*s
    }
}
struct Anchors {
    var head: [Int], visor: [Int], neck: [Int], back: [Int], handL: [Int]?, handR: [Int]?, tilt: Double
    var object: [String: Any] { ["head":head,"visor":visor,"neck":neck,"back":back,"handL":handL as Any? ?? NSNull(),"handR":handR as Any? ?? NSNull(),"tilt":tilt] }
}
struct Geometry {
    let visor: Bounds, helmet: Bounds, torso: Bounds, unit: Int
    let anchors: Anchors
    init(_ b: Bitmap, id: String, diagnostics: Bool = false) {
        let w = b.width
        let darkParts = components(b, matching: isDark)
        
        let rawVisor = darkParts.filter {
            let r = bounds($0,width:w)
            return r.width >= 45 && r.width <= 125 && r.height >= 28 && r.height < 160 && r.y0 < 140
        }.max { $0.count < $1.count }!
        // A lifted mug can touch the visor outline. Keep the helmet-local portion
        // of that connected component; its lower part belongs to the held object.
        let rawBox = bounds(rawVisor,width:w)
        let vp = rawBox.height > 100 ? rawVisor.filter { $0/w < rawBox.y0+64 } : rawVisor
        let v = bounds(vp,width:w); visor = v
        unit = pixelUnit(vp,width:w)
        let shell = components(b, matching: { $0.a > 200 && min($0.r,$0.g,$0.b) > 165 && Int(max($0.r,$0.g,$0.b))-Int(min($0.r,$0.g,$0.b)) < 55 })
        let helmetParts = shell.filter {
            let r = bounds($0,width:w)
            return r.width > v.width/2 && r.midX >= v.x0 && r.midX <= v.x1 && r.y0 < v.y0 && r.y1 >= v.y0
        }
        let hp = helmetParts.max { $0.count < $1.count }!
        let hb = bounds(hp,width:w); helmet = hb
        // Fit the upper visor contour, ignoring its rounded outer corners. This also
        // detects the celebrating pose's tilted helmet without an id-specific angle.
        var contour = [(Double,Double)]()
        for x in (v.x0+v.width/4)...(v.x1-v.width/4) {
            if let y = vp.lazy.filter({ $0 % w == x }).map({ $0 / w }).min() { contour.append((Double(x),Double(y))) }
        }
        let mx = contour.map{$0.0}.reduce(0,+)/Double(contour.count), my = contour.map{$0.1}.reduce(0,+)/Double(contour.count)
        let slope = contour.map{($0.0-mx)*($0.1-my)}.reduce(0,+)/contour.map{pow($0.0-mx,2)}.reduce(0,+)
        let angle = abs(slope) < 0.045 ? 0 : atan(slope)*180/Double.pi
        // The topmost broad shell edge excludes the separate antenna and side ears.
        let topPixels = hp.filter { $0/w <= hb.y0+2 }
        let topCenter = bounds(topPixels,width:w).midX
        let bottomPixels = hp.filter { $0/w >= hb.y1-2 }
        let bottomCenter = bounds(bottomPixels,width:w).midX
        let bodyParts = shell.filter {
            let r = bounds($0,width:w)
            return r.y0 >= v.y1 && r.midY < v.y1+70 && r.x0 <= v.midX && r.x1 >= v.midX && r.width >= 28
        }
        let torsoBox = bodyParts.map{bounds($0,width:w)}.min { $0.y0 < $1.y0 }
            ?? Bounds(x0:hb.midX-22,y0:hb.y1+6,x1:hb.midX+22,y1:hb.y1+46)
        torso = torsoBox
        // Hands are the small pale lobes outside the helmet, separated by the dark
        // wrist joint. Select the outermost high lobe in raised poses. Working hands
        // remain visible above the keyboard; coffee hands already grip the cup/body.
        var hands = [[Int]]()
        if !id.hasPrefix("c") {
            let candidates = shell.filter {
                let r = bounds($0,width:w)
                if id.hasPrefix("t") {
                    return r.y0 > v.y1+44 && r.y1 < v.y1+82 && r.x0 >= v.x0-4 && r.x1 <= v.x1+2 && r.width >= 5 && r.width < 35 && r.height < 30
                }
                return (r.midX < hb.x0-12 || r.midX > hb.x1+12) && r.y0 < hb.y1+12 && r.y1 > hb.y0 && r.width >= 5 && r.width < 37 && r.height < 40
            }.map { bounds($0,width:w) }
            for left in [true,false] {
                let side = candidates.filter { left ? $0.midX < v.midX : $0.midX >= v.midX }
                if let first = side.min(by: { $0.y0 < $1.y0 }) {
                    // Include adjacent knuckle lobes, but not the forearm below.
                    let near = side.filter { abs($0.midY-first.midY) <= 10 && abs($0.midX-first.midX) <= 25 }
                    let x0 = near.map{$0.x0}.min()!, x1 = near.map{$0.x1}.max()!
                    let y0 = near.map{$0.y0}.min()!, y1 = near.map{$0.y1}.max()!
                    hands.append([(x0+x1)/2,(y0+y1)/2 + (id.hasPrefix("t") ? 0:4)])
                } else { hands.append([]) }
            }
        } else {
            // Coffee poses use dark gloves. Detect the mug's orange round emblem,
            // then exclude gloves already interacting with that object. Folded
            // gloves form one wide component, split at its two knuckle centers.
            let emblems=components(b,matching: { $0.a>200 && $0.r>180 && $0.g<175 && $0.b<100 }).filter {
                let r=bounds($0,width:w)
                return $0.count>60 && r.y0>v.y1-25 && r.height>10 && r.width<35 && r.width*10<=r.height*13
            }.map{bounds($0,width:w)}
            let gloves=components(b,matching: { $0.a>240 && min($0.r,$0.g,$0.b)>30 && max($0.r,$0.g,$0.b)<140 }).filter{$0.count>40}.map{bounds($0,width:w)}.filter {
                $0.width>=13 && $0.width<43 && $0.height>=13 && $0.height<33 && $0.y0>v.y1+24 && $0.y1<v.y1+85 && $0.x1<hb.x1
            }.filter { glove in
                !emblems.contains { abs($0.midX-glove.midX)<$0.width/2+35 && abs($0.midY-glove.midY)<48 }
            }
            hands=[[],[]]
            for glove in gloves {
                if glove.width>30 && abs(glove.midX-v.midX)<22 {
                    hands=[[glove.x0+9,glove.midY],[glove.x1-9,glove.midY]]
                } else {
                    hands[glove.midX<v.midX-20 ? 0:1]=[glove.midX,glove.midY]
                }
            }
        }
        let neckX = id.hasPrefix("c") ? v.midX+3 : (angle == 0 ? bottomCenter : Int(Double(v.midX)-sin(angle*Double.pi/180)*Double(v.height/2+8)))
        let neckY = id.hasPrefix("c") ? v.y1+12 : (angle == 0 ? hb.y1+3 : v.midY+v.height/2+8)
        anchors = Anchors(head:[topCenter,hb.y0-2],visor:[v.midX,v.midY],neck:[neckX,neckY],
            back:[id.hasPrefix("c") ? neckX+4 : torsoBox.midX,neckY+14],
            handL:hands[0].isEmpty ? nil : hands[0],handR:hands[1].isEmpty ? nil : hands[1],tilt:(angle*10).rounded()/10)
        if diagnostics { print("\(id): visor \(v), helmet \(hb), torso \(torsoBox), unit \(unit), hands \(hands), tilt \(anchors.tilt)") }
    }
}
func makeAnchors() throws {
    var all = [String:Any]()
    let cell = 330, columns = 7
    var sheet = Bitmap(width:columns*cell,height:70+((frameFiles.count+columns-1)/columns)*cell,fill:color("252C37"))
    label("HEAD RED / VISOR CYAN / NECK GOLD / BACK PURPLE / HAND L GREEN / HAND R PINK", &sheet, 16, 16)
    for (i,url) in frameFiles.enumerated() {
        let id = url.deletingPathExtension().lastPathComponent, b = Bitmap(url:url)
        // Legacy acc-* files also match the contract's a* prefix. Their existing
        // generator paints accessories onto h01 without moving the underlying
        // robot. Detect that source pose for landmarks hidden by the baked art.
        let detectionSource = id.hasPrefix("acc-") ? Bitmap(url:framesDir.appendingPathComponent("h01.png")) : b
        let f = Geometry(detectionSource,id:id,diagnostics:true)
        var anchor = f.anchors
        if id == "acc-mug" { anchor.handL = nil }
        all[id] = anchor.object
        let x = i%columns*cell+8, y = 70+i/columns*cell
        sheet.blit(b,x,y)
        for (key,p) in [("head",color("FF544C")),("visor",cyan),("neck",gold),("back",color("B78CFF")),("handL",color("49FF83")),("handR",color("FF77CE"))] {
            if let xy = anchor.object[key] as? [Int] {
                sheet.rect(x+xy[0]-5,y+xy[1]-1,11,3,ink); sheet.rect(x+xy[0]-1,y+xy[1]-5,3,11,ink)
                sheet.rect(x+xy[0]-4,y+xy[1],9,1,p); sheet.rect(x+xy[0],y+xy[1]-4,1,9,p)
            }
        }
        label(id,&sheet,x+10,y+304)
    }
    try saveJSON(all,framesDir.appendingPathComponent("mascot-anchors.json"))
    sheet.write(URL(fileURLWithPath:"/tmp/clockin-anchors.png"))
    for prefix in ["a","c","e","h","p","t","z"] {
        let selected=frameFiles.enumerated().filter{$0.element.lastPathComponent.hasPrefix(prefix)}
        var family=Bitmap(width:1320,height:40+((selected.count+3)/4)*330,fill:color("252C37"))
        label("HEAD RED / VISOR CYAN / NECK GOLD / BACK PURPLE / L GREEN / R PINK",&family,12,12)
        for (j,entry) in selected.enumerated() {
            let sx=entry.offset%columns*cell,sy=70+entry.offset/columns*cell
            for y in 0..<330 { for x in 0..<330 { family[j%4*330+x,40+j/4*330+y]=sheet[sx+x,sy+y] } }
        }
        family.write(URL(fileURLWithPath:"/tmp/clockin-anchors-"+prefix+".png"))
    }
    print("Anchors: \(all.count) frames. /tmp/clockin-anchors.png")
}
if CommandLine.arguments.last == "anchors" { try makeAnchors() }
// Draw in art cells, then expand each cell to exactly 2 image pixels. Polygon
// coverage is evaluated at cell centers; no antialiasing or fractional resampling.
struct Art {
    var b = Bitmap(width:180,height:140)
    mutating func rect(_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ p:Pixel) { b.rect(x,y,w,h,p) }
    mutating func box(_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ p:Pixel) { rect(x,y,w,h,ink); rect(x+1,y+1,w-2,h-2,p) }
    mutating func ellipse(_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ p:Pixel) {
        for yy in y..<(y+h) { for xx in x..<(x+w) {
            if pow((Double(xx-x)+0.5)/Double(w)*2-1,2)+pow((Double(yy-y)+0.5)/Double(h)*2-1,2) <= 1 { rect(xx,yy,1,1,p) }
        } }
    }
    mutating func oval(_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ p:Pixel) { ellipse(x,y,w,h,ink); ellipse(x+1,y+1,w-2,h-2,p) }
    mutating func poly(_ points:[(Int,Int)],_ p:Pixel) {
        let x0=points.map{$0.0}.min()!, x1=points.map{$0.0}.max()!, y0=points.map{$0.1}.min()!, y1=points.map{$0.1}.max()!
        for y in y0...y1 { for x in x0...x1 {
            var inside=false, j=points.count-1
            for i in points.indices {
                let a=points[i], c=points[j], py=Double(y)+0.5, px=Double(x)+0.5
                if (Double(a.1)>py) != (Double(c.1)>py) && px < Double(c.0-a.0)*(py-Double(a.1))/Double(c.1-a.1)+Double(a.0) { inside.toggle() }
                j=i
            }
            if inside { rect(x,y,1,1,p) }
        } }
    }
    mutating func line(_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int,_ p:Pixel,_ thick:Int=1) {
        let n=max(abs(x1-x0),abs(y1-y0))
        for i in 0...max(1,n) { rect(x0+(x1-x0)*i/max(1,n),y0+(y1-y0)*i/max(1,n),thick,thick,p) }
    }
    mutating func star(_ x:Int,_ y:Int,_ p:Pixel) { rect(x+2,y,1,5,p); rect(x,y+2,5,1,p); rect(x+1,y+1,3,3,p) }
    mutating func material(_ base: Pixel, shadow: Pixel, light: Pixel) {
        let original = b
        func same(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && y >= 0 && x < original.width && y < original.height && original[x,y] == base
        }
        for y in 2..<(b.height-3) { for x in 2..<(b.width-3) where same(x,y) {
            // Only shade broad surfaces. Preserve tiny stitching and facial details.
            guard same(x-1,y) && same(x+1,y) && same(x,y-1) && same(x,y+1) else { continue }
            if !same(x+3,y) || !same(x,y+3) { b[x,y] = shadow }
            else if !same(x-2,y) || !same(x,y-2) { b[x,y] = light }
        } }
    }
    mutating func finishMaterials() {
        material(color("3C785F"), shadow: color("285348"), light: color("8BBE78"))
        material(teal, shadow: color("286A70"), light: color("86D9BD"))
        material(purple, shadow: color("493C73"), light: color("BCA0DC"))
        material(coral, shadow: color("A54758"), light: color("FFB59A"))
        material(gold, shadow: color("B67635"), light: color("FFF0B0"))
        material(paper, shadow: color("A5B0CA"), light: color("FFFFFF"))
        material(steel, shadow: color("283040"), light: color("778BA4"))
        material(wood, shadow: color("754A3D"), light: color("DBA875"))
        material(woodLight, shadow: color("AC704D"), light: color("F4D4A0"))
    }
    mutating func worktable() {
        // Every desk option is a complete station, so its object never floats.
        box(8,42,66,6,woodLight)
        rect(10,43,62,1,color("FFE0AE"))
        box(12,48,6,26,wood); box(64,48,6,26,wood)
        box(18,49,45,10,wood); rect(21,50,39,1,woodLight)
        box(37,52,9,3,gold)
        rect(13,49,2,23,woodLight); rect(65,49,2,23,woodLight)
        rect(18,59,46,2,woodDark)
    }
    // A one-art-cell outline surrounds the union, including thin strings. This
    // does not fill transparent holes in glasses or handles.
    func sprite(pivot:[Int], outline:Bool=true) -> (Bitmap,[Int]) {
        var raster=b
        if outline {
            for y in 1..<(b.height-1) { for x in 1..<(b.width-1) where b[x,y].a==0 {
                if [(x-1,y),(x+1,y),(x,y-1),(x,y+1)].contains(where:{b[$0.0,$0.1].a>0 && b[$0.0,$0.1] != ink}) { raster[x,y]=ink }
            } }
        }
        let pixels=(0..<(raster.width*raster.height)).filter{raster[$0%raster.width,$0/raster.width].a>0}
        let r=bounds(pixels,width:raster.width)
        precondition(r.contains(pivot[0],pivot[1]),"Pivot outside content bounds")
        var out=Bitmap(width:r.width*2,height:r.height*2)
        for y in 0..<r.height { for x in 0..<r.width { out.rect(x*2,y*2,2,2,raster[x+r.x0,y+r.y0]) } }
        return (out,[(pivot[0]-r.x0)*2,(pivot[1]-r.y0)*2])
    }
}
func makeWardrobe() throws {
    try FileManager.default.createDirectory(at:wardrobeDir,withIntermediateDirectories:true)
    // Sizes follow the measured hello helmet and visor in art cells. The fixed
    // contract has no scale per pose, so use a modest overhang on hello that also
    // fits the wider three-quarter typing helmet.
    let g=Geometry(Bitmap(url:framesDir.appendingPathComponent("h01.png")),id:"h01")
    precondition(g.unit==2)
    var catalog=[String:Any]()
    func item(_ id:String,_ slot:String,_ pivot:[Int],_ draw:(inout Art)->Void) {
        var a=Art(); draw(&a); a.finishMaterials()
        // Fit in whole art cells around the authored attachment point. Visor
        // accessories stay inside the face; neck and hand items stay subordinate
        // to the robot. Hats retain enough clearance for the highest dance pose.
        let fit: [String: (Double, Double)] = [
            "cap": (0.80, 0.80), "antenna": (0.85, 0.65),
            "beanie": (0.84, 0.65), "party-hat": (0.55, 0.48),
            "chef-hat": (0.78, 0.60), "crown": (0.80, 0.60),
            "cowboy-hat": (0.80, 0.72), "wizard-hat": (0.70, 0.48),
            "round-glasses": (0.80, 0.80), "sunglasses": (0.80, 0.80),
            "pixel-shades": (0.80, 0.80), "monocle": (0.78, 0.78),
            "scarf": (0.76, 0.76), "bow-tie": (0.62, 0.62),
            "gold-medal": (0.65, 0.65), "necktie": (0.68, 0.68),
            "cape": (0.84, 0.84), "backpack": (0.76, 0.76),
            "jetpack": (0.82, 0.82), "mug": (0.68, 0.68),
            "trophy": (0.62, 0.62), "balloon": (0.76, 0.76),
            "small-flag": (0.70, 0.70)
        ]
        let (fitX, fitY) = fit[id] ?? (1.0, 1.0)
        var fittedPivot = pivot
        if fitX != 1 || fitY != 1 {
            let original = a.b
            a.b = Bitmap(width:180, height:140)
            a.b.blit(original, 0, 0, width:Int(180 * fitX), height:Int(140 * fitY))
            fittedPivot = [Int(Double(pivot[0]) * fitX), Int(Double(pivot[1]) * fitY)]
        }
        let (sprite,p)=a.sprite(pivot:fittedPivot)
        sprite.write(wardrobeDir.appendingPathComponent(id+".png"))
        let anchor=id == "headphones" ? "visor" : ["head":"head","face":"visor","neck":"neck","back":"back","hand":"handR"][slot]!
        var entry: [String: Any] = ["slot":slot,"anchorPoint":anchor,"pivot":p,"layer":slot=="back" ? "back":"front"]
        // Expose the near edge of compact packs in side-facing poses. These
        // offsets affect fitting only, never the behind-the-body layer order.
        let sideFits: [String: [String: [Int]]] = [
            "backpack": ["t": [-26, -4], "c": [38, -6], "pose2": [-26, -4], "pose4": [-22, 0]],
            "jetpack": ["t": [-20, -4], "c": [24, -6], "pose2": [-20, -4], "pose4": [-18, 0]],
            "cape": ["t": [-10, 0], "c": [12, 0], "pose2": [-10, 0], "pose4": [-10, 0]]
        ]
        if let offsets = sideFits[id] { entry["poseOffsets"] = offsets }
        catalog[id] = entry
    }
    item("cap","head",[40,34]) { a in
        a.ellipse(16,17,48,43,teal); a.rect(10,38,63,5,teal)
        a.poly([(44,38),(68,38),(78,42),(70,46),(43,44)],color("286A70"))
        a.rect(14,43,50,20,.clear)
        a.line(39,19,39,35,color("286A70")); a.line(41,20,41,35,color("86D9BD"))
        a.rect(22,34,38,4,color("286A70")); a.rect(22,34,34,1,color("86D9BD"))
        a.box(26,25,13,8,woodLight); a.star(30,26,paper)
        a.rect(36,16,6,3,gold); a.line(51,40,69,41,color("86D9BD"))
    }
    item("antenna","head",[40,36]) { a in
        a.box(31,32,19,6,steel); a.rect(33,32,15,2,gold)
        a.box(38,19,5,14,steel); a.rect(39,20,2,10,paper)
        a.oval(32,8,17,15,coral); a.oval(35,10,10,9,gold)
        a.rect(36,10,4,3,paper); a.rect(35,36,11,2,steel)
    }
    item("beanie","head",[40,34]) { a in
        a.ellipse(16,12,48,49,purple); a.rect(14,34,52,10,color("493C73"))
        a.rect(15,44,52,25,.clear)
        for x in stride(from:22,through:59,by:6) { a.line(x,23,x,32,color("BCA0DC")); a.line(x,35,x,41,purple) }
        a.rect(18,34,44,2,color("BCA0DC")); a.oval(33,4,15,13,gold)
        a.rect(35,6,5,3,paper); a.box(46,36,11,6,woodLight); a.rect(49,38,5,2,woodDark)
    }
    item("party-hat","head",[40,39]) { a in
        a.poly([(16,44),(39,7),(64,44)],coral)
        a.poly([(40,10),(64,44),(50,44)],color("A54758"))
        a.poly([(22,34),(27,27),(53,34),(58,41)],gold)
        a.poly([(30,23),(33,18),(44,21),(48,28)],paper)
        a.rect(17,42,47,4,gold); a.rect(21,42,37,1,paper)
        a.oval(35,3,9,9,gold); a.star(34,33,teal)
    }
    item("crown","head",[40,30]) { a in
        a.poly([(14,11),(26,21),(40,6),(53,21),(66,11),(61,38),(20,38)],gold)
        a.poly([(53,21),(66,11),(61,38),(51,38)],color("B67635"))
        a.rect(20,32,42,6,gold); a.rect(21,32,39,2,color("FFF0B0"))
        a.box(35,22,11,10,woodDark); a.poly([(40,23),(45,27),(40,31),(36,27)],coral)
        a.rect(38,24,3,3,paper); a.box(24,27,5,4,cyan); a.box(52,27,5,4,cyan)
        for (x,y) in [(12,8),(38,3),(64,8)] { a.oval(x,y,5,5,gold); a.rect(x+1,y+1,2,1,paper) }
    }
    item("wizard-hat","head",[40,42]) { a in
        a.poly([(20,44),(30,23),(38,10),(58,6),(48,16),(52,28),(62,44)],purple)
        a.poly([(44,13),(58,6),(48,17),(54,31),(61,43),(48,43)],color("493C73"))
        a.oval(8,42,66,9,purple); a.rect(23,38,35,6,color("493C73"))
        a.line(27,38,53,38,color("BCA0DC")); a.box(38,39,9,5,gold)
        a.star(36,23,gold); a.star(47,31,color("FFF0B0")); a.rect(39,14,2,2,paper)
    }
    item("chef-hat","head",[40,34]) { a in
        a.oval(12,11,25,25,paper); a.oval(26,5,30,31,paper); a.oval(47,12,23,25,paper)
        a.rect(21,26,40,16,paper); a.rect(22,38,38,6,color("A5B0CA"))
        a.rect(23,38,35,3,paper)
        a.line(29,27,29,36,color("A5B0CA")); a.line(41,29,41,36,color("A5B0CA")); a.line(53,27,53,36,color("A5B0CA"))
        a.rect(20,14,8,2,color("FFFFFF")); a.rect(35,9,10,2,color("FFFFFF"))
    }
    item("cowboy-hat","head",[40,30]) { a in
        a.poly([(21,34),(25,10),(37,15),(48,10),(59,33)],woodLight)
        a.poly([(47,13),(53,13),(59,34),(48,34)],wood)
        a.poly([(6,26),(18,32),(61,32),(76,25),(72,36),(62,42),(20,42),(9,35)],woodLight)
        a.line(14,36,24,39,woodDark,2); a.line(24,39,59,39,woodDark,2)
        a.rect(23,28,36,6,woodDark); a.box(38,29,9,6,gold); a.rect(41,31,3,2,woodDark)
        a.line(28,15,27,25,color("F4D4A0")); a.line(13,29,21,33,color("F4D4A0"))
    }
    item("headphones","head",[40,32]) { a in
        a.ellipse(10,6,60,51,steel); a.ellipse(16,12,48,43,.clear)
        a.rect(18,35,45,28,.clear); a.rect(0,44,80,25,.clear)
        a.line(23,9,55,9,color("778BA4"),2)
        a.box(9,22,12,23,steel); a.box(60,22,12,23,steel)
        a.box(10,26,8,14,orange); a.box(64,26,8,14,orange)
        a.rect(12,28,2,9,gold); a.rect(66,28,2,9,gold)
        a.rect(18,24,3,19,color("A5B0CA")); a.rect(60,24,3,19,color("A5B0CA"))
    }
    item("round-glasses","face",[40,25]) { a in
        for x in [20,43] { a.oval(x,16,18,18,gold); a.ellipse(x+3,19,12,12,.clear); a.rect(x+4,19,2,4,paper) }
        a.line(37,23,43,23,gold,2); a.line(15,21,20,23,gold,2); a.line(60,23,64,21,gold,2)
    }
    item("sunglasses","face",[40,25]) { a in
        a.poly([(17,18),(37,20),(35,33),(22,32)],steel); a.poly([(43,20),(63,18),(58,32),(45,33)],steel)
        a.line(16,18,64,18,gold,2); a.rect(37,22,7,3,gold)
        a.line(22,22,30,22,color("778BA4"),2); a.line(24,24,29,24,cyan)
        a.line(47,22,55,22,color("778BA4"),2); a.line(49,24,54,24,cyan)
    }
    item("pixel-shades","face",[40,25]) { a in
        a.rect(17,18,46,5,ink); a.rect(20,23,17,9,ink); a.rect(43,23,17,9,ink)
        a.rect(18,18,44,1,color("778BA4"))
        for x in [22,28,45,51] { a.rect(x,22,3,3,paper); a.rect(x+3,25,3,3,paper) }
        a.rect(22,30,13,1,steel); a.rect(45,30,13,1,steel)
    }
    item("monocle","face",[40,25]) { a in
        a.oval(43,15,20,20,gold); a.ellipse(47,19,12,12,.clear)
        a.rect(47,19,2,5,paper); a.line(37,23,43,23,gold,2)
        a.line(61,29,64,37,gold); a.line(64,37,62,47,gold); a.line(62,47,56,50,gold)
        a.oval(54,48,4,4,gold)
    }
    item("scarf","neck",[40,12]) { a in
        a.poly([(22,7),(36,11),(58,7),(57,17),(40,21),(23,16)],coral)
        a.poly([(49,15),(59,12),(64,38),(52,36)],coral)
        a.poly([(48,16),(53,17),(58,35),(53,35)],color("A54758"))
        a.line(25,11,38,15,color("FFB59A"),2); a.line(39,15,53,12,color("FFB59A"),2)
        a.line(55,25,61,24,gold,3)
        for x in [53,57,61] { a.rect(x,35,2,5,gold) }
    }
    item("bow-tie","neck",[40,14]) { a in
        a.poly([(23,6),(40,12),(57,6),(57,23),(40,17),(23,23)],purple)
        a.poly([(25,9),(37,14),(25,19)],color("BCA0DC")); a.poly([(55,10),(43,15),(55,20)],color("493C73"))
        a.box(37,10,8,10,gold); a.rect(39,12,2,5,paper)
    }
    item("gold-medal","neck",[40,8]) { a in
        a.line(24,6,39,24,coral,4); a.line(53,6,40,24,coral,4)
        a.line(26,7,39,22,paper); a.line(54,8,43,22,gold)
        a.oval(31,21,21,21,gold); a.oval(34,24,15,15,color("B67635"))
        a.star(39,29,color("FFF0B0")); a.rect(35,24,6,2,paper)
    }
    item("necktie","neck",[40,10]) { a in
        a.poly([(35,6),(46,6),(43,14),(47,34),(40,40),(34,34),(37,14)],teal)
        a.poly([(42,15),(47,34),(40,40),(40,16)],color("286A70"))
        a.line(36,24,44,20,gold,2); a.line(35,32,45,27,color("86D9BD"),2)
        a.rect(37,8,6,2,color("86D9BD"))
    }
    item("cape","back",[40,20]) { a in
        a.poly([(23,12),(57,12),(66,35),(80,70),(63,74),(43,70),(22,75),(3,70),(15,38)],coral)
        a.poly([(23,16),(30,17),(19,68),(9,69)],color("FFB59A"))
        a.poly([(53,17),(59,21),(73,69),(63,71)],color("A54758"))
        a.poly([(37,27),(42,28),(42,68),(33,71)],color("A54758"))
        a.line(7,69,22,72,gold,2); a.line(23,72,42,68,gold,2); a.line(44,68,63,72,gold,2); a.line(64,72,77,69,gold,2)
        a.rect(24,12,32,4,gold)
    }
    item("backpack","back",[46,30]) { a in
        a.oval(7,12,68,55,teal); a.box(15,18,52,44,teal)
        a.box(29,6,26,9,woodDark); a.rect(34,9,16,6,.clear)
        a.box(6,36,13,26,woodLight); a.box(66,36,13,26,woodLight)
        a.box(14,18,56,16,teal); a.rect(18,20,44,2,color("86D9BD"))
        for x in [21,58] { a.rect(x,27,5,29,woodDark); a.box(x-1,37,7,7,gold) }
        a.box(28,42,26,19,teal); a.rect(30,45,22,2,gold)
        a.rect(8,41,7,2,paper); a.rect(69,41,7,2,paper)
    }
    item("jetpack","back",[40,29]) { a in
        a.box(22,21,38,24,steel)
        for x in [5,59] {
            a.oval(x,10,19,54,steel); a.oval(x+2,12,15,18,paper)
            a.box(x+2,28,15,22,steel); a.rect(x+4,30,3,16,color("778BA4"))
            a.box(x+2,49,15,7,orange); a.box(x+4,56,11,6,steel)
            a.poly([(x+4,62),(x+15,62),(x+13,72),(x+9,80),(x+5,71)],orange)
            a.poly([(x+7,62),(x+12,62),(x+9,73)],gold)
            a.rect(x+5,23,9,3,cyan)
        }
    }
    item("wings","back",[58,28]) { a in
        // Spread below raised forearms instead of following their silhouette.
        // The root stays on the back; each feather remains readable at 80 px.
        for right in [false,true] {
            func x(_ v:Int)->Int { right ? 116-v:v }
            a.poly([(x(58),28),(x(43),21),(x(21),15),(x(5),9),
                    (x(7),23),(x(12),34),(x(21),42),(x(34),47),
                    (x(47),42),(x(58),34)],color("A5B0CA"))
            a.poly([(x(55),28),(x(39),23),(x(20),17),(x(7),12),
                    (x(12),25),(x(29),31),(x(46),34)],paper)
            a.poly([(x(49),33),(x(31),28),(x(10),23),
                    (x(16),34),(x(32),39),(x(45),39)],color("D6DDEA"))
            a.poly([(x(46),39),(x(32),35),(x(18),33),
                    (x(24),41),(x(35),45)],paper)
            a.line(x(13),17,x(37),25,color("FFFFFF"),2)
            a.line(x(20),29,x(36),34,paper,2)
        }
        a.oval(51,24,15,16,gold)
    }
    item("mug","hand",[15,29]) { a in
        // Handle meets the raised fist; the cup sits outside the face silhouette.
        a.oval(9,18,14,18,steel); a.oval(11,20,10,14,paper); a.ellipse(13,23,5,8,.clear)
        a.box(19,15,23,26,teal); a.oval(19,12,23,8,paper); a.ellipse(22,14,17,4,woodDark)
        a.rect(22,21,3,14,color("86D9BD")); a.box(28,23,10,10,paper); a.star(30,25,orange)
        a.line(25,9,23,5,paper); a.line(33,9,35,4,paper)
    }
    item("trophy","hand",[40,46]) { a in
        a.oval(20,7,40,24,gold); a.ellipse(24,11,32,14,.clear)
        a.poly([(28,6),(53,6),(50,25),(41,32),(31,24)],gold)
        a.poly([(46,8),(51,8),(48,24),(42,28)],color("B67635"))
        a.rect(32,9,4,12,paper); a.rect(38,29,6,11,gold)
        a.box(28,40,26,9,woodDark); a.box(35,42,13,4,gold); a.rect(37,43,7,1,paper)
    }
    item("balloon","hand",[40,45]) { a in
        a.line(55,34,50,41,paper); a.line(50,41,40,45,paper)
        a.oval(40,2,32,36,coral); a.poly([(54,36),(51,41),(59,41)],coral)
        a.ellipse(45,7,8,15,color("FFB59A")); a.rect(47,8,3,6,paper)
        a.line(63,23,60,30,color("A54758"),2)
    }
    item("small-flag","hand",[40,47]) { a in
        a.box(39,5,4,46,woodLight)
        a.poly([(43,7),(60,7),(69,11),(64,20),(68,30),(53,26),(43,27)],teal)
        a.poly([(61,9),(69,11),(64,20),(68,30),(60,27)],color("286A70"))
        a.line(45,9,57,9,color("86D9BD")); a.star(49,14,gold)
        a.oval(37,2,8,7,gold)
    }
    try saveJSON(catalog,wardrobeDir.appendingPathComponent("wardrobe-sprites.json"))
    try makeColorways()
    print("Wardrobe: \(catalog.count) cropped 2-pixel sprites")
}
func makeColorways() throws {
    let ramps: [(String, String, [String], String, String)] = [
        ("classic", "Classic", ["505050","787878","AFAFAF","E8E8E8","FFFFFF"], "FF771A", "49EBFF"),
        ("midnight", "Midnight", ["19253D","2A3C5B","3F577C","567196","718BA9"], "F2C458", "74E7FF"),
        ("mint", "Mint", ["294C49","488378","7CB8A4","B4E3CC","E7FFF0"], "E69F63", "79E9FA"),
        ("sunset", "Sunset", ["58384B","97556A","D8898E","FFC0A2","FFE6CB"], "F58B45", "80E4ED"),
        ("gold", "Gold", ["58482D","947341","C8A15C","EDC879","FFF0BB"], "E08B40", "A2EEEC"),
        ("stealth", "Stealth", ["222329","36383F","4B4E58","626670","81858F"], "D85450", "FF534F")]
    func dark(_ hexValue: String) -> String {
        let p = color(hexValue)
        return hex(Pixel(r: p.r / 10, g: p.g / 10, b: p.b / 10, a: 255))
    }
    var output = [String: WardrobeColorway]()
    for (id, name, ramp, warm, glow) in ramps {
        var rules = [
            WardrobeColorRule(kind: "glow", hue: [160, 220], saturation: [0.12, 1], luminance: [0, 255], targets: [dark(glow), "#" + glow]),
            WardrobeColorRule(kind: "accents", hue: [0, 55], saturation: [0.16, 1], luminance: [0, 255], targets: [dark(warm), "#" + warm])
        ]
        let stops: [Double] = [80, 120, 175, 232, 255]
        for (index, kind) in ["joints", "grays", "shell", "highlights"].enumerated() {
            rules.append(.init(kind: kind, hue: [0, 360], saturation: [0, 0.55],
                               luminance: [stops[index], stops[index + 1]],
                               targets: ["#" + ramp[index], "#" + ramp[index + 1]]))
        }
        output[id] = WardrobeColorway(name: name, identity: id == "classic", rules: rules)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(output)
    try data.write(to: framesDir.appendingPathComponent("colorways.json"))
    print("Colorways: \(output.count), six rules each, \(data.count) bytes")
}
if CommandLine.arguments.last == "wardrobe" { try makeWardrobe() }
func makeHome() throws {
    try FileManager.default.createDirectory(at:homeDir,withIntermediateDirectories:true)
    var rooms=[String:Any](), items=[String:Any]()
    for id in ["cozy","studio","night"] {
        let night=id=="night", modern=id=="studio"
        var a=Art()
        let wall=night ? color("293850"):(modern ? color("D7DDD7"):color("D2B396"))
        a.rect(0,0,180,120,wall)
        if modern {
            a.rect(0,0,180,6,color("B7C6BE")); a.rect(8,8,2,79,color("C1CEC4"))
            a.rect(168,8,2,79,color("C1CEC4")); a.rect(9,80,160,2,color("B7C6BE"))
        } else {
            for y in stride(from:5,to:89,by:12) {
                a.rect(0,y,180,1,night ? color("202E45"):color("BE9A7A"))
                for x in stride(from:(y/12)%2*28+7,to:180,by:55) {
                    a.rect(x,y+1,1,10,night ? color("31435B"):color("E5CAB0"))
                    a.rect(x+16,y+5,8,1,night ? color("304058"):color("CAA586"))
                }
            }
            a.rect(0,0,7,91,night ? color("182A3E"):woodDark)
            a.rect(173,0,7,91,night ? color("182A3E"):woodDark)
            a.rect(0,0,180,5,night ? color("182A3E"):woodDark)
        }
        a.rect(0,90,180,30,night ? color("3E3F51"):color("A9816A"))
        a.rect(0,86,180,4,night ? color("1C2A3E"):woodDark)
        for y in stride(from:98,to:120,by:10) {
            a.rect(0,y,180,1,night ? color("2D3347"):color("87624F"))
            for x in stride(from:(y/10)%2*23,to:180,by:43) { a.rect(x,y-8,1,8,night ? color("34394C"):color("966D52")) }
        }
        // Fixed architectural round window, with a separate window-slot sill.
        a.oval(119,15,45,45,night ? color("17273D"):woodDark)
        a.ellipse(122,18,39,39,night ? color("111D39"):color("9CD4D9"))
        if night {
            for (x,y) in [(131,25),(150,24),(139,41),(153,39),(128,43)] { a.star(x,y,color("CFDAD4")) }
            a.ellipse(137,25,10,10,gold); a.ellipse(141,23,9,10,color("111D39"))
        } else {
            a.ellipse(144,23,8,8,color("FFF0BE")); a.rect(129,36,15,3,paper)
            a.poly([(124,47),(134,38),(144,48),(151,39),(158,48),(151,54),(132,54)],color("68AAA8"))
        }
        a.rect(140,18,2,39,night ? color("3F5365"):woodLight)
        a.rect(122,36,39,2,night ? color("3F5365"):woodLight)
        a.box(117,59,49,4,night ? color("455166"):woodLight)
        // Hanging practical light and restrained stepped light pool.
        a.line(88,5,88,14,night ? color("6F7480"):woodDark)
        a.poly([(82,13),(94,13),(99,20),(77,20)],night ? color("A58655"):gold)
        a.rect(81,20,14,2,night ? color("D5AF71"):color("FFE3A0"))
        if !modern { a.rect(29,7,1,77,night ? color("3A4559"):color("D7AC84")) }
        // Timber edges, skirting and broad reflected light, all on the art grid.
        a.rect(0,86,180,1,night ? color("52617A") : color("E8C6A0"))
        a.rect(0,90,180,3,night ? color("303449") : color("8D6550"))
        a.rect(7,5,2,80,night ? color("3B4D65") : color("E9C7A0"))
        a.rect(171,5,2,80,night ? color("152439") : color("A17353"))
        a.rect(7,5,164,2,night ? color("34465F") : color("E4BC94"))
        // Window joinery is thicker than distant scenery.
        a.line(122,59,162,59,night ? color("7B8394") : color("F5D7AA"))
        a.rect(118,63,47,2,night ? color("1D2C43") : color("A17F64"))
        if modern {
            a.rect(10,9,1,74,color("F1F0DF")); a.rect(168,9,1,74,color("B2C2B8"))
        }
        // Shallow side walls and converging floor seams establish room depth.
        let side = night ? color("202D43") : (modern ? color("BCCBC3") : color("AE896D"))
        a.poly([(0,0),(10,8),(10,86),(0,95)],side)
        a.poly([(170,8),(180,0),(180,95),(170,86)],side)
        a.line(10,8,10,86,night ? color("4A5A73") : color("F0D3AF"))
        a.line(170,8,170,86,night ? color("17273C") : color("8F715B"),2)
        a.line(0,95,10,86,night ? color("52617A") : color("E8C6A0"),2)
        a.line(170,86,179,95,night ? color("52617A") : color("E8C6A0"),2)
        for x in [28,66,108,150] {
            a.line(x,93,90+(x-90)*2,119,night ? color("2D3347") : color("886752"))
        }
        a.rect(10,88,160,2,night ? color("172539") : color("785740"))
        a.rect(10,90,160,2,night ? color("34384B") : color("B68B68"))
        var room=Bitmap(width:360,height:240)
        for y in 0..<120 { for x in 0..<180 { room.rect(x*2,y*2,2,2,a.b[x,y]) } }
        room.write(homeDir.appendingPathComponent("room-"+id+".png"))
        rooms[id]=["name":["cozy":"Cozy hut","studio":"Studio","night":"Night hut"][id]!,"file":"room-"+id+".png","floorY":180,
            "slots":["floorLeft":[42,224],"floorRight":[302,224],"wallLeft":[55,45],"wallRight":[210,69],"window":[282,120],"rug":[236,204],"desk":[142,158],"shelf":[132,90]],"mascotSpot":[240,224]]
    }
    func item(_ id:String,_ name:String,_ slot:String,_ pivot:[Int],_ draw:(inout Art)->Void) {
        var a=Art(); draw(&a); a.finishMaterials()
        let fit = id == "big-plant" ? 0.66 : (id == "string-lights" ? 0.70 : (slot == "desk" ? 0.84 : (slot == "rug" ? 1.0 : 0.76)))
        let original = a.b
        a.b = Bitmap(width:180,height:140)
        a.b.blit(original,0,0,width:Int(180*fit),height:Int(140*fit))
        let (sprite,p)=a.sprite(pivot:[Int(Double(pivot[0])*fit),Int(Double(pivot[1])*fit)])
        sprite.write(homeDir.appendingPathComponent(id+".png"))
        items[id]=["name":name,"file":id+".png","slot":slot,"pivot":p]
    }
    item("desk-monitor","Desk and monitor","desk",[40,42]) { a in
        a.worktable()
        a.box(23,12,44,26,steel); a.rect(26,15,38,19,color("22334B"))
        a.rect(27,16,36,2,color("3E5572")); a.rect(29,21,15,2,cyan)
        a.rect(29,26,25,1,color("88A7C1")); a.rect(29,29,18,1,color("88A7C1"))
        a.rect(42,38,5,4,steel); a.rect(37,41,16,2,steel)
        a.box(31,43,26,3,color("A5B0CA")); a.rect(34,43,20,1,paper)
        a.box(13,32,7,10,coral); a.rect(14,32,5,2,paper)
    }
    item("desk-lamp","Desk lamp and writing desk","desk",[40,42]) { a in
        a.worktable()
        a.oval(42,37,21,5,steel); a.line(52,36,58,24,steel,3); a.line(58,24,48,12,steel,3)
        a.line(53,33,59,24,color("778BA4")); a.oval(55,22,6,6,gold)
        a.poly([(38,8),(51,8),(55,18),(32,18)],teal); a.rect(35,18,17,3,gold)
        a.rect(37,18,12,1,paper); a.rect(38,10,10,2,color("86D9BD"))
        a.box(18,37,20,5,paper); a.rect(20,38,16,1,color("A5B0CA")); a.line(23,35,36,34,coral,2)
    }
    item("potted-plant","Potted plant","window",[39,42]) { a in
        a.line(39,31,39,12,woodDark,2)
        a.poly([(39,22),(31,12),(23,13),(26,21),(38,26)],teal)
        a.poly([(40,17),(46,5),(55,8),(51,17),(40,23)],teal)
        a.poly([(38,28),(27,22),(24,25),(29,31),(39,32)],teal)
        a.line(29,16,37,22,color("86D9BD")); a.line(49,10,42,19,color("86D9BD"))
        a.poly([(28,30),(51,30),(47,44),(32,44)],coral); a.box(27,29,25,5,woodLight)
        a.rect(34,35,3,7,color("FFB59A")); a.rect(31,31,16,1,color("F4D4A0"))
    }
    item("big-plant","Big plant","floorRight",[40,72]) { a in
        a.line(40,55,40,15,woodDark,3)
        for (x,y,flip) in [(21,18,false),(42,9,true),(18,35,false),(42,30,true)] {
            let dx=flip ? 1 : -1, origin=flip ? x : x+18
            a.poly([(origin,y+13),(origin+dx*20,y+4),(origin+dx*18,y-3),(origin+dx*7,y-1)],color("3C785F"))
            a.line(origin,y+10,origin+dx*15,y+1,color("8BBE78"))
        }
        a.oval(33,3,11,21,color("3C785F")); a.line(38,8,39,21,color("8BBE78"))
        a.poly([(26,52),(55,52),(51,73),(30,73)],woodLight); a.box(25,50,31,6,wood)
        a.rect(32,58,3,11,color("F4D4A0")); a.rect(46,58,3,11,wood)
        a.rect(28,52,24,1,color("F4D4A0"))
    }
    item("round-rug","Round rug","rug",[42,19]) { a in
        a.oval(3,4,79,31,color("286A70")); a.ellipse(6,6,73,27,woodLight)
        a.ellipse(9,8,67,23,teal); a.ellipse(13,10,59,19,color("286A70"))
        a.poly([(19,19),(42,11),(66,19),(42,27)],color("86D9BD"))
        a.poly([(28,19),(42,14),(57,19),(42,24)],teal)
        a.poly([(35,19),(42,16),(49,19),(42,22)],gold)
        for x in stride(from:13,through:71,by:6) { a.rect(x,32,2,2,woodLight) }
    }
    item("bookshelf","Bookshelf","shelf",[35,37]) { a in
        a.box(12,8,47,31,woodDark); a.rect(15,10,41,25,wood)
        a.rect(14,25,43,3,woodLight); a.rect(11,36,49,4,woodLight)
        for (x,h,p) in [(17,10,teal),(23,13,coral),(29,10,gold),(35,12,purple)] {
            a.box(x,25-h,5,h,p); a.rect(x+1,27-h,3,1,paper)
        }
        a.oval(46,14,7,9,teal); a.box(43,22,12,3,woodLight)
        for i in 0..<2 { a.box(18,32-i*3,16-i*2,3,[paper,teal][i]) }
        a.box(39,29,13,7,coral); a.rect(42,31,6,1,gold)
        a.rect(13,10,1,26,color("F4D4A0")); a.rect(15,37,41,1,color("F4D4A0"))
    }
    item("poster","Mountain poster","wallLeft",[27,24]) { a in
        a.box(11,6,33,36,woodDark); a.box(13,8,29,32,woodLight)
        a.rect(15,10,25,26,color("293D60")); a.ellipse(29,12,7,7,gold)
        a.poly([(15,34),(25,18),(35,34)],color("86D9BD")); a.poly([(22,24),(25,18),(29,24)],paper)
        a.poly([(25,34),(34,24),(40,34)],teal); a.rect(15,33,25,3,color("286A70"))
        a.rect(19,38,18,1,woodDark); a.rect(12,7,29,1,color("F4D4A0"))
    }
    item("wall-clock","Wall clock","wallRight",[26,23]) { a in
        a.oval(12,9,29,29,woodDark); a.oval(14,11,25,25,gold); a.ellipse(16,13,21,21,paper)
        for (x,y) in [(26,14),(26,30),(17,23),(33,23)] { a.rect(x,y,2,2,steel) }
        a.line(26,23,26,17,steel,2); a.line(26,23,31,26,steel,2); a.rect(25,22,3,3,coral)
        a.rect(18,12,8,1,color("FFF0B0"))
    }
    item("floor-lamp","Floor lamp","floorLeft",[27,76]) { a in
        a.oval(12,71,31,7,steel); a.rect(26,28,4,45,woodLight); a.rect(26,29,1,41,gold)
        a.poly([(16,9),(38,9),(45,31),(9,31)],gold)
        a.poly([(34,11),(38,11),(43,29),(34,29)],color("B67635"))
        a.rect(12,29,30,3,color("FFF0B0")); a.line(34,32,34,42,woodDark); a.oval(32,40,4,5,gold)
        a.line(20,12,17,26,color("FFF0B0")); a.rect(16,73,16,1,color("778BA4"))
    }
    item("bean-bag","Bean bag","floorRight",[35,43]) { a in
        a.poly([(7,34),(10,21),(24,10),(42,8),(55,19),(63,36),(53,46),(17,46)],purple)
        a.poly([(44,12),(55,21),(60,35),(51,41),(38,42),(45,32)],color("493C73"))
        a.ellipse(21,17,28,20,color("BCA0DC")); a.ellipse(24,21,24,14,purple)
        a.line(14,35,25,41,color("493C73"),2); a.line(25,41,43,41,color("493C73"),2)
        a.line(16,27,24,16,color("BCA0DC")); a.box(48,40,6,3,woodLight)
    }
    item("companion-bed","Companion bed","floorRight",[42,52]) { a in
        a.box(7,18,8,36,wood); a.box(69,31,7,24,wood)
        a.poly([(14,27),(60,27),(72,39),(24,39)],woodLight)
        a.poly([(15,29),(59,29),(69,39),(24,39)],paper)
        a.poly([(23,32),(57,32),(69,40),(25,40)],teal)
        a.box(23,39,47,10,teal); a.rect(25,40,43,2,color("86D9BD"))
        a.poly([(16,29),(28,29),(35,34),(21,34)],paper)
        a.line(24,46,68,46,gold,2)
        a.box(13,49,7,8,wood); a.box(65,49,7,8,wood)
        a.rect(8,19,4,30,woodLight); a.rect(70,32,3,20,woodLight)
    }
    item("coffee-machine","Coffee machine on stool","floorLeft",[31,61]) { a in
        a.box(12,36,38,5,woodLight); a.box(15,41,5,21,wood); a.box(42,41,5,21,wood)
        a.rect(20,53,22,3,woodDark); a.rect(14,37,33,1,color("F4D4A0"))
        a.box(16,10,31,26,steel); a.rect(19,13,25,7,coral); a.rect(21,22,21,11,ink)
        a.oval(34,14,5,5,gold); a.rect(22,15,8,2,paper)
        a.rect(30,20,4,6,color("A5B0CA")); a.box(27,27,10,7,paper)
        a.oval(36,28,5,5,paper); a.rect(37,29,2,2,ink)
        a.rect(23,34,19,2,color("778BA4")); a.rect(17,12,1,20,color("778BA4"))
    }
    item("cat-bed","Sleeping cat bed","floorLeft",[33,30]) { a in
        a.oval(13,15,41,21,woodDark); a.ellipse(15,17,37,16,coral); a.ellipse(18,19,31,11,color("A54758"))
        a.oval(25,11,24,18,woodLight); a.oval(17,13,18,14,woodLight)
        a.poly([(18,16),(18,7),(25,12),(31,8),(32,19)],woodLight)
        a.poly([(20,13),(20,10),(23,13)],coral); a.poly([(28,13),(30,11),(30,15)],coral)
        a.line(20,20,23,21,woodDark); a.line(27,21,30,20,woodDark); a.rect(24,23,2,1,coral)
        a.line(40,15,45,20,woodDark,2); a.line(44,23,36,26,woodDark,2); a.line(34,13,35,17,woodDark,2)
        a.line(19,29,34,31,color("FFB59A"),2)
    }
    item("guitar","Guitar on stand","floorRight",[28,64]) { a in
        a.line(28,43,28,62,steel,2); a.line(28,57,15,64,steel,2); a.line(28,57,42,64,steel,2)
        a.oval(14,36,29,26,woodDark); a.oval(16,37,25,23,woodLight); a.oval(20,27,19,23,woodLight)
        a.box(26,9,7,29,woodDark); a.box(24,4,11,10,woodLight)
        a.oval(24,37,10,11,woodDark); a.rect(24,53,11,3,woodDark)
        a.line(28,11,28,54,gold); a.line(31,11,31,54,gold)
        for y in [7,11] { a.rect(22,y,3,2,steel); a.rect(35,y,3,2,steel) }
        for y in [18,23,28] { a.rect(27,y,5,1,color("A5B0CA")) }
        a.rect(19,43,2,8,color("F4D4A0"))
    }
    item("record-player","Record player and console","desk",[40,42]) { a in
        a.worktable()
        a.box(17,18,48,16,woodDark); a.rect(20,21,42,11,color("286A70"))
        a.box(17,33,48,9,wood); a.rect(19,34,44,5,woodLight)
        a.oval(22,32,25,8,ink); a.ellipse(30,34,9,4,coral); a.rect(33,35,2,1,gold)
        a.line(57,34,57,37,steel,2); a.line(57,37,45,39,steel)
        a.rect(58,39,3,2,teal); a.rect(20,20,39,1,color("86D9BD"))
    }
    item("certificate","Framed certificate","wallRight",[30,22]) { a in
        a.box(9,8,43,29,woodDark); a.box(11,10,39,25,gold); a.rect(14,13,33,19,paper)
        a.rect(20,16,21,2,steel); a.rect(18,21,25,1,color("778BA4")); a.rect(21,24,19,1,color("778BA4"))
        a.oval(27,26,7,6,gold); a.poly([(28,30),(30,30),(28,35)],coral); a.poly([(31,30),(33,30),(33,35)],coral)
        a.rect(12,11,35,1,color("FFF0B0"))
    }
    item("string-lights","String lights","wallLeft",[30,14]) { a in
        a.line(5,5,19,11,woodDark); a.line(19,11,41,11,woodDark); a.line(41,11,55,5,woodDark)
        for (i,x) in [9,19,30,41,51].enumerated() {
            let y=(x<15 || x>45) ? 9:14
            a.rect(x,y-3,1,4,steel); a.oval(x-3,y,7,9,i%2==0 ? gold:coral)
            a.rect(x-1,y+2,2,4,paper)
        }
    }
    try saveJSON(["rooms":rooms,"items":items],homeDir.appendingPathComponent("home-items.json"))
    print("Home: \(rooms.count) rooms, \(items.count) furniture sprites")
}
if CommandLine.arguments.last == "home" { try makeHome() }
func makePreview() throws {
    let anchors=try json(framesDir.appendingPathComponent("mascot-anchors.json")).merging(json(framesDir.appendingPathComponent("fixed-pose-anchors.json"))) { original, _ in original }
    let wardrobe=try json(wardrobeDir.appendingPathComponent("wardrobe-sprites.json"))
    let colorways = try JSONDecoder().decode([String: WardrobeColorway].self, from: Data(contentsOf: framesDir.appendingPathComponent("colorways.json")))
    let home=try json(homeDir.appendingPathComponent("home-items.json"))
    let rooms=home["rooms"] as! [String:[String:Any]], furniture=home["items"] as! [String:[String:Any]]
    let clips=try json(framesDir.appendingPathComponent("mascot-clips.json"))
    let hello=(clips["hello"] as! [String:Any])["rest"] as! String
    let typing=(clips["working"] as! [String:Any])["rest"] as! String
    func recolored(_ b:Bitmap,_ id:String)->Bitmap {
        var out = b
        WardrobePalette.recolor(&out.bytes, colorway: colorways[id]!)
        return out
    }
    func dressed(_ frame:String,_ ids:[String],_ way:String="classic")->Bitmap {
        let anchor=anchors[frame] as! [String:Any]
        let sourceURL = frame.hasPrefix("pose")
            ? root.appendingPathComponent("Clockin/Assets.xcassets/"+frame+".imageset/"+frame+".png")
            : framesDir.appendingPathComponent(frame+".png")
        var normalized = Bitmap(width:314,height:314)
        normalized.blit(Bitmap(url:sourceURL),0,0,width:314,height:314)
        let original=recolored(normalized,way)
        var out=Bitmap(width:314,height:314)
        func overlay(_ id:String) {
            let entry=wardrobe[id] as! [String:Any], key=entry["anchorPoint"] as! String
            guard var point=anchor[key] as? [Int] else { return }
            let fits = entry["poseOffsets"] as? [String: [Int]] ?? [:]
            let offset = fits[frame] ?? fits[String(frame.prefix(1))] ?? [0, 0]
            point[0] += offset[0]; point[1] += offset[1]
            let sprite=Bitmap(url:wardrobeDir.appendingPathComponent(id+".png")), pivot=entry["pivot"] as! [Int]
            let slot=entry["slot"] as! String
            let theta=(slot=="head" || slot=="face") ? (anchor["tilt"] as! Double)*Double.pi/180:0
            if theta==0 { out.blit(sprite,point[0]-pivot[0],point[1]-pivot[1]); return }
            var layer=Bitmap(width:314,height:314)
            for y in 0..<314 { for x in 0..<314 {
                let dx=Double(x-point[0]),dy=Double(y-point[1])
                let sx=Int((cos(theta)*dx+sin(theta)*dy+Double(pivot[0])).rounded())
                let sy=Int((-sin(theta)*dx+cos(theta)*dy+Double(pivot[1])).rounded())
                if sx>=0 && sy>=0 && sx<sprite.width && sy<sprite.height { layer[x,y]=sprite[sx,sy] }
            } }
            out.blit(layer,0,0)
        }
        for id in ids where (wardrobe[id] as! [String:Any])["layer"] as! String=="back" { overlay(id) }
        out.blit(original,0,0)
        for id in ids where (wardrobe[id] as! [String:Any])["layer"] as! String=="front" { overlay(id) }
        return out
    }
    var sheet=Bitmap(width:1440,height:2800,fill:color("252C37"))
    label("COMPANION / WARDROBE AND HOME",&sheet,28,24,3)
    label("PIVOT ON ANCHOR / BACK THEN ROBOT THEN FRONT / NEAREST NEIGHBOR",&sheet,28,51)
    let outfit=["beanie","round-glasses","scarf","wings","mug"]
    for (i,id) in [hello,typing,"e01"].enumerated() {
        let x=28+i*466, b=dressed(id,outfit)
        label(id+" / FIVE SLOTS",&sheet,x,85)
        sheet.blit(b,x+4,105)
        sheet.blit(b,x+314,136,width:124,height:124)
        label("62 PT 2X",&sheet,x+314,270,1)
        sheet.blit(b,x+343,297,width:62,height:62)
        label("62 PX",&sheet,x+328,371,1)
    }
    label("25 WARDROBE SPRITES / NATIVE IMAGE PIXELS",&sheet,28,438)
    let order=["cap","beanie","party-hat","crown","wizard-hat","chef-hat","cowboy-hat","headphones","round-glasses","sunglasses","pixel-shades","monocle","scarf","bow-tie","gold-medal","necktie","cape","backpack","jetpack","wings","mug","trophy","balloon","small-flag","antenna"]
    for (i,id) in order.enumerated() {
        let x=24+i%6*236,y=468+i/6*176
        sheet.rect(x,y,220,160,color("303A47"))
        let b=Bitmap(url:wardrobeDir.appendingPathComponent(id+".png"))
        sheet.blit(b,x+(220-b.width)/2,y+6+(132-b.height)/2)
        label(id,&sheet,x+10,y+145,1)
    }
    label("SIX COLORWAYS / SHADING RULES",&sheet,28,1372)
    for (i,id) in ["classic","midnight","mint","sunset","gold","stealth"].enumerated() {
        let x=24+i*236,b=recolored(Bitmap(url:framesDir.appendingPathComponent(hello+".png")),id)
        sheet.blit(b,x+10,1406,width:206,height:206)
        label(id,&sheet,x+15,1626)
    }
    label("HOME / 340 PX WIDE / FEET ON MASCOT SPOT",&sheet,28,1666)
    let sets=[
        ["round-rug","poster","wall-clock","bookshelf","desk-monitor","potted-plant","big-plant","cat-bed"],
        ["round-rug","certificate","string-lights","bookshelf","desk-lamp","potted-plant","guitar","coffee-machine"],
        ["round-rug","string-lights","certificate","bookshelf","potted-plant","bean-bag","floor-lamp","record-player"]]
    for (i,id) in ["cozy","studio","night"].enumerated() {
        let room=rooms[id]!, slots=room["slots"] as! [String:[Int]], spot=room["mascotSpot"] as! [Int]
        var scene=Bitmap(url:homeDir.appendingPathComponent(room["file"] as! String))
        for itemID in sets[i] {
            let item=furniture[itemID]!,p=item["pivot"] as! [Int], xy=slots[item["slot"] as! String]!
            scene.blit(Bitmap(url:homeDir.appendingPathComponent(item["file"] as! String)),xy[0]-p[0],xy[1]-p[1])
        }
        let b=dressed(hello,["beanie","scarf"],i==2 ? "midnight":"classic")
        // Match CompanionHomeView's centered canvas and the mood's feet anchor.
        let helloFeet = 0.89 // MascotMood.hello.feet
        scene.blit(b,spot[0]-68,spot[1]-Int(136*helloFeet),width:136,height:136)
        let x=60+i*466
        label(id,&sheet,x,1706)
        sheet.blit(scene,x,1731,width:340,height:227)
        scene.write(URL(fileURLWithPath:"/tmp/clockin-home-"+id+".png"))
    }
    label("17 FURNITURE SPRITES / NATIVE IMAGE PIXELS",&sheet,28,2006)
    for (i,id) in furniture.keys.sorted().enumerated() {
        let x=24+i%8*177,y=2040+i/8*225,b=Bitmap(url:homeDir.appendingPathComponent(id+".png"))
        sheet.rect(x,y,165,208,color("303A47")); sheet.blit(b,x+(165-b.width)/2,y+18+(160-b.height)/2)
        label(id,&sheet,x+5,y+192,1)
    }
    label("SOURCE CANVAS 314 X 314 / ART CELL 2 X 2 / ROOMS 360 X 240",&sheet,28,2760)
    sheet.write(URL(fileURLWithPath:"/tmp/clockin-wardrobe-preview.png"))
    // Compact review board, from the same sprites, anchors and room manifests.
    var board = Bitmap(width: 960, height: 600, fill: color("252C37"))
    label("COMPANION / PIXEL ART POLISH", &board, 24, 22, 3)
    let looks = [["cap","scarf","mug"], ["crown","bow-tie","cape"],
                 ["headphones","wings"], ["wizard-hat","backpack"]]
    for (i, look) in looks.enumerated() {
        board.rect(16+i*236,62,224,248,color("303A47"))
        board.blit(dressed(hello,look),16+i*236,65,width:224,height:224)
        label(["DAILY","ROYAL","EXPLORER","WIZARD"][i], &board, 36+i*236,288)
    }
    for (i,id) in ["cozy","studio","night"].enumerated() {
        board.blit(Bitmap(url:URL(fileURLWithPath:"/tmp/clockin-home-"+id+".png")),
                   16+i*316,346,width:296,height:198)
        label(id, &board, 24+i*316,558)
    }
    board.write(URL(fileURLWithPath:"/tmp/clockin-companion-polish.png"))
    let homeExamples = [
        ("cozy-idle-deskLeft", "AT HOME"), ("cozy-working-deskLeft", "AT THE DESK"),
        ("studio-relaxing-deskRight", "BREAK / DESK RIGHT"), ("night-sleeping-deskRight", "REST / DESK RIGHT")]
    if homeExamples.allSatisfy({ FileManager.default.fileExists(atPath:"/tmp/clockin-home-"+$0.0+".png") }) {
        var homeBoard=Bitmap(width:1024,height:790,fill:color("252C37"))
        label("COMPANION HOME / ROOM AND ACTIVITY REVIEW",&homeBoard,24,22,2)
        for (i,example) in homeExamples.enumerated() {
            let x=24+(i%2)*500, y=64+(i/2)*360
            homeBoard.blit(Bitmap(url:URL(fileURLWithPath:"/tmp/clockin-home-"+example.0+".png")),x,y,width:476,height:317)
            label(example.1,&homeBoard,x,y+328,2)
        }
        homeBoard.write(URL(fileURLWithPath:"/tmp/clockin-home-development.png"))
    }

    let proportionBaseline = root.appendingPathComponent("docs/art-review/companion-polish/proportions-before.png")
    if FileManager.default.fileExists(atPath: proportionBaseline.path) {
        let before = Bitmap(url: proportionBaseline)
        var comparison = Bitmap(width:960,height:644,fill:color("252C37"))
        label("BEFORE / ACCESSORY PROPORTIONS", &comparison, 24, 14)
        label("AFTER / FITTED TO THE COMPANION", &comparison, 24, 336)
        for y in 0..<260 { for x in 0..<960 {
            comparison[x,44+y] = before[x,54+y]
            comparison[x,366+y] = board[x,54+y]
        } }
        comparison.write(URL(fileURLWithPath:"/tmp/clockin-proportions-comparison.png"))
    }

    var surfaces=Bitmap(width:1100,height:820,fill:color("252C37"))
    label("COMPANION / REAL DISPLAY SIZES / STATIC ART REVIEW", &surfaces, 20, 20)
    for (row,frame) in [hello,"t01","pose2","pose3","pose4"].enumerated() {
        let y=65+row*148
        label(frame,&surfaces,16,y+16)
        let sizes=[48,62,64,72,80,120]
        var x=136
        for side in sizes {
            surfaces.rect(x,y,side,side,color("394453"))
            surfaces.blit(dressed(frame,["beanie","scarf","mug"]),x,y,width:side,height:side)
            label(String(side),&surfaces,x,y+side+8,1)
            x += side+32
        }
    }
    surfaces.write(URL(fileURLWithPath:"/tmp/clockin-companion-surfaces.png"))


    let baseline = URL(fileURLWithPath: "/tmp/clockin-wardrobe-preview-before.png")
    if FileManager.default.fileExists(atPath: baseline.path) {
        let before = Bitmap(url: baseline)
        var comparison = Bitmap(width: 1440, height: 540, fill: color("252C37"))
        for (i, id) in ["classic","midnight","mint","sunset","gold","stealth"].enumerated() {
            let left = (i % 3) * 480, top = (i / 3) * 270
            label(id, &comparison, left + 16, top + 8)
            label("BEFORE", &comparison, left + 20, top + 34)
            label("RULES", &comparison, left + 250, top + 34)
            for y in 0..<206 { for x in 0..<206 {
                comparison[left + 12 + x, top + 58 + y] = before[34 + i * 236 + x, 1230 + y]
                comparison[left + 246 + x, top + 58 + y] = sheet[34 + i * 236 + x, 1406 + y]
            } }
        }
        comparison.write(URL(fileURLWithPath: "/tmp/clockin-colorways-comparison.png"))
    }
    // Every sprite is additionally tried on both required poses, avoiding a
    // showcase outfit that hides a poorly fitting individual item.
    var fit=Bitmap(width:1440,height:order.count*174,fill:color("252C37"))
    for (i,id) in order.enumerated() {
        label(id,&fit,12,i*174+12)
        for (j,frame) in [hello,typing,"c07","e01"].enumerated() {
            let b=dressed(frame,[id])
            fit.blit(b,250+j*290,i*174,width:174,height:174)
            fit.blit(b,430+j*290,i*174+50,width:62,height:62)
        }
    }
    fit.write(URL(fileURLWithPath:"/tmp/clockin-wardrobe-fit.png"))
    for page in 0..<5 {
        var detail=Bitmap(width:1440,height:min(1044,fit.height-page*1044))
        for y in 0..<detail.height { for x in 0..<1440 { if page*1044+y < fit.height { detail[x,y]=fit[x,page*1044+y] } } }
        detail.write(URL(fileURLWithPath:"/tmp/clockin-wardrobe-fit-\(page+1).png"))
    }
    print("Preview: /tmp/clockin-wardrobe-preview.png; all-item pose checks: /tmp/clockin-wardrobe-fit.png")
}
if CommandLine.arguments.last == "preview" { try makePreview() }

if CommandLine.arguments.last == "fixed-anchors" {
    var fixed = [String: Any]()
    for id in ["pose2", "pose3", "pose4"] {
        let url = root.appendingPathComponent("Clockin/Assets.xcassets/" + id + ".imageset/" + id + ".png")
        var normalized = Bitmap(width:314, height:314)
        normalized.blit(Bitmap(url:url), 0, 0, width:314, height:314)
        let geometry = Geometry(normalized, id:id, diagnostics:true)
        var anchors = geometry.anchors
        // Both hands are occupied by the overhead stretch.
        if id == "pose2" { anchors.handL = nil; anchors.handR = nil }
        fixed[id] = anchors.object
    }
    try saveJSON(fixed, framesDir.appendingPathComponent("fixed-pose-anchors.json"))
}
