#!/usr/bin/env swift  // Render the actual app warrior for the HD review, without editing Clockin/.
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let work = root.appendingPathComponent("build/hd-reference")
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
try FileManager.default.createDirectory(
  at: root.appendingPathComponent("build/hd-previews"), withIntermediateDirectories: true)
// Extract only standalone dependencies, keeping their original source verbatim.
for (file, end, output) in [
  ("LevelUpStage.swift", "/// Where the stage", "Curves.swift"),
  ("LevelPrestigeViews.swift", "/// Shared by", "Light.swift"),
  ("RankMaterial.swift", "enum RankOrnaments", "RankMaterial.swift"),
] {
  let source = try String(
    contentsOf: root.appendingPathComponent("Clockin/Celebrations/" + file), encoding: .utf8)
  guard let range = source.range(of: end) else {
    fatalError("Reference dependency changed: " + file)
  }
  try String(source[..<range.lowerBound]).write(
    to: work.appendingPathComponent(output), atomically: true, encoding: .utf8)
}
let main = #"""
  import SwiftUI
  import ImageIO
  for level in [150,300,450] {
      let view = LevelUpWarrior(style:LevelPrestige(level:level),t:7)
          .scaleEffect(1.5).frame(width:408,height:408)
          .background(Color(red:17/255,green:23/255,blue:37/255))
      let renderer = ImageRenderer(content:view)
      renderer.scale = 1
      guard let image = renderer.cgImage else { fatalError("reference render") }
      let url = URL(fileURLWithPath:"build/hd-previews/warrior-\(level).png")
      let destination = CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil)!
      CGImageDestinationAddImage(destination,image,nil)
      precondition(CGImageDestinationFinalize(destination))
  }
  """#
try main.write(to: work.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
let compile = Process()
compile.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
compile.arguments =
  ["-O", "-swift-version", "6", "-module-cache-path", "/tmp/clockin-art-module-cache"]
  + [
    "Shared/Core/AppLanguage.swift", "Clockin/Celebrations/LevelPrestige.swift",
    "Clockin/Celebrations/PrestigeForge.swift", "Clockin/Celebrations/LevelUpTiming.swift",
    "Clockin/Celebrations/LevelUpWarrior.swift",
  ].map { root.appendingPathComponent($0).path }
  + ["RankMaterial.swift", "Curves.swift", "Light.swift", "main.swift"].map {
    work.appendingPathComponent($0).path
  }
  + ["-o", work.appendingPathComponent("render").path]
try compile.run()
compile.waitUntilExit()
guard compile.terminationStatus == 0 else { exit(compile.terminationStatus) }
let run = Process()
run.executableURL = work.appendingPathComponent("render")
run.currentDirectoryURL = root
try run.run()
run.waitUntilExit()
exit(run.terminationStatus)
