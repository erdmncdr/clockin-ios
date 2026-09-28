import Foundation

// Package real resources so Bundle.main exercises the same lookup as the app.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
let fm = FileManager.default
let app = root.appendingPathComponent("build/skin-checks/Skins.app/Contents")
let resources = app.appendingPathComponent("Resources")
try fm.createDirectory(at: app.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
try fm.createDirectory(at: resources, withIntermediateDirectories: true)
for folder in ["Frames", "Wardrobe", "Skins", "Home"] {
    let target = resources.appendingPathComponent(folder)
    if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
    try fm.copyItem(at: root.appendingPathComponent("Shared/Mascot/" + folder), to: target)
}
let info = ["CFBundleIdentifier": "test.clockin.skins", "CFBundleExecutable": "checks", "CFBundlePackageType": "APPL"]
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: app.appendingPathComponent("Info.plist"))
let sources = [
    "Shared/Core/AppLanguage.swift", "Shared/Mascot/MascotMotion.swift", "Shared/Mascot/MascotFrames.swift",
    "Shared/Mascot/WardrobeArt.swift", "Shared/Mascot/CompanionAccessory.swift", "Shared/Mascot/Wardrobe.swift",
    "Shared/Mascot/WardrobePalette.swift", "Shared/Mascot/WardrobeCatalog.swift", "Shared/Mascot/WardrobeSkins.swift",
    "Shared/Mascot/RoomArrangement.swift", "Shared/Mascot/RoomPlacement.swift", "Shared/Mascot/HomeSceneLayout.swift",
    "Shared/Mascot/HeritageArt.swift", "Tests/manual/skins/main.swift"
]
let binary = app.appendingPathComponent("MacOS/checks")
let compile = Process()
compile.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
compile.arguments = ["-O", "-swift-version", "6", "-strict-concurrency=complete", "-D", "WIDGET_EXTENSION",
                     "-module-cache-path", "/tmp/clockin-art-module-cache"]
    + sources.map { root.appendingPathComponent($0).path } + ["-o", binary.path]
try compile.run(); compile.waitUntilExit()
guard compile.terminationStatus == 0 else { exit(compile.terminationStatus) }
let run = Process(); run.executableURL = binary; run.currentDirectoryURL = root
try run.run(); run.waitUntilExit(); exit(run.terminationStatus)
