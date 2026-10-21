import AppKit
import Foundation

/// The Clockin Chrome extension ships inside the app. People load it into
/// Chrome as an unpacked extension from a fixed folder; Settings writes the
/// files there and shows the steps. Every launch refreshes an existing folder,
/// so the extension updates with the app (Chrome picks it up when it restarts
/// or when the extension is reloaded).
enum ChromeExtensionInstaller {
    static let files = ["manifest.json", "background.js", "watch.js", "picker.js", "popup.html", "popup.js"]

    static var folder: URL {
        // A Debug build keeps its own copy, so it never replaces the extension
        // people use or points Chrome at itself.
        #if DEBUG
        let app = "Clockin Debug"
        #else
        let app = "Clockin"
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(app, isDirectory: true)
            .appendingPathComponent("Chrome Extension", isDirectory: true)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent("manifest.json").path)
    }

    /// Writes the extension, copies the folder's path for Chrome's file dialog
    /// and shows the folder in Finder.
    @MainActor
    @discardableResult
    static func prepare() throws -> URL {
        try write()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(folder.path(percentEncoded: false), forType: .string)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
        return folder
    }

    /// At launch: bring an existing copy up to date, never create one.
    @MainActor
    static func refreshIfInstalled() {
        guard isInstalled else { return }
        try? write()
    }

    @MainActor
    private static func write() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in files {
            let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
            guard let source = Bundle.main.url(forResource: parts[0], withExtension: parts[1], subdirectory: "ChromeExtension")
                    ?? Bundle.main.url(forResource: parts[0], withExtension: parts[1]) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: name])
            }
            let target = folder.appendingPathComponent(name)
            if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
            try manager.copyItem(at: source, to: target)
        }
        for size in iconSizes {
            try icon(size: size).write(to: folder.appendingPathComponent("icon\(size).png"))
        }
        #if DEBUG
        // Only on request: the browsers' host folders are shared with the real app.
        if ProcessInfo.processInfo.arguments.contains("--native-host") { ChromeNativeHost.writeManifests() }
        #else
        ChromeNativeHost.writeManifests()
        #endif
    }

    /// The sizes manifest.json names: toolbar (16, 32), extensions page (48, 128).
    static let iconSizes = [16, 32, 48, 128]

    /// The app icon cropped to its artwork. A macOS icon keeps a wide
    /// transparent margin around its tile, which made the toolbar icon look
    /// smaller than every other extension's; Chrome's toolbar sizes fill the
    /// square, and the 128 px one keeps Chrome's small store margin.
    @MainActor
    static func icon(size: Int, source: NSImage = NSApp.applicationIconImage) throws -> Data {
        let art = artwork(of: source)
        let margin = size >= 128 ? CGFloat(size) / 16 : 0
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { throw CocoaError(.fileWriteUnknown) }
        rep.size = NSSize(width: size, height: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        let side = CGFloat(size) - 2 * margin
        source.draw(in: NSRect(x: margin, y: margin, width: side, height: side), from: art, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return data
    }

    /// The square around the icon's visible pixels, in the image's points.
    @MainActor
    static func artwork(of image: NSImage) -> NSRect {
        let full = NSRect(origin: .zero, size: image.size)
        let pixels = 256
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return full }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        var minX = pixels, minY = pixels, maxX = -1, maxY = -1
        for y in 0..<pixels {
            for x in 0..<pixels where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return full }
        // colorAt counts rows from the top; drawing counts from the bottom.
        let side = CGFloat(max(maxX - minX, maxY - minY) + 1)
        let centerX = CGFloat(minX + maxX + 1) / 2
        let centerY = CGFloat(pixels) - CGFloat(minY + maxY + 1) / 2
        let scale = image.size.width / CGFloat(pixels)
        return NSRect(x: (centerX - side / 2) * scale, y: (centerY - side / 2) * scale,
                      width: side * scale, height: side * scale).intersection(full)
    }
}
