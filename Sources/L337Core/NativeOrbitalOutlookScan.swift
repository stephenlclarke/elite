import Foundation

/// Only completed native observations persist. Unfinished dwell and refusal retries stay runtime-local.
struct NativeOrbitalOutlookReading: Codable, Sendable, Equatable {
  let operation: UUID
  let authority: UUID
  let mission: UUID
  let boarding: UUID
  let owner: UUID
  let people: [NativePersonReference]
  let carrier: UUID
  let berths: [UUID]
  let equipment: UUID
  let inventoryRevision: UInt64
  let ordinal: Int
  let marker: UUID
  let actor: ActorIdentity
  let player: ActorIdentity
  let start: Double
  let end: Double
  let qualifiedSeconds: Double
  let intervals: Int
  let epoch: UUID
  let revision: UInt64
}

/// A bounded historical witness minted from the actual fitted item and owned native marker.
/// It survives later refitting and native rebinding; the live epoch is never a cold-load oracle.
struct NativeOrbitalOutlookAuthority: Codable, Sendable, Equatable {
  let id: UUID
  let operation: UUID
  let boarding: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
  let equipment: EquipmentPurchaseItem
  let marker: ScriptOwnedActor
  let observedAt: Double
}
/// Immutable attempt-local pending value; copying Game never copies another inline actor snapshot.
final class NativeOrbitalOutlookPending: Sendable, Equatable {
  let reading: NativeOrbitalOutlookReading
  let authority: NativeOrbitalOutlookAuthority
  init(reading: NativeOrbitalOutlookReading, authority: NativeOrbitalOutlookAuthority) {
    self.reading = reading
    self.authority = authority
  }
  static func == (lhs: NativeOrbitalOutlookPending, rhs: NativeOrbitalOutlookPending) -> Bool {
    lhs.reading == rhs.reading && lhs.authority == rhs.authority
  }
}

struct NativeOrbitalOutlookSample: Sendable, Equatable {
  let mission: UUID
  let boarding: UUID
  let owner: UUID
  let carrier: UUID
  let equipment: UUID
  let inventoryRevision: UInt64
  let ordinal: Int
  let marker: UUID
  let actor: ActorIdentity
  let player: ActorIdentity
  let time: Double
  let epoch: UUID
  func sameAuthority(as other: Self) -> Bool {
    mission == other.mission && boarding == other.boarding && owner == other.owner
      && carrier == other.carrier && equipment == other.equipment
      && inventoryRevision == other.inventoryRevision && ordinal == other.ordinal
      && marker == other.marker && actor == other.actor && player == other.player
      && epoch == other.epoch
  }
}
struct NativeOrbitalOutlookObservation: Sendable, Equatable {
  let first: NativeOrbitalOutlookSample
  var last: NativeOrbitalOutlookSample
  var seconds: Double
  var intervals: Int
}
struct NativeOrbitalOutlookRuntime: Sendable, Equatable {
  var observation: NativeOrbitalOutlookObservation?
  var pending: NativeOrbitalOutlookPending?
  var reason = "Lock the next marker in the front view."
}

extension NativeOrbitalOutlookJourney {
  static func markerIdentity(mission: UUID, ordinal: Int) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(mission):\(digest):\(encounterID):\(views[ordinal])")
  }
  static func returnReady(
    _ source: NativeOrbitalOutlookJourneyState, dock: NativeMainStationDockReceipt
  ) -> Bool {
    guard source.readings.count == 3, let boarding = source.boarding,
      let last = source.readings.last, sourceMatches(dock),
      dock.sequence > boarding.dock.sequence, dock.actor.visit > last.actor.visit
    else { return false }
    return true
  }
  @inline(never)
  static func readingsValid(
    _ source: borrowing NativeOrbitalOutlookJourneyState, commander: borrowing Commander
  ) -> Bool {
    guard source.readings.count <= 3, source.authorities.count == source.readings.count else {
      return false
    }
    guard let boarding = source.boarding else {
      guard source.readings.isEmpty else { return false }
      return source.authorities.isEmpty
    }
    var lastEnd = boarding.physicalTime
    var operations: Set<UUID> = []
    for (ordinal, reading) in source.readings.enumerated() {
      guard reading.ordinal == ordinal,
        authorityValid(
          source.authorities[ordinal], reading: reading, source: source, commander: commander),
        reading.revision == UInt64(ordinal + 1),
        operations.insert(reading.operation).inserted,
        reading.operation
          == ScriptIdentity.uuid("native-outlook-reading-v1:\(boarding.operation):\(ordinal)"),
        reading.mission == boarding.mission, reading.boarding == boarding.operation,
        reading.owner == source.owner, reading.people == source.references,
        reading.carrier == boarding.carrier, reading.berths == boarding.berths,
        reading.marker == markerIdentity(mission: boarding.mission, ordinal: ordinal),
        reading.actor.system == SystemIdentity(galaxy: 0, system: 185),
        reading.player.system == reading.actor.system, reading.player.visit == reading.actor.visit,
        reading.player.entity == 0, reading.actor.entity > 1,
        reading.actor.entity < commander.flightSimulation.nextActor,
        reading.actor.visit > boarding.dock.actor.visit,
        reading.actor.visit <= commander.flightSimulation.visit,
        reading.start.isFinite, reading.end.isFinite, reading.qualifiedSeconds.isFinite,
        reading.start >= lastEnd, reading.end <= commander.flightSimulation.physicalTime,
        reading.end > reading.start, reading.qualifiedSeconds >= 12,
        reading.qualifiedSeconds <= 12.1 + 1e-8,
        abs(reading.end - reading.start - reading.qualifiedSeconds) < 1e-6,
        reading.intervals >= 120, reading.intervals <= 1_000_000,
        reading.qualifiedSeconds <= Double(reading.intervals) * 0.1 + 1e-6,
        retainedReadingMarkerValid(
          mission: boarding.mission, ordinal: ordinal,
          marker: reading.marker, commander: commander)
      else { return false }
      lastEnd = reading.end
    }
    return true
  }
}

extension NativeOrbitalOutlookJourney {
  @inline(never)
  private static func retainedReadingMarkerValid(
    mission: UUID, ordinal: Int, marker: UUID,
    commander: borrowing Commander
  ) -> Bool {
    for index in commander.scriptState.instances.indices {
      if commander.scriptState.instances.keys[index] == mission {
        return retainedReadingInstanceValid(
          commander.scriptState.instances.values[index],
          ordinal: ordinal, marker: marker)
      }
    }
    return false
  }
  @inline(never)
  private static func retainedReadingInstanceValid(
    _ instance: borrowing ScriptInstance,
    ordinal: Int, marker: UUID
  ) -> Bool {
    for index in instance.ownedEncounters.indices {
      if instance.ownedEncounters.keys[index] == encounterID {
        return retainedReadingEncounterValid(
          instance.ownedEncounters.values[index],
          ordinal: ordinal, marker: marker)
      }
    }
    return false
  }
  @inline(never)
  private static func retainedReadingEncounterValid(
    _ encounter: borrowing ScriptOwnedEncounter,
    ordinal: Int, marker: UUID
  ) -> Bool {
    guard encounter.admitted, encounter.galaxy == 0, encounter.system == 185 else { return false }
    for index in encounter.actors.indices {
      if encounter.actors.keys[index] == views[ordinal] {
        return encounter.actors.values[index].identity == marker
      }
    }
    return false
  }
}

extension Game {
  /// Read-only start/end qualification. Selection and telemetry alone never advance a view.
  func orbitalOutlookSample() -> NativeOrbitalOutlookSample? {
    guard !paused, !docked, !playerEMPDisabled, screen == .front, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil,
      commander.system == 185, commander.galaxy == 0,
      let source = commander.nativePeople?.outlookJourney, source.terminalOperation == nil,
      let boarding = source.boarding, source.readings.count < 3,
      let mission = commander.scriptState.instances[boarding.mission], mission.outcome == .active,
      let equipment = commander.fittedEquipment(at: .targetingCore), commander.targetingTier != nil,
      let inventory = commander.equipmentInventory,
      let player = commander.flightSimulation.player, player.entity == 0,
      player.system == SystemIdentity(galaxy: 0, system: 185),
      let owner = commander.equipmentOwnerID, owner == source.owner,
      let carrier = commander.hullInstanceID, carrier == boarding.carrier,
      equipment.location?.hullInstanceID == carrier,
      let people = commander.nativePeople,
      source.references.allSatisfy({ person in people.held.contains { $0.person == person } }),
      NativeStationPassengerJourney.berthsValid(commander),
      let selected = informationTargetBody, let physical = selected.physical,
      selected.energy > 0, !selected.hostile,
      let encounter = mission.ownedEncounters[NativeOrbitalOutlookJourney.encounterID],
      encounter.admitted,
      encounter.galaxy == 0, encounter.system == 185
    else { return nil }
    let ordinal = source.readings.count
    let alias = NativeOrbitalOutlookJourney.views[ordinal]
    let marker = NativeOrbitalOutlookJourney.markerIdentity(mission: mission.id, ordinal: ordinal)
    guard let actor = encounter.actors[alias], actor.identity == marker, actor.presence == .present,
      selected.missionActorID == marker, selected.missionInstanceID == mission.id,
      actor.body.id == selected.id, physical.identity.system == player.system,
      physical.identity.visit == player.visit, physical.identity.entity != 0,
      selected.scriptNPC?.fit.definition.id == "outlook-marker",
      selected.scriptNPC?.fit.definition.speed == 0,
      selected.position.finite, selected.position.length > 0,
      selected.position.unit.dot(Vector3(0, 0, 1)) >= cos(2 * Double.pi / 180),
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 1500, radius: 0, includePlayer: false),
      contact.hit.target == .body(selected.id), contact.hit.distance >= 250,
      contact.hit.distance <= 1500
    else { return nil }
    return .init(
      mission: mission.id, boarding: boarding.operation, owner: owner,
      carrier: carrier, equipment: equipment.id, inventoryRevision: inventory.revision,
      ordinal: ordinal, marker: marker, actor: physical.identity, player: player,
      time: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
  }
  var orbitalOutlookScanStatus: String? {
    guard let source = commander.nativePeople?.outlookJourney, source.boarding != nil,
      source.terminalOperation == nil
    else { return nil }
    if source.readings.count == 3 { return "OUTLOOK 3/3 - return both people to Avenor care" }
    let elapsed = nativeOrbitalOutlookRuntime.observation?.seconds ?? 0
    return
      "OUTLOOK \(source.readings.count)/3: \(NativeOrbitalOutlookJourney.views[source.readings.count]) \(String(format: "%.1f", elapsed))/12s - \(nativeOrbitalOutlookRuntime.reason)"
  }
}

extension GameRuntime {
  /// Exactly one post-motion ingress. No renderer, query, Lua command or supplied elapsed-time API.
  func commitOrbitalOutlookScan(start: NativeOrbitalOutlookSample?) {
    if game.nativeOrbitalOutlookRuntime.pending != nil {
      publishPendingOrbitalOutlookReading()
      return
    }
    guard stageCompletedOrbitalOutlookScan(start: start) else { return }
    publishPendingOrbitalOutlookReading()
  }

  /// Full marker and authority values retire before native publication validates the candidate.
  @inline(never)
  private func stageCompletedOrbitalOutlookScan(start: NativeOrbitalOutlookSample?) -> Bool {
    if game.paused { return false }
    guard let start, let end = game.orbitalOutlookSample(), start.sameAuthority(as: end) else {
      game.nativeOrbitalOutlookRuntime.observation = nil
      game.nativeOrbitalOutlookRuntime.reason =
        "Use the next live marker, 250-1500 surface units, within 2 degrees and clear sight."
      return false
    }
    let interval = end.time - start.time
    guard interval > 0, interval <= 0.1 + 1e-9 else {
      game.nativeOrbitalOutlookRuntime.observation = nil
      game.nativeOrbitalOutlookRuntime.reason =
        "Unfinished view reset after a discontinuous native interval."
      return false
    }
    var observation: NativeOrbitalOutlookObservation
    if let previous = game.nativeOrbitalOutlookRuntime.observation,
      previous.last.sameAuthority(as: start), abs(previous.last.time - start.time) < 1e-9
    {
      observation = previous
      observation.last = end
      observation.seconds += interval
      observation.intervals += 1
    } else {
      observation = .init(first: start, last: end, seconds: interval, intervals: 1)
    }
    game.nativeOrbitalOutlookRuntime.observation = observation
    game.nativeOrbitalOutlookRuntime.reason =
      "Native observation in progress; interruption resets only this view."
    guard observation.seconds >= 12,
      let source = game.commander.nativePeople?.outlookJourney,
      let boarding = source.boarding
    else { return false }
    do {
      let purchase = try game.commander.purchaseSnapshot()
      guard let equipment = purchase.items.first(where: { $0.id == end.equipment }),
        purchase.owner == end.owner, purchase.activeHull == end.carrier,
        purchase.revision == end.inventoryRevision,
        let mission = game.commander.scriptState.instances[end.mission],
        let marker = mission.ownedEncounters[NativeOrbitalOutlookJourney.encounterID]?.actors[
          NativeOrbitalOutlookJourney.views[end.ordinal]],
        marker.identity == end.marker, marker.presence == .present,
        marker.body.physical?.identity == end.actor,
        game.bodies.contains(where: {
          $0.missionActorID == marker.identity && $0.physical?.identity == end.actor
            && $0.energy > 0
        })
      else { throw SaveError.invalidCommander }
      let operation = ScriptIdentity.uuid(
        "native-outlook-reading-v1:\(boarding.operation):\(end.ordinal)")
      let authorityID = NativeOrbitalOutlookJourney.authorityIdentity(
        operation: operation,
        equipment: end.equipment, inventoryRevision: end.inventoryRevision, epoch: end.epoch,
        actor: end.actor)
      let authority = NativeOrbitalOutlookAuthority(
        id: authorityID, operation: operation,
        boarding: boarding.operation, owner: end.owner, carrier: end.carrier,
        inventoryRevision: end.inventoryRevision, epoch: end.epoch, equipment: equipment,
        marker: marker, observedAt: end.time)
      let reading = NativeOrbitalOutlookReading(
        operation: operation, authority: authorityID,
        mission: end.mission, boarding: end.boarding, owner: end.owner, people: source.references,
        carrier: end.carrier, berths: boarding.berths, equipment: end.equipment,
        inventoryRevision: end.inventoryRevision, ordinal: end.ordinal, marker: end.marker,
        actor: end.actor, player: end.player, start: observation.first.time, end: end.time,
        qualifiedSeconds: observation.seconds, intervals: observation.intervals,
        epoch: end.epoch, revision: UInt64(end.ordinal + 1))
      game.nativeOrbitalOutlookRuntime.pending = .init(reading: reading, authority: authority)
    } catch {
      game.nativeOrbitalOutlookRuntime.observation = nil
      game.nativeOrbitalOutlookRuntime.reason =
        "Native marker or fitted authority changed before the reading sealed."
      return false
    }
    game.nativeOrbitalOutlookRuntime.observation = nil
    return true
  }
  @inline(never)
  private func publishPendingOrbitalOutlookReading() {
    guard let pending = game.nativeOrbitalOutlookRuntime.pending else { return }
    let reading = pending.reading
    guard let source = game.commander.nativePeople?.outlookJourney,
      source.terminalOperation == nil, source.readings.count == reading.ordinal,
      source.boarding?.operation == reading.boarding,
      game.nativeStationRuntimeEpoch == reading.epoch,
      game.commander.flightSimulation.player == reading.player,
      game.commander.hullInstanceID == reading.carrier,
      game.commander.nativePeople?.held.filter({ source.references.contains($0.person) }).count == 2
    else {
      game.nativeOrbitalOutlookRuntime = .init()
      return
    }
    guard let publish = scriptPublisher() else { return }
    var candidate = game
    do {
      try Self.stageOrbitalOutlookReading(&candidate, pending: pending)
      try publish(&candidate)
      game = candidate
    } catch {
      game.nativeOrbitalOutlookRuntime.reason =
        "Reading not saved; retry only this measured reading."
      game.notify("OUTLOOK READING NOT SAVED - RETRY SAVE")
    }
  }

  @inline(never)
  private static func stageOrbitalOutlookReading(
    _ candidate: inout Game, pending: NativeOrbitalOutlookPending
  ) throws {
    let reading = pending.reading
    guard var custody = candidate.commander.nativePeople, var next = custody.outlookJourney,
      var mission = candidate.commander.scriptState.instances[reading.mission],
      mission.outcome == .active
    else { throw SaveError.invalidCommander }
    next.readings.append(reading)
    next.authorities.append(pending.authority)
    custody.outlookJourney = next
    candidate.commander.savedNativePeopleCustody = custody
    mission.milestones.insert(reading.ordinal + 1)
    candidate.commander.scriptState.instances[reading.mission] = mission
    candidate.nativeOrbitalOutlookRuntime = .init()
  }
}

extension NativeOrbitalOutlookJourney {
  static func authorityIdentity(
    operation: UUID, equipment: UUID, inventoryRevision: UInt64,
    epoch: UUID, actor: ActorIdentity
  ) -> UUID {
    ScriptIdentity.uuid(
      "native-outlook-authority-v1:\(operation):\(equipment):\(inventoryRevision):\(epoch):\(actor.system.galaxy):\(actor.system.system):\(actor.visit):\(actor.entity)"
    )
  }
  @inline(never)
  static func authorityValid(
    _ authority: borrowing NativeOrbitalOutlookAuthority,
    reading: borrowing NativeOrbitalOutlookReading,
    source: borrowing NativeOrbitalOutlookJourneyState, commander: borrowing Commander
  ) -> Bool {
    guard views.indices.contains(reading.ordinal), let boarding = source.boarding else {
      return false
    }
    guard
      authorityBindingValid(authority, reading: reading, boarding: boarding, owner: source.owner)
    else { return false }
    guard authorityMarkerValid(authority.marker, reading: reading, mission: boarding.mission) else {
      return false
    }
    guard authorityPhysicalValid(authority.marker.body, reading: reading, commander: commander)
    else { return false }
    guard authorityFitValid(authority.marker.body) else { return false }
    guard
      authorityRetainedMarkerValid(
        authority.marker, mission: boarding.mission,
        ordinal: reading.ordinal, commander: commander)
    else { return false }
    return authorityAcquisitionValid(authority.equipment, owner: source.owner, commander: commander)
  }

  @inline(never)
  private static func authorityBindingValid(
    _ authority: borrowing NativeOrbitalOutlookAuthority,
    reading: borrowing NativeOrbitalOutlookReading,
    boarding: borrowing NativeOrbitalOutlookBoarding, owner: UUID
  ) -> Bool {
    guard authority.id == reading.authority,
      authority.id
        == authorityIdentity(
          operation: reading.operation, equipment: reading.equipment,
          inventoryRevision: reading.inventoryRevision, epoch: reading.epoch, actor: reading.actor),
      authority.operation == reading.operation, authority.boarding == boarding.operation,
      authority.owner == owner, authority.carrier == boarding.carrier,
      authority.inventoryRevision == reading.inventoryRevision,
      authority.inventoryRevision >= boarding.inventoryRevision,
      authority.epoch == reading.epoch, authority.observedAt == reading.end,
      authority.equipment.id == reading.equipment,
      TargetingTier.from(authority.equipment.node.key) != nil,
      authority.equipment.location?.hull == boarding.carrier,
      authority.equipment.location
        == EquipmentRuntimeCatalog.purchaseLocation(
          .init(hullInstanceID: boarding.carrier, slot: .targetingCore)),
      authority.equipment.node.family == EquipmentPurchaseCatalog.targeting
    else { return false }
    return true
  }

  @inline(never)
  private static func authorityMarkerValid(
    _ marker: borrowing ScriptOwnedActor, reading: borrowing NativeOrbitalOutlookReading,
    mission: UUID
  ) -> Bool {
    guard marker.valid, marker.presence == .present,
      marker.alias == views[reading.ordinal], marker.identity == reading.marker,
      marker.body.id >= 0, marker.body.missionInstanceID == mission,
      marker.body.missionActorID == reading.marker, marker.body.energy > 0, !marker.body.hostile
    else { return false }
    return true
  }

  @inline(never)
  private static func authorityPhysicalValid(
    _ body: borrowing SpaceBody, reading: borrowing NativeOrbitalOutlookReading,
    commander: borrowing Commander
  ) -> Bool {
    // Optional primitive reads preserve the original presence/identity/producer order without
    // holding another full PhysicalActorState (including its optional ordnance archive).
    guard body.physical?.identity == reading.actor, body.physical?.population == .mission,
      body.physical?.spawnIdentity?.producer == .mission,
      body.physical?.spawnIdentity?.system == reading.actor.system,
      body.physical?.spawnIdentity?.visit == reading.actor.visit,
      let sequence = body.physical?.spawnIdentity?.sequence,
      sequence > 0, sequence < commander.flightSimulation.nextSpawn
    else { return false }
    return true
  }

  @inline(never)
  private static func authorityFitValid(_ body: borrowing SpaceBody) -> Bool {
    guard body.scriptNPC?.fit.definition.id == "outlook-marker",
      body.scriptNPC?.fit.definition.model == "catalogue:SH040",
      body.scriptNPC?.fit.definition.speed == 0,
      body.scriptNPC?.fit.definition.missiles == 0,
      (body.scriptNPC?.fit.definition.lasers ?? []).isEmpty
    else { return false }
    return true
  }

  @inline(never)
  private static func authorityRetainedMarkerValid(
    _ marker: borrowing ScriptOwnedActor, mission: UUID, ordinal: Int,
    commander: borrowing Commander
  ) -> Bool {
    for index in commander.scriptState.instances.indices {
      if commander.scriptState.instances.keys[index] == mission {
        return authorityRetainedInstanceFits(
          commander.scriptState.instances.values[index],
          marker: marker, ordinal: ordinal)
      }
    }
    return false
  }

  @inline(never)
  private static func authorityRetainedInstanceFits(
    _ instance: borrowing ScriptInstance, marker: borrowing ScriptOwnedActor, ordinal: Int
  ) -> Bool {
    for index in instance.ownedEncounters.indices {
      if instance.ownedEncounters.keys[index] == encounterID {
        return authorityRetainedEncounterFits(
          instance.ownedEncounters.values[index],
          marker: marker, ordinal: ordinal)
      }
    }
    return false
  }

  @inline(never)
  private static func authorityRetainedEncounterFits(
    _ encounter: borrowing ScriptOwnedEncounter, marker: borrowing ScriptOwnedActor, ordinal: Int
  ) -> Bool {
    for index in encounter.actors.indices {
      if encounter.actors.keys[index] == views[ordinal] {
        return authorityRetainedActorFits(encounter.actors.values[index], marker: marker)
      }
    }
    return false
  }

  @inline(never)
  private static func authorityRetainedActorFits(
    _ retained: borrowing ScriptOwnedActor, marker: borrowing ScriptOwnedActor
  ) -> Bool {
    // The earlier fit phase proved marker.scriptNPC is present. This is the same definition
    // equality as the former guard, after the same mission/encounter/alias key lookups.
    guard retained.identity == marker.identity else { return false }
    return retained.body.scriptNPC?.fit.definition == marker.body.scriptNPC?.fit.definition
  }

  @inline(never)
  private static func authorityAcquisitionValid(
    _ equipment: borrowing EquipmentPurchaseItem, owner expectedOwner: UUID,
    commander: borrowing Commander
  ) -> Bool {
    let item = equipment.id
    let node = equipment.node
    switch equipment.provenance {
    case .paid(let owner, let transaction):
      guard owner == expectedOwner, let history = commander.savedEquipmentPurchaseHistory,
        history.owner == owner,
        history.paid.contains(where: { receipt in
          receipt.owner == owner && receipt.transaction == transaction
            && receipt.binding.request.newItem == item && receipt.node == node
        })
      else { return false }
    case .legacyUnknown:
      guard
        commander.savedEquipmentPurchaseHistory?.legacy.contains(where: {
          $0.owner == expectedOwner && $0.source.id == item && $0.source.node == node
        }) == true
      else { return false }
    default: break
    }
    return true
  }
}
