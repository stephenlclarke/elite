import Foundation
import Testing

@testable import EliteCore

private let cemOwner = UUID(uuidString: "91000000-0000-0000-0000-000000000001")!
private let cemHull = UUID(uuidString: "91000000-0000-0000-0000-000000000002")!

private func cemInitialize(
  _ commander: inout Commander, legacy: Bool = true, xyzzyGrant: Bool = false
) throws {
  var sequence = 0
  try commander.initializeEquipment(
    owner: cemOwner, hull: cemHull, legacy: legacy, xyzzyGrant: xyzzyGrant
  ) {
    sequence += 1
    return UUID(uuidString: String(format: "92000000-0000-0000-0000-%012d", sequence))!
  }
}

struct CommanderEquipmentMigrationTests {
  @Test func readingLegacyEquipmentNeverAllocatesOrChangesCommander() {
    let commander = Commander()
    let before = commander
    #expect(commander.equipmentInventory == nil && commander.equipmentPurchaseHistory == nil)
    #expect(commander.equipmentOwnerID == nil && commander.hullInstanceID == nil)
    #expect(commander.equipmentStateValid && commander.salvageLedger.inventory.isEmpty)
    #expect(commander == before)
  }

  @Test func explicitFreshInitializationAddsStandardPhysicalFoundationsWithoutPaidHistory() throws {
    var commander = Commander()
    let before = commander
    try cemInitialize(&commander, legacy: false)
    let inventory = try #require(commander.equipmentInventory)
    #expect(
      inventory.owner == cemOwner && inventory.activeHull == cemHull && inventory.items.count == 4)
    #expect(inventory.items.allSatisfy { $0.provenance == .standard && $0.location != nil })
    #expect(
      Set(inventory.items.compactMap { $0.location?.slot }) == [
        .shield, .energy, .navigation, .laser(.front),
      ])
    #expect(commander.equipmentPurchaseHistory?.paid.isEmpty == true)
    #expect(commander.equipmentPurchaseHistory?.legacy.isEmpty == true)
    #expect(commander.valid)
    commander.savedEquipmentInventory = nil
    commander.savedEquipmentPurchaseHistory = nil
    commander.savedEquipmentVersion = nil
    #expect(commander == before)
  }

  @Test func legacyMigrationRetainsMiningShieldStrengthAndHeldReplacedDevices() throws {
    var commander = Commander()
    commander.equipment.formUnion([
      "Mining Shield Booster", "Beam Laser", "Military Laser",
      "Extra Energy Unit", NavigationTier.advanced.equipmentName,
    ])
    commander.laserMounts = .init(front: .military, rear: .beam)
    commander.fuelStorageUnits = 2
    commander.credits = 12345
    commander.fuel = 11
    commander.cargo[0] = 3
    commander.legal = 17
    let before = commander
    try cemInitialize(&commander)
    let inventory = try #require(commander.equipmentInventory)
    let shield = try #require(inventory.items.first { $0.location?.slot == .shield }?.component)
    #expect(
      shield.statistics[.frontShieldCapacity] == 5 && shield.statistics[.rearShieldCapacity] == 5)
    #expect(
      shield.origin.identity.id == "shield.legacy.mining" && shield.grade.id == "shield.advanced")
    #expect(shield.receipts.isEmpty)
    #expect(inventory.items.contains { $0.node.key == "Pulse Laser" && $0.location == nil })
    #expect(
      inventory.items.filter { $0.node.family == EquipmentRuntimeCatalog.storageFamily }.count == 2)
    #expect(commander.equipmentPurchaseHistory?.paid.isEmpty == true)
    #expect(commander.equipmentPurchaseHistory?.legacy.isEmpty == false)
    #expect(commander.credits == before.credits && commander.fuel == before.fuel)
    #expect(commander.cargo == before.cargo && commander.legal == before.legal)
    #expect(commander.equipment == before.equipment && commander.laserMounts == before.laserMounts)
    #expect(
      commander.navigationPlan == before.navigationPlan
        && commander.shieldCapacity == before.shieldCapacity)
    #expect(commander.valid)
  }

  @Test func migrationKeepsKnownRewardsAndXYZZYSeparateFromGrandfatheredPurchases() throws {
    var reward = Commander()
    reward.capitalRewardClaimed = true
    reward.missionStage = .plansDelivered
    reward.equipment.formUnion([ShieldBooster.capital.equipmentName, Equipment.navalEnergyUnit])
    try cemInitialize(&reward)
    #expect(
      reward.equipmentInventory?.items.first { $0.location?.slot == .shield }?.provenance
        == .reward("elite-rank"))
    #expect(
      reward.equipmentInventory?.items.first { $0.location?.slot == .energy }?.provenance
        == .reward("thargoid-plans"))
    #expect(reward.equipmentPurchaseHistory?.paid.isEmpty == true)
    #expect(
      reward.equipmentPurchaseHistory?.legacy.allSatisfy {
        $0.source.node.family != EquipmentPurchaseCatalog.shields
          && $0.source.node.family != EquipmentPurchaseCatalog.energy
      } == true)
    var xyzzy = Commander()
    xyzzy.xyzzyActive = true
    xyzzy.equipment = Equipment.maximumHardware
    xyzzy.fuelStorageUnits = FuelStorage.maximumCount
    try cemInitialize(&xyzzy, legacy: false, xyzzyGrant: true)
    #expect(
      xyzzy.equipmentPurchaseHistory?.paid.isEmpty == true
        && xyzzy.equipmentPurchaseHistory?.legacy.isEmpty == true)
    #expect(
      xyzzy.equipmentInventory?.items.allSatisfy {
        $0.provenance == .standard || $0.provenance == .xyzzy
      } == true)
  }

  @Test func migrationIsIdempotentAndRoundTripRetainsAllPhysicalIdentities() throws {
    var commander = Commander()
    try cemInitialize(&commander)
    let before = commander
    var allocations = 0
    try commander.initializeEquipment(owner: UUID(), hull: UUID(), legacy: true) {
      allocations += 1
      return UUID()
    }
    #expect(allocations == 0 && commander == before)
    let decoded = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(commander))
    #expect(decoded == commander && decoded.valid)
    #expect(
      decoded.equipmentInventory?.items.map(\.id) == commander.equipmentInventory?.items.map(\.id))
  }

  @Test func nativeHullReachDoesNotBecomeATransferableComputerUpgrade() throws {
    for shipID in ["SH087", "SH001"] {
      var commander = Commander()
      commander.shipID = shipID
      let nativeReach = commander.jumpCap
      try cemInitialize(&commander)
      let navigation = try #require(
        commander.equipmentInventory?.items.first {
          $0.location?.slot == .navigation
        }?.component)
      #expect(navigation.statistics[.jumpReach] == 7 && navigation.grade.id == "navigation.basic")
      #expect(commander.jumpCap == nativeReach)
    }
  }

  @Test func oldXYZZYFlagDoesNotRelabelAmbiguousLaterPurchasesAsGrants() throws {
    var commander = Commander()
    commander.xyzzyActive = true
    commander.equipment.formUnion(["Beam Laser", NavigationTier.advanced.equipmentName])
    try cemInitialize(&commander)
    let items = try #require(commander.equipmentInventory?.items)
    #expect(items.contains { $0.node.key == "Beam Laser" && $0.provenance == .legacyUnknown })
    #expect(
      items.contains {
        $0.node.key == NavigationTier.advanced.equipmentName && $0.provenance == .legacyUnknown
      })
    #expect(!items.contains { $0.provenance == .xyzzy })
    #expect(commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func failedMigrationCannotPublishPartialEquipmentOrAlterExistingLegacyState() throws {
    var commander = Commander()
    let before = commander
    #expect(throws: OwnedEquipmentError.duplicateItem) {
      try commander.initializeEquipment(owner: cemOwner, hull: cemHull, legacy: true) { cemOwner }
    }
    #expect(commander == before)
    commander.equipment.insert("Unrecorded Engine")
    let unsupported = commander
    #expect(throws: CommanderEquipmentError.unknownLegacyItem("Unrecorded Engine")) {
      try cemInitialize(&commander)
    }
    #expect(commander == unsupported)
  }

  @Test func loadValidationRejectsUnknownVersionAndForeignLegacyEntitlementOwner() throws {
    var commander = Commander()
    try cemInitialize(&commander)
    commander.savedEquipmentVersion = 99
    #expect(!commander.equipmentStateValid && !commander.valid)
    commander.savedEquipmentVersion = 1
    let history = try #require(commander.equipmentPurchaseHistory)
    commander.savedEquipmentPurchaseHistory = .init(owner: UUID(), legacy: history.legacy)
    #expect(!commander.equipmentStateValid && !commander.valid)
    commander.savedEquipmentPurchaseHistory = history
    #expect(commander.valid)
  }

  @Test func highCoreAndHeldMiningLaserCannotInventSpecialistModuleOwnership() throws {
    var commander = Commander()
    commander.installTargetingComputer(.military)
    commander.equipment.insert("Mining Laser")
    try cemInitialize(&commander)
    let inventory = try #require(commander.equipmentInventory)
    #expect(inventory.items.contains { $0.node.key == "Mining Laser" && $0.location == nil })
    #expect(
      !inventory.items.contains {
        $0.location?.slot == .targetingMining || $0.location?.slot == .targetingSalvage
      })
    #expect(
      !inventory.items.contains {
        $0.node.family == EquipmentPurchaseCatalog.mining
          || $0.node.family == EquipmentPurchaseCatalog.salvage
      })
    try EquipmentPurchaseProgression.validate(EquipmentRuntimeCatalog.graph)
  }
}
