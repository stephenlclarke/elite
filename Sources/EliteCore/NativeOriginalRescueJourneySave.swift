import Foundation

extension NativeOriginalRescueJourney {
  @inline(never)
  static func liveActorMatches(
    commander: borrowing Commander, mission: UUID, alias: String,
    logical: UUID, bodyID: Int, actor: ActorIdentity
  ) -> Bool {
    for index in commander.scriptState.instances.indices {
      if commander.scriptState.instances.keys[index] == mission {
        return liveMissionActorMatches(
          commander.scriptState.instances.values[index],
          alias: alias, logical: logical, bodyID: bodyID, actor: actor)
      }
    }
    return false
  }
  @inline(never)
  private static func liveMissionActorMatches(
    _ mission: borrowing ScriptInstance, alias: String, logical: UUID, bodyID: Int,
    actor: ActorIdentity
  ) -> Bool {
    for index in mission.ownedEncounters.indices {
      if mission.ownedEncounters.keys[index] == encounterID {
        return liveEncounterActorMatches(
          mission.ownedEncounters.values[index],
          alias: alias, logical: logical, bodyID: bodyID, actor: actor)
      }
    }
    return false
  }
  @inline(never)
  private static func liveEncounterActorMatches(
    _ encounter: borrowing ScriptOwnedEncounter, alias: String,
    logical: UUID, bodyID: Int, actor: ActorIdentity
  ) -> Bool {
    for index in encounter.actors.indices {
      if encounter.actors.keys[index] == alias {
        return liveOwnedActorMatches(
          encounter.actors.values[index],
          logical: logical, bodyID: bodyID, actor: actor)
      }
    }
    return false
  }
  @inline(never)
  private static func liveOwnedActorMatches(
    _ saved: borrowing ScriptOwnedActor, logical: UUID, bodyID: Int, actor: ActorIdentity
  ) -> Bool {
    guard saved.presence == .present, saved.identity == logical,
      saved.body.id == bodyID, saved.body.physical?.identity == actor
    else { return false }
    return true
  }

  @inline(never)
  static func validAdmission(_ admission: NativePeopleAdmission, commander: borrowing Commander)
    -> Bool
  {
    guard let person = admission.person.rescue, person.valid,
      admission.origin == .originalRescuedPod,
      let state = commander.nativePeople?.originalRescue,
      person.owner == state.owner,
      let capture = state.captures.first(where: {
        $0.alias == aliases[person.ordinal]
      })
    else { return false }
    return admission.operation == capture.operation && admission.actor == capture.actor
      && admission.collector == capture.collector && admission.owner == capture.owner
      && admission.hull == capture.carrier && admission.tool == capture.tool.id
      && admission.inventoryRevision == capture.inventoryRevision
      && admission.physicalTime == capture.physicalTime && admission.epoch == capture.epoch
      && admission.revision == capture.revision
  }

  static func berthValid(_ berth: PassengerBerth, commander: borrowing Commander) -> Bool {
    guard case .nativePerson(let reference) = berth.use, let person = reference.rescue,
      let custody = commander.nativePeople, let state = custody.originalRescue,
      let boarding = state.boarding, boarding.berths.indices.contains(person.ordinal),
      person.owner == state.owner, person.valid, state.terminalOperation == nil,
      boarding.berths[person.ordinal] == berth.id,
      commander.accommodation.fitted.contains(berth.id), berth.lifeSupportWorking,
      berth.humanoidCompatible, custody.held.contains(where: { $0.person == reference })
    else { return false }
    return true
  }

  @inline(never)
  static func validSource(
    _ optional: NativeOriginalRescueJourneyState?, custody: NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    guard let state = optional else {
      return !NativeOriginalRescueJourneySave.hasClaims(commander)
    }
    guard sourceIdentitiesValid(state, commander: commander) else { return false }
    guard historyValid(state, custody: custody, commander: commander) else { return false }
    for index in commander.scriptState.instances.indices {
      if commander.scriptState.instances.keys[index] == state.mission {
        return missionValid(
          commander.scriptState.instances.values[index], state: state,
          custody: custody, commander: commander)
      }
    }
    return false
  }

  @inline(never)
  private static func sourceIdentitiesValid(
    _ state: NativeOriginalRescueJourneyState, commander: borrowing Commander
  ) -> Bool {
    var missions: [UUID] = []
    for index in commander.scriptState.instances.indices {
      let matches: Bool
      if commander.scriptState.instances.values[index].definition == stateID {
        matches = true
      } else {
        matches = commander.scriptState.instances.values[index].digest == digest
      }
      if matches { missions.append(commander.scriptState.instances.keys[index]) }
    }
    var boards: [String] = []
    for (key, board) in commander.contracts.boards {
      if (board.provider == "l337.contract" && board.id == boardID) || board.digest == digest
        || board.group == stateID
      {
        boards.append(key)
      }
    }
    return missions == [state.mission] && boards == [digest + "/" + boardID + "/" + source.key]
  }

  @inline(never)
  private static func historyValid(
    _ state: NativeOriginalRescueJourneyState, custody: NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    guard state.owner == custody.owner, state.owner == commander.equipmentOwnerID,
      state.definition.valid, state.version == "1.0.0", state.digest == digest,
      state.registeredAt.isFinite, state.registeredAt >= 0,
      state.registeredAt <= commander.flightSimulation.physicalTime,
      sourceMatches(state.registration),
      NativeStationPassengerJourney.historicalDock(state.registration, commander: commander),
      state.reservedBerths.count == 2, Set(state.reservedBerths).count == 2,
      state.captures.count <= 2, Set(state.captures.map(\.alias)).count == state.captures.count,
      Set(state.captures.map(\.operation)).count == state.captures.count,
      state.offers.count <= 64, state.replies.count <= 256,
      custody.admissions.filter({ $0.person.rescue != nil }).count == state.captures.count
    else { return false }
    let heldCapsules = custody.heldPods.filter { $0.person.rescue != nil }
    guard heldCapsules.count <= 1 else { return false }
    for (index, capture) in state.captures.enumerated() {
      if index > 0 {
        let previous = state.captures[index - 1]
        guard let ordinal = aliases.prefix(2).firstIndex(of: previous.alias),
          let care = state.care(for: state.references[ordinal], custody: custody),
          care.revision < capture.revision, care.physicalTime <= capture.physicalTime
        else { return false }
      }
      guard aliases.prefix(2).contains(capture.alias),
        captureValid(capture, state: state, commander: commander)
      else { return false }
    }
    if let record = state.record {
      guard record.alias == "emergency-record", state.boarding != nil,
        record.physicalTime >= state.boarding!.physicalTime,
        record.revision >= state.boarding!.revision, record.revision <= custody.revision,
        captureValid(record, state: state, commander: commander),
        !state.captures.contains(where: {
          $0.operation == record.operation || $0.actor == record.actor
        })
      else { return false }
    }
    if let receipt = state.recordReception {
      guard recordReceiptValid(receipt, state: state, commander: commander) else { return false }
    }
    guard careHistoryValid(state, custody: custody, commander: commander) else { return false }
    guard consentHistoryValid(state, custody: custody, commander: commander) else { return false }
    return accommodationValid(state, custody: custody, commander: commander)
  }

  @inline(never)
  static func captureValid(
    _ capture: NativeOriginalRescueCapture, state: NativeOriginalRescueJourneyState,
    commander: borrowing Commander
  ) -> Bool {
    guard
      let authority = try? captureAuthority(
        operation: capture.operation, actor: capture.actor, tool: capture.tool,
        inventory: capture.inventoryRevision, epoch: capture.epoch, time: capture.physicalTime),
      capture.authority == authority,
      capture.owner == state.owner, capture.carrier == state.carrier,
      capture.logicalActor == actorIdentity(mission: state.mission, alias: capture.alias),
      capture.actor.system == SystemIdentity(galaxy: 0, system: 85), capture.actor.entity > 1,
      capture.actor.visit >= state.registration.actor.visit,
      capture.actor.visit <= commander.flightSimulation.visit,
      capture.actor.entity < commander.flightSimulation.nextActor,
      capture.collector.system == capture.actor.system,
      capture.collector.visit == capture.actor.visit, capture.collector.entity == 0,
      capture.physicalTime.isFinite, capture.physicalTime >= state.registeredAt,
      capture.physicalTime <= commander.flightSimulation.physicalTime,
      capture.inventoryRevision >= state.inventoryRevision,
      capture.tool.id != state.carrier,
      capture.tool.location
        == EquipmentRuntimeCatalog.purchaseLocation(
          .init(hullInstanceID: state.carrier, slot: .utility(.fuelScoops))),
      capture.tool.node.key == "Fuel Scoops"
    else { return false }
    guard captureToolValid(capture.tool, owner: state.owner, commander: commander) else {
      return false
    }
    for index in commander.scriptState.instances.indices {
      if commander.scriptState.instances.keys[index] == state.mission {
        return retainedCaptureValid(
          capture, mission: commander.scriptState.instances.values[index],
          nextSpawn: commander.flightSimulation.nextSpawn)
      }
    }
    return false
  }

  @inline(never)
  private static func captureToolValid(
    _ tool: EquipmentPurchaseItem, owner expectedOwner: UUID, commander: borrowing Commander
  ) -> Bool {
    let item = tool.id
    let node = tool.node
    switch tool.provenance {
    case .paid(let owner, let transaction):
      guard let history = commander.savedEquipmentPurchaseHistory, history.owner == expectedOwner
      else {
        return false
      }
      return owner == expectedOwner
        && history.paid.contains {
          $0.owner == owner && $0.transaction == transaction
            && $0.binding.request.newItem == item && $0.node == node
        }
    case .legacyUnknown:
      guard let history = commander.savedEquipmentPurchaseHistory, history.owner == expectedOwner
      else {
        return false
      }
      return history.legacy.contains {
        $0.owner == expectedOwner && $0.source.id == item && $0.source.node == node
      }
    case .standard, .grant, .recovered, .reward, .earned, .xyzzy, .missionIssue:
      // These supported native acquisitions do not create paid entitlements. The private
      // same-turn seal captured the actual fitted purchaseSnapshot item; captureValid
      // already joined its complete provenance/fitting hash, owner, carrier, tool and actor.
      // Keeping that historical witness permits later real storage, refitting or removal.
      return true
    }
  }

  @inline(never)
  private static func retainedCaptureValid(
    _ capture: NativeOriginalRescueCapture, mission: borrowing ScriptInstance, nextSpawn: UInt64
  ) -> Bool {
    for index in mission.ownedEncounters.indices {
      if mission.ownedEncounters.keys[index] == encounterID {
        for actorIndex in mission.ownedEncounters.values[index].actors.indices {
          if mission.ownedEncounters.values[index].actors.keys[actorIndex] == capture.alias {
            return capturedActorValid(
              mission.ownedEncounters.values[index].actors.values[actorIndex], capture: capture,
              nextSpawn: nextSpawn)
          }
        }
      }
    }
    return false
  }
  @inline(never)
  private static func capturedActorValid(
    _ actor: borrowing ScriptOwnedActor, capture: NativeOriginalRescueCapture, nextSpawn: UInt64
  ) -> Bool {
    guard actor.identity == capture.logicalActor, actor.presence == .outside,
      actor.body.energy > 0, actor.body.physical?.identity == capture.actor,
      actor.body.missionActorID == capture.logicalActor,
      actor.body.scriptNPC?.fit.definition.model == "catalogue:SH040",
      actor.body.scriptNPC?.fit.definition.scale == 1,
      actor.body.physical?.population == .mission,
      actor.body.physical?.spawnIdentity?.producer == .mission,
      actor.body.physical?.spawnIdentity?.system == capture.actor.system,
      actor.body.physical?.spawnIdentity?.visit == capture.actor.visit,
      let sequence = actor.body.physical?.spawnIdentity?.sequence,
      sequence > 0, sequence < nextSpawn
    else { return false }
    return true
  }

  @inline(never)
  private static func careHistoryValid(
    _ state: NativeOriginalRescueJourneyState, custody: NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    for reference in state.references {
      let transfers = custody.transfers.filter { $0.members.contains(reference) }
      guard transfers.count <= (state.boarding == nil ? 1 : 2) else { return false }
      for (index, receipt) in transfers.enumerated() {
        guard receipt.kind != .sale else { return false }
        if index == 0 && receipt.kind == .care {
          guard let dock = receipt.dock, sourceMatches(dock),
            state.boarding.map({ receipt.revision < $0.revision }) ?? true
          else { return false }
        } else {
          guard state.terminalOperation == receipt.operation else { return false }
          if receipt.kind == .care {
            guard let boarding = state.boarding, receipt.revision > boarding.revision,
              let dock = receipt.dock, sourceMatches(dock) || destinationMatches(dock)
            else { return false }
          }
        }
      }
    }
    return true
  }

  @inline(never)
  private static func consentHistoryValid(
    _ state: NativeOriginalRescueJourneyState, custody: NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    for (index, offer) in state.offers.enumerated() {
      guard offer.revision == UInt64(index + 1),
        offer.id == ScriptIdentity.uuid("original-rescue-offer-v1:\(state.operation):\(index + 1)"),
        sourceMatches(offer.dock),
        NativeStationPassengerJourney.historicalDock(offer.dock, commander: commander),
        offer.carrier == state.carrier, offer.collector.entity == 0,
        offer.collector.system == offer.dock.actor.system,
        offer.collector.visit == offer.dock.actor.visit,
        offer.destination == SystemIdentity(galaxy: 0, system: 241), offer.reach.valid,
        offer.path
          == (ScriptCourierGeneration.routes(origin: source, reach: offer.reach).contains([85, 241])
            ? [85, 241] : []),
        offer.berths.count <= 2, offer.physicalTime.isFinite,
        offer.physicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    for (index, reply) in state.replies.enumerated() {
      guard reply.sequence == UInt64(index + 1), reply.person.valid,
        reply.person.owner == state.owner,
        reply.request
          == .init(revision: 1, destination: .init(galaxy: 0, system: 241), intent: .passage),
        let offer = state.offers.first(where: { $0.id == reply.offer }),
        let care = state.care(for: .rescue(reply.person), custody: custody),
        care.operation == reply.careOperation, care.physicalTime <= reply.physicalTime,
        reply.physicalTime >= offer.physicalTime,
        reply.physicalTime <= commander.flightSimulation.physicalTime,
        NativeStationPassengerJourney.historicalDock(reply.dock, commander: commander),
        sourceMatches(reply.dock)
      else { return false }
      let fresh =
        reply.dock == offer.dock && reply.carrier == offer.carrier
        && reply.inventoryRevision == offer.inventoryRevision && reply.epoch == offer.epoch
      let eligible =
        offer.path == [85, 241] && offer.berths.count == 2
        && reply.berth?.id == state.reservedBerths[reply.person.ordinal]
        && reply.berth?.lifeSupportWorking == true && reply.berth?.humanoidCompatible == true
        && reply.berth?.use == .reserved(mission: state.mission, person: reply.person.id)
        && offer.berths.indices.contains(reply.person.ordinal)
        && offer.berths[reply.person.ordinal] == reply.berth
      guard reply.kind == (!fresh ? .withdraw : (eligible ? .accept : .refuse)) else {
        return false
      }
    }
    guard let boarding = state.boarding else { return true }
    guard boarding.berths == state.reservedBerths, boarding.replies.count == 2,
      Set(boarding.replies).count == 2, boarding.revision > 0,
      boarding.revision <= custody.revision,
      let offer = state.offers.first(where: { $0.id == boarding.offer }),
      boarding.dock == offer.dock, boarding.carrier == offer.carrier,
      boarding.collector == offer.collector, boarding.inventoryRevision == offer.inventoryRevision,
      boarding.epoch == offer.epoch, boarding.physicalTime >= offer.physicalTime,
      boarding.physicalTime <= commander.flightSimulation.physicalTime
    else { return false }
    for ordinal in 0..<2 {
      let index = boarding.replies[ordinal]
      guard state.replies.indices.contains(index),
        let identity = state.references[ordinal].rescue,
        state.replies[index].person == identity, state.replies[index].offer == offer.id,
        state.replies[index].kind == .accept,
        state.replies.lastIndex(where: { $0.person == identity && $0.offer == offer.id }) == index,
        let care = state.care(for: state.references[ordinal], custody: custody),
        care.revision < boarding.revision, care.physicalTime <= boarding.physicalTime
      else { return false }
    }
    return true
  }

  @inline(never)
  private static func accommodationValid(
    _ state: NativeOriginalRescueJourneyState, custody: NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    if state.terminalOperation != nil {
      for berth in commander.accommodation.ownedBerths {
        if case .nativePerson(let person) = berth.use, state.references.contains(person) {
          return false
        }
        if case .reserved(let mission, _) = berth.use, mission == state.mission { return false }
      }
      return true
    }
    for ordinal in 0..<2 {
      guard
        let berth = commander.accommodation.ownedBerths.first(where: {
          $0.id == state.reservedBerths[ordinal]
        }),
        let identity = state.references[ordinal].rescue,
        commander.hullInstanceID == state.carrier,
        commander.accommodation.fitted.contains(berth.id), berth.lifeSupportWorking,
        berth.humanoidCompatible
      else { return false }
      if state.boarding != nil {
        guard berth.use == .nativePerson(state.references[ordinal]) else { return false }
      } else {
        guard berth.use == .reserved(mission: state.mission, person: identity.id) else {
          return false
        }
      }
    }
    return true
  }

  @inline(never)
  private static func missionValid(
    _ mission: borrowing ScriptInstance, state: borrowing NativeOriginalRescueJourneyState,
    custody: borrowing NativePeopleCustodyState, commander: borrowing Commander
  ) -> Bool {
    guard mission.definition == stateID, mission.digest == digest, mission.version == state.version,
      mission.contract != nil
    else { return false }
    // The synchronous immutable projection stays present across these borrowed phases.
    // No header, marker, board or terminal temporary is reserved beneath generic validation.
    guard genericMissionContractValid(mission.contract!) else { return false }
    guard nativeMissionContractValid(mission.contract!, mission: mission.id) else { return false }
    guard mission.payloads.isEmpty, mission.gearIssues.isEmpty, mission.choiceReceipts.isEmpty,
      mission.timers.isEmpty, Set(mission.ownedEncounters.keys).isSubset(of: [encounterID])
    else { return false }
    guard recordCaptureMarkerValid(mission, state: state) else { return false }
    guard sourceCohortValid(mission, state: state) else { return false }
    guard boardValid(commander: commander, state: state, offer: mission.contract!.offer) else {
      return false
    }
    return missionTerminalValid(mission, state: state, custody: custody, commander: commander)
  }

  @inline(never)
  private static func genericMissionContractValid(_ job: borrowing ScriptContractJob) -> Bool {
    job.valid
  }

  @inline(never)
  private static func nativeMissionContractValid(
    _ job: borrowing ScriptContractJob, mission: UUID
  ) -> Bool {
    guard job.provider == "l337.contract",
      job.station == source, job.group == stateID, job.digest == digest,
      job.boardKey == digest + "/" + boardID + "/" + source.key,
      job.clock == .local, job.deadline == nil, job.offer.duration == 0,
      job.offer.destinationGalaxy == 0, job.offer.destinationSystem == 241,
      job.offer.reward == reward, job.offer.deposit == 0, job.offer.failureReward == 0,
      !job.offer.refundOnFailure,
      job.offer.parameters == .object(["original_rescue": .string(batch)]),
      mission == Game.contractJobIdentity(job.offer.id)
    else { return false }
    return true
  }

  @inline(never)
  private static func recordCaptureMarkerValid(
    _ mission: borrowing ScriptInstance, state: borrowing NativeOriginalRescueJourneyState
  ) -> Bool {
    // Culling and collection share actor presence; this independent native receipt keeps
    // deleting only the record capture from restoring its physical source.
    let recordReceipts = mission.receipts.filter { $0.hasPrefix(recordCaptureReceiptPrefix) }
    if let record = state.record {
      guard recordReceipts.count == 1,
        recordReceipts.contains(recordCaptureReceipt(record.operation))
      else { return false }
    } else if !recordReceipts.isEmpty {
      return false
    }
    return true
  }

  @inline(never)
  private static func missionTerminalValid(
    _ mission: borrowing ScriptInstance, state: borrowing NativeOriginalRescueJourneyState,
    custody: borrowing NativePeopleCustodyState, commander: borrowing Commander
  ) -> Bool {
    if let terminal = state.terminalOperation {
      guard !custody.held.contains(where: { $0.person.rescue != nil }) else { return false }
      guard let receipt = mission.completionReceipt,
        receipt.valid(for: mission, engine: commander.scriptState),
        receipt.causeKind == "mission.receipted"
      else { return false }
      if mission.outcome == .complete {
        guard let boarding = state.boarding,
          let transfer = custody.transfers.first(where: { $0.operation == terminal }),
          transfer.kind == .care, transfer.members.filter({ $0.rescue != nil }) == state.references,
          transfer.revision > boarding.revision, let dock = transfer.dock, destinationMatches(dock),
          let record = state.recordReception, record.operation == terminal, record.dock == dock,
          receipt.cause?.nativeMainDock == dock, receipt.committed.nativeMainDock == dock,
          mission.milestones == [0, 1], mission.contract?.settlementAmount == reward
        else { return false }
        return state.terminalDock == dock
      }
      guard [.failed, .abandoned].contains(mission.outcome),
        mission.contract?.settlementAmount == 0,
        mission.milestones == [0]
      else { return false }
      if mission.outcome == .failed {
        guard state.terminalDock == nil,
          let transfer = custody.transfers.first(where: { $0.operation == terminal }),
          transfer.kind == .loss || transfer.kind == .escape,
          transfer.members.contains(where: { $0.rescue != nil })
        else { return false }
      } else {
        guard let dock = state.terminalDock, sourceMatches(dock),
          NativeStationPassengerJourney.historicalDock(dock, commander: commander),
          receipt.cause?.nativeMainDock == dock, receipt.committed.nativeMainDock == dock
        else { return false }
        if state.record != nil {
          guard state.recordReception?.dock == dock, state.recordReception?.operation == terminal
          else { return false }
        }
      }
      return true
    }
    guard mission.outcome == .active, mission.completionReceipt == nil, mission.milestones == [0]
    else { return false }
    return true
  }
  @inline(never)
  private static func sourceCohortValid(
    _ mission: borrowing ScriptInstance, state: borrowing NativeOriginalRescueJourneyState
  ) -> Bool {
    if mission.ownedEncounters.isEmpty {
      guard state.captures.isEmpty else { return false }
      return state.record == nil
    }
    guard mission.ownedEncounters.count == 1 else { return false }
    for index in mission.ownedEncounters.indices {
      return sourceEncounterValid(mission.ownedEncounters.values[index], state: state)
    }
    return false
  }
  @inline(never)
  private static func sourceEncounterValid(
    _ encounter: borrowing ScriptOwnedEncounter, state: borrowing NativeOriginalRescueJourneyState
  ) -> Bool {
    guard encounter.id == encounterID, encounter.galaxy == 0, encounter.system == 85,
      Set(encounter.actors.keys) == Set(aliases)
    else { return false }
    for index in encounter.actors.indices {
      guard sourceActorValid(encounter.actors.values[index], state: state) else { return false }
    }
    return true
  }
  @inline(never)
  private static func sourceActorValid(
    _ actor: borrowing ScriptOwnedActor, state: borrowing NativeOriginalRescueJourneyState
  ) -> Bool {
    guard let modelHash = geometryHash else { return false }
    guard case .some = actor.body.scriptNPC else { return false }
    // One stable optional projection supplies the actual fit to both validation phases.
    return sourceActorFitValid(
      actor.body.scriptNPC!.fit, actor: actor, state: state, modelHash: modelHash)
  }

  @inline(never)
  private static func sourceActorFitValid(
    _ fit: borrowing ScriptNPCFit, actor: borrowing ScriptOwnedActor,
    state: borrowing NativeOriginalRescueJourneyState, modelHash: String
  ) -> Bool {
    guard fit.models == ["catalogue:SH040": modelHash],
      aliases.contains(actor.alias),
      actor.identity == actorIdentity(mission: state.mission, alias: actor.alias),
      actor.body.missionInstanceID == state.mission, actor.body.missionActorID == actor.identity,
      actor.transitLocation == nil, ![.inTransit, .arrivalPending].contains(actor.presence),
      actor.body.hull == .cobra,
      actor.body.physical?.empSource == nil, actor.body.physical?.empCrewPod == nil,
      actor.body.physical?.payload == nil
    else { return false }
    return sourceActorDefinitionValid(fit.definition, alias: actor.alias)
  }

  @inline(never)
  private static func sourceActorDefinitionValid(
    _ definition: borrowing ScriptNPCDefinition, alias: String
  ) -> Bool {
    guard
      definition.id
        == (alias == "emergency-record"
          ? "original-emergency-record" : "original-living-capsule"),
      definition.model == "catalogue:SH040", definition.scale == 1, definition.energy == 70,
      definition.recharge == 0, definition.speed == 0, definition.acceleration == 0,
      definition.pitch == 0, definition.yaw == 0, definition.roll == 0,
      definition.missiles == 0, definition.fuel == 0, definition.ecm == false,
      definition.bounty == 0, definition.drive == nil,
      definition.lasers?.isEmpty ?? true, definition.components?.isEmpty ?? true
    else { return false }
    return true
  }
  @inline(never)
  private static func boardValid(
    commander: borrowing Commander, state: borrowing NativeOriginalRescueJourneyState,
    offer: borrowing ScriptContractOffer
  ) -> Bool {
    let key = digest + "/" + boardID + "/" + source.key
    for index in commander.contracts.boards.indices {
      if commander.contracts.boards.keys[index] == key {
        return boardHeaderValid(
          commander.contracts.boards.values[index], state: state, offer: offer)
      }
    }
    return false
  }
  @inline(never)
  private static func boardHeaderValid(
    _ board: borrowing ScriptContractBoard, state: borrowing NativeOriginalRescueJourneyState,
    offer: borrowing ScriptContractOffer
  ) -> Bool {
    guard board.valid, board.provider == "l337.contract", board.id == boardID,
      board.group == stateID,
      board.version == state.version, board.digest == digest, board.station == source,
      board.revision == 0, board.seed == 0, board.clock == .local, board.period == 3600
    else { return false }
    return acceptedOfferMatches(board, offer: offer, mission: state.mission)
  }
  @inline(never)
  private static func acceptedOfferMatches(
    _ board: borrowing ScriptContractBoard, offer: borrowing ScriptContractOffer, mission: UUID
  ) -> Bool {
    var accepted = copy offer
    accepted.status = .accepted(mission)
    return board.offers == [accepted]
  }

}

enum NativeOriginalRescueJourneySave {
  static let version = 45
  static let alienVersion = 46
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    contains(schema)
      ? (schema == alienVersion
        ? NativeOrbitalOutlookJourneySave.alienVersion
        : NativeOrbitalOutlookJourneySave.version) : schema
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if commander.nativePeople?.originalRescue != nil { return true }
    if NativeOriginalRescueJourney.hasMission(commander) { return true }
    for berth in commander.accommodation.ownedBerths {
      if case .nativePerson(let person) = berth.use,
        person.rescue != nil
      {
        return true
      }
    }
    for person in commander.nativePeople?.admissions ?? [] {
      if person.person.rescue != nil { return true }
    }
    for receipt in commander.nativePeople?.transfers ?? [] {
      if receipt.members.contains(where: { $0.rescue != nil }) {
        return true
      }
    }
    for board in commander.contracts.boards.values {
      if (board.provider == "l337.contract" && board.id == "custody-rescue")
        || board.digest == NativeOriginalRescueJourney.digest
        || board.group == NativeOriginalRescueJourney.stateID
      {
        return true
      }
    }
    return false
  }
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard let custody = commander.nativePeople else { return !hasClaims(commander) }
    guard
      NativeOriginalRescueJourney.validSource(
        custody.originalRescue, custody: custody, commander: commander),
      NativeStationPassengerJourney.berthsValid(commander)
    else { return false }
    return true
  }
}

extension NativeOriginalRescueJourneySave {
  /// Inspect only the native header/mission/contract paths, never authored script data keys.
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      root["originalRescue"] == nil, root["nativePerson"] == nil
    else { throw SaveError.invalidCommander }
    let allowed = contains(schema)
    func records(_ raw: Any?) throws -> [[String: Any]] {
      guard let raw else { return [] }
      let values: [Any]
      if let map = raw as? [String: Any], map.count <= 128 {
        values = Array(map.values)
      } else if let pairs = raw as? [Any], pairs.count % 2 == 0, pairs.count <= 256 {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      return try values.map { value in
        guard let object = value as? [String: Any] else { throw SaveError.invalidCommander }
        return object
      }
    }
    func missions(_ object: [String: Any], embedded: Bool) throws {
      for instance in try records(object["instances"]) {
        guard instance["originalRescue"] == nil, instance["nativePerson"] == nil else {
          throw SaveError.invalidCommander
        }
        if instance["definition"] as? String == NativeOriginalRescueJourney.stateID {
          guard allowed, !embedded else { throw SaveError.invalidCommander }
        }
      }
    }
    func contracts(_ object: [String: Any], embedded: Bool) throws {
      for board in try records(object["boards"]) {
        guard board["originalRescue"] == nil, board["nativePerson"] == nil else {
          throw SaveError.invalidCommander
        }
        if board["provider"] as? String == "l337.contract",
          board["id"] as? String == "custody-rescue"
        {
          guard allowed, !embedded else { throw SaveError.invalidCommander }
        }
      }
    }
    if part != .commander {
      guard root["savedNativePeopleCustody"] == nil, root["savedAccommodation"] == nil else {
        throw SaveError.invalidCommander
      }
      if part == .missions {
        try missions(root, embedded: false)
      } else {
        try contracts(root, embedded: false)
      }
      return
    }
    let custody = root["savedNativePeopleCustody"] as? [String: Any] ?? [:]
    let hasLeaf = custody.keys.contains("originalRescue")
    if hasLeaf {
      guard allowed, let raw = custody["originalRescue"] as? [String: Any] else {
        throw SaveError.invalidCommander
      }
      guard let captures = raw["captures"] as? [[String: Any]], captures.count <= 2,
        let berths = raw["reservedBerths"] as? [Any], berths.count == 2,
        let offers = raw["offers"] as? [[String: Any]], offers.count <= 64,
        let replies = raw["replies"] as? [Any], replies.count <= 256
      else { throw SaveError.invalidCommander }
      guard let definition = raw["definition"] as? [String: Any],
        let people = definition["people"] as? [Any], people.count == 2
      else { throw SaveError.invalidCommander }
      if let boarding = raw["boarding"] as? [String: Any] {
        guard let replies = boarding["replies"] as? [Any], replies.count == 2,
          let berths = boarding["berths"] as? [Any], berths.count == 2
        else { throw SaveError.invalidCommander }
      }
      for offer in offers {
        guard let slots = offer["berths"] as? [Any], slots.count <= 2,
          let path = offer["path"] as? [Any], path.count <= 2
        else { throw SaveError.invalidCommander }
      }
      let bytes = try JSONSerialization.data(withJSONObject: raw)
      let leaf = try JSONDecoder().decode(NativeOriginalRescueJourneyState.self, from: bytes)
      let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(leaf))
      guard (raw as NSDictionary).isEqual(canonical) else { throw SaveError.invalidCommander }
    }
    func reference(_ raw: Any?) throws {
      guard let object = raw as? [String: Any], object.keys.contains("rescue") else { return }
      let bytes = try JSONSerialization.data(withJSONObject: object)
      let person = try JSONDecoder().decode(NativePersonReference.self, from: bytes)
      guard person.rescue != nil else { throw SaveError.invalidCommander }
      guard allowed, hasLeaf, Set(object.keys) == ["rescue"], person.rescue?.valid == true,
        (object as NSDictionary).isEqual(
          try JSONSerialization.jsonObject(with: JSONEncoder().encode(person)))
      else { throw SaveError.invalidCommander }
    }
    if let admissions = custody["admissions"] as? [[String: Any]] {
      guard admissions.count <= NativePeopleCustodyState.maximumPeople else {
        throw SaveError.invalidCommander
      }
      for admission in admissions {
        guard admission["originalRescue"] == nil else { throw SaveError.invalidCommander }
        try reference(admission["person"])
      }
    }
    if let transfers = custody["transfers"] as? [[String: Any]] {
      guard transfers.count <= NativePeopleCustodyState.maximumPeople else {
        throw SaveError.invalidCommander
      }
      for transfer in transfers {
        guard transfer["originalRescue"] == nil else { throw SaveError.invalidCommander }
        for person in transfer["members"] as? [Any] ?? [] { try reference(person) }
      }
    }
    let accommodation = root["savedAccommodation"] as? [String: Any] ?? [:]
    guard accommodation["originalRescue"] == nil else { throw SaveError.invalidCommander }
    for berth in accommodation["ownedBerths"] as? [[String: Any]] ?? [] {
      guard berth["originalRescue"] == nil else { throw SaveError.invalidCommander }
      if let use = berth["use"] as? [String: Any], use.keys.contains("nativePerson") {
        let decoded = try JSONDecoder().decode(
          PassengerPlaceUse.self, from: JSONSerialization.data(withJSONObject: use))
        guard case .nativePerson(let person) = decoded else { throw SaveError.invalidCommander }
        guard person.rescue != nil else { continue }
        guard allowed, hasLeaf, Set(use.keys) == ["nativePerson"], person.rescue?.valid == true,
          (use as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
    if let embedded = root["savedScriptState"] as? [String: Any] {
      try missions(embedded, embedded: true)
    }
    if let embedded = root["savedContracts"] as? [String: Any] {
      try contracts(embedded, embedded: true)
    }
  }
}
