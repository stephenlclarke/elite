import Foundation
import Testing

@testable import EliteCore

@Test func xyzzyFitsClarkeAndCyclesDisplayWhilePreservingProgress() async throws {
  var game = Game(executive: false)
  #expect(game.commander.name == "JAMESON" && game.commander.shipDisplayStyle == .whiteWireframe)
  game.key("return")
  game.commander.credits = 1234
  game.commander.cargo[0] = 3
  game.frontShield = 1
  game.rearShield = 2
  game.energy = 3
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.commander.name == "CLARKE")
  #expect(game.commander.equipment == Set(Equipment.all.map(\.name)))
  #expect(game.commander.credits == 1234 && game.commander.cargo[0] == 3)
  #expect(game.commander.missiles == 4 && game.commander.fuel == 70)
  #expect(game.frontShield == 255 && game.rearShield == 255 && game.energy == 256)
  for expected in [
    ShipDisplayStyle.colourWireframe, .shadedPanels, .whiteWireframe, .colourWireframe,
  ] {
    game.key("0")
    #expect(game.commander.shipDisplayStyle == expected)
    #expect(!Display.render(game).pixels.isEmpty)
  }
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: url)
  let restored = GameRuntime()
  try await restored.load(from: url)
  #expect(await restored.snapshot().commander == game.commander)
  game.key("escape")
  game.key("0")
  #expect(!game.docked && game.commander.shipDisplayStyle == .colourWireframe)
}

@Test func displayStyleDecodingAcceptsOldSavesAndRejectsUnknownStyles() throws {
  let legacy = try JSONEncoder().encode(Commander())
  let old = try JSONDecoder().decode(Commander.self, from: legacy)
  #expect(old.shipDisplayStyle == .whiteWireframe && old == Commander())
  var object = try #require(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
  object["displayStyle"] = "unsupported"
  let invalid = try JSONSerialization.data(withJSONObject: object)
  #expect(throws: DecodingError.self) { try JSONDecoder().decode(Commander.self, from: invalid) }
}

@Test func coloursPreserveWireGeometryAndPanelsAreOpaqueAndClipped() {
  var game = Game(executive: false)
  game.screen = .front
  for hull in Hull.allCases {
    for angle in [0.0, Double.pi / 2, 2.3] {
      var body = SpaceBody(id: 0, hull: hull, position: .init(0, 0, 400))
      body.rotation = angle
      game.bodies = [body]
      game.commander.shipDisplayStyle = .whiteWireframe
      let white = Display.render(game, rasterizeShips: false)
      game.commander.shipDisplayStyle = .colourWireframe
      let colour = Display.render(game, rasterizeShips: false)
      #expect(white.shipLines.count == colour.shipLines.count && colour.shipPanels.isEmpty)
      #expect(colour.shipLines.allSatisfy { $0.ink == hull.ink })
      #expect(
        zip(white.shipLines, colour.shipLines).allSatisfy {
          $0.x0 == $1.x0 && $0.y0 == $1.y0 && $0.x1 == $1.x1 && $0.y1 == $1.y1
        })
      game.commander.shipDisplayStyle = .shadedPanels
      let shaded = Display.render(game)
      #expect(!shaded.shipPanels.isEmpty && shaded.shipLines.isEmpty)
      #expect(
        shaded.shipPanels.allSatisfy { panel in
          panel.colour & 255 == 255
            && panel.vertices.allSatisfy {
              $0.x >= -1e-8 && $0.x <= 255 + 1e-8 && $0.y >= 12 - 1e-8 && $0.y <= 175 + 1e-8
            }
        })
      #expect(shaded.pixels != white.pixels)
    }
  }
}

@Test func shadedFacesClipAcrossNearPlaneAndViewport() {
  let crossing = [Vector3(-2, -2, -1), Vector3(2, -2, 4), Vector3(2, 2, 4), Vector3(-2, 2, -1)]
  let projected = ShipProjection.polygon(crossing)
  #expect(projected.count == 4)
  #expect(ShipProjection.polygon([]).isEmpty)
  #expect(ShipProjection.polygon([.init(0, 0, -1), .init(1, 0, -1), .init(0, 1, -1)]).isEmpty)
  #expect(ShipProjection.polygon([.init(.infinity, 0, 1)]).isEmpty)
  var frame = Frame()
  frame.panel(projected, colour: Ink.blue.rawValue)
  #expect(!frame.shipPanels.isEmpty && frame.pixels.contains(Ink.blue.rawValue))
  frame.panel([], colour: 0)
  frame.panel([.init(.nan, 0), .init(0, 0), .init(1, 1)], colour: 0)
  frame.panel([.init(-50, -50), .init(-20, -50), .init(-20, -20)], colour: 0)
  #expect(frame.shipPanels.count == 1)
  let light = ShipProjection.shade(.cyan, normal: .init(-0.4, 0.6, -1))
  let dark = ShipProjection.shade(.cyan, normal: .init(0.4, -0.6, 1))
  #expect(light != dark && light & 255 == 255 && dark & 255 == 255)
}

@Test func nearerShadedShipsCoverDistantPanels() {
  var game = Game(executive: false)
  game.screen = .front
  game.commander.shipDisplayStyle = .shadedPanels
  let near = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 400))
  let far = SpaceBody(id: 2, hull: .cargo, position: .init(0, 0, 800))
  game.bodies = [near]
  let single = Display.render(game)
  game.bodies = [near, far]
  let both = Display.render(game)
  #expect(single.pixels[96 * 256 + 128] == both.pixels[96 * 256 + 128])
}

@Test func contextHelpPausesFlightAndRestoresEveryScreen() {
  for screen in Screen.allCases where screen != .help {
    var game = Game(executive: false)
    game.screen = screen
    game.docked = !screen.isFlight
    game.key("k")
    #expect(game.screen == .help && game.helpReturn == screen)
    let clearHelp = Display.render(game)
    game.notify("LAUNCHING FROM LAVE")
    #expect(Display.render(game) == clearHelp)
    let pages = PlayerHelp.pages(for: game)
    #expect(!pages.isEmpty && pages.allSatisfy { !$0.rows.isEmpty && $0.rows.count <= 16 })
    #expect(pages.flatMap(\.rows).allSatisfy { $0.count <= 40 })
    let time = game.time
    game.tick(delta: 0.1)
    #expect(game.time == time)
    for _ in 0..<20 { game.key("right") }
    #expect(game.helpPage == pages.count - 1)
    _ = Display.render(game)
    for _ in 0..<20 { game.key("up") }
    #expect(game.helpPage == 0)
    game.key("0")
    #expect(game.screen == .help)
    game.key("escape")
    #expect(game.screen == screen)
    game.key("k")
    game.key("k")
    #expect(game.screen == screen)
    game.key("k")
    game.key("return")
    #expect(game.screen == screen)
  }
  var paused = Game(executive: false)
  paused.paused = true
  paused.key("k")
  #expect(PlayerHelp.pages(for: paused)[0].title == "PAUSED")
  #expect(!PlayerHelp.pages(for: paused).flatMap(\.rows).contains { $0.contains("@") })
  _ = Display.render(paused)
  paused.key("escape")
  #expect(paused.paused)
}
