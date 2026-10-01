import AppKit
import SwiftUI

@main struct PlatformChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ value: Bool, _ message: String) {
            guard value else { print("FAIL \(message)"); exit(1) }
            count += 1; print("ok \(message)")
        }
        let fonts: [Font] = [.body, .largeTitle, .system(size: 37, weight: .black), .headline,
                             .title3.weight(.semibold), .caption]
        for font in fonts {
            for design: Font.Design in [.default, .rounded, .serif, .monospaced] {
                let native = RollingNumberFont.resolve(font, design: design, sizeCategory: .large)
                check(native.pointSize.isFinite && native.pointSize > 0, "known and new font recipes resolve safely: \(design)")
            }
        }
        for size: CGFloat in [.nan, .infinity, -1, 0, 18, 1e30] {
            let icon = MenuBarIcon.image(.running, pointSize: size)
            check(icon.size.height.isFinite && icon.size.height > 0 && icon.size.height <= 256,
                  "menu icon rejects invalid or unbounded size \(size)")
        }
        let icon = MenuBarIcon.image(.idle)
        let rasterized = await Task.detached { icon.tiffRepresentation != nil }.value
        check(rasterized, "AppKit may rasterize the icon on a background executor without actor assertions")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("clockin24-platform-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ClockStore(fileURL: folder.appendingPathComponent("clockin.json"))
        check(store.monthDuration(at: Date(timeIntervalSinceReferenceDate: .infinity)) == 0,
              "invalid month date returns safely before calendar access")
        let host = NSHostingView(rootView: Text("Offline audit").timerPersistenceAlert(store: store))
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        host.layoutSubtreeIfNeeded()
        check(host.fittingSize.width > 0, "timer alert renders with an explicit store and no EnvironmentObject")
        print("All \(count) platform checks passed.")
    }
}
