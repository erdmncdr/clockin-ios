import AppKit
import CoreGraphics
import ImageIO

// Run from website/: swiftc -O tools/optimize-images/main.swift -o /tmp/clockin-optimize
// /tmp/clockin-optimize [--output-root /tmp/clockin-preview]
// --png-only produces just the seven PNG assets when AVIF is unavailable.
// Outputs are immutable: reruns validate existing files using their manifest.
// New images are staged in memory until all encoding and verification succeed.
let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let args = CommandLine.arguments
let pngOnly = args.contains("--png-only")
let output = args.firstIndex(of: "--output-root").map { URL(fileURLWithPath: args[$0 + 1]) } ?? root
let assets = "dist/assets/"
var sourceSnapshot: [String: Data] = [:]
func fail(_ s: String) -> Never {
    if !sourceSnapshot.isEmpty {
        let unchanged = sourceSnapshot.allSatisfy { (try? Data(contentsOf: root.appendingPathComponent($0.key))) == $0.value }
        fputs("Original byte verification on failure: \(unchanged ? "UNCHANGED" : "CHANGED")\n", stderr)
    }
    fputs("ERROR: \(s)\n", stderr); exit(1) }
func read(_ u: URL) -> Data { do { return try Data(contentsOf: u) } catch { fail("\(u.path): \(error)") } }
func checksum(_ d: Data) -> String { var h: UInt64 = 14695981039346656037; for b in d { h = (h ^ UInt64(b)) &* 1099511628211 }; return String(format: "%016llx", h) }
func decode(_ d: Data) -> CGImage { guard let s = CGImageSourceCreateWithData(d as CFData, nil), let im = CGImageSourceCreateImageAtIndex(s, 0, nil) else { fail("ImageIO decode failed") }; return im }
let color = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
func context(_ w: Int, _ h: Int) -> CGContext { guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: color, bitmapInfo: info) else { fail("context") }; return c }
// Heights are rounded to an even number: Chrome decoded the opaque 720 w and
// 1080 w screenshots (1239 and 1859 px tall) as fully transparent AVIFs.
func scaled(_ im: CGImage, _ w: Int) -> CGImage { let exact = Double(im.height) * Double(w) / Double(im.width); let h = Int((exact / 2).rounded()) * 2; let c = context(w,h); c.interpolationQuality = .high; c.draw(im, in: CGRect(x: 0,y: 0,width: w,height: h)); return c.makeImage()! }
func pixels(_ im: CGImage) -> [UInt8] { let c = context(im.width,im.height); c.draw(im, in: CGRect(x: 0,y: 0,width: im.width,height: im.height)); return Array(UnsafeBufferPointer(start: c.data!.assumingMemoryBound(to: UInt8.self), count: im.width * im.height * 4)) }
struct Errors: Codable { let opaqueRGBMean: Double; let opaqueChannelP999: Int; let alphaMean: Double; let opaquePixels: Int; var passes: Bool { opaqueRGBMean <= 1.5 && opaqueChannelP999 <= 24 && alphaMean <= 1 }
    // ImageIO's AVIF encoder subsamples chroma, so the hard cyan/orange edges of
    // the pixel art keep a 99.9th-percentile error near 73 at any quality. Side
    // by side at 5x (Claude, 2026-09-15) q 0.9+ was indistinguishable from the
    // PNG at display size, so sprites use a looser gate and a high fixed quality.
    // Half-size frames (shown at 150 CSS px) sit at a mean of 3-5 for the same reason.
    var passesSprite: Bool { opaqueRGBMean <= 6.0 && opaqueChannelP999 <= 100 && alphaMean <= 1 } }
func errors(_ a: [UInt8], _ b: [UInt8]) -> Errors { precondition(a.count == b.count); var hist = [Int](repeating: 0,count: 256); var sum = 0; var alpha = 0; var n = 0
    for i in stride(from: 0,to: a.count,by: 4) { alpha += abs(Int(a[i+3])-Int(b[i+3])); if a[i+3] == 255 { n += 1; for ch in 0..<3 { let decoded = b[i+3] == 0 ? 0 : min(255, Int((Double(b[i+ch]) * 255 / Double(b[i+3])).rounded())); let e = abs(Int(a[i+ch])-decoded); hist[e] += 1; sum += e } } }
    let target = Int(ceil(Double(n * 3) * 0.999)); var acc = 0; var p = 0; for i in 0..<256 { acc += hist[i]; if acc >= target { p = i; break } }
    return Errors(opaqueRGBMean: n == 0 ? 0 : Double(sum)/Double(n*3),opaqueChannelP999: p,alphaMean: Double(alpha)/Double(a.count/4),opaquePixels: n)
}
func encode(_ im: CGImage, _ avif: Bool, _ q: Double?) -> Data { let d = NSMutableData(); guard let dest = CGImageDestinationCreateWithData(d,avif ? "public.avif" as CFString : "public.png" as CFString,1,nil) else { fail("encoder unavailable") }; var props: [CFString: Any] = [:]; if let q { props[kCGImageDestinationLossyCompressionQuality] = q }; CGImageDestinationAddImage(dest,im,props as CFDictionary); guard CGImageDestinationFinalize(dest) else { fail("encode failed at \(String(describing: q))") }; return d as Data }
var pending: [String: Data] = [:]
func generatedData(_ path: String) -> Data { pending[path] ?? read(output.appendingPathComponent(path)) }
func addOnly(_ data: Data, _ path: String) { let u = output.appendingPathComponent(path); do { try fm.createDirectory(at: u.deletingLastPathComponent(),withIntermediateDirectories: true); if fm.fileExists(atPath: u.path) { guard read(u) == data else { fail("Refusing to overwrite \(path)") } } else { pending[path] = data } } catch { fail("write \(path): \(error)") } }
struct Entry: Codable { let file: String; let source: String; let width: Int; let height: Int; let bytes: Int; let quality: Double?; let errors: Errors; let group: String; let hasTransparency: Bool; let thresholdsRequired: Bool }
struct Summary: Codable { let originalPNGBytes: Int; let replacementAVIFBytes: Int; let savedBytes: Int; let savedPercent: Double; let allGeneratedAssetBytes: Int; let replacementPolicy: String }
struct Manifest: Codable { let schemaVersion: Int; let status: String?; let metric: String; let files: [Entry]; let summary: Summary; let originalChecksumsFNV1a64: [String: String] }
let manifestPath = assets + "image-manifest.json"
let oldManifest = fm.fileExists(atPath: output.appendingPathComponent(manifestPath).path) ? try? JSONDecoder().decode(Manifest.self,from: read(output.appendingPathComponent(manifestPath))) : nil
let companion = root.appendingPathComponent(assets + "companion")
let spritePaths = ([assets + "mascot-hello.png",assets + "mascot-coffee.png"] + (fm.enumerator(at: companion,includingPropertiesForKeys: nil)!.allObjects as! [URL]).filter { $0.pathExtension == "png" }.map { String($0.path.dropFirst(root.path.count+1)) }).sorted()
let screenshotPaths = ["timer","history","progress"].map { assets + "app-\($0)-large.png" }
let sources = [assets + "clockin-icon.png"] + screenshotPaths + spritePaths
let originals = Dictionary(uniqueKeysWithValues: sources.map { ($0,read(root.appendingPathComponent($0))) })
sourceSnapshot = originals
let hashes = originals.mapValues(checksum)
var entries: [Entry] = []
func generate(_ src: String, _ dst: String, _ width: Int?, _ group: String, _ qualities: [Double]) {
    let original = decode(originals[src]!); let reference = width.map { scaled(original,$0) } ?? original; let a = pixels(reference); let alpha = stride(from: 3,to: a.count,by: 4).contains { a[$0] < 255 }; let avif = dst.hasSuffix(".avif"); let strict = group.hasPrefix("mascot")
    var chosen: Data?; var chosenQ: Double?; var measured: Errors?
    let existing = output.appendingPathComponent(dst)
    if fm.fileExists(atPath: existing.path) { guard let prior = oldManifest?.files.first(where: { $0.file == dst && $0.source == src }), oldManifest?.originalChecksumsFNV1a64[src] == hashes[src] else { fail("Existing output without matching provenance: \(dst)") }; chosen = read(existing); chosenQ = prior.quality }
    else if avif { for q in qualities { let d = encode(reference,true,q); let im = decode(d); guard im.width == reference.width && im.height == reference.height else { fail("AVIF dimensions \(dst)") }; let e = errors(a,pixels(im)); if !strict || e.passesSprite { chosen = d; chosenQ = q; measured = e; break }; print("RETRY \(dst) q=\(q) mean=\(e.opaqueRGBMean) p999=\(e.opaqueChannelP999) alpha=\(e.alphaMean)") } }
    else { chosen = encode(reference,false,nil) }
    guard let d = chosen else { fail("No requested quality meets thresholds for \(dst)") }
    let decoded = decode(d); guard decoded.width == reference.width && decoded.height == reference.height else { fail("Wrong dimensions: \(dst)") }; let b = pixels(decoded); let e = measured ?? errors(a,b)
    let hasAlphaChannel = [CGImageAlphaInfo.first,.last,.premultipliedFirst,.premultipliedLast,.alphaOnly].contains(decoded.alphaInfo)
    if alpha && (!hasAlphaChannel || !stride(from: 3,to: b.count,by: 4).contains(where: { b[$0] < 255 })) { fail("Lost alpha: \(dst)") }
    if strict && !e.passesSprite { fail("Threshold failure \(dst)") }
    addOnly(d,dst); entries.append(Entry(file: dst,source: src,width: decoded.width,height: decoded.height,bytes: d.count,quality: chosenQ,errors: e,group: group,hasTransparency: alpha,thresholdsRequired: strict))
    print("PASS \(dst) \(d.count) bytes q=\(chosenQ ?? 0) RGB=\(String(format: "%.4f", e.opaqueRGBMean)) p999=\(e.opaqueChannelP999) alpha=\(String(format: "%.4f",e.alphaMean))")
}
for (name,w) in [("clockin-icon-64.png",64),("clockin-icon-96.png",96),("favicon-32.png",32),("apple-touch-icon.png",180)] { generate(assets+"clockin-icon.png",assets+name,w,"icon",[]) }
for src in screenshotPaths { let base = src.replacingOccurrences(of: "-large.png",with: ""); generate(src,base+"-720.png",720,"screenshot-fallback",[]) }
if !pngOnly {
for src in screenshotPaths { let base = src.replacingOccurrences(of: "-large.png",with: ""); for w in [480,720,1080] { generate(src,"\(base)-\(w).avif",w,"screenshot",[0.82]) } }
for src in spritePaths { let base = String(src.dropLast(4)); generate(src,base+".avif",nil,"mascot-full",[0.94]); if src.contains("/typing/") || src.contains("/coffee-loop/") || src.contains("/celebrate-loop/") || src.hasSuffix("mascot-coffee.png") { generate(src,base+"-314.avif",314,"mascot-half",[0.95]) } }
// Human QA: nearest-neighbor 2x crops, composited on light gray to expose halos.
let sheet = context(1000,1160)
sheet.setFillColor(CGColor(gray: 0.88,alpha: 1)); sheet.fill(CGRect(x: 0,y: 0,width: 1000,height: 1160))
func label(_ s: String, _ x: CGFloat, _ y: CGFloat) { NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet,flipped: false); (s as NSString).draw(at: NSPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize: 15),.foregroundColor:NSColor.black]); NSGraphicsContext.restoreGraphicsState() }
func crop(_ im: CGImage, _ r: CGRect, _ x: Int, _ y: Int) { guard let c = im.cropping(to:r) else { fail("crop") }; sheet.interpolationQuality = .none; sheet.draw(c,in:CGRect(x:x,y:y,width:c.width*2,height:c.height*2)) }
label("2x antenna / eye crops | PNG left, AVIF right in each pair",20,1130)
for (row,src) in [assets+"companion/frame1.png",assets+"mascot-hello.png",assets+"companion/celebrate-loop/e01.png"].enumerated() { let a = decode(originals[src]!); let b = decode(generatedData(String(src.dropLast(4))+".avif")); let y = 855-row*270; label(src,20,CGFloat(y+240)); for (col,r) in [CGRect(x:200,y:80,width:100,height:110),CGRect(x:240,y:220,width:100,height:110)].enumerated() { crop(a,r,20+col*490,y); crop(b,r,240+col*490,y) } }
let screen = screenshotPaths[0]; let a = scaled(decode(originals[screen]!),720); let b = decode(generatedData(assets+"app-timer-720.avif"))
label("Timer text at 720w: scaled original (left), AVIF q0.82 (right), 2x",20,300)
let rect = CGRect(x:80,y:520,width:230,height:130); crop(a,rect,20,25); crop(b,rect,510,25)
addOnly(encode(sheet.makeImage()!,false,nil),"tools/optimize-images/compare.png")
}
for src in sources { let now = read(root.appendingPathComponent(src)); guard checksum(now) == hashes[src] && now == originals[src] else { fail("Original modified: \(src)") } }
let replacing = entries.filter { $0.group == "mascot-full" || ($0.group == "screenshot" && $0.width == 720) }
let before = Set(replacing.map(\.source)).reduce(0) { $0 + originals[$1]!.count }; let after = replacing.reduce(0) { $0 + $1.bytes }
let summary = Summary(originalPNGBytes:before,replacementAVIFBytes:after,savedBytes:before-after,savedPercent:before == 0 ? 0 : 100*Double(before-after)/Double(before),allGeneratedAssetBytes:entries.reduce(0){$0+$1.bytes},replacementPolicy:"One full-size AVIF per mascot PNG plus one 720w AVIF per screenshot. Excludes icon, half-size alternatives, other screenshot widths and PNG fallbacks; originals remain on disk.")
let manifest = Manifest(schemaVersion:1,status:pngOnly ? "partial-png-only; AVIF and contact sheet not generated or verified" : "complete",metric:"sRGB 8-bit straight RGB, source alpha == 255; pooled per-channel nearest-rank 99.9 percentile; alpha MAE across all pixels. Resized images compared against high-quality scaled source. PNG quality is null. Mascot thresholds: RGB MAE <=1.5, p999 <=24, alpha MAE <=1. Screenshot errors informational.",files:entries,summary:summary,originalChecksumsFNV1a64:hashes)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]; try! fm.createDirectory(at: output.appendingPathComponent(assets),withIntermediateDirectories:true)
for path in pending.keys.sorted() { let u = output.appendingPathComponent(path); try! fm.createDirectory(at:u.deletingLastPathComponent(),withIntermediateDirectories:true); try! pending[path]!.write(to:u,options:.withoutOverwriting) }
try! encoder.encode(manifest).write(to:output.appendingPathComponent(manifestPath),options:.atomic)
print("VERIFIED: \(entries.count) assets; \(entries.filter { $0.file.hasSuffix(".avif") }.count) AVIF dimensions and transparency; \(entries.filter { $0.thresholdsRequired }.count) mascot thresholds; \(sources.count) original checksums AND bytes unchanged.")
if pngOnly { print("PARTIAL PNG-ONLY RUN: AVIF encoding, quality search, savings and contact sheet have NOT been verified.") }
print("REPLACEMENT TOTAL: \(before) -> \(after) bytes; saved \(before-after) (\(String(format:"%.2f",summary.savedPercent))%). All variant assets: \(summary.allGeneratedAssetBytes) bytes.")
