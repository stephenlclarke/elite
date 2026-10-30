import Foundation
import Testing

@testable import L337Core

struct LegacyEquipmentMigrationTests {
  private func legacyCommander() -> Commander {
    var commander = Commander()
    commander.missiles = 0
    var inventory = LegacyOwnedEquipmentInventory()
    inventory.items = [.init(kind: .laser(.pulse), slot: .laser(.front))]
    commander.legacyOwnedEquipment = inventory
    return commander
  }

  private func issue(_ commander: inout Commander, loan: Bool, present: Bool) -> (UUID, UUID) {
    var instance = ScriptInstance(
      id: UUID(), definition: "fixture/equipment", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    let id = UUID()
    let kind = OwnedGearKind.module("Extra Energy Unit")
    instance.gearIssues["energy"] = .init(
      resource: "energy", kind: kind, items: [id], loan: loan,
      returnRemaining: true)
    commander.scriptState.instances[instance.id] = instance
    if present {
      var item = OwnedGear(id: id, kind: kind, slot: .module("Extra Energy Unit"))
      item.issuedBy = instance.id
      item.sourceResource = "energy"
      item.loanOwner = loan ? instance.id : nil
      commander.legacyOwnedEquipment?.items.append(item)
      commander.equipment.insert("Extra Energy Unit")
    }
    return (instance.id, id)
  }

  @Test func oldBagJSONKeyMigratesOnceAndPreservesHeldDamageWithoutMintingMissiles() throws {
    var commander = legacyCommander()
    var damaged = OwnedGear(kind: .missile, slot: .pylon(0))
    damaged.fittedSlot = nil
    damaged.condition = 7000
    damaged.modifications = ["guidance": 500]
    commander.legacyOwnedEquipment?.items.append(damaged)
    let before = commander
    let legacyJSON = try JSONEncoder().encode(commander)
    let legacyObject = try #require(
      JSONSerialization.jsonObject(with: legacyJSON) as? [String: Any])
    #expect(legacyObject["ownedEquipment"] != nil && legacyObject["legacyOwnedEquipment"] == nil)
    commander = try JSONDecoder().decode(Commander.self, from: legacyJSON)
    #expect(commander == before && commander.valid)
    try commander.migrateLegacyOwnedEquipment(owner: UUID(), hull: UUID()) { UUID() }
    let inventory = try #require(commander.equipmentInventory)
    let retained = try #require(inventory.items.first { $0.id == damaged.id })
    #expect(retained.location == nil && retained.preferredSlot == .missilePylon(0))
    #expect(
      retained.retainedLegacyState
        == .init(conditionBasisPoints: 7000, modifications: ["guidance": 500]))
    #expect(commander.savedEquipmentVersion == 2 && commander.legacyOwnedEquipment == nil)
    #expect(
      commander.missiles == 0 && commander.credits == before.credits
        && commander.fuel == before.fuel)
    #expect(inventory.items.count == 5 && commander.valid)
    let migrated = commander
    try commander.prepareEquipment()
    #expect(commander.savedEquipmentVersion == 3 && commander.valid)
    #expect(
      commander.equipmentInventory?.items.filter { !$0.isReservedStockDrive }
        == migrated.equipmentInventory?.items)
    #expect(commander.equipmentPurchaseHistory == migrated.equipmentPurchaseHistory)
    #expect(commander.fittedEquipment(at: .drive)?.isReservedStockDrive == true)
    let once = commander
    try commander.prepareEquipment()
    #expect(commander == once)
    let data = try JSONEncoder().encode(commander)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["ownedEquipment"] == nil && object["legacyOwnedEquipment"] == nil)
    #expect(try JSONDecoder().decode(Commander.self, from: data) == commander)
  }

  @Test func anOldLoanRetainsItsOriginalAndAnActualImplicitFoundationRestoration() throws {
    var commander = legacyCommander()
    let (mission, id) = issue(&commander, loan: true, present: true)
    let before = try #require(commander.legacyOwnedEquipment)
    #expect(commander.valid)
    try commander.migrateLegacyOwnedEquipment(owner: UUID(), hull: UUID()) { UUID() }
    let record = try #require(commander.scriptState.instances[mission]?.gearIssues["energy"])
    let inventory = try #require(commander.equipmentInventory)
    #expect(record.savedGearVersion == 2 && record.items == [id] && record.consumed.isEmpty)
    #expect(
      record.source?.mission == mission
        && record.node == EquipmentRuntimeCatalog.node(for: "Extra Energy Unit"))
    #expect(before.items.allSatisfy { old in inventory.items.contains { $0.id == old.id } })
    let displacement = try #require(record.displacements?.first)
    let foundation = try #require(inventory.items.first { $0.id == displacement.item })
    #expect(record.displacements?.count == 1 && displacement.location.slot == .energy)
    #expect(foundation.node.key == "Basic Energy System" && foundation.location == nil)
    #expect(foundation.provenance == .standard && commander.fittedEquipment(at: .energy)?.id == id)
    #expect(commander.issuedEquipmentValid && commander.valid)
  }

  @Test func genuinelyAbsentNonloanOriginalGetsOnlyTheMigrationAbsenceMarker() throws {
    var commander = legacyCommander()
    let (mission, id) = issue(&commander, loan: false, present: false)
    #expect(commander.valid)
    try commander.migrateLegacyOwnedEquipment(owner: UUID(), hull: UUID()) { UUID() }
    let record = try #require(commander.scriptState.instances[mission]?.gearIssues["energy"])
    #expect(record.items == [id] && record.consumed.isEmpty && record.legacyMissingItems == [id])
    #expect(commander.equipmentInventory?.items.contains { $0.id == id } == false)
    #expect(commander.issuedEquipmentValid && commander.valid)
  }

  @Test func substitutedOriginalOrMixedPhysicalRepresentationsRefuseWithoutAllocation() throws {
    var commander = legacyCommander()
    let (_, id) = issue(&commander, loan: true, present: true)
    let position = try #require(commander.legacyOwnedEquipment?.items.firstIndex { $0.id == id })
    commander.legacyOwnedEquipment?.items[position].issuedBy = nil
    commander.legacyOwnedEquipment?.items[position].sourceResource = nil
    commander.legacyOwnedEquipment?.items[position].loanOwner = nil
    let before = commander
    var allocations = 0
    #expect(throws: EquipmentMigrationError.obligationMismatch) {
      try commander.migrateLegacyOwnedEquipment(owner: UUID(), hull: UUID()) {
        allocations += 1
        return UUID()
      }
    }
    #expect(commander == before && allocations == 0)
    var mixed = legacyCommander()
    mixed.savedEquipmentInventory = try .init(owner: UUID(), activeHull: UUID())
    let originalMixed = mixed
    #expect(throws: EquipmentMigrationError.mixedRepresentations) { try mixed.prepareEquipment() }
    #expect(mixed == originalMixed)
  }

  @Test func scriptPayloadBoundsAreCheckedBeforeAggregationAndCannotPartiallyLoad() {
    for quantity in [Int.max, -1, 1_000_001] {
      var commander = Commander()
      var instance = ScriptInstance(
        id: UUID(), definition: "fixture/payload", version: "1.0.0",
        digest: String(repeating: "a", count: 64))
      instance.payloads = ["first": quantity, "second": quantity]
      commander.scriptState.instances[instance.id] = instance
      #expect(commander.checkedCargoTonnes == nil && !commander.valid)
      var game = Game()
      let before = game
      let loaded = game.load(commander)
      #expect(!loaded && game.commander == before.commander && game.bodies == before.bodies)
      #expect(game.inventoryContextEpoch == before.inventoryContextEpoch)
    }
    var maximum = Commander()
    for index in 0..<128 {
      var instance = ScriptInstance(
        id: UUID(), definition: "fixture/payload-\(index)", version: "1.0.0",
        digest: String(repeating: "a", count: 64))
      instance.payloads = Dictionary(
        uniqueKeysWithValues: (0..<128).map { ("parcel-\($0)", 1_000_000) })
      maximum.scriptState.instances[instance.id] = instance
    }
    #expect(maximum.checkedCargoTonnes == 16_384_000_000)
  }
}
