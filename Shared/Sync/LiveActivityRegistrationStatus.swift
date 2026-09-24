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
        case .idle: String(localized: "Start a session to connect", bundle: .app)
        case .waitingForToken: String(localized: "Waiting for Apple's notification address", bundle: .app)
        case .registering: String(localized: "Connecting to live updates", bundle: .app)
        case .registered: String(localized: "Connected to live updates", bundle: .app)
        case .activityUnavailable: String(localized: "Live Activity couldn't start", bundle: .app)
        case .failed: String(localized: "Live updates couldn't connect", bundle: .app)
        }
    }

    var detail: String {
        switch self {
        case .idle: String(localized: "The connection is checked when a session is running.", bundle: .app)
        case .waitingForToken: String(localized: "Keep Clockin open briefly. If this continues, check your connection and iPhone's Live Activities setting.", bundle: .app)
        case .registering: String(localized: "Your temporary notification address is being registered.", bundle: .app)
        case .registered: String(localized: "The server accepted this session. Apple still controls when updates appear.", bundle: .app)
        case .activityUnavailable: String(localized: "Check Allow Live Activities in iPhone Settings, then try again. Your work timer keeps running.", bundle: .app)
        case .failed(let code):
            code.map { String(localized: "Registration failed (\($0)). Check your connection, then try again.", bundle: .app) }
                ?? String(localized: "Check your internet connection, then try again.", bundle: .app)
        }
    }
}
