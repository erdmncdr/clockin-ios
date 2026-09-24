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
    var historyAmount: HistoryAmount?
    var historyShowsTRY = false

    private var isTimer: Bool { SessionDisplay.isClockin(session) }

    private var title: String {
        if showsDay {
            return session.start.formatted(.dateTime.locale(AppLanguage.formatLocale).month(.abbreviated).day().hour().minute())
        }
        let start = session.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLanguage.formatLocale))
        let end = session.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLanguage.formatLocale))
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
                if SessionDisplay.isMatched(session) {
                    Label(SessionDisplay.subtitle(session), systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                } else {
                    Text(SessionDisplay.subtitle(session))
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
                Text((historyAmount?.value(showTRY: historyShowsTRY) ?? store.earnings(for: session))
                    .money(code: historyAmount?.code(currency: store.currencyCode, showTRY: historyShowsTRY) ?? store.currencyCode))
                    .font(.caption)
                    .foregroundStyle(palette.accent)
                if let amount = historyAmount, store.currencyCode == "USD", let converted = amount.converted {
                    Text((historyShowsTRY ? amount.earned : converted).money(code: historyShowsTRY ? "USD" : "TRY"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                } else if historyAmount == nil, showsTRY, store.currencyCode == "USD",
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
