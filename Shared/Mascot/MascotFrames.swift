import ImageIO
import SwiftUI

enum MascotResources {
    static func url(_ name: String, extension ext: String = "png", bundle: Bundle = .main) -> URL? {
        for folder in [nil, "Frames", "Mascot/Frames"] as [String?] {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: folder) { return url }
        }
        return nil
    }

    static func frameURL(_ id: String, bundle: Bundle = .main) -> URL? {
        MascotFrameFallback.resolve(id) { url($0, bundle: bundle) != nil }
            .flatMap { url($0, bundle: bundle) }
    }

    static func decode(_ id: String, maxPixelSize: Int = 314) -> CGImage? {
        guard let url = frameURL(id),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }

    static let library: MascotLibrary? = url("mascot-clips", extension: "json")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { try? MascotLibrary(data: $0) }
}

// Widget hazir resmi alir; uygulama arka planda hazirlar.
struct ClockinMascotStill: View {
    #if WIDGET_EXTENSION
    private var image: CGImage?
    #else
    @State private var image: CGImage?
    #endif
    private var mood: MascotMood = .hello
    private var size = 192
    private var outfit = WardrobeState()
    private var prepared = false
    private var preparedImage: CGImage?
    private struct Request: Equatable {
        let mood: MascotMood
        let size: Int
        let outfit: WardrobeState
    }

    init(image: CGImage?) {
        preparedImage = image
        prepared = true
    }

    init(mood: MascotMood, accessory: CompanionAccessory? = nil, maxPixelSize: Int = 192,
         outfit: WardrobeState = WardrobeState()) {
        self.mood = mood; size = maxPixelSize; self.outfit = outfit
        if let accessory, let item = WardrobeCatalog.item(accessory.rawValue) {
            self.outfit.equipped[item.slot.rawValue] = item.id
        }
    }

    var body: some View {
        Group {
            if let displayed = prepared ? preparedImage : image {
                Image(decorative: displayed, scale: 1).resizable().interpolation(.none).scaledToFit()
            } else {
                Image(systemName: "face.smiling").resizable().scaledToFit()
            }
        }
        .accessibilityHidden(true)
        #if !WIDGET_EXTENSION
        .task(id: Request(mood: mood, size: size, outfit: outfit)) {
            guard !prepared else { return }
            let rest = MascotResources.library?[mood].rest ?? "h01"
            let result = await WardrobeFrameCache.shared.composite(frame: rest, outfit: outfit, size: size)
            guard !Task.isCancelled else { return }
            image = result
        }
        #endif
    }
}

#if !WIDGET_EXTENSION
@MainActor
final class MascotFrames {
    static let shared = MascotFrames()
    let library = MascotResources.library
    private var images: [String: CGImage] = [:]
    private var loading: [String: Task<Void, Never>] = [:]
    private(set) var overlayImages: [String: CGImage] = [:]

    func image(_ id: String, colorway: String = "classic", hidingAntenna: Bool = false) -> CGImage? { images[colorway + "/" + id + "/" + String(hidingAntenna)] }

    private var outfitLoading: Task<Void, Never>?

    func preloadOutfit() async {
        if let task = outfitLoading { return await task.value }
        let ids = Array(WardrobeArt.sprites.keys)
        let task = Task {
            let decoded = await Task.detached(priority: .utility) {
                ids.compactMap { id in
                    WardrobeArt.decode(id + ".png", folder: "Wardrobe").map { (id, $0) }
                }
            }.value
            for (id, image) in decoded { overlayImages[id] = image }
        }
        outfitLoading = task
        await task.value
    }

    func preload(_ mood: MascotMood, colorway: String = "classic", hidingAntenna: Bool = false) async {
        await preloadOutfit()
        guard let library else { return }
        let key = colorway + "/" + mood.rawValue + "/" + String(hidingAntenna)
        if let task = loading[key] { return await task.value }
        let missing = library[mood].frames.filter { images[colorway + "/" + $0 + "/" + String(hidingAntenna)] == nil }
        // Paylasilan decode isi gorunum kapaninca sonucunu onbellege birakir.
        let task = Task {
            let decoded = await Task.detached(priority: .utility) {
                var frames: [(String, CGImage)] = []
                for id in missing {
                    if let image = await WardrobeFrameCache.shared.image(id, colorway: colorway, hidingAntenna: hidingAntenna) { frames.append((id, image)) }
                }
                return frames
            }.value
            for (id, image) in decoded { images[colorway + "/" + id + "/" + String(hidingAntenna)] = image }
        }
        loading[key] = task
        await task.value
    }
}
#endif
