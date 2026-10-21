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
  #expect(game.persistSalvagePoses())
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
