import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
import Photos
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
    @State private var isSaving = false
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
                        #if canImport(UIKit)
                        // Stories go out from Photos on the iPhone, so saving
                        // there sits beside copying.
                        // Side by side while both labels fit in one line;
                        // stacked in Turkish at large text.
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) { saveButton(png.data); copyButton(png.data) }
                            VStack(spacing: 10) { saveButton(png.data); copyButton(png.data) }
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                        #else
                        Button(action: { copy(png.data) }) { Label("Copy image", systemImage: "doc.on.doc") }
                            .buttonStyle(.bordered)
                        #endif
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

    private func copy(_ data: Data) {
        #if canImport(UIKit)
        UIPasteboard.general.setData(data, forPasteboardType: UTType.png.identifier)
        #else
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setData(data, forType: .png) else {
            status = String(localized: "Could not copy image. Please try again.", bundle: .app)
            return
        }
        #endif
        status = String(localized: "PNG copied to clipboard.", bundle: .app)
        selectionFeedback.send(.entrySaved)
    }

    #if canImport(UIKit)
    private func saveButton(_ data: Data) -> some View {
        Button {
            Task { await save(data) }
        } label: {
            Label("Save to Photos", systemImage: "photo.badge.arrow.down")
                .lineLimit(1).fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity)
        }
        .disabled(isSaving)
    }

    private func copyButton(_ data: Data) -> some View {
        Button(action: { copy(data) }) {
            Label("Copy image", systemImage: "doc.on.doc")
                .lineLimit(1).fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity)
        }
    }

    /// Adds the picture to the photo library with add-only access, which
    /// asks once and never shows the library. One save at a time, so a
    /// second tap while the question is up does not add a second copy.
    private func save(_ data: Data) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        status = nil
        let access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard access == .authorized || access == .limited else {
            status = access == .restricted
                ? String(localized: "Photos access is restricted on this iPhone, so the picture can’t be saved. Share or copy it instead.", bundle: .app)
                : String(localized: "Clockin can’t add to Photos. Allow it in Settings > Privacy & Security > Photos.", bundle: .app)
            selectionFeedback.send(.validationFailed)
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
            status = String(localized: "Saved to Photos.", bundle: .app)
            selectionFeedback.send(.entrySaved)
        } catch {
            status = String(localized: "Could not save to Photos. Please try again.", bundle: .app)
            selectionFeedback.send(.validationFailed)
        }
    }
    #endif

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
