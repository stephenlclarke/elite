import Foundation

private struct ScriptGunAddress {
  let weapon: String
  let componentAlias: String?
  let componentID: UUID?
}

extension Game {
  /// Cooling and aim belong to the frame; the native firing boundary owns every discharge.
  mutating func advanceScriptNPCWeapons(delta: Double) {
    guard delta.isFinite, delta > 0, delta <= 60 else { return }
    let identities = bodies.filter { $0.scriptNPC != nil && $0.energy > 0 }.map(\.id)
    for identity in identities {
      guard let npc = bodies.first(where: { $0.id == identity })?.scriptNPC else { continue }
      var addresses = (npc.fit.definition.lasers ?? []).map {
        ScriptGunAddress(weapon: $0.id, componentAlias: nil, componentID: nil)
      }
      for spec in npc.fit.definition.components ?? [] {
        guard let component = npc.components[spec.id], component.energy > 0 else { continue }
        addresses += (spec.weapons ?? []).map {
          ScriptGunAddress(weapon: $0.id, componentAlias: spec.id, componentID: component.identity)
        }
      }
      for address in addresses {
        advanceScriptGun(bodyID: identity, address: address, delta: delta)
      }
    }
  }

  private mutating func advanceScriptGun(bodyID: Int, address: ScriptGunAddress, delta: Double) {
    // An earlier weapon can change hull energy, shots, law and other gun state. Resolve this
    // weapon from the live body and publish only its cooled/aimed gun before native firing.
    guard let index = bodies.firstIndex(where: { $0.id == bodyID }), bodies[index].energy > 0,
      let npc = bodies[index].scriptNPC
    else { return }
    let body = bodies[index]
    let weapon: ScriptNPCWeapon
    var gun: ScriptNPCGunState
    let pose: Basis3
    let origin: Vector3
    if let alias = address.componentAlias, let identity = address.componentID {
      guard let component = npc.components[alias], component.identity == identity,
        component.energy > 0,
        let spec = npc.fit.definition.components?.first(where: { $0.id == alias }),
        let selected = spec.weapons?.first(where: { $0.id == address.weapon }),
        let selectedGun = component.guns[address.weapon]
      else { return }
      weapon = selected
      gun = selectedGun
      pose = spec.orientation.transformed(by: body.orientation)
      origin =
        body.position + body.orientation.apply(spec.position * npc.fit.definition.scale)
        + pose.apply(weapon.muzzle * (spec.scale * npc.fit.definition.scale))
    } else {
      guard let selected = npc.fit.definition.lasers?.first(where: { $0.id == address.weapon }),
        let selectedGun = npc.guns[address.weapon]
      else { return }
      weapon = selected
      gun = selectedGun
      pose = body.orientation
      origin = body.position + pose.apply(weapon.muzzle * npc.fit.definition.scale)
    }
    gun.cooldown = max(0, gun.cooldown - delta)
    gun.heat = max(0, gun.heat - weapon.cooling * delta)
    let target: Vector3?
    if let intent = npc.intent, intent.mode == .attack {
      target =
        intent.player
        ? Vector3(0, 0, 0)
        : bodies.first { $0.missionActorID == intent.target && $0.energy > 0 }?.position
    } else {
      target = nil
    }
    if let target {
      let difference = target - origin
      if difference.length > 1e-6, difference.length <= weapon.range {
        let desired = pose.inverse(difference.unit)
        if desired.dot(weapon.direction) >= cos(weapon.arc) - 1e-9 {
          gun.aim = Self.scriptWeaponAim(
            gun.aim ?? weapon.direction, toward: desired,
            step: (weapon.trackingRate ?? 0) * delta)
        }
      }
    }
    if let alias = address.componentAlias {
      bodies[index].scriptNPC?.components[alias]?.guns[address.weapon] = gun
    } else {
      bodies[index].scriptNPC?.guns[address.weapon] = gun
    }
    do {
      _ = try fireMissionNativeWeapon(
        bodyID: bodyID, weaponID: address.weapon, componentID: address.componentID)
    } catch {
      recordScriptCombatRefusal(error, instance: body.missionInstanceID)
    }
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

  /// The sealed native step owns motion, impact, terminal cleanup and the one projection call.
  mutating func advanceScriptNPCShots(delta: Double) {
    guard delta.isFinite, delta > 0, delta <= 60 else { return }
    let shots = bodies.filter { $0.scriptShot != nil && $0.energy > 0 }.compactMap(\.scriptShot)
    for shot in shots {
      do {
        _ = try stepMissionNativeProjectile(projectileID: shot.identity, delta: delta)
      } catch {
        recordScriptCombatRefusal(error, instance: shot.instance)
      }
    }
  }

  private mutating func recordScriptCombatRefusal(_ error: any Error, instance: UUID?) {
    if error is ScriptMissionEventCapacityError { return }
    if let refusal = error as? NativeMissionProjectileAdmissionError {
      switch refusal {
      case .unavailablePack, .outsideBubble, .allocatorExhausted, .refused: return
      case .missingRecord, .invalidRecord: break
      }
    }
    guard let instance, commander.scriptState.instances[instance]?.suspension == nil else { return }
    commander.scriptState.instances[instance]?.suspension =
      "Native mission combat refused: \(error)"
  }
}
