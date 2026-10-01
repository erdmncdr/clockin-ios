import CloudKit
import Foundation

var checks = 0
@MainActor func check(_ value: @autoclosure () throws -> Bool, _ message: String) rethrows {
    guard try value() else { fatalError("FAIL: \(message)") }
    checks += 1; print("ok \(message)")
}
let now = Date(timeIntervalSince1970: 1_800_000_000)
var snapshot = SyncSnapshot(data: ClockinData())
snapshot.data.sessions = [.init(id: UUID(), start: now, end: now, duration: 0, note: "codec", hourlyRate: 25, source: "Clockin")]
snapshot.data.rateRules = [.init(effectiveFrom: now, hourlyRate: 25)]
snapshot.preferences["Clockin.Theme"] = .string("Carbon")
snapshot.ledger = [.init(itemID: "mint", cost: 100, date: now)]
let records = try SyncCore.diff(previous: nil, current: snapshot, known: [:],
                                stamp: .init(modifiedAt: now, modifiedBy: "codec", sequence: 1))
for value in records {
    let cloud = try ClockinCloudRecord.encode(value, systemFields: nil)
    try check(ClockinCloudRecord.decode(cloud) == value, "CKRecord roundtrip: \(value.kind.rawValue)")
    let fields = ClockinCloudRecord.systemFields(cloud)
    let restored = try ClockinCloudRecord.encode(value, systemFields: fields)
    try check(ClockinCloudRecord.decode(restored) == value, "system-field archive roundtrip: \(value.kind.rawValue)")
}
let value = records[0]
let bad = try ClockinCloudRecord.encode(value, systemFields: nil)
bad["modifiedBy"] = "different-device" as CKRecordValue
do { _ = try ClockinCloudRecord.decode(bad); fatalError("invalid stamp accepted") }
catch { check(true, "mismatched CloudKit metadata rejected") }
let wrongID = CKRecord(recordType: value.kind.rawValue,
                       recordID: .init(recordName: "wrong", zoneID: ClockinCloudRecord.zoneID))
wrongID["schema"] = Int64(2) as CKRecordValue
wrongID["payload"] = try SyncCoding.encode(value) as CKRecordValue
wrongID["modifiedAt"] = now as CKRecordValue
wrongID["modifiedBy"] = "codec" as CKRecordValue
do { _ = try ClockinCloudRecord.decode(wrongID); fatalError("wrong ID accepted") }
catch { check(true, "CloudKit record-name spoof rejected") }
var oversized = records.first { $0.kind == .session }!
var largeSession = try SyncCoding.decode(WorkSession.self, oversized.versions[0].payload)
largeSession.note = String(repeating: "a", count: ClockinCloudRecord.maximumPayloadBytes + 1)
oversized.versions[0].payload = try SyncCoding.encode(largeSession)
do { _ = try ClockinCloudRecord.encode(oversized, systemFields: nil); fatalError("oversized record accepted") }
catch { check(true, "over-limit input is invalid and never silently truncated") }
check(ClockinCloudAdapter.accountState(.noAccount) == .absent
      && ClockinCloudAdapter.accountState(.restricted) == .absent, "no account/restricted launch stays off")
check(ClockinCloudAdapter.accountState(.couldNotDetermine) == .temporary
      && ClockinCloudAdapter.accountState(.temporarilyUnavailable) == .temporary, "temporary account lookup schedules retry")
check(ClockinCloudAdapter.accountState(.available) == .available, "available account permits identity lookup")
for (code, expected) in [(CKError.Code.serverRecordChanged, SyncSendFailure.serverRecordChanged),
                         (.unknownItem, .unknownItem), (.zoneNotFound, .zoneNotFound),
                         (.networkFailure, .networkFailure), (.networkUnavailable, .networkUnavailable),
                         (.zoneBusy, .zoneBusy), (.serviceUnavailable, .serviceUnavailable),
                         (.requestRateLimited, .requestRateLimited), (.notAuthenticated, .notAuthenticated),
                         (.operationCancelled, .operationCancelled), (.quotaExceeded, .other),
                         (.permissionFailure, .other), (.invalidArguments, .other)] {
    check(ClockinCloudAdapter.failure(code) == expected, "CKError maps to offline send policy: \(code.rawValue)")
}
let invalidArchives = [Data([0, 1, 2]), try NSKeyedArchiver.archivedData(withRootObject: "wrong root", requiringSecureCoding: true)]
for fields in invalidArchives {
    do {
        _ = try ClockinCloudRecord.encode(records[0], systemFields: fields)
        check(false, "corrupt system fields should fail")
    } catch { check(true, "corrupt system fields return an error instead of an unarchiver exception") }
}
print("All \(checks) CloudKit codec checks passed without network or entitlements.")
