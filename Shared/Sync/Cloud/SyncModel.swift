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
    case invalid(String), unknownCatalog, unsupportedVersion, stalePreview, backupRequired, accountChanged
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
    // Immutable causal floor: maximum stamp observed for this identity when authored.
    // Unlike parent edges, this witness survives pruning.
    var observed: SyncStamp? = nil

    func concurrent(with other: Self) -> Bool {
        (observed.map { $0 < other.stamp } ?? true)
            && (other.observed.map { $0 < stamp } ?? true)
            && stamp.modifiedBy != other.stamp.modifiedBy
    }

    var id: String { "\(stamp.modifiedBy):\(stamp.sequence)" }
    static func less(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.stamp != rhs.stamp { return lhs.stamp < rhs.stamp }
        if lhs.deleted != rhs.deleted { return !lhs.deleted }
        return lhs.payload.lexicographicallyPrecedes(rhs.payload)
    }
}

// The wrapper distinguishes a known non-Clockin origin (nil) from a missing fact.
struct SyncSessionFact: Codable, Equatable, Sendable {
    var clockinStart: Date?
}

struct SyncRecord: Codable, Equatable, Sendable {
    var schema = 2
    var kind: SyncKind
    var name: String
    var versions: [SyncVersion]
    var maximumStamp: SyncStamp
    var sessionFact: SyncSessionFact?
    var ownership: [String] = []

    init(kind: SyncKind, name: String, versions: [SyncVersion]) {
        self.kind = kind; self.name = name; self.versions = versions
        maximumStamp = versions.map(\.stamp).max() ?? .init(modifiedAt: .distantPast, modifiedBy: "empty", sequence: 0)
        if kind == .session, let payload = versions.first?.payload,
           let value = try? SyncCoding.decode(WorkSession.self, payload) {
            sessionFact = .init(clockinStart: value.source == "Clockin" ? value.start : nil)
        }
        // These facts are extracted once at creation, then joined independently of history.
        if kind == .wardrobe {
            ownership = Set(versions.flatMap { (try? SyncCoding.decode(SyncWardrobe.self, $0.payload).owned) ?? [] }).sorted()
        } else if kind == .preference && name == "Clockin.SeenAccessoryIDs" {
            ownership = Set(versions.flatMap { version -> [String] in
                if case .strings(let ids) = try? SyncCoding.decode(SyncPreference.self, version.payload) { return ids }
                return []
            }).sorted()
        }
        if kind.removeWins {
            for i in self.versions.indices where self.versions[i].deleted { self.versions[i].payload = Data() }
        }
    }

    var key: String { kind.rawValue + ":" + name }
    func less(_ lhs: SyncVersion, _ rhs: SyncVersion) -> Bool {
        if kind.removeWins && lhs.deleted != rhs.deleted { return !lhs.deleted }
        if kind == .purchase,
           let a = try? SyncCoding.decode(WardrobePurchase.self, lhs.payload),
           let b = try? SyncCoding.decode(WardrobePurchase.self, rhs.payload) {
            if a.date != b.date { return a.date > b.date }
            if a.cost != b.cost { return a.cost > b.cost }
        }
        return SyncVersion.less(lhs, rhs)
    }
    var winner: SyncVersion? { versions.max(by: less) }

    func pruned() -> Self {
        var result = self
        result.maximumStamp = max(maximumStamp, versions.map(\.stamp).max() ?? maximumStamp)
        result.versions = Array(versions.sorted(by: less).suffix(kind.capacity))
        let retained = Set(result.versions.map(\.id))
        for i in result.versions.indices {
            result.versions[i].parents = Set(result.versions[i].parents).intersection(retained)
                .subtracting([result.versions[i].id]).sorted()
        }
        result.ownership = Set(ownership).sorted()
        return result
    }

    func joined(with other: Self) throws -> Self {
        guard kind == other.kind, name == other.name, schema == other.schema,
              sessionFact == other.sessionFact else {
            throw SyncFailure.invalid("Record identity or immutable clockinStart changed")
        }
        var byID: [String: SyncVersion] = [:]
        for var version in versions + other.versions {
            if let old = byID[version.id] {
                // Parent edges are a projected relation, not part of immutable revision identity.
                var left = old; var right = version
                left.parents = []; right.parents = []
                guard left == right else { throw SyncFailure.invalid("Revision identity reused") }
                version.parents = Set(old.parents + version.parents).sorted()
            }
            byID[version.id] = version
        }
        var result = self
        result.versions = Array(byID.values)
        result.maximumStamp = max(maximumStamp, other.maximumStamp)
        result.ownership = Set(ownership + other.ownership).sorted()
        return result.pruned()
    }
}

struct SyncQuarantine: Codable, Equatable, Sendable {
    var recordKey: String
    var bytes: Data
    var reason: String
    var futureCatalog: Bool = false
}

struct SyncNotice: Codable, Equatable, Sendable {
    var id: String
    var message: String
}

struct SyncRecovery: Codable, Equatable, Sendable {
    var recordKey: String
    var version: SyncVersion
    var reason: String
    var id: String { "recovery:" + recordKey + ":" + version.id }
    var notice: SyncNotice {
        let message: String
        switch reason {
        case "Displaced timer": message = String(localized: "Another timer state won. The previous timer is in recovery.", bundle: .app)
        case "Replaced value": message = String(localized: "A replaced value is available in recovery.", bundle: .app)
        case "Import-key duplicate": message = String(localized: "Duplicate entries were collapsed. Your previous entry is in recovery.", bundle: .app)
        default: message = String(localized: "Concurrent changes were resolved. Your previous value is in recovery.", bundle: .app)
        }
        return .init(id: id, message: message)
    }
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
