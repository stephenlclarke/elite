import Foundation
import Testing

@testable import EliteCore

struct NativeStationPersistenceTests {
  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func dockedSaveRestoresHistoricalReceiptWithFreshServiceEpochWithoutArrivalReplay(
    kind: NativeStationGeometry.Kind
  ) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.approach(kind: kind)
    try await verifyDockedStationRestoration(&game, storage: storage)
  }

  @Test func retainedFlightRebindsOnlyNativeStationActorsAndPreservesCommanderResources()
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched()
    try await verifyRetainedNativeStationFlight(&game, storage: storage)
  }

  @Test func failedEntryWritePreservesPreviousFilesAndDoesNotPublishDockingCustody() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.approach(kind: .headquarters)
    try await verifyFailedNativeStationEntryWrite(&game, storage: storage)
  }

  @Test(arguments: ["owner", "duplicate", "adapter"])
  func malformedStationSavesCannotReplaceLiveStateOrPreviousSaveFiles(reason: String)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched()
    try await verifyMalformedStationSave(&game, reason: reason, storage: storage)
  }

  @Test func legacyCommanderLoadCreatesNoStationArrivalOrServiceAuthority() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = Game(executive: false)
    try await verifyLegacyStationAbsence(&game, storage: storage)
  }

  @Test(arguments: [false, true])
  func saveCannotLaunderUnprovedRRSOrMainDockCustodyIntoRestoredAuthority(main: Bool)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched()
    try await verifyUnprovedStationSaveRefusal(&game, main: main, storage: storage)
  }
}

private func emptyStationRuntime() -> GameRuntime {
  GameRuntime(game: Game(executive: false))
}

private func stationSaveFiles(_ root: URL) throws -> [String: Data] {
  let entries = try #require(FileManager.default.enumerator(atPath: root.path))
  var result: [String: Data] = [:]
  for case let relative as String in entries {
    let url = root.appendingPathComponent(relative)
    if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
      try #require(!relative.isEmpty && result[relative] == nil)
      result[relative] = try Data(contentsOf: url)
    }
  }
  return result
}

private func verifyDockedStationRestoration(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  #expect(game.docked && !game.dockedAtMainStation)
  let receipt = try #require(game.commander.nativeStations?.ledger.currentDock)
  let previousContext = try #require(game.nativeStationBoardContext)
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let commander = game.commander
  let files = try stationSaveFiles(storage.directory)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
  #expect(disk == commander)
  let reloaded = emptyStationRuntime()
  try await reloaded.load(from: storage.url, persistMigrations: false)
  game = await reloaded.snapshot()
  let completeCommanderPreserved = game.commander == commander
  #expect(completeCommanderPreserved)
  #expect(game.docked && !game.dockedAtMainStation && !game.paused)
  #expect(game.commander.nativeStations?.ledger.currentDock == receipt)
  #expect(game.commander.nativeStations?.ledger.nextDockSequence == receipt.sequence + 1)
  let fresh = try #require(game.nativeStationBoardContext)
  #expect(fresh.service.receipt == previousContext.service.receipt)
  #expect(fresh.service.runtimeEpoch != previousContext.service.runtimeEpoch)
  #expect(!game.acceptsNativeStationBoardContext(previousContext))
  #expect(game.acceptsNativeStationBoardContext(fresh))
  #expect(try stationSaveFiles(storage.directory) == files)
}

private func verifyRetainedNativeStationFlight(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let before = game.commander
  let originals = game.bodies
  let oldCursor = game.nextBodyID
  let stations = originals.filter { $0.nativeStationIdentity != nil }
  let originalWorld = try #require(before.nativeStations)
  var expected = before
  var flight = before.flightSimulation
  let allocatedSpawn = flight.allocateSpawn()
  _ = try #require(allocatedSpawn)
  for (member, body) in stations.enumerated() {
    let allocatedActor = flight.allocateActor()
    let actor = try #require(allocatedActor)
    let identity = try #require(body.nativeStationIdentity)
    try expected.nativeStations?.ledger.rebind(
      identity, to: .init(actor: actor, bodyID: oldCursor + member))
  }
  expected.flightSimulation = flight
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
  var expectedDisk = before
  expectedDisk.npcPersistence.resetPhysicalBindings(system: game.systemIdentity)
  expectedDisk.resetWantedCareerBindings(system: game.systemIdentity)
  let completeDiskPolicyPreserved = disk == expectedDisk
  #expect(completeDiskPolicyPreserved)
  let reloaded = emptyStationRuntime()
  try await reloaded.load(from: storage.url, persistMigrations: false)
  game = await reloaded.snapshot()
  let completeCommanderPreservedExceptFreshStationBindings = game.commander == expected
  #expect(completeCommanderPreservedExceptFreshStationBindings)
  #expect(game.nextBodyID == oldCursor + stations.count)
  #expect(game.commander.nativeStations?.poses == originalWorld.poses)
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.nextDockSequence == 1)
  #expect(
    game.bodies.filter { $0.nativeStationIdentity == nil }
      == originals.filter { $0.nativeStationIdentity == nil })
  for old in stations {
    let current = try #require(
      game.bodies.first {
        $0.nativeStationIdentity == old.nativeStationIdentity
      })
    #expect(current.physical?.identity != old.physical?.identity && current.id != old.id)
    #expect(current.energy == old.energy && current.position == old.position)
    #expect(current.orientation == old.orientation && current.rotation == old.rotation)
    #expect(current.physical?.velocity == old.physical?.velocity)
    #expect(current.physical?.laserCooldown == old.physical?.laserCooldown)
    #expect(current.physical?.npc == old.physical?.npc)
    #expect(game.nativeStationBodyIsCurrent(current))
  }
}

private func verifyFailedNativeStationEntryWrite(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let before = game.commander
  let files = try stationSaveFiles(storage.directory)
  try storage.blockWriter()
  game = await runtime.advance(delta: 0.1)
  #expect(!game.docked)
  #expect(game.commander.nativeStations == before.nativeStations)
  #expect(game.commander.cargo == before.cargo && game.commander.credits == before.credits)
  #expect(game.commander.equipmentInventory == before.equipmentInventory)
  #expect(game.commander.savedEquipmentPurchaseHistory == before.savedEquipmentPurchaseHistory)
  #expect(game.commander.accommodation == before.accommodation)
  #expect(game.commander.flightSimulation.physicalTime > before.flightSimulation.physicalTime)
  #expect(game.commander.flightSimulation.pose != before.flightSimulation.pose)
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.nextDockSequence == 1)
  #expect(game.pendingNativeStationDock == nil && game.nativeStationBoardContext == nil)
  #expect(try stationSaveFiles(storage.backup) == files)
  try storage.restoreWriter()
  #expect(try stationSaveFiles(storage.directory) == files)
  // Failed saving cannot create a receipt just because the ship remains inside the opening.
  game = await runtime.advance(delta: 0.02)
  #expect(!game.docked && game.commander.nativeStations?.ledger.currentDock == nil)
}

private func verifyMalformedStationSave(
  _ game: inout Game, reason: String, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let commander = game.commander
  let bodies = game.bodies
  let files = try stationSaveFiles(storage.directory)
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(commander)) as? [String: Any])
  var world = try #require(object["nativeStations"] as? [String: Any])
  switch reason {
  case "owner":
    var ledger = try #require(world["ledger"] as? [String: Any])
    ledger["world"] = UUID().uuidString
    world["ledger"] = ledger
  case "duplicate":
    var poses = try #require(world["poses"] as? [[String: Any]])
    poses[1] = poses[0]
    world["poses"] = poses
  case "adapter": world["adapterRevision"] = "forged-adapter"
  default: throw NativeStationRuntimeError.invalidState
  }
  object["nativeStations"] = world
  let forged = storage.root.appendingPathComponent("forged.json")
  try JSONSerialization.data(withJSONObject: object).write(to: forged)
  await #expect(throws: (any Error).self) { try await runtime.load(from: forged) }
  game = await runtime.snapshot()
  let completeCommanderPreserved = game.commander == commander
  #expect(completeCommanderPreserved && game.bodies == bodies)
  #expect(try stationSaveFiles(storage.directory) == files)
}

private func verifyLegacyStationAbsence(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  let commander = game.commander
  let legacy = storage.root.appendingPathComponent("legacy.json")
  let bytes = try legacyStationRawSeedBytes(commander)
  try bytes.write(to: legacy)
  let beforeFiles = try legacyStationSourceFiles(storage.root)
  let runtime = GameRuntime(game: game)
  try await runtime.load(from: legacy, persistMigrations: false)
  game = await runtime.snapshot()
  #expect(game.docked && game.dockedAtMainStation)
  #expect(game.commander.nativeStations == nil)
  #expect(game.nativeStationBoardContext == nil && game.nativeStationEventFacts == nil)
  #expect(!game.nativeStationDockEvidenceIsCurrent && !game.nativeMainStationDockEvidenceIsCurrent)
  #expect(game.commander.credits == commander.credits && game.commander.cargo == commander.cargo)
  try expectLegacyStationStockMigration(from: commander, to: game.commander)
  let afterBytes = try Data(contentsOf: legacy)
  let afterFiles = try legacyStationSourceFiles(storage.root)
  #expect(afterBytes == bytes && afterFiles == beforeFiles)
}

private func verifyUnprovedStationSaveRefusal(
  _ game: inout Game, main: Bool, storage: NativeStationTestStorage
) async throws {
  let originalRuntime = GameRuntime(game: game, saveURL: storage.url)
  try await originalRuntime.save(to: storage.url)
  game = await originalRuntime.snapshot()
  let files = try stationSaveFiles(storage.directory)
  let station = try #require(game.bodies.first { $0.nativeStationIdentity != nil })
  let identity = try #require(station.nativeStationIdentity)
  let actor = try #require(station.physical?.identity)
  let mainActor = try #require(game.commander.flightSimulation.anchors?.station.identity)
  let owner = try #require(game.commander.equipmentOwnerID)
  let original = try #require(game.commander.nativeStations?.mainStations.first)
  game.dock(atMainStation: main)
  if main {
    let calendarSeconds = game.commander.scriptState.calendarSeconds
    game.commander.nativeStations?.currentMainDock = .init(
      station: original, actor: mainActor, commanderOwner: owner,
      sequence: 1, calendarSeconds: calendarSeconds)
    game.commander.nativeStations?.nextMainDockSequence = 2
  } else {
    try game.commander.nativeStations?.ledger.recordDock(
      at: identity, binding: .init(actor: actor, bodyID: station.id), commanderOwner: owner)
  }
  #expect(game.commander.nativeStationStateValid)
  #expect(!game.nativeStationDockEvidenceIsCurrent && !game.nativeMainStationDockEvidenceIsCurrent)
  let commander = game.commander
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  await #expect(throws: SaveError.invalidCommander) { try await runtime.save(to: storage.url) }
  game = await runtime.snapshot()
  let completeCommanderUnchanged = game.commander == commander
  #expect(completeCommanderUnchanged)
  #expect(try stationSaveFiles(storage.directory) == files)
  #expect(game.nativeStationBoardContext == nil)
  #expect(game.nativeMainStationArrivalContext(for: original) == nil)
}
