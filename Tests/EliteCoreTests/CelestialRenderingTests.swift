import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

private func celestialFrame(_ game: Game, projection: FlightProjection = .legacy) -> Frame {
  var frame = Frame()
  frame.rasterizeGraphics = false
  Display.celestialScene(game, projection: projection, into: &frame)
  return frame
}

private func planetPreviews(_ frame: Frame) -> [PlanetPreview] {
  frame.graphics.compactMap { if case .planet(let value) = $0 { value } else { nil } }
}

@Test func celestialDisksUseTheSameCameraCoordinatesInEveryCockpitView() throws {
  let views: [(Screen, Vector3)] = [
    (.front, .init(0, 0, 1000)), (.rear, .init(0, 0, -1000)),
    (.left, .init(-1000, 0, 0)), (.right, .init(1000, 0, 0)),
  ]
  for (screen, position) in views {
    var game = Game(executive: false)
    game.screen = screen
    game.celestials = [.init(kind: .planet, position: position, radius: 100)]
    let preview = try #require(planetPreviews(celestialFrame(game)).first)
    #expect(abs(preview.bounds.x + preview.bounds.width / 2 - 128) < 1e-9)
    #expect(abs(preview.bounds.y + preview.bounds.height / 2 - 96) < 1e-9)
    #expect(
      preview.identity == PlanetIdentity(galaxy: game.commander.galaxy, system: game.currentSystem))
    game.celestials = [.init(kind: .planet, position: position * -1, radius: 100)]
    #expect(celestialFrame(game).graphics.isEmpty)
  }
}

@Test func celestialPerspectiveChangesSizeAndPositionDuringApproach() throws {
  var game = Game(executive: false)
  game.screen = .front
  game.celestials = [.init(kind: .planet, position: .init(100, 50, 2000), radius: 100)]
  let far = try #require(planetPreviews(celestialFrame(game)).first)
  game.celestials[0].position = .init(100, 50, 1000)
  let near = try #require(planetPreviews(celestialFrame(game)).first)
  #expect(abs(near.bounds.width - far.bounds.width * 2) < 1e-9)
  #expect(near.bounds.x + near.bounds.width / 2 > far.bounds.x + far.bounds.width / 2)
  #expect(near.bounds.y + near.bounds.height / 2 < far.bounds.y + far.bounds.height / 2)
}

@Test func celestialLimbRemainsVisibleWithItsCenterOutsideTheViewport() {
  var game = Game(executive: false)
  game.screen = .front
  // Projected center x=270 lies beyond x=256; the radius 25.6 crosses the edge.
  for kind in [CelestialKind.planet, .sun] {
    game.celestials = [.init(kind: kind, position: .init(554.6875, 0, 1000), radius: 100)]
    #expect(!celestialFrame(game).graphics.isEmpty)
    game.celestials[0].position.x = 1000
    #expect(celestialFrame(game).graphics.isEmpty)
  }
}

@Test func celestialRenderingRejectsInvalidCoordinatesAndBoundsNearPlaneInteriors() throws {
  var game = Game(executive: false)
  game.screen = .front
  for position in [Vector3(.nan, 0, 1000), .init(0, .infinity, 1000), .init(0, 0, -.infinity)] {
    game.celestials = [.init(kind: .sun, position: position, radius: 100)]
    #expect(celestialFrame(game).graphics.isEmpty)
  }
  for radius in [0.0, -1, .nan, .infinity] {
    game.celestials = [.init(kind: .planet, position: .init(0, 0, 1000), radius: radius)]
    #expect(celestialFrame(game).graphics.isEmpty)
  }
  for position in [Vector3(0, 0, 0), .init(0, 0, 1), .init(100, 0, 0.001)] {
    game.celestials = [.init(kind: .planet, position: position, radius: 100)]
    for preview in planetPreviews(celestialFrame(game)) {
      #expect(preview.bounds.x.isFinite && preview.bounds.y.isFinite)
      #expect(preview.bounds.width.isFinite && preview.bounds.width <= 2048)
    }
  }
  game.celestials = [.init(kind: .planet, position: .init(0, 0, 0), radius: 100)]
  #expect(planetPreviews(celestialFrame(game)).count == 1)
  game.celestials = [.init(kind: .planet, position: .init(100, 0, 0.001), radius: 100)]
  #expect(planetPreviews(celestialFrame(game)).count == 1)
  let invalid = FlightProjection(center: .init(128, 96), focal: .infinity)
  #expect(celestialFrame(game, projection: invalid).graphics.isEmpty)
}

@Test func celestialSunHasFilledLuminousDisksAndCelestialsDrawFarToNear() throws {
  var game = Game(executive: false)
  game.screen = .front
  game.celestials = [
    .init(kind: .planet, position: .init(0, 0, 1000), radius: 100),
    .init(kind: .sun, position: .init(0, 0, 2000), radius: 100),
  ]
  let graphics = celestialFrame(game).graphics
  let first = try #require(graphics.first)
  guard case .point(_, let radius, let opacity, let ink) = first else {
    Issue.record("Far sun must draw before the nearer planet")
    return
  }
  #expect(radius > 0 && opacity > 0 && ink == .orange)
  #expect(graphics.contains { if case .point(_, _, 1, .gold) = $0 { true } else { false } })
  #expect(graphics.contains { if case .point(_, _, 1, .yellow) = $0 { true } else { false } })
  #expect(planetPreviews(celestialFrame(game)).count == 1)
}

@MainActor @Test func celestialPlanetTextureKeepsSpaceTransparentAndSurfaceOpaque() throws {
  let game = Game(executive: false)
  let preview = PlanetPreview(
    galaxy: game.commander.galaxy, system: game.currentSystem,
    bounds: .init(x: 0, y: 0, width: 64, height: 64), time: 0)
  let image = try #require(PlanetRenderer.image(for: preview, diameter: 64))
  let data = try #require(image.dataProvider?.data)
  let bytes = try #require(CFDataGetBytePtr(data))
  for (x, y) in [(0, 0), (63, 0), (0, 63), (63, 63)] {
    let offset = y * image.bytesPerRow + x * 4
    #expect(bytes[offset + 3] == 0)
    #expect(bytes[offset] == 0 && bytes[offset + 1] == 0 && bytes[offset + 2] == 0)
  }
  #expect(bytes[32 * image.bytesPerRow + 32 * 4 + 3] == 255)
}

@Test func celestialDefaultFlightSceneShowsPlanetAndSunWithinTheCockpitViewport() {
  var game = Game(executive: false)
  game.launch()
  let frame = Display.cockpit(game, width: 768, height: 768)
  #expect(frame.worldGraphics.contains { if case .planet = $0 { true } else { false } })
  #expect(
    frame.worldGraphics.contains { if case .point(_, _, 1, .gold) = $0 { true } else { false } })
}

@Test func celestialAndShipPainterOrderLetsThePlanetOccludeOnlyTheFartherShip() throws {
  var game = Game(executive: false)
  game.screen = .front
  game.commander.shipDisplayStyle = .whiteWireframe
  game.celestials = [.init(kind: .planet, position: .init(0, 0, 1000), radius: 200)]
  let far = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 2000))
  let near = SpaceBody(id: 2, hull: .cobra, position: .init(0, 0, 500))
  game.bodies = [near, far]
  var farFrame = Frame()
  farFrame.rasterizeGraphics = false
  Display.draw(far, game: game, into: &farFrame)
  var nearFrame = Frame()
  nearFrame.rasterizeGraphics = false
  Display.draw(near, game: game, into: &nearFrame)
  #expect(!farFrame.graphics.isEmpty && !nearFrame.graphics.isEmpty)
  var mixed = Frame()
  mixed.rasterizeGraphics = false
  Display.flightObjects(game, projection: .legacy, into: &mixed)
  let planetIndex = try #require(
    mixed.graphics.firstIndex {
      if case .planet = $0 { true } else { false }
    })
  #expect(Array(mixed.graphics[..<planetIndex]) == farFrame.graphics)
  #expect(Array(mixed.graphics[(planetIndex + 1)...]) == nearFrame.graphics)
}

@Test func celestialForwardLimbSurvivesCenterPassingBehindCameraInEveryView() throws {
  for screen in [Screen.front, .rear, .left, .right] {
    func world(_ x: Double, _ z: Double) -> Vector3 {
      switch screen {
      case .rear: .init(-x, 0, -z)
      case .left: .init(-z, 0, x)
      case .right: .init(z, 0, -x)
      default: .init(x, 0, z)
      }
    }
    var game = Game(executive: false)
    game.screen = screen
    var previews: [PlanetPreview] = []
    for depth in [1.0, -1.0] {
      game.celestials = [.init(kind: .planet, position: world(1200, depth), radius: 1100)]
      previews.append(try #require(planetPreviews(celestialFrame(game)).first))
    }
    // Both centers straddle the near plane, but the right-edge view ray still
    // intersects the forward limb. The bounded projection must not pop away.
    #expect(previews[0].bounds == previews[1].bounds)
    game.celestials = [.init(kind: .planet, position: world(0, -1200), radius: 1100)]
    #expect(celestialFrame(game).graphics.isEmpty)
  }
}
