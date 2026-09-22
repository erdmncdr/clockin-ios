#if !WIDGET_EXTENSION
import ActivityKit
import Foundation
import Combine
import OSLog
import UIKit

/// Registers the system's per-activity token. The server holds the APNs key;
/// neither the app nor the widget contains a shared server credential.
@MainActor
final class LiveActivityPush: ObservableObject {
    static let shared = LiveActivityPush()
    private static let logger = Logger(subsystem: "com.erdmncdr.clockin", category: "LiveActivityPush")
    private var observers: [String: Task<Void, Never>] = [:]
    private var uploads: [String: Task<Void, Never>] = [:]
    private var removals: [String: Task<Void, Never>] = [:]
    private var knownTokens: [String: String] = [:]
    private var registeredTokens: Set<String> = []
    @Published private(set) var deletionPending = false
    @Published private(set) var registrationStatus: LiveActivityRegistrationStatus = .idle
    private var statusActivityID: String?

    /// Sunucuda kaydi olan token'lar, gecerlilik sonlariyla. Bellekteki
    /// `registeredTokens` her acilista sifirlaniyor; guncelleme uygulamayi
    /// oldururken etkinligi de sonlandirdigi icin silme istegi kuyruga
    /// giremiyor ve sunucudaki kayit "canli" sayilmaya devam ediyordu.
    private var storedRegistrations: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: LiveActivityPrivacy.registeredTokensKey) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: LiveActivityPrivacy.registeredTokensKey) }
    }

    private var pendingDeletions: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: LiveActivityPrivacy.pendingDeletionsKey) as? [String: Double] ?? [:] }
        set {
            UserDefaults.standard.set(newValue, forKey: LiveActivityPrivacy.pendingDeletionsKey)
            deletionPending = !newValue.isEmpty
        }
    }

    static var endpoint: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ClockinLiveActivityEndpoint") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }

    // Development/ad-hoc apps embed their signed provisioning profile. Store
    // and TestFlight installations omit it and use production APNs.
    private static let environment: String? = {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            return "production"
        }
        guard let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let profile = try? PropertyListSerialization.propertyList(
                from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
              let entitlements = profile["Entitlements"] as? [String: Any],
              let value = entitlements["aps-environment"] as? String else { return nil }
        return value == "development" ? "sandbox" : value == "production" ? "production" : nil
        #endif
    }()

    func observe(_ activity: Activity<ClockinActivityAttributes>) {
        guard LiveActivityPrivacy.enabled, Self.endpoint != nil, activity.attributes.localState != nil, activity.attributes.remoteUpdatesUntil != nil else { return }
        let id = activity.id
        statusActivityID = id
        if let data = activity.pushToken {
            let token = data.map { String(format: "%02x", $0) }.joined()
            if registeredTokens.contains(token) { registrationStatus = .registered }
        } else { registrationStatus = .waitingForToken }
        if let token = activity.pushToken { register(token, activity: activity) }
        guard observers[id] == nil else { return }
        observers[id] = Task { [weak self] in
            var waitingForToken = activity.pushToken == nil
                ? UIApplication.shared.beginBackgroundTask(withName: "Live Activity token") { [weak self] in
                    Task { @MainActor in self?.observers[id]?.cancel() }
                } : .invalid
            defer {
                if waitingForToken != .invalid { UIApplication.shared.endBackgroundTask(waitingForToken) }
                self?.observers[id] = nil
            }
            for await token in activity.pushTokenUpdates {
                guard !Task.isCancelled else { return }
                self?.register(token, activity: activity)
                if waitingForToken != .invalid {
                    UIApplication.shared.endBackgroundTask(waitingForToken)
                    waitingForToken = .invalid
                }
            }
        }
    }

    private func register(_ data: Data, activity: Activity<ClockinActivityAttributes>) {
        let id = activity.id
        let token = data.map { String(format: "%02x", $0) }.joined()
        guard LiveActivityPrivacy.enabled, activity.attributes.localState != nil,
              !registeredTokens.contains(token), uploads[id] == nil,
              let expiresAt = activity.attributes.remoteUpdatesUntil,
              let environment = Self.environment, let endpoint = Self.endpoint else { return }
        if let previous = knownTokens[id], previous != token {
            queueDeletion(previous, expiresAt: expiresAt)
        }
        knownTokens[id] = token
        let state = activity.content.state
        guard !state.isPaused else { return }
        guard let body = try? JSONEncoder().encode(LiveActivityRegistration(environment: environment,
            expiresAt: expiresAt.timeIntervalSince1970)) else { return }
        uploads[id] = Task { [weak self] in
            self?.setStatus(.registering, for: id)
            // A short, legitimate background assertion lets an in-flight token
            // registration finish as the user locks the phone. It is NOT a timer.
            let taskID = UIApplication.shared.beginBackgroundTask(withName: "Live Activity registration") { [weak self] in
                Task { @MainActor in self?.uploads[id]?.cancel() }
            }
            defer {
                if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID) }
                self?.uploads[id] = nil
                if !Task.isCancelled, let latest = activity.pushToken, latest != data {
                    self?.register(latest, activity: activity)
                }
            }
            var failureCode: Int?
            for attempt in 0..<3 {
                guard !Task.isCancelled, LiveActivityPrivacy.enabled else { return }
                do {
                    let status = try await Self.request(endpoint, token: token, method: "PUT", body: body)
                    guard !Task.isCancelled, LiveActivityPrivacy.enabled else { return }
                    if status == 204 {
                        self?.registeredTokens.insert(token)
                        self?.remember(token, expiresAt: expiresAt)
                        self?.setStatus(.registered, for: id)
                        return
                    }
                    failureCode = status > 0 ? status : nil
                    if (400..<500).contains(status), status != 429 { break }
                } catch {
                    if Task.isCancelled { return }
                    failureCode = nil
                }
                if attempt < 2 { try? await Task.sleep(for: .seconds(2)) }
            }
            Self.logger.error("Live Activity registration failed; will retry when the app next runs")
            self?.setStatus(.failed(failureCode), for: id)
        }
    }

    private func setStatus(_ status: LiveActivityRegistrationStatus, for id: String) {
        guard statusActivityID == id else { return }
        registrationStatus = status
    }

    func activityCouldNotStart() {
        statusActivityID = nil
        registrationStatus = .activityUnavailable
    }

    func stop(id: String, token data: Data?, expiresAt: Date?) async {
        if statusActivityID == id {
            statusActivityID = nil
            registrationStatus = .idle
        }
        observers.removeValue(forKey: id)?.cancel()
        let upload = uploads.removeValue(forKey: id)
        upload?.cancel()
        await upload?.value
        let fallback = data?.map { String(format: "%02x", $0) }.joined()
        guard let token = knownTokens.removeValue(forKey: id) ?? fallback else { return }
        registeredTokens.remove(token)
        forget(token)
        queueDeletion(token, expiresAt: expiresAt ?? .now.addingTimeInterval(8 * 3600))
    }

    private func queueDeletion(_ token: String, expiresAt: Date) {
        var queued = pendingDeletions
        queued[token] = max(queued[token] ?? 0, expiresAt.timeIntervalSince1970)
        pendingDeletions = queued
        retryPendingDeletions()
    }

    private func remember(_ token: String, expiresAt: Date) {
        var stored = storedRegistrations
        stored[token] = max(stored[token] ?? 0, expiresAt.timeIntervalSince1970)
        storedRegistrations = stored
    }

    private func forget(_ token: String) {
        var stored = storedRegistrations
        stored.removeValue(forKey: token)
        storedRegistrations = stored
    }

    /// Yasayan bir etkinlige ait olmayan her kaydi silme kuyruguna alir.
    /// Bir etkinligin token'i henuz gelmediyse tur atlanir, yoksa yasayan
    /// bir kayit yanlislikla silinebilirdi.
    private func reconcileRegistrations() {
        var stored = storedRegistrations
        guard !stored.isEmpty else { return }
        let activities = Activity<ClockinActivityAttributes>.activities
        guard activities.allSatisfy({ $0.pushToken != nil }) else { return }
        let live = Set(activities.compactMap { $0.pushToken?.map { String(format: "%02x", $0) }.joined() })
        let stale = LiveActivityRegistry.stale(stored: stored, live: live)
        guard !stale.isEmpty else { return }
        for token in stale.keys { stored.removeValue(forKey: token) }
        storedRegistrations = stored
        pendingDeletions = LiveActivityRegistry.merging(queue: pendingDeletions, with: stale)
    }

    func retryPendingDeletions() {
        guard let endpoint = Self.endpoint else { return }
        reconcileRegistrations()
        var queued = pendingDeletions
        queued = queued.filter { $0.value > Date.now.timeIntervalSince1970 }
        pendingDeletions = queued
        for (token, _) in queued where removals[token] == nil {
            removals[token] = Task { [weak self] in
                let taskID = UIApplication.shared.beginBackgroundTask(withName: "Live Activity removal") { [weak self] in
                    Task { @MainActor in self?.removals[token]?.cancel() }
                }
                defer {
                    if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID) }
                    self?.removals[token] = nil
                }
                for attempt in 0..<3 {
                    guard !Task.isCancelled else { return }
                    if let status = try? await Self.request(endpoint, token: token, method: "DELETE", body: nil), status == 204 {
                        guard let self else { return }
                        var remaining = self.pendingDeletions
                        remaining.removeValue(forKey: token)
                        self.pendingDeletions = remaining
                        return
                    }
                    if attempt < 2 { try? await Task.sleep(for: .seconds(2)) }
                }
                // Kept across launches; Settings tells the user cleanup is pending.
            }
        }
    }

    func finishPendingUploads() async {
        for task in Array(uploads.values) { await task.value }
        for task in Array(removals.values) { await task.value }
    }

    nonisolated private static func request(_ url: URL, token: String, method: String, body: Data?) async throws -> Int {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}
#endif
