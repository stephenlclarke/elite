import Foundation

/// Closed G07 predicates consume existing native actor, station-choice and payment records.
enum OriginalCorridorDefence {
  static let stateID = "l337.contract/corridor-defence"
  static let digest = "ec6b00bfe07466f4d205c415adff00ef1fb0a9a56b487d5a1312dfe3f314762c"
  static let issuer = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let objective = SystemIdentity(galaxy: 0, system: 185)
  static let encounterID = "registered-corridor"
  static let actorIDs = ["raider-a", "raider-b", "raider-c"]
  static let group = "corridor-terminal"
  static let report = "voss-corridor-report"
  static let reportChoice = "report-defended-corridor"
  static let reward = 14000
  static let weapon = ScriptNPCWeapon(
    id: "forward", kind: .laser, muzzle: .init(0, 0, 61), direction: .init(0, 0, 1),
    arc: 0.03, damage: 6, range: 15000, interval: 0.1, energy: 0.5,
    heat: 3.2, cooling: 12, maximumHeat: 256, colour: nil, trackingRate: nil,
    projectileSpeed: nil, lifetime: nil, collisionRadius: nil, collisionDelay: nil)
  static let npc = ScriptNPCDefinition(
    id: "corridor-raider", name: "Registered Renas corridor raider",
    source: "Original G07 native corridor raider",
    basis: "Explicit native project NPC fit; H0 corridor defence, no incidental bounty.",
    model: "catalogue:SH023", scale: 1, energy: 100, recharge: 0, speed: 100,
    acceleration: 50, pitch: 1, yaw: 1, roll: 1, missiles: 0, fuel: 0,
    drive: nil, ecm: false, bounty: 0, lasers: [weapon], components: nil)

  static func validJob(_ state: borrowing ScriptInstance) -> Bool {
    guard state.definition == stateID, state.version == "1.0.0", state.digest == digest,
      let job = state.contract, job.valid, job.provider == "l337.contract",
      job.digest == digest, job.version == "1.0.0", job.station == issuer,
      job.boardKey == digest + "/corridor-defence/" + issuer.key,
      job.group == "l337.contract/corridor-defence", job.clock == .local,
      job.deadline == nil, job.offer.duration == 0, job.offer.key == "renas-corridor",
      job.offer.reward == reward, job.offer.deposit == 0, job.offer.failureReward == 0,
      !job.offer.refundOnFailure, job.offer.destinationGalaxy == objective.galaxy,
      job.offer.destinationSystem == objective.system,
      state.id == Game.contractJobIdentity(job.offer.id)
    else { return false }
    return job.offer.parameters
      == .object([
        "route": .array([.integer(7), .integer(185), .integer(7)]),
        "legs": .integer(2), "hazard": .integer(0),
        "encounter": .string(encounterID), "actors": .array(actorIDs.map(ScriptValue.string)),
        "receiver": .string(report),
      ])
  }

  static func target(_ state: borrowing ScriptInstance, alias: String) -> ScriptOwnedActor? {
    guard let encounter = state.ownedEncounters[encounterID], encounter.admitted,
      encounter.galaxy == objective.galaxy, encounter.system == objective.system,
      Set(encounter.actors.keys) == Set(actorIDs),
      Set(encounter.actors.values.map(\.identity)).count == 3,
      actorIDs.contains(alias), let actor = encounter.actors[alias],
      actor.identity
        == ScriptIdentity.uuid("script-actor-v2:\(state.id):\(digest):\(encounterID):\(alias)"),
      actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == state.id,
      actor.body.hostile, actor.body.id >= 0,
      actor.body.physical?.identity.system == objective,
      let fit = actor.body.scriptNPC?.fit, fit.definition == npc
    else { return nil }
    return actor
  }

  static func qualifiedKill(_ state: borrowing ScriptInstance, alias: String) -> Bool {
    guard let actor = target(state, alias: alias) else { return false }
    return actor.presence == .destroyed && actor.body.energy == 0
      && actor.destroyedByPlayer == true && actor.body.destroyedByPlayer == true
  }

  static func qualifiedKillCount(_ state: borrowing ScriptInstance) -> Int {
    var count = 0
    for alias in actorIDs { if qualifiedKill(state, alias: alias) { count += 1 } }
    return count
  }

  static func progressText(_ state: borrowing ScriptInstance) -> String {
    let count = qualifiedKillCount(state)
    return "VOSS: \(count)/3 registered raiders verified. "
      + (count == 3
        ? "Report the three actual destruction records to Voss at Avenor for 1400 CR."
        : "All three actual player-attributed destructions and Voss's return report are required. No payment yet.")
  }

  /// The same native choice receipt names Voss during live settlement and historical reload.
  static func reportReceipt(_ state: borrowing ScriptInstance) -> ScriptChoiceReceipt? {
    guard let choice = state.choiceReceipts[group], choice.instance == state.id,
      choice.group == group, choice.dialogue == report, choice.choice == reportChoice,
      let cause = choice.cause, cause.docked, cause.mainStation,
      cause.galaxy == issuer.galaxy, cause.system == issuer.system,
      let dock = cause.nativeMainDock, dock.valid, dock.station.key == issuer.key,
      choice.committed.nativeMainDock == dock,
      choice.committed.galaxy == issuer.galaxy, choice.committed.system == issuer.system
    else { return nil }
    return choice
  }

  static func requireAcceptance(
    _ event: ScriptEvent, game: borrowing Game, state: borrowing ScriptInstance,
    candidate: borrowing Commander
  ) throws {
    guard validJob(state), event.kind == "mission.accepted", event.instance == state.id,
      event.context == game.scriptEventContext(state),
      game.nativeMainStationDockEvidenceIsCurrent, game.contractStation == issuer,
      candidate.galaxy == issuer.galaxy, candidate.system == issuer.system,
      let front = candidate.laser(on: .front), front.damage > 0,
      candidate.fittedEquipment(at: .laser(.front)) != nil
    else {
      throw MissionPackError(
        "Voss requires the actual Avenor issuer and a fitted damaging front weapon.")
    }
    let systems = Universe.systemsIncludingPlugh(number: issuer.galaxy)
    let distance = systems[issuer.system].distance(to: systems[objective.system])
    guard distance <= candidate.maximumJumpDistance, distance <= candidate.fullTankJumpDistance
    else {
      throw MissionPackError(
        "Refuel or refit for the frozen Avenor-Renas-Avenor corridor defence route.")
    }
  }

  static func requireFinish(
    _ outcome: ScriptOutcome, event: ScriptEvent, game: borrowing Game,
    state: borrowing ScriptInstance
  ) throws {
    guard validJob(state) else {
      throw MissionPackError("Corridor defence terms changed from their original native offer.")
    }
    if outcome == .failed {
      guard event.kind == "actor.destroyed", event.instance == state.id,
        let alias = event.values["alias"]?.string,
        let actor = target(state, alias: alias), actor.presence == .destroyed,
        actor.body.energy == 0,
        actor.destroyedByPlayer == false, actor.body.destroyedByPlayer != true,
        event.values["actor_id"]?.string == actor.identity.uuidString,
        event.values["encounter_id"]?.string == encounterID
      else {
        throw MissionPackError(
          "A failed corridor defence needs its actual non-player destruction record.")
      }
      return
    }
    guard game.nativeMainStationDockEvidenceIsCurrent, game.contractStation == issuer,
      event.kind == "dialogue.confirmed", event.instance == state.id,
      event.context == game.scriptEventContext(state),
      let choice = state.choiceReceipts[group], choice.sequence == event.sequence,
      choice.revision == state.revision + 1, choice.cause == event.context,
      choice.committed.nativeMainDock == event.context?.nativeMainDock
    else {
      throw MissionPackError(
        "Return to the actual issuing Voss contact and confirm its current report.")
    }
    if outcome == .complete {
      guard qualifiedKillCount(state) == 3, reportReceipt(state) != nil,
        event.values["dialogue_id"]?.string == report,
        event.values["choice_id"]?.string == reportChoice
      else {
        throw MissionPackError(
          "Only all three registered raiders' actual player-attributed destructions can be reported."
        )
      }
    } else {
      guard outcome == .abandoned, choice.dialogue == "voss-corridor-withdraw",
        choice.choice == "withdraw-corridor",
        event.values["dialogue_id"]?.string == choice.dialogue,
        event.values["choice_id"]?.string == choice.choice
      else { throw MissionPackError("Use the issuing Voss withdrawal confirmation.") }
    }
  }

  /// Historical facts remain valid after legitimate later travel; no live station is required.
  static func validCompletion(
    _ receipt: ScriptCompletionReceipt, state: borrowing ScriptInstance,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard validJob(state), let job = state.contract, job.settled,
      job.settlementOutcome == receipt.outcome
    else { return false }
    if receipt.outcome != .complete {
      return [ScriptOutcome.failed, .abandoned].contains(receipt.outcome)
        && job.settlementAmount == 0 && receipt.settlementAmount == 0
    }
    guard qualifiedKillCount(state) == 3, receipt.causeKind == "dialogue.confirmed",
      receipt.settlementAmount == reward, job.settlementAmount == reward,
      let choice = reportReceipt(state), choice.valid(for: state, engine: engine),
      choice.sequence == receipt.sequence, choice.revision == receipt.revision,
      choice.cause == receipt.cause, choice.committed == receipt.committed,
      receipt.destroyedEncounters == [encounterID]
    else { return false }
    return true
  }
}
