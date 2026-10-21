import CryptoKit
import Foundation

private enum ContractAcceptancePreflight: Sendable {
  case alreadyAccepted(UUID)
  case ready(PreparedContractAcceptance)
}

private struct PreparedContractAcceptance: Sendable {
  let key: String
  let index: Int
  let pack: ScriptPack
  let board: ScriptContractBoard
  let offer: ScriptContractOffer
  let job: ScriptContractJob
  let instanceID: UUID
  let pledgeAdmission: ScriptPledgeAdmission?
  let courierAdmission: ScriptCourierAdmission?
}

extension Game {
  var contractStation: ContractStationIdentity {
    .init(galaxy: commander.galaxy, system: commander.system, stationClass: "main-orbital")
  }
  func contractRevision(_ board: ScriptBoardDefinition) -> Int64 {
    Int64(floor(commander.scriptState.clock(board.clock) / board.period))
  }
  mutating func ensureContractBoard(_ pack: ScriptPack) throws -> String {
    try ScriptPackLibrary.validateCourier(pack.manifest)
    if pack.manifest.courier != nil { ensureMissionCalendar() }
    resolveCourierTerminals()
    guard docked, dockedAtMainStation, !paused, let definition = pack.manifest.board,
      scriptUnavailable(pack) == nil,
      [.local, .flight, .calendar, .missionCalendar].contains(definition.clock)
    else {
      throw MissionPackError("This station has no available contract provider for this pack.")
    }
    if pack.manifest.pledge != nil || pack.manifest.courier != nil, commander.system >= 256 {
      throw MissionPackError("Station Aid pledges do not support this synthetic host site.")
    }
    let key = pack.digest + "/" + definition.id + "/" + contractStation.key
    let revision = contractRevision(definition)
    if commander.contracts.boards[key]?.revision == revision { return key }
    guard commander.contracts.boards[key] != nil || commander.contracts.boards.count < 128 else {
      throw MissionPackError("The saved contract board limit has been reached.")
    }
    let seedBytes = Array(SHA256.hash(data: Data("contract-board-v1:\(key):\(revision)".utf8)))
    var seed = seedBytes.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    let initialSeed = seed
    var draws: [ScriptValue] = []
    for _ in 0..<64 {
      seed = seed &* 6_364_136_223_846_793_005 &+ 1
      draws.append(.integer(Int64(seed >> 32)))
    }
    let courierGeneration = try pack.manifest.courier.map { _ in
      try ScriptCourierGeneration(origin: contractStation, commander: commander, seed: initialSeed)
    }
    var world = scriptSnapshot.object ?? [:]
    if let declaration = pack.manifest.courier, let courierGeneration {
      world["courier_plan"] = courierGeneration.plan(declaration)
    }
    world["station_id"] = .string(contractStation.key)
    world["board_revision"] = .integer(revision)
    world["board_seed_u32"] = .integer(Int64(Self.pledgeProfileSeed(initialSeed)))
    world["offer_draws"] = .array(draws)
    world["destinations"] = .array(
      knownSystems.sorted { $0.id < $1.id }.filter { $0.id < 256 }.map {
        .object([
          "system": .integer(Int64($0.id)), "name": .string($0.name),
          "distance": .number(currentSystem.distance(to: $0)),
          "economy": .integer(Int64($0.economy)), "government": .integer(Int64($0.government)),
          "technology": .integer(Int64($0.technology)),
        ])
      })
    let result = try ScriptEvaluator.evaluate(
      source: pack.source, handler: definition.generator,
      event: .object(["kind": .string("board.generate")]), snapshot: .object(world),
      state: .object([:]))
    guard result.commands.isEmpty, let fields = result.data.object, Set(fields.keys) == ["offers"],
      let raw = fields["offers"]?.array, raw.count <= 16
    else {
      throw MissionPackError(
        "A board generator must return only a bounded offers list and no commands.")
    }
    var offers = try raw.map { try makeContractOffer($0, namespace: "\(key):\(revision)") }
    if let declaration = pack.manifest.courier, let courierGeneration {
      guard offers.count == 6 else {
        throw MissionPackError("Courier provider requires six native rows.")
      }
      for index in offers.indices {
        offers[index].courier = courierGeneration.terms(declaration, row: index)
        guard offers[index].courier?.matches(offers[index]) == true else {
          throw MissionPackError("Authored courier row changed native terms or order.")
        }
      }
    }
    let board = ScriptContractBoard(
      id: definition.id, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, title: definition.title, station: contractStation, revision: revision,
      seed: initialSeed, clock: definition.clock, period: definition.period,
      group: pack.manifest.id + "/" + (definition.exclusiveGroup ?? definition.id), offers: offers,
      courierGeneration: courierGeneration)
    guard board.valid else {
      throw MissionPackError("Generated contract offers are invalid or duplicated.")
    }
    if pack.manifest.pledge != nil {
      var checking = self
      checking.commander.contracts.boards[key] = board
      let expected = Set(
        ["credits", "food"].flatMap { variant in
          (1...3).map { variant + "-" + String($0) }
        })
      guard board.offers.count == 6, Set(board.offers.map(\.key)) == expected,
        board.offers.allSatisfy({ (try? checking.pledgePreview(board: key, offer: $0.id)) != nil })
      else {
        throw MissionPackError("A pledge provider must generate its six exact native offers.")
      }
    }
    // No generation side effects escape until the complete snapshot can be saved by the caller.
    commander.contracts.boards[key] = board
    return key
  }
  private func makeContractOffer(_ raw: ScriptValue, namespace: String) throws
    -> ScriptContractOffer
  {
    let keys: Set<String> = [
      "key", "title", "briefing", "destination_galaxy", "destination_system", "reward", "deposit",
      "failure_reward", "refund_on_failure", "duration", "parameters",
    ]
    guard let fields = raw.object, Set(fields.keys) == keys,
      let key = fields["key"]?.string, let title = fields["title"]?.string,
      let briefing = fields["briefing"]?.string,
      let galaxy = fields["destination_galaxy"]?.integer,
      let system = fields["destination_system"]?.integer,
      let reward = fields["reward"]?.integer, let deposit = fields["deposit"]?.integer,
      let failureReward = fields["failure_reward"]?.integer,
      case .bool(let refund) = fields["refund_on_failure"],
      let duration = fields["duration"]?.double, let parameters = fields["parameters"]
    else {
      throw MissionPackError("Generated contract terms are incomplete or have invalid types.")
    }
    let id = Self.contractNamespace("contract-offer-v1:\(namespace):\(key)")
    let offer = ScriptContractOffer(
      id: id, key: key, title: title, briefing: briefing,
      destinationGalaxy: Int(galaxy), destinationSystem: Int(system), reward: Int(reward),
      deposit: Int(deposit),
      failureReward: Int(failureReward), refundOnFailure: refund, duration: duration,
      parameters: parameters)
    guard offer.valid else { throw MissionPackError("Contract terms exceed supported limits.") }
    return offer
  }
  private static func contractNamespace(_ value: String) -> UUID {
    ScriptIdentity.uuid(value)
  }
  static func contractJobIdentity(_ offer: UUID) -> UUID {
    contractNamespace("contract-job-v1:\(offer)")
  }
  public func contractAcceptanceQuote(board key: String, offer id: UUID) -> ContractAcceptanceQuote
  {
    var candidate = self
    var issues: [String] = []
    do { _ = try candidate.acceptContract(board: key, offer: id) } catch {
      issues.append(error.localizedDescription)
    }
    return completedContractAcceptanceQuote(board: key, offer: id, issues: issues)
  }
  // Quote resource snapshots belong after the isolated acceptance simulation has returned.
  private func completedContractAcceptanceQuote(
    board key: String, offer id: UUID, issues: [String]
  ) -> ContractAcceptanceQuote {
    var quote = ContractAcceptanceQuote(
      board: key, offer: id, issues: issues, resources: commander.contractQuoteResources,
      epoch: ecmControl.epoch)
    quote.pledge = try? pledgePreview(board: key, offer: id)
    quote.courier = try? courierPreview(board: key, offer: id)
    return quote
  }
  mutating func confirmContract(_ quote: ContractAcceptanceQuote) throws -> UUID {
    guard quote.epoch == ecmControl.epoch else {
      throw MissionPackError("The commander context changed; review this offer again.")
    }
    let identity = Self.contractJobIdentity(quote.offer)
    if let job = commander.scriptState.instances[identity]?.contract,
      job.offer.id == quote.offer, job.boardKey == quote.board
    {
      return identity
    }
    guard quote.allowed, quote.resources == commander.contractQuoteResources else {
      throw MissionPackError("Your ship, resources or assignment changed. Review the offer again.")
    }
    return try acceptContract(
      board: quote.board, offer: quote.offer, confirmationToken: quote.reviewToken)
  }
  mutating func acceptContract(board key: String, offer id: UUID, confirmationToken: UUID = UUID())
    throws -> UUID
  {
    switch try prepareContractAcceptance(
      board: key, offer: id, confirmationToken: confirmationToken)
    {
    case .alreadyAccepted(let existing): return existing
    case .ready(let preparation): return try performContractAcceptance(preparation)
    }
  }
  private mutating func prepareContractAcceptance(
    board key: String, offer id: UUID, confirmationToken: UUID
  ) throws -> ContractAcceptancePreflight {
    resolveCourierTerminals()
    guard docked, dockedAtMainStation, !paused, let board = commander.contracts.boards[key],
      board.station == contractStation, let index = board.offers.firstIndex(where: { $0.id == id }),
      let pack = scriptPacks.first(where: { $0.digest == board.digest }),
      let definition = pack.manifest.board,
      contractRevision(definition) == board.revision, scriptUnavailable(pack) == nil
    else {
      throw MissionPackError(
        "The contract board changed or is unavailable. Return to its current offers.")
    }
    let offer = board.offers[index]
    if case .accepted(let existing) = offer.status { return .alreadyAccepted(existing) }
    guard offer.status == .available else { throw MissionPackError("This offer was declined.") }
    guard
      !commander.scriptState.instances.values.contains(where: {
        $0.outcome == .active && $0.contract?.group == board.group
      })
    else {
      throw MissionPackError("You already have an active assignment from this provider.")
    }
    guard commander.credits >= offer.deposit else {
      throw MissionPackError("Insufficient cash for this contract's deposit.")
    }
    try ScriptPackLibrary.validateCourier(pack.manifest)
    if let terms = offer.courier { try requireCourierResources(terms) }
    let acceptedAt = commander.scriptState.clock(board.clock)
    let deadline = offer.duration == 0 ? nil : acceptedAt + offer.duration
    let job = ScriptContractJob(
      boardKey: key, provider: board.provider, version: board.version,
      digest: board.digest, station: board.station, boardRevision: board.revision,
      group: board.group,
      offer: offer, clock: board.clock, acceptedAt: acceptedAt, deadline: deadline,
      deadlinePolicy: offer.courier == nil ? nil : .inclusiveConfirmation)
    let instanceID = Self.contractJobIdentity(id)
    var pledgeAdmission: ScriptPledgeAdmission? = nil
    var courierAdmission: ScriptCourierAdmission? = nil
    if let pledge = try pledgePreview(board: key, offer: id) {
      try requirePledgeResources(pledge)
      guard scriptPledgeAdmission == nil,
        commander.scriptState.nextEvent < UInt64(Int64.max) - 1
      else { throw MissionPackError("A pledge confirmation cannot start in this context.") }
      pledgeAdmission = .init(
        instance: instanceID, board: board, offer: offer,
        preview: pledge, epoch: ecmControl.epoch,
        sequence: commander.scriptState.nextEvent + 1,
        cause: scriptEventContext(
          .init(
            id: instanceID, definition: pack.manifest.stateID,
            version: pack.manifest.version, digest: pack.digest)))
    }
    if offer.courier != nil {
      guard scriptCourierAdmission == nil,
        commander.scriptState.nextEvent < UInt64(Int64.max) - 1
      else {
        throw MissionPackError("Courier confirmation cannot start in this context.")
      }
      courierAdmission = .init(
        kind: .issue, instance: instanceID,
        item: ScriptCourierCustody.itemIdentity(instanceID),
        proof: courierProof(token: confirmationToken.uuidString, revision: 0), job: job)
    }
    return .ready(
      .init(
        key: key, index: index, pack: pack, board: board, offer: offer, job: job,
        instanceID: instanceID, pledgeAdmission: pledgeAdmission, courierAdmission: courierAdmission
      ))
  }
  private mutating func performContractAcceptance(_ preparation: PreparedContractAcceptance)
    throws -> UUID
  {
    let key = preparation.key
    let index = preparation.index
    let pack = preparation.pack
    let board = preparation.board
    let offer = preparation.offer
    let job = preparation.job
    let instanceID = preparation.instanceID
    var candidate = self
    if let admission = preparation.pledgeAdmission { candidate.scriptPledgeAdmission = admission }
    if let admission = preparation.courierAdmission { candidate.scriptCourierAdmission = admission }
    candidate.commander.credits -= offer.deposit
    candidate.commander.contracts.boards[key]?.offers[index].status = .accepted(instanceID)
    _ = try candidate.acceptScriptMission(
      pack, instanceID: instanceID, randomSeed: board.seed, contract: job, drainAccepted: false)
    candidate.drainScriptEvents()
    try Self.validateCompletedContractAcceptance(&candidate, pack: pack, instanceID: instanceID)
    return publishContractAcceptance(&candidate, instanceID: instanceID)
  }
  // Reserve post-acceptance read buffers only after the real event drain has returned.
  private static func validateCompletedContractAcceptance(
    _ candidate: inout Game, pack: ScriptPack, instanceID: UUID
  ) throws {
    if let reason = candidate.commander.scriptState.instances[instanceID]?.suspension {
      throw MissionPackError(reason)
    }
    if pack.manifest.pledge != nil {
      candidate.scriptPledgeAdmission = nil
      guard candidate.pledgeAcceptanceComplete(instanceID) else {
        throw MissionPackError(
          "Donation was not completed in its original confirmation; nothing transferred.")
      }
    }
    if let admission = candidate.scriptCourierAdmission {
      candidate.scriptCourierAdmission = nil
      guard candidate.courierActionComplete(admission) else {
        throw MissionPackError("Courier item was not issued in its original confirmation.")
      }
    }
    guard candidate.commander.valid else {
      throw MissionPackError("This contract cannot fit the current commander.")
    }
  }
  private mutating func publishContractAcceptance(_ candidate: inout Game, instanceID: UUID) -> UUID
  {
    self = candidate
    return instanceID
  }
  mutating func declineContract(board key: String, offer id: UUID) throws {
    guard docked, dockedAtMainStation, !paused, let board = commander.contracts.boards[key],
      board.station == contractStation,
      let index = board.offers.firstIndex(where: { $0.id == id }),
      board.offers[index].status == .available,
      Int64(floor(commander.scriptState.clock(board.clock) / board.period)) == board.revision
    else { throw MissionPackError("This offer is no longer available to decline.") }
    commander.contracts.boards[key]?.offers[index].status = .declined
  }
  func settleContract(
    _ outcome: ScriptOutcome, state: inout ScriptInstance, candidate: inout Commander
  ) throws {
    guard var job = state.contract else { return }
    guard !job.settled else { throw MissionPackError("This contract is already settled.") }
    let reward =
      outcome == .complete ? job.offer.reward : (outcome == .failed ? job.offer.failureReward : 0)
    let refund =
      outcome == .complete || (outcome == .failed && job.offer.refundOnFailure)
      ? job.offer.deposit : 0
    let amount = reward + refund
    guard candidate.credits <= 4_294_967_295 - amount else {
      throw MissionPackError("Spend credits before collecting this contract payment.")
    }
    candidate.credits += amount
    job.settled = true
    job.settlementOutcome = outcome
    job.settlementAmount = amount
    job.settledAt = state.courier?.terminal?.proof.clock ?? candidate.scriptState.clock(job.clock)
    state.contract = job
  }
  func contractSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    guard let job = instance.contract else { return .object([:]) }
    return .object([
      "offer_id": .string(job.offer.id.uuidString), "station_id": .string(job.station.key),
      "destination_galaxy": .integer(Int64(job.offer.destinationGalaxy)),
      "destination_system": .integer(Int64(job.offer.destinationSystem)),
      "reward": .integer(Int64(job.offer.reward)), "deposit": .integer(Int64(job.offer.deposit)),
      "parameters": job.offer.parameters, "accepted_at": .number(job.acceptedAt),
      "distance_ly": job.offer.destinationGalaxy == commander.galaxy
        ? .number(
          currentSystem.distance(
            to: Universe.systemsIncludingPlugh(number: job.offer.destinationGalaxy)[
              job.offer.destinationSystem])) : .null,
      "deadline": job.deadline.map { .number($0) } ?? .null,
      "deadline_passed": .bool(
        job.deadline.map { due in
          job.deadlinePolicy == nil
            ? commander.scriptState.clock(job.clock) >= due
            : commander.scriptState.clock(job.clock) > due
        } ?? false),
    ])
  }
}
extension GameRuntime {
  public func generateContractBoard(packDigest: String) throws -> String {
    try scriptCommand { game in
      guard let pack = game.scriptPacks.first(where: { $0.digest == packDigest }) else {
        throw MissionPackError("The contract provider is unavailable.")
      }
      return try game.ensureContractBoard(pack)
    }
  }
  public func contractAcceptanceQuote(board key: String, offer id: UUID) -> ContractAcceptanceQuote
  {
    game.contractAcceptanceQuote(board: key, offer: id)
  }
  @discardableResult public func confirmContract(_ quote: ContractAcceptanceQuote) throws -> UUID {
    try scriptCommand { try $0.confirmContract(quote) }
  }
  public func declineContract(board key: String, offer id: UUID) throws {
    try scriptCommand { try $0.declineContract(board: key, offer: id) }
  }
}
