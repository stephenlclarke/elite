import Foundation

enum StationInertialIdentity: Hashable, Codable, Sendable {
  case main(NativeMainStationIdentity)
  case rrs(NativeStationIdentity)

  var system: SystemIdentity {
    switch self {
    case .main(let id): id.system
    case .rrs(let id): id.system
    }
  }
}

/// Separate from immutable source anchors. Only the live contact authority below writes
/// displacement/momentum; coast projection never rewrites authored station geometry.
struct NativeStationInertia: Equatable, Codable, Sendable {
  private enum Segment: String, Codable, Sendable {
    case impact, refusedStep
  }
  private let segment: Segment
  private let refusedStepDuration: Double
  let refusedMotionTime: Double
  let refusedSteps: UInt64
  let station: StationInertialIdentity
  private(set) var displacement: Vector3
  private(set) var momentum: Vector3
  private(set) var physicalTime: Double
  private(set) var contacts: UInt64
  private(set) var priorDisplacement: Vector3
  private(set) var priorMomentum: Vector3
  private(set) var priorTime: Double
  private(set) var impactTime: Double

  var velocity: Vector3 { momentum * (1 / AsteroidImpactPolicy.massKg(hull: .station)) }
  var previousVelocity: Vector3 {
    priorMomentum * (1 / AsteroidImpactPolicy.massKg(hull: .station))
  }
  private var impactOffset: Vector3 {
    priorDisplacement + previousVelocity * (impactTime - priorTime)
  }
  var valid: Bool {
    guard displacement.finite, displacement.length.isFinite, momentum.finite,
      momentum.length.isFinite,
      priorDisplacement.finite, priorDisplacement.length.isFinite, priorMomentum.finite,
      priorMomentum.length.isFinite,
      velocity.length <= AsteroidImpactPolicy.maximumSpeed,
      previousVelocity.length <= AsteroidImpactPolicy.maximumSpeed,
      physicalTime.isFinite, (0...1e12).contains(physicalTime),
      priorTime.isFinite, (0...physicalTime).contains(priorTime),
      impactTime.isFinite, (0...physicalTime).contains(impactTime),
      contacts < UInt64(Int64.max),
      refusedMotionTime.isFinite, (0...physicalTime).contains(refusedMotionTime),
      refusedSteps < UInt64(Int64.max),
      (refusedSteps == 0) == (refusedMotionTime == 0)
    else { return false }
    switch segment {
    case .impact:
      guard contacts > 0, refusedStepDuration == 0, impactTime >= priorTime,
        refusedMotionTime <= priorTime,
        contacts != 1
          || (priorDisplacement == .init(0, 0, 0)
            && priorMomentum == .init(0, 0, 0) && (priorTime == 0 || refusedSteps > 0))
      else { return false }
      let expected = impactOffset + velocity * (physicalTime - impactTime)
      return expected.finite && expected.length.isFinite && (displacement - expected).length < 1e-5
    case .refusedStep:
      if contacts == 0 {
        guard impactTime == 0, momentum == .init(0, 0, 0),
          priorMomentum == .init(0, 0, 0), displacement == .init(0, 0, 0),
          priorDisplacement == .init(0, 0, 0)
        else { return false }
      }
      // A refused integration retains motion, not elapsed displacement. The
      // physical event clock still advances; no impulse or contact is invented.
      return impactTime <= priorTime && physicalTime > priorTime
        && refusedStepDuration.isFinite && refusedStepDuration > 0 && refusedStepDuration <= 0.1
        && priorTime == physicalTime - refusedStepDuration
        && refusedSteps > 0 && refusedMotionTime >= physicalTime - priorTime
        && momentum == priorMomentum && displacement == priorDisplacement
    }
  }

  /// Retain one actual pre-impact segment for this step's doorway and collision consumers.
  func offset(at time: Double) -> Vector3? {
    guard valid, time.isFinite, time >= priorTime else { return nil }
    let value: Vector3
    switch segment {
    case .impact:
      value =
        time >= impactTime
        ? impactOffset + velocity * (time - impactTime)
        : priorDisplacement + previousVelocity * (time - priorTime)
    case .refusedStep:
      value = displacement + velocity * max(0, time - physicalTime)
    }
    return value.finite && value.length.isFinite ? value : nil
  }

  /// RRS spin follows admitted movement time as well. A refused interval must
  /// not rotate an unproved surface merely because the event clock advanced.
  fileprivate func motionTime(at time: Double) -> Double? {
    guard valid, time.isFinite, time >= priorTime else { return nil }
    let value: Double
    switch segment {
    case .impact:
      value = time - refusedMotionTime
    case .refusedStep:
      let previousRefusals = refusedMotionTime - (physicalTime - priorTime)
      value = priorTime - previousRefusals + max(0, time - physicalTime)
    }
    return value.isFinite && value >= 0 ? value : nil
  }

  fileprivate func sweepMargin(from start: Double, to end: Double) -> Double {
    let transition = segment == .impact ? impactTime : physicalTime
    guard end > start, transition > start, transition < end else { return 0 }
    let change = segment == .impact ? (velocity - previousVelocity).length : velocity.length
    return change * (transition - start) * (end - transition) / (end - start)
  }

  fileprivate init?(
    proof: StationContactTransfer, previous: NativeStationInertia?,
    sourcePosition: Vector3
  ) {
    let oldMomentum = previous?.momentum ?? .init(0, 0, 0)
    let oldVelocity = previous?.velocity ?? .init(0, 0, 0)
    guard previous == nil || previous?.station == proof.station,
      proof.physicalTime.isFinite, proof.physicalTime >= (previous?.physicalTime ?? 0),
      proof.impactTime.isFinite,
      proof.impactTime >= (previous?.physicalTime ?? 0), proof.impactTime <= proof.physicalTime,
      (oldVelocity - proof.previousVelocity).length < 1e-7,
      proof.finalPosition.finite, sourcePosition.finite,
      (previous?.contacts ?? 0) < UInt64(Int64.max) - 1
    else { return nil }
    segment = .impact
    refusedStepDuration = 0
    refusedMotionTime = previous?.refusedMotionTime ?? 0
    refusedSteps = previous?.refusedSteps ?? 0
    station = proof.station
    priorDisplacement = previous?.displacement ?? .init(0, 0, 0)
    priorMomentum = oldMomentum
    priorTime = previous?.physicalTime ?? 0
    impactTime = proof.impactTime
    momentum = oldMomentum + proof.impulse
    physicalTime = proof.physicalTime
    contacts = (previous?.contacts ?? 0) + 1
    displacement =
      priorDisplacement + oldVelocity * (impactTime - priorTime)
      + momentum * ((physicalTime - impactTime) / AsteroidImpactPolicy.massKg(hull: .station))
    guard valid, (velocity - proof.finalVelocity).length < 1e-7,
      (sourcePosition + displacement - proof.finalPosition).length < 1e-5
    else { return nil }
  }

  fileprivate init?(
    refusal: StationMotionRefusal, previous: NativeStationInertia?,
    sourcePosition: Vector3
  ) {
    if previous == nil {
      guard case .rrs = refusal.station else { return nil }
    }
    guard previous == nil || (previous?.valid == true && previous?.station == refusal.station),
      refusal.fromTime.isFinite, refusal.toTime.isFinite,
      refusal.fromTime >= (previous?.physicalTime ?? 0),
      refusal.toTime > refusal.fromTime,
      refusal.duration.isFinite, refusal.duration > 0, refusal.duration <= 0.1,
      refusal.fromTime == refusal.toTime - refusal.duration,
      (previous?.refusedSteps ?? 0) < UInt64(Int64.max) - 1
    else { return nil }
    let offset: Vector3
    if let previous {
      guard let retained = previous.offset(at: refusal.fromTime) else { return nil }
      offset = retained
    } else {
      offset = .init(0, 0, 0)
    }
    let oldVelocity = previous?.velocity ?? .init(0, 0, 0)
    guard (sourcePosition + offset - refusal.position).length < 1e-5,
      (oldVelocity - refusal.velocity).length < 1e-7
    else { return nil }
    segment = .refusedStep
    refusedStepDuration = refusal.duration
    refusedMotionTime = (previous?.refusedMotionTime ?? 0) + (refusal.toTime - refusal.fromTime)
    refusedSteps = (previous?.refusedSteps ?? 0) + 1
    station = refusal.station
    displacement = offset
    momentum = previous?.momentum ?? .init(0, 0, 0)
    physicalTime = refusal.toTime
    contacts = previous?.contacts ?? 0
    priorDisplacement = offset
    priorMomentum = momentum
    priorTime = refusal.fromTime
    impactTime = previous?.impactTime ?? 0
    guard valid else { return nil }
  }
}

extension NativeStationWorld {
  static var maximumInertialStations: Int {
    NativeMainStationIdentity.maximumCount + NativeStationLedger.recordLimit
  }

  func inertia(for station: StationInertialIdentity) -> NativeStationInertia? {
    stationInertia.first { $0.station == station }
  }

  func motionTime(for station: StationInertialIdentity, at time: Double) -> Double? {
    guard time.isFinite, time >= 0 else { return nil }
    guard let motion = inertia(for: station) else { return time }
    return motion.motionTime(at: time)
  }

  func currentOrientation(for station: NativeStationIdentity, at time: Double) -> Basis3? {
    guard let saved = pose(for: station), let phase = motionTime(for: .rrs(station), at: time)
    else {
      return nil
    }
    return saved.orientation(at: phase)
  }

  func sourcePosition(for station: StationInertialIdentity) -> Vector3? {
    switch station {
    case .main(let identity):
      guard mainStations.contains(identity), identity.world == ledger.world else { return nil }
      return .init(0, 0, 0)
    case .rrs(let identity):
      guard identity.world == ledger.world else { return nil }
      return pose(for: identity)?.position
    }
  }

  func currentPosition(for station: StationInertialIdentity, at time: Double) -> Vector3? {
    guard let source = sourcePosition(for: station) else { return nil }
    guard let state = inertia(for: station) else { return source }
    return state.offset(at: time).map { source + $0 }
  }

  func stationSweepMargin(_ station: StationInertialIdentity, from start: Double, to end: Double)
    -> Double
  {
    guard let motion = inertia(for: station), end > start else { return 0 }
    return motion.sweepMargin(from: start, to: end)
  }

  var inertiaIsValid: Bool {
    stationInertia.count <= Self.maximumInertialStations
      && Set(stationInertia.map(\.station)).count == stationInertia.count
      && stationInertia.allSatisfy { $0.valid && sourcePosition(for: $0.station) != nil }
  }
}

extension Game {
  func stationInertialIdentity(for body: SpaceBody) -> StationInertialIdentity? {
    guard body.hull == .station, body.energy > 0, let physical = body.physical,
      let world = commander.nativeStations, world.valid,
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit
    else { return nil }
    if let id = body.nativeStationIdentity, nativeStationBodyIsCurrent(body) { return .rrs(id) }
    guard body.id == 0, let anchors = commander.flightSimulation.anchors,
      physical.identity == anchors.station.identity,
      bodies.filter({ $0.id == 0 }).count == 1,
      let id = world.mainStations.first(where: { $0.system == systemIdentity }),
      let resource = commander.scriptState.stationResources[id.key],
      resource.identity == id.resource, !resource.destroyed
    else { return nil }
    return .main(id)
  }

  func nativeStationVelocity(_ body: SpaceBody) -> Vector3 {
    guard commander.nativeStations?.stationInertia.isEmpty == false else { return .init(0, 0, 0) }
    guard let id = stationInertialIdentity(for: body) else { return .init(0, 0, 0) }
    return commander.nativeStations?.inertia(for: id)?.velocity ?? .init(0, 0, 0)
  }

  func nativeStationRelativeEntrySpeed(_ body: SpaceBody) -> Double {
    guard commander.nativeStations?.stationInertia.isEmpty == false,
      let identity = stationInertialIdentity(for: body),
      let motion = commander.nativeStations?.inertia(for: identity)
    else { return max(speed * 18, autoPilot.velocity.length) }
    return (flightWorldVelocity - motion.velocity).length
  }

  /// Only current native bodies can consume owned coast projection. Either the prior
  /// or already-current position must match; this cannot normalize an arbitrary teleport.
  mutating func synchronizeNativeStationInertia(
    at time: Double, advancingFrom oldTime: Double? = nil
  )
    -> Bool
  {
    guard let world = commander.nativeStations else { return true }
    guard world.stationInertia.contains(where: { $0.station.system == systemIdentity }) else {
      return true
    }
    guard world.valid, time.isFinite, time >= 0 else { return false }
    var changes: [(index: Int, position: Vector3, velocity: Vector3)] = []
    for index in bodies.indices where bodies[index].hull == .station {
      let body = bodies[index]
      guard let id = stationInertialIdentity(for: body), let state = world.inertia(for: id) else {
        continue
      }
      guard let point = world.currentPosition(for: id, at: time),
        let physical = body.physical, (physical.velocity - state.velocity).length < 1e-7
      else { return false }
      let actual = commander.flightSimulation.pose.systemPoint(body.position)
      let previous = oldTime.flatMap { world.currentPosition(for: id, at: $0) }
      guard
        (actual - point).length < 1e-5
          || previous.map({ (actual - $0).length < 1e-5 }) == true
      else { return false }
      changes.append((index, commander.flightSimulation.pose.shipPoint(point), state.velocity))
    }
    for change in changes {
      bodies[change.index].position = change.position
      bodies[change.index].physical?.velocity = change.velocity
    }
    return true
  }

  /// The same once-consumed native frame that rejects movement owns this rebase.
  /// Every restored station is checked before publishing any new coast origin.
  mutating func retainNativeStationRefusal(_ proofs: [StationMotionRefusal]) -> Bool {
    guard !proofs.isEmpty else { return true }
    guard proofs.count <= 3, Set(proofs.map(\.station)).count == proofs.count,
      var world = commander.nativeStations, world.valid
    else { return false }
    for proof in proofs {
      guard proof.system == systemIdentity, proof.visit == commander.flightSimulation.visit,
        proof.toTime == commander.flightSimulation.physicalTime,
        let body = bodies.first(where: { $0.id == proof.bodyID }),
        body.physical?.identity == proof.actor,
        stationInertialIdentity(for: body) == proof.station,
        (commander.flightSimulation.pose.systemPoint(body.position) - proof.position).length < 1e-5,
        let velocity = body.physical?.velocity, (velocity - proof.velocity).length < 1e-7,
        let source = world.sourcePosition(for: proof.station),
        let retained = NativeStationInertia(
          refusal: proof, previous: world.inertia(for: proof.station), sourcePosition: source)
      else { return false }
      if let index = world.stationInertia.firstIndex(where: { $0.station == proof.station }) {
        world.stationInertia[index] = retained
      } else {
        guard world.stationInertia.count < NativeStationWorld.maximumInertialStations else {
          return false
        }
        world.stationInertia.append(retained)
      }
    }
    guard world.valid else { return false }
    commander.nativeStations = world
    return true
  }

  func stationTransferCanCommit(_ proof: StationContactTransfer) -> Bool {
    guard proof.system == systemIdentity, proof.visit == commander.flightSimulation.visit,
      proof.physicalTime == commander.flightSimulation.physicalTime,
      let world = commander.nativeStations, world.valid,
      let body = bodies.first(where: { $0.id == proof.bodyID }),
      body.physical?.identity == proof.actor,
      stationInertialIdentity(for: body) == proof.station,
      body.energy.isFinite, body.energy > 0, proof.damage.isFinite, proof.damage >= 0,
      let source = world.sourcePosition(for: proof.station),
      NativeStationInertia(
        proof: proof, previous: world.inertia(for: proof.station),
        sourcePosition: source) != nil,
      world.inertia(for: proof.station) != nil
        || world.stationInertia.count < NativeStationWorld.maximumInertialStations
    else { return false }
    return true
  }

  func prepareStationTransfers(_ proofs: [StationContactTransfer]) -> PreparedStationTransfers? {
    PreparedStationTransfers(game: self, proofs: proofs)
  }
}

/// Holds only owned station effects. Preparation validates against the live contact;
/// the synchronous native event then commits this value without another refusal point.
final class PreparedStationTransfers {
  private let world: NativeStationWorld
  private let mainResource: ScriptStationResource?
  private let effects: [(index: Int, energy: Double, velocity: Vector3)]

  @inline(never)
  fileprivate init?(game: borrowing Game, proofs: [StationContactTransfer]) {
    guard !proofs.isEmpty, proofs.count <= 2,
      Set(proofs.map(\.station)).count == proofs.count
    else { return nil }
    for proof in proofs {
      guard game.stationTransferCanCommit(proof) else { return nil }
    }
    guard var staged = game.commander.nativeStations else { return nil }
    var bodyEffects: [(index: Int, energy: Double, velocity: Vector3)] = []
    var originalResource: ScriptStationResource?
    for proof in proofs {
      guard let index = game.bodies.firstIndex(where: { $0.id == proof.bodyID }),
        let source = staged.sourcePosition(for: proof.station),
        let motion = NativeStationInertia(
          proof: proof, previous: staged.inertia(for: proof.station),
          sourcePosition: source)
      else { return nil }
      let energy = max(0, game.bodies[index].energy - proof.damage)
      switch proof.station {
      case .main(let id):
        guard var resource = game.commander.scriptState.stationResources[id.key],
          resource.identity == id.resource, !resource.destroyed
        else { return nil }
        resource.energy = energy
        resource.destroyed = energy == 0
        guard resource.valid else { return nil }
        originalResource = resource
      case .rrs(let id):
        guard let poseIndex = staged.poses.firstIndex(where: { $0.station == id }),
          let binding = staged.ledger.records.first(where: { $0.identity == id })?.binding,
          binding == .init(actor: proof.actor, bodyID: proof.bodyID)
        else { return nil }
        if energy == 0 {
          do { try staged.ledger.destroy(id, binding: binding) } catch { return nil }
        }
        staged.poses[poseIndex].energy = energy
      }
      if let old = staged.stationInertia.firstIndex(where: { $0.station == proof.station }) {
        staged.stationInertia[old] = motion
      } else {
        staged.stationInertia.append(motion)
      }
      bodyEffects.append((index, energy, motion.velocity))
    }
    guard staged.valid else { return nil }
    world = staged
    mainResource = originalResource
    effects = bodyEffects
  }

  @inline(never)
  func commit(to game: inout Game) {
    if let mainResource {
      game.commander.scriptState.stationResources[mainResource.key] = mainResource
    }
    game.commander.nativeStations = world
    for effect in effects {
      game.bodies[effect.index].energy = effect.energy
      game.bodies[effect.index].physical?.velocity = effect.velocity
    }
  }
}

extension Game {
  func currentNativeMainStationAnchor(at time: Double) -> StationAnchor? {
    guard let source = commander.flightSimulation.anchors?.station else { return nil }
    guard let world = commander.nativeStations,
      let id = world.mainStations.first(where: { $0.system == systemIdentity }),
      let motion = world.inertia(for: .main(id))
    else { return source }
    guard let offset = motion.offset(at: time) else { return nil }
    return commander.flightSimulation.projectedMainStationAnchor(displacement: offset)
  }

  /// Re-admit a genuinely registered original source at its owned current physical pose.
  /// The original canonical anchor and registration identity remain unchanged.
  mutating func projectRegisteredMainStationForScene() throws {
    guard let world = commander.nativeStations,
      let id = world.mainStations.first(where: { $0.system == systemIdentity }),
      let motion = world.inertia(for: .main(id))
    else { return }
    guard world.valid, let anchor = commander.flightSimulation.anchors?.station,
      let current = currentNativeMainStationAnchor(at: commander.flightSimulation.physicalTime),
      let index = bodies.firstIndex(where: { $0.id == 0 && $0.hull == .station }),
      bodies.filter({ $0.id == 0 }).count == 1,
      bodies[index].physical?.identity == anchor.identity,
      let resource = commander.scriptState.stationResources[id.key],
      resource.identity == id.resource, !resource.destroyed
    else {
      throw NativeStationRuntimeError.invalidState
    }
    let position = commander.flightSimulation.pose.systemPoint(bodies[index].position)
    guard (position - anchor.position).length < 1e-5 || (position - current.position).length < 1e-5
    else {
      throw NativeStationRuntimeError.invalidSource
    }
    bodies[index].position = commander.flightSimulation.pose.shipPoint(current.position)
    bodies[index].physical?.velocity = motion.velocity
  }

  /// Preserve the existing zero-motion launch exactly. A moved station launches relative
  /// to its real current location and carries its actual inertial velocity into departure.
  mutating func offsetMovingMainStationDeparture() throws {
    guard let world = commander.nativeStations,
      let id = world.mainStations.first(where: { $0.system == systemIdentity }),
      let state = world.inertia(for: .main(id))
    else { return }
    guard let offset = state.offset(at: commander.flightSimulation.physicalTime) else {
      throw NativeStationRuntimeError.unsafeExit
    }
    if offset == .init(0, 0, 0), state.velocity == .init(0, 0, 0) { return }
    let old = commander.flightSimulation.pose
    var pose = old
    pose.position = pose.position + offset
    let radius = commander.playerMesh.vertices.map(\.length).max() ?? .infinity
    guard pose.position.finite, radius.isFinite else { throw NativeStationRuntimeError.unsafeExit }
    for body in bodies where body.energy > 0 {
      guard let hull = preparedWorkHull(mesh: gameplayMesh(for: body), key: "main-exit:\(body.id)"),
        HullSweepSafety.validatePlacement(
          center: pose.position, radius: radius,
          hull: hull, pose: modelPose(of: body), requiredClearance: 8
        ).safe
      else { throw NativeStationRuntimeError.unsafeExit }
    }
    if let anchors = commander.flightSimulation.anchors {
      for celestial in [anchors.planet, anchors.sun] {
        guard (pose.position - celestial.position).length > radius + celestial.radius + 8 else {
          throw NativeStationRuntimeError.unsafeExit
        }
      }
    }
    let combined = pose.orientation.apply(.init(0, 0, speed * 18)) + state.velocity
    guard combined.finite, combined.length <= AsteroidImpactPolicy.maximumSpeed else {
      throw NativeStationRuntimeError.unsafeExit
    }
    for index in bodies.indices {
      bodies[index].position = pose.shipPoint(old.systemPoint(bodies[index].position))
    }
    for index in celestials.indices {
      celestials[index].position = pose.shipPoint(old.systemPoint(celestials[index].position))
    }
    commander.flightSimulation.pose = pose
    autoPilot.setApproachVelocity(pose.shipVector(state.velocity))
    manualResidualFlight = true
  }
}
