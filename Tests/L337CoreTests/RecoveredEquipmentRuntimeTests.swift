import Foundation
import Testing

@testable import L337Core

private func recoveredEquipmentLedger(_ definition: String) throws -> SalvageLedger {
  var ledger = SalvageLedger(seed: 123)
  try addRecoveredEquipmentLot(definition, site: 0, ledger: &ledger)
  return ledger
}

private func addRecoveredEquipmentLot(
  _ definition: String, site: UInt32, ledger: inout SalvageLedger
) throws {
  let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: site, lineage: 1)
  let section = SalvageSectionProfile(
    index: 0, kind: .computer, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
    radius: 10, workSeconds: 1, structural: false,
    technologyDefinitionIDs: [definition], sourceFaceIndex: 0)
  _ = ledger.advance(
    wreck: wreck, section: section, pose: .init(), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: UInt64(site) + 1,
    conditions: .init(
      toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
      resourcesAvailable: true, ownershipAuthorized: true))
  let lot = try #require(ledger.pendingLots.first)
  var cargo = Array(repeating: 0, count: 17)
  let collected = ledger.collect(
    lot: lot.identity, cargo: &cargo, freeTonnes: 20, apertureHalfExtents: .init(100, 100, 100),
    hasScoops: true, approachAllowed: true, protection: .init())
  #expect(collected == .collected(lot))
}

func recoveredEquipmentGame(_ definition: String) throws -> Game {
  var game = Game(executive: false)
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.screen = .inventory
  try game.commander.prepareEquipment(legacy: false)
  game.commander.salvageLedger = try recoveredEquipmentLedger(definition)
  return game
}

struct RecoveredEquipmentRuntimeTests {
  @Test(arguments: [
    SalvageUpgradeAxis.frontShieldCapacity, .rearShieldCapacity,
    .frontShieldRecharge, .rearShieldRecharge,
  ])
  func actualShieldUpgradeConsumesItsSourceOnceAndPreservesBothChargeFractions(
    axis: SalvageUpgradeAxis
  ) throws {
    var game = try recoveredEquipmentGame("shield-technology")
    game.energy = game.commander.performance.energy / 4
    game.frontShield = game.commander.shieldCapacity / 2
    game.rearShield = game.commander.rearShieldCapacity * 0.75
    let old = try #require(game.commander.fittedEquipment(at: .shield))
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: axis, slot: .shield)
    let credits = game.commander.credits
    let fuel = game.commander.fuel
    let cargoBefore = game.commander.cargoTonnes
    try game.applyRecoveredUpgrade(quote)
    let after = try #require(game.commander.fittedEquipment(at: .shield))
    #expect(after.id == old.id && after.provenance == old.provenance)
    #expect(after.component?.origin == old.component?.origin)
    #expect(after.component?.receipts.count == 1 && after.component != old.component)
    #expect(game.commander.salvageLedger.inventory.isEmpty)
    #expect(game.commander.cargoTonnes < cargoBefore)
    #expect(game.commander.credits == credits && game.commander.fuel == fuel)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
    #expect(abs(game.frontShield / game.commander.shieldCapacity - 0.5) < 1e-10)
    #expect(abs(game.rearShield / game.commander.rearShieldCapacity - 0.75) < 1e-10)
    #expect(game.energy == game.commander.performance.energy / 4)
    let committed = game.commander
    #expect(throws: RecoveredEquipmentError.staleQuote) { try game.applyRecoveredUpgrade(quote) }
    #expect(game.commander == committed)
  }

  @Test func anEnergyUpgradeQuotedBeforeARealFlightTickStillFitsItsUnchangedPhysicalComponent()
    throws
  {
    var game = try recoveredEquipmentGame("energy-technology")
    game.launch()
    game.bodies = []
    game.celestials = []
    game.speed = 0
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: .energyCapacity, slot: .energy)
    let time = game.commander.flightSimulation.physicalTime
    game.energy = game.commander.performance.energy / 4
    game.tick(delta: 0.1)
    #expect(game.commander.flightSimulation.physicalTime > time)
    let fraction = game.energy / game.commander.performance.energy
    let native = game.commander.performance.energy
    try game.applyRecoveredUpgrade(quote)
    #expect(game.commander.performance.energy > native)
    #expect(abs(game.energy / game.commander.performance.energy - fraction) < 1e-10)
    #expect(game.commander.salvageLedger.inventory.isEmpty && !game.docked)
  }

  @Test func realNavigationFuelEfficiencyControlsRingsRoutesJumpSpoolAndActualFuelDebit() throws {
    var game = try recoveredEquipmentGame("drive-technology")
    game.commander.credits = 100_000
    game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
    let navigation = try #require(
      Equipment.all.first { $0.name == NavigationTier.advanced.equipmentName })
    let purchase = try game.quoteEquipmentPurchase(navigation)
    _ = try game.applyEquipmentPurchase(purchase)
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: .jumpFuelCost, slot: .navigation)
    let before = game.commander.fuel
    try game.applyRecoveredUpgrade(quote)
    #expect(game.commander.jumpFuelMultiplier < 1 && game.commander.fuel == before)
    #expect(game.jumpReach.actual == game.commander.maximumJumpDistance)
    #expect(game.jumpReach.maximum == game.commander.fullTankJumpDistance)
    let origin = try #require(
      game.knownSystems.first { origin in
        game.knownSystems.contains {
          let distance = origin.distance(to: $0)
          return distance > 7 && distance <= game.commander.maximumJumpDistance
        }
      })
    game.commander.system = origin.id
    let destination = try #require(
      game.knownSystems.first {
        let distance = origin.distance(to: $0)
        return distance > 7 && distance <= game.commander.maximumJumpDistance
          && game.commander.jumpFuelCost(distance: distance) < Int((distance * 10).rounded())
      })
    let distance = game.currentSystem.distance(to: destination)
    let graph = NavigationGraph(game: game)
    #expect(
      graph.path(from: game.commander.system, to: destination.id, fuel: before, scoring: 0) == [
        game.commander.system, destination.id,
      ])
    game.launch()
    game.bodies = []
    game.celestials = []
    game.selectedSystem = destination.id
    game.beginHyperspace()
    #expect(game.jumpCountdown == game.commander.performance.spool)
    let debit = game.commander.jumpFuelCost(distance: distance)
    game.arrive()
    #expect(game.commander.system == destination.id && game.commander.fuel == before - debit)
  }

  @Test(arguments: [SalvageUpgradeAxis.jumpReach, .spoolDuration])
  func otherNavigationAxesAffectActualShipValuesAndKeepLegacyKeys(axis: SalvageUpgradeAxis) throws {
    var game = try recoveredEquipmentGame("drive-technology")
    let before = game.commander
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: axis, slot: .navigation)
    try game.applyRecoveredUpgrade(quote)
    if axis == .jumpReach {
      #expect(game.commander.jumpCap > before.jumpCap)
      #expect(game.commander.performance.spool == before.performance.spool)
    } else {
      #expect(game.commander.performance.spool < before.performance.spool)
      #expect(game.commander.jumpCap == before.jumpCap)
      game.launch()
      game.bodies = []
      game.celestials = []
      game.selectedSystem = try #require(
        game.knownSystems.first {
          let distance = game.currentSystem.distance(to: $0)
          return distance > 0 && distance <= game.commander.maximumJumpDistance
        }?.id)
      game.beginHyperspace()
      #expect(game.jumpCountdown == game.commander.performance.spool)
      #expect(try #require(game.jumpCountdown) < before.performance.spool)
    }
    #expect(NavigationTier.advanced.equipmentName == "Navigation: Advanced")
    #expect(NavigationTier.advanced.label == "Intermediate")
    #expect(NavigationTier.military.equipmentName == "Navigation: Military")
    #expect(NavigationTier.military.label == "Advanced")
  }

  @Test func actualAdditionalRecoveryInvalidatesTheSourceRevisionWithoutConsumingEitherLot() throws
  {
    var game = try recoveredEquipmentGame("shield-technology")
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: .frontShieldCapacity, slot: .shield)
    let ownedRevision = game.commander.equipmentInventory!.revision
    var ledger = game.commander.salvageLedger
    try addRecoveredEquipmentLot("energy-technology", site: 1, ledger: &ledger)
    game.commander.salvageLedger = ledger
    #expect(ledger.revision > quote.sourceRevision && ledger.inventory.count == 2)
    #expect(game.commander.equipmentInventory?.revision == ownedRevision)
    let before = game.commander
    #expect(throws: RecoveredEquipmentError.staleQuote) { try game.applyRecoveredUpgrade(quote) }
    #expect(game.commander == before && game.commander.salvageLedger.inventory.count == 2)
  }

  @Test(arguments: [false, true])
  func anActualDifferentOwnerOrHullCannotApplyTheOriginalPhysicalQuote(changeHull: Bool) throws {
    var game = try recoveredEquipmentGame("shield-technology")
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: .frontShieldCapacity, slot: .shield)
    if changeHull {
      try game.commander.transferEquipment(to: "SH013", hullID: UUID())
      #expect(game.commander.equipmentOwnerID == quote.owner)
      #expect(game.commander.hullInstanceID != quote.hull)
    } else {
      game = try recoveredEquipmentGame("shield-technology")
      #expect(game.commander.equipmentOwnerID != quote.owner)
    }
    let before = game.commander
    #expect(throws: RecoveredEquipmentError.staleQuote) { try game.applyRecoveredUpgrade(quote) }
    #expect(game.commander == before && game.commander.salvageLedger.inventory.count == 1)
  }

  @Test func anActualShieldPurchaseReplacesTheQuotedInstanceWithoutConsumingItsRecoveredSource()
    throws
  {
    var game = try recoveredEquipmentGame("shield-technology")
    game.commander.credits = 100_000
    game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: .frontShieldCapacity, slot: .shield)
    let item = try #require(Equipment.all.first { $0.name == ShieldBooster.pulse.equipmentName })
    let purchase = try game.quoteEquipmentPurchase(item)
    _ = try game.applyEquipmentPurchase(purchase)
    #expect(game.commander.fittedEquipment(at: .shield)?.id != quote.item.id)
    let before = game.commander
    #expect(throws: RecoveredEquipmentError.staleQuote) { try game.applyRecoveredUpgrade(quote) }
    #expect(game.commander == before && game.commander.salvageLedger.inventory.count == 1)
  }

  @Test func changedPhysicalCustodyCannotConsumeTheOriginalUpgradeForAnotherComponent() throws {
    var game = try recoveredEquipmentGame("shield-technology")
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: .frontShieldCapacity, slot: .shield)
    let shield = try #require(game.commander.fittedEquipment(at: .shield))
    try game.storeEquipment(shield, expectedRevision: game.commander.equipmentInventory!.revision)
    let before = game.commander
    #expect(throws: RecoveredEquipmentError.staleQuote) { try game.applyRecoveredUpgrade(quote) }
    #expect(game.commander == before && game.commander.salvageLedger.inventory.count == 1)
  }

  @Test func aLaterFailedExplicitSaveDoesNotUndoOrRepeatAnAlreadyCommittedFit() async throws {
    var game = try recoveredEquipmentGame("energy-technology")
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: .energyRecharge, slot: .energy)
    try game.applyRecoveredUpgrade(quote)
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    await #expect(throws: (any Error).self) { try await runtime.save(to: directory) }
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander)
    #expect(after.commander.salvageLedger.inventory.isEmpty)
    #expect(after.commander.fittedComponent(at: .energy)?.receipts.count == 1)
  }
}
