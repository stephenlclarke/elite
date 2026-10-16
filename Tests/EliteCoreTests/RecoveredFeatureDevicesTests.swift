import Foundation
import Testing

@testable import EliteCore

private let featureIDs = [
  "feature-mining-targeting", "feature-salvage-targeting", "feature-fuel-scoops",
  "feature-ecm", "feature-salvage-cutter",
]
private let featureOwner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private let featureHull = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
private let featureCommand = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!

private func featureInventory(core: Bool = true, heldCore: Bool = false) throws
  -> (OwnedEquipmentInventory, OwnedEquipmentContext)
{
  let performance = try #require(ShipCatalogue.ship("SH023")?.game)
  let context = EquipmentRuntimeCatalog.context(
    owner: featureOwner, hull: featureHull, performance: performance)
  var items: [OwnedEquipmentItem] = []
  if core {
    let node = try #require(EquipmentRuntimeCatalog.node(for: TargetingTier.basic.equipmentName))
    items.append(
      .init(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, node: node,
        provenance: .grant("fixture"),
        location: heldCore ? nil : .init(hullInstanceID: featureHull, slot: .targetingCore)))
  }
  return (try .init(owner: featureOwner, activeHull: featureHull, items: items), context)
}

private func featureLedger(_ id: String) throws -> (SalvageLedger, SalvageLot) {
  var ledger = SalvageLedger(seed: 123)
  let section = SalvageSectionProfile(
    index: 0, kind: .computer, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
    radius: 10, workSeconds: 1, structural: false, technologyDefinitionIDs: [id], sourceFaceIndex: 0
  )
  _ = ledger.advance(
    wreck: .init(system: .init(galaxy: 0, system: 7), site: 0, lineage: 1),
    section: section, pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0),
    tool: .cutter, elapsed: 1, operation: 1,
    conditions: .init(
      toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
      resourcesAvailable: true, ownershipAuthorized: true))
  let lot = try #require(ledger.pendingLots.first)
  var cargo = Array(repeating: 0, count: 17)
  let collected = ledger.collect(
    lot: lot.identity, cargo: &cargo, freeTonnes: 20, apertureHalfExtents: .init(100, 100, 100),
    hasScoops: true, approachAllowed: true, protection: .init())
  #expect(collected == .collected(lot))
  return (ledger, lot)
}

private func featureConditionZero(_ value: Any) -> Any {
  if let array = value as? [Any] { return array.map(featureConditionZero) }
  guard var object = value as? [String: Any] else { return value }
  for (key, child) in object { object[key] = featureConditionZero(child) }
  if var technology = object["technology"] as? [String: Any], technology["_2"] != nil {
    technology["_2"] = 0
    object["technology"] = technology
  }
  return object
}

struct RecoveredFeatureDevicesTests {
  @Test func allFiveDevicesFitFromActualCustodyWithExactSourceAndReceiptEvidence() throws {
    for id in featureIDs {
      let (inventory, context) = try featureInventory()
      let (ledger, lot) = try featureLedger(id)
      let quote = try RecoveredFeatureDevices.quote(
        lotID: lot.identity, ledger: ledger, inventory: inventory, context: context)
      #expect(quote.sourceLot == lot && quote.definition.definitionID == id)
      #expect(quote.definition.schemaVersion == 1)
      let result = try RecoveredFeatureDevices.apply(
        quote: quote, commandID: featureCommand, inventory: inventory, ledger: ledger,
        context: context)
      #expect(
        result.item.id == featureCommand && result.item.provenance == .recovered(lot.identity))
      #expect(result.item.component == nil && result.item.boundHull == nil)
      #expect(result.item.location == quote.location && result.ledger.inventory.isEmpty)
      #expect(RecoveredFeatureDevices.source(for: result.item, ledger: result.ledger) == lot)
      try RecoveredFeatureDevices.validateRecoveredFeatures(
        inventory: result.inventory, ledger: result.ledger)
      #expect(ledger.inventory == [lot] && inventory.items.count == 1)
      let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger))
      let zeroData = try JSONSerialization.data(withJSONObject: featureConditionZero(encoded))
      let zeroLedger = try JSONDecoder().decode(SalvageLedger.self, from: zeroData)
      let zeroQuote = try RecoveredFeatureDevices.quote(
        lotID: lot.identity, ledger: zeroLedger, inventory: inventory, context: context)
      let zeroResult = try RecoveredFeatureDevices.apply(
        quote: zeroQuote, commandID: featureCommand,
        inventory: inventory, ledger: zeroLedger, context: context)
      guard case .technology(_, _, let condition) = zeroQuote.sourceLot.content else {
        Issue.record("Expected recovered feature technology")
        return
      }
      #expect(condition == 0 && zeroResult.item.node == result.item.node)
    }
  }

  @Test func sourceEvidenceSurvivesSaveStoreAndRefitWithoutClaimingPaidAcquisition() throws {
    let (inventory, context) = try featureInventory()
    let (ledger, lot) = try featureLedger("feature-ecm")
    let quote = try RecoveredFeatureDevices.quote(
      lotID: lot.identity, ledger: ledger, inventory: inventory, context: context)
    let result = try RecoveredFeatureDevices.apply(
      quote: quote, commandID: featureCommand,
      inventory: inventory, ledger: ledger, context: context)
    let savedLedger = try JSONDecoder().decode(
      SalvageLedger.self, from: JSONEncoder().encode(result.ledger))
    var savedInventory = try JSONDecoder().decode(
      OwnedEquipmentInventory.self, from: JSONEncoder().encode(result.inventory))
    try savedInventory.store(
      expected: result.item, expectedRevision: savedInventory.revision, context: context)
    let held = try #require(savedInventory.items.first { $0.id == result.item.id })
    #expect(RecoveredFeatureDevices.source(for: held, ledger: savedLedger) == lot)
    try savedInventory.fit(
      expected: held, at: quote.location, expectedRevision: savedInventory.revision,
      context: context)
    try RecoveredFeatureDevices.validateRecoveredFeatures(
      inventory: savedInventory, ledger: savedLedger)
    let transferredHull = UUID(uuidString: "00000000-0000-0000-0000-000000000777")!
    let transferredItem = OwnedEquipmentItem(
      id: result.item.id, node: result.item.node, provenance: result.item.provenance,
      location: .init(hullInstanceID: transferredHull, slot: quote.definition.slot))
    let transferred = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: transferredHull, items: [transferredItem])
    try RecoveredFeatureDevices.validateRecoveredFeatures(
      inventory: transferred, ledger: savedLedger)
    #expect(RecoveredFeatureDevices.source(for: transferredItem, ledger: savedLedger) == lot)
    #expect(
      savedInventory.items.first { $0.id == result.item.id }?.provenance == .recovered(lot.identity)
    )
  }

  @Test func addonRequiresActuallyFittedCoreAndOccupiedSlotCannotBeReplaced() throws {
    for held in [false, true] {
      let (inventory, context) = try featureInventory(core: held, heldCore: held)
      let (ledger, lot) = try featureLedger("feature-mining-targeting")
      #expect(throws: (any Error).self) {
        try RecoveredFeatureDevices.quote(
          lotID: lot.identity, ledger: ledger, inventory: inventory, context: context)
      }
    }
    let (inventory, context) = try featureInventory()
    let (ledger, lot) = try featureLedger("feature-ecm")
    let quote = try RecoveredFeatureDevices.quote(
      lotID: lot.identity, ledger: ledger, inventory: inventory, context: context)
    let result = try RecoveredFeatureDevices.apply(
      quote: quote, commandID: featureCommand,
      inventory: inventory, ledger: ledger, context: context)
    let (otherLedger, otherLot) = try featureLedger("feature-ecm")
    #expect(throws: (any Error).self) {
      try RecoveredFeatureDevices.quote(
        lotID: otherLot.identity, ledger: otherLedger,
        inventory: result.inventory, context: context)
    }
  }

  @Test func staleInventoryRevisionAndSourceRevisionRefuseWithoutChangingInputs() throws {
    let (inventory, context) = try featureInventory()
    let (ledger, lot) = try featureLedger("feature-ecm")
    let quote = try RecoveredFeatureDevices.quote(
      lotID: lot.identity, ledger: ledger, inventory: inventory, context: context)
    let stale = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: inventory.activeHull,
      revision: inventory.revision + 1, items: inventory.items)
    #expect(throws: (any Error).self) {
      try RecoveredFeatureDevices.apply(
        quote: quote, commandID: featureCommand, inventory: stale, ledger: ledger, context: context)
    }
    var changed = ledger
    _ = changed.markWreckDestroyed(lot.identity.section.wreck)
    #expect(throws: (any Error).self) {
      try RecoveredFeatureDevices.apply(
        quote: quote, commandID: featureCommand, inventory: inventory, ledger: changed,
        context: context)
    }
    for revision in [UInt64.max - 1, UInt64.max] {
      let exhausted = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull,
        revision: revision, items: inventory.items)
      let exhaustedQuote = try RecoveredFeatureDevices.quote(
        lotID: lot.identity, ledger: ledger, inventory: exhausted, context: context)
      #expect(throws: (any Error).self) {
        try RecoveredFeatureDevices.apply(
          quote: exhaustedQuote, commandID: featureCommand,
          inventory: exhausted, ledger: ledger, context: context)
      }
    }
    let heldNode = try #require(EquipmentRuntimeCatalog.node(for: "Energy Bomb"))
    let filledItems =
      inventory.items
      + (1..<OwnedEquipmentInventory.maximumCount).map { index in
        OwnedEquipmentItem(
          id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index))!,
          node: heldNode, provenance: .grant("capacity fixture"))
      }
    let full = try OwnedEquipmentInventory(
      owner: inventory.owner,
      activeHull: inventory.activeHull, items: filledItems)
    let fullQuote = try RecoveredFeatureDevices.quote(
      lotID: lot.identity, ledger: ledger, inventory: full, context: context)
    #expect(throws: (any Error).self) {
      try RecoveredFeatureDevices.apply(
        quote: fullQuote, commandID: featureCommand,
        inventory: full, ledger: ledger, context: context)
    }
    #expect(ledger.inventory == [lot] && inventory.items.count == 1)
  }

  @Test func commandCollisionAndConsumedSourceReplayCannotMintAnotherItem() throws {
    let (inventory, context) = try featureInventory()
    let (ledger, lot) = try featureLedger("feature-ecm")
    let quote = try RecoveredFeatureDevices.quote(
      lotID: lot.identity, ledger: ledger, inventory: inventory, context: context)
    let collision = try #require(inventory.items.first?.id)
    #expect(throws: (any Error).self) {
      try RecoveredFeatureDevices.apply(
        quote: quote, commandID: collision, inventory: inventory, ledger: ledger, context: context)
    }
    let result = try RecoveredFeatureDevices.apply(
      quote: quote, commandID: featureCommand,
      inventory: inventory, ledger: ledger, context: context)
    for command in [featureCommand, UUID(uuidString: "00000000-0000-0000-0000-000000000998")!] {
      #expect(throws: (any Error).self) {
        try RecoveredFeatureDevices.apply(
          quote: quote, commandID: command,
          inventory: result.inventory, ledger: result.ledger, context: context)
      }
    }
    #expect(result.inventory.items.count == inventory.items.count + 1)
    let unrelated = try #require(EquipmentRuntimeCatalog.node(for: "Energy Bomb"))
    let wrong = OwnedEquipmentItem(
      id: result.item.id, node: unrelated,
      provenance: result.item.provenance)
    let duplicate = OwnedEquipmentItem(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000996")!,
      node: unrelated, provenance: result.item.provenance)
    for items in [inventory.items + [wrong], result.inventory.items + [duplicate]] {
      let forgedInventory = try OwnedEquipmentInventory(
        owner: inventory.owner,
        activeHull: inventory.activeHull, items: items)
      #expect(throws: (any Error).self) {
        try RecoveredFeatureDevices.validateRecoveredFeatures(
          inventory: forgedInventory, ledger: result.ledger)
      }
    }
  }

  @Test func forgedRecoveredProvenanceWithoutRealReceiptCannotValidate() throws {
    let (inventory, _) = try featureInventory()
    let (ledger, lot) = try featureLedger("feature-ecm")
    let definition = try #require(RecoveredFeatureDevices.definition(for: "feature-ecm"))
    let forged = OwnedEquipmentItem(
      id: featureCommand, node: definition.node, provenance: .recovered(lot.identity))
    let malformed = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: inventory.activeHull,
      items: inventory.items + [forged])
    #expect(RecoveredFeatureDevices.source(for: forged, ledger: ledger) == nil)
    let wrongNode = try #require(EquipmentRuntimeCatalog.node(for: "Energy Bomb"))
    let hidden = OwnedEquipmentItem(
      id: forged.id, node: wrongNode, provenance: forged.provenance)
    for items in [
      [hidden],
      [
        forged,
        OwnedEquipmentItem(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000997")!,
          node: wrongNode, provenance: forged.provenance),
      ],
    ] {
      let bad = try OwnedEquipmentInventory(
        owner: inventory.owner,
        activeHull: inventory.activeHull, items: inventory.items + items)
      #expect(throws: (any Error).self) {
        try RecoveredFeatureDevices.validateRecoveredFeatures(inventory: bad, ledger: ledger)
      }
    }
    #expect(throws: (any Error).self) {
      try RecoveredFeatureDevices.validateRecoveredFeatures(inventory: malformed, ledger: ledger)
    }
  }

  @Test func registryRejectsScalarAndUnknownDefinitionsAndUnsupportedCutterSlot() throws {
    let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 7, lineage: 1)
    let source = SalvageLootSource(
      roles: [.generalShip], legalValue: 0, economy: 3,
      technology: 10, ownership: .abandoned)
    var fixedLedger: SalvageLedger?
    for seed in UInt64(0)..<4096 {
      let plan = SalvageLootProfiles.plan(
        section: .init(wreck: wreck, section: 0), seed: seed, source: source)
      guard
        plan.items.contains(where: {
          if case .technology(let id, _, _, _) = $0.content { return featureIDs.contains(id) }
          return false
        })
      else { continue }
      var candidate = SalvageLedger(seed: seed)
      let section = SalvageSectionProfile(
        index: 0, kind: .computer,
        localPosition: .init(0, 0, 0), normal: .init(0, 0, 1), radius: 10,
        workSeconds: 1, structural: false, technologyDefinitionIDs: [], sourceFaceIndex: 0)
      _ = candidate.advance(
        wreck: wreck, section: section, pose: .init(),
        velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
        elapsed: 1, operation: 1,
        conditions: .init(
          toolInstalled: true, inRange: true,
          aligned: true, lineOfSight: true, resourcesAvailable: true, ownershipAuthorized: true),
        source: source)
      guard
        let lot = candidate.pendingLots.first(where: {
          guard case .technology(let id, _, _) = $0.content else { return false }
          return featureIDs.contains(id) && $0.loot != nil
        })
      else { continue }
      var cargo = Array(repeating: 0, count: 17)
      _ = candidate.collect(
        lot: lot.identity, cargo: &cargo, freeTonnes: 20,
        apertureHalfExtents: .init(100, 100, 100), hasScoops: true,
        approachAllowed: true, protection: .init())
      fixedLedger = candidate
      break
    }
    let issued = try #require(fixedLedger)
    let issuedLot = try #require(issued.inventory.first)
    let (issuedInventory, issuedContext) = try featureInventory()
    let issuedQuote = try RecoveredFeatureDevices.quote(
      lotID: issuedLot.identity, ledger: issued, inventory: issuedInventory, context: issuedContext)
    let issuedResult = try RecoveredFeatureDevices.apply(
      quote: issuedQuote, commandID: featureCommand,
      inventory: issuedInventory, ledger: issued, context: issuedContext)
    #expect(
      RecoveredFeatureDevices.source(for: issuedResult.item, ledger: issuedResult.ledger)
        == issuedLot)
    func corruptFixedBonus(_ value: Any) -> Any {
      if let array = value as? [Any] { return array.map(corruptFixedBonus) }
      guard var object = value as? [String: Any] else { return value }
      for (key, child) in object { object[key] = corruptFixedBonus(child) }
      if object["bonusBasisPoints"] != nil { object["bonusBasisPoints"] = 1 }
      return object
    }
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(issued))
    let tampered = try JSONSerialization.data(withJSONObject: corruptFixedBonus(json))
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(SalvageLedger.self, from: tampered)
    }
    #expect(RecoveredFeatureDevices.definition(for: "shield-technology") == nil)
    #expect(RecoveredFeatureDevices.definition(for: "missing") == nil)
    let (inventory, original) = try featureInventory()
    let context = OwnedEquipmentContext(
      owner: original.owner, activeHull: original.activeHull,
      supportedSlots: original.supportedSlots.subtracting([.utility(.salvageCutter)]),
      nodes: original.nodes, familyLimits: original.familyLimits, definitions: original.definitions)
    let (ledger, lot) = try featureLedger("feature-salvage-cutter")
    #expect(throws: (any Error).self) {
      try RecoveredFeatureDevices.quote(
        lotID: lot.identity, ledger: ledger, inventory: inventory, context: context)
    }
  }
}
