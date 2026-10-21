import Foundation
import Testing

@testable import EliteCore

private func upgradedPlansDelivery() throws -> Game {
  var game = try recoveredEquipmentGame("energy-technology")
  game.commander.credits = 100_000
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Extra Energy Unit" })
  game.purchase()
  let outgoing = try #require(game.commander.fittedEquipment(at: .energy))
  #expect(outgoing.node.key == "Extra Energy Unit")
  let lot = try #require(game.commander.salvageLedger.inventory.first)
  let upgrade = try game.commander.quoteRecoveredUpgrade(
    lot: lot.identity, axis: .energyCapacity, slot: .energy)
  try game.applyRecoveredUpgrade(upgrade)
  #expect(game.commander.fittedComponent(at: .energy)?.receipts.count == 1)
  #expect(game.commander.performance.energy > game.commander.nativePerformance.energy)
  game.commander.galaxy = 2
  game.commander.system = 36
  game.systems = Universe.systemsIncludingPlugh(number: 2)
  game.commander.kills = 1280
  game.commander.missionStage = .carryingPlans
  game.screen = .status
  #expect(game.commander.valid)
  return game
}

struct MissionResourceFractionTests {
  @Test(arguments: [0.0, 0.25, 1.0])
  func upgradedOutgoingEnergyUnitPreservesPartialAndEmptyCharge(fraction: Double) throws {
    var game = try upgradedPlansDelivery()
    game.energy = game.commander.performance.energy * fraction
    game.frontShield = game.commander.shieldCapacity * 0.5
    game.rearShield = game.commander.rearShieldCapacity * 0.75
    let front = game.frontShield
    let rear = game.rearShield
    let cash = game.commander.credits
    let history = game.commander.equipmentPurchaseHistory
    let outgoing = try #require(game.commander.fittedEquipment(at: .energy))
    let committed = game.dispatchMission(.dock, naval: true)
    #expect(committed && game.commander.missionStage == .plansDelivered)
    #expect(game.commander.fittedEquipment(at: .energy)?.node.key == Equipment.navalEnergyUnit)
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == outgoing.id } == false)
    #expect(abs(game.energy - game.commander.performance.energy * fraction) < 1e-10)
    #expect(game.energy <= game.commander.performance.energy)
    #expect(game.frontShield == front && game.rearShield == rear)
    #expect(game.commander.credits == cash && game.commander.equipmentPurchaseHistory == history)
    #expect(game.commander.kills == 1536 && game.commander.valid)
  }

  @Test func actualDockAndPlansRewardRefillOnlyToTheNewEnergyCapacity() throws {
    var game = try upgradedPlansDelivery()
    let rewardedCapacity = game.commander.nativePerformance.energy
    game.energy = game.commander.performance.energy / 4
    game.frontShield = 0
    game.rearShield = 0
    game.dock()
    #expect(game.commander.missionStage == .plansDelivered && game.screen == .mission)
    #expect(game.energy == game.commander.performance.energy && game.energy == rewardedCapacity)
    #expect(game.frontShield == game.commander.shieldCapacity)
    #expect(game.rearShield == game.commander.rearShieldCapacity)
  }

  @Test func refusedPlansEquipmentTransactionKeepsAllLiveResourcesAndOriginalOwnership() throws {
    var game = try upgradedPlansDelivery()
    game.energy = game.commander.performance.energy / 3
    game.frontShield = game.commander.shieldCapacity / 4
    game.rearShield = game.commander.rearShieldCapacity / 5
    let inventory = try #require(game.commander.equipmentInventory)
    game.commander.savedEquipmentInventory = try .init(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: UInt64.max - 1,
      items: inventory.items)
    let before = game.commander
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    let committed = game.dispatchMission(.dock, naval: true)
    #expect(!committed && game.commander == before)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
  }
}
