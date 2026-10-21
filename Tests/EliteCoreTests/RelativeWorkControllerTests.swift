import Foundation
import Testing

@testable import EliteCore

private let rwActor = ActorIdentity(
  system: .init(galaxy: 0, system: 7), visit: 10, entity: 42)
private let rwWreck = WreckIdentity(
  system: .init(galaxy: 0, system: 7), site: 4, lineage: 600)
private let rwLimits = RelativeWorkLimits(
  acceleration: 40, speed: 120, pitchRate: 0.6, yawRate: 0.6, rollRate: 0.6)

private func rwTarget(
  identity: ActorIdentity = rwActor, wreck: WreckIdentity? = rwWreck
) -> RelativeWorkTarget {
  .init(
    identity: identity, wreck: wreck, pose: .init(), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), surfacePoint: .init(0, 0, 0),
    surfaceNormal: .init(0, 0, -1))
}

private func rwInput(target: RelativeWorkTarget? = rwTarget()) -> RelativeWorkInput {
  var pose = ShipPose()
  pose.position = .init(0, 0, -151)
  return .init(
    ship: pose, velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0),
    target: target, playerRadius: 30, limits: rwLimits, delta: 0.02)
}

private func rwRotate(_ vector: Vector3, omega: Vector3, delta: Double) -> Vector3 {
  guard omega.length > 1e-12 else { return vector }
  let axis = omega * (1 / omega.length)
  let angle = omega.length * delta
  return vector * cos(angle) + axis.cross(vector) * sin(angle)
    + axis * (axis.dot(vector) * (1 - cos(angle)))
}

private func rwAdvance(_ basis: Basis3, omega: Vector3, delta: Double) -> Basis3 {
  var result = basis
  result.x = rwRotate(basis.x, omega: omega, delta: delta)
  result.y = rwRotate(basis.y, omega: omega, delta: delta)
  result.z = rwRotate(basis.z, omega: omega, delta: delta)
  return result
}

/// Test-only integration enacts the requests; the controller cannot write either pose.
private func rwTick(
  _ controller: inout RelativeWorkController, _ input: inout RelativeWorkInput,
  validate: (RelativeWorkSweep) -> RelativeWorkClearance = { _ in .clear }
) -> RelativeWorkOutput {
  let output = controller.step(input, validate: validate)
  #expect(output.acceleration.length <= input.limits.acceleration + 1e-8)
  #expect(
    (output.velocity - input.velocity).length <= input.limits.acceleration * input.delta + 1e-8)
  #expect(abs(output.pitchRate) <= input.limits.pitchRate + 1e-9)
  #expect(abs(output.yawRate) <= input.limits.yawRate + 1e-9)
  #expect(abs(output.rollRate) <= input.limits.rollRate + 1e-9)
  let omega = input.ship.orientation.apply(
    .init(output.pitchRate, -output.yawRate, output.rollRate))
  input.ship.position =
    input.ship.position + input.velocity * input.delta
    + output.acceleration * (0.5 * input.delta * input.delta)
  input.ship.orientation = rwAdvance(input.ship.orientation, omega: omega, delta: input.delta)
  input.velocity = output.velocity
  input.angularVelocity = omega
  if var target = input.target {
    target.pose.position = target.pose.position + target.velocity * input.delta
    target.pose.orientation = rwAdvance(
      target.pose.orientation, omega: target.angularVelocity, delta: input.delta)
    input.target = target
  }
  return output
}

@Test func relativeWorkApproachesDriftingRotatingSurfaceAndHoldsWithoutFreezingIt() throws {
  var target = rwTarget()
  target.velocity = .init(15, 2, 0)
  target.angularVelocity = .init(0, 0.04, 0.03)
  target.surfacePoint = .init(70, 0, 0)
  var input = rwInput(target: target)
  input.ship.position = .init(320, 70, -900)
  input.velocity = .init(0, 0, 8)
  var controller = RelativeWorkController(parent: rwActor, wreck: rwWreck, category: .wreck)
  var selections = 0
  var heldFrames = 0
  var final: RelativeWorkOutput?
  for _ in 0..<3000 {
    let output = rwTick(&controller, &input)
    selections += output.transitions.filter { $0 == .selectTool(.salvageCutter) }.count
    if output.status == .holding { heldFrames += 1 }
    #expect(output.motionValidated)
    #expect(output.velocity.length <= rwLimits.speed + 1e-8)
    final = output
  }
  let output = try #require(final)
  #expect(output.status == .holding && heldFrames > 1000)
  #expect(output.positionError < 1 && output.relativeSpeed < 1 && output.facingError < 0.025)
  #expect(selections == 1)
  #expect(controller.parent == rwActor && controller.wreck == rwWreck)
  #expect((try #require(input.target)).pose.position.x > 899)
  #expect((try #require(input.target)).pose.orientation != target.pose.orientation)
}

@Test func relativeWorkFeedForwardIncludesWorkOffsetSpinAndCentripetalAcceleration() throws {
  var target = rwTarget()
  target.surfacePoint = .init(100, 0, 0)
  target.angularVelocity = .init(0, 0, 0.1)
  target.velocity = .init(10, 0, 0)
  var input = rwInput(target: target)
  input.ship.position = .init(100, 0, -151)
  input.velocity = .init(10, 10, 0)
  input.angularVelocity = target.angularVelocity
  var controller = RelativeWorkController(parent: rwActor, wreck: rwWreck, category: .rock)
  var sweep: RelativeWorkSweep?
  let output = controller.step(input) { candidate in
    sweep = candidate
    return .clear
  }
  #expect((output.acceleration - Vector3(-1, 0, 0)).length < 1e-8)
  #expect((output.velocity - Vector3(9.98, 10, 0)).length < 1e-8)
  #expect(abs(output.rollRate - 0.1) < 1e-8)
  let checked = try #require(sweep)
  #expect(checked.target.identity == rwActor && checked.target.wreck == rwWreck)
  #expect(checked.requiredClearance == 120 && checked.duration == input.delta)
  #expect(checked.targetEnd.orientation != target.pose.orientation)
  #expect(checked.end.position != checked.start.position)
}

@Test func relativeWorkUsesSurfaceNormalAndActualPlayerRadiusForWorkClearance() {
  var target = rwTarget()
  target.surfaceNormal = .init(0, 5, 0)
  var input = rwInput(target: target)
  input.playerRadius = 90
  input.ship.position = .init(0, 271, 0)
  input.ship.orientation.x = .init(0, 0, -1)
  input.ship.orientation.y = .init(1, 0, 0)
  input.ship.orientation.z = .init(0, -1, 0)
  var controller = RelativeWorkController(parent: rwActor, category: .rock)
  for _ in 0..<30 {
    let output = rwTick(&controller, &input)
    #expect(output.requiredClearance == 180)
    #expect(output.workPosition == Vector3(0, 271, 0))
    #expect(output.surfacePosition == Vector3(0, 0, 0))
    #expect(output.facingError < 1e-9)
  }
  #expect(controller.status == .holding)
}

@Test func relativeWorkRefusesUnattainableDriftSpinAccelerationAndRange() {
  let cases: [(RelativeWorkBlock, (inout RelativeWorkInput) -> Void)] = [
    (.speedLimit, { $0.target?.velocity = .init(121, 0, 0) }),
    (
      .speedLimit,
      {
        $0.target?.velocity = .init(0, 0, 120)
        $0.ship.position.z = -500
      }
    ),
    (.turnLimit, { $0.target?.angularVelocity = .init(0, 0, 0.7) }),
    (
      .turnLimit,
      {
        $0.ship.orientation.rotate(pitch: 0.2, roll: 0, yaw: 0)
        $0.limits.pitchRate = 0
        $0.limits.yawRate = 0
        $0.limits.rollRate = 0
      }
    ),
    (
      .accelerationLimit,
      {
        $0.target?.angularVelocity = .init(0, 0, 0.4)
        $0.target?.surfacePoint = .init(1000, 0, 0)
        $0.limits.speed = 1000
      }
    ),
    (.toolRange, { $0.playerRadius = 100 }),
    (.toolRange, { $0.cutterRange = 119 }),
  ]
  for (reason, change) in cases {
    var input = rwInput()
    input.velocity = .init(8, 0, 0)
    change(&input)
    var controller = RelativeWorkController(parent: rwActor, wreck: rwWreck, category: .wreck)
    var purposes: [RelativeWorkSweep.Purpose] = []
    let output = controller.step(input) { sweep in
      purposes.append(sweep.purpose)
      return .clear
    }
    #expect(output.status == .blocked(reason))
    #expect(output.motionValidated && output.acceleration.x == -40)
    #expect(abs(output.velocity.x - 7.2) < 1e-8)
    #expect(purposes.count == 1 && purposes.first == .braking)
    #expect(controller.parent == rwActor)
    #expect(!output.transitions.contains(.selectTool(.salvageCutter)))
  }
}

@Test func relativeWorkRequiresActualSweptClearanceAndSeparatelyValidatesBraking() {
  var input = rwInput()
  input.ship.position.z = -300
  input.velocity = .init(0, 0, 10)
  input.target?.angularVelocity = .init(0, 0.1, 0)
  var controller = RelativeWorkController(parent: rwActor, wreck: rwWreck, category: .wreck)
  var checked: [RelativeWorkSweep] = []
  let output = controller.step(input) { sweep in
    checked.append(sweep)
    // The owner has detected a swept protrusion on the work path, not on the brake path.
    return sweep.purpose == .work ? .blocked("Rotating antenna crosses approach") : .clear
  }
  #expect(output.status == .blocked(.clearance("Rotating antenna crosses approach")))
  #expect(checked.count == 2 && checked[0].purpose == .work && checked[1].purpose == .braking)
  #expect(output.motionValidated && output.acceleration.z == -40)
  #expect(output.velocity.z < input.velocity.z && output.velocity.z > 0)
  #expect(checked[0].targetEnd.orientation != checked[0].target.pose.orientation)
  #expect(checked[1].end.position.z > input.ship.position.z)

  var deniedController = RelativeWorkController(parent: rwActor, category: .wreck)
  let denied = deniedController.step(input) { _ in .blocked("No collision-free brake path") }
  #expect(!denied.motionValidated && denied.acceleration == Vector3(0, 0, 0))
  #expect(denied.velocity == input.velocity)
  #expect(denied.status == .blocked(.clearance("No collision-free brake path")))
}

@Test func relativeWorkStableHoldSelectsToolOnceAndDepletionRetainsParent() {
  for category in [SalvageTargetCategory.rock, .wreck, .section] {
    var input = rwInput()
    var controller = RelativeWorkController(parent: rwActor, wreck: rwWreck, category: category)
    var transitions: [RelativeWorkTransition] = []
    for frame in 0..<150 {
      if frame == 50 { input.target?.depleted = true }
      let output = rwTick(&controller, &input)
      transitions += output.transitions
      if frame < 24 {
        #expect(!output.transitions.contains(.selectTool(.miningLaser)))
        #expect(!output.transitions.contains(.selectTool(.salvageCutter)))
      }
      if frame >= 50 { #expect(output.status == .holding) }
    }
    let tool: RelativeWorkTool = category == .rock ? .miningLaser : .salvageCutter
    #expect(transitions.filter { $0 == .selectTool(tool) }.count == 1)
    #expect(transitions.filter { $0 == .status(.holding) }.count == 1)
    #expect(transitions.filter { $0 == .workComplete }.count == 1)
    #expect(controller.parent == rwActor && controller.wreck == rwWreck)
    #expect(controller.status == .holding)
  }
}

@Test func relativeWorkCancellationLossChangedPrimaryAndLineageHaveDistinctResults() {
  var input = rwInput()
  input.manualCancel = true
  input.target = nil
  input.velocity = .init(1, 2, 3)
  var cancelled = RelativeWorkController(parent: rwActor, category: .rock)
  let first = cancelled.step(input) { _ in
    Issue.record("Manual cancellation must not request automatic motion validation")
    return .clear
  }
  #expect(first.status == .cancelled && !first.active && first.velocity == input.velocity)
  #expect(first.acceleration == Vector3(0, 0, 0) && first.transitions == [.status(.cancelled)])
  input.manualCancel = false
  input.target = rwTarget()
  #expect(cancelled.step(input) { _ in .clear }.transitions.isEmpty)

  var lost = RelativeWorkController(parent: rwActor, category: .wreck)
  input.target = nil
  #expect(lost.step(input) { _ in .clear }.status == .targetLost)
  #expect(lost.parent == rwActor)

  var changed = RelativeWorkController(parent: rwActor, category: .wreck)
  input.target = rwTarget(identity: .init(system: rwActor.system, visit: 10, entity: 99))
  #expect(changed.step(input) { _ in .clear }.status == .changedPrimary)
  #expect(changed.parent == rwActor)

  var lineage = RelativeWorkController(parent: rwActor, wreck: rwWreck, category: .wreck)
  input.target = rwTarget(wreck: .init(system: rwActor.system, site: 4, lineage: 601))
  #expect(lineage.step(input) { _ in .clear }.status == .blocked(.identityMismatch))
  #expect(lineage.wreck == rwWreck)

  input.target = rwTarget()
  var looseItem = RelativeWorkController(parent: rwActor, category: .cargo)
  let unsupported = looseItem.step(input) { _ in .clear }
  #expect(unsupported.status == .blocked(.unsupportedTarget))
  #expect(!unsupported.transitions.contains(.selectTool(.salvageCutter)))
}

@Test func relativeWorkRejectsInvalidDeltaPoseAndNonfiniteInputsWithoutRequests() {
  let changes: [(inout RelativeWorkInput) -> Void] = [
    { $0.delta = 0 }, { $0.delta = -0.1 }, { $0.delta = 0.10001 }, { $0.delta = .nan },
    { $0.velocity.x = .infinity }, { $0.target?.angularVelocity.y = .nan },
    { $0.target?.surfaceNormal = .init(0, 0, 0) },
    { $0.ship.orientation.x = .init(2, 0, 0) },
    { $0.playerRadius = .greatestFiniteMagnitude }, { $0.limits.acceleration = 0 },
  ]
  for change in changes {
    var input = rwInput()
    change(&input)
    var controller = RelativeWorkController(parent: rwActor, category: .rock)
    let output = controller.step(input) { _ in
      Issue.record("Invalid input must not reach physical validation")
      return .clear
    }
    #expect(output.status == .blocked(.invalidInput) && !output.motionValidated)
    #expect(output.acceleration == Vector3(0, 0, 0))
    #expect(output.velocity.length.isFinite)
  }
}

@Test func relativeWorkPreservesAccelerationAuthorityAndBrakesOverspeedWithoutSnapping() {
  var input = rwInput()
  input.ship.position = .init(0, 0, -2000)
  input.velocity = .init(0, 0, 240)
  input.limits.acceleration = 5
  var controller = RelativeWorkController(parent: rwActor, category: .rock)
  let first = rwTick(&controller, &input)
  #expect(first.acceleration.length <= 5 + 1e-9)
  #expect(abs(first.velocity.z - 239.9) < 1e-8)
  #expect(first.velocity.z > input.limits.speed)
  for _ in 0..<500 {
    let output = rwTick(&controller, &input)
    #expect(output.velocity.length.isFinite)
  }
}

@Test func relativeWorkAdmittedDeltaPartitionsConvergeToEquivalentMovingHold() throws {
  func simulate(delta: Double) -> (RelativeWorkOutput, ShipPose, Int) {
    var target = rwTarget()
    target.velocity = .init(8, 0, 0)
    target.angularVelocity = .init(0, 0.04, 0.01)
    target.surfacePoint = .init(40, 0, 0)
    var input = rwInput(target: target)
    input.ship.position = .init(-100, 40, -800)
    input.ship.orientation.rotate(pitch: 0.1, roll: 0.2, yaw: .pi)
    input.delta = delta
    var controller = RelativeWorkController(parent: rwActor, category: .rock)
    var selectionCount = 0
    var final = controller.step(input) { _ in .clear }
    for _ in 0..<Int((60 / delta).rounded()) {
      final = rwTick(&controller, &input)
      selectionCount += final.transitions.filter { $0 == .selectTool(.miningLaser) }.count
    }
    return (final, input.ship, selectionCount)
  }
  let fine = simulate(delta: 0.02)
  let coarse = simulate(delta: 0.1)
  #expect(fine.0.status == .holding && coarse.0.status == .holding)
  #expect(fine.2 == 1 && coarse.2 == 1)
  #expect((fine.1.position - coarse.1.position).length < 1)
  #expect((fine.1.orientation.z - coarse.1.orientation.z).length < 0.01)
  #expect(fine.0.relativeSpeed < 1 && coarse.0.relativeSpeed < 1)
}

@Test func relativeWorkKeepsVisibleObliqueApproachInsteadOfLosingItsBrakingCorridor() throws {
  // Run 539 acquired an oblique SH127 cargo face from local -Y, then accelerated
  // diagonally toward its normal: both work and braking lost the unchanged 138 gap.
  // This closed wedge retains that grazing visible-face/corner configuration cheaply.
  let faces = [
    [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
    [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
  ]
  let hull = try PreparedHull(
    mesh: Mesh(
      vertices: [
        .init(-68, -20, -66), .init(68, -20, -66),
        .init(68, 20, -66), .init(-68, 20, -66),
        .init(-68, -20, -16), .init(68, -20, -16),
        .init(68, 20, -3.7), .init(-68, 20, -3.7),
      ], faces: faces, preserveWinding: true))
  let player = try PreparedHull(
    mesh: Mesh(
      vertices: [
        .init(-60, -10, -30), .init(60, -10, -30),
        .init(60, 10, -30), .init(-60, 10, -30),
        .init(-60, -10, 30), .init(60, -10, 30),
        .init(60, 10, 30), .init(-60, 10, 30),
      ], faces: faces, preserveWinding: true))
  var target = rwTarget()
  target.surfacePoint = .init(0, 0, -9.85)
  target.surfaceNormal = Vector3(0, -12.3, 40).unit
  target.angularVelocity = .init(0.02, 0, 0)
  var initial = rwInput(target: target)
  initial.playerRadius = 69
  initial.limits = .init(
    acceleration: 216, speed: 576, pitchRate: 1, yawRate: 1, rollRate: 1)
  initial.ship.position = target.surfacePoint + Vector3(0, -200, 0)
  initial.ship.orientation.x = .init(1, 0, 0)
  initial.ship.orientation.y = .init(0, 0, -1)
  initial.ship.orientation.z = .init(0, 1, 0)

  // Counterfactual original steering develops real inward momentum, then even its
  // separately checked brake cannot keep the required gap. No fake validator is used.
  var normalInput = initial
  var normalController = RelativeWorkController(parent: rwActor, wreck: rwWreck, category: .wreck)
  var lostBrakingCorridor = false
  for _ in 0..<200 {
    var workRefused = false
    var brakeRefused = false
    let output = rwTick(&normalController, &normalInput) { sweep in
      let result = HullSweepSafety.validate(sweep, target: hull, player: player)
      if result.failure == .clearanceViolation {
        if sweep.purpose == .work { workRefused = true }
        if sweep.purpose == .braking { brakeRefused = true }
      }
      return result.clearance
    }
    if workRefused && brakeRefused {
      lostBrakingCorridor = true
      #expect(!output.motionValidated && output.velocity.y > 0)
      break
    }
  }
  #expect(lostBrakingCorridor)

  // The acquired ray still sees the same geometric face. Only steering changes;
  // every accepted endpoint and continuous interval pays the original exact proof.
  var input = initial
  var controller = RelativeWorkController(
    parent: rwActor, wreck: rwWreck, category: .wreck, approachDirection: .init(0, -1, 0))
  var heldFrames = 0
  var minimumClearance = Double.infinity
  for _ in 0..<600 {
    let output = rwTick(&controller, &input) { sweep in
      let result = HullSweepSafety.validate(sweep, target: hull, player: player)
      if let clearance = result.minimumSampledClearance {
        minimumClearance = min(minimumClearance, clearance)
      }
      return result.clearance
    }
    #expect(output.requiredClearance == 138)
    if !output.motionValidated {
      Issue.record("Acquired visible approach must retain its exact hull clearance")
      break
    }
    if output.status == .holding { heldFrames += 1 }
    if heldFrames >= 30 { break }
  }
  #expect(controller.status == .holding && heldFrames >= 30)
  #expect(minimumClearance >= 138 && minimumClearance.isFinite)
  #expect(input.target?.surfaceNormal == target.surfaceNormal)
}

@Test func relativeWorkRejectsInvalidOrBackFacingAcquiredApproach() {
  for direction in [Vector3(0, 0, 0), .init(.nan, 0, 0), .init(0, 0, 1)] {
    var controller = RelativeWorkController(
      parent: rwActor, category: .wreck, approachDirection: direction)
    let output = controller.step(rwInput()) { _ in
      Issue.record("Invalid approach direction must not reach swept motion admission")
      return .clear
    }
    #expect(output.status == .blocked(.invalidInput) && !output.motionValidated)
  }
}

private func rwClearancePlaneHull() throws -> PreparedHull {
  try PreparedHull(
    mesh: Mesh(
      vertices: [
        .init(-1000, -1000, -100), .init(1000, -1000, -100),
        .init(1000, 1000, -100), .init(-1000, 1000, -100),
        .init(-1000, -1000, 0), .init(1000, -1000, 0),
        .init(1000, 1000, 0), .init(-1000, 1000, 0),
      ],
      faces: [
        [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
        [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
      ], preserveWinding: true))
}

@Test func relativeWorkObliqueDestinationClearsRealPlaneHullAndPreservesRangeBoundary() throws {
  let hull = try rwClearancePlaneHull()
  var target = rwTarget()
  target.surfaceNormal = .init(0, 0, 1)
  target.velocity = .init(2, 0, 0)
  target.angularVelocity = .init(0, 0.01, 0)
  var input = rwInput(target: target)
  input.ship.position = .init(0, 0, 300)
  input.playerRadius = 10
  let approach = Vector3(sqrt(3) / 2, 0, 0.5)
  var controller = RelativeWorkController(
    parent: rwActor, category: .rock, approachDirection: approach)
  var checked: [RelativeWorkSweep] = []
  let output = controller.step(input) {
    checked.append($0)
    return HullSweepSafety.validate($0, target: hull).clearance
  }
  let sweep = try #require(output.validatedSweep)
  let destination = sweep.workPosition
  #expect(output.motionValidated && checked.count == 2)
  let prospective = try #require(checked.first)
  #expect(prospective.start != input.ship && sweep.start == input.ship)
  #expect(prospective.target == target && prospective.targetEnd != target.pose)
  #expect(prospective.duration == input.delta && prospective.playerRadius == 10)
  #expect(prospective.initialVelocity.length > 0 && prospective.angularVelocity.length > 0)
  #expect(sweep.requiredClearance == 120)
  #expect(abs(destination.z - 131) < 1e-8)
  #expect(destination.cross(approach).length < 1e-8)
  let placement = HullSweepSafety.validatePlacement(
    center: destination, radius: 10, hull: hull, pose: .init(), requiredClearance: 120)
  #expect(placement.safe)
  #expect((try #require(placement.minimumSampledClearance)) > 120.99)
  // This admitted 60-degree approach previously placed the centre only65.5from the face.
  let oldPlacement = HullSweepSafety.validatePlacement(
    center: .init(sqrt(3) / 2 * 131, 0, 65.5), radius: 10,
    hull: hull, pose: .init(), requiredClearance: 120)
  #expect(oldPlacement.failure == .clearanceViolation)
  for range in [261.999, 262.0, 262.001] {
    var bounded = input
    bounded.cutterRange = range
    var candidate = RelativeWorkController(
      parent: rwActor, category: .rock, approachDirection: approach)
    let result = candidate.step(bounded) { HullSweepSafety.validate($0, target: hull).clearance }
    #expect((result.status == .blocked(.toolRange)) == (range < 262))
  }
}

@Test(arguments: [-1.0, 1.0])
func relativeWorkObliqueCollectionOffsetPaysItsInwardNormalComponent(sign: Double) throws {
  let hull = try rwClearancePlaneHull()
  var target = rwTarget()
  target.surfaceNormal = .init(0, 0, 1)
  target.pose.orientation.y = .init(0, 0.5, -sign * sqrt(3) / 2)
  target.pose.orientation.z = .init(0, sign * sqrt(3) / 2, 0.5)
  var input = rwInput(target: target)
  input.ship.position = .init(0, 0, 400)
  input.playerRadius = 10
  input.collectionOffset = 20
  input.cutterRange = 1000
  var controller = RelativeWorkController(
    parent: rwActor, category: .rock, approachDirection: .init(0, -sign * sqrt(3) / 2, 0.5))
  let output = controller.step(input) { HullSweepSafety.validate($0, target: hull).clearance }
  let destination = try #require(output.workPosition)
  #expect(output.motionValidated && output.requiredClearance == 120)
  #expect(abs(destination.y - 20) < 1e-9 && abs(destination.x) < 1e-9)
  // An independently checked plane support gap, not the implementation's distance formula.
  let supportGap =
    destination.dot(target.pose.orientation.apply(target.surfaceNormal).unit) - input.playerRadius
  #expect(supportGap >= 120.99999999)
}

@Test(arguments: [0.0, 1e-12, Double.leastNonzeroMagnitude])
func relativeWorkTangentApproachNeverBypassesFiniteOrToolRangeGuards(cosine: Double) throws {
  let hull = try rwClearancePlaneHull()
  var target = rwTarget()
  target.surfaceNormal = .init(0, 0, 1)
  var input = rwInput(target: target)
  input.playerRadius = 10
  input.ship.position = .init(0, 0, 400)
  var controller = RelativeWorkController(
    parent: rwActor, category: .rock, approachDirection: .init(1, 0, cosine))
  var purposes: [RelativeWorkSweep.Purpose] = []
  let output = controller.step(input) {
    purposes.append($0.purpose)
    return HullSweepSafety.validate($0, target: hull).clearance
  }
  if cosine == 1e-12 {
    #expect(output.status == .blocked(.toolRange))
    #expect(purposes == [.work, .braking])
    #expect(output.validatedSweep?.purpose == .braking)
  } else {
    #expect(output.status == .blocked(.invalidInput))
    #expect(purposes == (cosine == 0 ? [] : [.work]))
    #expect(!output.motionValidated)
  }
  #expect(output.validatedSweep?.purpose != .work)
  #expect(!output.transitions.contains(.selectTool(.miningLaser)))
}

private func rwFiniteRockApproachHulls() throws -> (target: PreparedHull, player: PreparedHull) {
  // The retained G12 failure's finite octahedral target dimensions, without a broad plane.
  let target = try PreparedHull(
    mesh: Mesh(
      vertices: [
        .init(0, 48.85951709870832, 0), .init(-45.805797280039044, 0, 0),
        .init(0, 0, -45.805797280039044), .init(45.805797280039044, 0, 0),
        .init(0, 0, 45.805797280039044), .init(0, -40.71626424892359, 0),
      ],
      faces: [
        [0, 2, 1], [0, 3, 2], [0, 4, 3], [0, 1, 4],
        [5, 1, 2], [5, 2, 3], [5, 3, 4], [5, 4, 1],
      ], preserveWinding: true))
  // A closed narrow hull puts its longitudinal support near the enclosing radius.
  let depth = sqrt(69.0 * 69 - 2)
  let player = try PreparedHull(
    mesh: Mesh(
      vertices: [
        .init(-1, -1, -depth), .init(1, -1, -depth),
        .init(1, 1, -depth), .init(-1, 1, -depth),
        .init(-1, -1, depth), .init(1, -1, depth),
        .init(1, 1, depth), .init(-1, 1, depth),
      ],
      faces: [
        [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
        [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
      ], preserveWinding: true))
  return (target, player)
}

@Test(arguments: [0.02, 0.05, 0.1])
func relativeWorkStationaryNearHoldConvergesWithoutCrossingItsWorkPoint(delta: Double) throws {
  let hulls = try rwFiniteRockApproachHulls()
  var target = rwTarget(wreck: nil)
  target.surfacePoint = .init(0, 0, -45.805797280039044)
  var input = rwInput(target: target)
  input.playerRadius = 69
  input.limits = .init(acceleration: 216, speed: 576, pitchRate: 1, yawRate: 1, rollRate: 1)
  input.delta = delta
  let workZ = target.surfacePoint.z - 208
  input.ship.position = .init(0, 0, workZ - 20)
  var controller = RelativeWorkController(parent: rwActor, category: .rock)
  var previousError = 20.0
  var last: RelativeWorkOutput?
  for _ in 0..<Int((10 / delta).rounded()) {
    let output = rwTick(&controller, &input) {
      HullSweepSafety.validate($0, target: hulls.target, player: hulls.player).clearance
    }
    try #require(output.motionValidated)
    #expect(output.requiredClearance == 138)
    let error = workZ - input.ship.position.z
    // The old underdamped pair crosses the waypoint even from this unsaturated rest state.
    #expect(error >= -1e-8 && error <= previousError + 1e-8)
    #expect(input.velocity.z >= -1e-8)
    previousError = error
    last = output
  }
  let final = try #require(last)
  #expect(final.status == .holding && final.relativeSpeed < 0.01)
  #expect(previousError < 0.01)
}

@Test func relativeWorkRotatingFiniteRockRetainsClearanceWhileApproachMomentumSettles() throws {
  let hulls = try rwFiniteRockApproachHulls()
  var target = rwTarget(wreck: nil)
  target.surfacePoint = .init(0, 0, -45.805797280039044)
  target.angularVelocity = .init(0, 0.04, 0)
  var input = rwInput(target: target)
  input.playerRadius = 69
  input.limits = .init(acceleration: 216, speed: 576, pitchRate: 1, yawRate: 1, rollRate: 1)
  input.delta = 0.05
  input.ship.position = target.surfacePoint + Vector3(0, 0, -1000)
  var controller = RelativeWorkController(parent: rwActor, category: .rock)
  var heldFrames = 0
  var minimumGap = Double.infinity
  for _ in 0..<400 {
    let output = rwTick(&controller, &input) {
      let result = HullSweepSafety.validate($0, target: hulls.target, player: hulls.player)
      if let gap = result.minimumSampledClearance { minimumGap = min(minimumGap, gap) }
      return result.clearance
    }
    try #require(output.motionValidated)
    #expect(output.requiredClearance == 138)
    #expect(output.velocity.length <= input.limits.speed + 1e-8)
    #expect(input.target?.angularVelocity == target.angularVelocity)
    if output.status == .holding { heldFrames += 1 }
    if heldFrames >= 30 { break }
  }
  #expect(controller.status == .holding && heldFrames >= 30)
  #expect(minimumGap >= 138 && minimumGap.isFinite)
  #expect((try #require(input.target)).pose.orientation != target.pose.orientation)
}
