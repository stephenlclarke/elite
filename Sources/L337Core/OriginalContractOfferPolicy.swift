import Foundation

/// The cached board is a durable floor; retained native jobs advance it without using time.
/// Future pruning must retain this floor before removing a board or its job evidence.
enum OriginalContractOfferPolicy {
  static let maximumRevision: Int64 = 1_000_000_000_000

  static func advanced(_ revision: Int64, by amount: Int64) throws -> Int64 {
    guard revision >= 0, revision <= maximumRevision - amount else {
      throw MissionPackError("The Original offer generation limit has been reached.")
    }
    return revision + amount
  }

  @inline(never)
  static func revision(
    pack: borrowing ScriptPack, station: ContractStationIdentity,
    commander: borrowing Commander
  ) throws -> Int64 {
    guard let definition = pack.manifest.board else { throw SaveError.invalidCommander }
    let key = pack.digest + "/" + definition.id + "/" + station.key
    let group = pack.manifest.id + "/" + (definition.exclusiveGroup ?? definition.id)
    let floor = try cachedRevision(
      key: key, group: group, definition: definition, pack: pack, station: station,
      commander: commander)
    return try retainedRevision(
      floor: floor, key: key, group: group, definition: definition, pack: pack, station: station,
      commander: commander)
  }

  // Keep retained-job buffers out of the frame that recursively validates cached offers.
  @inline(never)
  private static func cachedRevision(
    key: String, group: String, definition: borrowing ScriptBoardDefinition,
    pack: borrowing ScriptPack, station: ContractStationIdentity, commander: borrowing Commander
  ) throws -> Int64 {
    if let board = commander.contracts.boards[key] {
      guard board.valid, board.provider == pack.manifest.id,
        board.version == pack.manifest.version, board.digest == pack.digest,
        board.station == station, board.id == definition.id, board.group == group,
        board.clock == definition.clock, board.period == definition.period
      else { throw SaveError.invalidCommander }
      return board.revision
    }
    return 0
  }

  @inline(never)
  private static func retainedRevision(
    floor: Int64, key: String, group: String, definition: borrowing ScriptBoardDefinition,
    pack: borrowing ScriptPack, station: ContractStationIdentity, commander: borrowing Commander
  ) throws -> Int64 {
    var floor = floor
    for state in commander.scriptState.instances.values {
      guard let job = state.contract, job.boardKey == key,
        state.definition == pack.manifest.stateID, state.digest == pack.digest,
        state.version == pack.manifest.version, state.id == Game.contractJobIdentity(job.offer.id),
        job.provider == pack.manifest.id, job.digest == pack.digest,
        job.version == pack.manifest.version, job.station == station,
        job.group == group, job.clock == definition.clock, job.valid,
        job.offer.id
          == ScriptIdentity.uuid(
            "contract-offer-v1:\(key):\(job.boardRevision):\(job.offer.key)"),
        commander.freightStateValid(state), commander.procurementStateValid(state)
      else { continue }
      let increment: Int64
      if state.outcome == .active, !job.settled {
        increment = 1
      } else if state.outcome != .active, job.settled,
        job.settlementOutcome == state.outcome
      {
        increment = 2
      } else {
        continue
      }
      floor = max(floor, try advanced(job.boardRevision, by: increment))
    }
    return floor
  }
}

extension Game {
  func contractRevision(_ definition: ScriptBoardDefinition, pack: ScriptPack) throws -> Int64 {
    if pack.manifest.stateID == OriginalMutualContribution.stateID {
      guard OriginalMutualContribution.validManifest(pack.manifest),
        definition.id == pack.manifest.board?.id, definition.clock == .local,
        definition.period == 3600
      else { throw SaveError.invalidCommander }
      return contractRevision(definition)
    }
    if OriginalServiceReservationPolicy.isContractDefinition(pack.manifest.stateID) {
      return try OriginalContractOfferPolicy.revision(
        pack: pack, station: contractStation, commander: commander)
    }
    return contractRevision(definition)
  }

  func contractRevision(_ board: ScriptContractBoard) throws -> Int64 {
    if !OriginalServiceReservationPolicy.isContractDefinition(board.provider + "/") {
      return Int64(floor(commander.scriptState.clock(board.clock) / board.period))
    }
    guard
      let pack = scriptPacks.first(where: {
        $0.digest == board.digest && $0.manifest.id == board.provider
          && $0.manifest.version == board.version && $0.manifest.board?.id == board.id
      }), let definition = pack.manifest.board
    else { throw SaveError.invalidCommander }
    if pack.manifest.stateID == OriginalMutualContribution.stateID {
      guard OriginalMutualContribution.validManifest(pack.manifest),
        board.clock == definition.clock, board.period == definition.period
      else { throw SaveError.invalidCommander }
      return contractRevision(definition)
    }
    return try contractRevision(definition, pack: pack)
  }
}
