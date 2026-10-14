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
        commander: candidate.commander, world: candidate.scriptWorldSave, to: url,
        scope: namespace == nil ? "commander" : "gallery")
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
      || before.commander.ownedEquipment != nil || game.commander.ownedEquipment != nil
      || !before.commander.contracts.boards.isEmpty || !game.commander.contracts.boards.isEmpty
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
      || !candidate.commander.accommodation.ownedBerths.isEmpty || candidate.isMissionTrial
      || candidate.commander.ownedEquipment != nil
      || !candidate.commander.contracts.boards.isEmpty
    {
      try ScriptSaveStore.write(
        commander: candidate.commander, world: candidate.scriptWorldSave, to: url,
        scope: candidate.isMissionTrial ? "gallery" : "commander")
    } else {
      let data = try JSONEncoder().encode(candidate.commander)
      guard data.count <= 4_194_304 else { throw SaveError.invalidCommander }
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url, options: .atomic)
    }
  }
}

extension Game {
  mutating func recordScriptFailure(_ id: UUID, error: any Error, publish: ScriptPublisher?) {
    commander.scriptState.instances[id]?.suspension = String(
      error.localizedDescription.prefix(1024))
    notify("MISSION SUSPENDED - SEE MISSION GALLERY")
    // A deterministic script/validation fault can be saved without its rejected proposal.
    // A failed filesystem write is not retried here; live native facts remain intact.
    guard error is MissionPackError, let publish else { return }
    var fault = self
    do {
      try publish(&fault)
      self = fault
    } catch { notify("MISSION SUSPENDED - SAVE UNAVAILABLE") }
  }
}
