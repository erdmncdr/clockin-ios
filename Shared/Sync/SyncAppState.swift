#if !WIDGET_EXTENSION
import Foundation

@MainActor
struct SyncPreferenceStore {
    let standard: UserDefaults
    let language: UserDefaults?

    func suite(for key: String) -> UserDefaults? { key == AppLanguage.key ? language : standard }
    func capture() -> [String: SyncPreference] {
        var result: [String: SyncPreference] = [:]
        for (key, type) in SyncPreferences.types {
            guard let object = suite(for: key)?.object(forKey: key) else { continue }
            switch type {
            case "bool": if let value = object as? Bool { result[key] = .bool(value) }
            case "integer": if let value = object as? Int { result[key] = .integer(value) }
            case "double": if let value = object as? Double { result[key] = .double(value) }
            case "string": if let value = object as? String { result[key] = .string(value) }
            case "strings": if let value = object as? [String] { result[key] = .strings(value) }
            default: break
            }
        }
        return result
    }

    func apply(_ values: [String: SyncPreference]) {
        for key in SyncPreferences.types.keys {
            guard let defaults = suite(for: key) else { continue }
            guard let value = values[key] else { defaults.removeObject(forKey: key); continue }
            switch value {
            case .bool(let v): defaults.set(v, forKey: key)
            case .integer(let v): defaults.set(v, forKey: key)
            case .double(let v): defaults.set(v, forKey: key)
            case .string(let v): defaults.set(v, forKey: key)
            case .strings(let v): defaults.set(v, forKey: key)
            }
        }
    }
}

enum SyncSnapshotValidation {
    // Validate every domain before writing anything. Existing invalid local-only values may
    // survive a merge, but a remote value can never use that exemption to change them.
    static func validate(_ value: SyncSnapshot, preserving local: SyncSnapshot,
                         issues: [SyncLocalIssue], now: Date) throws {
        guard Set(value.data.sessions.map(\.id)).count == value.data.sessions.count,
              Set((value.data.rateRules ?? []).map(\.id)).count == (value.data.rateRules ?? []).count,
              Set(value.preferences.keys).isSubset(of: Set(SyncPreferences.types.keys)) else {
            throw SyncFailure.invalid("Invalid snapshot identities or preference keys")
        }
        var invalid = Set<String>()
        let records = try SyncCore.payloads(value, onInvalid: { invalid.insert($0) })
        for (key, var record) in records {
            // Snapshot templates use distantPast; validate running duration at apply time.
            record.versions[0].stamp.modifiedAt = now
            record.maximumStamp = record.versions[0].stamp
            do { try SyncCore.validate(record) } catch { invalid.insert(key) }
        }
        // payloads intentionally collapses purchase identities. Check every input row too.
        for purchase in value.ledger {
            let key = "WardrobePurchase:" + SyncCore.purchaseName(purchase.itemID)
            do {
                let record = SyncRecord(kind: .purchase, name: SyncCore.purchaseName(purchase.itemID), versions: [
                    .init(stamp: .init(modifiedAt: now, modifiedBy: "snapshot", sequence: 0),
                          payload: try SyncCoding.encode(purchase))])
                try SyncCore.validate(record)
            } catch { invalid.insert(key) }
        }
        let preserved = Set(issues.map(\.recordKey))
        for key in invalid {
            guard preserved.contains(key), unchanged(key, value, local) else {
                throw SyncFailure.invalid("Invalid snapshot value: " + key)
            }
        }
    }

    private static func unchanged(_ key: String, _ a: SyncSnapshot, _ b: SyncSnapshot) -> Bool {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let kind = SyncKind(rawValue: parts[0]) else { return false }
        switch kind {
        case .session: return a.data.sessions.first { $0.id.uuidString == parts[1] } == b.data.sessions.first { $0.id.uuidString == parts[1] }
        case .rateRule: return a.data.rateRules?.first { $0.id.uuidString == parts[1] } == b.data.rateRules?.first { $0.id.uuidString == parts[1] }
        case .profile: return a.data.hourlyRate == b.data.hourlyRate && a.data.currencyCode == b.data.currencyCode
        case .running: return a.data.running == b.data.running
        case .preference: return a.preferences[parts[1]] == b.preferences[parts[1]]
        case .wardrobe: return a.wardrobe == b.wardrobe
        case .purchase:
            return a.ledger.filter { SyncCore.purchaseName($0.itemID) == parts[1] }
                == b.ledger.filter { SyncCore.purchaseName($0.itemID) == parts[1] }
        }
    }
}

struct SyncRecoveryEntry: Identifiable, Sendable {
    enum Value: Sendable {
        case session(WorkSession), rateRule(RateRule), profile(SyncProfile), running(SyncRunning)
        case preference(key: String, value: SyncPreference), purchase(WardrobePurchase), wardrobe(SyncWardrobe)
        case unavailable
    }
    let recovery: SyncRecovery
    var id: String { recovery.id }
    var kind: SyncKind? { SyncKind(rawValue: String(recovery.recordKey.split(separator: ":").first ?? "")) }
    var recordKey: String { recovery.recordKey }
    var message: String { recovery.notice.message }
    /// Time and installation identity of the replaced value, not the other device's display name.
    var modifiedAt: Date { recovery.version.stamp.modifiedAt }
    var fromDeviceID: String? { recovery.version.stamp.modifiedBy }
    var recoveredAt: Date? { recovery.recoveredAt }
    var value: Value {
        let bytes = recovery.version.payload
        do {
            switch kind {
            case .session: return .session(try SyncCoding.decode(WorkSession.self, bytes))
            case .rateRule: return .rateRule(try SyncCoding.decode(RateRule.self, bytes))
            case .profile: return .profile(try SyncCoding.decode(SyncProfile.self, bytes))
            case .running: return .running(try SyncCoding.decode(SyncRunning.self, bytes))
            case .preference: return .preference(key: String(recordKey.dropFirst("Preference:".count)), value: try SyncCoding.decode(SyncPreference.self, bytes))
            case .purchase: return .purchase(try SyncCoding.decode(WardrobePurchase.self, bytes))
            case .wardrobe: return .wardrobe(try SyncCoding.decode(SyncWardrobe.self, bytes))
            case nil: return .unavailable
            }
        } catch { return .unavailable }
    }
}

struct SyncIssue: Identifiable, Sendable {
    enum Kind: Sendable { case quarantine, localValue, notice }
    let id: String
    let kind: Kind
    let recordKey: String?
    let message: String
    // Technical diagnostics/opaque original bytes for a review/export tool, not UI copy.
    var quarantine: SyncQuarantine? = nil
}

extension SyncKind {
    var title: String {
        switch self {
        case .session: String(localized: "Session", bundle: .app)
        case .rateRule: String(localized: "Rate rule", bundle: .app)
        case .profile: String(localized: "Pay settings", bundle: .app)
        case .running: String(localized: "Running timer", bundle: .app)
        case .preference: String(localized: "Preference", bundle: .app)
        case .purchase: String(localized: "Wardrobe purchase", bundle: .app)
        case .wardrobe: String(localized: "Wardrobe", bundle: .app)
        }
    }
}
#endif
