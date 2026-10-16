import Foundation
import Testing

@testable import EliteCore

private func workRuntimeGame(module: WorkTargetSpecialty = .salvage, scoops: Bool = true) throws
  -> Game
{
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    "Targeting: Military", at: .targetingCore, provenance: .grant("work fixture"))
  try game.commander.grantEquipment(
    "Targeting: " + (module == .mining ? "Mining" : "Salvage") + " Module",
    at: module == .mining ? .targetingMining : .targetingSalvage, provenance: .grant("work fixture")
  )
  if scoops {
    try game.commander.grantEquipment(
      "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("work fixture"))
  }
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  game.miningFields = []
  game.salvageSites = []
  game.commander.npcPersistence = .init()
  return game
}

private func addWorkCargo(_ game: inout Game, position: Vector3, velocity: Vector3 = .init(0, 0, 0))
  throws -> ActorIdentity
{
  let allocated = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocated)
  var body = SpaceBody(id: 88, hull: .cargo, position: position)
  body.rotationRate = 0
  body.physical = .init(
    identity: actor, population: .cargo, velocity: velocity,
    spawnIdentity: .init(
      system: actor.system, visit: actor.visit, sequence: 88, member: 0, producer: .cargo),
    canonicalSpin: true)
  game.bodies = [body]
  return actor
}

private func engageWorkCargo(_ game: inout Game) {
  game.workTargetFilter = .salvage
  game.key("r")
}

struct FlightWorkGuidanceRuntimeTests {
  @Test func filterKeyUsesActualFittedModulesAndKeepsOriginalShipDefault() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 500))
    #expect(game.workTargetFilter == .ships)
    game.key("r")
    #expect(game.autoPilot.targetID == nil)
    game.key("f")
    #expect(game.workTargetFilter == .mining)
    game.key("r")
    #expect(game.autoPilot.targetID == nil)
    game.key("f")
    #expect(game.workTargetFilter == .salvage)
    game.key("r")
    #expect(game.workGuidance?.mode == .autoScoop(.salvage))
    game.key("f")
    #expect(game.workTargetFilter == .all && game.workGuidance == nil)
    game.key("f")
    #expect(game.workTargetFilter == .ships)
    let help = PlayerHelp.pages(for: game).flatMap(\.rows).joined(separator: " ")
    #expect(help.contains("F - SHIPS / MINING / SALVAGE / ALL"))
  }

  @Test func approvedActualMeshEndpointIsAppliedOnceWithoutEndVelocityEuler() throws {
    var game = try workRuntimeGame()
    let actor = try addWorkCargo(&game, position: .init(0, -45, 500))
    engageWorkCargo(&game)
    #expect(game.workGuidance?.parent == actor)
    let start = game.commander.flightSimulation.pose
    game.advanceWorkGuidance(delta: 0.1)
    let motion = try #require(game.approvedWorkMotion)
    let beforeCargo = game.modelPose(of: game.bodies[0])
    #expect(motion.start == start && motion.acceleration.length > 0)
    let moved = game.moveWorkFrame(delta: 0.1)
    #expect(moved)
    #expect(game.commander.flightSimulation.pose == motion.end)
    #expect(game.approvedWorkMotion == nil && game.lastAppliedWorkMotion == motion)
    #expect(
      (game.flightWorldVelocity - motion.initialVelocity - motion.acceleration * 0.1).length < 1e-9)
    #expect((game.modelPose(of: game.bodies[0]).position - beforeCargo.position).length < 1e-8)
    let correct = start.position + motion.initialVelocity * 0.1 + motion.acceleration * 0.005
    #expect((motion.end.position - correct).length < 1e-9)
    #expect((motion.end.position - start.position - game.flightWorldVelocity * 0.1).length > 1e-4)
  }

  @Test func realTickCollectsOneCargoAndBrakesAgainstCurrentSceneWithoutGhostPrimary() throws {
    var game = try workRuntimeGame()
    let collectedActor = try addWorkCargo(
      &game, position: .init(0, -45, 55), velocity: .init(0, 0, 10))
    engageWorkCargo(&game)
    game.workGuidance?.velocity = .init(0, 0, 10)
    let before = game.commander.cargo[0]
    game.tick(delta: 0.02)
    #expect(game.commander.cargo[0] == before + 1)
    #expect(!game.bodies.contains { $0.id == 88 })
    #expect(game.workGuidance == nil && game.workBraking != nil)
    #expect(game.autoPilot.targetID == nil && game.weaponsTargetID == nil)
    #expect(game.message.hasPrefix("SCOOPED"))
    let velocity = game.flightWorldVelocity
    game.advanceWorkGuidance(delta: 0.02)
    let brake = try #require(game.approvedWorkMotion)
    #expect(brake.initialVelocity == velocity && brake.acceleration.dot(velocity) < 0)
    let snapshot = game.workObstacles(excluding: nil, delta: 0.02)
    let current = try #require(snapshot)
    #expect(!current.contains { $0.identity == collectedActor })
    let moved = game.moveWorkFrame(delta: 0.02)
    #expect(moved)
    #expect(game.flightWorldVelocity.length < velocity.length)
    game.scoopCargo()
    #expect(game.commander.cargo[0] == before + 1)
  }

  @Test func otherPodStillBlocksPostCaptureBrakingAndReceivesNoThrust() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 55))
    engageWorkCargo(&game)
    game.workGuidance?.velocity = .init(0, 0, 25)
    let collected = game.bodies[0]
    game.workTargetCollected(collected)
    game.bodies = []
    let allocated = game.commander.flightSimulation.allocateActor()
    let other = try #require(allocated)
    var obstruction = SpaceBody(id: 89, hull: .cargo, position: .init(0, 0, 0))
    obstruction.rotationRate = 0
    obstruction.physical = .init(identity: other, population: .cargo, canonicalSpin: true)
    game.bodies = [obstruction]
    let energy = game.energy
    game.advanceWorkGuidance(delta: 0.1)
    #expect(game.approvedWorkMotion == nil && game.energy == energy)
    let snapshot = game.workObstacles(excluding: nil, delta: 0.1)
    let obstacles = try #require(snapshot)
    #expect(obstacles.count == 1 && obstacles[0].identity == other)
    _ = game.moveWorkFrame(delta: 0.1)
    #expect(game.flightWorldVelocity == .init(0, 0, 25))
  }

  @Test func actualApertureOverspeedRefusesCollectionAndKeepsTheTarget() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 55))
    engageWorkCargo(&game)
    game.workGuidance?.velocity = .init(0, 0, 100)
    let cargo = game.commander.cargo
    game.scoopCargo()
    #expect(game.commander.cargo == cargo && game.bodies.count == 1)
    #expect(game.workGuidance != nil)
  }

  @Test func manualAndDamageInterruptionsPreserveActualMomentumAndSuppressHeldTool() throws {
    for damage in [false, true] {
      var game = try workRuntimeGame()
      _ = try addWorkCargo(&game, position: .init(0, -45, 500))
      engageWorkCargo(&game)
      let velocity = Vector3(20, -10, 50)
      game.workGuidance?.velocity = velocity
      if damage {
        game.applyDamage(1, front: true)
        #expect(game.workFireSuspended)
      } else {
        game.key("q")
      }
      #expect(game.workGuidance == nil && game.autoPilot.targetID == nil)
      #expect((game.flightWorldVelocity - velocity).length < 1e-9)
      let before = game.commander.flightSimulation.pose.position
      game.tick(delta: 0.02)
      #expect(
        (game.commander.flightSimulation.pose.position - before - velocity * 0.02).length < 1e-8)
      #expect(!game.workFireSuspended)
    }
  }

  @Test func displayIDReuseNeverFollowsANewPhysicalActor() throws {
    var game = try workRuntimeGame()
    let original = try addWorkCargo(&game, position: .init(0, -45, 500))
    engageWorkCargo(&game)
    let replacement = try addWorkCargo(&game, position: .init(0, -45, 500))
    #expect(original != replacement && game.autoTargetBody == nil)
    game.advanceWorkGuidance(delta: 0.02)
    #expect(game.workGuidance == nil && game.approvedWorkMotion == nil)
    #expect(game.message == "WORK TARGET UNAVAILABLE")
  }

  @Test func actualLegacyAIIsPlannedOnceBeforeTheProofAndNotMovedAgain() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 1000))
    engageWorkCargo(&game)
    var enemy = SpaceBody(id: 99, hull: .sidewinder, position: .init(3000, 2000, 3000))
    enemy.hostile = true
    game.bodies.append(enemy)
    game.ensurePhysicalActors()
    let before = game.modelPose(of: game.bodies[1]).position
    game.planWorkScene(delta: 0.1)
    let planned = try #require(game.plannedLegacyWorkMotion[99])
    let afterPlanning = game.modelPose(of: game.bodies[1]).position
    #expect((afterPlanning - before - planned.velocity * 0.1).length < 1e-8)
    game.advanceWorkGuidance(delta: 0.1)
    _ = game.moveWorkFrame(delta: 0.1)
    let after = game.modelPose(of: game.bodies[1]).position
    #expect((after - afterPlanning).length < 1e-8)
    #expect(game.workScenePlanned)
  }

  @Test func miningAndSalvageNeverInheritEachOthersFittedModule() throws {
    var game = try workRuntimeGame(module: .mining)
    _ = try addWorkCargo(&game, position: .init(0, -45, 500))
    game.workTargetFilter = .all
    game.key("r")
    #expect(game.workGuidance == nil && game.autoPilot.targetID == nil)
    let context = try #require(game.gameplayContext())
    let candidate = try #require(
      game.workTargetCandidate(for: game.bodies[0], context: context, frontVisible: true))
    #expect(
      WorkTargetSelection.evaluate(
        candidate, system: context.system, visit: context.visit,
        capabilities: game.workTargetCapabilities) == .refused(.missingModule(.salvage)))
    #expect(game.workTargetCapabilities.core == .military)
  }

  @Test func canonicalizingVisibleLegacySpinDoesNotMoveAnyMeshVertex() throws {
    var game = try workRuntimeGame()
    let actor = try addWorkCargo(&game, position: .init(40, -55, 800))
    game.bodies[0].physical?.canonicalSpin = nil
    game.bodies[0].rotation = 1.2
    game.bodies[0].rotationRate = -0.3
    game.bodies[0].orientation.rotate(pitch: 0.3, roll: -0.2, yaw: 0.4)
    let mesh = game.gameplayMesh(for: game.bodies[0])
    let before = mesh.vertices.map(game.modelPose(of: game.bodies[0]).systemPoint)
    game.canonicalizeWorkTarget(actor)
    let after = mesh.vertices.map(game.modelPose(of: game.bodies[0]).systemPoint)
    #expect(zip(before, after).allSatisfy { ($0 - $1).length < 1e-8 })
    #expect(game.bodies[0].rotation == 0 && game.bodies[0].rotationRate == 0)
    #expect(game.bodies[0].physical?.canonicalSpin == true)
    #expect((game.bodies[0].physical?.angularVelocity.length ?? 0) > 0)
  }
}
