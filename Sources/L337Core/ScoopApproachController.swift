import Foundation

/// Actual cargo geometry and model motion supplied by the simulation.
public struct ScoopApproachTarget: Sendable {
  public let identity: ActorIdentity
  public let hull: PreparedHull
  public var pose: ShipPose
  public var velocity: Vector3
  public var angularVelocity: Vector3
  public var surfacePoint: Vector3
  public var surfaceNormal: Vector3

  public init(
    identity: ActorIdentity, hull: PreparedHull, pose: ShipPose, velocity: Vector3,
    angularVelocity: Vector3, surfacePoint: Vector3, surfaceNormal: Vector3
  ) {
    self.identity = identity
    self.hull = hull
    self.pose = pose
    self.velocity = velocity
    self.angularVelocity = angularVelocity
    self.surfacePoint = surfacePoint
    self.surfaceNormal = surfaceNormal
  }

  fileprivate var motionTarget: RelativeWorkTarget {
    .init(
      identity: identity, pose: pose, velocity: velocity, angularVelocity: angularVelocity,
      surfacePoint: surfacePoint, surfaceNormal: surfaceNormal)
  }
}

public struct ScoopApproachInput: Sendable {
  public var ship: ShipPose
  public var velocity: Vector3
  public var angularVelocity: Vector3
  public var target: ScoopApproachTarget?
  public var playerRadius: Double
  public var limits: RelativeWorkLimits
  /// Desired cargo origin in the ship's local frame; runtime owns aperture eligibility.
  public var captureOffsetInShip: Vector3
  public var captureTolerance: Double
  public var delta: Double
  public var manualCancel: Bool

  public init(
    ship: ShipPose, velocity: Vector3, angularVelocity: Vector3,
    target: ScoopApproachTarget?, playerRadius: Double, limits: RelativeWorkLimits,
    captureOffsetInShip: Vector3, captureTolerance: Double, delta: Double,
    manualCancel: Bool = false
  ) {
    self.ship = ship
    self.velocity = velocity
    self.angularVelocity = angularVelocity
    self.target = target
    self.playerRadius = playerRadius
    self.limits = limits
    self.captureOffsetInShip = captureOffsetInShip
    self.captureTolerance = captureTolerance
    self.delta = delta
    self.manualCancel = manualCancel
  }
}

public enum ScoopApproachStatus: Sendable, Equatable {
  case approaching, matching, ready
  case blocked(RelativeWorkBlock)
  case cancelled, targetLost, changedPrimary
}

public struct ScoopApproachOutput: Sendable {
  public let status: ScoopApproachStatus
  public let acceleration: Vector3
  public let velocity: Vector3
  public let pitchRate: Double
  public let yawRate: Double
  public let rollRate: Double
  /// Approved endpoint metrics; blocked output reports the current snapshot instead.
  public let captureError: Double
  public let relativeSpeed: Double
  public let facingError: Double
  public let validatedSweep: RelativeWorkSweep?
  public var motionValidated: Bool { validatedSweep != nil }
  /// Informational alignment only; never authorizes collection or changes custody.
  public var captureReady: Bool { status == .ready && validatedSweep?.purpose == .scoop }
}

/// Bounded cargo approach, independent of the large-target work stand-off and work tools.
public struct ScoopApproachController: Sendable {
  public static let maximumRelativeSpeed = 15.0
  public let parent: ActorIdentity
  public private(set) var status: ScoopApproachStatus = .approaching

  public init(parent: ActorIdentity) { self.parent = parent }

  public mutating func step(
    _ input: ScoopApproachInput,
    validate: (RelativeWorkSweep) -> RelativeWorkClearance
  ) -> ScoopApproachOutput {
    if input.manualCancel || status == .cancelled { return inactive(.cancelled, input: input) }
    if status == .targetLost || status == .changedPrimary { return inactive(status, input: input) }
    guard let target = input.target else { return inactive(.targetLost, input: input) }
    guard target.identity == parent else { return inactive(.changedPrimary, input: input) }
    guard Self.valid(input), Self.valid(target) else {
      return inactive(.blocked(.invalidInput), input: input)
    }
    let desired = Self.facing(target)
    let lever = desired.apply(input.captureOffsetInShip) * -1
    let goal = target.pose.position + lever
    let goalVelocity = target.velocity + target.angularVelocity.cross(lever)
    let goalAcceleration = target.angularVelocity.cross(target.angularVelocity.cross(lever))
    let error = goal - input.ship.position
    let rotation = Self.rotationError(from: input.ship.orientation, to: desired)
    let current = Self.metrics(
      input, target: target, ship: input.ship, velocity: input.velocity,
      omega: input.angularVelocity, desired: desired)
    guard [lever, goal, goalVelocity, goalAcceleration, error, rotation].allSatisfy(Self.finite),
      current.finite
    else { return inactive(.blocked(.invalidInput), input: input) }
    if let reason = Self.restriction(
      input, target: target, desired: desired, goalVelocity: goalVelocity,
      goalAcceleration: goalAcceleration, rotation: rotation)
    {
      return blocked(
        reason, input: input, target: target, goal: goal, metrics: current, validate: validate)
    }
    let available = max(0, input.limits.acceleration - goalAcceleration.length)
    let closing = min(
      Self.maximumRelativeSpeed, min(error.length * 1.5, sqrt(2 * available * error.length) * 0.7))
    let rates = Self.clamp(
      Self.localRates(target.angularVelocity + rotation * 2, basis: input.ship.orientation),
      limits: input.limits)
    let omega = input.ship.orientation.apply(.init(rates.x, -rates.y, rates.z))
    let apertureSpin = omega.cross(input.ship.orientation.apply(input.captureOffsetInShip))
    let requested = goalVelocity + error.unit * closing
    // Bound the requested cargo-relative aperture velocity, including ship rotation.
    // Actual overspeed still requires finite acceleration over time, never a velocity snap.
    let relative = (requested + apertureSpin - target.velocity).limited(
      to: Self.maximumRelativeSpeed)
    let desiredVelocity = target.velocity + relative - apertureSpin
    var acceleration = (goalAcceleration + (desiredVelocity - input.velocity) * 3).limited(
      to: input.limits.acceleration)
    var velocity = input.velocity + acceleration * input.delta
    let cappedVelocity = velocity.limited(to: input.limits.speed)
    let cappedAcceleration = (cappedVelocity - input.velocity) * (1 / input.delta)
    if cappedAcceleration.length <= input.limits.acceleration + 1e-9 {
      velocity = cappedVelocity
      acceleration = cappedAcceleration
    }
    guard closing.isFinite,
      [
        rates, omega, apertureSpin, requested, relative, desiredVelocity,
        acceleration, velocity,
      ].allSatisfy(Self.finite)
    else { return inactive(.blocked(.invalidInput), input: input) }
    let sweep = Self.sweep(
      input, target: target, goal: goal, acceleration: acceleration,
      rates: rates, purpose: .scoop)
    let endpoint = Self.metrics(
      input, target: target, ship: sweep.end, velocity: velocity,
      omega: sweep.angularVelocity, desired: Self.facing(target, pose: sweep.targetEnd),
      targetPose: sweep.targetEnd)
    guard Self.valid(sweep.end), Self.valid(sweep.targetEnd), endpoint.finite else {
      return inactive(.blocked(.invalidInput), input: input)
    }
    if case .blocked(let reason) = validate(sweep) {
      return blocked(
        .clearance(reason), input: input, target: target, goal: goal, metrics: current,
        validate: validate)
    }
    let ready =
      endpoint.error <= input.captureTolerance
      && endpoint.speed <= Self.maximumRelativeSpeed && endpoint.angle <= 0.025
      && (input.angularVelocity - target.angularVelocity).length <= 0.02
      && (omega - target.angularVelocity).length <= 0.02
    status = ready ? .ready : (endpoint.error <= 20 ? .matching : .approaching)
    return Self.output(
      status, acceleration: acceleration, velocity: velocity, rates: rates,
      metrics: endpoint, sweep: sweep)
  }

  private struct Metrics {
    let error: Double
    let speed: Double
    let angle: Double
    var finite: Bool { error.isFinite && speed.isFinite && angle.isFinite }
    static let empty = Self(error: 0, speed: 0, angle: 0)
  }

  private static func metrics(
    _ input: ScoopApproachInput, target: ScoopApproachTarget, ship: ShipPose,
    velocity: Vector3, omega: Vector3, desired: Basis3, targetPose: ShipPose? = nil
  ) -> Metrics {
    let aperture = ship.systemPoint(input.captureOffsetInShip)
    let apertureVelocity = velocity + omega.cross(ship.orientation.apply(input.captureOffsetInShip))
    return .init(
      error: ((targetPose ?? target.pose).position - aperture).length,
      speed: (target.velocity - apertureVelocity).length,
      angle: rotationError(from: ship.orientation, to: desired).length)
  }

  private static func restriction(
    _ input: ScoopApproachInput, target: ScoopApproachTarget, desired: Basis3,
    goalVelocity: Vector3, goalAcceleration: Vector3, rotation: Vector3
  ) -> RelativeWorkBlock? {
    if goalVelocity.length > input.limits.speed + 1e-9 { return .speedLimit }
    if goalAcceleration.length > input.limits.acceleration + 1e-9 { return .accelerationLimit }
    let turn = localRates(target.angularVelocity, basis: desired)
    if abs(turn.x) > input.limits.pitchRate + 1e-9
      || abs(turn.y) > input.limits.yawRate + 1e-9
      || abs(turn.z) > input.limits.rollRate + 1e-9
      || (rotation.length > 0.025
        && input.limits.pitchRate + input.limits.yawRate + input.limits.rollRate == 0)
    {
      return .turnLimit
    }
    return nil
  }

  private mutating func inactive(_ next: ScoopApproachStatus, input: ScoopApproachInput)
    -> ScoopApproachOutput
  {
    status = next
    return Self.output(
      next, acceleration: .init(0, 0, 0),
      velocity: Self.finite(input.velocity) ? input.velocity : .init(0, 0, 0),
      rates: .init(0, 0, 0), metrics: .empty, sweep: nil)
  }

  private mutating func blocked(
    _ reason: RelativeWorkBlock, input: ScoopApproachInput, target: ScoopApproachTarget,
    goal: Vector3, metrics: Metrics, validate: (RelativeWorkSweep) -> RelativeWorkClearance
  ) -> ScoopApproachOutput {
    let acceleration =
      input.velocity.unit * -min(input.limits.acceleration, input.velocity.length / input.delta)
    let sweep = Self.sweep(
      input, target: target, goal: goal, acceleration: acceleration,
      rates: .init(0, 0, 0), purpose: .braking)
    guard Self.valid(sweep.end), Self.valid(sweep.targetEnd) else {
      return inactive(.blocked(.invalidInput), input: input)
    }
    let approved = validate(sweep) == .clear
    let safeAcceleration = approved ? acceleration : .init(0, 0, 0)
    status = .blocked(reason)
    return Self.output(
      status, acceleration: safeAcceleration,
      velocity: input.velocity + safeAcceleration * input.delta, rates: .init(0, 0, 0),
      metrics: metrics, sweep: approved ? sweep : nil)
  }

  private static func output(
    _ status: ScoopApproachStatus, acceleration: Vector3, velocity: Vector3, rates: Vector3,
    metrics: Metrics, sweep: RelativeWorkSweep?
  ) -> ScoopApproachOutput {
    .init(
      status: status, acceleration: acceleration, velocity: velocity,
      pitchRate: rates.x, yawRate: rates.y, rollRate: rates.z,
      captureError: metrics.error, relativeSpeed: metrics.speed, facingError: metrics.angle,
      validatedSweep: sweep)
  }

  private static func sweep(
    _ input: ScoopApproachInput, target: ScoopApproachTarget, goal: Vector3,
    acceleration: Vector3, rates: Vector3, purpose: RelativeWorkSweep.Purpose
  ) -> RelativeWorkSweep {
    let omega = input.ship.orientation.apply(.init(rates.x, -rates.y, rates.z))
    var end = input.ship
    end.position =
      input.ship.position + input.velocity * input.delta + acceleration
      * (0.5 * input.delta * input.delta)
    end.orientation = RelativeWorkController.rotated(
      input.ship.orientation, omega: omega, delta: input.delta)
    var targetEnd = target.pose
    targetEnd.position = target.pose.position + target.velocity * input.delta
    targetEnd.orientation = RelativeWorkController.rotated(
      target.pose.orientation, omega: target.angularVelocity, delta: input.delta)
    return .init(
      purpose: purpose, start: input.ship, end: end,
      initialVelocity: input.velocity, acceleration: acceleration, angularVelocity: omega,
      target: target.motionTarget, targetEnd: targetEnd,
      surfacePosition: target.pose.systemPoint(target.surfacePoint), workPosition: goal,
      playerRadius: input.playerRadius, requiredClearance: 0, duration: input.delta)
  }

  private static func facing(_ target: ScoopApproachTarget, pose: ShipPose? = nil) -> Basis3 {
    let basis = (pose ?? target.pose).orientation
    var result = Basis3()
    result.z = basis.apply(target.surfaceNormal.unit) * -1
    var up = basis.y - result.z * basis.y.dot(result.z)
    if up.length < 1e-6 { up = basis.x - result.z * basis.x.dot(result.z) }
    result.y = up.unit
    result.x = result.y.cross(result.z).unit
    return result
  }

  private static func rotationError(from current: Basis3, to desired: Basis3) -> Vector3 {
    let cross = current.z.cross(desired.z)
    let angle = atan2(cross.length, current.z.dot(desired.z))
    let axis = cross.length > 1e-9 ? cross.unit : current.y
    let up =
      current.y * cos(angle) + axis.cross(current.y) * sin(angle)
      + axis * (axis.dot(current.y) * (1 - cos(angle)))
    let roll = atan2(desired.z.dot(up.cross(desired.y)), up.dot(desired.y))
    return axis * angle + desired.z * roll
  }

  private static func localRates(_ omega: Vector3, basis: Basis3) -> Vector3 {
    .init(omega.dot(basis.x), -omega.dot(basis.y), omega.dot(basis.z))
  }

  private static func clamp(_ rates: Vector3, limits: RelativeWorkLimits) -> Vector3 {
    .init(
      max(-limits.pitchRate, min(limits.pitchRate, rates.x)),
      max(-limits.yawRate, min(limits.yawRate, rates.y)),
      max(-limits.rollRate, min(limits.rollRate, rates.z)))
  }

  private static func finite(_ vector: Vector3) -> Bool {
    vector.finite && vector.length.isFinite
  }

  private static func valid(_ pose: ShipPose) -> Bool {
    let basis = pose.orientation
    return finite(pose.position) && [basis.x, basis.y, basis.z].allSatisfy(finite)
      && abs(basis.x.length - 1) < 1e-5 && abs(basis.y.length - 1) < 1e-5
      && abs(basis.z.length - 1) < 1e-5 && abs(basis.x.dot(basis.y)) < 1e-5
      && (basis.x.cross(basis.y) - basis.z).length < 1e-5
  }

  private static func valid(_ target: ScoopApproachTarget) -> Bool {
    valid(target.pose) && finite(target.velocity) && finite(target.angularVelocity)
      && finite(target.surfacePoint) && finite(target.surfaceNormal)
      && target.surfaceNormal.length > 1e-6
  }

  private static func valid(_ input: ScoopApproachInput) -> Bool {
    let limits = input.limits
    return valid(input.ship) && finite(input.velocity) && finite(input.angularVelocity)
      && finite(input.captureOffsetInShip) && input.captureTolerance.isFinite
      && input.captureTolerance > 0
      && input.playerRadius.isFinite && input.playerRadius >= 0
      && input.delta.isFinite && input.delta > 0 && input.delta <= 0.1
      && limits.acceleration.isFinite && limits.acceleration > 0
      && limits.speed.isFinite && limits.speed > 0
      && [limits.pitchRate, limits.yawRate, limits.rollRate].allSatisfy { $0.isFinite && $0 >= 0 }
  }
}
