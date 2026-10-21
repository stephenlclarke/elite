import Foundation
import Testing

@testable import EliteCore

private func equipmentPlansDelivery() throws -> Game {
  var game = Game(executive: true)
  game.screen = .status
  game.commander.galaxy = 2
  game.commander.system = 36
  game.systems = Universe.systemsIncludingPlugh(number: 2)
  game.commander.kills = 1280
  game.commander.missionStage = .carryingPlans
  try game.commander.prepareEquipment(legacy: false)
  return game
}

struct MissionEquipmentBridgeTests {
  @Test func originalPlansDeliveryGrantsActualNavalHardwareAndCannotDuplicateAfterReload() throws {
    var game = try equipmentPlansDelivery()
    let entry = try #require(game.missionPacks.entries.first { $0.pack.id == "xyzzy.plans" })
    let delivered = game.dispatchMission(.dock, naval: true)
    #expect(delivered && game.commander.missionStage == .plansDelivered)
    #expect(game.commander.kills == 1536 && game.commander.credits == 1000)
    let reward = try #require(game.commander.fittedEquipment(at: .energy))
    #expect(reward.node.key == Equipment.navalEnergyUnit)
    #expect(reward.provenance == .grant("mission-pack:" + entry.digest))
    #expect(game.commander.energyRechargeMultiplier == 3)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
    let saved = try JSONEncoder().encode(game.commander)
    let decoded = try JSONDecoder().decode(Commander.self, from: saved)
    var restored = Game()
    let loaded = restored.load(decoded)
    #expect(loaded)
    let inventory = restored.commander.equipmentInventory
    let second = restored.dispatchMission(.dock, naval: true)
    #expect(!second && restored.commander.kills == 1536)
    #expect(restored.commander.equipmentInventory == inventory)
    #expect(restored.commander.fittedEquipment(at: .energy)?.id == reward.id)
  }

  @Test func explicitRemovalConsumesOnlyTheRequestedFittedDeviceAndAbsenceIsANoOp() throws {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let digest = String(repeating: "a", count: 64)
    var state = MissionProgress(version: "1.0.0", digest: digest, stage: "active")
    try commander.apply(
      .init(kind: "equipmentAdd", key: "Extra Energy Unit", amount: nil), state: &state)
    let extra = try #require(commander.fittedEquipment(at: .energy))
    try commander.apply(
      .init(kind: "equipmentAdd", key: Equipment.navalEnergyUnit, amount: nil), state: &state)
    let naval = try #require(commander.fittedEquipment(at: .energy))
    #expect(commander.equipmentInventory?.items.first { $0.id == extra.id }?.location == nil)
    try commander.apply(
      .init(kind: "equipmentRemove", key: "Extra Energy Unit", amount: nil), state: &state)
    #expect(commander.fittedEquipment(at: .energy) == naval)
    #expect(commander.equipmentInventory?.items.contains { $0.id == extra.id } == true)
    try commander.apply(
      .init(kind: "equipmentRemove", key: Equipment.navalEnergyUnit, amount: nil), state: &state)
    #expect(commander.equipmentInventory?.items.contains { $0.id == naval.id } == false)
    let before = commander
    try commander.apply(
      .init(kind: "equipmentRemove", key: Equipment.navalEnergyUnit, amount: nil), state: &state)
    #expect(commander == before)
  }

  @Test func failedPhysicalRewardRollsBackTheOriginalMissionProposalAndScore() throws {
    var game = try equipmentPlansDelivery()
    let inventory = try #require(game.commander.equipmentInventory)
    game.commander.savedEquipmentInventory = try .init(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: UInt64.max,
      items: inventory.items)
    #expect(game.commander.valid)
    let before = game.commander
    let messageBefore = game.message
    let committed = game.dispatchMission(.dock, naval: true)
    #expect(!committed && game.commander == before && game.message != messageBefore)
    #expect(game.commander.missionStage == .carryingPlans && game.commander.kills == 1280)
    #expect(game.commander.fittedEquipment(at: .energy)?.node.key == "Basic Energy System")
  }

  @Test func anInvalidOwnershipLedgerCannotBeTreatedAsAbsentMissionEquipment() throws {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    commander.savedEquipmentPurchaseHistory = .init(owner: UUID())
    let before = commander
    var state = MissionProgress(
      version: "1.0.0", digest: String(repeating: "a", count: 64), stage: "active")
    #expect(throws: CommanderEquipmentError.incompleteState) {
      try commander.apply(
        .init(kind: "equipmentRemove", key: "Extra Energy Unit", amount: nil), state: &state)
    }
    #expect(commander == before)
  }
}
