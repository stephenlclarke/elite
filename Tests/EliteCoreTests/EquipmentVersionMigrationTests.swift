import Foundation
import Testing

@testable import EliteCore

struct EquipmentVersionMigrationTests {
  private func versionOne(rounds: Int = 2, revision: UInt64 = 7) throws -> Commander {
    var commander = Commander()
    commander.missiles = rounds
    try commander.initializeEquipment(owner: UUID(), hull: UUID(), legacy: false) { UUID() }
    let inventory = try #require(commander.equipmentInventory)
    commander.savedEquipmentInventory = try .init(
      owner: inventory.owner, activeHull: inventory.activeHull,
      revision: revision,
      items: inventory.items.filter { $0.node != EquipmentRuntimeCatalog.standardMissile })
    commander.savedEquipmentVersion = 1
    try commander.validateEquipmentState()
    return commander
  }

  @Test func versionOneImportPreservesExistingIdentitiesAndAllocatesRoundsExactlyOnce() throws {
    var commander = try versionOne()
    let before = commander
    let inventory = try #require(before.equipmentInventory)
    let history = try #require(before.equipmentPurchaseHistory)
    var allocations = 0
    try commander.migrateFiniteAmmunition {
      allocations += 1
      return UUID()
    }
    let next = try #require(commander.equipmentInventory)
    #expect(allocations == 2 && commander.savedEquipmentVersion == 2)
    #expect(next.owner == inventory.owner && next.activeHull == inventory.activeHull)
    #expect(
      next.items.filter { $0.node != EquipmentRuntimeCatalog.standardMissile } == inventory.items)
    #expect(next.revision == inventory.revision + 1 && commander.missiles == 2)
    #expect(commander.equipmentPurchaseHistory?.paid == history.paid)
    #expect(commander.equipmentPurchaseHistory?.revision == history.revision)
    #expect(
      commander.credits == before.credits && commander.fuel == before.fuel
        && commander.cargo == before.cargo)
    let migrated = commander
    try commander.migrateFiniteAmmunition {
      allocations += 1
      return UUID()
    }
    #expect(commander == migrated && allocations == 2)
    try commander.prepareEquipment()
    #expect(commander == migrated)
  }

  @Test func aSavedVersionTwoEmptyRackRemainsEmptyAcrossReadsAndAdmission() throws {
    var commander = Commander()
    commander.missiles = 0
    try commander.prepareEquipment(legacy: false)
    let original = commander
    let restored = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(commander))
    #expect(restored.savedEquipmentVersion == 2 && restored.missiles == 0)
    #expect(
      restored.equipmentInventory?.items.contains {
        $0.node == EquipmentRuntimeCatalog.standardMissile
      } == false)
    for _ in 0..<10 {
      #expect(
        commander.equipmentInventory == original.equipmentInventory && commander.missiles == 0)
      try commander.prepareEquipment()
    }
    #expect(commander == original)
    var game = Game()
    let loaded = game.load(restored)
    #expect(
      loaded && game.commander.missiles == 0
        && game.commander.equipmentInventory == original.equipmentInventory)
  }

  @Test func versionTwoCounterMismatchRejectsTheWholeLoadInsteadOfRepairingIt() throws {
    var commander = Commander()
    try commander.prepareEquipment()
    commander.missiles = 0
    #expect(!commander.valid)
    var game = Game()
    let original = game
    let loaded = game.load(commander)
    #expect(!loaded && game.commander == original.commander && game.bodies == original.bodies)
    #expect(throws: EquipmentMigrationError.invalidCrosswalk) { try commander.prepareEquipment() }
  }

  @Test func versionOneMixedFactsAndExhaustedRevisionCannotPublishMigration() throws {
    var mixed = Commander()
    try mixed.prepareEquipment()
    mixed.savedEquipmentVersion = 1
    let originalMixed = mixed
    #expect(throws: EquipmentMigrationError.mixedRepresentations) { try mixed.prepareEquipment() }
    #expect(mixed == originalMixed)
    var exhausted = try versionOne(revision: .max)
    let original = exhausted
    #expect(throws: OwnedEquipmentError.revisionExhausted) { try exhausted.prepareEquipment() }
    #expect(exhausted == original)
  }

  @Test func actualShopPurchaseCreatesOnePaidFiniteRoundAtOneNewRevision() throws {
    var game = Game()
    game.commander.missiles = 0
    game.commander.credits = 100000
    game.screen = .equipment
    game.selection = try #require(Equipment.all.firstIndex { $0.name == "Missile" })
    try game.commander.prepareEquipment(legacy: false)
    let before = try #require(game.commander.equipmentInventory)
    let result = game.purchaseImmediately()
    guard case .applied(.purchase(let name, let identity, let fitted)) = result else {
      Issue.record("Expected a physical missile purchase, got \(result)")
      return
    }
    let id = try #require(identity)
    let next = try #require(game.commander.equipmentInventory)
    let round = try #require(next.items.first { $0.id == id })
    #expect(name == "Missile" && fitted && game.commander.missiles == 1)
    #expect(
      round.node == EquipmentRuntimeCatalog.standardMissile
        && round.location?.slot == .missilePylon(0))
    #expect(next.revision == before.revision + 1 && game.commander.valid)
    #expect(game.commander.equipmentPurchaseHistory?.paid.last?.binding.request.newItem == id)
  }

  @Test func changingUnlimitedSupplyDoesNotRefillOrConsumeFiniteRounds() throws {
    var game = Game()
    game.commander.missiles = 0
    try game.commander.prepareEquipment(legacy: false)
    game.commander.xyzzyActive = true
    game.screen = .secret
    let inventory = game.commander.equipmentInventory
    game.secretKey("3")
    #expect(game.commander.unlimitedMissiles && game.commander.missiles == 0)
    #expect(game.commander.equipmentInventory == inventory)
    game.secretKey("3")
    #expect(!game.commander.unlimitedMissiles && game.commander.equipmentInventory == inventory)
  }
}
