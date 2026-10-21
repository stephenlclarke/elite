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
  let station: StationInertialIdentity
  private(set) var displacement: Vector3
  private(set) var momentum: Vector3
  private(set) var physicalTime: Double
  private(set) var contacts: UInt64

  var velocity: Vector3 { momentum * (1 / AsteroidImpactPolicy.massKg(hull: .station)) }
  var valid: Bool {
    displacement.finite && displacement.length.isFinite && momentum.finite
      && momentum.length.isFinite
      && velocity.length <= AsteroidImpactPolicy.maximumSpeed
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && contacts > 0 && contacts < UInt64(Int64.max)
  }

  func offset(at time: Double) -> Vector3? {
    guard valid, time.isFinite, time >= physicalTime else { return nil }
    let value = displacement + velocity * (time - physicalTime)
    return value.finite && value.length.isFinite ? value : nil
  }

  fileprivate init?(
    proof: StationContactTransfer, previous: NativeStationInertia?,
    sourcePosition: Vector3
  ) {
    let oldMomentum = previous?.momentum ?? .init(0, 0, 0)
    let oldVelocity = previous?.velocity ?? .init(0, 0, 0)
    guard previous == nil || previous?.station == proof.station,
      proof.physicalTime.isFinite, proof.physicalTime >= (previous?.physicalTime ?? 0),
      (oldVelocity - proof.previousVelocity).length < 1e-7,
      proof.finalPosition.finite, sourcePosition.finite,
      (previous?.contacts ?? 0) < UInt64(Int64.max) - 1
    else { return nil }
    station = proof.station
    displacement = proof.finalPosition - sourcePosition
    momentum = oldMomentum + proof.impulse
    physicalTime = proof.physicalTime
    contacts = (previous?.contacts ?? 0) + 1
    guard valid, (velocity - proof.finalVelocity).length < 1e-7 else { return nil }
  }
}

extension NativeStationWorld {
  static var maximumInertialStations: Int {
    NativeMainStationIdentity.maximumCount + NativeStationLedger.recordLimit
  }

  func inertia(for station: StationInertialIdentity) -> NativeStationInertia? {
    stationInertia.first { $0.station == station }
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
    guard let id = stationInertialIdentity(for: body) else { return .init(0, 0, 0) }
    return commander.nativeStations?.inertia(for: id)?.velocity ?? .init(0, 0, 0)
  }

  func nativeStationRelativeEntrySpeed(_ body: SpaceBody) -> Double {
    let velocity = nativeStationVelocity(body)
    if velocity == .init(0, 0, 0) { return max(speed * 18, autoPilot.velocity.length) }
    return (flightWorldVelocity - velocity).length
  }

  /// Only current native bodies can consume owned coast projection. Either the prior
  /// or already-current position must match; this cannot normalize an arbitrary teleport.
  mutating func synchronizeNativeStationInertia(
    at time: Double, advancingFrom oldTime: Double? = nil
  )
    -> Bool
  {
    guard let world = commander.nativeStations else { return true }
    guard world.valid, time.isFinite, time >= 0 else { return false }
    for index in bodies.indices where bodies[index].hull == .station {
      let body = bodies[index]
      guard let id = stationInertialIdentity(for: body), let state = world.inertia(for: id) else {
        continue
      }
      guard let point = world.currentPosition(for: id, at: time) else { return false }
      let actual = commander.flightSimulation.pose.systemPoint(body.position)
      let previous = oldTime.flatMap { world.currentPosition(for: id, at: $0) }
      guard
        (actual - point).length < 1e-5
          || previous.map({ (actual - $0).length < 1e-5 }) == true
      else { return false }
      bodies[index].position = commander.flightSimulation.pose.shipPoint(point)
      bodies[index].physical?.velocity = state.velocity
    }
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

  /// A live, non-decodable contact proof joins the actual body to its real resource.
  /// Every fallible lookup precedes the first persistent or physical write.
  mutating func commitStationTransfer(_ proof: StationContactTransfer) -> Bool {
    guard stationTransferCanCommit(proof), var world = commander.nativeStations,
      let index = bodies.firstIndex(where: { $0.id == proof.bodyID }),
      let source = world.sourcePosition(for: proof.station),
      let state = NativeStationInertia(
        proof: proof, previous: world.inertia(for: proof.station),
        sourcePosition: source)
    else { return false }
    let energy = max(0, bodies[index].energy - proof.damage)
    switch proof.station {
    case .main(let id):
      guard var resource = commander.scriptState.stationResources[id.key],
        resource.identity == id.resource, !resource.destroyed
      else { return false }
      resource.energy = energy
      resource.destroyed = energy == 0
      commander.scriptState.stationResources[id.key] = resource
    case .rrs(let id):
      guard let poseIndex = world.poses.firstIndex(where: { $0.station == id }),
        let binding = world.ledger.records.first(where: { $0.identity == id })?.binding,
        binding == .init(actor: proof.actor, bodyID: proof.bodyID)
      else { return false }
      if energy == 0 {
        do { try world.ledger.destroy(id, binding: binding) } catch { return false }
      }
      world.poses[poseIndex].energy = energy
    }
    if let old = world.stationInertia.firstIndex(where: { $0.station == proof.station }) {
      world.stationInertia[old] = state
    } else {
      world.stationInertia.append(state)
    }
    commander.nativeStations = world
    bodies[index].energy = energy
    bodies[index].physical?.velocity = state.velocity
    return true
  }
}
