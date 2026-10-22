import Foundation

extension Game {
  var uncollectedInductionSeedJobs: [UUID] {
    commander.scriptState.instances.values.filter {
      $0.savedNativeInductionSeed?.close == nil && $0.savedNativeInductionSeed != nil
        && $0.savedNativeInductionSeed?.custody == nil
        && $0.outcome == .active
    }.map(\.id).sorted { $0.uuidString < $1.uuidString }
  }
  mutating func closeUncollectedInductionSeedOnExit(_ cause: WayfarerColdChainLossCause) throws {
    for id in uncollectedInductionSeedJobs {
      try closeInductionSeedBooking(instance: id, cause: cause)
    }
  }
  var lostUncollectedInductionSeedJobs: [UUID] {
    uncollectedInductionSeedJobs.filter { id in
      guard let booking = commander.scriptState.instances[id]?.savedNativeInductionSeed?.booking,
        let source = commander.scriptState.instances[booking.parent]?.savedWayfarerInduction?
          .charterSeedSource,
        let resource = commander.scriptState.stationResources[
          source.issue.profile.source.resourceKey]
      else { return false }
      return resource.destroyed && resource.energy == 0
    }
  }
  mutating func closeKnownLostInductionSeedSources() throws {
    for id in lostUncollectedInductionSeedJobs {
      try closeInductionSeedBooking(instance: id, sourceDestroyed: true)
    }
  }
}

extension GameRuntime {
  /// Retain attained native destruction on a refused writer; retry the same reservation release.
  func commitInductionSeedUncollectedLoss() {
    let fatal = game.screen == .gameOver && !game.docked && game.energy.isFinite && game.energy <= 0
    guard
      fatal
        ? !game.uncollectedInductionSeedJobs.isEmpty
        : !game.lostUncollectedInductionSeedJobs.isEmpty
    else { return }
    do {
      try scriptCommand { candidate in
        if fatal {
          try candidate.closeUncollectedInductionSeedOnExit(.shipDestroyed)
        } else {
          try candidate.closeKnownLostInductionSeedSources()
        }
      }
    } catch { game.notify("SEED RESERVATION LOSS NOT SAVED - NATIVE LOSS RETAINED FOR RETRY") }
  }
}
