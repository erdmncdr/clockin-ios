import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

private struct LevelPNG: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName("Clockin-level-up.png")
    }
}

/// Share from the level-up card: the card itself as a picture, with the
/// format and whether the hours show, and the picture large on the screen.
@MainActor
struct ShareLevelView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: LevelShareSnapshot
    @State private var format: LevelShareFormat = .story
    @State private var showsHours = true
    @State private var png: LevelPNG?
    @State private var preview: Image?
    @State private var status: String?
    @State private var selectionFeedback = HapticSignal()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let preview {
                        preview.resizable().scaledToFit()
                            .frame(maxHeight: 440)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                            .accessibilityLabel("Level up image preview")
                            .accessibilityValue(String(localized: "Level \(snapshot.level)", bundle: .app) + ", " + LevelPrestige(level: snapshot.level).name)
                    }
                    VStack(spacing: 12) {
                        Picker("Format", selection: $format.hapticSelection($selectionFeedback)) {
                            ForEach(LevelShareFormat.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).labelsHidden().accessibilityLabel("Format")
                        Toggle("Show hours of focus", isOn: $showsHours.hapticSelection($selectionFeedback))
                            .font(.subheadline)
                    }.padding(16).card(palette)
                    if let png, let preview {
                        ShareLink(item: png, preview: SharePreview(String(localized: "Level \(snapshot.level)", bundle: .app), image: preview)) {
                            Label("Share image", systemImage: "square.and.arrow.up")
                        }.buttonStyle(PrimaryActionButtonStyle(palette: palette))
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.setData(png.data, forPasteboardType: UTType.png.identifier)
                            #else
                            NSPasteboard.general.clearContents()
                            guard NSPasteboard.general.setData(png.data, forType: .png) else {
                                status = String(localized: "Could not copy image. Please try again.", bundle: .app)
                                return
                            }
                            #endif
                            status = String(localized: "PNG copied to clipboard.", bundle: .app)
                        } label: { Label("Copy image", systemImage: "doc.on.doc") }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Retry image rendering", action: render)
                    }
                    if let status {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(16)
            }
            .background(palette.background)
            .navigationTitle("Share level up")
            .inlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .hapticFeedback(selectionFeedback)
        .tint(palette.accent).fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
        .onAppear(perform: render)
        .onChange(of: format) { render() }
        .onChange(of: showsHours) { render() }
        .transaction { if reduceMotion { $0.animation = nil } }
    }

    private func render() {
        status = nil
        guard let rendered = LevelShareCard.render(snapshot: snapshot, format: format, showsHours: showsHours) else {
            png = nil
            preview = nil
            status = String(localized: "Could not create image. Please try again.", bundle: .app)
            return
        }
        png = LevelPNG(data: rendered.png)
        preview = Image(decorative: rendered.image, scale: 3)
    }
}
