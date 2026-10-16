import Foundation
import Testing

@testable import EliteCore

@Test(arguments: ShipDisplayStyle.allCases)
func nearPlaneShipKeepsVisibleGeometryWhenItsCenterIsBehind(style: ShipDisplayStyle) {
  let mesh = Mesh(
    vertices: [
      .init(-2, -2, -40), .init(2, -2, -40), .init(2, 2, -40), .init(-2, 2, -40),
      .init(-2, -2, 40), .init(2, -2, 40), .init(2, 2, 40), .init(-2, 2, 40),
    ],
    faces: [
      [0, 1, 2, 3], [4, 5, 6, 7], [0, 4, 7, 3], [1, 5, 6, 2], [0, 1, 5, 4], [3, 2, 6, 7],
    ])
  var game = Game(executive: false)
  game.screen = .front
  game.commander.shipDisplayStyle = style
  for z in [-5.0, 5] {
    var body = SpaceBody(id: 90, hull: .cobra, position: .init(4, 0, z))
    body.rotation = 0.15
    var frame = Frame()
    frame.rasterizeGraphics = false
    Display.draw(body, game: game, into: &frame, mesh: mesh)
    #expect(!frame.graphics.isEmpty)
    for graphic in frame.graphics {
      switch graphic {
      case .panel(let panel):
        #expect(
          panel.vertices.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.x >= frame.flightClip.x
              && $0.x < frame.flightClip.maxX && $0.y >= frame.flightClip.y
              && $0.y < frame.flightClip.maxY
          })
      case .wire(let line):
        #expect([line.x0, line.y0, line.x1, line.y1].allSatisfy(\.isFinite))
      default: Issue.record("Unexpected ship primitive")
      }
    }
  }
  var hidden = Frame()
  Display.draw(
    SpaceBody(id: 90, hull: .cobra, position: .init(4, 0, -50)),
    game: game, into: &hidden, mesh: mesh)
  #expect(hidden.graphics.isEmpty)
}

@Test func chartClearUsesItsOwnRectangleAndOutsideClicksPreserveSearch() {
  var game = Game(executive: false)
  game.screen = .chart
  game.viewportWidth = 768
  game.viewportHeight = 768
  let layout = ChartLayout(width: 768, height: 768, local: false, docked: game.docked)
  game.key("/")
  game.key("l")
  game.mapClick(x: layout.searchRect.maxX - 30, y: layout.searchRect.y - 2)
  #expect(!game.mapSearch.active && game.mapSearch.query == "l")
  game.key("/")
  game.mapClick(x: layout.searchClearRect.maxX + 2, y: layout.searchClearRect.y + 10)
  #expect(!game.mapSearch.active && game.mapSearch.query == "l")
  game.key("/")
  game.mapClick(x: layout.searchClearRect.x + 10, y: layout.searchClearRect.y + 10)
  #expect(game.mapSearch.active && game.mapSearch.query.isEmpty)
}

@Test func showroomPortableProjectionMatchesPaidCargoBayHullExchangeWithoutMutation() throws {
  var game = Game(executive: false)
  game.commander.credits = 10_000_000
  game.screen = .equipment
  let bay = try #require(Equipment.all.first { $0.name == "Large Cargo Bay" })
  let quote = try game.quoteEquipmentPurchase(bay)
  #expect(try game.applyEquipmentPurchase(quote))
  let inventory = try #require(game.commander.equipmentInventory)
  let bound = try #require(inventory.items.first { $0.boundHull != nil })
  #expect(game.commander.standardCargoCapacity == 35)
  game.screen = .status
  game.openShowroom()
  game.showroom.selection = "SH013"
  let before = game.commander
  let projected = try #require(game.showroomProfile)
  let profileAgain = try #require(game.showroomProfile)
  #expect(projected.fields == profileAgain.fields)
  #expect(projected.fields.first { $0.key == "physical_hold" }?.number == 125)
  game.showroom.baselineUsesCurrent = false
  game.showroom.baseline = "SH013"
  #expect(game.showroomBaselineProfile?.fields == projected.fields)
  #expect(game.commander == before)
  #expect(game.shipTradeQuote?.allowed == true)
  let portable = Set(inventory.items.filter { $0.boundHull == nil }.map(\.id))
  game.showroom.trading = true
  game.confirmShipTrade()
  #expect(game.commander.shipID == "SH013")
  #expect(game.commander.gameShipProfile.fields == projected.fields)
  #expect(game.commander.equipmentInventory?.items.contains { $0.id == bound.id } == false)
  #expect(Set(game.commander.equipmentInventory?.items.map(\.id) ?? []) == portable)
  #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
}

@Test func incompatibleShowroomProjectionIsExplicitAndKeepsCustody() throws {
  var game = Game(executive: false)
  try game.commander.prepareEquipment()
  // An Adder cannot carry the Cobra's starting three missiles.
  game.showroom.selection = "SH001"
  let before = game.commander
  let profile = try #require(game.showroomProfile)
  #expect(profile.title.contains("incompatible carried fit"))
  #expect(profile.fields.allSatisfy { $0.text == "Unavailable" && $0.number == nil })
  #expect(game.showroomComparison.allSatisfy { $0.rating == .unavailable })
  #expect(game.commander == before)
}
