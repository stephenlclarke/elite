import Foundation
import Testing

@testable import EliteCore

private let motionActor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 10, entity: 42)

private func motionInput() -> RelativeWorkInput {
  var target = RelativeWorkTarget(
    identity: motionActor, pose: .init(), velocity: .init(10, 0, 0),
    angularVelocity: .init(0, 0, 0.1), surfacePoint: .init(100, 0, 0),
    surfaceNormal: .init(0, 0, -1))
  target.depleted = false
  return .init(
    ship: .init(position: .init(100, 0, -151)), velocity: .init(10, 10, 0),
    angularVelocity: .init(0, 0, 0.1), target: target, playerRadius: 30,
    limits: .init(acceleration: 40, speed: 120, pitchRate: 0.6, yawRate: 0.6, rollRate: 0.6),
    delta: 0.02)
}

private func assertSameMotion(_ actual: RelativeWorkSweep, _ expected: RelativeWorkSweep) {
  #expect(actual.purpose == expected.purpose)
  #expect(actual.start == expected.start && actual.end == expected.end)
  #expect(actual.initialVelocity == expected.initialVelocity)
  #expect(
    actual.acceleration == expected.acceleration
      && actual.angularVelocity == expected.angularVelocity)
  #expect(actual.target == expected.target && actual.targetEnd == expected.targetEnd)
  #expect(
    actual.surfacePosition == expected.surfacePosition
      && actual.workPosition == expected.workPosition)
  #expect(actual.playerRadius == expected.playerRadius)
  #expect(
    actual.requiredClearance == expected.requiredClearance && actual.duration == expected.duration)
}

private func motionRodrigues(_ vector: Vector3, omega: Vector3, time: Double) -> Vector3 {
  guard omega.length > 0 else { return vector }
  let axis = omega * (1 / omega.length)
  let angle = omega.length * time
  return vector * cos(angle) + axis.cross(vector) * sin(angle)
    + axis * (axis.dot(vector) * (1 - cos(angle)))
}

struct RelativeWorkMotionOutputTests {
  @Test func approvedOutputRetainsExactSweepAndAnalyticalAcceleratingRotatingEndpoint() throws {
    var input = motionInput()
    input.ship.orientation.rotate(pitch: 0.12, roll: 0.08, yaw: 0.15)
    var controller = RelativeWorkController(parent: motionActor, category: .rock)
    var supplied: [RelativeWorkSweep] = []
    let output = controller.step(input) {
      supplied.append($0)
      return .clear
    }
    let approved = try #require(output.validatedSweep)
    #expect(supplied.count == 1 && output.motionValidated)
    assertSameMotion(approved, try #require(supplied.first))
    #expect(approved.purpose == .work)
    #expect((output.acceleration - Vector3(-1, 0, 0)).length < 1e-8)
    #expect((output.velocity - Vector3(9.98, 10, 0)).length < 1e-8)
    #expect(abs(output.pitchRate) > 0 && abs(output.yawRate) > 0 && abs(output.rollRate) > 0)
    #expect(approved.acceleration.length > 0 && approved.angularVelocity.length > 0)
    let position =
      input.ship.position + input.velocity * input.delta
      + output.acceleration * (0.5 * input.delta * input.delta)
    #expect((approved.end.position - position).length < 1e-12)
    let omega = input.ship.orientation.apply(
      .init(output.pitchRate, -output.yawRate, output.rollRate))
    for (start, end) in [
      (input.ship.orientation.x, approved.end.orientation.x),
      (input.ship.orientation.y, approved.end.orientation.y),
      (input.ship.orientation.z, approved.end.orientation.z),
    ] {
      #expect((end - motionRodrigues(start, omega: omega, time: input.delta)).length < 1e-12)
    }
    #expect(output.status == .matching && output.transitions == [.status(.matching)])
  }

  @Test func approvedBrakeReturnsItsOwnSweepRatherThanRejectedWork() throws {
    let input = motionInput()
    var controller = RelativeWorkController(parent: motionActor, category: .rock)
    var supplied: [RelativeWorkSweep] = []
    let output = controller.step(input) { sweep in
      supplied.append(sweep)
      return sweep.purpose == .work ? .blocked("Work path obstructed") : .clear
    }
    #expect(supplied.count == 2)
    #expect(supplied[0].purpose == .work && supplied[1].purpose == .braking)
    let approved = try #require(output.validatedSweep)
    assertSameMotion(approved, supplied[1])
    #expect(output.status == .blocked(.clearance("Work path obstructed")))
    #expect(output.motionValidated && approved.purpose == .braking)
    #expect(approved.end != supplied[0].end)
    #expect(approved.angularVelocity == Vector3(0, 0, 0))
    #expect(output.pitchRate == 0 && output.yawRate == 0 && output.rollRate == 0)
    #expect(output.transitions == [.status(.blocked(.clearance("Work path obstructed")))])
    #expect(output.velocity == input.velocity + approved.acceleration * input.delta)
    #expect(
      approved.end.position == input.ship.position + input.velocity * input.delta
        + approved.acceleration * (0.5 * input.delta * input.delta))
  }

  @Test func rejectedWorkAndBrakeNeverPublishAnApprovedSweep() {
    let input = motionInput()
    var controller = RelativeWorkController(parent: motionActor, category: .rock)
    var supplied: [RelativeWorkSweep] = []
    let output = controller.step(input) {
      supplied.append($0)
      return .blocked("No safe path")
    }
    #expect(supplied.count == 2)
    #expect(!output.motionValidated)
    #expect(output.validatedSweep == nil)
    #expect(output.velocity == input.velocity && output.acceleration == Vector3(0, 0, 0))
    #expect(output.status == .blocked(.clearance("No safe path")))
  }

  @Test func cancelledInvalidAndLostOutputsDoNotCallValidatorOrPublishMotion() {
    for scenario in 0..<3 {
      var input = motionInput()
      if scenario == 0 { input.manualCancel = true }
      if scenario == 1 { input.delta = .nan }
      if scenario == 2 { input.target = nil }
      var controller = RelativeWorkController(parent: motionActor, category: .rock)
      var calls = 0
      let output = controller.step(input) { _ in
        calls += 1
        return .clear
      }
      #expect(calls == 0 && !output.motionValidated)
      #expect(output.validatedSweep == nil)
      #expect(output.velocity == input.velocity && output.acceleration == Vector3(0, 0, 0))
      let expected: RelativeWorkStatus =
        scenario == 0
        ? .cancelled
        : scenario == 1 ? .blocked(.invalidInput) : .targetLost
      #expect(output.status == expected)
      if scenario != 1 {
        let repeated = controller.step(motionInput()) { _ in
          calls += 1
          return .clear
        }
        #expect(repeated.validatedSweep == nil)
        #expect(repeated.transitions.isEmpty && calls == 0)
      }
    }
  }
}
