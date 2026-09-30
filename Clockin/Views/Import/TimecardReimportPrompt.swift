import SwiftUI

/// Iki kez ice aktarilmis puantaj kayitlari varsa kullanicidan puantaji bastan yeniden
/// ice aktarmasini ister.
///
/// Sync'ten once her cihaz ayni dokumu kendi kimlikleriyle ice aktariyordu; ilk birlestirme
/// birebir aynilari tekillestirdi ama birkac dakika farkli satirlari iki is sandi ve saatler
/// sisti. Puantaj isin resmi kaydidir: tam donemi kapsayan bir ice aktarma dosyada olmayan
/// her kaydi temizler. Kopyasi olmayan kullanici hicbir sey gormez; "Sonra" bir gun susturur.
private struct TimecardReimportPrompt: ViewModifier {
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var sync = SyncCoordinator.shared
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.TimecardReimportSnoozedUntil") private var snoozedUntil: Double = 0
    @State private var showsAlert = false
    @State private var showsImport = false

    func body(content: Content) -> some View {
        let found = store.importedTwice
        content
            .task(id: found.pairs) {
                // Acilis ekranlari ve ilk birlestirme once gelsin.
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                showsAlert = found.pairs > 0 && sync.pendingFirstMerge == nil
                    && Date.now.timeIntervalSinceReferenceDate >= snoozedUntil
            }
            .alert("Re-import your timecards", isPresented: $showsAlert) {
                Button("Import timecards") { showsImport = true }
                Button("Later", role: .cancel) {
                    snoozedUntil = Date.now.addingTimeInterval(24 * 3600).timeIntervalSinceReferenceDate
                }
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
