import Foundation
import Testing

@testable import EliteCore

private func legacyIntentGame() -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.speed = 0
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  game.bodies = [
    SpaceBody(id: 10, hull: .sidewinder, position: .init(0, 0, 1000), hostile: true)
  ]
  game.bodies[0].energy = 100
  game.celestials = []
  game.energy = 100
  game.frontShield = 0
  game.rearShield = 0
  game.ensurePhysicalActors()
  return game
}

private enum LegacyInvalidIntent: CaseIterable, Equatable, Sendable {
  case missingIntent, dock, flee, nonplayer, staleTarget, missingNPC, missingPhysical
  case staleActorVisit, staleActorSystem, reservedActor, unallocatedActor, missingPlayer
  case wrongPlayerSystem
}

struct LegacyNPCIntentTests {
  @Test(arguments: LegacyInvalidIntent.allCases)
  fileprivate func staleHostilityDoesNotAuthorizePursuitOrEmission(_ invalid: LegacyInvalidIntent)
    throws
  {
    var game = legacyIntentGame()
    let player = try #require(game.commander.flightSimulation.player)
    let physical = try #require(game.bodies[0].physical)
    try #require(physical.npc?.intention == .engage(player))
    switch invalid {
    case .missingIntent: game.bodies[0].physical?.npc?.intention = nil
    case .dock:
      let station = try #require(game.commander.flightSimulation.anchors?.station.identity)
      game.bodies[0].physical?.npc?.intention = .dock(station)
    case .flee: game.bodies[0].physical?.npc?.intention = .flee(player)
    case .nonplayer:
      let allocated = game.commander.flightSimulation.allocateActor()
      let other = try #require(allocated)
      game.bodies[0].physical?.npc?.intention = .engage(other)
    case .staleTarget:
      let old = ActorIdentity(system: player.system, visit: player.visit - 1, entity: player.entity)
      game.bodies[0].physical?.npc?.intention = .engage(old)
    case .missingNPC: game.bodies[0].physical?.npc = nil
    case .missingPhysical: game.bodies[0].physical = nil
    case .staleActorVisit, .staleActorSystem, .reservedActor, .unallocatedActor:
      let old = physical.identity
      let identity = ActorIdentity(
        system: invalid == .staleActorSystem
          ? .init(galaxy: old.system.galaxy, system: old.system.system + 1) : old.system,
        visit: invalid == .staleActorVisit ? old.visit - 1 : old.visit,
        entity: invalid == .reservedActor
          ? 1
          : invalid == .unallocatedActor ? game.commander.flightSimulation.nextActor : old.entity)
      game.bodies[0].physical = .init(
        identity: identity, population: physical.population, npc: physical.npc)
    case .missingPlayer: game.commander.flightSimulation = .init()
    case .wrongPlayerSystem: game.commander.system += 1
    }
    let before = game.bodies
    let commander = game.commander
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies == before && game.commander == commander)
    #expect(game.energy == 100 && game.frontShield == 0 && game.rearShield == 0)
  }

  @Test func adoptedPlayerEngagementStillPursuesAndEmitsThroughRealCombat() throws {
    var game = legacyIntentGame()
    let player = try #require(game.commander.flightSimulation.player)
    let before = try #require(game.bodies.first)
    try #require(before.physical?.npc?.intention == .engage(player))
    let emission = game.commander.flightSimulation.nextEmission
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies[0].position.z < before.position.z && game.energy < 100)
    #expect(game.commander.flightSimulation.nextEmission == emission + 1)
    #expect((game.bodies[0].physical?.npc?.resources?.laserHeat ?? 0) > 0)
    #expect(game.commander.legal == 0 && game.commander.kills == 0)
  }

  @Test func actualNonplayerAssaultRetargetsAndStopsLegacyPlayerAttack() throws {
    var game = legacyIntentGame()
    game.bodies.append(.init(id: 11, hull: .cobra, position: .init(500, 0, 1000)))
    game.ensurePhysicalActors()
    let attacker = try #require(game.bodies[1].physical?.identity)
    let origin = game.makeAttackOrigin(owner: attacker)
    let attack = try #require(origin)
    let hit = GameplayHit(target: .body(10), distance: 500, point: game.bodies[0].position)
    let recorded = game.applyCombatHit(hit, origin: attack, kind: .laser, damage: 1)
    let incident = try #require(recorded)
    #expect(
      incident.origin.owner == attacker && incident.victim == game.bodies[0].physical?.identity)
    #expect(game.bodies[0].physical?.npc?.firstAggressor == attacker)
    #expect(game.bodies[0].physical?.npc?.intention == .engage(attacker))
    #expect(!game.bodies[0].hostile && game.bodies[0].energy == 99)
    let before = game.bodies
    let commander = game.commander
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies == before && game.commander == commander && game.energy == 100)
    #expect(game.commander.legal == 0 && game.commander.kills == 0)
  }

  @Test func actualPlayerAssaultStillEnablesOrdinaryRetaliation() throws {
    var game = legacyIntentGame()
    game.bodies[0].hostile = false
    game.bodies[0].physical?.npc?.intention = nil
    let player = try #require(game.commander.flightSimulation.player)
    let origin = game.makeAttackOrigin(owner: player)
    let attack = try #require(origin)
    let hit = GameplayHit(target: .body(10), distance: 1000, point: game.bodies[0].position)
    let recorded = game.applyCombatHit(hit, origin: attack, kind: .laser, damage: 1)
    try #require(recorded != nil)
    #expect(game.bodies[0].hostile && game.bodies[0].physical?.npc?.intention == .engage(player))
    let legal = game.commander.legal
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.energy < 100 && game.commander.legal == legal && legal > 0)
  }

  @Test func authenticatedLegacyBeamStillRespectsCelestialOcclusion() {
    var game = legacyIntentGame()
    game.celestials = [.init(kind: .planet, position: .init(0, 0, 500), radius: 100)]
    let emission = game.commander.flightSimulation.nextEmission
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies[0].position.z < 1000 && game.energy == 100)
    #expect(game.commander.flightSimulation.nextEmission == emission + 1)
  }

  @Test func blackjackDriverRemainsEligibleWithoutOrdinaryPlayerIntent() throws {
    var game = legacyIntentGame()
    var encounter = BlackjackEncounter(role: .bolts, id: 10)
    encounter.body.position = .init(0, 0, 1000)
    game.bodies = [
      encounter.body, .init(id: 11, hull: .sidewinder, position: .init(500, 0, 1000)),
    ]
    game.ensurePhysicalActors()
    let attacker = try #require(game.bodies[1].physical?.identity)
    let origin = game.makeAttackOrigin(owner: attacker)
    let attack = try #require(origin)
    let hit = GameplayHit(target: .body(10), distance: 500, point: game.bodies[0].position)
    let recorded = game.applyCombatHit(hit, origin: attack, kind: .laser, damage: 1)
    try #require(recorded != nil)
    #expect(game.bodies[0].hostile && game.bodies[0].physical?.npc?.intention == .engage(attacker))
    let before = game.bodies[0].position
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.bodies[0].position.length < before.length)
    #expect((game.bodies[0].blackjackLaserCooldown ?? 0) > 0)
  }
}
