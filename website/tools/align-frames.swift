#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import AppKit

// Coordinates are PNG rows: x increases right, y increases down.
// Centre is the mean x of component pixels in its lowest ceil(height * .12) rows.
struct Raster {
    let width: Int
    let height: Int
    var pixels: [UInt8]
    init(_ path: String) throws {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure("Cannot read PNG: \(path)")
        }
        width = image.width; height = image.height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
        let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.interpolationQuality = .none
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        if !ok { throw Failure("Cannot decode \(path)") }
    }
    init(width: Int, height: Int) {
        self.width = width; self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }
    var nontransparent: Int { stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 0 }.count }
    var opaque: Int { stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 32 }.count }
    func write(_ path: String) throws {
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        guard let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
            let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)
        else { throw Failure("Cannot create PNG: \(path)") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure("Cannot write PNG: \(path)") }
    }
    func ground() throws -> (bottom: Int, centre: Double) {
        var visited = [Bool](repeating: false, count: width * height)
        var largest: [Int] = []
        for start in visited.indices where !visited[start] && pixels[start * 4 + 3] > 32 {
            var component = [start]; visited[start] = true
            var cursor = 0
            while cursor < component.count {
                let index = component[cursor]; cursor += 1
                let x = index % width, y = index / width
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let next = ny * width + nx
                        if !visited[next] && pixels[next * 4 + 3] > 32 {
                            visited[next] = true; component.append(next)
                        }
                    }
                }
            }
            if component.count > largest.count { largest = component }
        }
        guard !largest.isEmpty else { throw Failure("No opaque body component") }
        let bottom = largest.map { $0 / width }.max()!
        let top = largest.map { $0 / width }.min()!
        let rows = max(1, Int(ceil(Double(bottom - top + 1) * 0.12)))
        let contact = largest.filter { $0 / width >= bottom - rows + 1 }
        let centre = Double(contact.reduce(0) { $0 + $1 % width }) / Double(contact.count)
        return (bottom, centre)
    }
    func shifted(dx: Int, dy: Int) throws -> Raster {
        var result = Raster(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                let source = (y * width + x) * 4
                let nx = x + dx, ny = y + dy
                if nx < 0 || nx >= width || ny < 0 || ny >= height {
                    // Stricter than alpha > 32: protect every nontransparent pixel.
                    if pixels[source + 3] > 0 { throw Failure("Offset (\(dx), \(dy)) would crop pixel (\(x), \(y))") }
                } else {
                    let target = (ny * width + nx) * 4
                    result.pixels[target..<target + 4] = pixels[source..<source + 4]
                }
            }
        }
        return result
    }
}
struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

do {
    var args = Array(CommandLine.arguments.dropFirst())
    let measureOnly = args.first == "--measure-only"
    let sheetOnly = args.first == "--sheet"
    let verify = args.first == "--verify"
    if measureOnly || sheetOnly || verify { args.removeFirst() }
    if verify {
        guard args.count == 2 else { throw Failure("Usage: --verify <original.png> <aligned.png>") }
        let original = try Raster(args[0]), aligned = try Raster(args[1])
        guard original.width == aligned.width, original.height == aligned.height,
              original.nontransparent == aligned.nontransparent, original.opaque == aligned.opaque
        else { throw Failure("Size or pixel count changed: \(args)") }
        print("PASS \(args[1]): \(aligned.width)x\(aligned.height), alpha>0=\(aligned.nontransparent), alpha>32=\(aligned.opaque), unchanged")
    } else {
        guard args.count >= 3 else {
            throw Failure("Usage: [--measure-only | --sheet] <reference.png> <output-dir (or sheet.png)> <frame1.png> ...\n       --verify <original.png> <aligned.png>")
        }
        let reference = try Raster(args[0]), ground = try reference.ground()
        guard reference.width == 627, reference.height == 627 else { throw Failure("Reference must be 627x627") }
        var outputs: [(String, Raster)] = []
        for path in args.dropFirst(2) {
            let frame = try Raster(path)
            guard frame.width == reference.width, frame.height == reference.height else { throw Failure("Wrong canvas size: \(path)") }
            let measured = try frame.ground()
            let dx = Int((ground.centre - measured.centre).rounded()), dy = ground.bottom - measured.bottom
            print(String(format: "%@: bottom=%d centre=%.3f offset=(%+d,%+d)%@", path, measured.bottom, measured.centre, dx, dy, measureOnly || sheetOnly ? " [report only]" : ""))
            outputs.append((URL(fileURLWithPath: path).lastPathComponent, try (measureOnly || sheetOnly ? frame : frame.shifted(dx: dx, dy: dy))))
        }
        if sheetOnly {
            // Native-size panels, grey backdrop, one-pixel red common ground line.
            var sheet = Raster(width: 627 * outputs.count, height: 627)
            for y in 0..<627 {
                for x in 0..<sheet.width {
                    let source = (y * 627 + x % 627) * 4, target = (y * sheet.width + x) * 4
                    let pixels = outputs[x / 627].1.pixels
                    let alpha = Int(pixels[source + 3])
                    for channel in 0..<3 {
                        sheet.pixels[target + channel] = UInt8(min(255, Int(pixels[source + channel]) + (230 * (255 - alpha) + 127) / 255))
                    }
                    sheet.pixels[target + 3] = 255
                    if y == ground.bottom { sheet.pixels[target..<target + 4] = [220, 65, 65, 255] }
                }
            }
            try sheet.write(args[1])
        } else if !measureOnly {
            // Validate every shift before writing any output; loading first also supports in-place use.
            try FileManager.default.createDirectory(atPath: args[1], withIntermediateDirectories: true)
            for (name, frame) in outputs { try frame.write(URL(fileURLWithPath: args[1]).appendingPathComponent(name).path) }
        }
    }
} catch {
    FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
    exit(1)
}
