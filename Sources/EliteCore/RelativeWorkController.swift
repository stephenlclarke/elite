import Foundation

public enum RelativeWorkTool: Sendable, Equatable {
  case miningLaser, salvageCutter
}

public enum RelativeWorkBlock: Sendable, Equatable {
  case invalidInput, unsupportedTarget, identityMismatch, toolRange
  case speedLimit, accelerationLimit, turnLimit
  case clearance(String)
}

public enum RelativeWorkStatus: Sendable, Equatable {
  case idle, approaching, matching, holding
  case blocked(RelativeWorkBlock)
  case cancelled, targetLost, changedPrimary
}

public enum RelativeWorkTransition: Sendable, Equatable {
  case status(RelativeWorkStatus)
  case selectTool(RelativeWorkTool)
  case workComplete
}

/// All linear quantities use native world units; angular rates use radians/second.
public struct RelativeWorkLimits: Sendable, Equatable {
  public var acceleration: Double
  public var speed: Double
  public var pitchRate: Double
  public var yawRate: Double
  public var rollRate: Double

  public init(
    acceleration: Double, speed: Double, pitchRate: Double, yawRate: Double, rollRate: Double
  ) {
    self.acceleration = acceleration
    self.speed = speed
    self.pitchRate = pitchRate
    self.yawRate = yawRate
    self.rollRate = rollRate
  }
}

public struct RelativeWorkTarget: Sendable, Equatable {
  public let identity: ActorIdentity
  public let wreck: WreckIdentity?
  public var pose: ShipPose
  public var velocity: Vector3
  public var angularVelocity: Vector3
  public var surfacePoint: Vector3
  public var surfaceNormal: Vector3
  public var depleted: Bool

  public init(
    identity: ActorIdentity, wreck: WreckIdentity? = nil, pose: ShipPose,
    velocity: Vector3, angularVelocity: Vector3,
    surfacePoint: Vector3, surfaceNormal: Vector3, depleted: Bool = false
  ) {
    self.identity = identity
    self.wreck = wreck
    self.pose = pose
    self.velocity = velocity
    self.angularVelocity = angularVelocity
    self.surfacePoint = surfacePoint
    self.surfaceNormal = surfaceNormal
    self.depleted = depleted
  }
}

public struct RelativeWorkInput: Sendable {
  public var ship: ShipPose
  public var velocity: Vector3
  public var angularVelocity: Vector3
  public var target: RelativeWorkTarget?
  public var playerRadius: Double
  public var limits: RelativeWorkLimits
  public var cutterRange: Double
  public var delta: Double
  public var manualCancel: Bool

  public init(
    ship: ShipPose, velocity: Vector3, angularVelocity: Vector3,
    target: RelativeWorkTarget?, playerRadius: Double, limits: RelativeWorkLimits,
    cutterRange: Double = 300, delta: Double, manualCancel: Bool = false
  ) {
    self.ship = ship
    self.velocity = velocity
    self.angularVelocity = angularVelocity
    self.target = target
    self.playerRadius = playerRadius
    self.limits = limits
    self.cutterRange = cutterRange
    self.delta = delta
    self.manualCancel = manualCancel
  }
}

/// The caller must test actual hulls and rotating swept protrusions, not just centres/radii.
public struct RelativeWorkSweep: Sendable {
  public enum Purpose: Sendable, Equatable { case work, braking }
  public let purpose: Purpose
  public let start: ShipPose
  public let end: ShipPose
  public let initialVelocity: Vector3
  public let acceleration: Vector3
  public let angularVelocity: Vector3
  public let target: RelativeWorkTarget
  public let targetEnd: ShipPose
  public let surfacePosition: Vector3
  public let workPosition: Vector3
  public let playerRadius: Double
  public let requiredClearance: Double
  public let duration: Double
}

public enum RelativeWorkClearance: Sendable, Equatable {
  case clear
  case blocked(String)
}

public struct RelativeWorkOutput: Sendable {
  public let status: RelativeWorkStatus
  public let acceleration: Vector3
  public let velocity: Vector3
  /// Local game control convention: +pitch about X, +yaw about -Y, +roll about Z.
  public let pitchRate: Double
  public let yawRate: Double
  public let rollRate: Double
  public let workPosition: Vector3?
  public let surfacePosition: Vector3?
  public let positionError: Double
  public let relativeSpeed: Double
  public let facingError: Double
  public let requiredClearance: Double
  /// False means no candidate motion has passed the caller's actual-hull validation.
  public let motionValidated: Bool
  public let transitions: [RelativeWorkTransition]
  public var active: Bool {
    ![.cancelled, .targetLost, .changedPrimary].contains(status)
  }
}

/// Produces bounded requests only. The simulation remains the sole owner of pose and thrust.
public struct RelativeWorkController: Sendable {
  /// Positive proof headroom beyond the required hull-to-hull gap.
  public static let workMargin = 1.0
  public let parent: ActorIdentity
  public let wreck: WreckIdentity?
  public let category: SalvageTargetCategory
  public private(set) var status: RelativeWorkStatus = .idle
  private var stableDuration = 0.0
  private var toolSelected = false
  private var completionAnnounced = false

  public init(
    parent: ActorIdentity, wreck: WreckIdentity? = nil, category: SalvageTargetCategory
  ) {
    self.parent = parent
    self.wreck = wreck
    self.category = category
  }

  public mutating func step(
    _ input: RelativeWorkInput,
    validate: (RelativeWorkSweep) -> RelativeWorkClearance
  ) -> RelativeWorkOutput {
    if input.manualCancel || status == .cancelled {
      return inactive(.cancelled, input: input)
    }
    if status == .targetLost || status == .changedPrimary {
      return inactive(status, input: input)
    }
    guard let target = input.target else { return inactive(.targetLost, input: input) }
    guard target.identity == parent else { return inactive(.changedPrimary, input: input) }
    guard Self.valid(input), Self.valid(target) else {
      return inactive(.blocked(.invalidInput), input: input)
    }
    let clearance = max(120, 2 * input.playerRadius)
    let normal = target.pose.orientation.apply(target.surfaceNormal.unit)
    let surface = target.pose.systemPoint(target.surfacePoint)
    let offset =
      target.pose.orientation.apply(target.surfacePoint) + normal
      * (clearance + input.playerRadius + Self.workMargin)
    let work = target.pose.position + offset
    let workVelocity = target.velocity + target.angularVelocity.cross(offset)
    let workAcceleration = target.angularVelocity.cross(target.angularVelocity.cross(offset))
    let error = work - input.ship.position
    let relativeVelocity = input.velocity - workVelocity
    let desired = Self.facing(normal: normal, target: target.pose.orientation)
    let rotationError = Self.rotationError(from: input.ship.orientation, to: desired)
    guard clearance.isFinite,
      [
        normal, surface, offset, work, workVelocity, workAcceleration, error, relativeVelocity,
        rotationError,
      ]
      .allSatisfy(Self.finite)
    else { return inactive(.blocked(.invalidInput), input: input) }
    let metrics = Metrics(
      target: target, work: work, surface: surface, error: error.length,
      speed: relativeVelocity.length,
      angle: rotationError.length, clearance: clearance)

    if let reason = restriction(
      input, target: target, metrics: metrics, workVelocity: workVelocity,
      workAcceleration: workAcceleration, error: error, desired: desired)
    {
      return blocked(reason, input: input, metrics: metrics, validate: validate)
    }
    let availableAcceleration = input.limits.acceleration - workAcceleration.length

    let closingSpeed = min(error.length * 1.5, sqrt(2 * availableAcceleration * error.length) * 0.7)
    let desiredVelocity = (workVelocity + error.unit * closingSpeed).limited(to: input.limits.speed)
    var acceleration =
      (workAcceleration + (desiredVelocity - input.velocity) * 3).limited(
        to: input.limits.acceleration)
    var velocity = input.velocity + acceleration * input.delta
    // A speed projection is legal only when it respects this step's acceleration budget.
    // In particular, externally induced overspeed must brake over time, not snap to the cap.
    let cappedVelocity = velocity.limited(to: input.limits.speed)
    let cappedAcceleration = (cappedVelocity - input.velocity) * (1 / input.delta)
    if cappedAcceleration.length <= input.limits.acceleration + 1e-9 {
      velocity = cappedVelocity
      acceleration = cappedAcceleration
    }
    let rates = Self.clamp(
      Self.localRates(target.angularVelocity + rotationError * 2, basis: input.ship.orientation),
      limits: input.limits)
    let sweep = Self.sweep(
      input, target: target, metrics: metrics, acceleration: acceleration,
      rates: rates, purpose: .work)
    if case .blocked(let reason) = validate(sweep) {
      return blocked(.clearance(reason), input: input, metrics: metrics, validate: validate)
    }

    let transitions = advancePhase(input, target: target, metrics: metrics)
    return Self.output(
      status: status, metrics: metrics, acceleration: acceleration,
      velocity: velocity,
      rates: rates, validated: true, transitions: transitions)
  }

  private struct Metrics {
    let target: RelativeWorkTarget
    let work: Vector3
    let surface: Vector3
    let error: Double
    let speed: Double
    let angle: Double
    let clearance: Double
  }

  private func restriction(
    _ input: RelativeWorkInput, target: RelativeWorkTarget, metrics: Metrics,
    workVelocity: Vector3, workAcceleration: Vector3, error: Vector3, desired: Basis3
  ) -> RelativeWorkBlock? {
    if wreck != nil && target.wreck != wreck {
      return .identityMismatch
    }
    guard [.rock, .wreck, .section].contains(category) else {
      return .unsupportedTarget
    }
    guard metrics.clearance + input.playerRadius + Self.workMargin <= input.cutterRange else {
      return .toolRange
    }
    guard workVelocity.length <= input.limits.speed + 1e-9 else {
      return .speedLimit
    }
    // A straight target already at the speed ceiling cannot be caught from behind.
    if target.angularVelocity.length < 1e-9,
      workVelocity.length >= input.limits.speed - 1e-9,
      error.dot(workVelocity) > 5 * workVelocity.length
    {
      return .speedLimit
    }
    let availableAcceleration = input.limits.acceleration - workAcceleration.length
    guard availableAcceleration >= 0,
      availableAcceleration > 1e-9 || (metrics.error < 5 && metrics.speed < 1)
    else {
      return .accelerationLimit
    }
    let requiredTurn = Self.localRates(target.angularVelocity, basis: desired)
    guard Self.within(requiredTurn, limits: input.limits),
      metrics.angle <= 0.025
        || input.limits.pitchRate + input.limits.yawRate + input.limits.rollRate > 0
    else {
      return .turnLimit
    }

    return nil
  }

  private mutating func advancePhase(
    _ input: RelativeWorkInput, target: RelativeWorkTarget, metrics: Metrics
  ) -> [RelativeWorkTransition] {
    let angularError = (input.angularVelocity - target.angularVelocity).length
    let stable =
      metrics.error <= 5 && metrics.speed <= 1 && metrics.angle <= 0.025
      && angularError <= 0.02
    stableDuration = stable ? stableDuration + input.delta : 0
    let retainedHold =
      status == .holding && metrics.error <= 10 && metrics.speed <= 2
      && metrics.angle <= 0.05 && angularError <= 0.04
    let next: RelativeWorkStatus
    if stableDuration >= 0.5 || retainedHold {
      next = .holding
    } else if metrics.error <= 20 {
      next = .matching
    } else {
      next = .approaching
    }
    var transitions = change(to: next)
    if next == .holding && !toolSelected {
      toolSelected = true
      transitions.append(.selectTool(category == .rock ? .miningLaser : .salvageCutter))
    }
    if next == .holding && target.depleted && !completionAnnounced {
      completionAnnounced = true
      transitions.append(.workComplete)
    }
    return transitions
  }

  private mutating func change(to next: RelativeWorkStatus) -> [RelativeWorkTransition] {
    guard next != status else { return [] }
    status = next
    return [.status(next)]
  }

  private mutating func inactive(
    _ next: RelativeWorkStatus, input: RelativeWorkInput
  ) -> RelativeWorkOutput {
    stableDuration = 0
    return Self.output(
      status: next, metrics: nil, acceleration: .init(0, 0, 0),
      velocity: Self.finite(input.velocity) ? input.velocity : .init(0, 0, 0),
      rates: .init(0, 0, 0), validated: false, transitions: change(to: next))
  }

  private mutating func blocked(
    _ reason: RelativeWorkBlock, input: RelativeWorkInput, metrics: Metrics,
    validate: (RelativeWorkSweep) -> RelativeWorkClearance
  ) -> RelativeWorkOutput {
    stableDuration = 0
    let acceleration =
      input.velocity.unit * -min(
        input.limits.acceleration, input.velocity.length / input.delta)
    let sweep = Self.sweep(
      input, target: metrics.target, metrics: metrics, acceleration: acceleration,
      rates: .init(0, 0, 0), purpose: .braking)
    let approved = validate(sweep) == .clear
    let safeAcceleration = approved ? acceleration : .init(0, 0, 0)
    let transitions = change(to: .blocked(reason))
    return Self.output(
      status: status, metrics: metrics, acceleration: safeAcceleration,
      velocity: input.velocity + safeAcceleration * input.delta, rates: .init(0, 0, 0),
      validated: approved, transitions: transitions)
  }

  private static func output(
    status: RelativeWorkStatus, metrics: Metrics?,
    acceleration: Vector3, velocity: Vector3, rates: Vector3, validated: Bool,
    transitions: [RelativeWorkTransition]
  ) -> RelativeWorkOutput {
    .init(
      status: status, acceleration: acceleration, velocity: velocity,
      pitchRate: rates.x, yawRate: rates.y, rollRate: rates.z,
      workPosition: metrics?.work, surfacePosition: metrics?.surface,
      positionError: metrics?.error ?? 0, relativeSpeed: metrics?.speed ?? 0,
      facingError: metrics?.angle ?? 0, requiredClearance: metrics?.clearance ?? 0,
      motionValidated: validated, transitions: transitions)
  }

  private static func sweep(
    _ input: RelativeWorkInput, target: RelativeWorkTarget, metrics: Metrics,
    acceleration: Vector3, rates: Vector3, purpose: RelativeWorkSweep.Purpose
  ) -> RelativeWorkSweep {
    let omega = input.ship.orientation.apply(.init(rates.x, -rates.y, rates.z))
    var end = input.ship
    end.position =
      input.ship.position + input.velocity * input.delta
      + acceleration * (0.5 * input.delta * input.delta)
    end.orientation = rotated(input.ship.orientation, omega: omega, delta: input.delta)
    var targetEnd = target.pose
    targetEnd.position = target.pose.position + target.velocity * input.delta
    targetEnd.orientation = rotated(
      target.pose.orientation, omega: target.angularVelocity, delta: input.delta)
    return .init(
      purpose: purpose, start: input.ship, end: end, initialVelocity: input.velocity,
      acceleration: acceleration, angularVelocity: omega, target: target, targetEnd: targetEnd,
      surfacePosition: metrics.surface, workPosition: metrics.work,
      playerRadius: input.playerRadius, requiredClearance: metrics.clearance, duration: input.delta)
  }

  private static func facing(normal: Vector3, target: Basis3) -> Basis3 {
    var result = Basis3()
    result.z = normal * -1
    var up = target.y - result.z * target.y.dot(result.z)
    if up.length < 1e-6 { up = target.x - result.z * target.x.dot(result.z) }
    result.y = up.unit
    result.x = result.y.cross(result.z).unit
    return result
  }

  private static func rotationError(from current: Basis3, to desired: Basis3) -> Vector3 {
    let cross = current.z.cross(desired.z)
    let angle = atan2(cross.length, current.z.dot(desired.z))
    let axis = cross.length > 1e-9 ? cross.unit : current.y
    let alignedUp = rotate(current.y, axis: axis, angle: angle)
    let roll = atan2(desired.z.dot(alignedUp.cross(desired.y)), alignedUp.dot(desired.y))
    return axis * angle + desired.z * roll
  }

  private static func localRates(_ omega: Vector3, basis: Basis3) -> Vector3 {
    .init(omega.dot(basis.x), -omega.dot(basis.y), omega.dot(basis.z))
  }

  private static func within(_ rates: Vector3, limits: RelativeWorkLimits) -> Bool {
    abs(rates.x) <= limits.pitchRate + 1e-9 && abs(rates.y) <= limits.yawRate + 1e-9
      && abs(rates.z) <= limits.rollRate + 1e-9
  }

  private static func clamp(_ rates: Vector3, limits: RelativeWorkLimits) -> Vector3 {
    .init(
      max(-limits.pitchRate, min(limits.pitchRate, rates.x)),
      max(-limits.yawRate, min(limits.yawRate, rates.y)),
      max(-limits.rollRate, min(limits.rollRate, rates.z)))
  }

  private static func rotated(_ basis: Basis3, omega: Vector3, delta: Double) -> Basis3 {
    guard omega.length > 1e-9 else { return basis }
    var result = basis
    result.x = rotate(basis.x, axis: omega.unit, angle: omega.length * delta)
    result.y = rotate(basis.y, axis: omega.unit, angle: omega.length * delta)
    result.z = rotate(basis.z, axis: omega.unit, angle: omega.length * delta)
    return result
  }

  private static func rotate(_ v: Vector3, axis: Vector3, angle: Double) -> Vector3 {
    v * cos(angle) + axis.cross(v) * sin(angle) + axis * (axis.dot(v) * (1 - cos(angle)))
  }

  private static func finite(_ vector: Vector3) -> Bool {
    vector.x.isFinite && vector.y.isFinite && vector.z.isFinite && vector.length.isFinite
  }

  private static func valid(_ pose: ShipPose) -> Bool {
    let basis = pose.orientation
    return finite(pose.position) && [basis.x, basis.y, basis.z].allSatisfy(finite)
      && abs(basis.x.length - 1) < 1e-5 && abs(basis.y.length - 1) < 1e-5
      && abs(basis.z.length - 1) < 1e-5 && abs(basis.x.dot(basis.y)) < 1e-5
      && (basis.x.cross(basis.y) - basis.z).length < 1e-5
  }

  private static func valid(_ target: RelativeWorkTarget) -> Bool {
    valid(target.pose) && finite(target.velocity) && finite(target.angularVelocity)
      && finite(target.surfacePoint) && finite(target.surfaceNormal)
      && target.surfaceNormal.length > 1e-6
  }

  private static func valid(_ input: RelativeWorkInput) -> Bool {
    let limits = input.limits
    return valid(input.ship) && finite(input.velocity) && finite(input.angularVelocity)
      && input.delta.isFinite && input.delta > 0 && input.delta <= 0.1
      && input.playerRadius.isFinite && input.playerRadius >= 0
      && input.cutterRange.isFinite && input.cutterRange > 0
      && limits.acceleration.isFinite && limits.acceleration > 0
      && limits.speed.isFinite && limits.speed > 0
      && [limits.pitchRate, limits.yawRate, limits.rollRate].allSatisfy { $0.isFinite && $0 >= 0 }
  }
}
