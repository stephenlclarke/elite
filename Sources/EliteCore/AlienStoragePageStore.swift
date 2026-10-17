import Darwin
import Foundation

/// Stages immutable pages. The native save owner publishes the complete generation.
/// Every path component is opened from a directory descriptor without following links.
struct AlienStoragePageStore: AlienStoragePageReader, AlienStoragePageWriter, Sendable {
  let directory: URL
  init(directory: URL, create: Bool = false) throws {
    guard directory.isFileURL else { throw AlienStorageError.invalidReference }
    // Foundation may reintroduce /var's alias after creation; preserve the physical input.
    self.directory = directory
    let fd = try Self.openDirectory(self.directory, create: create)
    Darwin.close(fd)
  }
  func readPage(hash: String) throws -> Data {
    guard AlienStoragePageCodec.validHash(hash) else { throw AlienStorageError.invalidReference }
    let root = try Self.openDirectory(directory)
    defer { Darwin.close(root) }
    let pages = try Self.childDirectory("alien-pages", parent: root)
    defer { Darwin.close(pages) }
    let prefix = try Self.childDirectory(String(hash.prefix(2)), parent: pages)
    defer { Darwin.close(prefix) }
    return try Self.read(
      hash + ".json", parent: prefix, maximumBytes: AlienStoragePageCodec.maximumPageBytes)
  }
  func writePage(hash: String, data: Data) throws {
    guard AlienStoragePageCodec.validHash(hash),
      data.count <= AlienStoragePageCodec.maximumPageBytes,
      ScriptPackLibrary.hash(data) == hash
    else { throw AlienStorageError.hashMismatch }
    let root = try Self.openDirectory(directory)
    defer { Darwin.close(root) }
    let pages = try Self.childDirectory("alien-pages", parent: root, create: true)
    defer { Darwin.close(pages) }
    let prefix = try Self.childDirectory(String(hash.prefix(2)), parent: pages, create: true)
    defer { Darwin.close(prefix) }
    try Self.writeImmutable(
      data, name: hash + ".json", parent: prefix,
      maximumBytes: AlienStoragePageCodec.maximumPageBytes)
    try Self.sync(prefix)
    try Self.sync(pages)
    try Self.sync(root)
  }
  static func write(
    snapshot: AlienStorageSnapshot, previous: AlienStorageSnapshot?, to directory: URL
  )
    throws -> AlienStorageReference
  {
    var store = try Self(directory: directory, create: true)
    let archive = try AlienStoragePageCodec.encode(
      snapshot: snapshot, previous: previous, into: &store)
    let root = try openDirectory(store.directory)
    defer { Darwin.close(root) }
    try writeImmutable(
      archive.rootData, name: "alien-root.json", parent: root,
      maximumBytes: AlienStoragePageCodec.maximumRootBytes)
    try sync(root)
    return archive.reference
  }
  static func read(reference: AlienStorageReference, expectedOwner: UUID, from directory: URL)
    throws -> AlienStorageSnapshot
  {
    let store = try Self(directory: directory)
    let root = try openDirectory(store.directory)
    defer { Darwin.close(root) }
    let data = try read(
      "alien-root.json", parent: root, maximumBytes: AlienStoragePageCodec.maximumRootBytes)
    return try AlienStoragePageCodec.decode(
      reference: reference, expectedOwner: expectedOwner,
      rootData: data, from: store)
  }
  /// Anchoring from / also rejects links in ancestors of the staging directory.
  private static func openDirectory(_ url: URL, create: Bool = false) throws -> Int32 {
    var fd = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    guard fd >= 0 else { throw ioError() }
    do {
      for component in url.pathComponents where component != "/" {
        let child = try childDirectory(component, parent: fd, create: create)
        Darwin.close(fd)
        fd = child
      }
      return fd
    } catch {
      Darwin.close(fd)
      throw error
    }
  }
  private static func childDirectory(_ name: String, parent: Int32, create: Bool = false) throws
    -> Int32
  {
    guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\0") else {
      throw AlienStorageError.invalidReference
    }
    if create {
      let result = mkdirat(parent, name, mode_t(0o700))
      guard result == 0 || errno == EEXIST else { throw ioError() }
    }
    let child = openat(parent, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    guard child >= 0 else { throw ioError() }
    do {
      // Retry makes an interrupted directory creation durable too.
      if create { try sync(parent) }
      return child
    } catch {
      Darwin.close(child)
      throw error
    }
  }
  private static func read(_ name: String, parent: Int32, maximumBytes: Int) throws -> Data {
    let fd = openat(parent, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
    guard fd >= 0 else { throw ioError() }
    defer { Darwin.close(fd) }
    return try read(fd, maximumBytes: maximumBytes)
  }
  private static func read(_ fd: Int32, maximumBytes: Int) throws -> Data {
    var info = stat()
    guard fstat(fd, &info) == 0 else { throw ioError() }
    guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), info.st_size >= 0,
      info.st_size <= maximumBytes
    else { throw AlienStorageError.invalidPage }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 16384)
    while true {
      let count = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
      if count < 0 && errno == EINTR { continue }
      guard count >= 0 else { throw ioError() }
      if count == 0 { break }
      guard count <= maximumBytes - result.count else { throw AlienStorageError.oversizedRecord }
      result.append(contentsOf: buffer.prefix(count))
    }
    return result
  }
  private static func writeImmutable(_ data: Data, name: String, parent: Int32, maximumBytes: Int)
    throws
  {
    guard data.count <= maximumBytes else { throw AlienStorageError.oversizedRecord }
    let fd = openat(
      parent, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
    if fd < 0 {
      guard errno == EEXIST else { throw ioError() }
      let existing = openat(parent, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
      guard existing >= 0 else { throw ioError() }
      defer { Darwin.close(existing) }
      guard try read(existing, maximumBytes: maximumBytes) == data else {
        throw AlienStorageError.historyChanged
      }
      // Authentication alone is insufficient: an orphan may precede its first fsync.
      try sync(existing)
      return
    }
    defer { Darwin.close(fd) }
    do {
      try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
          guard let address = bytes.baseAddress else { throw AlienStorageError.invalidPage }
          let count = Darwin.write(fd, address.advanced(by: offset), bytes.count - offset)
          if count < 0 && errno == EINTR { continue }
          guard count > 0 else { throw ioError() }
          offset += count
        }
      }
      try sync(fd)
    } catch {
      _ = unlinkat(parent, name, 0)
      throw error
    }
  }
  private static func sync(_ fd: Int32) throws {
    guard fsync(fd) == 0 else { throw ioError() }
  }
  private static func ioError() -> POSIXError {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
  }
}
