import Foundation

extension ScriptPledgeVariant {
  func displayAmount(_ amount: Int) -> String {
    if self == .credits { return String(format: "%.1f CR", Double(amount) / 10) }
    return "\(amount) \(amount == 1 ? "tonne" : "tonnes") Food"
  }
}

public struct ScriptPledgePreview: Sendable, Equatable {
  public let declaration: ScriptPledgeDefinition
  public let station: ContractStationIdentity
  public let difficulty: Int
  public let variant: ScriptPledgeVariant
  public let amount: Int
  public let profileSeed: UInt32
  public let before: ScriptPledgeAssets
  public var charge: String {
    variant.displayAmount(amount)
  }
  public var terms: [String] {
    let place = Universe.systemsIncludingPlugh(number: station.galaxy)[station.system].name
    let afterCash = variant == .credits ? before.cash - amount : before.cash
    let afterFood = variant == .food ? before.food - amount : before.food
    return [
      declaration.title + " / local station standing",
      "Provider: " + declaration.title,
      "Issuer: Galaxy \(station.galaxy + 1), \(place) main orbital station.",
      "Difficulty \(difficulty) / \(variant.rawValue). Full pledge: \(charge).",
      String(format: "Real cash: %.1f CR.", Double(before.cash) / 10),
      "Food: \(before.food) tonnes aboard; \(before.unreservedFood) tonnes unreserved.",
      afterCash >= 0 && afterFood >= 0
        ? String(format: "After donation: %.1f CR; ", Double(afterCash) / 10)
          + "\(ScriptPledgeVariant.food.displayAmount(afterFood))."
        : "Acquire the full required resource before donating. No partial pledge.",
      before.standing < 128
        ? "Local Station Aid standing: \(before.standing) -> \(before.standing + 1)."
        : "Local standing: \(before.standing). The retained record limit has been reached.",
      "One complete donation raises local standing by one. No cash reward or deadline.",
      "Back changes nothing. Decline only consumes this offer.",
      "Amounts and standing are project estimates; no faction or trading privileges.",
    ]
  }
}

/// Exists only in a candidate Game during this one native confirmation; never Codable or saved.
struct ScriptPledgeAdmission: Sendable {
  let instance: UUID
  let board: ScriptContractBoard
  let offer: ScriptContractOffer
  let preview: ScriptPledgePreview
  let epoch: UUID
  let sequence: UInt64
  let cause: ScriptEventContext
}

extension Game {
  static let pledgeFood = 0
  static func pledgeBoardSeed(_ board: String, revision: Int64) -> UInt64? {
    UInt64(
      ScriptPackLibrary.hash(Data("contract-board-v1:\(board):\(revision)".utf8)).prefix(16),
      radix: 16)
  }
  static func pledgeProfileSeed(_ seed: UInt64) -> UInt32 {
    let value = UInt32(truncatingIfNeeded: seed)
    return value == 0 ? 0x6D2B_79F5 : value
  }
  static func pledgeParameters(
    _ parameters: ScriptValue, difficulty: Int, variant: ScriptPledgeVariant, seed: UInt32
  ) -> Bool {
    guard let fields = parameters.object,
      Set(fields.keys) == ["difficulty", "variant", "profile_seed"]
    else { return false }
    return fields["difficulty"]?.integer == Int64(difficulty)
      && fields["variant"]?.string == variant.rawValue
      && fields["profile_seed"]?.integer == Int64(seed)
  }
  func pledgeAssets(
    _ definition: ScriptPledgeDefinition, station: ContractStationIdentity,
    commander: Commander
  ) -> ScriptPledgeAssets {
    .init(
      cash: commander.credits, food: commander.cargo[Self.pledgeFood],
      unreservedFood: commander.sellableCargo(Self.pledgeFood),
      standing: commander.scriptState.pledgeLedger?.standing(
        provider: definition.provider,
        station: station) ?? 0)
  }
  func pledgePreview(board key: String, offer id: UUID) throws -> ScriptPledgePreview? {
    guard let board = commander.contracts.boards[key],
      let pack = scriptPacks.first(where: { $0.digest == board.digest }),
      let declaration = pack.manifest.pledge
    else { return nil }
    guard let offer = board.offers.first(where: { $0.id == id }), declaration.valid,
      declaration.provider == board.provider, declaration.provider == pack.manifest.id,
      board.station.system < 256, board.clock == .local, board.period == 3600,
      let tier = offer.parameters["difficulty"]?.integer, (1...3).contains(tier),
      let value = offer.parameters["variant"]?.string,
      let variant = ScriptPledgeVariant(rawValue: value),
      let amount = declaration.amount(difficulty: Int(tier), variant: variant),
      Self.pledgeParameters(
        offer.parameters, difficulty: Int(tier), variant: variant,
        seed: Self.pledgeProfileSeed(board.seed)),
      offer.key == variant.rawValue + "-" + String(tier),
      offer.destinationGalaxy == board.station.galaxy,
      offer.destinationSystem == board.station.system,
      offer.reward == 0, offer.deposit == 0, offer.failureReward == 0,
      !offer.refundOnFailure, offer.duration == 0,
      Commodity.all[Self.pledgeFood].name == "Food", Commodity.all[Self.pledgeFood].unit == "t"
    else { throw MissionPackError("This offer does not match its native station pledge terms.") }
    return .init(
      declaration: declaration, station: board.station, difficulty: Int(tier),
      variant: variant, amount: amount, profileSeed: Self.pledgeProfileSeed(board.seed),
      before: pledgeAssets(declaration, station: board.station, commander: commander))
  }
  func requirePledgeResources(_ preview: ScriptPledgePreview) throws {
    let ledger = commander.scriptState.pledgeLedger ?? ScriptPledgeLedger()
    guard preview.before.valid,
      ledger.receipts.count < 128, preview.before.standing < 128,
      ledger.issuers[preview.declaration.provider + "/" + preview.station.key] != nil
        || ledger.issuers.count < 128
    else { throw MissionPackError("The retained station pledge record limit has been reached.") }
    if preview.variant == .credits, preview.before.cash < preview.amount {
      throw MissionPackError(
        "The full pledge requires \(preview.charge); real cash is insufficient.")
    }
    if preview.variant == .food, preview.before.unreservedFood < preview.amount {
      throw MissionPackError("The full pledge requires \(preview.amount) tonnes unreserved Food.")
    }
  }
  func applyPledgeCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws {
    guard command.object.map({ Set($0.keys) == ["op"] }) == true,
      command["op"]?.string == "pledge.commit", state.outcome == .active,
      let admission = scriptPledgeAdmission, admission.instance == state.id,
      admission.epoch == ecmControl.epoch, event.kind == "mission.accepted",
      event.instance == state.id, event.sequence == admission.sequence,
      event.context == admission.cause, event.values.isEmpty, state.revision == 0,
      let declaration = pack.manifest.pledge, declaration == admission.preview.declaration,
      pack.manifest.capabilities.contains("station-pledges-basic-v2"),
      state.digest == pack.digest, state.version == pack.manifest.version,
      let job = state.contract, job.boardKey == admission.board.cacheKey,
      job.offer == admission.offer, job.station == admission.preview.station,
      job.boardRevision == admission.board.revision, !job.settled,
      candidate.contracts.boards[job.boardKey] == acceptedPledgeBoard(admission),
      docked, dockedAtMainStation, !paused, contractStation == job.station,
      pledgeAssets(declaration, station: job.station, commander: candidate)
        == admission.preview.before,
      candidate.scriptState.pledgeLedger?.receipt(instance: state.id) == nil,
      state.pledgeReceiptID == nil,
      admission.cause.valid, admission.cause.docked, admission.cause.mainStation
    else { throw MissionPackError("A pledge requires its exact native Donate confirmation.") }
    try requirePledgeResources(admission.preview)
    let before = admission.preview.before
    if admission.preview.variant == .credits {
      candidate.credits -= admission.preview.amount
    } else {
      candidate.cargo[Self.pledgeFood] -= admission.preview.amount
    }
    var ledger = candidate.scriptState.pledgeLedger ?? ScriptPledgeLedger()
    let issuer = ScriptPledgeIssuer(
      provider: declaration.provider, station: job.station,
      standing: before.standing + 1)
    ledger.issuers[issuer.key] = issuer
    candidate.scriptState.pledgeLedger = ledger
    let after = pledgeAssets(declaration, station: job.station, commander: candidate)
    var committed = state
    committed.revision += 1
    let receipt = ScriptPledgeReceipt(
      id: ScriptPledgeReceipt.identity(state.id), instance: state.id,
      declaration: declaration, version: state.version, digest: state.digest,
      board: job.boardKey, offer: job.offer.id, boardRevision: job.boardRevision,
      boardSeed: admission.board.seed, profileSeed: admission.preview.profileSeed,
      difficulty: admission.preview.difficulty, variant: admission.preview.variant,
      amount: admission.preview.amount,
      unit: admission.preview.variant == .credits ? "decicredits" : "t",
      origin: job.station, donatedAt: contractStation, creditedAt: contractStation,
      before: before, after: after, sequence: event.sequence, revision: committed.revision,
      cause: admission.cause, committed: scriptEventContext(committed))
    ledger.receipts[receipt.id] = receipt
    candidate.scriptState.pledgeLedger = ledger
    state.pledgeReceiptID = receipt.id
    try applyScriptCommand(
      .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
      event: event, pack: pack, state: &state, candidate: &candidate)
  }
  private func acceptedPledgeBoard(_ admission: ScriptPledgeAdmission) -> ScriptContractBoard {
    var board = admission.board
    if let index = board.offers.firstIndex(where: { $0.id == admission.offer.id }) {
      board.offers[index].status = .accepted(admission.instance)
    }
    return board
  }
  func pledgeAcceptanceComplete(_ id: UUID) -> Bool {
    guard let state = commander.scriptState.instances[id], state.outcome == .complete,
      state.contract?.settled == true, state.contract?.settlementAmount == 0,
      let receipt = commander.scriptState.pledgeLedger?.receipt(instance: id)
    else { return false }
    return receipt.valid(engine: commander.scriptState)
  }
  func pledgeQuery(_ state: ScriptInstance) -> ScriptValue {
    guard let receipt = commander.scriptState.pledgeLedger?.receipt(instance: state.id) else {
      return .null
    }
    return .object([
      "provider": .string(receipt.declaration.provider),
      "station": .string(receipt.creditedAt.key), "variant": .string(receipt.variant.rawValue),
      "amount": .integer(Int64(receipt.amount)), "unit": .string(receipt.unit),
      "standing": .integer(
        Int64(
          commander.scriptState.pledgeLedger?.standing(
            provider: receipt.declaration.provider, station: receipt.creditedAt) ?? 0)),
      "receipt": .string(receipt.id.uuidString),
    ])
  }
  func pledgeGallerySummary(_ state: ScriptInstance?) -> String {
    guard let state, let receipt = commander.scriptState.pledgeLedger?.receipt(instance: state.id)
    else { return "" }
    let station = Universe.systemsIncludingPlugh(number: receipt.creditedAt.galaxy)[
      receipt.creditedAt.system
    ].name
    return "\n\nDonation: \(receipt.variant.displayAmount(receipt.amount))."
      + "\n\(receipt.declaration.title) / Galaxy \(receipt.creditedAt.galaxy + 1), \(station) main station."
      + "\nLocal standing \(receipt.before.standing) -> \(receipt.after.standing). Completed once."
  }
}

extension ScriptPackLibrary {
  static func validatePledge(_ manifest: ScriptManifest) throws {
    guard let pledge = manifest.pledge else { return }
    guard pledge.valid, pledge.provider == manifest.id,
      manifest.capabilities.contains("station-pledges-basic-v2"),
      manifest.capabilities.contains("story-v2"),
      manifest.capabilities.contains("durable-commands-v2"),
      manifest.board?.clock == .local, manifest.board?.period == 3600,
      manifest.mission.parentOnly != true, (manifest.children ?? []).isEmpty
    else { throw MissionPackError("Invalid native station pledge declaration or provider.") }
  }
}
