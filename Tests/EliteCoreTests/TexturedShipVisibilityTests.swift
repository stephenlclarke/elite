import Testing

@testable import EliteCore

struct TexturedShipVisibilityTests {
  @Test(arguments: ["SH169", "SH170"])
  func selectedTexturedHullsUseActualFrontClippingAndBasicAcquisition(id: String) throws {
    var game = Game(executive: false)
    try verifyTexturedHullVisibility(&game, id: id)
  }

  @Test func surfacePresenceRejectsHUDWireOnlyAndClippedTextureFaces() {
    var frame = Frame()
    frame.rasterizeGraphics = false
    frame.flightClip = .init(x: 20, y: 20, width: 20, height: 20)
    frame.point(25, 25)
    frame.graphics.append(.ellipse(center: .init(25, 25), radiusX: 4, radiusY: 4, ink: .white))
    frame.graphics.append(.wire(.init(x0: 22, y0: 22, x1: 30, y1: 30, ink: .white)))
    #expect(!frame.hasShipSurfaces && !frame.shipLines.isEmpty)
    for (points, visible) in [
      ([(22.0, 22.0), (35.0, 22.0), (22.0, 35.0)], true),
      ([(0.0, 0.0), (25.0, 0.0), (0.0, 25.0)], false),
      ([(0.0, 0.0), (10.0, 0.0), (0.0, 10.0)], false),
      ([(20.0, 20.0), (20.0, 30.0), (20.0, 40.0)], false),
    ] {
      frame.graphics = []
      frame.textured(
        .init(
          vertices: points.map {
            .init(point: .init($0.0, $0.1), reciprocalDepth: 1, uOverDepth: 0, vOverDepth: 0)
          }, texture: "sunray-diffuse", brightness: 1,
          clip: .init(x: 0, y: 0, width: 100, height: 100)))
      #expect(frame.hasShipSurfaces == visible)
      frame.worldGraphics = frame.graphics
      frame.graphics = []
      #expect(frame.hasShipSurfaces == visible)
      frame.worldGraphics = []
    }
    frame.graphics = [
      .textured(
        .init(
          vertices: [], texture: "sunray-diffuse", brightness: 1,
          clip: frame.flightClip))
    ]
    #expect(!frame.hasShipSurfaces)
    frame.graphics = []
    frame.panel([.init(22, 22), .init(35, 22), .init(22, 35)], colour: 0xffff_ffff)
    #expect(frame.hasShipSurfaces)
  }
}

private func verifyTexturedHullVisibility(_ game: inout Game, id: String) throws {
  game.launch()
  game.speed = 0
  game.commander.installTargetingComputer(.basic)
  game.viewportWidth = 512
  game.viewportHeight = 518
  let allocated = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocated)
  var body = SpaceBody(id: 42, hull: .cobra, position: .init(0, 0, 1000))
  body.physical = game.nativePhysicalActorState(for: body, identity: actor)
  body.physical?.catalogueShipID = id
  let layout = CockpitLayout(game: game, width: 512, height: 518)
  let edge = (layout.flightClip.maxX - layout.projection.center.x) * 1000 / layout.projection.focal
  for style in ShipDisplayStyle.allCases {
    game.commander.shipDisplayStyle = style
    for (position, visible) in [
      (Vector3(0, 0, 1000), true), (Vector3(edge, 0, 1000), true),
      (Vector3(100_000, 0, 1000), false), (Vector3(0, 0, -1000), false),
    ] {
      body.position = position
      game.bodies = [body]
      game.cancelAutoTarget()
      game.weaponsTargetID = nil
      game.screen = .front
      #expect(Display.visibleInFront(body, game: game, layout: layout) == visible)
      game.key("r")
      #expect(game.autoPilot.targetID == (visible ? body.id : nil))
    }
  }
}
