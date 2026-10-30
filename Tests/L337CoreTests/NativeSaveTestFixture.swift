import Foundation

@testable import L337Core

enum NativeSaveTestFixture {
  /// Establish the current native policy before capturing an independent preservation oracle.
  static func prepareCurrentPolicy(_ game: inout Game) throws {
    try game.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
    game.ensureScriptCalendar(origin: .newCommander)
  }

  /// Actual current native saves use the authenticated versioned reader. There is no raw fallback.
  static func readVersionedCommander(from file: URL) throws -> Commander {
    try ScriptSaveStore.read(Data(contentsOf: file), from: file).0
  }
}
