import Foundation

enum NativeOriginalSurveySave {
  static let version = 49
  static let alienVersion = 50
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    contains(schema)
      ? (schema == alienVersion
        ? NativeOriginalEvacuationSave.alienVersion : NativeOriginalEvacuationSave.version)
      : schema
  }

  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    for instance in commander.scriptState.instances.values {
      if instance.definition == NativeOriginalSurvey.stateID
        || instance.digest == NativeOriginalSurvey.digest || instance.savedOriginalSurvey != nil
      {
        return true
      }
    }
    for board in commander.contracts.boards.values {
      if board.group == NativeOriginalSurvey.stateID || board.digest == NativeOriginalSurvey.digest
        || (board.provider == "l337.contract" && board.id == NativeOriginalSurvey.boardID)
      {
        return true
      }
    }
    return false
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    var count = 0
    for instance in commander.scriptState.instances.values {
      guard instance.definition == NativeOriginalSurvey.stateID else {
        if instance.savedOriginalSurvey != nil || instance.digest == NativeOriginalSurvey.digest {
          return false
        }
        continue
      }
      count += 1
      guard count == 1, let source = instance.savedOriginalSurvey,
        validState(source, instance: instance, commander: commander)
      else { return false }
    }
    let boards = commander.contracts.boards.values.filter {
      $0.group == NativeOriginalSurvey.stateID || $0.digest == NativeOriginalSurvey.digest
        || ($0.provider == "l337.contract" && $0.id == NativeOriginalSurvey.boardID)
    }
    return boards.count == count
  }

  @inline(never)
  private static func validState(
    _ source: borrowing NativeOriginalSurveyState, instance: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard source.definition.valid, source.owner == commander.equipmentOwnerID,
      source.version == "1.0.0", source.version == instance.version,
      source.digest == instance.digest, source.digest == NativeOriginalSurvey.digest,
      let permission = source.permission, permission.mission == instance.id,
      permission.operation
        == ScriptIdentity.uuid("native-survey-permission-v1:\(source.owner):\(instance.id)"),
      permission.dock.valid, NativeOriginalSurvey.sourceMatches(permission.dock),
      permission.dock.commanderOwner == source.owner,
      let stations = commander.nativeStations,
      stations.mainStations.contains(permission.dock.station),
      permission.dock.sequence < stations.nextMainDockSequence,
      permission.dock.actor.visit <= commander.flightSimulation.visit,
      permission.reach.valid, permission.reach.revision == "elite-canonical-native-reach-v2",
      permission.path == [7, 185, 7],
      NativeOriginalSurvey.route(reach: permission.reach) == permission.path,
      permission.collector.entity == 0,
      permission.collector.system == permission.dock.actor.system,
      permission.collector.visit == permission.dock.actor.visit,
      permission.physicalTime.isFinite, permission.physicalTime >= 0,
      permission.physicalTime <= commander.flightSimulation.physicalTime,
      permission.dock.calendarSeconds <= commander.scriptState.calendarSeconds,
      NativeOriginalSurvey.readingsValid(source, commander: commander),
      let job = instance.contract, job.provider == "l337.contract",
      job.digest == source.digest, job.group == NativeOriginalSurvey.stateID,
      job.version == source.version,
      job.boardKey == source.digest + "/consented-survey/" + NativeOriginalSurvey.source.key,
      job.boardRevision == 0, job.clock == .local,
      job.station == NativeOriginalSurvey.source,
      job.offer.reward == NativeOriginalSurvey.reward, job.offer.deposit == 0,
      job.offer.duration == 0, job.deadline == nil,
      job.offer.destinationGalaxy == 0, job.offer.destinationSystem == 7,
      job.offer.failureReward == 0, !job.offer.refundOnFailure,
      job.offer.key == source.definition.batch,
      job.offer.id
        == ScriptIdentity.uuid(
          "contract-offer-v1:\(job.boardKey):0:\(source.definition.batch)"),
      Game.contractJobIdentity(job.offer.id) == instance.id,
      let board = commander.contracts.boards[job.boardKey],
      board.id == NativeOriginalSurvey.boardID, board.group == NativeOriginalSurvey.stateID,
      board.provider == "l337.contract", board.version == source.version,
      board.station == NativeOriginalSurvey.source, board.revision == 0,
      board.digest == instance.digest, board.offers.count == 1,
      board.offers.first?.id == job.offer.id,
      board.offers.first?.status == .accepted(instance.id)
    else { return false }
    let expected = Set(0...source.readings.count)
    if instance.outcome == .active {
      guard source.terminalOperation == nil, source.terminalDock == nil else { return false }
      return instance.milestones == expected
    }
    guard
      source.terminalOperation
        == ScriptIdentity.uuid(
          "native-survey-terminal-v1:\(permission.operation):\(instance.outcome.rawValue)"),
      let dock = source.terminalDock, dock.valid, NativeOriginalSurvey.sourceMatches(dock),
      dock.commanderOwner == source.owner, stations.mainStations.contains(dock.station),
      dock.sequence < stations.nextMainDockSequence,
      dock.calendarSeconds <= commander.scriptState.calendarSeconds,
      let receipt = instance.completionReceipt, receipt.instance == instance.id,
      receipt.definition == NativeOriginalSurvey.stateID, receipt.digest == source.digest,
      receipt.outcome == instance.outcome, receipt.cause?.nativeMainDock == dock,
      receipt.committed.nativeMainDock == dock
    else { return false }
    switch instance.outcome {
    case .complete:
      guard NativeOriginalSurvey.returnReady(source, dock: dock),
        instance.milestones == Set(0...4)
      else { return false }
      return job.settlementAmount == NativeOriginalSurvey.reward
    case .abandoned:
      guard instance.milestones == expected else { return false }
      return job.settlementAmount == 0
    case .active, .failed: return false
    }
  }

  static func validateFields(
    _ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      !root.keys.contains("savedOriginalSurvey"), !root.keys.contains("originalSurvey")
    else { throw SaveError.invalidCommander }
    func records(_ raw: Any?) throws -> [[String: Any]] {
      guard let raw else { return [] }
      let values: [Any]
      if let map = raw as? [String: Any], map.count <= 128 {
        values = Array(map.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count % 2 == 0 {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      return try values.map {
        guard let object = $0 as? [String: Any] else { throw SaveError.invalidCommander }
        return object
      }
    }
    func missions(_ object: [String: Any], embedded: Bool) throws {
      for instance in try records(object["instances"]) {
        let own = instance["definition"] as? String == NativeOriginalSurvey.stateID
        let pinned = instance["digest"] as? String == NativeOriginalSurvey.digest
        guard own == pinned else { throw SaveError.invalidCommander }
        let leaf = instance.keys.contains("savedOriginalSurvey")
        guard own == leaf else { throw SaveError.invalidCommander }
        if own {
          guard contains(schema), !embedded,
            let raw = instance["savedOriginalSurvey"] as? [String: Any],
            let readings = raw["readings"] as? [Any], readings.count <= 3,
            let authorities = raw["authorities"] as? [Any], authorities.count == readings.count
          else { throw SaveError.invalidCommander }
          let data = try JSONSerialization.data(withJSONObject: raw)
          let state = try JSONDecoder().decode(NativeOriginalSurveyState.self, from: data)
          let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
          guard (raw as NSDictionary).isEqual(canonical) else { throw SaveError.invalidCommander }
        }
      }
    }
    func boards(_ object: [String: Any], embedded: Bool) throws {
      for board in try records(object["boards"]) {
        if board["digest"] as? String == NativeOriginalSurvey.digest
          || board["group"] as? String == NativeOriginalSurvey.stateID
          || (board["provider"] as? String == "l337.contract"
            && board["id"] as? String == NativeOriginalSurvey.boardID)
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
