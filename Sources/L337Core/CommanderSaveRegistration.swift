import Darwin
import Foundation

extension GameRuntime {
  /// Register an unbound live commander's destination without writing or claiming a saved file.
  public func registerNewCommanderDestination(at url: URL) throws -> URL {
    guard galleryNamespace == nil, galleryParent == nil, !game.isMissionTrial,
      scriptSaveURL == nil, url.isFileURL
    else { throw SaveError.invalidCommander }
    try CommanderSavePublication.requireAbsent(url)
    scriptSaveURL = url
    game.pendingNewSaveDestination = url
    game.scriptDurabilityAvailable = true
    return url
  }

  public func hasCommanderSaveDestination() -> Bool { scriptSaveURL != nil }

  /// Only an actual first publication can promote a new destination to the last successful save.
  public func takeNewCommanderSaveReceipt() -> CommanderFileReceipt? {
    let receipt = game.newCommanderSaveReceipt
    game.newCommanderSaveReceipt = nil
    guard galleryNamespace == nil, let receipt, !receipt.isTrial,
      receipt.url == scriptSaveURL
    else { return nil }
    return receipt
  }
}

extension Game {
  mutating func recordNewCommanderSavePublication(to url: URL) {
    if pendingNewSaveDestination == url, !isMissionTrial {
      newCommanderSaveReceipt = .init(url: url, isTrial: false)
    }
    pendingNewSaveDestination = nil
  }
}

/// A new destination must remain absent until its complete first pointer is published.
/// The exclusive rename closes the race between registration and the first real write.
enum CommanderSavePublication {
  static func requireAbsent(_ url: URL) throws {
    guard url.isFileURL else { throw SaveError.invalidCommander }
    var info = stat()
    let result = url.withUnsafeFileSystemRepresentation { path in
      path.map { lstat($0, &info) } ?? -1
    }
    guard result != 0, errno == ENOENT else { throw SaveError.invalidCommander }
  }

  static func write(_ bytes: Data, to url: URL, exclusive: Bool) throws {
    guard exclusive else {
      try bytes.write(to: url, options: .atomic)
      return
    }
    let staging = url.deletingLastPathComponent().appendingPathComponent(
      ".commander-" + UUID().uuidString + ".pending")
    let descriptor = staging.withUnsafeFileSystemRepresentation { path in
      path.map { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode_t(0o600)) } ?? -1
    }
    guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    defer {
      try? file.close()
      try? FileManager.default.removeItem(at: staging)
    }
    try file.write(contentsOf: bytes)
    try file.close()
    let result = staging.withUnsafeFileSystemRepresentation { source in
      url.withUnsafeFileSystemRepresentation { destination in
        guard let source, let destination else { return Int32(-1) }
        return renamex_np(source, destination, UInt32(RENAME_EXCL))
      }
    }
    guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
  }
}
