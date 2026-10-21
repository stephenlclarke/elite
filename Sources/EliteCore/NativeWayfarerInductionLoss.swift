import Foundation

extension Game {
  /// Called at the real escape/destruction boundary; it consumes no replacement clinic stock.
  mutating func loseWayfarerInductionCrate(_ cause: WayfarerColdChainLossCause) throws -> Bool {
    guard var mission = wayfarerInductionMission, let state = mission.savedWayfarerInduction,
      !state.payloads.isEmpty
    else { return false }
    guard !docked, mission.outcome == .active, let carrier = commander.hullInstanceID,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      mission.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let facts = WayfarerColdChainPhysicalLoss(
      cause: cause, sequence: sequence, context: scriptEventContext(mission),
      energy: max(0, energy), visit: commander.flightSimulation.visit)
    let loss = NativeInductionCrateLoss(
      carrier: carrier, physicalTime: commander.flightSimulation.physicalTime, facts: facts)
    let next = try state.losing(loss)
    mission.savedWayfarerInduction = next
    mission.payloads = next.payloads
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      "The original induction consignment was lost with its carrier; no replacement stock or success was granted."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    return true
  }
}

extension GameRuntime {
  func commitWayfarerInductionCrateLoss() {
    guard game.screen == .gameOver, game.energy.isFinite, game.energy <= 0,
      let state = game.wayfarerInductionMission?.savedWayfarerInduction,
      !state.payloads.isEmpty, let publish = scriptPublisher()
    else { return }
    var candidate = game
    do {
      guard try candidate.loseWayfarerInductionCrate(.shipDestroyed) else { return }
      try publish(&candidate)
      game = candidate
    } catch { game.notify("INDUCTION CARGO LOSS NOT SAVED - NATIVE LOSS RETAINED FOR RETRY") }
  }
}
