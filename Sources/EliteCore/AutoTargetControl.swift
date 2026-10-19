import Foundation

public struct Basis3: Sendable, Equatable, Codable {
  public var x = Vector3(1, 0, 0)
  public var y = Vector3(0, 1, 0)
  public var z = Vector3(0, 0, 1)
  public init() {}
  public func apply(_ v: Vector3) -> Vector3 { x * v.x + y * v.y + z * v.z }
  mutating func rotate(pitch: Double, roll: Double, yaw: Double) {
    x = x.rotated(pitch: pitch, roll: roll, yaw: yaw)
    y = y.rotated(pitch: pitch, roll: roll, yaw: yaw)
    z = z.rotated(pitch: pitch, roll: roll, yaw: yaw)
  }
}

extension Vector3 {
  var unit: Vector3 { length > 1e-9 ? self * (1 / length) : .init(0, 0, 0) }
  func limited(to maximum: Double) -> Vector3 { length > maximum ? unit * maximum : self }
}

extension SpaceBody {
  public func modelVector(_ v: Vector3) -> Vector3 {
    orientation.apply(v.rotated(pitch: hull == .station ? 0 : rotation * 0.4, roll: rotation))
  }
  private var nativePort: NativeStationGeometry.Port? {
    nativeStationIdentity.flatMap { NativeStationSource.binding(for: $0)?.geometry.docking }
  }
  public var entrancePosition: Vector3 {
    position + modelVector(nativePort?.center ?? MainStationGeometry.docking.center)
  }
  public var entranceNormal: Vector3 {
    modelVector(nativePort?.outward ?? MainStationGeometry.docking.outward)
  }
  public var entranceUp: Vector3 { modelVector(nativePort?.up ?? MainStationGeometry.docking.up) }
  var stationClearanceRadius: Double {
    guard let identity = nativeStationIdentity,
      let source = NativeStationSource.binding(for: identity)
    else { return 400 }
    return (source.geometry.mesh.vertices.map(\.length).max() ?? .infinity) + 400
  }
  var stationApproachDistance: Double {
    nativeStationIdentity == nil ? 1000 : stationClearanceRadius + 1000
  }
}

enum StationDefencePhase: Sendable, Equatable { case approach, defending, returning }

public struct AutoTargetControl: Sendable {
  private(set) var stationDefencePhase = StationDefencePhase.approach
  public private(set) var targetID: Int?
  public private(set) var targetActor: ActorIdentity?
  public private(set) var status = "OFF"
  public private(set) var ready = false
  public private(set) var finalApproach = false
  public private(set) var velocity = Vector3(0, 0, 0)
  public private(set) var rollRate = 0.0
  public private(set) var positionError = 0.0
  public private(set) var facingError = 0.0
  public private(set) var phaseError = 0.0
  public private(set) var rateError = 0.0
  public private(set) var manualEngagement = false
  private var previousAim: Vector3?
  private var previousDelta = 0.0
  private var stationStaged = false
  private(set) var validatedMovingEntry = false
  private var visited: Set<Int> = []
  private var membership: Set<Int> = []
  private var cycleSignature = ""
  private var cycleOrigin: ActorIdentity?
  private var remaining: [Int] = []
  public init() {}
  public mutating func disengage() {
    targetID = nil
    targetActor = nil
    manualEngagement = false
    previousAim = nil
    ready = false
    finalApproach = false
    stationStaged = false
    validatedMovingEntry = false
    stationDefencePhase = .approach
    velocity = .init(0, 0, 0)
    rollRate = 0
    status = "OFF"
  }
  mutating func cycle(
    _ eligible: [SpaceBody], frontIDs: Set<Int>, signature: String, manualEngagement: Bool = false,
    origin: ActorIdentity? = nil
  ) {
    // Scene numbers, including station zero, identify different actors on a new visit.
    // Keep same-visit cycling history, but never carry visited numbers into another origin.
    if cycleOrigin != origin {
      cycleOrigin = origin
      visited.removeAll(keepingCapacity: true)
      membership.removeAll(keepingCapacity: true)
      remaining.removeAll(keepingCapacity: true)
      cycleSignature = ""
    }
    let ids = Set(eligible.map(\.id))
    let ordered = eligible.sorted { a, b in
      func group(_ body: SpaceBody) -> Int {
        if body.hull == .station { return 2 }
        return frontIDs.contains(body.id) ? 0 : 1
      }
      if group(a) != group(b) { return group(a) < group(b) }
      if a.position.length != b.position.length { return a.position.length < b.position.length }
      return a.id < b.id
    }.map(\.id)
    // Positions can move throughout a cycle. Membership/tier/viewport changes reconcile
    // only unvisited targets; a completed cycle takes a fresh visibility snapshot.
    visited.formIntersection(ids)
    if membership != ids || cycleSignature != signature {
      membership = ids
      cycleSignature = signature
      remaining = ordered.filter { !visited.contains($0) }
    }
    if remaining.isEmpty {
      visited = []
      remaining = ordered
    }
    guard !remaining.isEmpty else {
      disengage()
      status = "NO TARGETS"
      return
    }
    self.manualEngagement = manualEngagement
    previousAim = nil
    targetID = remaining.removeFirst()
    targetActor = eligible.first { $0.id == targetID }?.physical?.identity
    if let targetID { visited.insert(targetID) }
    ready = false
    finalApproach = false
    stationStaged = false
    validatedMovingEntry = false
    stationDefencePhase = .approach
    velocity = .init(0, 0, 0)
    status = "FACING TARGET"
  }

  static let stationStagingTolerance = 40.0
  static let stationEntryStepReserve = 0.1

  /// Standalone callers retain the original controller policy. Runtime supplies actual hull limits.
  static let policyLimits = RelativeWorkLimits(
    acceleration: 240, speed: 144, pitchRate: 0.8, yawRate: 0.8, rollRate: 1)

  mutating func steer(
    target: SpaceBody, delta: Double, aimTolerance: Double = 0.001,
    limits: RelativeWorkLimits = Self.policyLimits, defence: StationAutoGuidance? = nil
  ) -> (
    pitch: Double, yaw: Double, roll: Double?
  ) {
    guard delta.isFinite, delta > 0,
      [limits.acceleration, limits.speed, limits.pitchRate, limits.yawRate, limits.rollRate]
        .allSatisfy({ $0.isFinite && $0 > 0 })
    else { return (0, 0, target.hull == .station ? 0 : nil) }
    let pitchLimit = min(Self.policyLimits.pitchRate, limits.pitchRate)
    let yawLimit = min(Self.policyLimits.yawRate, limits.yawRate)
    let station = target.hull == .station
    let inwardSpeed = max(0, velocity.dot(target.position.unit))
    let stopping = inwardSpeed * inwardSpeed / (2 * limits.acceleration) + inwardSpeed * delta
    let clearance = max(target.stationClearanceRadius, defence?.clearanceRadius ?? 0)
    let canInterrupt =
      station && defence?.interruptionAllowed == true
      && target.position.length > clearance + stopping
    let movingEntry =
      station && defence?.movingEntryAllowed == true
      && defence?.hazard == .active && defence?.joinedIncoming != true
    let brakingEntry =
      !movingEntry && validatedMovingEntry && delta <= Self.stationEntryStepReserve
      && station && defence?.entryBrakingAllowed == true
      && defence?.hazard == .active && defence?.joinedIncoming != true
      && canInterrupt && velocity.dot(target.entranceNormal) < 0
    if movingEntry || brakingEntry {
      // Fresh source/geometry/kinematics permit immediate finite final-course motion.
      // Native movement still owns the swept crossing and any docking receipt.
      stationDefencePhase = .returning
      stationStaged = true
      finalApproach = movingEntry
      ready = false
    }
    if movingEntry {
      validatedMovingEntry = true
    } else if !brakingEntry {
      validatedMovingEntry = false
    }
    let shouldInterrupt =
      station && defence?.hazard == .active && canInterrupt && !movingEntry && !brakingEntry
      && stationDefencePhase != .defending
    if shouldInterrupt {
      ready = false
      finalApproach = false
      stationStaged = false
      stationDefencePhase = .defending
    } else if station && stationDefencePhase == .defending {
      let goal = target.entrancePosition + target.entranceNormal * target.stationApproachDistance
      positionError = goal.length
      let waypoint = approachWaypoint(target, goal: goal, clearance: clearance)
      let speed = velocity.length
      let braking = speed * speed / (2 * limits.acceleration) + speed * delta
      let handover =
        defence?.hazard != .active && defence?.handoverAllowed == true && canInterrupt
        && waypoint == goal && waypoint.length <= braking + Self.stationStagingTolerance
      if defence?.hazard == .clear || handover { stationDefencePhase = .returning }
    }
    let canStage =
      movingEntry || brakingEntry
      || (stationDefencePhase != .defending
        && (defence == nil || defence?.hazard == .clear
          || (stationDefencePhase == .returning && defence?.handoverAllowed == true)))
    if stationDefencePhase == .returning && !canStage && canInterrupt {
      // Unknown exterior observations revoke acquisition, not the native doorway safety rules.
      ready = false
      finalApproach = false
      stationStaged = false
    }
    var aim: Vector3
    if station {
      let goal = target.entrancePosition + target.entranceNormal * target.stationApproachDistance
      positionError = goal.length
      // Finish the forward journey before turning to the entrance axis. The
      // smaller staging radius also keeps final lateral correction inside the door.
      if canStage && !finalApproach && positionError < 12 && velocity.length < 8 {
        stationStaged = true
        if defence == nil || defence?.hazard == .clear { stationDefencePhase = .approach }
      }
      aim =
        stationStaged || finalApproach
        ? target.entranceNormal * -1 : approachWaypoint(target, goal: goal, clearance: clearance)
    } else {
      aim = target.position
    }
    let stationFacing = hypot(atan2(aim.y, hypot(aim.x, aim.z)), atan2(aim.x, aim.z))
    let defensiveSteering =
      station && !stationStaged && !finalApproach
      && ((stationDefencePhase == .defending && canInterrupt)
        || target.position.length > target.stationClearanceRadius + target.stationApproachDistance)
    let guidance =
      defensiveSteering && stationDefencePhase != .returning && defence?.hasManeuver == true
      ? defence : nil
    let shieldAim =
      guidance?.protectFrontShield == true
      ? (guidance?.aim.flatMap { $0.finite && $0.length > 0 ? $0 * -1 : nil }
        ?? guidance?.transitGoal.map { approachWaypoint(target, goal: $0, clearance: clearance) })
      : nil
    let trackingResponse =
      shieldAim == nil && guidance?.aim.map { $0.finite && $0.length > 0 } == true
    if let shieldAim {
      // A cover waypoint can still face the attacker. Turn the weak front bank away
      // from its current source; translation independently keeps the clearance route.
      aim = shieldAim
    } else if let defensiveAim = guidance?.aim, trackingResponse {
      aim = defensiveAim
    }
    let pitchAngle = atan2(aim.y, hypot(aim.x, aim.z))
    let yawAngle = atan2(aim.x, aim.z)
    facingError = station ? stationFacing : hypot(pitchAngle, yawAngle)
    var pitch = max(-pitchLimit, min(pitchLimit, pitchAngle * 1.8))
    var yaw = max(-yawLimit, min(yawLimit, yawAngle * 1.8))
    guard station else {
      let motion = targetMotion(aim, delta: delta)
      status = facingError < aimTolerance ? "TRACKING TARGET" : "FACING TARGET"
      return (
        max(-pitchLimit, min(pitchLimit, pitchAngle * 4 + motion.pitch)),
        max(-yawLimit, min(yawLimit, yawAngle * 4 + motion.yaw)), nil
      )
    }
    if trackingResponse {
      // The same camera-corrected bearing tracker used for ordinary moving targets.
      let motion = targetMotion(aim, delta: delta)
      pitch = max(-pitchLimit, min(pitchLimit, pitchAngle * 4 + motion.pitch))
      yaw = max(-yawLimit, min(yawLimit, yawAngle * 4 + motion.yaw))
    } else {
      resetTargetMotion()
    }
    rollRate = max(-limits.rollRate, min(limits.rollRate, rollRate))
    let previousRate = rollRate
    alignStation(
      target, delta: delta, limits: limits, defence: guidance,
      transitGoal: stationDefencePhase == .defending && canInterrupt ? guidance?.transitGoal : nil,
      canStage: canStage, clearance: clearance, brakingEntry: brakingEntry)
    return (pitch, yaw, (previousRate + rollRate) / 2)
  }

  mutating func resetTargetMotion() {
    previousAim = nil
    previousDelta = 0
  }

  private mutating func targetMotion(_ aim: Vector3, delta: Double) -> (pitch: Double, yaw: Double)
  {
    defer {
      previousAim = aim.unit
      previousDelta = delta
    }
    guard let previousAim, previousDelta > 0 else { return (0, 0) }
    let pitch =
      atan2(aim.y, hypot(aim.x, aim.z)) - atan2(previousAim.y, hypot(previousAim.x, previousAim.z))
    var yaw = atan2(aim.x, aim.z) - atan2(previousAim.x, previousAim.z)
    if yaw > .pi { yaw -= 2 * .pi }
    if yaw < -.pi { yaw += 2 * .pi }
    return (pitch / previousDelta, yaw / previousDelta)
  }

  mutating func setApproachVelocity(_ value: Vector3) { velocity = value }

  private mutating func alignStation(
    _ target: SpaceBody, delta: Double, limits: RelativeWorkLimits, defence: StationAutoGuidance?,
    transitGoal: Vector3?, canStage: Bool, clearance: Double, brakingEntry: Bool = false
  ) {
    let acceleration = limits.acceleration
    let maximumRoll = min(Self.policyLimits.rollRate, limits.rollRate)
    phaseError = atan2(target.entranceUp.x, target.entranceUp.y)
    let matchRate = -target.rotationRate * target.orientation.z.z
    let spinFeasible = abs(matchRate) <= maximumRoll
    if !spinFeasible && (stationStaged || finalApproach) {
      finalApproach = false
      stationStaged = true
    }
    let acquiringSpin =
      stationStaged || finalApproach
      || (stationDefencePhase == .returning && canStage && spinFeasible)
    let command =
      acquiringSpin
      ? max(-maximumRoll, min(maximumRoll, matchRate + phaseError * 1.8)) : 0
    rollRate += max(-0.8 * delta, min(0.8 * delta, command - rollRate))
    rateError = abs(rollRate - matchRate)
    let goal = target.entrancePosition + target.entranceNormal * target.stationApproachDistance
    positionError = goal.length
    ready =
      !brakingEntry && canStage && spinFeasible && stationStaged
      && positionError < Self.stationStagingTolerance
      && facingError < 0.02
      && abs(phaseError) < 0.03
      && rateError < 0.02 && velocity.length < 1
    if ready { finalApproach = true }
    var desired: Vector3
    var finalEnvelope: Double?
    if finalApproach {
      let motion = finalVelocity(target, delta: delta, limits: limits)
      desired = motion.velocity
      finalEnvelope = motion.envelope
    } else if stationStaged {
      // Hold at the safe external goal while facing the doorway and matching spin.
      desired = .init(0, 0, 0)
      if brakingEntry {
        status = "BRAKING FOR CLEAR DOCKING COURSE"
      } else if !spinFeasible {
        status = "STATION SPIN EXCEEDS HULL LIMIT"
      } else {
        status = facingError > 0.02 ? "ALIGNING" : "MATCHING SPIN"
      }
    } else {
      // Existing cruise momentum brakes under the acceleration limit. Once the
      // waypoint is ahead, thrust follows the same bearing as the forward view.
      let destination = transitGoal ?? goal
      let waypoint = approachWaypoint(target, goal: destination, clearance: clearance)
      // A cover-route detour is a through waypoint, not a place to stop under fire.
      // Clearance braking still applies below, and the real destination still brakes normally.
      let brakingDistance = transitGoal != nil ? destination.length : waypoint.length
      let cruiseSpeed = Self.approachCruiseSpeed(
        distance: brakingDistance, acceleration: acceleration, delta: delta,
        maximumSpeed: limits.speed)
      desired =
        facingError < 0.12 || defence != nil || stationDefencePhase == .defending
        ? waypoint.unit * cruiseSpeed : .init(0, 0, 0)
      status =
        stationDefencePhase == .returning
        ? "RETURNING TO APPROACH"
        : (stationDefencePhase == .defending || defence != nil
          ? "DEFENDING APPROACH" : "APPROACHING")
      // The cover transit already owns an evasive route. Adding the staging-point
      // correction here would pull it back into the same exposed equilibrium.
      if transitGoal == nil, let evasion = defence?.lateralVelocity, evasion.finite {
        desired = desired + evasion
      }
    }
    let safeDesired =
      finalApproach
      ? desired
      : stationClearanceVelocity(
        target, desired: desired, acceleration: acceleration,
        delta: delta, clearance: clearance)
    let maximumSpeed =
      stationStaged && !finalApproach ? min(Self.policyLimits.speed, limits.speed) : limits.speed
    let requestedThrust = acceleration * delta
    let thrustBudget = requestedThrust.isFinite ? requestedThrust : Double.greatestFiniteMagnitude
    // One thrust budget covers approach, braking and station avoidance. Existing
    // overspeed coasts down within that budget rather than projecting velocity instantly.
    let speed = velocity.length
    let overspeed =
      finalEnvelope.map {
        speed > $0 + max(speed.ulp, $0.ulp) * 16
      } ?? false
    let requested =
      overspeed
      ? velocity.unit * max(0, speed - thrustBudget) : safeDesired.limited(to: maximumSpeed)
    velocity = velocity + (requested - velocity).limited(to: thrustBudget)
  }

  /// Reserve one complete step and the stopping distance before the current external waypoint.
  static func approachCruiseSpeed(
    distance: Double, acceleration: Double, delta: Double, maximumSpeed: Double
  ) -> Double {
    guard [distance, acceleration, delta, maximumSpeed].allSatisfy({ $0.isFinite && $0 > 0 })
    else { return 0 }
    let available = acceleration
    // Factor the square root; 2*a*d could overflow even when its square root is finite.
    let root = sqrt(2 * available) * sqrt(distance)
    guard delta <= 1 || available <= Double.greatestFiniteMagnitude / delta else { return 0 }
    let reaction = available * delta
    // Rationalize sqrt(reaction² + 2*a*d) - reaction without squaring or adding two large values.
    let halfDenominator = hypot(root, reaction) * 0.5 + reaction * 0.5
    guard halfDenominator.isFinite && halfDenominator > 0 else { return 0 }
    let stoppingSpeed = (root * 0.5) * (root / halfDenominator)
    return min(maximumSpeed, distance * 0.8, stoppingSpeed)
  }
  /// Full-step reserve plus native hull braking to the conservative near-door speed.
  /// At or below that terminal speed no further deceleration is needed at the boundary.
  static func finalCruiseSpeed(
    distance: Double, delta: Double, acceleration: Double, maximumSpeed: Double
  ) -> Double {
    guard distance.isFinite, delta.isFinite, delta > 0,
      acceleration.isFinite, acceleration > 0, maximumSpeed.isFinite, maximumSpeed > 0
    else { return 0 }
    guard distance >= 0 else { return 0 }
    let terminal = min(48, maximumSpeed)
    guard distance > 200 else { return terminal }
    let available = distance - 200
    let root = sqrt(acceleration) * sqrt(2) * sqrt(available)
    let reaction = acceleration * delta
    let combined = hypot(root, terminal)
    let halfDenominator = hypot(combined, reaction) * 0.5 + reaction * 0.5
    guard combined.isFinite, reaction.isFinite, halfDenominator.isFinite,
      halfDenominator > 0
    else { return terminal }
    // Rationalize sqrt(reaction² + terminal² + 2*a*d) - reaction without squaring.
    let bounded = (combined * 0.5) * (combined / halfDenominator)
    guard bounded.isFinite else { return terminal }
    return min(maximumSpeed, max(terminal, bounded))
  }

  private mutating func finalVelocity(
    _ target: SpaceBody, delta: Double, limits: RelativeWorkLimits
  ) -> (velocity: Vector3, envelope: Double) {
    let door = target.entrancePosition
    let normal = target.entranceNormal
    let distance = -door.dot(normal)
    let lateral = door - normal * door.dot(normal)
    let aligned =
      facingError < 0.03 && abs(phaseError) < 0.08 && rateError < 0.06 && lateral.length < 15
    if !aligned {
      status = "HOLDING FOR ALIGNMENT"
      let envelope = min(48, limits.speed)
      return ((lateral * 1.8 + normal * (distance < 200 ? 40 : 0)).limited(to: envelope), envelope)
    }
    status = "FINAL APPROACH"
    let envelope = Self.finalCruiseSpeed(
      distance: distance, delta: delta, acceleration: limits.acceleration,
      maximumSpeed: limits.speed)
    return ((lateral * 1.8 - normal * envelope).limited(to: envelope), envelope)
  }
  private func approachWaypoint(_ target: SpaceBody, goal: Vector3, clearance: Double) -> Vector3 {
    let closest =
      target.position - goal * max(0, min(1, target.position.dot(goal) / max(1, goal.dot(goal))))
    guard closest.length < clearance && goal.length > Self.stationStagingTolerance else {
      return goal
    }
    let radial = target.position.unit * -1
    // Avoidance belongs to the station's fixed entrance axis, not its spinning
    // doorway phase. A rotating detour can outrun the player's transit speed.
    var tangent = target.orientation.x
    if abs(tangent.dot(radial)) > 0.8 { tangent = target.orientation.y }
    return target.position + (radial + tangent * 0.8).unit * (clearance * 1.5)
  }
  private mutating func stationClearanceVelocity(
    _ target: SpaceBody, desired: Vector3, acceleration: Double, delta: Double, clearance: Double
  ) -> Vector3 {
    let distance = target.position.length
    let outward = target.position.unit * -1
    let inwardSpeed = max(0, -velocity.dot(outward))
    let stoppingDistance = inwardSpeed * inwardSpeed / (2 * acceleration) + inwardSpeed * delta
    if distance < clearance + stoppingDistance {
      // If engagement starts too close to stop, apply the strongest legal outward
      // thrust. Avoidance cannot erase momentum or promise physically impossible clearance.
      status = "BRAKING FOR CLEARANCE"
      return outward * 80
    }
    if (target.position - desired * delta).length < clearance {
      return desired - outward * min(0, desired.dot(outward))
    }
    return desired
  }

  mutating func rotateVelocity(pitch: Double, roll: Double, yaw: Double) {
    velocity = velocity.rotated(pitch: pitch, roll: roll, yaw: yaw)
    previousAim = previousAim?.rotated(pitch: pitch, roll: roll, yaw: yaw)
  }
}

extension Game {
  public var autoTargetBody: SpaceBody? {
    bodies.first {
      $0.id == autoPilot.targetID && $0.energy > 0
        && (autoPilot.targetActor == nil || $0.physical?.identity == autoPilot.targetActor)
    }
  }
  public var autoHUDLines: [String] {
    guard targetingEnabled || dockingComputer || autoPilot.manualEngagement else { return [] }
    if let work = workGuidance {
      return [
        "AUTO: " + work.status, "F FILTER: " + workTargetFilter.label.uppercased() + " / Q OFF",
      ]
    }
    if workBraking != nil { return ["AUTO: BRAKING AFTER COLLECTION / Q RELEASE HOLD"] }
    guard let target = autoTargetBody else {
      return [
        "AUTO: TAB SELECT TARGET / Q RELEASE HOLD",
        "F FILTER: " + workTargetFilter.label.uppercased(),
      ]
    }
    return [
      "AUTO: \(information(for: target)?.identifier ?? "Target #\(target.id)") - \(autoPilot.status)"
    ]
  }
  mutating func cancelAutoTarget() {
    interruptFlightTool()
    stationAutoDefence = nil
    let stationActive = autoTargetBody?.hull == .station
    let stationVelocity =
      stationActive
      ? commander.flightSimulation.pose.shipVector(flightWorldVelocity) : nil
    let preserveMomentum = workGuidance != nil || workBraking != nil || manualResidualFlight
    releaseWorkGuidance()
    let remainingVelocity = autoPilot.velocity
    autoPilot.disengage()
    if let stationVelocity {
      speed = 0
      manualResidualFlight = true
      autoPilot.setApproachVelocity(stationVelocity)
    } else if preserveMomentum {
      autoPilot.setApproachVelocity(remainingVelocity)
    }
    dockingComputer = false
  }
  mutating func cycleAutoTarget() {
    interruptFlightTool()
    guard !playerEMPDisabled else {
      notify("NO ELECTRICAL POWER - AUTO FLIGHT UNAVAILABLE")
      return
    }
    targetPanelScroll = 0
    guard !docked, screen.isFlight else { return }
    guard let tier = commander.targetingTier else {
      notify("FIT A TARGETING COMPUTER")
      return
    }
    stationAutoDefence = nil
    let initialVelocity = flightWorldVelocity
    releaseWorkGuidance()
    ensurePhysicalActors()
    guard let context = gameplayContext() else { return }
    let layout = CockpitLayout(game: self, width: viewportWidth, height: viewportHeight)
    let frontIDs = Set(
      bodies.filter {
        Display.visibleInFront($0, game: self, layout: layout)
      }.map(\.id))
    let candidates = bodies.compactMap {
      workTargetCandidate(for: $0, context: context, frontVisible: frontIDs.contains($0.id))
    }
    let choices = WorkTargetSelection.ordered(
      candidates, filter: workTargetFilter, system: context.system, visit: context.visit,
      capabilities: workTargetCapabilities)
    let identities = Set(choices.map { $0.candidate.identity })
    let eligible = bodies.filter { $0.physical.map { identities.contains($0.identity) } == true }
    let signature =
      "\(tier.rawValue):\(workTargetFilter.label):\(Int(viewportWidth)):\(Int(viewportHeight))"
    autoPilot.cycle(
      eligible, frontIDs: frontIDs, signature: signature, manualEngagement: !targetingEnabled,
      origin: context.player.identity)
    if manualResidualFlight {
      speed = 0
      autoPilot.setApproachVelocity(commander.flightSimulation.pose.shipVector(initialVelocity))
    }
    weaponsTargetID = autoPilot.targetID
    screen = .front
    dockingComputer = autoTargetBody?.hull == .station
    if let body = autoTargetBody,
      let choice = choices.first(where: { $0.candidate.identity == body.physical?.identity }),
      case .hold = choice.mode
    {
      beginWorkGuidance(body: body, mode: choice.mode, velocity: initialVelocity)
    } else if let body = autoTargetBody,
      let choice = choices.first(where: { $0.candidate.identity == body.physical?.identity }),
      case .autoScoop = choice.mode
    {
      beginWorkGuidance(body: body, mode: choice.mode, velocity: initialVelocity)
    } else if dockingComputer {
      beginStationGuidance(velocity: initialVelocity)
      notify("AUTO DOCKING ENGAGED")
    } else if autoTargetBody != nil {
      notify("AUTO TARGETING ENGAGED")
    } else {
      let stationOnly = bodies.contains { $0.hull == .station && $0.energy > 0 } && tier < .docking
      if workTargetFilter != .ships,
        let refusal = candidates.compactMap({ candidate -> WorkTargetRefusal? in
          guard case .recoverable = candidate.kind,
            case .refused(let reason) = WorkTargetSelection.evaluate(
              candidate, system: context.system,
              visit: context.visit, capabilities: workTargetCapabilities)
          else { return nil }
          return reason
        }).first
      {
        notify(workRefusalMessage(refusal))
      } else {
        notify(stationOnly ? "DOCKING TARGETING TIER REQUIRED FOR STATIONS" : "NO ELIGIBLE TARGETS")
      }
    }
  }
  private mutating func beginStationGuidance(velocity: Vector3) {
    spin.stop(immediate: true)
    manualResidualFlight = false
    autoPilot.setApproachVelocity(commander.flightSimulation.pose.shipVector(velocity))
    speed = 0
  }
  mutating func applyAutoTarget(delta: Double, controls: Controls) {
    if workGuidance != nil || workBraking != nil {
      if controls.pitch != 0 || controls.yaw != 0 || controls.roll != 0 || controls.throttle != 0 {
        cancelAutoTarget()
        notify("WORK GUIDANCE CANCELLED - MANUAL CONTROL")
      } else {
        pitch = 0
        yaw = 0
        roll = 0
        return
      }
    }
    guard autoPilot.targetID != nil else { return }
    let station = autoTargetBody?.hull == .station
    let enabled =
      station
      ? commander.hasAutomaticDocking && (targetingEnabled || autoPilot.manualEngagement)
      : (targetingEnabled || autoPilot.manualEngagement)
    if !enabled
      || controls.pitch != 0 || controls.yaw != 0
      || controls.roll != 0 || ((station || manualResidualFlight) && controls.throttle != 0)
    {
      cancelAutoTarget()
      return
    }
    guard let target = autoTargetBody else {
      if let body = bodies.first(where: { $0.id == autoPilot.targetID }) {
        clearRemovedTarget(body)
      } else {
        cancelAutoTarget()
        weaponsTargetID = nil
        notify("TARGET LOST")
      }
      return
    }
    let previousPhase = autoPilot.status
    let focal = CockpitLayout(game: self, width: viewportWidth, height: viewportHeight).projection
      .focal
    let defence = station ? stationAutoGuidance(target: target) : nil
    if !station { stationAutoDefence = nil }
    let steering = autoPilot.steer(
      target: target, delta: delta, aimTolerance: 1.5 / focal, limits: workLimits, defence: defence)
    if station && previousPhase != autoPilot.status { notify("AUTO DOCKING: " + autoPilot.status) }
    pitch = steering.pitch
    yaw = steering.yaw
    if let ownedRoll = steering.roll {
      roll = ownedRoll
      speed = 0
    }
  }
}
