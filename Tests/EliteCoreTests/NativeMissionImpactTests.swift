import Foundation
import Testing

@testable import EliteCore

private func actualLaserImpactGame(towardPlayer: Bool) throws -> (Game, MissionNativeLaserProof) {
  var (game, _, index) = try actualMissionBridgeGame()
  game.ensurePhysicalActors()
  let source = game.bodies[index]
  let npc = try #require(source.scriptNPC)
  let weapon = try #require(npc.fit.definition.lasers?.first { $0.kind == .laser })
  game.bodies = [source]
  game.celestials = []
  let muzzle = source.position + source.orientation.apply(weapon.muzzle * npc.fit.definition.scale)
  let proof = try game.makeMissionNativeLaserProof(
    sourceBodyID: source.id, weapon: weapon, component: nil, muzzle: muzzle,
    direction: towardPlayer ? muzzle.unit * -1 : .init(0, 1, 0))
  return (game, proof)
}

struct NativeMissionImpactTests {
  @Test(arguments: [false, true])
  func actualInstantLaserIsConsumedOnceForMissAndPlayerShieldHit(hit: Bool) throws {
    var (game, proof) = try actualLaserImpactGame(towardPlayer: hit)
    try #require(hit ? proof.hit?.target == .player : proof.hit == nil)
    let incident = game.commander.flightSimulation.nextIncident
    let shield = game.frontShield
    let energy = game.energy
    let receipt = try game.applyMissionImpact(proof)
    #expect(receipt.adjudication == .currentVisit && !receipt.player)
    #expect(receipt.sourceActorID == proof.sourceActorID && receipt.terminalShotID == nil)
    #expect(game.commander.flightSimulation.nextIncident == incident + 1)
    #expect(game.energy == energy)
    #expect(game.frontShield == (hit ? max(0, shield - proof.damage) : shield))
    let before = game.commander
    let bodies = game.bodies
    let afterShield = game.frontShield
    #expect(throws: (any Error).self) { try game.applyMissionImpact(proof) }
    #expect(game.commander == before && game.bodies == bodies && game.frontShield == afterShield)
  }

  @Test func actualLaserClockDriftRefusesBeforeAnyIncidentOrPhysicalDamage() throws {
    var (game, proof) = try actualLaserImpactGame(towardPlayer: true)
    game.commander.flightSimulation.advancePhysicalTime(0.01)
    let before = game.commander
    let bodies = game.bodies
    let shield = game.frontShield
    #expect(throws: (any Error).self) { try game.applyMissionImpact(proof) }
    #expect(game.commander == before && game.bodies == bodies && game.frontShield == shield)
  }

  @Test func rawCommanderReplacementStartsItsOwnEmissionTimelineWithoutRevivingOldProof() throws {
    var (game, oldProof) = try actualLaserImpactGame(towardPlayer: false)
    _ = try game.applyMissionImpact(oldProof)
    let pack = try #require(game.scriptPacks.first)
    let raw = Game(executive: false).commander
    try #require(game.load(raw))
    game.screen = .status
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    game.drainScriptEvents()
    game.ensurePhysicalActors()
    let source = try #require(game.bodies.first { $0.missionInstanceID == instance })
    let npc = try #require(source.scriptNPC)
    let weapon = try #require(npc.fit.definition.lasers?.first { $0.kind == .laser })
    game.bodies = [source]
    game.celestials = []
    let fresh = try game.makeMissionNativeLaserProof(
      sourceBodyID: source.id, weapon: weapon, component: nil,
      muzzle: source.position + source.orientation.apply(weapon.muzzle * npc.fit.definition.scale),
      direction: .init(0, 1, 0))
    try #require(fresh.origin.emissionID == oldProof.origin.emissionID)
    #expect(throws: (any Error).self) { try game.applyMissionImpact(oldProof) }
    _ = try game.applyMissionImpact(fresh)
    let commander = game.commander
    #expect(throws: (any Error).self) { try game.applyMissionImpact(fresh) }
    #expect(game.commander == commander)
  }

  @Test func actualPlayerLaserUsesAuthoredComponentGeometryAndSharedDamage() throws {
    var (game, _, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    var target = game.bodies[index]
    target.position = .init(0, -25, 1000)
    target.orientation = .init()
    target.rotation = 0
    target.rotationRate = 0
    game.bodies = [target]
    game.celestials = []
    game.screen = .front
    let contact = try #require(
      game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000,
        radius: 0, includePlayer: false))
    try #require(contact.victimPart == "turret")
    let component = try #require(target.scriptNPC?.components["turret"])
    let damage = game.commander.laserDamage(against: target.hull, mount: .front)
    game.fireLaser()
    let actual = try #require(game.bodies.first { $0.id == target.id })
    #expect(actual.energy == target.energy)
    #expect(actual.scriptNPC?.components["turret"]?.identity == component.identity)
    #expect(actual.scriptNPC?.components["turret"]?.energy == max(0, component.energy - damage))
    let events = game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.damaged" }
    #expect(events.count == 1)
    #expect(events.first?.values["player"] == .bool(true))
    #expect(events.first?.values["attacker_id"] == .null)
  }

  @Test func livingProfiledActorCullsOutsideAndReentersWithSameConditionAndIdentity() throws {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.speed = 0
    game.pitch = 0
    game.roll = 0
    game.yaw = 0
    game.bodies[index].position = .init(70_000, 0, 1000)
    game.bodies[index].energy = 73
    game.bodies[index].scriptNPC?.intent = nil
    game.bodies[index].scriptNPC?.velocity = .init(0, 0, 0)
    let identity = try #require(game.bodies[index].missionActorID)
    let condition = try #require(game.bodies[index].scriptNPC?.components)
    game.tick(delta: 0.01)
    let retained = try #require(
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"])
    #expect(retained.identity == identity && retained.presence == .outside)
    #expect(retained.body.energy > 0 && !retained.destroyedByPlayer)
    #expect(retained.body.scriptNPC?.components == condition)
    #expect(!game.bodies.contains { $0.missionActorID == identity })
    #expect(!game.commander.scriptState.pendingEvents.contains { $0.kind == "actor.destroyed" })
    let travel = Vector3(70_000, 0, 0)
    game.commander.flightSimulation.pose.position =
      game.commander.flightSimulation.pose.position
      + game.commander.flightSimulation.pose.orientation.apply(travel)
    for i in game.bodies.indices { game.bodies[i].position = game.bodies[i].position - travel }
    try game.restoreScriptActors()
    let restored = try #require(game.bodies.first { $0.missionActorID == identity })
    #expect(restored.energy == retained.body.energy && restored.scriptNPC?.components == condition)
    #expect(
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?
        .actors["lead"]?.presence == .present)
  }

  @Test func actualDeadProfiledActorIsRecordedOnceAndCannotRestore() throws {
    var (game, instance, index) = try actualMissionBridgeGame()
    let identity = try #require(game.bodies[index].missionActorID)
    game.bodies[index].energy = 0
    game.bodies[index].destroyedByPlayer = false
    game.resolveDestroyed()
    let retained = try #require(
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"])
    #expect(retained.presence == .destroyed && retained.body.energy == 0)
    #expect(!game.bodies.contains { $0.missionActorID == identity })
    let events = game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.destroyed" }
    #expect(events.count == 1)
    game.resolveDestroyed()
    try game.restoreScriptActors()
    #expect(!game.bodies.contains { $0.missionActorID == identity })
    #expect(game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.destroyed" } == events)
  }
}
