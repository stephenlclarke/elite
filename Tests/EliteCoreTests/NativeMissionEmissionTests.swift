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
  @Test func independentNativeProducerCountersPermitActualMissionPlasmaAdmission() throws {
    var (game, _, index) = try actualMissionBridgeGame()
    let sourceID = game.bodies[index].id
    _ = try admitProducerLocalMissionSceneSpawns(&game)
    let before = game.commander
    let bodies = game.bodies
    let cursor = game.nextBodyID
    let plan = try actualEmissionPlan(game, sourceID: sourceID)
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == cursor)
    let receipt = try game.commitMissionProjectileAdmission(plan)
    let emitted = try #require(game.bodies.first { $0.id == receipt.bodyID })
    #expect(emitted.physical?.spawnIdentity?.producer == .ordnance)
    #expect(emitted.physical?.spawnIdentity?.sequence == before.flightSimulation.nextSpawn)
    #expect(game.commander.flightSimulation.nextSpawn == before.flightSimulation.nextSpawn + 1)
    #expect(
      game.commander.scriptState.projectiles[plan.shotID]?.body.scriptShot?.nativeAttribution
        == plan.archive)
  }

  @Test(arguments: NativeMissionSpawnForgery.allCases)
  func invalidSharedOrForeignSpawnAddressesRefuseMissionEmissionWithoutAllocation(
    forgery: NativeMissionSpawnForgery
  ) throws {
    var (game, _, index) = try actualMissionBridgeGame()
    let sourceID = game.bodies[index].id
    let spawns = try admitProducerLocalMissionSceneSpawns(&game)
    try forgeProducerLocalMissionSceneSpawn(&game, spawns: spawns, forgery: forgery)
    let before = game.commander
    let bodies = game.bodies
    let cursor = game.nextBodyID
    var refused = false
    do { _ = try actualEmissionPlan(game, sourceID: sourceID) } catch let error
      as NativeMissionProjectileAdmissionError
    {
      refused = error == .allocatorExhausted
    } catch { Issue.record(error) }
    #expect(refused)
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == cursor)
  }

  @Test func actualPreparationHasNoEffectsAndCommitPublishesOneNativeBodyAndCanonicalRecord() throws
  {
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
    #expect(
      game.commander.flightSimulation.nextEmission == before.flightSimulation.nextEmission + 1)
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
    try verifyProjectilePopulationLimit(&game, sourceIndex: index)
  }

  // Construct the actual fixture before reserving the independent verification snapshots.
  private func verifyProjectilePopulationLimit(_ game: inout Game, sourceIndex: Int) throws {
    game.ensurePhysicalActors()
    let sourceID = game.bodies[sourceIndex].id
    let allocated = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocated)
    let context = try #require(game.gameplayContext())
    func projectileRequests(spacing: Double) -> [SpawnRequest] {
      (0..<PopulationClass.projectile.maximum).map { member in
        SpawnRequest(
          identity: .init(
            system: context.system, visit: context.visit, sequence: sequence,
            member: UInt16(member), producer: .ordnance),
          population: .projectile, hull: .missile,
          position: context.player.position + .init(10_000, Double(member) * spacing, 10_000),
          orientation: .init(), velocity: .init(0, 0, 0),
          npc: nil, rock: nil, payload: nil, priority: .mission)
      }
    }
    let overlap = projectileRequests(spacing: 20)
    let beforeOverlap = game.commander
    let bodiesBeforeOverlap = game.bodies
    let cursorBeforeOverlap = game.nextBodyID
    let overlapReceipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: overlap, atomic: true)], intents: []))
    let overlapRefusals = overlapReceipts.map { String(describing: $0.refusal) }.joined(
      separator: "; ")
    try #require(
      overlapReceipts.count == overlap.count
        && overlapReceipts.allSatisfy { $0.actor == nil && $0.refusal == .unsafePosition },
      Comment(rawValue: overlapRefusals))
    #expect(
      game.commander == beforeOverlap && game.bodies == bodiesBeforeOverlap
        && game.nextBodyID == cursorBeforeOverlap)
    let radius = try #require(Mesh.hull(.missile).vertices.map(\.length).max())
    try #require(radius.isFinite && radius > 0)
    // Leave clearance between actual mesh bounds before testing the population limit.
    let requests = projectileRequests(spacing: 2 * radius + 16)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: true)], intents: []))
    let refusals = receipts.map { String(describing: $0.refusal) }.joined(separator: "; ")
    try #require(
      receipts.count == requests.count
        && receipts.allSatisfy { $0.actor != nil && $0.refusal == nil },
      Comment(rawValue: refusals))
    #expect(
      game.bodies.filter { $0.physical?.population == .projectile }.count
        == PopulationClass.projectile.maximum)
    let before = game.commander
    let bodies = game.bodies
    let next = game.nextBodyID
    #expect(throws: NativeMissionProjectileAdmissionError.refused(.populationLimit)) {
      try actualEmissionPlan(game, sourceID: sourceID)
    }
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == next)
  }
}
