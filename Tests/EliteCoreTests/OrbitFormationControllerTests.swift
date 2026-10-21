import Foundation
import Testing

@testable import EliteCore

private enum OrbitFixture {
  static func id(_ value: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
  }
  static func state(
    radius: Double = 1000, phase: Double = 0, speed: Double = 0.05,
    requested: Double = 0.05, spacing: Double = 0.08, timeout: Double = 120,
    captureDistance: Double = 3000, center: Vector3 = .init(0, 0, 0), basis: Basis3 = Basis3(),
    direction: OrbitFormationDirection = .positive
  ) throws -> OrbitFormationState {
    try .init(
      incarnation: id(250),
      anchor: .init(
        identity: id(251), center: center, basis: basis,
        planetRadius: 100, orbitRadius: radius, surfaceClearance: 10),
      configuration: .init(
        direction: direction, angularSpeed: requested, slotSpacing: spacing,
        captureDistance: captureDistance, captureTimeout: timeout), phase: phase,
      angularSpeed: speed)
  }
  static func member(
    _ state: OrbitFormationState, slot: Int = 0,
    limits: OrbitFormationLimits = .init(speed: 200, acceleration: 20, turnRate: 1)
  ) -> OrbitFormationMember {
    let sign = Double(state.configuration.direction.rawValue)
    let angle = state.phase - sign * Double(slot) * state.configuration.slotSpacing
    let radial = state.anchor.basis.x * cos(angle) + state.anchor.basis.y * sin(angle)
    let tangent = (state.anchor.basis.x * -sin(angle) + state.anchor.basis.y * cos(angle)) * sign
    return .init(
      logicalID: id(UInt8(slot + 1)), slot: slot,
      position: state.anchor.center + radial * state.anchor.orbitRadius,
      velocity: tangent * (state.angularSpeed * state.anchor.orbitRadius), forward: tangent,
      hullRadius: 2, limits: limits)
  }
  static func changed(
    _ member: OrbitFormationMember, id: UUID? = nil, slot: Int? = nil,
    position: Vector3? = nil, velocity: Vector3? = nil, forward: Vector3? = nil,
    hullRadius: Double? = nil, limits: OrbitFormationLimits? = nil
  ) -> OrbitFormationMember {
    .init(
      logicalID: id ?? member.logicalID, slot: slot ?? member.slot,
      position: position ?? member.position, velocity: velocity ?? member.velocity,
      forward: forward ?? member.forward, hullRadius: hullRadius ?? member.hullRadius,
      limits: limits ?? member.limits)
  }
  static func step(
    _ state: OrbitFormationState, _ members: [OrbitFormationMember], delta: Double = 0.1
  )
    throws -> OrbitFormationStep
  {
    try OrbitFormationController.step(
      state: state,
      input: .init(
        anchor: state.anchor,
        members: members, delta: delta))
  }
  static func length(_ value: Vector3) -> Double { hypot(hypot(value.x, value.y), value.z) }
}

struct OrbitFormationControllerTests {
  @Test(arguments: [OrbitFormationDirection.positive, .negative])
  func eitherOrbitDirectionWrapsAndKeepsOrderedSlotTangentHandedness(
    direction: OrbitFormationDirection
  ) throws {
    let phase = direction == .positive ? 2 * Double.pi - 0.001 : 0.001
    let state = try OrbitFixture.state(phase: phase, direction: direction)
    let result = try OrbitFixture.step(
      state, [OrbitFixture.member(state), OrbitFixture.member(state, slot: 4)])
    #expect(
      direction == .positive ? result.state.phase < 0.01 : result.state.phase > 2 * .pi - 0.01)
    for directive in result.directives {
      let steering = try #require(directive.steering)
      let normalMotion = (steering.goalPosition - state.anchor.center).cross(steering.goalVelocity)
        .dot(state.anchor.basis.z)
      #expect(normalMotion * Double(direction.rawValue) > 0)
    }
    #expect(result.directives.map(\.slot) == [0, 4])
  }

  @Test func translatedRotatedAnchorGivesOneOrderedCircleAndTangentNotLeaderOffsets() throws {
    var basis = Basis3()
    basis.x = .init(0, 1, 0)
    basis.y = .init(0, 0, 1)
    basis.z = .init(1, 0, 0)
    let state = try OrbitFixture.state(
      phase: .pi / 2, spacing: .pi / 2,
      center: .init(400, -800, 150), basis: basis)
    let result = try OrbitFixture.step(
      state, [OrbitFixture.member(state), OrbitFixture.member(state, slot: 1)])
    let first = try #require(result.directives[0].steering)
    let second = try #require(result.directives[1].steering)
    for steering in [first, second] {
      let radial = steering.goalPosition - state.anchor.center
      #expect(abs(OrbitFixture.length(radial) - 1000) < 1e-8)
      #expect(abs(radial.dot(basis.z)) < 1e-8)
      #expect(abs(radial.dot(steering.goalVelocity)) < 1e-8)
      #expect(abs(OrbitFixture.length(steering.goalVelocity) - 50) < 1e-8)
    }
    #expect(
      abs(OrbitFixture.length(first.goalPosition - second.goalPosition) - sqrt(2) * 1000) < 1e-8)
    #expect(result.directives.map(\.slot) == [0, 1])
    #expect(first.goalVelocity.dot(basis.x) < 0 && second.goalVelocity.dot(basis.y) > 0)
  }

  @Test(arguments: [500.0, 1000.0, 4000.0])
  func centripetalBudgetControlsCruiseForActualRadius(radius: Double) throws {
    let rate = sqrt(1 / radius)
    let state = try OrbitFixture.state(radius: radius, speed: rate, requested: 10)
    let limits = OrbitFormationLimits(speed: 1000, acceleration: 2, turnRate: 1)
    let member = OrbitFixture.member(state, limits: limits)
    let result = try OrbitFixture.step(state, [member])
    let steering = try #require(result.directives.first?.steering)
    let speed = OrbitFixture.length(steering.goalVelocity)
    #expect(abs(speed * speed / radius - 1) < 1e-8)
    #expect(OrbitFixture.length(steering.acceleration) <= 2 + 1e-10)
    #expect(speed <= limits.speed && result.state.angularSpeed <= limits.turnRate)
    #expect(steering.acceleration.dot(member.position - state.anchor.center) < 0)
  }

  @Test func weakMemberSlowsCommonPhaseWithoutIssuingImpossibleIntentOrJumpingSurvivor() throws {
    let state = try OrbitFixture.state()
    let strong = OrbitFixture.member(state)
    let weak = OrbitFixture.member(
      state, slot: 1, limits: .init(speed: 2, acceleration: 2, turnRate: 0.02))
    let result = try OrbitFixture.step(state, [strong, weak])
    #expect(result.state.angularSpeed < state.angularSpeed)
    #expect(state.angularSpeed - result.state.angularSpeed <= 0.00005 + 1e-12)
    #expect(
      result.directives[1].blocked == .formationSlowing && result.directives[1].steering == nil)
    let steering = try #require(result.directives[0].steering)
    #expect(OrbitFixture.length(steering.goalPosition - strong.position) < 6)
    #expect(OrbitFixture.length(steering.acceleration) <= strong.limits.acceleration)
  }

  @Test(arguments: [0, 1])
  func antiparallelHeadingAndParallelFallbackAxisRemainFiniteAndTurnLimited(variant: Int) throws {
    let state = try OrbitFixture.state()
    let original = OrbitFixture.member(state)
    let member: OrbitFormationMember
    if variant == 0 {
      member = OrbitFixture.changed(original, velocity: .init(0, 0, 0), forward: .init(0, -1, 0))
    } else {
      member = OrbitFixture.changed(
        original,
        position: .init(1000 * cos(0.5), 1000 * sin(0.5), 200), velocity: .init(0, 0, 0),
        forward: .init(0, 0, 1))
    }
    let first = try OrbitFixture.step(state, [member])
    let second = try OrbitFixture.step(state, [member])
    let steering = try #require(first.directives[0].steering)
    #expect(first == second && steering.desiredForward.finite)
    #expect(abs(OrbitFixture.length(steering.desiredForward) - 1) < 1e-10)
    #expect(acos(max(-1, min(1, member.forward.dot(steering.desiredForward)))) <= 0.1 + 1e-10)
  }

  @Test func overspeedRequestsBoundedBrakingWithoutInstantVelocityClipping() throws {
    let state = try OrbitFixture.state()
    let original = OrbitFixture.member(state)
    let member = OrbitFixture.changed(original, velocity: .init(0, 1000, 0))
    let result = try OrbitFixture.step(state, [member])
    let steering = try #require(result.directives[0].steering)
    #expect(OrbitFixture.length(steering.desiredVelocity) <= member.limits.speed)
    #expect(steering.acceleration.dot(member.velocity) < 0)
    #expect(OrbitFixture.length(steering.acceleration) <= member.limits.acceleration + 1e-10)
    let after = member.velocity + steering.acceleration * 0.1
    #expect(OrbitFixture.length(after) > member.limits.speed)
    #expect(
      OrbitFixture.length(after - member.velocity) <= member.limits.acceleration * 0.1 + 1e-10)
  }

  @Test(arguments: [0, 1, 2])
  func closedLoopCorrectsRadialPlaneAndPhaseErrorAroundThePlanet(variant: Int) throws {
    var state = try OrbitFixture.state()
    let original = OrbitFixture.member(state)
    let position: Vector3
    switch variant {
    case 0: position = .init(1120, 0, 0)
    case 1: position = .init(1000, 0, 100)
    default: position = .init(1000 * cos(-0.2), 1000 * sin(-0.2), 0)
    }
    var member = OrbitFixture.changed(original, position: position)
    for _ in 0..<1000 {
      let result = try OrbitFixture.step(state, [member], delta: 0.02)
      let steering = try #require(result.directives[0].steering)
      let nextPosition = member.position + member.velocity * 0.02 + steering.acceleration * 0.0002
      let velocity = member.velocity + steering.acceleration * 0.02
      #expect(OrbitFixture.length(nextPosition - state.anchor.center) > 112)
      #expect(OrbitFixture.length(steering.acceleration) <= member.limits.acceleration + 1e-9)
      member = OrbitFixture.changed(
        member, position: nextPosition, velocity: velocity, forward: steering.desiredForward)
      state = result.state
    }
    let relative = member.position - state.anchor.center
    #expect(abs(hypot(relative.x, relative.y) - 1000) < 8)
    #expect(abs(relative.z) < 3)
    let angleError = atan2(
      sin(atan2(relative.y, relative.x) - state.phase),
      cos(atan2(relative.y, relative.x) - state.phase))
    #expect(abs(angleError) < 0.03)
  }

  @Test func slotGapsReloadAndNewIncarnationPreserveLogicalIdentityAndPhase() throws {
    let state = try OrbitFixture.state(phase: 2 * .pi - 0.001)
    let first = try OrbitFixture.step(state, (0..<3).map { OrbitFixture.member(state, slot: $0) })
    #expect(first.state.phase < 0.01 && first.state.slots.map(\.slot) == [0, 1, 2])
    let restored = try JSONDecoder().decode(
      OrbitFormationState.self, from: JSONEncoder().encode(first.state))
    #expect(restored == first.state)
    let survivors = [OrbitFixture.member(restored), OrbitFixture.member(restored, slot: 2)]
    let after = try OrbitFixture.step(restored, survivors)
    #expect(after.directives.map(\.logicalID) == survivors.map(\.logicalID))
    #expect(after.state.slots.map(\.slot) == [0, 1, 2])
    let added = try OrbitFixture.step(
      after.state, [OrbitFixture.member(after.state), OrbitFixture.member(after.state, slot: 3)])
    #expect(added.state.slots.map(\.slot) == [0, 1, 2, 3])
    let foreign = OrbitFixture.changed(
      OrbitFixture.member(after.state, slot: 1), id: OrbitFixture.id(100))
    #expect(throws: OrbitFormationError.identityConflict) {
      try OrbitFixture.step(after.state, [foreign])
    }
    let renumbered = OrbitFixture.changed(survivors[0], slot: 4)
    #expect(throws: OrbitFormationError.identityConflict) {
      try OrbitFixture.step(after.state, [renumbered])
    }
    let fresh = try OrbitFormationState(
      incarnation: OrbitFixture.id(249), anchor: after.state.anchor,
      configuration: after.state.configuration, phase: after.state.phase,
      angularSpeed: after.state.angularSpeed)
    #expect(try OrbitFixture.step(fresh, [foreign]).state.slots[0].logicalID == foreign.logicalID)
    let paused = try OrbitFixture.step(after.state, [])
    #expect(paused.state == after.state && paused.directives.isEmpty)
  }

  @Test func captureTimerSurvivesAbsenceAndReloadAndNeverResetsWithinIncarnation() throws {
    var state = try OrbitFixture.state(timeout: 0.25)
    let member = OrbitFixture.changed(OrbitFixture.member(state), position: .init(1100, 0, 0))
    state = try OrbitFixture.step(state, [member]).state
    state = try JSONDecoder().decode(OrbitFormationState.self, from: JSONEncoder().encode(state))
    state = try OrbitFixture.step(state, []).state
    #expect(state.slots[0].captureElapsed == 0.1)
    state = try OrbitFixture.step(state, [member]).state
    let expired = try OrbitFixture.step(state, [member])
    #expect(
      expired.directives[0].blocked == .captureTimeout && expired.directives[0].steering == nil)
    #expect(expired.state.slots[0].captureElapsed == 0.25)
    let onRail = OrbitFixture.member(expired.state)
    let tracked = try OrbitFixture.step(expired.state, [onRail])
    #expect(tracked.directives[0].steering?.tracking == .tracking)
    #expect(tracked.state.slots[0].captureElapsed == 0.25)
    let displaced = OrbitFixture.changed(onRail, position: .init(1100, 0, 0))
    #expect(
      try OrbitFixture.step(tracked.state, [displaced]).directives[0].blocked == .captureTimeout)
  }

  @Test func planetSweepAndCaptureDistanceBlockWithoutMotionOrTeleport() throws {
    let state = try OrbitFixture.state()
    let member = OrbitFixture.changed(
      OrbitFixture.member(state), position: .init(115, 0, 0), velocity: .init(-100, 0, 0))
    let result = try OrbitFixture.step(state, [member])
    #expect(
      result.directives[0].blocked == .unsafeClearance && result.directives[0].steering == nil)
    let far = OrbitFixture.changed(member, position: .init(5000, 0, 0), velocity: .init(0, 0, 0))
    #expect(try OrbitFixture.step(state, [far]).directives[0].blocked == .captureDistance)
  }

  @Test func fullSixtyFourSlotsAndWraparoundClearanceAreBoundedPerIncarnation() throws {
    let state = try OrbitFixture.state()
    let members = (0..<64).map { OrbitFixture.member(state, slot: $0) }
    let result = try OrbitFixture.step(state, members)
    #expect(result.state.slots.count == 64 && result.directives.count == 64)
    #expect(result.directives.allSatisfy { $0.steering != nil })
    let crowded = try OrbitFixture.state(spacing: (2 * .pi - 0.0005) / 63)
    #expect(throws: OrbitFormationError.infeasibleOrbit) {
      try OrbitFixture.step(
        crowded, [OrbitFixture.member(crowded), OrbitFixture.member(crowded, slot: 63)])
    }
  }

  @Test(arguments: [
    "delta-zero", "delta-nan", "delta-large", "position", "velocity", "forward", "speed",
    "acceleration", "turn", "duplicate-id", "duplicate-slot", "order", "oversize", "hull",
  ])
  func invalidPhysicalInputsAndMembershipAreRejected(reason: String) throws {
    let state = try OrbitFixture.state()
    var members = [OrbitFixture.member(state)]
    var delta = 0.1
    switch reason {
    case "delta-zero": delta = 0
    case "delta-nan": delta = .nan
    case "delta-large": delta = 0.1001
    case "position": members[0] = OrbitFixture.changed(members[0], position: .init(.infinity, 0, 0))
    case "velocity": members[0] = OrbitFixture.changed(members[0], velocity: .init(0, .nan, 0))
    case "forward": members[0] = OrbitFixture.changed(members[0], forward: .init(0, 0, 0))
    case "speed":
      members[0] = OrbitFixture.changed(
        members[0], limits: .init(speed: 0, acceleration: 20, turnRate: 1))
    case "acceleration":
      members[0] = OrbitFixture.changed(
        members[0], limits: .init(speed: 200, acceleration: -1, turnRate: 1))
    case "turn":
      members[0] = OrbitFixture.changed(
        members[0], limits: .init(speed: 200, acceleration: 20, turnRate: .infinity))
    case "duplicate-id":
      members.append(
        OrbitFixture.changed(OrbitFixture.member(state, slot: 1), id: members[0].logicalID))
    case "duplicate-slot":
      members.append(OrbitFixture.changed(OrbitFixture.member(state, slot: 1), slot: 0))
    case "order": members.insert(OrbitFixture.member(state, slot: 1), at: 0)
    case "oversize": members = Array(repeating: members[0], count: 65)
    default: members[0] = OrbitFixture.changed(members[0], hullRadius: 0)
    }
    #expect(throws: OrbitFormationError.invalidInput) {
      try OrbitFixture.step(state, members, delta: delta)
    }
    #expect(state.slots.isEmpty && state.phase == 0)
  }

  @Test func badBasisAnchorDerivedMathAndPoisonedSavedSlotsFailClosed() throws {
    var reflected = Basis3()
    reflected.z = .init(0, 0, -1)
    #expect(throws: OrbitFormationError.invalidInput) { try OrbitFixture.state(basis: reflected) }
    #expect(throws: OrbitFormationError.invalidInput) { try OrbitFixture.state(radius: 100) }
    #expect(throws: OrbitFormationError.invalidInput) { try OrbitFixture.state(phase: .nan) }
    let state = try OrbitFixture.state()
    let other = try OrbitFixture.state(center: .init(1, 0, 0))
    #expect(throws: OrbitFormationError.invalidInput) {
      try OrbitFormationController.step(
        state: state,
        input: .init(
          anchor: other.anchor,
          members: [OrbitFixture.member(state)], delta: 0.1))
    }
    let huge = try OrbitFixture.state(center: .init(Double.greatestFiniteMagnitude, 0, 0))
    let member = OrbitFixture.changed(
      OrbitFixture.member(huge), position: .init(-Double.greatestFiniteMagnitude, 0, 0))
    #expect(throws: OrbitFormationError.unrepresentable) { try OrbitFixture.step(huge, [member]) }
    let poison = try JSONSerialization.data(withJSONObject: [
      "slots": Array(repeating: NSNull(), count: 65)
    ])
    do {
      _ = try JSONDecoder().decode(OrbitFormationState.self, from: poison)
      Issue.record("Oversized saved formation accepted")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.debugDescription == "Orbit formation slot limit exceeded.")
    }
  }

  @Test(arguments: ["phase", "speed", "capture", "slot", "duplicate"])
  func malformedSavedStateCannotResetBoundsOrDuplicateClaimedSlots(field: String) throws {
    let state = try OrbitFixture.state()
    let registered = try OrbitFixture.step(state, [OrbitFixture.member(state)]).state
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(registered)) as? [String: Any])
    switch field {
    case "phase": object["phase"] = 2 * Double.pi
    case "speed": object["angularSpeed"] = -1
    default:
      var slots = try #require(object["slots"] as? [[String: Any]])
      if field == "duplicate" {
        slots.append(slots[0])
      } else {
        slots[0][field == "capture" ? "captureElapsed" : "slot"] = -1
      }
      object["slots"] = slots
    }
    let data = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: OrbitFormationError.invalidInput) {
      try JSONDecoder().decode(OrbitFormationState.self, from: data)
    }
  }
}
