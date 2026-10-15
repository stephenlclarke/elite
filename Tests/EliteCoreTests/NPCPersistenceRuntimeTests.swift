import Foundation
import Testing

@testable import EliteCore

private func persistedNPCGame() throws -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
  let allocated = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocated)
  var npc = NPCState(
    role: .trader, origin: game.systemIdentity, destination: .init(galaxy: 1, system: 0))
  npc.resources = NPCResources.stock(game.commander.performance)
  npc.resources?.fuel = 23
  npc.resources?.frontShield = 12
  npc.resources?.rearShield = 15
  npc.resources?.laserHeat = 37
  npc.ordinaryCargo = [.init(commodity: .gold, quantity: 4)]
  npc.cargoProvenance = .recorded
  npc.routeProvenance = .generated
  npc.legalProvenance = .recorded
  npc.legal = .init(value: 16, bountyTenths: 50)
  npc.hasFuelScoops = false
  npc.firstAggressor = game.commander.flightSimulation.player
  npc.intention = .engage(try #require(game.commander.flightSimulation.player))
  var body = SpaceBody(id: 40, hull: .cobra, position: .init(0, 0, 2000))
  body.energy = 73
  body.missiles = 1
  body.ecmEnabled = true
  let spawn = SpawnIdentity(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit, sequence: 1,
    member: 0)
  body.physical = .init(
    identity: actor, population: .civilian, npc: npc, velocity: .init(0, 0, 10),
    laserCooldown: 0.19, spawnIdentity: spawn)
  game.bodies = [body]
  return game
}

struct NPCPersistenceRuntimeTests {
  @Test func realSaveReloadAndLaunchRetainSpentStateAndRebindSceneReferences() async throws {
    let game = try persistedNPCGame()
    let source = try #require(game.bodies[0].physical?.identity)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    try await runtime.load(from: url)
    await runtime.key("0")
    let loaded = await runtime.snapshot()
    let rebound = try #require(loaded.commander.npcPersistence.binding(for: source))
    let body = try #require(loaded.bodies.first { $0.physical?.identity == rebound })
    #expect(rebound != source && rebound.visit == loaded.commander.flightSimulation.visit)
    #expect(body.energy == 73 && body.missiles == 1 && body.ecmEnabled)
    #expect(body.physical?.laserCooldown == 0.19)
    #expect(body.physical?.npc?.resources == game.bodies[0].physical?.npc?.resources)
    #expect(body.physical?.npc?.ordinaryCargo == game.bodies[0].physical?.npc?.ordinaryCargo)
    #expect(body.physical?.npc?.routeProvenance == .generated)
    #expect(body.physical?.npc?.legal == game.bodies[0].physical?.npc?.legal)
    #expect(body.physical?.npc?.firstAggressor == loaded.commander.flightSimulation.player)
    #expect(
      body.physical?.npc?.intention
        == .engage(try #require(loaded.commander.flightSimulation.player)))
    #expect(loaded.bodies.filter { $0.physical?.npc?.role == .trader }.count == 1)
  }

  @Test func actualCullKeepsCoastingStateWithoutReAdmissionUntilPlayerReturns() throws {
    var game = try persistedNPCGame()
    game.bodies[0].physical?.npc?.firstAggressor = nil
    game.bodies[0].physical?.npc?.intention = .navigate(
      position: .init(0, 0, 100000), speedUnitsPerSecond: 100)
    game.bodies[0].position.z = 45000
    let source = try #require(game.bodies[0].physical?.identity)
    game.tick(delta: 0.001)
    #expect(game.bodies.isEmpty)
    #expect(game.commander.npcPersistence.binding(for: source) == nil)
    let culled = try #require(game.commander.npcPersistence.snapshot(for: source))
    let allocator = game.commander.flightSimulation.nextActor
    game.tick(delta: 0.1)
    game.tick(delta: 0.1)
    #expect(game.bodies.isEmpty && game.commander.flightSimulation.nextActor == allocator)
    let coasted = try #require(game.commander.npcPersistence.snapshot(for: source))
    #expect(coasted.position.z > culled.position.z)
    #expect(coasted.npc.resources?.laserHeat ?? 0 < culled.npc.resources?.laserHeat ?? 0)
    #expect(coasted.npc.resources?.fuel == culled.npc.resources?.fuel)
    game.commander.flightSimulation.pose.position = coasted.position - .init(0, 0, 1000)
    game.admitPersistentNPCs()
    let actor = try #require(game.commander.npcPersistence.binding(for: source))
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(body.energy == coasted.energy && body.physical?.npc?.resources == coasted.npc.resources)
    #expect(body.missiles == 1 && actor != source)
    game.admitPersistentNPCs()
    #expect(game.bodies.count == 1 && game.commander.npcPersistence.binding(for: source) == actor)
  }

  @Test func actualDestroyedNPCSettlesCargoThenCannotReturnAsFreshStock() throws {
    var game = try persistedNPCGame()
    let source = try #require(game.bodies[0].physical?.identity)
    #expect(game.persistNPCStates().isEmpty)
    game.bodies[0].energy = 0
    game.resolveDestroyed()
    game.admitPersistentNPCs()
    #expect(game.bodies.isEmpty && game.commander.npcPersistence.livingCount == 0)
    #expect(game.commander.npcPersistence.count == 1)
    #expect(
      game.commander.cargoDebrisLedger.pendingPayloads.map(\.amount) == [
        .init(commodity: .gold, quantity: 4)
      ])
    #expect(game.commander.npcPersistence.binding(for: source) == nil)
  }

  @Test func failedSaveCannotPublishNPCBindingsOrConsumeARecord() async throws {
    let game = try persistedNPCGame()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let runtime = GameRuntime(game: game)
    var failed = false
    do { try await runtime.save(to: directory) } catch { failed = true }
    #expect(failed)
    let after = await runtime.snapshot()
    #expect(after.commander == game.commander && after.bodies == game.bodies)
    try await runtime.save(to: directory.appendingPathComponent("commander.json"))
    #expect(await runtime.snapshot().commander.npcPersistence.count == 1)
  }
}
