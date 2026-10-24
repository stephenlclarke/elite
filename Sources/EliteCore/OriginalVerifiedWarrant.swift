import Foundation

/// Closed G06 predicates consume existing native actor, station-choice and payment records.
enum OriginalVerifiedWarrant {
  static let stateID = "l337.contract/verified-warrant"
  static let digest = "f125be8200d0dd3ae834f2dc4cd52da46f7c571de7e67cbec61f76c7beab9911"
  static let issuer = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let objective = SystemIdentity(galaxy: 0, system: 185)
  static let encounterID = "verified-hostile"
  static let actorID = "warrant-target"
  static let group = "warrant-terminal"
  static let report = "voss-report"
  static let reportChoice = "report-verified-target"
  static let reward = 11200
  static let weapon = ScriptNPCWeapon(
    id: "forward", kind: .laser, muzzle: .init(0, 0, 61), direction: .init(0, 0, 1),
    arc: 0.03, damage: 6, range: 15000, interval: 0.1, energy: 0.5,
    heat: 3.2, cooling: 12, maximumHeat: 256, colour: nil, trackingRate: nil,
    projectileSpeed: nil, lifetime: nil, collisionRadius: nil, collisionDelay: nil)
  static let npc = ScriptNPCDefinition(
    id: "armed-aggressor", name: "Verified Renas armed aggressor",
    source: "Original G06 native warrant target",
    basis: "Explicit native project NPC fit; H0 warrant, no incidental bounty.",
    model: "catalogue:SH023", scale: 1, energy: 100, recharge: 0, speed: 100,
    acceleration: 50, pitch: 1, yaw: 1, roll: 1, missiles: 0, fuel: 0,
    drive: nil, ecm: false, bounty: 0, lasers: [weapon], components: nil)

  static func validJob(_ state: borrowing ScriptInstance) -> Bool {
    guard state.definition == stateID, state.version == "1.0.0", state.digest == digest,
      let job = state.contract, job.valid, job.provider == "l337.contract",
      job.digest == digest, job.version == "1.0.0", job.station == issuer,
      job.boardKey == digest + "/verified-warrant/" + issuer.key,
      job.group == "l337.contract/verified-warrant", job.clock == .local,
      job.deadline == nil, job.offer.duration == 0, job.offer.key == "renas-hostile",
      job.offer.reward == reward, job.offer.deposit == 0, job.offer.failureReward == 0,
      !job.offer.refundOnFailure, job.offer.destinationGalaxy == objective.galaxy,
      job.offer.destinationSystem == objective.system,
      state.id == Game.contractJobIdentity(job.offer.id)
    else { return false }
    return job.offer.parameters
      == .object([
        "route": .array([.integer(7), .integer(185), .integer(7)]),
        "legs": .integer(2), "hazard": .integer(0),
        "encounter": .string(encounterID), "actor": .string(actorID), "receiver": .string(report),
      ])
  }

  static func target(_ state: borrowing ScriptInstance) -> ScriptOwnedActor? {
    guard let encounter = state.ownedEncounters[encounterID], encounter.admitted,
      encounter.galaxy == objective.galaxy, encounter.system == objective.system,
      Set(encounter.actors.keys) == [actorID], let actor = encounter.actors[actorID],
      actor.identity
        == ScriptIdentity.uuid("script-actor-v2:\(state.id):\(digest):\(encounterID):\(actorID)"),
      actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == state.id,
      actor.body.hostile, actor.body.id >= 0,
      actor.body.physical?.identity.system == objective,
      let fit = actor.body.scriptNPC?.fit, fit.definition == npc
    else { return nil }
    return actor
  }

  static func qualifiedKill(_ state: borrowing ScriptInstance) -> Bool {
    guard let actor = target(state) else { return false }
    return actor.presence == .destroyed && actor.body.energy == 0
      && actor.destroyedByPlayer == true && actor.body.destroyedByPlayer == true
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
      throw MissionPackError("Refuel or refit for the frozen Avenor-Renas-Avenor warrant route.")
    }
  }

  static func requireFinish(
    _ outcome: ScriptOutcome, event: ScriptEvent, game: borrowing Game,
    state: borrowing ScriptInstance
  ) throws {
    guard validJob(state) else {
      throw MissionPackError("Warrant terms changed from their original native offer.")
    }
    if outcome == .failed {
      guard event.kind == "actor.destroyed", event.instance == state.id,
        let actor = target(state), actor.presence == .destroyed, actor.body.energy == 0,
        actor.destroyedByPlayer == false, actor.body.destroyedByPlayer != true,
        event.values["actor_id"]?.string == actor.identity.uuidString,
        event.values["encounter_id"]?.string == encounterID
      else {
        throw MissionPackError("A failed warrant needs its actual non-player destruction record.")
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
      guard qualifiedKill(state), reportReceipt(state) != nil,
        event.values["dialogue_id"]?.string == report,
        event.values["choice_id"]?.string == reportChoice
      else {
        throw MissionPackError(
          "Only this warrant's actual player-attributed hostile kill can be reported.")
      }
    } else {
      guard outcome == .abandoned, choice.dialogue == "voss-withdraw",
        choice.choice == "withdraw-warrant", event.values["dialogue_id"]?.string == choice.dialogue,
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
    guard qualifiedKill(state), receipt.causeKind == "dialogue.confirmed",
      receipt.settlementAmount == reward, job.settlementAmount == reward,
      let choice = reportReceipt(state), choice.valid(for: state, engine: engine),
      choice.sequence == receipt.sequence, choice.revision == receipt.revision,
      choice.cause == receipt.cause, choice.committed == receipt.committed,
      receipt.destroyedEncounters == [encounterID]
    else { return false }
    return true
  }
}
