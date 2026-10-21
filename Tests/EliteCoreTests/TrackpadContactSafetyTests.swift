import Testing

@testable import EliteCore

struct TrackpadContactSafetyTests {
  @Test(arguments: [false, true])
  func rejectedSystemGestureStaysSuppressedWhenContactsDropToSteering(spin: Bool) {
    var input = TrackpadInput()
    input.update(positions: [.zero, .zero, .zero, .zero], spinMode: spin)
    input.update(positions: [.init(0.7, 0.7), .init(0.9, 0.9)], spinMode: spin)
    #expect(input.fingerCount == 0 && input.direction == .zero)
    #expect(input.controls.pitch == 0 && input.controls.roll == 0 && input.controls.throttle == 0)
    #expect(input.spinControls.spinContacts == 0)
    input.update(positions: [.init(0.6, 0.6)], spinMode: spin)
    #expect(input.fingerCount == 0 && input.controls.throttle == 0)
    input.update(positions: [], spinMode: spin)
    input.update(positions: [.init(0.5, 0.5), .init(0.5, 0.5)], spinMode: spin)
    input.update(positions: [.init(0.8, 0.8), .init(0.8, 0.8)], spinMode: spin)
    #expect(input.fingerCount == 2 && input.direction.x > 0 && input.direction.y > 0)
  }

  @Test(arguments: [false, true])
  func modeChangeCannotRearmAnInvalidTouchUntilEveryFingerLifts(spin: Bool) {
    var input = TrackpadInput()
    input.update(positions: [.init(.nan, 0.5)], spinMode: spin)
    input.update(positions: [.init(0.8, 0.8)], spinMode: !spin)
    #expect(input.fingerCount == 0 && input.direction == .zero && input.controls.throttle == 0)
    input.update(positions: [], spinMode: !spin)
    input.update(positions: [.init(0.8, 0.8)], spinMode: !spin)
    #expect(input.fingerCount == 1)
  }
}
