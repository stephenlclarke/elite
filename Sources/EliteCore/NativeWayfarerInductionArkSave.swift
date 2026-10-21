import Foundation

enum NativeInductionArkSave {
  static let version = 75
  static let alienVersion = 76
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeWayfarerInductionSave.alienVersion : NativeWayfarerInductionSave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if commander.scriptState.instances.values.contains(where: NativeInductionArkPack.marked) {
      return true
    }
    return commander.scriptState.instances.values.contains { $0.savedWayfarerInduction?.ark != nil }
  }

  @inline(never)
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    let jobs = engine.instances.values.filter { NativeInductionArkPack.marked($0) }
    let parents = engine.instances.values.filter { $0.savedWayfarerInduction?.ark != nil }
    guard jobs.count == parents.count, jobs.count <= 1 else { return false }
    for child in jobs {
      guard let state = child.savedNativeArk,
        let parent = engine.instances[state.authorization.parent],
        let leaf = parent.savedWayfarerInduction, let key = leaf.seedKey,
        let service = leaf.cassetteService, let link = leaf.ark,
        let source = try? NativeInductionArkSource(
          loan: key, permission: leaf.permission, service: service),
        parent.definition == NativeWayfarerInduction.stateID,
        parent.digest == NativeWayfarerInduction.digest,
        child.definition == NativeInductionArkPack.stateID,
        child.version == NativeInductionArkPack.version,
        child.digest == NativeInductionArkPack.digest,
        child.id == state.authorization.job, child.outcome == .active,
        child.contract == nil, child.completionReceipt == nil, child.dialogue == nil,
        child.payloads.isEmpty, child.gearIssues.isEmpty, child.milestones.isEmpty,
        child.data == .object([:]), child.campaignParent == nil, child.campaignChildren.isEmpty,
        child.timers.keys.allSatisfy({ $0 == NativeInductionArkPack.launchTimer }),
        link.job == child.id, link.registeredArk == source.actor,
        link.operation == state.authorization.operation, link.loanOperation == key.operation,
        state.shapeValid(source: source, key: key),
        state.authorization.sequence <= engine.nextEvent,
        parent.hasAcknowledged(state.authorization.sequence),
        child.hasAcknowledged(state.authorization.sequence),
        commander.equipmentOwnerID == source.owner,
        currentBoundsValid(state, commander: commander),
        actorValid(child, state: state, source: source),
        legsValid(state, source: source, engine: engine)
      else { return false }
    }
    return true
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
