import SwiftUI
import UIKit
import CoreTransferable
import UniformTypeIdentifiers

private struct StatsPNG: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName("Clockin-stats.png")
    }
}

struct StatsShareSnapshot: Identifiable {
    let id = UUID()
    let date: Date
    let values: [StatsShareField: String]

    @MainActor
    init(store: ClockStore, dailyGoal: Double, monthlyGoal: Double) {
        let now = Date()
        let stats = InsightsSnapshot(store: store, now: now, dailyGoal: dailyGoal, monthlyGoal: monthlyGoal)
        date = now
        var fields: [StatsShareField: String] = [
            .time: DurationText.compact(stats.totalDuration),
            .earnings: stats.totalEarnings.money(code: store.currencyCode),
            .sessions: "\(stats.sessionCount)", .activeDays: "\(stats.daily.count)",
            .streak: String(localized: "\(stats.currentStreak) days"), .longestStreak: String(localized: "\(stats.longestStreak) days"),
            .badges: "\(stats.badges.filter(\.unlocked).count)", .xp: "\(stats.xp)", .level: "\(stats.level)",
            .fullDays: "\(stats.fullDays)", .longDays: "\(stats.longDays)",
            .bigMonths: "\(stats.bigMonths)", .momentum: String(format: "%+.0f%%", stats.monthTrend * 100),
            .weekday: stats.bestWeekday.map { Calendar.current.weekdaySymbols[$0 - 1] } ?? String(localized: "No sessions"),
            .hour: stats.bestStartHour.map { String(format: "%02d:00", $0) } ?? String(localized: "No sessions")
        ]
        if let day = stats.bestDay {
            fields[.bestDay] = day.formatted(.dateTime.month(.abbreviated).day())
            fields[.bestDayDuration] = DurationText.compact(stats.bestDayDuration)
        }
        values = fields
    }
}

@MainActor
struct ShareStatsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: StatsShareSnapshot
    @State private var privacy: StatsSharePrivacy = .publicStats
    @State private var page: StatsSharePage = .overview
    @State private var mode: StatsShareMode = .all
    @State private var png: StatsPNG?
    @State private var preview: UIImage?
    @State private var status: String?

    @State private var selectionFeedback = HapticSignal()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("SHARE YOUR STATS")
                        Picker("Privacy", selection: $privacy.hapticSelection($selectionFeedback)) {
                            ForEach(StatsSharePrivacy.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).accessibilityLabel("Stats privacy")
                        Text("Private hides headline time, earnings and best-day duration. XP, level, streaks and rhythm remain visible. It is not anonymization.")
                            .font(.caption).foregroundStyle(.secondary)
                        Picker("Page", selection: $page.hapticSelection($selectionFeedback)) {
                            ForEach(StatsSharePage.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).accessibilityLabel("Preview page")
                        Picker("Export", selection: $mode.hapticSelection($selectionFeedback)) {
                            ForEach(StatsShareMode.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).accessibilityLabel("Image pages")
                    }.padding(16).card(palette)
                    if let preview {
                        Image(uiImage: preview).resizable().scaledToFit()
                            .accessibilityLabel(String(localized: "\(privacy.title) stats preview, \(mode == .all ? String(localized: "all three pages") : page.title)"))
                            .accessibilityValue(previewDescription)
                    }
                    if let png, let preview {
                        ShareLink(item: png, preview: SharePreview("Clockin stats", image: Image(uiImage: preview))) {
                            Label("Share PNG", systemImage: "square.and.arrow.up")
                        }.buttonStyle(PrimaryActionButtonStyle(palette: palette))
                            .accessibilityLabel("Share stats as PNG")
                        Button {
                            UIPasteboard.general.setData(png.data, forPasteboardType: UTType.png.identifier)
                            status = String(localized: "PNG copied to clipboard.")
                        } label: { Label("Copy image", systemImage: "doc.on.doc") }
                        .buttonStyle(.bordered).accessibilityLabel("Copy stats PNG to clipboard")
                    }
                    if let status {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                    if png == nil {
                        Button("Retry image rendering", action: render)
                    }
                }.padding(16)
            }
            .background(palette.background)
            .navigationTitle("Share stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .hapticFeedback(selectionFeedback)
        .tint(palette.accent).fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
        .onAppear(perform: render)
        .onChange(of: privacy) { render() }
        .onChange(of: page) { render() }
        .onChange(of: mode) { render() }
        .onChange(of: displayScale) { render() }
        .onChange(of: palette.background) { render() }
        .onChange(of: palette.accent) { render() }
        .onChange(of: palette.colorScheme) { render() }
        .onChange(of: palette.fontDesign) { render() }
        .transaction { if reduceMotion { $0.animation = nil } }
    }

    private var previewDescription: String {
        mode.pages(current: page).map { page in
            page.title + ": " + StatsShareFields.rows(page: page, privacy: privacy, values: snapshot.values)
                .map { "\($0.field.title): \($0.value)" }.joined(separator: ", ")
        }.joined(separator: ". ")
    }

    private func render() {
        // Tek anlik goruntu, etkin oturum ilerlese de onizleme ile paylasimi ayni tutar.
        png = nil
        preview = nil
        status = nil
        let content = VStack(spacing: 12) {
            ForEach(mode.pages(current: page)) { selected in
                StatsShareCard(snapshot: snapshot, privacy: privacy, page: selected)
            }
        }
        .padding(12).background(palette.background)
        .environment(\.palette, palette)
        .environment(\.colorScheme, palette.colorScheme)
        .environment(\.dynamicTypeSize, .medium)
        .fontDesign(palette.fontDesign)
        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        renderer.isOpaque = true
        guard let image = renderer.uiImage, let data = image.pngData() else {
            status = String(localized: "Could not create image. Please try again.")
            return
        }
        preview = image
        png = StatsPNG(data: data)
    }
}

private struct StatsShareCard: View {
    @Environment(\.palette) private var palette
    let snapshot: StatsShareSnapshot
    let privacy: StatsSharePrivacy
    let page: StatsSharePage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("CLOCKIN").font(.system(size: 14, weight: .black)).tracking(3)
                Spacer()
                Text("\((StatsSharePage.allCases.firstIndex(of: page) ?? 0) + 1) / 3")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            Rectangle().fill(palette.accent).frame(width: 42, height: 4).padding(.top, 12)
            Text(title).font(.system(size: 32, weight: .black)).tracking(-1)
            Text(snapshot.date.formatted(.dateTime.month(.wide).day().year()))
                .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            VStack(spacing: 16) {
                ForEach(StatsShareFields.rows(page: page, privacy: privacy, values: snapshot.values)) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.field.title.uppercased(with: .current))
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text(row.value).font(.system(size: 18, weight: .bold, design: palette.fontDesign))
                            .lineLimit(1).minimumScaleFactor(0.55)
                    }.accessibilityElement(children: .combine)
                }
            }.padding(.top, 10)
            Spacer(minLength: 0)
            HStack {
                Text("STATS REWIND")
                Spacer()
                Text(privacy.title.uppercased(with: .current))
            }.font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(28).frame(width: 350, height: 540)
        .foregroundStyle(.primary)
        .background(palette.background)
        .overlay(alignment: .topTrailing) {
            Circle().fill(palette.accent.opacity(0.12)).frame(width: 160, height: 160)
                .offset(x: 65, y: -85).allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).stroke(palette.surfaceStroke) }
    }

    private var title: String {
        switch page {
        case .overview: privacy == .publicStats ? String(localized: "FOCUS\nIN NUMBERS") : String(localized: "FOCUS\nJOURNEY")
        case .rhythm: String(localized: "RHYTHM\nREPORT")
        case .milestones: String(localized: "MILESTONES\n& MOMENTUM")
        }
    }
}
