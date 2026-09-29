import Foundation

// Byte limits are on canonical JSON, including base64. Requested KB/MB caps use decimal bytes.
enum SyncBounds {
    static let recoveryCount = 50
    static let recoveryBytes = 256_000
    static let quarantineCount = 100
    static let quarantineBytes = 1_000_000
    static let futureCatalogCount = 16
    static let systemFieldBytes = 16 * 1024
    static let engineBytes = 256 * 1024
    static let envelopeBytes = 512 * 1024 // Strictly above every valid schema-2 envelope.
    static let catalog = Set(WardrobeCatalog.items.map(\.id))

    static func identifier(_ value: String, max: Int = 128) -> Bool {
        !value.isEmpty && value.utf8.count <= max && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }
    // A grapheme can contain arbitrarily many combining scalars; both limits are necessary.
    static func text(_ value: String, characters: Int) -> Bool {
        value.count <= characters && value.utf8.count <= characters * 4
    }
    static func size<T: Encodable>(_ value: T) -> Int { (try? SyncCoding.encode(value).count) ?? Int.max }
    static func base64(_ n: Int) -> Int { 4 * ((n + 2) / 3) }
}

extension SyncKind {
    var capacity: Int {
        switch self {
        case .session, .rateRule: 1
        case .profile: 4
        case .purchase: 3 // Winner plus two alternatives.
        case .running, .preference, .wardrobe: 8
        }
    }
    var payloadBytes: Int {
        switch self {
        case .session: 16 * 1024
        case .rateRule, .profile, .purchase: 1024
        case .running: 16 * 1024
        case .preference, .wardrobe: 32 * 1024
        }
    }
    var envelopeBound: Int {
        // 2 KiB record header + catalog facts; each version: payload + 1 KiB scalar
        // metadata + at most K 152-byte ASCII parent references.
        2048 + SyncBounds.catalog.count * 84
            + capacity * (SyncBounds.base64(payloadBytes) + 1024 + capacity * 152)
    }
}

struct SyncLocalIssue: Codable, Equatable, Sendable {
    var recordKey: String
    // Stable key and localized fallback; no arbitrary payload/reason is duplicated in the sidecar.
    var messageKey: String { "sync.localValueInvalid" }
    var message: String {
        String(localized: "This value exceeds sync limits or is unsupported. It is saved only on this device. Edit it to resume syncing.", bundle: .app)
    }
}
