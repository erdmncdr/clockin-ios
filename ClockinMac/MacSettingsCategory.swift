import SwiftUI

enum MacSettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case timer = "Timer & goals"
    case pay = "Pay & currency"
    case menuBar = "Menu bar"
    case notifications = "Notifications"
    case icloud = "iCloud"
    case data = "Data & import"
    case help = "Help & about"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .timer: "timer"
        case .pay: "banknote"
        case .menuBar: "menubar.rectangle"
        case .notifications: "bell"
        case .icloud: "icloud"
        case .data: "tray.and.arrow.down"
        case .help: "questionmark.circle"
        }
    }
}

/// Ayarlar kategorileri. Sistem kenar cubugu secimi uygulamanin sabit
/// vurgusuyla (yesil) ciziliyor ve temayi dinlemiyordu; mavi temada yesil bir
/// blok kaliyordu. Ayni olcu ve davranis, secili temanin vurgusuyla.
struct MacSettingsSidebar: View {
    @Binding var selection: MacSettingsCategory?
    @Environment(\.palette) private var palette
    @FocusState private var focused: Bool
    @State private var hovered: MacSettingsCategory?

    private var current: MacSettingsCategory { selection ?? .general }

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(MacSettingsCategory.allCases) { item in
                    row(item)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.never)
        .background(palette.surface)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.upArrow) { step(-1) }
        .onKeyPress(.downArrow) { step(1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings categories")
    }

    private func row(_ item: MacSettingsCategory) -> some View {
        let isSelected = item == current
        return Button {
            selection = item
            focused = true
        } label: {
            Label {
                Text(LocalizedStringKey(item.rawValue)).lineLimit(1)
            } icon: {
                Image(systemName: item.symbol)
                    .foregroundStyle(isSelected ? Color.white : palette.accent)
                    .frame(width: 18)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? palette.accent : (hovered == item ? Color.primary.opacity(0.07) : .clear))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { if hovered != item { hovered = item } }
            else if hovered == item { hovered = nil }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func step(_ offset: Int) -> KeyPress.Result {
        let all = MacSettingsCategory.allCases
        guard let index = all.firstIndex(of: current) else { return .ignored }
        let next = index + offset
        guard all.indices.contains(next) else { return .handled }
        selection = all[next]
        return .handled
    }
}
