import SwiftUI
import UIKit

/// The same try-first flow is used for clothing, colors, rooms and furniture.
struct CompanionHomePreview: View {
    let item: WardrobeItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var wardrobe = WardrobeStore.shared
    @State private var layout: CompanionHomeLayout
    @State private var lamp: Bool
    @State private var time = "Now"
    @State private var activity: CompanionHomeActivity?
    @State private var purchaseError = false
    @State private var purchased = false
    @State private var visible = false
    @State private var sceneVisible = false

    init(item: WardrobeItem) {
        self.item = item
        _layout = State(initialValue: WardrobeStore.shared.state.homeLayout)
        _lamp = State(initialValue: WardrobeStore.shared.state.homeLampOn)
    }
    private var draft: WardrobeState {
        var copy = wardrobe.state.previewing(item)
        if item.isHomeItem { copy.homeLayout = layout; copy.homeLampOn = lamp }
        return copy
    }
    private var light: CompanionHomeLight? {
        switch time { case "Day": .day; case "Evening": .dusk; case "Night": .night; default: nil }
    }
    private var owned: Bool { wardrobe.state.owned.contains(item.id) }
    private var canChoose: Bool { owned || (item.unlock.price.map { $0 <= wardrobe.balance } ?? false) }
    private var actionTitle: String {
        if purchased { return String(localized: "Done", bundle: .app) }
        if owned { return item.isHomeItem ? String(localized: "Use in my room", bundle: .app) : String(localized: "Wear this", bundle: .app) }
        if let price = item.unlock.price { return String(localized: "Buy for \(price) coins", bundle: .app) }
        return item.unlock.label
    }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                let viewportHeight = viewport.size.height
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        CompanionHomeView(outfitCloseup: !item.isHomeItem, stateOverride: draft,
                                          activityOverride: activity, lightOverride: light)
                            .modifier(CompanionPreviewFrame(isHome: item.isHomeItem, outfitHeight: 220))
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 24))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .environment(\.clockinContentActive, visible && sceneVisible && !purchaseError)
                            .onGeometryChange(for: Bool.self) { proxy in
                                let frame = proxy.frame(in: .named("itemPreview"))
                                return frame.maxY > 0 && frame.minY < viewportHeight
                            } action: { sceneVisible = $0 }
                        if purchased {
                            Label("Purchased", systemImage: "checkmark.circle.fill")
                                .font(.title3.bold()).foregroundStyle(palette.accent)
                                .accessibilityIdentifier("companion.purchase.success")
                            Text("\(item.name) is yours and equipped.").foregroundStyle(.secondary)
                        } else {
                            Text(item.isHomeItem ? "Try it in your room" : "Try it on")
                                .font(.title3.bold())
                            // The title already says try; say what kind of item it is.
                            Text(item.category.title)
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if item.isHomeItem && !purchased {
                            DisclosureGroup("Scene options") { sceneOptions.padding(.top, 12) }
                        }
                        // A price the button already shows is not repeated here.
                        if !owned && (item.unlock.price == nil || !canChoose) {
                            Label(item.unlock.label, systemImage: item.unlock.price == nil ? "lock" : "circle.circle")
                                .font(.subheadline.weight(.semibold))
                            if !canChoose {
                                Text(item.unlock.price == nil ? "Reach the milestone to unlock." : "Keep working to earn more coins.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }.padding(20)
                }.coordinateSpace(name: "itemPreview")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    if !purchased {
                        Text("Balance: \(wardrobe.balance.formatted(.number.locale(AppLanguage.formatLocale))) coins")
                            .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Button(actionTitle) {
                        if purchased { dismiss() } else { choose() }
                    }
                    .buttonStyle(PrimaryActionButtonStyle(palette: palette))
                    .disabled(!purchased && !canChoose)
                    .accessibilityIdentifier("companion.purchase.action")
                    if !purchased && wardrobe.selected(item) && item.slot != .room && item.id != "classic" {
                        Button(item.isHomeItem ? "Remove from room" : (item.slot == .colorway ? "Use classic color" : "Take off")) {
                            wardrobe.clear(item.slot)
                            Haptics.play(.companionReaction)
                            dismiss()
                        }
                        .font(.subheadline).frame(minHeight: 44)
                        .accessibilityIdentifier("companion.item.remove")
                    }
                }.padding(16).background(palette.background)
            }
            .background(palette.background)
            .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(purchased ? "Close" : "Cancel") { dismiss() } } }
            .alert("Not enough coins", isPresented: $purchaseError) { Button("OK", role: .cancel) {} }
        }
        .tint(palette.accent).fontDesign(palette.fontDesign).preferredColorScheme(palette.colorScheme)
        .onAppear { visible = true }
        .onDisappear { visible = false; sceneVisible = false }
    }

    private var sceneOptions: some View {
        VStack(spacing: 16) {
            Picker("Room layout", selection: $layout) {
                ForEach(CompanionHomeLayout.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Window light", selection: $time) {
                ForEach(["Now", "Day", "Evening", "Night"], id: \.self) { Text(LocalizedStringKey($0)) }
            }.pickerStyle(.segmented)
            Toggle("Room lamp", isOn: $lamp)
            Picker("Companion activity", selection: $activity) {
                Text("Automatic").tag(Optional<CompanionHomeActivity>.none)
                Text("Working").tag(Optional(CompanionHomeActivity.working))
                Text("Taking a break").tag(Optional(CompanionHomeActivity.relaxing))
                if draft.furniture["floorRight"] == "companion-bed" { Text("Resting").tag(Optional(CompanionHomeActivity.sleeping)) }
            }
        }
    }

    private func choose() {
        guard !purchased else { return }
        CelebrationCenter.shared.refresh(store: store)
        let wasOwned = wardrobe.state.owned.contains(item.id)
        if wasOwned { wardrobe.equip(item) }
        else if !wardrobe.buy(item) { purchaseError = true; return }
        if item.isHomeItem { wardrobe.setHomeLayout(layout); wardrobe.setHomeLamp(lamp) }
        Haptics.play(.companionReaction)
        if wasOwned { dismiss() } else {
            purchased = true
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Purchased. \(item.name) is yours and equipped.", bundle: .app))
        }
    }
}
