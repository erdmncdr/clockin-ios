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
        url(id, bundle: bundle)
            ?? (id.hasPrefix("a") ? url("h" + id.dropFirst(), bundle: bundle) : nil)
            ?? url("h01", bundle: bundle)
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

// Widget sadece tek kucuk kareyi tutar; hareket onbellegini kullanmaz.
struct ClockinMascotStill: View {
    private let image: CGImage?

    init(mood: MascotMood, maxPixelSize: Int = 192) {
        let rest = MascotResources.library?[mood].rest ?? "h01"
        image = MascotResources.decode(rest, maxPixelSize: maxPixelSize)
    }

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().interpolation(.none).scaledToFit()
            } else {
                Image(systemName: "face.smiling").resizable().scaledToFit()
            }
        }
        .accessibilityHidden(true)
    }
}

#if !WIDGET_EXTENSION
@MainActor
final class MascotFrames {
    static let shared = MascotFrames()
    let library = MascotResources.library
    private var images: [String: CGImage] = [:]
    private var loading: [MascotMood: Task<Void, Never>] = [:]

    func image(_ id: String) -> CGImage? { images[id] }

    func preload(_ mood: MascotMood) async {
        guard let library else { return }
        if let task = loading[mood] { return await task.value }
        let missing = library[mood].frames.filter { images[$0] == nil }
        // Paylasilan isin omru tek gorunumun iptalinden bagimsizdir.
        let task = Task {
            let decoded = await Task.detached(priority: .utility) {
                missing.compactMap { id in MascotResources.decode(id).map { (id, $0) } }
            }.value
            for (id, image) in decoded { images[id] = image }
        }
        loading[mood] = task
        await task.value
    }
}
#endif
