import Foundation

enum NativeInductionArkSave {
  static let version = 81
  static let alienVersion = 82
  static func supportsReserve(_ schema: Int?) -> Bool {
    schema == version || schema == alienVersion || NativeInductionCrewLogSave.contains(schema)
  }
  static func supportsReceiving(_ schema: Int?) -> Bool {
    supportsReserve(schema) || schema == 79 || schema == 80
  }
  static func supportsService(_ schema: Int?) -> Bool {
    supportsReceiving(schema) || schema == 77 || schema == 78
  }
  static func contains(_ schema: Int?) -> Bool {
    supportsService(schema) || schema == 75 || schema == 76
  }
  static func isAlien(_ schema: Int?) -> Bool {
    schema == NativeInductionCrewLogSave.alienVersion || schema == 128 || schema == 124
      || schema == 120 || schema == 122
      || schema == 118
      || schema == 116 || schema == 114
      || schema == 112
      || schema == 110
      || schema == 108
      || schema == 106
      || schema == 104
      || schema == 102
      || schema == 100 || schema == 98 || schema == 96
      || schema == 94
      || schema == 92
      || schema == 90
      || schema == 88
      || schema == 86
      || schema == 84
      || schema == alienVersion
      || schema == 80
      || schema == 78 || schema == 76
  }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return isAlien(schema)
      ? NativeWayfarerInductionSave.alienVersion : NativeWayfarerInductionSave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if commander.scriptState.instances.values.contains(where: NativeInductionArkPack.marked) {
      return true
    }
    return commander.scriptState.instances.values.contains {
      $0.savedWayfarerInduction?.ark != nil || $0.savedArkReserve != nil
        || $0.savedArkRecovery != nil
    }
  }

  @inline(never)
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    let jobs = engine.instances.values.filter { NativeInductionArkPack.marked($0) }
    let parents = engine.instances.values.filter {
      $0.savedWayfarerInduction != nil || $0.savedArkReserve != nil || $0.savedArkRecovery != nil
    }
    guard parents.count <= 1, jobs.count <= 2 else { return false }
    var expectedJobs: Set<UUID> = []
    for parent in parents {
      guard recoveryParentValid(parent, commander: commander) else { return false }
      if let current = parent.savedWayfarerInduction?.ark { expectedJobs.insert(current.job) }
      if let retired = parent.savedArkRecovery?.retired { expectedJobs.insert(retired.job) }
    }
    guard Set(jobs.map(\.id)) == expectedJobs else { return false }
    for child in jobs {
      guard let state = child.savedNativeArk,
        let parent = engine.instances[state.authorization.parent],
        let leaf = parent.savedWayfarerInduction, let key = leaf.seedKey,
        let service = leaf.cassetteService,
        let link = leaf.ark?.job == child.id ? leaf.ark : parent.savedArkRecovery?.retired,
        let source = try? NativeInductionArkSource(
          loan: key, permission: leaf.permission, service: service,
          reserve: state.authorization.reserve),
        parent.definition == NativeWayfarerInduction.stateID,
        parent.digest == NativeWayfarerInduction.digest,
        child.definition == NativeInductionArkPack.stateID,
        child.version == NativeInductionArkPack.version,
        child.digest == NativeInductionArkPack.digest,
        child.id == state.authorization.job, child.outcome == .active,
        child.contract == nil, child.completionReceipt == nil, child.dialogue == nil,
        child.payloads.isEmpty, child.gearIssues.isEmpty,
        child.milestones == (state.reception == nil ? [] : [0]),
        child.data == .object([:]), child.campaignParent == nil, child.campaignChildren.isEmpty,
        child.timers.keys.allSatisfy({ $0 == NativeInductionArkPack.launchTimer }),
        link.job == child.id, link.registeredArk == source.actor,
        link.operation == state.authorization.operation, link.loanOperation == key.operation,
        state.shapeValid(source: source, key: key),
        child.id == leaf.ark?.job
          ? (state.reception == leaf.seedReception && state.fuel.closure?.recoveryOperation == nil)
          : (state.reception == nil && state.loss == parent.savedArkRecovery?.priorLoss),
        child.id != leaf.ark?.job
          || state.authorization.reserve
            == (parent.savedArkRecovery == nil ? nil : parent.savedArkReserve),
        receivingClaimsValid(state, parent: parent, child: child, engine: engine),
        state.authorization.sequence <= engine.nextEvent,
        parent.hasAcknowledged(state.authorization.sequence),
        child.hasAcknowledged(state.authorization.sequence),
        commander.equipmentOwnerID == source.owner,
        currentBoundsValid(state, commander: commander),
        actorValid(child, state: state, source: source),
        legsValid(state, source: source, engine: engine),
        fuelHistoryValid(state, child: child, engine: engine)
      else { return false }
    }
    return supplierClaimsValid(commander)
  }

  private static func currentBoundsValid(
    _ state: NativeInductionArkState, commander: borrowing Commander
  ) -> Bool {
    let a = state.authorization
    guard let world = commander.nativeStations,
      world.mainStations.contains(a.dock.station), a.dock.sequence < world.nextMainDockSequence,
      a.dock.actor.visit <= commander.flightSimulation.visit,
      a.physicalTime <= commander.flightSimulation.physicalTime,
      a.flightSeconds <= commander.scriptState.flightSeconds
    else { return false }
    if let admission = state.admission {
      guard admission.actor.visit <= commander.flightSimulation.visit,
        admission.physicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    if let loss = state.loss {
      guard loss.actor.visit <= commander.flightSimulation.visit,
        loss.observedPhysicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    for contact in state.fuelContacts {
      guard world.mainStations.contains(contact.station),
        contact.arkActor.visit <= commander.flightSimulation.visit,
        contact.physicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    if let reception = state.reception {
      guard reception.playerDock.sequence < world.nextMainDockSequence,
        reception.playerDock.actor.visit <= commander.flightSimulation.visit,
        reception.physicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    for exit in state.exits {
      guard exit.actor.visit <= commander.flightSimulation.visit,
        exit.physicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    for purchase in state.fuel.purchases {
      guard purchase.request.offer.supplierActor.visit <= commander.flightSimulation.visit,
        purchase.request.offer.quotedAtPhysicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    return true
  }

  private static func actorValid(
    _ child: ScriptInstance, state: NativeInductionArkState, source: NativeInductionArkSource
  ) -> Bool {
    if child.ownedEncounters.isEmpty {
      return state.admission == nil && state.legs.isEmpty && state.loss == nil
    }
    guard child.ownedEncounters.count == 1,
      let group = child.ownedEncounters[NativeInductionArkPack.encounter],
      group.id == NativeInductionArkPack.encounter, group.galaxy == 0, group.system == 162,
      group.actors.count == 1, let actor = group.actors[NativeInductionArkPack.alias],
      actor.identity == state.authorization.actor,
      actor.body.missionInstanceID == child.id, actor.body.missionActorID == actor.identity,
      let npc = actor.body.scriptNPC, source.matchesFit(npc.fit)
    else { return false }
    if let contact = state.dockedContact {
      guard actor.presence == .unloaded, actor.body.energy > 0,
        actor.body.physical?.identity == contact.arkActor,
        actor.location(in: group) == contact.station.system
      else { return false }
    }
    if let loss = state.loss {
      guard actor.presence == .destroyed && actor.body.energy == 0,
        actor.body.physical?.identity == loss.actor
      else { return false }
    }
    if !group.admitted { return state.admission == nil && state.legs.isEmpty }
    return true  // Native admission may be durable before its owning observation is recorded.
  }

  private static func legsValid(
    _ state: NativeInductionArkState, source: NativeInductionArkSource, engine: ScriptEngineState
  ) -> Bool {
    let a = state.authorization
    var previous: NativeArkHopReference?
    var previousLeg: NativeWormholeLeg?
    for reference in state.legs {
      guard let leg = engine.wormholeTransit?.legs[reference.leg], leg.valid,
        leg.instance == a.job, leg.actor == a.actor,
        leg.encounter == NativeInductionArkPack.encounter,
        leg.alias == NativeInductionArkPack.alias, leg.request == reference.request,
        leg.destinationWorld == a.route.worldKeys[reference.hop + 1]
      else { return false }
      if let previous, let previousLeg {
        if reference.hop == previous.hop {
          guard previousLeg.phase == .cancelled, reference.attempt == previous.attempt + 1 else {
            return false
          }
        } else {
          guard reference.hop == previous.hop + 1, reference.attempt == 0,
            previousLeg.phase == .arrived
          else { return false }
        }
      } else if reference.hop != 0 || reference.attempt != 0 {
        return false
      }
      if let route = leg.route {
        guard route.origin.worldID == a.route.worldKeys[reference.hop],
          route.destination.worldID == a.route.worldKeys[reference.hop + 1],
          route.distanceLightYears == a.route.legDistancesLY[reference.hop]
        else { return false }
      }
      if let departure = leg.departure {
        guard let fit = departure.body.scriptNPC?.fit, source.matchesFit(fit),
          leg.driveTerms == source.definition.drive
        else { return false }
      }
      previous = reference
      previousLeg = leg
    }
    let all = engine.wormholeTransit?.legs.values.filter { $0.instance == a.job } ?? []
    return all.count == state.legs.count
  }
}
