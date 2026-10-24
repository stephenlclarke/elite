import Testing

@testable import EliteCore

struct EquipmentSelectionTests {
  @Test(arguments: [512.0, 1280.0])
  func pointerSelectionUsesTheRenderedUtilityBoundsAndClearsItForACombatCell(width: Double) throws {
    var game = Game(executive: false)
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity
    game.screen = .equipment
    game.viewportWidth = width
    game.viewportHeight = width == 512 ? 518 : 900
    let layout = EquipmentLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
    let tool = try #require(layout.workToolBounds)
    let before = game.commander
    game.equipmentClick(y: tool.y + tool.height / 2, x: tool.x + tool.width / 2)
    #expect(game.equipmentWorkTool && game.commander == before)
    let combat = try #require(layout.mounts.first)
    game.equipmentClick(
      y: combat.bounds.y + combat.bounds.height / 2, x: combat.bounds.x + combat.bounds.width / 2)
    #expect(!game.equipmentWorkTool && game.equipmentMount == combat.mount)
    #expect(game.commander == before)
  }

  @Test func existingArrowAndReturnControlsBuyIntoTheSeparateWorkTool() throws {
    var game = Game(executive: false)
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity
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
