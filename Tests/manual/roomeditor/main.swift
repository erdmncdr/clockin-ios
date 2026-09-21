import Foundation
import CoreGraphics
import ImageIO

var checks = 0
@MainActor func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message); checks += 1
}
let root = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Shared/Mascot/Home")
let home = try JSONDecoder().decode(WardrobeHome.self,from:Data(contentsOf:root.appendingPathComponent("home-items.json")))
func size(_ id:String) -> CGSize {
    let file = home.items[id]!.file, url = root.appendingPathComponent(file)
    let image = HeritageArt.render(file,source:url) ?? CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL,nil)!,0,nil)!
    return CGSize(width:image.width,height:image.height)
}
func placed(_ id:String, _ room:WardrobeRoom) -> RoomPlacedItem {
    let item = home.items[id]!
    return .init(id:id,name:item.name,slot:item.slot,base:HomeSceneLayout.furnitureRect(item,in:room,imageSize:size(id),layout:.deskLeft))
}
let old = WardrobeState.decode(#"{"owned":["bean-bag","headphones"],"equipped":{"head":"headphones"},"furniture":{"floorRight":"bean-bag"},"homeLayout":"deskRight"}"#)
check(old.owned.contains("headphones") && old.homeArrangement.rooms.isEmpty && old.homeLayout == .deskRight,"old saves retain inventory, outfit, orientation and exact default room")
let corrupt = WardrobeState.decode(#"{"owned":["bean-bag"],"homeArrangement":{"cozy":{"bean-bag":[-80,0],"bad":["x"],"large":[99999,-99999]},"night":null}}"#)
check(corrupt.owned.contains("bean-bag") && corrupt.homeArrangement.offset(for:"bean-bag",room:"cozy").x == -80,"bad individual item does not erase saved state")
check(corrupt.homeArrangement.offset(for:"large",room:"cozy") == .init(360,-240),"import limits unreasonable offsets")
var invalid = RoomArrangement(); invalid.set(.init(.nan,.infinity),for:"a",room:"cozy")
check(invalid.rooms.isEmpty,"nonfinite offsets cannot be saved")
var original = old
original.homeArrangement.set(.init(-60,0),for:"bean-bag",room:"night")
var draft = original.homeArrangement
draft.set(.init(-100,-10),for:"bean-bag",room:"cozy")
check(original.homeArrangement != draft && !original.homeArrangement.contains("bean-bag",room:"cozy"),"draft and cancel preserve saved state")
original.homeArrangement.merge(room:"cozy",from:draft)
check(original.homeArrangement.offset(for:"bean-bag",room:"night").x == -60,"save merges only edited room")
check(WardrobeState.decode(original.json) == original,"save reload roundtrip retains layouts and inventory")
let suite = "Clockin.RoomEditor.Tests.\(UUID())", defaults = UserDefaults(suiteName:suite)!
defer { defaults.removePersistentDomain(forName:suite) }
defaults.set(original.json,forKey:WardrobeState.stateKey)
let backup = try WardrobeBackupSection(defaults:defaults).adding(to:Data("{}".utf8))
defaults.removeObject(forKey:WardrobeState.stateKey)
try WardrobeBackupSection.read(from:backup)!.restore(to:defaults)
check(WardrobeState.decode(defaults.string(forKey:WardrobeState.stateKey)) == original,"backup restores arrangement together with inventory")
draft.reset(room:"cozy")
check(draft.contains("bean-bag",room:"night") && !draft.contains("bean-bag",room:"cozy"),"reset current room preserves other themes")
draft.reset(item:"bean-bag",room:"night")
check(draft.rooms.isEmpty,"reset last item removes empty room")
for (roomID,room) in home.rooms {
    for id in home.items.keys {
        let item = placed(id,room)
        check(RoomPlacement.rect(item,room:room,roomID:roomID,arrangement:.init(),layout:.deskLeft) == item.base,"legacy default geometry unchanged")
        for layout in CompanionHomeLayout.allCases {
            let base = RoomPlacement.rect(item,room:room,roomID:roomID,arrangement:.init(),layout:layout)
            check(abs(RoomPlacement.mirror(RoomPlacement.mirror(base)).minX-base.minX) < 0.000001,"mirroring roundtrip")
            for translation in [CGSize(width:-1000,height:-1000),CGSize(width:1000,height:1000),CGSize(width:-24,height:20)] {
                let arranged = RoomPlacement.moved(item,translation:translation,room:room,roomID:roomID,arrangement:.init(),layout:layout)
                let rect = RoomPlacement.rect(item,room:room,roomID:roomID,arrangement:arranged,layout:.deskLeft)
                check(rect.minX >= 20 && rect.maxX <= 340.000001 && rect.minY >= 24 && rect.maxY <= 238.000001,"drag stays in room")
                check(RoomPlacement.isWall(item.slot) ? rect.maxY <= 166.000001 : rect.maxY >= room.floorY,"wall and floor limits")
            }
        }
    }
    let bean = placed("bean-bag",room)
    for layout in CompanionHomeLayout.allCases {
        let before = RoomPlacement.rect(bean,room:room,roomID:roomID,arrangement:.init(),layout:layout)
        let moved = RoomPlacement.moved(bean,translation:CGSize(width:layout.mirrored ? 80 : -80,height:-8),room:room,roomID:roomID,arrangement:.init(),layout:layout)
        let after = RoomPlacement.rect(bean,room:room,roomID:roomID,arrangement:moved,layout:layout)
        check(layout.mirrored ? after.midX > before.midX : after.midX < before.midX,"drag follows displayed direction in both orientations")
        let first = HomeSceneLayout.seatedCenter(in:room,layout:layout,side:118,feet:300.0/314,furniture:["floorRight":"bean-bag"])
        let last = HomeSceneLayout.seatedCenter(in:room,layout:layout,side:118,feet:300.0/314,furniture:["floorRight":"bean-bag"],roomID:roomID,arrangement:moved)
        check(abs((last.x-first.x)-(after.midX-before.midX)) < 0.0001 && abs((last.y-first.y)-(after.midY-before.midY)) < 0.0001,"mascot follows moved bean bag exactly")
        let bed = placed("companion-bed",room)
        let changed = RoomPlacement.moved(bed,translation:CGSize(width:layout.mirrored ? 76 : -76,height:4),room:room,roomID:roomID,arrangement:.init(),layout:layout)
        let bedRect = RoomPlacement.rect(bed,room:room,roomID:roomID,arrangement:changed,layout:layout)
        let beforeBed = RoomPlacement.rect(bed,room:room,roomID:roomID,arrangement:.init(),layout:layout)
        let delta = HomeSceneLayout.attachmentOffset("companion-bed",in:room,layout:layout,roomID:roomID,arrangement:changed)
        check(abs(delta.x-(bedRect.minX-beforeBed.minX)) < 0.0001 && abs(delta.y-(bedRect.minY-beforeBed.minY)) < 0.0001,"bed attachment matches real asset bounds")
    }
    let portrait = placed("ataturk-portrait",room), shelf = placed("bookshelf",room), rug = placed("round-rug",room)
    let window = RoomPlacement.moved(portrait,translation:CGSize(width:240,height:0),room:room,roomID:roomID,arrangement:.init(),layout:.deskLeft)
    check(RoomPlacement.issue(for:portrait,items:[portrait],room:room,roomID:roomID,arrangement:window) != nil,"window cannot be covered")
    let collision = RoomPlacement.moved(portrait,translation:CGSize(width:80,height:0),room:room,roomID:roomID,arrangement:.init(),layout:.deskLeft)
    check(RoomPlacement.issue(for:portrait,items:[portrait,shelf],room:room,roomID:roomID,arrangement:collision) != nil,"overlapping furniture rejected")
    check(RoomPlacement.issue(for:rug,items:[rug,bean],room:room,roomID:roomID,arrangement:.init()) == nil,"rug can sit under furniture")
    check(size("bean-bag") == CGSize(width:90,height:62) && size("companion-bed") == CGSize(width:106,height:60),"attachment authored sizes verified")
}
print("\(checks) room editor checks passed: migration, save/cancel, backup, bounds, mirrors, collisions, seat attachments")
