import Foundation

@main struct DecisionChecks {
    static func main() {
        precondition(LiveActivityDecision.action(running: true, hasActivity: true,
            needsReplacement: true, appIsActive: false) == .keep,
            "A background replacement must keep the existing card")
        print("ok: background replacement preserves card")
        for active in [false, true] {
            precondition(LiveActivityDecision.action(running: false, hasActivity: true,
                needsReplacement: true, appIsActive: active) == .end,
                "Clock-out ends immediately in foreground and background")
            precondition(LiveActivityDecision.action(running: true, hasActivity: true,
                needsReplacement: false, appIsActive: active) == .update,
                "Mutable content can update in foreground and background")
        }
        precondition(LiveActivityDecision.action(running: true, hasActivity: false,
            needsReplacement: false, appIsActive: false) == .request, "Empty slot preserves existing intent-compatible request path")
        precondition(LiveActivityDecision.action(running: true, hasActivity: false,
            needsReplacement: false, appIsActive: true) == .request, "Foreground can start")
        precondition(LiveActivityDecision.action(running: true, hasActivity: true,
            needsReplacement: true, appIsActive: true) == .replace, "Foreground retries deferred replacement")
        print("All 8 Live Activity decisions passed.")
    }
}
