import Testing

@testable import L337Core

struct ReadmeOriginalDesignPresentationTests {
  @Test(arguments: ["SH002", "SH035"])
  func presentationUsesTheAuthenticatedOriginalMeshAndCanonicalName(id: String) throws {
    let game = Game(executive: false)
    let name = id == "SH002" ? "Gyrfalcon Assault" : "Stag Liner"
    let frame = try Display.originalDesignPresentation(
      game, shipID: id, time: 0, width: 1024, height: 768)
    #expect(
      frame.labels.map(\.text) == [
        "ORIGINAL SHIP DESIGN", id + " - " + name, "DESIGN PRESENTATION",
      ])
    #expect(
      (frame.graphics + frame.worldGraphics).contains {
        switch $0 {
        case .textured: true
        default: false
        }
      })
    let model = try OriginalFleetShowroomModels.model(for: id)
    var expected = Frame()
    expected.responsive = true
    expected.rasterizeGraphics = false
    expected.canvas = frame.canvas
    expected.flightClip = frame.flightClip
    var body = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 400))
    body.orientation.rotate(pitch: 0.35, roll: 0, yaw: 0)
    let projection = FlightProjection(center: .init(512, 768 * 0.47), focal: 768 * 1.15)
    Display.draw(
      body, game: game, into: &expected, projection: projection,
      mesh: model.displayMesh.showroomNormalised, screen: .title)
    #expect(frame.graphics == expected.graphics)
    #expect(frame.worldGraphics == expected.worldGraphics)
    var legacy = expected
    legacy.graphics = []
    legacy.worldGraphics = []
    Display.draw(
      body, game: game, into: &legacy, projection: projection,
      mesh: Mesh.hull(.cobra), screen: .title)
    #expect(frame.graphics != legacy.graphics || frame.worldGraphics != legacy.worldGraphics)
    let rotated = try Display.originalDesignPresentation(
      game, shipID: id, time: 2.5, width: 1024, height: 768)
    #expect(frame.graphics != rotated.graphics || frame.worldGraphics != rotated.worldGraphics)
  }

  @Test(arguments: ["", "SH999"])
  func unavailableDesignRefusesInsteadOfSubstitutingALegacyHull(id: String) {
    #expect(throws: OriginalFleetShowroomModels.Failure.unknownID) {
      try Display.originalDesignPresentation(
        Game(executive: false), shipID: id, time: 0, width: 1024, height: 768)
    }
  }

  @Test func presentationIsRepeatableAndLeavesCommanderDiscoveryAndWorldUntouched() throws {
    var game = Game(executive: false)
    game.screen = .showroom
    game.time = 42
    let commander = game.commander
    let bodies = game.bodies
    let before = Display.presentation(game, width: 1024, height: 768)
    let first = try Display.originalDesignPresentation(
      game, shipID: "SH002", time: 1.25, width: 1024, height: 768)
    let second = try Display.originalDesignPresentation(
      game, shipID: "SH002", time: 1.25, width: 1024, height: 768)
    #expect(first == second)
    #expect(game.commander == commander)
    #expect(game.bodies == bodies)
    #expect(game.screen == .showroom && game.time == 42)
    #expect(Display.presentation(game, width: 1024, height: 768) == before)
  }
}
