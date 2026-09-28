import Foundation

/// A caller-owned PNG directory with an application Caches default.
/// No UI framework or eviction of caller files. Writes are atomic.
struct ArmorHDCache: Sendable {
  struct Key: Sendable {
    let version: String
    let frame: String
    let style: String
    let size: Int
  }
  let directory: URL
  static var application: Self {
    let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return Self(directory: base.appendingPathComponent("Clockin/ArmorHD", isDirectory: true))
  }

  func url(for key: Key) throws -> URL {
    let safe = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
    guard
      [key.version, key.frame, key.style].allSatisfy({
        !$0.isEmpty && $0.utf8.count <= 180 && $0.unicodeScalars.allSatisfy(safe.contains)
      }), (32...2048).contains(key.size)
    else { throw CocoaError(.fileWriteInvalidFileName) }
    return directory.appendingPathComponent(key.version, isDirectory: true)
      .appendingPathComponent(key.style, isDirectory: true)
      .appendingPathComponent("\(key.frame)-\(key.size).png")
  }
  func read(_ key: Key) throws -> Data? {
    let file = try url(for: key)
    do { return try Data(contentsOf: file) } catch let error as CocoaError
      where error.code == .fileReadNoSuchFile
    { return nil }
  }
  func write(_ png: Data, for key: Key) throws {
    let file = try url(for: key)
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: file, options: .atomic)
  }
}
