import Foundation
import Testing

@testable import L337Core

private let recoveredFeatureIDs = [
  "feature-mining-targeting", "feature-salvage-targeting", "feature-fuel-scoops",
  "feature-ecm", "feature-salvage-cutter",
]

private func recoveredFeatureGame(_ id: String, core: Bool = true) throws -> Game {
  var game = try recoveredEquipmentGame(id)
  if core {
    try game.commander.grantEquipment(
      TargetingTier.basic.equipmentName, at: .targetingCore, provenance: .grant("feature fixture"))
  }
  game.launch()
  game.bodies = []
  game.celestials = []
  game.speed = 0
  game.screen = .inventory
  return game
}

@discardableResult
private func installRecoveredFeature(_ game: inout Game) throws -> OwnedEquipmentItem {
  let lot = try #require(game.commander.salvageLedger.inventory.first)
  let preview = game.inventoryActionPreview(for: .recovered(lot))
  let command = try #require(preview.command)
  guard case .installFeature(_, let definition) = command.action else {
    throw RecoveredEquipmentError.invalidBinding
  }
  let accepted = game.performInventoryCommand(command)
  #expect(accepted)
  return try #require(game.commander.fittedEquipment(at: definition.slot))
}

struct RecoveredFeatureRuntimeTests {
  @Test(arguments: recoveredFeatureIDs)
  func explicitInSpaceActionCreatesOneSourceLinkedDeviceWithoutPaidHistoryOrRefilling(
    id: String
  ) throws {
    var game = try recoveredFeatureGame(id)
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let before = game.commander
    let rows = game.inventoryInformationRows(width: 512)
    #expect(rows == game.inventoryInformationRows(width: 512))
    #expect(game.commander == before)
    let preview = game.inventoryActionPreview(for: .recovered(lot))
    let command = try #require(preview.command)
    #expect(preview.label == "Fit now" && preview.detail.hasPrefix("Enable "))
    game.energy = game.commander.performance.energy / 4
    game.frontShield = game.commander.shieldCapacity / 2
    game.rearShield = game.commander.rearShieldCapacity * 0.75
    game.laserHeat = 145
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    let accepted = game.performInventoryCommand(command)
    #expect(accepted && !game.docked && game.commander.salvageLedger.inventory.isEmpty)
    let added = try #require(
      game.commander.equipmentInventory?.items.first { item in
        !before.equipmentInventory!.items.contains(where: { $0.id == item.id })
      })
    #expect(added.provenance == .recovered(lot.identity) && added.component == nil)
    #expect(RecoveredFeatureDevices.source(for: added, ledger: game.commander.salvageLedger) == lot)
    #expect(
      game.commander.equipmentInventory!.items.count == before.equipmentInventory!.items.count + 1)
    #expect(game.commander.equipment.contains(added.node.key))
    #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    #expect(game.commander.credits == before.credits && game.commander.fuel == before.fuel)
    #expect(game.commander.missiles == before.missiles && game.laserHeat == 145)
    #expect(abs(game.energy - energy) < 1e-10 && abs(game.frontShield - front) < 1e-10)
    #expect(abs(game.rearShield - rear) < 1e-10)
    let committed = game.commander
    let repeated = game.performInventoryCommand(command)
    #expect(!repeated && game.commander == committed)
    #expect(
      game.inventoryInformationRows(width: 1512).contains {
        $0.text.contains("Recovered quality") && $0.text.contains("condition")
      })
  }

  @Test(arguments: ["feature-mining-targeting", "feature-salvage-targeting"])
  func actualFittedCoreIsRequiredAndNeitherSpecialtyConfersTheOther(id: String) throws {
    var game = try recoveredFeatureGame(id, core: false)
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let before = game.commander
    let refused = game.inventoryActionPreview(for: .recovered(lot))
    #expect(refused.command == nil && refused.detail.contains("core"))
    #expect(game.commander == before)
    try game.commander.grantEquipment(
      TargetingTier.military.equipmentName, at: .targetingCore, provenance: .grant("core fixture"))
    #expect(!game.workTargetCapabilities.miningModule && !game.workTargetCapabilities.salvageModule)
    let core = try #require(game.commander.fittedEquipment(at: .targetingCore))
    try game.commander.storeEquipment(
      core, expectedRevision: game.commander.equipmentInventory!.revision)
    #expect(game.inventoryActionPreview(for: .recovered(lot)).command == nil)
    let heldCore = try #require(game.commander.equipmentInventory?.items.first { $0.id == core.id })
    try game.commander.fitEquipment(
      heldCore, at: .targetingCore,
      expectedRevision: game.commander.equipmentInventory!.revision)
    _ = try installRecoveredFeature(&game)
    #expect(game.workTargetCapabilities.miningModule == (id == "feature-mining-targeting"))
    #expect(game.workTargetCapabilities.salvageModule == (id == "feature-salvage-targeting"))
    let installed = try #require(
      game.commander.equipmentInventory?.items.first {
        $0.provenance == .recovered(lot.identity)
      })
    let fittedCore = try #require(game.commander.fittedEquipment(at: .targetingCore))
    try game.commander.storeEquipment(
      fittedCore, expectedRevision: game.commander.equipmentInventory!.revision)
    #expect(game.commander.valid && game.workTargetCapabilities.core == nil)
    #expect(game.commander.equipmentInventory?.items.contains(installed) == true)
    #expect(
      RecoveredFeatureDevices.source(for: installed, ledger: game.commander.salvageLedger) == lot)
    let target = WorkTargetCandidate(
      identity: try #require(game.commander.flightSimulation.player), kind: .ship,
      isLive: true, frontVisible: true, distance: 100, singleScoopCompatible: false)
    #expect(
      WorkTargetSelection.evaluate(
        target, system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
        capabilities: game.workTargetCapabilities) == .refused(.missingCore))
  }

  @Test func changedOwnedAndSourceRevisionsRefuseAQuotedInstallWithoutLosingCustody() throws {
    for sourceChanges in [false, true] {
      var game = try recoveredFeatureGame("feature-fuel-scoops")
      let lot = try #require(game.commander.salvageLedger.inventory.first)
      let quote = try game.commander.quoteRecoveredFeature(lot: lot.identity)
      if sourceChanges {
        game.commander.salvageLedger = SalvageLedger()
      } else {
        try game.commander.grantEquipment(
          "E.C.M. System", at: .utility(.ecm), provenance: .grant("revision fixture"))
      }
      let before = game.commander
      #expect(throws: (any Error).self) { try game.applyRecoveredFeature(quote) }
      #expect(
        game.commander == before && game.commander.fittedEquipment(at: .utility(.fuelScoops)) == nil
      )
    }
  }

  @Test func alteredDisplayedDefinitionOrFullLotCannotInstallADifferentDevice() throws {
    for changeDefinition in [false, true] {
      var game = try recoveredFeatureGame("feature-fuel-scoops")
      let lot = try #require(game.commander.salvageLedger.inventory.first)
      let original = try #require(game.inventoryActionPreview(for: .recovered(lot)).command)
      let definition = try #require(
        RecoveredFeatureDevices.definition(
          for: changeDefinition ? "feature-ecm" : "feature-fuel-scoops"))
      let displayedLot =
        changeDefinition
        ? lot
        : SalvageLot(
          identity: lot.identity, content: lot.content, position: lot.position,
          velocity: lot.velocity + Vector3(1, 0, 0), halfExtents: lot.halfExtents,
          massKg: lot.massKg, loot: lot.loot)
      let altered = InventoryCommand(
        owner: original.owner, hull: original.hull, context: original.context,
        shipID: original.shipID, ownedRevision: original.ownedRevision,
        sourceRevision: original.sourceRevision,
        action: .installFeature(displayedLot, definition: definition))
      let before = game.commander
      let accepted = game.performInventoryCommand(altered)
      #expect(!accepted && game.commander == before)
    }
  }

  @Test func occupiedAndUnsupportedSlotsRefuseWithoutConsumingTheRecoveredDevice() throws {
    var occupied = try recoveredFeatureGame("feature-ecm")
    try occupied.commander.grantEquipment(
      "E.C.M. System", at: .utility(.ecm), provenance: .grant("occupied fixture"))
    let occupiedLot = try #require(occupied.commander.salvageLedger.inventory.first)
    let beforeOccupied = occupied.commander
    #expect(occupied.inventoryActionPreview(for: .recovered(occupiedLot)).command == nil)
    #expect(occupied.commander == beforeOccupied)
    let hull = try #require(
      ShipCatalogue.all.first {
        $0.game?.workTools?.contains(.salvageCutter) != true && $0.game != nil
      })
    var unsupported = Game(executive: false)
    unsupported.commander.shipID = hull.id
    unsupported.commander.fuel = min(70, unsupported.commander.nativePerformance.fuel)
    unsupported.commander.missiles = min(3, unsupported.commander.nativePerformance.missiles)
    try #require((0...unsupported.commander.fuelCapacity).contains(unsupported.commander.fuel))
    try #require(
      (0...unsupported.commander.missileCapacity).contains(unsupported.commander.missiles))
    try unsupported.commander.prepareEquipment(legacy: false)
    unsupported.commander.salvageLedger = try recoveredEquipmentGame("feature-salvage-cutter")
      .commander.salvageLedger
    let unsupportedLot = try #require(unsupported.commander.salvageLedger.inventory.first)
    let beforeUnsupported = unsupported.commander
    #expect(unsupported.inventoryActionPreview(for: .recovered(unsupportedLot)).command == nil)
    #expect(unsupported.commander == beforeUnsupported)
  }

  @Test func recoveredECMAndScoopsUseTheRealFlightConsumers() throws {
    var ecm = try recoveredFeatureGame("feature-ecm")
    let energy = ecm.energy
    ecm.ecm()
    #expect(ecm.energy == energy && ecm.ecmFrames == 0)
    _ = try installRecoveredFeature(&ecm)
    ecm.ecm()
    #expect(ecm.ecmFrames == 32 && ecm.energy == energy - 22)
    var scoops = try recoveredFeatureGame("feature-fuel-scoops")
    scoops.commander.fuel = 0
    scoops.speed = 8
    scoops.celestials = [.init(kind: .sun, position: .init(0, 0, 2970), radius: 1100)]
    scoops.advanceSolarFlight(delta: 0.1)
    #expect(scoops.solarScoopState == .noScoops && scoops.commander.fuel == 0)
    _ = try installRecoveredFeature(&scoops)
    for _ in 0..<10 { scoops.advanceSolarFlight(delta: 0.1) }
    #expect(scoops.solarScoopState == .collecting && scoops.commander.fuel > 0)
  }

  @Test func recoveredCutterEnablesTheActualToolWithoutChangingCombatLasers() throws {
    var game = try recoveredFeatureGame("feature-salvage-cutter")
    game.screen = .front
    game.selectFlightTool(.salvageCutter)
    #expect(game.message == "FIT SALVAGE CUTTER")
    let lasers = game.commander.laserMounts
    game.screen = .inventory
    _ = try installRecoveredFeature(&game)
    game.screen = .front
    game.selectFlightTool(.salvageCutter)
    #expect(game.message == "SELECTED SALVAGE CUTTER")
    #expect(game.commander.laserMounts == lasers)
  }

  @Test func sourceReceiptSurvivesStoreRefitRoundTripAndACompatibleNewHull() throws {
    var game = try recoveredFeatureGame("feature-fuel-scoops")
    let source = try #require(game.commander.salvageLedger.inventory.first)
    let installed = try installRecoveredFeature(&game)
    try game.commander.storeEquipment(
      installed, expectedRevision: game.commander.equipmentInventory!.revision)
    let held = try #require(
      game.commander.equipmentInventory?.items.first { $0.id == installed.id })
    #expect(held.location == nil && !game.commander.equipment.contains("Fuel Scoops"))
    try game.commander.fitEquipment(
      held, at: .utility(.fuelScoops),
      expectedRevision: game.commander.equipmentInventory!.revision)
    let oldHull = game.commander.hullInstanceID
    try game.commander.transferEquipment(to: game.commander.shipID, hullID: UUID())
    #expect(game.commander.hullInstanceID != oldHull)
    let encoded = try JSONEncoder().encode(game.commander)
    let decoded = try JSONDecoder().decode(Commander.self, from: encoded)
    try decoded.validateEquipmentState()
    let moved = try #require(decoded.equipmentInventory?.items.first { $0.id == installed.id })
    #expect(moved.location?.hullInstanceID == decoded.hullInstanceID)
    #expect(RecoveredFeatureDevices.source(for: moved, ledger: decoded.salvageLedger) == source)
    #expect(decoded.equipmentPurchaseHistory == game.commander.equipmentPurchaseHistory)
    #expect(decoded == game.commander && decoded.valid)
  }

  @Test func missingPermanentEvidenceRefusesLoadWithoutPublishingOrChangingInteraction()
    async throws
  {
    var game = try recoveredFeatureGame("feature-fuel-scoops")
    _ = try installRecoveredFeature(&game)
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    var invalid = before.commander
    invalid.salvageLedger = SalvageLedger()
    #expect(!invalid.valid)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try JSONEncoder().encode(invalid).write(to: url)
    await #expect(throws: (any Error).self) {
      try await runtime.load(from: url, persistMigrations: false)
    }
    let after = await runtime.snapshot()
    #expect(
      after.commander == before.commander
        && after.inventoryContextEpoch == before.inventoryContextEpoch)
  }
}
