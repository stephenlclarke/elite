import Foundation
import Testing

@testable import L337Core

private func actualComponentOccluder(distance: Double) throws -> (Game, UUID, Int) {
  var (game, instance, index) = try actualMissionBridgeGame()
  // Explicit compatible work-tool hull; the default player hull need not support these slots.
  game.commander.shipID = "SH023"
  game.commander.fuel = min(game.commander.fuel, game.commander.fuelCapacity)
  game.ensurePhysicalActors()
  let id = game.bodies[index].id
  game.bodies[index].position = .init(0, -25, distance)
  game.bodies[index].orientation = .init()
  game.bodies[index].rotation = 0
  game.bodies[index].rotationRate = 0
  game.bodies[index].scriptNPC?.intent = nil
  game.celestials = []
  game.speed = 0
  game.screen = .front
  return (game, instance, id)
}

struct NativeMissionWeaponGeometryTests {
  @Test(arguments: [false, true])
  func realNativeMissileHitsAnOffAxisComponentOnceAndRetriesEventPressureWithoutMotion(
    pressure: Bool
  ) throws {
    var (game, instance, sourceID) = try actualComponentOccluder(distance: 500)
    let targetID = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: targetID, hull: .sidewinder, position: .init(0, 0, 2000)))
    game.ensurePhysicalActors()
    let source = try #require(game.bodies.first { $0.id == sourceID })
    let targetEnergy = try #require(game.bodies.first { $0.id == targetID }?.energy)
    let contact = try game.nearestMissionCollision(
      from: .init(0, 0, 24), direction: .init(0, 0, 1), range: 700,
      radius: 0, includePlayer: false)
    try #require(contact?.hit.target == .body(sourceID) && contact?.victimPart == "turret")
    game.weaponsTargetID = targetID
    game.missileArmed = true
    let launched = game.fireMissile()
    try #require(launched)
    let missile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
    game.commander.flightSimulation.advancePhysicalTime(0.8)
    game.scriptEventsDeferred = true
    if pressure {
      let count = game.commander.scriptState.pendingEvents.count
      for _ in count..<4096 {
        game.emitScriptEvent("capacity.probe", values: [:], only: instance, drain: false)
      }
      let commander = game.commander
      let bodies = game.bodies
      game.advanceGameplayOrdnance(allowEnemyECM: false)
      #expect(game.commander == commander && game.bodies == bodies)
      game.scriptEventsDeferred = false
      game.drainScriptEvents()
      game.scriptEventsDeferred = true
      try #require(game.commander.scriptState.pendingEvents.count < 4096)
    }
    let credits = game.commander.credits
    game.advanceGameplayOrdnance(allowEnemyECM: false)
    let damaged = try #require(game.bodies.first { $0.id == sourceID })
    #expect(damaged.energy == source.energy)
    #expect(damaged.scriptNPC?.components["turret"]?.energy == 0)
    #expect(game.bodies.first { $0.id == targetID }?.energy == targetEnergy)
    #expect(game.bodies.first { $0.id == missile.id }?.physical?.ordnance?.termination == .impact)
    #expect(game.bodies.first { $0.id == missile.id }?.energy == 0)
    #expect(game.commander.credits == credits)
    #expect(
      game.commander.scriptState.pendingEvents.filter { $0.kind == "component.destroyed" }.count
        == 1)
    let commander = game.commander
    let bodies = game.bodies
    game.advanceGameplayOrdnance(allowEnemyECM: false)
    #expect(game.commander == commander && game.bodies == bodies)
  }

  @Test func authoredComponentOccludesMiningWithoutTakingDamageOrChargingTheTool() throws {
    var (game, _, sourceID) = try actualComponentOccluder(distance: 250)
    try game.commander.grantEquipment(
      LaserKind.mining.equipmentName, at: .utility(.miningLaser),
      provenance: .grant("geometry fixture"))
    try #require(game.commander.hasMiningWorkTool)
    let rock = try #require(game.miningFields.first?.rocks.first)
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    let id = game.nextBodyID
    game.nextBodyID += 1
    var body = SpaceBody(id: id, hull: .asteroid, position: .init(0, 0, 500))
    body.energy = rock.energy
    body.physical = .init(identity: actor, population: .asteroid, rock: rock.identity)
    game.bodies.append(body)
    let contact = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000,
      radius: 0, includePlayer: false)
    try #require(contact?.hit.target == .body(sourceID) && contact?.victimPart == "turret")
    let commander = game.commander
    let bodies = game.bodies
    let resources = [game.energy, game.laserHeat, game.fireCooldown, game.laserFlash]
    let audio = game.dischargeAudio.events
    let fired = game.fireMiningWorkTool()
    #expect(!fired && game.commander == commander && game.bodies == bodies)
    #expect([game.energy, game.laserHeat, game.fireCooldown, game.laserFlash] == resources)
    #expect(game.dischargeAudio.events == audio)
    game.bodies.removeAll { $0.id == sourceID }
    let unobstructed = game.fireMiningWorkTool()
    #expect(unobstructed)
    #expect(game.bodies.first { $0.id == id }?.energy == rock.energy - LaserKind.mining.damage)
  }

  @Test func authoredComponentOccludesAnEligibleCutterSurfaceWithoutAnyChargeOrDamage() throws {
    var (game, _, sourceID) = try actualComponentOccluder(distance: 100)
    try game.commander.grantEquipment(
      "Salvage Cutter", at: .utility(.salvageCutter), provenance: .grant("geometry fixture"))
    try #require(game.commander.fittedEquipment(at: .utility(.salvageCutter)) != nil)
    try #require(game.commander.performance.workTools?.contains(.salvageCutter) == true)
    let allocation = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocation)
    let wreck = WreckIdentity(system: game.systemIdentity, site: 88, lineage: 99)
    let id = game.nextBodyID
    game.nextBodyID += 1
    var selected: SpaceBody?
    for profile in SalvageCatalogue.all {
      for section in profile.sections {
        let z = section.normal.unit * -1
        let cardinal = abs(z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
        var axes = Basis3()
        axes.z = z
        axes.x = cardinal.cross(z).unit
        axes.y = z.cross(axes.x).unit
        let orientation = axes.transposed
        var body = SpaceBody(
          id: id, hull: .cobra,
          position: Vector3(0, 0, 200) - orientation.apply(section.localPosition))
        body.orientation = orientation
        body.rotationRate = 0
        body.physical = .init(
          identity: actor, population: .civilian, catalogueShipID: profile.catalogueShipID,
          salvage: .init(
            category: .wreck, ownership: .abandoned, claimant: nil, wreck: wreck,
            section: nil, lot: nil, bounds: profile.bounds,
            workSurfaces: profile.surfaces(wreck: wreck)))
        let hit = GameplayRaycast.nearest(
          origin: .init(0, 0, 0), direction: .init(0, 0, 1), maxDistance: 300,
          bodies: [body], meshOverrides: [id: game.gameplayMesh(for: body)])
        if hit?.target == .body(id), let point = hit?.point,
          (point - Vector3(0, 0, 200)).length < 0.001
        {
          selected = body
          break
        }
      }
      if selected != nil { break }
    }
    let target = try #require(selected)
    game.bodies.append(target)
    let contact = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300,
      radius: 0, includePlayer: false)
    try #require(contact?.hit.target == .body(sourceID) && contact?.victimPart == "turret")
    let commander = game.commander
    let bodies = game.bodies
    let resources = [game.energy, game.laserHeat, game.fireCooldown, game.laserFlash]
    let audio = game.dischargeAudio.events
    let accepted = game.fireSalvageCutter(delta: 0.1)
    #expect(!accepted && game.commander == commander && game.bodies == bodies)
    #expect([game.energy, game.laserHeat, game.fireCooldown, game.laserFlash] == resources)
    #expect(game.dischargeAudio.events == audio)
    game.bodies.removeAll { $0.id == sourceID }
    let unobstructed = game.fireSalvageCutter(delta: 0.1)
    #expect(unobstructed)
    #expect(game.bodies.first { $0.id == id }?.energy == target.energy)
  }

}
