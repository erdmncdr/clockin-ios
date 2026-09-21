import Foundation
import CoreGraphics

struct RoomPlacedItem: Identifiable {
    let id: String
    let name: String
    let slot: String
    let base: CGRect
}

enum RoomPlacement {
    static let grid = 4.0
    static func isWall(_ slot: String) -> Bool { ["wallLeft", "wallRight", "shelf", "window"].contains(slot) }
    static func mirror(_ rect: CGRect) -> CGRect {
        CGRect(x: 360 - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
    }
    static func clamped(_ rect: CGRect, slot: String, room: WardrobeRoom) -> CGRect {
        let minY = isWall(slot) ? 24 : max(24, room.floorY - rect.height)
        let maxY = isWall(slot) ? 166 - rect.height : (slot == "rug" ? 238 : 232) - rect.height
        return CGRect(x: min(max(20, rect.minX), max(20, 340 - rect.width)),
                      y: min(max(minY, rect.minY), max(minY, maxY)), width: rect.width, height: rect.height)
    }
    static func rect(_ item: RoomPlacedItem, room: WardrobeRoom, roomID: String,
                     arrangement: RoomArrangement, layout: CompanionHomeLayout) -> CGRect {
        var result = item.base
        if arrangement.contains(item.id, room: roomID) {
            let offset = arrangement.offset(for: item.id, room: roomID)
            result = clamped(result.offsetBy(dx: offset.x, dy: offset.y), slot: item.slot, room: room)
        }
        return layout.mirrored ? mirror(result) : result
    }
    /// Drag translation is in displayed room units, independent of screen points.
    static func moved(_ item: RoomPlacedItem, translation: CGSize, room: WardrobeRoom, roomID: String,
                      arrangement: RoomArrangement, layout: CompanionHomeLayout) -> RoomArrangement {
        let old = rect(item, room: room, roomID: roomID, arrangement: arrangement, layout: .deskLeft)
        let x = old.minX + (layout.mirrored ? -translation.width : translation.width)
        let y = old.minY + translation.height
        let proposed = clamped(CGRect(x: (x / grid).rounded() * grid, y: (y / grid).rounded() * grid,
                                     width: old.width, height: old.height), slot: item.slot, room: room)
        var result = arrangement
        result.set(.init(proposed.minX - item.base.minX, proposed.minY - item.base.minY), for: item.id, room: roomID)
        return result
    }
    static func issue(for item: RoomPlacedItem, items: [RoomPlacedItem], room: WardrobeRoom,
                      roomID: String, arrangement: RoomArrangement) -> String? {
        let r = rect(item, room: room, roomID: roomID, arrangement: arrangement, layout: .deskLeft)
        if isWall(item.slot), item.slot != "window", r.intersects(CGRect(x:234,y:27,width:100,height:101)) {
            return "Keep the window clear"
        }
        guard item.slot != "rug" else { return nil }
        for other in items where other.id != item.id && other.slot != "rug" {
            let otherRect = rect(other, room: room, roomID: roomID, arrangement: arrangement, layout: .deskLeft)
            // Two points of breathing room; touching is allowed, covering another item is not.
            if r.insetBy(dx:1,dy:1).intersects(otherRect.insetBy(dx:1,dy:1)) { return "Leave space for \(other.name)" }
        }
        return nil
    }
}
