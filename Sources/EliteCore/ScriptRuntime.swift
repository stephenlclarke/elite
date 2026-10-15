import Foundation

extension GameRuntime {
  public func loadScriptPacks(directory: URL) {
    let library = ScriptPackLibrary.installed(directory: directory)
    game.scriptPacks = library.packs
    game.suspendUnavailableScriptContent()
    for error in library.errors { game.notify(error) }
  }
  public func installScriptPack(from directory: URL, destination: URL) throws {
    guard galleryNamespace == nil else {
      throw MissionPackError("Install packs in the main game, then start a new Gallery trial.")
    }
    let pack = try ScriptPackLibrary.read(directory)
    _ = try ScriptPackLibrary.install(pack, directory: destination)
    if !game.scriptPacks.contains(where: { $0.digest == pack.digest }) {
      game.scriptPacks.append(pack)
    }
    game.notify(
      pack.missingCapabilities.isEmpty
        ? (pack.manifest.board == nil
          ? "MISSION PACK INSTALLED - VISIT STATION CONTACTS"
          : "CONTRACT PROVIDER INSTALLED - OPEN STATION CONTRACTS")
        : "MISSION REFERENCE INSTALLED - SEE MISSION GALLERY")
  }
  public func resumeScriptMission(_ id: UUID) throws {
    guard let state = game.commander.scriptState.instances[id],
      state.outcome == .active || game.hasSuspendedWorldJobs(origin: id),
      let pack = game.scriptPack(for: state),
      game.scriptUnavailable(pack) == nil,
      state.outcome != .active || game.campaignExecutionIssue(state) == nil
    else { throw MissionPackError("Restore the exact saved pack and its requirements.") }
    var candidate = game
    if state.outcome == .active { candidate.commander.scriptState.instances[id]?.suspension = nil }
    for jobID in candidate.commander.scriptState.worldJobs.keys {
      if candidate.commander.scriptState.worldJobs[jobID]?.origin == id {
        candidate.commander.scriptState.worldJobs[jobID]?.suspension = nil
      }
    }
    try scriptPublisher()?(&candidate)
    game = candidate
    game.drainScriptEvents(publish: scriptPublisher())
    game.retryPendingWorldJobs(origin: id, publish: scriptPublisher())
    if let reason = game.commander.scriptState.instances[id]?.suspension
      ?? game.worldJobSuspension(origin: id)
    {
      throw MissionPackError(reason)
    }
  }
  /// Gallery trials receive separate value state and have no access to live save writers or directories.
  public func scriptGalleryTrial(packDigest: String, seed: UInt64 = 0x45_4c49_5445) throws
    -> GameRuntime
  {
    let trial = try game.makeScriptTrial(packDigest: packDigest, seed: seed)
    return try GameRuntime(trialGame: trial)
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

extension GameRuntime {
  public func gallerySaveDirectory() -> URL? { galleryNamespace }
  func requireGalleryFileAccess(_ url: URL) throws {
    try Self.requireGalleryFileAccess(url, namespace: galleryNamespace)
  }
  static func requireGalleryFileAccess(_ url: URL, namespace: URL?) throws {
    try requireGalleryPathAccess(url, namespace: namespace)
    try requireGalleryPathAccess(url.appendingPathExtension("missions"), namespace: namespace)
  }
  static func requireGalleryPathAccess(_ url: URL, namespace: URL?) throws {
    guard let namespace else { return }
    let ownedRoot = namespace.standardizedFileURL.path
    guard namespace.resolvingSymlinksInPath().standardizedFileURL.path == ownedRoot else {
      throw MissionPackError(
        "The Gallery save folder has changed. Start a new trial to save safely.")
    }
    let target = url.resolvingSymlinksInPath().standardizedFileURL.path
    guard target.hasPrefix(ownedRoot + "/") else {
      throw MissionPackError(
        "Gallery trials use their own save folder and cannot replace production commanders.")
    }
  }
}
