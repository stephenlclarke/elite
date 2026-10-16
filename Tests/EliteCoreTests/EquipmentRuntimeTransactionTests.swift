import Foundation
import Testing

@testable import EliteCore

private func equipmentShopGame() throws -> Game {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 1_000_000
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  try game.commander.prepareEquipment(legacy: false)
  return game
}

private func equipmentShopBuy(_ name: String, game: inout Game) throws {
  game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
  game.purchase()
}

struct EquipmentRuntimeTransactionTests {
  @Test func actualShopRequiresEveryPaidCoreAndRetainsReplacedPhysicalDevices() throws {
    var game = try equipmentShopGame()
    let before = game.commander
    try equipmentShopBuy(TargetingTier.military.equipmentName, game: &game)
    #expect(game.commander == before && game.message.contains("BUY TARGETING: BASIC FIRST"))
    for tier in TargetingTier.allCases {
      try equipmentShopBuy(tier.equipmentName, game: &game)
      #expect(game.commander.targetingTier == tier)
    }
    let inventory = try #require(game.commander.equipmentInventory)
    let cores = inventory.items.filter { $0.node.family == EquipmentPurchaseCatalog.targeting }
    #expect(cores.count == 6 && cores.filter { $0.location == nil }.count == 5)
    #expect(Set(cores.map(\.id)).count == 6)
    #expect(game.commander.equipmentPurchaseHistory?.paid.count == 6)
    #expect(
      game.commander.credits == before.credits - TargetingTier.allCases.reduce(0) { $0 + $1.price })
    #expect(game.commander.valid)
  }

  @Test func aGrantedHighCoreCannotInventPaidPredecessorsOrSpecialistOwnership() throws {
    var game = try equipmentShopGame()
    try game.commander.grantEquipment(
      TargetingTier.military.equipmentName, at: .targetingCore, provenance: .grant("fixture"))
    let military = try #require(game.commander.fittedEquipment(at: .targetingCore))
    let before = game.commander
    try equipmentShopBuy("Targeting: Mining Module", game: &game)
    #expect(game.commander == before && game.message.contains("BUY TARGETING: BASIC FIRST"))
    try equipmentShopBuy(TargetingTier.basic.equipmentName, game: &game)
    #expect(game.commander.fittedEquipment(at: .targetingCore) == military)
    #expect(
      game.commander.equipmentInventory?.items.contains {
        $0.node.key == TargetingTier.basic.equipmentName && $0.location == nil
      } == true)
    try equipmentShopBuy("Targeting: Mining Module", game: &game)
    #expect(game.commander.fittedEquipment(at: .targetingMining) != nil)
    #expect(game.commander.fittedEquipment(at: .targetingSalvage) == nil)
    #expect(game.commander.credits == before.credits - 8000 - 12000)
    #expect(game.commander.equipmentPurchaseHistory?.paid.count == 2)
    #expect(game.commander.equipmentPurchaseHistory?.legacy.isEmpty == true)
  }

  @Test func stockShieldPurchasesAreMonotonicAndPreserveBothCurrentFractions() throws {
    var game = try equipmentShopGame()
    game.energy = game.commander.performance.energy / 4
    game.frontShield = game.commander.shieldCapacity / 2
    game.rearShield = game.commander.rearShieldCapacity * 0.75
    let oldShield = try #require(game.commander.fittedEquipment(at: .shield))
    for (booster, ratio) in [
      (ShieldBooster.pulse, 1.5), (.mining, 1.8), (.beam, 2.0), (.military, 2.3),
    ] {
      try equipmentShopBuy(booster.equipmentName, game: &game)
      #expect(game.commander.shieldCapacity == game.commander.nativePerformance.shield * ratio)
      #expect(abs(game.frontShield / game.commander.shieldCapacity - 0.5) < 1e-10)
      #expect(abs(game.rearShield / game.commander.rearShieldCapacity - 0.75) < 1e-10)
      #expect(game.energy == game.commander.performance.energy / 4)
    }
    #expect(
      game.commander.equipmentInventory?.items.first { $0.id == oldShield.id }?.location == nil)
    var legacy = Commander()
    legacy.equipment.insert(ShieldBooster.mining.equipmentName)
    let original = legacy.shieldCapacity
    try legacy.prepareEquipment()
    #expect(legacy.shieldCapacity == original && original == legacy.nativePerformance.shield * 5)
  }

  @Test(arguments: ["cash", "inventory", "shop", "mount", "work-tool", "flight"])
  func actualPurchaseRejectsAStaleCommanderOrOfferWithoutFurtherMutation(change: String) throws {
    var game = try equipmentShopGame()
    let item = try #require(Equipment.all.first { $0.name == TargetingTier.basic.equipmentName })
    let quote = try game.quoteEquipmentPurchase(item)
    switch change {
    case "cash": game.commander.credits -= 1
    case "inventory":
      let pulse = try #require(game.commander.fittedEquipment(at: .laser(.front)))
      try game.commander.storeEquipment(
        pulse, expectedRevision: game.commander.equipmentInventory!.revision)
    case "shop": game.commander.system = Plugh.systemID
    case "mount": game.equipmentMount = .rear
    case "work-tool": game.equipmentWorkTool = true
    default: game.docked = false
    }
    let before = game
    #expect(throws: EquipmentRuntimeError.staleCommander) {
      try game.applyEquipmentPurchase(quote)
    }
    #expect(game.commander == before.commander)
    #expect(
      game.energy == before.energy && game.frontShield == before.frontShield
        && game.rearShield == before.rearShield)
  }

  @Test func storageAndSeparateWorkToolsChargeExactlyWithoutRefillingOrReplacingCombatWeapons()
    throws
  {
    var game = try equipmentShopGame()
    game.commander.fuel = 17
    let pulse = try #require(game.commander.fittedEquipment(at: .laser(.front)))
    let before = game.commander
    try equipmentShopBuy(FuelStorage.equipmentName, game: &game)
    #expect(game.commander.fuelCapacity == 140 && game.commander.fuel == 17)
    #expect(game.commander.missiles == before.missiles)
    game.equipmentWorkTool = true
    try equipmentShopBuy(LaserKind.mining.equipmentName, game: &game)
    try equipmentShopBuy("Salvage Cutter", game: &game)
    #expect(game.commander.fittedEquipment(at: .laser(.front)) == pulse)
    #expect(game.commander.fittedEquipment(at: .utility(.miningLaser)) != nil)
    #expect(game.commander.fittedEquipment(at: .utility(.salvageCutter)) != nil)
    #expect(game.commander.fittedEquipment(at: .targetingMining) == nil)
    #expect(game.commander.fittedEquipment(at: .targetingSalvage) == nil)
    #expect(game.commander.credits == before.credits - 20000 - 8000 - 16000)
  }

  @Test func specialistAvailabilityAndIndependentPricesUseActualShopTechnology() throws {
    var game = try equipmentShopGame()
    for (name, price, technology) in [
      ("Targeting: Mining Module", 12000, 7), ("Targeting: Salvage Module", 24000, 8),
      ("Salvage Cutter", 16000, 8),
    ] {
      let item = try #require(Equipment.all.first { $0.name == name })
      #expect(item.price == price && item.technology == technology)
      game.commander.system = 7
      #expect(!game.equipmentAvailable(item))
      game.commander.system = Plugh.systemID
      #expect(game.equipmentAvailable(item) && game.shopPrice(item) == Plugh.discount(price))
    }
  }

  @Test func storedSpareCannotActAndConsumptionRemovesOnlyTheFittedPhysicalDevice() throws {
    var game = try equipmentShopGame()
    try game.commander.grantEquipment(
      "Energy Bomb", at: .utility(.energyBomb), provenance: .grant("fixture"))
    let bomb = try #require(game.commander.fittedEquipment(at: .utility(.energyBomb)))
    try game.storeEquipment(bomb, expectedRevision: game.commander.equipmentInventory!.revision)
    let before = game.commander
    let heldActed = game.commander.consumeEquipped("Energy Bomb")
    #expect(!heldActed && game.commander == before)
    let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == bomb.id })
    try game.fitEquipment(
      held, at: .utility(.energyBomb), expectedRevision: game.commander.equipmentInventory!.revision
    )
    let fittedActed = game.commander.consumeEquipped("Energy Bomb")
    #expect(fittedActed && !game.commander.equipment.contains("Energy Bomb"))
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == bomb.id } == false)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func actualHullConfirmationKeepsPortableIdentityHistoryAndResourceFractions() throws {
    var game = try equipmentShopGame()
    game.commander.credits = 100_000_000
    try equipmentShopBuy("E.C.M. System", game: &game)
    try equipmentShopBuy("Large Cargo Bay", game: &game)
    let inventory = try #require(game.commander.equipmentInventory)
    let portable = inventory.items.filter { $0.boundHull == nil }
    let bound = try #require(inventory.items.first { $0.boundHull != nil })
    let history = game.commander.equipmentPurchaseHistory
    game.energy = game.commander.performance.energy * 0.4
    game.frontShield = game.commander.shieldCapacity * 0.3
    game.rearShield = game.commander.rearShieldCapacity * 0.6
    game.showroom.selection = "SH013"
    game.showroom.trading = true
    #expect(game.shipTradeQuote?.allowed == true)
    game.confirmShipTrade()
    #expect(
      game.commander.shipID == "SH013" && game.commander.hullInstanceID != inventory.activeHull)
    #expect(game.commander.equipmentPurchaseHistory == history)
    let transferred = try #require(game.commander.equipmentInventory)
    for item in portable {
      let after = try #require(transferred.items.first { $0.id == item.id })
      #expect(
        after.node == item.node && after.provenance == item.provenance
          && after.component == item.component)
    }
    #expect(!transferred.items.contains { $0.id == bound.id })
    #expect(abs(game.energy / game.commander.performance.energy - 0.4) < 1e-10)
    #expect(abs(game.frontShield / game.commander.shieldCapacity - 0.3) < 1e-10)
    #expect(abs(game.rearShield / game.commander.rearShieldCapacity - 0.6) < 1e-10)
  }

  @Test func maximumGrantIsIdempotentAndDoesNotCreatePaidPurchaseHistory() throws {
    var game = try equipmentShopGame()
    game.docked = false
    game.enableXYZzy()
    let first = game.commander
    game.fitMaximumHardware()
    #expect(game.commander.equipmentInventory == first.equipmentInventory)
    #expect(game.commander.equipmentPurchaseHistory == first.equipmentPurchaseHistory)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
    #expect(game.commander.fittedEquipment(at: .targetingMining)?.provenance == .xyzzy)
    #expect(game.commander.fittedEquipment(at: .targetingSalvage)?.provenance == .xyzzy)
    #expect(game.commander.fittedEquipment(at: .utility(.salvageCutter))?.provenance == .xyzzy)
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    #expect(
      game.commander.fuelStorageUnits == 4
        && game.commander.credits == Commander.xyzzyStartingCredits)
    #expect(!game.commander.unlimitedCash && game.commander.valid)
  }

  @Test func realSaveRoundTripRetainsPhysicalItemsAndPaidHistoryWithoutDuplicatingAMutation()
    async throws
  {
    var game = try equipmentShopGame()
    try equipmentShopBuy(TargetingTier.basic.equipmentName, game: &game)
    try equipmentShopBuy("Targeting: Salvage Module", game: &game)
    #expect(game.commander.fittedEquipment(at: .targetingMining) == nil)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let saved = await runtime.snapshot()
    let restored = GameRuntime()
    try await restored.load(from: url)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.equipmentInventory == saved.commander.equipmentInventory)
    #expect(loaded.commander.equipmentPurchaseHistory == saved.commander.equipmentPurchaseHistory)
    #expect(loaded.commander.credits == game.commander.credits)
    #expect(loaded.commander.fittedEquipment(at: .targetingMining) == nil)
    #expect(loaded.commander.fittedEquipment(at: .targetingSalvage) != nil)
  }

  @Test func failedMigrationWritePreservesTheRunningCommanderAndOriginalSaveBytes() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("commander.json")
    let legacy = try JSONEncoder().encode(Commander())
    try legacy.write(to: url)
    let runtime = GameRuntime(game: try equipmentShopGame())
    let before = await runtime.snapshot()
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: directory.path)
      try? FileManager.default.removeItem(at: directory)
    }
    await #expect(throws: (any Error).self) { try await runtime.load(from: url) }
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander && after.screen == before.screen)
    #expect(try Data(contentsOf: url) == legacy)
  }
}
