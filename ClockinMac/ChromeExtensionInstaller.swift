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
        try icon().write(to: folder.appendingPathComponent("icon128.png"))
        #if DEBUG
        // Only on request: the browsers' host folders are shared with the real app.
        if ProcessInfo.processInfo.arguments.contains("--native-host") { ChromeNativeHost.writeManifests() }
        #else
        ChromeNativeHost.writeManifests()
        #endif
    }

    /// The app icon at 128 px, for Chrome's toolbar and extensions page.
    @MainActor
    private static func icon() throws -> Data {
        let size = NSSize(width: 128, height: 128)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 128, pixelsHigh: 128, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { throw CocoaError(.fileWriteUnknown) }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSApp.applicationIconImage.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}
