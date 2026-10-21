import Foundation
import Testing

@testable import EliteCore

private let scoopActor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 42)

private func scoopInput() throws -> ScoopApproachInput {
  let mesh = Mesh.hull(.cargo)
  let hull = try PreparedHull(mesh: mesh)
  let surface = try #require(mesh.vertices.min { $0.z < $1.z })
  let target = ScoopApproachTarget(
    identity: scoopActor, hull: hull, pose: .init(), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), surfacePoint: surface,
    surfaceNormal: .init(0, 0, -1))
  return .init(
    ship: .init(position: .init(0, 45, -55)), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), target: target, playerRadius: 100,
    limits: .init(acceleration: 40, speed: 120, pitchRate: 0.6, yawRate: 0.6, rollRate: 0.6),
    captureOffsetInShip: .init(0, -45, 55), captureTolerance: 2, delta: 0.02)
}

private func scoopRotate(_ vector: Vector3, omega: Vector3, time: Double) -> Vector3 {
  guard omega.length > 0 else { return vector }
  let axis = omega * (1 / omega.length)
  let angle = omega.length * time
  return vector * cos(angle) + axis.cross(vector) * sin(angle)
    + axis * (axis.dot(vector) * (1 - cos(angle)))
}

private func scoopSameSweep(_ a: RelativeWorkSweep, _ b: RelativeWorkSweep) {
  #expect(a.purpose == b.purpose && a.start == b.start && a.end == b.end)
  #expect(a.initialVelocity == b.initialVelocity && a.acceleration == b.acceleration)
  #expect(
    a.angularVelocity == b.angularVelocity && a.target == b.target && a.targetEnd == b.targetEnd)
  #expect(a.surfacePosition == b.surfacePosition && a.workPosition == b.workPosition)
  #expect(a.requiredClearance == b.requiredClearance && a.playerRadius == b.playerRadius)
  #expect(a.duration == b.duration)
}

struct ScoopApproachControllerTests {
  @Test func realCobraAndCargoMeshCanValidateCaptureWhileEnclosingSphereRefuses() throws {
    let input = try scoopInput()
    let target = try #require(input.target)
    let cobra = try PreparedHull(mesh: #require(ShipCatalogue.ship("SH023")).design.rawMesh)
    var exact = ScoopApproachController(parent: scoopActor)
    let accepted = exact.step(input) {
      HullSweepSafety.validate($0, target: target.hull, player: cobra).clearance
    }
    #expect(accepted.captureReady && accepted.validatedSweep?.purpose == .scoop)
    var sphere = ScoopApproachController(parent: scoopActor)
    let refused = sphere.step(input) { HullSweepSafety.validate($0, target: target.hull).clearance }
    #expect(!refused.captureReady && !refused.motionValidated)
    let obstruction = HullSweepObstacle(
      identity: .init(system: scoopActor.system, visit: 1, entity: 99),
      hull: target.hull, pose: input.ship, clearanceOverride: 0)
    var obstructed = ScoopApproachController(parent: scoopActor)
    let blocked = obstructed.step(input) {
      HullSweepSafety.validate($0, target: target.hull, player: cobra, obstacles: [obstruction])
        .clearance
    }
    #expect(!blocked.captureReady && !blocked.motionValidated)
    var overlapping = input
    overlapping.target?.pose.position = input.ship.position
    var contact = ScoopApproachController(parent: scoopActor)
    let intersects = contact.step(overlapping) {
      HullSweepSafety.validate($0, target: target.hull, player: cobra).clearance
    }
    #expect(!intersects.captureReady && !intersects.motionValidated)
  }

  @Test func rotatingMovingTargetUsesNegativeFullLeverAndActualApertureVelocity() throws {
    var input = try scoopInput()
    let omega = Vector3(0.02, 0.03, 0.04)
    let offset = input.captureOffsetInShip
    input.target?.pose.position = .init(100, 200, 300)
    input.target?.velocity = .init(5, 6, 7)
    input.target?.angularVelocity = omega
    input.ship.position = Vector3(100, 200, 300) - offset
    input.velocity = Vector3(5, 6, 7) - omega.cross(offset)
    input.angularVelocity = omega
    var controller = ScoopApproachController(parent: scoopActor)
    let output = controller.step(input) { _ in .clear }
    let initialApertureVelocity = input.velocity + input.angularVelocity.cross(offset)
    #expect((Vector3(5, 6, 7) - initialApertureVelocity).length < 1e-10)
    #expect((output.acceleration + omega.cross(omega.cross(offset))).length < 1e-8)
    let sweep = try #require(output.validatedSweep)
    #expect(sweep.workPosition == input.ship.position && sweep.requiredClearance == 0)
    let endpointError = (sweep.targetEnd.position - sweep.end.systemPoint(offset)).length
    let endpointVelocity =
      output.velocity + sweep.angularVelocity.cross(sweep.end.orientation.apply(offset))
    #expect(abs(output.captureError - endpointError) < 1e-12)
    #expect(abs(output.relativeSpeed - (Vector3(5, 6, 7) - endpointVelocity).length) < 1e-12)
    #expect(output.captureReady)
  }

  @Test func highApertureVelocityCannotProduceFalseReadyEvenWithSmallCentreVelocity() throws {
    var input = try scoopInput()
    input.angularVelocity = .init(0, 1, 0)
    var controller = ScoopApproachController(parent: scoopActor)
    let output = controller.step(input) { _ in .clear }
    let actualRelativeSpeed = input.angularVelocity.cross(
      input.ship.orientation.apply(input.captureOffsetInShip)
    ).length
    #expect(actualRelativeSpeed > 15 && !output.captureReady)
  }

  @Test func accelerationSpeedAndTurnRemainBoundedWithoutExternalOverspeedSnap() throws {
    var input = try scoopInput()
    input.ship.position = .init(100, 100, -500)
    input.velocity = .init(0, 0, 300)
    var controller = ScoopApproachController(parent: scoopActor)
    let output = controller.step(input) { _ in .clear }
    #expect(output.acceleration.length <= input.limits.acceleration + 1e-8)
    #expect(
      (output.velocity - input.velocity).length <= input.limits.acceleration * input.delta + 1e-8)
    #expect(output.velocity.length > input.limits.speed && !output.captureReady)
    #expect(abs(output.pitchRate) <= input.limits.pitchRate)
    #expect(
      abs(output.yawRate) <= input.limits.yawRate && abs(output.rollRate) <= input.limits.rollRate)
    for scenario in 0..<3 {
      var restricted = try scoopInput()
      let reason: RelativeWorkBlock
      if scenario == 0 {
        restricted.target?.velocity = .init(121, 0, 0)
        reason = .speedLimit
      } else if scenario == 1 {
        restricted.target?.angularVelocity = .init(0, 0, 4)
        restricted.limits.speed = 1000
        restricted.limits.rollRate = 10
        reason = .accelerationLimit
      } else {
        restricted.target?.angularVelocity = .init(0, 0, 0.7)
        reason = .turnLimit
      }
      var limited = ScoopApproachController(parent: scoopActor)
      let result = limited.step(restricted) { _ in .clear }
      #expect(result.status == .blocked(reason) && !result.captureReady)
      #expect(result.validatedSweep?.purpose == .braking)
    }
  }

  @Test func approvedSweepIsExactAcceleratingRodriguesEndpoint() throws {
    var input = try scoopInput()
    input.ship.position.x += 5
    input.target?.angularVelocity = .init(0.01, 0.02, 0.03)
    var controller = ScoopApproachController(parent: scoopActor)
    var supplied: RelativeWorkSweep?
    let output = controller.step(input) {
      supplied = $0
      return .clear
    }
    let approved = try #require(output.validatedSweep)
    scoopSameSweep(approved, try #require(supplied))
    #expect(approved.purpose == .scoop && approved.acceleration.length > 0)
    #expect(
      approved.end.position == input.ship.position + input.velocity * input.delta
        + output.acceleration * (0.5 * input.delta * input.delta))
    #expect(
      (approved.end.position - (input.ship.position + output.velocity * input.delta)).length > 1e-8)
    let omega = input.ship.orientation.apply(
      .init(output.pitchRate, -output.yawRate, output.rollRate))
    for (start, end) in [
      (input.ship.orientation.x, approved.end.orientation.x),
      (input.ship.orientation.y, approved.end.orientation.y),
      (input.ship.orientation.z, approved.end.orientation.z),
    ] {
      #expect((end - scoopRotate(start, omega: omega, time: input.delta)).length < 1e-12)
    }
  }

  @Test func rejectedScoopPublishesOnlyApprovedBrakingOrNoAuthority() throws {
    let input = try scoopInput()
    for allowBrake in [false, true] {
      var controller = ScoopApproachController(parent: scoopActor)
      var supplied: [RelativeWorkSweep] = []
      let output = controller.step(input) {
        supplied.append($0)
        return allowBrake && $0.purpose == .braking ? .clear : .blocked("Collision")
      }
      #expect(supplied.first?.purpose == .scoop && !output.captureReady)
      if allowBrake {
        let approved = try #require(output.validatedSweep)
        #expect(approved.purpose == .braking)
        scoopSameSweep(approved, try #require(supplied.last))
      } else {
        #expect(!output.motionValidated)
      }
    }
  }

  @Test func cancellationIdentityLossInvalidInputsAndOutsideToleranceNeverGrantReadiness() throws {
    for scenario in 0..<17 {
      var input = try scoopInput()
      switch scenario {
      case 0: input.manualCancel = true
      case 1: input.target = nil
      case 2:
        let target = try #require(input.target)
        input.target = .init(
          identity: .init(system: scoopActor.system, visit: 2, entity: 42), hull: target.hull,
          pose: target.pose, velocity: target.velocity, angularVelocity: target.angularVelocity,
          surfacePoint: target.surfacePoint, surfaceNormal: target.surfaceNormal)
      case 3: input.delta = 0
      case 4: input.delta = .nan
      case 5: input.captureTolerance = -1
      case 6: input.captureOffsetInShip.x = .infinity
      case 7: input.delta = 0.1001
      case 8: input.captureTolerance = 0
      case 9: input.captureTolerance = .nan
      case 10: input.velocity.y = .nan
      case 11: input.target?.angularVelocity.z = .infinity
      case 12: input.ship.orientation.x = .init(2, 0, 0)
      case 13: input.playerRadius = -1
      case 14: input.captureOffsetInShip.x = .greatestFiniteMagnitude
      case 15: input.target?.surfaceNormal = .init(0, 0, 0)
      default: input.ship.position.x += 10
      }
      var controller = ScoopApproachController(parent: scoopActor)
      var calls = 0
      let output = controller.step(input) { _ in
        calls += 1
        return .clear
      }
      #expect(!output.captureReady)
      if scenario < 16 {
        #expect(calls == 0 && !output.motionValidated)
      } else {
        #expect(output.captureError > input.captureTolerance)
      }
    }
  }
}
