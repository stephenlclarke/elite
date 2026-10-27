import Foundation

public struct ScriptPledgeDefinition: Codable, Sendable, Equatable {
  public let profile: String
  public let provider: String
  public let title: String
  /// Native money is integer decicredits; Food quantities are whole tonnes.
  public let creditAmounts: [Int]
  public let foodTonnes: [Int]
  var valid: Bool {
    if profile == OriginalMutualContribution.profile {
      return OriginalMutualContribution.matches(self)
    }
    return PackValidation.localID(profile) && PackValidation.identifier(provider)
      && (1...96).contains(title.count) && creditAmounts.count == 3 && foodTonnes.count == 3
      && creditAmounts.allSatisfy { (1...4_294_967_295).contains($0) }
      && foodTonnes.allSatisfy { (1...1_000_000).contains($0) }
  }
  func amount(difficulty: Int, variant: ScriptPledgeVariant) -> Int? {
    if profile == OriginalMutualContribution.profile {
      return valid && difficulty == 1 && variant == .credits
        ? OriginalMutualContribution.amount : nil
    }
    guard valid, (1...3).contains(difficulty) else { return nil }
    return (variant == .credits ? creditAmounts : foodTonnes)[difficulty - 1]
  }
}

public enum ScriptPledgeVariant: String, Codable, Sendable { case credits, food }

public struct ScriptPledgeIssuer: Codable, Sendable, Equatable {
  public let provider: String
  public let station: ContractStationIdentity
  public let standing: Int
  public var key: String { provider + "/" + station.key }
  var valid: Bool {
    PackValidation.identifier(provider) && station.valid && station.system < 256
      && (0...128).contains(standing)
  }
}

public struct ScriptPledgeAssets: Codable, Sendable, Equatable {
  public let cash: Int
  public let food: Int
  public let unreservedFood: Int
  public let standing: Int
  var valid: Bool {
    (0...4_294_967_295).contains(cash) && (0...Int.max / 17).contains(food)
      && (0...food).contains(unreservedFood) && (0...128).contains(standing)
  }
}

public struct ScriptPledgeReceipt: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let instance: UUID
  public let declaration: ScriptPledgeDefinition
  public let version: String
  public let digest: String
  public let board: String
  public let offer: UUID
  public let boardRevision: Int64
  public let boardSeed: UInt64
  public let profileSeed: UInt32
  public let difficulty: Int
  public let variant: ScriptPledgeVariant
  public let amount: Int
  public let unit: String
  public let origin: ContractStationIdentity
  public let donatedAt: ContractStationIdentity
  public let creditedAt: ContractStationIdentity
  public let before: ScriptPledgeAssets
  public let after: ScriptPledgeAssets
  public let sequence: UInt64
  public let revision: UInt64
  public let cause: ScriptEventContext
  public let committed: ScriptEventContext
  public var issuerKey: String { declaration.provider + "/" + creditedAt.key }
  static func identity(_ instance: UUID) -> UUID {
    ScriptIdentity.uuid("station-pledge-receipt-v1:" + instance.uuidString)
  }
  func valid(engine: ScriptEngineState) -> Bool {
    guard declaration.valid, before.valid, after.valid, cause.valid, committed.valid,
      let expectedAmount = declaration.amount(difficulty: difficulty, variant: variant),
      amount == expectedAmount, unit == (variant == .credits ? "decicredits" : "t"),
      id == Self.identity(instance), profileSeed != 0,
      profileSeed == Game.pledgeProfileSeed(boardSeed),
      origin.valid, origin.system < 256, origin == donatedAt, donatedAt == creditedAt,
      let state = engine.instances[instance], let job = state.contract,
      let completion = state.completionReceipt,
      state.outcome == .complete, state.campaignParent == nil, state.pledgeReceiptID == id,
      state.version == version, state.digest == digest,
      state.definition.hasPrefix(declaration.provider + "/"),
      job.provider == declaration.provider, job.version == version, job.digest == digest,
      job.boardKey == board, job.boardRevision == boardRevision, job.offer.id == offer,
      boardRevision == Int64(floor(cause.localSeconds / 3600)), job.offer.status == .available,
      boardSeed == Game.pledgeBoardSeed(board, revision: boardRevision),
      offer == ScriptIdentity.uuid("contract-offer-v1:\(board):\(boardRevision):\(job.offer.key)"),
      instance == Game.contractJobIdentity(offer), job.station == origin,
      job.offer.destinationGalaxy == origin.galaxy, job.offer.destinationSystem == origin.system,
      job.clock == .local, job.deadline == nil, job.offer.duration == 0,
      job.offer.reward == 0, job.offer.deposit == 0, job.offer.failureReward == 0,
      !job.offer.refundOnFailure, job.settled, job.settlementOutcome == .complete,
      job.settlementAmount == 0, job.acceptedAt == cause.localSeconds,
      job.settledAt == committed.localSeconds,
      Game.pledgeParameters(
        job.offer.parameters, difficulty: difficulty, variant: variant,
        seed: profileSeed),
      job.offer.key == variant.rawValue + "-" + String(difficulty),
      sequence > 0, sequence <= engine.nextEvent, state.hasAcknowledged(sequence),
      revision > 0, revision == state.revision, cause.revision + 1 == revision,
      completion.sequence == sequence, completion.revision == revision,
      completion.causeKind == "mission.accepted", completion.cause == cause,
      completion.committed == committed, completion.settlementAmount == 0,
      completion.valid(for: state, engine: engine),
      cause.valid, committed.valid, cause.docked, cause.mainStation,
      committed.docked, committed.mainStation, committed.revision == revision,
      cause.galaxy == origin.galaxy, cause.system == origin.system,
      committed.galaxy == origin.galaxy, committed.system == origin.system,
      before.standing < 128, after.standing == before.standing + 1
    else { return false }
    if variant == .credits {
      return before.cash >= amount && after.cash == before.cash - amount
        && after.food == before.food && after.unreservedFood == before.unreservedFood
    }
    return before.unreservedFood >= amount && after.food == before.food - amount
      && after.unreservedFood == before.unreservedFood - amount && after.cash == before.cash
  }
}

/// Standing is derived from the complete retained native receipt sequence; never from Lua data.
public struct ScriptPledgeLedger: Codable, Sendable, Equatable {
  public var issuers: [String: ScriptPledgeIssuer] = [:]
  public var receipts: [UUID: ScriptPledgeReceipt] = [:]
  public init() {}
  public func standing(provider: String, station: ContractStationIdentity) -> Int {
    issuers[provider + "/" + station.key]?.standing ?? 0
  }
  func receipt(instance: UUID) -> ScriptPledgeReceipt? {
    receipts[ScriptPledgeReceipt.identity(instance)]
  }
  func valid(engine: ScriptEngineState) -> Bool {
    guard engine.instances.count <= 128, issuers.count <= 128, receipts.count <= 128 else {
      return false
    }
    let markers = engine.instances.values.compactMap(\.pledgeReceiptID)
    guard markers.count == receipts.count, Set(markers).count == markers.count,
      engine.instances.values.allSatisfy({ state in
        guard let marker = state.pledgeReceiptID else { return true }
        return state.outcome == .complete && receipts[marker]?.instance == state.id
      }),
      Set(receipts.values.map(\.instance)).count == receipts.count,
      Set(receipts.values.map(\.sequence)).count == receipts.count,
      receipts.allSatisfy({ $0.key == $0.value.id && $0.value.valid(engine: engine) }),
      Set(issuers.keys) == Set(receipts.values.map(\.issuerKey)),
      issuers.allSatisfy({ $0.key == $0.value.key && $0.value.valid })
    else { return false }
    for issuer in issuers.values {
      let history = receipts.values.filter { $0.issuerKey == issuer.key }
        .sorted { $0.sequence < $1.sequence }
      guard issuer.standing == history.count,
        history.enumerated().allSatisfy({ index, receipt in
          receipt.before.standing == index && receipt.after.standing == index + 1
        })
      else { return false }
    }
    return true
  }
}
