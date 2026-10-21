import Foundation

enum ScriptProcurementGeneration {
  static func plans(
    pack: ScriptPack, commander: Commander, origin: ContractStationIdentity,
    revision: Int64, seed: UInt64
  ) throws -> [ScriptProcurementPlan] {
    try ScriptPackLibrary.validateProcurement(pack.manifest)
    guard let declaration = pack.manifest.procurement, let owner = commander.equipmentOwnerID,
      let board = pack.manifest.board
    else { throw MissionPackError("Procurement requires a current native owner and provider.") }
    let reach = ScriptCourierReach(commander)
    let paths = ScriptCourierGeneration.routes(origin: origin, reach: reach)
    let candidates = (0..<3).map { row in
      ScriptProcurementPlan.candidatePaths(
        paths, galaxy: origin.galaxy, row: row, generatorRevision: declaration.generatorRevision)
    }
    guard candidates.allSatisfy({ !$0.isEmpty }) else {
      throw MissionPackError("No native procurement route fits every required tier's deadline.")
    }
    let initial = Game.pledgeProfileSeed(seed)
    var state = initial
    let draws = (0..<6).map { _ in ScriptCourierGeneration.next(&state) }
    return (0..<3).map { row in
      let paths = candidates[row]
      let index = ScriptProcurementPlan.index(draws[row * 2], count: paths.count)
      return .init(
        profile: declaration.profile, generatorRevision: declaration.generatorRevision,
        variant: declaration.variant,
        content: .init(
          provider: pack.manifest.id, version: pack.manifest.version, digest: pack.digest,
          stateID: pack.manifest.stateID, boardID: board.id), owner: owner,
        boardRevision: revision, seedHex: String(format: "%016llx", seed), origin: origin,
        reach: reach, row: row, initialState: initial, draws: draws, finalState: state,
        routeIndex: index,
        commodityIndex: ScriptProcurementPlan.index(draws[row * 2 + 1], count: 3),
        path: paths[index],
        calendarLowerBoundSeconds: ScriptProcurementPlan.calendarCost(
          paths[index], galaxy: origin.galaxy),
        template: declaration.collectionTemplate, deliveryContact: declaration.deliveryContact,
        abandonContact: declaration.abandonContact,
        capabilities: pack.manifest.capabilities.sorted())
    }
  }
  static func value(_ plans: [ScriptProcurementPlan]) throws -> ScriptValue {
    .array(
      try plans.map { plan in
        guard let parameters = plan.parameters else { throw SaveError.invalidCommander }
        _ = try ScriptWire.encode([parameters], limit: 4096)
        return .object([
          "key": .string(plan.key), "difficulty": .integer(Int64(plan.difficulty)),
          "commodity": .integer(Int64(plan.commodity!.rawValue)),
          "quantity": .integer(Int64(plan.quantity)),
          "destination": .integer(Int64(plan.path.last!)),
          "reward": .integer(Int64(plan.reward)), "duration": .number(plan.duration),
          "parameters": parameters,
        ])
      })
  }
  static func valid(_ board: ScriptContractBoard) -> Bool {
    guard board.courierGeneration == nil, board.clock == .missionCalendar, board.period == 3600,
      board.group == board.provider + "/" + ScriptProcurementPlan.group,
      board.offers.count == 3,
      (1...160).contains(board.title.count), board.offers.allSatisfy(\.valid),
      Set(board.offers.map(\.id)).count == board.offers.count,
      Set(board.offers.map(\.key)).count == board.offers.count,
      let seed = Game.pledgeBoardSeed(board.cacheKey, revision: board.revision),
      seed == board.seed
    else { return false }
    var first: ScriptProcurementPlan?
    for (row, offer) in board.offers.enumerated() {
      guard let plan = ScriptProcurementPlan.read(offer.parameters), plan.matches(offer),
        plan.row == row, plan.origin == board.station, plan.boardRevision == board.revision,
        plan.content.provider == board.provider, plan.content.version == board.version,
        plan.content.digest == board.digest, plan.content.boardID == board.id,
        plan.seedHex == String(format: "%016llx", seed),
        offer.id
          == ScriptIdentity.uuid(
            "contract-offer-v1:\(board.cacheKey):\(board.revision):\(offer.key)")
      else { return false }
      if let first {
        guard first.owner == plan.owner, first.reach == plan.reach, first.draws == plan.draws,
          first.content == plan.content, first.declaration == plan.declaration,
          first.capabilities == plan.capabilities
        else { return false }
      } else {
        first = plan
      }
    }
    return true
  }
  static func valid(_ job: ScriptContractJob) -> Bool {
    guard job.offer.valid, let plan = ScriptProcurementPlan.read(job.offer.parameters),
      plan.matches(job.offer),
      job.clock == .missionCalendar, job.deadlinePolicy == .inclusiveConfirmation,
      job.station == plan.origin, job.boardRevision == plan.boardRevision,
      job.provider == plan.content.provider, job.version == plan.content.version,
      job.digest == plan.content.digest,
      job.boardKey == plan.content.digest + "/" + plan.content.boardID + "/" + plan.origin.key,
      job.group == job.provider + "/" + ScriptProcurementPlan.group,
      let seed = Game.pledgeBoardSeed(job.boardKey, revision: job.boardRevision),
      plan.seedHex == String(format: "%016llx", seed),
      plan.calendarLowerBoundSeconds < plan.duration,
      job.offer.id
        == ScriptIdentity.uuid(
          "contract-offer-v1:\(job.boardKey):\(job.boardRevision):\(job.offer.key)")
    else { return false }
    guard job.offer.status == .available, job.acceptedAt.isFinite,
      (0...1e12).contains(job.acceptedAt), job.acceptedAt <= 1e12 - plan.duration,
      job.deadline == job.acceptedAt + plan.duration,
      job.settlementOutcome != .active
    else { return false }
    if !job.settled {
      return job.settlementOutcome == nil && job.settlementAmount == nil && job.settledAt == nil
    }
    guard let outcome = job.settlementOutcome, let amount = job.settlementAmount,
      let at = job.settledAt, at.isFinite, at >= job.acceptedAt, at <= 1e12,
      amount == (outcome == .complete ? plan.reward : 0),
      outcome != .complete || at <= job.deadline!
    else { return false }
    return true
  }
}
