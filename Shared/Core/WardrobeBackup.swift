import Foundation

struct WardrobeBackupSection: Codable, Equatable {
    var state: String?
    var ledger: String?
    var showHomeInDeskMode: Bool

    init(defaults: UserDefaults) {
        state = defaults.string(forKey: "Clockin.WardrobeState")
        ledger = defaults.string(forKey: "Clockin.WardrobeLedger")
        showHomeInDeskMode = defaults.object(forKey: "Clockin.WardrobeShowHomeInDeskMode") as? Bool ?? true
    }
    func restore(to defaults: UserDefaults) {
        defaults.set(state, forKey: "Clockin.WardrobeState")
        defaults.set(ledger, forKey: "Clockin.WardrobeLedger")
        defaults.set(showHomeInDeskMode, forKey: "Clockin.WardrobeShowHomeInDeskMode")
    }
    static func read(from data: Data) throws -> Self? {
        struct Extra: Decodable { let wardrobe: WardrobeBackupSection? }
        return try JSONDecoder().decode(Extra.self, from: data).wardrobe
    }
    func adding(to data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        object["wardrobe"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(self))
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
