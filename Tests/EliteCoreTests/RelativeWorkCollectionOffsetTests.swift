import Foundation
import Testing

@testable import EliteCore

private let offsetActor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 42)

private func offsetInput(offset: Double? = nil, range: Double = 300) -> RelativeWorkInput {
  let target = RelativeWorkTarget(
    identity: offsetActor, pose: .init(), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), surfacePoint: .init(0, 0, 0),
    surfaceNormal: .init(0, 0, -1))
  var input = RelativeWorkInput(
    ship: .init(position: .init(0, offset ?? 0, -151)), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), target: target, playerRadius: 30,
    limits: .init(acceleration: 40, speed: 120, pitchRate: 0.6, yawRate: 0.6, rollRate: 0.6),
    cutterRange: range, delta: 0.02)
  if let offset { input.collectionOffset = offset }
  return input
}

private func offsetSweepEqual(_ a: RelativeWorkSweep, _ b: RelativeWorkSweep) {
  #expect(a.purpose == b.purpose && a.start == b.start && a.end == b.end)
  #expect(a.initialVelocity == b.initialVelocity && a.acceleration == b.acceleration)
  #expect(
    a.angularVelocity == b.angularVelocity && a.target == b.target && a.targetEnd == b.targetEnd)
  #expect(a.surfacePosition == b.surfacePosition && a.workPosition == b.workPosition)
  #expect(a.playerRadius == b.playerRadius && a.requiredClearance == b.requiredClearance)
  #expect(a.duration == b.duration)
}

struct RelativeWorkCollectionOffsetTests {
  @Test func defaultAndExplicitZeroPreserveAllOutputAndValidatedSweepFields() throws {
    for scenario in 0..<3 {
      var omitted = offsetInput()
      if scenario == 1 {
        omitted.target?.pose.orientation.x = .init(0, 1, 0)
        omitted.target?.pose.orientation.y = .init(-1, 0, 0)
      }
      var explicit = omitted
      explicit.collectionOffset = 0
      var a = RelativeWorkController(parent: offsetActor, category: .wreck)
      var b = a
      let validator: (RelativeWorkSweep) -> RelativeWorkClearance = {
        scenario == 2 && $0.purpose == .work ? .blocked("Obstruction") : .clear
      }
      let left = a.step(omitted, validate: validator)
      let right = b.step(explicit, validate: validator)
      #expect(left.status == right.status && left.acceleration == right.acceleration)
      #expect(left.velocity == right.velocity && left.pitchRate == right.pitchRate)
      #expect(left.yawRate == right.yawRate && left.rollRate == right.rollRate)
      #expect(
        left.workPosition == right.workPosition && left.surfacePosition == right.surfacePosition)
      #expect(
        left.positionError == right.positionError && left.relativeSpeed == right.relativeSpeed)
      #expect(
        left.facingError == right.facingError && left.requiredClearance == right.requiredClearance)
      #expect(
        left.transitions == right.transitions && left.motionValidated == right.motionValidated)
      offsetSweepEqual(try #require(left.validatedSweep), try #require(right.validatedSweep))
    }
  }

  @Test func offsetUsesTargetUpIndependentOfPlayerOrientationAndRetainsNormalClearance() throws {
    for scenario in 0..<3 {
      var input = offsetInput(offset: 40)
      var desiredUp = Vector3(0, 1, 0)
      var normal = Vector3(0, 0, -1)
      if scenario == 1 {
        input.target?.pose.orientation.x = .init(0, 1, 0)
        input.target?.pose.orientation.y = .init(-1, 0, 0)
        desiredUp = .init(-1, 0, 0)
      } else if scenario == 2 {
        input.target?.surfaceNormal = .init(0, 1, 0)
        normal = .init(0, 1, 0)
        desiredUp = .init(1, 0, 0)
      }
      input.ship.orientation.rotate(pitch: 0.1, roll: 0.2, yaw: 0.3)
      var controller = RelativeWorkController(parent: offsetActor, category: .wreck)
      let output = controller.step(input) { _ in .clear }
      let sweep = try #require(output.validatedSweep)
      let standOff = 120 + input.playerRadius + RelativeWorkController.workMargin
      #expect(sweep.workPosition == normal * standOff + desiredUp * 40)
      #expect(sweep.surfacePosition == Vector3(0, 0, 0))
      #expect(sweep.requiredClearance == 120)
      let displacement = sweep.workPosition - sweep.surfacePosition
      #expect(abs(displacement.dot(normal) - standOff) < 1e-12)
      #expect(abs((sweep.surfacePosition - sweep.workPosition).dot(desiredUp) + 40) < 1e-12)
    }
  }

  @Test func rotatingTranslatedTargetUsesFullLeverArmAndAnalyticalApprovedEndpoint() throws {
    var input = offsetInput(offset: 40, range: 160)
    input.target?.pose.position = .init(20, 30, 40)
    input.target?.surfacePoint = .init(1000, 0, 0)
    input.target?.velocity = .init(10, 0, 0)
    input.target?.angularVelocity = .init(0, 0, 0.1)
    let lever = Vector3(1000, 40, -151)
    let omega = Vector3(0, 0, 0.1)
    input.ship.position = Vector3(20, 30, 40) + lever
    input.velocity = Vector3(10, 0, 0) + omega.cross(lever)
    input.angularVelocity = omega
    var controller = RelativeWorkController(parent: offsetActor, category: .wreck)
    var captured: RelativeWorkSweep?
    let output = controller.step(input) {
      captured = $0
      return .clear
    }
    let sweep = try #require(output.validatedSweep)
    offsetSweepEqual(sweep, try #require(captured))
    #expect(sweep.purpose == .work)
    #expect((output.acceleration - omega.cross(omega.cross(lever))).length < 1e-8)
    #expect(
      sweep.end.position == input.ship.position + input.velocity * input.delta
        + output.acceleration * (0.5 * input.delta * input.delta))
    let angle = omega.length * input.delta
    let axis = omega * (1 / omega.length)
    let start = input.ship.orientation.x
    let rotated =
      start * cos(angle) + axis.cross(start) * sin(angle)
      + axis * (axis.dot(start) * (1 - cos(angle)))
    #expect((sweep.end.orientation.x - rotated).length < 1e-12)
  }

  @Test func rangeUsesActualSurfaceHypotenuseWithInclusiveBoundaryAndZeroCompatibility() {
    let distance = Vector3(0, 40, -151).length
    for range in [distance - 0.001, distance, distance + 0.001] {
      let input = offsetInput(offset: 40, range: range)
      var controller = RelativeWorkController(parent: offsetActor, category: .wreck)
      let output = controller.step(input) { _ in .clear }
      #expect((output.status == .blocked(.toolRange)) == (range < distance))
    }
    var zero = RelativeWorkController(parent: offsetActor, category: .wreck)
    let output = zero.step(offsetInput(range: 151)) { _ in .clear }
    #expect(output.status != .blocked(.toolRange) && output.motionValidated)
  }

  @Test func invalidOffsetsNeverValidateAndRejectedWorkOnlyPublishesApprovedBrake() throws {
    for offset in [-1.0, .nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
      var controller = RelativeWorkController(parent: offsetActor, category: .wreck)
      var input = offsetInput()
      input.collectionOffset = offset
      var calls = 0
      let output = controller.step(input) { _ in
        calls += 1
        return .clear
      }
      #expect(output.status == .blocked(.invalidInput) && calls == 0 && !output.motionValidated)
    }
    for allowBrake in [false, true] {
      var controller = RelativeWorkController(parent: offsetActor, category: .wreck)
      let output = controller.step(offsetInput(offset: 40)) {
        allowBrake && $0.purpose == .braking ? .clear : .blocked("Collision")
      }
      #expect(output.status == .blocked(.clearance("Collision")))
      if allowBrake {
        let sweep = try #require(output.validatedSweep)
        #expect(sweep.purpose == .braking)
      } else {
        #expect(!output.motionValidated)
      }
      #expect(!output.transitions.contains(.selectTool(.salvageCutter)))
    }
  }
}
