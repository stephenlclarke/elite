import Foundation
import Testing

@testable import L337Core

struct EquipmentMissionIssueSchemaTests {
  private let owner = UUID()
  private let hull = UUID()
  private var node: EquipmentNodeID { EquipmentRuntimeCatalog.standardMissile }
  private var context: OwnedEquipmentContext {
    EquipmentRuntimeCatalog.context(
      owner: owner, hull: hull, performance: Commander().nativePerformance)
  }
  private var source: EquipmentIssueSource {
    .init(mission: UUID(), resource: "loan-rounds", packDigest: String(repeating: "a", count: 64))
  }

  @Test func typedIssueMetadataRoundTripsAndEveryMovePreservesIt() throws {
    let source = source
    let item = OwnedEquipmentItem(
      id: UUID(), node: node,
      provenance: .missionIssue(
        mission: source.mission, resource: source.resource, index: 0, packDigest: source.packDigest),
      preferredSlot: .missilePylon(1),
      retainedLegacyState: .init(conditionBasisPoints: 10000, modifications: [:]))
    let fitted = item.moved(to: .init(hullInstanceID: hull, slot: .missilePylon(0)))
    #expect(fitted.id == item.id && fitted.provenance == item.provenance)
    #expect(fitted.preferredSlot == item.preferredSlot)
    #expect(fitted.retainedLegacyState == item.retainedLegacyState)
    #expect(fitted.moved(to: nil) == item)
    let inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [fitted])
    try inventory.validate(context: context)
    let restored = try JSONDecoder().decode(
      OwnedEquipmentInventory.self, from: JSONEncoder().encode(inventory))
    #expect(restored == inventory)
  }

  @Test func oldPhysicalItemsAndAttackOriginsDecodeWithoutNewFields() throws {
    let item = OwnedEquipmentItem(id: UUID(), node: node, provenance: .legacyUnknown)
    var record = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
    record.removeValue(forKey: "preferredSlot")
    record.removeValue(forKey: "retainedLegacyState")
    let restored = try JSONDecoder().decode(
      OwnedEquipmentItem.self, from: JSONSerialization.data(withJSONObject: record))
    #expect(restored == item)
    let actor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 2)
    let origin = AttackOrigin(
      emissionID: 3, owner: actor, emittedAt: 4, ownerLegalAtEmission: .init(),
      playerAmmunition: .physical(item: item.id))
    var attack = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(origin)) as? [String: Any])
    attack.removeValue(forKey: "playerAmmunition")
    let old = try JSONDecoder().decode(
      AttackOrigin.self, from: JSONSerialization.data(withJSONObject: attack))
    #expect(old.playerAmmunition == nil && old.owner == actor && old.emissionID == 3)
    let current = try JSONDecoder().decode(
      AttackOrigin.self, from: JSONEncoder().encode(origin))
    #expect(current == origin)
    let virtual = PlayerAmmunitionSource.virtualUnlimited
    #expect(
      try JSONDecoder().decode(PlayerAmmunitionSource.self, from: JSONEncoder().encode(virtual))
        == virtual)
  }

  @Test func atomicBatchHasOneRevisionAndRejectsStaleOrInvalidCandidates() throws {
    let first = OwnedEquipmentItem(id: UUID(), node: node, provenance: .standard)
    let inventory = try OwnedEquipmentInventory(
      owner: owner, activeHull: hull, revision: 8, items: [first])
    let unchanged = try inventory.applyingBatch(
      items: inventory.items, expectedRevision: 8, context: context)
    #expect(unchanged.items == inventory.items && unchanged.revision == 9)
    #expect(inventory.revision == 8)
    #expect(throws: OwnedEquipmentError.staleRevision) {
      try inventory.applyingBatch(items: [], expectedRevision: 7, context: context)
    }
    #expect(throws: OwnedEquipmentError.duplicateItem) {
      try inventory.applyingBatch(items: [first, first], expectedRevision: 8, context: context)
    }
    let exhausted = try OwnedEquipmentInventory(owner: owner, activeHull: hull, revision: .max)
    #expect(throws: OwnedEquipmentError.revisionExhausted) {
      try exhausted.applyingBatch(items: [], expectedRevision: .max, context: context)
    }
  }

  @Test func retainedDamageIsHeldOnlyAndMalformedIssueSourcesCannotEnterInventory() throws {
    let damaged = OwnedEquipmentItem(
      id: UUID(), node: node, provenance: .legacyUnknown, preferredSlot: .missilePylon(0),
      retainedLegacyState: .init(conditionBasisPoints: 9000, modifications: ["guidance": 12]))
    var inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [damaged])
    try inventory.validate(context: context)
    let original = inventory
    #expect(throws: OwnedEquipmentError.invalidStructure) {
      try inventory.fit(
        expected: damaged, at: .init(hullInstanceID: hull, slot: .missilePylon(0)),
        expectedRevision: 0, context: context)
    }
    #expect(inventory == original)
    for (index, resource, digest) in [
      (-1, "rounds", String(repeating: "a", count: 64)),
      (32, "rounds", String(repeating: "a", count: 64)),
      (0, "../rounds", String(repeating: "a", count: 64)),
      (0, "rounds", "short"),
    ] {
      let invalid = OwnedEquipmentItem(
        id: UUID(), node: node,
        provenance: .missionIssue(
          mission: UUID(), resource: resource, index: index, packDigest: digest))
      #expect(throws: OwnedEquipmentError.invalidStructure) {
        try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [invalid])
      }
    }
    let boundRound = OwnedEquipmentItem(
      id: UUID(), node: node, provenance: .standard, boundHull: hull)
    #expect(throws: OwnedEquipmentError.invalidStructure) {
      try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [boundRound])
    }
  }

  @Test func stockAmmunitionContextExposesExactlyTheNativePylons() throws {
    #expect(EquipmentRuntimeCatalog.node(for: "Missile") == node)
    let count = Commander().nativePerformance.missiles
    let capability = try #require(context.nodes[node])
    #expect(capability.slots == Set((0..<count).map(ComponentFittingSlot.missilePylon)))
    #expect(context.familyLimits[node.family] == count && capability.componentFamily == nil)
    let unsupported = OwnedEquipmentItem(
      id: UUID(), node: node, provenance: .standard,
      location: .init(hullInstanceID: hull, slot: .missilePylon(count)))
    let inventory = try OwnedEquipmentInventory(
      owner: owner, activeHull: hull, items: [unsupported])
    #expect(throws: OwnedEquipmentError.unsupportedSlot) {
      try inventory.validate(context: context)
    }
  }

  @Test func legacyAbsenceSnapshotCannotConcealAConsumedOrLoanedOriginal() {
    let id = UUID()
    let source = source
    func obligation(consumed: Set<UUID>, loan: Bool, missing: Set<UUID>)
      -> EquipmentIssueObligationSnapshot
    {
      .init(
        source: source, node: node, items: [id], consumed: consumed, status: .issued,
        loan: loan, returnRemaining: true, displacements: [], legacyMissingItems: missing)
    }
    #expect(obligation(consumed: [], loan: false, missing: [id]).valid)
    #expect(!obligation(consumed: [id], loan: false, missing: [id]).valid)
    #expect(!obligation(consumed: [], loan: true, missing: [id]).valid)
    #expect(!obligation(consumed: [], loan: false, missing: [UUID()]).valid)
  }
}
