import Foundation

extension Game {
  mutating func advanceScriptNPCWeapons(delta: Double) {
    let identities = bodies.filter { $0.scriptNPC != nil && $0.energy > 0 }.map(\.id)
    for id in identities {
      guard let index = bodies.firstIndex(where: { $0.id == id }),
        var npc = bodies[index].scriptNPC
      else { continue }
      let body = bodies[index]
      let target: Vector3?
      if let intent = npc.intent, intent.mode == .attack {
        target =
          intent.player
          ? Vector3(0, 0, 0)
          : bodies.first { $0.missionActorID == intent.target && $0.energy > 0 }?.position
      } else {
        target = nil
      }
      for weapon in npc.fit.definition.lasers ?? [] {
        guard var gun = npc.guns[weapon.id] else { continue }
        let pose = body.orientation
        let origin = body.position + pose.apply(weapon.muzzle * npc.fit.definition.scale)
        advanceScriptGun(
          weapon, gun: &gun, npc: &npc, body: body,
          component: nil, origin: origin, pose: pose, target: target, delta: delta)
        npc.guns[weapon.id] = gun
      }
      for spec in npc.fit.definition.components ?? [] {
        guard var component = npc.components[spec.id], component.energy > 0 else { continue }
        let pose = spec.orientation.transformed(by: body.orientation)
        let center =
          body.position + body.orientation.apply(spec.position * npc.fit.definition.scale)
        for weapon in spec.weapons ?? [] {
          guard var gun = component.guns[weapon.id] else { continue }
          let origin = center + pose.apply(weapon.muzzle * (spec.scale * npc.fit.definition.scale))
          advanceScriptGun(
            weapon, gun: &gun, npc: &npc, body: body,
            component: component.identity, origin: origin, pose: pose, target: target, delta: delta)
          component.guns[weapon.id] = gun
        }
        npc.components[spec.id] = component
      }
      bodies[index].scriptNPC = npc
    }
  }
  private mutating func advanceScriptGun(
    _ weapon: ScriptNPCWeapon, gun: inout ScriptNPCGunState, npc: inout ScriptNPCState,
    body: SpaceBody, component: UUID?, origin: Vector3, pose: Basis3, target: Vector3?,
    delta: Double
  ) {
    gun.cooldown = max(0, gun.cooldown - delta)
    gun.heat = max(0, gun.heat - weapon.cooling * delta)
    guard let target, let owner = body.missionActorID, let instance = body.missionInstanceID,
      let index = bodies.firstIndex(where: { $0.id == body.id }), bodies[index].energy > 0
    else { return }
    let toTarget = target - origin
    guard toTarget.length > 1e-6, toTarget.length <= weapon.range else { return }
    let desired = pose.inverse(toTarget.unit)
    guard desired.dot(weapon.direction) >= cos(weapon.arc) - 1e-9 else { return }
    let current = gun.aim ?? weapon.direction
    gun.aim = Self.scriptWeaponAim(
      current, toward: desired,
      step: (weapon.trackingRate ?? 0) * delta)
    let direction = pose.apply(gun.aim ?? weapon.direction).unit
    guard gun.cooldown <= 0, gun.heat + weapon.heat <= weapon.maximumHeat,
      bodies[index].energy > weapon.energy,
      direction.dot(toTarget.unit) > 0.999,
      npc.shots < UInt64(Int64.max)
    else { return }
    if weapon.kind == .plasma {
      let saved = Set(commander.scriptState.projectiles.keys)
      let current = Set(bodies.compactMap { $0.scriptShot?.identity })
      guard saved.union(current).count < 1024,
        bodies.reduce(0, { $0 + $1.scriptNativeUnits }) < 1024, nextBodyID < 999_999_999,
        let speed = weapon.projectileSpeed, let lifetime = weapon.lifetime,
        let radius = weapon.collisionRadius, let delay = weapon.collisionDelay
      else { return }
      var projectile = SpaceBody(id: nextBodyID, hull: .missile, position: origin)
      projectile.rotationRate = 0
      projectile.scriptShot = .init(
        identity: Self.scriptShotIdentity(owner: owner, shot: npc.shots + 1), owner: owner,
        instance: instance,
        weapon: weapon.id, component: component, velocity: direction * speed,
        age: 0, lifetime: lifetime, damage: weapon.damage, radius: radius, collisionDelay: delay)
      bodies.append(projectile)
      nextBodyID += 1
    } else {
      let hit = scriptNPCHit(
        from: origin, direction: direction, range: weapon.range, excluding: owner)
      let player = scriptPlayerHit(from: origin, direction: direction, range: weapon.range)
      gun.beamRange = min(weapon.range, hit?.distance ?? .infinity, player ?? .infinity)
      if let player, player <= weapon.range && player <= (hit?.distance ?? .infinity) {
        applyDamage(weapon.damage, front: origin.z >= 0)
      } else if let hit {
        damageScriptNPC(hit, amount: weapon.damage, player: false, attacker: owner)
      }
    }
    bodies[index].energy = max(0, bodies[index].energy - weapon.energy)
    gun.heat += weapon.heat
    gun.cooldown = weapon.interval
    npc.shots += 1
    emitScriptEvent(
      "weapon.fired",
      values: [
        "actor_id": .string(owner.uuidString),
        "weapon": .string(weapon.id), "shot": .integer(Int64(npc.shots)),
        "component_id": component.map { .string($0.uuidString) } ?? .null,
      ],
      only: instance, drain: false)
  }
  private static func scriptShotIdentity(owner: UUID, shot: UInt64) -> UUID {
    ScriptIdentity.uuid("npc-shot-v1:\(owner):\(shot)")
  }
  private static func scriptWeaponAim(_ current: Vector3, toward desired: Vector3, step: Double)
    -> Vector3
  {
    let angle = acos(max(-1, min(1, current.dot(desired))))
    guard step > 0, angle > 1e-9 else { return current }
    if step >= angle { return desired }
    var axis = current.cross(desired)
    if axis.length < 1e-9 {
      axis = current.cross(abs(current.x) < 0.9 ? .init(1, 0, 0) : .init(0, 1, 0))
    }
    axis = axis.unit
    return
      (current * cos(step) + axis.cross(current) * sin(step)
      + axis * (axis.dot(current) * (1 - cos(step)))).unit
  }
  mutating func advanceScriptNPCShots(delta: Double) {
    for id in bodies.filter({ $0.scriptShot != nil && $0.energy > 0 }).map(\.id) {
      guard let index = bodies.firstIndex(where: { $0.id == id }),
        var shot = bodies[index].scriptShot
      else { continue }
      let dt = min(delta, max(0, shot.lifetime - shot.age))
      let origin = bodies[index].position
      let end = origin + shot.velocity * dt
      let activeAfter = max(0, shot.collisionDelay - shot.age)
      shot.age += dt
      if activeAfter < dt {
        let start = origin + shot.velocity * activeAfter
        let distance = shot.velocity.length * (dt - activeAfter)
        let direction = shot.velocity.unit
        let hit = scriptNPCHit(
          from: start, direction: direction,
          range: distance, excluding: shot.owner, radius: shot.radius)
        let player = scriptPlayerHit(
          from: start, direction: direction, range: distance, radius: shot.radius)
        if let player, player <= distance && player <= (hit?.distance ?? .infinity) {
          applyDamage(shot.damage, front: start.z >= 0)
          bodies[index].energy = 0
        } else if let hit {
          damageScriptNPC(hit, amount: shot.damage, player: false, attacker: shot.owner)
          bodies[index].energy = 0
        }
      }
      bodies[index].position = end
      bodies[index].scriptShot = shot
      if shot.age >= shot.lifetime { bodies[index].energy = 0 }
    }
  }
}
