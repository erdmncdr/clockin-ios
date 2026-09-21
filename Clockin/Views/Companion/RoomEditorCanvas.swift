import SwiftUI

/// Shared gesture surface, also used by the native interaction review harness.
struct RoomEditorCanvas<Scene: View>: View {
    let items: [RoomPlacedItem]
    let room: WardrobeRoom
    let roomID: String
    let layout: CompanionHomeLayout
    @Binding var arrangement: RoomArrangement
    @Binding var selectedID: String?
    @Binding var feedback: String?
    @Binding var isDragging: Bool
    @ViewBuilder let scene: (RoomArrangement) -> Scene
    @State private var dragOrigin: RoomArrangement?
    @State private var proposal: RoomArrangement?

    private var displayed: RoomArrangement { proposal ?? arrangement }
    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 360
            ZStack(alignment: .topLeading) {
                scene(displayed).allowsHitTesting(false)
                if isDragging {
                    Canvas { context, size in
                        var lines = Path()
                        for x in stride(from: 20.0, through: 340.0, by: 16) {
                            lines.move(to: .init(x:x*scale,y:24*scale)); lines.addLine(to:.init(x:x*scale,y:238*scale))
                        }
                        for y in stride(from: 24.0, through: 238.0, by: 16) {
                            lines.move(to:.init(x:20*scale,y:y*scale)); lines.addLine(to:.init(x:340*scale,y:y*scale))
                        }
                        context.stroke(lines, with: .color(.white.opacity(0.2)), lineWidth: 0.5)
                    }.allowsHitTesting(false)
                }
                ForEach(items.sorted { $0.base.width * $0.base.height > $1.base.width * $1.base.height }) { item in
                    let rect = RoomPlacement.rect(item, room:room, roomID:roomID, arrangement:displayed, layout:layout)
                    let selected = selectedID == item.id
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.clear)
                        .overlay(RoundedRectangle(cornerRadius:4)
                            .strokeBorder(selected ? (feedback == nil ? Color.cyan : .red) : .white.opacity(0.25),
                                          style:StrokeStyle(lineWidth:selected ? 2 : 1, dash:selected ? [] : [3,3])))
                        .frame(width: max(24,rect.width*scale), height: max(24,rect.height*scale))
                        .contentShape(Rectangle())
                        .position(x:rect.midX*scale,y:rect.midY*scale)
                        .onTapGesture { selectedID = item.id; feedback = nil }
                        .gesture(DragGesture(minimumDistance:3, coordinateSpace:.named("room-editor-canvas"))
                            .onChanged { value in
                                if dragOrigin == nil { dragOrigin = arrangement; selectedID = item.id; isDragging = true }
                                let next = RoomPlacement.moved(item,
                                    translation:CGSize(width:value.translation.width/scale,height:value.translation.height/scale),
                                    room:room,roomID:roomID,arrangement:dragOrigin ?? arrangement,layout:layout)
                                proposal = next
                                feedback = RoomPlacement.issue(for:item,items:items,room:room,roomID:roomID,arrangement:next)
                            }
                            .onEnded { _ in
                                if let next = proposal,
                                   RoomPlacement.issue(for:item,items:items,room:room,roomID:roomID,arrangement:next) == nil {
                                    arrangement = next; feedback = nil
                                }
                                proposal = nil; dragOrigin = nil; isDragging = false
                            })
                        .accessibilityElement(children:.ignore)
                        .accessibilityLabel(item.name)
                        .accessibilityValue(selected ? "Selected" : "")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { selectedID = item.id; feedback = nil }
                        .accessibilityHint("Select, then use the move buttons")
                        .accessibilityIdentifier("room.editor.item.\(item.id)")
                }
            }
            .coordinateSpace(name:"room-editor-canvas")
        }
        .aspectRatio(1.5, contentMode:.fit)
        .clipped()
        .onDisappear { proposal = nil; dragOrigin = nil; isDragging = false }
    }
}
