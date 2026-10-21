import Foundation

/// Original generic terms. Historical GSE's short-balance closure is a different profile.
public struct ScriptFinanceDefinition: Codable, Sendable, Equatable {
  public let id: String
  public let profile: String
  public let creditor: String
  public let title: String
  public let principal: Int
  public let galaxy: Int
  public let system: Int
  var valid: Bool {
    PackValidation.localID(id) && profile == "fixed-principal-v1"
      && PackValidation.identifier(creditor) && (1...96).contains(title.utf8.count)
      && (1...4_294_967_295).contains(principal)
      && (0..<8).contains(galaxy) && (0...256).contains(system)
  }
  func station(owner: UUID) -> NativeMainStationIdentity {
    let key = "main-orbital:\(galaxy):\(system)"
    return .init(
      world: owner, system: .init(galaxy: galaxy, system: system),
      resource: Game.worldResourceIdentity("main-station-v1:" + key))
  }
}

struct ScriptFinanceSource: Codable, Sendable, Equatable {
  let instance: UUID
  let definition: String
  let version: String
  let digest: String
  let sequence: UInt64
  let cause: ScriptEventContext
  var valid: Bool {
    let parts = definition.split(separator: "/", omittingEmptySubsequences: false)
    return parts.count == 2 && parts.allSatisfy { PackValidation.identifier(String($0)) }
      && PackValidation.version(version) && ScriptCompletionReceipt.validDigest(digest)
      && sequence > 0 && sequence < UInt64(Int64.max) && cause.valid
      && cause.docked && cause.mainStation
  }
  func matches(_ state: ScriptInstance) -> Bool {
    instance == state.id && definition == state.definition && version == state.version
      && digest == state.digest
  }
  func identity(owner: UUID, loan: String) -> UUID {
    ScriptIdentity.uuid(
      "finance-obligation-v1:\(owner):\(instance):\(definition):\(version):\(digest):\(loan)")
  }
}

enum ScriptFinanceOperation: String, Codable, Sendable { case borrow, repay, decline }
enum ScriptFinanceStatus: String, Sendable { case offered, declined, outstanding, paid }

/// Historical facts do not depend on today's dock, epoch, parent lifetime or installed content.
struct ScriptFinanceReceipt: Codable, Sendable, Equatable {
  let id: UUID
  let token: UUID
  let obligation: UUID
  let operation: ScriptFinanceOperation
  let revision: UInt64
  let beforeCash: Int
  let afterCash: Int
  let beforePrincipal: Int
  let afterPrincipal: Int
  let amount: Int
  let dock: NativeMainStationDockReceipt
  let calendarSeconds: Double
  let epoch: UUID
  static func identity(_ obligation: UUID, revision: UInt64) -> UUID {
    ScriptIdentity.uuid("finance-receipt-v1:\(obligation):\(revision)")
  }
}

struct ScriptFinanceRecord: Codable, Sendable, Equatable {
  let id: UUID
  let terms: ScriptFinanceDefinition
  let source: ScriptFinanceSource
  let createdRevision: UInt64
  var receipts: [ScriptFinanceReceipt] = []
  var remaining: Int { receipts.last?.afterPrincipal ?? 0 }
  var status: ScriptFinanceStatus {
    guard let first = receipts.first else { return .offered }
    if first.operation == .decline { return .declined }
    return remaining == 0 ? .paid : .outstanding
  }
  func valid(owner: UUID, revision: UInt64) -> Bool {
    guard terms.valid, source.valid, id == source.identity(owner: owner, loan: terms.id),
      source.cause.galaxy == terms.galaxy, source.cause.system == terms.system,
      source.cause.nativeMainDock.map({
        $0.commanderOwner == owner && $0.station == terms.station(owner: owner)
          && $0.calendarSeconds <= source.cause.calendarSeconds
      }) ?? true,
      createdRevision > 0, createdRevision <= revision,
      receipts.count <= ScriptFinanceLedger.maximumReceipts
    else { return false }
    var previousRevision = createdRevision
    var previousTime = source.cause.calendarSeconds
    var previousDock = source.cause.nativeMainDock?.sequence ?? 0
    var remaining = 0
    for (index, receipt) in receipts.enumerated() {
      guard receipt.id == ScriptFinanceReceipt.identity(id, revision: receipt.revision),
        receipt.obligation == id, receipt.revision > previousRevision, receipt.revision <= revision,
        receipt.dock.valid, receipt.dock.station == terms.station(owner: owner),
        receipt.dock.sequence >= previousDock,
        receipt.calendarSeconds.isFinite, (previousTime...1e12).contains(receipt.calendarSeconds),
        receipt.dock.calendarSeconds <= receipt.calendarSeconds,
        [receipt.beforeCash, receipt.afterCash, receipt.beforePrincipal, receipt.afterPrincipal]
          .allSatisfy({ (0...4_294_967_295).contains($0) }),
        receipt.beforePrincipal == remaining
      else { return false }
      switch receipt.operation {
      case .borrow:
        guard index == 0, receipt.amount == terms.principal,
          receipt.beforeCash <= 4_294_967_295 - terms.principal,
          receipt.afterCash == receipt.beforeCash + terms.principal,
          receipt.afterPrincipal == terms.principal
        else { return false }
      case .decline:
        guard index == 0, receipts.count == 1, receipt.amount == 0,
          receipt.afterCash == receipt.beforeCash, receipt.afterPrincipal == 0
        else { return false }
      case .repay:
        guard index > 0, remaining > 0, receipt.beforeCash > 0,
          receipt.amount == min(receipt.beforeCash, remaining),
          receipt.afterCash == receipt.beforeCash - receipt.amount,
          receipt.afterPrincipal == remaining - receipt.amount
        else { return false }
      }
      remaining = receipt.afterPrincipal
      previousRevision = receipt.revision
      previousTime = receipt.calendarSeconds
      previousDock = receipt.dock.sequence
    }
    return true
  }

  private enum CodingKeys: String, CodingKey { case id, terms, source, createdRevision, receipts }
  init(
    id: UUID, terms: ScriptFinanceDefinition, source: ScriptFinanceSource, createdRevision: UInt64
  ) {
    self.id = id
    self.terms = terms
    self.source = source
    self.createdRevision = createdRevision
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    terms = try values.decode(ScriptFinanceDefinition.self, forKey: .terms)
    source = try values.decode(ScriptFinanceSource.self, forKey: .source)
    createdRevision = try values.decode(UInt64.self, forKey: .createdRevision)
    var entries = try values.nestedUnkeyedContainer(forKey: .receipts)
    guard (entries.count ?? 0) <= ScriptFinanceLedger.maximumReceipts else {
      throw DecodingError.dataCorruptedError(
        in: entries, debugDescription: "Finance receipt limit exceeded.")
    }
    while !entries.isAtEnd {
      guard receipts.count < ScriptFinanceLedger.maximumReceipts else {
        throw DecodingError.dataCorruptedError(
          in: entries, debugDescription: "Finance receipt limit exceeded.")
      }
      receipts.append(try entries.decode(ScriptFinanceReceipt.self))
    }
  }
}

struct ScriptFinanceLedger: Codable, Sendable, Equatable {
  static let maximumRecords = 128
  static let maximumReceipts = 1024
  let owner: UUID
  var revision: UInt64 = 0
  var records: [ScriptFinanceRecord] = []
  var receiptCount: Int { records.reduce(0) { $0 + $1.receipts.count } }
  var valid: Bool {
    guard !records.isEmpty, records.count <= Self.maximumRecords,
      records.allSatisfy({ $0.valid(owner: owner, revision: revision) }),
      receiptCount <= Self.maximumReceipts, Set(records.map(\.id)).count == records.count
    else { return false }
    let receipts = records.flatMap(\.receipts)
    let revisions = records.map(\.createdRevision) + receipts.map(\.revision)
    return revision == UInt64(revisions.count)
      && revisions.sorted() == Array(1...revision)
      && Set(receipts.map(\.token)).count == receipts.count
      && Set(receipts.map(\.id)).count == receipts.count
  }
  func valid(engine: ScriptEngineState) -> Bool {
    valid
      && records.allSatisfy { record in
        record.source.sequence <= engine.nextEvent
          && record.source.cause.calendarSeconds <= engine.calendarSeconds
          && (record.receipts.last?.calendarSeconds ?? 0) <= engine.calendarSeconds
          && (engine.instances[record.source.instance].map {
            record.source.matches($0) && $0.hasAcknowledged(record.source.sequence)
              && record.source.cause.revision < $0.revision
          } ?? true)
      }
  }
  private enum CodingKeys: String, CodingKey { case owner, revision, records }
  init(owner: UUID) { self.owner = owner }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    owner = try values.decode(UUID.self, forKey: .owner)
    revision = try values.decode(UInt64.self, forKey: .revision)
    var entries = try values.nestedUnkeyedContainer(forKey: .records)
    guard (entries.count ?? 0) <= Self.maximumRecords else {
      throw DecodingError.dataCorruptedError(
        in: entries, debugDescription: "Finance record limit exceeded.")
    }
    var count = 0
    while !entries.isAtEnd {
      guard records.count < Self.maximumRecords else {
        throw DecodingError.dataCorruptedError(
          in: entries, debugDescription: "Finance record limit exceeded.")
      }
      let record = try entries.decode(ScriptFinanceRecord.self)
      count += record.receipts.count
      guard count <= Self.maximumReceipts else { throw SaveError.invalidCommander }
      records.append(record)
    }
  }
}

extension Commander {
  var financeStateValid: Bool {
    guard let ledger = scriptState.financeLedger else { return true }
    guard ledger.owner == equipmentOwnerID, ledger.valid(engine: scriptState) else { return false }
    return ledger.records.allSatisfy { record in
      let docks =
        record.receipts.map(\.dock) + (record.source.cause.nativeMainDock.map { [$0] } ?? [])
      return docks.allSatisfy { dock in
        guard let world = nativeStations else { return false }
        return world.ledger.world == ledger.owner && world.mainStations.contains(dock.station)
          && dock.sequence < world.nextMainDockSequence
      }
    }
  }
}
