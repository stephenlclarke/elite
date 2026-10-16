import Foundation

typealias ScriptPublisher = @Sendable (inout Game) throws -> Void

extension GameRuntime {
  /// Captures only value paths. No writer, actor or interpreter callback escapes this turn.
  func scriptPublisher() -> ScriptPublisher? {
    guard game.requiresScriptDurability, let url = scriptSaveURL else { return nil }
    let namespace = galleryNamespace
    return { candidate in
      try Self.requireGalleryFileAccess(url, namespace: namespace)
      if candidate.commander.scriptState.calendarLedger == nil {
        let legacy =
          candidate.commander.legacyOwnedEquipment != nil || candidate.jumpCountdown != nil
        candidate.ensureScriptCalendar(origin: legacy ? .inactiveLegacyMigration : .newCommander)
      }
      candidate.persistScriptActors()
      let prepared = try Self.prepareNativeSaveState(candidate)
      try ScriptSaveStore.write(
        commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url,
        scope: namespace == nil ? "commander" : "gallery")
      candidate = prepared.game
    }
  }
  /// User commands are staged before a frame is published. Disk failure publishes no
  /// command effects; autonomous physics uses a separate proposal-only barrier.
  func commitScriptCommand(from before: Game) throws {
    let ownsPersistentState =
      before.requiresScriptDurability || game.requiresScriptDurability
    let changed =
      before.commander != game.commander || before.docked != game.docked
      || before.bodies != game.bodies || before.jumpCountdown != game.jumpCountdown
    guard ownsPersistentState, changed else { return }
    var candidate = game
    if let publish = scriptPublisher() {
      try publish(&candidate)
    } else if before.requiresScriptDurability, !game.requiresScriptDurability,
      let url = scriptSaveURL
    {
      // Clearing the last retained feature still replaces the bound save. Native-only
      // commanders use the existing writer without inventing a new script calendar.
      try requireGalleryFileAccess(url)
      try Self.writeCommander(&candidate, to: url)
    } else {
      return
    }
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
  func nativeCommand(_ action: @Sendable (inout Game) -> Void) {
    do { try scriptCommand(action) } catch {
      game.notify("MISSION SAVE FAILED - ACTION NOT COMMITTED")
    }
  }
  static func writeCommander(_ candidate: inout Game, to url: URL) throws {
    if candidate.requiresScriptDurability && candidate.commander.scriptState.calendarLedger == nil {
      let legacy = candidate.commander.legacyOwnedEquipment != nil || candidate.jumpCountdown != nil
      candidate.ensureScriptCalendar(origin: legacy ? .inactiveLegacyMigration : .newCommander)
    }
    candidate.persistScriptActors()
    let prepared = try Self.prepareNativeSaveState(candidate)
    if prepared.game.requiresScriptDurability {
      try ScriptSaveStore.write(
        commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url,
        scope: prepared.game.isMissionTrial ? "gallery" : "commander")
    } else {
      let data = try JSONEncoder().encode(prepared.commander)
      guard data.count <= 4_194_304 else { throw SaveError.invalidCommander }
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url, options: .atomic)
    }
    candidate = prepared.game
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
