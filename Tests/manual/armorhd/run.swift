import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let directory = root.appendingPathComponent("build/hd-checks")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let binary = directory.appendingPathComponent("checks")
let compile = Process()
compile.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
compile.arguments =
  [
    "-O", "-swift-version", "6", "-strict-concurrency=complete", "-module-cache-path",
    "/tmp/clockin-art-module-cache",
  ]
  + [
    "Shared/Mascot/WardrobePalette.swift", "Shared/Mascot/ArmorHD.swift",
    "Shared/Mascot/ArmorHDPixels.swift",
    "Shared/Mascot/ArmorHDParts.swift", "Shared/Mascot/ArmorHDCache.swift",
    "Tests/manual/armorhd/main.swift",
  ].map { root.appendingPathComponent($0).path }
  + ["-o", binary.path]
try compile.run()
compile.waitUntilExit()
guard compile.terminationStatus == 0 else { exit(compile.terminationStatus) }
let run = Process()
run.executableURL = binary
run.currentDirectoryURL = root
try run.run()
run.waitUntilExit()
exit(run.terminationStatus)
