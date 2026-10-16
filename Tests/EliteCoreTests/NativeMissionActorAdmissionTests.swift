import Foundation
import Testing

@testable import EliteCore

private func unloadedAdmissionGame() throws -> (Game, UUID, [SpaceBody]) {
  var (game, instance, _) = try actualMissionBridgeGame()
  game.ensurePhysicalActors()
  for index in game.bodies.indices where game.bodies[index].missionInstanceID == instance {
    game.bodies[index].energy -= 7
    game.bodies[index].missiles = max(0, game.bodies[index].missiles - 1)
    game.bodies[index].scriptNPC?.velocity = .init(13, -7, 31)
    game.bodies[index].scriptNPC?.guns["forward"]?.cooldown = 0.07
    if let alias = game.bodies[index].scriptNPC?.components.keys.sorted().first {
      game.bodies[index].scriptNPC?.components[alias]?.energy -= 2
    }
  }
  let prior = game.bodies.filter { $0.missionInstanceID == instance }
  #expect(prior.count == 2)
  game.persistScriptActors(unloading: true)
  game.bodies.removeAll { $0.missionInstanceID == instance }
  return (game, instance, prior)
}

private func readyAdmission(_ preparation: NativeMissionActorAdmissionPreparation) throws
  -> NativeMissionActorAdmissionPlan
{
  guard case .ready(let plan) = preparation else {
    Issue.record("Expected ready whole-cohort admission")
    throw NativeMissionActorAdmissionError.invalidScene
  }
  return plan
}

private func publishAdmission(
  _ plan: NativeMissionActorAdmissionPlan, game: inout Game,
  instance: UUID
) throws -> NativeMissionActorAdmissionReceipt {
  let current = try #require(game.commander.scriptState.instances[instance])
  let staged = try plan.retentionPatch.preparingInstance(current)
  let receipt = try game.commitMissionActorAdmission(plan)
  game.commander.scriptState.instances[instance] = staged
  return receipt
}

struct NativeMissionActorAdmissionTests {
  @Test func retainedWholeCohortPreservesConditionAndAllocatesFreshAddressesOnce() throws {
    var (game, instance, prior) = try unloadedAdmissionGame()
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.instanceID == instance })
    let before = game
    let preparation = try game.prepareMissionActorAdmission(source)
    let plan = try readyAdmission(preparation)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    let receipt = try publishAdmission(plan, game: &game, instance: instance)
    let restored = game.bodies.filter { $0.missionInstanceID == instance }
    #expect(restored.count == 2 && receipt.nativeActors.count == 2)
    #expect(
      game.commander.flightSimulation.nextActor == before.commander.flightSimulation.nextActor + 2)
    #expect(
      game.commander.flightSimulation.nextSpawn == before.commander.flightSimulation.nextSpawn + 1)
    #expect(game.nextBodyID == before.nextBodyID + 2)
    #expect(Set(restored.compactMap { $0.physical?.spawnIdentity?.sequence }).count == 1)
    #expect(Set(restored.compactMap { $0.physical?.spawnIdentity?.member }) == Set([UInt16(0), 1]))
    for body in restored {
      let original = try #require(prior.first { $0.missionActorID == body.missionActorID })
      #expect(body.id != original.id && body.physical?.identity != original.physical?.identity)
      #expect(body.energy == original.energy && body.missiles == original.missiles)
      #expect(body.scriptNPC?.components == original.scriptNPC?.components)
      #expect(body.scriptNPC?.guns == original.scriptNPC?.guns)
      #expect(body.scriptNPC?.fuel == original.scriptNPC?.fuel)
      #expect(receipt.sceneBodyIDs[body.missionActorID!] == body.id)
      #expect(receipt.nativeActors[body.missionActorID!] == body.physical?.identity)
    }
    let committed = game
    let repeatedSources = try game.retainedMissionActorAdmissionSources()
    let repeatedSource = try #require(repeatedSources.first { $0.instanceID == instance })
    let repeated = try game.prepareMissionActorAdmission(repeatedSource)
    guard case .unchanged = repeated else {
      Issue.record("An already present whole cohort must be unchanged")
      return
    }
    #expect(
      game.commander == committed.commander && game.bodies == committed.bodies
        && game.nextBodyID == committed.nextBodyID)
  }

  @Test func native128CapacityRefusesWholeCohortWithoutAllocatingThenRecovers() throws {
    var (game, instance, _) = try unloadedAdmissionGame()
    let additional = 127 - game.bodies.count
    #expect(additional > 0)
    game.ensurePhysicalActors()
    let allocatedSpawn = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSpawn)
    let context = try #require(game.gameplayContext())
    let requests = (0..<additional).map { index -> SpawnRequest in
      let position = Vector3(
        10000 + Double(index % 9) * 400,
        10000 + Double(index / 9) * 400, 10000)
      var request = SpawnRequest(
        identity: .init(
          system: context.system, visit: context.visit,
          sequence: sequence, member: UInt16(index), producer: .mission),
        population: .mission, hull: .cobra,
        position: game.commander.flightSimulation.pose.systemPoint(position),
        orientation: .init(), velocity: .init(0, 0, 0),
        npc: .init(role: .mission, origin: context.system, destination: context.system),
        rock: nil, payload: nil, priority: .mission)
      request.energy = 100
      return request
    }
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: requests, atomic: true)], intents: [])
    )
    #expect(
      receipts.count == additional && receipts.allSatisfy { $0.actor != nil && $0.refusal == nil })
    #expect(game.bodies.count == 127)
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.instanceID == instance })
    let before = game
    let refused = try game.prepareMissionActorAdmission(source)
    guard case .pending(.native(.reservedCapacity)) = refused else {
      Issue.record("127 actual bodies plus two-root cohort must refuse native total128")
      return
    }
    #expect(
      game.commander == before.commander && game.bodies == before.bodies
        && game.nextBodyID == before.nextBodyID)
    game.bodies.removeLast()
    #expect(game.bodies.count == 126)
    let recoverySources = try game.retainedMissionActorAdmissionSources()
    let recoverySource = try #require(recoverySources.first { $0.instanceID == instance })
    let recovery = try game.prepareMissionActorAdmission(recoverySource)
    let plan = try readyAdmission(recovery)
    _ = try publishAdmission(plan, game: &game, instance: instance)
    #expect(game.bodies.count == 128)
    #expect(game.bodies.filter { $0.missionInstanceID == instance }.count == 2)
  }

  @Test func malformedLaterRetainedActorHardFailsBeforeAnyRestoration() throws {
    var (game, instance, _) = try unloadedAdmissionGame()
    let aliases = try #require(
      game.commander.scriptState.instances[instance]?
        .ownedEncounters["opponents"]?.actors.keys.sorted())
    let last = try #require(aliases.last)
    game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?
      .actors[last]?.body.energy = 1_000_001
    let before = game
    var refused = false
    do { _ = try game.retainedMissionActorAdmissionSources() } catch { refused = true }
    #expect(refused)
    #expect(
      game.commander == before.commander && game.bodies == before.bodies
        && game.nextBodyID == before.nextBodyID)
    #expect(!game.bodies.contains { $0.missionInstanceID == instance })
  }

  @Test func retainedProfileVelocityTransformsExactlyOnceThroughActualRotatedAnchor() throws {
    var (game, instance, _) = try unloadedAdmissionGame()
    let stationIndex = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
    game.bodies[stationIndex].orientation.rotate(pitch: 0.1, roll: 0.2, yaw: 0.3)
    let anchor = try #require(game.scriptAnchor)
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.instanceID == instance })
    let preparation = try game.prepareMissionActorAdmission(source)
    let plan = try readyAdmission(preparation)
    _ = try publishAdmission(plan, game: &game, instance: instance)
    for template in source.actors {
      let body = try #require(game.bodies.first { $0.missionActorID == template.actorID })
      let canonical = try #require(template.canonicalBody.scriptNPC?.velocity)
      let expectedView = anchor.orientation.apply(canonical)
      #expect(body.scriptNPC?.velocity == expectedView)
      let expectedWorld = game.commander.flightSimulation.pose.orientation.apply(expectedView)
      #expect(body.physical?.velocity == expectedWorld)
      #expect(
        body.position == anchor.position + anchor.orientation.apply(template.canonicalBody.position)
      )
    }
  }
  @Test func actualNewVisitPreservesNavigationAndRebindsOnlyPermittedNativeTargets() throws {
    for scenario in 0..<4 {
      var (game, instance, prior) = try unloadedAdmissionGame()
      let oldPlayer = try #require(game.commander.flightSimulation.player)
      let aliases = try #require(
        game.commander.scriptState.instances[instance]?
          .ownedEncounters["opponents"]?.actors.keys.sorted())
      let alias = try #require(aliases.first)
      let saved = try #require(
        game.commander.scriptState.instances[instance]?
          .ownedEncounters["opponents"]?.actors[alias])
      let destination = Vector3(1234, 2345, 3456)
      let action: NPCAction =
        scenario == 1
        ? .flee(oldPlayer)
        : scenario == 2
          ? .engage(oldPlayer)
          : .navigate(position: destination, speedUnitsPerSecond: 5)
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?
        .actors[alias]?.body.physical?.npc?.intention = action
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?
        .actors[alias]?.body.physical?.npc?.firstAggressor = oldPlayer
      game.launch()
      let currentPlayer = try #require(game.commander.flightSimulation.player)
      #expect(currentPlayer != oldPlayer)
      if scenario == 3 {
        game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?
          .actors[alias]?.body.physical?.npc?.firstAggressor = currentPlayer
      }
      let sources = try game.retainedMissionActorAdmissionSources()
      let source = try #require(sources.first { $0.instanceID == instance })
      let template = try #require(source.actors.first { $0.alias == alias })
      #expect(template.declaredHostile)
      let prepared = try game.prepareMissionActorAdmission(source)
      let plan = try readyAdmission(prepared)
      _ = try publishAdmission(plan, game: &game, instance: instance)
      let restored = try #require(game.bodies.first { $0.missionActorID == saved.identity })
      #expect(!prior.contains { $0.physical?.identity == restored.physical?.identity })
      let condition = try #require(restored.physical?.npc)
      if scenario == 1 {
        #expect(condition.intention == nil)
      } else if scenario == 2 {
        #expect(condition.intention == .engage(currentPlayer))
      } else {
        #expect(condition.intention == .navigate(position: destination, speedUnitsPerSecond: 5))
      }
      #expect(condition.firstAggressor == (scenario == 3 ? currentPlayer : nil))
    }
  }

  @Test func malformedRetainedNavigationRefusesBeforeAnyTemporaryAdmissionOutcome() throws {
    for scenario in 0..<3 {
      var (game, instance, _) = try unloadedAdmissionGame()
      let aliases = try #require(
        game.commander.scriptState.instances[instance]?
          .ownedEncounters["opponents"]?.actors.keys.sorted())
      let alias = try #require(aliases.last)
      let actor = try #require(
        game.commander.scriptState.instances[instance]?
          .ownedEncounters["opponents"]?.actors[alias])
      let maximum = try #require(actor.body.scriptNPC?.fit.definition.speed)
      let position = scenario == 0 ? Vector3(.infinity, 0, 0) : Vector3(1234, 2345, 3456)
      let speed = scenario == 1 ? -1 : scenario == 2 ? maximum + 1 : 5
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?
        .actors[alias]?.body.physical?.npc?.intention = .navigate(
          position: position, speedUnitsPerSecond: speed)
      let before = game
      var refused = false
      do {
        let sources = try game.retainedMissionActorAdmissionSources()
        let source = try #require(sources.first { $0.instanceID == instance })
        _ = try game.prepareMissionActorAdmission(source)
      } catch { refused = true }
      #expect(refused)
      #expect(
        game.commander == before.commander && game.bodies == before.bodies
          && game.nextBodyID == before.nextBodyID)
    }
  }

  @Test func unboundLiveObstacleRefusesBeforeCapacityOrAlreadyPresentNoop() throws {
    var (game, instance, _) = try unloadedAdmissionGame()
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.instanceID == instance })
    let template = try #require(source.actors.first)
    let anchor = try #require(game.scriptAnchor)
    let bodyID = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(
      .init(
        id: bodyID, hull: .cargo,
        position: anchor.position + anchor.orientation.apply(template.canonicalBody.position)))
    let before = game
    var exactRefusal = false
    do {
      _ = try game.prepareMissionActorAdmission(source)
      Issue.record(
        "A live obstacle without native binding must not disappear from admission context")
    } catch let error as NativeMissionActorAdmissionError {
      exactRefusal = error == .invalidScene
    } catch { Issue.record("Expected invalidScene, received \(error)") }
    #expect(exactRefusal)
    #expect(
      game.commander == before.commander && game.bodies == before.bodies
        && game.nextBodyID == before.nextBodyID)
    var (present, presentInstance, _) = try actualMissionBridgeGame()
    present.ensurePhysicalActors()
    let presentSources = try present.retainedMissionActorAdmissionSources()
    let presentSource = try #require(presentSources.first { $0.instanceID == presentInstance })
    let ordinaryIndex = try #require(
      present.bodies.firstIndex { $0.missionActorID == nil && $0.id != 0 })
    present.bodies[ordinaryIndex].physical = nil
    let presentBefore = present
    var noopRefused = false
    do {
      _ = try present.prepareMissionActorAdmission(presentSource)
      Issue.record("Unbound live scene state must be checked before already-present no-op")
    } catch let error as NativeMissionActorAdmissionError {
      noopRefused = error == .invalidScene
    } catch { Issue.record("Expected invalidScene, received \(error)") }
    #expect(noopRefused)
    #expect(
      present.commander == presentBefore.commander && present.bodies == presentBefore.bodies
        && present.nextBodyID == presentBefore.nextBodyID)
  }

}
