import Testing

@testable import EliteCore

@Test func heldTrackpadDirectionUsesAbsolutePositionAndNeutralCenter() {
  var input = TrackpadInput()
  input.update(positions: [.init(0.5, 1)])
  #expect(input.fingerCount == 1 && input.direction == SIMD2(0, 1))
  input.update(positions: [.init(0.5, 0)])
  #expect(input.direction == SIMD2(0, -1))
  input.update(positions: [.init(0, 0.5)])
  #expect(input.direction == SIMD2(-1, 0))
  input.update(positions: [.init(1, 0.5)])
  #expect(input.direction == SIMD2(1, 0))
  input.update(positions: [.init(0.6, 0.4)])
  #expect(input.direction == .zero)
  input.update(positions: [.init(0.81, 0.81)])
  #expect(abs(input.direction.x - 0.5) < 1e-9 && input.direction.x == input.direction.y)
  input.update(positions: [])
  #expect(input == TrackpadInput())
}

@Test func trackpadFingerCountSelectsBrakingSteeringAndAcceleration() {
  var input = TrackpadInput()
  input.update(positions: [.init(0.4, 0.9), .init(0.6, 0.9)])
  #expect(input.fingerCount == 2 && input.direction.x == 0 && input.direction.y > 0.7)
  #expect(input.controls.pitch > 0.7 && input.controls.throttle == 0)
  input.update(positions: [.init(0.6, 0.9)])
  #expect(input.controls.throttle == -1 && input.controls.pitch == 0 && input.controls.roll == 0)
  input.update(positions: [.init(0.4, 0.9), .init(0.6, 0.9), .init(0.5, 0.9)])
  #expect(input.controls.throttle == 1 && input.controls.pitch == 0 && input.controls.roll == 0)
  input.update(positions: [.init(0.4, 0.5), .init(0.6, 0.5)])
  #expect(input.controls.throttle == 0 && input.controls.pitch == 0 && input.controls.roll == 0)
  input.update(positions: [])
  #expect(input == TrackpadInput() && input.controls.throttle == 0)
}

@Test func trackpadRejectsSystemGesturesAndInvalidContactsUntilLift() {
  var input = TrackpadInput()
  input.update(positions: [.init(1, 1)])
  #expect(input.fingerCount == 1 && input.direction == SIMD2(1, 1))
  input.update(positions: [.zero, .zero, .zero, .zero])
  #expect(input.fingerCount == 0 && input.direction == .zero)
  input.update(positions: [.init(0.5, 0.5), .init(0.5, 0.5), .init(0.5, 0.5)])
  #expect(input.controls.throttle == 0)
  input.update(positions: [])
  input.update(positions: [.init(1, 1)])
  #expect(input.fingerCount == 1)
  input.reset()
  input.update(positions: [.init(.nan, 0.5)])
  #expect(input.fingerCount == 0)
  input.reset()
  input.update(positions: [.init(0.5, .infinity)])
  #expect(input.fingerCount == 0)
  input.reset()
  input.update(positions: [.init(-0.1, 0.5)])
  #expect(input.fingerCount == 0)
}

@Test func trackpadFlightHelpFitsEveryPageWhileUsingOtherScreensInSpace() {
  for screen in [Screen.front, .chart, .shortChart, .system, .market, .status, .inventory] {
    var game = Game(executive: false)
    game.launch()
    game.screen = screen
    game.key("k")
    let pages = PlayerHelp.pages(for: game)
    #expect(pages.allSatisfy { $0.rows.count <= 16 && $0.rows.allSatisfy { $0.count <= 40 } })
    #expect(pages.flatMap(\.rows).contains("TRACKPAD: 2 FINGERS - STEER / CRUISE"))
    #expect(pages.flatMap(\.rows).contains("LIFT ALL - CENTRE YOKE / KEEP SPEED"))
    for _ in pages {
      #expect(Display.render(game).pixels.contains(Ink.yellow.rawValue))
      game.key("right")
    }
  }
}

@Test func trackpadHoldsTurnOrThrustEveryFrameAndReleaseStabilizesAtCruisingSpeed() async throws {
  var game = Game(executive: false)
  // The fixed speed, braking and turn-rate witnesses use the native stock Cobra.
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  let validHull = game.commander.valid
  try #require(validHull)
  game.launch()
  game.bodies = [SpaceBody(id: 99, hull: .cargo, position: .init(0, 100, 5000))]
  let runtime = GameRuntime(game: game)
  var input = TrackpadInput()
  input.update(positions: [.init(0.5, 0.5), .init(0.5, 0.5), .init(0.5, 0.5)])
  await runtime.setControls(input.controls)
  for _ in 0..<100 { _ = await runtime.advance(delta: 0.1) }
  #expect(await runtime.snapshot().speed == 32)
  input.update(positions: [.init(0.5, 0.75)])
  await runtime.setControls(input.controls)
  for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
  let slowing = await runtime.snapshot()
  #expect(abs(slowing.speed - 20) < 1e-8 && slowing.pitch == 0 && slowing.roll == 0)
  input.update(positions: [.init(0.7, 0.7), .init(0.9, 0.9)])
  await runtime.setControls(input.controls)
  let before = await runtime.snapshot()
  for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
  let turning = await runtime.snapshot()
  #expect(turning.speed == before.speed && turning.pitch > 0.4 && turning.roll < -0.4)
  #expect(turning.bodies[0].position.x != before.bodies[0].position.x)
  input.update(positions: [])
  await runtime.setControls(input.controls)
  for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
  let released = await runtime.snapshot()
  #expect(released.pitch == 0 && released.roll == 0 && released.speed == turning.speed)
  #expect(released.bodies[0].position.x == turning.bodies[0].position.x)
  #expect(released.bodies[0].position.y == turning.bodies[0].position.y)
  #expect(released.bodies[0].position.z < turning.bodies[0].position.z)
  input.update(positions: [.init(0.5, 0.5)])
  await runtime.setControls(input.controls)
  for _ in 0..<100 { _ = await runtime.advance(delta: 0.1) }
  #expect(await runtime.snapshot().speed == 0)
}
