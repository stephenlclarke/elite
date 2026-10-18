import Foundation
import Testing

@testable import EliteCore

private func nativeSalvageScoopFixture() throws -> (Game, SalvageLot) {
  var game = try missionGearGame()
  game.commander.system = 7
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops),
    provenance: .grant("native salvage scoop fixture"))
  game.commander.mirrorFittedEquipment()
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  var original = try AlienLegacyFixture.make()
  let target = try #require(
    original.ledger.pendingLots.first {
      if case .technology(let id, _, _) = $0.content {
        return id == AlienModuleKind.energyCapacity.definitionID
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

struct NativeSalvageCollectionRuntimeTests {
  @Test func actualScoopPublishesOriginalModuleAndRemovesOnlyItsBoundBodyAfterSave() async throws {
    let (game, lot) = try nativeSalvageScoopFixture()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    let published = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(published == after.commander)
    try await runtime.load(from: file, persistMigrations: false)
    #expect(await runtime.snapshot().commander == after.commander)
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
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(saved == retry.commander)
  }

  @Test func directTickAndUnboundActorCannotPublishACollectionOrRemoveTheActualFragment()
    async throws
  {
    var (game, lot) = try nativeSalvageScoopFixture()
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

private func recoveredModuleAtActualPlughDock(_ file: URL) async throws -> (GameRuntime, UUID) {
  let (initial, lot) = try nativeSalvageScoopFixture()
  let recovery = GameRuntime(game: initial)
  try await recovery.save(to: file)
  var game = await recovery.advance(delta: 0.1)
  let item = try #require(game.commander.alienStorageState?.current.snapshot.attachments.first)
  #expect(
    game.commander.alienStorageState?.current.snapshot.sources.first?.lot.identity == lot.identity)
  game.dock()
  try #require(game.docked)
  // Controlled next scene setup; no hyperspace travel or discovery mission claim.
  game.commander.discoverPlugh(in: game.commander.galaxy)
  game.commander.system = Plugh.systemID
  game.launch()
  try #require(!game.docked && game.commander.valid)
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
  return (runtime, item.id)
}

extension NativeSalvageCollectionRuntimeTests {
  @Test func actualPlughDockFitsAndStoresTheSameModuleWithoutRefillCashOrSourceLoss() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, id) = try await recoveredModuleAtActualPlughDock(file)
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
      abs(fitted.commander.performance.energy - before.commander.performance.energy * 1.1) < 1e-9)
    #expect(fitted.energy == 100 && fitted.frontShield == 50 && fitted.rearShield == 40)
    #expect(fitted.commander.fittedAlienEnergyModuleCount == 1)
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
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    var (game, original) = try nativeSalvageScoopFixture()
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
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
