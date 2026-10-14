import Foundation

extension GameRuntime {
  public func loadScriptPacks(directory: URL) {
    let library = ScriptPackLibrary.installed(directory: directory)
    game.scriptPacks = library.packs
    for error in library.errors { game.notify(error) }
  }
  public func installScriptPack(from directory: URL, destination: URL) throws {
    let pack = try ScriptPackLibrary.read(directory)
    _ = try ScriptPackLibrary.install(pack, directory: destination)
    if !game.scriptPacks.contains(where: { $0.digest == pack.digest }) {
      game.scriptPacks.append(pack)
    }
    game.notify(
      pack.missingCapabilities.isEmpty
        ? "MISSION PACK INSTALLED - VISIT STATION CONTACTS"
        : "MISSION REFERENCE INSTALLED - SEE MISSION GALLERY")
  }
  public func resumeScriptMission(_ id: UUID) throws {
    guard let state = game.commander.scriptState.instances[id],
      let pack = game.scriptPack(for: state),
      game.scriptUnavailable(pack) == nil
    else { throw MissionPackError("Restore the exact saved pack and its requirements.") }
    game.commander.scriptState.instances[id]?.suspension = nil
    game.drainScriptEvents()
  }
  /// Gallery trials receive separate value state and have no access to live save writers or directories.
  public func scriptGalleryTrial(packDigest: String, seed: UInt64 = 0x45_4c49_5445) throws
    -> GameRuntime
  {
    guard let pack = game.scriptPacks.first(where: { $0.digest == packDigest }),
      game.scriptUnavailable(pack) == nil
    else {
      throw MissionPackError("This mission's native capabilities are not available for a trial.")
    }
    var trial = Game(executive: false)
    trial.screen = .status
    trial.scriptPacks = game.scriptPacks
    let id = try trial.acceptScriptMission(pack)
    trial.commander.scriptState.instances[id]?.randomState = seed
    return GameRuntime(game: trial)
  }
}

extension GameRuntime {
  /// Runs in the native leak diagnostic, without installing content or touching a commander.
  public func diagnoseScriptHost() throws {
    let source = Data(
      """
      return {check=function(event, world, data)
        data.count=(data.count or 0)+1
        data.samples={true,123,1.5,'value'}
        return {data=data,commands={}}
      end}
      """.utf8)
    var state: ScriptValue = .object([:])
    for count in 1...32 {
      let result = try ScriptEvaluator.evaluate(
        source: source, handler: "check",
        event: .object([:]), snapshot: .object([:]), state: state)
      guard result.data["count"] == .integer(Int64(count)) else {
        throw MissionPackError("Script host diagnostic returned inconsistent explicit state.")
      }
      state = result.data
    }
    for _ in 0..<8 {
      do {
        _ = try ScriptEvaluator.evaluate(
          source: Data("while true do end".utf8), handler: "check",
          event: .object([:]), snapshot: .object([:]), state: .object([:]))
        throw MissionPackError("Script host failed to stop an endless loop.")
      } catch let error as MissionPackError
        where error.reason.contains("Instruction budget exceeded")
      {
        // The expected protected failure must release the VM and any proposal buffer.
      }
    }
  }
}
