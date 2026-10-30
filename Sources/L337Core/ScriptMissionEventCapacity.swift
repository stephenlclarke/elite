import Foundation

/// Ephemeral accounting for one uninterrupted native effect/projection turn, not a reservation
/// or damage capability. Native owners supply the real outcome flags; this never predicts damage.
struct ScriptMissionEventCapacityPlan: Sendable, Equatable {
  let requiredEvents: Int
  let pendingCount: Int
  let nextEvent: UInt64

  fileprivate init(requiredEvents: Int, pendingCount: Int, nextEvent: UInt64) {
    self.requiredEvents = requiredEvents
    self.pendingCount = pendingCount
    self.nextEvent = nextEvent
  }
}

enum ScriptMissionEventCapacityError: Error, Equatable, Sendable {
  case insufficientCapacity
}

extension Game {
  /// Matches emitScriptEvent and the actual retained terminal-record guards. Call before emission
  /// or physical commit, then project in the same actor turn before unrelated emission/draining.
  func planScriptMissionImpactEvents(
    target: SpaceBody?, damage: Double, damageAdmitted: Bool, victimPart: String?,
    victimComponentID: UUID?, componentDestroyed: Bool, hullDestroyed: Bool,
    sourceWeaponInstanceID: UUID? = nil
  ) throws -> ScriptMissionEventCapacityPlan {
    var required = 0
    if let source = sourceWeaponInstanceID,
      commander.scriptState.instances[source]?.outcome == .active
    {
      required += 1
    }
    if let target, let instanceID = target.missionInstanceID, let actorID = target.missionActorID,
      let instance = commander.scriptState.instances[instanceID], instance.outcome == .active
    {
      if damageAdmitted, damage.isFinite, damage > 0 {
        required += 1
        if componentDestroyed, victimPart != nil, victimComponentID != nil { required += 1 }
      }
      if hullDestroyed,
        instance.ownedEncounters.values.contains(where: { encounter in
          encounter.admitted
            && encounter.actors.values.contains { actor in
              actor.identity == actorID && actor.presence == .present && actor.body.id == target.id
            }
        })
      {
        required += 1
      }
    }
    let pending = commander.scriptState.pendingEvents.count
    let sequence = commander.scriptState.nextEvent
    let (finalPending, pendingOverflow) = pending.addingReportingOverflow(required)
    let (finalSequence, sequenceOverflow) = sequence.addingReportingOverflow(UInt64(required))
    // These are the actual emitter's 4096-entry bound and strict pre-increment Int64 guard.
    guard !pendingOverflow, !sequenceOverflow, finalPending <= 4096,
      finalSequence <= UInt64(Int64.max) - 1
    else { throw ScriptMissionEventCapacityError.insufficientCapacity }
    return .init(requiredEvents: required, pendingCount: pending, nextEvent: sequence)
  }
}
