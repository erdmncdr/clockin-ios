import Foundation
import CoreGraphics

/// Room-space layout shared by the live scene and its render checks (360 × 240).
enum HomeSceneLayout {
    static func decorativeDeskRect(in room: WardrobeRoom, imageSize: CGSize,
                                   layout: CompanionHomeLayout) -> CGRect {
        let shelf = room.slots["shelf"] ?? .init(132, 90)
        // The shelf art ends six points below its anchor. Leave eight points
        // of wall between it and the decoration; align the feet to the floor.
        let top = shelf.y + 14
        let height = max(1, room.floorY - top)
        let width = imageSize.width * height / max(1, imageSize.height)
        let center = layout.x(shelf.x + 1)
        return CGRect(x: center - width / 2, y: top, width: width, height: height)
    }

    static func furnitureRect(_ item: WardrobeFurniture, in room: WardrobeRoom,
                              imageSize: CGSize, layout: CompanionHomeLayout,
                              roomID: String = "", arrangement: RoomArrangement = .init()) -> CGRect {
        let base = defaultFurnitureRect(item,in:room,imageSize:imageSize,layout:.deskLeft)
        let placed = RoomPlacedItem(id:String(item.file.prefix { $0 != "." }),name:item.name,slot:item.slot,base:base)
        return RoomPlacement.rect(placed,room:room,roomID:roomID,arrangement:arrangement,layout:layout)
    }

    private static func defaultFurnitureRect(_ item: WardrobeFurniture, in room: WardrobeRoom,
                                             imageSize: CGSize, layout: CompanionHomeLayout) -> CGRect {
        if item.slot == "desk" { return decorativeDeskRect(in: room, imageSize: imageSize, layout: layout) }
        guard let anchor = room.slots[item.slot] else { return .zero }
        let scale: Double
        let offset: WardrobePoint
        switch item.file {
        case "ataturk-portrait.jpg":
            scale = 0.85; offset = .init(0, 17)
        case "turkish-flag.svg":
            scale = 0.75; offset = .init(-5, 0)
        default:
            scale = 1; offset = .init(0, 0)
        }
        let width = imageSize.width * scale, height = imageSize.height * scale
        let x = anchor.x + offset.x - item.pivot.x * scale
        return CGRect(x: layout.mirrored ? 360 - x - width : x,
                      y: anchor.y + offset.y - item.pivot.y * scale,
                      width: width, height: height)
    }

    static func seatedCenter(in room: WardrobeRoom, layout: CompanionHomeLayout,
                             side: Double, feet: Double, furniture: [String: String],
                             roomID: String = "", arrangement: RoomArrangement = .init()) -> WardrobePoint {
        let bean = furniture["floorRight"] == "bean-bag"
        let anchor = bean ? (room.slots["floorRight"] ?? .init(302, 224)) : room.mascotSpot
        let x = bean ? anchor.x - 4 : anchor.x - 28
        let floor = anchor.y - (bean ? 12 : 0)
        let delta = bean ? attachmentOffset("bean-bag",in:room,layout:layout,roomID:roomID,arrangement:arrangement) : .init(0,0)
        return .init(layout.x(x) + delta.x, floor - side * (feet - 0.5) + delta.y)
    }

    /// Pose attachments use the same bounds as their source furniture.
    static func attachmentOffset(_ id: String, in room: WardrobeRoom, layout: CompanionHomeLayout,
                                 roomID: String, arrangement: RoomArrangement) -> WardrobePoint {
        let bean = id == "bean-bag"
        let pivot = bean ? WardrobePoint(44,54) : WardrobePoint(52,52)
        let size = bean ? CGSize(width:90,height:62) : CGSize(width:106,height:60)
        let item = WardrobeFurniture(name:id,file:id+".png",slot:"floorRight",pivot:pivot)
        let base = furnitureRect(item,in:room,imageSize:size,layout:layout)
        let moved = furnitureRect(item,in:room,imageSize:size,layout:layout,roomID:roomID,arrangement:arrangement)
        return .init(moved.minX-base.minX,moved.minY-base.minY)
    }

    static func mirrorsCompanion(_ activity: CompanionHomeActivity, layout: CompanionHomeLayout) -> Bool {
        // Typing art faces right; the seated rest art faces left.
        switch activity {
        case .working: return !layout.mirrored
        case .relaxing: return layout.mirrored
        default: return false
        }
    }
}
