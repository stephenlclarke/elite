import Foundation
import Testing

@testable import EliteCore

private func moveOreObserver(_ game: inout Game, to position: Vector3) {
  let old = game.commander.flightSimulation.pose
  let translation = old.shipVector(position - old.position)
  game.commander.flightSimulation.pose.position = position
  for index in game.bodies.indices {
    game.bodies[index].position = game.bodies[index].position - translation
  }
  for index in game.celestials.indices {
    game.celestials[index].position = game.celestials[index].position - translation
  }
}

private func actualMinedOreGame() throws -> (Game, TypedCargoPayload, Int) {
  var game = Game(executive: false)
  // Initial fixture hull declares the utility slot used by the real mining tool below.
  game.commander.shipID = "SH023"
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    LaserKind.mining.equipmentName, at: .utility(.miningLaser),
    provenance: .grant("runtime fixture"))
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("runtime fixture"))
  game.launch()
  game.speed = 0
  game.bodies = []
  game.commander.npcPersistence = .init()
  let field = try #require(game.miningFields.first)
  let rock = try #require(field.rocks.first)
  // Isolate one genuine generated rock without changing its identity, native yield or position.
  game.miningFields = [.init(position: field.position, rocks: [rock])]
  moveOreObserver(&game, to: rock.position - .init(0, 0, 500))
  game.activateNearbyMiningFields()
  #expect(game.bodies.contains { $0.physical?.rock == rock.identity })
  game.selectFlightTool(.miningLaser)
  var controls = Controls()
  controls.fire = true
  for _ in 0..<300 {
    game.tick(delta: 0.1, controls: controls)
    if game.commander.miningLedger.isDepleted(rock.identity) { break }
  }
  #expect(game.commander.miningLedger.isDepleted(rock.identity))
  let payload = try #require(
    game.commander.miningLedger.pendingPayloads.first { payload in
      if case .ore(let identity, _) = payload.identity { return identity == rock.identity }
      return false
    })
  let body = try #require(game.bodies.first { $0.physical?.payload == payload.identity })
  #expect(game.commander.miningLedger.boundActor(for: payload.identity) == body.physical?.identity)
  return (game, payload, body.id)
}

struct MiningOreRuntimeTests {
  @Test func actualMovingOreKeepsCanonicalPoseThroughCameraMotionCullAndReentry() throws {
    var (game, payload, bodyID) = try actualMinedOreGame()
    let first = try #require(game.bodies.first { $0.id == bodyID }?.physical?.identity)
    let observer = game.commander.flightSimulation.pose.position
    var controls = Controls()
    controls.pitch = 0.2
    controls.yaw = -0.1
    game.tick(delta: 0.1, controls: controls)
    let moved = try #require(game.bodies.first { $0.id == bodyID })
    let actual = game.commander.flightSimulation.pose.systemPoint(moved.position)
    let recorded = try #require(
      game.commander.miningLedger.pendingPayloads.first { $0.identity == payload.identity })
    #expect(
      (recorded.position - actual).length < 1e-8 && recorded.velocity == moved.physical?.velocity)
    #expect((recorded.position - payload.position).length > 0)
    moveOreObserver(&game, to: observer + .init(50000, 0, 0))
    game.tick(delta: 0.02)
    #expect(!game.bodies.contains { $0.physical?.identity == first })
    let culled = try #require(
      game.commander.miningLedger.pendingPayloads.first { $0.identity == payload.identity })
    moveOreObserver(&game, to: observer)
    game.admitPendingOre()
    let returned = try #require(game.bodies.first { $0.physical?.payload == payload.identity })
    #expect(returned.physical?.identity != first)
    #expect(
      (game.commander.flightSimulation.pose.systemPoint(returned.position) - culled.position).length
        < 1e-8)
    #expect(returned.physical?.velocity == culled.velocity)
    let count = game.bodies.filter { $0.physical?.payload == payload.identity }.count
    game.admitPendingOre()
    #expect(
      count == 1 && game.bodies.filter { $0.physical?.payload == payload.identity }.count == 1)
  }

  @Test func realSaveReloadAndLaunchUseLatestOreMotionWithoutCreatingAnotherYield() async throws {
    var (game, payload, bodyID) = try actualMinedOreGame()
    game.tick(delta: 0.1)
    let observer = game.commander.flightSimulation.pose.position
    let body = try #require(game.bodies.first { $0.id == bodyID })
    let expected = game.commander.flightSimulation.pose.systemPoint(body.position)
    let runtime = GameRuntime(game: game)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try await runtime.save(to: url)
    try await runtime.load(from: url, persistMigrations: false)
    let loaded = await runtime.snapshot()
    let saved = try #require(
      loaded.commander.miningLedger.pendingPayloads.first { $0.identity == payload.identity })
    #expect((saved.position - expected).length < 1e-8 && saved.amount == payload.amount)
    var relaunched = Game(executive: false)
    relaunched.commander = loaded.commander
    relaunched.launch()
    relaunched.bodies = []
    moveOreObserver(&relaunched, to: observer)
    relaunched.admitPendingOre()
    let restored = try #require(
      relaunched.bodies.first { $0.physical?.payload == payload.identity })
    #expect(
      (relaunched.commander.flightSimulation.pose.systemPoint(restored.position) - expected).length
        < 1e-8)
    #expect(
      relaunched.commander.miningLedger.pendingPayloads.count
        == loaded.commander.miningLedger.pendingPayloads.count)
    if case .ore(let rock, _) = payload.identity {
      #expect(relaunched.commander.miningLedger.isDepleted(rock))
    }
  }

  @Test func wrongActorCannotScoopOrRewriteAnActualAcknowledgedOrePod() throws {
    var (game, payload, bodyID) = try actualMinedOreGame()
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    var wrong = SpaceBody(id: 990, hull: .cargo, position: .init(0, -12, 40))
    wrong.physical = .init(identity: actor, population: .cargo, payload: payload.identity)
    game.bodies.append(wrong)
    let before = game.commander
    game.scoopCargo()
    #expect(game.commander == before && game.bodies.contains { $0.id == bodyID })
    game.persistOrePoses()
    let actual = try #require(game.bodies.first { $0.id == bodyID })
    let retained = try #require(
      game.commander.miningLedger.pendingPayloads.first { $0.identity == payload.identity })
    #expect(
      (retained.position - game.commander.flightSimulation.pose.systemPoint(actual.position)).length
        < 1e-8)
    #expect(
      game.commander.miningLedger.boundActor(for: payload.identity) == actual.physical?.identity)
  }

  @Test func actualBoundOreCollectsOnlyOnceAndAnOldVisitBodyCannotCollectIt() throws {
    var (game, payload, bodyID) = try actualMinedOreGame()
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    game.bodies[index].position = .init(0, -12, 40)
    var stale = game
    stale.commander.flightSimulation.enter(stale.systemIdentity, arriving: false)
    let before = stale.commander
    stale.scoopCargo()
    #expect(stale.commander == before && stale.bodies.contains { $0.id == bodyID })
    let quantity = game.commander.cargo[payload.amount.commodity.rawValue]
    game.scoopCargo()
    #expect(
      game.commander.cargo[payload.amount.commodity.rawValue] == quantity + payload.amount.quantity)
    #expect(!game.bodies.contains { $0.id == bodyID })
    #expect(
      !game.commander.miningLedger.pendingPayloads.contains { $0.identity == payload.identity })
    let collected = game.commander
    game.scoopCargo()
    #expect(game.commander == collected)
  }
}
