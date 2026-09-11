#if !WIDGET_EXTENSION
import Foundation

/// Uygulamanin tek `ClockStore`'u.
///
/// Kisayollar ve Live Activity dugmeleri de bu ornegi kullanir. Ayri ornekler
/// ayni dosyayi birbirinden habersiz yazar; ekrandaki deger eskir ve son
/// yazan digerinin degisikligini silerdi.
@MainActor
enum SharedStore {
    static let clock: ClockStore = {
        AppGroup.migrateLegacyDataIfNeeded()
        let store = ClockStore(fileURL: AppGroup.dataFileURL)
        SessionMirror.shared.start(observing: store)
        return store
    }()
}
#endif
