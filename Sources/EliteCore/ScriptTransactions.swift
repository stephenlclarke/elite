import Foundation

typealias ScriptPublisher = @Sendable (inout Game) throws -> Void

extension GameRuntime {
  /// Captures only value paths. No writer, actor or interpreter callback escapes this turn.
  func scriptPublisher() -> ScriptPublisher? {
    guard let url = scriptSaveURL else { return nil }
    let namespace = galleryNamespace
    return { candidate in
      try Self.requireGalleryFileAccess(url, namespace: namespace)
      candidate.persistBlackjackTargets()
      candidate.persistScriptActors()
      try ScriptSaveStore.write(
        commander: candidate.commander, world: candidate.scriptWorldSave, to: url)
    }
  }
  /// User commands are staged before a frame is published. Disk failure publishes no
  /// command effects; autonomous physics uses a separate proposal-only barrier.
  func commitScriptCommand(from before: Game) throws {
    let ownsPersistentState =
      !before.commander.scriptState.instances.isEmpty
      || !game.commander.scriptState.instances.isEmpty
      || !before.commander.accommodation.ownedBerths.isEmpty
      || !game.commander.accommodation.ownedBerths.isEmpty
    let changed =
      before.commander != game.commander || before.docked != game.docked
      || before.bodies != game.bodies || before.jumpCountdown != game.jumpCountdown
    guard ownsPersistentState, changed, let publish = scriptPublisher() else { return }
    var candidate = game
    candidate.resolveDestroyed()
    try publish(&candidate)
    game = candidate
  }
  func scriptCommand<T>(_ action: (inout Game) throws -> T) throws -> T {
    let before = game
    do {
      let value = try action(&game)
      try commitScriptCommand(from: before)
      return value
    } catch {
      game = before
      throw error
    }
  }
  func nativeCommand(_ action: (inout Game) -> Void) {
    do { try scriptCommand(action) } catch {
      game.notify("MISSION SAVE FAILED - ACTION NOT COMMITTED")
    }
  }
  static func writeCommander(_ candidate: inout Game, to url: URL) throws {
    candidate.resolveDestroyed()
    candidate.persistBlackjackTargets()
    candidate.persistScriptActors()
    guard candidate.commander.valid else { throw SaveError.invalidCommander }
    if !candidate.commander.scriptState.instances.isEmpty
      || !candidate.commander.accommodation.ownedBerths.isEmpty
    {
      try ScriptSaveStore.write(
        commander: candidate.commander, world: candidate.scriptWorldSave, to: url)
    } else {
      let data = try JSONEncoder().encode(candidate.commander)
      guard data.count <= 4_194_304 else { throw SaveError.invalidCommander }
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url, options: .atomic)
    }
  }
}
