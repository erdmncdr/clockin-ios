import SwiftUI

struct MacLiveActivityTipCard: View {
    @ObservedObject var tip = MacLiveActivityTip.shared
    var beforeOpenSettings: () -> Void = {}

    var body: some View {
        if tip.isVisible {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Seeing two timers in the menu bar?")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Button { tip.dismiss() } label: {
                        Image(systemName: "xmark").font(.caption.weight(.semibold))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Dismiss tip")
                    .help("Dismiss tip")
                }
                Text("Your iPhone’s Live Activity can also appear in the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    beforeOpenSettings()
                    IPhoneNotificationSettings.open()
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("mac.liveActivityTip")
        }
    }
}
