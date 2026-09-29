import Foundation

/// Uygulama ile widget uzantisinin paylastigi klasor.
enum AppGroup {
    static let identifier = "group.com.erdmncdr.clockin"

    /// Ilk surumun veriyi tuttugu yer; `ClockStore.defaultFileURL` ile ayni.
    private static var legacyDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Clockin", directoryHint: .isDirectory)
    }

    /// Grup kapsayicisi alinamazsa (yetkisiz imza) eski klasore duser:
    /// uygulama yine calisir, yalnizca widget veriyi goremez.
    ///
    /// Mac eski Mac uygulamasinin klasorunde kalir; 1.1.6'dan guncellenen
    /// kullanici verisini yerinde bulur. Debug derlemesi ayri klasor kullanir,
    /// gunluk kullanilan uygulamanin verisine dokunmaz.
    static var directory: URL {
        #if os(macOS)
        #if DEBUG
        return legacyDirectory.deletingLastPathComponent().appending(path: "Clockin Debug", directoryHint: .isDirectory)
        #else
        return legacyDirectory
        #endif
        #else
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            return legacyDirectory
        }
        return container.appending(path: "Clockin", directoryHint: .isDirectory)
        #endif
    }

    static var dataFileURL: URL { directory.appending(path: "clockin.json") }
    #if os(macOS)
    /// Mac widget'i sandbox icinde calisir ve uygulamanin klasorunu okuyamaz;
    /// ozet takim onekli grup kapsayicisinda durur. Veri eski klasorde kalir.
    static let macIdentifier = "LU36PKDPT3.com.ismailakdag.clockin"

    static var snapshotURL: URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: macIdentifier) else {
            return directory.appending(path: "widget-snapshot.json")
        }
        #if DEBUG
        let folder = "Clockin Debug"
        #else
        let folder = "Clockin"
        #endif
        return container.appending(path: folder, directoryHint: .isDirectory).appending(path: "widget-snapshot.json")
    }
    #else
    static var snapshotURL: URL { directory.appending(path: "widget-snapshot.json") }
    #endif

    /// Veri grup kapsayicisina bir kez kopyalanir. Eski dosya silinmez; bir
    /// sorun olursa elle geri alinabilsin.
    static func migrateLegacyDataIfNeeded() {
        #if os(macOS)
        return
        #else
        let fileManager = FileManager.default
        let legacy = legacyDirectory.appending(path: "clockin.json")
        guard dataFileURL != legacy,
              !fileManager.fileExists(atPath: dataFileURL.path),
              fileManager.fileExists(atPath: legacy.path) else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.copyItem(at: legacy, to: dataFileURL)
        #endif
    }
}
