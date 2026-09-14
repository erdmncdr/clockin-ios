import SwiftUI

/// Tek bir kaydin satiri. Kendi dolgusu yok; kapsayici belirliyor.
struct SessionRow: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette

    let session: WorkSession
    /// Gun basligi altinda listelenirken tarih tekrar yazilmaz, saat araligi
    /// gosterilir.
    var showsDay = true
    /// Baska bir kaydin uzerine biniyorsa saatler isaretlenir. Bu kayitlar
    /// gun toplamina iki kez giriyor ve gunu imkansiz bir toplama cikarabiliyor.
    var conflicts = false
    /// USD hesaplarda o gunun kuruyla TL karsiligi. Yalnizca gecmiste; kucuk
    /// listelerde (cakisma uyarisi gibi) satiri gereksiz uzatmasin.
    var showsTRY = false

    /// Resmi dokumle duzeltilmis bir sayac kaydi.
    ///
    /// Mac her `matchedExternalSource` tasiyan satira "Matched" yaziyor. Yeni
    /// ice aktarilan kayitlar da kendi kaynaklariyla isaretlendigi icin bu,
    /// her dokum satirinda ayni etiketi tekrarlamak olurdu; ikon zaten ice
    /// aktarildigini soyluyor. Bilgi tasiyan durum, sayacin dokume gore
    /// duzeltilmis olmasi.
    private var matchedSource: String? {
        guard let source = session.matchedExternalSource, source != session.source else { return nil }
        return source
    }

    private var isTimer: Bool { session.source == "Clockin" }

    private var title: String {
        if showsDay {
            return session.start.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
        let start = session.start.formatted(date: .omitted, time: .shortened)
        let end = session.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isTimer ? "bolt.fill" : "arrow.down.doc.fill")
                .font(.footnote)
                .foregroundStyle(isTimer ? palette.accent : palette.secondary)
                .frame(width: 32, height: 32)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    if conflicts {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Overlaps another entry")
                    }
                }
                if let matchedSource {
                    Label("Matched \(matchedSource)", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                } else {
                    Text(session.note.isEmpty ? session.source : session.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(DurationText.compact(session.duration))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(store.earnings(for: session).money(code: store.currencyCode))
                    .font(.caption)
                    .foregroundStyle(palette.accent)
                if showsTRY, store.currencyCode == "USD",
                   let rate = exchangeRates.rate(onCalendarDay: session.start) {
                    Text((store.earnings(for: session) * rate).money(code: "TRY"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        // Dugme etiketi olarak kullanildiginda metin vurgu rengini almasin.
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
