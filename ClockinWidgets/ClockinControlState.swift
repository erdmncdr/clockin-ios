@available(iOS 18.0, *)
enum ClockinControlState: Sendable {
    case off
    case working
    case paused

    init(snapshot: ClockinSnapshot) {
        guard let running = snapshot.running else {
            self = .off
            return
        }
        self = running.isPaused ? .paused : .working
    }

    var isOn: Bool { self != .off }

    func valueLabel(isOn: Bool) -> String {
        isOn ? (self == .paused ? "Paused" : "Working") : "Off"
    }

    var pauseTitle: String {
        switch self {
        case .off: "Pause or Resume"
        case .working: "Pause"
        case .paused: "Resume"
        }
    }

    var pauseSymbol: String {
        switch self {
        case .off: "pause.circle"
        case .working: "pause.fill"
        case .paused: "play.fill"
        }
    }
}
