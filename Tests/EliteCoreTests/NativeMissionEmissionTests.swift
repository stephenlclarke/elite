import Foundation
import Testing

@testable import EliteCore

private func actualEmissionPlan(_ game: Game, sourceID: Int) throws
  -> NativeMissionProjectileEmissionPlan
{
  let source = try game.currentMissionNativeBinding(bodyID: sourceID)
  let body = try #require(game.bodies.first { $0.id == sourceID })
  let npc = try #require(body.scriptNPC)
  let spec = try #require(npc.fit.definition.components?.first)
  let state = try #require(npc.components[spec.id])
  let weapon = try #require(spec.weapons?.first { $0.kind == .plasma })
  let center = body.position + body.orientation.apply(spec.position * npc.fit.definition.scale)
  let pose = spec.orientation.transformed(by: body.orientation)
  let muzzle = center + pose.apply(weapon.muzzle * (spec.scale * npc.fit.definition.scale))
  return try game.prepareMissionProjectileAdmission(
    source: source, weapon: weapon, component: state.identity, muzzle: muzzle,
    direction: muzzle.unit * -1, intendedTarget: .player)
}

struct NativeMissionEmissionTests {
  @Test func actualPreparationHasNoEffectsAndCommitPublishesOneNativeBodyAndCanonicalRecord() throws {
    var (game, _, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    let source = game.bodies[index]
    let before = game.commander
    let bodies = game.bodies
    let next = game.nextBodyID
    let plan = try actualEmissionPlan(game, sourceID: source.id)
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == next)
    let receipt = try game.commitMissionProjectileAdmission(plan)
    let actual = try #require(game.bodies.first { $0.id == receipt.bodyID })
    #expect(actual.id == next && actual.physical?.identity == plan.actor)
    #expect(actual.scriptShot?.identity == plan.shotID)
    #expect(actual.scriptShot?.nativeAttribution == plan.archive)
    #expect(game.commander.flightSimulation.nextActor == before.flightSimulation.nextActor + 1)
    #expect(game.commander.flightSimulation.nextSpawn == before.flightSimulation.nextSpawn + 1)
    #expect(game.commander.flightSimulation.nextEmission == before.flightSimulation.nextEmission + 1)
    #expect(game.nextBodyID == next + 1)
    let saved = try #require(game.commander.scriptState.projectiles[plan.shotID])
    let anchor = try #require(game.scriptAnchor)
    #expect(saved.presence == .present && saved.body.id == actual.id)
    #expect(saved.body.position == anchor.orientation.inverse(actual.position - anchor.position))
    #expect(saved.body.scriptShot?.nativeAttribution == plan.archive)
    #expect(game.bodies.first { $0.id == source.id }?.scriptNPC == source.scriptNPC)
    // This verifies native admission only. The actual gun wrapper separately commits its
    // selected gun fields and weapon.fired event; this test does not claim that wrapper ran.
    let committed = game.commander
    let admitted = game.bodies
    #expect(throws: (any Error).self) { try game.commitMissionProjectileAdmission(plan) }
    #expect(game.commander == committed && game.bodies == admitted)
  }

  @Test func changedActualGunConditionRefusesAStalePlanWithoutAnyNativeAllocation() throws {
    var (game, _, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    let sourceID = game.bodies[index].id
    let plan = try actualEmissionPlan(game, sourceID: sourceID)
    game.bodies[index].scriptNPC?.components["turret"]?.guns["plasma"]?.cooldown = 0.1
    let before = game.commander
    let bodies = game.bodies
    let next = game.nextBodyID
    #expect(throws: (any Error).self) { try game.commitMissionProjectileAdmission(plan) }
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == next)
  }

  @Test func actualNativeProjectilePopulationLimitRefusesBeforeEmissionOrRecordCreation() throws {
    var (game, _, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    let sourceID = game.bodies[index].id
    let allocated = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocated)
    let context = try #require(game.gameplayContext())
    let requests = (0..<PopulationClass.projectile.maximum).map { member in
      SpawnRequest(
        identity: .init(
          system: context.system, visit: context.visit, sequence: sequence,
          member: UInt16(member), producer: .ordnance),
        population: .projectile, hull: .missile,
        position: context.player.position + .init(10_000, Double(member) * 20, 10_000),
        orientation: .init(), velocity: .init(0, 0, 0),
        npc: nil, rock: nil, payload: nil, priority: .mission)
    }
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: true)], intents: []))
    try #require(receipts.count == requests.count && receipts.allSatisfy { $0.actor != nil })
    let before = game.commander
    let bodies = game.bodies
    let next = game.nextBodyID
    #expect(throws: NativeMissionProjectileAdmissionError.refused(.populationLimit)) {
      try actualEmissionPlan(game, sourceID: sourceID)
    }
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == next)
  }
}
