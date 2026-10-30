import Foundation
import Testing

@testable import L337Core

// Controlled shop initialization; no arrival, purchase or fitted-item receipt is invented.
private func originalEquipmentShop(atPlugh: Bool = false) throws -> Game {
  var game = Game(executive: false)
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity - 3
  game.commander.credits = 1_000_000
  if atPlugh {
    game.commander.discoverPlugh(in: game.commander.galaxy)
    game.commander.system = Plugh.systemID
  } else {
    game.commander.system = try #require(
      game.systems.first { !$0.isPlugh && $0.technology >= 17 }?.id)
  }
  game.screen = .equipment
  game.equipmentMount = .left
  try game.commander.prepareEquipment(legacy: false)
  game.energy = game.commander.performance.energy / 2
  game.frontShield = game.commander.shieldCapacity / 2
  game.rearShield = game.commander.rearShieldCapacity / 4
  try #require(game.stationAllowsEquipmentServices && game.commander.valid)
  try #require(game.commander.missiles < game.commander.missileCapacity)
  return game
}

struct OriginalEquipmentStockValuesTests {
  @Test func originalStockPricesAndOneBasedTechnologyUseTheAuthenticatedFourteenRows() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    #expect(
      OriginalWorldCatalogue.approvedFingerprints["authoring.toml"]
        == "47d83caae5a9b22a4a932f19c55f79c5cb5435b962826a0969ece096b11f80eb")
    try #require(catalogue.authoring.equipment.count == 14)
    for row in catalogue.authoring.equipment {
      let matches = Equipment.all.filter { $0.name == row.name }
      let item = try #require(matches.first)
      #expect(matches.count == 1)
      #expect(item.technology == row.technology - 1)
      #expect(item.requiredTechnologyLevel == row.technology)
      if row.id == "fuel" {
        // The authored 1.8 CR has no denominator; retain the existing native supply-unit price.
        #expect(row.priceCR == 1.8 && item.price == 2)
      } else {
        #expect(Double(item.price) == row.priceCR * 10)
      }
    }
  }

  @Test(arguments: [false, true])
  func actualStockQuotesDebitTheApprovedPriceOnceAndRetainPhysicalCustody(atPlugh: Bool) throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    for row in catalogue.authoring.equipment where row.id != "fuel" {
      var game = try originalEquipmentShop(atPlugh: atPlugh)
      if row.name == Equipment.navalEnergyUnit {
        let intermediate = try #require(Equipment.all.first { $0.name == "Extra Energy Unit" })
        let predecessor = try game.quoteEquipmentPurchase(intermediate)
        let fitted = try game.applyEquipmentPurchase(predecessor)
        try #require(fitted)
      }
      let item = try #require(Equipment.all.first { $0.name == row.name })
      let nativePrice = Int(row.priceCR * 10)
      let expected = atPlugh ? (nativePrice * 3 + 2) / 4 : nativePrice
      if row.name == Equipment.navalEnergyUnit && atPlugh { #expect(expected == 147000) }
      let before = game.commander
      let inventory = try #require(before.equipmentInventory)
      let energy = game.energy
      let front = game.frontShield
      let rear = game.rearShield
      let quote = try game.quoteEquipmentPurchase(item)
      #expect(game.shopPrice(item) == expected && quote.purchase.requiredDebit == expected)
      let fitted = try game.applyEquipmentPurchase(quote)
      #expect(fitted && !game.commander.unlimitedCash)
      #expect(game.commander.credits == before.credits - expected)
      let paid = try #require(game.commander.equipmentPurchaseHistory?.paid.last)
      #expect(paid.node == quote.request.offer.node && paid.price == expected)
      #expect(
        game.commander.equipmentPurchaseHistory?.paid.count
          == (before.equipmentPurchaseHistory?.paid.count ?? 0) + 1)
      let after = try #require(game.commander.equipmentInventory)
      #expect(after.owner == inventory.owner && after.activeHull == inventory.activeHull)
      #expect(after.items.contains { $0.id == quote.request.newItem && $0.location != nil })
      for original in inventory.items {
        let retained = try #require(after.items.first { $0.id == original.id })
        #expect(retained.moved(to: nil) == original.moved(to: nil))
      }
      #expect(game.commander.fuel == before.fuel && game.commander.cargo == before.cargo)
      #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
      if row.name == "Extra Energy Unit" || row.name == Equipment.navalEnergyUnit {
        #expect(
          game.commander.energyRechargeMultiplier == (row.name == "Extra Energy Unit" ? 2 : 3))
        #expect(game.commander.performance.energy == game.commander.nativePerformance.energy)
      }
      #expect(game.commander.valid)
    }
  }

  @Test func originalTechnologyBoundariesAndDockServicesStillRefuseUnavailableOffers() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    for row in catalogue.authoring.equipment {
      var game = try originalEquipmentShop()
      let item = try #require(Equipment.all.first { $0.name == row.name })
      game.commander.system = try #require(
        game.systems.first { !$0.isPlugh && $0.technology >= row.technology }?.id)
      #expect(game.equipmentAvailable(item))
      if let lower = game.systems.filter({ !$0.isPlugh && $0.technology < row.technology })
        .max(by: { $0.technology < $1.technology })
      {
        game.commander.system = lower.id
        let before = game.commander
        #expect(!game.equipmentAvailable(item))
        #expect(throws: EquipmentRuntimeError.unavailable) { try game.quoteEquipmentPurchase(item) }
        #expect(game.commander == before)
      }
      game.commander.system = Plugh.systemID
      #expect(game.equipmentAvailable(item))
      game.docked = false
      #expect(!game.equipmentAvailable(item))
    }
  }

  @Test func supersededStockPricesCannotBecomeAuthoritativePaidReceipts() throws {
    let oldOffers: [(String, Int, Int)] = [
      ("Missile", 300, 0), ("Large Cargo Bay", 4000, 0), ("E.C.M. System", 6000, 2),
      ("Pulse Laser", 4000, 3), ("Beam Laser", 10000, 4), ("Fuel Scoops", 5250, 5),
      ("Escape Pod", 10000, 6), ("Energy Bomb", 9000, 7), ("Extra Energy Unit", 15000, 8),
      ("Galactic Hyperdrive", 50000, 10), ("Mining Laser", 8000, 10),
      ("Military Laser", 60000, 10), (Equipment.navalEnergyUnit, 45000, 11),
    ]
    let game = try originalEquipmentShop()
    let before = game.commander
    for (name, price, technology) in oldOffers {
      let old = Equipment(name: name, price: price, technology: technology)
      #expect(throws: EquipmentRuntimeError.unavailable) { try game.quoteEquipmentPurchase(old) }
      #expect(game.commander == before)
    }
  }

  @Test func higherStockPricesDoNotBypassPaidPredecessorsCashOrAlienAcquisition() throws {
    var game = try originalEquipmentShop(atPlugh: true)
    let advanced = try #require(Equipment.all.first { $0.name == Equipment.navalEnergyUnit })
    let intermediate = try #require(Equipment.all.first { $0.name == "Extra Energy Unit" })
    let prerequisite = try #require(EquipmentRuntimeCatalog.node(for: intermediate.name))
    let before = game.commander
    #expect(throws: EquipmentPurchaseError.missingPrerequisite(prerequisite)) {
      try game.quoteEquipmentPurchase(advanced)
    }
    #expect(game.commander == before)
    game.commander.credits = 53999
    let insufficient = game.commander
    #expect(game.shopPrice(intermediate) == 54000)
    #expect(throws: EquipmentPurchaseError.insufficientFunds) {
      try game.quoteEquipmentPurchase(intermediate)
    }
    #expect(game.commander == insufficient)
    let alien = try #require(Equipment.all.first { $0.name == AlienMissileDefinition.name })
    #expect(!game.commander.hasAlienMissileResearch && !game.equipmentAvailable(alien))
    #expect(game.commander == insufficient)
  }

  @Test func unresolvedFuelPriceStillChargesMissingSupplyAndDiscountsTheWholeRefillOnce() throws {
    var game = try originalEquipmentShop(atPlugh: true)
    let fuel = try #require(Equipment.all.first { $0.name == "Fuel" })
    try #require(game.commander.fuelCapacity - game.commander.fuel == 3)
    #expect(fuel.price == 2 && fuel.requiredTechnologyLevel == 1)
    #expect(game.shopPrice(fuel) == 5 && game.refillCost == 5)
    game.selection = try #require(Equipment.all.firstIndex { $0.name == fuel.name })
    let before = game.commander
    game.purchase()
    #expect(game.commander.credits == before.credits - 5)
    #expect(game.commander.fuel == game.commander.fuelCapacity)
    #expect(game.commander.equipmentInventory == before.equipmentInventory)
    #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  }
}
