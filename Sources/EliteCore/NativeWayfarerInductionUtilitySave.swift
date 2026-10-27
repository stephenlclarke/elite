import Foundation

enum NativeInductionUtilitySave {
  @inline(never)
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    let jobs = engine.instances.values.filter { NativeInductionUtilityPack.marked($0) }
    guard jobs.count <= 1 else { return false }
    for child in jobs {
      guard jobClaimsValid(child, engine: engine, commander: commander) else { return false }
    }
    return engine.instances.values.allSatisfy { parent in
      guard let receipt = parent.savedWayfarerInduction?.utilityReception else { return true }
      return engine.instances[receipt.job]?.savedNativeInductionUtility?.receiving == receipt
    }
  }

  /// Present-job payloads must not reserve a frame while unrelated missions are classified.
  @inline(never)
  private static func jobClaimsValid(
    _ child: ScriptInstance, engine: borrowing ScriptEngineState, commander: borrowing Commander
  ) -> Bool {
    guard let state = child.savedNativeInductionUtility,
      let parent = engine.instances[state.authorization.parent],
      parent.definition == NativeWayfarerInduction.stateID,
      parent.version == NativeWayfarerInduction.version,
      parent.digest == NativeWayfarerInduction.digest,
      let leaf = parent.savedWayfarerInduction, state.shapeValid(parent: leaf),
      let source = try? NativeInductionUtilitySource(parent: leaf),
      child.id == state.authorization.job, child.definition == NativeInductionUtilityPack.stateID,
      child.version == NativeInductionUtilityPack.version,
      child.digest == NativeInductionUtilityPack.digest,
      child.outcome == .active, child.contract == nil, child.completionReceipt == nil,
      child.dialogue == nil, child.payloads.isEmpty, child.gearIssues.isEmpty,
      child.milestones == (state.receiving == nil ? [] : [0]), child.data == .object([:]),
      child.campaignParent == nil,
      child.campaignChildren.isEmpty,
      child.timers.keys.allSatisfy({ $0 == NativeInductionUtilityPack.timer }),
      source.owner == commander.equipmentOwnerID,
      state.authorization.sequence <= engine.nextEvent,
      parent.hasAcknowledged(state.authorization.sequence),
      child.hasAcknowledged(state.authorization.sequence),
      state.authorization.physicalTime <= commander.flightSimulation.physicalTime,
      state.authorization.flightSeconds <= engine.flightSeconds,
      state.authorization.dock.calendarSeconds <= engine.calendarSeconds,
      workClaimsValid(state, parent: parent, child: child, commander: commander),
      state.authorization.dock.actor.visit <= commander.flightSimulation.visit,
      commander.nativeStations?.mainStations.contains(state.authorization.dock.station) == true,
      state.authorization.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      actorClaimsValid(child, state: state, source: source, commander: commander)
    else { return false }
    return true
  }

  static func actorClaimsValid(
    _ child: ScriptInstance, state: NativeInductionUtilityState,
    source: NativeInductionUtilitySource, commander: borrowing Commander
  ) -> Bool {
    if child.ownedEncounters.isEmpty { return state.admission == nil }
    guard child.ownedEncounters.count == 1,
      let group = child.ownedEncounters[NativeInductionUtilityPack.encounter],
      group.id == NativeInductionUtilityPack.encounter, group.galaxy == 0, group.system == 190,
      group.actors.count == 3, group.admitted || state.admission == nil
    else { return false }
    for role in NativeInductionUtilityRole.allCases {
      guard let actor = group.actors[role.rawValue], actor.alias == role.rawValue,
        actor.identity == NativeInductionUtilityPack.actor(job: child.id, role: role),
        actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == child.id,
        actor.location(in: group) == NativeInductionUtilitySource.location,
        actor.transitLocation == nil, ![.inTransit, .arrivalPending].contains(actor.presence),
        !actor.body.hostile, actor.body.rotationRate == 0, let npc = actor.body.scriptNPC,
        source.matchesFit(npc.fit),
        npc.fuel == 0, npc.intent == nil, npc.velocity == .init(0, 0, 0)
      else { return false }
      if group.admitted {
        guard let native = actor.body.physical,
          native.population == .mission, native.npc?.role == .mission,
          native.identity.system == NativeInductionUtilitySource.location,
          native.identity.visit >= state.authorization.dock.actor.visit,
          native.identity.visit <= commander.flightSimulation.visit,
          native.identity.entity > 1, native.identity.entity < commander.flightSimulation.nextActor,
          native.ordnance == nil, native.rock == nil, native.salvage == nil,
          native.empSource == nil, native.empCrewPod == nil, native.payload == nil
        else { return false }
      }
      if let admission = state.admission?[role.rawValue] {
        guard admission.actor.visit <= commander.flightSimulation.visit,
          admission.actor.entity < commander.flightSimulation.nextActor,
          admission.physicalTime <= commander.flightSimulation.physicalTime
        else { return false }
      }
    }
    return true
  }

  static func validateFields(_ mission: [String: Any], schema: Int?, embedded: Bool) throws {
    let own = mission["definition"] as? String == NativeInductionUtilityPack.stateID
    let pin = mission["digest"] as? String == NativeInductionUtilityPack.digest
    let claim = mission.keys.contains("savedNativeInductionUtility")
    guard own == pin, own == claim else { throw SaveError.invalidCommander }
    guard own else { return }
    guard NativeInductionCrewLogSave.supportsUtilitySource(schema), !embedded,
      let leaf = mission["savedNativeInductionUtility"] as? [String: Any],
      let modules = leaf["modules"] as? [Any], modules.count == 3
    else { throw SaveError.invalidCommander }
    let bytes = try JSONSerialization.data(withJSONObject: leaf)
    if leaf.keys.contains("receiving")
      || modules.contains(where: { ($0 as? [String: Any])?.keys.contains("work") == true })
    {
      guard NativeInductionCrewLogSave.supportsUtilityWork(schema) else {
        throw SaveError.invalidCommander
      }
    }
    for raw in modules {
      guard let work = (raw as? [String: Any])?["work"] as? [String: Any],
        let segments = work["segments"] as? [[String: Any]]
      else { continue }
      if segments.contains(where: {
        ($0["arm"] as? [String: Any])?.keys.contains("binding") == true
      }) {
        guard NativeInductionCrewLogSave.supportsUtilityBinding(schema) else {
          throw SaveError.invalidCommander
        }
      }
    }
    guard bytes.count <= 1_048_576 else { throw SaveError.invalidCommander }
    let decoded = try JSONDecoder().decode(NativeInductionUtilityState.self, from: bytes)
    guard
      (leaf as NSDictionary).isEqual(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
    else { throw SaveError.invalidCommander }
  }
}
