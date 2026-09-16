import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

let now = Date(timeIntervalSince1970: 1_800_000_000)
var snapshot = ClockinSnapshot.empty
let off = ClockinControlState(snapshot: snapshot)
check(!off.isOn && off.valueLabel(isOn: off.isOn) == "Off", "no session is off")
check(off.pauseTitle == "Pause or Resume" && off.pauseSymbol == "pause.circle", "idle pause button has a neutral label")

snapshot.running = RunningSession(start: now, accumulated: 0, resumedAt: now, note: "")
let working = ClockinControlState(snapshot: snapshot)
check(working.isOn && working.valueLabel(isOn: working.isOn) == "Working", "running session is on and working")
check(working.pauseTitle == "Pause" && working.pauseSymbol == "pause.fill", "running session offers pause")

snapshot.running?.resumedAt = nil
let paused = ClockinControlState(snapshot: snapshot)
check(paused.isOn && paused.valueLabel(isOn: paused.isOn) == "Paused", "paused session stays on")
check(paused.pauseTitle == "Resume" && paused.pauseSymbol == "play.fill", "paused session offers resume")
check(paused.valueLabel(isOn: false) == "Off", "turning off a paused session shows off")
check(off.valueLabel(isOn: true) == "Working", "turning on an idle control shows working")

let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
let url = directory.appending(path: "snapshot.json")
defer { try? FileManager.default.removeItem(at: directory) }
check(ClockinControlState(snapshot: ClockinSnapshot.load(from: url) ?? .empty) == .off,
      "missing snapshot falls back to off")
try snapshot.write(to: url)
check(ClockinControlState(snapshot: ClockinSnapshot.load(from: url) ?? .empty) == .paused,
      "snapshot round trip preserves paused state")
snapshot.running?.resumedAt = now
try snapshot.write(to: url)
check(ClockinControlState(snapshot: ClockinSnapshot.load(from: url) ?? .empty) == .working,
      "snapshot reload observes resume")
snapshot.running = nil
try snapshot.write(to: url)
check(ClockinControlState(snapshot: ClockinSnapshot.load(from: url) ?? .empty) == .off,
      "snapshot reload observes clock out")
try Data("invalid snapshot".utf8).write(to: url)
check(ClockinControlState(snapshot: ClockinSnapshot.load(from: url) ?? .empty) == .off,
      "unreadable snapshot falls back to off")
print("\(checks) controls checks passed")
