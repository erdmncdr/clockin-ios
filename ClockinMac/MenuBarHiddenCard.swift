import AppKit
import SwiftUI

/// Today's notice for a hidden menu bar item.
struct MenuBarHiddenCard: View {
    @ObservedObject var visibility = MenuBarVisibility.shared
    @ObservedObject var store: ClockStore
    @State private var copied = false

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
                Text("macOS is not showing Clockin’s icon and timer, usually because the menu bar is full or Clockin is turned off in Menu Bar settings. Reset its position, check that Clockin is allowed in Menu Bar settings, or keep the timer on screen with the pinned timer. If it stays hidden, copy the details and send them to us.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Things to try, in order; the last one gathers what to send us.
                HStack(spacing: 14) {
                    Button("Reset position") { MenuBarController.shared.resetItemPosition() }
                    Button("Menu Bar settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    if !store.pinVisible {
                        Button("Show pinned timer") { store.setPinned(true) }
                    }
                    Button(copied ? "Copied" : "Copy details") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(MenuBarController.shared.diagnostics(), forType: .string)
                        copied = true
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("mac.menuBarHidden")
        }
    }
}
