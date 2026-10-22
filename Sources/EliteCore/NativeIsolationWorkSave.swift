import Foundation

enum NativeIsolationWorkSave {
  static let version = 131
  static let alienVersion = 132
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func supports(_ schema: Int?) -> Bool {
    contains(schema) || NativeIsolationWorkParentSave.contains(schema)
  }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeInductionCrewLogSave.alienVersion : NativeInductionCrewLogSave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    let instances = commander.scriptState.instances
    return instances.values.contains(where: { NativeIsolationWorkPack.marked($0) })
  }

  /// Historical custody is joined through the parent's primitive, never through Commander.valid
  /// or the runtime's currently-held-tool factory. Genuine return/loss must not erase old work.
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    let physicalTime = commander.flightSimulation.physicalTime
    let jobs = engine.instances.values.filter { NativeIsolationWorkPack.marked($0) }
    guard jobs.count <= 1 else { return false }
    for child in jobs {
      guard let state = child.savedIsolationWork, state.shapeValid,
        let parent = engine.instances[state.permission.parent],
        let primitive = try? NativeIsolationWorkParent.primitive(
          parent: parent, commander: commander),
        let accepted = parent.savedIsolationWorkParent,
        child.id == state.job, child.definition == NativeIsolationWorkPack.stateID,
        child.version == NativeIsolationWorkPack.version,
        child.digest == NativeIsolationWorkPack.digest,
        child.outcome == .active, child.contract == nil, child.completionReceipt == nil,
        child.dialogue == nil, child.payloads.isEmpty, child.gearIssues.isEmpty,
        child.milestones.isEmpty, child.data == .object([:]), child.campaignParent == nil,
        child.campaignChildren.isEmpty,
        child.timers.keys.allSatisfy({ $0 == NativeIsolationWorkPack.timer }),
        state.permission.parent == primitive.parentID,
        state.permission.parentDigest == primitive.parentDigest,
        state.permission.authorization == primitive.authorization,
        state.permission.issueOperation == primitive.issueOperation,
        state.permission.owner == primitive.owner, state.permission.issuer == primitive.issuer,
        state.permission.acceptance == primitive.acceptance,
        state.permission.carrier == accepted.carrier,
        accepted.inventoryRevision < UInt64(Int64.max) - 1,
        state.permission.inventoryRevision == accepted.inventoryRevision + 1,
        state.permission.owner == commander.equipmentOwnerID,
        state.permission.sequence > primitive.sequence,
        state.permission.physicalTime == primitive.physicalTime,
        state.permission.physicalTime <= physicalTime,
        acknowledged(
          state.permission.sequence, child: child, parent: parent, next: engine.nextEvent),
        actorClaims(child: child, state: state, commander: commander)
      else { return false }
      let cutoff = primitive.cutoff
      for module in state.modules {
        if let admission = module.admission {
          guard
            acknowledged(admission.sequence, child: child, parent: parent, next: engine.nextEvent),
            admission.physicalTime <= physicalTime,
            state.localSeconds <= physicalTime - admission.physicalTime + 1e-7
          else { return false }
        }
        for segment in module.history.segments {
          guard segment.last <= physicalTime,
            segment.first >= state.permission.physicalTime,
            segment.authority.inventoryRevision >= state.permission.inventoryRevision
          else { return false }
          if let cutoff, segment.last > cutoff.physicalTime { return false }
        }
        if let opening = module.opening {
          guard
            acknowledged(opening.sequence, child: child, parent: parent, next: engine.nextEvent),
            opening.meter.end <= physicalTime
          else { return false }
          if let cutoff {
            guard opening.sequence < cutoff.sequence, opening.meter.end <= cutoff.physicalTime
            else { return false }
          }
        }
        if let verification = module.verification {
          guard
            acknowledged(
              verification.sequence, child: child, parent: parent, next: engine.nextEvent),
            verification.last.end <= physicalTime
          else { return false }
          if let cutoff {
            guard verification.sequence < cutoff.sequence,
              verification.last.end <= cutoff.physicalTime
            else { return false }
          }
        }
        if let meter = module.lastMeter {
          guard meter.end <= physicalTime,
            meter.start >= (module.admission?.physicalTime ?? .infinity),
            meter.actor.entity < commander.flightSimulation.nextActor,
            meter.peer.entity < commander.flightSimulation.nextActor,
            meter.actor.visit <= commander.flightSimulation.visit
          else { return false }
        }
        if let loss = module.loss {
          guard acknowledged(loss.sequence, child: child, parent: parent, next: engine.nextEvent),
            loss.physicalTime <= physicalTime
          else { return false }
        }
      }
      if let loss = state.stationLoss {
        guard acknowledged(loss.sequence, child: child, parent: parent, next: engine.nextEvent),
          loss.physicalTime <= physicalTime,
          commander.nativeStations?.mainStations.contains(loss.station) == true,
          engine.stationResources[loss.station.key]?.destroyed == true
        else { return false }
      }
    }
    return true
  }

  private static func acknowledged(
    _ sequence: UInt64, child: ScriptInstance, parent: ScriptInstance, next: UInt64
  ) -> Bool {
    sequence > 0 && sequence <= next && child.hasAcknowledged(sequence)
      && parent.hasAcknowledged(sequence)
  }

  private static func actorClaims(
    child: ScriptInstance, state: NativeIsolationWorkState, commander: borrowing Commander
  ) -> Bool {
    if child.ownedEncounters.isEmpty { return state.modules.allSatisfy { $0.admission == nil } }
    guard child.ownedEncounters.count == 1,
      let group = child.ownedEncounters[NativeIsolationWorkPack.encounter],
      group.id == NativeIsolationWorkPack.encounter, group.galaxy == 0, group.system == 185,
      group.actors.count == 2
    else { return false }
    let source = NativeIsolationWorkSource(owner: state.permission.owner)
    let visit = commander.flightSimulation.visit
    let nextActor = commander.flightSimulation.nextActor
    for module in state.modules {
      guard let actor = group.actors[module.role.rawValue], actor.alias == module.role.rawValue,
        actor.identity == NativeIsolationWorkPack.actor(job: child.id, role: module.role),
        actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == child.id,
        actor.location(in: group) == NativeIsolationWorkSource.location,
        actor.transitLocation == nil,
        ![.inTransit, .arrivalPending].contains(actor.presence),
        !actor.body.hostile, actor.body.rotationRate == 0,
        let npc = actor.body.scriptNPC, source.matches(npc.fit),
        npc.fuel == 0, npc.intent == nil, npc.velocity == .init(0, 0, 0)
      else { return false }
      if group.admitted {
        guard let admission = module.admission, admission.actor.visit <= visit,
          admission.actor.entity < nextActor,
          let native = actor.body.physical,
          native.population == .mission, native.npc?.role == .mission,
          native.identity.system == NativeIsolationWorkSource.location,
          native.identity.visit >= admission.actor.visit, native.identity.visit <= visit,
          native.identity.entity > 1, native.identity.entity < nextActor,
          native.ordnance == nil, native.rock == nil, native.salvage == nil,
          native.empSource == nil, native.empCrewPod == nil, native.payload == nil,
          (actor.presence == .destroyed) == (module.loss != nil)
        else { return false }
      } else {
        guard module.admission == nil, actor.presence == .prepared,
          actor.body.position == module.role.offset, actor.body.physical == nil
        else { return false }
      }
      for segment in module.history.segments {
        guard segment.authority.actor.visit <= visit, segment.authority.actor.entity < nextActor,
          segment.authority.actor.visit >= (module.admission?.actor.visit ?? UInt64.max)
        else { return false }
      }
    }
    return true
  }

  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedIsolationWork"), !root.keys.contains("isolationWork")
    else { throw SaveError.invalidCommander }
    func validate(_ raw: Any?, embedded: Bool) throws {
      guard let raw else { return }
      let values: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        values = Array(dictionary.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      for raw in values {
        guard let mission = raw as? [String: Any], !mission.keys.contains("isolationWork")
        else { throw SaveError.invalidCommander }
        let own = mission["definition"] as? String == NativeIsolationWorkPack.stateID
        let pin = mission["digest"] as? String == NativeIsolationWorkPack.digest
        let claim = mission.keys.contains("savedIsolationWork")
        guard own == pin, own == claim else { throw SaveError.invalidCommander }
        if own {
          guard supports(schema), !embedded,
            let leaf = mission["savedIsolationWork"] as? [String: Any],
            let modules = leaf["modules"] as? [[String: Any]], modules.count == 2,
            modules.allSatisfy({
              guard let history = $0["history"] as? [String: Any],
                let segments = history["segments"] as? [Any]
              else { return false }
              return segments.count <= NativeIsolationWorkEnvelope.maximumSegments
            })
          else { throw SaveError.invalidCommander }
          let bytes = try JSONSerialization.data(withJSONObject: leaf)
          guard bytes.count <= 1_048_576 else { throw SaveError.invalidCommander }
          let decoded = try JSONDecoder().decode(NativeIsolationWorkState.self, from: bytes)
          guard decoded.shapeValid,
            (leaf as NSDictionary).isEqual(
              try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
          else { throw SaveError.invalidCommander }
        }
      }
    }
    if part == .missions { try validate(root["instances"], embedded: false) }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try validate(embedded["instances"], embedded: true)
    }
  }
}
