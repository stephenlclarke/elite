import Foundation
import Testing

@testable import EliteCore

private func workToolGame() throws -> Game {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  game.commander.equipment = Equipment.maximumHardware
  game.commander.laserMounts = .init(front: .naval, left: .naval, right: .naval, rear: .naval)
  game.commander.xyzzyActive = true
  try game.commander.initializeEquipment(
    owner: UUID(), hull: UUID(), legacy: false,
    xyzzyGrant: true
  ) { UUID() }
  return game
}

@discardableResult private func workToolRock(_ game: inout Game) throws -> Int {
  let rock = try #require(game.miningFields.first?.rocks.first)
  let allocated = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocated)
  var body = SpaceBody(id: 80, hull: .asteroid, position: .init(0, 0, 500))
  body.energy = rock.energy
  body.physical = .init(identity: actor, population: .asteroid, rock: rock.identity)
  game.bodies.append(body)
  return body.id
}

struct MiningWorkToolTests {
  @Test func explicitWorkToolCoexistsWithFourNavalFacingsAndAnIndependentCutter() throws {
    var game = try workToolGame()
    var inventory = try #require(game.commander.equipmentInventory)
    let cutter = OwnedEquipmentItem(
      id: UUID(),
      node: try #require(EquipmentRuntimeCatalog.node(for: "Salvage Cutter")), provenance: .xyzzy,
      location: .init(hullInstanceID: inventory.activeHull, slot: .utility(.salvageCutter)))
    try inventory.admit(
      cutter, expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.performance))
    game.commander.savedEquipmentInventory = inventory
    #expect(game.commander.hasMiningWorkTool)
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    #expect(
      inventory.items.filter {
        if case .laser = $0.location?.slot { return true }
        return false
      }.count == 4)
    #expect(inventory.items.contains { $0.location?.slot == .utility(.salvageCutter) })
    try workToolRock(&game)
    let energy = game.energy
    let rockEnergy = game.bodies[0].energy
    #expect(game.fireMiningWorkTool())
    #expect(game.bodies[0].energy == rockEnergy - LaserKind.mining.damage)
    #expect(game.energy == energy - 1 && game.laserHeat == 10)
    #expect(game.fireCooldown == LaserKind.mining.firingInterval)
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    #expect(!game.fireMiningWorkTool())
    for _ in 0..<4 where game.bodies[0].energy > 0 {
      game.fireCooldown = 0
      #expect(game.fireMiningWorkTool())
    }
    let rock = try #require(game.miningFields.first?.rocks.first)
    #expect(game.commander.miningLedger.isDepleted(rock.identity))
    let payloads = game.commander.miningLedger.pendingPayloads
    #expect(!payloads.isEmpty && !game.fireMiningWorkTool())
    #expect(game.commander.miningLedger.pendingPayloads == payloads)
  }

  @Test func workToolCannotFireThroughShipsStationsOrCelestials() throws {
    for obstacle in 0..<3 {
      var game = try workToolGame()
      try workToolRock(&game)
      if obstacle == 2 {
        game.celestials = [.init(kind: .planet, position: .init(0, 0, 250), radius: 100)]
      } else {
        game.bodies.append(
          .init(
            id: 90, hull: obstacle == 0 ? .cobra : .station,
            position: .init(0, 0, 250)))
      }
      let energy = game.energy
      let rockEnergy = game.bodies[0].energy
      #expect(!game.fireMiningWorkTool())
      #expect(game.bodies[0].energy == rockEnergy && game.energy == energy)
      #expect(game.bodies.last?.energy == (obstacle == 2 ? rockEnergy : 100))
      #expect(game.commander.legal == 0 && game.commander.kills == 0 && game.laserHeat == 0)
    }
  }

  @Test func installedWorkToolRequiresDeclaredHullSupportAndMiningType() throws {
    var game = try workToolGame()
    let inventory = try #require(game.commander.equipmentInventory)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull,
      performance: game.commander.performance)
    let naval = try #require(inventory.items.first { $0.location?.slot == .laser(.front) })
    var attempted = inventory
    #expect(throws: OwnedEquipmentError.unsupportedSlot) {
      try attempted.fit(
        expected: naval,
        at: .init(
          hullInstanceID: inventory.activeHull,
          slot: .utility(.miningLaser)), replacing: game.commander.fittedMiningWorkTool,
        expectedRevision: inventory.revision, context: context)
    }
    #expect(attempted == inventory)
    game.commander.shipID = "SH087"
    #expect(!game.commander.hasMiningWorkTool && !game.fireMiningWorkTool())
    #expect(throws: OwnedEquipmentError.unsupportedSlot) {
      try inventory.validate(
        context: EquipmentRuntimeCatalog.context(
          owner: inventory.owner, hull: inventory.activeHull,
          performance: game.commander.performance))
    }
  }

  @Test func storingMiningToolRemovesCapabilityWithoutChangingAnyCombatFacing() throws {
    var game = try workToolGame()
    var inventory = try #require(game.commander.equipmentInventory)
    let tool = try #require(game.commander.fittedMiningWorkTool)
    try inventory.store(
      expected: tool, expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.performance))
    game.commander.savedEquipmentInventory = inventory
    #expect(!game.commander.hasMiningWorkTool && !game.fireMiningWorkTool())
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    #expect(inventory.items.first { $0.id == tool.id }?.location == nil)
  }
}
