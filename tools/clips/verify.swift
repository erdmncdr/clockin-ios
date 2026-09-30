#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO

// Run from website/: swift tools/clips/verify.swift [optional-manifest-path]
// Coordinates and alpha > 32 match the generators' bottom-edge convention.
// Exact equality is intentional: typing's source-pose 536/537 variation is
// reported as a failure, not silently treated as a hop or given a tolerance.
// Event semantics from the generators:
// hello h06 = dip + pulse 1; h07 = pulse 2; h08 = pulse 1; h11 = blink + dip.
// celebrate e02 = hip +6 + dip; e07/e08/e09 = hip -6 / +blink / +blink+dip;
// e15 = pulse -1. Positive pulses exist ONLY in hop frames and are omitted.
// coffee c03 = steam 12 + dip; c04 = blink + dip; c08/c11 = drink/smile + dip.
// working t02/t04 (duplicates t10/t12) brighten the pressed key, not the core;
// t03/t07/t14 dip in source poses 2/4/1; t09 = blink + dip in source pose 1.
// Coffee's base is a quiet sitting hold; the drinking action is scheduled apart.
// Event clips explicitly enter from rest at 0 ms and return to rest at 0 ms.
// Base clips close explicitly onto their first frame at 0 ms (no extra hold).

struct Frame: Decodable, Equatable {
    let file: String
    let ms: Int
    init(from decoder: Decoder) throws {
        var pair = try decoder.unkeyedContainer()
        file = try pair.decode(String.self)
        ms = try pair.decode(Int.self)
        guard pair.isAtEnd else {
            throw DecodingError.dataCorruptedError(in: pair, debugDescription: "Expected [frame, ms]")
        }
    }
}
struct Animation: Decodable {
    let folder: String
    let rest: String
    let clips: [String: [Frame]]
    let bakedHopFrames: [String]
    let loop: [Frame]
}
struct Sequence: Decodable {
    struct Entry: Decodable { let file: String; let ms: Int }
    let frames: [Entry]
}
struct Raster {
    let width: Int
    let height: Int
    let bottom: Int
    init(_ url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure("Cannot decode \(url.path)")
        }
        width = image.width
        height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let w = width, h = height
        try rgba.withUnsafeMutableBytes { bytes in
            let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            guard let context = CGContext(data: bytes.baseAddress, width: w, height: h,
                                          bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else {
                throw Failure("Cannot allocate RGBA decoder")
            }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        guard let edge = (0..<h).last(where: { y in
            (0..<w).contains { x in rgba[(y * w + x) * 4 + 3] > 32 }
        }) else { throw Failure("Empty PNG \(url.path)") }
        bottom = edge
    }
}
struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// Independent transcription of each generator's hop table. Coffee and typing
// never translate the whole subject. Do not classify their pose changes as hops.
let specs: [(name: String, folder: String, rest: String, hops: [String: Int])] = [
    ("hello", "hello-loop", "h01", ["h03": 6, "h04": 12, "h05": 6, "h14": 6, "h15": 12, "h16": 6]),
    ("celebrate", "celebrate-loop", "e01", ["e03": 6, "e04": 12, "e05": 6, "e11": 6, "e12": 12, "e13": 6]),
    ("coffee", "coffee-loop", "c01", [:]),
    ("working", "typing", "t01", [:])
]
var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition { failures += 1; print("  FAIL: \(message)") }
}
func validStem(_ name: String) -> Bool {
    name.range(of: "^[hcet][0-9]{2}$", options: .regularExpression) != nil
}
do {
    guard CommandLine.arguments.count <= 2 else { throw Failure("Usage: swift tools/clips/verify.swift [manifest-path]") }
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("dist/assets/companion")
    let manifestURL = CommandLine.arguments.count == 2
        ? URL(fileURLWithPath: CommandLine.arguments[1]) : root.appendingPathComponent("clips.json")
    let decoder = JSONDecoder()
    let manifest = try decoder.decode([String: Animation].self, from: Data(contentsOf: manifestURL))
    check(Set(manifest.keys) == Set(specs.map(\.name)), "Expected exactly hello, celebrate, coffee, working")
    for spec in specs {
        let before = failures
        guard let animation = manifest[spec.name] else { continue }
        print("\(spec.name):")
        check(animation.folder == spec.folder, "Incorrect folder")
        check(animation.rest == spec.rest, "Rest must be the neutral generator frame \(spec.rest)")
        let folder = root.appendingPathComponent(spec.folder)
        let sequence = try decoder.decode(Sequence.self, from: Data(contentsOf: folder.appendingPathComponent("sequence.json")))
        let sequenceNames = sequence.frames.map { URL(fileURLWithPath: $0.file).deletingPathExtension().lastPathComponent }
        let known = Set(sequenceNames)
        let hops = Set(animation.bakedHopFrames)
        check(hops.count == animation.bakedHopFrames.count, "Duplicate bakedHopFrames")
        check(hops == Set(spec.hops.keys), "bakedHopFrames differs from generator table")
        check(animation.loop.map(\.file) == sequenceNames && animation.loop.map(\.ms) == sequence.frames.map(\.ms),
              "Fallback loop differs from sequence.json (order, names or timing)")
        check(!hops.contains(animation.rest), "Rest is a baked hop")
        check(!animation.clips.isEmpty, "No clips")
        if spec.name == "coffee" || spec.name == "working" {
            check(animation.clips["base"] != nil, "Missing base clip")
        }
        for (name, clip) in animation.clips.sorted(by: { $0.key < $1.key }) {
            guard let first = clip.first, let last = clip.last else {
                check(false, "\(name): empty clip"); continue
            }
            check(clip.count >= 2, "\(name): missing closure")
            check(first.file == animation.rest, "\(name): must start from rest")
            let target = name == "base" ? first.file : animation.rest
            check(last.file == target && last.ms == 0, "\(name): must end on \(target) at 0 ms")
            check(clip.contains { $0.ms > 0 }, "\(name): no timed frames")
            for (i, frame) in clip.enumerated() {
                check(!hops.contains(frame.file), "\(name): uses baked hop \(frame.file)")
                check(frame.ms >= 0, "\(name): negative duration")
                if i > 0 && i < clip.count - 1 {
                    check(frame.ms > 0, "\(name): interior frame must have a positive duration")
                }
            }
        }
        // Include every sequence frame, even unused duplicates, so omitting a
        // hop from bakedHopFrames cannot evade the decoded PNG ground check.
        var referenced = known.union(hops).union([animation.rest])
        referenced.formUnion(animation.loop.map(\.file))
        for clip in animation.clips.values { referenced.formUnion(clip.map(\.file)) }
        var rasters: [String: Raster] = [:]
        let suffixes = spec.name == "hello" ? [".png", ".avif"] : [".png", ".avif", "-314.avif"]
        var assets = 0
        for frame in referenced.sorted() {
            check(validStem(frame) && known.contains(frame), "Unknown or invalid frame \(frame)")
            guard validStem(frame) else { continue }
            for suffix in suffixes {
                let path = folder.appendingPathComponent(frame + suffix).path
                let exists = FileManager.default.fileExists(atPath: path)
                check(exists, "Missing \(frame + suffix)")
                if exists { assets += 1 }
            }
            do { rasters[frame] = try Raster(folder.appendingPathComponent(frame + ".png")) }
            catch { check(false, "\(error)") }
        }
        var groundFailures = [String]()
        if let rest = rasters[animation.rest] {
            for frame in referenced.sorted() {
                guard let raster = rasters[frame] else { continue }
                check(raster.width == rest.width && raster.height == rest.height, "\(frame): canvas differs from rest")
                let expected = rest.bottom - (hops.contains(frame) ? (spec.hops[frame] ?? 0) : 0)
                if raster.bottom != expected { groundFailures.append("\(frame)=\(raster.bottom) (expected \(expected))") }
            }
            check(groundFailures.isEmpty, "PNG bottom edges: " + groundFailures.joined(separator: ", "))
            print("  \(failures == before ? "PASS" : "FAIL"): \(animation.clips.count) clips; \(assets) assets; \(referenced.subtracting(hops).count) hop-free PNGs; \(hops.count) baked hops; rest bottom=\(rest.bottom); fallback \(animation.loop.count) frames exact=\(animation.loop.map(\.file) == sequenceNames && animation.loop.map(\.ms) == sequence.frames.map(\.ms))")
        } else { check(false, "Rest PNG could not be decoded") }
    }
    print(failures == 0 ? "PASS: all checks passed" : "FAIL: \(failures) check(s) failed")
    exit(failures == 0 ? 0 : 1)
} catch {
    print("ERROR: \(error)")
    exit(1)
}
