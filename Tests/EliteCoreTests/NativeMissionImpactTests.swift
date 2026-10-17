import Foundation
import Testing

@testable import EliteCore

private func actualLaserImpactGame(towardPlayer: Bool) throws -> (Game, MissionNativeLaserProof) {
  var (game, _, index) = try actualMissionBridgeGame()
  let proof = try initializeActualLaserImpact(&game, index: index, towardPlayer: towardPlayer)
  return (game, proof)
}

private func initializeActualLaserImpact(_ game: inout Game, index: Int, towardPlayer: Bool) throws
  -> MissionNativeLaserProof
{
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
  return proof
}

private func actualRestoredImpactGame(immuneStation: Bool) throws -> (
  Game, MissionNativeImpactProof
) {
  var (game, sample) = try actualShotArchiveFixture()
  let proof = try initializeActualRestoredImpact(
    &game, sample: sample, immuneStation: immuneStation)
  return (game, proof)
}

private func initializeActualRestoredImpact(
  _ game: inout Game, sample: ScriptNPCShot, immuneStation: Bool
) throws -> MissionNativeImpactProof {
  var target = try #require(
    game.bodies.first {
      immuneStation ? $0.id == 0 : $0.missionActorID != nil && $0.missionActorID != sample.owner
    })
  let station = try #require(game.bodies.first { $0.id == 0 })
  target.position = .init(0, immuneStation ? 0 : -25, 1000)
  target.orientation = .init()
  target.rotation = 0
  target.rotationRate = 0
  game.bodies = immuneStation ? [target] : [station, target]
  game.celestials = []
  let anchor = try #require(game.scriptAnchor)
  let velocity = Vector3(0, 0, sample.velocity.length)
  let shot = ScriptNPCShot(
    identity: sample.identity, owner: sample.owner, instance: sample.instance,
    weapon: sample.weapon, component: sample.component,
    velocity: anchor.orientation.inverse(velocity), age: 0.1, lifetime: sample.lifetime,
    damage: sample.damage, radius: sample.radius, collisionDelay: sample.collisionDelay,
    nativeAttribution: sample.nativeAttribution)
  var saved = SpaceBody(
    id: 900_000_000, hull: .missile,
    position: anchor.orientation.inverse(Vector3(0, 0, 700) - anchor.position))
  saved.orientation = Basis3().relative(to: anchor.orientation)
  saved.scriptShot = shot
  saved.energy = 1
  game.commander.scriptState.projectiles[shot.identity] = .init(
    galaxy: game.commander.galaxy, system: game.commander.system, body: saved, presence: .unloaded)
  let receipt = try game.admitRetainedMissionProjectile(shot.identity)
  game.commander.scriptState.projectiles[shot.identity]?.body.id = receipt.bodyID
  game.commander.scriptState.projectiles[shot.identity]?.presence = .present
  let proposed = try game.missionNativeImpactProof(projectileID: shot.identity, delta: 0.5)
  let proof = try #require(proposed)
  try #require(proof.hit.target == .body(target.id) && proof.currentSource == nil)
  return proof
}

private func fillActualMissionEvents(_ game: inout Game, instance: UUID, count: Int) throws {
  let existing = game.commander.scriptState.pendingEvents.count
  try #require(existing <= count)
  for _ in existing..<count {
    game.emitScriptEvent("capacity.probe", values: [:], only: instance, drain: false)
  }
  try #require(game.commander.scriptState.pendingEvents.count == count)
}

struct NativeMissionImpactTests {
  @Test func actualLaserPreviewCountsDamageDeathAndSourceFireWithoutAllocating() throws {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    var source = game.bodies[index]
    var target = try #require(
      game.bodies.first { $0.missionActorID != nil && $0.missionActorID != source.missionActorID })
    source.orientation = .init()
    source.rotation = 0
    target.orientation = .init()
    target.rotation = 0
    target.position = source.position + .init(0, 0, 2000)
    target.energy = 1
    game.bodies = [source, target]
    game.celestials = []
    let npc = try #require(source.scriptNPC)
    let weapon = try #require(npc.fit.definition.lasers?.first)
    let query = try game.queryMissionNativeLaser(
      sourceBodyID: source.id, weapon: weapon, component: nil,
      muzzle: source.position + source.orientation.apply(weapon.muzzle * npc.fit.definition.scale),
      direction: .init(0, 0, 1))
    try #require(query.contact?.hit.target == .body(target.id))
    try #require(query.contact?.victimPart == nil)
    let before = game.commander
    let bodies = game.bodies
    let preview = try game.preflightMissionNativeLaser(query)
    #expect(preview.requiredEvents == 3)
    #expect(game.commander == before && game.bodies == bodies)
    try fillActualMissionEvents(&game, instance: instance, count: 4094)
    let full = game.commander
    #expect(throws: ScriptMissionEventCapacityError.insufficientCapacity) {
      try game.preflightMissionNativeLaser(query)
    }
    #expect(game.commander == full && game.bodies == bodies)
  }

  @Test func aFullActualQueueRefusesProjectileImpactAndAllowsRetryAfterRealEventDraining() throws {
    var (game, proof) = try actualRestoredImpactGame(immuneStation: false)
    try fillActualMissionEvents(&game, instance: proof.sourceInstanceID, count: 4096)
    let before = game.commander
    let bodies = game.bodies
    #expect(throws: ScriptMissionEventCapacityError.insufficientCapacity) {
      try game.applyMissionImpact(proof)
    }
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.bodies.first { $0.scriptShot?.identity == proof.shotID }?.energy == 1)
    game.drainScriptEvents()
    try #require(game.commander.scriptState.pendingEvents.count < 4096)
    let candidate = try game.missionNativeImpactProof(projectileID: proof.shotID, delta: 0.5)
    let retry = try #require(candidate)
    let receipt = try game.applyMissionImpact(retry)
    game.projectScriptMissionImpact(receipt)
    #expect(receipt.damageAdmitted && receipt.terminalShotID == proof.shotID)
    #expect(game.commander.scriptState.projectiles[proof.shotID] == nil)
    #expect(
      game.commander.flightSimulation.nextIncident == before.flightSimulation.nextIncident + 1)
    #expect(
      game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.damaged" }.count == 1)
  }

  @Test func fullMissionQueueRefusesActualPlayerFireBeforeEmissionAndGunDebit() throws {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    var target = game.bodies[index]
    target.position = .init(0, -25, 1000)
    target.orientation = .init()
    target.rotation = 0
    game.bodies = [target]
    game.celestials = []
    game.screen = .front
    try fillActualMissionEvents(&game, instance: instance, count: 4096)
    let commander = game.commander
    let bodies = game.bodies
    let heat = game.laserHeat
    let energy = game.energy
    let cooldown = game.fireCooldown
    let audio = game.dischargeAudio
    game.fireLaser()
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.laserHeat == heat && game.energy == energy && game.fireCooldown == cooldown)
    #expect(game.dischargeAudio.epoch == audio.epoch && game.dischargeAudio.events == audio.events)
  }

  @Test(arguments: [false, true])
  func actualRestoredPlasmaConsumesOnceAndPreservesImmuneContactSemantics(immune: Bool) throws {
    var (game, proof) = try actualRestoredImpactGame(immuneStation: immune)
    let target = try #require(proof.targetBody)
    let incident = game.commander.flightSimulation.nextIncident
    let receipt = try game.applyMissionImpact(proof)
    #expect(receipt.adjudication == .unknown && receipt.originalOrigin == proof.originalOrigin)
    #expect(receipt.damage == proof.damage && receipt.damageAdmitted == !immune)
    #expect(game.commander.flightSimulation.nextIncident == incident + 1)
    #expect(game.bodies.first { $0.scriptShot?.identity == proof.shotID }?.energy == 0)
    let actual = try #require(game.bodies.first { $0.id == target.id })
    if immune {
      #expect(actual.energy == target.energy)
    } else {
      try #require(proof.victimPart == "turret")
      let before = try #require(target.scriptNPC?.components["turret"]?.energy)
      #expect(actual.energy == target.energy)
      #expect(actual.scriptNPC?.components["turret"]?.energy == max(0, before - proof.damage))
    }
    let commander = game.commander
    let bodies = game.bodies
    #expect(throws: (any Error).self) { try game.applyMissionImpact(proof) }
    #expect(game.commander == commander && game.bodies == bodies)
    game.projectScriptMissionImpact(receipt)
    #expect(game.commander.scriptState.projectiles[proof.shotID] == nil)
  }

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
    let loaded = game.load(raw)
    try #require(loaded)
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
    let nearest = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000,
      radius: 0, includePlayer: false)
    let contact = try #require(nearest)
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
    #expect(retained.body.energy > 0 && retained.destroyedByPlayer != true)
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
    #expect(
      game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.destroyed" } == events)
  }
}
