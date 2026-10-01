/// Keep immutable attributes until a foreground replacement can start. With no
/// existing card there is nothing to lose: preserve the existing request path,
/// including system-authorized LiveActivityIntent launches.
enum LiveActivityDecision: Equatable {
    case end, request, update, keep, replace

    static func action(running: Bool, hasActivity: Bool, needsReplacement: Bool,
                       appIsActive: Bool) -> Self {
        guard running else { return .end }
        guard hasActivity else { return .request }
        guard needsReplacement else { return .update }
        return appIsActive ? .replace : .keep
    }
}
