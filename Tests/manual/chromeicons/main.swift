// The Chrome extension's icons: cropped to the app icon's artwork, so the
// toolbar icon is as large as other extensions' (a macOS icon's transparent
// margin made it look small).
//
// swiftc -swift-version 6 ClockinMac/ChromeExtensionInstaller.swift Tests/manual/chromeicons/main.swift -o /tmp/clockin-chromeicons && /tmp/clockin-chromeicons "$PWD/build/DerivedData/Build/Products/Debug/Clockin.app" [output folder]
import AppKit

enum ChromeNativeHost { static func writeManifests() {} }

var passed = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else { FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8)); exit(1) }
    passed += 1
}

/// How much of one ring of pixels (`ring` px in from the edge) is drawn.
func drawn(_ rep: NSBitmapImageRep, ring: Int) -> Double {
    let n = rep.pixelsWide
    var hit = 0, count = 0
    for y in 0..<n {
        for x in 0..<n where min(x, y, n - 1 - x, n - 1 - y) == ring {
            count += 1
            if rep.colorAt(x: x, y: y)!.alphaComponent > 0.5 { hit += 1 }
        }
    }
    return Double(hit) / Double(count)
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    let app = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/DerivedData/Build/Products/Debug/Clockin.app"
    let source = NSWorkspace.shared.icon(forFile: URL(fileURLWithPath: app).standardizedFileURL.path)
    source.size = NSSize(width: 1024, height: 1024)
    let art = ChromeExtensionInstaller.artwork(of: source)
    check(art.width < source.size.width * 0.95, "the macOS icon's transparent margin is found: \(art)")
    let out = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
    for size in ChromeExtensionInstaller.iconSizes {
        let data = try! ChromeExtensionInstaller.icon(size: size, source: source)
        if let out { try! data.write(to: out.appendingPathComponent("icon\(size).png")) }
        let rep = NSBitmapImageRep(data: data)!
        check(rep.pixelsWide == size && rep.pixelsHigh == size, "icon\(size) is \(size) px")
        // Toolbar sizes fill the square; 128 keeps Chrome's 8 px margin. The
        // tile's rounded corners leave its corners clear, so a ring just
        // inside the art is mostly drawn, not all of it.
        let margin = size >= 128 ? size / 16 : 0
        let inside = drawn(rep, ring: margin + max(1, size / 32))
        check(inside > 0.6, "icon\(size) reaches its edges (\(Int(inside * 100))% drawn)")
        if margin > 0 { check(drawn(rep, ring: margin / 2) < 0.02, "icon\(size) keeps its margin clear") }
    }
    print("\(passed) Chrome icon checks passed")
}
