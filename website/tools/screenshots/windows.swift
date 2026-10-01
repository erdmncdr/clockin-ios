// Prints the on-screen window numbers of a process, largest first:
//   swiftc windows.swift -o /tmp/clockin-windows && /tmp/clockin-windows <pid>
import CoreGraphics
import Foundation

let pid = Int(CommandLine.arguments.dropFirst().first ?? "") ?? 0
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let windows = list.compactMap { info -> (Int, Double)? in
    guard (info[kCGWindowOwnerPID as String] as? Int) == pid,
          let number = info[kCGWindowNumber as String] as? Int,
          let bounds = info[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double,
          width > 80, height > 60 else { return nil }
    return (number, width * height)
}
for (number, _) in windows.sorted(by: { $0.1 > $1.1 }) { print(number) }
