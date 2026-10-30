import Foundation

/// Only completed native observations persist. Unfinished dwell and refusal retries stay runtime-local.
struct NativeOriginalSurveyReading: Codable, Sendable, Equatable {
  let operation: UUID
  let authority: UUID
  let mission: UUID
  let permission: UUID
  let owner: UUID
  let carrier: UUID
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
struct NativeOriginalSurveyAuthority: Codable, Sendable, Equatable {
  let id: UUID
  let operation: UUID
  let permission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
  let equipment: EquipmentPurchaseItem
  let marker: ScriptOwnedActor
  let observedAt: Double
}
/// Immutable attempt-local pending value; copying Game never copies another inline actor snapshot.
final class NativeOriginalSurveyPending: Sendable, Equatable {
  let reading: NativeOriginalSurveyReading
  let authority: NativeOriginalSurveyAuthority
  init(reading: NativeOriginalSurveyReading, authority: NativeOriginalSurveyAuthority) {
    self.reading = reading
    self.authority = authority
  }
  static func == (lhs: NativeOriginalSurveyPending, rhs: NativeOriginalSurveyPending) -> Bool {
    lhs.reading == rhs.reading && lhs.authority == rhs.authority
  }
}

struct NativeOriginalSurveySample: Sendable, Equatable {
  let mission: UUID
  let permission: UUID
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
    mission == other.mission && permission == other.permission && owner == other.owner
      && carrier == other.carrier && equipment == other.equipment
      && inventoryRevision == other.inventoryRevision && ordinal == other.ordinal
      && marker == other.marker && actor == other.actor && player == other.player
      && epoch == other.epoch
  }
}
struct NativeOriginalSurveyObservation: Sendable, Equatable {
  let first: NativeOriginalSurveySample
  var last: NativeOriginalSurveySample
  var seconds: Double
  var intervals: Int
}
struct NativeOriginalSurveyRuntime: Sendable, Equatable {
  var observation: NativeOriginalSurveyObservation?
  var pending: NativeOriginalSurveyPending?
  var reason = "Lock the next marker in the front reading."
}

extension NativeOriginalSurvey {
  static func markerIdentity(mission: UUID, digest: String, ordinal: Int) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(mission):\(digest):\(encounterID):\(targets[ordinal])")
  }
  static func returnReady(
    _ source: borrowing NativeOriginalSurveyState, dock: NativeMainStationDockReceipt
  ) -> Bool {
    guard source.readings.count == 3, let permission = source.permission,
      let last = source.readings.last, sourceMatches(dock),
      dock.sequence > permission.dock.sequence, dock.actor.visit > last.actor.visit
    else { return false }
    return true
  }
  @inline(never)
  static func readingsValid(
    _ source: borrowing NativeOriginalSurveyState, commander: borrowing Commander
  ) -> Bool {
    guard source.readings.count <= 3, source.authorities.count == source.readings.count else {
      return false
    }
    guard let permission = source.permission else {
      guard source.readings.isEmpty else { return false }
      return source.authorities.isEmpty
    }
    var lastEnd = permission.physicalTime
    var operations: Set<UUID> = []
    for (ordinal, reading) in source.readings.enumerated() {
      guard reading.ordinal == ordinal,
        authorityValid(
          source.authorities[ordinal], reading: reading, source: source, commander: commander),
        reading.revision == UInt64(ordinal + 1),
        operations.insert(reading.operation).inserted,
        reading.operation
          == ScriptIdentity.uuid("native-survey-reading-v1:\(permission.operation):\(ordinal)"),
        reading.mission == permission.mission, reading.permission == permission.operation,
        reading.owner == source.owner,
        reading.carrier == permission.carrier,
        reading.marker
          == markerIdentity(mission: permission.mission, digest: source.digest, ordinal: ordinal),
        reading.actor.system == SystemIdentity(galaxy: 0, system: 185),
        reading.player.system == reading.actor.system, reading.player.visit == reading.actor.visit,
        reading.player.entity == 0, reading.actor.entity > 1,
        reading.actor.entity < commander.flightSimulation.nextActor,
        reading.actor.visit > permission.dock.actor.visit,
        reading.actor.visit <= commander.flightSimulation.visit,
        reading.start.isFinite, reading.end.isFinite, reading.qualifiedSeconds.isFinite,
        reading.start >= lastEnd, reading.end <= commander.flightSimulation.physicalTime,
        reading.end > reading.start, reading.qualifiedSeconds >= 12,
        reading.qualifiedSeconds <= 12.1 + 1e-8,
        abs(reading.end - reading.start - reading.qualifiedSeconds) < 1e-6,
        reading.intervals >= 120, reading.intervals <= 1_000_000,
        reading.qualifiedSeconds <= Double(reading.intervals) * 0.1 + 1e-6,
        retainedReadingMarkerValid(
          mission: permission.mission, ordinal: ordinal,
          marker: reading.marker, commander: commander)
      else { return false }
      lastEnd = reading.end
    }
    return true
  }
}

extension NativeOriginalSurvey {
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
      if encounter.actors.keys[index] == targets[ordinal] {
        return encounter.actors.values[index].identity == marker
      }
    }
    return false
  }
}

extension Game {
  /// Read-only start/end qualification. Selection and telemetry alone never advance a reading.
  func originalSurveySample() -> NativeOriginalSurveySample? {
    guard !paused, !docked, !playerEMPDisabled, screen == .front, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil,
      commander.system == 185, commander.galaxy == 0,
      let source = originalSurveyState, source.terminalOperation == nil,
      let permission = source.permission, source.readings.count < 3,
      let mission = commander.scriptState.instances[permission.mission], mission.outcome == .active,
      let equipment = commander.fittedEquipment(at: .targetingCore), commander.targetingTier != nil,
      let inventory = commander.equipmentInventory,
      let player = commander.flightSimulation.player, player.entity == 0,
      player.system == SystemIdentity(galaxy: 0, system: 185),
      let owner = commander.equipmentOwnerID, owner == source.owner,
      let carrier = commander.hullInstanceID, carrier == permission.carrier,
      equipment.location?.hullInstanceID == carrier,
      let selected = informationTargetBody, let physical = selected.physical,
      selected.energy > 0, !selected.hostile,
      let encounter = mission.ownedEncounters[NativeOriginalSurvey.encounterID],
      encounter.admitted,
      encounter.galaxy == 0, encounter.system == 185
    else { return nil }
    let ordinal = source.readings.count
    let alias = NativeOriginalSurvey.targets[ordinal]
    let marker = NativeOriginalSurvey.markerIdentity(
      mission: mission.id, digest: source.digest, ordinal: ordinal)
    guard let actor = encounter.actors[alias], actor.identity == marker, actor.presence == .present,
      selected.missionActorID == marker, selected.missionInstanceID == mission.id,
      actor.body.id == selected.id, physical.identity.system == player.system,
      physical.identity.visit == player.visit, physical.identity.entity != 0,
      selected.scriptNPC?.fit.definition.id == NativeOriginalSurvey.markerID,
      selected.scriptNPC?.fit.definition.speed == 0,
      selected.position.finite, selected.position.length > 0,
      selected.position.unit.dot(Vector3(0, 0, 1)) >= cos(2 * Double.pi / 180),
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: NativeOriginalSurvey.maximumRange, radius: 0, includePlayer: false),
      contact.hit.target == .body(selected.id),
      contact.hit.distance >= NativeOriginalSurvey.minimumRange,
      contact.hit.distance <= NativeOriginalSurvey.maximumRange
    else { return nil }
    return .init(
      mission: mission.id, permission: permission.operation, owner: owner,
      carrier: carrier, equipment: equipment.id, inventoryRevision: inventory.revision,
      ordinal: ordinal, marker: marker, actor: physical.identity, player: player,
      time: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
  }
  var originalSurveyScanStatus: String? {
    guard let source = originalSurveyState, source.permission != nil,
      source.terminalOperation == nil
    else { return nil }
    if source.readings.count == 3 { return "SURVEY 3/3 - return measurements to Avenor" }
    let elapsed = nativeOriginalSurveyRuntime?.observation?.seconds ?? 0
    return
      "SURVEY \(source.readings.count)/3: \(NativeOriginalSurvey.targets[source.readings.count]) \(String(format: "%.1f", elapsed))/12s - \(nativeOriginalSurveyRuntime?.reason ?? "Lock the next marker.")"
  }
}

extension GameRuntime {
  /// Exactly one post-motion ingress. No renderer, query, Lua command or supplied elapsed-time API.
  func commitOriginalSurveyScan(start: NativeOriginalSurveySample?) {
    guard game.originalSurveyState != nil else { return }
    if game.nativeOriginalSurveyRuntime == nil { game.nativeOriginalSurveyRuntime = .init() }
    if game.nativeOriginalSurveyRuntime?.pending != nil {
      publishPendingOriginalSurveyReading()
      return
    }
    guard stageCompletedOriginalSurveyScan(start: start) else { return }
    publishPendingOriginalSurveyReading()
  }

  /// Full marker and authority values retire before native publication validates the candidate.
  @inline(never)
  private func stageCompletedOriginalSurveyScan(start: NativeOriginalSurveySample?) -> Bool {
    if game.paused { return false }
    guard let start, let end = game.originalSurveySample(), start.sameAuthority(as: end) else {
      game.nativeOriginalSurveyRuntime?.observation = nil
      game.nativeOriginalSurveyRuntime?.reason =
        "Use the next live marker, 250-1500 surface units, within 2 degrees and clear sight."
      return false
    }
    let interval = end.time - start.time
    guard interval > 0, interval <= NativeOriginalSurvey.maximumInterval + 1e-9 else {
      game.nativeOriginalSurveyRuntime?.observation = nil
      game.nativeOriginalSurveyRuntime?.reason =
        "Unfinished reading reset after a discontinuous native interval."
      return false
    }
    var observation: NativeOriginalSurveyObservation
    if let previous = game.nativeOriginalSurveyRuntime?.observation,
      previous.last.sameAuthority(as: start), abs(previous.last.time - start.time) < 1e-9
    {
      observation = previous
      observation.last = end
      observation.seconds += interval
      observation.intervals += 1
    } else {
      observation = .init(first: start, last: end, seconds: interval, intervals: 1)
    }
    game.nativeOriginalSurveyRuntime?.observation = observation
    game.nativeOriginalSurveyRuntime?.reason =
      "Native observation in progress; interruption resets only this reading."
    guard observation.seconds >= NativeOriginalSurvey.requiredSeconds,
      let source = game.originalSurveyState,
      let permission = source.permission
    else { return false }
    do {
      let purchase = try game.commander.purchaseSnapshot()
      guard let equipment = purchase.items.first(where: { $0.id == end.equipment }),
        purchase.owner == end.owner, purchase.activeHull == end.carrier,
        purchase.revision == end.inventoryRevision,
        let mission = game.commander.scriptState.instances[end.mission],
        let marker = mission.ownedEncounters[NativeOriginalSurvey.encounterID]?.actors[
          NativeOriginalSurvey.targets[end.ordinal]],
        marker.identity == end.marker, marker.presence == .present,
        marker.body.physical?.identity == end.actor,
        game.bodies.contains(where: {
          $0.missionActorID == marker.identity && $0.physical?.identity == end.actor
            && $0.energy > 0
        })
      else { throw SaveError.invalidCommander }
      let operation = ScriptIdentity.uuid(
        "native-survey-reading-v1:\(permission.operation):\(end.ordinal)")
      let authorityID = try NativeOriginalSurvey.authorityIdentity(
        operation: operation,
        equipment: equipment, inventoryRevision: end.inventoryRevision, epoch: end.epoch,
        actor: end.actor)
      let authority = NativeOriginalSurveyAuthority(
        id: authorityID, operation: operation,
        permission: permission.operation, owner: end.owner, carrier: end.carrier,
        inventoryRevision: end.inventoryRevision, epoch: end.epoch, equipment: equipment,
        marker: marker, observedAt: end.time)
      let reading = NativeOriginalSurveyReading(
        operation: operation, authority: authorityID,
        mission: end.mission, permission: end.permission, owner: end.owner,
        carrier: end.carrier, equipment: end.equipment,
        inventoryRevision: end.inventoryRevision, ordinal: end.ordinal, marker: end.marker,
        actor: end.actor, player: end.player, start: observation.first.time, end: end.time,
        qualifiedSeconds: observation.seconds, intervals: observation.intervals,
        epoch: end.epoch, revision: UInt64(end.ordinal + 1))
      game.nativeOriginalSurveyRuntime?.pending = .init(reading: reading, authority: authority)
    } catch {
      game.nativeOriginalSurveyRuntime?.observation = nil
      game.nativeOriginalSurveyRuntime?.reason =
        "Native marker or fitted authority changed before the reading sealed."
      return false
    }
    game.nativeOriginalSurveyRuntime?.observation = nil
    return true
  }
  @inline(never)
  private func publishPendingOriginalSurveyReading() {
    guard let pending = game.nativeOriginalSurveyRuntime?.pending else { return }
    let reading = pending.reading
    guard let source = game.originalSurveyState,
      source.terminalOperation == nil, source.readings.count == reading.ordinal,
      source.permission?.operation == reading.permission,
      game.nativeStationRuntimeEpoch == reading.epoch,
      game.commander.flightSimulation.player == reading.player,
      game.commander.hullInstanceID == reading.carrier
    else {
      game.nativeOriginalSurveyRuntime = .init()
      return
    }
    guard let publish = scriptPublisher() else { return }
    var candidate = game
    do {
      try Self.stageOriginalSurveyReading(&candidate, pending: pending)
      try publish(&candidate)
      game = candidate
    } catch {
      game.nativeOriginalSurveyRuntime?.reason =
        "Reading not saved; retry only this measured reading."
      game.notify("SURVEY READING NOT SAVED - RETRY SAVE")
    }
  }

  @inline(never)
  private static func stageOriginalSurveyReading(
    _ candidate: inout Game, pending: NativeOriginalSurveyPending
  ) throws {
    let reading = pending.reading
    guard var mission = candidate.commander.scriptState.instances[reading.mission],
      var next = mission.savedOriginalSurvey, mission.outcome == .active
    else { throw SaveError.invalidCommander }
    next.readings.append(reading)
    next.authorities.append(pending.authority)
    mission.savedOriginalSurvey = next
    mission.milestones.insert(reading.ordinal + 1)
    candidate.commander.scriptState.instances[reading.mission] = mission
    candidate.nativeOriginalSurveyRuntime = .init()
  }
}

extension NativeOriginalSurvey {
  static func authorityIdentity(
    operation: UUID, equipment: borrowing EquipmentPurchaseItem, inventoryRevision: UInt64,
    epoch: UUID, actor: ActorIdentity
  ) throws -> UUID {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let seal = ScriptPackLibrary.hash(try encoder.encode(copy equipment))
    return ScriptIdentity.uuid(
      "native-survey-authority-v1:\(operation):\(seal):\(inventoryRevision):\(epoch):\(actor.system.galaxy):\(actor.system.system):\(actor.visit):\(actor.entity)"
    )
  }
  @inline(never)
  static func authorityValid(
    _ authority: borrowing NativeOriginalSurveyAuthority,
    reading: borrowing NativeOriginalSurveyReading,
    source: borrowing NativeOriginalSurveyState, commander: borrowing Commander
  ) -> Bool {
    guard targets.indices.contains(reading.ordinal), let permission = source.permission else {
      return false
    }
    guard
      authorityBindingValid(
        authority, reading: reading, permission: permission, owner: source.owner)
    else { return false }
    guard authorityMarkerValid(authority.marker, reading: reading, mission: permission.mission)
    else {
      return false
    }
    guard authorityPhysicalValid(authority.marker.body, reading: reading, commander: commander)
    else { return false }
    guard authorityFitValid(authority.marker.body) else { return false }
    guard
      authorityRetainedMarkerValid(
        authority.marker, mission: permission.mission,
        ordinal: reading.ordinal, commander: commander)
    else { return false }
    return authorityAcquisitionValid(authority.equipment, owner: source.owner, commander: commander)
  }

  @inline(never)
  private static func authorityBindingValid(
    _ authority: borrowing NativeOriginalSurveyAuthority,
    reading: borrowing NativeOriginalSurveyReading,
    permission: borrowing NativeOriginalSurveyPermission, owner: UUID
  ) -> Bool {
    guard authority.id == reading.authority,
      authority.id
        == (try? authorityIdentity(
          operation: reading.operation, equipment: authority.equipment,
          inventoryRevision: reading.inventoryRevision, epoch: reading.epoch, actor: reading.actor)),
      authority.operation == reading.operation, authority.permission == permission.operation,
      authority.owner == owner, authority.carrier == permission.carrier,
      authority.inventoryRevision == reading.inventoryRevision,
      authority.inventoryRevision >= permission.inventoryRevision,
      authority.epoch == reading.epoch, authority.observedAt == reading.end,
      authority.equipment.id == reading.equipment,
      TargetingTier.from(authority.equipment.node.key) != nil,
      authority.equipment.location?.hull == permission.carrier,
      authority.equipment.location
        == EquipmentRuntimeCatalog.purchaseLocation(
          .init(hullInstanceID: permission.carrier, slot: .targetingCore)),
      authority.equipment.node.family == EquipmentPurchaseCatalog.targeting
    else { return false }
    return true
  }

  @inline(never)
  private static func authorityMarkerValid(
    _ marker: borrowing ScriptOwnedActor, reading: borrowing NativeOriginalSurveyReading,
    mission: UUID
  ) -> Bool {
    guard marker.valid, marker.presence == .present,
      marker.alias == targets[reading.ordinal], marker.identity == reading.marker,
      marker.body.id >= 0, marker.body.missionInstanceID == mission,
      marker.body.missionActorID == reading.marker, marker.body.energy > 0, !marker.body.hostile
    else { return false }
    return true
  }

  @inline(never)
  private static func authorityPhysicalValid(
    _ body: borrowing SpaceBody, reading: borrowing NativeOriginalSurveyReading,
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
    guard body.scriptNPC?.fit.definition.id == NativeOriginalSurvey.markerID,
      body.scriptNPC?.fit.definition.model == "catalogue:SH040",
      body.scriptNPC?.fit.definition.scale == 1,
      body.scriptNPC?.fit.definition.energy == 100,
      body.scriptNPC?.fit.definition.recharge == 0,
      body.scriptNPC?.fit.definition.speed == 0,
      body.scriptNPC?.fit.definition.acceleration == 0,
      body.scriptNPC?.fit.definition.pitch == 0,
      body.scriptNPC?.fit.definition.yaw == 0,
      body.scriptNPC?.fit.definition.roll == 0,
      body.scriptNPC?.fit.definition.fuel == 0,
      body.scriptNPC?.fit.definition.missiles == 0,
      body.scriptNPC?.fit.definition.ecm == false,
      body.scriptNPC?.fit.definition.bounty == 0,
      body.scriptNPC?.fit.definition.drive == nil,
      (body.scriptNPC?.fit.definition.lasers ?? []).isEmpty,
      (body.scriptNPC?.fit.definition.components ?? []).isEmpty
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
      if encounter.actors.keys[index] == targets[ordinal] {
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
    // Retained acquisition facts take precedence over the claimed provenance. A paid item
    // cannot become a grant merely by changing the historical witness and rehashing its chunk.
    if let history = commander.savedEquipmentPurchaseHistory {
      for receipt in history.paid where receipt.binding.request.newItem == item {
        guard history.owner == expectedOwner, receipt.owner == expectedOwner,
          receipt.node == node
        else { return false }
        return equipment.provenance == .paid(owner: expectedOwner, transaction: receipt.transaction)
      }
      for entitlement in history.legacy where entitlement.source.id == item {
        guard history.owner == expectedOwner, entitlement.owner == expectedOwner,
          entitlement.source.node == node
        else { return false }
        return equipment.provenance == .legacyUnknown
      }
    }
    switch equipment.provenance {
    case .paid, .legacyUnknown:
      return false
    case .standard, .grant, .recovered, .reward, .earned, .xyzzy, .missionIssue:
      // The native producer sealed the complete fitted item, including provenance, into the
      // retained reading's authority identity. Later fitting, storage or removal does not
      // replace that historical acquisition witness with the current fitted item.
      return true
    }
  }
}
