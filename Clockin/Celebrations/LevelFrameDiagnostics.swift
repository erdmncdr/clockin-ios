#if DEBUG
import Foundation
import os

/// Explicit launch-flag probe; never enabled in shipping builds.
enum LevelFrameDiagnostics {
    private struct Sample: Sendable {
        var warmup = 0.0
        var start = 0.0
        var last = 0.0
        var count = 0
        var longest = 0.0
    }
    private static let sample = OSAllocatedUnfairLock(initialState: Sample())
    private static let enabled = ProcessInfo.processInfo.arguments.contains("--measure-level-cadence")
    static func record(_ time: Double) {
        guard enabled, time > 10 else { return }
        let message = sample.withLock { state -> String? in
            if state.warmup == 0 { state.warmup = time }
            guard time >= state.warmup + 2, time > state.last, state.count < 360 else { return nil }
            if state.count == 0 { state.start = time }
            else { state.longest = max(state.longest, time - state.last) }
            state.last = time
            state.count += 1
            guard state.count == 360 else { return nil }
            return "LEVEL CADENCE: \(Double(state.count - 1) / (time - state.start)) updates/sec; max gap \(state.longest * 1000) ms"
        }
        if let message { print(message) }
    }
}
#endif
