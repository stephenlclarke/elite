import Foundation
import Testing

@testable import EliteCore

struct OriginalEquipmentPriceUnitTests {
  // Independent approved CR-to-tenths oracle; energy units retain their later module prices.
  private static let prices: [String: Int] = [
    "Fuel": 18, "Missile": 1800, "Large Cargo Bay": 28000, "E.C.M. System": 21000,
    "Pulse Laser": 14500, "Beam Laser": 47000, "Fuel Scoops": 19000, "Escape Pod": 36000,
    "Energy Bomb": 128000, "Galactic Hyperdrive": 285000, "Mining Laser": 33000,
    "Military Laser": 164000,
  ]

  private func shop(_ name: String, discounted: Bool) throws -> Game {
    var game = Game(executive: false)
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity - 7
    game.commander.missiles = 0
    game.commander.credits = 1_000_000
    game.energy = game.commander.performance.energy
    game.frontShield = game.commander.shieldCapacity
    game.rearShield = game.commander.rearShieldCapacity
    if discounted {
      game.commander.discoverPlugh(in: game.commander.galaxy)
      game.commander.system = Plugh.systemID
    } else {
      game.commander.system = try #require(
        game.systems.filter { !$0.isPlugh }.max { $0.technology < $1.technology }?.id)
    }
    game.selectedSystem = game.commander.system
    game.screen = .equipment
    game.equipmentMount = .rear
    game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
    try game.commander.prepareEquipment(legacy: false)
    try #require(game.commander.valid && game.stationAllowsEquipmentServices)
    return game
  }

  private func checkReadout(_ game: Game, price: Int, fuel: Bool = false) throws {
    let layout = EquipmentLayout(game: game, width: 1512, height: 768)
    let row = try #require(EquipmentGroups.rows.firstIndex(of: .item(game.selection)))
    try #require(row >= layout.start && row < layout.start + layout.count)
    let y = layout.listTop + Double(row - layout.start) * layout.row
    let expected = String(format: fuel ? "Refill %.1f CR" : "%.1f CR", Double(price) / 10)
    let frame = Display.equipmentScreen(game, width: 1512, height: 768)
    #expect(frame.labels.contains { $0.y == y && $0.text == expected })
  }

  @Test(arguments: Array(OriginalEquipmentPriceUnitTests.prices.keys).sorted(), [false, true])
  func approvedPricesReachActualQuotesReadoutsAndOnceOnlyDebits(name: String, discounted: Bool)
    throws
  {
    var game = try shop(name, discounted: discounted)
    let item = Equipment.all[game.selection]
    let base = try #require(Self.prices[name])
    #expect(item.price == base)
    let raw = name == "Fuel" ? 7 * base : base
    let expected = discounted ? (raw * 3 + 2) / 4 : raw
    #expect(game.shopPrice(item) == expected)
    try checkReadout(game, price: expected, fuel: name == "Fuel")
    let before = game.commander
    if name != "Fuel" {
      let quote = try game.quoteEquipmentPurchase(item)
      #expect(quote.purchase.requiredDebit == expected && quote.request.offer.price == expected)
      #expect(game.commander == before)
    } else {
      #expect(game.refillCost == expected)
      if discounted { #expect(expected == 95) }  // Discount the whole seven-unit refill once.
    }
    let intent = EquipmentMutationIntent.purchase(try #require(game.equipmentPurchaseContext))
    let result = game.performEquipmentMutation(intent)
    #expect(result.applied)
    #expect(game.commander.credits == before.credits - expected)
    #expect(game.commander.valid)
    if name == "Fuel" {
      #expect(game.commander.fuel == game.commander.fuelCapacity)
      #expect(game.commander.equipmentInventory == before.equipmentInventory)
    } else {
      #expect(game.commander.equipmentPurchaseHistory?.paid.last?.price == expected)
      #expect(game.commander.fuel == before.fuel)
    }
    let paid = game.commander
    let replay = game.performEquipmentMutation(intent)
    #expect(replay == .refused(.staleContext))
    #expect(game.commander == paid)
  }

  @Test(arguments: ["Fuel", "Missile", "E.C.M. System", "Mining Laser"], [false, true])
  func insufficientFundsAndFabricatedPricesCannotMutateTheCommander(name: String, discounted: Bool)
    throws
  {
    var game = try shop(name, discounted: discounted)
    let item = Equipment.all[game.selection]
    let price = game.shopPrice(item)
    game.commander.credits = price - 1
    let before = game.commander
    if name != "Fuel" {
      #expect(throws: EquipmentRuntimeError.unavailable) {
        try game.quoteEquipmentPurchase(
          .init(name: item.name, price: item.price - 1, technology: item.technology))
      }
      #expect(throws: EquipmentPurchaseError.insufficientFunds) {
        try game.quoteEquipmentPurchase(item)
      }
    }
    let intent = EquipmentMutationIntent.purchase(try #require(game.equipmentPurchaseContext))
    let result = game.performEquipmentMutation(intent)
    #expect(!result.applied)
    #expect(game.commander == before)
  }

  @Test func retainedFuelMissileAndCargoPurchasesUseTheApprovedDebits() throws {
    try equipmentPurchases()
  }

  @Test(arguments: [false, true])
  func retainedShieldPurchaseScenariosUseUpdatedPrices(legacy: Bool) throws {
    if legacy {
      try legacyMiningStrengthSurvivesPaidWeakerPurchasesStoredWithOriginalIdentity()
    } else {
      try buyingBoosterRespectsTechnologyCashAndPreventsWeakerTierCharges()
    }
  }

  @Test func laterEnergyPricesAndLaserDerivedShieldQuotesRetainTheirExistingJoins() throws {
    var game = try shop("Extra Energy Unit", discounted: true)
    for (name, base, discounted) in [
      ("Extra Energy Unit", 15000, 11250), (Equipment.navalEnergyUnit, 45000, 33750),
    ] {
      game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
      let item = Equipment.all[game.selection]
      #expect(item.price == base && game.shopPrice(item) == discounted)
      try checkReadout(game, price: discounted)
      let quote = try game.quoteEquipmentPurchase(item)
      #expect(quote.purchase.requiredDebit == discounted)
      let cash = game.commander.credits
      _ = try game.applyEquipmentPurchase(quote)
      #expect(game.commander.credits == cash - discounted)
    }
    var shields = try shop(ShieldBooster.pulse.equipmentName, discounted: false)
    for (booster, price) in [
      (ShieldBooster.pulse, 10875), (.mining, 24750), (.beam, 35250), (.military, 123000),
    ] {
      shields.selection = try #require(
        Equipment.all.firstIndex { $0.name == booster.equipmentName })
      let item = Equipment.all[shields.selection]
      #expect(item.price == price)
      try checkReadout(shields, price: price)
      let quote = try shields.quoteEquipmentPurchase(item)
      #expect(quote.purchase.requiredDebit == price)
      let cash = shields.commander.credits
      _ = try shields.applyEquipmentPurchase(quote)
      #expect(shields.commander.credits == cash - price)
    }
    #expect(Plugh.rewardPrices[Equipment.navalEnergyUnit] == 45000)
    #expect(Plugh.rewardPrices[ShieldBooster.capital.equipmentName] == 135000)
  }
}
