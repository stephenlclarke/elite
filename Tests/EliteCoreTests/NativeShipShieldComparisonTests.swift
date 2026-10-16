import Testing

@testable import EliteCore

struct NativeShipShieldComparisonTests {
  @Test func symmetricStockStillSuppliesBothKnownShieldAxesForEveryNativeHull() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let before = game.commander
    for ship in ShipCatalogue.all where ship.game != nil {
      game.showroom.selection = ship.id
      let profile = try #require(game.showroomProfile)
      for key in [
        "fore_shield_max", "aft_shield_max", "fore_shield_recharge_per_second",
        "aft_shield_recharge_per_second",
      ] {
        let field = try #require(profile.fields.first { $0.key == key })
        #expect(field.number != nil && field.status == "game")
      }
      #expect(
        !game.showroomComparison.filter { $0.label.contains("shield") }.contains {
          $0.rating == .unavailable
        })
    }
    #expect(game.commander == before)
  }

  @Test func actualRecoveredRearUpgradeKeepsFrontAndRearComparisonsAvailable() throws {
    var game = try recoveredEquipmentGame("shield-technology")
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let quote = try game.commander.quoteRecoveredUpgrade(
      lot: lot.identity, axis: .rearShieldCapacity, slot: .shield)
    try game.applyRecoveredUpgrade(quote)
    #expect(game.commander.rearShieldCapacity > game.commander.shieldCapacity)
    game.showroom.selection = "SH013"
    let actual = game.commander.gameShipProfile
    #expect(
      actual.fields.first { $0.key == "aft_shield_max" }?.number
        == game.commander.rearShieldCapacity)
    #expect(
      actual.fields.first { $0.key == "fore_shield_max" }?.number == game.commander.shieldCapacity)
    let comparisons = game.showroomComparison.filter { $0.label.contains("shield") }
    #expect(comparisons.count == 4 && comparisons.allSatisfy { $0.rating != .unavailable })
  }
}
