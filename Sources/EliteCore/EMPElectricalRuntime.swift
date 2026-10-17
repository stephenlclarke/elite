import Foundation

private struct EMPPulseContact {
  let target: GameplayHitTarget
  let point: Vector3
  let power: Double
}

extension Game {
  var playerEMPDisabled: Bool { commander.savedPlayerElectrical?.disabledAt != nil }

  /// Repeated held-fire requests leave the actual ten-second simulation charge intact.
  @discardableResult
  mutating func fireEMPPirateBlaster() -> Bool {
    guard commander.savedEMPCharge == nil, !playerEMPDisabled,
      !docked, screen == .front, commander.valid,
      let tool = commander.fittedEquipment(at: .utility(.empPirateBlaster)),
      let owner = commander.equipmentOwnerID, let hull = commander.hullInstanceID,
      let profile = try? EMPPulseProfile.resolve(for: commander),
      laserHeat.isFinite, laserHeat + profile.heatCost < 240,
      fireCooldown.isFinite, fireCooldown <= 0
    else { return false }
    ensurePhysicalActors()
    guard let player = commander.flightSimulation.player,
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: profile.range,
        radius: 0, includePlayer: false),
      case .body(let id) = contact.hit.target,
      let body = bodies.first(where: { $0.id == id }), empPulseEligible(body),
      let target = body.physical?.identity,
      let reserve = currentPlayerElectrical(), reserve.remaining > profile.energyCost
    else { return false }
    commander.savedEMPCharge = .init(
      player: player, target: target, owner: owner, hull: hull, weapon: tool.id,
      startedAt: commander.flightSimulation.physicalTime)
    notify("EMP CHARGING - TEN SECONDS")
    return true
  }

  private func currentPlayerElectrical() -> ElectricalReserve? {
    let craft = commander.performance
    var reserve =
      commander.savedPlayerElectrical
      ?? ElectricalReserve(
        capacity: craft.energy,
        recharge: craft.recharge * commander.energyRechargeMultiplier,
        at: commander.flightSimulation.physicalTime)
    guard
      reserve?.advance(
        to: commander.flightSimulation.physicalTime,
        capacity: craft.energy, recharge: craft.recharge * commander.energyRechargeMultiplier)
        == true
    else { return nil }
    return reserve
  }

  func empPulseEligible(_ body: SpaceBody) -> Bool {
    guard body.energy > 0, [.cobra, .viper, .sidewinder].contains(body.hull),
      let physical = body.physical, let npc = physical.npc, npc.role != .mission,
      physical.empCrewPod == nil, physical.empSource == nil, physical.salvage == nil,
      !body.navalTarget, body.missionInstanceID == nil, body.blackjackRole == nil,
      let context = gameplayContext(),
      !context.protection.protectedActors.contains(physical.identity),
      let catalogue = physical.catalogueShipID ?? ShipCatalogue.nativeShip(body.hull)?.id,
      let ship = ShipCatalogue.ship(catalogue), EMPState.hasSupportedCrew(ship),
      SalvageCatalogue.empProfile(catalogueShipID: catalogue) != nil,
      npc.resources?.valid == true
    else { return false }
    return true
  }

  /// Called by the real, source-attributed activation producer; field expiry cannot undo it.
  mutating func cancelEMPCharge(for activation: ECMActivationIdentity) {
    guard var charge = commander.savedEMPCharge, charge.phase == .charging,
      charge.player.system == activation.emitter.system,
      charge.player.visit == activation.emitter.visit
    else { return }
    charge.phase = .cancelled
    charge.endedAt = commander.flightSimulation.physicalTime
    charge.cancellingECM = activation
    commander.savedEMPCharge = charge
    notify("EMP CHARGE CANCELLED BY ECM")
  }

  mutating func advancePlayerElectrical() {
    guard var reserve = commander.savedPlayerElectrical else { return }
    let now = commander.flightSimulation.physicalTime
    if reserve.recoveryAt.map({ now >= $0 }) == true {
      guard reserve.recover(at: now) else { return }
      notify("ELECTRICAL POWER RECOVERED")
    }
    let craft = commander.performance
    guard
      reserve.advance(
        to: now, capacity: craft.energy,
        recharge: craft.recharge * commander.energyRechargeMultiplier)
    else { return }
    commander.savedPlayerElectrical = reserve
  }

  mutating func advanceEMPCharge(triggerHeld: Bool) {
    guard var charge = commander.savedEMPCharge else { return }
    if charge.phase != .charging {
      if !triggerHeld { commander.savedEMPCharge = nil }
      return
    }
    let now = commander.flightSimulation.physicalTime
    guard now + 1e-9 >= charge.startedAt + 10 else { return }
    charge.phase = .released
    charge.endedAt = now
    // Consume the request before attempting release; refusal never retries on a later frame.
    commander.savedEMPCharge = charge
    guard emitEMPPulse(charge) else {
      notify("EMP RELEASE REFUSED - TARGET OR EQUIPMENT CHANGED")
      return
    }
  }

  private func pulseContacts(primary: GameplayHit, profile: EMPPulseProfile) -> [EMPPulseContact] {
    guard case .body(let primaryID) = primary.target else { return [] }
    var contacts: [EMPPulseContact] = [
      .init(target: primary.target, point: primary.point, power: profile.power)
    ]
    let origin = primary.point
    for body in bodies.sorted(by: { $0.id < $1.id })
    where body.id != primaryID && empPulseEligible(body) {
      let direction = body.position - origin
      let radius = gameplayMesh(for: body).vertices.map(\.length).max() ?? 0
      guard direction.length > 0, direction.length - radius < profile.splashRadius,
        let hit = try? nearestMissionCollision(
          from: origin, direction: direction.unit,
          range: profile.splashRadius, radius: 0, excludingBodyIDs: [primaryID], includePlayer: true
        ),
        hit.hit.target == .body(body.id)
      else { continue }
      let power = profile.power * max(0, 1 - hit.hit.distance / profile.splashRadius)
      if power > 0 {
        contacts.append(.init(target: .body(body.id), point: hit.hit.point, power: power))
      }
    }
    let towardPlayer = origin * -1
    if towardPlayer.length > 0,
      let hit = try? nearestMissionCollision(
        from: origin, direction: towardPlayer.unit,
        range: profile.splashRadius, radius: 0, excludingBodyIDs: [primaryID], includePlayer: true),
      hit.hit.target == .player
    {
      let power = profile.power * max(0, 1 - hit.hit.distance / profile.splashRadius)
      if power > 0 { contacts.append(.init(target: .player, point: hit.hit.point, power: power)) }
    }
    return contacts
  }

  /// Cost, all actual victims, law and any zero-power custody admission publish together.
  private mutating func emitEMPPulse(_ charge: EMPChargeState) -> Bool {
    guard !docked, !playerEMPDisabled, screen == .front, commander.valid,
      commander.flightSimulation.player == charge.player,
      commander.equipmentOwnerID == charge.owner, commander.hullInstanceID == charge.hull,
      let tool = commander.fittedEquipment(at: .utility(.empPirateBlaster)),
      tool.id == charge.weapon,
      let profile = try? EMPPulseProfile.resolve(for: commander),
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: profile.range, radius: 0, includePlayer: false),
      case .body(let id) = contact.hit.target,
      let primary = bodies.first(where: { $0.id == id }),
      primary.physical?.identity == charge.target,
      empPulseEligible(primary), var reserve = currentPlayerElectrical(),
      reserve.remaining > profile.energyCost, fireCooldown <= 0,
      laserHeat.isFinite, laserHeat + profile.heatCost < 240
    else { return false }
    let contacts = pulseContacts(primary: contact.hit, profile: profile)
    guard !contacts.isEmpty else { return false }
    var candidate = self
    let now = commander.flightSimulation.physicalTime
    guard reserve.drain(profile.energyCost, at: now),
      let origin = candidate.makeAttackOrigin(
        owner: charge.player, sourcePart: "emp:" + tool.id.uuidString)
    else { return false }
    candidate.commander.savedPlayerElectrical = reserve
    for hit in contacts {
      guard candidate.applyElectricalPulse(hit, origin: origin, tool: tool) else { return false }
    }
    candidate.laserHeat += profile.heatCost
    candidate.fireCooldown = profile.cooldown
    candidate.laserFlash = 0.08
    candidate.dischargeAudio.record(.empPirateBlaster)
    candidate.commander.crimeLedger.finishEmission(origin.emissionID)
    guard candidate.persistEMPState(), candidate.persistNPCStates().isEmpty,
      candidate.commander.valid
    else { return false }
    candidate.notify("EMP PULSE RELEASED")
    self = candidate
    return true
  }

  private mutating func applyElectricalPulse(
    _ hit: EMPPulseContact, origin: AttackOrigin,
    tool: OwnedEquipmentItem
  ) -> Bool {
    let now = commander.flightSimulation.physicalTime
    if hit.target == .player {
      guard var reserve = commander.savedPlayerElectrical else { return false }
      let front = hit.point.z >= 0
      let shield = front ? frontShield : rearShield
      let absorbed = min(shield, hit.power)
      if front { frontShield -= absorbed } else { rearShield -= absorbed }
      guard reserve.drain(hit.power - absorbed, at: now) else { return false }
      commander.savedPlayerElectrical = reserve
      if reserve.disabledAt != nil {
        releaseWorkGuidance()
        autoPilot.disengage()
        dockingComputer = false
        spin.stop(immediate: true)
        jumpCountdown = nil
        notify("ELECTRICAL POWER LOST - EMERGENCY BOMB OR ESCAPE POD AVAILABLE")
      }
      return true
    }
    guard case .body(let id) = hit.target,
      let index = bodies.firstIndex(where: { $0.id == id }), empPulseEligible(bodies[index]),
      var resources = bodies[index].physical?.npc?.resources
    else { return false }
    if resources.profile == .legacyEnergyOnly, resources.legacyElectricalRecharge == nil {
      guard
        let catalogue = bodies[index].physical?.catalogueShipID
          ?? ShipCatalogue.nativeShip(bodies[index].hull)?.id,
        let native = ShipCatalogue.ship(catalogue)?.game, native.valid
      else { return false }
      resources.legacyElectricalRecharge = native.recharge
    }
    guard
      var reserve = resources.electrical
        ?? ElectricalReserve(
          capacity: resources.energyCapacity,
          recharge: resources.electricalRecharge, at: now),
      reserve.advance(
        to: now, capacity: resources.energyCapacity, recharge: resources.electricalRecharge)
    else { return false }
    let facing =
      (hit.point - bodies[index].position).dot(bodies[index].modelVector(.init(0, 0, 1))) >= 0
    let overflow = resources.absorb(hit.power, front: facing)
    guard reserve.drain(overflow, at: now) else { return false }
    resources.electrical = reserve
    bodies[index].physical?.npc?.resources = resources
    guard
      let incident = recordCombat(
        origin: origin, kind: .emp, outcome: .hit, target: hit.target,
        worldPosition: commander.flightSimulation.pose.systemPoint(hit.point),
        emissionPosition: commander.flightSimulation.pose.position)
    else { return false }
    if reserve.remaining == 0 { return disableEMPHull(id: id, incident: incident, tool: tool) }
    return true
  }
}
