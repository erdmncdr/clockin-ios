#!/usr/bin/env swift
// Ortak renk motorunu sanat araciyla derle.
import Foundation
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
task.arguments = ["-module-cache-path", "/tmp/clockin-art-module-cache",
                  "iOS/Tools/run-art.swift", "iOS/Tools/MascotArt.swift", "anchors"]
try task.run()
task.waitUntilExit()
exit(task.terminationStatus)
