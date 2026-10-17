import Darwin
import Foundation

public enum CommanderSaveInput {
  public static let maximumBytes = 4_194_304

  /// Bound allocation and work on the opened file, not a race-prone URL size hint.
  public static func read(from url: URL) throws -> Data {
    guard url.isFileURL else { throw SaveError.invalidCommander }
    let descriptor = url.withUnsafeFileSystemRepresentation { path in
      path.map { Darwin.open($0, O_RDONLY | O_NONBLOCK | O_CLOEXEC) } ?? -1
    }
    guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    defer { try? file.close() }
    var info = stat()
    guard fstat(descriptor, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
      info.st_size >= 0, info.st_size <= off_t(maximumBytes)
    else { throw SaveError.invalidCommander }
    var data = Data()
    while data.count <= maximumBytes {
      let remaining = maximumBytes + 1 - data.count
      guard let chunk = try file.read(upToCount: min(65_536, remaining)), !chunk.isEmpty else {
        return data
      }
      data.append(chunk)
    }
    throw SaveError.invalidCommander
  }
}
