import Foundation
import Testing

@testable import EliteCore

private func receiptID(_ value: Int) -> UUID {
  UUID(uuidString: String(format: "41000000-0000-0000-0000-%012d", value))!
}

private struct ScriptReceiptFixture {
  let source = EquipmentIssueSource(
    mission: receiptID(3), resource: "original", packDigest: String(repeating: "a", count: 64))
  let context: OwnedEquipmentContext
  let budget: EquipmentFitBudgetSnapshot
  let personal: OwnedEquipmentItem
  let location = ComponentFittingLocation(hullInstanceID: receiptID(2), slot: .energy)
  var inventory: OwnedEquipmentInventory
  var engine: ScriptEngineState

  init() throws {
    context = EquipmentRuntimeCatalog.context(
      owner: receiptID(1), hull: receiptID(2), performance: Commander().nativePerformance)
    budget = .init(
      equipmentCapacity: 100, reservedEquipmentUnits: 0,
      nodeEquipmentUnits: Dictionary(
        uniqueKeysWithValues: EquipmentRuntimeCatalog.graph.nodes.map {
          ($0.id, Commander.commonEquipmentUnitCost(for: $0.id))
        }), projectedCargoCapacity: 20, occupiedCargoTonnes: 0, accommodationAllowed: true)
    let basic = try #require(EquipmentRuntimeCatalog.node(for: "Basic Energy System"))
    personal = .init(
      id: receiptID(20), node: basic, provenance: .standard,
      component: EquipmentRuntimeCatalog.stockComponent(for: basic, id: receiptID(20)),
      location: location)
    let initial = try OwnedEquipmentInventory(
      owner: receiptID(1), activeHull: receiptID(2), items: [personal])
    let node = try #require(EquipmentRuntimeCatalog.node(for: "Extra Energy Unit"))
    let request = EquipmentIssueRequest(
      command: receiptID(4), source: source,
      devices: [.init(id: receiptID(100), node: node, index: 0, preferredSlot: .energy)],
      fitting: .held)
    let quote = try EquipmentIssueTransactions.quoteAdmission(
      request: request, inventory: initial, context: context, obligations: [], budget: budget)
    inventory = try EquipmentIssueTransactions.applyAdmission(
      quote: quote, inventory: initial, context: context, obligations: [], budget: budget
    ).inventory
    var instance = ScriptInstance(
      id: source.mission, definition: "fixture.receipt/gear", version: "1.0.0",
      digest: source.packDigest)
    instance.gearIssues[source.resource] = .init(
      resource: source.resource, kind: .module("Extra Energy Unit"), items: [receiptID(100)],
      loan: true, returnRemaining: true, savedGearVersion: 2, source: source, node: node,
      displacements: [])
    engine = ScriptEngineState()
    engine.instances[source.mission] = instance
  }

  var record: ScriptGearIssue { engine.instances[source.mission]!.gearIssues[source.resource]! }

  mutating func refit() throws -> EquipmentIssueReceipt {
    let obligation = try #require(record.obligation)
    let item = try #require(inventory.items.first { $0.id == receiptID(100) })
    let quote = try EquipmentIssueTransactions.quoteFitting(
      command: receiptID(5), obligation: obligation, item: item, destination: location,
      replacing: personal, inventory: inventory, context: context, obligations: [obligation],
      budget: budget)
    let applied = try EquipmentIssueTransactions.applyFitting(
      quote: quote, inventory: inventory, context: context, obligations: [obligation],
      budget: budget)
    inventory = applied.inventory
    return applied.receipt
  }
}

struct ScriptEquipmentReceiptTests {
  @Test func actualRefitAndStoreReceiptsRetainNewDisplacementsAndPermitLedgerIdempotence() throws {
    var fixture = try ScriptReceiptFixture()
    let original = fixture.record
    let refit = try fixture.refit()
    let afterRefit = try fixture.engine.applying(refit)
    #expect(fixture.record == original)
    fixture.engine = afterRefit
    #expect(
      fixture.record.displacements == [.init(item: fixture.personal.id, location: fixture.location)]
    )
    #expect(fixture.record.source == original.source && fixture.record.items == original.items)
    #expect(fixture.record.consumed == original.consumed && fixture.record.loan)
    let obligation = try #require(fixture.record.obligation)
    let item = try #require(fixture.inventory.items.first { $0.id == receiptID(100) })
    let quote = try EquipmentIssueTransactions.quoteFitting(
      command: receiptID(6), obligation: obligation, item: item, destination: nil, replacing: nil,
      inventory: fixture.inventory, context: fixture.context, obligations: [obligation],
      budget: fixture.budget)
    let stored = try EquipmentIssueTransactions.applyFitting(
      quote: quote, inventory: fixture.inventory, context: fixture.context,
      obligations: [obligation], budget: fixture.budget)
    let staged = try fixture.engine.applying(stored.receipt)
    #expect(staged == fixture.engine)
    #expect(try staged.applying(stored.receipt) == staged)
    #expect(stored.inventory.items.first { $0.id == item.id }?.location == nil)
    #expect(throws: OwnedEquipmentError.staleRevision) {
      try EquipmentIssueTransactions.applyFitting(
        quote: quote, inventory: stored.inventory, context: fixture.context,
        obligations: [obligation], budget: fixture.budget)
    }
  }

  @Test(arguments: [EquipmentIssueSettlement.returnOriginals, .releaseLoan])
  func actualSettlementReceiptsChangeOnlyTheirStatusAndRetainHistory(
    operation: EquipmentIssueSettlement
  )
    throws
  {
    var fixture = try ScriptReceiptFixture()
    let refit = try fixture.refit()
    fixture.engine = try fixture.engine.applying(refit)
    let original = fixture.record
    let obligation = try #require(original.obligation)
    let quote = try EquipmentIssueTransactions.quoteSettlement(
      command: receiptID(7), operation: operation, obligation: obligation,
      inventory: fixture.inventory, context: fixture.context, obligations: [obligation],
      budget: fixture.budget)
    let applied = try EquipmentIssueTransactions.applySettlement(
      quote: quote, inventory: fixture.inventory, context: fixture.context,
      obligations: [obligation], budget: fixture.budget)
    let staged = try fixture.engine.applying(applied.receipt)
    var expected = original
    expected.status = operation == .returnOriginals ? .returned : .released
    #expect(
      staged.instances[fixture.source.mission]?.gearIssues[fixture.source.resource] == expected)
    #expect(fixture.record == original)
    if operation == .returnOriginals {
      #expect(applied.inventory.items.first { $0.id == fixture.personal.id } == fixture.personal)
      #expect(!applied.inventory.items.contains { $0.id == receiptID(100) })
    } else {
      #expect(applied.inventory.items == fixture.inventory.items)
    }
  }

  @Test(arguments: ["consumed", "source", "displacement"])
  func changedRetainedRecordRefusesAnActualReceiptWithoutChangingState(field: String) throws {
    var fixture = try ScriptReceiptFixture()
    let receipt = try fixture.refit()
    let original = fixture.record
    var changed = original
    switch field {
    case "consumed": changed.consumed.insert(receiptID(100))
    case "source":
      changed = .init(
        resource: original.resource, kind: original.kind, items: original.items, loan: true,
        returnRemaining: true, savedGearVersion: 2,
        source: .init(
          mission: receiptID(99), resource: original.resource,
          packDigest: fixture.source.packDigest), node: original.node, displacements: [])
    default:
      changed = original.replacingDisplacements([
        .init(item: receiptID(21), location: fixture.location)
      ])
    }
    let source = fixture.source
    var selected = try #require(fixture.engine.instances[source.mission])
    selected.gearIssues[source.resource] = changed
    fixture.engine.instances[source.mission] = selected
    let before = fixture.engine
    #expect(throws: EquipmentIssueError.staleObligation) { try fixture.engine.applying(receipt) }
    #expect(fixture.engine == before)
  }
}
