import Foundation

/// A single ordered native consumer submits these to the simulation's sole owner.
public enum CommanderFileOperation: Sendable, Equatable {
  case save(URL)
  case load(URL, persistMigrations: Bool)
}

extension GameRuntime {
  /// File preparation, validation, writing and publication contain no actor suspension.
  public func commanderFileOperation(_ operation: CommanderFileOperation) throws {
    switch operation {
    case .save(let url): try save(to: url)
    case .load(let url, let persist): try load(from: url, persistMigrations: persist)
    }
  }
}
