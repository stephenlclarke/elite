import Foundation

public struct ScriptTrialDefinition: Codable, Sendable {
  public let ship: String
  public let galaxy: Int
  public let system: Int
  /// Decicredits; trial resources never come from the live commander.
  public let credits: Int
  public let cabins: Int
  public let flight: Bool
  public let offer: Int?
  var valid: Bool {
    guard let hull = ShipCatalogue.ship(ship), let performance = hull.game,
      let accommodation = try? ShipAccommodationProfile(ship: hull)
    else { return false }
    return (0..<8).contains(galaxy) && (0...255).contains(system)
      && (0...4_294_967_295).contains(credits) && (0...128).contains(cabins)
      && cabins * 5 <= performance.cargo && cabins <= accommodation.equipmentUnits
      && credits >= cabins * PassengerCabin.price
      && (offer.map { (0..<16).contains($0) } ?? true)
  }
}
struct GalleryParentState: Sendable {
  let game: Game
  let controls: Controls
  let saveURL: URL?
}
public struct CommanderFileReceipt: Sendable {
  public let url: URL
  public let isTrial: Bool
}
extension Game {
  var selectedGalleryMission: GalleryMission? {
    let missions = missionCatalogue
    return missions.indices.contains(gallery.selection) ? missions[gallery.selection] : nil
  }
  public var canTrialSelectedMission: Bool {
    guard !isMissionTrial, let digest = selectedGalleryMission?.trialDigest,
      let pack = scriptPacks.first(where: { $0.digest == digest })
    else { return false }
    var isolatedAvailability = self
    isolatedAvailability.scriptDurabilityAvailable = true
    isolatedAvailability.commander.scriptState = ScriptEngineState()
    return isolatedAvailability.scriptUnavailable(pack) == nil
      && isolatedAvailability.scriptAcceptanceIssue(pack) == nil
  }
  public var canRetrySelectedMission: Bool {
    guard let id = selectedGalleryMission?.savedInstance,
      let state = commander.scriptState.instances[id],
      state.outcome == .active && state.suspension != nil || hasSuspendedWorldJobs(origin: id),
      let pack = scriptPack(for: state)
    else { return false }
    return scriptUnavailable(pack) == nil
  }
  func makeScriptTrial(packDigest: String, seed: UInt64) throws -> Game {
    guard let pack = scriptPacks.first(where: { $0.digest == packDigest }) else {
      throw MissionPackError("Choose an installed mission for a trial.")
    }
    var trial = Game(executive: false)
    trial.screen = .status
    trial.scriptPacks = scriptPacks
    trial.missionPacks = missionPacks
    trial.scriptDurabilityAvailable = true
    trial.isMissionTrial = true
    trial.trialTitle = pack.manifest.mission.title
    trial.trialDigest = pack.digest
    trial.trialSeed = seed
    trial.viewportWidth = viewportWidth
    trial.viewportHeight = viewportHeight
    guard trial.scriptUnavailable(pack) == nil else {
      throw MissionPackError("This mission's native capabilities are not available for a trial.")
    }
    trial.ensureScriptCalendar(origin: .newCommander)
    trial.seedScriptTrial(seed)
    if let scene = pack.manifest.trial {
      trial.commander.shipID = scene.ship
      trial.commander.galaxy = scene.galaxy
      trial.commander.system = scene.system
      trial.commander.credits = scene.credits
      trial.commander.fuel = min(trial.commander.fuel, trial.commander.fuelCapacity)
      trial.commander.missiles = min(trial.commander.missiles, trial.commander.missileCapacity)
      trial.systems = Universe.systemsIncludingPlugh(number: scene.galaxy)
      trial.selectedSystem = scene.system
      trial.market = MarketItem.generate(economy: trial.currentSystem.economy, fluctuation: 0)
      trial.energy = trial.commander.performance.energy
      trial.frontShield = trial.commander.shieldCapacity
      trial.rearShield = trial.commander.shieldCapacity
      for _ in 0..<scene.cabins { try trial.confirmPassengerBerth(trial.passengerBerthQuote) }
    }
    if pack.manifest.board != nil {
      let key = try trial.ensureContractBoard(pack)
      let offers = trial.commander.contracts.boards[key]?.offers ?? []
      let index = pack.manifest.trial?.offer ?? 0
      guard offers.indices.contains(index) else {
        throw MissionPackError("This trial has no generated offer at the selected position.")
      }
      _ = try trial.acceptContract(board: key, offer: offers[index].id)
    } else {
      _ = try trial.acceptScriptMission(pack, randomSeed: seed)
    }
    if pack.manifest.trial?.flight == true {
      trial.launch()
      trial.observeScriptLocation(
        wasDocked: true, galaxy: trial.commander.galaxy, system: trial.commander.system)
      trial.drainScriptEvents()
    }
    return trial
  }
}
extension GameRuntime {
  static func newGalleryNamespace() -> URL {
    FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("elite-mission-gallery-" + UUID().uuidString, isDirectory: true)
  }
  public func startScriptGalleryTrial(packDigest: String, seed: UInt64 = 0x45_4c49_5445) throws {
    guard game.screen == .gallery, galleryNamespace == nil, galleryParent == nil else {
      throw MissionPackError("Return to your commander before starting another trial.")
    }
    var candidate = try game.makeScriptTrial(packDigest: packDigest, seed: seed)
    let namespace = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("elite-mission-gallery-" + UUID().uuidString, isDirectory: true)
    let target = namespace.appendingPathComponent("commander.json")
    try Self.writeCommander(&candidate, to: target)
    galleryParent = GalleryParentState(game: game, controls: controls, saveURL: scriptSaveURL)
    galleryNamespace = namespace
    scriptSaveURL = target
    game = candidate
    controls = Controls()
  }
  public func restartScriptGalleryTrial() throws {
    guard galleryNamespace != nil, let digest = game.trialDigest, let seed = game.trialSeed,
      let target = scriptSaveURL
    else {
      throw MissionPackError("This runtime has no mission trial to restart.")
    }
    try requireGalleryFileAccess(target)
    var candidate = try game.makeScriptTrial(packDigest: digest, seed: seed)
    try Self.writeCommander(&candidate, to: target)
    game = candidate
    controls = Controls()
  }
  public func returnFromScriptGalleryTrial() throws {
    guard let parent = galleryParent else {
      throw MissionPackError("This standalone trial has no live commander to return to.")
    }
    game = parent.game
    controls = parent.controls
    scriptSaveURL = parent.saveURL
    galleryNamespace = nil
    galleryParent = nil
  }
  public func saveForInterface(to requested: URL? = nil, expectedEpoch: UUID? = nil) throws
    -> CommanderFileReceipt
  {
    try requirePresentationEpoch(expectedEpoch)
    guard let target = requested ?? scriptSaveURL else {
      throw MissionPackError("Choose a commander save location first.")
    }
    let isTrial = galleryNamespace != nil
    try save(to: target)
    return CommanderFileReceipt(url: target, isTrial: isTrial)
  }
  public func loadForInterface(
    from requested: URL? = nil, persistMigrations: Bool = true, expectedEpoch: UUID? = nil
  ) throws
    -> CommanderFileReceipt
  {
    try requirePresentationEpoch(expectedEpoch)
    guard let target = requested ?? scriptSaveURL else {
      throw MissionPackError("Choose a commander save location first.")
    }
    let isTrial = galleryNamespace != nil
    try load(from: target, persistMigrations: persistMigrations)
    return CommanderFileReceipt(url: target, isTrial: isTrial)
  }
  private func requirePresentationEpoch(_ expected: UUID?) throws {
    guard expected == nil || expected == game.ecmControl.epoch else {
      throw MissionPackError("The commander context changed. Choose the file action again.")
    }
  }
  func galleryAction(_ key: String) -> Bool {
    if key == "trial-restart"
      || (galleryNamespace != nil && game.screen == .gameOver && [" ", "return"].contains(key))
    {
      do { try restartScriptGalleryTrial() } catch { game.notify(error.localizedDescription) }
      return true
    }
    if key == "trial-return" {
      do { try returnFromScriptGalleryTrial() } catch { game.notify(error.localizedDescription) }
      return true
    }
    guard game.screen == .gallery else { return false }
    if ["t", "gallery-trial"].contains(key) {
      do {
        guard game.canTrialSelectedMission, let digest = game.selectedGalleryMission?.trialDigest
        else {
          throw MissionPackError("This entry has no supported mission trial.")
        }
        try startScriptGalleryTrial(packDigest: digest)
      } catch { game.notify(error.localizedDescription) }
      return true
    }
    if ["r", "mission-resume"].contains(key) {
      do {
        guard game.canRetrySelectedMission, let id = game.selectedGalleryMission?.savedInstance
        else {
          throw MissionPackError("Restore the exact saved content before retrying this mission.")
        }
        try resumeScriptMission(id)
        game.notify("MISSION RESUMED")
      } catch { game.notify(error.localizedDescription) }
      return true
    }
    return false
  }
}
