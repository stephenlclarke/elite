import Foundation
import Testing

@testable import EliteCore

private func actualComponentOccluder(distance: Double) throws -> (Game, UUID, Int) {
  var (game, instance, index) = try actualMissionBridgeGame()
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
      game.drainScriptEvents()
      try #require(game.commander.scriptState.pendingEvents.count < 4096)
    }
    let credits = game.commander.credits
    game.advanceGameplayOrdnance(allowEnemyECM: false)
    let damaged = try #require(game.bodies.first { $0.id == sourceID })
    #expect(damaged.energy == source.energy)
    #expect(damaged.scriptNPC?.components["turret"]?.energy == 0)
    #expect(game.bodies.first { $0.id == targetID }?.energy == Hull.sidewinder.navalEnergy ?? 100)
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
}
