import Foundation
import Testing

@testable import EliteCore

private func projectionActors(component: Bool) throws -> (Game, UUID, Int, Int) {
  var (game, instance, sourceIndex) = try actualMissionBridgeGame()
  let sourceID = game.bodies[sourceIndex].id
  let wing = try #require(
    game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors["wing"])
  let targetIndex = try #require(game.bodies.firstIndex { $0.missionActorID == wing.identity })
  let targetID = game.bodies[targetIndex].id
  game.bodies[sourceIndex].position = .init(0, 0, 1000)
  game.bodies[sourceIndex].orientation = Basis3()
  game.bodies[targetIndex].position = .init(0, 0, 2000)
  game.bodies[targetIndex].orientation = Basis3()
  if component {
    game.bodies[targetIndex].scriptNPC?.components["turret"]?.energy = 5
  } else {
    game.bodies[targetIndex].energy = 5
  }
  game.ensurePhysicalActors()
  game.bodies = game.bodies.filter { $0.id == sourceID || $0.id == targetID }
  game.celestials = []
  game.scriptEventsDeferred = true
  return (game, instance, sourceID, targetID)
}

private func producedLaser(_ game: inout Game, sourceID: Int, targetID: Int, component: Bool) throws
  -> MissionNativeLaserProof
{
  let source = try #require(game.bodies.first { $0.id == sourceID })
  let target = try #require(game.bodies.first { $0.id == targetID })
  let npc = try #require(source.scriptNPC)
  let weapon = try #require(npc.fit.definition.lasers?.first)
  let muzzle = source.position + source.orientation.apply(weapon.muzzle * npc.fit.definition.scale)
  let aim: Vector3
  if component {
    let specification = try #require(
      target.scriptNPC?.fit.definition.components?.first { $0.id == "turret" })
    aim =
      target.position
      + target.orientation.apply(specification.position * target.scriptNPC!.fit.definition.scale)
  } else {
    aim = target.position
  }
  return try game.makeMissionNativeLaserProof(
    sourceBodyID: sourceID, weapon: weapon, component: nil, muzzle: muzzle,
    direction: (aim - muzzle).unit)
}

struct ScriptMissionImpactProjectionTests {
  @Test(arguments: [false, true])
  func realNpcLaserProofKernelAndProjectionRetainOriginalAmountAndTerminalExactlyOnce(
    component: Bool
  ) throws {
    var (game, instance, sourceID, targetID) = try projectionActors(component: component)
    let sourceActor = try #require(game.bodies.first { $0.id == sourceID }?.missionActorID)
    let targetActor = try #require(game.bodies.first { $0.id == targetID }?.missionActorID)
    let proof = try producedLaser(
      &game, sourceID: sourceID, targetID: targetID, component: component)
    try #require(proof.hit?.target == .body(targetID))
    try #require(proof.victimPart == (component ? "turret" : nil))
    let firstSequence = game.commander.scriptState.nextEvent
    let receipt = try game.applyMissionImpact(proof)
    #expect(receipt.damageAdmitted && receipt.damage == proof.damage && receipt.damage > 5)
    #expect(!receipt.player && receipt.sourceActorID == sourceActor)
    #expect(receipt.targetMissionActorID == targetActor)
    #expect(receipt.componentDestroyed == component && receipt.hullDestroyed == !component)
    #expect(game.commander.scriptState.nextEvent == firstSequence)
    let physical = game.bodies
    let law = game.commander.crimeLedger
    let flight = game.commander.flightSimulation
    game.projectScriptMissionImpact(receipt)
    #expect(game.bodies == physical && game.commander.crimeLedger == law)
    #expect(game.commander.flightSimulation == flight)
    let events = game.commander.scriptState.pendingEvents.filter { $0.sequence > firstSequence }
    #expect(
      events.map(\.kind) == [
        "actor.damaged", component ? "component.destroyed" : "actor.destroyed",
      ])
    let damage = try #require(events.first)
    #expect(damage.values["amount"] == .number(proof.damage))
    #expect(damage.values["attacker_id"] == .string(sourceActor.uuidString))
    #expect(damage.values["player"] == .bool(false))
    if component {
      #expect(damage.values["component"] == .string("turret"))
      #expect(
        damage.values["component_id"] == receipt.victimComponentID.map { .string($0.uuidString) })
      #expect(game.bodies.first { $0.id == targetID }?.energy == 120)
    } else {
      #expect(events.last?.values["destroyed_by_player"] == .bool(false))
      #expect(
        game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors[
          "wing"]?.presence == .destroyed)
    }
    let committed = game.commander
    let committedBodies = game.bodies
    #expect(throws: (any Error).self) { try game.applyMissionImpact(proof) }
    #expect(game.commander == committed && game.bodies == committedBodies)
    game.resolveDestroyed()
    let terminal = game.commander.scriptState.pendingEvents.filter {
      $0.kind == "actor.destroyed" && $0.values["actor_id"] == .string(targetActor.uuidString)
    }
    #expect(terminal.count == (component ? 0 : 1))
  }

  @Test func actualPlayerNativeContactProducesPlayerReceiptAndNullScriptAttacker() throws {
    var (game, _, sourceID, targetID) = try projectionActors(component: true)
    let sourceIndex = try #require(game.bodies.firstIndex { $0.id == sourceID })
    let targetIndex = try #require(game.bodies.firstIndex { $0.id == targetID })
    game.bodies[sourceIndex].position.x = 2000
    game.bodies[targetIndex].position.y = -25
    game.ensurePhysicalActors()
    let queried = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0, includePlayer: false)
    let contact = try #require(queried)
    try #require(contact.hit.target == .body(targetID) && contact.victimPart == "turret")
    let player = try #require(game.commander.flightSimulation.player)
    let allocated = game.makeAttackOrigin(owner: player)
    let origin = try #require(allocated)
    let laser = try #require(game.commander.laser(on: .front))
    let amount = game.commander.laserDamage(against: game.bodies[targetIndex].hull, mount: .front)
    let sequence = game.commander.scriptState.nextEvent
    let receipt = try game.applyNativeMissionContact(
      contact, origin: origin, damage: amount, laser: laser, mount: .front,
      emissionPosition: game.commander.flightSimulation.pose.position)
    #expect(receipt.player && receipt.sourceActorID == nil && receipt.sourceInstanceID == nil)
    #expect(receipt.originalOrigin == origin && receipt.damageAdmitted && receipt.damage == amount)
    let physical = game.bodies
    let law = game.commander.crimeLedger
    game.projectScriptMissionImpact(receipt)
    #expect(game.bodies == physical && game.commander.crimeLedger == law)
    let events = game.commander.scriptState.pendingEvents.filter { $0.sequence > sequence }
    #expect(events.map(\.kind) == ["actor.damaged", "component.destroyed"])
    #expect(events.first?.values["player"] == .bool(true))
    #expect(events.first?.values["attacker_id"] == .null)
    #expect(events.first?.values["amount"] == .number(amount))
    let committed = game.commander
    let committedBodies = game.bodies
    #expect(throws: (any Error).self) {
      try game.applyNativeMissionContact(
        contact, origin: origin, damage: amount, laser: laser, mount: .front,
        emissionPosition: game.commander.flightSimulation.pose.position)
    }
    #expect(game.commander == committed && game.bodies == committedBodies)
  }

  @Test(arguments: [false, true])
  func realRestoredLegacyPlasmaKeepsGenuineAbsentSourceUuidWithoutNativeCredit(component: Bool)
    throws
  {
    var (game, shotID) = try retainedProjectileGame(archived: false)
    let retainedShot = try #require(game.commander.scriptState.projectiles[shotID]?.body.scriptShot)
    let source = try #require(game.bodies.first { $0.missionActorID == retainedShot.owner })
    let anchor = try #require(game.scriptAnchor)
    let targetIndex = try #require(
      game.bodies.firstIndex {
        $0.missionInstanceID == retainedShot.instance && $0.missionActorID != retainedShot.owner
      })
    let targetID = game.bodies[targetIndex].id
    let targetActor = try #require(game.bodies[targetIndex].missionActorID)
    game.bodies[targetIndex].position =
      anchor.position + anchor.orientation.apply(.init(0, 0, 5500))
    game.bodies[targetIndex].orientation = anchor.orientation
    if component {
      game.bodies[targetIndex].scriptNPC?.components["turret"]?.energy = 5
    } else {
      game.bodies[targetIndex].energy = 5
    }
    let target = game.bodies[targetIndex]
    game.recordScriptActorRemoval(source, destroyed: false)
    game.bodies = [anchor, target]
    game.celestials = []
    game.scriptEventsDeferred = true
    game.commander.scriptState.projectiles[shotID]?.body.position = .init(
      0, component ? 25 : 0, 5000)
    try game.restoreScriptShots(anchor: anchor)
    let produced = try game.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
    let proof = try #require(produced)
    try #require(proof.hit.target == .body(targetID))
    try #require(
      proof.currentSource == nil && proof.originalOrigin == nil && proof.attribution == .unknown)
    let sequence = game.commander.scriptState.nextEvent
    let credits = game.commander.credits
    let kills = game.commander.kills
    let receipt = try game.applyMissionImpact(proof)
    #expect(receipt.damageAdmitted && receipt.damage == retainedShot.damage)
    #expect(receipt.sourceActorID == retainedShot.owner && !receipt.player)
    #expect(receipt.adjudication == .unknown && receipt.originalOrigin == nil)
    let physical = game.bodies
    let law = game.commander.crimeLedger
    game.projectScriptMissionImpact(receipt)
    #expect(game.bodies == physical && game.commander.crimeLedger == law)
    #expect(game.commander.scriptState.projectiles[shotID] == nil)
    let events = game.commander.scriptState.pendingEvents.filter { $0.sequence > sequence }
    #expect(
      events.map(\.kind) == [
        "actor.damaged", component ? "component.destroyed" : "actor.destroyed",
      ])
    #expect(events.first?.values["actor_id"] == .string(targetActor.uuidString))
    #expect(events.first?.values["attacker_id"] == .string(retainedShot.owner.uuidString))
    #expect(events.first?.values["player"] == .bool(false))
    #expect(events.first?.values["amount"] == .number(retainedShot.damage))
    let committed = game.commander
    let committedBodies = game.bodies
    #expect(throws: (any Error).self) { try game.applyMissionImpact(proof) }
    #expect(game.commander == committed && game.bodies == committedBodies)
    game.resolveDestroyed()
    #expect(game.commander.credits == credits && game.commander.kills == kills)
    #expect(
      game.commander.scriptState.instances[retainedShot.instance]?.ownedEncounters["opponents"]?
        .actors["lead"]?.presence == .outside)
    let terminal = game.commander.scriptState.pendingEvents.filter {
      $0.kind == "actor.destroyed" && $0.values["actor_id"] == .string(targetActor.uuidString)
    }
    #expect(terminal.count == (component ? 0 : 1))
  }
}
