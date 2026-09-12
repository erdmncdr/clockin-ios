import SwiftUI

@MainActor
struct DashboardLevelBadge: View {
    @EnvironmentObject private var store: ClockStore
    let showInsights: () -> Void
    @State private var level = 1
    @State private var xp = 0
    @State private var didLoad = false
    /// Yalnizca seviye yukseldiginde artar; parlama buna bagli.
    @State private var levelUps = 0
    /// Veri her degistiginde artar ve hesaplamayi yeniden baslatir.
    @State private var dataVersion = 0

    var body: some View {
        Button(action: showInsights) {
            LevelBadge(level: level, xp: xp, levelUps: levelUps)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Level \(level), \(xp) XP")
        .accessibilityValue("\(500 - xp % 500) XP to next level")
        .accessibilityHint("Opens your level and badges")
        // Once yalnizca dakikada bir hesaplaniyordu, veri degisince degil.
        // Gecmis sureyle baslatilan 4 saatlik bir oturum iptal edildiginde
        // seviye bir dakika kadar yuksek kaliyordu; Rozetler sekmesi ayni anda
        // dogru seviyeyi gosterdigi icin iki ekran birbirini tutmuyordu.
        //
        // Simdi her kayit degisikligi (iptal, bitirme, silme, duzenleme, ice
        // aktarma, geri yukleme) hemen yeniden hesaplatir. Zamanla degisen tek
        // sey calisan oturumun suresi; o yuzden yalnizca calisirken dakikada
        // bir tazelenir. Store bildirimleri saniyede gelmedigi icin tarama
        // maliyeti degismiyor.
        .onReceive(store.objectWillChange) { _ in dataVersion &+= 1 }
        .task(id: dataVersion) {
            // `objectWillChange` deger yazilmadan once gelir; gorev bir sonraki
            // turda basladigi icin burada okunan veri yenisidir.
            refresh()
            while store.running?.isPaused == false {
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
                refresh()
            }
        }
    }

    private func refresh() {
        let stats = InsightsSnapshot(store: store, now: .now, dailyGoal: 0, monthlyGoal: 0)
        // Ilk yuklemede ve seviye duserken kutlama yok; yalnizca gercek yukselis.
        if didLoad, stats.level > level { levelUps &+= 1 }
        level = stats.level
        xp = stats.xp
        didLoad = true
    }
}

private struct LevelBadge: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let level: Int
    let xp: Int
    let levelUps: Int

    private var progress: Double { min(max(Double(xp % 500) / 500, 0), 1) }

    var body: some View {
        // Kupa yerine dolgunun yuzdesi. Kupa hicbir seye karsilik gelmiyordu;
        // rozetin anlatmak istedigi zaten bir sonraki seviyeye ne kadar
        // kaldigi ve o sayi arkadaki dolguyu da okunur kiliyor.
        HStack(spacing: 6) {
            Text("LV \(level)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.accent.opacity(0.65))
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(palette.accent.opacity(0.12))
                GeometryReader { geometry in
                    let fill = geometry.size.width * progress
                    // Isik dolgunun bittigi yerde bitsin: tarama rozetin
                    // tamamini gezerse ilerlemeyi degil rozeti anlatir.
                    //
                    // Kirpma dolgunun kendi kapsul sekliyle yapilir. Dikdortgen
                    // kirpma, yuvarlak ucun uzerinde duz bir cizgi birakiyordu.
                    Capsule(style: .continuous)
                        .fill(palette.accent.opacity(0.22))
                        .frame(width: fill)
                        .overlay {
                            if !reduceMotion { BadgeSweep() }
                        }
                        .clipShape(Capsule(style: .continuous))
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous).stroke(palette.accent.opacity(0.26), lineWidth: 1)
            }
        }
        .phaseAnimator([false, true, false], trigger: levelUps) { content, highlighted in
            content.overlay {
                Capsule(style: .continuous)
                    .stroke(palette.accent.opacity(!reduceMotion && highlighted ? 0.85 : 0), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .brightness(!reduceMotion && highlighted ? 0.12 : 0)
        } animation: { highlighted in
            reduceMotion ? nil : .easeOut(duration: highlighted ? 0.2 : 0.7)
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
    }
}

private struct BadgeSweep: View {
    private enum Phase: CaseIterable { case start, end }

    var body: some View {
        GeometryReader { geometry in
            // Bant dolgunun kendisine gore olculur. Sabit genislikte bir
            // bant, dar bir dolguyu bastan sona kaplayip taramak yerine
            // tek parca yanip sonuyordu.
            let band = max(6, geometry.size.width * 0.5)
            LinearGradient(
                colors: [.clear, .white.opacity(0.45), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: band, height: geometry.size.height)
            // Once saniyede 30 kez yeniden cizilen bir TimelineView'du: 120 Hz
            // ekranda kayan isik takiliyordu ve her karede gorunum bastan
            // hesaplaniyordu. Simdi yalnizca uc noktalar veriliyor, ara kareleri
            // sistem ekranin hizinda ciziyor. 4,2 saniye bekleme ve 1,8 saniye
            // tarama; basa donus animasyonsuz.
            //
            // Bekleme ayri bir asama olarak yazilinca deger degismedigi icin
            // sistem onu aninda geciyordu ve isik durmadan tariyordu. Gecikme
            // taramanin kendisine ekleniyor.
            .phaseAnimator(Phase.allCases) { content, phase in
                content.offset(x: phase == .start ? -band : geometry.size.width)
            } animation: { phase in
                switch phase {
                case .start: nil
                case .end: .linear(duration: 1.8).delay(4.2)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
