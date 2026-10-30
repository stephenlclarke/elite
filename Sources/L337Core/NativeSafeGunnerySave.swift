import Foundation

enum NativeSafeGunnerySave {
  static let version = 127
  static let alienVersion = 128
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func marked(_ instance: ScriptInstance) -> Bool {
    instance.savedSafeGunnery != nil || instance.digest == NativeSafeGunnery.digest
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    let instances = commander.scriptState.instances
    if instances.values.contains(where: marked) { return true }
    let boards = commander.contracts.boards
    return boards.values.contains { $0.digest == NativeSafeGunnery.digest }
  }
  static func shapeValid(_ instance: ScriptInstance) -> Bool {
    guard instance.definition == NativeSafeGunnery.stateID,
      instance.digest == NativeSafeGunnery.digest, instance.version == NativeSafeGunnery.version,
      let state = instance.savedSafeGunnery, state.valid,
      state.permission.mission == instance.id,
      (state.terminalOutcome ?? .active) == instance.outcome,
      instance.choiceReceipts[NativePracticeSource.consentGroup] == state.permission.consent,
      instance.payloads.isEmpty, instance.gearIssues.isEmpty, instance.ownedEncounters.isEmpty,
      instance.timers.isEmpty, instance.savedFlightReception == nil
    else { return false }
    if let progress = state.progress {
      guard let provider = instance.savedNativePractice, progress.matches(provider) else {
        return false
      }
    } else if instance.savedNativePractice != nil {
      return false
    }
    let milestones: Set<Int> = Set(
      [0] + (state.progress == nil ? [] : [1])
        + (state.progress?.threeDistinctHits == true ? [2] : [])
        + (state.quietSeconds == NativeSafeGunnery.quietSeconds && state.ordinaryHit == nil
          ? [3] : [])
        + (instance.outcome == .complete ? [4] : []))
    return instance.milestones == milestones
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let instances = commander.scriptState.instances
    let boardCache = commander.contracts.boards
    let physicalTime = commander.flightSimulation.physicalTime
    let nextEmission = commander.flightSimulation.nextEmission
    let nextIncident = commander.flightSimulation.nextIncident
    let nextActor = commander.flightSimulation.nextActor
    let own = instances.values.filter(marked)
    guard own.count <= 128, own.filter({ $0.outcome == .active }).count <= 1 else { return false }
    var attempts: Set<Int> = []
    for instance in own {
      guard shapeValid(instance), let state = instance.savedSafeGunnery,
        let owner = commander.equipmentOwnerID, state.permission.owner == owner,
        state.permission.consent.valid(for: instance, engine: commander.scriptState),
        NativeFlightReceptionSave.historicalDock(state.permission.dock, commander: commander),
        state.permission.acceptedAt <= physicalTime,
        state.lastDischargeEmission < nextEmission,
        state.lastFrameTime.map({ $0 <= physicalTime }) ?? true,
        state.ordinaryHit.map({
          $0.id < nextIncident
            && $0.origin.emissionID < nextEmission
        }) ?? true,
        state.pendingProjectiles.values.allSatisfy({
          $0.emissionID < nextEmission
            && ($0.ordnance.map { $0.entity < nextActor } ?? false)
        }),
        let job = instance.contract, job.provider == "l337.training",
        job.digest == instance.digest, job.version == instance.version,
        job.group == instance.definition,
        job.station.galaxy == 0, job.station.system == 7,
        job.station.stationClass == "main-orbital",
        job.boardRevision == 0, job.clock == .local, job.deadline == nil,
        job.offer.reward == 0, job.offer.deposit == 0, job.offer.failureReward == 0,
        !job.offer.refundOnFailure, job.offer.duration == 0,
        job.offer.destinationGalaxy == 0, job.offer.destinationSystem == 7,
        job.offer.parameters == .object([:]), job.offer.key.hasPrefix("safe-gunnery-"),
        let suffix = job.offer.key.split(separator: "-").last, let attempt = Int(suffix),
        (0..<128).contains(attempt), attempts.insert(attempt).inserted,
        job.boardKey == instance.digest + "/" + NativeSafeGunnery.boardID + "/" + job.station.key,
        job.offer.id == ScriptIdentity.uuid("contract-offer-v1:\(job.boardKey):0:\(job.offer.key)"),
        Game.contractJobIdentity(job.offer.id) == instance.id,
        let board = boardCache[job.boardKey],
        board.offers.first(where: { $0.id == job.offer.id })?.status == .accepted(instance.id)
      else { return false }
      if let receipt = instance.completionReceipt {
        guard receipt.valid(for: instance, engine: commander.scriptState),
          receipt.causeKind == "mission.receipted", job.settlementAmount == 0
        else { return false }
      } else if instance.outcome != .active {
        return false
      }
      if instance.outcome == .complete {
        guard let dock = state.terminalDock, dock.station == state.permission.dock.station,
          dock.sequence > state.permission.dock.sequence,
          NativeFlightReceptionSave.historicalDock(dock, commander: commander),
          instance.completionReceipt?.cause?.nativeMainDock == dock,
          instance.completionReceipt?.committed.nativeMainDock == dock,
          let progress = state.progress,
          dock.actor.visit >= progress.original.permission.player.visit
        else { return false }
      }
    }
    guard attempts == Set(0..<own.count) else { return false }
    let boards = boardCache.filter { $0.value.digest == NativeSafeGunnery.digest }
    for (key, board) in boards {
      let matching = own.filter { $0.contract?.boardKey == key }
      guard !matching.isEmpty, board.cacheKey == key, board.id == NativeSafeGunnery.boardID,
        board.provider == "l337.training", board.version == NativeSafeGunnery.version,
        board.group == NativeSafeGunnery.stateID, board.revision == 0, board.seed == 0,
        board.clock == .local, board.period == 3600,
        board.offers.count == matching.count,
        Set(board.offers.map(\.id)) == Set(matching.compactMap { $0.contract?.offer.id })
      else { return false }
    }
    guard Set(own.compactMap { $0.contract?.boardKey }) == Set(boards.keys) else { return false }
    let completed = own.filter { $0.outcome == .complete }
    if !completed.isEmpty {
      guard let award = commander.scriptState.savedClueJournal?.awards[NativeSafeGunnery.stateID],
        award.clueID == "safe-gunnery-family-trace",
        completed.contains(where: { $0.completionReceipt == award.completion })
      else { return false }
    }
    return true
  }

  static func publicationVersion(lesson: Bool, practice: Bool, crewLog: Bool, alien: Bool) -> Int? {
    guard lesson else {
      return NativePracticeSave.publicationVersion(
        practice: practice, crewLog: crewLog, alien: alien)
    }
    return max(
      alien ? alienVersion : version,
      NativePracticeSave.publicationVersion(practice: practice, crewLog: crewLog, alien: alien)
        ?? (crewLog
          ? (alien ? NativeInductionCrewLogSave.alienVersion : NativeInductionCrewLogSave.version)
          : 0))
  }

  static func validateArchiveFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?, alien: Bool
  ) throws {
    try validateFields(data, part: part, schema: schema)
    try NativePracticeSave.validateArchiveFields(
      data, part: part, schema: contains(schema) ? (alien ? 122 : 121) : schema, alien: alien)
  }

  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedSafeGunnery"), !root.keys.contains("safeGunnery")
    else { throw SaveError.invalidCommander }
    func instances(_ raw: Any?, embedded: Bool) throws {
      guard let raw else { return }
      let entries: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        entries = Array(dictionary.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
        entries = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      for entry in entries {
        guard let instance = entry as? [String: Any], !instance.keys.contains("safeGunnery") else {
          throw SaveError.invalidCommander
        }
        let pinned = instance["digest"] as? String == NativeSafeGunnery.digest
        let leaf = instance["savedSafeGunnery"]
        guard pinned == (leaf != nil) else { throw SaveError.invalidCommander }
        if let leaf {
          guard contains(schema) || NativeC01SurveyorSave.contains(schema), !embedded,
            instance["definition"] as? String == NativeSafeGunnery.stateID,
            let object = leaf as? [String: Any]
          else { throw SaveError.invalidCommander }
          if let pending = object["pendingProjectiles"] {
            if let dictionary = pending as? [String: Any] {
              guard dictionary.count <= PopulationClass.projectile.maximum else {
                throw SaveError.invalidCommander
              }
            } else if let pairs = pending as? [Any] {
              guard pairs.count <= PopulationClass.projectile.maximum * 2,
                pairs.count.isMultiple(of: 2)
              else { throw SaveError.invalidCommander }
            } else {
              throw SaveError.invalidCommander
            }
          }
          if let progress = object["progress"] {
            guard let progress = progress as? [String: Any],
              let hits = progress["hits"] as? [Any], hits.count <= 3,
              let original = progress["original"] as? [String: Any],
              let beacons = original["beacons"] as? [Any], beacons.count == 3,
              let originalHits = original["hits"] as? [Any], originalHits.isEmpty
            else { throw SaveError.invalidCommander }
          }
          let decoded = try JSONDecoder().decode(
            NativeSafeGunneryState.self, from: JSONSerialization.data(withJSONObject: object))
          guard decoded.valid,
            (object as NSDictionary).isEqual(
              try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
          else { throw SaveError.invalidCommander }
        }
      }
    }
    switch part {
    case .missions: try instances(root["instances"], embedded: false)
    case .commander:
      if let state = root["savedScriptState"] as? [String: Any] {
        try instances(state["instances"], embedded: true)
      }
    case .contracts: break
    }
  }
}
