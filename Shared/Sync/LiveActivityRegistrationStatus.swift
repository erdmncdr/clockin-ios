import Foundation

enum LiveActivityRegistrationStatus: Equatable {
    case idle
    case waitingForToken
    case registering
    case registered
    case activityUnavailable
    case failed(Int?)

    var title: String {
        switch self {
        case .idle: "Start a session to connect"
        case .waitingForToken: "Waiting for Apple's notification address"
        case .registering: "Connecting to live updates"
        case .registered: "Connected to live updates"
        case .activityUnavailable: "Live Activity couldn't start"
        case .failed: "Live updates couldn't connect"
        }
    }

    var detail: String {
        switch self {
        case .idle: "The connection is checked when a session is running."
        case .waitingForToken: "Keep Clockin open briefly. If this continues, check your connection and iPhone's Live Activities setting."
        case .registering: "Your temporary notification address is being registered."
        case .registered: "The server accepted this session. Apple still controls when updates appear."
        case .activityUnavailable: "Check Allow Live Activities in iPhone Settings, then try again. Your work timer keeps running."
        case .failed(let code):
            code.map { "Registration failed (\($0)). Check your connection, then try again." }
                ?? "Check your internet connection, then try again."
        }
    }
}
