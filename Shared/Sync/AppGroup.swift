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
    static var directory: URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            return legacyDirectory
        }
        return container.appending(path: "Clockin", directoryHint: .isDirectory)
    }

    static var dataFileURL: URL { directory.appending(path: "clockin.json") }
    static var snapshotURL: URL { directory.appending(path: "widget-snapshot.json") }

    /// Veri grup kapsayicisina bir kez kopyalanir. Eski dosya silinmez; bir
    /// sorun olursa elle geri alinabilsin.
    static func migrateLegacyDataIfNeeded() {
        let fileManager = FileManager.default
        let legacy = legacyDirectory.appending(path: "clockin.json")
        guard dataFileURL != legacy,
              !fileManager.fileExists(atPath: dataFileURL.path),
              fileManager.fileExists(atPath: legacy.path) else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.copyItem(at: legacy, to: dataFileURL)
    }
}
