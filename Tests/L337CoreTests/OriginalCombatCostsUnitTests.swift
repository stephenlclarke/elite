import Foundation
import Testing

@testable import L337Core

struct OriginalCombatCostsUnitTests {
  private func flight(bomb: Bool = true, rounds: Int = 3) throws -> Game {
    var game = Game(executive: false)
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity
    game.commander.missiles = rounds
    try game.commander.prepareEquipment(legacy: false)
    if bomb {
      try game.commander.grantEquipment(
        "Energy Bomb", at: .utility(.energyBomb),
        provenance: .grant("original combat cost fixture"))
    }
    game.launch()
    game.speed = 0
    game.celestials = []
    game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
    game.bodies = [.init(id: 70, hull: .cobra, position: .init(0, 0, 1000))]
    game.ensurePhysicalActors()
    try #require(!game.docked && game.commander.valid)
    return game
  }

  @Test func actualECMUsesTwentyTwoEnergyOnceAndKeepsItsPositiveEnergyBoundary() throws {
    for available in [21.0, 22.0, 22.5, 256.0] {
      var game = try flight(bomb: false)
      try game.commander.grantEquipment(
        "E.C.M. System", at: .utility(.ecm), provenance: .grant("ECM cost fixture"))
      game.energy = available
      let before = game
      game.ecm()
      if available > 22 {
        try #require(game.ecmControl.ownFieldActive)
        #expect(game.energy == available - 22 && game.ecmFrames == 32)
        #expect(game.ecmControl.activation == before.ecmControl.activation + 1)
        #expect(game.commander.equipmentInventory == before.commander.equipmentInventory)
        let active = game
        game.ecm()
        #expect(game.energy == active.energy && game.commander == active.commander)
        #expect(game.ecmControl.events == active.ecmControl.events)
        #expect(game.ecmControl.activation == active.ecmControl.activation)
      } else {
        #expect(game.energy == available && game.ecmFrames == 0)
        #expect(game.commander == before.commander && game.bodies == before.bodies)
        #expect(game.ecmControl.events == before.ecmControl.events)
        #expect(game.ecmControl.activation == before.ecmControl.activation)
      }
    }
  }

  @Test func physicalBombDebitsOneHundredEightyOnceAndRefusesUnfundedOrNonfiniteUse() throws {
    for available in [179.0, 180.0, 180.5, 256.0, .nan, .infinity, -.infinity] {
      var game = try flight()
      let bomb = try #require(game.commander.fittedEquipment(at: .utility(.energyBomb)))
      game.energy = available
      let before = game
      game.energyBomb()
      if available.isFinite && available > 180 {
        try #require(game.commander.fittedEquipment(at: .utility(.energyBomb)) == nil)
        #expect(game.energy == available - 180 && game.energy > 0)
        #expect(game.commander.equipmentInventory?.items.contains { $0.id == bomb.id } == false)
        #expect(game.bodies.first { $0.id == 70 }?.energy == 0)
        let spent = game
        game.energyBomb()
        #expect(game.energy == spent.energy && game.commander == spent.commander)
        #expect(game.bodies == spent.bodies && game.nextBodyID == spent.nextBodyID)
      } else {
        #expect(game.energy.bitPattern == before.energy.bitPattern)
        #expect(game.commander == before.commander && game.bodies == before.bodies)
        #expect(game.nextBodyID == before.nextBodyID && game.message == before.message)
        #expect(game.ecmControl.events == before.ecmControl.events)
      }
    }
  }

  @Test func missingHeldAndDockedBombsCannotSpendEnergyOrChangeOwnedProperty() throws {
    for mode in ["missing", "held", "docked"] {
      var game = try flight(bomb: mode != "missing")
      game.energy = 256
      if mode == "held" {
        let bomb = try #require(game.commander.fittedEquipment(at: .utility(.energyBomb)))
        var inventory = try #require(game.commander.equipmentInventory)
        try inventory.store(
          expected: bomb, expectedRevision: inventory.revision,
          context: EquipmentRuntimeCatalog.context(
            owner: inventory.owner, hull: inventory.activeHull,
            performance: game.commander.nativePerformance))
        game.commander.savedEquipmentInventory = inventory
        game.commander.mirrorFittedEquipment()
        try #require(game.commander.fittedEquipment(at: .utility(.energyBomb)) == nil)
        try #require(inventory.items.contains { $0.id == bomb.id && $0.location == nil })
      } else if mode == "docked" {
        game.docked = true
      }
      let before = game
      game.energyBomb()
      #expect(game.energy == before.energy && game.commander == before.commander)
      #expect(game.bodies == before.bodies && game.nextBodyID == before.nextBodyID)
      #expect(game.message == before.message && game.ecmControl.events == before.ecmControl.events)
    }
  }

  @Test func aRefusedDeathIncidentRollsBackTheBombEnergyItemAndEveryVictim() throws {
    let baseline = try flight()
    var positive = baseline
    positive.energyBomb()
    try #require(positive.energy == baseline.energy - 180)
    try #require(positive.commander.fittedEquipment(at: .utility(.energyBomb)) == nil)
    try #require(positive.bodies.first { $0.id == 70 }?.energy == 0)
    var game = baseline
    var object = try #require(
      JSONSerialization.jsonObject(
        with: JSONEncoder().encode(game.commander.flightSimulation)) as? [String: Any])
    object["nextIncident"] = NSNumber(value: UInt64.max - 1)
    game.commander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self,
      from: JSONSerialization.data(withJSONObject: object))
    try #require(game.commander.valid)
    let before = game
    game.energyBomb()
    #expect(game.energy == before.energy && game.commander == before.commander)
    #expect(game.bodies == before.bodies && game.nextBodyID == before.nextBodyID)
    #expect(game.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(game.message == before.message && game.ecmControl.events == before.ecmControl.events)
  }

  @Test func refusedConsumptionBroadcastPreservesBombEnergyCustodyAndVictims() throws {
    var baseline = try flight()
    for definition in ["observer/first", "observer/second"] {
      var observer = ScriptInstance(
        id: UUID(), definition: definition, version: "1.0.0",
        digest: String(repeating: "a", count: 64))
      observer.outcome = .active
      baseline.commander.scriptState.instances[observer.id] = observer
    }
    try #require(baseline.commander.valid)
    var positive = baseline
    positive.energyBomb()
    try #require(positive.energy == baseline.energy - 180)
    try #require(positive.commander.fittedEquipment(at: .utility(.energyBomb)) == nil)
    try #require(positive.commander.scriptState.pendingEvents.count == 2)
    var game = baseline
    game.commander.scriptState.nextEvent = UInt64(Int64.max) - 2
    try #require(game.commander.valid)
    let before = game
    game.energyBomb()
    #expect(game.energy == before.energy && game.commander == before.commander)
    #expect(game.bodies == before.bodies && game.nextBodyID == before.nextBodyID)
    #expect(game.inventoryContextEpoch == before.inventoryContextEpoch)
    var expectedAnnouncements = before.ecmControl
    expectedAnnouncements.emit(.gameplay("ENERGY BOMB REFUSED"))
    #expect(game.ecmControl.events == expectedAnnouncements.events)
    #expect(game.ecmControl.activation == before.ecmControl.activation)
    #expect(game.message == "ENERGY BOMB REFUSED")
  }

  @Test func empDisabledPhysicalBombKeepsNativeImmunityAndPaysHullEnergyWithoutElectricalPower()
    throws
  {
    var game = try flight()
    let protected = SpaceBody(id: 71, hull: .constrictor, position: .init(500, 0, 1000))
    game.bodies.append(protected)
    game.ensurePhysicalActors()
    var reserve = try #require(
      ElectricalReserve(
        capacity: game.commander.performance.energy,
        recharge: game.commander.performance.recharge * game.commander.energyRechargeMultiplier,
        at: game.commander.flightSimulation.physicalTime))
    try #require(reserve.drain(reserve.capacity, at: reserve.physicalTime))
    game.commander.savedPlayerElectrical = reserve
    try #require(game.playerEMPDisabled)
    let before = game
    game.energyBomb()
    #expect(game.energy == before.energy - 180 && game.energy > 0)
    #expect(game.commander.fittedEquipment(at: .utility(.energyBomb)) == nil)
    #expect(game.bodies.first { $0.id == 70 }?.energy == 0)
    #expect(game.bodies.first { $0.id == 71 }?.energy == protected.energy)
    #expect(game.commander.savedPlayerElectrical == before.commander.savedPlayerElectrical)
    #expect(game.playerEMPDisabled && game.commander.valid)
  }

  @Test func actualFiniteMissileImpactKeepsOrdinaryAndAlienRelativeDamageAndPhysicalAmmunition()
    throws
  {
    for (name, profile, damage) in [
      ("Missile", OrdnanceProfile.standardMissile, 160.0),
      (AlienMissileDefinition.name, OrdnanceProfile.alienSeeker, 200.0),
    ] {
      var game = try flight(bomb: false, rounds: 0)
      try game.commander.grantEquipment(
        name, at: .missilePylon(0), provenance: .grant("finite missile cost fixture"))
      let round = try #require(game.commander.fittedEquipment(at: .missilePylon(0)))
      let resources = NPCResources(
        profile: .nativeHull, energyCapacity: 100, energyRecharge: 0,
        frontCapacity: 500, rearCapacity: 500, shieldRecharge: 0,
        frontShield: 500, rearShield: 500, heatCapacity: 240, heatCooling: 12,
        fuel: 70, fuelCapacity: 70)
      game.bodies[0].physical?.npc?.resources = resources
      try #require(game.bodies[0].physical?.npc?.resources == resources)
      game.weaponsTargetID = 70
      game.missileArmed = true
      try #require(game.fireMissile())
      let projectile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
      let state = try #require(projectile.physical?.ordnance)
      try #require(state.profile == profile && state.profile.damage == damage)
      #expect(state.origin.playerAmmunition == .physical(item: round.id))
      #expect(game.commander.equipmentInventory?.items.contains { $0.id == round.id } == false)
      game.commander.flightSimulation.advancePhysicalTime(2)
      game.advanceNavalMissiles(delta: 2)
      let target = try #require(game.bodies.first { $0.id == 70 })
      let remaining = try #require(target.physical?.npc?.resources)
      #expect(target.energy == 100 && game.commander.kills == 0)
      #expect(remaining.frontShield + remaining.rearShield == 1000 - damage)
      #expect(
        game.bodies.first { $0.id == projectile.id }?.physical?.ordnance?.termination == .impact)
    }
  }
}
