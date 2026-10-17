import Foundation
import Testing

@testable import EliteCore

/// Real owned equipment and an ordinary catalogue-backed actor, not a pre-disabled or synthetic wreck.
func empFixture(catalogue: String = "SH023", hostile: Bool = false, police: Bool = false) throws
  -> Game
{
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  for (name, slot) in [
    (Equipment.empPirateBlaster, ComponentFittingSlot.utility(.empPirateBlaster)),
    ("Salvage Cutter", .utility(.salvageCutter)), ("Fuel Scoops", .utility(.fuelScoops)),
    ("Targeting: Salvage Module", .targetingSalvage),
    (TargetingTier.military.equipmentName, .targetingCore),
  ] {
    try game.commander.grantEquipment(name, at: slot, provenance: .grant("EMP regression"))
  }
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  game.miningFields = []
  game.salvageSites = []
  game.commander.npcPersistence = .init()
  let id = police ? try #require(ShipCatalogue.nativeShip(.viper)?.id) : catalogue
  let ship = try #require(ShipCatalogue.ship(id))
  let performance = try #require(ship.game)
  var body = SpaceBody(
    id: 42, hull: police ? .viper : .cobra, position: .init(0, 0, 1000), hostile: hostile)
  body.rotationRate = 0
  body.energy = min(77, performance.energy * 0.6)
  game.bodies = [body]
  game.nextBodyID = max(game.nextBodyID, 43)
  game.ensurePhysicalActors()
  game.bodies[0].physical?.catalogueShipID = id
  game.bodies[0].physical?.velocity = .init(15, -2, 5)
  game.bodies[0].physical?.angularVelocity = .init(0, 0.1, 0.2)
  game.bodies[0].physical?.canonicalSpin = true
  game.bodies[0].physical?.npc?.resources = .stock(performance)
  game.bodies[0].physical?.npc?.ordinaryCargo = [.init(commodity: .food, quantity: 2)]
  game.bodies[0].physical?.npc?.cargoProvenance = .recorded
  game.bodies[0].physical?.npc?.legalProvenance = .recorded
  let destination = try #require(
    game.systems.first {
      $0.id != game.commander.system && $0.id != Plugh.systemID
        && game.currentSystem.distance(to: $0) > 0 && game.currentSystem.distance(to: $0) <= 3
    })
  game.bodies[0].physical?.npc?.destination = .init(
    galaxy: game.commander.galaxy, system: destination.id)
  game.bodies[0].physical?.npc?.routeProvenance = .recorded
  game.selectFlightTool(.empPirateBlaster)
  try #require(game.commander.valid)
  return game
}

struct EMPPirateBlasterTests {
  @Test func realMeshHitDisablesWithoutDamageOrRewardAndRepeatedHitsAreIdempotent() throws {
    var game = try empFixture()
    let before = game.commander
    let body = game.bodies[0]
    let energy = game.energy
    let heat = game.laserHeat
    let empResult = game.fireEMPPirateBlaster()
    #expect(empResult)
    let disabled = try #require(game.bodies.first { $0.id == body.id })
    let source = try #require(disabled.physical?.empSource)
    let record = try #require(game.commander.savedEMPState?.records[source])
    #expect(record.valid && game.commander.valid)
    #expect(
      disabled.energy == body.energy
        && disabled.physical?.npc?.resources == body.physical?.npc?.resources)
    #expect(disabled.physical?.identity == body.physical?.identity)
    #expect(disabled.position == body.position && disabled.orientation == body.orientation)
    #expect(disabled.physical?.velocity == body.physical?.velocity)
    #expect(disabled.physical?.angularVelocity == body.physical?.angularVelocity)
    #expect(game.commander.credits == before.credits && game.commander.kills == before.kills)
    #expect(game.commander.cargo == before.cargo && disabled.destroyedByPlayer == nil)
    #expect(game.energy == energy - Game.empEnergyCost && game.laserHeat == heat + Game.empHeatCost)
    #expect(game.fireCooldown == Game.empCooldown)
    #expect(record.disableIncident.kind == .emp && record.disableIncident.outcome == .hit)
    #expect(record.disableIncident.victim == body.physical?.identity)
    #expect(game.commander.legal > before.legal)
    #expect(record.crewAboard == record.crewTotal && record.pods.isEmpty)
    let cutterResult = game.fireSalvageCutter(delta: 0.1)
    #expect(!cutterResult)
    game.fireCooldown = 0
    let once = game.commander
    let remaining = game.energy
    let empResult2 = game.fireEMPPirateBlaster()
    #expect(!empResult2)
    #expect(game.commander == once && game.energy == remaining)
    #expect(
      !game.message.contains("DESTROYED")
        && game.dischargeAudio.events.last?.tool == .empPirateBlaster)
  }

  @Test(arguments: [false, true])
  func missAndActualOccludingMeshCannotDisableTheShip(occluded: Bool) throws {
    var game = try empFixture()
    if occluded {
      game.bodies.append(.init(id: 99, hull: .asteroid, position: .init(0, 0, 350)))
      game.nextBodyID = 100
      game.ensurePhysicalActors()
    } else {
      game.bodies[0].position.x = 1500
    }
    let before = game.commander
    let bodies = game.bodies
    let energy = game.energy
    let empResult = game.fireEMPPirateBlaster()
    #expect(!empResult)
    #expect(game.commander == before && game.bodies == bodies && game.energy == energy)
    #expect(game.commander.savedEMPState == nil)
  }

  @Test func disabledPropulsionCoastsAndActualFuelledJumpRefusesWithoutSpendingFuel() throws {
    var game = try empFixture()
    let target = game.bodies[0]
    let destination = try #require(target.physical?.npc?.destination)
    let fuel = try #require(target.physical?.npc?.resources?.fuel)
    var available = game
    let jumpResult = available.initiateNPCJump(bodyID: target.id, destination: destination)
    #expect(jumpResult)
    let actor = try #require(target.physical?.identity)
    let spent = try #require(
      available.commander.npcPersistence.snapshot(for: actor)?.npc.resources?.fuel)
    #expect(spent < fuel && !available.bodies.contains { $0.id == target.id })
    #expect(available.commander.npcPersistence.terminalReason(for: actor) == .jumped)
    let empResult = game.fireEMPPirateBlaster()
    #expect(empResult)
    let before = game.commander
    let jumpResult2 = game.initiateNPCJump(bodyID: target.id, destination: destination)
    #expect(!jumpResult2)
    #expect(game.commander == before)
    let position = game.commander.flightSimulation.pose.systemPoint(game.bodies[0].position)
    let velocity = try #require(game.bodies[0].physical?.velocity)
    let angular = try #require(game.bodies[0].physical?.angularVelocity)
    game.tick(delta: 0.1)
    let coast = try #require(game.bodies.first { $0.id == target.id })
    #expect(
      (game.commander.flightSimulation.pose.systemPoint(coast.position) - position - velocity * 0.1)
        .length < 1e-7)
    #expect(coast.physical?.velocity == velocity && coast.physical?.angularVelocity == angular)
    #expect(coast.physical?.npc?.resources?.fuel == fuel)
  }

  @Test func ordinaryPoliceAreNotImmuneAndTheirRealSourceAndAssaultAreRetained() throws {
    var game = try empFixture(police: true)
    try #require(game.bodies[0].physical?.blocksNavalEncounter == true)
    let before = game.commander.legal
    let empResult = game.fireEMPPirateBlaster()
    #expect(empResult)
    let record = try #require(game.commander.savedEMPState?.records.values.first)
    #expect(record.custody.kind == .police && record.custody.valid && record.valid)
    #expect(record.custody.original.body.physical?.npc?.role == .police)
    #expect(record.disableIncident.victimRole == .police && game.commander.legal > before)
    #expect(game.commander.npcPersistence.count == 0)
  }

  @Test func missionProtectedAndAlienModelsCannotBecomeHumanDerelicts() throws {
    for alien in [false, true] {
      var game = try empFixture(catalogue: alien ? "SH123" : "SH023")
      if !alien { game.bodies[0].physical?.npc?.role = .mission }
      let before = game.commander
      let bodies = game.bodies
      let empResult = game.fireEMPPirateBlaster()
      #expect(!empResult)
      #expect(game.commander == before && game.bodies == bodies)
      #expect(game.commander.savedEMPState == nil)
    }
  }

  @Test func fullActorCapacityKeepsEveryActualCrewMemberAboardUntilPodsAreAdmitted() throws {
    var game = try empFixture(catalogue: "SH001")
    game.bodies[0].physical?.velocity = .init(0, 0, 0)
    game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    let empResult = game.fireEMPPirateBlaster()
    #expect(empResult)
    let source = try #require(game.bodies[0].physical?.empSource)
    let crew = try #require(game.commander.savedEMPState?.records[source]?.crewTotal)
    try #require(crew == 2)
    for i in 0..<128 {
      game.bodies.append(
        .init(id: 100 + i, hull: .cargo, position: .init(10_000 + Double(i) * 100, 0, 0)))
    }
    game.nextBodyID = 228
    game.ensurePhysicalActors()
    for _ in 0..<11 { game.commander.flightSimulation.advancePhysicalTime(0.1) }
    game.advanceEMPActors()
    let blocked = try #require(game.commander.savedEMPState?.records[source])
    #expect(blocked.crewAboard == crew && blocked.pods.isEmpty)
    #expect(game.bodies.first { $0.physical?.empSource == source }?.physical?.npc != nil)
    game.bodies.removeAll { $0.id >= 100 }
    for _ in 0..<40 { game.tick(delta: 0.1) }
    let abandoned = try #require(game.commander.savedEMPState?.records[source])
    #expect(abandoned.crewAboard == 0 && abandoned.pods.count == crew)
    #expect(Set(abandoned.pods.compactMap { $0.body.physical?.empCrewPod }).count == crew)
    let hull = try #require(game.bodies.first { $0.physical?.empSource == source })
    #expect(hull.physical?.npc == nil && hull.physical?.salvage?.ownership == .abandoned)
    let pods = game.bodies.filter { $0.physical?.empCrewPod?.source == source }
    #expect(
      pods.count == crew && pods.allSatisfy { $0.physical?.salvage?.category == .occupiedPod })
    let people = abandoned.pods
    for _ in 0..<20 { game.tick(delta: 0.1) }
    #expect(game.commander.savedEMPState?.records[source]?.pods.count == people.count)
    #expect(game.commander.valid)
  }
}
