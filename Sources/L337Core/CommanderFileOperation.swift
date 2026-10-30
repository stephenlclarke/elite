import Foundation

/// A single ordered native consumer submits these to the simulation's sole owner.
public enum CommanderFileOperation: Sendable, Equatable {
  case save(URL)
  case load(URL, persistMigrations: Bool)
}

extension GameRuntime {
  /// Active native actions resolve in this ordered actor turn. Gallery uses its
  /// private writer; explicit panel URLs retain their identity and path checks.
  public func commanderFileOperationForInterface(
    _ operation: CommanderFileOperation, activePath: Bool
  ) throws -> CommanderFileReceipt {
    switch operation {
    case .save(let url):
      return try saveForInterface(to: activePath && galleryNamespace != nil ? nil : url)
    case .load(let url, let persist):
      return try loadForInterface(
        from: activePath && galleryNamespace != nil ? nil : url,
        persistMigrations: persist)
    }
  }

  /// File preparation, validation, writing and publication contain no actor suspension.
  public func commanderFileOperation(_ operation: CommanderFileOperation) throws {
    switch operation {
    case .save(let url): try save(to: url)
    case .load(let url, let persist): try load(from: url, persistMigrations: persist)
    }
  }
}
