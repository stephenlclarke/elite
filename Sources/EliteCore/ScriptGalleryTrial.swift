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
      && credits >= cabins * PassengerCabinGrade.economy.price
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
private enum ScriptGalleryAction: Sendable {
  case restart, returnToCommander, commitCampaign, consumed, unhandled
  case start(String)
  case resume(UUID)
}
private struct ScriptGalleryRestart: Sendable {
  let digest: String
  let seed: UInt64
  let target: URL
}
extension Game {
  var selectedGalleryMission: GalleryMission? {
    if let preview = gallery.campaignPreview { return preview }
    return galleryReadQuery().selected
  }

  public var canTrialSelectedMission: Bool {
    guard !isMissionTrial else { return false }
    return canTrialSelectedMission(galleryReadQuery())
  }

  func canTrialSelectedMission(_ query: GalleryReadQuery) -> Bool {
    guard !isMissionTrial, let digest = query.selected?.trialDigest else { return false }
    if digest == NativePeopleGallery.digest { return true }
    guard let pack = scriptPacks.first(where: { $0.digest == digest })
    else { return false }
    return isolatedMissionTrialAvailable(pack)
  }
  // Keep isolated trial storage out of the selected-entry/catalogue lookup frame.
  private func isolatedMissionTrialAvailable(_ pack: ScriptPack) -> Bool {
    guard pack.manifest.stateID != NativeInductionSeedPack.stateID,
      pack.digest != NativeInductionSeedPack.digest,
      pack.manifest.stateID != NativeInductionWorkshopPack.stateID,
      pack.digest != NativeInductionWorkshopPack.digest,
      pack.manifest.stateID != NativeInductionClinicPack.stateID,
      pack.digest != NativeInductionClinicPack.digest
    else { return false }
    guard pack.manifest.stateID != NativeInductionUtilityPack.stateID,
      pack.digest != NativeInductionUtilityPack.digest
    else { return false }
    guard pack.manifest.stateID != NativeInductionCrewLogPack.stateID,
      pack.digest != NativeInductionCrewLogPack.digest
    else { return false }
    guard pack.manifest.stateID != NativeInductionArkPack.stateID,
      pack.digest != NativeInductionArkPack.digest
    else { return false }
    guard pack.manifest.wayfarerInduction == nil,
      pack.manifest.stateID != NativeWayfarerInduction.stateID
    else { return false }
    guard pack.manifest.glassMeridian == nil, pack.manifest.stateID != NativeGlassMeridian.stateID
    else { return false }
    guard pack.manifest.flightReception == nil,
      pack.manifest.stateID != NativeFlightReception.stateID
    else { return false }
    var isolatedAvailability = self
    isolatedAvailability.scriptDurabilityAvailable = true
    isolatedAvailability.commander.scriptState = ScriptEngineState()
    return pack.manifest.mission.parentOnly != true
      && isolatedAvailability.scriptUnavailable(pack) == nil
      && isolatedAvailability.scriptAcceptanceIssue(pack) == nil
  }
  public var canRetrySelectedMission: Bool { canRetrySelectedMission(galleryReadQuery()) }

  func canRetrySelectedMission(_ query: GalleryReadQuery) -> Bool {
    guard let id = query.selected?.savedInstance,
      let state = commander.scriptState.instances[id],
      state.outcome == .active && state.suspension != nil || hasSuspendedWorldJobs(origin: id),
      let pack = scriptPack(for: state)
    else { return false }
    return scriptUnavailable(pack) == nil
      && (state.outcome != .active || campaignExecutionIssue(state) == nil)
  }
  func makeScriptTrial(packDigest: String, seed: UInt64) throws -> Game {
    var trial = try constructScriptTrial(packDigest: packDigest, seed: seed)
    try trial.prepareScriptTrial(packDigest: packDigest, seed: seed)
    return trial
  }
  func constructScriptTrial(packDigest: String, seed: UInt64) throws -> Game {
    if packDigest == NativePeopleGallery.digest {
      var trial = try constructNativePeopleTrial(seed: seed)
      try trial.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
      return trial
    }
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
      var commander = Commander()
      commander.shipID = scene.ship
      commander.galaxy = scene.galaxy
      commander.system = scene.system
      commander.credits = scene.credits
      commander.fuel = min(commander.fuel, commander.fuelCapacity)
      commander.missiles = min(commander.missiles, commander.missileCapacity)
      try commander.prepareEquipment(legacy: false)
      trial.commander = commander
      trial.ensureScriptCalendar(origin: .newCommander)
      trial.systems = Universe.systemsIncludingPlugh(number: scene.galaxy)
      trial.selectedSystem = scene.system
      trial.market = MarketItem.at(trial.currentSystem)
      trial.energy = trial.commander.performance.energy
      trial.frontShield = trial.commander.shieldCapacity
      trial.rearShield = trial.commander.shieldCapacity
      for _ in 0..<scene.cabins {
        try trial.confirmPassengerBerth(trial.passengerCabinQuote(.economy))
      }
    }
    // Reviews bind the physical property, mirrors and mining policy published by the writer.
    try trial.commander.prepareEquipment(legacy: false)
    trial.commander.mirrorFittedEquipment()
    try trial.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
    return trial
  }
  mutating func prepareScriptTrial(packDigest: String, seed: UInt64) throws {
    if packDigest == NativePeopleGallery.digest { return }
    guard let pack = scriptPacks.first(where: { $0.digest == packDigest }) else {
      throw MissionPackError("Choose an installed mission for a trial.")
    }
    if pack.manifest.freight != nil {
      try prepareFreightTrial(pack)
      return
    }
    if pack.manifest.procurement != nil {
      try prepareProcurementTrial(pack)
      return
    }
    if pack.manifest.board != nil {
      let key = try ensureContractBoard(pack)
      let offers = commander.contracts.boards[key]?.offers ?? []
      let index = pack.manifest.trial?.offer ?? 0
      guard offers.indices.contains(index) else {
        throw MissionPackError("This trial has no generated offer at the selected position.")
      }
      if pack.manifest.pledge != nil || pack.manifest.courier != nil {
        openContractBoard()
        guard
          let selection = contractBoard.rows.firstIndex(where: {
            $0.offer?.id == offers[index].id
          })
        else { throw MissionPackError("This pledge trial has no available board review.") }
        contractBoard.selection = selection
        contractBoardKey("return")
      } else {
        _ = try acceptContract(board: key, offer: offers[index].id)
      }
    } else {
      try prepareStandaloneTrialAcceptance(pack, seed: seed)
    }
    if pack.manifest.trial?.flight == true {
      launch()
      observeScriptLocation(
        wasDocked: true, galaxy: commander.galaxy, system: commander.system)
      drainScriptEvents()
    }
  }
  private mutating func prepareStandaloneTrialAcceptance(_ pack: ScriptPack, seed: UInt64) throws {
    var candidate = self
    let instanceID = try candidate.acceptScriptMission(
      pack, randomSeed: seed, drainAccepted: false)
    candidate.drainScriptEvents()
    if let reason = candidate.commander.scriptState.instances[instanceID]?.suspension {
      throw MissionPackError(reason)
    }
    self = candidate
  }
}
extension GameRuntime {
  static func newGalleryNamespace() -> URL {
    FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("elite-mission-gallery-" + UUID().uuidString, isDirectory: true)
  }
  public func startScriptGalleryTrial(packDigest: String, seed: UInt64 = 0x45_4c49_5445) throws {
    var candidate = try constructNewScriptGalleryTrial(packDigest: packDigest, seed: seed)
    try candidate.prepareScriptTrial(packDigest: packDigest, seed: seed)
    let namespace = Self.newGalleryNamespace()
    let target = namespace.appendingPathComponent("commander.json")
    try Self.writeCommander(&candidate, to: target)
    publishNewScriptGalleryTrial(&candidate, namespace: namespace, target: target)
  }
  // Construction reads the live game only before the candidate enters nested acceptance.
  private func constructNewScriptGalleryTrial(packDigest: String, seed: UInt64) throws -> Game {
    guard game.screen == .gallery, galleryNamespace == nil, galleryParent == nil else {
      throw MissionPackError("Return to your commander before starting another trial.")
    }
    return try constructScriptGalleryCandidate(packDigest: packDigest, seed: seed)
  }
  private func constructScriptGalleryCandidate(packDigest: String, seed: UInt64) throws -> Game {
    try game.constructScriptTrial(packDigest: packDigest, seed: seed)
  }
  // Capture the parent and publish only after the complete private trial save succeeds.
  private func publishNewScriptGalleryTrial(
    _ candidate: inout Game, namespace: URL, target: URL
  ) {
    galleryParent = GalleryParentState(game: game, controls: controls, saveURL: scriptSaveURL)
    galleryNamespace = namespace
    scriptSaveURL = target
    game = candidate
    controls = Controls()
    game.invalidateNativeStationAuthority()
    invalidateInventoryContext()
  }
  public func restartScriptGalleryTrial() throws {
    let restart = try scriptGalleryRestart()
    var candidate = try constructScriptGalleryCandidate(
      packDigest: restart.digest, seed: restart.seed)
    try candidate.prepareScriptTrial(packDigest: restart.digest, seed: restart.seed)
    try Self.writeCommander(&candidate, to: restart.target)
    publishRestartedScriptGalleryTrial(&candidate)
  }
  private func scriptGalleryRestart() throws -> ScriptGalleryRestart {
    guard galleryNamespace != nil, let digest = game.trialDigest, let seed = game.trialSeed,
      let target = scriptSaveURL
    else {
      throw MissionPackError("This runtime has no mission trial to restart.")
    }
    try requireGalleryFileAccess(target)
    return .init(digest: digest, seed: seed, target: target)
  }
  private func publishRestartedScriptGalleryTrial(_ candidate: inout Game) {
    game = candidate
    controls = Controls()
    game.invalidateNativeStationAuthority()
    invalidateInventoryContext()
  }
  public func returnFromScriptGalleryTrial() throws {
    guard let parent = galleryParent else {
      throw MissionPackError("This standalone trial has no live commander to return to.")
    }
    game = parent.game
    game.invalidateNativeStationAuthority()
    game.gallery.presentationGeneration = UUID()
    controls = parent.controls
    scriptSaveURL = parent.saveURL
    galleryNamespace = nil
    galleryParent = nil
    invalidateInventoryContext()
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
    switch prepareGalleryAction(key) {
    case .restart:
      restartGalleryAction()
    case .returnToCommander:
      returnGalleryAction()
    case .commitCampaign:
      commitCampaignGalleryTrial()
    case .start(let digest):
      startGalleryAction(packDigest: digest)
    case .resume(let id):
      resumeGalleryAction(id)
    case .consumed:
      break
    case .unhandled:
      return false
    }
    return true
  }
  // Finish selection and availability reads before an action enters a native transaction.
  private func prepareGalleryAction(_ key: String) -> ScriptGalleryAction {
    if key == "trial-restart"
      || (galleryNamespace != nil && game.screen == .gameOver && [" ", "return"].contains(key))
    {
      return .restart
    }
    if key == "trial-return" {
      return .returnToCommander
    }
    guard game.screen == .gallery else { return .unhandled }
    if game.gallery.campaignReview != nil {
      if key == "return", game.gallery.campaignStartSelected {
        return .commitCampaign
      }
      if ["t", "gallery-trial", "r", "mission-resume"].contains(key) { return .consumed }
      return .unhandled
    }
    if ["t", "gallery-trial"].contains(key) {
      if game.campaignImmediateOwner != nil {
        game.openCampaignTrialReview()
        return .consumed
      }
      game.gallery.presentationGeneration = UUID()
      do {
        guard game.canTrialSelectedMission, let digest = game.selectedGalleryMission?.trialDigest
        else {
          throw MissionPackError("This entry has no supported mission trial.")
        }
        return .start(digest)
      } catch {
        game.notify(error.localizedDescription)
        return .consumed
      }
    }
    if ["r", "mission-resume"].contains(key) {
      game.gallery.presentationGeneration = UUID()
      do {
        guard game.canRetrySelectedMission, let id = game.selectedGalleryMission?.savedInstance
        else {
          throw MissionPackError("Restore the exact saved content before retrying this mission.")
        }
        return .resume(id)
      } catch {
        game.notify(error.localizedDescription)
        return .consumed
      }
    }
    return .unhandled
  }
  private func restartGalleryAction() {
    do { try restartScriptGalleryTrial() } catch { notifyGalleryAction(error.localizedDescription) }
  }
  private func returnGalleryAction() {
    do { try returnFromScriptGalleryTrial() } catch {
      notifyGalleryAction(error.localizedDescription)
    }
  }
  private func startGalleryAction(packDigest: String) {
    do { try startScriptGalleryTrial(packDigest: packDigest) } catch {
      notifyGalleryAction(error.localizedDescription)
    }
  }
  private func resumeGalleryAction(_ id: UUID) {
    do {
      try resumeScriptMission(id)
      notifyGalleryAction("MISSION RESUMED")
    } catch { notifyGalleryAction(error.localizedDescription) }
  }
  private func notifyGalleryAction(_ text: String) {
    game.notify(text)
  }

  func commitCampaignGalleryTrial() {
    game.gallery.campaignTrialRequested = false
    game.gallery.presentationGeneration = UUID()
    guard let review = game.gallery.campaignReview,
      review == game.campaignTrialReview, game.gallery.campaignStartSelected
    else {
      game.gallery.campaignReview = nil
      game.notify("CAMPAIGN CHANGED - REVIEW ITS TRIAL AGAIN")
      return
    }
    let browsing = game.gallery
    game.gallery.campaignReview = nil
    game.gallery.campaignStartSelected = false
    do {
      try startScriptGalleryTrial(packDigest: review.digest)
    } catch {
      game.gallery = browsing
      game.gallery.campaignStartSelected = false
      game.notify(error.localizedDescription)
    }
  }

  /// Runtime forwarding keeps trial creation and save publication inside the simulation actor.
  public func campaignGalleryClick(x: Double, y: Double) {
    game.galleryClick(x: x, y: y)
    if game.gallery.campaignTrialRequested { commitCampaignGalleryTrial() }
  }
}
