import Foundation

extension Game {
  /// Mount direction, hull intersections and legal attribution share the same
  /// physical frame; a targeting lock never makes a shot pass through a ship.
  mutating func fireLaser() {
    guard fireCooldown <= 0, laserHeat < 240, energy > 1,
      let mount = LaserMount.from(screen), let laser = commander.laser(on: mount)
    else { return }
    ensurePhysicalActors()
    guard let player = commander.flightSimulation.player,
      let origin = makeAttackOrigin(owner: player)
    else { return }
    fireCooldown = laser.firingInterval
    laserHeat += 10
    energy -= 1
    laserFlash = 0.08
    dischargeAudio.record(.combatLaser)
    let direction: Vector3
    switch mount {
    case .front: direction = .init(0, 0, 1)
    case .rear: direction = .init(0, 0, -1)
    case .left: direction = .init(-1, 0, 0)
    case .right: direction = .init(1, 0, 0)
    }
    let emissionPosition = commander.flightSimulation.pose.position
    guard
      let hit = GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: direction, maxDistance: 6000,
        bodies: bodies.filter { $0.energy > 0 }, celestials: celestials,
        meshOverrides: gameplayMeshOverrides)
    else {
      recordCombat(
        origin: origin, kind: .laser, outcome: .discharge, target: nil,
        worldPosition: emissionPosition, emissionPosition: emissionPosition,
        laser: laser, mount: mount)
      commander.crimeLedger.finishEmission(origin.emissionID)
      return
    }
    let damage: Double
    if case .body(let id) = hit.target, let body = bodies.first(where: { $0.id == id }) {
      damage = commander.laserDamage(against: body.hull, mount: mount)
    } else {
      damage = laser.damage
    }
    applyCombatHit(
      hit, origin: origin, kind: .laser, damage: damage, laser: laser, mount: mount,
      emissionPosition: emissionPosition)
    commander.crimeLedger.finishEmission(origin.emissionID)
  }

  /// A legacy scripted beam still obeys occlusion and records its real emitter.
  /// Script-specific cadence/damage remains with the original encounter.
  mutating func emitLegacyNPCBeam(bodyID: Int, damage: Double, energyMultiplier: Double = 1) {
    ensurePhysicalActors()
    guard let body = bodies.first(where: { $0.id == bodyID && $0.energy > 0 }),
      let owner = body.physical?.identity, let origin = makeAttackOrigin(owner: owner),
      body.position.length > 0
    else { return }
    let launch = commander.flightSimulation.pose.systemPoint(body.position)
    if let index = bodies.firstIndex(where: { $0.id == bodyID }) {
      bodies[index].physical?.npc?.resources?.recordBeam(heat: min(10, damage * 10 / 15))
    }
    let hit = GameplayRaycast.nearest(
      origin: body.position, direction: body.position * -1, maxDistance: body.position.length + 1,
      bodies: bodies.filter { $0.energy > 0 }, ignoring: [bodyID],
      playerMesh: commander.playerMesh, celestials: celestials,
      meshOverrides: gameplayMeshOverrides)
    if let hit {
      applyCombatHit(
        hit, origin: origin, kind: .laser, damage: damage, emissionPosition: launch,
        energyMultiplier: energyMultiplier)
    } else {
      recordCombat(
        origin: origin, kind: .laser, outcome: .discharge, target: nil,
        worldPosition: launch, emissionPosition: launch)
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
  }

  mutating func applyAttributedEnergyBomb() {
    ensurePhysicalActors()
    guard let player = commander.flightSimulation.player,
      let origin = makeAttackOrigin(owner: player)
    else { return }
    let launch = commander.flightSimulation.pose.position
    for body in bodies where body.energy > 0 {
      applyCombatHit(
        .init(target: .body(body.id), distance: body.position.length, point: body.position),
        origin: origin, kind: .bomb, damage: body.hull.bombImmune ? 0 : body.energy,
        emissionPosition: launch)
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
  }

  /// Destruction created by an older scripted path uses the same once-only
  /// settlement. Already attributed damage must never receive a second bounty.
  mutating func settleLegacyCombatDeath(_ body: SpaceBody) {
    guard body.destroyedByPlayer == true, body.physical?.deathOrigin == nil,
      body.hull.isTargetShip, let player = commander.flightSimulation.player,
      let origin = makeAttackOrigin(owner: player)
    else { return }
    let destruction = recordCombat(
      origin: origin, kind: .laser, outcome: .destruction, target: .body(body.id),
      worldPosition: commander.flightSimulation.pose.systemPoint(body.position))
    if let index = bodies.firstIndex(where: { $0.id == body.id }) {
      bodies[index].physical?.deathOrigin = origin
      bodies[index].physical?.deathIncidentID = destruction?.id
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
  }

  var gameplayMeshOverrides: [Int: Mesh] {
    var result: [Int: Mesh] = [:]
    for body in bodies {
      if body.physical?.catalogueShipID != nil || body.physical?.rock != nil
        || body.physical?.salvage?.lot != nil
      {
        result[body.id] = gameplayMesh(for: body)
      }
    }
    return result
  }

  func gameplayMesh(for body: SpaceBody) -> Mesh {
    if let payload = body.physical?.payload, case .salvage(let identity) = payload,
      let lot = commander.salvageLedger.pendingLots.first(where: { $0.identity == identity })
    {
      let base = Mesh.hull(.cargo)
      let x = base.vertices.map { abs($0.x) }.max() ?? 1
      let y = base.vertices.map { abs($0.y) }.max() ?? 1
      let z = base.vertices.map { abs($0.z) }.max() ?? 1
      guard x > 0, y > 0, z > 0 else { return base }
      return .init(
        vertices: base.vertices.map {
          .init(
            $0.x * lot.halfExtents.x / x, $0.y * lot.halfExtents.y / y,
            $0.z * lot.halfExtents.z / z)
        }, faces: base.faces, details: base.details, materials: base.materials,
        faceMaterials: base.faceMaterials, preserveWinding: true)
    }
    if let id = body.physical?.catalogueShipID, let ship = ShipCatalogue.ship(id) {
      return ship.design.rawMesh
    }
    let base = Mesh.hull(body.hull)
    guard let identity = body.physical?.rock,
      let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == identity })
    else { return base }
    let radius = base.vertices.map(\.length).max() ?? 1
    return .init(
      vertices: base.vertices.map { $0 * (rock.radius / radius) }, faces: base.faces,
      details: base.details, materials: base.materials, faceMaterials: base.faceMaterials,
      preserveWinding: true)
  }
}
