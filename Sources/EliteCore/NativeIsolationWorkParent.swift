import Foundation

/// Historical proof links only. Canonical gearIssues and inventory own the loan.
struct NativeIsolationWorkParentIssue: Codable, Equatable, Sendable {
  let operation: UUID
  let source: EquipmentIssueSource
  let original: UUID
}

struct NativeIsolationWorkParentReturn: Codable, Equatable, Sendable {
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let sequence: UInt64
  let physicalTime: Double
}

enum NativeIsolationWorkParentCutoff: Codable, Equatable, Sendable {
  case returned(NativeIsolationWorkParentReturn)
  case lost(NativeIsolationProgrammerLoss)
  var operation: UUID {
    switch self {
    case .returned(let value): value.operation
    case .lost(let value): value.operation
    }
  }
  var sequence: UInt64 {
    switch self {
    case .returned(let value): value.sequence
    case .lost(let value): value.facts.sequence
    }
  }
  var physicalTime: Double {
    switch self {
    case .returned(let value): value.physicalTime
    case .lost(let value): value.facts.physicalTime
    }
  }
}

struct NativeIsolationWorkParentState: Codable, Equatable, Sendable {
  let parent: UUID
  let digest: String
  let owner: UUID
  let source: UUID
  let issuer: UUID
  let authorization: UUID
  let acceptance: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let sequence: UInt64
  let physicalTime: Double
  let terms: String
  let issue: NativeIsolationWorkParentIssue
  var cutoff: NativeIsolationWorkParentCutoff?
  var terminal: NativeIsolationContractTerminal?
}

/// Validated historical inputs for the provider's sole opaque authority factory.
/// This value does not grant current work permission or assert provider completion.
struct NativeIsolationWorkParentPrimitive: Equatable, Sendable {
  let parentID: UUID
  let parentDigest: String
  let authorization: UUID
  let owner: UUID
  let issuer: UUID
  let acceptance: NativeMainStationDockReceipt
  let issueOperation: UUID
  let sequence: UInt64
  let physicalTime: Double
  let cutoff: NativeIsolationWorkParentCutoff?
  let terminal: NativeIsolationContractTerminal?
}

enum NativeIsolationWorkParent {
  static let stateID = "l337.contract/isolation-work"
  static let version = "1.0.0"
  static let digest = "6ee1d1af06b71a13061faf8b34dc06ec05ddeeb0dc945a599d321cb86be00860"
  static let station = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let reward = 9700
  static func source(owner: UUID) -> UUID {
    ScriptIdentity.uuid("g11-renas-dual-feed-v1:\(owner):pair-001")
  }
  static func offer(owner: UUID) -> ScriptContractOffer {
    .init(
      id: ScriptIdentity.uuid(
        "g11-initial-isolation-v1:\(owner):\(source(owner: owner)):\(digest)"),
      key: "initial-isolation", title: "Lerr / External isolation work",
      briefing:
        "Avenor-Renas-Avenor; isolate both original feeders and return the original programmer. L2 H0. Requires one real tonne; no fee, deposit or deadline.",
      destinationGalaxy: 0, destinationSystem: 185, reward: reward,
      deposit: 0, failureReward: 0, refundOnFailure: false, duration: 0,
      parameters: .object(["legs": .integer(2), "hazard": .integer(0)]))
  }
  static func job(owner: UUID, acceptedAt: Double) -> ScriptContractJob {
    .init(
      boardKey: digest + "/isolation-work/" + station.key, provider: "l337.contract",
      version: version, digest: digest, station: station, boardRevision: 0,
      group: "l337.contract/isolation-work", offer: offer(owner: owner), clock: .calendar,
      acceptedAt: acceptedAt, deadline: nil)
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    pack.manifest.stateID == stateID && pack.manifest.version == version && pack.digest == digest
  }
  static func marked(_ mission: borrowing ScriptInstance) -> Bool {
    let own = mission.definition == stateID
    let pinned = mission.digest == digest
    let claimed = mission.savedIsolationWorkParent != nil
    return own || pinned || claimed
  }
  static func authorization(
    parent: UUID, owner: UUID, dock: NativeMainStationDockReceipt, sequence: UInt64,
    issueOperation: UUID, carrier: UUID, inventoryRevision: UInt64,
    physicalTime: Double, terms: String
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "g11-lerr-consent-v1:\(parent):\(owner):\(try NativeFlightReception.hash(dock)):\(sequence):\(issueOperation):\(carrier):\(inventoryRevision):\(physicalTime):\(terms)"
    )
  }

  /// No whole-commander, provider or terminal validator is called here.
  static func primitive(parent: ScriptInstance, commander: borrowing Commander) throws
    -> NativeIsolationWorkParentPrimitive
  {
    guard commander.scriptState.instances[parent.id] == parent, parent.definition == stateID,
      parent.digest == digest, parent.version == version,
      let p = parent.savedIsolationWorkParent, let owner = commander.equipmentOwnerID,
      let job = parent.contract, job.valid,
      let issue = parent.gearIssues[NativeIsolationProgrammerDefinition.resource],
      issue.valid(for: parent), let obligation = issue.obligation,
      parent.gearIssues.count == 1, parent.payloads.isEmpty,
      parent.id == Game.contractJobIdentity(offer(owner: owner).id), p.parent == parent.id,
      p.owner == owner, p.digest == digest, p.source == source(owner: owner),
      p.issuer == NativeIsolationProgrammerDefinition.issuer(owner: owner),
      job.offer == offer(owner: owner), job.boardRevision == 0,
      job.boardKey == digest + "/isolation-work/" + station.key,
      job.provider == "l337.contract", job.version == version, job.digest == digest,
      job.station == station, job.group == stateID, job.clock == .calendar,
      p.terms
        == (try? NativeFlightReception.hash(Self.job(owner: owner, acceptedAt: job.acceptedAt))),
      NativeStationPassengerJourney.historicalDock(p.acceptance, commander: commander),
      p.acceptance.station.system == SystemIdentity(galaxy: 0, system: 7),
      p.acceptance.station.world == owner,
      p.authorization
        == (try? authorization(
          parent: parent.id, owner: owner, dock: p.acceptance, sequence: p.sequence,
          issueOperation: p.issue.operation, carrier: p.carrier,
          inventoryRevision: p.inventoryRevision, physicalTime: p.physicalTime, terms: p.terms)),
      p.sequence > 0, p.sequence <= commander.scriptState.nextEvent,
      parent.hasAcknowledged(p.sequence),
      p.physicalTime.isFinite, p.physicalTime >= 0,
      p.physicalTime <= commander.flightSimulation.physicalTime,
      job.acceptedAt >= p.acceptance.calendarSeconds,
      job.acceptedAt <= commander.scriptState.calendarSeconds,
      p.inventoryRevision < UInt64(Int64.max),
      p.issue.source == obligation.source,
      p.issue.source
        == EquipmentIssueSource(
          mission: parent.id, resource: NativeIsolationProgrammerDefinition.resource,
          packDigest: digest),
      p.issue.original == NativeIsolationProgrammerDefinition.serial(parent: parent.id),
      obligation.items == [p.issue.original],
      obligation.node == NativeIsolationProgrammerDefinition.node,
      obligation.loan, !obligation.returnRemaining,
      obligation.consumed.isSubset(of: [p.issue.original]),
      obligation.displacements.isEmpty, obligation.legacyMissingItems.isEmpty,
      obligation.status != .released
    else { throw SaveError.invalidCommander }
    if let cutoff = p.cutoff {
      guard cutoff.sequence > p.sequence, cutoff.sequence <= commander.scriptState.nextEvent,
        parent.hasAcknowledged(cutoff.sequence), cutoff.physicalTime.isFinite,
        cutoff.physicalTime >= p.physicalTime,
        cutoff.physicalTime <= commander.flightSimulation.physicalTime
      else { throw SaveError.invalidCommander }
      switch cutoff {
      case .returned(let value):
        guard obligation.status == .returned, obligation.consumed.isEmpty,
          value.dock.station == p.acceptance.station,
          NativeStationPassengerJourney.historicalDock(value.dock, commander: commander),
          value.dock.sequence >= p.acceptance.sequence,
          value.dock.calendarSeconds >= p.acceptance.calendarSeconds
        else { throw SaveError.invalidCommander }
      case .lost(let value):
        guard obligation.status == .issued, obligation.consumed == [p.issue.original],
          value.valid(parent: parent, proof: p, commander: commander)
        else { throw SaveError.invalidCommander }
      }
    } else {
      guard obligation.status == .issued, obligation.consumed.isEmpty else {
        throw SaveError.invalidCommander
      }
    }
    if let terminal = p.terminal {
      guard terminal.shapeValid(proof: p), terminal.facts.outcome == parent.outcome,
        terminal.facts.sequence <= commander.scriptState.nextEvent,
        parent.hasAcknowledged(terminal.facts.sequence),
        terminal.facts.physicalTime <= commander.flightSimulation.physicalTime
      else { throw SaveError.invalidCommander }
    }
    return .init(
      parentID: parent.id, parentDigest: digest, authorization: p.authorization,
      owner: owner, issuer: p.issuer, acceptance: p.acceptance, issueOperation: p.issue.operation,
      sequence: p.sequence, physicalTime: p.physicalTime, cutoff: p.cutoff, terminal: p.terminal)
  }
}
