import AppIntents
import Foundation

@available(iOS 18.0, *)
struct SetClockedInIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Clock In or Out"
    static let description = IntentDescription("Starts or resumes the Clockin timer, or clocks out and saves the session.")

    @Parameter(title: "Clocked in")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        #if WIDGET_EXTENSION
        return .result()
        #else
        // Kontrol yeniden okunmadan once ozet diske yazilmis olmali.
        defer { SessionMirror.shared.refresh() }
        if value {
            _ = try await ClockInIntent().perform()
        } else {
            _ = try await ClockOutIntent().perform()
        }
        return .result()
        #endif
    }
}
