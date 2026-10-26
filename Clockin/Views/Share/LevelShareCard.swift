import SwiftUI

/// The level-up card as a picture: the stage on its final frame, the crest
/// with the new level, the banner, the rank and a Clockin mark. Drawn with
/// the card's own pieces, so what people share is what they saw.
struct LevelShareCard: View {
    let snapshot: LevelShareSnapshot
    let format: LevelShareFormat
    let showsHours: Bool

    private var style: LevelPrestige { .init(level: snapshot.level) }
    private var companion: Bool { LevelShareLayout.showsCompanion(format, enabled: snapshot.companion) }

    var body: some View {
        let size = format.size
        VStack(spacing: 0) {
            // Without the companion the stage is shorter; the block sits in
            // the middle instead of leaving the bottom half empty.
            Spacer(minLength: 0)
            LevelUpStage(level: snapshot.level, t: LevelUpCurve.still, companion: companion, moving: false)
                .frame(width: size.width, height: LevelShareLayout.stageHeight(format, companion: snapshot.companion))
            banner.padding(.horizontal, 24).padding(.top, format == .story ? 10 : 2)
            if format == .story {
                rank.padding(.horizontal, 28).padding(.top, 18)
            } else {
                rankLine.padding(.horizontal, 28).padding(.top, 12)
            }
            Spacer(minLength: 0)
            footer.padding(.horizontal, 28).padding(.bottom, format == .story ? 24 : 18)
        }
        .frame(width: size.width, height: size.height)
        .background { LevelUpBackdrop(stage: style.stage).equatable() }
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    private var banner: some View {
        let title = String(localized: "Level up", bundle: .app).uppercased(with: AppLanguage.locale)
        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                LevelUpRule(style: style, leading: true).frame(maxWidth: 56)
                Text(verbatim: title)
                    .font(.system(size: 25, weight: .heavy).width(.expanded))
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(LinearGradient(colors: [.white, style.highlight, style.tint],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.6), radius: 0, y: 2)
                    .shadow(color: style.tint.opacity(0.55), radius: 12)
                LevelUpRule(style: style, leading: false).frame(maxWidth: 56)
            }
            if showsHours {
                Text(snapshot.hours == 1 ? "1 hour of focus"
                     : "\(snapshot.hours.formatted(.number.locale(AppLanguage.formatLocale))) hours of focus")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
        }
        .multilineTextAlignment(.center)
    }

    /// The story's rank panel, as on the card, with the level beside it.
    private var rank: some View {
        HStack(spacing: 14) {
            PrestigeInsignia(style: style).frame(width: 30, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(style.name).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(.white)
                Text(style.detail).font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            .lineLimit(2).minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            levelMark
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background { LevelUpPanel(style: style, glow: 0) }
    }

    /// The post has one line for the rank, over a hairline.
    private var rankLine: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PrestigeInsignia(style: style).frame(width: 19, height: 22)
                Text(style.name).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(.white)
                Spacer(minLength: 8)
                levelMark
            }
            Rectangle().fill(style.highlight.opacity(0.25)).frame(height: 1)
        }
    }

    private var levelMark: some View {
        Text(verbatim: "LV \(snapshot.level)")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(style.highlight.opacity(0.9))
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: "CLOCKIN")
                .font(.system(size: 12, weight: .black)).tracking(3)
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 8)
            if LevelShareLayout.showsStreak(snapshot.streak) {
                HStack(spacing: 4) {
                    Text("Streak").foregroundStyle(style.highlight.opacity(0.9))
                    Text(verbatim: "·")
                    Text("\(snapshot.streak) days")
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                .padding(.trailing, 10)
            }
            Text(snapshot.date.formatted(.dateTime.locale(AppLanguage.formatLocale).month(.abbreviated).day().year()))
                .font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.5))
        }
        .lineLimit(1).minimumScaleFactor(0.8)
    }

    /// The card rendered at 3x as PNG data, with the image for a preview.
    @MainActor
    static func render(snapshot: LevelShareSnapshot, format: LevelShareFormat, showsHours: Bool) -> (png: Data, image: CGImage)? {
        let renderer = ImageRenderer(content:
            LevelShareCard(snapshot: snapshot, format: format, showsHours: showsHours)
                .environment(\.displayScale, 3)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, .large)
                .environment(\.locale, AppLanguage.locale))
        renderer.scale = 3
        renderer.isOpaque = true
        guard let image = renderer.cgImage else { return nil }
        #if canImport(UIKit)
        guard let data = UIImage(cgImage: image).pngData() else { return nil }
        #else
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return nil }
        #endif
        return (data, image)
    }
}

#if DEBUG
/// `--level-share-render DIR` writes the card for a few levels in both
/// formats to DIR and quits, for looking at the pictures.
enum LevelShareRenderFixture {
    static func runIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--level-share-render"), arguments.indices.contains(index + 1) else { return }
        let folder = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Task { @MainActor in
            for (level, hours, streak, companion) in [(12, 55, 1, true), (75, 370, 9, true), (450, 2245, 23, false)] {
                let snapshot = LevelShareSnapshot(level: level, hours: hours, xp: (level - 1) * 500 + 180, streak: streak,
                                                  date: Date(timeIntervalSince1970: 1_792_500_000), companion: companion)
                for format in LevelShareFormat.allCases {
                    for showsHours in [true, false] where showsHours || format == .story {
                        guard let rendered = LevelShareCard.render(snapshot: snapshot, format: format, showsHours: showsHours) else {
                            print("LEVEL_SHARE ERROR: level \(level) \(format)"); exit(1)
                        }
                        let name = "level-\(level)-\(format.rawValue.lowercased())\(showsHours ? "" : "-nohours").png"
                        try? rendered.png.write(to: folder.appendingPathComponent(name))
                        print("LEVEL_SHARE \(name) \(rendered.image.width)x\(rendered.image.height)")
                    }
                }
            }
            exit(0)
        }
    }
}
#endif
