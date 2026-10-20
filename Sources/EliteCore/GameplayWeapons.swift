import Foundation

/// Synchronous query facts; no Game copy or authority beyond the original physical contact.
private final class NPCBeamPreparation {
  let owner: ActorIdentity
  let launch: Vector3
  let contact: MissionCollisionContact?

  @inline(never)
  init(owner: ActorIdentity, launch: Vector3, contact: consuming MissionCollisionContact?) {
    self.owner = owner
    self.launch = launch
    self.contact = consume contact
  }
}

/// Only the original flight snapshot can roll back a refused native mission impact.
private final class NPCBeamEmission {
  let preparation: NPCBeamPreparation
  let flightBeforeEmission: FlightSimulationState
  let origin: AttackOrigin

  @inline(never)
  init(
    preparation: NPCBeamPreparation, flightBeforeEmission: consuming FlightSimulationState,
    origin: AttackOrigin
  ) {
    self.preparation = preparation
    self.flightBeforeEmission = consume flightBeforeEmission
    self.origin = origin
  }
}

extension Game {
  static let combatLaserEnergyCost = 1.0
  /// Mount direction, hull intersections and legal attribution share the same
  /// physical frame; a targeting lock never makes a shot pass through a ship.
  mutating func fireLaser() {
    guard let mount = LaserMount.from(screen) else { return }
    fireLaser(mount: mount)
  }

  /// Autonomous fire uses the fitted mount without changing the user's view or selected tool.
  mutating func fireLaser(mount: LaserMount) {
    guard !playerEMPDisabled, fireCooldown <= 0, laserHeat < 240,
      energy > Self.combatLaserEnergyCost,
      let laser = commander.laser(on: mount)
    else { return }
    ensurePhysicalActors()
    let direction: Vector3
    switch mount {
    case .front: direction = .init(0, 0, 1)
    case .rear: direction = .init(0, 0, -1)
    case .left: direction = .init(-1, 0, 0)
    case .right: direction = .init(1, 0, 0)
    }
    let contact: MissionCollisionContact?
    do {
      contact = try nearestMissionCollision(
        from: .init(0, 0, 0), direction: direction, range: 6000, radius: 0,
        excludingBodyIDs: [], includePlayer: false)
    } catch { return }
    guard let player = commander.flightSimulation.player else { return }
    let damage: Double
    if let contact, case .body(let id) = contact.hit.target,
      let body = bodies.first(where: { $0.id == id })
    {
      damage = commander.laserDamage(against: body.hull, mount: mount)
    } else {
      damage = laser.damage
    }
    if let contact, contact.selectedTargetBody?.scriptNPC != nil {
      do {
        _ = try preflightNativeMissionContact(
          contact, owner: player, damage: damage, laser: laser, mount: mount)
      } catch { return }
    }
    let flightBeforeEmission = commander.flightSimulation
    guard let origin = makeAttackOrigin(owner: player) else { return }
    let emissionPosition = commander.flightSimulation.pose.position
    guard let contact else {
      recordPlayerLaserDischarge(laser)
      recordCombat(
        origin: origin, kind: .laser, outcome: .discharge, target: nil,
        worldPosition: emissionPosition, emissionPosition: emissionPosition,
        laser: laser, mount: mount)
      commander.crimeLedger.finishEmission(origin.emissionID)
      return
    }
    let hit = contact.hit
    if contact.selectedTargetBody?.scriptNPC != nil {
      do {
        let receipt = try applyNativeMissionContact(
          contact, origin: origin, damage: damage, laser: laser, mount: mount,
          emissionPosition: emissionPosition)
        projectScriptMissionImpact(receipt)
      } catch {
        commander.flightSimulation = flightBeforeEmission
        return
      }
    } else {
      applyCombatHit(
        hit, origin: origin, kind: .laser, damage: damage, laser: laser, mount: mount,
        emissionPosition: emissionPosition)
    }
    recordPlayerLaserDischarge(laser)
    commander.crimeLedger.finishEmission(origin.emissionID)
  }

  private mutating func recordPlayerLaserDischarge(_ laser: LaserKind) {
    fireCooldown = laser.firingInterval
    laserHeat += 10
    energy -= Self.combatLaserEnergyCost
    laserFlash = 0.08
    dischargeAudio.record(.combatLaser)
  }

  /// NPC beams obey occlusion and record their real emitter; the encounter owns cadence/damage.
  /// Cold phases mutate the same live Game, without reserving their query values in this frame.
  @inline(never)
  mutating func emitLegacyNPCBeam(bodyID: Int, damage: Double, energyMultiplier: Double = 1) {
    ensurePhysicalActors()
    guard let preparation = prepareNPCBeam(bodyID: bodyID, damage: damage),
      let emission = prepareNPCBeamEmission(preparation),
      applyNPCBeamImpact(emission, damage: damage, energyMultiplier: energyMultiplier)
    else { return }
    finishNPCBeam(emission, bodyID: bodyID, damage: damage)
  }

  @inline(never)
  private mutating func prepareNPCBeam(bodyID: Int, damage: Double) -> NPCBeamPreparation? {
    guard let body = bodies.first(where: { $0.id == bodyID && $0.energy > 0 }),
      !isEMPDisabled(body),
      let owner = body.physical?.identity,
      body.position.length > 0
    else { return nil }
    let launch = commander.flightSimulation.pose.systemPoint(body.position)
    let contact: MissionCollisionContact?
    do {
      contact = try nearestMissionCollision(
        from: body.position, direction: body.position.unit * -1,
        range: body.position.length + 1, radius: 0,
        excludingBodyIDs: [bodyID], includePlayer: true)
    } catch { return nil }
    if let contact, contact.selectedTargetBody?.scriptNPC != nil {
      do {
        _ = try preflightNativeMissionContact(
          contact, owner: owner, damage: damage, laser: nil, mount: nil)
      } catch { return nil }
    }
    return .init(owner: owner, launch: launch, contact: contact)
  }

  @inline(never)
  private mutating func prepareNPCBeamEmission(_ preparation: NPCBeamPreparation)
    -> NPCBeamEmission?
  {
    let flightBeforeEmission = commander.flightSimulation
    guard let origin = makeAttackOrigin(owner: preparation.owner) else { return nil }
    return .init(
      preparation: preparation, flightBeforeEmission: flightBeforeEmission, origin: origin)
  }

  @inline(never)
  private mutating func applyNPCBeamImpact(
    _ emission: NPCBeamEmission, damage: Double, energyMultiplier: Double
  ) -> Bool {
    if let contact = emission.preparation.contact {
      if contact.selectedTargetBody?.scriptNPC != nil {
        guard
          let receipt = try? applyNativeMissionContact(
            contact, origin: emission.origin, damage: damage, laser: nil, mount: nil,
            emissionPosition: emission.preparation.launch)
        else {
          commander.flightSimulation = emission.flightBeforeEmission
          return false
        }
        projectScriptMissionImpact(receipt)
      } else {
        applyCombatHit(
          contact.hit, origin: emission.origin, kind: .laser, damage: damage,
          emissionPosition: emission.preparation.launch,
          energyMultiplier: energyMultiplier)
      }
    } else {
      recordCombat(
        origin: emission.origin, kind: .laser, outcome: .discharge, target: nil,
        worldPosition: emission.preparation.launch, emissionPosition: emission.preparation.launch)
    }
    return true
  }

  @inline(never)
  private mutating func finishNPCBeam(_ emission: NPCBeamEmission, bodyID: Int, damage: Double) {
    if let index = bodies.firstIndex(where: { $0.id == bodyID }) {
      bodies[index].physical?.npc?.resources?.recordBeam(heat: min(10, damage * 10 / 15))
    }
    commander.crimeLedger.finishEmission(emission.origin.emissionID)
  }

  @discardableResult mutating func applyAttributedEnergyBomb() -> Bool {
    ensurePhysicalActors()
    guard let player = commander.flightSimulation.player,
      let origin = makeAttackOrigin(owner: player)
    else { return false }
    let launch = commander.flightSimulation.pose.position
    for body in bodies where body.energy > 0 {
      guard
        applyCombatHit(
          .init(target: .body(body.id), distance: body.position.length, point: body.position),
          origin: origin, kind: .bomb, damage: body.hull.bombImmune ? 0 : body.energy,
          emissionPosition: launch) != nil
      else { return false }
      if let damaged = bodies.first(where: { $0.id == body.id }), damaged.energy <= 0,
        damaged.hull != .missile, damaged.physical?.deathIncidentID == nil
      {
        return false
      }
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
    return true
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
        || body.physical?.salvage?.lot != nil || body.nativeStationIdentity != nil
        || body.physical?.ordnance?.profile == .alienSeeker
      {
        result[body.id] = gameplayMesh(for: body)
      }
    }
    return result
  }

  func gameplayMesh(for body: SpaceBody) -> Mesh {
    if body.physical?.ordnance?.profile == .alienSeeker { return AlienMissileMesh.mesh }
    if let identity = body.nativeStationIdentity {
      guard nativeStationBodyIsCurrent(body),
        let source = NativeStationSource.binding(for: identity)
      else { return .init(vertices: [], faces: []) }
      return source.geometry.mesh
    }
    if body.hull == .station { return MainStationGeometry.mesh }
    if let payload = body.physical?.payload, case .salvage(let identity) = payload,
      let lot = salvageLotForGeometry(identity)
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
        faceMaterials: base.faceMaterials, faceTextures: base.faceTextures, preserveWinding: true)
    }
    if let id = body.physical?.catalogueShipID, let mesh = ShipCatalogue.rawMesh(id) {
      return mesh
    }
    let base = Mesh.hull(body.hull)
    guard let identity = body.physical?.rock,
      let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == identity })
    else { return base }
    let radius = base.vertices.map(\.length).max() ?? 1
    let scaled = Mesh(
      vertices: base.vertices.map { $0 * (rock.radius / radius) }, faces: base.faces,
      details: base.details, materials: base.materials, faceMaterials: base.faceMaterials,
      faceTextures: base.faceTextures, preserveWinding: true)
    return MiningRockAppearance.materials(for: rock, mesh: scaled)
  }
}
