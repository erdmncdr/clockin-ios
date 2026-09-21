import SwiftUI

struct RoomEditorSession: Identifiable {
    let id = UUID()
    let state: WardrobeState
}

struct RoomEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @ObservedObject private var wardrobe = WardrobeStore.shared
    private let original: WardrobeState
    @State private var draft: RoomArrangement
    @State private var selectedID: String?
    @State private var feedback: String?
    @State private var isDragging = false
    @State private var images: [String: CGImage] = [:]
    @State private var loaded = false

    init(state: WardrobeState) {
        original = state
        _draft = State(initialValue:state.homeArrangement)
    }
    private var room: WardrobeRoom? { WardrobeArt.home.rooms[original.room] }
    private var items: [RoomPlacedItem] {
        guard let room else { return [] }
        return original.furniture.values.sorted().compactMap { id in
            guard let item = WardrobeArt.home.items[id], let image = images[id] else { return nil }
            return RoomPlacedItem(id:id,name:item.name,slot:item.slot,
                base:HomeSceneLayout.furnitureRect(item,in:room,imageSize:CGSize(width:image.width,height:image.height),layout:.deskLeft))
        }
    }
    private func state(_ arrangement: RoomArrangement) -> WardrobeState {
        var copy = original; copy.homeArrangement = arrangement; return copy
    }
    private var changed: Bool { draft != original.homeArrangement }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    Text("Drag to arrange").font(.title3.bold())
                    Text("Wall items stay on the wall. Rugs fit under furniture.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let room {
                        RoomEditorCanvas(items:items,room:room,roomID:original.room,layout:original.homeLayout,
                            arrangement:$draft,selectedID:$selectedID,feedback:$feedback,isDragging:$isDragging) { value in
                                CompanionHomeView(stateOverride:state(value))
                                    .environment(\.clockinContentActive,false)
                            }
                            .clipShape(RoundedRectangle(cornerRadius:12))
                            .accessibilityIdentifier("room.editor.canvas")
                        if !loaded { ProgressView().frame(maxWidth:.infinity) }
                        else if items.isEmpty {
                            Text("Choose home items in Companion first.").font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            controls(room)
                        }
                    }
                    Button("Reset room",systemImage:"arrow.counterclockwise") {
                        draft.reset(room:original.room); feedback = nil
                    }.disabled(isDragging || !loaded || items.isEmpty)
                        .frame(minHeight:44).accessibilityIdentifier("room.editor.reset")
                }.padding(16)
            }
            .background(palette.background)
            .navigationTitle("Edit room").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("room.editor.cancel")
                }
                ToolbarItem(placement:.confirmationAction) {
                    Button("Save") {
                        wardrobe.setRoomArrangement(draft,room:original.room)
                        dismiss()
                    }.disabled(!loaded || isDragging || !changed).accessibilityIdentifier("room.editor.save")
                }
            }
            .interactiveDismissDisabled(changed)
        }
        .tint(palette.accent).fontDesign(palette.fontDesign).preferredColorScheme(palette.colorScheme)
        .task {
            let ids = original.furniture.values.sorted()
            let decoded = await Task.detached(priority:.utility) {
                var result: [String:CGImage] = [:]
                for id in ids {
                    if let item = WardrobeArt.home.items[id], let image = WardrobeArt.decode(item.file,folder:"Home") {
                        result[id] = image
                    }
                }
                return result
            }.value
            guard !Task.isCancelled else { return }
            images = decoded; loaded = true; selectedID = items.first?.id
        }
    }

    @ViewBuilder private func controls(_ room: WardrobeRoom) -> some View {
        Picker("Item",selection:$selectedID) {
            ForEach(items) { item in Text(item.name).tag(Optional(item.id)) }
        }.pickerStyle(.menu).disabled(isDragging)
            .onChange(of:selectedID) { _, _ in feedback = nil }
        if let item = items.first(where: { $0.id == selectedID }) {
            HStack(spacing:8) {
                moveButton("Move left",symbol:"arrow.left",dx:-4,dy:0,item:item,room:room)
                moveButton("Move right",symbol:"arrow.right",dx:4,dy:0,item:item,room:room)
                moveButton("Move up",symbol:"arrow.up",dx:0,dy:-4,item:item,room:room)
                moveButton("Move down",symbol:"arrow.down",dx:0,dy:4,item:item,room:room)
                Spacer(minLength:0)
                Button {
                    var next = draft; next.reset(item:item.id,room:original.room)
                    feedback = RoomPlacement.issue(for:item,items:items,room:room,roomID:original.room,arrangement:next)
                    if feedback == nil { draft = next }
                } label: {
                    Image(systemName:"arrow.uturn.backward").frame(width:44,height:44)
                }.accessibilityLabel("Reset selected item").disabled(isDragging)
            }
        }
        Text(feedback ?? "Changes stay here until you save.")
            .font(.caption).foregroundStyle(feedback == nil ? Color.secondary : .red)
            .frame(minHeight:30,alignment:.topLeading)
            .accessibilityIdentifier("room.editor.feedback")
    }
    private func moveButton(_ title: String, symbol: String, dx: Double, dy: Double,
                            item: RoomPlacedItem, room: WardrobeRoom) -> some View {
        Button {
            let next = RoomPlacement.moved(item,translation:CGSize(width:dx,height:dy),room:room,
                roomID:original.room,arrangement:draft,layout:original.homeLayout)
            feedback = RoomPlacement.issue(for:item,items:items,room:room,roomID:original.room,arrangement:next)
            if feedback == nil { draft = next }
        } label: { Image(systemName:symbol).frame(width:44,height:44) }
        .accessibilityLabel(title).disabled(isDragging)
    }
}
