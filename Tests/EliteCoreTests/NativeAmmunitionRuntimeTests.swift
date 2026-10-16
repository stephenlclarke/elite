import Foundation
import Testing

@testable import EliteCore

struct NativeAmmunitionRuntimeTests {
  private func flight(rounds: Int = 3) throws -> Game {
    var game = Game(executive: false)
    game.commander.missiles = rounds
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.speed = 0
    game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
    game.bodies = [.init(id: 70, hull: .cobra, position: .init(0, 0, 1800))]
    game.ensurePhysicalActors()
    game.weaponsTargetID = 70
    game.missileArmed = true
    return game
  }

  @Test func nativeLaunchUsesTheHighestOccupiedPhysicalPylonEvenWithAHole() throws {
    var game = try flight()
    let inventory = try #require(game.commander.equipmentInventory)
    let hole = try #require(game.commander.fittedEquipment(at: .missilePylon(1)))
    let last = try #require(game.commander.fittedEquipment(at: .missilePylon(2)))
    var stored = inventory
    try stored.store(
      expected: hole, expectedRevision: stored.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.nativePerformance))
    game.commander.savedEquipmentInventory = stored
    game.commander.mirrorFittedEquipment()
    let before = game.commander
    let launched = game.fireMissile()
    #expect(launched)
    let origin = try #require(
      game.bodies.first { $0.physical?.ordnance != nil }?.physical?.attackOrigin)
    #expect(origin.playerAmmunition == .physical(item: last.id))
    #expect(game.commander.missiles == 1 && game.commander.valid)
    #expect(game.commander.equipmentInventory?.revision == stored.revision + 1)
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == last.id } == false)
    let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == hole.id })
    #expect(held == hole.moved(to: nil))
    #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  }

  @Test func virtualNativeLaunchNeverSpendsAPhysicalRoundOrMintsAnEmptyRack() throws {
    for count in [0, 3] {
      var game = try flight(rounds: count)
      game.commander.unlimitedMissiles = true
      let before = game.commander
      let launched = game.fireMissile()
      #expect(launched)
      let origin = try #require(
        game.bodies.first { $0.physical?.ordnance != nil }?.physical?.attackOrigin)
      #expect(origin.playerAmmunition == .virtualUnlimited)
      #expect(game.commander.equipmentInventory == before.equipmentInventory)
      #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
      #expect(game.commander.missiles == count && game.commander.valid)
      let saved = try JSONDecoder().decode(
        Commander.self, from: JSONEncoder().encode(game.commander))
      #expect(saved.equipmentInventory == before.equipmentInventory && saved.missiles == count)
    }
  }

  @Test func refusedNativeProjectileAdmissionPreservesInventoryAndEverySimulationAllocator() throws
  {
    var game = try flight()
    for id in 100..<132 {
      game.bodies.append(.init(id: id, hull: .missile, position: .init(Double(id) * 10, 0, 4000)))
    }
    game.ensurePhysicalActors()
    let original = game
    let launched = game.fireMissile()
    #expect(!launched)
    #expect(game.commander == original.commander && game.bodies == original.bodies)
    #expect(game.nextBodyID == original.nextBodyID && game.missileArmed == original.missileArmed)
    #expect(game.commander.flightSimulation == original.commander.flightSimulation)
    #expect(game.commander.crimeLedger == original.commander.crimeLedger)
    #expect(game.commander.scriptState == original.commander.scriptState)
  }
}
