import Foundation
import Testing

@testable import EliteCore

private func boundaryGame(_ name: String = "Fuel") throws -> Game {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 1_000_000
  game.commander.fuel = 10
  game.commander.missiles = 0
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  try game.commander.prepareEquipment(legacy: false)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
  return game
}

private func boundaryRecoveredGame() throws -> Game {
  var game = try boundaryGame()
  game.screen = .inventory
  var ledger = SalvageLedger(seed: 123)
  let section = SalvageSectionProfile(
    index: 0, kind: .computer,
    localPosition: .init(0, 0, 0), normal: .init(0, 0, 1), radius: 10, workSeconds: 1,
    structural: false, technologyDefinitionIDs: ["energy-technology"], sourceFaceIndex: 0)
  _ = ledger.advance(
    wreck: .init(system: .init(galaxy: 0, system: 7), site: 0, lineage: 1),
    section: section, pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0),
    tool: .cutter, elapsed: 1, operation: 1,
    conditions: .init(
      toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
      resourcesAvailable: true, ownershipAuthorized: true))
  let lot = try #require(ledger.pendingLots.first)
  var cargo = Array(repeating: 0, count: 17)
  let collected = ledger.collect(
    lot: lot.identity, cargo: &cargo, freeTonnes: 20,
    apertureHalfExtents: .init(100, 100, 100), hasScoops: true, approachAllowed: true,
    protection: .init())
  #expect(collected == .collected(lot))
  game.commander.salvageLedger = ledger
  game.energy = 64
  game.frontShield = 100
  game.rearShield = 50
  return game
}

struct EquipmentActorBoundaryTests {
  @Test(arguments: [false, true])
  func purchaseWithoutDestinationRequiresOnlyRetainedStateDurability(retainedState: Bool)
    async throws
  {
    var game = try boundaryGame("Beam Laser")
    if retainedState { game.ensureScriptCalendar(origin: .newCommander) }
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    #expect(before.requiresScriptDurability == retainedState)
    let context = try #require(before.equipmentPurchaseContext)
    let result = await runtime.equipmentTransaction(.purchase(context))
    let after = await runtime.snapshot()
    if retainedState {
      #expect(result == .refused(.invalidState))
      #expect(after.commander == before.commander)
      #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
      #expect(after.energy == before.energy && after.frontShield == before.frontShield)
      #expect(after.rearShield == before.rearShield)
    } else {
      #expect(result.applied)
      #expect(
        after.commander.credits
          == before.commander.credits - before.shopPrice(Equipment.all[before.selection]))
      #expect(after.commander.laser(on: .front) == .beam)
      #expect(after.commander.equipmentPurchaseHistory?.paid.count == 1)
    }
  }

  @Test func retainedStateRecoveredUpgradeWithoutDestinationPreservesItsSourceAndComponent()
    async throws
  {
    var game = try boundaryRecoveredGame()
    game.ensureScriptCalendar(origin: .newCommander)
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let lot = try #require(before.commander.salvageLedger.inventory.first)
    let command = try #require(before.inventoryActionPreview(for: .recovered(lot)).command)
    let result = await runtime.equipmentTransaction(.inventory(command))
    #expect(result == .refused(.invalidState))
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(after.energy == before.energy && after.frontShield == before.frontShield)
    #expect(after.rearShield == before.rearShield)
  }

  @Test func retainedStatePurchasePublishesExactSavedCommanderAndReplayPreservesSaveBytes()
    async throws
  {
    var game = try boundaryGame("Beam Laser")
    game.ensureScriptCalendar(origin: .newCommander)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game, saveURL: file)
    let before = await runtime.snapshot()
    let context = try #require(before.equipmentPurchaseContext)
    let result = await runtime.equipmentTransaction(.purchase(context))
    #expect(result.applied)
    let after = await runtime.snapshot()
    let bytes = try Data(contentsOf: file)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(saved == after.commander)
    #expect(
      after.commander.credits == before.commander.credits
        - before.shopPrice(Equipment.all[before.selection]))
    #expect(after.commander.laser(on: .front) == .beam)
    #expect(after.commander.equipmentPurchaseHistory?.paid.count == 1)
    let replay = await runtime.equipmentTransaction(.purchase(context))
    #expect(replay == .refused(.staleContext))
    let replayed = await runtime.snapshot()
    #expect(replayed.commander == after.commander)
    #expect(try Data(contentsOf: file) == bytes)
  }

  @Test func retainedStatePurchaseWriterFailurePreservesCashItemsContextAndResources()
    async throws
  {
    var game = try boundaryGame("Beam Laser")
    game.ensureScriptCalendar(origin: .newCommander)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocker = directory.appendingPathComponent("blocked-parent")
    let original = Data("existing file blocks the save directory".utf8)
    try original.write(to: blocker)
    let runtime = GameRuntime(game: game, saveURL: blocker.appendingPathComponent("commander.json"))
    let before = await runtime.snapshot()
    let context = try #require(before.equipmentPurchaseContext)
    let result = await runtime.equipmentTransaction(.purchase(context))
    #expect(result == .refused(.invalidState))
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(after.energy == before.energy && after.frontShield == before.frontShield)
    #expect(after.rearShield == before.rearShield)
    #expect(try Data(contentsOf: blocker) == original)
  }

  @Test func concurrentFuelAndPhysicalMissileDuplicateIntentsCommitOnce()
    async throws
  {
    for name in ["Fuel", "Missile"] {
      let runtime = GameRuntime(game: try boundaryGame(name))
      let before = await runtime.snapshot()
      let context = try #require(before.equipmentPurchaseContext)
      async let first = runtime.equipmentTransaction(.purchase(context))
      async let second = runtime.equipmentTransaction(.purchase(context))
      let results = await [first, second]
      #expect(results.filter(\.applied).count == 1)
      #expect(results.contains(.refused(.staleContext)))
      let after = await runtime.snapshot()
      let oldInventory = try #require(before.commander.equipmentInventory)
      let nextInventory = try #require(after.commander.equipmentInventory)
      if name == "Fuel" {
        #expect(nextInventory == oldInventory)
        #expect(
          after.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
      } else {
        #expect(nextInventory.revision == oldInventory.revision + 1)
        #expect(nextInventory.items.count == oldInventory.items.count + 1)
        #expect(after.commander.equipmentPurchaseHistory?.paid.count == 1)
        #expect(nextInventory.items.contains { $0.node == EquipmentRuntimeCatalog.standardMissile })
      }
      #expect(
        after.commander.credits == before.commander.credits
          - before.shopPrice(Equipment.all[before.selection]))
      #expect(
        name == "Fuel"
          ? after.commander.fuel == after.commander.fuelCapacity : after.commander.missiles == 1)
      if name == "Missile" {
        let fresh = try #require(after.equipmentPurchaseContext)
        let secondIntent = await runtime.equipmentTransaction(.purchase(fresh))
        let twice = await runtime.snapshot()
        #expect(secondIntent.applied && twice.commander.missiles == 2)
      }
    }
  }

  @Test func competingSameRevisionPhysicalSlotIntentsCannotBothCreatePaidItems() async throws {
    let runtime = GameRuntime(game: try boundaryGame("Beam Laser"))
    let before = await runtime.snapshot()
    let context = try #require(before.equipmentPurchaseContext)
    var otherFitting = before
    otherFitting.equipmentMount = .left
    let otherContext = try #require(otherFitting.equipmentPurchaseContext)
    async let a = runtime.equipmentTransaction(.purchase(context))
    async let b = runtime.equipmentTransaction(.purchase(otherContext))
    let results = await [a, b]
    #expect(results.filter(\.applied).count == 1)
    let after = await runtime.snapshot()
    #expect(after.commander.equipmentPurchaseHistory?.paid.count == 1)
    #expect(after.commander.laser(on: .front) == .beam)
    #expect(after.commander.laser(on: .left) == nil)
    #expect(
      after.commander.equipmentInventory?.items.count
        == (before.commander.equipmentInventory?.items.count ?? 0) + 1)
  }

  @Test func concurrentRecoveredSourceCommandsConsumeExactLotOnceWithoutCashOrPaidReceipts()
    async throws
  {
    let runtime = GameRuntime(game: try boundaryRecoveredGame())
    let before = await runtime.snapshot()
    let energyFraction = before.energy / before.commander.performance.energy
    let frontFraction = before.frontShield / before.commander.shieldCapacity
    let rearFraction = before.rearShield / before.commander.rearShieldCapacity
    let lot = try #require(before.commander.salvageLedger.inventory.first)
    let command = try #require(before.inventoryActionPreview(for: .recovered(lot)).command)
    async let a = runtime.equipmentTransaction(.inventory(command))
    async let b = runtime.equipmentTransaction(.inventory(command))
    let results = await [a, b]
    #expect(results.filter(\.applied).count == 1)
    #expect(results.contains(.refused(.staleContext)))
    let after = await runtime.snapshot()
    #expect(after.commander.salvageLedger.inventory.isEmpty)
    #expect(after.commander.fittedComponent(at: .energy)?.receipts.count == 1)
    #expect(after.commander.credits == before.commander.credits)
    #expect(after.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
    #expect(abs(after.energy / after.commander.performance.energy - energyFraction) < 1e-10)
    #expect(abs(after.frontShield / after.commander.shieldCapacity - frontFraction) < 1e-10)
    #expect(abs(after.rearShield / after.commander.rearShieldCapacity - rearFraction) < 1e-10)
    var flying = try boundaryRecoveredGame()
    flying.launch()
    flying.screen = .inventory
    flying.bodies = []
    flying.celestials = []
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let flightRuntime = GameRuntime(game: flying, saveURL: file)
    let flightPreview = await flightRuntime.snapshot()
    let flightLot = try #require(flightPreview.commander.salvageLedger.inventory.first)
    let flightCommand = try #require(
      flightPreview.inventoryActionPreview(for: .recovered(flightLot)).command)
    _ = await flightRuntime.advance(delta: 0.02)
    let beforeFlightMutation = await flightRuntime.snapshot()
    let flightResult = await flightRuntime.equipmentTransaction(.inventory(flightCommand))
    #expect(flightResult.applied)
    let committed = await flightRuntime.snapshot()
    #expect(!committed.docked && committed.requiresScriptDurability)
    #expect(committed.commander.salvageLedger.inventory.isEmpty)
    #expect(committed.commander.fittedComponent(at: .energy)?.receipts.count == 1)
    #expect(
      committed.commander.fittedComponent(at: .energy)?.receipts.first?.item
        == .salvage(flightLot.identity))
    #expect(committed.commander.credits == beforeFlightMutation.commander.credits)
    #expect(
      committed.commander.equipmentPurchaseHistory
        == beforeFlightMutation.commander.equipmentPurchaseHistory)
    let oldInventory = try #require(beforeFlightMutation.commander.equipmentInventory)
    let nextInventory = try #require(committed.commander.equipmentInventory)
    #expect(
      nextInventory.owner == oldInventory.owner
        && nextInventory.activeHull == oldInventory.activeHull)
    #expect(nextInventory.revision == oldInventory.revision + 1)
    #expect(nextInventory.items.count == oldInventory.items.count)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 21 && pointer.scope == "commander")
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(saved.valid && saved.salvageLedger == committed.commander.salvageLedger)
    #expect(saved.equipmentInventory == committed.commander.equipmentInventory)
    #expect(saved.equipmentPurchaseHistory == committed.commander.equipmentPurchaseHistory)
    #expect(saved.credits == committed.commander.credits)
  }

  @Test func loadRefreshesContextEvenWhenCommanderPurchaseFactsAreUnchanged() async throws {
    let game = try boundaryGame()
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let context = try #require(before.equipmentPurchaseContext)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try await runtime.save(to: url)
    try await runtime.load(from: url)
    await runtime.key("3")
    let loaded = await runtime.snapshot()
    #expect(loaded.commander.equipmentOwnerID == before.commander.equipmentOwnerID)
    #expect(loaded.commander.hullInstanceID == before.commander.hullInstanceID)
    #expect(
      loaded.commander.equipmentInventory?.revision == before.commander.equipmentInventory?.revision
    )
    #expect(loaded.inventoryContextEpoch != before.inventoryContextEpoch)
    let result = await runtime.equipmentTransaction(.purchase(context))
    #expect(result == .refused(.staleContext))
    let after = await runtime.snapshot()
    #expect(after.commander == loaded.commander)
    for scenario in 0..<3 {
      let freshRuntime = GameRuntime(game: game)
      let original = await freshRuntime.snapshot()
      let old = try #require(original.equipmentPurchaseContext)
      if scenario == 0 {
        await freshRuntime.key("8")
        await freshRuntime.key("3")
      } else if scenario == 1 {
        await freshRuntime.key("pause")
        await freshRuntime.key("return")
        let paused = await freshRuntime.snapshot()
        #expect(paused.commander == original.commander)
        let denied = await freshRuntime.equipmentTransaction(.purchase(old))
        #expect(!denied.applied)
        await freshRuntime.key("pause")
        await freshRuntime.key("escape")
        await freshRuntime.key("3")
      } else {
        try await freshRuntime.restoreStartup(from: url)
        await freshRuntime.key("return")
        await freshRuntime.key("3")
      }
      let stale = await freshRuntime.equipmentTransaction(.purchase(old))
      #expect(stale == .refused(.staleContext))
    }
  }

  @Test func refusalRollsBackAndFailedLaterExplicitSaveCannotUndoCommittedMutation() async throws {
    var game = try boundaryGame(TargetingTier.military.equipmentName)
    let refusedRuntime = GameRuntime(game: game)
    let before = await refusedRuntime.snapshot()
    let refusal = await refusedRuntime.equipmentTransaction(
      .purchase(try #require(before.equipmentPurchaseContext)))
    #expect(!refusal.applied)
    let unchanged = await refusedRuntime.snapshot()
    #expect(unchanged.commander == before.commander)
    var malformed = try boundaryGame("Fuel")
    malformed.commander.fuel = malformed.commander.fuelCapacity + 1
    let badRuntime = GameRuntime(game: malformed)
    let badBefore = await badRuntime.snapshot()
    let badContext = try #require(badBefore.equipmentPurchaseContext)
    let invalid = await badRuntime.equipmentTransaction(.purchase(badContext))
    let badAfter = await badRuntime.snapshot()
    #expect(invalid == .refused(.invalidState) && badAfter.commander == badBefore.commander)
    game.selection = try #require(Equipment.all.firstIndex { $0.name == "Beam Laser" })
    let runtime = GameRuntime(game: game)
    let snapshot = await runtime.snapshot()
    let result = await runtime.equipmentTransaction(
      .purchase(try #require(snapshot.equipmentPurchaseContext)))
    #expect(result.applied)
    let committed = await runtime.snapshot()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    await #expect(throws: (any Error).self) { try await runtime.save(to: directory) }
    let after = await runtime.snapshot()
    #expect(after.commander == committed.commander)
    #expect(after.commander.equipmentPurchaseHistory?.paid.count == 1)
  }

  @Test func concurrentSnapshotsObserveOnlyCoherentBeforeOrAfterPurchaseStates() async throws {
    let runtime = GameRuntime(game: try boundaryGame("Beam Laser"))
    let before = await runtime.snapshot()
    let context = try #require(before.equipmentPurchaseContext)
    async let purchase = runtime.equipmentTransaction(.purchase(context))
    async let reading = runtime.snapshot()
    let result = await purchase
    let observed = await reading
    let after = await runtime.snapshot()
    #expect(result.applied)
    #expect(observed.commander == before.commander || observed.commander == after.commander)
    #expect(after.commander.equipmentPurchaseHistory?.paid.count == 1)
    #expect(after.commander.laser(on: .front) == .beam)
    #expect(after.commander.credits < before.commander.credits)
  }
}
