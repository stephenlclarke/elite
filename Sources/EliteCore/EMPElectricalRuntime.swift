import Foundation

private struct EMPPulseContact {
  let target: GameplayHitTarget
  let point: Vector3
  let power: Double
}

/// A zero-power transition finishes synchronously after application temporaries unwind.
private enum EMPPulseApplication {
  case refused
  case applied
  case pendingDisable(id: Int, incident: CombatIncident, context: EncounterContext)
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
    guard !docked, !playerEMPDisabled, screen == .front, commander.valid else { return false }
    var candidate = self
    guard candidate.buildEMPPulseEffects(charge),
      candidate.persistEMPState(), candidate.persistNPCStates().isEmpty,
      candidate.commander.valid
    else { return false }
    candidate.notify("EMP PULSE RELEASED")
    self = candidate
    return true
  }

  /// Preflight and all discharge effects finish before full archive/scene validation starts.
  /// Only the caller's private candidate is changed; refusal discards every staged effect.
  private mutating func buildEMPPulseEffects(_ charge: EMPChargeState) -> Bool {
    guard commander.flightSimulation.player == charge.player,
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
    let now = commander.flightSimulation.physicalTime
    guard reserve.drain(profile.energyCost, at: now),
      let origin = makeAttackOrigin(
        owner: charge.player, sourcePart: "emp:" + tool.id.uuidString)
    else { return false }
    commander.savedPlayerElectrical = reserve
    for hit in contacts {
      switch applyElectricalPulse(hit, origin: origin) {
      case .refused:
        return false
      case .applied:
        break
      case .pendingDisable(let id, let incident, let context):
        // Finish this victim before any next contact, after the pulse-application frame unwinds.
        guard disableEMPHull(id: id, incident: incident, tool: tool, context: context),
          commander.valid
        else { return false }
      }
    }
    laserHeat += profile.heatCost
    fireCooldown = profile.cooldown
    laserFlash = 0.08
    dischargeAudio.record(.empPirateBlaster)
    commander.crimeLedger.finishEmission(origin.emissionID)
    return true
  }

  private mutating func applyElectricalPulse(
    _ hit: EMPPulseContact, origin: AttackOrigin
  ) -> EMPPulseApplication {
    let now = commander.flightSimulation.physicalTime
    if hit.target == .player {
      guard var reserve = commander.savedPlayerElectrical else { return .refused }
      let front = hit.point.z >= 0
      let shield = front ? frontShield : rearShield
      let absorbed = min(shield, hit.power)
      if front { frontShield -= absorbed } else { rearShield -= absorbed }
      guard reserve.drain(hit.power - absorbed, at: now) else { return .refused }
      commander.savedPlayerElectrical = reserve
      if reserve.disabledAt != nil {
        let momentum = flightWorldVelocity
        releaseWorkGuidance()
        autoPilot.disengage()
        dockingComputer = false
        speed = 0
        manualResidualFlight = true
        autoPilot.setApproachVelocity(commander.flightSimulation.pose.shipVector(momentum))
        jumpCountdown = nil
        notify("ELECTRICAL POWER LOST - EMERGENCY BOMB OR ESCAPE POD AVAILABLE")
      }
      return .applied
    }
    guard case .body(let id) = hit.target,
      let index = bodies.firstIndex(where: { $0.id == id }), empPulseEligible(bodies[index]),
      var resources = bodies[index].physical?.npc?.resources
    else { return .refused }
    var legacyCatalogue: String?
    if resources.profile == .legacyEnergyOnly {
      guard
        let catalogue = bodies[index].physical?.catalogueShipID
          ?? ShipCatalogue.nativeShip(bodies[index].hull)?.id,
        let native = ShipCatalogue.ship(catalogue)?.game, native.valid,
        resources.legacyElectricalRecharge == nil
          || resources.legacyElectricalRecharge == native.recharge
      else { return .refused }
      resources.legacyElectricalRecharge = native.recharge
      legacyCatalogue = catalogue
    }
    guard
      var reserve = resources.electrical
        ?? ElectricalReserve(
          capacity: resources.energyCapacity,
          recharge: resources.electricalRecharge, at: now),
      reserve.advance(
        to: now, capacity: resources.energyCapacity, recharge: resources.electricalRecharge)
    else { return .refused }
    let facing =
      (hit.point - bodies[index].position).dot(bodies[index].modelVector(.init(0, 0, 1))) >= 0
    let overflow = resources.absorb(hit.power, front: facing)
    guard reserve.drain(overflow, at: now) else { return .refused }
    resources.electrical = reserve
    bodies[index].physical?.npc?.resources = resources
    guard
      let incident = recordCombat(
        origin: origin, kind: .emp, outcome: .hit, target: hit.target,
        worldPosition: commander.flightSimulation.pose.systemPoint(hit.point),
        emissionPosition: commander.flightSimulation.pose.position)
    else { return .refused }
    if reserve.remaining == 0 {
      // A positive partial hit retains its existing native mesh; custody already pins on zero.
      if let legacyCatalogue { bodies[index].physical?.catalogueShipID = legacyCatalogue }
      guard let context = gameplayContext() else { return .refused }
      return .pendingDisable(id: id, incident: incident, context: context)
    }
    return .applied
  }

  /// Only an actual zero electrical reserve can transfer the live hull and people.
  /// Only buildEMPPulseEffects calls this inside emitEMPPulse's atomic candidate.
  /// Any refusal discards that entire candidate, including earlier victims and cost.
  @discardableResult
  private mutating func disableEMPHull(
    id: Int, incident: CombatIncident, tool: OwnedEquipmentItem, context: EncounterContext
  ) -> Bool {
    guard let preparation = prepareEMPDisable(id: id, context: context),
      let custody = claimEMPSource(bodyID: id, context: context, pose: preparation.facts.pose),
      var record = constructDisabledEMPRecord(
        id: id, incident: incident, tool: tool, context: context,
        preparation: preparation, custody: custody)
    else { return false }
    let ejections = sampleEMPCrewEjections(ordinals: record.aboardOrdinals)
    guard
      record.appendCrewDisableEpisode(
        incident: incident, weapon: tool, owner: preparation.facts.owner, ejections: ejections),
      record.valid
    else { return false }
    var state = preparation.facts.state
    state.records[record.source] = record
    if preparation.previousSource == nil { state.nextSequence += 1 }
    commander.savedEMPState = state
    notify("ENGINES AND WEAPONS DISABLED - CREW EJECTION PENDING")
    return true
  }

  // Finish immutable eligibility reads before claiming the complete original source.
  private func prepareEMPDisable(id: Int, context: EncounterContext) -> EMPDisablePreparation? {
    guard let actual = bodies.first(where: { $0.id == id }),
      let actor = actual.physical?.identity, let facts = commander.empDisableFacts(actor: actor),
      actual.physical?.npc?.resources?.electrical?.remaining == 0,
      actual.physical?.npc?.resources?.electrical?.disabledAt
        == facts.time
    else { return nil }
    guard
      let index = bodies.firstIndex(where: { $0.id == id }),
      let physical = bodies[index].physical, let npc = physical.npc,
      bodies[index].energy > 0, [.cobra, .viper, .sidewinder].contains(bodies[index].hull),
      !bodies[index].navalTarget, bodies[index].missionInstanceID == nil,
      bodies[index].blackjackRole == nil, npc.role != .mission, physical.salvage == nil,
      physical.empCrewPod == nil,
      !context.protection.protectedActors.contains(physical.identity),
      let catalogue = physical.catalogueShipID ?? ShipCatalogue.nativeShip(bodies[index].hull)?.id,
      let ship = ShipCatalogue.ship(catalogue),
      EMPState.hasSupportedCrew(ship),
      let profile = SalvageCatalogue.empProfile(catalogueShipID: catalogue),
      let crew = try? ShipAccommodationProfile(ship: ship).operatingCrew, crew > 0
    else { return nil }
    // A repeated hit has no new disable/ejection/loot transition or additional cost.
    guard physical.empSource == nil else { return nil }
    let state = facts.state
    guard state.valid else { return nil }
    let priorSource =
      facts.logical
      ?? state.records.first(where: {
        $0.value.isRecovered && $0.value.hull.binding == physical.identity
      })?.key
    let previous = priorSource.flatMap { state.records[$0] }
    if let previous {
      guard previous.isRecovered, !previous.terminal, previous.savedOrdinaryTerminal == nil,
        previous.crewAboard > 0,
        previous.disableEpisodes.count < EMPHullRecord.maximumDisableEpisodes
      else { return nil }
    } else {
      guard state.records.count < EMPState.maximumHulls,
        crew <= EMPState.maximumPeople - state.records.values.reduce(0, { $0 + $1.crewTotal }),
        state.nextSequence < 1_000_000_000 - 1
      else { return nil }
    }
    return .init(
      facts: facts, previousSource: previous?.source, catalogue: catalogue, crew: crew,
      profile: profile, originalSpawn: physical.spawnIdentity,
      cargo: npc.ordinaryCargo, legal: npc.legal)
  }

  // Construct the record after custody admission, before sampling or validating its episode.
  private mutating func constructDisabledEMPRecord(
    id: Int, incident: CombatIncident, tool: OwnedEquipmentItem, context: EncounterContext,
    preparation: EMPDisablePreparation, custody: EMPSourceCustody
  ) -> EMPHullRecord? {
    guard let current = bodies.firstIndex(where: { $0.id == id }) else { return nil }
    let previous = preparation.previousSource.flatMap { preparation.facts.state.records[$0] }
    let logical = previous?.source ?? custody.logical
    guard previous == nil || custody.logical == logical else { return nil }
    let sequence = previous?.sequence ?? preparation.facts.state.nextSequence
    let wreck =
      previous?.wreck
      ?? WreckIdentity(
        system: context.system,
        site: 0x8000_0000 + UInt32(sequence), lineage: logical.visit)
    bodies[current].physical?.canonicalSpin = true
    bodies[current].physical?.catalogueShipID = preparation.catalogue
    bodies[current].physical?.spawnIdentity = .init(
      system: context.system, visit: context.visit, sequence: sequence, member: 0, producer: .emp)
    bodies[current].physical?.empSource = logical
    bodies[current].physical?.salvage = .init(
      category: .wreck, ownership: .occupied, claimant: nil, wreck: wreck, section: nil, lot: nil,
      bounds: preparation.profile.bounds, workSurfaces: preparation.profile.surfaces(wreck: wreck))
    var record: EMPHullRecord
    if var retained = previous {
      retained.hull = .init(
        body: bodies[current], pose: preparation.facts.pose,
        time: context.physicalTime)
      retained.savedCurrentTrafficTransfer = custody.traffic
      retained.savedCurrentCargo = preparation.cargo
      retained.savedCurrentLegal = preparation.legal
      retained.savedRecoveredAt = nil
      retained.savedOrdinaryTerminal = nil
      record = retained
    } else {
      record = EMPHullRecord(
        source: logical, sequence: sequence, wreck: wreck, crewTotal: preparation.crew,
        originalSpawn: preparation.originalSpawn, originalBodyID: id, custody: custody,
        disableIncident: incident, weapon: tool, weaponOwner: preparation.facts.owner,
        hull: .init(
          body: bodies[current], pose: preparation.facts.pose,
          time: context.physicalTime), cargo: preparation.cargo, legal: preparation.legal,
        nextEjectionAt: context.physicalTime + 1)
    }
    return record
  }
}

extension Game {
  /// Police bookkeeping is not mission immunity. Actual traffic custody is retired only when it exists.
  private mutating func claimEMPSource(
    bodyID: Int, context: EncounterContext, pose: ShipPose
  ) -> EMPSourceCustody? {
    guard let body = bodies.first(where: { $0.id == bodyID }), let physical = body.physical,
      let npc = physical.npc,
      !context.protection.protectedActors.contains(physical.identity)
    else { return nil }
    if !physical.blocksNavalEncounter {
      guard !persistNPCStates(context: context, pose: pose).contains(bodyID) else { return nil }
    } else if npc.role != .police || physical.population != .police {
      return nil
    }
    let facts = commander.empSourceClaimFacts(actor: physical.identity)
    let logical = facts.logical
    let traffic = facts.traffic
    let evidence = EMPSourceCustody(
      kind: npc.role == .police ? .police : .ordinary,
      logical: logical,
      original: .init(
        body: body, pose: pose,
        time: context.physicalTime), traffic: traffic,
      assignment: facts.assignment)
    guard evidence.valid else { return nil }
    if traffic != nil {
      guard commander.npcPersistence.terminal(actor: physical.identity, reason: .empTransferred)
      else {
        return nil
      }
    }
    return evidence
  }
}

private struct EMPDisableFacts {
  let time: Double
  let pose: ShipPose
  let owner: UUID
  let state: EMPState
  let logical: ActorIdentity?
}
private struct EMPDisablePreparation {
  let facts: EMPDisableFacts
  let previousSource: ActorIdentity?
  let catalogue: String
  let crew: Int
  let profile: SalvageProfile
  let originalSpawn: SpawnIdentity?
  let cargo: [CommodityAmount]
  let legal: LegalRecord
}
private struct EMPSourceClaimFacts {
  let logical: ActorIdentity
  let traffic: NPCPersistenceSnapshot?
  let assignment: PoliceAssignment?
}
extension Commander {
  /// Read the large commander value once, retaining only immutable transition facts.
  fileprivate func empDisableFacts(actor: ActorIdentity) -> EMPDisableFacts? {
    guard let owner = equipmentOwnerID else { return nil }
    return .init(
      time: flightSimulation.physicalTime, pose: flightSimulation.pose,
      owner: owner, state: savedEMPState ?? EMPState(),
      logical: npcPersistence.logicalIdentity(for: actor))
  }
  fileprivate func empSourceClaimFacts(actor: ActorIdentity) -> EMPSourceClaimFacts {
    let logical =
      npcPersistence.logicalIdentity(for: actor)
      ?? savedEMPState?.records.first(where: {
        $0.value.isRecovered && $0.value.savedOrdinaryTerminal == nil
          && $0.value.hull.binding == actor
      })?.key ?? actor
    return .init(
      logical: logical, traffic: npcPersistence.snapshot(for: logical),
      assignment: stationSecurity.assignments.first { $0.actor == actor })
  }
}
