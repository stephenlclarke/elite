import Testing

@testable import EliteCore

@Test func starsMoveContinuouslyWithTheShipAndStayStillAtRest() {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  let stationary = game.starfield
  game.tick(delta: 1.0 / 60)
  #expect(game.starfield == stationary)
  game.speed = 32
  let before = game.starfield.positions
  game.tick(delta: 1.0 / 60)
  let after = game.starfield.positions
  for index in before.indices {
    #expect(after[index].x == before[index].x && after[index].y == before[index].y)
    #expect(abs(after[index].z - before[index].z + 9.6) < 1e-9)
  }
  let moving = game.starfield
  game.key("k")
  game.tick(delta: 0.1)
  #expect(game.starfield == moving)
}

@Test func starMotionIsIndependentOfFrameRateAndMatchesCameraRotation() {
  var whole = Starfield()
  var split = whole
  whole.advance(delta: 0.1, speed: 8, pitch: 0, roll: 0)
  for _ in 0..<6 { split.advance(delta: 1.0 / 60, speed: 8, pitch: 0, roll: 0) }
  #expect(zip(whole.positions, split.positions).allSatisfy { ($0 - $1).length < 1e-8 })
  var turn = Starfield()
  let first = turn.positions[0]
  turn.advance(delta: 0.05, speed: 8, pitch: 1, roll: -1)
  let expected = first.rotated(pitch: 0.05, roll: -0.05) - Vector3(0, 0, 7.2)
  #expect((turn.positions[0] - expected).length < 1e-8)
}

@Test func starfieldRecyclesWithoutGrowingOrLeavingTheViewEmpty() {
  var game = Game(executive: false)
  game.launch()
  for _ in 0..<3000 { game.starfield.advance(delta: 0.1, speed: 32, pitch: 0, roll: 0) }
  #expect(game.starfield.positions.count == 768)
  #expect(game.starfield.positions.allSatisfy { $0.length >= 300 && $0.length <= 9000 })
  for screen in [Screen.front, .rear, .left, .right] {
    game.screen = screen
    let points = Display.render(game, rasterizeGraphics: false).graphics.compactMap { graphic in
      if case .point(let center, let radius, let opacity, _) = graphic {
        return (center, radius, opacity)
      }
      return nil
    }
    #expect(points.count >= 8)
    #expect(points.allSatisfy { $0.0.y >= 13 && $0.0.y <= 174 && $0.1 < 0.4 && $0.2 <= 1 })
    #expect(points.contains { abs($0.0.x - $0.0.x.rounded()) > 0.01 })
  }
}
