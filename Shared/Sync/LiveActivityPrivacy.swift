import Foundation

enum LiveActivityPrivacy {
    // New, versioned opt-in: earlier automatic registrations are not consent.
    static let consentKey = "Clockin.RemoteActivityConsent.v2"
    static let pendingDeletionsKey = "Clockin.RemoteActivityPendingDeletions.v2"
    static let setupSeenKey = "Clockin.LiveActivitySetupSeen.v1"
    static var enabled: Bool { isEnabled(in: .standard) }
    static func isEnabled(in defaults: UserDefaults) -> Bool { defaults.bool(forKey: consentKey) }
    static let policyURL = URL(string: "https://getclockin.netlify.app/privacy/")!
}

struct LiveActivityRegistration: Encodable {
    let environment: String
    let expiresAt: TimeInterval
    let protocolVersion = 2
    enum CodingKeys: String, CodingKey { case environment, expiresAt; case protocolVersion = "protocol" }
}
