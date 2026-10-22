import Foundation

/// A native observation, deliberately separate from CombatIncident and all settlement ledgers.
struct NativePracticeHitReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let target: UUID
  let actor: ActorIdentity
  let origin: AttackOrigin
  let kind: AttackKind
  let time: Double
  let position: Vector3

  fileprivate init(
    state: NativePracticeState, beacon: NativePracticeBeacon, origin: AttackOrigin,
    kind: AttackKind, time: Double, position: Vector3
  ) {
    operation = state.permission.operation
    target = beacon.identity
    actor = beacon.actor
    self.origin = origin
    self.kind = kind
    self.time = time
    self.position = position
  }

  func valid(in state: NativePracticeState) -> Bool {
    guard let beacon = state.beacons.first(where: { $0.identity == target }),
      operation == state.permission.operation, actor == beacon.actor,
      origin.owner == state.permission.player,
      origin.emissionID > 0, origin.emissionID < UInt64.max,
      origin.emittedAt.isFinite, origin.emittedAt >= state.permission.begunAt,
      time.isFinite, time >= origin.emittedAt, time <= 1e12,
      position.finite, origin.sourcePart == nil,
      [.laser, .missile, .plasma].contains(kind)
    else { return false }
    if kind == .laser {
      guard origin.ordnance == nil, origin.playerAmmunition == nil else { return false }
    } else {
      guard let projectile = origin.ordnance, projectile.entity >= 2,
        projectile.system == actor.system, projectile.visit == actor.visit,
        projectile != actor, !state.beacons.contains(where: { $0.actor == projectile })
      else { return false }
    }
    // Swept ordnance reports a contact point on its swept centre, so only laser points
    // are required to lie on the exact cube surface rather than the projectile envelope.
    let local = state.permission.frame.shipVector(
      position - state.permission.position(beacon.ordinal))
    if kind == .laser {
      let extent = max(abs(local.x), abs(local.y), abs(local.z))
      guard abs(extent - NativePracticeSource.halfSide) <= 1e-5 else { return false }
    }
    return (position - state.permission.volume.position).length <= state.permission.volume.radius
  }
}

enum NativePracticeHitPolicy {
  /// The native caller supplies a sealed first contact, never a scan or target disappearance.
  static func nativeContact(
    _ contact: MissionCollisionContact, state: NativePracticeState, pose: ShipPose,
    origin: AttackOrigin, kind: AttackKind, time: Double, nextEmission: UInt64,
    projectile: OrdnanceState? = nil
  ) throws -> NativePracticeHitReceipt {
    guard let selected = contact.selectedTargetBody else { throw NativePracticeError.invalidTarget }
    return try checkedHit(
      contact.hit, body: selected, state: state, pose: pose, origin: origin,
      kind: kind, time: time, nextEmission: nextEmission, projectile: projectile)
  }

  /// Isolated native-ray entry, also used by policy units with the real nearest mesh query.
  /// All scene meshes are explicit: an occluding ordinary body retains the first hit.
  static func laser(
    state: NativePracticeState, pose: ShipPose, bodies: [SpaceBody],
    meshes: [Int: Mesh], celestials: [CelestialBody], direction: Vector3,
    range: Double, origin: AttackOrigin, time: Double, nextEmission: UInt64
  ) throws -> NativePracticeHitReceipt {
    guard Set(bodies.map(\.id)).count == bodies.count,
      bodies.allSatisfy({ meshes[$0.id] != nil }),
      let hit = GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: direction, maxDistance: range,
        bodies: bodies, celestials: celestials, meshOverrides: meshes),
      case .body(let id) = hit.target, let body = bodies.first(where: { $0.id == id })
    else { throw NativePracticeError.invalidTarget }
    return try checkedHit(
      hit, body: body, state: state, pose: pose, origin: origin, kind: .laser,
      time: time, nextEmission: nextEmission, projectile: nil)
  }

  private static func checkedHit(
    _ hit: GameplayHit, body: SpaceBody, state: NativePracticeState, pose: ShipPose,
    origin: AttackOrigin, kind: AttackKind, time: Double, nextEmission: UInt64,
    projectile: OrdnanceState?
  ) throws -> NativePracticeHitReceipt {
    guard state.valid, case .body(let id) = hit.target, id == body.id,
      hit.distance.isFinite, hit.distance >= 0, hit.point.finite,
      origin.emissionID < nextEmission,
      let beacon = state.beacon(for: body, pose: pose)
    else { throw NativePracticeError.invalidTarget }
    if kind == .laser {
      guard projectile == nil else { throw NativePracticeError.invalidTarget }
    } else {
      guard let projectile, projectile.valid, projectile.termination == nil,
        projectile.origin == origin, projectile.profile.attackKind == kind,
        projectile.lastUpdatedAt == time
      else { throw NativePracticeError.invalidTarget }
    }
    let receipt = NativePracticeHitReceipt(
      state: state, beacon: beacon, origin: origin, kind: kind,
      time: time, position: pose.systemPoint(hit.point))
    guard receipt.valid(in: state) else { throw NativePracticeError.invalidTarget }
    guard
      !state.hits.contains(where: {
        $0.target == receipt.target || $0.origin.emissionID == receipt.origin.emissionID
      })
    else { throw NativePracticeError.duplicateHit }
    return receipt
  }
}
