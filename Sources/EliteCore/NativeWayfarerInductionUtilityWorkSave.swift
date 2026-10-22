import Foundation

extension NativeInductionUtilitySave {
  static func bindingMatches(_ arm: NativeInductionUtilityArm, admission: NativeArkAdmission)
    -> Bool
  {
    if let binding = arm.binding {
      return binding.firstAdmission == admission
        && binding.valid(job: arm.job, role: arm.role, actor: arm.actor, time: arm.physicalTime)
    }
    return arm.actor.visit != admission.actor.visit || arm.actor == admission.actor
  }

  static func workClaimsValid(
    _ state: NativeInductionUtilityState,
    parent: ScriptInstance, child: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    let physicalTime = commander.flightSimulation.physicalTime
    let flightTime = commander.scriptState.flightSeconds
    let visit = commander.flightSimulation.visit
    let nextActor = commander.flightSimulation.nextActor
    let event = commander.scriptState.nextEvent
    var intervals: UInt64 = 0
    for module in state.modules {
      guard let work = module.work else { continue }
      guard let admission = state.admission?[module.role.rawValue] else { return false }
      for segment in work.segments {
        let arm = segment.arm
        guard arm.sequence <= event, child.hasAcknowledged(arm.sequence),
          parent.hasAcknowledged(arm.sequence),
          arm.actor.visit >= admission.actor.visit, arm.actor.visit <= visit,
          arm.actor.entity < nextActor, arm.physicalTime >= admission.physicalTime,
          bindingMatches(arm, admission: admission),
          arm.physicalTime <= physicalTime, arm.flightSeconds <= flightTime,
          (segment.last ?? arm.physicalTime) <= physicalTime,
          segment.seconds <= flightTime - arm.flightSeconds + 1e-7
        else { return false }
        intervals += segment.intervals
      }
      if let repair = work.repair {
        guard repair.sequence <= event, child.hasAcknowledged(repair.sequence),
          parent.hasAcknowledged(repair.sequence),
          repair.physicalTime <= physicalTime, repair.flightSeconds <= flightTime,
          repair.actor.visit <= visit, repair.actor.entity < nextActor
        else { return false }
      }
    }
    if let receipt = state.receiving {
      guard receipt.sequence <= event, parent.hasAcknowledged(receipt.sequence),
        child.hasAcknowledged(receipt.sequence), receipt.physicalTime <= physicalTime,
        receipt.flightSeconds <= flightTime,
        receipt.dock.calendarSeconds <= commander.scriptState.calendarSeconds,
        receipt.dock.actor.visit <= visit,
        receipt.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
        commander.nativeStations?.mainStations.contains(receipt.dock.station) == true
      else { return false }
    }
    return intervals <= child.revision
  }
}
