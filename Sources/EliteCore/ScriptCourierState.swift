import Foundation

public struct ScriptCourierDefinition: Codable, Sendable, Equatable {
  public let profile: String
  public let generatorRevision: Int
  public let deliveryContact: String
  public let abandonContact: String
  var valid: Bool {
    profile == "PROJECT-SPACE-G02-1" && generatorRevision == 1
      && deliveryContact == "courier-delivery" && abandonContact == "courier-abandon"
  }
}

public enum ScriptCourierVariant: String, Codable, Sendable {
  case data, package
  var tonnes: Int { self == .package ? 1 : 0 }
  var title: String { self == .data ? "Encrypted data" : "Sealed package" }
}
public enum ScriptContractDeadlinePolicy: String, Codable, Sendable {
  case inclusiveConfirmation
}

public struct ScriptCourierTerms: Codable, Sendable, Equatable {
  public let declaration: ScriptCourierDefinition
  public let capabilities: [String]
  public let generation: ScriptCourierGeneration
  public let row: Int
  public let calendarLowerBoundSeconds: Double
  public var difficulty: Int { row / 2 + 1 }
  public var variant: ScriptCourierVariant { row % 2 == 0 ? .data : .package }
  public var key: String { variant.rawValue + "-" + String(difficulty) }
  public var path: [Int] { generation.path(for: row) ?? [] }
  public var destination: Int { path.last ?? -1 }
  public var duration: Double { difficulty == 3 ? 259200 : 172800 }
  public var reward: Int { ([500, 750, 1000][difficulty - 1] + 300 * (path.count - 1)) * 10 }
  var validRow: Bool {
    declaration.valid && capabilities == Self.requiredCapabilities.sorted()
      && (0..<6).contains(row) && (2...4).contains(path.count)
      && calendarLowerBoundSeconds.isFinite
      && calendarLowerBoundSeconds == generation.calendarCost(path)
  }
  var valid: Bool { validRow && generation.valid }
  static let requiredCapabilities: Set<String> = [
    "courier-contracts-basic-v2", "mission-calendar-v2", "story-v2", "durable-commands-v2",
    "contracts-basic-v2",
  ]
  func matches(_ offer: ScriptContractOffer) -> Bool {
    guard validRow else { return false }
    return offer.key == key && offer.destinationGalaxy == generation.origin.galaxy
      && offer.destinationSystem == destination && offer.reward == reward
      && offer.deposit == 0 && offer.failureReward == 0 && !offer.refundOnFailure
      && offer.duration == duration
      && offer.parameters
        == .object([
          "difficulty": .integer(Int64(difficulty)), "variant": .string(variant.rawValue),
        ])
  }
}

/// Saved causal proof is descriptive; only an unencoded one-action admission authorizes commands.
public struct ScriptCourierActionProof: Codable, Sendable, Equatable {
  public let sequence: UInt64
  public let token: String
  public let revision: UInt64
  public let epoch: UUID
  public let clock: Double
  public let station: ContractStationIdentity
  var valid: Bool {
    sequence > 0 && sequence < UInt64(Int64.max) && revision < UInt64(Int64.max)
      && (1...256).contains(token.utf8.count) && station.valid
      && clock.isFinite && (0...1e12).contains(clock)
  }
}
public enum ScriptCourierTerminalCause: String, Codable, Sendable {
  case delivered, expired, abandoned, escapePod, shipDestroyed
  var title: String {
    switch self {
    case .delivered: "Delivered"
    case .expired: "Expired"
    case .abandoned: "Abandoned"
    case .escapePod: "Lost - ship abandoned with escape pod"
    case .shipDestroyed: "Lost - ship destroyed"
    }
  }
  var outcome: ScriptOutcome {
    switch self {
    case .delivered: .complete
    case .abandoned: .abandoned
    default: .failed
    }
  }
}
public struct ScriptCourierTerminalReceipt: Codable, Sendable, Equatable {
  public let id: UUID
  public let item: UUID
  public let cause: ScriptCourierTerminalCause
  public let proof: ScriptCourierActionProof
  public let amount: Int
}
public struct ScriptCourierPendingLoss: Codable, Sendable, Equatable {
  public let id: UUID
  public let item: UUID
  public let clock: Double
  public let station: ContractStationIdentity
  public let epoch: UUID
  public let context: ScriptEventContext
}
public struct ScriptCourierCustody: Codable, Sendable, Equatable {
  public let item: UUID
  public let issue: ScriptCourierActionProof
  public var terminal: ScriptCourierTerminalReceipt?
  public var pendingLoss: ScriptCourierPendingLoss?
  static func itemIdentity(_ instance: UUID) -> UUID {
    ScriptIdentity.uuid("courier-item-v1:" + instance.uuidString)
  }
  static func terminalIdentity(_ item: UUID) -> UUID {
    ScriptIdentity.uuid("courier-terminal-v1:" + item.uuidString)
  }
  static let payloadKey = "courier-consignment"
  func valid(state: ScriptInstance, engine: ScriptEngineState) -> Bool {
    guard let job = state.contract, let deadline = job.deadline, let terms = job.offer.courier,
      terms.valid,
      job.clock == .missionCalendar, job.deadlinePolicy == .inclusiveConfirmation,
      item == Self.itemIdentity(state.id), issue.valid, issue.clock == job.acceptedAt,
      issue.station == job.station, issue.sequence <= engine.nextEvent,
      state.hasAcknowledged(issue.sequence), issue.revision == 0,
      let calendar = engine.missionCalendar, calendar.valid, calendar.seconds >= issue.clock
    else { return false }
    let quantity = state.payloads[Self.payloadKey, default: 0]
    guard quantity == (terminal == nil ? terms.variant.tonnes : 0) else { return false }
    if let pending = pendingLoss {
      guard terms.variant == .package, terminal == nil, state.outcome == .active,
        pending.item == item,
        pending.id == ScriptIdentity.uuid("courier-fatal-v1:" + item.uuidString),
        pending.clock.isFinite, pending.clock >= issue.clock, pending.clock <= calendar.seconds,
        pending.station.valid, pending.context.valid,
        pending.context.galaxy == pending.station.galaxy,
        pending.context.system == pending.station.system,
        pending.context.revision <= state.revision
      else { return false }
    }
    guard let receipt = terminal else {
      return state.outcome == .active && !job.settled && state.completionReceipt == nil
    }
    guard let completion = state.completionReceipt,
      completion.instance == state.id, completion.sequence == receipt.proof.sequence,
      receipt.proof.revision < UInt64(Int64.max) - 1,
      completion.revision == receipt.proof.revision + 1,
      completion.causeKind
        == (receipt.cause == .delivered || receipt.cause == .abandoned
          ? "dialogue.confirmed" : "courier.terminated"),
      completion.valid(for: state, engine: engine),
      pendingLoss == nil, receipt.item == item, receipt.id == Self.terminalIdentity(item),
      receipt.proof.valid, receipt.proof.sequence <= engine.nextEvent,
      state.hasAcknowledged(receipt.proof.sequence), receipt.proof.clock >= issue.clock,
      receipt.proof.clock <= calendar.seconds, receipt.proof.revision < state.revision,
      receipt.cause.outcome == state.outcome, job.settled,
      job.settlementAmount == receipt.amount, job.settledAt == receipt.proof.clock
    else { return false }
    switch receipt.cause {
    case .delivered:
      return receipt.amount == terms.reward && receipt.proof.clock <= deadline
        && receipt.proof.station.galaxy == job.offer.destinationGalaxy
        && receipt.proof.station.system == job.offer.destinationSystem
        && receipt.proof.token.hasSuffix(":" + terms.declaration.deliveryContact)
    case .abandoned:
      return receipt.amount == 0 && receipt.proof.station == job.station
        && receipt.proof.token.hasSuffix(":" + terms.declaration.abandonContact)
    case .expired: return receipt.amount == 0 && receipt.proof.clock > deadline
    case .escapePod, .shipDestroyed: return receipt.amount == 0 && terms.variant == .package
    }
  }
}

extension ScriptPackLibrary {
  static func validateCourier(_ manifest: ScriptManifest) throws {
    guard let courier = manifest.courier else {
      guard manifest.board?.clock != .missionCalendar,
        !manifest.capabilities.contains("courier-contracts-basic-v2"),
        !manifest.capabilities.contains("mission-calendar-v2"),
        !manifest.handlers.contains(where: { $0.event == "courier.terminated" })
      else { throw MissionPackError("Mission calendar requires a closed courier declaration.") }
      return
    }
    guard courier.valid,
      ScriptCourierTerms.requiredCapabilities.isSubset(of: Set(manifest.capabilities)),
      manifest.board?.clock == .missionCalendar, manifest.board?.period == 3600,
      manifest.board?.exclusiveGroup == "g02-courier", manifest.pledge == nil,
      manifest.mission.parentOnly != true, (manifest.children ?? []).isEmpty,
      manifest.dialogs?.contains(where: { $0.id == courier.deliveryContact }) == true,
      manifest.dialogs?.contains(where: { $0.id == courier.abandonContact }) == true
    else { throw MissionPackError("Invalid native courier declaration or clock authorization.") }
  }
}
