import Foundation

public struct EquipmentFamilyID: Hashable, Codable, Sendable {
  public let rawValue: String
  public init(_ rawValue: String) { self.rawValue = rawValue }
}

/// Keys are saved equipment identities; display labels must not be parsed as tier numbers.
public struct EquipmentNodeID: Hashable, Codable, Sendable {
  public let family: EquipmentFamilyID
  public let key: String
  public init(family: EquipmentFamilyID, key: String) {
    self.family = family
    self.key = key
  }
}

public struct EquipmentFittingLocation: Hashable, Codable, Sendable {
  public let hull: UUID
  public let slot: String
  public init(hull: UUID, slot: String) {
    self.hull = hull
    self.slot = slot
  }
}

public enum EquipmentPurchasePolicy: Equatable, Codable, Sendable {
  case standardFoundation, shop, acquisitionOnly
  /// A current physical count is mandatory, including held units and known non-paid acquisitions.
  case repeatable(maximumCount: Int)
}

public struct EquipmentPurchaseNode: Equatable, Codable, Sendable {
  public let id: EquipmentNodeID
  public let displayName: String
  public let policy: EquipmentPurchasePolicy
  public let prerequisites: [EquipmentNodeID]
  /// Installation and paid history are independent requirements. A higher installed descendant
  /// can supply the declared core, but cannot supply its missing paid purchase history.
  public let fittedPrerequisites: [EquipmentNodeID]
  public init(
    id: EquipmentNodeID, displayName: String, policy: EquipmentPurchasePolicy = .shop,
    prerequisites: [EquipmentNodeID] = [], fittedPrerequisites: [EquipmentNodeID] = []
  ) {
    self.id = id
    self.displayName = displayName
    self.policy = policy
    self.prerequisites = prerequisites
    self.fittedPrerequisites = fittedPrerequisites
  }
}

public struct EquipmentPurchaseAlias: Equatable, Codable, Sendable {
  public let alias: EquipmentNodeID
  public let canonical: EquipmentNodeID
  public init(alias: EquipmentNodeID, canonical: EquipmentNodeID) {
    self.alias = alias
    self.canonical = canonical
  }
}

public struct EquipmentPurchaseGraph: Equatable, Codable, Sendable {
  public let revision: Int
  public let nodes: [EquipmentPurchaseNode]
  public let aliases: [EquipmentPurchaseAlias]
  public init(revision: Int, nodes: [EquipmentPurchaseNode], aliases: [EquipmentPurchaseAlias] = [])
  {
    self.revision = revision
    self.nodes = nodes
    self.aliases = aliases
  }
}

public enum EquipmentAcquisitionProvenance: Equatable, Codable, Sendable {
  case standard
  case paid(owner: UUID, transaction: UUID)
  case grant(String)
  case recovered(SalvageLotIdentity)
  case reward(String)
  case earned(String)
  case xyzzy
  /// Only a migration adapter with genuinely unknown historical acquisition may use this case.
  case legacyUnknown
}

public struct EquipmentPurchaseItem: Equatable, Codable, Sendable {
  public let id: UUID
  public let node: EquipmentNodeID
  public let location: EquipmentFittingLocation?
  public let provenance: EquipmentAcquisitionProvenance
  public init(
    id: UUID, node: EquipmentNodeID, location: EquipmentFittingLocation? = nil,
    provenance: EquipmentAcquisitionProvenance
  ) {
    self.id = id
    self.node = node
    self.location = location
    self.provenance = provenance
  }
}

public struct EquipmentLegacyEntitlement: Equatable, Codable, Sendable {
  public let owner: UUID
  public let source: EquipmentPurchaseItem
  public let lineage: Set<EquipmentNodeID>
  fileprivate init(owner: UUID, source: EquipmentPurchaseItem, lineage: Set<EquipmentNodeID>) {
    self.owner = owner
    self.source = source
    self.lineage = lineage
  }
}

public struct EquipmentPurchaseOffer: Equatable, Codable, Sendable {
  public let node: EquipmentNodeID
  /// Tenths of a credit, matching Commander cash. The caller supplies the authoritative shop price.
  public let price: Int
  public let shop: String
  public let revision: UInt64
  public init(node: EquipmentNodeID, price: Int, shop: String, revision: UInt64) {
    self.node = node
    self.price = price
    self.shop = shop
    self.revision = revision
  }
}

public struct EquipmentPurchaseSnapshot: Equatable, Codable, Sendable {
  /// Commander/ledger identity, never the current hull UUID.
  public let owner: UUID
  public let activeHull: UUID
  /// Must change for every relevant cash, item, provenance, fitting or physical-count mutation.
  public let revision: UInt64
  public let funds: Int
  public let items: [EquipmentPurchaseItem]
  public init(
    owner: UUID, activeHull: UUID, revision: UInt64, funds: Int,
    items: [EquipmentPurchaseItem]
  ) {
    self.owner = owner
    self.activeHull = activeHull
    self.revision = revision
    self.funds = funds
    self.items = items
  }
}

public struct EquipmentPurchaseRequest: Equatable, Codable, Sendable {
  public let transaction: UUID
  public let newItem: UUID
  public let offer: EquipmentPurchaseOffer
  public let location: EquipmentFittingLocation?
  public init(
    transaction: UUID, newItem: UUID, offer: EquipmentPurchaseOffer,
    location: EquipmentFittingLocation? = nil
  ) {
    self.transaction = transaction
    self.newItem = newItem
    self.offer = offer
    self.location = location
  }
}

/// Complete relevant original quote binding is persisted for replay/conflict diagnosis.
public struct EquipmentPurchaseBinding: Equatable, Codable, Sendable {
  public let request: EquipmentPurchaseRequest
  public let snapshot: EquipmentPurchaseSnapshot
  public let historyRevision: UInt64
  public let graphRevision: Int
  public let lineage: [EquipmentPurchaseNode]
}

public struct EquipmentPaidPurchaseReceipt: Equatable, Codable, Sendable {
  public let owner: UUID
  public let node: EquipmentNodeID
  public let binding: EquipmentPurchaseBinding
  public var transaction: UUID { binding.request.transaction }
  public var price: Int { binding.request.offer.price }
}

public struct EquipmentPurchaseHistory: Equatable, Codable, Sendable {
  public let owner: UUID
  public let revision: UInt64
  public let paid: [EquipmentPaidPurchaseReceipt]
  public let legacy: [EquipmentLegacyEntitlement]
  public init(
    owner: UUID, revision: UInt64 = 0, paid: [EquipmentPaidPurchaseReceipt] = [],
    legacy: [EquipmentLegacyEntitlement] = []
  ) {
    self.owner = owner
    self.revision = revision
    self.paid = paid
    self.legacy = legacy
  }
}

public struct EquipmentPurchaseQuote: Sendable {
  public let node: EquipmentNodeID
  public let requiredDebit: Int
  public let binding: EquipmentPurchaseBinding
  fileprivate let graph: EquipmentPurchaseGraph
  fileprivate let history: EquipmentPurchaseHistory
}

public struct EquipmentPurchaseApplication: Sendable {
  public let history: EquipmentPurchaseHistory
  public let receipt: EquipmentPaidPurchaseReceipt
  public let item: EquipmentPurchaseItem
  public let requiredDebit: Int
  public let expectedSnapshotRevision: UInt64
  public let expectedHistoryRevision: UInt64
}

public enum EquipmentPurchaseError: Error, Equatable, Sendable {
  case invalidGraph
  case unknownNode(EquipmentNodeID)
  case notForSale(EquipmentNodeID)
  case invalidHistory, invalidSnapshot, invalidRequest, ownerMismatch
  case missingPrerequisite(EquipmentNodeID)
  case missingFittedPrerequisite(EquipmentNodeID)
  case maximumCount(EquipmentNodeID, Int)
  case insufficientFunds, staleQuote
  case replayedTransaction, conflictingTransaction, legacyProvenanceRequired
}

/// Pure eligibility/receipt planning. It cannot charge cash, install equipment or grant capability.
/// Caller must revalidate/apply on copied authoritative state, debit the exact required amount,
/// install the returned item and persist item+cash+history atomically. On failed save, publish none
/// of that state. All purchase paths (including PLUGH/discounts) must supply current trusted offers.
/// A receipt is bookkeeping, not authentication of an untrusted save or an external shop offer.
public enum EquipmentPurchaseProgression {
  public static func validate(_ graph: EquipmentPurchaseGraph) throws {
    _ = try Prepared(graph)
  }

  public static func legacyEntitlement(
    for item: EquipmentPurchaseItem, owner: UUID, graph: EquipmentPurchaseGraph
  ) throws -> EquipmentLegacyEntitlement {
    guard item.provenance == .legacyUnknown else {
      throw EquipmentPurchaseError.legacyProvenanceRequired
    }
    let prepared = try Prepared(graph)
    let id = try prepared.resolve(item.node)
    let canonical = EquipmentPurchaseItem(
      id: item.id, node: id, location: item.location, provenance: .legacyUnknown)
    return .init(owner: owner, source: canonical, lineage: Set(prepared.lineage(id).map(\.id)))
  }

  public static func quote(
    request: EquipmentPurchaseRequest, snapshot: EquipmentPurchaseSnapshot,
    history: EquipmentPurchaseHistory, graph: EquipmentPurchaseGraph
  ) throws -> EquipmentPurchaseQuote {
    let prepared = try Prepared(graph)
    try validate(history, prepared: prepared)
    guard history.owner == snapshot.owner else { throw EquipmentPurchaseError.ownerMismatch }
    try validate(snapshot, prepared: prepared)
    try checkReplay(request, snapshot: snapshot, history: history, graph: graph, prepared: prepared)
    guard request.offer.price > 0, !request.offer.shop.isEmpty,
      request.location.map({ !$0.slot.isEmpty }) ?? true,
      request.location.map({ $0.hull == snapshot.activeHull }) ?? true,
      !snapshot.items.contains(where: { $0.id == request.newItem }),
      !history.paid.contains(where: { $0.binding.request.newItem == request.newItem })
    else { throw EquipmentPurchaseError.invalidRequest }
    let id = try prepared.resolve(request.offer.node)
    let node = prepared.nodes[id]!
    switch node.policy {
    case .standardFoundation, .acquisitionOnly: throw EquipmentPurchaseError.notForSale(id)
    case .shop: break
    case .repeatable(let maximum):
      let count = snapshot.items.filter { $0.node == id }.count
      guard count < maximum else { throw EquipmentPurchaseError.maximumCount(id, maximum) }
    }
    let lineage = prepared.lineage(id)
    let entitled = Set(history.paid.map(\.node)).union(history.legacy.flatMap(\.lineage))
    for ancestor in lineage where ancestor.id != id {
      if ancestor.policy != .standardFoundation && !entitled.contains(ancestor.id) {
        throw EquipmentPurchaseError.missingPrerequisite(ancestor.id)
      }
    }
    for required in node.fittedPrerequisites {
      let installed = snapshot.items.contains { item in
        guard item.location?.hull == snapshot.activeHull, item.node.family == required.family else {
          return false
        }
        return prepared.lineage(item.node).contains { $0.id == required }
      }
      guard installed else { throw EquipmentPurchaseError.missingFittedPrerequisite(required) }
    }
    guard snapshot.funds >= request.offer.price else {
      throw EquipmentPurchaseError.insufficientFunds
    }
    let binding = EquipmentPurchaseBinding(
      request: request, snapshot: snapshot, historyRevision: history.revision,
      graphRevision: graph.revision, lineage: lineage)
    return .init(
      node: id, requiredDebit: request.offer.price, binding: binding, graph: graph,
      history: history)
  }

  public static func apply(
    _ quote: EquipmentPurchaseQuote, request: EquipmentPurchaseRequest,
    snapshot: EquipmentPurchaseSnapshot, history: EquipmentPurchaseHistory,
    graph: EquipmentPurchaseGraph
  ) throws -> EquipmentPurchaseApplication {
    if let receipt = history.paid.first(where: { $0.transaction == request.transaction }) {
      guard receipt.binding == quote.binding, request == quote.binding.request,
        snapshot == quote.binding.snapshot, graph == quote.graph
      else {
        throw EquipmentPurchaseError.conflictingTransaction
      }
      throw EquipmentPurchaseError.replayedTransaction
    }
    guard request == quote.binding.request, snapshot == quote.binding.snapshot,
      history == quote.history, graph == quote.graph
    else { throw EquipmentPurchaseError.staleQuote }
    let checked = try Self.quote(
      request: request, snapshot: snapshot, history: history, graph: graph)
    guard checked.binding == quote.binding, history.revision < UInt64.max else {
      throw EquipmentPurchaseError.staleQuote
    }
    let receipt = EquipmentPaidPurchaseReceipt(
      owner: history.owner, node: quote.node,
      binding: checked.binding)
    let item = EquipmentPurchaseItem(
      id: request.newItem, node: quote.node, location: request.location,
      provenance: .paid(owner: history.owner, transaction: request.transaction))
    return .init(
      history: .init(
        owner: history.owner, revision: history.revision + 1,
        paid: history.paid + [receipt], legacy: history.legacy),
      receipt: receipt, item: item, requiredDebit: quote.requiredDebit,
      expectedSnapshotRevision: snapshot.revision, expectedHistoryRevision: history.revision)
  }

  private static func checkReplay(
    _ request: EquipmentPurchaseRequest, snapshot: EquipmentPurchaseSnapshot,
    history: EquipmentPurchaseHistory, graph: EquipmentPurchaseGraph, prepared: Prepared
  ) throws {
    guard let previous = history.paid.first(where: { $0.transaction == request.transaction }) else {
      return
    }
    guard previous.binding.request == request, previous.binding.snapshot == snapshot,
      previous.binding.graphRevision == graph.revision,
      previous.binding.lineage == prepared.lineage(previous.node)
    else {
      throw EquipmentPurchaseError.conflictingTransaction
    }
    throw EquipmentPurchaseError.replayedTransaction
  }

  private static func validate(_ history: EquipmentPurchaseHistory, prepared: Prepared) throws {
    guard history.paid.count <= 100_000, history.legacy.count <= 1024,
      Set(history.paid.map(\.transaction)).count == history.paid.count,
      Set(history.paid.map { $0.binding.request.newItem }).count == history.paid.count,
      Set(history.legacy.map { $0.source.id }).count == history.legacy.count,
      history.paid.allSatisfy({ receipt in
        receipt.owner == history.owner && receipt.binding.snapshot.owner == history.owner
          && prepared.nodes[receipt.node] != nil
          && prepared.nodes[receipt.node]?.policy != .standardFoundation && receipt.price > 0
          && (try? prepared.resolve(receipt.binding.request.offer.node)) == receipt.node
          && receipt.binding.historyRevision < history.revision
      })
    else { throw EquipmentPurchaseError.invalidHistory }
    for entitlement in history.legacy {
      guard entitlement.owner == history.owner, entitlement.source.provenance == .legacyUnknown,
        prepared.nodes[entitlement.source.node] != nil,
        entitlement.lineage == Set(prepared.lineage(entitlement.source.node).map(\.id))
      else { throw EquipmentPurchaseError.invalidHistory }
    }
  }

  private static func validate(_ snapshot: EquipmentPurchaseSnapshot, prepared: Prepared) throws {
    guard snapshot.funds >= 0, snapshot.items.count <= 100_000,
      Set(snapshot.items.map(\.id)).count == snapshot.items.count,
      snapshot.items.allSatisfy({
        prepared.nodes[$0.node] != nil && ($0.location.map { !$0.slot.isEmpty } ?? true)
      })
    else { throw EquipmentPurchaseError.invalidSnapshot }
  }

  private struct Prepared {
    let nodes: [EquipmentNodeID: EquipmentPurchaseNode]
    let aliases: [EquipmentNodeID: EquipmentNodeID]
    init(_ graph: EquipmentPurchaseGraph) throws {
      guard graph.revision > 0, !graph.nodes.isEmpty, graph.nodes.count <= 1024,
        graph.aliases.count <= 4096,
        Set(graph.nodes.map(\.id)).count == graph.nodes.count,
        Set(graph.aliases.map(\.alias)).count == graph.aliases.count
      else { throw EquipmentPurchaseError.invalidGraph }
      nodes = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
      aliases = Dictionary(uniqueKeysWithValues: graph.aliases.map { ($0.alias, $0.canonical) })
      for node in graph.nodes {
        guard !node.id.family.rawValue.isEmpty, !node.id.key.isEmpty, !node.displayName.isEmpty,
          Set(node.prerequisites).count == node.prerequisites.count,
          Set(node.fittedPrerequisites).count == node.fittedPrerequisites.count,
          node.prerequisites.allSatisfy({ nodes[$0] != nil }),
          node.fittedPrerequisites.allSatisfy({ nodes[$0] != nil })
        else { throw EquipmentPurchaseError.invalidGraph }
        if node.policy == .standardFoundation && !node.prerequisites.isEmpty {
          throw EquipmentPurchaseError.invalidGraph
        }
        if case .repeatable(let count) = node.policy, !(1...10_000).contains(count) {
          throw EquipmentPurchaseError.invalidGraph
        }
      }
      for alias in graph.aliases {
        guard nodes[alias.alias] == nil, nodes[alias.canonical] != nil,
          alias.alias.family == alias.canonical.family, !alias.alias.key.isEmpty
        else { throw EquipmentPurchaseError.invalidGraph }
      }
      var visiting: Set<EquipmentNodeID> = []
      var done: Set<EquipmentNodeID> = []
      func visit(_ id: EquipmentNodeID) throws {
        if done.contains(id) { return }
        guard visiting.insert(id).inserted else { throw EquipmentPurchaseError.invalidGraph }
        for parent in nodes[id]!.prerequisites { try visit(parent) }
        visiting.remove(id)
        done.insert(id)
      }
      for node in graph.nodes { try visit(node.id) }
      for node in graph.nodes {
        guard Set(node.fittedPrerequisites).isSubset(of: Set(lineage(node.id).map(\.id))) else {
          throw EquipmentPurchaseError.invalidGraph
        }
      }
    }
    func resolve(_ id: EquipmentNodeID) throws -> EquipmentNodeID {
      if nodes[id] != nil { return id }
      guard let canonical = aliases[id] else { throw EquipmentPurchaseError.unknownNode(id) }
      return canonical
    }
    /// Stable ancestors-before-child order; independent branches never depend on row order.
    func lineage(_ id: EquipmentNodeID) -> [EquipmentPurchaseNode] {
      var result: [EquipmentPurchaseNode] = []
      var visited: Set<EquipmentNodeID> = []
      func append(_ key: EquipmentNodeID) {
        guard visited.insert(key).inserted, let node = nodes[key] else { return }
        for parent in node.prerequisites.sorted(by: Self.less) { append(parent) }
        result.append(node)
      }
      append(id)
      return result
    }
    static func less(_ a: EquipmentNodeID, _ b: EquipmentNodeID) -> Bool {
      a.family.rawValue == b.family.rawValue ? a.key < b.key : a.family.rawValue < b.family.rawValue
    }
  }
}

/// Known modular lineages. Other families must declare their real prerequisites/repeatable policy;
/// unknown shop entries are refused rather than inferred from names, prices or catalogue order.
public enum EquipmentPurchaseCatalog {
  public static let navigation = EquipmentFamilyID("navigation")
  public static let energy = EquipmentFamilyID("energy")
  public static let shields = EquipmentFamilyID("shields")
  public static let targeting = EquipmentFamilyID("targeting-core")
  public static let mining = EquipmentFamilyID("targeting-mining")
  public static let salvage = EquipmentFamilyID("targeting-salvage")

  public static func id(_ family: EquipmentFamilyID, _ key: String) -> EquipmentNodeID {
    .init(family: family, key: key)
  }

  /// Keeps legacy saved keys even where display names changed. Elite shield shop availability
  /// remains an explicit caller policy: earned/XYZZY acquisition is independent in either case.
  public static func modularGraph(eliteShieldForSale: Bool = false) -> EquipmentPurchaseGraph {
    var nodes: [EquipmentPurchaseNode] = []
    var aliases: [EquipmentPurchaseAlias] = []
    func chain(_ family: EquipmentFamilyID, _ rows: [(String, String)], standard: Bool) {
      for (index, row) in rows.enumerated() {
        let key = id(family, row.0)
        nodes.append(
          .init(
            id: key, displayName: row.1,
            policy: index == 0 && standard ? .standardFoundation : .shop,
            prerequisites: index == 0 ? [] : [id(family, rows[index - 1].0)]))
        if row.0 != row.1 {
          aliases.append(.init(alias: id(family, row.1), canonical: key))
        }
      }
    }
    chain(
      navigation,
      [
        ("Navigation: Basic", "Basic Navigation Computer"),
        ("Navigation: Advanced", "Intermediate Navigation Module"),
        ("Navigation: Military", "Advanced Navigation Module"),
      ], standard: true)
    chain(
      energy,
      [
        ("Basic Energy System", "Basic Energy System"),
        ("Extra Energy Unit", "Intermediate Energy Module"),
        ("Naval Energy Unit", "Advanced Energy Module"),
      ], standard: true)
    chain(
      shields,
      [
        ("Basic Shield", "Basic Shield"),
        ("Pulse Shield Booster", "Basic II Shield Module"),
        ("Mining Shield Booster", "Intermediate Shield Module"),
        ("Beam Shield Booster", "Intermediate II Shield Module"),
        ("Military Shield Booster", "Advanced Shield Module"),
        ("Capital Ship Shield Booster", "Advanced II Shield Module"),
      ], standard: true)
    nodes.append(
      .init(
        id: id(shields, "Elite Shield Module"), displayName: "Elite Shield Module",
        policy: eliteShieldForSale ? .shop : .acquisitionOnly,
        prerequisites: [id(shields, "Capital Ship Shield Booster")]))
    for (alias, key) in [
      ("Pulse Shield Module", "Pulse Shield Booster"),
      ("Mining Shield Module", "Mining Shield Booster"),
      ("Beam Shield Module", "Beam Shield Booster"),
      ("Military Shield Module", "Military Shield Booster"),
      ("Capital Ship Shield Module", "Capital Ship Shield Booster"),
      ("Intermediary Shield Module", "Mining Shield Booster"),
      ("Intermediary II Shield Module", "Beam Shield Booster"),
    ] {
      aliases.append(.init(alias: id(shields, alias), canonical: id(shields, key)))
    }
    chain(
      targeting,
      ["Basic", "Advanced", "Docking", "Identification", "Pirate", "Military"].map {
        ("Targeting: " + $0, $0 + " Targeting Module")
      }, standard: false)
    aliases.append(
      .init(
        alias: id(targeting, "Docking Computers"),
        canonical: id(targeting, "Targeting: Docking")))
    let basic = id(targeting, "Targeting: Basic")
    for (family, name) in [(mining, "Mining"), (salvage, "Salvage")] {
      nodes.append(
        .init(
          id: id(family, "Targeting: " + name + " Module"), displayName: name + " Targeting Module",
          prerequisites: [basic], fittedPrerequisites: [basic]))
    }
    return .init(revision: 1, nodes: nodes, aliases: aliases)
  }
}
