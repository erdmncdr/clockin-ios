#if DEBUG
import SwiftUI

/// Every skin on the moving companion, in its room and large on its own, with
/// its sheen and aura. Launch with `--skin-preview`; add `--skin <id>` to show
/// one skin in several moods.
struct CompanionSkinPreview: View {
    private var only: String? {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "--skin").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    }
    private var skins: [WardrobeItem] {
        WardrobeCatalog.items.filter { $0.slot == .skin && (only == nil || $0.id == only) }
    }
    private var tiles: [(id: String, item: WardrobeItem, mood: MascotMood)] {
        let moods: [MascotMood] = only == nil ? [.hello] : [.hello, .celebrate, .working, .coffee, .tired]
        return skins.flatMap { item in moods.map { (item.id + "/" + $0.rawValue, item, $0) } }
    }
    private func outfit(_ id: String) -> WardrobeState {
        var state = WardrobeState()
        state.owned.insert(id)
        state.equipped[WardrobeSlot.skin.rawValue] = id
        return state
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(tiles, id: \.id) { tile in
                    VStack(spacing: 4) {
                        ClockinMotionMascot(mood: tile.mood, outfitOverride: outfit(tile.item.id))
                            .frame(width: 150, height: 150)
                        Text(tile.item.name).font(.caption.bold()).foregroundStyle(.white)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.09, green: 0.11, blue: 0.17), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(12)
        }
        .background(Color.black)
        .environment(\.clockinContentActive, true)
    }
}
#endif
