import Darwin
import Foundation
import Testing

@testable import EliteCore

// Match the existing native page-store fixtures: every ancestor is a physical
// directory so the production O_NOFOLLOW checks remain exercised unchanged.
func nativeSalvageTestDirectory() throws -> URL {
  let path = FileManager.default.temporaryDirectory.path
  let resolved = path.withCString { realpath($0, nil) }
  let physical = try #require(resolved)
  defer { free(physical) }
  return URL(fileURLWithPath: String(cString: physical), isDirectory: true)
    .appendingPathComponent("native-salvage-" + UUID().uuidString, isDirectory: true)
}

func nativeSalvageScoopFixture(
  definition: String = AlienModuleKind.energyCapacity.definitionID, system: Int = 7
) throws -> (Game, SalvageLot) {
  var game = try missionGearGame()
  game.commander.system = system
  if system == Plugh.systemID { game.commander.discoverPlugh(in: game.commander.galaxy) }
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops),
    provenance: .grant("native salvage scoop fixture"))
  game.commander.mirrorFittedEquipment()
  game.launch()
  game.speed = 0
  game.celestials = []
  var original = try AlienLegacyFixture.make(definition: definition, system: system)
  let target = try #require(
    original.ledger.pendingLots.first {
      if case .technology(let id, _, _) = $0.content {
        return id == definition
      }
      return false
    })
  original.ledger.updateLot(
    target.identity,
    position: game.commander.flightSimulation.pose.systemPoint(.init(0, -45, 400)),
    velocity: .init(0, 0, 0))
  game.commander.salvageLedger = original.ledger
  let context = try #require(game.gameplayContext())
  let requests = game.commander.salvageLedger.spawnRequests(context: context)
  let request = try #require(requests.first { $0.payload == .salvage(target.identity) })
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit,
      revision: context.revision, batches: [.init(requests: [request], atomic: false)], intents: [])
  )
  #expect(receipts.count == 1 && receipts[0].actor != nil && receipts[0].refusal == nil)
  game.commander.salvageLedger.acknowledge(receipts: receipts)
  let index = try #require(
    game.bodies.firstIndex { $0.physical?.payload == .salvage(target.identity) })
  game.bodies[index].position = .init(0, -45, 55)
  game.bodies[index].rotationRate = 0
  game.bodies[index].physical?.velocity = .init(0, 0, 0)
  let posesPersisted = game.persistSalvagePoses()
  #expect(posesPersisted)
  let actual = try #require(game.currentSalvageLot(for: game.bodies[index]))
  #expect(actual.identity == target.identity && actual.loot == target.loot)
  return (game, actual)
}

/// Project the retained pre-load scene's fresh RRS bindings without reading the loaded result.
@inline(never)
private func nativeSalvageColdCommanderExpectation(_ original: Game) throws -> Commander {
  var expected = original.commander
  let indices = original.bodies.indices.filter {
    original.bodies[$0].nativeStationIdentity != nil
  }
  guard !indices.isEmpty else { return expected }
  var world = try #require(expected.nativeStations)
  try #require(
    world.sceneIsConsistent(
      bodies: original.bodies, docked: original.docked, mainStation: original.dockedAtMainStation,
      system: original.systemIdentity, flight: expected.flightSimulation))
  try #require(original.nextBodyID > 0 && original.nextBodyID < 1_000_000_000 - indices.count)
  var flight = expected.flightSimulation
  let allocatedSpawn = flight.allocateSpawn()
  _ = try #require(allocatedSpawn)
  for (member, index) in indices.enumerated() {
    let station = try #require(original.bodies[index].nativeStationIdentity)
    try #require(original.bodies[index].physical != nil)
    let allocatedActor = flight.allocateActor()
    let actor = try #require(allocatedActor)
    try world.ledger.rebind(
      station, to: .init(actor: actor, bodyID: original.nextBodyID + member))
  }
  try #require(world.valid && flight.valid)
  expected.nativeStations = world
  expected.flightSimulation = flight
  return expected
}

struct NativeSalvageCollectionRuntimeTests {
  @Test func actualScoopPublishesOriginalModuleAndRemovesOnlyItsBoundBodyAfterSave() async throws {
    let (game, lot) = try nativeSalvageScoopFixture()
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let before = await runtime.snapshot()
    let after = await runtime.advance(delta: 0.1)
    let native = try #require(after.commander.alienStorageState?.current.snapshot)
    let source = try #require(native.sources.first { $0.lot.identity == lot.identity })
    let item = try #require(native.attachments.first { $0.source == source.id })
    #expect(source.lot.content == lot.content && source.lot.loot == lot.loot)
    #expect(item.kind == .energyCapacity && item.disposition == .stored)
    #expect(!after.bodies.contains { $0.physical?.payload == .salvage(lot.identity) })
    #expect(after.commander.salvageLedger.boundActor(for: lot.identity) == nil)
    #expect(after.commander.salvageLedger.isNativeTransferred(lot.identity.section))
    #expect(after.commander.cargo == before.commander.cargo)
    #expect(after.commander.credits == before.commander.credits)
    #expect(after.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(
      after.commander.flightSimulation.physicalTime > before.commander.flightSimulation.physicalTime
    )
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 27)
    // The file deliberately parks NPC bindings; the retained flight world rebinds
    // those original logical actors on load. Keep all source/resources in the oracle.
    var expectedDisk = after.commander
    expectedDisk.npcPersistence.resetPhysicalBindings(system: after.systemIdentity)
    expectedDisk.resetWantedCareerBindings(system: after.systemIdentity)
    let published = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(published == expectedDisk)
    let expectedLoaded = try nativeSalvageColdCommanderExpectation(after)
    try await runtime.load(from: file, persistMigrations: false)
    #expect(await runtime.snapshot().commander == expectedLoaded)
    #expect(try Data(contentsOf: file) == bytes)
    let repeated = await runtime.advance(delta: 0.1)
    #expect(repeated.commander.alienStorageState?.current.snapshot.sources == native.sources)
    #expect(
      repeated.commander.alienStorageState?.current.snapshot.attachments == native.attachments)
  }

  @Test func blockedActualWriterKeepsPhysicalFrameAndOriginalCustodyThenRecoversOnRetry()
    async throws
  {
    let (game, lot) = try nativeSalvageScoopFixture()
    let folder = try nativeSalvageTestDirectory()
    let preserved = folder.appendingPathExtension("preserved")
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: preserved)
    }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let before = await runtime.snapshot()
    let bytes = try Data(contentsOf: file)
    try FileManager.default.moveItem(at: folder, to: preserved)
    try Data("blocked writer".utf8).write(to: folder)
    let control = GameRuntime(game: before)
    let expectedPhysical = await control.advance(delta: 0.1)
    let refused = await runtime.advance(delta: 0.1)
    #expect(refused.commander == expectedPhysical.commander)
    #expect(refused.bodies == expectedPhysical.bodies)
    #expect(
      refused.energy == expectedPhysical.energy
        && refused.frontShield == expectedPhysical.frontShield)
    #expect(
      refused.rearShield == expectedPhysical.rearShield && refused.speed == expectedPhysical.speed)
    #expect(refused.commander.alienStorageState == nil)
    #expect(refused.bodies.contains { $0.physical?.payload == .salvage(lot.identity) })
    #expect(try Data(contentsOf: preserved.appendingPathComponent("commander.json")) == bytes)
    try FileManager.default.removeItem(at: folder)
    try FileManager.default.moveItem(at: preserved, to: folder)
    let retry = await runtime.advance(delta: 0.1)
    #expect(retry.commander.alienStorageState?.current.snapshot.sources.count == 1)
    #expect(!retry.bodies.contains { $0.physical?.payload == .salvage(lot.identity) })
    var expectedDisk = retry.commander
    expectedDisk.npcPersistence.resetPhysicalBindings(system: retry.systemIdentity)
    expectedDisk.resetWantedCareerBindings(system: retry.systemIdentity)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(saved == expectedDisk)
  }

  @Test func directTickAndUnboundActorCannotPublishACollectionOrRemoveTheActualFragment()
    async throws
  {
    let (initial, lot) = try nativeSalvageScoopFixture()
    var game = initial
    let previous = game.commander.salvageLedger
    game.tick(delta: 0.1)
    #expect(game.pendingNativeSalvageCollections.count == 1)
    #expect(game.bodies.contains { $0.physical?.payload == .salvage(lot.identity) })
    #expect(game.commander.salvageLedger.inventory == previous.inventory)
    #expect(game.commander.alienStorageState == nil)
    let runtime = GameRuntime(game: game)
    let after = await runtime.advance(delta: 0.1)
    #expect(after.commander.alienStorageState == nil)
    #expect(after.bodies.contains { $0.physical?.payload == .salvage(lot.identity) })
  }
}

func recoveredModuleAtActualPlughDock(
  _ file: URL,
  kind: AlienModuleKind = .energyCapacity
) async throws -> (GameRuntime, UUID) {
  // Begin the controlled recovery scene at PLUGH; changing system after collecting
  // would bypass actual travel and strand the retained original NPC ledger elsewhere.
  let (initial, lot) = try nativeSalvageScoopFixture(
    definition: kind.definitionID, system: Plugh.systemID)
  let recovery = GameRuntime(game: initial)
  try await recovery.save(to: file)
  var game = await recovery.advance(delta: 0.1)
  let item = try #require(game.commander.alienStorageState?.current.snapshot.attachments.first)
  #expect(
    game.commander.alienStorageState?.current.snapshot.sources.first?.lot.identity == lot.identity)
  let retainedNPCs = game.commander.npcPersistence
  try #require(retainedNPCs.system == game.systemIdentity)
  var parkedNPCs = retainedNPCs
  parkedNPCs.resetPhysicalBindings(system: game.systemIdentity)
  game.dock()
  try #require(game.docked && game.commander.npcPersistence == parkedNPCs)
  // Controlled same-system relaunch; no hyperspace travel or discovery mission claim.
  game.launch()
  try #require(!game.docked && game.commander.valid)
  let runtime = try await dockAtActualPlughDoorway(game, file: file)
  return (runtime, item.id)
}

func dockAtActualPlughDoorway(_ input: Game, file: URL) async throws -> GameRuntime {
  var game = input
  let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  let old = game.commander.flightSimulation.pose
  var pose = ShipPose()
  pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
  pose.orientation.y = old.orientation.apply(station.entranceUp)
  pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 3
  let runtime = GameRuntime(game: game, saveURL: file)
  for _ in 0..<100 where !game.docked { game = await runtime.advance(delta: 0.1) }
  try #require(game.docked && game.dockedAtMainStation && game.commander.system == Plugh.systemID)
  try #require(game.nativeMainStationDockEvidenceIsCurrent && game.nativeAlienFittingAvailable)
  // Select inventory through the actor after the actual doorway supplies its receipt.
  await runtime.nativeCommand { $0.screen = .inventory }
  return runtime
}

extension NativeSalvageCollectionRuntimeTests {
  @Test(arguments: AlienModuleKind.allCases)
  func actualPlughDockFitsAndStoresTheSameModuleWithoutRefillCashOrSourceLoss(kind: AlienModuleKind)
    async throws
  {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, id) = try await recoveredModuleAtActualPlughDock(file, kind: kind)
    await runtime.nativeCommand {
      $0.energy = 100
      $0.frontShield = 50
      $0.rearShield = 40
    }
    let before = await runtime.snapshot()
    let command = try #require(before.inventoryActionPreview(for: .alienAttachment(id)).command)
    let applied = await runtime.equipmentTransaction(.inventory(command))
    #expect(applied.applied)
    let fitted = await runtime.snapshot()
    #expect(
      abs(
        fitted.commander.performance.energy
          - before.commander.performance.energy * (kind == .energyCapacity ? 1.1 : 1)) < 1e-9)
    #expect(
      abs(
        fitted.commander.energyRechargeMultiplier
          - before.commander.energyRechargeMultiplier * (kind == .energyRecharge ? 1.1 : 1)) < 1e-9)
    #expect(
      abs(
        fitted.commander.shieldCapacity
          - before.commander.shieldCapacity * (kind == .shieldCapacity ? 1.1 : 1)) < 1e-9)
    #expect(
      abs(
        fitted.commander.rearShieldCapacity
          - before.commander.rearShieldCapacity * (kind == .shieldCapacity ? 1.1 : 1)) < 1e-9)
    #expect(
      abs(
        fitted.commander.frontShieldRecharge
          - before.commander.frontShieldRecharge * (kind == .shieldRecharge ? 1.1 : 1)) < 1e-9)
    #expect(
      abs(
        fitted.commander.rearShieldRecharge
          - before.commander.rearShieldRecharge * (kind == .shieldRecharge ? 1.1 : 1)) < 1e-9)
    let pulse = try EMPPulseProfile.resolve(for: fitted.commander)
    #expect(pulse.energyStage == (kind.isEnergyModule ? 1 : 0))
    #expect(pulse.power == (kind.isEnergyModule ? 48 : 32))
    #expect(pulse.range == (kind.isEnergyModule ? 4500 : 3000))
    #expect(fitted.energy == 100 && fitted.frontShield == 50 && fitted.rearShield == 40)
    #expect(fitted.commander.fittedAlienEnergyModuleCount == (kind.isEnergyModule ? 1 : 0))
    #expect(fitted.commander.credits == before.commander.credits)
    #expect(
      fitted.commander.alienStorageState?.current.snapshot.sources
        == before.commander.alienStorageState?.current.snapshot.sources)
    #expect(fitted.commander.equipmentInventory == before.commander.equipmentInventory)
    let item = try #require(
      fitted.commander.alienStorageState?.current.snapshot.attachments.first { $0.id == id })
    let hull = try #require(fitted.commander.hullInstanceID)
    #expect(item.disposition == .fitted(hull: hull))
    let disk = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(disk == fitted.commander)
    let stale = await runtime.equipmentTransaction(.inventory(command))
    #expect(!stale.applied)
    let store = try #require(fitted.inventoryActionPreview(for: .alienAttachment(id)).command)
    let storedResult = await runtime.equipmentTransaction(.inventory(store))
    #expect(storedResult.applied)
    let stored = await runtime.snapshot()
    #expect(stored.commander.fittedAlienEnergyModuleCount == 0)
    #expect(stored.commander.performance.energy == before.commander.performance.energy)
    #expect(stored.commander.energyRechargeMultiplier == before.commander.energyRechargeMultiplier)
    #expect(stored.commander.shieldCapacity == before.commander.shieldCapacity)
    #expect(stored.commander.rearShieldCapacity == before.commander.rearShieldCapacity)
    #expect(stored.commander.frontShieldRecharge == before.commander.frontShieldRecharge)
    #expect(stored.commander.rearShieldRecharge == before.commander.rearShieldRecharge)
    let storedPulse = try EMPPulseProfile.resolve(for: stored.commander)
    #expect(storedPulse.energyStage == 0)
    #expect(stored.energy == 100 && stored.frontShield == 50 && stored.rearShield == 40)
    #expect(stored.commander.credits == before.commander.credits)
    #expect(
      stored.commander.alienStorageState?.current.snapshot.attachments.first { $0.id == id }?
        .disposition == .stored)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == stored.commander)
  }

  @Test func booleanPlughDockAndStaleServiceEpochCannotAuthorizeAlienFitting() async throws {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, id) = try await recoveredModuleAtActualPlughDock(file)
    var game = await runtime.snapshot()
    let command = try #require(game.inventoryActionPreview(for: .alienAttachment(id)).command)
    let before = game.commander
    game.invalidateNativeStationAuthority()
    let stale = game.performInventoryCommand(command)
    #expect(!stale && game.commander == before)
    game.nativeMainStationDockEvidence = nil
    game.docked = true
    game.dockedAtMainStation = true
    #expect(!game.nativeAlienFittingAvailable)
    #expect(game.inventoryActionPreview(for: .alienAttachment(id)).command == nil)
    #expect(game.commander == before)
  }
}

extension NativeSalvageCollectionRuntimeTests {
  @Test func failedPlughFitWriterRetainsChargeSourceCashAndPreviewThenSameCommandRetries()
    async throws
  {
    let folder = try nativeSalvageTestDirectory()
    let preserved = folder.appendingPathExtension("preserved")
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: preserved)
    }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, id) = try await recoveredModuleAtActualPlughDock(file)
    let before = await runtime.snapshot()
    let command = try #require(before.inventoryActionPreview(for: .alienAttachment(id)).command)
    let bytes = try Data(contentsOf: file)
    try FileManager.default.moveItem(at: folder, to: preserved)
    try Data("blocked writer".utf8).write(to: folder)
    let result = await runtime.equipmentTransaction(.inventory(command))
    #expect(!result.applied)
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.bodies == before.bodies)
    #expect(refused.energy == before.energy && refused.frontShield == before.frontShield)
    #expect(refused.rearShield == before.rearShield)
    #expect(refused.inventoryActionPreview(for: .alienAttachment(id)).command == command)
    #expect(try Data(contentsOf: preserved.appendingPathComponent("commander.json")) == bytes)
    try FileManager.default.removeItem(at: folder)
    try FileManager.default.moveItem(at: preserved, to: folder)
    let retried = await runtime.equipmentTransaction(.inventory(command))
    #expect(retried.applied)
    let after = await runtime.snapshot()
    #expect(after.commander.fittedAlienEnergyModuleCount == 1)
    #expect(after.commander.credits == before.commander.credits)
    #expect(
      after.commander.alienStorageState?.current.snapshot.sources
        == before.commander.alienStorageState?.current.snapshot.sources)
  }
}

extension NativeSalvageCollectionRuntimeTests {
  @Test func actualNativeFragmentMotionStaysHotUntilSaveAndCullReentryRetainsTheSameLot()
    async throws
  {
    let (initial, original) = try nativeSalvageScoopFixture()
    var game = initial
    let index = try #require(
      game.bodies.firstIndex { $0.physical?.payload == .salvage(original.identity) })
    game.bodies[index].position = .init(0, -45, 400)
    game.bodies[index].physical?.velocity = .init(1, 0, 0)
    let posesPersisted = game.persistSalvagePoses()
    #expect(posesPersisted)
    let owner = try #require(game.commander.equipmentOwnerID)
    let imported = try NativeSalvageImport(
      ledger: game.commander.salvageLedger,
      section: original.identity.section, owner: owner,
      at: game.commander.flightSimulation.physicalTime, previous: nil)
    // Controlled supported imported state; genuine collection is covered separately.
    try imported.apply(to: &game.commander)
    // A genuine unrelated allocated body departs in the same physical frame.
    let allocation = game.commander.flightSimulation.allocateActor()
    let unrelatedActor = try #require(allocation)
    var unrelated = SpaceBody(id: game.nextBodyID, hull: .cargo, position: .init(0, 0, 90000))
    game.nextBodyID += 1
    unrelated.physical = .init(identity: unrelatedActor, population: .cargo)
    game.bodies.append(unrelated)
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let before = await runtime.snapshot()
    let oldState = try #require(before.commander.alienStorageState?.current)
    let oldSnapshot = oldState.snapshot
    let oldActor = try #require(before.bodies[index].physical?.identity)
    let moved = await runtime.advance(delta: 0.1)
    let held = try #require(moved.commander.alienStorageState?.current)
    #expect(held === oldState)
    #expect(!moved.bodies.contains { $0.physical?.identity == unrelatedActor })
    #expect(moved.nativeSalvageMotion[original.identity] != nil)
    let body = try #require(moved.bodies.first { $0.physical?.identity == oldActor })
    #expect(
      moved.currentSalvageLot(for: body)?.position
        == moved.commander.flightSimulation.pose.systemPoint(body.position))
    try await runtime.save(to: file)
    let cold = await runtime.snapshot()
    #expect(cold.nativeSalvageMotion.isEmpty)
    let savedPending = try #require(
      cold.commander.alienStorageState?.current.salvage.pending[original.identity])
    #expect(savedPending.physicalTime == moved.commander.flightSimulation.physicalTime)
    #expect(savedPending.lot.position == moved.currentSalvageLot(for: body)?.position)
    #expect(oldState.snapshot == oldSnapshot)
    await runtime.nativeCommand { candidate in
      if let index = candidate.bodies.firstIndex(where: { $0.physical?.identity == oldActor }) {
        candidate.bodies[index].position.z = 90000
        candidate.bodies[index].physical?.velocity = .init(0, 0, 0)
      }
    }
    let culled = await runtime.advance(delta: 0.1)
    #expect(!culled.bodies.contains { $0.physical?.identity == oldActor })
    let parked = try #require(
      culled.commander.alienStorageState?.current.salvage.pending[original.identity])
    #expect(parked.binding == nil && parked.offer == nil)
    await runtime.nativeCommand { candidate in
      var pose = candidate.commander.flightSimulation.pose
      pose.position = parked.lot.position - pose.orientation.apply(.init(0, -45, 400))
      NativeStationTestFixture.reframe(&candidate, to: pose)
    }
    let returned = await runtime.advance(delta: 0.1)
    let newPending = try #require(
      returned.commander.alienStorageState?.current.salvage.pending[original.identity])
    let newActor = try #require(newPending.binding)
    #expect(newActor != oldActor && newActor.visit == oldActor.visit)
    #expect(newPending.lot.content == parked.lot.content && newPending.lot.loot == parked.lot.loot)
    #expect(newPending.lot.identity == original.identity)
    #expect(
      returned.bodies.filter { $0.physical?.payload == .salvage(original.identity) }.count == 1)
    #expect(
      returned.commander.salvageLedger.pendingLots.allSatisfy { $0.identity != original.identity })
  }
}

/// Add a controlled genuine original ledger outcome using the retained seed and allocator.
/// Admission and collection use their actual native paths; this is not fresh cutting coverage.
private func admitLegacyAlienOutcome(_ definition: String, in game: inout Game) throws -> SalvageLot
{
  let section = try #require(
    game.commander.alienStorageState?.current.snapshot.world.compactMap {
      if case .legacySection(let value) = $0 { return value }
      return nil
    }.first)
  let source = section.plan.source
  let identity = try #require(
    (UInt32(1001)..<4000).map {
      WreckSectionIdentity(
        wreck: .init(system: game.systemIdentity, site: $0, lineage: 123), section: 1)
    }.first { identity in
      !game.commander.salvageLedger.isNativeTransferred(identity)
        && SalvageLootProfiles.plan(section: identity, seed: section.seed, source: source).items
          .contains {
            if case .technology(let id, _, _, _) = $0.content { return id == definition }
            return false
          }
    })
  let profile = SalvageSectionProfile(
    index: 1, kind: .computer,
    localPosition: .init(10, 0, 0), normal: .init(0, 0, 1), radius: 10,
    workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)
  let allocatedOperation = game.commander.flightSimulation.allocateIncident()
  let operation = try #require(allocatedOperation)
  let result = game.commander.salvageLedger.advance(
    wreck: identity.wreck, section: profile,
    pose: ShipPose(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0),
    tool: .cutter, elapsed: 1, operation: operation,
    conditions: .init(
      toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
      resourcesAvailable: true, ownershipAuthorized: true), source: source)
  guard case .released = result else { throw AlienStorageError.invalidJoin }
  let original = try #require(
    game.commander.salvageLedger.pendingLots.first {
      guard $0.identity.section == identity else { return false }
      if case .technology(let id, _, _) = $0.content { return id == definition }
      return false
    })
  game.commander.salvageLedger.updateLot(
    original.identity,
    position: game.commander.flightSimulation.pose.systemPoint(.init(0, -45, 400)),
    velocity: .init(0, 0, 0))
  let context = try #require(game.gameplayContext())
  let requests = game.commander.salvageLedger.spawnRequests(context: context)
  let request = try #require(requests.first { $0.payload == .salvage(original.identity) })
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit,
      revision: context.revision, batches: [.init(requests: [request], atomic: false)], intents: [])
  )
  try #require(receipts.count == 1 && receipts[0].actor != nil && receipts[0].refusal == nil)
  game.commander.salvageLedger.acknowledge(receipts: receipts)
  let index = try #require(
    game.bodies.firstIndex { $0.physical?.payload == .salvage(original.identity) })
  game.bodies[index].position = .init(0, -45, 55)
  game.bodies[index].rotationRate = 0
  game.bodies[index].physical?.velocity = .init(0, 0, 0)
  let persisted = game.persistSalvagePoses()
  try #require(persisted)
  return try #require(game.currentSalvageLot(for: game.bodies[index]))
}

extension NativeSalvageCollectionRuntimeTests {
  @Test func twoActuallyRecoveredUpgradesChangeOnePhysicalModuleWithoutIncreasingEMPCount()
    async throws
  {
    let folder = try nativeSalvageTestDirectory()
    let backup = folder.appendingPathExtension("preserved")
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: backup)
    }
    let file = folder.appendingPathComponent("commander.json")
    let (initialRuntime, module) = try await recoveredModuleAtActualPlughDock(file)
    var runtime = initialRuntime
    let first = await runtime.snapshot()
    let fit = try #require(first.inventoryActionPreview(for: .alienAttachment(module)).command)
    let fitResult = await runtime.equipmentTransaction(.inventory(fit))
    try #require(fitResult.applied)
    var contribution = AlienModuleDefinition.baseBonusBasisPoints
    var originalUpgradeIDs: [UUID] = []
    var originalLots: [SalvageLotIdentity] = []
    for iteration in 0..<2 {
      var flight = await runtime.snapshot()
      flight.launch()
      try #require(!flight.docked)
      let lot = try admitLegacyAlienOutcome(
        AlienModuleKind.energyCapacity.upgradeDefinitionID, in: &flight)
      originalLots.append(lot.identity)
      runtime = GameRuntime(game: flight, saveURL: file)
      try await runtime.save(to: file)
      let recovered = await runtime.advance(delta: 0.1)
      let upgrade = try #require(
        recovered.commander.alienStorageState?.current.snapshot.upgrades.first {
          item in
          recovered.commander.alienStorageState?.current.snapshot.sources.first {
            $0.id == item.source
          }?.lot.identity == lot.identity
        })
      originalUpgradeIDs.append(upgrade.id)
      #expect(upgrade.disposition == .stored)
      runtime = try await dockAtActualPlughDoorway(recovered, file: file)
      await runtime.nativeCommand {
        $0.energy = 100
        $0.frontShield = 50
        $0.rearShield = 40
      }
      let before = await runtime.snapshot()
      let command = try #require(
        before.inventoryActionPreview(for: .alienUpgrade(upgrade.id)).command)
      if iteration == 1 {
        let bytes = try Data(contentsOf: file)
        try FileManager.default.moveItem(at: folder, to: backup)
        try Data("blocked writer".utf8).write(to: folder)
        let failed = await runtime.equipmentTransaction(.inventory(command))
        #expect(!failed.applied)
        let refused = await runtime.snapshot()
        #expect(refused.commander == before.commander && refused.energy == before.energy)
        #expect(
          refused.frontShield == before.frontShield && refused.rearShield == before.rearShield)
        #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
        try FileManager.default.removeItem(at: folder)
        try FileManager.default.moveItem(at: backup, to: folder)
      }
      let result = await runtime.equipmentTransaction(.inventory(command))
      try #require(result.applied)
      guard case .technology(_, let quality, _) = lot.content else {
        throw AlienStorageError.invalidJoin
      }
      contribution += quality.bonusBasisPoints
      let after = await runtime.snapshot()
      let current = try #require(after.commander.alienStorageState?.current.snapshot)
      let physical = try #require(current.attachments.first { $0.id == module })
      #expect(physical.contributionBasisPoints == contribution)
      #expect(current.attachments.count == 1 && after.commander.fittedAlienEnergyModuleCount == 1)
      #expect(
        abs(
          after.commander.performance.energy - after.commander.nativePerformance.energy
            * (1 + Double(contribution) / 10000)) < 1e-9)
      let pulse = try EMPPulseProfile.resolve(for: after.commander)
      #expect(pulse.energyStage == 1 && pulse.power == 48 && pulse.range == 4500)
      #expect(after.energy == 100 && after.frontShield == 50 && after.rearShield == 40)
      #expect(after.commander.credits == before.commander.credits)
      #expect(current.sources == before.commander.alienStorageState?.current.snapshot.sources)
      #expect(
        current.receipts.filter {
          if case .upgrade(let target, let source, _) = $0.effect {
            return target == module && source == upgrade.id
          }
          return false
        }.count == 1)
      let replay = await runtime.equipmentTransaction(.inventory(command))
      #expect(!replay.applied)
      #expect(after.inventoryActionPreview(for: .alienUpgrade(upgrade.id)).command == nil)
    }
    #expect(Set(originalLots).count == 2 && Set(originalUpgradeIDs).count == 2)
    let beforeStore = await runtime.snapshot()
    let store = try #require(
      beforeStore.inventoryActionPreview(for: .alienAttachment(module)).command)
    let storeResult = await runtime.equipmentTransaction(.inventory(store))
    try #require(storeResult.applied)
    let stored = await runtime.snapshot()
    #expect(stored.commander.fittedAlienEnergyModuleCount == 0)
    #expect(stored.commander.alienStorageState?.current.snapshot.attachments.first?.id == module)
    #expect(
      stored.commander.alienStorageState?.current.snapshot.attachments.first?
        .contributionBasisPoints == contribution)
    try await runtime.load(from: file, persistMigrations: false)
    #expect(await runtime.snapshot().commander == stored.commander)
  }
}

private func poisonNativeFragment(_ reason: String, game: inout Game, lot: SalvageLot) throws {
  let index = try #require(
    game.bodies.firstIndex { $0.physical?.payload == .salvage(lot.identity) })
  let actor = try #require(game.bodies[index].physical?.identity)
  let spawn = try #require(game.bodies[index].physical?.spawnIdentity)
  switch reason {
  case "naval": game.bodies[index].navalTarget = true
  case "blackjack": game.bodies[index].blackjackIdentity = UUID()
  case "projectile": game.bodies[index].enemyMissile = true
  case "npc":
    let npc = NPCState(
      role: .trader, origin: game.systemIdentity,
      destination: game.systemIdentity)
    game.bodies[index].physical?.npc = npc
  case "emp": game.bodies[index].physical?.empSource = actor
  case "mission":
    game.bodies[index].missionActorID = UUID()
    game.bodies[index].missionInstanceID = UUID()
  case "shape", "claimant":
    let old = try #require(game.bodies[index].physical?.salvage)
    let metadata = SalvageTargetMetadata(
      category: old.category, ownership: old.ownership,
      claimant: reason == "claimant" ? game.commander.flightSimulation.player : old.claimant,
      wreck: old.wreck, section: old.section, lot: old.lot,
      bounds: .init(
        center: old.bounds.center, radius: old.bounds.radius + (reason == "shape" ? 1 : 0)),
      workSurfaces: old.workSurfaces)
    game.bodies[index].physical?.salvage = metadata
  case "spawn-highwater", "spawn-producer":
    game.bodies[index].physical?.spawnIdentity = .init(
      system: spawn.system, visit: spawn.visit,
      sequence: reason == "spawn-highwater" ? UInt64.max - 1 : spawn.sequence,
      member: spawn.member, producer: reason == "spawn-producer" ? .ambient : .salvage)
  case "actor-highwater":
    let unallocated = ActorIdentity(
      system: actor.system, visit: actor.visit,
      entity: game.commander.flightSimulation.nextActor)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(game.bodies[index])) as? [String: Any]
    )
    var physical = try #require(object["physical"] as? [String: Any])
    physical["identity"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(unallocated))
    object["physical"] = physical
    game.bodies[index] = try JSONDecoder().decode(
      SpaceBody.self,
      from: JSONSerialization.data(withJSONObject: object))
    let previous = try #require(game.commander.alienStorageState?.current.snapshot)
    let world = previous.world.map { record -> AlienStorageWorldRecord in
      guard case .legacyCurrent(let current) = record,
        case .pending(let pending, let at, let offer, let binding) = current.state,
        pending.identity == lot.identity, binding == actor
      else { return record }
      return .legacyCurrent(
        .init(
          id: current.id, owner: current.owner, claim: current.claim,
          state: .pending(lot: pending, at: at, offer: offer, binding: unallocated)))
    }
    try game.commander.replaceAlienStorage(
      with: .init(
        owner: previous.owner,
        revision: previous.revision, worldRevision: previous.worldRevision + 1, world: world,
        sources: previous.sources, attachments: previous.attachments, upgrades: previous.upgrades,
        receipts: previous.receipts, commands: previous.commands))
  case "mining-owner":
    var ledger = MiningLedger(seed: 42)
    let rock = MiningRock(
      identity: .init(system: game.systemIdentity, field: 0, rock: 0),
      position: .init(1000, 0, 0), radius: 40, energy: 1)
    let player = try #require(game.commander.flightSimulation.player)
    let attack = CombatIncident(
      id: 1, physicalTime: 0,
      origin: .init(
        emissionID: 1, owner: player, ordnance: nil, emittedAt: 0,
        ownerLegalAtEmission: .init()), victim: nil, kind: .laser, outcome: .hit,
      position: rock.position, victimLegalBeforeAttack: nil, firstAggressor: nil,
      victimRole: nil, victimIsStation: false, laser: .mining, mount: .front)
    let extracted = ledger.hit(rock: rock, incident: attack, damage: 1)
    guard case .extracted = extracted else { throw AlienStorageError.invalidJoin }
    let context = try #require(game.gameplayContext())
    let requests = ledger.pendingSpawnRequests(
      context: context,
      fields: [.init(position: rock.position, rocks: [rock])])
    let request = try #require(requests.first)
    ledger.acknowledge(receipts: [.init(request: request.identity, actor: actor, refusal: nil)])
    try #require(ledger.ownsPhysicalActor(actor))
    game.commander.miningLedger = ledger
  case "npc-owner":
    var other = SpaceBody(id: game.bodies[index].id, hull: .sidewinder, position: .init(1000, 0, 0))
    let performance = try #require(ShipCatalogue.nativeShip(.sidewinder)?.game)
    var npc = NPCState(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity)
    let resources = try #require(NPCResources.stock(performance))
    npc.resources = resources
    other.energy = performance.energy
    other.missiles = performance.missiles
    other.physical = .init(
      identity: actor, population: .civilian, npc: npc,
      spawnIdentity: .init(
        system: actor.system, visit: actor.visit, sequence: 1, member: 0, producer: .ambient))
    let snapshot = try #require(
      NPCPersistenceSnapshot.capture(
        body: other,
        pose: game.commander.flightSimulation.pose, physicalTime: 0, protection: .init()))
    let captured = game.commander.npcPersistence.capture(snapshot, protection: .init())
    guard case .refused = captured else {
      try #require(game.commander.npcPersistence.logicalIdentity(for: actor) != nil)
      return
    }
    throw AlienStorageError.invalidJoin
  case "cargo-owner":
    let allocatedSource = game.commander.flightSimulation.allocateActor()
    let dead = try #require(allocatedSource)
    let source = ActorSnapshot(
      identity: dead, hull: .cobra, position: .init(1000, 0, 0),
      orientation: .init(), velocity: .init(0, 0, 0), energy: 0, maximumEnergy: 100,
      maximumSpeedUnitsPerSecond: 100, legal: .init(),
      npc: .init(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity),
      rock: nil, payload: nil, ordinaryCargo: [.init(commodity: .food, quantity: 1)])
    let registered = game.commander.cargoDebrisLedger.registerDeath(
      actor: source,
      manifest: source.ordinaryCargo, settlementID: 1, physicalTime: 0, protection: .init())
    try #require(registered == .registered(lots: 1))
    let context = try #require(game.gameplayContext())
    let requests = game.commander.cargoDebrisLedger.pendingSpawnRequests(context: context)
    let request = try #require(requests.first)
    // Poison a real producer offer with a conflicting existing physical owner.
    game.commander.cargoDebrisLedger.acknowledge(receipts: [
      .init(request: request.identity, actor: actor, refusal: nil)
    ])
    try #require(game.commander.cargoDebrisLedger.ownsPhysicalActor(actor))
  default: throw AlienStorageError.invalidJoin
  }
}

extension NativeSalvageCollectionRuntimeTests {
  @Test(arguments: [
    "npc", "emp", "mission", "shape", "claimant", "spawn-highwater",
    "spawn-producer", "actor-highwater", "cargo-owner", "mining-owner", "npc-owner",
    "naval", "blackjack", "projectile",
  ])
  func conflictingNativeFragmentOwnersCannotBeScoopedOrSaved(reason: String) async throws {
    let (initial, lot) = try nativeSalvageScoopFixture()
    var game = initial
    let owner = try #require(game.commander.equipmentOwnerID)
    let imported = try NativeSalvageImport(
      ledger: game.commander.salvageLedger,
      section: lot.identity.section, owner: owner, at: game.commander.flightSimulation.physicalTime,
      previous: nil)
    try imported.apply(to: &game.commander)
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    try GameRuntime.writeCommander(&game, to: file)
    let bytes = try Data(contentsOf: file)
    try poisonNativeFragment(reason, game: &game, lot: lot)
    #expect(!game.commander.nativeSalvageSceneIsConsistent(game.bodies, docked: false))
    let before = game.commander
    let bodies = game.bodies
    game.scoopCargo()
    #expect(game.pendingNativeSalvageCollections.isEmpty)
    #expect(game.commander == before && game.bodies == bodies)
    let runtime = GameRuntime(game: game)
    let beforeSave = await runtime.snapshot()
    await #expect(throws: (any Error).self) { try await runtime.save(to: file) }
    let after = await runtime.snapshot()
    #expect(after.commander == beforeSave.commander && after.bodies == beforeSave.bodies)
    #expect(try Data(contentsOf: file) == bytes)
  }
}

extension NativeSalvageCollectionRuntimeTests {
  @Test func twoDistinctActuallyFittedEnergyKindsStrengthenEMPByPhysicalCountOnly() async throws {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (initialRuntime, firstID) = try await recoveredModuleAtActualPlughDock(file)
    var runtime = initialRuntime
    let initial = await runtime.snapshot()
    let firstFit = try #require(
      initial.inventoryActionPreview(for: .alienAttachment(firstID)).command)
    let fittedFirst = await runtime.equipmentTransaction(.inventory(firstFit))
    try #require(fittedFirst.applied)
    var flight = await runtime.snapshot()
    flight.launch()
    let lot = try admitLegacyAlienOutcome(AlienModuleKind.energyRecharge.definitionID, in: &flight)
    runtime = GameRuntime(game: flight, saveURL: file)
    try await runtime.save(to: file)
    let recovered = await runtime.advance(delta: 0.1)
    let second = try #require(
      recovered.commander.alienStorageState?.current.snapshot.attachments.first {
        item in
        recovered.commander.alienStorageState?.current.snapshot.sources.first {
          $0.id == item.source
        }?.lot.identity == lot.identity
      })
    #expect(second.id != firstID && second.kind == .energyRecharge)
    runtime = try await dockAtActualPlughDoorway(recovered, file: file)
    let before = await runtime.snapshot()
    let command = try #require(
      before.inventoryActionPreview(for: .alienAttachment(second.id)).command)
    let fittedSecond = await runtime.equipmentTransaction(.inventory(command))
    try #require(fittedSecond.applied)
    let both = await runtime.snapshot()
    let pulse = try EMPPulseProfile.resolve(for: both.commander)
    #expect(both.commander.fittedAlienEnergyModuleCount == 2)
    #expect(pulse.energyStage == 2 && pulse.power == 64 && pulse.range == 6000)
    #expect(
      abs(both.commander.performance.energy - both.commander.nativePerformance.energy * 1.1) < 1e-9)
    #expect(abs(both.commander.energyRechargeMultiplier - 1.1) < 1e-9)
    #expect(
      both.energy == before.energy && both.frontShield == before.frontShield
        && both.rearShield == before.rearShield)
    #expect(both.commander.credits == before.commander.credits)
    try await runtime.load(from: file, persistMigrations: false)
    #expect(await runtime.snapshot().commander == both.commander)
  }

  @Test func actualHullQuotesAndFailedThenSuccessfulTradePreserveNativeModuleIdentityAndReceipts()
    async throws
  {
    let folder = try nativeSalvageTestDirectory()
    let backup = folder.appendingPathExtension("preserved")
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: backup)
    }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, id) = try await recoveredModuleAtActualPlughDock(file)
    let initial = await runtime.snapshot()
    let fit = try #require(initial.inventoryActionPreview(for: .alienAttachment(id)).command)
    let fitted = await runtime.equipmentTransaction(.inventory(fit))
    try #require(fitted.applied)
    await runtime.nativeCommand { game in
      game.screen = .showroom
      game.showroom.selection = "SH013"
      game.commander.credits = 10_000_000
    }
    let before = await runtime.snapshot()
    let original = try #require(before.commander.alienStorageState?.current.snapshot)
    let oldHull = try #require(before.commander.hullInstanceID)
    let quote = try #require(before.shipTradeQuote)
    try #require(quote.allowed)
    for _ in 0..<5 {
      let again = try #require(before.shipTradeQuote)
      #expect(again.balance == quote.balance && again.allowed)
      let projected = try before.commander.projectedEquipmentTransfer(to: "SH013")
      #expect(projected.hullInstanceID == oldHull)
      #expect(projected.alienStorageState?.current.snapshot == original)
    }
    #expect(await runtime.snapshot().commander == before.commander)
    await runtime.key("showroom-trade")
    await runtime.key("right")
    let beforeFailure = await runtime.snapshot()
    let bytes = try Data(contentsOf: file)
    try FileManager.default.moveItem(at: folder, to: backup)
    try Data("blocked writer".utf8).write(to: folder)
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == beforeFailure.commander)
    #expect(refused.commander.alienStorageState?.current.snapshot == original)
    #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
    try FileManager.default.removeItem(at: folder)
    try FileManager.default.moveItem(at: backup, to: folder)
    await runtime.key("return")
    let after = await runtime.snapshot()
    let newHull = try #require(after.commander.hullInstanceID)
    let next = try #require(after.commander.alienStorageState?.current.snapshot)
    #expect(after.commander.shipID == "SH013" && newHull != oldHull)
    #expect(after.commander.credits == quote.balance)
    #expect(next.sources == original.sources && next.upgrades == original.upgrades)
    let item = try #require(next.attachments.first { $0.id == id })
    #expect(item.disposition == .fitted(hull: newHull))
    #expect(
      item.contributionBasisPoints
        == original.attachments.first { $0.id == id }?.contributionBasisPoints)
    #expect(
      after.commander.fittedAlienEnergyModuleCount == before.commander.fittedAlienEnergyModuleCount)
    #expect(next.commands.count == original.commands.count + 1)
    #expect(next.receipts.count == original.receipts.count + 1)
    #expect(next.receipts.filter { $0.effect == .transfer(attachment: id) }.count == 1)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(saved == after.commander)
    try await runtime.load(from: file, persistMigrations: false)
    #expect(await runtime.snapshot().commander == after.commander)
  }
}
