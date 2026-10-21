import Foundation

public enum OrbitFormationDirection: Int, Codable, Sendable {
  case positive = 1
  case negative = -1
}

/// Resolved world geometry, retained unchanged across camera movement and scene rebindings.
public struct OrbitFormationAnchor: Codable, Equatable, Sendable {
  public let identity: UUID
  public let center: Vector3
  public let basis: Basis3
  public let planetRadius: Double
  public let orbitRadius: Double
  public let surfaceClearance: Double

  public init(
    identity: UUID, center: Vector3, basis: Basis3, planetRadius: Double,
    orbitRadius: Double, surfaceClearance: Double
  ) {
    self.identity = identity
    self.center = center
    self.basis = basis
    self.planetRadius = planetRadius
    self.orbitRadius = orbitRadius
    self.surfaceClearance = surfaceClearance
  }
}

public struct OrbitFormationConfiguration: Codable, Equatable, Sendable {
  public let direction: OrbitFormationDirection
  public let angularSpeed: Double
  public let slotSpacing: Double
  public let captureDistance: Double
  public let captureTimeout: Double

  public init(
    direction: OrbitFormationDirection, angularSpeed: Double, slotSpacing: Double,
    captureDistance: Double, captureTimeout: Double
  ) {
    self.direction = direction
    self.angularSpeed = angularSpeed
    self.slotSpacing = slotSpacing
    self.captureDistance = captureDistance
    self.captureTimeout = captureTimeout
  }
}

/// Linear units are world units/second and world units/second squared; turns are radians/second.
public struct OrbitFormationLimits: Equatable, Sendable {
  public let speed: Double
  public let acceleration: Double
  public let turnRate: Double
  public init(speed: Double, acceleration: Double, turnRate: Double) {
    self.speed = speed
    self.acceleration = acceleration
    self.turnRate = turnRate
  }
}

public struct OrbitFormationMember: Equatable, Sendable {
  public let logicalID: UUID
  public let slot: Int
  public let position: Vector3
  public let velocity: Vector3
  public let forward: Vector3
  public let hullRadius: Double
  public let limits: OrbitFormationLimits

  public init(
    logicalID: UUID, slot: Int, position: Vector3, velocity: Vector3,
    forward: Vector3, hullRadius: Double, limits: OrbitFormationLimits
  ) {
    self.logicalID = logicalID
    self.slot = slot
    self.position = position
    self.velocity = velocity
    self.forward = forward
    self.hullRadius = hullRadius
    self.limits = limits
  }
}

public struct OrbitFormationInput: Sendable {
  public let anchor: OrbitFormationAnchor
  public let members: [OrbitFormationMember]
  public let delta: Double
  public init(anchor: OrbitFormationAnchor, members: [OrbitFormationMember], delta: Double) {
    self.anchor = anchor
    self.members = members
    self.delta = delta
  }
}

public struct OrbitFormationSlot: Codable, Equatable, Sendable {
  public let logicalID: UUID
  public let slot: Int
  /// Cumulative capture time within this incarnation. Tracking pauses it; reload never resets it.
  public fileprivate(set) var captureElapsed: Double
}

public struct OrbitFormationState: Codable, Equatable, Sendable {
  public static let maximumSlots = 64
  public let incarnation: UUID
  public let anchor: OrbitFormationAnchor
  public let configuration: OrbitFormationConfiguration
  public fileprivate(set) var phase: Double
  public fileprivate(set) var angularSpeed: Double
  public fileprivate(set) var slots: [OrbitFormationSlot]

  public init(
    incarnation: UUID, anchor: OrbitFormationAnchor,
    configuration: OrbitFormationConfiguration, phase: Double, angularSpeed: Double = 0
  ) throws {
    guard phase.isFinite else { throw OrbitFormationError.invalidInput }
    self.incarnation = incarnation
    self.anchor = anchor
    self.configuration = configuration
    self.phase = OrbitFormationController.wrap(phase)
    self.angularSpeed = angularSpeed
    slots = []
    try OrbitFormationController.validate(self)
  }

  private enum CodingKeys: String, CodingKey {
    case incarnation, anchor, configuration, phase, angularSpeed, slots
  }
  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    var entries = try values.nestedUnkeyedContainer(forKey: .slots)
    guard (entries.count ?? 0) <= Self.maximumSlots else {
      throw DecodingError.dataCorruptedError(
        in: entries,
        debugDescription: "Orbit formation slot limit exceeded.")
    }
    var decoded: [OrbitFormationSlot] = []
    while !entries.isAtEnd {
      guard decoded.count < Self.maximumSlots else {
        throw DecodingError.dataCorruptedError(
          in: entries,
          debugDescription: "Orbit formation slot limit exceeded.")
      }
      decoded.append(try entries.decode(OrbitFormationSlot.self))
    }
    incarnation = try values.decode(UUID.self, forKey: .incarnation)
    anchor = try values.decode(OrbitFormationAnchor.self, forKey: .anchor)
    configuration = try values.decode(OrbitFormationConfiguration.self, forKey: .configuration)
    phase = try values.decode(Double.self, forKey: .phase)
    angularSpeed = try values.decode(Double.self, forKey: .angularSpeed)
    slots = decoded
    try OrbitFormationController.validate(self)
  }
}

public enum OrbitFormationError: Error, Equatable, Sendable {
  case invalidInput, identityConflict, infeasibleOrbit, unrepresentable
}
public enum OrbitFormationBlock: Equatable, Sendable {
  case captureDistance, captureTimeout, unsafeClearance, formationSlowing
}
public enum OrbitFormationTracking: Equatable, Sendable { case capturing, tracking }

public struct OrbitFormationSteering: Equatable, Sendable {
  public let goalPosition: Vector3
  /// Exact derivative of this slot's common circular trajectory at the next controller phase.
  public let goalVelocity: Vector3
  public let desiredVelocity: Vector3
  public let acceleration: Vector3
  public let desiredForward: Vector3
  public let tracking: OrbitFormationTracking
}

/// A blocked member has no motion intent. Even steering is not a collision-approved movement.
public struct OrbitFormationDirective: Equatable, Sendable {
  public let logicalID: UUID
  public let slot: Int
  public let steering: OrbitFormationSteering?
  public let blocked: OrbitFormationBlock?
}
public struct OrbitFormationStep: Equatable, Sendable {
  public let state: OrbitFormationState
  public let directives: [OrbitFormationDirective]
}

public enum OrbitFormationController {
  private static let revolution = 2 * Double.pi
  private static let cruiseHeadroom = 0.75

  public static func step(state: OrbitFormationState, input: OrbitFormationInput) throws
    -> OrbitFormationStep
  {
    try validate(state)
    try validate(input, state: state)
    guard !input.members.isEmpty else { return .init(state: state, directives: []) }
    var next = state
    for member in input.members
    where !next.slots.contains(where: { $0.logicalID == member.logicalID }) {
      next.slots.append(.init(logicalID: member.logicalID, slot: member.slot, captureElapsed: 0))
    }
    next.slots.sort { $0.slot < $1.slot }
    let rate = try commonRate(state: state, members: input.members, delta: input.delta)
    next.angularSpeed = rate
    let advance = (0.5 * state.angularSpeed + 0.5 * rate) * input.delta
    guard advance.isFinite else { throw OrbitFormationError.unrepresentable }
    next.phase = wrap(state.phase + Double(state.configuration.direction.rawValue) * advance)
    var directives: [OrbitFormationDirective] = []
    for member in input.members {
      guard let index = next.slots.firstIndex(where: { $0.logicalID == member.logicalID }) else {
        throw OrbitFormationError.identityConflict
      }
      let result = try steer(
        member, state: state, next: next, delta: input.delta,
        elapsed: next.slots[index].captureElapsed)
      if result.steering?.tracking != .tracking {
        let remaining = state.configuration.captureTimeout - next.slots[index].captureElapsed
        next.slots[index].captureElapsed += min(input.delta, remaining)
      }
      directives.append(result)
    }
    try validate(next)
    return .init(state: next, directives: directives)
  }

  fileprivate static func wrap(_ angle: Double) -> Double {
    let remainder = angle.truncatingRemainder(dividingBy: revolution)
    let value = remainder < 0 ? remainder + revolution : remainder
    return value >= revolution ? 0 : value
  }

  fileprivate static func validate(_ state: OrbitFormationState) throws {
    let a = state.anchor
    let c = state.configuration
    guard a.center.finite, a.basis.validRotation,
      abs(a.basis.x.cross(a.basis.y).dot(a.basis.z) - 1) < 1e-10,
      [a.basis.x, a.basis.y, a.basis.z].allSatisfy({ abs(length($0) - 1) < 1e-10 }),
      abs(a.basis.x.dot(a.basis.y)) < 1e-10, abs(a.basis.x.dot(a.basis.z)) < 1e-10,
      abs(a.basis.y.dot(a.basis.z)) < 1e-10,
      [
        a.planetRadius, a.orbitRadius, c.angularSpeed, c.slotSpacing, c.captureDistance,
        c.captureTimeout,
      ]
      .allSatisfy({ $0.isFinite && $0 > 0 }),
      a.surfaceClearance.isFinite, a.surfaceClearance >= 0,
      (a.planetRadius + a.surfaceClearance).isFinite,
      a.orbitRadius > a.planetRadius + a.surfaceClearance, c.slotSpacing < revolution,
      state.phase.isFinite, (0..<revolution).contains(state.phase),
      state.angularSpeed.isFinite, (0...c.angularSpeed).contains(state.angularSpeed),
      state.slots.count <= OrbitFormationState.maximumSlots,
      Set(state.slots.map(\.logicalID)).count == state.slots.count,
      Set(state.slots.map(\.slot)).count == state.slots.count,
      state.slots.map(\.slot) == state.slots.map(\.slot).sorted(),
      state.slots.allSatisfy({ entry in
        (0..<OrbitFormationState.maximumSlots).contains(entry.slot)
          && Double(entry.slot) * c.slotSpacing < revolution
          && entry.captureElapsed.isFinite && (0...c.captureTimeout).contains(entry.captureElapsed)
      })
    else { throw OrbitFormationError.invalidInput }
  }

  private static func validate(_ input: OrbitFormationInput, state: OrbitFormationState) throws {
    guard input.anchor == state.anchor, input.delta.isFinite, input.delta > 0, input.delta <= 0.1,
      input.members.count <= OrbitFormationState.maximumSlots,
      Set(input.members.map(\.logicalID)).count == input.members.count,
      Set(input.members.map(\.slot)).count == input.members.count,
      input.members.map(\.slot) == input.members.map(\.slot).sorted()
    else { throw OrbitFormationError.invalidInput }
    for member in input.members {
      guard (0..<OrbitFormationState.maximumSlots).contains(member.slot),
        member.position.finite, member.velocity.finite, member.forward.finite,
        abs(length(member.forward) - 1) <= 1e-6,
        member.hullRadius.isFinite, member.hullRadius > 0,
        [member.limits.speed, member.limits.acceleration, member.limits.turnRate]
          .allSatisfy({ $0.isFinite && $0 > 0 }),
        Double(member.slot) * state.configuration.slotSpacing < revolution
      else { throw OrbitFormationError.invalidInput }
      if state.slots.contains(where: {
        ($0.logicalID == member.logicalID && $0.slot != member.slot)
          || ($0.slot == member.slot && $0.logicalID != member.logicalID)
      }) {
        throw OrbitFormationError.identityConflict
      }
      let clearance = state.anchor.planetRadius + state.anchor.surfaceClearance + member.hullRadius
      guard clearance.isFinite else { throw OrbitFormationError.unrepresentable }
      guard state.anchor.orbitRadius > clearance else { throw OrbitFormationError.infeasibleOrbit }
    }
    let newCount = input.members.filter { member in
      !state.slots.contains(where: { $0.logicalID == member.logicalID })
    }.count
    guard newCount <= OrbitFormationState.maximumSlots - state.slots.count else {
      throw OrbitFormationError.identityConflict
    }
    for i in input.members.indices {
      for j in input.members.indices where j > i {
        let difference =
          Double(input.members[j].slot - input.members[i].slot) * state.configuration.slotSpacing
        let distance =
          2 * state.anchor.orbitRadius * sin(min(difference, revolution - difference) / 2)
        let required = input.members[i].hullRadius + input.members[j].hullRadius
        guard distance.isFinite, required.isFinite else {
          throw OrbitFormationError.unrepresentable
        }
        guard distance > required else { throw OrbitFormationError.infeasibleOrbit }
      }
    }
  }

  private static func commonRate(
    state: OrbitFormationState, members: [OrbitFormationMember],
    delta: Double
  ) throws -> Double {
    let radius = state.anchor.orbitRadius
    var target = state.configuration.angularSpeed
    var acceleration = Double.infinity
    for member in members {
      let speedRate = member.limits.speed / radius
      let accelerationRate = member.limits.acceleration / radius
      guard speedRate.isFinite, accelerationRate.isFinite, speedRate > 0, accelerationRate > 0
      else { throw OrbitFormationError.unrepresentable }
      target = min(
        target, cruiseHeadroom * speedRate, cruiseHeadroom * member.limits.turnRate,
        sqrt(0.5 * accelerationRate))
      acceleration = min(acceleration, 0.25 * accelerationRate)
    }
    let change = acceleration * delta
    guard target.isFinite, target > 0, change.isFinite, change > 0 else {
      throw OrbitFormationError.unrepresentable
    }
    return state.angularSpeed + max(-change, min(change, target - state.angularSpeed))
  }

  private static func steer(
    _ member: OrbitFormationMember, state: OrbitFormationState,
    next: OrbitFormationState, delta: Double, elapsed: Double
  ) throws -> OrbitFormationDirective {
    func blocked(_ reason: OrbitFormationBlock) -> OrbitFormationDirective {
      .init(logicalID: member.logicalID, slot: member.slot, steering: nil, blocked: reason)
    }
    let anchor = state.anchor
    let direction = Double(state.configuration.direction.rawValue)
    let oldAngle = state.phase - direction * Double(member.slot) * state.configuration.slotSpacing
    let angle = next.phase - direction * Double(member.slot) * state.configuration.slotSpacing
    let goalRadial = anchor.basis.x * cos(angle) + anchor.basis.y * sin(angle)
    let goalTangent = (anchor.basis.x * -sin(angle) + anchor.basis.y * cos(angle)) * direction
    let goal = anchor.center + goalRadial * anchor.orbitRadius
    let goalSpeed = next.angularSpeed * anchor.orbitRadius
    let goalVelocity = goalTangent * goalSpeed
    let relative = member.position - anchor.center
    guard goal.finite, goalVelocity.finite, relative.finite, goalSpeed.isFinite else {
      throw OrbitFormationError.unrepresentable
    }
    let requiredCentripetal = goalSpeed * next.angularSpeed
    guard requiredCentripetal.isFinite else { throw OrbitFormationError.unrepresentable }
    if goalSpeed > member.limits.speed || next.angularSpeed > member.limits.turnRate
      || requiredCentripetal > 0.5 * member.limits.acceleration * (1 + 1e-12)
    {
      return blocked(.formationSlowing)
    }
    let normal = anchor.basis.z
    let planeError = relative.dot(normal)
    let projected = relative - normal * planeError
    let radius = length(projected)
    let radial =
      radius > 1e-9
      ? normalized(projected) : anchor.basis.x * cos(oldAngle) + anchor.basis.y * sin(oldAngle)
    let tangent = normal.cross(radial) * direction
    let actualAngle =
      radius > 1e-9 ? atan2(projected.dot(anchor.basis.y), projected.dot(anchor.basis.x)) : oldAngle
    let phaseError = wrap(oldAngle - actualAngle + Double.pi) - Double.pi
    let radialError = anchor.orbitRadius - radius
    let error = hypot(hypot(radialError, planeError), anchor.orbitRadius * phaseError)
    let radialSpeed = member.velocity.dot(radial)
    let tangentialSpeed = member.velocity.dot(tangent)
    let normalSpeed = member.velocity.dot(normal)
    guard
      [planeError, radius, error, radialSpeed, tangentialSpeed, normalSpeed].allSatisfy(\.isFinite)
    else { throw OrbitFormationError.unrepresentable }
    let tolerance = max(1, member.hullRadius * 0.25)
    let tracking =
      error <= tolerance && length(member.velocity - goalVelocity) <= max(1, goalSpeed * 0.05)
    if !tracking && error > state.configuration.captureDistance { return blocked(.captureDistance) }
    if !tracking && elapsed + delta >= state.configuration.captureTimeout {
      return blocked(.captureTimeout)
    }
    let safeRadius = max(radius, anchor.orbitRadius * 0.25)
    let turnCap = member.limits.turnRate * safeRadius
    let accelerationCap = sqrt(0.5 * member.limits.acceleration) * sqrt(safeRadius)
    guard turnCap.isFinite, accelerationCap.isFinite else {
      throw OrbitFormationError.unrepresentable
    }
    let catchupCap = min(member.limits.speed, turnCap, accelerationCap)
    let requestedTangent = goalSpeed + (0.5 * direction * phaseError) * radius
    guard requestedTangent.isFinite else { throw OrbitFormationError.unrepresentable }
    let desiredTangent = max(0, min(catchupCap, requestedTangent))
    let desiredRadial = max(
      -0.25 * member.limits.speed, min(0.25 * member.limits.speed, radialError * 0.5))
    let desiredNormal = max(
      -0.25 * member.limits.speed, min(0.25 * member.limits.speed, -planeError * 0.5))
    let desiredVelocity = limited(
      tangent * desiredTangent + radial * desiredRadial + normal * desiredNormal,
      to: member.limits.speed)
    let centripetal = tangentialSpeed * (tangentialSpeed / safeRadius)
    let raw =
      radial * (desiredVelocity.dot(radial) - radialSpeed - centripetal)
      + tangent * (desiredVelocity.dot(tangent) - tangentialSpeed)
      + normal * (desiredVelocity.dot(normal) - normalSpeed)
    guard catchupCap.isFinite, desiredVelocity.finite, raw.finite, length(raw).isFinite else {
      throw OrbitFormationError.unrepresentable
    }
    let acceleration = limited(raw, to: member.limits.acceleration)
    let required = anchor.planetRadius + anchor.surfaceClearance + member.hullRadius
    let endpoint = relative + member.velocity * delta
    let deviation = 0.5 * length(acceleration) * delta * delta
    guard endpoint.finite, deviation.isFinite else { throw OrbitFormationError.unrepresentable }
    let clearance = segmentDistance(relative, endpoint) - deviation
    guard clearance.isFinite else { throw OrbitFormationError.unrepresentable }
    if clearance <= required {
      return blocked(.unsafeClearance)
    }
    let heading =
      length(desiredVelocity) > 1e-9 ? normalized(desiredVelocity) : normalized(member.forward)
    let desiredForward = turned(
      normalized(member.forward), toward: heading,
      maximum: member.limits.turnRate * delta, fallback: anchor.basis.z)
    guard desiredForward.finite else { throw OrbitFormationError.unrepresentable }
    return .init(
      logicalID: member.logicalID, slot: member.slot,
      steering: .init(
        goalPosition: goal, goalVelocity: goalVelocity, desiredVelocity: desiredVelocity,
        acceleration: acceleration, desiredForward: desiredForward,
        tracking: tracking ? .tracking : .capturing),
      blocked: nil)
  }

  private static func length(_ value: Vector3) -> Double { hypot(hypot(value.x, value.y), value.z) }
  private static func normalized(_ value: Vector3) -> Vector3 {
    let magnitude = length(value)
    return .init(value.x / magnitude, value.y / magnitude, value.z / magnitude)
  }
  private static func limited(_ value: Vector3, to maximum: Double) -> Vector3 {
    length(value) > maximum ? normalized(value) * maximum : value
  }
  private static func segmentDistance(_ start: Vector3, _ end: Vector3) -> Double {
    let difference = end - start
    let magnitude = length(difference)
    guard magnitude > 0 else { return length(start) }
    let unit = normalized(difference)
    let along = max(0, min(magnitude, -start.dot(unit)))
    return length(start + unit * along)
  }
  private static func turned(
    _ from: Vector3, toward target: Vector3, maximum: Double,
    fallback: Vector3
  ) -> Vector3 {
    let cosine = max(-1, min(1, from.dot(target)))
    let angle = acos(cosine)
    guard angle > maximum else { return target }
    var axis = from.cross(target)
    if length(axis) < 1e-9 {
      axis = from.cross(fallback)
      if length(axis) < 1e-9 {
        let cardinal = abs(from.x) < 0.8 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)
        axis = from.cross(cardinal)
      }
    }
    axis = normalized(axis)
    return normalized(
      from * cos(maximum) + axis.cross(from) * sin(maximum)
        + axis * (axis.dot(from) * (1 - cos(maximum))))
  }
}
