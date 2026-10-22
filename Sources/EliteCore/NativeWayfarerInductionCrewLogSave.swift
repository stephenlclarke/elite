import Foundation

enum NativeInductionCrewLogSave {
  static let version = 83
  static let alienVersion = 84
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains(where: NativeInductionCrewLogPack.marked)
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    let jobs = engine.instances.values.filter { NativeInductionCrewLogPack.marked($0) }
    guard jobs.count <= 1 else { return false }
    for child in jobs {
      guard let state = child.savedNativeCrewLog,
        let parent = engine.instances[state.authorization.manifest.mission],
        let leaf = parent.savedWayfarerInduction,
        parent.definition == NativeWayfarerInduction.stateID,
        parent.version == NativeWayfarerInduction.version,
        parent.digest == NativeWayfarerInduction.digest,
        let source = try? NativeInductionCrewLogSource(parent: leaf),
        state.shapeValid(parent: leaf), state.authorization.manifest == source.manifest,
        state.authorization.manifest.owner == commander.equipmentOwnerID,
        state.authorization.sequence <= engine.nextEvent,
        state.authorization.stationActor.visit <= commander.flightSimulation.visit,
        state.authorization.physicalTime <= commander.flightSimulation.physicalTime,
        state.authorization.flightSeconds <= engine.flightSeconds,
        commander.nativeStations?.mainStations.contains(where: {
          $0.world == source.manifest.owner && $0.system == NativeInductionCrewLogSource.location
        }) == true,
        parent.hasAcknowledged(state.authorization.sequence),
        child.hasAcknowledged(state.authorization.sequence),
        child.id == state.authorization.job,
        child.definition == NativeInductionCrewLogPack.stateID,
        child.version == NativeInductionCrewLogPack.version,
        child.digest == NativeInductionCrewLogPack.digest,
        child.outcome == .active, child.contract == nil, child.completionReceipt == nil,
        child.dialogue == nil, child.payloads.isEmpty, child.gearIssues.isEmpty,
        child.milestones.isEmpty, child.data == .object([:]), child.campaignParent == nil,
        child.campaignChildren.isEmpty,
        child.timers.keys.allSatisfy({ $0 == NativeInductionCrewLogPack.timer }),
        actorClaimsValid(child, state: state, source: source, commander: commander)
      else { return false }
    }
    return true
  }

  static func actorClaimsValid(
    _ child: ScriptInstance, state: NativeInductionCrewLogState,
    source: NativeInductionCrewLogSource, commander: borrowing Commander
  ) -> Bool {
    if child.ownedEncounters.isEmpty { return state.admission == nil && state.losses.isEmpty }
    guard child.ownedEncounters.count == 1,
      let group = child.ownedEncounters[NativeInductionCrewLogPack.encounter],
      group.id == NativeInductionCrewLogPack.encounter, group.galaxy == 0, group.system == 211,
      group.actors.count == 3, group.admitted || state.admission == nil
    else { return false }
    if let admission = state.admission {
      guard admission.physicalTime <= commander.flightSimulation.physicalTime,
        admission.tender.visit <= commander.flightSimulation.visit
      else { return false }
    }
    for role in NativeInductionCrewLogRole.allCases {
      guard let actor = group.actors[role.rawValue],
        actor.alias == role.rawValue,
        actor.identity == NativeInductionCrewLogPack.actor(job: child.id, role: role),
        actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == child.id,
        actor.location(in: group) == NativeInductionCrewLogSource.location,
        actor.transitLocation == nil, ![.inTransit, .arrivalPending].contains(actor.presence),
        !actor.body.hostile, let npc = actor.body.scriptNPC,
        source.matchesFit(npc.fit, recorder: role == .recorder),
        role != .tender || npc.components["drive"]?.energy == 0,
        npc.intent == nil, npc.velocity == .init(0, 0, 0),
        actor.body.physical?.empSource == nil, actor.body.physical?.empCrewPod == nil
      else { return false }
      if group.admitted {
        guard let native = actor.body.physical,
          native.population == .mission, native.npc?.role == .mission,
          native.identity.system == NativeInductionCrewLogSource.location,
          native.identity.visit >= state.authorization.stationActor.visit,
          native.identity.visit <= commander.flightSimulation.visit,
          native.identity.entity > 1, native.identity.entity < commander.flightSimulation.nextActor,
          native.ordnance == nil, native.rock == nil, native.salvage == nil,
          native.empSource == nil, native.empCrewPod == nil
        else { return false }
      }
      if let loss = state.losses.first(where: { $0.role == role.rawValue }) {
        guard actor.presence == .destroyed, actor.body.energy == 0,
          actor.body.physical?.identity == loss.actor,
          loss.physicalTime <= commander.flightSimulation.physicalTime
        else { return false }
      }
    }
    // Actual admission/destruction can precede its secondary observation publication.
    return true
  }
}
