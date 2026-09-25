#if DEBUG
import SwiftUI
import UIKit

/// Opt-in render/behavior fixture; a separate celebration center never changes earned XP.
struct LevelFeedbackReview: View {
    @Environment(\.palette) private var palette
    @StateObject private var center: CelebrationCenter
    @State private var shortcut: DashboardShortcut?
    @State private var result = "Checking…"
    private let mode: String
    init() {
        let args = ProcessInfo.processInfo.arguments
        let i = args.firstIndex(of: "--feedback-review")!
        mode = args.indices.contains(i + 1) ? args[i + 1] : "gallery"
        let defaults = UserDefaults(suiteName: "Clockin.Review.\(UUID().uuidString)")!
        defaults.set(499, forKey: CelebrationRules.levelKey)
        defaults.set([], forKey: CelebrationRules.badgesKey)
        _center = StateObject(wrappedValue: CelebrationCenter(defaults: defaults))
    }
    var body: some View {
        Group {
            if mode == "gallery" { LevelBadgeGallery(currentLevel: 375, xp: 187325) }
            else if mode == "pins" {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            DashboardPinnedTools { shortcut = $0 }
                        }.padding(16)
                    }.navigationTitle("Today controls").background(palette.background)
                }.sheet(item: $shortcut) { DashboardShortcutSheet(feature: $0) }
            } else if mode == "settings" {
                DashboardCustomizationView()
            } else if mode == "xp" {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 24) {
                            ForEach([1, 75, 150, 375, 500], id: \.self) { level in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Level \(level)").font(.title3.bold())
                                    Text("325 / 500 XP").font(.subheadline).foregroundStyle(.secondary)
                                    PrestigeProgressBar(level: level, progress: 0.65)
                                }.padding(16).card(palette)
                            }
                        }.padding(16)
                    }.navigationTitle("XP progress").background(palette.background)
                }
            } else {
                ZStack {
                    palette.background.ignoresSafeArea()
                    Text(result).accessibilityIdentifier("review.retention")
                }
                .background(ReviewWindowProbe(center: center))
                .overlay {
                    CelebrationOverlay(center: center, share: { result = "Share callback"; center.dismiss() }, openBadges: {}, openCompanion: {})
                }
                .task {
                    if mode == "banners" { center.previewBannersForReview(); return }
                    center.previewLevelForReview()
                    do { try await Task.sleep(for: .seconds(7)) } catch { return }
                    result = center.event?.autoDismissDelay == nil && center.event != nil ? "PASS: level card remains after 7 seconds" : "FAIL: card dismissed"
                    print(result)
                }
            }
        }
        .environment(\.palette, ClockinThemeChoice.carbon.palette)
        .preferredColorScheme(.dark)
    }
}
private struct ReviewWindowProbe: UIViewRepresentable {
    let center: CelebrationCenter
    func makeUIView(context: Context) -> ReviewWindowView { ReviewWindowView(center: center) }
    func updateUIView(_ view: ReviewWindowView, context: Context) {}
}
private final class ReviewWindowView: UIView {
    let celebrationCenter: CelebrationCenter
    init(center: CelebrationCenter) { self.celebrationCenter = center; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
    override func didMoveToWindow() {
        super.didMoveToWindow(); celebrationCenter.window = window; celebrationCenter.screenAttached()
    }
}
#endif
