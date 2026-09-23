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
        case .idle: String(localized: "Start a session to connect")
        case .waitingForToken: String(localized: "Waiting for Apple's notification address")
        case .registering: String(localized: "Connecting to live updates")
        case .registered: String(localized: "Connected to live updates")
        case .activityUnavailable: String(localized: "Live Activity couldn't start")
        case .failed: String(localized: "Live updates couldn't connect")
        }
    }

    var detail: String {
        switch self {
        case .idle: String(localized: "The connection is checked when a session is running.")
        case .waitingForToken: String(localized: "Keep Clockin open briefly. If this continues, check your connection and iPhone's Live Activities setting.")
        case .registering: String(localized: "Your temporary notification address is being registered.")
        case .registered: String(localized: "The server accepted this session. Apple still controls when updates appear.")
        case .activityUnavailable: String(localized: "Check Allow Live Activities in iPhone Settings, then try again. Your work timer keeps running.")
        case .failed(let code):
            code.map { String(localized: "Registration failed (\($0)). Check your connection, then try again.") }
                ?? String(localized: "Check your internet connection, then try again.")
        }
    }
}
