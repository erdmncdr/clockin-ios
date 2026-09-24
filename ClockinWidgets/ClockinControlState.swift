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
        isOn ? (self == .paused ? String(localized: "Paused", bundle: .app) : String(localized: "Working", bundle: .app)) : String(localized: "Off", bundle: .app)
    }

    var pauseTitle: String {
        switch self {
        case .off: String(localized: "Pause or Resume", bundle: .app)
        case .working: String(localized: "Pause", bundle: .app)
        case .paused: String(localized: "Resume", bundle: .app)
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
