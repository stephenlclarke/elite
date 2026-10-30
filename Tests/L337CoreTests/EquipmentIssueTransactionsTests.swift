import Foundation
import Testing

@testable import L337Core

private func issueUUID(_ index: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
}
private let issueOwner = issueUUID(1)
private let issueHull = issueUUID(2)
private let issueSource = EquipmentIssueSource(
  mission: issueUUID(3), resource: "loan-kit", packDigest: String(repeating: "a", count: 64))

private func issueContext() throws -> OwnedEquipmentContext {
  EquipmentRuntimeCatalog.context(
    owner: issueOwner, hull: issueHull,
    performance: try #require(ShipCatalogue.ship("SH023")?.game))
}
private func issueBudget(capacity: Int = 100, occupied: Int = 0) -> EquipmentFitBudgetSnapshot {
  .init(
    equipmentCapacity: capacity, reservedEquipmentUnits: 0,
    nodeEquipmentUnits: Dictionary(
      uniqueKeysWithValues: EquipmentRuntimeCatalog.graph.nodes.map {
        let node = $0.id
        let cost: Int
        if node.family == EquipmentRuntimeCatalog.laserFamily
          || node.family.rawValue == "ammunition"
        {
          cost = 0
        } else if node.key == "Extra Energy Unit" {
          cost = 2
        } else if node.key == "Naval Energy Unit" {
          cost = 3
        } else if node.key == Equipment.eliteEnergyUnit {
          cost = 4
        } else {
          cost = ShieldBooster.from(node.key) == nil ? 1 : 2
        }
        return (node, cost)
      }), projectedCargoCapacity: 20, occupiedCargoTonnes: occupied, accommodationAllowed: true)
}
private func issueRequest(
  _ name: String = "Extra Energy Unit", count: Int = 1,
  fitting: IssueFittingPlan = .held
) throws -> EquipmentIssueRequest {
  let node = try #require(EquipmentRuntimeCatalog.node(for: name))
  return .init(
    command: issueUUID(4), source: issueSource,
    devices: (0..<count).map {
      .init(
        id: issueUUID(100 + $0), node: node, index: $0,
        preferredSlot: EquipmentRuntimeCatalog.slot(for: node))
    }, fitting: fitting)
}
private func issueObligation(
  _ request: EquipmentIssueRequest, loan: Bool = true, remaining: Bool = false,
  consumed: Set<UUID> = [], displacements: [EquipmentIssueDisplacement] = [],
  missing: Set<UUID> = []
) -> EquipmentIssueObligationSnapshot {
  .init(
    source: request.source, node: request.devices[0].node,
    items: request.devices.map(\.id), consumed: consumed, status: .issued, loan: loan,
    returnRemaining: remaining, displacements: displacements, legacyMissingItems: missing)
}
private func issueAdmit(
  _ request: EquipmentIssueRequest, inventory: OwnedEquipmentInventory,
  context: OwnedEquipmentContext, obligations: [EquipmentIssueObligationSnapshot] = [],
  budget: EquipmentFitBudgetSnapshot = issueBudget()
) throws -> EquipmentIssueApplication {
  let quote = try EquipmentIssueTransactions.quoteAdmission(
    request: request, inventory: inventory, context: context, obligations: obligations,
    budget: budget)
  return try EquipmentIssueTransactions.applyAdmission(
    quote: quote, inventory: inventory, context: context, obligations: obligations, budget: budget)
}

struct EquipmentIssueTransactionsTests {
  @Test func heldOneAndThirtyTwoDevicesHaveCanonicalComponentsAndSingleBatchRevision() throws {
    let context = try issueContext()
    let inventory = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    for count in [1, 32] {
      let request = try issueRequest(count: count)
      let result = try issueAdmit(request, inventory: inventory, context: context)
      #expect(result.inventory.revision == inventory.revision + 1)
      #expect(result.inventory.items.count == count && inventory.items.isEmpty)
      #expect(result.receipt.originalItems == request.devices.map(\.id))
      #expect(result.receipt.operation == .issued && result.receipt.source == issueSource)
      for (index, item) in result.inventory.items.enumerated() {
        #expect(item.location == nil && item.id == request.devices[index].id)
        #expect(item.component?.id == item.id)
        #expect(
          item.component == EquipmentRuntimeCatalog.stockComponent(for: item.node, id: item.id))
        #expect(
          item.provenance
            == .missionIssue(
              mission: issueSource.mission,
              resource: issueSource.resource, index: index, packDigest: issueSource.packDigest))
      }
    }
  }

  @Test func fitAllRetainsExactPersonalDisplacementAndReturnRestoresSameDevice() throws {
    let context = try issueContext()
    let node = try #require(EquipmentRuntimeCatalog.node(for: "Basic Energy System"))
    let location = ComponentFittingLocation(hullInstanceID: issueHull, slot: .energy)
    let personal = OwnedEquipmentItem(
      id: issueUUID(20), node: node, provenance: .standard,
      component: EquipmentRuntimeCatalog.stockComponent(for: node, id: issueUUID(20)),
      location: location)
    let inventory = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull, items: [personal])
    let request = try issueRequest(
      fitting: .fitAll([
        .init(item: issueUUID(100), location: location, replacing: personal)
      ]))
    let issued = try issueAdmit(request, inventory: inventory, context: context)
    #expect(issued.inventory.items.first { $0.id == personal.id }?.location == nil)
    #expect(issued.receipt.displacements == [.init(item: personal.id, location: location)])
    let obligation = issueObligation(request, displacements: issued.receipt.displacements)
    let quote = try EquipmentIssueTransactions.quoteSettlement(
      command: issueUUID(5),
      operation: .returnOriginals, obligation: obligation, inventory: issued.inventory,
      context: context, obligations: [obligation], budget: issueBudget())
    let returned = try EquipmentIssueTransactions.applySettlement(
      quote: quote,
      inventory: issued.inventory, context: context, obligations: [obligation],
      budget: issueBudget())
    let projection = try EquipmentIssueTransactions.projectSettlement(
      operation: .returnOriginals, obligation: obligation, inventory: issued.inventory,
      context: context, obligations: [obligation])
    #expect(projection.items == returned.inventory.items)
    #expect(issued.inventory.revision == inventory.revision + 1)
    let exhausted = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull,
      revision: .max, items: issued.inventory.items)
    let maxProjection = try EquipmentIssueTransactions.projectSettlement(
      operation: .returnOriginals, obligation: obligation, inventory: exhausted,
      context: context, obligations: [obligation])
    #expect(maxProjection.items == returned.inventory.items && exhausted.revision == .max)
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.quoteSettlement(
        command: issueUUID(90),
        operation: .returnOriginals, obligation: obligation, inventory: exhausted,
        context: context, obligations: [obligation], budget: issueBudget())
    }
    let missingPersonal = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull,
      revision: issued.inventory.revision,
      items: issued.inventory.items.filter { $0.id != personal.id })
    try EquipmentIssueTransactions.validateObligations(
      inventory: missingPersonal, context: context, obligations: [obligation])
    let missingBefore = missingPersonal
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.projectSettlement(
        operation: .returnOriginals,
        obligation: obligation, inventory: missingPersonal, context: context,
        obligations: [obligation])
    }
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.quoteSettlement(
        command: issueUUID(91),
        operation: .returnOriginals, obligation: obligation, inventory: missingPersonal,
        context: context, obligations: [obligation], budget: issueBudget())
    }
    #expect(missingPersonal == missingBefore)
    #expect(returned.inventory.items == [personal])
    #expect(returned.inventory.revision == issued.inventory.revision + 1)
    #expect(returned.receipt.operation == .returned)
  }

  @Test func ownLoanStoresAndRefitsButForeignLoanCannotBeDisplaced() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let request = try issueRequest(
      "Fuel Scoops",
      fitting: .fitAll([
        .init(
          item: issueUUID(100),
          location: .init(hullInstanceID: issueHull, slot: .utility(.fuelScoops)), replacing: nil)
      ]))
    let issued = try issueAdmit(request, inventory: empty, context: context)
    let obligation = issueObligation(request)
    let item = try #require(issued.inventory.items.first)
    let store = try EquipmentIssueTransactions.quoteFitting(
      command: issueUUID(6), obligation: obligation,
      item: item, destination: nil, replacing: nil, inventory: issued.inventory, context: context,
      obligations: [obligation], budget: issueBudget())
    let stored = try EquipmentIssueTransactions.applyFitting(
      quote: store,
      inventory: issued.inventory, context: context, obligations: [obligation],
      budget: issueBudget())
    let held = try #require(stored.inventory.items.first)
    #expect(held.location == nil && stored.inventory.revision == issued.inventory.revision + 1)
    let fit = try EquipmentIssueTransactions.quoteFitting(
      command: issueUUID(7), obligation: obligation,
      item: held, destination: item.location, replacing: nil, inventory: stored.inventory,
      context: context, obligations: [obligation], budget: issueBudget())
    let refitted = try EquipmentIssueTransactions.applyFitting(
      quote: fit,
      inventory: stored.inventory, context: context, obligations: [obligation],
      budget: issueBudget())
    #expect(refitted.inventory.items == issued.inventory.items)
    let otherSource = EquipmentIssueSource(
      mission: issueUUID(8), resource: "other-kit", packDigest: issueSource.packDigest)
    let foreign = EquipmentIssueRequest(
      command: issueUUID(9), source: otherSource,
      devices: [
        .init(id: issueUUID(101), node: item.node, index: 0, preferredSlot: item.location?.slot)
      ],
      fitting: .fitAll([
        .init(item: issueUUID(101), location: try #require(item.location), replacing: item)
      ]))
    #expect(throws: (any Error).self) {
      try issueAdmit(
        foreign, inventory: issued.inventory, context: context, obligations: [obligation])
    }
  }

  @Test func releaseRetainsPhysicalArrayAndReturnRemainingRequiresRealSurvivors() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let request = try issueRequest("Fuel Scoops", count: 2)
    let issued = try issueAdmit(request, inventory: empty, context: context)
    let loan = issueObligation(request)
    let quote = try EquipmentIssueTransactions.quoteSettlement(
      command: issueUUID(10),
      operation: .releaseLoan, obligation: loan, inventory: issued.inventory,
      context: context, obligations: [loan], budget: issueBudget())
    let released = try EquipmentIssueTransactions.applySettlement(
      quote: quote,
      inventory: issued.inventory, context: context, obligations: [loan], budget: issueBudget())
    #expect(released.inventory.items == issued.inventory.items)
    #expect(
      released.inventory.revision == issued.inventory.revision + 1
        && released.receipt.operation == .released)
    let survivor = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull,
      revision: issued.inventory.revision, items: Array(issued.inventory.items.dropFirst()))
    let all = issueObligation(request, consumed: [request.devices[0].id])
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.quoteSettlement(
        command: issueUUID(11), operation: .returnOriginals,
        obligation: all, inventory: survivor, context: context, obligations: [all],
        budget: issueBudget())
    }
    let remaining = issueObligation(request, remaining: true, consumed: [request.devices[0].id])
    let returning = try EquipmentIssueTransactions.quoteSettlement(
      command: issueUUID(12), operation: .returnOriginals,
      obligation: remaining, inventory: survivor, context: context, obligations: [remaining],
      budget: issueBudget())
    let result = try EquipmentIssueTransactions.applySettlement(
      quote: returning, inventory: survivor,
      context: context, obligations: [remaining], budget: issueBudget())
    #expect(result.inventory.items.isEmpty && result.receipt.consumedItems == remaining.consumed)
  }

  @Test func admissionQuotePinsWholeInventoryContextObligationsAndBudget() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let request = try issueRequest()
    let quote = try EquipmentIssueTransactions.quoteAdmission(
      request: request,
      inventory: empty, context: context, obligations: [], budget: issueBudget())
    let stale = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull, revision: 1)
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applyAdmission(
        quote: quote, inventory: stale,
        context: context, obligations: [], budget: issueBudget())
    }
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applyAdmission(
        quote: quote, inventory: empty,
        context: context, obligations: [], budget: issueBudget(capacity: 99))
    }
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applyAdmission(
        quote: quote, inventory: empty,
        context: context, obligations: [issueObligation(request)], budget: issueBudget())
    }
    let different = OwnedEquipmentContext(
      owner: context.owner, activeHull: context.activeHull,
      supportedSlots: context.supportedSlots.subtracting([.utility(.ecm)]), nodes: context.nodes,
      familyLimits: context.familyLimits, definitions: context.definitions)
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applyAdmission(
        quote: quote, inventory: empty,
        context: different, obligations: [], budget: issueBudget())
    }
    #expect(empty.items.isEmpty && empty.revision == 0)
  }

  @Test func malformedQuantityIndexSourceAndPartialFitRefuseWithoutAdmission() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    for count in [0, 33] {
      let request = try issueRequest(count: count)
      #expect(throws: (any Error).self) {
        try issueAdmit(request, inventory: empty, context: context)
      }
    }
    let original = try issueRequest(count: 2)
    let partial = EquipmentIssueRequest(
      command: original.command, source: original.source,
      devices: original.devices,
      fitting: .fitAll([
        .init(
          item: original.devices[0].id,
          location: .init(hullInstanceID: issueHull, slot: .energy), replacing: nil)
      ]))
    #expect(throws: (any Error).self) {
      try issueAdmit(partial, inventory: empty, context: context)
    }
    let malformed = EquipmentIssueRequest(
      command: original.command,
      source: .init(mission: issueSource.mission, resource: "bad source", packDigest: "bad"),
      devices: [
        .init(id: issueUUID(100), node: original.devices[0].node, index: 7, preferredSlot: nil)
      ], fitting: .held)
    #expect(throws: (any Error).self) {
      try issueAdmit(malformed, inventory: empty, context: context)
    }
    #expect(empty.items.isEmpty)
  }

  @Test func missingLegacyOriginalAndExhaustedRevisionRefuseAtomically() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let request = try issueRequest("Fuel Scoops")
    let missing = issueObligation(
      request, loan: false, remaining: true, missing: [request.devices[0].id])
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.quoteSettlement(
        command: issueUUID(13), operation: .returnOriginals,
        obligation: missing, inventory: empty, context: context, obligations: [missing],
        budget: issueBudget())
    }
    let exhausted = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull, revision: .max)
    #expect(throws: (any Error).self) {
      try issueAdmit(request, inventory: exhausted, context: context)
    }
    let pulse = try #require(EquipmentRuntimeCatalog.node(for: "Pulse Laser"))
    let full = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull,
      items: (0..<OwnedEquipmentInventory.maximumCount).map {
        .init(id: issueUUID(1000 + $0), node: pulse, provenance: .grant("capacity fixture"))
      })
    #expect(throws: (any Error).self) { try issueAdmit(request, inventory: full, context: context) }
    #expect(full.items.count == OwnedEquipmentInventory.maximumCount)
    #expect(exhausted.revision == .max && exhausted.items.isEmpty)
  }

  @Test func intrinsicDowngradeAndMissingFittedCoreCannotEnterFitAll() throws {
    let context = try issueContext()
    let advanced = try #require(EquipmentRuntimeCatalog.node(for: "Naval Energy Unit"))
    let location = ComponentFittingLocation(hullInstanceID: issueHull, slot: .energy)
    let current = OwnedEquipmentItem(
      id: issueUUID(30), node: advanced, provenance: .grant("fixture"),
      component: EquipmentRuntimeCatalog.stockComponent(for: advanced, id: issueUUID(30)),
      location: location)
    let inventory = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull, items: [current])
    let downgrade = try issueRequest(
      fitting: .fitAll([.init(item: issueUUID(100), location: location, replacing: current)]))
    #expect(throws: (any Error).self) {
      try issueAdmit(downgrade, inventory: inventory, context: context)
    }
    let addon = try issueRequest(
      "Targeting: Mining Module",
      fitting: .fitAll([
        .init(
          item: issueUUID(100), location: .init(hullInstanceID: issueHull, slot: .targetingMining),
          replacing: nil)
      ]))
    #expect(throws: (any Error).self) {
      try issueAdmit(addon, inventory: inventory, context: context)
    }
  }
  @Test func retainedHistoricalOriginalAndDisplacementIDsCannotBeReissuedByNewSource() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let request = try issueRequest("Fuel Scoops")
    let node = request.devices[0].node
    for (status, consumed, missing) in [
      (EquipmentIssueStatus.returned, Set<UUID>(), Set<UUID>()),
      (.issued, Set([issueUUID(100)]), Set<UUID>()),
      (.issued, Set<UUID>(), Set([issueUUID(100)])),
    ] {
      let historical = EquipmentIssueObligationSnapshot(
        source: issueSource, node: node,
        items: [issueUUID(100)], consumed: consumed, status: status, loan: false,
        returnRemaining: true,
        displacements: [
          .init(
            item: issueUUID(20),
            location: .init(hullInstanceID: issueHull, slot: .utility(.fuelScoops)))
        ], legacyMissingItems: missing)
      for reused in [issueUUID(100), issueUUID(20)] {
        let new = EquipmentIssueRequest(
          command: issueUUID(40),
          source: .init(
            mission: issueUUID(41), resource: "new-kit", packDigest: issueSource.packDigest),
          devices: [.init(id: reused, node: node, index: 0, preferredSlot: nil)], fitting: .held)
        #expect(throws: EquipmentIssueError.identityMismatch) {
          try issueAdmit(new, inventory: empty, context: context, obligations: [historical])
        }
      }
    }
  }

  @Test func terminalAndReleasedObligationReciprocityCannotHideOrDuplicateSurvivors() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let request = try issueRequest("Fuel Scoops")
    let issued = try issueAdmit(request, inventory: empty, context: context)
    for status in [EquipmentIssueStatus.returned, .released] {
      let obligation = EquipmentIssueObligationSnapshot(
        source: request.source,
        node: request.devices[0].node, items: request.devices.map(\.id), consumed: [],
        status: status, loan: true, returnRemaining: false, displacements: [])
      let actual = status == .returned ? issued.inventory : empty
      if status == .returned {
        #expect(throws: EquipmentIssueError.identityMismatch) {
          try EquipmentIssueTransactions.validateObligations(
            inventory: actual, context: context, obligations: [obligation])
        }
      } else {
        #expect(throws: EquipmentIssueError.missingOriginal(request.devices[0].id)) {
          try EquipmentIssueTransactions.validateObligations(
            inventory: actual, context: context, obligations: [obligation])
        }
      }
    }
  }

  @Test func fittingAndSettlementQuotesPinCompleteFactsAndRestorationFitsExactBudget() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let request = try issueRequest("Fuel Scoops")
    let issued = try issueAdmit(request, inventory: empty, context: context)
    let obligation = issueObligation(request)
    let item = try #require(issued.inventory.items.first)
    let fit = try EquipmentIssueTransactions.quoteFitting(
      command: issueUUID(43), obligation: obligation,
      item: item, destination: .init(hullInstanceID: issueHull, slot: .utility(.fuelScoops)),
      replacing: nil,
      inventory: issued.inventory, context: context, obligations: [obligation],
      budget: issueBudget(capacity: 1))
    let stale = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull,
      revision: issued.inventory.revision + 1, items: issued.inventory.items)
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applyFitting(
        quote: fit, inventory: stale,
        context: context, obligations: [obligation], budget: issueBudget(capacity: 1))
    }
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applyFitting(
        quote: fit, inventory: issued.inventory,
        context: context, obligations: [], budget: issueBudget(capacity: 1))
    }
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applyFitting(
        quote: fit, inventory: issued.inventory,
        context: context, obligations: [obligation], budget: issueBudget(capacity: 0))
    }
    let fitted = try EquipmentIssueTransactions.applyFitting(
      quote: fit, inventory: issued.inventory,
      context: context, obligations: [obligation], budget: issueBudget(capacity: 1))
    #expect(fitted.inventory.items.first?.location?.slot == .utility(.fuelScoops))
    let settlement = try EquipmentIssueTransactions.quoteSettlement(
      command: issueUUID(44),
      operation: .returnOriginals, obligation: obligation, inventory: fitted.inventory,
      context: context, obligations: [obligation], budget: issueBudget(capacity: 1))
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applySettlement(
        quote: settlement, inventory: fitted.inventory,
        context: context, obligations: [], budget: issueBudget(capacity: 1))
    }
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applySettlement(
        quote: settlement, inventory: fitted.inventory,
        context: context, obligations: [obligation], budget: issueBudget(capacity: 2))
    }
    let budgetBlocked = issueBudget(capacity: 0)
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.quoteFitting(
        command: issueUUID(45), obligation: obligation,
        item: item, destination: .init(hullInstanceID: issueHull, slot: .utility(.fuelScoops)),
        replacing: nil,
        inventory: issued.inventory, context: context, obligations: [obligation],
        budget: budgetBlocked)
    }
  }

  @Test func targetingTierDowngradeRefusesAdmissionAndRefitWhileEqualTierReplacementIsAllowed()
    throws
  {
    let context = try issueContext()
    let military = try #require(EquipmentRuntimeCatalog.node(for: "Targeting: Military"))
    let location = ComponentFittingLocation(hullInstanceID: issueHull, slot: .targetingCore)
    let current = OwnedEquipmentItem(
      id: issueUUID(70), node: military,
      provenance: .grant("personal military core"), location: location)
    let inventory = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull, items: [current])
    let basic = try issueRequest(
      "Targeting: Basic",
      fitting: .fitAll([
        .init(item: issueUUID(100), location: location, replacing: current)
      ]))
    #expect(throws: EquipmentIssueError.unsupportedReplacement) {
      try issueAdmit(basic, inventory: inventory, context: context)
    }
    let heldRequest = try issueRequest("Targeting: Basic")
    let heldResult = try issueAdmit(heldRequest, inventory: inventory, context: context)
    let obligation = issueObligation(heldRequest)
    let held = try #require(heldResult.inventory.items.first { $0.id == issueUUID(100) })
    let before = heldResult.inventory
    #expect(throws: EquipmentIssueError.unsupportedReplacement) {
      try EquipmentIssueTransactions.quoteFitting(
        command: issueUUID(71), obligation: obligation,
        item: held, destination: location, replacing: current, inventory: before,
        context: context, obligations: [obligation], budget: issueBudget())
    }
    #expect(heldResult.inventory == before && inventory.items == [current])
    let equal = try issueRequest(
      "Targeting: Military",
      fitting: .fitAll([
        .init(item: issueUUID(100), location: location, replacing: current)
      ]))
    let replacement = try issueAdmit(equal, inventory: inventory, context: context)
    #expect(replacement.inventory.items.first { $0.id == issueUUID(100) }?.location == location)
    #expect(replacement.inventory.items.first { $0.id == current.id }?.location == nil)
  }

  @Test func onlyActualFittedStandardFoundationsAreFreeAndHeldDevicesDoNotSpendFitBudget() throws {
    let context = try issueContext()
    let node = try #require(EquipmentRuntimeCatalog.node(for: "Navigation: Basic"))
    let location = ComponentFittingLocation(hullInstanceID: issueHull, slot: .navigation)
    let standard = OwnedEquipmentItem(
      id: issueUUID(72), node: node, provenance: .standard,
      component: EquipmentRuntimeCatalog.stockComponent(for: node, id: issueUUID(72)),
      location: location)
    let inventory = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull, items: [standard])
    let heldRequest = try issueRequest("Targeting: Basic")
    let heldResult = try issueAdmit(
      heldRequest, inventory: inventory,
      context: context, budget: issueBudget(capacity: 0))
    #expect(heldResult.inventory.items.count == 2)
    #expect(heldResult.inventory.items.first { $0.id == issueUUID(100) }?.location == nil)
    let mission = try issueRequest(
      "Navigation: Basic",
      fitting: .fitAll([
        .init(item: issueUUID(100), location: location, replacing: standard)
      ]))
    #expect(throws: EquipmentIssueError.invalidBudget) {
      try issueAdmit(
        mission, inventory: inventory, context: context, budget: issueBudget(capacity: 0))
    }
    #expect(inventory.items == [standard] && inventory.revision == 0)
    let charged = try issueAdmit(
      mission, inventory: inventory,
      context: context, budget: issueBudget(capacity: 1))
    #expect(charged.inventory.items.first { $0.id == issueUUID(100) }?.location == location)
    let basicTargeting = try #require(EquipmentRuntimeCatalog.node(for: "Targeting: Basic"))
    let purchased = OwnedEquipmentItem(
      id: issueUUID(73), node: basicTargeting,
      provenance: .paid(owner: issueOwner, transaction: issueUUID(74)),
      location: .init(hullInstanceID: issueHull, slot: .targetingCore))
    let paidInventory = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull,
      items: [standard, purchased])
    #expect(throws: EquipmentIssueError.invalidBudget) {
      try issueAdmit(
        try issueRequest("Fuel Scoops"), inventory: paidInventory,
        context: context, budget: issueBudget(capacity: 0))
    }
    #expect(paidInventory.items == [standard, purchased] && paidInventory.revision == 0)
  }

  @Test func portableHullExchangeRestoresHistoricalSlotOnCurrentHullWithoutChangingEvidence() throws
  {
    let context = try issueContext()
    let node = try #require(EquipmentRuntimeCatalog.node(for: "Extra Energy Unit"))
    let oldLocation = ComponentFittingLocation(hullInstanceID: issueHull, slot: .energy)
    let personal = OwnedEquipmentItem(
      id: issueUUID(80), node: node,
      provenance: .paid(owner: issueOwner, transaction: issueUUID(81)),
      component: EquipmentRuntimeCatalog.stockComponent(for: node, id: issueUUID(80)),
      location: oldLocation, preferredSlot: .energy,
      retainedLegacyState: .init(conditionBasisPoints: 10000, modifications: [:]))
    let original = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull, items: [personal])
    let request = try issueRequest(
      "Naval Energy Unit",
      fitting: .fitAll([
        .init(item: issueUUID(100), location: oldLocation, replacing: personal)
      ]))
    let issued = try issueAdmit(request, inventory: original, context: context)
    let obligation = issueObligation(request, displacements: issued.receipt.displacements)
    try issued.inventory.validate(context: context)
    let newHull = issueUUID(82)
    let transferred = try OwnedEquipmentInventory(
      owner: issued.inventory.owner, activeHull: newHull, revision: issued.inventory.revision + 1,
      items: issued.inventory.items.map { item in
        item.moved(to: item.location.map { .init(hullInstanceID: newHull, slot: $0.slot) })
      })
    let newContext = EquipmentRuntimeCatalog.context(
      owner: issueOwner, hull: newHull,
      performance: try #require(ShipCatalogue.ship("SH043")?.game))
    try transferred.validate(context: newContext)
    let snapshot = transferred
    let projected = try EquipmentIssueTransactions.projectSettlement(
      operation: .returnOriginals,
      obligation: obligation, inventory: transferred, context: newContext, obligations: [obligation]
    )
    let quote = try EquipmentIssueTransactions.quoteSettlement(
      command: issueUUID(83),
      operation: .returnOriginals, obligation: obligation, inventory: transferred,
      context: newContext, obligations: [obligation], budget: issueBudget(capacity: 2))
    let returned = try EquipmentIssueTransactions.applySettlement(
      quote: quote, inventory: transferred,
      context: newContext, obligations: [obligation], budget: issueBudget(capacity: 2))
    #expect(returned.inventory.items == projected.items && transferred == snapshot)
    let restored = try #require(returned.inventory.items.first)
    #expect(restored.id == personal.id && restored.node == personal.node)
    #expect(restored.location == .init(hullInstanceID: newHull, slot: .energy))
    #expect(restored.component == personal.component && restored.provenance == personal.provenance)
    #expect(
      restored.preferredSlot == personal.preferredSlot
        && restored.retainedLegacyState == personal.retainedLegacyState)
    #expect(returned.receipt.displacements == [.init(item: personal.id, location: oldLocation)])
    #expect(returned.inventory.revision == transferred.revision + 1)
    #expect(throws: EquipmentIssueError.invalidBudget) {
      try EquipmentIssueTransactions.quoteSettlement(
        command: issueUUID(84), operation: .returnOriginals,
        obligation: obligation, inventory: transferred, context: newContext,
        obligations: [obligation], budget: issueBudget(capacity: 1))
    }
    #expect(transferred == snapshot)
  }

  @Test func exchangedHullRestorationCannotOverwriteOccupantOrUseUnsupportedSlot() throws {
    let context = try issueContext()
    let node = try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops"))
    let oldLocation = ComponentFittingLocation(
      hullInstanceID: issueHull, slot: .utility(.fuelScoops))
    let personal = OwnedEquipmentItem(
      id: issueUUID(85), node: node,
      provenance: .grant("portable scoop"), location: oldLocation)
    let original = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull, items: [personal])
    let request = try issueRequest(
      "Fuel Scoops",
      fitting: .fitAll([
        .init(item: issueUUID(100), location: oldLocation, replacing: personal)
      ]))
    let issued = try issueAdmit(request, inventory: original, context: context)
    let obligation = issueObligation(request, displacements: issued.receipt.displacements)
    try issued.inventory.validate(context: context)
    let newHull = issueUUID(86)
    let transferred = try OwnedEquipmentInventory(
      owner: issued.inventory.owner, activeHull: newHull, revision: issued.inventory.revision + 1,
      items: issued.inventory.items.map { item in
        item.moved(to: item.location.map { .init(hullInstanceID: newHull, slot: $0.slot) })
      })
    let newContext = EquipmentRuntimeCatalog.context(
      owner: issueOwner, hull: newHull,
      performance: try #require(ShipCatalogue.ship("SH043")?.game))
    try transferred.validate(context: newContext)
    let issuedItem = try #require(transferred.items.first { $0.id == issueUUID(100) })
    var occupied = transferred
    try occupied.store(
      expected: issuedItem, expectedRevision: occupied.revision, context: newContext)
    let bothHeld = occupied
    let occupant = OwnedEquipmentItem(
      id: issueUUID(87), node: node, provenance: .grant("new personal scoop"),
      location: .init(hullInstanceID: newHull, slot: .utility(.fuelScoops)))
    try occupied.admit(occupant, expectedRevision: occupied.revision, context: newContext)
    let before = occupied
    #expect(throws: OwnedEquipmentError.occupiedSlot) {
      try EquipmentIssueTransactions.projectSettlement(
        operation: .returnOriginals,
        obligation: obligation, inventory: occupied, context: newContext, obligations: [obligation])
    }
    #expect(throws: OwnedEquipmentError.occupiedSlot) {
      try EquipmentIssueTransactions.quoteSettlement(
        command: issueUUID(88),
        operation: .returnOriginals, obligation: obligation, inventory: occupied,
        context: newContext, obligations: [obligation], budget: issueBudget())
    }
    #expect(occupied == before)
    let incompatible = OwnedEquipmentContext(
      owner: newContext.owner, activeHull: newContext.activeHull,
      supportedSlots: newContext.supportedSlots.subtracting([.utility(.fuelScoops)]),
      nodes: newContext.nodes, familyLimits: newContext.familyLimits,
      definitions: newContext.definitions)
    try EquipmentIssueTransactions.validateObligations(
      inventory: bothHeld, context: incompatible, obligations: [obligation])
    let heldBefore = bothHeld
    #expect(throws: OwnedEquipmentError.unsupportedSlot) {
      try EquipmentIssueTransactions.projectSettlement(
        operation: .returnOriginals,
        obligation: obligation, inventory: bothHeld, context: incompatible,
        obligations: [obligation])
    }
    #expect(throws: OwnedEquipmentError.unsupportedSlot) {
      try EquipmentIssueTransactions.quoteSettlement(
        command: issueUUID(89),
        operation: .returnOriginals, obligation: obligation, inventory: bothHeld,
        context: incompatible, obligations: [obligation], budget: issueBudget())
    }
    #expect(bothHeld == heldBefore)
    #expect(transferred.items.count == issued.inventory.items.count)
  }

  @Test func originalDockingAliasSurvivesHeldFitStoreAndRefitWithoutChangingCanonicalNode() throws {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let node = try #require(EquipmentRuntimeCatalog.node(for: Equipment.legacyDockingComputer))
    let request = EquipmentIssueRequest(
      command: issueUUID(92), source: issueSource,
      devices: [
        .init(
          id: issueUUID(100), node: node, index: 0, preferredSlot: .targetingCore,
          originalEquipmentName: Equipment.legacyDockingComputer)
      ], fitting: .held)
    let issued = try issueAdmit(request, inventory: empty, context: context)
    let obligation = issueObligation(request)
    var current = issued.inventory
    for destination in [
      ComponentFittingLocation(hullInstanceID: issueHull, slot: .targetingCore),
      nil, ComponentFittingLocation(hullInstanceID: issueHull, slot: .targetingCore),
    ] {
      let item = try #require(current.items.first)
      #expect(
        item.node == node
          && item.retainedLegacyState?.originalEquipmentName == Equipment.legacyDockingComputer)
      #expect(item.retainedLegacyState?.conditionBasisPoints == 10000)
      #expect(item.retainedLegacyState?.modifications.isEmpty == true)
      let quote = try EquipmentIssueTransactions.quoteFitting(
        command: issueUUID(93),
        obligation: obligation, item: item, destination: destination, replacing: nil,
        inventory: current, context: context, obligations: [obligation], budget: issueBudget())
      let application = try EquipmentIssueTransactions.applyFitting(
        quote: quote,
        inventory: current, context: context, obligations: [obligation], budget: issueBudget())
      current = application.inventory
    }
    #expect(
      current.items.first?.retainedLegacyState == issued.inventory.items.first?.retainedLegacyState)
    let modern = try issueRequest("Targeting: Docking")
    let modernResult = try issueAdmit(modern, inventory: empty, context: context)
    #expect(modernResult.inventory.items.first?.retainedLegacyState == nil)
  }

  @Test func invalidOriginalAliasAndWrongCanonicalNodeRefuseAndMetadataChangesInvalidateQuote()
    throws
  {
    let context = try issueContext()
    let empty = try OwnedEquipmentInventory(owner: issueOwner, activeHull: issueHull)
    let docking = try #require(EquipmentRuntimeCatalog.node(for: "Targeting: Docking"))
    let ammo = EquipmentNodeID(family: .init("ammunition"), key: "missile-standard")
    let fuel = try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops"))
    for (node, name) in [
      (docking, "unknown alias"), (fuel, Equipment.legacyDockingComputer),
      (ammo, Equipment.legacyDockingComputer),
    ] {
      let bad = EquipmentIssueRequest(
        command: issueUUID(94), source: issueSource,
        devices: [
          .init(
            id: issueUUID(100), node: node, index: 0, preferredSlot: nil,
            originalEquipmentName: name)
        ], fitting: .held)
      #expect(throws: EquipmentIssueError.invalidRequest) {
        try issueAdmit(bad, inventory: empty, context: context)
      }
      #expect(empty.items.isEmpty && empty.revision == 0)
    }
    let request = EquipmentIssueRequest(
      command: issueUUID(95), source: issueSource,
      devices: [
        .init(
          id: issueUUID(100), node: docking, index: 0, preferredSlot: .targetingCore,
          originalEquipmentName: Equipment.legacyDockingComputer)
      ], fitting: .held)
    let issued = try issueAdmit(request, inventory: empty, context: context)
    let obligation = issueObligation(request)
    let item = try #require(issued.inventory.items.first)
    let quote = try EquipmentIssueTransactions.quoteFitting(
      command: issueUUID(96), obligation: obligation,
      item: item, destination: .init(hullInstanceID: issueHull, slot: .targetingCore),
      replacing: nil,
      inventory: issued.inventory, context: context, obligations: [obligation],
      budget: issueBudget())
    let changedItem = OwnedEquipmentItem(
      id: item.id, node: item.node, provenance: item.provenance,
      component: item.component, location: item.location, boundHull: item.boundHull,
      preferredSlot: item.preferredSlot,
      retainedLegacyState: .init(conditionBasisPoints: 10000, modifications: [:]))
    let changed = try OwnedEquipmentInventory(
      owner: issueOwner, activeHull: issueHull,
      revision: issued.inventory.revision, items: [changedItem])
    #expect(throws: (any Error).self) {
      try EquipmentIssueTransactions.applyFitting(
        quote: quote, inventory: changed,
        context: context, obligations: [obligation], budget: issueBudget())
    }
    #expect(changed.items == [changedItem] && issued.inventory.items == [item])
  }

}
