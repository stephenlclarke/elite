import Foundation
import Testing

@testable import L337Core

private func resourceGame() throws -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  game.speed = 0
  let allocated = game.commander.flightSimulation.allocateActor()
  let identity = try #require(allocated)
  var npc = NPCState(
    role: .trader, origin: game.systemIdentity, destination: .init(galaxy: 1, system: 0))
  npc.cargoProvenance = .recorded
  npc.routeProvenance = .generated
  npc.legalProvenance = .recorded
  npc.ordinaryCargo = [.init(commodity: .gold, quantity: 4)]
  npc.resources = NPCResources.stock(game.commander.performance)
  var body = SpaceBody(id: 40, hull: .cobra, position: .init(0, 0, 500))
  body.energy = game.commander.performance.energy
  body.physical = .init(identity: identity, population: .civilian, npc: npc)
  game.bodies = [body]
  return game
}

struct NPCResourceTests {
  @Test func nativeEmitterActuallyWaitsForEnoughThermalHeadroomAfterCooling() throws {
    var game = try resourceGame()
    // The fixed forward emitter needs a closed player hull on its centre ray.
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity
    let performance = game.commander.performance
    game.bodies[0].physical?.npc?.resources = NPCResources.stock(performance)
    game.bodies[0].energy = performance.energy
    game.commander.cargo[0] = 1
    game.energy = 100000
    game.frontShield = 100000
    game.rearShield = 100000
    game.bodies[0].physical?.npc?.role = .pirate
    let spawn = SpawnIdentity(
      system: game.systemIdentity, visit: game.commander.flightSimulation.visit, sequence: 1,
      member: 0)
    game.bodies[0].physical?.spawnIdentity = spawn
    game.bodies[0].orientation.rotate(pitch: 0, roll: 0, yaw: .pi)
    let first = game.commander.flightSimulation.nextEmission
    var thermalWaits = 0
    for _ in 0..<3000 {
      game.commander.flightSimulation.advancePhysicalTime(0.02)
      // Isolate this admitted pirate's actual steering/emitter from new traffic proposals.
      game.commander.encounterDirector = EncounterDirector(
        context: try #require(game.gameplayContext()))
      let before = game.commander.flightSimulation.nextEmission
      let cooldown = game.bodies[0].physical?.laserCooldown ?? 0
      let heat = game.bodies[0].physical?.npc?.resources?.laserHeat ?? 0
      game.advanceGameplayEncounters(delta: 0.02)
      if cooldown <= 0.02 && heat > 230.24,
        game.commander.flightSimulation.nextEmission == before
      {
        thermalWaits += 1
      }
    }
    let shots = game.commander.flightSimulation.nextEmission - first
    #expect(shots >= 80 && shots <= 100)
    #expect(thermalWaits > 0)
    #expect((game.bodies[0].physical?.npc?.resources?.laserHeat ?? 241) <= 240)
  }

  @Test func nonshipBuilderDoesNotInventShipArmamentOrResourceReadings() throws {
    var game = try resourceGame()
    game.commander.installTargetingComputer(.military)
    for hull in [Hull.cargo, .asteroid, .missile] {
      let info = try #require(
        game.information(for: .init(id: 90, hull: hull, position: .init(0, 0, 500))))
      #expect(info.fields.isEmpty)
    }
  }

  @Test func explicitAdmissionInitializesFreshEnergyAndPreservesSpentEnergyOnReAdmission() throws {
    for remaining in [Double?.none, .some(7)] {
      var game = try resourceGame()
      var npc = try #require(game.bodies[0].physical?.npc)
      npc.resources?.frontShield = 12
      game.bodies = []
      var request = SpawnRequest(
        identity: .init(
          system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
          sequence: 2, member: 0), population: .civilian, hull: .cobra,
        position: game.commander.flightSimulation.pose.systemPoint(.init(1000, 0, 1000)),
        orientation: Basis3(), velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil,
        priority: .ordinary)
      request.energy = remaining
      let plan = EncounterPlan(
        system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
        revision: game.gameplayRevision, batches: [.init(requests: [request], atomic: false)],
        intents: [])
      let receipts = game.admitEncounterPlan(plan)
      #expect(receipts.first?.actor != nil)
      #expect(game.bodies.first?.energy == (remaining ?? npc.resources?.energyCapacity))
      #expect(game.bodies.first?.physical?.npc?.resources?.frontShield == 12)
    }
  }

  @Test func everyCargoAndResourceRowRemainsReadableAndReachableInCompactTargetPanel() throws {
    var game = try resourceGame()
    game.commander.installTargetingComputer(.military)
    game.commander.shipDisplayStyle = .whiteWireframe
    game.weaponsTargetID = 40
    game.targetPanelExpanded = true
    game.bodies[0].physical?.npc?.ordinaryCargo = CommodityIdentity.allCases.map {
      .init(commodity: $0, quantity: $0.rawValue + 1)
    }
    let before = game.bodies
    for width in [512.0, 768, 1512] {
      game.viewportWidth = width
      game.viewportHeight = 518
      game.targetPanelScroll = 0
      let info = try #require(game.targetInformation)
      let cockpit = CockpitLayout(game: game, width: width, height: 518)
      let initial = TargetPanelLayout(game: game, info: info, cockpit: cockpit)
      #expect(initial.window.last > 0)
      var read = Set<String>()
      for _ in 0...initial.fields.count {
        let layout = TargetPanelLayout(game: game, info: info, cockpit: cockpit)
        var frame = Frame()
        frame.rasterizeGraphics = false
        Display.targetPanel(game, layout: cockpit, into: &frame)
        for label in frame.labels {
          #expect(label.bounds.x >= 0 && label.bounds.maxX <= width)
          #expect(label.bounds.maxY <= cockpit.flightClip.maxY)
          read.insert(label.text)
        }
        if layout.window.offset == layout.window.last { break }
        game.key("pagedown")
      }
      #expect(initial.fields.allSatisfy { read.contains($0) })
      #expect(read.contains { $0.hasPrefix("Fuel:") })
      game.key("pageup")
      #expect(game.targetPanelScroll < initial.window.last)
    }
    #expect(game.bodies == before && game.time == 0)
  }

  @Test func invalidTimeCannotCorruptActualActorReadingsAndRearHitsRemainIndependent() throws {
    var game = try resourceGame()
    game.bodies[0].physical?.npc?.resources?.rearShield = 3
    let before = game.bodies[0]
    for delta in [Double.nan, .infinity, -.infinity, -1, 0] {
      game.advanceNPCResources(delta: delta)
      #expect(game.bodies[0] == before)
    }
    let player = try #require(game.commander.flightSimulation.player)
    let captured = game.makeAttackOrigin(owner: player)
    let origin = try #require(captured)
    game.applyCombatHit(
      .init(target: .body(40), distance: 499, point: .init(0, 0, 499)), origin: origin,
      kind: .laser, damage: 10, laser: .pulse)
    #expect(game.bodies[0].physical?.npc?.resources?.rearShield == 0)
    #expect(
      game.bodies[0].physical?.npc?.resources?.frontShield
        == before.physical?.npc?.resources?.frontShield)
    #expect(game.bodies[0].energy == before.energy - 7)
  }

  @Test func attributedDamageUsesTheStruckNPCShieldThenHullAndRechargeUsesItsOwnProfile() throws {
    var game = try resourceGame()
    let player = try #require(game.commander.flightSimulation.player)
    let captured = game.makeAttackOrigin(owner: player)
    let origin = try #require(captured)
    let capacity = try #require(game.bodies[0].physical?.npc?.resources?.frontCapacity)
    game.applyCombatHit(
      .init(target: .body(40), distance: 501, point: .init(0, 0, 501)), origin: origin,
      kind: .laser, damage: capacity + 10, laser: .pulse)
    #expect(game.bodies[0].physical?.npc?.resources?.frontShield == 0)
    #expect(game.bodies[0].physical?.npc?.resources?.rearShield == capacity)
    #expect(game.bodies[0].energy == game.commander.performance.energy - 10)
    game.advanceNPCResources(delta: 1)
    #expect(
      game.bodies[0].physical?.npc?.resources?.frontShield
        == game.commander.performance.shieldRecharge)
    #expect(
      game.bodies[0].energy == game.commander.performance.energy - 10
        + game.commander.performance.recharge)
  }

  @Test func actualBeamHeatLimitsCoolIndependentlyAndLegacyEnergyOnlyDoesNotGainShields() throws {
    var resources = try #require(NPCResources.stock(Commander().performance))
    for _ in 0..<24 { resources.recordBeam(heat: 10) }
    #expect(resources.laserHeat == 240 && !resources.canFire)
    resources.advance(delta: 1)
    #expect(resources.laserHeat == 228 && resources.canFire)
    var legacy = try #require(NPCResources.legacyEnergyOnly(maximumEnergy: 252))
    let unshielded = legacy.absorb(15, front: true)
    #expect(unshielded == 15)
    #expect(legacy.frontCapacity == 0 && legacy.rearCapacity == 0)
    #expect(legacy.fuel == nil && legacy.fuelCapacity == nil)
    legacy.recordBeam(heat: 240)
    #expect(legacy.canFire && legacy.laserHeat == 240)
  }

  @Test func fuelChangesOnlyForAcceptedConsumptionOrActualNPCSolarScooping() throws {
    var game = try resourceGame()
    game.bodies[0].physical?.npc?.resources?.fuel = 3
    game.bodies[0].physical?.velocity = .init(0, 0, 144)
    game.advanceNPCResources(delta: 10)
    #expect(game.bodies[0].physical?.npc?.resources?.fuel == 3)
    let spent = game.bodies[0].physical?.npc?.resources?.spendFuel(4)
    #expect(spent == false && game.bodies[0].physical?.npc?.resources?.fuel == 3)
    let accepted = game.bodies[0].physical?.npc?.resources?.spendFuel(3)
    #expect(accepted == true && game.bodies[0].physical?.npc?.resources?.fuel == 0)
    game.celestials = [.init(kind: .sun, position: .init(0, 0, 2500), radius: 1000)]
    game.advanceNPCResources(delta: 1)
    #expect(game.bodies[0].physical?.npc?.resources?.fuel == 0)
    game.bodies[0].physical?.npc?.hasFuelScoops = true
    game.advanceNPCResources(delta: 1)
    #expect(game.bodies[0].physical?.npc?.resources?.fuel == 7)
  }

  @Test func targetReadsNPCFactsRatherThanCommanderAndRespectsDisclosure() throws {
    var game = try resourceGame()
    game.commander.cargo[0] = 99
    game.commander.fuel = 1
    game.commander.legal = 100
    game.frontShield = 1
    game.bodies[0].physical?.npc?.resources?.fuel = 23
    game.bodies[0].physical?.npc?.resources?.frontShield = 12
    game.bodies[0].physical?.npc?.resources?.laserHeat = 37
    game.commander.installTargetingComputer(.pirate)
    let pirate = try #require(game.information(for: game.bodies[0]))
    #expect(pirate.fields.contains { $0.label == "Cargo" && $0.value == "Gold 4 kg" })
    #expect(pirate.fields.contains { $0.label == "Destination" && $0.value.contains("Galaxy 2") })
    #expect(pirate.fields.contains { $0.label == "Legal status" && $0.value == "Clean" })
    #expect(!pirate.fields.contains { $0.label == "Front shield" || $0.label == "Fuel" })
    game.commander.installTargetingComputer(.military)
    let military = try #require(game.information(for: game.bodies[0]))
    #expect(military.fields.contains { $0.label == "Front shield" && $0.value.hasPrefix("12.0 /") })
    #expect(military.fields.contains { $0.label == "Laser heat" && $0.value.hasPrefix("37.0 /") })
    #expect(military.fields.contains { $0.label == "Fuel" && $0.value.hasPrefix("2.3 /") })
    game.bodies[0].physical?.npc?.cargoProvenance = nil
    #expect(game.telemetryFacts(for: game.bodies[0]).cargo == nil)
  }

  @Test func spentResourcesAndProvenanceRoundTripWithoutRefillAndOldNPCStateIsUnknown() throws {
    var game = try resourceGame()
    game.bodies[0].physical?.npc?.resources?.fuel = 2
    game.bodies[0].physical?.npc?.resources?.laserHeat = 200
    game.bodies[0].physical?.npc?.resources?.rearShield = 7
    let data = try JSONEncoder().encode(game.bodies[0])
    let restored = try JSONDecoder().decode(SpaceBody.self, from: data)
    #expect(restored == game.bodies[0])
    var npcObject = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(restored.physical?.npc))
        as? [String: Any])
    for key in [
      "resources", "legalProvenance", "cargoProvenance", "routeProvenance", "hasFuelScoops",
    ] { npcObject.removeValue(forKey: key) }
    let old = try JSONDecoder().decode(
      NPCState.self, from: JSONSerialization.data(withJSONObject: npcObject))
    #expect(old.resources == nil && old.cargoProvenance == nil && old.routeProvenance == nil)
  }
}
