import Foundation

enum MascotAsset: String {
    case idle, working, paused, celebrate, angry

    static func session(running: RunningSession?, angry: Bool = false) -> Self {
        if running?.isPaused == false { return .working }
        if angry { return .angry }
        return running == nil ? .idle : .paused
    }

    var mood: MascotMood {
        switch self {
        case .idle: .hello
        case .working: .working
        case .paused: .coffee
        case .celebrate: .celebrate
        case .angry: .angry
        }
    }

    var message: String {
        switch self {
        case .angry: "Your companion is waiting"
        case .idle: "Ready when you are"
        case .working: "You are doing great, keep going!"
        case .paused: "Taking a reset break"
        case .celebrate: "Every focused hour makes your companion stronger."
        }
    }
}
