#if os(iOS)
#if canImport(SafariServices)
import SafariServices
#endif
import SwiftUI

/// Presented as its own sheet, including when opened over the setup guide.
struct PrivacyPolicyBrowser: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: LiveActivityPrivacy.policyURL)
        controller.dismissButtonStyle = .close
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {
        context.coordinator.onClose = { dismiss() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onClose: { dismiss() }) }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var onClose: () -> Void
        init(onClose: @escaping () -> Void) { self.onClose = onClose }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onClose() }
    }
}
#else
import AppKit
import SwiftUI

struct PrivacyPolicyBrowser: View {
    @Environment(\.dismiss) private var dismiss
    @State private var attempted = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Privacy policy").font(.headline)
            if failed { Text("Could not open the browser. Please try again.") }
            Button("Open in browser", action: openPolicy)
            Button("Done") { dismiss() }
        }
        .padding(24)
        .task {
            guard !attempted else { return }
            attempted = true
            openPolicy()
        }
    }

    private func openPolicy() {
        if NSWorkspace.shared.open(LiveActivityPrivacy.policyURL) { dismiss() }
        else { failed = true }
    }
}
#endif
