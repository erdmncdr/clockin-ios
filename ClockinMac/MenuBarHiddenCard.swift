import SwiftUI

/// Today's notice for a hidden menu bar item.
struct MenuBarHiddenCard: View {
    @ObservedObject var visibility = MenuBarVisibility.shared
    @ObservedObject var store: ClockStore

    var body: some View {
        if visibility.showsNotice {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Clockin is hidden in the menu bar")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Button { visibility.dismiss() } label: {
                        Image(systemName: "xmark").font(.caption.weight(.semibold))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Dismiss tip")
                    .help("Dismiss tip")
                }
                Text("The menu bar is full, so macOS is hiding Clockin’s icon and timer. Hold ⌘ and drag other icons out of the menu bar to make room, or keep the timer on screen with the pinned timer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !store.pinVisible {
                    Button("Show pinned timer") { store.setPinned(true) }
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.medium))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("mac.menuBarHidden")
        }
    }
}
