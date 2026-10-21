import Foundation

enum WayfarerFieldReliefSave {
  static let version = 57
  static let alienVersion = 58
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  // G1 composition point: if G12 is included, map 57/58 to its 55/56 first.
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? WayfarerRecordRecoverySave.alienVersion : WayfarerRecordRecoverySave.version
  }
  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard manifest.fieldRelief != nil || manifest.stateID == WayfarerFieldRelief.stateID else {
      return
    }
    guard manifest.stateID == WayfarerFieldRelief.stateID, manifest.version == "1.0.0",
      manifest.fieldRelief?.valid == true,
      manifest.capabilities.contains(WayfarerFieldRelief.capability),
      manifest.mission.milestones.count == 3, manifest.board == nil,
      manifest.coldChain == nil, manifest.repairLoop == nil, manifest.courier == nil,
      manifest.freight == nil, manifest.procurement == nil, manifest.providerContract == nil,
      manifest.pledge == nil, manifest.stationJourney == nil, manifest.orbitalOutlook == nil,
      manifest.originalSurvey == nil, manifest.recordRecovery == nil,
      manifest.identifiedSalvage == nil, manifest.originalRescue == nil,
      manifest.orbitalEvacuation == nil, manifest.trial == nil,
      (manifest.equipment ?? []).isEmpty, (manifest.encounters ?? []).isEmpty,
      (manifest.passengerParties ?? []).isEmpty, (manifest.worldJobs ?? []).isEmpty,
      (manifest.children ?? []).isEmpty, (manifest.receiptRequirements ?? []).isEmpty,
      (manifest.answerRequirements ?? []).isEmpty, (manifest.collections ?? []).isEmpty,
      (manifest.books ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.npcs ?? []).isEmpty, (manifest.modules ?? []).isEmpty,
      (manifest.dialogs ?? []).isEmpty,
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.mission.requiredDestructionEncounters?.isEmpty ?? true,
      manifest.mission.requiredPassengerParties?.isEmpty ?? true,
      manifest.mission.requiredEquipmentReturns?.isEmpty ?? true,
      manifest.mission.requiredChoiceGroups?.isEmpty ?? true,
      manifest.mission.requiredBooks?.isEmpty ?? true,
      manifest.mission.requiredCollections?.isEmpty ?? true
    else { throw MissionPackError("Invalid ordinary native field-relief declaration.") }
  }

  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.nativeUtility?.consignments.isEmpty == false
      || commander.scriptState.instances.values.contains(where: WayfarerFieldRelief.marked)
      || commander.contracts.boards.values.contains(where: marked)
  }
  private static func marked(_ board: ScriptContractBoard) -> Bool {
    board.group == WayfarerFieldRelief.stateID || board.digest == WayfarerFieldRelief.digest
      || (board.provider == "l337.wayfarer-service" && board.id == WayfarerFieldRelief.boardID)
  }
  static func engineValid(_ engine: borrowing ScriptEngineState) -> Bool {
    var count = 0
    for state in engine.instances.values where WayfarerFieldRelief.marked(state) {
      count += 1
      guard count <= 2, state.definition == WayfarerFieldRelief.stateID,
        state.digest == WayfarerFieldRelief.digest, state.version == "1.0.0",
        let leaf = state.savedFieldRelief, leaf.accepted.valid,
        leaf.accepted.revision == 0, leaf.acceptanceSequence > 0,
        leaf.acceptanceSequence <= engine.nextEvent,
        state.hasAcknowledged(leaf.acceptanceSequence),
        state.id == WayfarerFieldRelief.instance(leaf.job.id),
        state.payloads.isEmpty, state.gearIssues.isEmpty, state.ownedEncounters.isEmpty,
        state.timers.isEmpty, state.dialogue == nil, state.revision > 0,
        state.contract?.valid == true
      else { return false }
    }
    return OriginalServiceReservationPolicy.valid(engine)
  }

  @inline(never)
  static func validateClaims(
    _ commander: borrowing Commander, requireRecordedLoss: Bool = false
  ) -> Bool {
    let engine = commander.scriptState
    let missions = engine.instances.values.filter { WayfarerFieldRelief.marked($0) }
    let boards = commander.contracts.boards.values.filter { marked($0) }
    let jobs = commander.nativeUtility?.consignments ?? []
    if jobs.isEmpty { return missions.isEmpty && boards.isEmpty }
    guard engineValid(engine), let utility = commander.nativeUtility,
      commander.nativeUtilityStateValid, missions.count == jobs.count, boards.count == 1,
      let board = boards.first, board.cacheKey == WayfarerFieldRelief.boardKey,
      board.id == WayfarerFieldRelief.boardID, board.provider == "l337.wayfarer-service",
      board.version == "1.0.0", board.digest == WayfarerFieldRelief.digest,
      board.group == WayfarerFieldRelief.stateID, board.station == WayfarerFieldRelief.source,
      board.revision == 0, board.seed == 0, board.clock == .local, board.period == 3600,
      board.offers.count == jobs.count, board.valid
    else { return false }
    let targetDead = commander.nativeStations?.ledger.records.first(where: {
      $0.identity == utility.target
    })?.tombstone != nil
    for job in jobs {
      guard let state = engine.instances[WayfarerFieldRelief.instance(job.id)],
        let leaf = state.savedFieldRelief,
        leaf.owner == utility.owner, leaf.owner == commander.equipmentOwnerID,
        let dock = leaf.accepted.nativeMainDock, dock.station == utility.source,
        NativeUtilitySourceContact(dock) == job.source,
        dock.commanderOwner == utility.owner, dock.valid,
        leaf.accepted.galaxy == 0, leaf.accepted.system == 7,
        leaf.accepted.docked, leaf.accepted.mainStation,
        leaf.accepted.localSeconds <= engine.localSeconds,
        leaf.accepted.flightSeconds <= engine.flightSeconds,
        leaf.accepted.calendarSeconds <= engine.calendarSeconds,
        leaf.accepted.transitSeconds <= engine.transitSeconds,
        let contract = state.contract, contract.boardKey == board.cacheKey,
        contract.provider == board.provider, contract.version == board.version,
        contract.digest == board.digest, contract.station == board.station,
        contract.boardRevision == 0, contract.group == board.group, contract.clock == .local,
        contract.acceptedAt == leaf.accepted.localSeconds, contract.deadline == nil,
        contract.deadlinePolicy == nil, contract.offer.id == WayfarerFieldRelief.offer(job.id),
        contract.offer.key == job.id.uuidString.lowercased(),
        contract.offer.reward == job.rewardTenths, contract.offer.deposit == 0,
        contract.offer.failureReward == 0, !contract.offer.refundOnFailure,
        contract.offer.duration == 0, contract.offer.parameters == .object([:]),
        contract.offer.destinationGalaxy == 0, contract.offer.destinationSystem == 237,
        board.offers.contains(where: {
          var accepted = contract.offer
          accepted.status = .accepted(state.id)
          return $0 == accepted
        }),
        joinedJob(leaf, native: job, targetDead: targetDead),
        stateValid(state, job: job, targetDead: targetDead, engine: engine,
                   requireRecordedLoss: requireRecordedLoss)
      else { return false }
    }
    return true
  }

  private static func joinedJob(
    _ leaf: WayfarerFieldReliefCustody, native: NativeUtilityConsignment, targetDead: Bool
  ) -> Bool {
    if leaf.job == native { return true }
    // Only an already failed, still-held original may subsequently return unpaid.
    guard leaf.terminalReason == "targetDestroyed", targetDead,
      leaf.job.phase == .held, native.phase == .returned, native.returned != nil else {
      return false
    }
    var historical = native
    historical.phase = .held
    historical.returned = nil
    return historical == leaf.job
  }

  private static func stateValid(
    _ state: borrowing ScriptInstance, job: NativeUtilityConsignment, targetDead: Bool,
    engine: borrowing ScriptEngineState, requireRecordedLoss: Bool
  ) -> Bool {
    guard let leaf = state.savedFieldRelief, let contract = state.contract else { return false }
    let milestones: Set<Int> = job.installation == nil ? [0] : [0, 1]
    if state.outcome == .active {
      return (job.phase == .held || job.phase == .installed)
        && leaf.terminalReason == nil && state.completionReceipt == nil && !contract.settled
        && state.milestones == milestones && (!requireRecordedLoss || !targetDead)
    }
    guard contract.settled, contract.settlementOutcome == state.outcome,
      let receipt = state.completionReceipt, receipt.valid(for: state, engine: engine),
      receipt.cause != nil, receipt.sequence > leaf.acceptanceSequence,
      receipt.committed.localSeconds >= leaf.accepted.localSeconds
    else { return false }
    switch leaf.terminalReason {
    case "received":
      guard state.outcome == .complete, job.phase == .received,
        let reception = job.reception, let installation = job.installation,
        reception.installation == installation.operation,
        state.milestones == [0, 1, 2], contract.settlementAmount == job.rewardTenths,
        receipt.causeKind == "dialogue.confirmed",
        let facts = receipt.cause?.nativeStation,
        facts.receipt.station == NativeUtilityState.target(owner: leaf.owner),
        NativeUtilityStationContact(facts.receipt) == reception.contact,
        receipt.committed.nativeStation == facts,
        let award = engine.savedClueJournal?.awards[WayfarerFieldRelief.stateID],
        award.clueID == "exchange-service-field-relief",
        let first = engine.instances[award.completion.instance],
        first.savedFieldRelief?.terminalReason == "received", first.outcome == .complete,
        first.completionReceipt == award.completion
      else { return false }
      return true
    case "returned":
      return state.outcome == .abandoned && job.phase == .returned
        && contract.settlementAmount == 0 && state.milestones == [0]
        && receipt.causeKind == "mission.receipted"
        && receipt.cause?.nativeMainDock.map {
          $0.station == leaf.accepted.nativeMainDock?.station
            && NativeUtilitySourceContact($0) == job.returned
        } == true
        && receipt.committed.nativeMainDock == receipt.cause?.nativeMainDock
    case "escape", "shipDestroyed":
      return state.outcome == .failed && job.phase == .lost
        && job.loss?.cause.rawValue == leaf.terminalReason
        && contract.settlementAmount == 0 && state.milestones == [0]
        && receipt.causeKind == "mission.receipted"
    case "targetDestroyed":
      return state.outcome == .failed && targetDead && job.reception == nil && job.loss == nil
        && [.held, .installed, .returned].contains(job.phase)
        && contract.settlementAmount == 0 && state.milestones == milestones
        && receipt.causeKind == "mission.receipted"
    default: return false
    }
  }
}

extension WayfarerFieldReliefSave {
  /// Native JSON containers only; Lua data stays opaque. Canonical roundtrips close nested keys.
  static func validateFields(_ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      !root.keys.contains("savedFieldRelief"), !root.keys.contains("fieldRelief")
    else { throw SaveError.invalidCommander }
    func records(_ raw: Any?) throws -> [[String: Any]] {
      guard let raw else { return [] }
      let values: [Any]
      if let map = raw as? [String: Any], map.count <= 128 {
        values = Array(map.values)
      } else if let pairs = raw as? [Any], pairs.count % 2 == 0, pairs.count <= 256 {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else { throw SaveError.invalidCommander }
      return try values.map {
        guard let object = $0 as? [String: Any] else { throw SaveError.invalidCommander }
        return object
      }
    }
    func rejectLeaf(_ object: [String: Any]) throws {
      guard !object.keys.contains("savedFieldRelief"), !object.keys.contains("fieldRelief") else {
        throw SaveError.invalidCommander
      }
    }
    func missions(_ object: [String: Any], embedded: Bool) throws {
      for instance in try records(object["instances"]) {
        guard !instance.keys.contains("fieldRelief") else { throw SaveError.invalidCommander }
        if let contract = instance["contract"] as? [String: Any] {
          try rejectLeaf(contract)
          if let offer = contract["offer"] as? [String: Any] { try rejectLeaf(offer) }
        }
        let own = instance["definition"] as? String == WayfarerFieldRelief.stateID
        let pinned = instance["digest"] as? String == WayfarerFieldRelief.digest
        let hasLeaf = instance.keys.contains("savedFieldRelief")
        guard own == pinned, own == hasLeaf else { throw SaveError.invalidCommander }
        if own {
          guard contains(schema), !embedded,
            let leaf = instance["savedFieldRelief"] as? [String: Any],
            let job = leaf["job"] as? [String: Any],
            let originals = job["originalUnits"] as? [Any], originals.count == 4,
            let route = job["route"] as? [Any], (2...256).contains(route.count)
          else { throw SaveError.invalidCommander }
          let data = try JSONSerialization.data(withJSONObject: leaf)
          let decoded = try JSONDecoder().decode(WayfarerFieldReliefCustody.self, from: data)
          guard (leaf as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
          else { throw SaveError.invalidCommander }
        }
      }
    }
    func boards(_ object: [String: Any], embedded: Bool) throws {
      for board in try records(object["boards"]) {
        try rejectLeaf(board)
        if let offers = board["offers"] as? [[String: Any]] {
          for offer in offers { try rejectLeaf(offer) }
        }
        if board["group"] as? String == WayfarerFieldRelief.stateID
          || board["digest"] as? String == WayfarerFieldRelief.digest
          || (board["provider"] as? String == "l337.wayfarer-service"
              && board["id"] as? String == WayfarerFieldRelief.boardID)
        {
          guard contains(schema), !embedded else { throw SaveError.invalidCommander }
        }
      }
    }
    switch part {
    case .missions: try missions(root, embedded: false)
    case .contracts: try boards(root, embedded: false)
    case .commander:
      if let embedded = root["savedScriptState"] as? [String: Any] {
        try missions(embedded, embedded: true)
      }
      if let embedded = root["savedContracts"] as? [String: Any] {
        try boards(embedded, embedded: true)
      }
    }
  }
}
