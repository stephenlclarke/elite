import Testing

@testable import EliteCore

struct EquipmentSelectionTests {
  @Test func existingArrowAndReturnControlsBuyIntoTheSeparateWorkTool() throws {
    var game = Game(executive: false)
    game.screen = .equipment
    game.commander.credits = 100_000
    game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
    try game.commander.prepareEquipment(legacy: false)
    let front = try #require(game.commander.fittedEquipment(at: .laser(.front)))
    for _ in 0..<4 { game.key("right") }
    #expect(game.equipmentWorkTool && game.equipmentMount == .rear)
    game.selection = try #require(
      Equipment.all.firstIndex { $0.name == LaserKind.mining.equipmentName })
    game.key("return")
    #expect(game.commander.hasMiningWorkTool)
    #expect(game.commander.fittedEquipment(at: .laser(.front)) == front)
    #expect(game.commander.credits == 92000)
    game.key("right")
    #expect(!game.equipmentWorkTool && game.equipmentMount == .front)
    game.key("left")
    #expect(game.equipmentWorkTool)
  }

  @Test func anUnsupportedHullNeverAddsAUtilityDestinationToTheMountCycle() {
    var game = Game(executive: false)
    game.screen = .equipment
    game.commander.shipID = "SH001"
    game.commander.missiles = 1
    for _ in 0..<4 { game.key("right") }
    #expect(!game.equipmentWorkTool && game.equipmentMount == .front)
    game.equipmentWorkTool = true
    game.key("left")
    #expect(!game.equipmentWorkTool && game.equipmentMount == .rear)
  }
}
