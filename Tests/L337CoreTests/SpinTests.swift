import Foundation
import Testing

@testable import L337Core

private func circlePoint(_ angle: Double, radius: Double = 0.3) -> SIMD2<Double> {
  .init(0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius)
}

@Test func deliberateCirclesRecognizeBothPilotDirectionsOnlyInSpinMode() {
  for (sign, expected) in [(-1.0, SpinDirection.clockwise), (1.0, .anticlockwise)] {
    var spin = TrackpadInput()
    var ordinary = TrackpadInput()
    var detections: [SpinDirection] = []
    for index in 0...80 {
      let point = circlePoint(sign * Double(index) * .pi / 20)
      if let direction = spin.update(positions: [point], spinMode: true) {
        detections.append(direction)
      }
      #expect(ordinary.update(positions: [point]) == nil)
      #expect(spin.spinControls.pitch == 0 && spin.spinControls.yaw == 0)
    }
    #expect(detections == [expected])
    spin.update(positions: [], spinMode: true)
    #expect(spin.spinControls.spinRecognition == 0)
  }
}

@Test func circleRecognizerRejectsShortArcsReversalsStationaryTouchesAndJumps() {
  var gesture = SpinGesture()
  for index in 0...20 {
    #expect(gesture.update(circlePoint(Double(index) * .pi / 40)) == nil)
  }
  #expect(gesture.progress > 0 && gesture.progress < 0.4)
  for index in (0...20).reversed() {
    #expect(gesture.update(circlePoint(Double(index) * .pi / 40)) == nil)
  }
  #expect(gesture.progress < 0.4)
  gesture.reset()
  for _ in 0..<100 { #expect(gesture.update(.init(0.8, 0.5)) == nil) }
  #expect(gesture.progress == 0)
  #expect(gesture.update(.init(0.5, 0.5)) == nil)
  #expect(gesture.update(.init(1, 1)) == nil)
  #expect(gesture.update(.init(0.8, 0.5)) == nil)
  #expect(gesture.update(.init(0.2, 0.5)) == nil)
  #expect(gesture.progress == 0)
}

@Test func spinSteeringRebasesEveryContactCountAndDoesNotApplyTheCircleToAim() {
  var input = TrackpadInput()
  for index in 0...15 {
    input.update(positions: [circlePoint(Double(index) * .pi / 40)], spinMode: true)
  }
  #expect(input.spinControls.spinRecognition > 0)
  input.update(positions: [.init(0.1, 0.8), .init(0.3, 0.8)], spinMode: true)
  #expect(input.spinControls.spinRecognition == 0)
  #expect(input.spinControls.pitch == 0 && input.spinControls.yaw == 0)
  input.update(positions: [.init(0.2, 0.7), .init(0.4, 0.7)], spinMode: true)
  #expect(input.spinControls.pitch < 0 && input.spinControls.yaw > 0)
  input.update(positions: [.zero, .zero, .zero], spinMode: true)
  #expect(input.spinControls.pitch == 0 && input.spinControls.yaw == 0)
  input.update(positions: [.init(0.7, 0.1), .init(0.9, 0.1)], spinMode: true)
  #expect(input.spinControls.pitch == 0 && input.spinControls.yaw == 0)
  input.update(positions: [.init(0.4, 0.5), .init(0.6, 0.5)], spinMode: true)
  #expect(input.spinControls.pitch == 1 && input.spinControls.yaw == -1)
  input.update(positions: [])
  #expect(input.spinControls.spinContacts == 0)
}

@Test func spinHoldAcceleratesCapsSlowsToZeroAndKeepsHandsOffRate() {
  var spin = SpinControl()
  spin.begin(.clockwise)
  #expect(spin.commandedRate == 0)
  spin.toggleMode()
  spin.begin(.clockwise)
  var controls = Controls()
  for _ in 0..<20 { spin.advance(delta: 0.1, controls: controls) }
  #expect(spin.actualRate == 12 && spin.commandedRate == 12)
  controls.spinContacts = 3
  spin.advance(delta: 0.05, controls: controls)
  #expect(spin.commandedRate == 12)
  controls.spinContacts = 1
  spin.advance(delta: 0.05, controls: controls)
  #expect(spin.commandedRate == 12)
  controls.spinContacts = 3
  for _ in 0..<200 { spin.advance(delta: 0.1, controls: controls) }
  #expect(spin.actualRate == 60 && spin.commandedRate == 60)
  for contacts in [2, 0] {
    controls.spinContacts = contacts
    for _ in 0..<100 { spin.advance(delta: 0.1, controls: controls) }
    #expect(spin.actualRate == 60)
  }
  controls.spinContacts = 1
  for _ in 0..<200 {
    spin.advance(delta: 0.1, controls: controls)
    #expect(spin.commandedRate >= 0 && spin.actualRate >= 0)
  }
  #expect(spin.actualRate == 0 && spin.hudLines[0] == "SPIN HOLD: STOPPED")
  spin.stop()
  #expect(spin.hudLines.isEmpty)
}

@Test func oppositeCircleAndStopChangeActualRateSmoothlyAndHUDReportsBothRates() {
  var spin = SpinControl()
  spin.toggleMode()
  #expect(spin.hudLines[0] == "SPIN MODE: STOPPED")
  spin.begin(.clockwise)
  #expect(spin.hudLines[0].contains("STOPPED") && spin.hudLines[1].contains("TARGET CW -> 12.0"))
  for _ in 0..<10 { spin.advance(delta: 0.1, controls: Controls()) }
  #expect(spin.hudLines[0].contains("CW -> 12.0 DEG/S"))
  spin.begin(.anticlockwise)
  spin.advance(delta: 0.1, controls: Controls())
  #expect(abs(spin.actualRate - 9.6) < 1e-9 && spin.commandedRate == -12)
  #expect(spin.hudLines[1].contains("TARGET CCW <- 12.0"))
  for _ in 0..<20 { spin.advance(delta: 0.1, controls: Controls()) }
  #expect(spin.actualRate == -12 && spin.hudLines[0].contains("CCW <- 12.0 DEG/S"))
  spin.stop()
  spin.advance(delta: 0.1, controls: Controls())
  #expect(abs(spin.actualRate + 9.6) < 1e-9 && !spin.mode)
  #expect(spin.hudLines[0].contains("SPIN STOPPING"))
  spin.stop(immediate: true)
  #expect(spin.actualRate == 0 && spin.commandedRate == 0 && spin.hudLines.isEmpty)
}

@Test func spinAdjustmentTimingIsFrameRateIndependentAndCircleSuppressesSpeedChanges() {
  var whole = SpinControl()
  whole.toggleMode()
  whole.begin(.clockwise)
  whole.advance(delta: 0.1, controls: Controls())
  var split = whole
  var contacts = Controls()
  contacts.spinContacts = 3
  for _ in 0..<30 { whole.advance(delta: 0.1, controls: contacts) }
  for _ in 0..<180 { split.advance(delta: 1.0 / 60, controls: contacts) }
  #expect(abs(whole.commandedRate - split.commandedRate) < 1e-8)
  #expect(abs(whole.actualRate - split.actualRate) < 1e-8)
  let before = whole.commandedRate
  contacts.spinRecognition = 0.5
  contacts.spinContacts = 1
  for _ in 0..<30 { whole.advance(delta: 0.1, controls: contacts) }
  #expect(whole.commandedRate == before)
  #expect(whole.hudLines[1] == "TRACING CIRCLE: 50%")
  contacts.spinRecognition = 0
  contacts.spinSlower = true
  whole.advance(delta: 0.1, controls: contacts)
  #expect(whole.commandedRate < before)
  contacts.spinFaster = true
  let holding = whole.commandedRate
  whole.advance(delta: 0.1, controls: contacts)
  #expect(whole.commandedRate == holding)
}

@Test func spinRollPreservesForwardHeadingAndUsesPilotClockwisePerspective() {
  for (key, expectedSign) in [("]", 1.0), ("[", -1.0)] {
    var game = Game(executive: false)
    game.launch()
    game.speed = 0
    game.bodies = [
      .init(id: 10, hull: .cargo, position: .init(0, 0, 5000)),
      .init(id: 11, hull: .cargo, position: .init(100, 0, 5000)),
    ]
    game.key("v")
    game.key(key)
    for _ in 0..<10 { game.tick(delta: 0.1) }
    #expect(game.bodies[0].position == .init(0, 0, 5000))
    // CW craft roll makes the world rotate CCW: the right-hand object rises.
    #expect(game.bodies[1].position.y * expectedSign > 0)
    #expect(game.spin.actualRate == expectedSign * 12)
    #expect(abs(game.roll - expectedSign * .pi / 15) < 1e-9)
    #expect(!Display.render(game).pixels.isEmpty)
    var aim = Controls()
    aim.pitch = 0.2
    aim.yaw = 0.2
    game.tick(delta: 0.1, controls: aim)
    #expect(game.bodies[0].position.x < 0 && game.bodies[0].position.y < 0)
  }
}

@Test func spinStartupAndStoppingRotateTheSameAmountAtDifferentFrameRates() {
  func run(delta: Double, count: Int) -> Vector3 {
    var game = Game(executive: false)
    game.launch()
    game.speed = 0
    game.bodies = [.init(id: 10, hull: .cargo, position: .init(100, 0, 5000))]
    game.key("v")
    game.key("]")
    for _ in 0..<count { game.tick(delta: delta) }
    game.key("b")
    for _ in 0..<count { game.tick(delta: delta) }
    return game.bodies[0].position
  }
  #expect((run(delta: 0.1, count: 20) - run(delta: 1.0 / 60, count: 120)).length < 1e-8)
}

@Test func spinCancelsOnFocusPauseHelpDockingAndChartsButExplicitStopIsSmooth() {
  for key in ["spin-cancel", "pause", "k", "4"] {
    var game = Game(executive: false)
    game.launch()
    game.key("v")
    game.key("spin:cw")
    for _ in 0..<10 { game.tick(delta: 0.1) }
    game.key(key)
    #expect(!game.spin.mode && game.spin.actualRate == 0)
  }
  var game = Game(executive: false)
  game.key("v")
  #expect(!game.spin.mode)
  game.launch()
  game.key("v")
  game.key("]")
  for _ in 0..<10 { game.tick(delta: 0.1) }
  game.key("b")
  #expect(game.spin.actualRate == 12 && game.spin.commandedRate == 0)
  for _ in 0..<10 { game.tick(delta: 0.1) }
  #expect(game.spin.actualRate == 0 && game.roll == 0)
  game.key("v")
  game.key("[")
  game.dock()
  #expect(!game.spin.mode)
  game.launch()
  game.key("v")
  game.key("]")
  #expect(game.load(Commander()) && !game.spin.mode)
}
