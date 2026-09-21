import Foundation

// Bagimsiz test gercek renk motorunu kullanir.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
task.arguments = ["-module-cache-path", "/tmp/clockin-art-module-cache",
    root.appendingPathComponent("iOS/Tools/run-art.swift").path,
    "iOS/Tests/manual/wardrobeart/checks.swift", CommandLine.arguments.dropFirst().first ?? root.path]
try task.run(); task.waitUntilExit()
exit(task.terminationStatus)
