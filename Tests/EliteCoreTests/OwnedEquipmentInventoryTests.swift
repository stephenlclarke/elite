import Foundation
import Testing

@testable import EliteCore

struct OwnedEquipmentInventoryTests {
  private let owner = UUID()
  private let hull = UUID()
  private let family = EquipmentFamilyID("shields")
  private var node: EquipmentNodeID { .init(family: family, key: "Basic Shields") }
  private var shield: ComponentFamilyDefinition { EquipmentModuleTemplates.shield }

  private func context(limit: Int = 1) -> OwnedEquipmentContext {
    .init(
      owner: owner, activeHull: hull, supportedSlots: [.shield],
      nodes: [node: .init(slots: [.shield], componentFamily: shield.family)],
      familyLimits: [family: limit], definitions: [shield.family: shield])
  }

  private func item(
    id: UUID = UUID(), fitted: Bool = false, bound: Bool = false,
    provenance: EquipmentAcquisitionProvenance = .standard
  ) -> OwnedEquipmentItem {
    .init(
      id: id, node: node, provenance: provenance,
      component: .init(id: id, origin: shield.grades[0]),
      location: fitted ? .init(hullInstanceID: hull, slot: .shield) : nil,
      boundHull: bound ? hull : nil)
  }

  @Test func explicitReplacementStoresPreviousItemAndPreservesPhysicalHistory() throws {
    let originalOwner = UUID()
    let old = item(fitted: true, bound: true)
    let next = item(provenance: .paid(owner: originalOwner, transaction: UUID()))
    var inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [old, next])
    let initial = inventory
    let location = ComponentFittingLocation(hullInstanceID: hull, slot: .shield)
    #expect(throws: OwnedEquipmentError.occupiedSlot) {
      try inventory.fit(expected: next, at: location, expectedRevision: 0, context: context())
    }
    #expect(inventory == initial)
    try inventory.fit(
      expected: next, at: location, replacing: old, expectedRevision: 0, context: context())
    #expect(inventory.revision == 1 && inventory.items.count == 2)
    let stored = try #require(inventory.items.first { $0.id == old.id })
    let fitted = try #require(inventory.items.first { $0.id == next.id })
    #expect(stored.location == nil && stored.boundHull == hull)
    #expect(stored.component == old.component && stored.provenance == old.provenance)
    #expect(fitted.location == location && fitted.provenance == next.provenance)
    #expect(fitted.component == next.component && fitted.boundHull == next.boundHull)
    try inventory.store(expected: fitted, expectedRevision: 1, context: context())
    let held = try #require(inventory.items.first { $0.id == next.id })
    #expect(held.location == nil && held.provenance == next.provenance)
    let removed = try inventory.remove(expected: stored, expectedRevision: 2, context: context())
    #expect(removed == stored && removed.boundHull == hull)
    #expect(inventory.revision == 3 && inventory.items == [held])
    // Physical paid provenance never changes its original acquisition owner.
    #expect(inventory.owner == owner && held.provenance == next.provenance)
  }

  @Test func fullItemAndRevisionPinsRefuseWithoutMutation() throws {
    let original = item(fitted: true)
    var inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [original])
    let before = inventory
    #expect(throws: OwnedEquipmentError.staleRevision) {
      try inventory.store(expected: original, expectedRevision: 1, context: context())
    }
    let altered = OwnedEquipmentItem(
      id: original.id, node: original.node, provenance: .xyzzy,
      component: original.component, location: original.location)
    #expect(throws: OwnedEquipmentError.staleItem) {
      try inventory.store(expected: altered, expectedRevision: 0, context: context())
    }
    #expect(inventory == before)
    try inventory.store(expected: original, expectedRevision: 0, context: context())
    let stored = try #require(inventory.items.first)
    let after = inventory
    #expect(throws: OwnedEquipmentError.staleItem) {
      try inventory.remove(expected: original, expectedRevision: 1, context: context())
    }
    #expect(throws: OwnedEquipmentError.noChange) {
      try inventory.store(expected: stored, expectedRevision: 1, context: context())
    }
    #expect(inventory == after)
  }

  @Test func installedCapsDoNotCountStoredItemsAndAllDeclaredStockPylonsRemainUsable() throws {
    let missileFamily = EquipmentFamilyID("missiles")
    let missile = EquipmentNodeID(family: missileFamily, key: "Standard Missile")
    let slots = Set((0..<32).map(ComponentFittingSlot.missilePylon))
    let context = OwnedEquipmentContext(
      owner: owner, activeHull: hull, supportedSlots: slots,
      nodes: [missile: .init(slots: slots)], familyLimits: [missileFamily: 32])
    let stored = (0..<33).map { _ in
      OwnedEquipmentItem(id: UUID(), node: missile, provenance: .grant("stock loadout"))
    }
    var inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: stored)
    try inventory.validate(context: context)
    for index in 0..<32 {
      try inventory.fit(
        expected: stored[index], at: .init(hullInstanceID: hull, slot: .missilePylon(index)),
        expectedRevision: UInt64(index), context: context)
    }
    #expect(inventory.items.filter { $0.location != nil }.count == 32)
    #expect(inventory.items.count == 33)
    let full = inventory
    #expect(throws: OwnedEquipmentError.unsupportedSlot) {
      try inventory.fit(
        expected: stored[32], at: .init(hullInstanceID: hull, slot: .missilePylon(32)),
        expectedRevision: 32, context: context)
    }
    #expect(inventory == full)
    let lowerCap = OwnedEquipmentContext(
      owner: owner, activeHull: hull, supportedSlots: slots,
      nodes: context.nodes, familyLimits: [missileFamily: 31])
    #expect(throws: OwnedEquipmentError.familyLimit) { try inventory.validate(context: lowerCap) }
  }

  @Test func unknownCapabilitiesForeignHullDuplicateAndCapacityFailuresAreAtomic() throws {
    let original = item(bound: true)
    var inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [original])
    let before = inventory
    #expect(throws: OwnedEquipmentError.duplicateItem) {
      try inventory.admit(original, expectedRevision: 0, context: context())
    }
    let unknown = OwnedEquipmentItem(
      id: UUID(), node: .init(family: family, key: "unknown"), provenance: .legacyUnknown)
    #expect(throws: OwnedEquipmentError.unknownNode) {
      try inventory.admit(unknown, expectedRevision: 0, context: context())
    }
    #expect(throws: OwnedEquipmentError.wrongHull) {
      try inventory.fit(
        expected: original, at: .init(hullInstanceID: UUID(), slot: .shield),
        expectedRevision: 0, context: context())
    }
    let noFamily = OwnedEquipmentContext(
      owner: owner, activeHull: hull, supportedSlots: [.shield], nodes: context().nodes,
      familyLimits: [:], definitions: context().definitions)
    #expect(throws: OwnedEquipmentError.unknownFamily) {
      try inventory.validate(context: noFamily)
    }
    #expect(inventory == before)
    let records = (0..<256).map { _ in item() }
    var maximum = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: records)
    let full = maximum
    #expect(throws: OwnedEquipmentError.capacity) {
      try maximum.admit(item(), expectedRevision: 0, context: context())
    }
    #expect(maximum == full)
    let alienBound = OwnedEquipmentItem(
      id: UUID(), node: node, provenance: .reward("mission"), boundHull: UUID())
    #expect(throws: OwnedEquipmentError.wrongHull) {
      try inventory.admit(alienBound, expectedRevision: 0, context: context())
    }
    #expect(inventory == before)
  }

  @Test func gradedReplacementUsesSealedProofAndIndependentSourceRevision() throws {
    let original = item(fitted: true, bound: true, provenance: .xyzzy)
    let component = try #require(original.component)
    let effect = ComponentUpgrade(
      identity: .service(UUID()), boundComponent: component.id, origin: component.origin.identity,
      basisPoints: [.frontShieldCapacity: 1500])
    let quote = try ComponentProgression.quote(
      component: component, item: effect, definition: shield, inventoryRevision: 77)
    let application = try ComponentProgression.apply(
      quote, component: component, item: effect, definition: shield, inventoryRevision: 77)
    var inventory = try OwnedEquipmentInventory(
      owner: owner, activeHull: hull, revision: 4, items: [original])
    let before = inventory
    #expect(throws: ComponentProgressionError.inventoryChanged) {
      try inventory.replaceGradedInstance(
        expected: original, application: application, expectedRevision: 4,
        sourceInventoryRevision: 78, context: context())
    }
    #expect(inventory == before)
    try inventory.replaceGradedInstance(
      expected: original, application: application, expectedRevision: 4,
      sourceInventoryRevision: 77, context: context())
    let result = try #require(inventory.items.first)
    #expect(result.component == application.component && result.id == original.id)
    #expect(result.location == original.location && result.boundHull == original.boundHull)
    #expect(result.provenance == original.provenance && result.node == original.node)
    #expect(inventory.revision == 5)
    let applied = inventory
    #expect(throws: OwnedEquipmentError.staleItem) {
      try inventory.replaceGradedInstance(
        expected: original, application: application, expectedRevision: 5,
        sourceInventoryRevision: 77, context: context())
    }
    #expect(inventory == applied)
  }

  @Test func decodingIsBoundedAndComponentValidationUsesExplicitFamilyMapping() throws {
    let original = item()
    let inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [original])
    let data = try JSONEncoder().encode(inventory)
    let restored = try JSONDecoder().decode(OwnedEquipmentInventory.self, from: data)
    #expect(restored == inventory)
    try restored.validate(context: context())
    let mismatched = OwnedEquipmentContext(
      owner: owner, activeHull: hull, supportedSlots: [.shield],
      nodes: [
        node: .init(slots: [.shield], componentFamily: EquipmentModuleTemplates.energy.family)
      ],
      familyLimits: [family: 1], definitions: context().definitions)
    #expect(throws: OwnedEquipmentError.incompatibleComponent) {
      try restored.validate(context: mismatched)
    }
    let badID = OwnedEquipmentItem(
      id: UUID(), node: node, provenance: .standard, component: original.component)
    #expect(throws: OwnedEquipmentError.invalidStructure) {
      _ = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [badID])
    }
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let record = try #require((object["items"] as? [[String: Any]])?.first)
    object["items"] = Array(repeating: record, count: 257)
    let overfull = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: OwnedEquipmentError.capacity) {
      _ = try JSONDecoder().decode(OwnedEquipmentInventory.self, from: overfull)
    }
    let exhausted = try OwnedEquipmentInventory(
      owner: owner, activeHull: hull, revision: UInt64.max, items: [original])
    var copy = exhausted
    #expect(throws: OwnedEquipmentError.revisionExhausted) {
      try copy.remove(expected: original, expectedRevision: UInt64.max, context: context())
    }
    #expect(copy == exhausted)
  }

  @Test func gradedNodesCannotBypassLoadedValidationWithMissingOrMalformedInstances() throws {
    var inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull)
    let missing = OwnedEquipmentItem(id: UUID(), node: node, provenance: .legacyUnknown)
    let before = inventory
    #expect(throws: OwnedEquipmentError.incompatibleComponent) {
      try inventory.admit(missing, expectedRevision: 0, context: context())
    }
    #expect(inventory == before)
    let raw = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [missing])
    let loaded = try JSONDecoder().decode(
      OwnedEquipmentInventory.self, from: JSONEncoder().encode(raw))
    #expect(throws: OwnedEquipmentError.incompatibleComponent) {
      try loaded.validate(context: context())
    }
    let id = UUID()
    var statistics = shield.grades[0].statistics
    statistics[.frontShieldCapacity] = .nan
    let malformed = OwnedEquipmentItem(
      id: id, node: node, provenance: .standard,
      component: .init(id: id, origin: shield.grades[0], statistics: statistics))
    #expect(throws: ComponentProgressionError.invalidInstance) {
      try inventory.admit(malformed, expectedRevision: 0, context: context())
    }
    #expect(inventory == before)
    let foreign = OwnedEquipmentContext(
      owner: UUID(), activeHull: hull, supportedSlots: [.shield], nodes: context().nodes,
      familyLimits: [family: 1], definitions: context().definitions)
    #expect(throws: OwnedEquipmentError.wrongOwner) {
      try inventory.admit(item(), expectedRevision: 0, context: foreign)
    }
    #expect(inventory == before)
  }
}
