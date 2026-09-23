import SwiftUI

struct CompanionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var wardrobe = WardrobeStore.shared
    @State private var category: WardrobeCategory?
    @State private var preview: WardrobeItem?
    @State private var roomEditor: RoomEditorSession?
    @State private var visible = false
    @State private var headerVisible = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 96), spacing: 8)]
    }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
            let viewportHeight = viewport.size.height
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        if category?.isHome == false {
                            CompanionHomeView(outfitCloseup: true)
                        } else {
                            CompanionHomeView()
                        }
                    }
                        .modifier(CompanionPreviewFrame(isHome: category?.isHome != false, outfitHeight: 156))
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .environment(\.clockinContentActive, visible && headerVisible && preview == nil && roomEditor == nil && scenePhase == .active)
                        .onGeometryChange(for: Bool.self) { proxy in
                            let frame = proxy.frame(in: .named("companionScroll"))
                            return frame.maxY > 0 && frame.minY < viewportHeight
                        } action: { headerVisible = $0 }
                        .onDisappear { headerVisible = false }
                    if category == nil || category?.isHome == true {
                        Button { roomEditor = RoomEditorSession(state:wardrobe.state) } label: {
                            Label("Edit room",systemImage:"move.3d").frame(maxWidth:.infinity,minHeight:44)
                        }.buttonStyle(.bordered).accessibilityIdentifier("companion.editRoom")
                    }
                    Label("\(wardrobe.balance.formatted()) focus coins", systemImage: "circle.circle.fill")
                        .font(.title3.bold()).foregroundStyle(palette.accent)
                    DisclosureGroup("How coins work") {
                        Text("10 coins/hour, 25/goal day, 50/work badge, 100/level. Saved work only; minutes round down. Edits recalculate coins. Purchased items stay yours.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                    }
                    CompanionCategoryTabs(selection: $category, accent: palette.accent, surface: palette.surface)
                    Text("\(displayedItems.count) items")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text("Tap any item to preview it. Owned and locked items stay together in their category.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if category == nil || category?.isHome == true {
                        DisclosureGroup("Room settings") {
                            VStack(spacing: 12) {
                                Picker("Room layout", selection: Binding(get: { wardrobe.state.homeLayout }, set: { wardrobe.setHomeLayout($0) })) {
                                    ForEach(CompanionHomeLayout.allCases, id: \.self) { Text($0.title).tag($0) }
                                }.pickerStyle(.segmented)
                                Toggle("Room lamp", isOn: Binding(get: { wardrobe.state.homeLampOn }, set: { wardrobe.setHomeLamp($0) }))
                            }.padding(.top, 8)
                        }
                    }
                    ForEach(displayedCategories) { section in
                        let items = displayedItems.filter { $0.category == section }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(section.title, systemImage: section.symbol)
                                    .font(.headline).accessibilityAddTraits(.isHeader)
                                grid(items)
                            }
                        }
                    }
                }.padding(16)
            }
            .coordinateSpace(name: "companionScroll")
            }
            .background(palette.background)
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $preview) { item in CompanionHomePreview(item: item) }
            .fullScreenCover(item:$roomEditor) { session in RoomEditorView(state:session.state) }

        }
        .tint(palette.accent).fontDesign(palette.fontDesign).preferredColorScheme(palette.colorScheme)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .celebrationBlocked(by: preview != nil || roomEditor != nil)
    }

    private func grid(_ items: [WardrobeItem]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                let owned = wardrobe.state.owned.contains(item.id)
                Button { preview = item } label: {
                    CompanionProductTile(
                        name: item.name,
                        status: owned ? (wardrobe.selected(item) ? String(localized: "Equipped") : String(localized: "Owned")) : item.unlock.label,
                        symbol: owned ? (wardrobe.selected(item) ? "checkmark.circle.fill" : "checkmark") : (item.unlock.price == nil ? "lock.fill" : "circle.circle"),
                        selected: wardrobe.selected(item), accent: palette.accent, surface: palette.surface
                    ) { WardrobeThumbnail(item: item) }
                }
                .buttonStyle(.plain).buttonPressHaptic(false)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Preview before choosing")
                .accessibilityIdentifier("companion.item.\(item.id)")
            }
        }
    }

    private var displayedCategories: [WardrobeCategory] {
        category.map { [$0] } ?? WardrobeCategory.allCases
    }

    private var displayedItems: [WardrobeItem] {
        WardrobeCatalog.items.filter { (category == nil || $0.category == category) && WardrobeArt.available($0) }
    }

}

private struct WardrobeThumbnail: View {
    let item: WardrobeItem
    @State private var image: CGImage?
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().interpolation(.none).scaledToFit() }
            else { Image(systemName: item.slot == .colorway ? "paintpalette" : "square.dashed").foregroundStyle(.secondary) }
        }
        .task(id: item.id) {
            let item = item
            let decoded = await Task.detached(priority: .utility) {
                if item.slot == .colorway {
                    return await WardrobeFrameCache.shared.image("h01", colorway: item.id)
                }
                if item.slot == .room { return WardrobeArt.home.rooms[item.id].flatMap { WardrobeArt.decode($0.file, folder: "Home") } }
                if WardrobeSlot.furniture.contains(item.slot) { return WardrobeArt.home.items[item.id].flatMap { WardrobeArt.decode($0.file, folder: "Home") } }
                return WardrobeArt.decode(item.id + ".png", folder: "Wardrobe")
            }.value
            guard !Task.isCancelled else { return }
            image = decoded
        }
    }
}
