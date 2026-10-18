import Foundation

typealias ScriptPublisher = @Sendable (inout Game) throws -> Void

extension GameRuntime {
  /// Captures value paths and a bounded Sendable, non-authoritative observation reference.
  /// No writer, actor or interpreter callback escapes this turn.
  func scriptPublisher(
    requireNativeSalvage: Bool = false, diagnosticBoundary: ScriptRefusalBoundary = .publication
  ) -> ScriptPublisher? {
    guard game.requiresScriptDurability || requireNativeSalvage, let url = scriptSaveURL else {
      return nil
    }
    let namespace = galleryNamespace
    let diagnostics = scriptRefusalDiagnostic
    return { candidate in
      try Self.requireGalleryFileAccess(url, namespace: namespace)
      // Both publication paths pin current policy before choosing the save schema.
      try candidate.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
      if candidate.commander.scriptState.calendarLedger == nil {
        let legacy =
          candidate.commander.legacyOwnedEquipment != nil || candidate.jumpCountdown != nil
        candidate.ensureScriptCalendar(origin: legacy ? .inactiveLegacyMigration : .newCommander)
        if candidate.jumpCountdown != nil {
          candidate.commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
        }
      }
      candidate.persistScriptActors()
      let prepared = try Self.prepareNativeSaveState(
        candidate, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
      let alienPublication: AlienStoragePublication?
      do {
        alienPublication = try ScriptSaveStore.write(
          commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url,
          scope: namespace == nil ? "commander" : "gallery",
          exclusive: candidate.pendingNewSaveDestination == url, diagnostics: diagnostics,
          diagnosticBoundary: diagnosticBoundary)
      } catch {
        diagnostics?.record(
          diagnosticBoundary, .init(stage: .storeWrite, error: error, game: prepared.game))
        throw error
      }
      candidate = prepared.game
      candidate.commander.publishAlienStorage(alienPublication)
      candidate.recordNewCommanderSavePublication(to: url)
    }
  }
  /// User commands are staged before a frame is published. Disk failure publishes no
  /// command effects; autonomous physics uses a separate proposal-only barrier.
  func commitScriptCommand(from before: Game) throws {
    var stage = ScriptRefusalStage.commandFlush
    do {
      guard game.flushNativeSalvageWork() else { throw SaveError.invalidCommander }
      let ownsPersistentState =
        before.requiresScriptDurability || game.requiresScriptDurability
      let changed =
        before.commander != game.commander || before.docked != game.docked
        || before.bodies != game.bodies || before.jumpCountdown != game.jumpCountdown
      guard ownsPersistentState, changed else { return }
      var candidate = game
      stage = .commandPublish
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
    } catch {
      scriptRefusalDiagnostic?.record(
        .publication, .init(stage: stage, error: error, game: game))
      throw error
    }
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
    try candidate.commander.prepareEquipment()
    try candidate.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
    if (candidate.requiresScriptDurability || candidate.commander.usesEconomyMiningSaveVersion
      || candidate.commander.usesModularDriveSaveVersion)
      && candidate.commander.scriptState.calendarLedger == nil
    {
      let legacy = candidate.commander.legacyOwnedEquipment != nil || candidate.jumpCountdown != nil
      candidate.ensureScriptCalendar(origin: legacy ? .inactiveLegacyMigration : .newCommander)
      if candidate.jumpCountdown != nil {
        candidate.commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
      }
    }
    candidate.persistScriptActors()
    let prepared = try Self.prepareNativeSaveState(candidate)
    var alienPublication: AlienStoragePublication?
    if prepared.game.requiresScriptDurability {
      alienPublication = try ScriptSaveStore.write(
        commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url,
        scope: prepared.game.isMissionTrial ? "gallery" : "commander",
        exclusive: candidate.pendingNewSaveDestination == url)
    } else {
      let data = try JSONEncoder().encode(prepared.commander)
      guard data.count <= 4_194_304 else { throw SaveError.invalidCommander }
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try CommanderSavePublication.write(
        data, to: url, exclusive: candidate.pendingNewSaveDestination == url)
    }
    candidate = prepared.game
    candidate.commander.publishAlienStorage(alienPublication)
    candidate.recordNewCommanderSavePublication(to: url)
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
