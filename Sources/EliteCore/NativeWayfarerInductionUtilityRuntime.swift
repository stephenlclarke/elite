import Foundation

private final class NativeInductionUtilityAttempt {
  var game: Game
  init(_ game: borrowing Game) { self.game = copy game }
}

extension Game {
  /// Only observes the actual admitted cohort; never repairs a fault or recreates local kits.
  mutating func advanceInductionUtilitySource(publish: ScriptPublisher?) {
    guard let publish, !paused, !docked, !isMissionTrial, screen.isFlight,
      systemIdentity == NativeInductionUtilitySource.location,
      let child = inductionUtilityChild, child.suspension == nil,
      child.savedNativeInductionUtility?.admission == nil
    else { return }
    let attempt = NativeInductionUtilityAttempt(self)
    do {
      guard try attempt.game.observeInductionUtilityAdmission() else { return }
      attempt.game.persistScriptActors()
      guard attempt.game.commander.valid else { throw SaveError.invalidCommander }
      try publish(&attempt.game)
      self = attempt.game
    } catch { return }
  }
  private mutating func observeInductionUtilityAdmission() throws -> Bool {
    guard var child = inductionUtilityChild, var state = child.savedNativeInductionUtility,
      state.admission == nil, child.revision < UInt64(Int64.max) - 1,
      let group = child.ownedEncounters[NativeInductionUtilityPack.encounter], group.admitted,
      let leaf = wayfarerInductionMission?.savedWayfarerInduction
    else { return false }
    var admitted: [String: NativeArkAdmission] = [:]
    for role in NativeInductionUtilityRole.allCases {
      guard let actor = group.actors[role.rawValue],
        actor.identity == NativeInductionUtilityPack.actor(job: child.id, role: role),
        let native = actor.body.physical?.identity
      else { return false }
      admitted[role.rawValue] = .init(
        actor: native, physicalTime: commander.flightSimulation.physicalTime)
    }
    state.admission = admitted
    guard state.shapeValid(parent: leaf) else { throw SaveError.invalidCommander }
    child.savedNativeInductionUtility = state
    child.revision += 1
    child.journal.append(
      "Three original Enron utility modules actually admitted. Their initial faults and single crew-owned kits remain unchanged; no repair or stage10 receipt is inferred."
    )
    commander.scriptState.instances[child.id] = child
    return true
  }
}
