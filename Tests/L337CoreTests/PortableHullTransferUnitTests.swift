import Foundation
import Testing

@testable import L337Core

struct PortableHullTransferUnitTests {
  private func fixture() throws -> (OwnedEquipmentInventory, OwnedEquipmentContext) {
    let owner = UUID()
    let sourceHull = UUID()
    let source = try #require(ShipCatalogue.ship("SH023")?.game)
    let destination = try #require(ShipCatalogue.ship("SH001")?.game)
    var items: [OwnedEquipmentItem] = (0..<4).map { index in
      .init(
        id: UUID(), node: EquipmentRuntimeCatalog.standardMissile,
        provenance: .paid(owner: owner, transaction: UUID()),
        location: .init(hullInstanceID: sourceHull, slot: .missilePylon(index)))
    }
    let laser = try #require(EquipmentRuntimeCatalog.node(for: LaserKind.military.equipmentName))
    let lot = SalvageLotIdentity(
      section: .init(
        wreck: .init(system: .init(galaxy: 0, system: 7), site: 4, lineage: 400), section: 1),
      lot: 1)
    items += LaserMount.allCases.map { mount in
      .init(
        id: UUID(), node: laser, provenance: .recovered(lot),
        location: .init(hullInstanceID: sourceHull, slot: .laser(mount)),
        preferredSlot: .laser(mount))
    }
    let energy = try #require(
      EquipmentRuntimeCatalog.graph.nodes.first {
        $0.id.family == EquipmentPurchaseCatalog.energy
      }?.id)
    let componentID = UUID()
    items.append(
      .init(
        id: componentID, node: energy, provenance: .grant("transfer-component"),
        component: EquipmentRuntimeCatalog.stockComponent(for: energy, id: componentID),
        location: .init(hullInstanceID: sourceHull, slot: .energy)))
    let shield = try #require(
      EquipmentRuntimeCatalog.graph.nodes.first {
        $0.id.family == EquipmentPurchaseCatalog.shields
      }?.id)
    let boundID = UUID()
    items.append(
      .init(
        id: boundID, node: shield, provenance: .standard,
        component: EquipmentRuntimeCatalog.stockComponent(for: shield, id: boundID),
        location: .init(hullInstanceID: sourceHull, slot: .shield), boundHull: sourceHull))
    let inventory = try OwnedEquipmentInventory(owner: owner, activeHull: sourceHull, items: items)
    try inventory.validate(
      context: EquipmentRuntimeCatalog.context(
        owner: owner, hull: sourceHull, performance: source))
    return (
      inventory,
      EquipmentRuntimeCatalog.context(
        owner: owner, hull: UUID(), performance: destination)
    )
  }

  @Test func smallerHullStoresPortableOverflowWithItsActualItemAndComponentHistory() throws {
    let (original, context) = try fixture()
    let transferred = try original.transferringPortableItems(to: context)
    #expect(transferred.owner == original.owner && transferred.activeHull == context.activeHull)
    #expect(transferred.revision == original.revision + 1)
    #expect(transferred.items.map(\.id) == original.items.filter { $0.boundHull == nil }.map(\.id))
    for before in original.items where before.boundHull == nil {
      let after = try #require(transferred.items.first { $0.id == before.id })
      #expect(after.node == before.node && after.provenance == before.provenance)
      #expect(after.component == before.component && after.preferredSlot == before.preferredSlot)
      #expect(after.retainedLegacyState == before.retainedLegacyState)
      if let slot = before.location?.slot, !context.supportedSlots.contains(slot) {
        #expect(after.location == nil)
      }
      if let location = after.location { #expect(location.hullInstanceID == context.activeHull) }
    }
    let rounds = transferred.items.filter { $0.node == EquipmentRuntimeCatalog.standardMissile }
    #expect(rounds.count == 4 && rounds.filter { $0.location != nil }.count == 1)
    #expect(transferred.items.contains { $0.location == nil })
    try transferred.validate(context: context)
  }

  @Test func installedFamilyLimitStoresExcessEvenWhenSlotsRemainSupported() throws {
    let (original, _) = try fixture()
    let large = EquipmentRuntimeCatalog.context(
      owner: original.owner, hull: UUID(),
      performance: try #require(ShipCatalogue.ship("SH023")?.game))
    var limits = large.familyLimits
    limits[EquipmentRuntimeCatalog.ammunitionFamily] = 1
    let limited = OwnedEquipmentContext(
      owner: large.owner, activeHull: large.activeHull, supportedSlots: large.supportedSlots,
      nodes: large.nodes, familyLimits: limits, definitions: large.definitions)
    let transferred = try original.transferringPortableItems(to: limited)
    let rounds = transferred.items.filter { $0.node == EquipmentRuntimeCatalog.standardMissile }
    #expect(rounds.count == 4 && rounds.filter { $0.location != nil }.count == 1)
    try transferred.validate(context: limited)
  }

  @Test func returningToALargerHullDoesNotRefitStoredSparesOrRecreateSoldBoundItems() throws {
    let (original, small) = try fixture()
    let transferred = try original.transferringPortableItems(to: small)
    let large = EquipmentRuntimeCatalog.context(
      owner: original.owner, hull: UUID(),
      performance: try #require(ShipCatalogue.ship("SH023")?.game))
    let returned = try transferred.transferringPortableItems(to: large)
    #expect(returned.items.map(\.id) == transferred.items.map(\.id))
    for item in transferred.items where item.location == nil {
      #expect(returned.items.first { $0.id == item.id } == item)
    }
    #expect(returned.items.allSatisfy { $0.boundHull == nil })
    try returned.validate(context: large)
  }

  @Test func foreignOwnerUnknownNodeAndExhaustedRevisionRefuseWithoutChangingSource() throws {
    let (original, context) = try fixture()
    let before = original
    let foreign = OwnedEquipmentContext(
      owner: UUID(), activeHull: context.activeHull, supportedSlots: context.supportedSlots,
      nodes: context.nodes, familyLimits: context.familyLimits, definitions: context.definitions)
    #expect(throws: OwnedEquipmentError.wrongOwner) {
      try original.transferringPortableItems(to: foreign)
    }
    let unknown = OwnedEquipmentContext(
      owner: context.owner, activeHull: context.activeHull, supportedSlots: context.supportedSlots,
      nodes: [:], familyLimits: context.familyLimits, definitions: context.definitions)
    #expect(throws: OwnedEquipmentError.unknownNode) {
      try original.transferringPortableItems(to: unknown)
    }
    let exhausted = try OwnedEquipmentInventory(
      owner: original.owner, activeHull: original.activeHull, revision: .max, items: original.items)
    #expect(throws: OwnedEquipmentError.revisionExhausted) {
      try exhausted.transferringPortableItems(to: context)
    }
    #expect(original == before)
  }
}
