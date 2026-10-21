import Foundation
import Testing

@testable import EliteCore

private let epOwner = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
private let epHull = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
private let epOther = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
private let epGraph = EquipmentPurchaseCatalog.modularGraph(eliteShieldForSale: true)
private func epID(_ family: EquipmentFamilyID, _ key: String) -> EquipmentNodeID {
  EquipmentPurchaseCatalog.id(family, key)
}
private func epUUID(_ number: Int) -> UUID {
  UUID(uuidString: String(format: "40000000-0000-0000-0000-%012d", number))!
}
private func epSnapshot(
  owner: UUID = epOwner, hull: UUID = epHull, revision: UInt64 = 0,
  funds: Int = 1_000_000, items: [EquipmentPurchaseItem] = []
) -> EquipmentPurchaseSnapshot {
  .init(owner: owner, activeHull: hull, revision: revision, funds: funds, items: items)
}
private func epRequest(
  _ node: EquipmentNodeID, number: Int = 1, price: Int = 100, shop: String = "station",
  offerRevision: UInt64 = 1, location: EquipmentFittingLocation? = nil
) -> EquipmentPurchaseRequest {
  .init(
    transaction: epUUID(number), newItem: epUUID(number + 1000),
    offer: .init(node: node, price: price, shop: shop, revision: offerRevision),
    location: location)
}
private func epPurchase(
  _ request: EquipmentPurchaseRequest, snapshot: EquipmentPurchaseSnapshot = epSnapshot(),
  history: EquipmentPurchaseHistory, graph: EquipmentPurchaseGraph = epGraph
) throws -> EquipmentPurchaseApplication {
  let quote = try EquipmentPurchaseProgression.quote(
    request: request, snapshot: snapshot, history: history, graph: graph)
  return try EquipmentPurchaseProgression.apply(
    quote, request: request, snapshot: snapshot, history: history, graph: graph)
}
private func epPaidChain(_ ids: [EquipmentNodeID]) throws -> EquipmentPurchaseHistory {
  var history = EquipmentPurchaseHistory(owner: epOwner)
  for (index, id) in ids.enumerated() {
    history = try epPurchase(epRequest(id, number: index + 1), history: history).history
  }
  return history
}

@Test func equipmentPurchaseValidatesGraphAndChecksEntireShieldChainInStableOrder() throws {
  try EquipmentPurchaseProgression.validate(epGraph)
  let family = EquipmentPurchaseCatalog.shields
  let first = epID(family, "Pulse Shield Booster")
  let last = epID(family, "Capital Ship Shield Booster")
  let empty = EquipmentPurchaseHistory(owner: epOwner)
  #expect(throws: EquipmentPurchaseError.missingPrerequisite(first)) {
    try epPurchase(epRequest(last), history: empty)
  }
  let intermediate = epID(family, "Mining Shield Booster")
  let history = try epPaidChain([first, intermediate])
  #expect(throws: EquipmentPurchaseError.missingPrerequisite(epID(family, "Beam Shield Booster"))) {
    try epPurchase(epRequest(last, number: 10), history: history)
  }
  let complete = try epPaidChain([
    first, intermediate, epID(family, "Beam Shield Booster"),
    epID(family, "Military Shield Booster"), last,
  ])
  let result = try epPurchase(
    epRequest(epID(family, "Elite Shield Module"), number: 10),
    history: complete)
  #expect(result.history.paid.count == 6 && result.receipt.price == 100)
  #expect(result.history.paid.allSatisfy { $0.node.key != "Basic Shield" })
}

@Test func equipmentPurchaseStandardFoundationsNeverInventPaidReceipts() throws {
  for (family, basic, first, advanced) in [
    (
      EquipmentPurchaseCatalog.navigation, "Navigation: Basic", "Navigation: Advanced",
      "Navigation: Military"
    ),
    (
      EquipmentPurchaseCatalog.energy, "Basic Energy System", "Extra Energy Unit",
      "Naval Energy Unit"
    ),
  ] {
    let history = EquipmentPurchaseHistory(owner: epOwner)
    #expect(throws: EquipmentPurchaseError.notForSale(epID(family, basic))) {
      try epPurchase(epRequest(epID(family, basic)), history: history)
    }
    #expect(throws: EquipmentPurchaseError.missingPrerequisite(epID(family, first))) {
      try epPurchase(epRequest(epID(family, advanced)), history: history)
    }
    let bought = try epPurchase(epRequest(epID(family, first)), history: history)
    let upgraded = try epPurchase(
      epRequest(epID(family, advanced), number: 2), history: bought.history)
    #expect(upgraded.history.paid.count == 2)
    #expect(!upgraded.history.paid.contains { $0.node == epID(family, basic) })
  }
}

@Test func equipmentPurchaseLegacyNavigationAliasesKeepRawTierMeanings() throws {
  let family = EquipmentPurchaseCatalog.navigation
  let initial = EquipmentPurchaseHistory(owner: epOwner)
  let intermediate = try epPurchase(
    epRequest(epID(family, "Intermediate Navigation Module")),
    history: initial)
  #expect(intermediate.item.node.key == "Navigation: Advanced")
  let advanced = try epPurchase(
    epRequest(epID(family, "Advanced Navigation Module"), number: 2),
    history: intermediate.history)
  #expect(advanced.item.node.key == "Navigation: Military")
  #expect(advanced.history.paid.count == 2)
  let shield = try epPurchase(
    epRequest(epID(EquipmentPurchaseCatalog.shields, "Intermediary Shield Module"), number: 3),
    history: try epPaidChain([epID(EquipmentPurchaseCatalog.shields, "Pulse Shield Booster")]))
  #expect(shield.item.node.key == "Mining Shield Booster")
}

@Test func equipmentPurchaseSpecialistsRequirePaidAndInstalledBasicButNotEachOther() throws {
  let basic = epID(EquipmentPurchaseCatalog.targeting, "Targeting: Basic")
  let military = epID(EquipmentPurchaseCatalog.targeting, "Targeting: Military")
  let mining = epID(EquipmentPurchaseCatalog.mining, "Targeting: Mining Module")
  let salvage = epID(EquipmentPurchaseCatalog.salvage, "Targeting: Salvage Module")
  let location = EquipmentFittingLocation(hull: epHull, slot: "targeting")
  let xyzzy = EquipmentPurchaseItem(
    id: epUUID(20), node: military, location: location,
    provenance: .xyzzy)
  let snapshot = epSnapshot(items: [xyzzy])
  #expect(throws: EquipmentPurchaseError.missingPrerequisite(basic)) {
    try epPurchase(epRequest(mining), snapshot: snapshot, history: .init(owner: epOwner))
  }
  let paid = try epPaidChain([basic])
  #expect(throws: EquipmentPurchaseError.missingFittedPrerequisite(basic)) {
    try epPurchase(epRequest(mining, number: 2), history: paid)
  }
  let result = try epPurchase(epRequest(mining, number: 2), snapshot: snapshot, history: paid)
  let other = try epPurchase(epRequest(salvage, number: 3), snapshot: snapshot, history: paid)
  #expect(result.history.paid.count == 2 && other.history.paid.count == 2)
  #expect(!result.history.paid.contains { $0.node == salvage })
  #expect(!other.history.paid.contains { $0.node == mining })
  let wrongHull = epSnapshot(hull: epOther, items: [xyzzy])
  #expect(throws: EquipmentPurchaseError.missingFittedPrerequisite(basic)) {
    try epPurchase(epRequest(salvage, number: 4), snapshot: wrongHull, history: paid)
  }
  let specialistOnly = EquipmentPurchaseItem(
    id: epUUID(21), node: mining, location: location, provenance: .earned("mining"))
  #expect(throws: EquipmentPurchaseError.missingFittedPrerequisite(basic)) {
    try epPurchase(
      epRequest(salvage, number: 4), snapshot: epSnapshot(items: [specialistOnly]),
      history: paid)
  }
}

@Test func equipmentPurchaseKnownGrantsRewardsRecoveredAndEarnedNeverBecomePaidAncestors() throws {
  let family = EquipmentPurchaseCatalog.energy
  let first = epID(family, "Extra Energy Unit")
  let next = epID(family, "Naval Energy Unit")
  let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 4, lineage: 400)
  let lot = SalvageLotIdentity(section: .init(wreck: wreck, section: 1), lot: 1)
  let sources: [EquipmentAcquisitionProvenance] = [
    .grant("developer"), .reward("naval"), .earned("numeric-promotion"), .xyzzy,
    .recovered(lot), .paid(owner: epOther, transaction: epUUID(99)),
  ]
  for source in sources {
    let item = EquipmentPurchaseItem(id: epUUID(20), node: first, provenance: source)
    #expect(throws: EquipmentPurchaseError.missingPrerequisite(first)) {
      try epPurchase(
        epRequest(next), snapshot: epSnapshot(items: [item]),
        history: .init(owner: epOwner))
    }
    #expect(throws: EquipmentPurchaseError.legacyProvenanceRequired) {
      try EquipmentPurchaseProgression.legacyEntitlement(for: item, owner: epOwner, graph: epGraph)
    }
  }
}

@Test func equipmentPurchaseExplicitLegacyLineagePreservesStrengthWithoutFictionalPayments() throws
{
  let family = EquipmentPurchaseCatalog.shields
  let old = EquipmentPurchaseItem(
    id: epUUID(40), node: epID(family, "Military Shield Booster"),
    provenance: .legacyUnknown)
  let entitlement = try EquipmentPurchaseProgression.legacyEntitlement(
    for: old, owner: epOwner, graph: epGraph)
  let history = EquipmentPurchaseHistory(owner: epOwner, legacy: [entitlement])
  let result = try epPurchase(
    epRequest(epID(family, "Capital Ship Shield Booster")), history: history)
  #expect(result.history.paid.count == 1 && result.history.legacy == [entitlement])
  #expect(entitlement.source == old && entitlement.lineage.count == 5)
  #expect(throws: EquipmentPurchaseError.invalidHistory) {
    try epPurchase(
      epRequest(epID(family, "Capital Ship Shield Booster")),
      snapshot: epSnapshot(owner: epOther),
      history: .init(owner: epOther, legacy: [entitlement]))
  }
  #expect(
    throws: EquipmentPurchaseError.missingPrerequisite(
      epID(EquipmentPurchaseCatalog.navigation, "Navigation: Advanced"))
  ) {
    try epPurchase(
      epRequest(epID(EquipmentPurchaseCatalog.navigation, "Navigation: Military"), number: 2),
      history: history)
  }
  #expect(throws: EquipmentPurchaseError.notForSale(epID(family, "Elite Shield Module"))) {
    try epPurchase(
      epRequest(epID(family, "Elite Shield Module"), number: 2), history: result.history,
      graph: EquipmentPurchaseCatalog.modularGraph())
  }
}

@Test func equipmentPurchaseHistorySurvivesRemovalHullExchangeAndSaveButCannotCrossCommanders()
  throws
{
  let family = EquipmentPurchaseCatalog.navigation
  let history = try epPaidChain([epID(family, "Navigation: Advanced")])
  let restored = try JSONDecoder().decode(
    EquipmentPurchaseHistory.self,
    from: JSONEncoder().encode(history))
  #expect(restored == history)
  let result = try epPurchase(
    epRequest(epID(family, "Navigation: Military"), number: 2),
    snapshot: epSnapshot(hull: epOther), history: restored)
  #expect(result.history.owner == epOwner && result.history.paid.count == 2)
  #expect(throws: EquipmentPurchaseError.ownerMismatch) {
    try epPurchase(
      epRequest(epID(family, "Navigation: Military"), number: 3),
      snapshot: epSnapshot(owner: epOther), history: restored)
  }
}

@Test func equipmentPurchaseQuoteBindsPriceShopHullItemsProvenanceAndBothRevisions() throws {
  let node = epID(EquipmentPurchaseCatalog.energy, "Extra Energy Unit")
  let history = EquipmentPurchaseHistory(owner: epOwner)
  let location = EquipmentFittingLocation(hull: epHull, slot: "energy")
  let request = epRequest(node, location: location)
  let old = EquipmentPurchaseItem(
    id: epUUID(50), node: epID(EquipmentPurchaseCatalog.energy, "Basic Energy System"),
    location: location, provenance: .standard)
  let snapshot = epSnapshot(items: [old])
  let quote = try EquipmentPurchaseProgression.quote(
    request: request, snapshot: snapshot,
    history: history, graph: epGraph)
  for changed in [
    epRequest(node, price: 90, location: location),
    epRequest(node, shop: "PLUGH", location: location),
    epRequest(node, offerRevision: 2, location: location),
    epRequest(node, location: .init(hull: epHull, slot: "other-slot")),
    epRequest(node, location: .init(hull: epOther, slot: "energy")),
  ] {
    #expect(throws: EquipmentPurchaseError.staleQuote) {
      try EquipmentPurchaseProgression.apply(
        quote, request: changed, snapshot: snapshot,
        history: history, graph: epGraph)
    }
  }
  let changedProvenance = EquipmentPurchaseItem(
    id: old.id, node: old.node, location: location,
    provenance: .xyzzy)
  for changed in [
    epSnapshot(revision: 1, items: [old]), epSnapshot(funds: 999999, items: [old]),
    epSnapshot(items: [changedProvenance]), epSnapshot(hull: epOther, items: [old]),
  ] {
    #expect(throws: EquipmentPurchaseError.staleQuote) {
      try EquipmentPurchaseProgression.apply(
        quote, request: request, snapshot: changed,
        history: history, graph: epGraph)
    }
  }
  #expect(throws: EquipmentPurchaseError.staleQuote) {
    try EquipmentPurchaseProgression.apply(
      quote, request: request, snapshot: snapshot,
      history: .init(owner: epOwner, revision: 1), graph: epGraph)
  }
  let graph = EquipmentPurchaseGraph(revision: 2, nodes: epGraph.nodes, aliases: epGraph.aliases)
  #expect(throws: EquipmentPurchaseError.staleQuote) {
    try EquipmentPurchaseProgression.apply(
      quote, request: request, snapshot: snapshot,
      history: history, graph: graph)
  }
  #expect(history.paid.isEmpty && snapshot.funds == 1_000_000 && snapshot.items == [old])
}

@Test func equipmentPurchaseReplayCannotDebitAgainAndChangedReplayIsAConflict() throws {
  let node = epID(EquipmentPurchaseCatalog.energy, "Extra Energy Unit")
  let request = epRequest(node)
  let snapshot = epSnapshot()
  let history = EquipmentPurchaseHistory(owner: epOwner)
  let quote = try EquipmentPurchaseProgression.quote(
    request: request, snapshot: snapshot,
    history: history, graph: epGraph)
  let result = try epPurchase(request, history: history)
  #expect(result.requiredDebit == 100 && result.expectedSnapshotRevision == 0)
  #expect(result.expectedHistoryRevision == 0 && result.history.revision == 1)
  #expect(result.item.provenance == .paid(owner: epOwner, transaction: request.transaction))
  #expect(throws: EquipmentPurchaseError.replayedTransaction) {
    try EquipmentPurchaseProgression.apply(
      quote, request: request, snapshot: snapshot,
      history: result.history, graph: epGraph)
  }
  #expect(throws: EquipmentPurchaseError.replayedTransaction) {
    try epPurchase(request, history: result.history)
  }
  #expect(throws: EquipmentPurchaseError.conflictingTransaction) {
    try EquipmentPurchaseProgression.apply(
      quote, request: epRequest(node, price: 90), snapshot: snapshot,
      history: result.history, graph: epGraph)
  }
  #expect(throws: EquipmentPurchaseError.conflictingTransaction) {
    try epPurchase(epRequest(node, price: 90), history: result.history)
  }
  let changed = epSnapshot(revision: 1, funds: 999900, items: [result.item])
  #expect(throws: EquipmentPurchaseError.conflictingTransaction) {
    try EquipmentPurchaseProgression.apply(
      quote, request: request, snapshot: changed, history: result.history, graph: epGraph)
  }
  #expect(throws: EquipmentPurchaseError.conflictingTransaction) {
    try epPurchase(request, snapshot: changed, history: result.history)
  }
  let reusedPhysicalID = EquipmentPurchaseRequest(
    transaction: epUUID(2), newItem: request.newItem,
    offer: request.offer)
  #expect(throws: EquipmentPurchaseError.invalidRequest) {
    try epPurchase(reusedPhysicalID, history: result.history)
  }
}

@Test func equipmentPurchaseRepeatablePolicyUsesAllPhysicalUnitsAndFiniteCapacity() throws {
  let family = EquipmentFamilyID("fuel-storage")
  let node = epID(family, "Fuel Storage")
  let graph = EquipmentPurchaseGraph(
    revision: 1,
    nodes: [
      .init(id: node, displayName: "Fuel Storage", policy: .repeatable(maximumCount: 2))
    ])
  let history = EquipmentPurchaseHistory(owner: epOwner)
  let held = EquipmentPurchaseItem(id: epUUID(50), node: node, provenance: .grant("one"))
  let fitted = EquipmentPurchaseItem(
    id: epUUID(51), node: node,
    location: .init(hull: epHull, slot: "tank"), provenance: .xyzzy)
  let result = try epPurchase(
    epRequest(node), snapshot: epSnapshot(items: [held]), history: history,
    graph: graph)
  #expect(result.history.paid.count == 1)
  #expect(throws: EquipmentPurchaseError.maximumCount(node, 2)) {
    try epPurchase(
      epRequest(node), snapshot: epSnapshot(items: [held, fitted]), history: history,
      graph: graph)
  }
}

@Test func equipmentPurchaseRejectsCyclesMissingParentsDuplicatesAndAmbiguousAliases() throws {
  let family = EquipmentFamilyID("test")
  let a = epID(family, "a")
  let b = epID(family, "b")
  let first = EquipmentPurchaseNode(id: a, displayName: "A")
  let graphs: [EquipmentPurchaseGraph] = [
    .init(revision: 1, nodes: [first, first]),
    .init(revision: 1, nodes: [.init(id: a, displayName: "A", prerequisites: [b])]),
    .init(revision: 1, nodes: [.init(id: a, displayName: "A", prerequisites: [a])]),
    .init(
      revision: 1,
      nodes: [
        .init(id: a, displayName: "A", prerequisites: [b]),
        .init(id: b, displayName: "B", prerequisites: [a]),
      ]),
    .init(
      revision: 1, nodes: [first],
      aliases: [.init(alias: b, canonical: a), .init(alias: b, canonical: a)]),
    .init(revision: 1, nodes: [first], aliases: [.init(alias: a, canonical: a)]),
    .init(revision: 1, nodes: [first], aliases: [.init(alias: b, canonical: b)]),
    .init(
      revision: 1,
      nodes: [
        .init(id: a, displayName: "A", fittedPrerequisites: [b]),
        .init(id: b, displayName: "B"),
      ]),
    .init(
      revision: 1, nodes: [.init(id: a, displayName: "A", policy: .repeatable(maximumCount: 0))]),
    .init(revision: 0, nodes: [first]),
  ]
  for graph in graphs {
    #expect(throws: EquipmentPurchaseError.invalidGraph) {
      try EquipmentPurchaseProgression.validate(graph)
    }
  }
}

@Test func equipmentPurchaseUnknownFamiliesFundsAndZeroPriceFailClosed() throws {
  let unknown = epID(.init("undeclared-drive"), "Advanced")
  let history = EquipmentPurchaseHistory(owner: epOwner)
  #expect(throws: EquipmentPurchaseError.unknownNode(unknown)) {
    try epPurchase(epRequest(unknown), history: history)
  }
  let first = epID(EquipmentPurchaseCatalog.energy, "Extra Energy Unit")
  #expect(throws: EquipmentPurchaseError.insufficientFunds) {
    try epPurchase(epRequest(first), snapshot: epSnapshot(funds: 99), history: history)
  }
  #expect(throws: EquipmentPurchaseError.invalidRequest) {
    try epPurchase(epRequest(first, price: 0), history: history)
  }
  #expect(history.paid.isEmpty && history.legacy.isEmpty)
}

@Test func equipmentPurchaseRejectsForgedHistoryAndInvalidPhysicalSnapshot() throws {
  let node = epID(EquipmentPurchaseCatalog.energy, "Extra Energy Unit")
  let request = epRequest(node)
  let result = try epPurchase(request, history: .init(owner: epOwner))
  let receipt = result.receipt
  let forged = EquipmentPaidPurchaseReceipt(
    owner: epOther, node: receipt.node, binding: receipt.binding)
  for history in [
    EquipmentPurchaseHistory(owner: epOwner, revision: 1, paid: [forged]),
    EquipmentPurchaseHistory(owner: epOwner, revision: 1, paid: [receipt, receipt]),
    EquipmentPurchaseHistory(owner: epOwner, revision: 0, paid: [receipt]),
  ] {
    #expect(throws: EquipmentPurchaseError.invalidHistory) {
      try epPurchase(epRequest(node, number: 2), history: history)
    }
  }
  let item = EquipmentPurchaseItem(id: epUUID(70), node: node, provenance: .grant("one"))
  for snapshot in [
    epSnapshot(funds: -1), epSnapshot(items: [item, item]),
    epSnapshot(items: [
      .init(id: item.id, node: epID(.init("unknown"), "unknown"), provenance: .xyzzy)
    ]),
  ] {
    #expect(throws: EquipmentPurchaseError.invalidSnapshot) {
      try epPurchase(request, snapshot: snapshot, history: .init(owner: epOwner))
    }
  }
  let alienLocation = EquipmentFittingLocation(hull: epOther, slot: "energy")
  #expect(throws: EquipmentPurchaseError.invalidRequest) {
    try epPurchase(epRequest(node, location: alienLocation), history: .init(owner: epOwner))
  }
}

@Test func equipmentPurchaseLegacyEntitlementCannotExpandBeyondItsRecordedLineage() throws {
  let node = epID(EquipmentPurchaseCatalog.energy, "Extra Energy Unit")
  let item = EquipmentPurchaseItem(id: epUUID(80), node: node, provenance: .legacyUnknown)
  let entitlement = try EquipmentPurchaseProgression.legacyEntitlement(
    for: item, owner: epOwner,
    graph: epGraph)
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(entitlement))
      as? [String: Any])
  object["lineage"] = try JSONSerialization.jsonObject(
    with: JSONEncoder().encode([
      node, epID(EquipmentPurchaseCatalog.targeting, "Targeting: Military"),
    ]))
  let forged = try JSONDecoder().decode(
    EquipmentLegacyEntitlement.self,
    from: JSONSerialization.data(withJSONObject: object))
  #expect(throws: EquipmentPurchaseError.invalidHistory) {
    try epPurchase(
      epRequest(epID(EquipmentPurchaseCatalog.energy, "Naval Energy Unit")),
      history: .init(owner: epOwner, legacy: [forged]))
  }
  let restored = try JSONDecoder().decode(
    EquipmentLegacyEntitlement.self,
    from: JSONEncoder().encode(entitlement))
  #expect(restored == entitlement && restored.owner == epOwner)
}
