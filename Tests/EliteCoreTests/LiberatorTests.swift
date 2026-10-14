import Foundation
import Testing

@testable import EliteCore

@Test func liberatorCanBeFoundBoughtFlownDockedAndSavedWithItsActualFit() throws {
  let ship = try #require(ShipCatalogue.ship("SH171"))
  let performance = try #require(ship.game)
  #expect(ship.name == "Liberator DSV2" && performance.price == 415_000)
  var game = Game(executive: false)
  game.screen = .status
  game.commander.credits = 10_000_000
  game.commander.cargo[0] = 3
  game.commander.missionStage = .huntingConstrictor
  game.commander.installLaser(.beam, on: .rear)
  game.key("6")
  for query in ["liberator", "DSV2", "SH171"] {
    game.showroom.query = query
    #expect(game.showroomShips.map(\.id) == ["SH171"])
  }
  game.showroom.selection = "SH171"
  let original = game.commander
  let quote = try #require(game.shipTradeQuote)
  #expect(quote.allowed && quote.purchase == 4_150_000 && quote.allowance == 1_125_000)
  #expect(game.showroomComparison.contains { $0.label == "Cargo" && $0.rating == .better })
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander.shipID == "SH171" && game.commander.credits == quote.balance)
  #expect(game.commander.cargo == original.cargo && game.commander.equipment == original.equipment)
  #expect(game.commander.missionStage == original.missionStage)
  #expect(game.commander.laserMounts == original.laserMounts)
  #expect(game.commander.fuel == original.fuel && game.commander.missiles == original.missiles)
  game.launch()
  game.bodies = []
  game.speed = 0
  var controls = Controls()
  controls.throttle = 1
  controls.pitch = 1
  game.tick(delta: 0.1, controls: controls)
  #expect(abs(game.speed - performance.acceleration * 0.1) < 0.00001)
  #expect(game.pitch == performance.pitch && game.energy == performance.energy)
  game.dock()
  #expect(game.frontShield == performance.shield && game.rearShield == performance.shield)
  let restored = try JSONDecoder().decode(
    Commander.self, from: JSONEncoder().encode(game.commander))
  #expect(restored == game.commander && restored.shipID == "SH171" && restored.valid)
  #expect(restored.playerMesh.materials == ship.previewMesh?.materials)
  #expect(restored.playerMesh.faceMaterials == ship.design.faceMaterials)
}

@Test func liberatorMaterialsSurviveProjectionAndKeepWireframePoliciesIndependent() throws {
  let ship = try #require(ShipCatalogue.ship("SH171"))
  let mesh = try #require(ship.previewMesh)
  #expect(ship.design.valid && mesh.materials.count == 7)
  #expect(mesh.faceMaterials.count == mesh.faces.count)
  #expect(mesh.materials.filter(\.emissive).map(\.name) == ["engine"])
  var greenSeen = false
  for step in 0..<24 {
    let angle = Double(step) * .pi / 12
    let portrait = Display.shipPortrait(ship, angle: angle)
    #expect(!portrait.shipPanels.isEmpty)
    #expect(portrait.shipPanels.flatMap(\.vertices).allSatisfy { portrait.flightClip.contains($0) })
    greenSeen = greenSeen || portrait.shipPanels.contains { $0.colour == 0x39D8_5BFF }
    var game = Game(executive: false)
    game.screen = .front
    var body = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 400))
    body.orientation.rotate(pitch: 0.3, roll: 0.15, yaw: angle)
    var counts: [Int] = []
    for style in [ShipDisplayStyle.whiteWireframe, .colourWireframe] {
      game.commander.shipDisplayStyle = style
      var frame = Frame()
      frame.rasterizeGraphics = false
      Display.draw(body, game: game, into: &frame, mesh: mesh)
      #expect(frame.shipPanels.isEmpty && !frame.shipLines.isEmpty)
      #expect(frame.shipLines.allSatisfy { $0.ink == (style == .whiteWireframe ? .white : .cyan) })
      counts.append(frame.shipLines.count)
    }
    #expect(counts[0] == counts[1])
  }
  #expect(greenSeen)
  #expect(
    ShipProjection.shade(UInt32(0x39D8_5BFF), normal: .init(0, 0, 1), emissive: true) == 0x39D8_5BFF
  )
  #expect(ShipProjection.shade(.cyan, normal: .init(0, 0, 1)) != Ink.cyan.rawValue)
}

@Test func shipMaterialLoaderRejectsIncompleteIndicesAndTransparentPanels() throws {
  let ship = try #require(ShipCatalogue.ship("SH171"))
  var definition = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ship.design)) as? [String: Any])
  for invalid in [[0], Array(repeating: 999, count: ship.design.faces.count)] {
    definition["faceMaterials"] = invalid
    let design = try JSONDecoder().decode(
      ShipDesign.self, from: JSONSerialization.data(withJSONObject: definition))
    #expect(!design.valid)
  }
  definition["faceMaterials"] = ship.design.faceMaterials
  definition["materials"] = [["name": "transparent", "colour": 0x00FF_FF00, "emissive": false]]
  definition["faceMaterials"] = Array(repeating: 0, count: ship.design.faces.count)
  let transparent = try JSONDecoder().decode(
    ShipDesign.self, from: JSONSerialization.data(withJSONObject: definition))
  #expect(!transparent.valid)
  definition.removeValue(forKey: "materials")
  definition.removeValue(forKey: "faceMaterials")
  let legacy = try JSONDecoder().decode(
    ShipDesign.self, from: JSONSerialization.data(withJSONObject: definition))
  #expect(legacy.valid && legacy.rawMesh.materials.isEmpty)
}
