import Foundation

// Uygulama ve araclar ayni renk motorunu derler.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("clockin-art-" + UUID().uuidString)
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let source = root.appendingPathComponent(CommandLine.arguments[1])
let main = temporary.appendingPathComponent("main.swift")
try FileManager.default.copyItem(at: source, to: main)
let binary = temporary.appendingPathComponent("art")
let compile = Process()
compile.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
compile.arguments = ["-O", "-swift-version", "6", "-module-cache-path", "/tmp/clockin-art-module-cache",
    root.appendingPathComponent("iOS/Shared/Mascot/WardrobePalette.swift").path, main.path, "-o", binary.path]
try compile.run(); compile.waitUntilExit()
guard compile.terminationStatus == 0 else { exit(compile.terminationStatus) }
let run = Process()
run.executableURL = binary
run.currentDirectoryURL = root
run.arguments = Array(CommandLine.arguments.dropFirst(2))
try run.run(); run.waitUntilExit()
exit(run.terminationStatus)
