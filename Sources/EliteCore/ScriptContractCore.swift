import CryptoKit
import Foundation

extension Game {
  var contractStation: ContractStationIdentity {
    .init(galaxy: commander.galaxy, system: commander.system, stationClass: "main-orbital")
  }
  func contractRevision(_ board: ScriptBoardDefinition) -> Int64 {
    Int64(floor(commander.scriptState.clock(board.clock) / board.period))
  }
  mutating func ensureContractBoard(_ pack: ScriptPack) throws -> String {
    guard docked, dockedAtMainStation, !paused, let definition = pack.manifest.board,
      scriptUnavailable(pack) == nil,
      [.local, .flight, .calendar].contains(definition.clock)
    else {
      throw MissionPackError("This station has no available contract provider for this pack.")
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
    var world = scriptSnapshot.object ?? [:]
    world["station_id"] = .string(contractStation.key)
    world["board_revision"] = .integer(revision)
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
    let offers = try raw.map { try makeContractOffer($0, namespace: "\(key):\(revision)") }
    let board = ScriptContractBoard(
      id: definition.id, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, title: definition.title, station: contractStation, revision: revision,
      seed: initialSeed, clock: definition.clock, period: definition.period,
      group: pack.manifest.id + "/" + (definition.exclusiveGroup ?? definition.id), offers: offers)
    guard board.valid else {
      throw MissionPackError("Generated contract offers are invalid or duplicated.")
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
    return .init(
      board: key, offer: id, issues: issues, resources: commander.contractQuoteResources,
      epoch: ecmControl.epoch)
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
    return try acceptContract(board: quote.board, offer: quote.offer)
  }
  mutating func acceptContract(board key: String, offer id: UUID) throws -> UUID {
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
    if case .accepted(let existing) = offer.status { return existing }
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
    let acceptedAt = commander.scriptState.clock(board.clock)
    let deadline = offer.duration == 0 ? nil : acceptedAt + offer.duration
    let job = ScriptContractJob(
      boardKey: key, provider: board.provider, version: board.version,
      digest: board.digest, station: board.station, boardRevision: board.revision,
      group: board.group,
      offer: offer, clock: board.clock, acceptedAt: acceptedAt, deadline: deadline)
    let instanceID = Self.contractJobIdentity(id)
    var candidate = self
    candidate.commander.credits -= offer.deposit
    candidate.commander.contracts.boards[key]?.offers[index].status = .accepted(instanceID)
    _ = try candidate.acceptScriptMission(
      pack, instanceID: instanceID, randomSeed: board.seed, contract: job)
    guard candidate.commander.valid else {
      throw MissionPackError("This contract cannot fit the current commander.")
    }
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
    job.settledAt = candidate.scriptState.clock(job.clock)
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
        job.deadline.map { commander.scriptState.clock(job.clock) >= $0 } ?? false),
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
