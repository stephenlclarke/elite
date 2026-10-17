import Foundation

extension Game {
  static let empRange = 3000.0
  static let empEnergyCost = 8.0
  static let empHeatCost = 18.0
  static let empCooldown = 1.5

  func isEMPDisabled(_ body: SpaceBody) -> Bool {
    guard let source = body.physical?.empSource,
      let record = commander.savedEMPState?.records[source]
    else { return false }
    return !record.terminal && record.hull.binding == body.physical?.identity
  }

  func empTargetStatus(_ body: SpaceBody) -> String? {
    if body.physical?.empCrewPod != nil {
      guard let context = gameplayContext(), let pod = nativePodFacts(body, context: context) else {
        return "OCCUPIED ESCAPE POD - PROTECTED"
      }
      if !hasNativeRescueTools { return "OCCUPIED POD - FIT SALVAGE MODULE AND FUEL SCOOPS" }
      return pod.fits ? "OCCUPIED POD - SINGLE 1T RESCUE UNIT" : "OCCUPIED POD - REAL HOLD FULL"
    }
    guard let source = body.physical?.empSource,
      let record = commander.savedEMPState?.records[source], isEMPDisabled(body)
    else { return nil }
    if record.crewAboard > 0 {
      let inWindow =
        record.crewDeadline.map { commander.flightSimulation.physicalTime < $0 } ?? false
      return inWindow
        ? "DISABLED - \(record.crewAboard) CREW ABOARD / CUTTER CAPTURE"
        : "CREW RECOVERY DEADLINE - CAPTURE CLOSED"
    }
    if let profile = salvageProfile(for: body),
      profile.sections.allSatisfy({
        commander.salvageLedger.isDepleted(.init(wreck: record.wreck, section: $0.index))
      })
    {
      return "ENGINES AND WEAPONS DISABLED - SALVAGE EXHAUSTED"
    }
    return "ENGINES AND WEAPONS DISABLED - UNOCCUPIED SALVAGE"
  }

  /// Electronic effects use a real occluded mesh hit and the ordinary aggression ledger, never damage.
  @discardableResult
  mutating func fireEMPPirateBlaster() -> Bool {
    guard !docked, screen == .front, commander.valid,
      let tool = commander.fittedEquipment(at: .utility(.empPirateBlaster)),
      energy.isFinite, energy > Self.empEnergyCost, laserHeat.isFinite,
      laserHeat + Self.empHeatCost < 240, fireCooldown.isFinite, fireCooldown <= 0
    else { return false }
    ensurePhysicalActors()
    guard
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: Self.empRange,
        radius: 0, includePlayer: false), case .body(let id) = contact.hit.target,
      let index = bodies.firstIndex(where: { $0.id == id }),
      let physical = bodies[index].physical, let npc = physical.npc,
      bodies[index].energy > 0, [.cobra, .viper, .sidewinder].contains(bodies[index].hull),
      !bodies[index].navalTarget, bodies[index].missionInstanceID == nil,
      bodies[index].blackjackRole == nil, npc.role != .mission, physical.salvage == nil,
      physical.empCrewPod == nil,
      let context = gameplayContext(),
      !context.protection.protectedActors.contains(physical.identity),
      let catalogue = physical.catalogueShipID ?? ShipCatalogue.nativeShip(bodies[index].hull)?.id,
      let ship = ShipCatalogue.ship(catalogue),
      EMPState.hasSupportedCrew(ship),
      let profile = SalvageCatalogue.empProfile(catalogueShipID: catalogue),
      let crew = try? ShipAccommodationProfile(ship: ship).operatingCrew, crew > 0,
      let player = commander.flightSimulation.player,
      let owner = commander.equipmentOwnerID
    else { return false }
    // A repeated hit has no new disable/ejection/loot transition or additional cost.
    guard physical.empSource == nil else { return false }
    var candidate = self
    var state = candidate.commander.savedEMPState ?? EMPState()
    guard state.valid else { return false }
    guard state.records.count < EMPState.maximumHulls,
      crew <= EMPState.maximumPeople - state.records.values.reduce(0, { $0 + $1.crewTotal }),
      state.nextSequence < 1_000_000_000 - 1
    else {
      notify("EMP CUSTODY CAPACITY FULL - NO DISABLEMENT")
      return false
    }
    guard let custody = candidate.claimEMPSource(bodyID: id),
      let origin = candidate.makeAttackOrigin(
        owner: player, sourcePart: "emp:" + tool.id.uuidString),
      let incident = candidate.recordCombat(
        origin: origin, kind: .emp, outcome: .hit, target: .body(id),
        worldPosition: candidate.commander.flightSimulation.pose.systemPoint(contact.hit.point),
        emissionPosition: candidate.commander.flightSimulation.pose.position),
      let current = candidate.bodies.firstIndex(where: { $0.id == id })
    else { return false }
    let logical = custody.logical
    let sequence = state.nextSequence
    let wreck = WreckIdentity(
      system: context.system, site: 0x8000_0000 + UInt32(sequence), lineage: logical.visit)
    candidate.bodies[current].physical?.canonicalSpin = true
    candidate.bodies[current].physical?.catalogueShipID = catalogue
    candidate.bodies[current].physical?.spawnIdentity = .init(
      system: context.system, visit: context.visit, sequence: sequence, member: 0, producer: .emp)
    candidate.bodies[current].physical?.empSource = logical
    candidate.bodies[current].physical?.salvage = .init(
      category: .wreck, ownership: .occupied, claimant: nil, wreck: wreck, section: nil, lot: nil,
      bounds: profile.bounds, workSurfaces: profile.surfaces(wreck: wreck))
    var record = EMPHullRecord(
      source: logical, sequence: sequence, wreck: wreck, crewTotal: crew,
      originalSpawn: physical.spawnIdentity, originalBodyID: id, custody: custody,
      disableIncident: incident, weapon: tool, weaponOwner: owner,
      hull: .init(
        body: candidate.bodies[current], pose: candidate.commander.flightSimulation.pose,
        time: context.physicalTime), cargo: npc.ordinaryCargo, legal: npc.legal,
      nextEjectionAt: context.physicalTime + 1)
    let ejections = candidate.sampleEMPCrewEjections(ordinals: record.aboardOrdinals)
    guard record.appendCrewDisableEpisode(incident: incident, ejections: ejections), record.valid
    else { return false }
    state.records[logical] = record
    state.nextSequence += 1
    candidate.commander.savedEMPState = state
    candidate.energy -= Self.empEnergyCost
    candidate.laserHeat += Self.empHeatCost
    candidate.fireCooldown = Self.empCooldown
    candidate.laserFlash = 0.08
    candidate.dischargeAudio.record(.empPirateBlaster)
    candidate.commander.crimeLedger.finishEmission(origin.emissionID)
    candidate.notify("ENGINES AND WEAPONS DISABLED - CREW EJECTION PENDING")
    guard candidate.commander.valid else { return false }
    self = candidate
    return true
  }
}
