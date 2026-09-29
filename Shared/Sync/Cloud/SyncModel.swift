import Foundation

enum SyncCoding {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

enum SyncFailure: Error, Equatable {
    case invalid(String), unsupportedVersion, stalePreview, backupRequired, accountChanged
}

struct SyncSnapshot: Sendable {
    var data: ClockinData
    var preferences: [String: SyncPreference] = [:]
    var wardrobe: WardrobeState = .init()
    var ledger: [WardrobePurchase] = []
}

enum SyncPreference: Codable, Equatable, Sendable {
    case bool(Bool), integer(Int), double(Double), string(String), strings([String])

    var type: String {
        switch self {
        case .bool: "bool"
        case .integer: "integer"
        case .double: "double"
        case .string: "string"
        case .strings: "strings"
        }
    }
}

struct SyncProfile: Codable, Equatable, Sendable {
    var hourlyRate: Double
    var currencyCode: String
}

struct SyncRunning: Codable, Equatable, Sendable {
    // Nil is an explicit idle value, never a CloudKit deletion.
    var session: RunningSession?
    init(session: RunningSession?) { self.session = session }
    private enum CodingKeys: String, CodingKey { case session }
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard values.contains(.session) else { throw SyncFailure.invalid("Missing running state") }
        session = try values.decodeIfPresent(RunningSession.self, forKey: .session)
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        if let session { try values.encode(session, forKey: .session) }
        else { try values.encodeNil(forKey: .session) }
    }
}

// Strict wire DTO: the app's forgiving wardrobe decoder is not a network validator.
struct SyncWardrobe: Codable, Equatable, Sendable {
    var owned: [String]
    var equipped: [String: String]
    var colorway: String
    var room: String
    var furniture: [String: String]
    var homeLayout: CompanionHomeLayout
    var homeLampOn: Bool
    var arrangement: [String: [String: WardrobePoint]]

    init(_ state: WardrobeState) {
        owned = state.owned.sorted(); equipped = state.equipped
        colorway = state.colorway; room = state.room; furniture = state.furniture
        homeLayout = state.homeLayout; homeLampOn = state.homeLampOn
        arrangement = state.homeArrangement.rooms
    }

    func applying(to local: WardrobeState) -> WardrobeState {
        var state = local
        state.owned = Set(owned); state.equipped = equipped
        state.colorway = colorway; state.room = room; state.furniture = furniture
        state.homeLayout = homeLayout; state.homeLampOn = homeLampOn
        state.homeArrangement = .init()
        for (room, items) in arrangement {
            for (item, point) in items { state.homeArrangement.set(point, for: item, room: room) }
        }
        return state
    }
}

enum SyncKind: String, Codable, Sendable, CaseIterable {
    case session = "Session", rateRule = "RateRule", profile = "Profile", running = "Running"
    case preference = "Preference", purchase = "WardrobePurchase", wardrobe = "WardrobeState"

    var removeWins: Bool { self == .session || self == .rateRule }
}

struct SyncStamp: Codable, Equatable, Comparable, Sendable {
    var modifiedAt: Date
    var modifiedBy: String
    var sequence: UInt64

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt < rhs.modifiedAt }
        if lhs.modifiedBy != rhs.modifiedBy { return lhs.modifiedBy < rhs.modifiedBy }
        return lhs.sequence < rhs.sequence
    }
}

struct SyncVersion: Codable, Equatable, Sendable {
    var stamp: SyncStamp
    var deleted: Bool = false
    var payload: Data
    // Causal parents distinguish a conflict from an ordinary sequential edit.
    var parents: [String] = []

    var id: String { "\(stamp.modifiedBy):\(stamp.sequence)" }
    static func less(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.stamp != rhs.stamp { return lhs.stamp < rhs.stamp }
        if lhs.deleted != rhs.deleted { return !lhs.deleted }
        return lhs.payload.lexicographicallyPrecedes(rhs.payload)
    }
}

struct SyncRecord: Codable, Equatable, Sendable {
    var schema = 1
    var kind: SyncKind
    var name: String
    var versions: [SyncVersion]

    var key: String { kind.rawValue + ":" + name }
    var winner: SyncVersion? {
        let eligible = kind.removeWins && versions.contains(where: \.deleted)
            ? versions.filter(\.deleted) : versions
        return eligible.max(by: SyncVersion.less)
    }

    func joined(with other: Self) throws -> Self {
        guard kind == other.kind, name == other.name, schema == other.schema else {
            throw SyncFailure.invalid("Record identity changed")
        }
        var byID: [String: SyncVersion] = [:]
        for version in versions + other.versions {
            if let old = byID[version.id], old != version {
                throw SyncFailure.invalid("Revision identity reused")
            }
            byID[version.id] = version
        }
        var result = self
        result.versions = byID.values.sorted(by: SyncVersion.less)
        return result
    }
}

struct SyncQuarantine: Codable, Equatable, Sendable {
    var recordKey: String
    var bytes: Data
    var reason: String
}

struct SyncNotice: Codable, Equatable, Sendable {
    var id: String
    var message: String
}

struct SyncRecovery: Sendable {
    var recordKey: String
    var version: SyncVersion
    var reason: String
}

struct SyncMerge: Sendable {
    var records: [String: SyncRecord]
    var snapshot: SyncSnapshot
    var resend: [SyncRecord]
    var quarantine: [SyncQuarantine]
    var recoveries: [SyncRecovery]
    var notices: [SyncNotice]
}

struct SyncFirstPreview: Sendable {
    var localCount: Int
    var remoteCount: Int
    var duplicates: Int
    var mergedCount: Int
    var revision: UInt64
    var merge: SyncMerge
}
