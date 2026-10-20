import AppKit
import SwiftUI

/// Today's notice for a hidden menu bar item.
struct MenuBarHiddenCard: View {
    @ObservedObject var visibility = MenuBarVisibility.shared
    @ObservedObject var store: ClockStore
    @State private var copied = false
    @State private var testing = false
    @State private var result: MenuBarProbe.TestResult? = MenuBarProbe.lastTest

    var body: some View {
        if visibility.showsNotice {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Clockin’s icon isn’t showing in the menu bar")
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
                // No cause is named before the test: it differs from Mac to Mac.
                Text("macOS hasn’t placed Clockin’s icon in the menu bar. The reason differs from Mac to Mac, so test it first: Clockin briefly adds two test icons and checks whether macOS shows them. The pinned timer keeps the timer on screen meanwhile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let result { MenuBarTestResultText(result: result) }
                // Things to try, in order; the last one gathers what to send us.
                HStack(spacing: 14) {
                    Button(testing ? "Testing…" : "Test menu bar") {
                        testing = true
                        MenuBarController.shared.testPlacement { outcome in
                            result = outcome
                            testing = false
                        }
                    }
                    .disabled(testing)
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

/// What the menu bar test found, in words.
struct MenuBarTestResultText: View {
    var result: MenuBarProbe.TestResult

    var body: some View {
        Group {
            switch result.verdict {
            case .shown:
                Text("Clockin’s icon is in the menu bar now.")
            case .itemOnly:
                Text("The test icons appeared but Clockin’s own did not, so Clockin made its icon again the same way as a test icon. If it still doesn’t show, copy the details and send them to us.")
            case .noRoom:
                Text("The menu bar has no room left: macOS took the test icons in but kept them off the bar too. Remove some icons (hold ⌘ and drag them out) or use the pinned timer.")
            case .notAllowed:
                Text("macOS didn’t take any of Clockin’s icons into the menu bar, not even the test icons. A full menu bar looks different, so this is decided by macOS for the whole app, not by Clockin’s settings. Check that Clockin is allowed in System Settings > Menu Bar. If Clockin isn’t listed there, restart the Mac and test again; if nothing changes, copy the details and send them to us.")
            }
        }
        .font(.caption.weight(.medium))
        .fixedSize(horizontal: false, vertical: true)
    }
}
