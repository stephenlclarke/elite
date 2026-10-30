import Foundation

/// Approved T03 measurements only. These geometric predicates cannot issue lesson progress.
/// Native callers must also establish actual manual control, source contact, region clearance
/// and contiguous native motion before retaining a timed observation.
enum NativeDefensiveFlightGeometry {
  static let stateID = "l337.training/defensive-flight"
  static let acquisitionSeconds = 2.0
  static let gateSeconds = 0.5
  static let withdrawalSeconds = 3.0
  static let gateRadius = 40.0
  static let gateSpeed = 5.0...30.0
  static let lateralSpeed = 3.0
  static let withdrawalDistance = 1100.0
  static let separatingSpeed = 5.0

  enum Gate: Int, Codable, Sendable, CaseIterable {
    case positive, negative
    var offset: Vector3 {
      .init(self == .positive ? 180 : -180, 0, -450)
    }
    var direction: Double { self == .positive ? 1 : -1 }
  }

  struct Reading: Codable, Sendable, Equatable {
    let operation: UUID
    let player: ActorIdentity
    let centreActor: ActorIdentity
    let time: Double
    let position: Vector3
    let velocity: Vector3
    let forward: Vector3
    var speed: Double { velocity.length }
  }

  /// Coordinates are measured in the original provider frame, relative to its centre beacon.
  /// No camera position, caller-selected beacon, narrative flag or replacement actor is used.
  static func reading(
    practice: NativePracticeState, player: ActorIdentity, pose: ShipPose,
    worldVelocity: Vector3, time: Double
  ) -> Reading? {
    guard practice.valid, practice.endedAt == nil,
      practice.permission.lesson == .defensiveFlight,
      player == practice.permission.player,
      let centre = practice.beacons.first(where: { $0.ordinal == 1 }),
      pose.position.finite, NativePracticeSource.properRotation(pose.orientation),
      worldVelocity.finite, worldVelocity.length.isFinite,
      time.isFinite, time >= practice.permission.begunAt, time <= 1e12
    else { return nil }
    let frame = practice.permission.frame
    let position = frame.shipVector(pose.position - practice.permission.position(1))
    let velocity = frame.shipVector(worldVelocity)
    let forward = frame.shipVector(pose.orientation.z)
    guard position.finite, position.length.isFinite, velocity.finite, forward.finite else {
      return nil
    }
    return .init(
      operation: practice.permission.operation, player: player, centreActor: centre.actor,
      time: time, position: position, velocity: velocity, forward: forward)
  }

  static func acquisitionAligned(_ reading: Reading) -> Bool {
    let distance = reading.position.length
    guard distance.isFinite, distance > 1e-9 else { return false }
    return abs(reading.position.x) <= 50 && abs(reading.position.y) <= 50
      && (-500 ... -350).contains(reading.position.z) && (350...500).contains(distance)
      && reading.speed <= 5
      && reading.forward.dot(reading.position * (-1 / distance)) >= cos(5 * .pi / 180)
  }

  /// The gate contains the player centre. The measured bounding hull must independently fit
  /// the published course and maintain its full swept clearance from every original beacon.
  static func insideGate(_ gate: Gate, reading: Reading, measuredHullRadius: Double) -> Bool {
    guard measuredHullRadius.isFinite, measuredHullRadius > 0,
      hullFits(radius: measuredHullRadius), gateSpeed.contains(reading.speed)
    else { return false }
    return (reading.position - gate.offset).length <= gateRadius
      && reading.velocity.x * gate.direction >= lateralSpeed
      && reading.forward.dot(reading.velocity * (1 / reading.speed)) >= cos(30 * .pi / 180)
  }

  static func withdrawing(_ reading: Reading, measuredHullRadius: Double) -> Bool {
    let distance = reading.position.length
    guard exitContains(reading.position), reading.position.z <= -withdrawalDistance,
      hullFits(radius: measuredHullRadius), gateSpeed.contains(reading.speed), distance.isFinite,
      distance > NativePracticeSource.volumeRadius + measuredHullRadius + 128
    else {
      return false
    }
    let outward = reading.position * (1 / distance)
    return reading.forward.dot(outward * -1) <= cos(150 * .pi / 180)
      && reading.velocity.dot(outward) >= separatingSpeed
  }

  static func exitContains(_ point: Vector3) -> Bool {
    point.finite && abs(point.x) <= 250 && abs(point.y) <= 150
      && (-1450 ... -450).contains(point.z)
  }

  static func hullFits(radius: Double) -> Bool {
    guard radius.isFinite, radius > 0 else { return false }
    let beacons = NativePracticeSource.offsets.map { $0 - NativePracticeSource.volumeOffset }
    let course = [
      Vector3(0, 0, -450), Gate.positive.offset, Gate.negative.offset,
      Vector3(-180, 0, -1450),
    ]
    for gate in Gate.allCases {
      guard gate.offset.length + gateRadius + radius + 32 <= NativePracticeSource.volumeRadius,
        beacons.allSatisfy({
          ($0 - gate.offset).length > gateRadius + radius + NativePracticeSource.radius + 32
        })
      else { return false }
    }
    return zip(course, course.dropFirst()).allSatisfy { start, end in
      beacons.allSatisfy {
        segmentDistance($0, start: start, end: end) > radius + NativePracticeSource.radius + 32
      }
    }
  }

  static func segmentDistance(_ point: Vector3, start: Vector3, end: Vector3) -> Double {
    let delta = end - start
    let lengthSquared = delta.dot(delta)
    let fraction =
      lengthSquared > 0 ? max(0, min(1, (point - start).dot(delta) / lengthSquared)) : 0
    return (point - (start + delta * fraction)).length
  }

}
