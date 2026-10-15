import AppKit
import Foundation
import Testing
@testable import EliteMac
@testable import EliteCore

private func modeCelestials(_ style: ShipDisplayStyle, position: Vector3 = .init(0, 0, 1000)) -> Frame {
  var game = Game(executive: false)
  game.screen = .front
  game.commander.shipDisplayStyle = style
  game.celestials = [
    .init(kind: .planet, position: position, radius: 100),
    .init(kind: .sun, position: position + .init(200, 0, 0), radius: 50),
  ]
  var frame = Frame()
  frame.rasterizeGraphics = false
  Display.celestialScene(game, projection: .legacy, into: &frame)
  return frame
}

@Test func wireCelestialsShareClippedGeometryAndOnlyChangeInk() {
  for position in [Vector3(0, 0, 1000), .init(550, 0, 1000), .init(100, 0, 1)] {
    let white = modeCelestials(.whiteWireframe, position: position)
    let colour = modeCelestials(.colourWireframe, position: position)
    #expect(!white.graphics.isEmpty)
    #expect(white.graphics.count == colour.graphics.count)
    for (a, b) in zip(white.graphics, colour.graphics) {
      guard case .wire(let left) = a, case .wire(let right) = b else {
        Issue.record("Wire celestial emitted a filled or textured command")
        continue
      }
      #expect(left.ink == .white)
      #expect(right.ink == .blue || right.ink == .gold)
      #expect(left.x0 == right.x0 && left.y0 == right.y0)
      #expect(left.x1 == right.x1 && left.y1 == right.y1)
      for (x, y) in [(left.x0, left.y0), (left.x1, left.y1)] {
        #expect(x.isFinite && y.isFinite)
        #expect(x >= white.flightClip.x && x <= white.flightClip.maxX - 1)
        #expect(y >= white.flightClip.y && y <= white.flightClip.maxY - 1)
      }
    }
  }
}

@Test func shadedCelestialsRetainTextureAndCorona() {
  let frame = modeCelestials(.shadedPanels)
  #expect(frame.graphics.contains { if case .planet = $0 { true } else { false } })
  #expect(frame.graphics.contains { if case .point(_, _, 0.15, .orange) = $0 { true } else { false } })
  #expect(!frame.graphics.contains { if case .wire = $0 { true } else { false } })
}

@Test func wireCelestialRasterCannotReachDashboard() {
  var game = Game(executive: false)
  game.screen = .front
  game.commander.shipDisplayStyle = .whiteWireframe
  game.celestials = [.init(kind: .planet, position: .init(0, -100, 1000), radius: 500)]
  var frame = Frame()
  Display.celestialScene(game, projection: .legacy, into: &frame)
  let dashboard = frame.pixels[(176 * Frame.width)...]
  #expect(dashboard.allSatisfy { $0 == Ink.black.rawValue })
}

@Test @MainActor func celestialModeRendererEvidence() throws {
  guard let output = ProcessInfo.processInfo.environment["ELITE_CELESTIAL_MODE_EVIDENCE"] else { return }
  let directory = URL(fileURLWithPath: output, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  var game = Game(executive: false)
  game.launch()
  game.screen = .front
  game.speed = 0
  game.bodies = [
    .init(id: 1, hull: .cobra, position: .init(-300, -150, 1000)),
    .init(id: 2, hull: .station, position: .init(0, 250, 1800)),
    .init(id: 3, hull: .asteroid, position: .init(300, -200, 1100)),
  ]
  game.celestials = [
    .init(kind: .planet, position: .init(1600, 0, 6000), radius: 1000),
    .init(kind: .sun, position: .init(-2300, 800, 8000), radius: 800),
  ]
  for style in ShipDisplayStyle.allCases {
    game.commander.shipDisplayStyle = style
    let image = try #require(imageForGame(game, width: 1024, height: 768, scale: 2))
    let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    try data.write(to: directory.appendingPathComponent(style.rawValue + ".png"))
  }
}
