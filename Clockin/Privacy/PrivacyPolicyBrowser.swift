import SafariServices
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
