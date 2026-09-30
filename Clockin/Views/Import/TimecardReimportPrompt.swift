import SwiftUI

/// Iki kez ice aktarilmis puantaj kayitlari varsa kullanicidan puantaji bastan yeniden
/// ice aktarmasini ister.
///
/// Sync'ten once her cihaz ayni dokumu kendi kimlikleriyle ice aktariyordu; ilk birlestirme
/// birebir aynilari tekillestirdi ama birkac dakika farkli satirlari iki is sandi ve saatler
/// sisti. Puantaj isin resmi kaydidir: tam donemi kapsayan bir ice aktarma dosyada olmayan
/// her kaydi temizler. Kopyasi olmayan kullanici hicbir sey gormez; gosterim bir gun susturur.
private struct TimecardReimportPrompt: ViewModifier {
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var sync = SyncCoordinator.shared
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.TimecardReimportSnoozedUntil") private var snoozedUntil: Double = 0
    @State private var showsAlert = false
    @State private var showsImport = false

    private struct CheckInput: Equatable {
        let copies: Int
        let mergePending: Bool
    }

    func body(content: Content) -> some View {
        let found = store.importedTwice
        let input = CheckInput(copies: found.pairs, mergePending: sync.pendingFirstMerge != nil)
        content
            .onChange(of: input.mergePending) { _, pending in
                if pending { showsAlert = false }
            }
            .task(id: input) {
                showsAlert = false
                guard input.copies > 0, !input.mergePending else { return }
                // Acilis ekranlari ve ilk birlestirme once gelsin.
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, sync.pendingFirstMerge == nil, !showsImport,
                      Date.now.timeIntervalSinceReferenceDate >= snoozedUntil else { return }
                // Ice aktarma acilip iptal edilse de gunluk sinir korunur.
                snoozedUntil = Date.now.addingTimeInterval(24 * 3600).timeIntervalSinceReferenceDate
                showsAlert = true
            }
            .alert("Re-import your timecards", isPresented: $showsAlert) {
                Button("Import timecards") { showsImport = true }
                Button("Later", role: .cancel) {}
            } message: {
                Text("\(found.pairs) entries look imported twice and add about \(DurationText.compact(found.extra)). Import your timecard CSV covering everything from your first workday to today. Entries the file does not contain are removed after you review them.")
            }
            .sheet(isPresented: $showsImport) {
                TimecardImportView()
                    .environment(\.palette, palette)
                    .macSheetFrame()
            }
    }
}

extension View {
    /// Kopya puantaj kayitlari temizlenene kadar, gunde en fazla bir kez sorar.
    func timecardReimportPrompt() -> some View { modifier(TimecardReimportPrompt()) }
}
