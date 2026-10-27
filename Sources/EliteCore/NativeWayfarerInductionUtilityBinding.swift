import Foundation

/// Actual arm-time binding to the retained logical module; first admission remains historical.
struct NativeInductionUtilityBinding: Codable, Sendable, Equatable {
  let logicalActor: UUID
  let firstAdmission: NativeArkAdmission
  let actor: ActorIdentity
  let physicalTime: Double
  fileprivate init(
    logicalActor: UUID, firstAdmission: NativeArkAdmission,
    actor: ActorIdentity, physicalTime: Double
  ) {
    self.logicalActor = logicalActor
    self.firstAdmission = firstAdmission
    self.actor = actor
    self.physicalTime = physicalTime
  }
  func valid(job: UUID, role: NativeInductionUtilityRole, actor: ActorIdentity, time: Double)
    -> Bool
  {
    logicalActor == NativeInductionUtilityPack.actor(job: job, role: role)
      && self.actor == actor && physicalTime == time && time.isFinite
      && firstAdmission.actor.system == actor.system
      && firstAdmission.actor.visit <= actor.visit && firstAdmission.actor.entity > 1
      && firstAdmission.physicalTime.isFinite && firstAdmission.physicalTime <= time
      && (actor == firstAdmission.actor || actor.entity > firstAdmission.actor.entity)
  }
}

extension Game {
  /// Only the actual live body and retained alias may establish a fresh native address at arm time.
  func inductionUtilityBinding(for body: SpaceBody, role: NativeInductionUtilityRole)
    -> NativeInductionUtilityBinding?
  {
    guard inductionUtilityRole(body) == role,
      let actual = bodies.first(where: { $0.physical?.identity == body.physical?.identity }),
      actual == body, let native = actual.physical?.identity,
      let child = inductionUtilityChild, let state = child.savedNativeInductionUtility,
      let first = state.admission?[role.rawValue],
      let retained = child.ownedEncounters[NativeInductionUtilityPack.encounter]?.actors[
        role.rawValue],
      retained.identity == NativeInductionUtilityPack.actor(job: child.id, role: role),
      retained.alias == role.rawValue, retained.presence == .present, retained.body.id == actual.id,
      retained.body.missionInstanceID == child.id,
      retained.body.missionActorID == retained.identity,
      native.entity < commander.flightSimulation.nextActor
    else { return nil }
    let binding = NativeInductionUtilityBinding(
      logicalActor: retained.identity,
      firstAdmission: first, actor: native, physicalTime: commander.flightSimulation.physicalTime)
    guard binding.valid(job: child.id, role: role, actor: native, time: binding.physicalTime)
    else { return nil }
    return binding
  }
}
