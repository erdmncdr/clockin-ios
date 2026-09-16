import SwiftUI

/// Bir kayitla ilgili acilan ekranlar. Bugun ve Gecmis ayni sheet'leri
/// kullaniyor; ayri boolean bayraklar yerine tek bir secim tutuluyor.
enum SessionSheet: Identifiable {
    case newEntry
    case edit(WorkSession)
    case summary(WorkSession)
    case manualStart

    var id: String {
        switch self {
        case .newEntry: "new"
        case .edit(let session): "edit-\(session.id)"
        case .summary(let session): "summary-\(session.id)"
        case .manualStart: "manual-start"
        }
    }
}

extension View {
    func sessionSheets(_ sheet: Binding<SessionSheet?>) -> some View {
        modifier(SessionSheetsModifier(sheet: sheet))
    }

    /// Silmeden once onay ister. Bagli deger `nil` degilse uyari acilir.
    func deleteSessionAlert(_ pending: Binding<WorkSession?>) -> some View {
        modifier(DeleteSessionAlert(pending: pending))
    }
}

private struct SessionSheetsModifier: ViewModifier {
    @Environment(\.palette) private var palette
    @Binding var sheet: SessionSheet?

    func body(content: Content) -> some View {
        content.sheet(item: $sheet) { destination in
            Group {
                switch destination {
                case .newEntry: ManualEntryView()
                case .edit(let session): ManualEntryView(editing: session)
                case .summary(let session): SessionSummaryView(session: session)
                case .manualStart: ManualStartView()
                }
            }
            // Renk semasi tercihi en yakin sunuma uygulanir; sheet kendi
            // sunumu oldugu icin tekrar verilmesi gerekiyor.
            .preferredColorScheme(palette.colorScheme)
        }
    }
}

private struct DeleteSessionAlert: ViewModifier {
    @EnvironmentObject private var store: ClockStore
    @Binding var pending: WorkSession?

    func body(content: Content) -> some View {
        content
            .hapticFeedback(.destructiveConfirmation, trigger: pending?.id) { _, new in new != nil }
            .alert(
            "Delete this session?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { session in
            Button("Delete", role: .destructive) { store.deleteSession(id: session.id) }
            Button("Keep", role: .cancel) {}
        } message: { _ in
            Text("Its time and earnings will be removed permanently.")
        }
    }
}
