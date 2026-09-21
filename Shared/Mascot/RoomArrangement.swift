import Foundation

/// Offsets in the unmirrored 360×240 room. Each theme remembers its own layout.
struct RoomArrangement: Codable, Equatable, Sendable {
    private(set) var rooms: [String: [String: WardrobePoint]] = [:]
    init() {}
    func offset(for item: String, room: String) -> WardrobePoint { rooms[room]?[item] ?? .init(0, 0) }
    func contains(_ item: String, room: String) -> Bool { rooms[room]?[item] != nil }
    mutating func set(_ offset: WardrobePoint, for item: String, room: String) {
        guard offset.x.isFinite, offset.y.isFinite else { return }
        rooms[room, default: [:]][item] = .init(min(360, max(-360, offset.x)), min(240, max(-240, offset.y)))
    }
    mutating func reset(item: String, room: String) { rooms[room]?[item] = nil; prune(room) }
    mutating func reset(room: String) { rooms[room] = nil }
    mutating func merge(room: String, from draft: Self) { rooms[room] = draft.rooms[room]; prune(room) }
    private mutating func prune(_ room: String) { if rooms[room]?.isEmpty == true { rooms[room] = nil } }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        for room in container.allKeys where room.stringValue.count <= 64 {
            guard let items = try? container.nestedContainer(keyedBy: Key.self, forKey: room) else { continue }
            for item in items.allKeys where item.stringValue.count <= 80 {
                guard let point = try? items.decode(WardrobePoint.self, forKey: item) else { continue }
                set(point, for: item.stringValue, room: room.stringValue)
            }
        }
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        for (room, items) in rooms where !items.isEmpty {
            try container.encode(items, forKey: Key(stringValue: room))
        }
    }
}
