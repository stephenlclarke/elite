import Foundation
import Testing

@testable import EliteCore

private func frameSaveFolder() throws -> URL {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "native-mission-frame-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  return folder
}

struct NativeMissionRuntimeFrameTests {
  @Test func actualRuntimeFrameFiresEachAuthoredGunAndMovesItsNewProjectileExactlyOnce()
    async throws
  {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    game.speed = 0
    for i in game.bodies.indices where game.bodies[i].scriptNPC != nil {
      game.bodies[i].scriptNPC?.intent = nil
      game.bodies[i].scriptNPC?.velocity = .init(0, 0, 0)
    }
    game.bodies[index].orientation = .init(
      x: .init(-1, 0, 0), y: .init(0, 1, 0), z: .init(0, 0, -1))
    game.bodies[index].scriptNPC?.intent = .init(
      request: "runtime-fire", mode: .attack, target: nil, player: true,
      offset: .init(0, 0, 0), speed: 0, tolerance: 1)
    let identity = try #require(game.bodies[index].missionActorID)
    let priorShots = try #require(game.bodies[index].scriptNPC?.shots)
    let folder = try frameSaveFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let runtime = GameRuntime(game: game, saveURL: folder.appendingPathComponent("commander.json"))
    await runtime.setControls(.init())
    let frame = await runtime.advance(delta: 0.1)
    let source = try #require(frame.bodies.first { $0.missionActorID == identity })
    let npc = try #require(source.scriptNPC)
    #expect(npc.shots == priorShots + 2)
    #expect(frame.commander.scriptState.instances[instance]?.suspension == nil)
    let projectiles = frame.bodies.filter { $0.scriptShot?.owner == identity }
    try #require(projectiles.count == 1)
    let body = projectiles[0]
    let shot = try #require(body.scriptShot)
    #expect(abs(shot.age - 0.1) < 1e-9)
    #expect(shot.nativeAttribution?.sourceActorID == identity)
    #expect(shot.nativeAttribution?.instanceID == instance)
    #expect(
      frame.commander.scriptState.projectiles[shot.identity]?.body.scriptShot?.age == shot.age)
    let component = try #require(npc.fit.definition.components?.first)
    let weapon = try #require(component.weapons?.first)
    let pose = component.orientation.transformed(by: source.orientation)
    let muzzle =
      source.position + source.orientation.apply(component.position * npc.fit.definition.scale)
      + pose.apply(weapon.muzzle * (component.scale * npc.fit.definition.scale))
    #expect((body.position - (muzzle + shot.velocity * 0.1)).length < 1e-6)
    #expect(shot.damage == weapon.damage && shot.lifetime == weapon.lifetime)
    #expect(shot.radius == weapon.collisionRadius && shot.collisionDelay == weapon.collisionDelay)
  }

  @Test func actualRuntimeGivesANativelyAdmittedProfileOneMovementOwnerAndCurrentWorldVelocity()
    async throws
  {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    game.speed = 0
    var source = game.bodies[index]
    source.scriptNPC?.intent = nil
    source.scriptNPC?.velocity = .init(40, 0, 0)
    let owner = try #require(source.missionActorID)
    game.bodies.removeAll { $0.id == source.id }
    let context = try #require(game.gameplayContext())
    let allocated = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocated)
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .mission),
      population: .mission, hull: source.hull,
      position: game.commander.flightSimulation.pose.systemPoint(source.position),
      orientation: game.commander.flightSimulation.pose.orientation.composed(
        with: source.orientation),
      velocity: game.commander.flightSimulation.pose.orientation.apply(.init(40, 0, 0)),
      npc: source.physical?.npc, rock: nil, payload: nil, priority: .mission, energy: source.energy)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: true)], intents: []))
    let admission = try #require(receipts.first?.actor)
    let admittedIndex = try #require(game.bodies.firstIndex { $0.physical?.identity == admission })
    source.id = game.bodies[admittedIndex].id
    source.physical = game.bodies[admittedIndex].physical
    game.bodies[admittedIndex] = source
    game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?
      .actors["lead"]?.body.id = source.id
    let before = game.commander.flightSimulation.pose.systemPoint(source.position)
    let folder = try frameSaveFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let runtime = GameRuntime(game: game, saveURL: folder.appendingPathComponent("commander.json"))
    await runtime.setControls(.init())
    let frame = await runtime.advance(delta: 0.1)
    let actual = try #require(frame.bodies.first { $0.missionActorID == owner })
    let velocity = try #require(actual.scriptNPC?.velocity)
    let world = frame.commander.flightSimulation.pose.orientation.apply(velocity)
    let after = frame.commander.flightSimulation.pose.systemPoint(actual.position)
    let physical = try #require(actual.physical)
    #expect(physical.identity == admission && physical.spawnIdentity == request.identity)
    #expect((after - before - world * 0.1).length < 1e-6)
    #expect((physical.velocity - world).length < 1e-6)
    #expect(abs(velocity.x - 35) < 1e-6)
  }
}
