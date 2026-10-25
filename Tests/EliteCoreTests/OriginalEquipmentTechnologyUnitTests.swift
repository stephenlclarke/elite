import Foundation
import Testing

@testable import EliteCore

struct OriginalEquipmentTechnologyUnitTests {
  private static let levels: [String: Int] = [
    "Fuel": 1, "Missile": 2, "Large Cargo Bay": 4, "E.C.M. System": 5,
    "Pulse Laser": 3, "Beam Laser": 7, "Fuel Scoops": 4, "Escape Pod": 6,
    "Energy Bomb": 13, "Galactic Hyperdrive": 15, "Mining Laser": 6, "Military Laser": 14,
  ]

  private func shop(_ name: String, level: Int) throws -> Game {
    let world = try #require(Universe.originalWorlds.worlds.first { $0.technology == level })
    var game = Game(executive: false)
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity - 1
    game.commander.missiles = 0
    game.commander.credits = 1_000_000
    game.commander.galaxy = world.galaxy
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.energy = game.commander.performance.energy
    game.frontShield = game.commander.shieldCapacity
    game.rearShield = game.commander.rearShieldCapacity
    game.screen = .equipment
    game.equipmentMount = .rear
    game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
    try game.commander.prepareEquipment(legacy: false)
    try #require(game.currentSystem.technology == level && game.commander.valid)
    return game
  }

  @Test(
    arguments: Array(OriginalEquipmentTechnologyUnitTests.levels.keys).filter {
      OriginalEquipmentTechnologyUnitTests.levels[$0]! >= 4
    }
    .sorted())
  func actualWorldBoundaryControlsShopQuoteAndDisplayedRefusal(name: String) throws {
    let level = try #require(Self.levels[name])
    var below = try shop(name, level: level - 1)
    let item = Equipment.all[below.selection]
    #expect(item.technology == level - 1 && item.requiredTechnologyLevel == level)
    #expect(!below.equipmentAvailable(item))
    #expect(below.equipmentPurchaseRequirement(item) == "Requires TL\(level)")
    let frame = Display.equipmentScreen(below, width: 1512, height: 768)
    #expect(frame.labels.map(\.text).joined(separator: " ").contains("Requires TL\(level)"))
    let before = below.commander
    #expect(throws: EquipmentRuntimeError.unavailable) { try below.quoteEquipmentPurchase(item) }
    let refused = below.purchaseImmediately()
    #expect(!refused.applied && below.commander == before)

    var at = try shop(name, level: level)
    #expect(at.equipmentAvailable(item) && at.equipmentPurchaseRequirement(item) == nil)
    let availableFrame = Display.equipmentScreen(at, width: 1512, height: 768)
    #expect(!availableFrame.labels.map(\.text).joined(separator: " ").contains("Requires TL"))
    let quote = try at.quoteEquipmentPurchase(item)
    let cash = at.commander.credits
    _ = try at.applyEquipmentPurchase(quote)
    #expect(at.commander.credits == cash - quote.purchase.requiredDebit && at.commander.valid)
  }

  @Test func lowestAuthoredWorldsAndLaterEnergyKeepTheirCurrentConsumerPolicies() throws {
    // The authored catalogue starts at TL3; do not invent TL1/2 planets for a boundary test.
    #expect(Universe.originalWorlds.worlds.map(\.technology).min() == 3)
    for name in ["Fuel", "Missile", "Pulse Laser"] {
      var game = try shop(name, level: 3)
      let item = Equipment.all[game.selection]
      let level = try #require(Self.levels[name])
      #expect(item.technology == level - 1 && item.requiredTechnologyLevel == level)
      #expect(game.equipmentAvailable(item) && game.equipmentPurchaseRequirement(item) == nil)
      let cash = game.commander.credits
      let price = game.shopPrice(item)
      let result = game.purchaseImmediately()
      #expect(result.applied && game.commander.credits == cash - price)
      if name == "Fuel" { #expect(game.commander.fuel == game.commander.fuelCapacity) }
    }
    for (name, level) in [
      ("Extra Energy Unit", 9), (Equipment.navalEnergyUnit, 12), (Equipment.eliteEnergyUnit, 14),
    ] {
      let game = try shop(name, level: level - 1)
      let item = Equipment.all[game.selection]
      #expect(item.requiredTechnologyLevel == level)
      #expect(!game.equipmentAvailable(item))
      #expect(game.equipmentPurchaseRequirement(item) == "Requires TL\(level)")
    }
  }

  @Test(arguments: [ShieldBooster.pulse, .mining, .beam, .military])
  func derivedShieldUnlocksAndPlughExceptionKeepTheirExistingAuthority(booster: ShieldBooster)
    throws
  {
    let laserName = booster.label + " Laser"
    let level = try #require(Self.levels[laserName])
    var below = try shop(booster.equipmentName, level: max(3, level - 1))
    let item = Equipment.all[below.selection]
    #expect(item.requiredTechnologyLevel == level)
    if level > 3 {
      #expect(!below.equipmentAvailable(item))
      #expect(below.equipmentPurchaseRequirement(item) == "Requires TL\(level)")
    } else {
      #expect(below.equipmentAvailable(item) && below.equipmentPurchaseRequirement(item) == nil)
    }
    below.commander.discoverPlugh(in: below.commander.galaxy)
    below.commander.system = Plugh.systemID
    #expect(below.equipmentAvailable(item))
    // Availability does not manufacture paid predecessor receipts at the secret port.
    if booster != .pulse {
      #expect(below.equipmentPurchaseRequirement(item)?.hasPrefix("Buy ") == true)
    }
    let laser = try #require(Equipment.all.first { $0.name == laserName })
    #expect(item.technology == laser.technology && item.price == laser.price * 3 / 4)
  }
}
