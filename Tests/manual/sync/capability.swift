import Foundation

@main struct CapabilityChecks {
    @MainActor static func main() async throws {
        guard !CloudSyncCapability.isEntitled else {
            print("FAIL: offline harness must not carry iCloud entitlements"); exit(1)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clockin24-capability-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = SyncBridge(state: SyncSidecar(deviceID: "unsigned"), snapshot: SyncSnapshot(data: ClockinData()),
            disk: SyncSidecarStore(archiveURL: directory.appendingPathComponent("clockin.json"))) { _, _ in }
        let adapter = ClockinCloudAdapter(bridge: bridge)
        print("ok adapter construction is inert without an entitlement")
        for _ in 0..<7 { await adapter.launch() }
        guard adapter.status == .off, bridge.state.accountID == nil else { exit(1) }
        print("ok seven entitlement-free launches return off without constructing CKContainer")
        await adapter.stop()
        print("All 2 capability checks passed. No CloudKit operation was permitted.")
    }
}
