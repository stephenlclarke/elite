import Foundation

extension Game {
  var uncollectedInductionClinicJobs: [UUID] {
    commander.scriptState.instances.values.filter {
      $0.savedNativeInductionClinic?.close == nil && $0.savedNativeInductionClinic != nil
        && $0.savedNativeInductionClinic?.custody == nil
        && $0.outcome == .active
    }.map(\.id).sorted { $0.uuidString < $1.uuidString }
  }
  mutating func closeUncollectedInductionClinicOnExit(_ cause: WayfarerColdChainLossCause) throws {
    for id in uncollectedInductionClinicJobs {
      try closeInductionClinicBooking(instance: id, cause: cause)
    }
  }
  var lostUncollectedInductionClinicJobs: [UUID] {
    uncollectedInductionClinicJobs.filter { id in
      guard let booking = commander.scriptState.instances[id]?.savedNativeInductionClinic?.booking,
        let source = commander.scriptState.instances[booking.parent]?.savedWayfarerInduction?
          .charterClinicSource,
        let resource = commander.scriptState.stationResources[
          source.issue.profile.source.resourceKey]
      else { return false }
      return resource.destroyed && resource.energy == 0
    }
  }
  mutating func closeKnownLostInductionClinicSources() throws {
    for id in lostUncollectedInductionClinicJobs {
      try closeInductionClinicBooking(instance: id, sourceDestroyed: true)
    }
  }
}

extension GameRuntime {
  /// Retain attained native destruction on a refused writer; retry the same reservation release.
  func commitInductionClinicUncollectedLoss() {
    let fatal = game.screen == .gameOver && !game.docked && game.energy.isFinite && game.energy <= 0
    guard
      fatal
        ? !game.uncollectedInductionClinicJobs.isEmpty
        : !game.lostUncollectedInductionClinicJobs.isEmpty
    else { return }
    do {
      try scriptCommand { candidate in
        if fatal {
          try candidate.closeUncollectedInductionClinicOnExit(.shipDestroyed)
        } else {
          try candidate.closeKnownLostInductionClinicSources()
        }
      }
    } catch { game.notify("CLINIC RESERVATION LOSS NOT SAVED - NATIVE LOSS RETAINED FOR RETRY") }
  }
}
