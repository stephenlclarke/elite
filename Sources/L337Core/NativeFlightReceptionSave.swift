import Foundation

enum NativeFlightReceptionSave {
  static let version = 59
  static let alienVersion = 60
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? WayfarerFieldReliefSave.alienVersion : WayfarerFieldReliefSave.version
  }
  private static let fitNodes = Set(EquipmentRuntimeCatalog.graph.nodes.map(\.id))

  static func marked(_ instance: ScriptInstance) -> Bool {
    instance.definition == NativeFlightReception.stateID
      || instance.digest == NativeFlightReception.digest
      || instance.savedFlightReception != nil
  }
  static func marked(_ board: ScriptContractBoard) -> Bool {
    board.group == NativeFlightReception.stateID || board.digest == NativeFlightReception.digest
      || (board.provider == "l337.training" && board.id == NativeFlightReception.boardID)
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    for instance in commander.scriptState.instances.values where marked(instance) { return true }
    for board in commander.contracts.boards.values where marked(board) { return true }
    return false
  }
  static func historicalDock(_ dock: NativeMainStationDockReceipt, commander: borrowing Commander)
    -> Bool
  {
    guard dock.valid, dock.commanderOwner == commander.equipmentOwnerID,
      let world = commander.nativeStations, world.mainStations.contains(dock.station),
      dock.sequence < world.nextMainDockSequence,
      dock.actor.visit <= commander.flightSimulation.visit,
      dock.calendarSeconds <= commander.scriptState.calendarSeconds
    else { return false }
    return true
  }

  @inline(never)
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let own = commander.scriptState.instances.values.filter { marked($0) }
    let boards = commander.contracts.boards.filter { marked($0.value) }
    guard own.count <= 128, own.filter({ $0.outcome == .active }).count <= 1 else { return false }
    var attempts: Set<Int> = []
    for instance in own {
      guard valid(instance, commander: commander), let contract = instance.contract,
        let suffix = contract.offer.key.split(separator: "-").last, let attempt = Int(suffix),
        (0..<128).contains(attempt), attempts.insert(attempt).inserted
      else { return false }
    }
    guard attempts == Set(0..<own.count) else { return false }
    for (key, board) in boards {
      let matching = own.filter { $0.contract?.boardKey == key }
      guard !matching.isEmpty, board.cacheKey == key, board.id == NativeFlightReception.boardID,
        board.provider == "l337.training", board.digest == NativeFlightReception.digest,
        board.version == NativeFlightReception.version,
        board.group == NativeFlightReception.stateID,
        board.revision == 0, board.seed == 0, board.clock == .local, board.period == 3600,
        board.offers.count <= 16, board.offers.count == matching.count,
        Set(board.offers.map(\.id)) == Set(matching.compactMap { $0.contract?.offer.id })
      else { return false }
    }
    guard Set(own.compactMap { $0.contract?.boardKey }) == Set(boards.keys) else { return false }
    let complete = own.filter { $0.outcome == .complete }
    if !complete.isEmpty {
      guard
        let award = commander.scriptState.savedClueJournal?.awards[NativeFlightReception.stateID],
        award.clueID == "flight-reception-family-trace",
        complete.contains(where: { $0.completionReceipt == award.completion })
      else { return false }
    }
    return true
  }

  @inline(never)
  private static func valid(_ instance: ScriptInstance, commander: borrowing Commander) -> Bool {
    guard instance.definition == NativeFlightReception.stateID,
      instance.digest == NativeFlightReception.digest,
      instance.version == NativeFlightReception.version,
      let state = instance.savedFlightReception, let job = instance.contract,
      instance.payloads.isEmpty, instance.gearIssues.isEmpty, instance.ownedEncounters.isEmpty,
      instance.timers.isEmpty,
      job.provider == "l337.training", job.version == instance.version,
      job.digest == instance.digest,
      job.group == instance.definition, job.clock == .local, job.deadline == nil,
      job.offer.key.hasPrefix("flight-reception-"), job.offer.reward == 0, job.offer.deposit == 0,
      job.offer.failureReward == 0, !job.offer.refundOnFailure, job.offer.duration == 0,
      job.boardRevision == 0,
      job.boardKey == instance.digest + "/" + NativeFlightReception.boardID + "/" + job.station.key,
      job.offer.id == ScriptIdentity.uuid("contract-offer-v1:\(job.boardKey):0:\(job.offer.key)"),
      Game.contractJobIdentity(job.offer.id) == instance.id,
      let board = commander.contracts.boards[job.boardKey], board.station == job.station,
      board.offers.first(where: { $0.id == job.offer.id })?.status == .accepted(instance.id)
    else { return false }
    let permission = state.permission
    guard permission.mission == instance.id, permission.owner == commander.equipmentOwnerID,
      permission.dock.commanderOwner == permission.owner,
      historicalDock(permission.dock, commander: commander),
      permission.dock.station.system.galaxy == job.station.galaxy,
      permission.dock.station.system.system == job.station.system,
      job.station.stationClass == "main-orbital", job.station.system < 256,
      job.offer.destinationGalaxy == job.station.galaxy,
      job.offer.destinationSystem == job.station.system,
      permission.inventoryRevision < UInt64.max, !permission.fit.isEmpty,
      permission.fit.count <= OwnedEquipmentInventory.maximumCount + 1,
      Set(permission.fit.map(\.id)).count == permission.fit.count,
      permission.fit.allSatisfy({
        fitNodes.contains($0.node)
          && ($0.location == nil || $0.location?.hull == permission.carrier)
      }),
      permission.operation
        == (try? NativeFlightReception.permissionOperation(
          mission: instance.id, owner: permission.owner, carrier: permission.carrier,
          revision: permission.inventoryRevision, dock: permission.dock, fit: permission.fit))
    else { return false }
    var milestones: Set<Int> = [0]
    if let reading = state.reading {
      guard NativeFlightReception.readingValid(reading), reading.first.mission == instance.id,
        reading.first.permission == permission.operation, reading.first.owner == permission.owner,
        reading.first.carrier == permission.carrier,
        reading.first.inventoryRevision == permission.inventoryRevision,
        reading.first.station == permission.dock.station,
        reading.last.time <= commander.flightSimulation.physicalTime,
        reading.first.player.visit > permission.dock.actor.visit,
        reading.last.player.visit <= commander.flightSimulation.visit
      else { return false }
      milestones.insert(1)
    }
    if instance.outcome == .active {
      return state.terminalOperation == nil && state.terminalOutcome == nil
        && state.terminalDock == nil && instance.completionReceipt == nil && !job.settled
        && instance.milestones == milestones
    }
    guard [.complete, .abandoned, .failed].contains(instance.outcome),
      state.terminalOutcome == instance.outcome,
      state.terminalOperation
        == ScriptIdentity.uuid(
          "flight-reception-terminal-v1:\(permission.operation):\(instance.outcome.rawValue)"),
      job.settled, job.settlementAmount == 0, job.settlementOutcome == instance.outcome,
      let receipt = instance.completionReceipt,
      receipt.instance == instance.id, receipt.definition == instance.definition,
      receipt.version == instance.version, receipt.digest == instance.digest,
      receipt.outcome == instance.outcome, receipt.revision == instance.revision,
      receipt.causeKind == "mission.receipted", receipt.settlementAmount == 0
    else { return false }
    if instance.outcome == .failed {
      guard state.terminalDock == nil else { return false }
    } else {
      guard let dock = state.terminalDock, historicalDock(dock, commander: commander),
        dock.station == permission.dock.station, receipt.cause?.nativeMainDock == dock,
        receipt.committed.nativeMainDock == dock
      else { return false }
      if instance.outcome == .complete {
        guard NativeFlightReception.returnReady(state, dock: dock) else { return false }
        milestones.insert(2)
      }
    }
    return instance.milestones == milestones && receipt.milestones == milestones.sorted()
  }
}

extension NativeFlightReceptionSave {
  static func validateFields(_ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      !root.keys.contains("savedFlightReception"), !root.keys.contains("flightReception")
    else { throw SaveError.invalidCommander }
    func records(_ raw: Any?) throws -> [[String: Any]] {
      guard let raw else { return [] }
      let values: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        values = Array(dictionary.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count % 2 == 0 {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      return try values.map {
        guard let value = $0 as? [String: Any] else { throw SaveError.invalidCommander }
        return value
      }
    }
    func missions(_ object: [String: Any], embedded: Bool) throws {
      for instance in try records(object["instances"]) {
        let own = instance["definition"] as? String == NativeFlightReception.stateID
        let pinned = instance["digest"] as? String == NativeFlightReception.digest
        let hasLeaf = instance.keys.contains("savedFlightReception")
        guard own == pinned, own == hasLeaf else { throw SaveError.invalidCommander }
        if own {
          guard contains(schema), !embedded,
            let leaf = instance["savedFlightReception"] as? [String: Any],
            let permission = leaf["permission"] as? [String: Any],
            let fit = permission["fit"] as? [Any],
            fit.count <= OwnedEquipmentInventory.maximumCount + 1
          else { throw SaveError.invalidCommander }
          let encoded = try JSONSerialization.data(withJSONObject: leaf)
          let decoded = try JSONDecoder().decode(NativeFlightReceptionState.self, from: encoded)
          guard
            (leaf as NSDictionary).isEqual(
              try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
          else { throw SaveError.invalidCommander }
        }
      }
    }
    func boards(_ object: [String: Any], embedded: Bool) throws {
      for board in try records(object["boards"]) {
        if board["group"] as? String == NativeFlightReception.stateID
          || board["digest"] as? String == NativeFlightReception.digest
          || (board["provider"] as? String == "l337.training"
            && board["id"] as? String == NativeFlightReception.boardID)
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
