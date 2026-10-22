import Foundation

extension Game {
  var activeInductionWorkshopJobs: [UUID] {
    commander.scriptState.instances.values.filter {
      $0.savedNativeInductionWorkshop != nil && $0.savedNativeInductionWorkshop?.end == nil
        && $0.outcome == .active
    }.map(\.id).sorted { $0.uuidString < $1.uuidString }
  }
  var lostInductionWorkshopSources: [UUID] {
    activeInductionWorkshopJobs.filter { id in
      guard let contract = commander.scriptState.instances[id]?.savedNativeInductionWorkshop,
        contract.pickup == nil,
        let source = commander.scriptState.instances[contract.booking.parent]?
          .savedWayfarerInduction?.charterWorkshopSource,
        let resource = commander.scriptState.stationResources[
          source.issue.profile.source.resourceKey]
      else { return false }
      return resource.destroyed && resource.energy == 0
    }
  }
  mutating func loseInductionWorkshopOnExit(_ cause: WayfarerColdChainLossCause) throws {
    for id in activeInductionWorkshopJobs {
      try finishInductionWorkshop(id, kind: .carrierExit, cause: cause)
    }
  }
  mutating func closeLostInductionWorkshopSources() throws {
    for id in lostInductionWorkshopSources { try finishInductionWorkshop(id, kind: .sourceLost) }
  }
}
extension GameRuntime {
  func commitInductionWorkshopLoss() {
    let fatal = game.screen == .gameOver && !game.docked && game.energy.isFinite && game.energy <= 0
    guard
      fatal ? !game.activeInductionWorkshopJobs.isEmpty : !game.lostInductionWorkshopSources.isEmpty
    else { return }
    do {
      try scriptCommand { candidate in
        if fatal {
          try candidate.loseInductionWorkshopOnExit(.shipDestroyed)
        } else {
          try candidate.closeLostInductionWorkshopSources()
        }
      }
    } catch { game.notify("ORIGINAL WORKSHOP LOSS NOT SAVED - NATIVE LOSS RETAINED FOR RETRY") }
  }
}
