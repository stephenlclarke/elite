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
    return !record.terminal && !record.isRecovered && record.hull.binding == body.physical?.identity
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

  /// Only an actual zero electrical reserve can transfer the live hull and people.
  /// The caller owns the whole-pulse candidate, including cost and legal incidents.
  @discardableResult
  mutating func disableEMPHull(id: Int, incident: CombatIncident, tool: OwnedEquipmentItem) -> Bool
  {
    guard let actual = bodies.first(where: { $0.id == id }),
      actual.physical?.npc?.resources?.electrical?.remaining == 0,
      actual.physical?.npc?.resources?.electrical?.disabledAt
        == commander.flightSimulation.physicalTime
    else { return false }
    guard
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
      let owner = commander.equipmentOwnerID
    else { return false }
    // A repeated hit has no new disable/ejection/loot transition or additional cost.
    guard physical.empSource == nil else { return false }
    var candidate = self
    var state = candidate.commander.savedEMPState ?? EMPState()
    guard state.valid else { return false }
    let priorSource =
      candidate.commander.npcPersistence.logicalIdentity(for: physical.identity)
      ?? state.records.first(where: {
        $0.value.isRecovered && $0.value.hull.binding == physical.identity
      })?.key
    let previous = priorSource.flatMap { state.records[$0] }
    if let previous {
      guard previous.isRecovered, !previous.terminal, previous.savedOrdinaryTerminal == nil,
        previous.crewAboard > 0,
        previous.disableEpisodes.count < EMPHullRecord.maximumDisableEpisodes
      else { return false }
    } else {
      guard state.records.count < EMPState.maximumHulls,
        crew <= EMPState.maximumPeople - state.records.values.reduce(0, { $0 + $1.crewTotal }),
        state.nextSequence < 1_000_000_000 - 1
      else { return false }
    }
    guard let custody = candidate.claimEMPSource(bodyID: id),
      let current = candidate.bodies.firstIndex(where: { $0.id == id })
    else { return false }
    let logical = previous?.source ?? custody.logical
    guard previous == nil || custody.logical == logical else { return false }
    let sequence = previous?.sequence ?? state.nextSequence
    let wreck =
      previous?.wreck
      ?? WreckIdentity(
        system: context.system,
        site: 0x8000_0000 + UInt32(sequence), lineage: logical.visit)
    candidate.bodies[current].physical?.canonicalSpin = true
    candidate.bodies[current].physical?.catalogueShipID = catalogue
    candidate.bodies[current].physical?.spawnIdentity = .init(
      system: context.system, visit: context.visit, sequence: sequence, member: 0, producer: .emp)
    candidate.bodies[current].physical?.empSource = logical
    candidate.bodies[current].physical?.salvage = .init(
      category: .wreck, ownership: .occupied, claimant: nil, wreck: wreck, section: nil, lot: nil,
      bounds: profile.bounds, workSurfaces: profile.surfaces(wreck: wreck))
    var record: EMPHullRecord
    if var retained = previous {
      retained.hull = .init(
        body: candidate.bodies[current], pose: candidate.commander.flightSimulation.pose,
        time: context.physicalTime)
      retained.savedCurrentTrafficTransfer = custody.traffic
      retained.savedCurrentCargo = npc.ordinaryCargo
      retained.savedCurrentLegal = npc.legal
      retained.savedRecoveredAt = nil
      retained.savedOrdinaryTerminal = nil
      record = retained
    } else {
      record = EMPHullRecord(
        source: logical, sequence: sequence, wreck: wreck, crewTotal: crew,
        originalSpawn: physical.spawnIdentity, originalBodyID: id, custody: custody,
        disableIncident: incident, weapon: tool, weaponOwner: owner,
        hull: .init(
          body: candidate.bodies[current], pose: candidate.commander.flightSimulation.pose,
          time: context.physicalTime), cargo: npc.ordinaryCargo, legal: npc.legal,
        nextEjectionAt: context.physicalTime + 1)
    }
    let ejections = candidate.sampleEMPCrewEjections(ordinals: record.aboardOrdinals)
    guard
      record.appendCrewDisableEpisode(
        incident: incident, weapon: tool, owner: owner, ejections: ejections), record.valid
    else { return false }
    state.records[logical] = record
    if previous == nil { state.nextSequence += 1 }
    candidate.commander.savedEMPState = state
    candidate.notify("ENGINES AND WEAPONS DISABLED - CREW EJECTION PENDING")
    guard candidate.commander.valid else { return false }
    self = candidate
    return true
  }
}
