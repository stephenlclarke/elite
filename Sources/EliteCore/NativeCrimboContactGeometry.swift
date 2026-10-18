import Foundation

/// A bounded complete scene from the one native pre-movement boundary, never a motion journal.
struct NativeCrimboContactMotionFrame: Equatable, Sendable {
  static let maximumBlockers = 256
  static let subdivisions = 8
  struct Formation: Equatable, Sendable {
    let previous: OrbitFormationState
    let next: OrbitFormationState
    let slot: Int
    let hullRadius: Double
    let trackingAtStart: Bool

    func qualifies(_ fact: NativeCrimboAttainedMotion, duration: Double) -> Bool {
      guard trackingAtStart, previous.anchor == next.anchor,
        previous.configuration == next.configuration, previous.incarnation == next.incarnation,
        previous.angularSpeed.isFinite, next.angularSpeed.isFinite,
        previous.angularSpeed > 0, next.angularSpeed > 0,
        hullRadius.isFinite, hullRadius > 0, duration > 0
      else { return false }
      let direction = Double(previous.configuration.direction.rawValue)
      let advance = 0.5 * (previous.angularSpeed + next.angularSpeed) * duration
      guard
        abs(
          atan2(
            sin(next.phase - previous.phase - direction * advance),
            cos(next.phase - previous.phase - direction * advance))) < 1e-8
      else { return false }
      let anchor = previous.anchor
      let velocity = fact.subjectStartVelocity
      let initial = fact.subjectStart.position - anchor.center
      let normalSpeed = velocity.dot(anchor.basis.z)
      let planeVelocity = velocity - anchor.basis.z * normalSpeed
      let planeInitial = initial - anchor.basis.z * initial.dot(anchor.basis.z)
      let minimumRadius = NativeCrimboMotion.closestDistance(
        offset: planeInitial, displacement: planeVelocity * duration)
      guard minimumRadius.isFinite, minimumRadius > 1e-6 else { return false }
      let alpha = (next.angularSpeed - previous.angularSpeed) / duration
      let maximumOmega = max(previous.angularSpeed, next.angularSpeed)
      let minimumSpeed = min(previous.angularSpeed, next.angularSpeed) * anchor.orbitRadius
      let positionSlope = hypot(
        velocity.length,
        anchor.orbitRadius * (maximumOmega + planeVelocity.length / minimumRadius))
      let velocitySlope = anchor.orbitRadius * (abs(alpha) + maximumOmega * maximumOmega)
      let half = duration / Double(NativeCrimboContactMotionFrame.subdivisions * 2)
      for i in 0..<NativeCrimboContactMotionFrame.subdivisions {
        let t = (Double(i) + 0.5) * duration / Double(NativeCrimboContactMotionFrame.subdivisions)
        let angle =
          previous.phase - direction * Double(slot) * previous.configuration.slotSpacing
          + direction * (previous.angularSpeed * t + 0.5 * alpha * t * t)
        let point = initial + velocity * t
        let normal = point.dot(anchor.basis.z)
        let plane = point - anchor.basis.z * normal
        let radius = plane.length
        let actualAngle = atan2(plane.dot(anchor.basis.y), plane.dot(anchor.basis.x))
        let phase = atan2(sin(angle - actualAngle), cos(angle - actualAngle))
        let error = hypot(hypot(anchor.orbitRadius - radius, normal), anchor.orbitRadius * phase)
        let tangent = (anchor.basis.x * -sin(angle) + anchor.basis.y * cos(angle)) * direction
        let goalVelocity = tangent * (anchor.orbitRadius * (previous.angularSpeed + alpha * t))
        guard error.isFinite, positionSlope.isFinite, velocitySlope.isFinite,
          error + positionSlope * half + 1e-8 <= max(1, hullRadius * 0.25),
          (velocity - goalVelocity).length + velocitySlope * half + 1e-8
            <= max(1, minimumSpeed * 0.05)
        else { return false }
      }
      return true
    }
  }

  private struct Blocker: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
      case ordinary(Int, ActorIdentity, String?)
      case station(Int, ActorIdentity?)
      case celestial(Int, CelestialKind)
      case anchor(CelestialKind)
    }
    let kind: Kind
    let center: Vector3
    let velocity: Vector3
    let radius: Double
  }
  private let blockers: [Blocker]
  private let bodyIDs: Set<Int>
  private let celestialCount: Int
  let formation: Formation?

  static func capture(in game: Game, subject: ActorIdentity, formation: Formation?) -> Self? {
    guard game.bodies.count + game.celestials.count - 1 <= maximumBlockers,
      Set(game.bodies.map(\.id)).count == game.bodies.count
    else { return nil }
    let pose = game.commander.flightSimulation.pose
    guard let context = game.gameplayContext() else { return nil }
    var blockers: [Blocker] = []
    var actorIDs: Set<ActorIdentity> = []
    for body in game.bodies {
      if let identity = body.physical?.identity {
        guard actorIDs.insert(identity).inserted else { return nil }
        if identity == subject { continue }
      }
      let mesh = game.gameplayMesh(for: body)
      let radius = mesh.vertices.map(\.length).max() ?? .infinity
      let center = pose.systemPoint(body.position)
      guard !mesh.faces.isEmpty, mesh.vertices.allSatisfy(\.finite), radius.isFinite, radius > 0,
        center.finite, body.energy.isFinite, body.energy > 0
      else { return nil }
      let kind: Blocker.Kind
      let velocity: Vector3
      if body.id == 0, body.hull == .station,
        body.physical?.identity == context.anchors.station.identity,
        close(center, context.anchors.station.position)
      {
        kind = .station(body.id, body.physical?.identity)
        velocity = .init(0, 0, 0)
      } else if let identity = body.nativeStationIdentity,
        let station = game.commander.nativeStations?.pose(for: identity),
        close(center, station.position)
      {
        kind = .station(body.id, body.physical?.identity)
        velocity = .init(0, 0, 0)
      } else if let physical = body.physical, physical.spawnIdentity != nil,
        physical.ordnance == nil, body.scriptShot == nil, body.scriptNPC == nil,
        physical.velocity.finite
      {
        kind = .ordinary(body.id, physical.identity, physical.catalogueShipID)
        velocity = physical.velocity
      } else {
        // Unknown legacy/script/projectile interiors cannot be proved by endpoint coincidence.
        return nil
      }
      blockers.append(.init(kind: kind, center: center, velocity: velocity, radius: radius))
    }
    // Canonical physical spheres exist even when a presentation fixture omits its drawn bodies.
    for (kind, sphere) in [
      (CelestialKind.planet, context.anchors.planet), (.sun, context.anchors.sun),
    ] {
      guard sphere.position.finite, sphere.radius.isFinite, sphere.radius > 0 else { return nil }
      blockers.append(
        .init(
          kind: .anchor(kind), center: sphere.position,
          velocity: .init(0, 0, 0), radius: sphere.radius))
    }
    for (index, celestial) in game.celestials.enumerated() {
      let center = pose.systemPoint(celestial.position)
      guard center.finite, celestial.radius.isFinite, celestial.radius > 0 else { return nil }
      blockers.append(
        .init(
          kind: .celestial(index, celestial.kind), center: center,
          velocity: .init(0, 0, 0), radius: celestial.radius))
    }
    guard blockers.count <= maximumBlockers else { return nil }
    return .init(
      blockers: blockers, bodyIDs: Set(game.bodies.map(\.id)),
      celestialCount: game.celestials.count, formation: formation)
  }

  func provesLineOfSight(in game: Game, fact: NativeCrimboAttainedMotion) -> Bool {
    let duration = fact.endTime - fact.startTime
    guard duration.isFinite, duration > 0, duration <= 0.100001,
      let player = fact.playerTrajectory,
      Set(game.bodies.map(\.id)) == bodyIDs, game.bodies.count == bodyIDs.count,
      game.celestials.count == celestialCount
    else { return false }
    let half = duration / Double(Self.subdivisions * 2)
    for blocker in blockers {
      guard endpointMatches(blocker, in: game, duration: duration) else { return false }
      let relativePlayerStart = player.initialVelocity - blocker.velocity
      let relativePlayerEnd = relativePlayerStart + player.acceleration * duration
      let relativeSubject = fact.subjectStartVelocity - blocker.velocity
      let slope = max(
        relativeSubject.length, max(relativePlayerStart.length, relativePlayerEnd.length))
      for i in 0..<Self.subdivisions {
        let t = (Double(i) + 0.5) * duration / Double(Self.subdivisions)
        let center = blocker.center + blocker.velocity * t
        let sender =
          fact.playerStart.position + player.initialVelocity * t
          + player.acceleration * (0.5 * t * t)
        let receiver = fact.subjectStart.position + fact.subjectStartVelocity * t
        let distance = NativeCrimboMotion.closestDistance(
          offset: sender - center, displacement: receiver - sender)
        guard distance.isFinite, slope.isFinite,
          distance - slope * half > blocker.radius + 1e-7
            * max(1, max(blocker.center.length, max(sender.length, receiver.length)))
        else { return false }
      }
    }
    return true
  }

  private func endpointMatches(_ blocker: Blocker, in game: Game, duration: Double) -> Bool {
    let pose = game.commander.flightSimulation.pose
    switch blocker.kind {
    case .ordinary(let id, let actor, let catalogue):
      guard let body = game.bodies.first(where: { $0.id == id }), body.energy > 0,
        body.physical?.identity == actor, body.physical?.catalogueShipID == catalogue,
        body.physical?.velocity == blocker.velocity, body.physical?.ordnance == nil,
        body.scriptNPC == nil, body.scriptShot == nil,
        (game.gameplayMesh(for: body).vertices.map(\.length).max() ?? .infinity) <= blocker.radius
          + 1e-8
      else { return false }
      return Self.close(
        pose.systemPoint(body.position), blocker.center + blocker.velocity * duration)
    case .station(let id, let actor):
      guard let body = game.bodies.first(where: { $0.id == id }), body.energy > 0,
        body.hull == .station, body.physical?.identity == actor,
        (game.gameplayMesh(for: body).vertices.map(\.length).max() ?? .infinity) <= blocker.radius
          + 1e-8
      else {
        return false
      }
      return Self.close(pose.systemPoint(body.position), blocker.center)
    case .anchor(let kind):
      guard let context = game.gameplayContext() else { return false }
      let sphere = kind == .planet ? context.anchors.planet : context.anchors.sun
      return sphere.radius == blocker.radius && Self.close(sphere.position, blocker.center)
    case .celestial(let index, let kind):
      let celestial = game.celestials[index]
      return celestial.kind == kind && celestial.radius == blocker.radius
        && Self.close(pose.systemPoint(celestial.position), blocker.center)
    }
  }

  private static func close(_ a: Vector3, _ b: Vector3) -> Bool {
    a.finite && b.finite && (a - b).length <= max(1, b.length) * 1e-8
  }
}

extension Game {
  /// G1 calls after work guidance and immediately before the existing sole moveBodies integration.
  mutating func sampleNativeCrimboContactMotion(delta: Double) {
    let previous = nativeCrimboMotionSample
    nativeCrimboMotionSample = nil
    guard delta.isFinite, delta > 0, delta <= 0.1, nativeCrimboLifecycleAvailable,
      !paused, !docked, screen != .gameOver,
      let registry = commander.savedCrimboState, registry.threat == nil,
      registry.world == commander.equipmentOwnerID,
      registry.spawnSequence < commander.flightSimulation.nextSpawn,
      (try? registry.validate()) != nil,
      let context = gameplayContext(), context.physicalTime >= delta,
      context.system == NativeCrimboRegistry.system,
      let actorID = registry.binding(of: registry.members[6], ledger: commander.npcPersistence),
      let actor = context.actors.first(where: { $0.identity == actorID }), actor.energy > 0,
      actorID.visit == context.visit,
      let logical = registry.members[6].ownership.logical,
      let body = bodies.first(where: { $0.physical?.identity == actorID }), !isEMPDisabled(body),
      body.missionActorID == nil, body.scriptNPC == nil, body.missionInstanceID == nil,
      let actual = NPCPersistenceSnapshot.capture(
        body: body, pose: commander.flightSimulation.pose,
        physicalTime: context.physicalTime, protection: context.protection),
      NativeCrimboRegistry.matches(actual, member: registry.members[6])
    else { return }
    let reference = previous.flatMap {
      $0.actor == actorID && $0.frame == context.revision && $0.provider == registry.provider
        ? $0.formationReference : nil
    }
    let frame = NativeCrimboContactMotionFrame.capture(
      in: self, subject: actorID, formation: reference)
    let radial = (actor.position - registry.orbit.anchor.center).unit
    var subject = ShipPose()
    subject.position = actor.position
    subject.orientation = actor.orientation
    nativeCrimboMotionSample = .init(
      provider: registry.provider, member: registry.members[6].identity, actor: actorID,
      runtimeEpoch: nativeStationRuntimeEpoch, frame: context.revision,
      stationImpactRevision: stationImpactRevision,
      startTime: context.physicalTime - delta, endTime: context.physicalTime,
      subject: subject, player: commander.flightSimulation.pose,
      subjectVelocity: actor.velocity, playerVelocity: context.player.velocity,
      tangent: registry.orbit.anchor.basis.z.cross(radial)
        * Double(registry.orbit.configuration.direction.rawValue),
      normalPlayerStep: nativeCrimboNormalPlayerStep(delta: delta),
      observationIdentity: .init(
        world: registry.world, manifest: registry.manifest,
        player: context.player.identity, sceneGeneration: registry.orbit.anchor.identity,
        logical: logical),
      contactMotion: frame, formationReference: reference)
  }
}
