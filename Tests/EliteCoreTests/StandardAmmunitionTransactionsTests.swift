import Foundation
import Testing

@testable import EliteCore

private let ammoOwner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private let ammoHull = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
private func ammoID(_ index: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 100))!
}
private func ammoContext(_ count: Int = 4, owner: UUID = ammoOwner) -> OwnedEquipmentContext {
  let slots = Set((0..<count).map(ComponentFittingSlot.missilePylon))
  return .init(
    owner: owner, activeHull: ammoHull, supportedSlots: slots,
    nodes: [EquipmentRuntimeCatalog.standardMissile: .init(slots: slots)],
    familyLimits: [EquipmentRuntimeCatalog.ammunitionFamily: count])
}
private func ammoRound(
  _ index: Int, pylon: Int? = nil,
  provenance: EquipmentAcquisitionProvenance = .standard
) -> OwnedEquipmentItem {
  .init(
    id: ammoID(index), node: EquipmentRuntimeCatalog.standardMissile, provenance: provenance,
    location: pylon.map { .init(hullInstanceID: ammoHull, slot: .missilePylon($0)) },
    preferredSlot: .missilePylon(0),
    retainedLegacyState: .init(conditionBasisPoints: 10000, modifications: [:]))
}
private func ammoInventory(_ items: [OwnedEquipmentItem], revision: UInt64 = 0) throws
  -> OwnedEquipmentInventory
{
  try .init(owner: ammoOwner, activeHull: ammoHull, revision: revision, items: items)
}
private func ammoIssue(
  _ item: OwnedEquipmentItem, loan: Bool = true,
  status: EquipmentIssueStatus = .issued
) -> EquipmentIssueObligationSnapshot {
  .init(
    source: .init(
      mission: ammoID(900), resource: "rounds", packDigest: String(repeating: "a", count: 64)),
    node: item.node, items: [item.id], consumed: [], status: status, loan: loan,
    returnRemaining: true, displacements: [])
}
private func issuedAmmo(_ index: Int, pylon: Int? = nil) -> OwnedEquipmentItem {
  .init(
    id: ammoID(index), node: EquipmentRuntimeCatalog.standardMissile,
    provenance: .missionIssue(
      mission: ammoID(900), resource: "rounds", index: 0,
      packDigest: String(repeating: "a", count: 64)),
    location: pylon.map { .init(hullInstanceID: ammoHull, slot: .missilePylon($0)) })
}

struct StandardAmmunitionTransactionsTests {
  @Test func highestOccupiedNativePylonWinsIndependentlyOfArrayOrderAcrossOneToThirtyTwo() throws {
    for capacity in 1...32 {
      let context = ammoContext(capacity)
      let rounds = (0..<capacity).map { ammoRound($0, pylon: $0) }
      let held = ammoRound(80)
      let inventory = try ammoInventory([held] + rounds.reversed())
      let quote = try StandardAmmunitionTransactions.quoteConsumption(
        unlimited: false,
        inventory: inventory, context: context, obligations: [])
      let selected = rounds[capacity - 1]
      #expect(quote.source == .physical(item: selected.id) && quote.removedItem == selected)
      let applied = try StandardAmmunitionTransactions.applyConsumption(
        quote: quote,
        inventory: inventory, context: context, obligations: [])
      #expect(applied.removedItem == selected && applied.inventory.revision == 1)
      #expect(applied.inventory.items == inventory.items.filter { $0.id != selected.id })
      #expect(applied.inventory.items.contains(held))
      #expect(throws: StandardAmmunitionError.staleRound) {
        try StandardAmmunitionTransactions.applyConsumption(
          quote: quote,
          inventory: applied.inventory, context: context, obligations: [])
      }
    }
    let low = ammoRound(1, pylon: 0)
    let high = ammoRound(2, pylon: 3)
    let held = ammoRound(3)
    let sparse = try ammoInventory([held, high, low])
    let quote = try StandardAmmunitionTransactions.quoteConsumption(
      unlimited: false,
      inventory: sparse, context: ammoContext(), obligations: [])
    #expect(quote.removedItem == high && quote.source == .physical(item: high.id))
    let consumed = try StandardAmmunitionTransactions.applyConsumption(
      quote: quote,
      inventory: sparse, context: ammoContext(), obligations: [])
    #expect(consumed.inventory.items == [held, low] && consumed.inventory.revision == 1)

  }

  @Test func loadingMovesExactHeldRoundInOneRevisionAndReturnsNoConsumption() throws {
    let item = ammoRound(1)
    let inventory = try ammoInventory([item])
    let context = ammoContext()
    let destination = ComponentFittingLocation(hullInstanceID: ammoHull, slot: .missilePylon(3))
    let quote = try StandardAmmunitionTransactions.quoteLoad(
      item: item, destination: destination,
      inventory: inventory, context: context, obligations: [])
    #expect(inventory.items == [item] && inventory.revision == 0)
    let applied = try StandardAmmunitionTransactions.applyLoad(
      quote: quote,
      inventory: inventory, context: context, obligations: [])
    #expect(applied.inventory.revision == 1 && applied.fittedItem == item.moved(to: destination))
    #expect(applied.fittedItem.id == item.id && applied.fittedItem.provenance == item.provenance)
    #expect(applied.fittedItem.retainedLegacyState == item.retainedLegacyState)
    #expect(applied.fittedItem.preferredSlot == item.preferredSlot)
    #expect(throws: StandardAmmunitionError.staleRound) {
      try StandardAmmunitionTransactions.applyLoad(
        quote: quote, inventory: applied.inventory,
        context: context, obligations: [])
    }
  }

  @Test func nonpristineHeldLegacyRoundCannotBeActivatedAndRemainsOwned() throws {
    let item = OwnedEquipmentItem(
      id: ammoID(1), node: EquipmentRuntimeCatalog.standardMissile,
      provenance: .legacyUnknown, preferredSlot: .missilePylon(0),
      retainedLegacyState: .init(conditionBasisPoints: 9000, modifications: ["calibration": 1]))
    let inventory = try ammoInventory([item])
    let context = ammoContext()
    #expect(throws: StandardAmmunitionError.unsupportedProfile) {
      try StandardAmmunitionTransactions.quoteLoad(
        item: item,
        destination: .init(hullInstanceID: ammoHull, slot: .missilePylon(0)),
        inventory: inventory, context: context, obligations: [])
    }
    #expect(inventory.items == [item] && inventory.revision == 0)
  }

  @Test func virtualUseLeavesActualRoundsLoanObligationsAndExhaustedRevisionUntouched() throws {
    let item = issuedAmmo(1, pylon: 2)
    let obligation = ammoIssue(item)
    let inventory = try ammoInventory([item], revision: UInt64.max)
    let context = ammoContext()
    let quote = try StandardAmmunitionTransactions.quoteConsumption(
      unlimited: true,
      inventory: inventory, context: context, obligations: [obligation])
    let applied = try StandardAmmunitionTransactions.applyConsumption(
      quote: quote,
      inventory: inventory, context: context, obligations: [obligation])
    #expect(applied.source == .virtualUnlimited && applied.removedItem == nil)
    #expect(applied.inventory == inventory && obligation.consumed.isEmpty)
    #expect(throws: OwnedEquipmentError.revisionExhausted) {
      try StandardAmmunitionTransactions.quoteConsumption(
        unlimited: false,
        inventory: inventory, context: context, obligations: [obligation])
    }
  }

  @Test func activeLoanCannotUseGenericLoadButPhysicalConsumptionReturnsActualOriginal() throws {
    let held = issuedAmmo(1)
    let obligation = ammoIssue(held)
    let context = ammoContext()
    let inventory = try ammoInventory([held])
    #expect(throws: EquipmentIssueError.foreignLoan(held.id)) {
      try StandardAmmunitionTransactions.quoteLoad(
        item: held,
        destination: .init(hullInstanceID: ammoHull, slot: .missilePylon(0)),
        inventory: inventory, context: context, obligations: [obligation])
    }
    let fitted = held.moved(to: .init(hullInstanceID: ammoHull, slot: .missilePylon(3)))
    let loaded = try ammoInventory([fitted])
    let quote = try StandardAmmunitionTransactions.quoteConsumption(
      unlimited: false,
      inventory: loaded, context: context, obligations: [obligation])
    let application = try StandardAmmunitionTransactions.applyConsumption(
      quote: quote,
      inventory: loaded, context: context, obligations: [obligation])
    #expect(application.removedItem == fitted && application.inventory.items.isEmpty)
    #expect(application.source == .physical(item: held.id) && obligation.consumed.isEmpty)
  }

  @Test func physicalLoadQuoteRejectsExhaustedRevisionBeforePublishingAPreview() throws {
    let item = ammoRound(1)
    let inventory = try ammoInventory([item], revision: UInt64.max)
    #expect(throws: OwnedEquipmentError.revisionExhausted) {
      try StandardAmmunitionTransactions.quoteLoad(
        item: item,
        destination: .init(hullInstanceID: ammoHull, slot: .missilePylon(0)),
        inventory: inventory, context: ammoContext(), obligations: [])
    }
    #expect(inventory.items == [item] && inventory.revision == UInt64.max)
  }

  @Test func staleWholeFactsContextAndObligationsFailBeforeAnyMutation() throws {
    let item = ammoRound(1, pylon: 1)
    let inventory = try ammoInventory([item])
    let context = ammoContext()
    let quote = try StandardAmmunitionTransactions.quoteConsumption(
      unlimited: false,
      inventory: inventory, context: context, obligations: [])
    let changed = try ammoInventory([ammoRound(1, pylon: 2)])
    for current in [changed, try ammoInventory([item], revision: 1)] {
      #expect(throws: StandardAmmunitionError.staleRound) {
        try StandardAmmunitionTransactions.applyConsumption(
          quote: quote,
          inventory: current, context: context, obligations: [])
      }
    }
    #expect(throws: StandardAmmunitionError.staleRound) {
      try StandardAmmunitionTransactions.applyConsumption(
        quote: quote,
        inventory: inventory, context: ammoContext(3), obligations: [])
    }
    #expect(throws: StandardAmmunitionError.staleRound) {
      try StandardAmmunitionTransactions.applyConsumption(
        quote: quote,
        inventory: inventory, context: context, obligations: [ammoIssue(item)])
    }
    #expect(inventory.items == [item] && inventory.revision == 0)
  }

  @Test func emptyAndHeldOnlyRackCannotSupplyFiniteRoundAndInvalidLoadsRefuse() throws {
    let held = ammoRound(1)
    let context = ammoContext()
    for inventory in [try ammoInventory([]), try ammoInventory([held])] {
      #expect(throws: StandardAmmunitionError.noFiniteRound) {
        try StandardAmmunitionTransactions.quoteConsumption(
          unlimited: false,
          inventory: inventory, context: context, obligations: [])
      }
      let virtual = try StandardAmmunitionTransactions.quoteConsumption(
        unlimited: true,
        inventory: inventory, context: context, obligations: [])
      #expect(virtual.source == .virtualUnlimited)
    }
    let occupied = ammoRound(2, pylon: 1)
    let inventory = try ammoInventory([held, occupied])
    #expect(throws: OwnedEquipmentError.occupiedSlot) {
      try StandardAmmunitionTransactions.quoteLoad(
        item: held,
        destination: .init(hullInstanceID: ammoHull, slot: .missilePylon(1)),
        inventory: inventory, context: context, obligations: [])
    }
    for slot in [
      ComponentFittingSlot.missilePylon(-1), .missilePylon(4), .missilePylon(32), .shield,
    ] {
      #expect(throws: StandardAmmunitionError.unsupportedProfile) {
        try StandardAmmunitionTransactions.quoteLoad(
          item: held,
          destination: .init(hullInstanceID: ammoHull, slot: slot),
          inventory: inventory, context: context, obligations: [])
      }
    }
    #expect(throws: OwnedEquipmentError.wrongOwner) {
      try StandardAmmunitionTransactions.quoteConsumption(
        unlimited: true,
        inventory: inventory, context: ammoContext(owner: ammoID(999)), obligations: [])
    }
  }
}
