import Foundation
import Testing

@testable import EliteCore

@Test func failedHullExchangeSavePublishesNeitherGearNorCashAndCanBeRetried() async throws {
  let folder = try missionGearFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let directory = folder.appendingPathComponent("save")
  let file = directory.appendingPathComponent("commander.json")
  var game = try missionGearGame(missiles: 4)
  let stored = try missionPrepareSmallHullExchange(&game)
  game.screen = .showroom
  game.showroom.selection = "SH001"
  game.commander.credits = 10_000_000
  // Exercise the real retained-feature writer; canonical native gear alone does not autosave.
  let cabinQuote = game.passengerBerthQuote
  try #require(cabinQuote.allowed)
  let cabin = try game.confirmPassengerBerth(cabinQuote)
  try game.setPassengerBerthFitted(cabin, fitted: false)
  try #require(game.requiresScriptDurability && game.commander.valid)
  let quote = try #require(game.shipTradeQuote)
  try #require(quote.allowed)
  let runtime = GameRuntime(game: game, saveURL: file)
  try await runtime.save(to: file)
  let before = await runtime.snapshot().commander
  let bytes = try Data(contentsOf: file)
  let property = try ownedHullSaveFiles(at: directory)
  let backup = folder.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: directory, to: backup)
  try Data("blocked".utf8).write(to: directory)
  await runtime.key("showroom-trade")
  await runtime.key("right")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == before)
  #expect(await runtime.snapshot().showroom.trading)
  #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
  #expect(try ownedHullSaveFiles(at: backup) == property)
  try FileManager.default.removeItem(at: directory)
  try FileManager.default.moveItem(at: backup, to: directory)
  await runtime.key("return")
  let after = await runtime.snapshot().commander
  #expect(after.shipID == "SH001" && after.missiles == 1 && after.valid)
  #expect(after.credits == quote.balance)
  #expect(after.accommodation == before.accommodation)
  #expect(after.accommodation.storedBerths.map(\.id) == [cabin])
  try verifyOwnedHullPortableProperty(before: before, after: after)
  for id in stored {
    #expect(after.equipmentInventory?.items.first { $0.id == id }?.location == nil)
  }
  try #require(after.npcPersistence.count == 0)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: file), from: file)
  #expect(saved == after)
  let reloaded = GameRuntime()
  try await reloaded.load(from: file, persistMigrations: false)
  #expect(await reloaded.snapshot().commander == after)
}

@Test func ordinaryHullTradeSurvivesLaterExplicitSaveFailureAndSavesCurrentPropertyOnRetry()
  async throws
{
  let folder = try missionGearFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let directory = folder.appendingPathComponent("save")
  let file = directory.appendingPathComponent("commander.json")
  var game = try missionGearGame(missiles: 4)
  let stored = try missionPrepareSmallHullExchange(&game)
  game.screen = .showroom
  game.showroom.selection = "SH001"
  game.commander.credits = 10_000_000
  try #require(!game.requiresScriptDurability)
  let quote = try #require(game.shipTradeQuote)
  try #require(quote.allowed)
  let runtime = GameRuntime(game: game, saveURL: file)
  try await runtime.save(to: file)
  let before = await runtime.snapshot().commander
  let bytes = try Data(contentsOf: file)
  let property = try ownedHullSaveFiles(at: directory)
  let backup = folder.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: directory, to: backup)
  try Data("blocked".utf8).write(to: directory)
  await runtime.key("showroom-trade")
  await runtime.key("right")
  await runtime.key("return")
  let acceptedGame = await runtime.snapshot()
  let accepted = acceptedGame.commander
  try #require(!acceptedGame.requiresScriptDurability && accepted.npcPersistence.count == 0)
  #expect(accepted.shipID == "SH001" && accepted.missiles == 1 && accepted.valid)
  #expect(accepted.credits == quote.balance && !acceptedGame.showroom.trading)
  try verifyOwnedHullPortableProperty(before: before, after: accepted)
  for id in stored {
    #expect(accepted.equipmentInventory?.items.first { $0.id == id }?.location == nil)
  }
  await #expect(throws: (any Error).self) { try await runtime.save(to: file) }
  #expect(await runtime.snapshot().commander == accepted)
  #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
  #expect(try ownedHullSaveFiles(at: backup) == property)
  try FileManager.default.removeItem(at: directory)
  try FileManager.default.moveItem(at: backup, to: directory)
  // Freeze the independent expected disk property before writing, not from readback.
  let expectedDisk = accepted
  try await runtime.save(to: file)
  #expect(await runtime.snapshot().commander == expectedDisk)
  let saved = try JSONDecoder().decode(Commander.self, from: Data(contentsOf: file))
  #expect(saved == expectedDisk)
}

private func verifyOwnedHullPortableProperty(before: Commander, after: Commander) throws {
  let original = try #require(before.equipmentInventory)
  let transferred = try #require(after.equipmentInventory)
  try #require(original.items.allSatisfy { $0.boundHull == nil })
  #expect(transferred.owner == original.owner && transferred.activeHull != original.activeHull)
  #expect(transferred.revision == original.revision + 1)
  #expect(Set(transferred.items.map(\.id)) == Set(original.items.map(\.id)))
  for item in original.items {
    let retained = try #require(transferred.items.first { $0.id == item.id })
    #expect(retained.moved(to: nil) == item.moved(to: nil))
    #expect(retained.location?.slot == item.location?.slot)
    #expect(retained.location == nil || retained.location?.hullInstanceID == transferred.activeHull)
  }
  #expect(after.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  #expect(after.cargo == before.cargo && after.fuel == before.fuel)
}

private func ownedHullSaveFiles(at directory: URL) throws -> [String: Data] {
  let files = try #require(
    FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
  var result: [String: Data] = [:]
  for case let file as URL in files {
    guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
      continue
    }
    result[String(file.path.dropFirst(directory.path.count + 1))] = try Data(contentsOf: file)
  }
  return result
}

@Test func hullConflictsRefuseAtomicallyAndExplicitRefitsKeepTheSameLasersRoundsAndEmptyCabins()
  throws
{
  var game = try missionGearGame(missiles: 4)
  for mount in LaserMount.allCases {
    try game.commander.grantEquipment(
      LaserKind.military.equipmentName, at: .laser(mount), provenance: .grant("hull-fixture"))
  }
  let cabin = PassengerBerth()
  game.commander.accommodation.ownedBerths = [cabin]
  game.commander.accommodation.fitted = [cabin.id]
  let before = game.commander
  #expect(throws: (any Error).self) {
    try game.commander.transferEquipment(to: "SH001", hullID: UUID())
  }
  #expect(game.commander == before)
  _ = try missionPrepareSmallHullExchange(&game)
  let target = try #require(ShipCatalogue.ship("SH001")?.game)
  for item in try #require(game.commander.equipmentInventory).items {
    if case .laser(let mount) = item.location?.slot, !target.supports(mount) {
      try missionStorePhysical(item, in: &game)
    }
  }
  try game.setPassengerBerthFitted(cabin.id, fitted: false)
  try game.commander.transferEquipment(to: "SH001", hullID: UUID())
  #expect(game.commander.valid && game.commander.missiles == 1)
  try game.commander.transferEquipment(to: "SH023", hullID: UUID())
  for original in try #require(before.equipmentInventory).items {
    guard let slot = original.location?.slot,
      let held = game.commander.equipmentInventory?.items.first(where: { $0.id == original.id }),
      held.location == nil
    else { continue }
    try game.fitEquipment(
      held, at: slot, expectedRevision: game.commander.equipmentInventory!.revision)
  }
  try game.setPassengerBerthFitted(cabin.id, fitted: true)
  #expect(
    Set(game.commander.equipmentInventory!.items.map(\.id))
      == Set(before.equipmentInventory!.items.map(\.id)))
  #expect(game.commander.missiles == 4 && game.commander.accommodation.fitted == [cabin.id])
  #expect(game.commander.valid)
}

@Test func firingAfterAnExplicitStoredTransferConsumesOneActualRoundWithoutRecreatingIt() throws {
  var game = try missionGearGame(missiles: 4)
  let stored = try missionPrepareSmallHullExchange(&game)
  try game.commander.transferEquipment(to: "SH001", hullID: UUID())
  let before = try #require(game.commander.equipmentInventory)
  game.launch()
  game.bodies = [SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 800))]
  game.missileArmed = true
  let launched = game.fireMissile()
  try #require(launched)
  #expect(game.commander.equipmentInventory?.items.count == before.items.count - 1)
  game.dock()
  try game.commander.transferEquipment(to: "SH023", hullID: UUID())
  #expect(game.commander.missiles == 0)
  for (index, id) in stored.sorted(by: { $0.uuidString < $1.uuidString }).enumerated() {
    let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == id })
    try game.fitEquipment(
      held, at: .missilePylon(index), expectedRevision: game.commander.equipmentInventory!.revision)
  }
  #expect(game.commander.missiles == 3)
  #expect(
    Set(game.commander.equipmentInventory!.items.map(\.id)).isSubset(
      of: Set(before.items.map(\.id))))
  let decoded = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(game.commander))
  #expect(decoded == game.commander && decoded.valid)
}

@Test func legacyReadDTORejectsDuplicateSlotsAndPreservesStoredConditionThroughActualMigration()
  throws
{
  var original = OwnedGear(kind: .module("E.C.M. System"), slot: .module("E.C.M. System"))
  var legacy = LegacyOwnedEquipmentInventory()
  legacy.items = [original, original]
  #expect(!legacy.valid)
  original.condition = 4000
  legacy.items = [original]
  #expect(!legacy.valid)
  original.fittedSlot = nil
  original.modifications = ["source-upgrade": 7]
  legacy.items = [original]
  #expect(legacy.valid)
  var commander = Commander()
  commander.equipment = []
  commander.laserMounts = LaserMounts()
  commander.missiles = 0
  commander.fuel = 0
  commander.legacyOwnedEquipment = legacy
  let decoded = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(commander))
  var migrated = decoded
  try migrated.prepareEquipment()
  try migrated.transferEquipment(to: "SH013", hullID: UUID())
  let preserved = try #require(migrated.equipmentInventory?.items.first { $0.id == original.id })
  #expect(preserved.retainedLegacyState?.conditionBasisPoints == 4000)
  #expect(preserved.retainedLegacyState?.modifications == ["source-upgrade": 7])
  #expect(preserved.location == nil && migrated.valid)
}
