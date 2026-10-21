import Foundation
import Testing

@testable import EliteCore

struct CampaignGalleryFixture {
  let directory: URL
  let child: ScriptPack
  let parents: [ScriptPack]
  let nested: ScriptPack
  var save: URL { directory.appendingPathComponent("save/commander.json") }

  init(
    unstarted: Bool = false, parentOnly: Bool = false, dependency: Bool = false,
    additionalAliases: Int = 0, retryFault: Bool = false
  ) throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "campaign-gallery-" + UUID().uuidString)
    let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let childFolder = directory.appendingPathComponent("child")
    try FileManager.default.copyItem(
      at: examples.appendingPathComponent("scripted-patrol"), to: childFolder)
    if parentOnly {
      let manifest = childFolder.appendingPathComponent("manifest.toml")
      let text = try String(contentsOf: manifest, encoding: .utf8)
        .replacingOccurrences(
          of: "\"classic-encounters-v2\"]",
          with: "\"classic-encounters-v2\", \"scoped-campaigns-basic-v2\"]"
        )
        .replacingOccurrences(of: "[mission]", with: "[mission]\nparentOnly=true")
      try text.write(to: manifest, atomically: true, encoding: .utf8)
    }
    if retryFault {
      let module = childFolder.appendingPathComponent("scripts/main.lua")
      let text = try String(contentsOf: module, encoding: .utf8)
        .replacingOccurrences(
          of: "function M.contact(e,w,d)",
          with:
            "function M.contact(e,w,d)\n  if w.credits<2000 then error('More working capital required') end"
        )
      try text.write(to: module, atomically: true, encoding: .utf8)
    }
    child = try ScriptPackLibrary.read(childFolder)
    var loaded: [ScriptPack] = []
    for index in 0..<2 {
      let folder = directory.appendingPathComponent("parent\(index)")
      try FileManager.default.copyItem(
        at: examples.appendingPathComponent("scoped-patrol"), to: folder)
      let manifest = folder.appendingPathComponent("manifest.toml")
      var text = try String(contentsOf: manifest, encoding: .utf8)
        .replacingOccurrences(of: "example.scoped-patrol", with: "test.gallery-\(index)")
        .replacingOccurrences(
          of: "Owned patrol campaign demonstration", with: "Campaign \(index + 1)"
        )
        .replacingOccurrences(
          of: "f7c2123ea24e13e6d8e613a72270a052ae6b5a010e4edb678ab10a239f185906",
          with: child.digest)
      if dependency, index == 0 {
        text = text.replacingOccurrences(
          of: "priority = 540",
          with: "priority = 540\ndependencies = [\"test.gallery-1@1.0.0\"]")
      }
      for alias in 0..<additionalAliases {
        let declaration = """
          [[children]]
          id = "alternate-\(alias)"
          definition = "\(child.manifest.stateID)"
          version = "1.0.0"
          digest = "\(child.digest)"
          terminalPolicy = "suspend"

          [[receiptRequirements]]
          """
        text = text.replacingOccurrences(of: "[[receiptRequirements]]", with: declaration)
      }
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      if unstarted {
        let module = folder.appendingPathComponent("scripts/main.lua")
        let source = try String(contentsOf: module, encoding: .utf8)
          .replacingOccurrences(
            of: "commands={{op='child.ensure',id='patrol'}}}", with: "commands={}}")
        try source.write(to: module, atomically: true, encoding: .utf8)
      }
      loaded.append(try ScriptPackLibrary.read(folder))
    }
    parents = loaded
    let folder = directory.appendingPathComponent("nested")
    try FileManager.default.copyItem(at: directory.appendingPathComponent("parent0"), to: folder)
    let manifest = folder.appendingPathComponent("manifest.toml")
    let text = try String(contentsOf: manifest, encoding: .utf8)
      .replacingOccurrences(of: "test.gallery-0", with: "test.gallery-root")
      .replacingOccurrences(of: "Campaign 1", with: "Root campaign")
      .replacingOccurrences(of: child.manifest.stateID, with: parents[0].manifest.stateID)
      .replacingOccurrences(of: child.digest, with: parents[0].digest)
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    nested = try ScriptPackLibrary.read(folder)
  }

  func clean() { try? FileManager.default.removeItem(at: directory) }

  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [child] + parents + [nested]
    game.scriptDurabilityAvailable = true
    return game
  }

  func prepareNativeCommanderForComparison(_ game: inout Game) throws {
    let before = game.commander
    try game.commander.prepareEquipment()
    game.commander.mirrorFittedEquipment()
    try #require(game.commander.savedEquipmentVersion == 2)
    #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
    #expect(game.commander.shipID == before.shipID && game.commander.name == before.name)
    #expect(game.commander.fuel == before.fuel && game.commander.missiles == before.missiles)
    #expect(game.commander.scriptState == before.scriptState)
    #expect(game.commander.contracts == before.contracts)
    #expect(game.commander.accommodation == before.accommodation)
  }

  func start(_ game: inout Game, parent: ScriptPack? = nil) throws -> (UUID, UUID) {
    let id = try game.acceptScriptMission(parent ?? parents[0])
    for _ in 0..<8 { game.drainScriptEvents() }
    return (
      id, try #require(game.commander.scriptState.instances[id]?.campaignChildren["patrol"]?.child)
    )
  }

  func select(_ id: UUID, game: inout Game) throws {
    if game.screen != .gallery { game.openGallery() }
    game.gallery.selection = try #require(
      game.missionCatalogue.firstIndex { $0.savedInstance == id })
    game.gallery.detail = true
    game.pinGallerySelection()
  }

  func startContractCampaign(_ game: inout Game, nested: Bool = false) throws
    -> (root: UUID, child: UUID, provider: ScriptPack)
  {
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-contracts")
    let folder = directory.appendingPathComponent("contract-campaign")
    try FileManager.default.copyItem(at: source, to: folder)
    let member = nested ? parents[0] : child
    let manifest = folder.appendingPathComponent("manifest.toml")
    let declaration = """

      [[children]]
      id = "patrol"
      definition = "\(member.manifest.stateID)"
      version = "\(member.manifest.version)"
      digest = "\(member.digest)"
      terminalPolicy = "suspend"
      """
    let text = try String(contentsOf: manifest, encoding: .utf8)
      .replacingOccurrences(
        of: "\"durable-commands-v2\"]",
        with: "\"durable-commands-v2\", \"scoped-campaigns-basic-v2\"]")
    try (text + declaration + "\n").write(to: manifest, atomically: true, encoding: .utf8)
    let module = folder.appendingPathComponent("scripts/main.lua")
    let script = try String(contentsOf: module, encoding: .utf8)
      .replacingOccurrences(
        of: "{op = \"payload.add\", id = \"collect-samples\"",
        with:
          "{op = \"child.ensure\", id = \"patrol\"},\n      {op = \"payload.add\", id = \"collect-samples\""
      )
    try script.write(to: module, atomically: true, encoding: .utf8)
    let provider = try ScriptPackLibrary.read(folder)
    game.scriptPacks.append(provider)
    let key = try game.ensureContractBoard(provider)
    let offer = try #require(game.commander.contracts.boards[key]?.offers.first)
    let root = try game.acceptContract(board: key, offer: offer.id)
    for _ in 0..<8 { game.drainScriptEvents() }
    let direct = try #require(
      game.commander.scriptState.instances[root]?.campaignChildren["patrol"]?.child)
    let selected =
      nested
      ? try #require(
        game.commander.scriptState.instances[direct]?.campaignChildren["patrol"]?.child)
      : direct
    #expect(game.commander.valid)
    #expect(game.commander.scriptState.instances[root]?.contract?.offer.id == offer.id)
    #expect(game.commander.credits == 1000 - offer.deposit)
    #expect(game.commander.contracts.boards[key]?.offers.first?.status == .accepted(root))
    return (root, selected, provider)
  }
}

@Test(arguments: [false, true])
func campaignGallerySavedContractRootRefusesChildTrialAndPreservesProviderTrial(nested: Bool)
  async throws
{
  let fixture = try CampaignGalleryFixture(parentOnly: true)
  defer { fixture.clean() }
  var game = fixture.game()
  let campaign = try fixture.startContractCampaign(&game, nested: nested)
  game.commander.name = "LIVE OWNER"
  #expect(game.commander.valid)
  let savedRoot = try #require(
    game.missionCatalogue.first { $0.savedInstance == campaign.root })
  #expect(savedRoot.trialDigest == nil)
  try fixture.select(campaign.child, game: &game)
  #expect(game.campaignTrialRoot?.id == campaign.root)
  #expect(game.campaignImmediateOwner != nil)
  #expect(
    game.campaignTrialUnavailableReason == "Trials of saved contract assignments are not supported."
  )
  #expect(game.campaignTrialReview == nil && !game.canReviewSelectedCampaignTrial)
  #expect(!game.canTrialSelectedMission)
  // Match the actor's canonical equipment preparation before checking rejected UI actions.
  let unprepared = game.commander
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  try #require(game.commander.savedEquipmentVersion == 2)
  #expect(game.commander.credits == unprepared.credits && game.commander.cargo == unprepared.cargo)
  #expect(game.commander.shipID == unprepared.shipID && game.commander.name == unprepared.name)
  #expect(game.commander.fuel == unprepared.fuel && game.commander.missiles == unprepared.missiles)
  #expect(game.commander.scriptState == unprepared.scriptState)
  #expect(game.commander.contracts == unprepared.contracts)
  #expect(game.commander.accommodation == unprepared.accommodation)
  let before = game.commander
  let epoch = game.ecmControl.epoch
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  #expect(await runtime.snapshot().commander == before)
  try await runtime.save(to: fixture.save)
  #expect(await runtime.snapshot().commander == before)
  let bytes = try Data(contentsOf: fixture.save)
  await runtime.key("t")
  await runtime.key("return")
  let links = await runtime.snapshot()
  #expect(links.gallery.campaignLinks)
  let layout = GalleryLayout(width: game.viewportWidth, height: game.viewportHeight)
  await runtime.campaignGalleryClick(x: 20, y: layout.listTop + layout.linkHeight + 1)
  #expect(await runtime.snapshot().gallery.campaignReview == nil)
  #expect(await runtime.gallerySaveDirectory() == nil)
  #expect(await runtime.snapshot().ecmControl.epoch == epoch)
  #expect(await runtime.snapshot().commander == before)
  await runtime.key("up")
  await runtime.key("return")
  #expect(
    await runtime.snapshot().selectedGalleryMission?.savedInstance == game.campaignImmediateOwner)
  #expect(try Data(contentsOf: fixture.save) == bytes)

  var provider = await runtime.snapshot()
  provider.gallery.campaignHistory = []
  provider.gallery.campaignLinks = false
  provider.gallery.campaignSelection = nil
  provider.gallery.selection = try #require(
    provider.missionCatalogue.firstIndex {
      $0.savedInstance == nil && $0.trialDigest == campaign.provider.digest
    })
  provider.pinGallerySelection()
  #expect(provider.canTrialSelectedMission)
  let providerSelection = provider
  await runtime.nativeCommand { @Sendable candidate in candidate = providerSelection }
  await runtime.key("t")
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let trial = await runtime.snapshot()
  #expect(trial.isMissionTrial && trial.trialDigest == campaign.provider.digest)
  #expect(trial.commander.valid)
  // Native board IDs are deterministic; isolated worlds may generate the same offer UUID.
  #expect(trial.commander.name != before.name && trial.commander != before)
  #expect(trial.ecmControl.epoch != epoch)
  #expect(trial.commander.scriptState.instances.values.contains { $0.contract != nil })
  #expect(try Data(contentsOf: fixture.save) == bytes)
  await runtime.key("trial-return")
  #expect(await runtime.snapshot().commander == before)
  #expect(try Data(contentsOf: fixture.save) == bytes)
}

@Test func campaignGalleryNavigatesTwoActualParentsByInstanceAndRestoresReadingPosition() throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let first = try fixture.start(&game)
  let second = try fixture.start(&game, parent: fixture.parents[1])
  let before = game.commander
  for (parent, child) in [first, second] {
    try fixture.select(parent, game: &game)
    #expect(game.selectedCampaignAssignments.map(\.instance) == [child])
    #expect(game.selectedCampaignAssignments[0].status == "Active")
    #expect(!game.selectedCampaignAssignments[0].objective.isEmpty)
    game.gallery.scroll = 4
    game.key("return")
    game.key("return")
    #expect(game.selectedGalleryMission?.savedInstance == child)
    #expect(game.campaignImmediateOwner == parent && game.campaignTrialRoot?.id == parent)
    #expect(
      game.galleryDetailLines(width: 480, font: GameTypography.scale).contains {
        $0.hasPrefix("Part of Campaign")
      })
    game.key("escape")
    #expect(game.selectedGalleryMission?.savedInstance == parent && game.gallery.scroll == 4)
    #expect(game.gallery.campaignLinks)
    game.key("return")
    game.key("return")
    game.key("return")
    #expect(game.selectedGalleryMission?.savedInstance == parent)
  }
  #expect(game.commander == before)
}

@Test func campaignGalleryNestedChildUsesImmediateOwnerAndSeparateRootForTrial() throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (root, owner) = try fixture.start(&game, parent: fixture.nested)
  let child = try #require(
    game.commander.scriptState.instances[owner]?.campaignChildren["patrol"]?.child)
  try fixture.select(child, game: &game)
  #expect(game.campaignImmediateOwner == owner && game.campaignTrialRoot?.id == root)
  #expect(game.campaignTrialReview?.digest == fixture.nested.digest)
  game.key("return")
  game.key("return")
  #expect(game.selectedGalleryMission?.savedInstance == owner)
  #expect(game.campaignImmediateOwner == root)
}

@Test func campaignGalleryUnstartedPreviewAndMissingContentNeverCreateOrDiscardInstances() throws {
  let fixture = try CampaignGalleryFixture(unstarted: true)
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parents[0])
  try fixture.select(parent, game: &game)
  let before = game.commander
  #expect(game.selectedCampaignAssignments[0].status == "Not started")
  game.key("return")
  game.key("return")
  #expect(game.selectedGalleryMission?.savedInstance == nil)
  #expect(game.selectedGalleryMission?.destination == "Not started")
  #expect(game.campaignImmediateOwner == parent)
  #expect(game.campaignTrialReview?.root == parent)
  game.key("escape")
  #expect(game.selectedGalleryMission?.savedInstance == parent)
  game.scriptPacks.removeAll { $0.digest == fixture.child.digest }
  #expect(
    game.selectedCampaignAssignments[0].unavailableReason == "Restore the exact assignment content."
  )
  #expect(game.commander == before)
}

@Test(arguments: [ScriptOutcome.active, .complete, .failed, .abandoned])
func campaignGalleryDisplaysActualChildOutcomesAndKeepsSuspensionReason(outcome: ScriptOutcome)
  throws
{
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (parent, child) = try fixture.start(&game)
  // Projection fixture only: terminal engine transitions are covered by physical-play acceptance.
  game.commander.scriptState.instances[child]?.outcome = outcome
  game.commander.scriptState.instances[child]?.suspension = "Restore the original ship model."
  try fixture.select(parent, game: &game)
  let before = game.commander
  let row = try #require(game.selectedCampaignAssignments.first)
  #expect(row.status == (outcome == .active ? "Suspended" : outcome.rawValue.capitalized))
  #expect(row.unavailableReason == "Restore the original ship model.")
  #expect(game.commander == before)
}

@Test func campaignGalleryMissingOwnerAndRootKeepChildVisibleAndTrialUnavailable() throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (parent, child) = try fixture.start(&game)
  game.scriptPacks = [fixture.child]
  try fixture.select(child, game: &game)
  let before = game.commander
  #expect(game.campaignTrialUnavailableReason == "Restore the exact root campaign content.")
  game.key("return")
  game.key("return")
  #expect(game.selectedGalleryMission?.savedInstance == parent)
  #expect(game.selectedCampaignAssignments[0].instance == child)
  #expect(game.commander == before)
}

@Test func campaignGalleryOwnedTrialReviewRequiresChoiceAndRejectsChangedSelection() async throws {
  let fixture = try CampaignGalleryFixture(parentOnly: true)
  defer { fixture.clean() }
  var game = fixture.game()
  let first = try fixture.start(&game)
  let second = try fixture.start(&game, parent: fixture.parents[1])
  try fixture.select(first.1, game: &game)
  #expect(!game.canTrialSelectedMission)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let before = await runtime.snapshot().commander
  await runtime.key("t")
  await runtime.key("t")
  #expect(await runtime.gallerySaveDirectory() == nil)
  #expect(await runtime.snapshot().gallery.campaignReview?.root == first.0)
  await runtime.key("return")
  #expect(await runtime.snapshot().gallery.campaignReview == nil)
  await runtime.key("t")
  await runtime.key("down")
  let changedIndex = try #require(game.missionCatalogue.firstIndex { $0.savedInstance == second.1 })
  await runtime.nativeCommand { $0.gallery.selection = changedIndex }
  await runtime.key("return")
  #expect(await runtime.gallerySaveDirectory() == nil)
  #expect(await runtime.snapshot().commander == before)
  #expect(await runtime.snapshot().message.contains("CAMPAIGN CHANGED"))
}

@Test func campaignGalleryPointerAndKeyboardChooseTheSameActualChild() async throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (parent, child) = try fixture.start(&game)
  try fixture.select(parent, game: &game)
  try fixture.prepareNativeCommanderForComparison(&game)
  let before = game.commander
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  #expect(await runtime.snapshot().commander == before)
  let layout = GalleryLayout(width: game.viewportWidth, height: game.viewportHeight)
  await runtime.campaignGalleryClick(x: 20, y: layout.actionTop + 1)
  await runtime.campaignGalleryClick(x: 20, y: layout.listTop + 1)
  #expect(await runtime.snapshot().selectedGalleryMission?.savedInstance == child)
  await runtime.key("escape")
  #expect(await runtime.snapshot().selectedGalleryMission?.savedInstance == parent)
  #expect(await runtime.snapshot().commander == before)
}

@Test func campaignGalleryRootTrialFliesItsOwnedPatrolAndRestoresLiveSaveBytes() async throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var live = fixture.game()
  live.commander.name = "CAMPAIGN OWNER"
  live.commander.credits = 76543
  let first = try fixture.start(&live)
  let second = try fixture.start(&live, parent: fixture.parents[1])
  let runtime = GameRuntime(game: live, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let original = await runtime.snapshot()
  let bytes = try Data(contentsOf: fixture.save)
  await runtime.key("gallery-open")
  let index = try #require(original.missionCatalogue.firstIndex { $0.savedInstance == second.1 })
  for _ in 0..<index { await runtime.key("down") }
  await runtime.key("return")
  let liveSelection = await runtime.snapshot()
  await runtime.key("t")
  #expect(await runtime.snapshot().gallery.campaignReview?.root == second.0)
  await runtime.key("down")
  await runtime.key("return")
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let initialTrial = await runtime.snapshot()
  await runtime.key("trial-restart")
  var actual = await runtime.advance(delta: 0.1)
  #expect(actual.ecmControl.epoch != initialTrial.ecmControl.epoch)
  #expect(actual.commander.credits == initialTrial.commander.credits)
  #expect(actual.commander.shipID == initialTrial.commander.shipID)
  let root = try #require(
    actual.commander.scriptState.instances.values.first { $0.campaignParent == nil })
  let child = try #require(root.campaignChildren["patrol"]?.child)
  #expect(root.digest == fixture.parents[1].digest)
  #expect(actual.commander.scriptState.instances[first.0] == nil)
  #expect(actual.commander.scriptState.instances[second.0] == nil)
  #expect(actual.commander.scriptState.instances[child]?.campaignParent?.parent == root.id)
  #expect(actual.commander.scriptState.calendarSeconds == 0.1)
  #expect(actual.ecmControl.epoch != liveSelection.ecmControl.epoch)
  // Test hardware setup only; targets, destruction, docking and receipts use native gameplay.
  let beforeHardware = await runtime.snapshot().commander
  await runtime.nativeCommand { game in
    do {
      try game.commander.grantEquipment(
        TargetingTier.docking.equipmentName, at: .targetingCore, provenance: .legacyUnknown)
    } catch { Issue.record(error) }
  }
  let fitted = await runtime.snapshot().commander
  try #require(fitted.hasAutomaticDocking)
  #expect(
    fitted.fittedEquipment(at: .targetingCore)?.node.key == TargetingTier.docking.equipmentName)
  #expect(fitted.credits == beforeHardware.credits && fitted.cargo == beforeHardware.cargo)
  #expect(fitted.scriptState == beforeHardware.scriptState)
  #expect(
    fitted.contracts == beforeHardware.contracts
      && fitted.accommodation == beforeHardware.accommodation)
  await runtime.key("0")
  let legalBefore = await runtime.snapshot().commander.legal
  try #require(legalBefore == 0)
  let beforeFire = campaignPatrolDiagnostic(await runtime.snapshot(), child: child)
  var observedFlash = false
  var firing = Controls()
  for _ in 0..<200 {
    firing = Controls()
    if try campaignPatrolOutsideStationZone(await runtime.snapshot()) {
      try await selectCampaignPatrolTarget(runtime, child: child)
      firing.fire = try campaignPatrolHasActualLaserContact(await runtime.snapshot(), child: child)
    }
    await runtime.setControls(firing)
    actual = await runtime.advance(delta: 0.1)
    observedFlash = observedFlash || actual.laserFlash > 0
    if actual.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.destroyed == true
    {
      break
    }
  }
  #expect(
    actual.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.destroyed == true,
    Comment(
      rawValue: "beforeFire: \(beforeFire); observedFlash=\(observedFlash); afterFire: "
        + campaignPatrolDiagnostic(actual, child: child)))
  #expect(
    actual.commander.legal == legalBefore,
    Comment(rawValue: campaignPatrolDiagnostic(actual, child: child)))
  await runtime.setControls(Controls())
  for _ in 0..<8 {
    await runtime.key("r")
    if await runtime.snapshot().autoPilot.targetID == 0 { break }
  }
  let beforeDock = campaignPatrolDiagnostic(await runtime.snapshot(), child: child)
  for _ in 0..<5000 {
    actual = await runtime.advance(delta: 0.02)
    if actual.docked { break }
  }
  #expect(
    actual.docked && actual.dockedAtMainStation,
    Comment(
      rawValue: "afterStationSelection: \(beforeDock); afterDockFlight: "
        + campaignPatrolDiagnostic(actual, child: child)))
  #expect(actual.commander.legal == legalBefore)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().scriptOffer == child)
  let report = await runtime.snapshot().scriptPagePresentation
  await runtime.scriptPageKey("return", expected: report)
  _ = await runtime.advance(delta: 0.1)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().scriptOffer == root.id)
  let debrief = await runtime.snapshot().scriptPagePresentation
  await runtime.scriptPageKey("return", expected: debrief)
  let completed = await runtime.snapshot()
  #expect(completed.commander.scriptState.instances[root.id]?.outcome == .complete)
  #expect(
    completed.commander.scriptState.instances[root.id]?.receiptJoins?["owned-report"] == [child])
  let saved = try await runtime.saveForInterface(expectedEpoch: completed.ecmControl.epoch)
  #expect(saved.isTrial && saved.url.path.hasPrefix(namespace.path + "/"))
  _ = try campaignExpectedDiskCommander(
    completed.commander, await runtime.snapshot().commander,
    system: await runtime.snapshot().systemIdentity, url: saved.url)
  _ = try await runtime.loadForInterface(expectedEpoch: completed.ecmControl.epoch)
  let restoredCommander = await runtime.snapshot().commander
  try campaignReloadEvidence(
    completed.commander, restoredCommander, name: "root-gallery-docked-reload")
  let restoredMatchesWholeExpectedCommander = restoredCommander == completed.commander
  #expect(restoredMatchesWholeExpectedCommander)
  #expect(try Data(contentsOf: fixture.save) == bytes)
  await runtime.key("trial-return")
  let restored = await runtime.snapshot()
  #expect(restored.commander == original.commander)
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  #expect(
    try encoder.encode(restored.scriptWorldSave) == encoder.encode(liveSelection.scriptWorldSave))
  #expect(restored.gallery.selection == index && restored.gallery.detail)
  #expect(restored.gallery.campaignReview == nil && !restored.gallery.campaignStartSelected)
  #expect(restored.ecmControl.epoch == liveSelection.ecmControl.epoch)
  #expect(try Data(contentsOf: fixture.save) == bytes)
  await #expect(throws: MissionPackError.self) {
    _ = try await runtime.saveForInterface(expectedEpoch: completed.ecmControl.epoch)
  }
}

@Test func campaignGalleryUnavailableRequirementsAndExistingTrialCannotLaunchAnotherRoot()
  async throws
{
  let fixture = try CampaignGalleryFixture(dependency: true)
  defer { fixture.clean() }
  var game = fixture.game()
  let (_, child) = try fixture.start(&game)
  try fixture.select(child, game: &game)
  game.scriptPacks.removeAll { $0.digest == fixture.parents[1].digest }
  // Establish the same native state as GameRuntime.init without changing campaign property.
  let unprepared = game.commander
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  try #require(game.commander.savedEquipmentVersion == 2)
  #expect(game.commander.credits == unprepared.credits && game.commander.cargo == unprepared.cargo)
  #expect(game.commander.shipID == unprepared.shipID && game.commander.name == unprepared.name)
  #expect(game.commander.fuel == unprepared.fuel && game.commander.missiles == unprepared.missiles)
  #expect(game.commander.scriptState == unprepared.scriptState)
  #expect(game.commander.contracts == unprepared.contracts)
  #expect(game.commander.accommodation == unprepared.accommodation)
  let before = game.commander
  #expect(game.campaignTrialUnavailableReason == "Requires: test.gallery-1@1.0.0")
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  #expect(await runtime.snapshot().commander == before)
  await runtime.key("t")
  #expect(await runtime.snapshot().gallery.campaignReview == nil)
  #expect(await runtime.gallerySaveDirectory() == nil)
  #expect(await runtime.snapshot().commander == before)
  game.scriptPacks.append(fixture.parents[1])
  game.isMissionTrial = true
  #expect(
    game.campaignTrialUnavailableReason == "Return to your commander before starting another trial."
  )
  #expect(game.campaignTrialReview == nil)
}

@Test func campaignGalleryPointerBackAndScrollingPreserveExactRelationshipContext() throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (parent, child) = try fixture.start(&game)
  try fixture.select(child, game: &game)
  let before = game.commander
  game.key("return")
  game.key("gallery-scroll:1")
  #expect(game.gallery.campaignLinkSelection == 1)
  game.key("pageup")
  #expect(game.gallery.campaignLinkSelection == 0)
  game.key("pagedown")
  #expect(game.gallery.campaignLinkSelection == 1)
  game.key("gallery-scroll:-1")
  game.key("return")
  #expect(game.selectedGalleryMission?.savedInstance == parent)
  game.galleryClick(x: 30, y: 80)
  #expect(game.selectedGalleryMission?.savedInstance == child)
  #expect(game.gallery.campaignLinks)
  #expect(game.commander == before)
}

@Test func campaignGalleryLayoutKeepsRelationshipTextAndActionsInsideBothViewports() throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (parent, child) = try fixture.start(&game)
  for (width, height) in [(512.0, 518.0), (1512.0, 982.0)] {
    game.viewportWidth = width
    game.viewportHeight = height
    for id in [parent, child] {
      try fixture.select(id, game: &game)
      game.gallery.campaignLinks = false
      for links in [false, true] {
        game.gallery.campaignLinks = links
        let frame = Display.gallery(game, width: width, height: height)
        #expect(
          frame.labels.allSatisfy {
            $0.bounds.x >= 0 && $0.bounds.maxX <= width
              && $0.bounds.y >= 0 && $0.bounds.maxY <= height
          })
      }
    }
    game.gallery.detail = false
    game.gallery.campaignLinks = false
    if width >= 900 {
      let layout = GalleryLayout(width: width, height: height)
      game.galleryClick(x: layout.divider + 20, y: layout.actionTop + 1)
      #expect(game.gallery.campaignLinks && game.gallery.detail)
    }
    game.openCampaignTrialReview()
    let frame = Display.gallery(game, width: width, height: height)
    #expect(frame.labels.contains { $0.text == "> Back" })
    #expect(frame.labels.allSatisfy { $0.bounds.maxX <= width && $0.bounds.maxY <= height })
    game.key("escape")
  }
}

@Test func campaignGalleryMissingChildBlocksTheOwningRootTrialWithoutChangingItsSave() async throws
{
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (_, child) = try fixture.start(&game)
  try fixture.select(child, game: &game)
  try fixture.prepareNativeCommanderForComparison(&game)
  let before = game.commander
  game.scriptPacks.removeAll { $0.digest == fixture.child.digest }
  #expect(game.selectedGalleryMission?.savedInstance == child)
  #expect(game.campaignTrialUnavailableReason == "Restore the exact campaign assignment content.")
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  #expect(await runtime.snapshot().commander == before)
  await runtime.key("t")
  #expect(await runtime.gallerySaveDirectory() == nil)
  #expect(await runtime.snapshot().commander == before)
}

@Test func campaignGalleryProofDistinguishesPreviewAliasesAndStaysCompact() throws {
  let fixture = try CampaignGalleryFixture(unstarted: true, additionalAliases: 1)
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parents[0])
  try fixture.select(parent, game: &game)
  let before = game.commander
  game.followCampaignGalleryLink(0)
  let first = game.scriptPagePresentation
  game.key("escape")
  game.followCampaignGalleryLink(1)
  let second = game.scriptPagePresentation
  #expect(first != second)
  #expect(game.selectedGalleryMission?.name == fixture.child.manifest.mission.title)
  let bytes = try JSONEncoder().encode(second)
  #expect(bytes.count <= 1024 && bytes.base64EncodedString().utf8.count <= 1400)
  #expect(try JSONDecoder().decode(ScriptPagePresentation.self, from: bytes) == second)
  #expect(game.commander == before)
}

@Test func campaignGallerySamePaintedReviewChoosesOnceAndOldReturnCannotRestartIt() async throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (_, child) = try fixture.start(&game)
  try fixture.select(child, game: &game)
  try fixture.prepareNativeCommanderForComparison(&game)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  #expect(await runtime.snapshot().commander == game.commander)
  let childPage = await runtime.snapshot().scriptPagePresentation
  await runtime.scriptPageKey("t", expected: childPage)
  await runtime.scriptPageKey("return", expected: childPage)
  #expect(await runtime.gallerySaveDirectory() == nil)
  let review = await runtime.snapshot().scriptPagePresentation
  await runtime.scriptPageKey("down", expected: review)
  #expect(await runtime.snapshot().scriptPagePresentation == review)
  await runtime.scriptPageKey("return", expected: review)
  let directory = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: directory) }
  let trial = await runtime.snapshot().commander
  await runtime.scriptPageKey("return", expected: review)
  #expect(await runtime.snapshot().commander == trial)
  await runtime.key("trial-return")
  let restored = await runtime.snapshot()
  #expect(restored.commander == game.commander)
  #expect(restored.scriptPagePresentation != childPage)
  await runtime.scriptPageKey("t", expected: childPage)
  await runtime.scriptPageKey("return", expected: review)
  #expect(await runtime.gallerySaveDirectory() == nil)
}

@Test func campaignGalleryProofBindsScrollResizeRetryRevisionAndRowReordering() async throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.viewportWidth = 512
  game.viewportHeight = 518
  let (_, child) = try fixture.start(&game)
  try fixture.select(child, game: &game)
  let before = game.commander
  let page = game.scriptPagePresentation
  game.key("down")
  #expect(game.scriptPagePresentation != page)
  let scrolled = game.scriptPagePresentation
  game.viewportWidth = 1512
  game.viewportHeight = 982
  #expect(game.scriptPagePresentation != scrolled)
  let oldIndex = game.resolvedGallerySelection
  let originalEntry = game.scriptGalleryPageIdentity.entry
  game.scriptPacks.removeAll { $0.digest == fixture.parents[1].digest }
  #expect(game.selectedGalleryMission?.savedInstance == child)
  #expect(game.scriptGalleryPageIdentity.entry == originalEntry)
  #expect(game.resolvedGallerySelection != oldIndex)
  #expect(game.commander == before)
  // A saved native fault/revision boundary; no successful gameplay outcome is manufactured.
  game.commander.scriptState.instances[child]?.suspension = "Restore requirements."
  let retry = game.scriptPagePresentation
  game.commander.scriptState.instances[child]?.revision += 1
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  await runtime.scriptPageKey("mission-resume", expected: retry)
  #expect(await runtime.snapshot().commander.scriptState.instances[child]?.suspension != nil)
}

@Test func campaignGalleryProofRejectsCrossPageCommandsAndChangedVisibleLinkMaps() async throws {
  let fixture = try CampaignGalleryFixture(unstarted: true, additionalAliases: 5)
  defer { fixture.clean() }
  var game = fixture.game()
  game.viewportWidth = 512
  game.viewportHeight = 518
  let parent = try game.acceptScriptMission(fixture.parents[0])
  try fixture.select(parent, game: &game)
  game.key("return")
  let original = game.scriptPagePresentation
  game.key("pagedown")
  #expect(game.scriptPagePresentation != original)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let before = await runtime.snapshot().commander
  await runtime.scriptPageClick(x: 20, y: 105, expected: original)
  #expect(await runtime.snapshot().gallery.campaignPreview == nil)
  let gallery = await runtime.snapshot().scriptPagePresentation
  for key in ["0", "trial-return", "commander-save-default", "unknown", "mission-resume"] {
    await runtime.scriptPageKey(key, expected: gallery)
  }
  let offer = ScriptPagePresentation(epoch: gallery.epoch, page: .offer(fixture.parents[0].digest))
  await runtime.scriptPageKey("gallery-trial", expected: offer)
  #expect(await runtime.snapshot().commander == before)
  #expect(await runtime.gallerySaveDirectory() == nil)
}

@Test func campaignGalleryFailedRetryConsumesItsPaintedAttemptEvenIfTheFaultRepeats() async throws {
  let fixture = try CampaignGalleryFixture(retryFault: true)
  defer { fixture.clean() }
  var game = fixture.game()
  let (_, child) = try fixture.start(&game)
  game.emitScriptEvent("contact.requested", only: child)
  #expect(
    game.commander.scriptState.instances[child]?.suspension?.contains("working capital") == true)
  try fixture.select(child, game: &game)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let page = await runtime.snapshot().scriptPagePresentation
  await runtime.scriptPageKey("r", expected: page)
  let retried = await runtime.snapshot()
  #expect(retried.commander.scriptState.instances[child]?.suspension != nil)
  #expect(retried.scriptPagePresentation != page)
  await runtime.scriptPageKey("r", expected: page)
  #expect(await runtime.snapshot().commander == retried.commander)
}
