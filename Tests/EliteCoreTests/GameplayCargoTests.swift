import Foundation
import Testing

@testable import EliteCore

private func cargoRuntimeGame(manifest: [CommodityAmount] = []) throws -> Game {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.bodies.removeAll { $0.id != 0 }
  let allocated = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocated)
  var npc = NPCState(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity)
  npc.ordinaryCargo = manifest
  npc.cargoProvenance = .recorded
  npc.resources = NPCResources.legacyEnergyOnly(maximumEnergy: 100)
  var body = SpaceBody(id: 90, hull: .cobra, position: .init(0, 0, 2000))
  body.energy = 0
  body.physical = .init(identity: actor, population: .civilian, npc: npc)
  game.bodies.append(body)
  return game
}

struct GameplayCargoTests {
  @Test func actualDeathReleasesOnlyExactManifestAndRepeatedRemovalCannotCreateFood() throws {
    var game = try cargoRuntimeGame(manifest: [
      .init(commodity: .food, quantity: 7), .init(commodity: .gold, quantity: 4),
      .init(commodity: .narcotics, quantity: 2),
    ])
    game.resolveDestroyed()
    #expect(!game.bodies.contains { $0.id == 90 })
    let amounts = game.commander.cargoDebrisLedger.pendingPayloads.map(\.amount)
    #expect(
      amounts == [
        .init(commodity: .food, quantity: 5), .init(commodity: .food, quantity: 2),
        .init(commodity: .narcotics, quantity: 2), .init(commodity: .gold, quantity: 4),
      ])
    let saved = game.commander.cargoDebrisLedger
    game.resolveDestroyed()
    #expect(game.commander.cargoDebrisLedger == saved)
    var empty = try cargoRuntimeGame()
    empty.resolveDestroyed()
    #expect(empty.commander.cargoDebrisLedger.pendingPayloads.isEmpty)
  }

  @Test func physicalScoopingTransfersNativeUnitsAndIllegalCargoOnlyOnce() throws {
    var game = try cargoRuntimeGame(manifest: [
      .init(commodity: .narcotics, quantity: 2), .init(commodity: .gold, quantity: 4),
    ])
    game.commander.equipment.insert("Fuel Scoops")
    game.resolveDestroyed()
    game.admitPendingCargo()
    let pods = game.bodies.filter { $0.physical?.payload != nil }
    #expect(pods.count == 2)
    for pod in pods {
      let index = try #require(game.bodies.firstIndex { $0.id == pod.id })
      game.bodies[index].position = .init(0, -10, 40)
      game.scoopCargo()
    }
    #expect(game.commander.cargo[CommodityIdentity.narcotics.rawValue] == 2)
    #expect(game.commander.cargo[CommodityIdentity.gold.rawValue] == 4)
    #expect(game.commander.cargoTonnes == 2)
    #expect(game.commander.cargoDebrisLedger.pendingPayloads.isEmpty)
    game.admitPendingCargo()
    game.scoopCargo()
    #expect(!game.bodies.contains { $0.physical?.payload != nil })
    #expect(game.commander.cargo[CommodityIdentity.narcotics.rawValue] == 2)
  }

  @Test func missionActorsCannotBecomeOrdinaryCargoAndDestroyedPodsCannotRespawn() throws {
    var protected = try cargoRuntimeGame(manifest: [.init(commodity: .gold, quantity: 5)])
    protected.bodies[1].physical?.npc?.role = .mission
    protected.resolveDestroyed()
    #expect(protected.commander.cargoDebrisLedger.pendingPayloads.isEmpty)
    var game = try cargoRuntimeGame(manifest: [.init(commodity: .food, quantity: 2)])
    game.resolveDestroyed()
    game.admitPendingCargo()
    let index = try #require(game.bodies.firstIndex { $0.physical?.payload != nil })
    game.bodies[index].energy = 0
    game.resolveDestroyed()
    game.admitPendingCargo()
    #expect(game.commander.cargoDebrisLedger.pendingPayloads.isEmpty)
    #expect(!game.bodies.contains { $0.physical?.payload != nil })
  }

  @Test func dockAndReloadPreserveManifestWhileActualTravelAbandonsIt() async throws {
    var game = try cargoRuntimeGame(manifest: [.init(commodity: .gold, quantity: 3)])
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let settled = await runtime.snapshot()
    #expect(settled.commander.cargoDebrisLedger.pendingPayloads.count == 1)
    try await runtime.load(from: url)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander.cargoDebrisLedger == settled.commander.cargoDebrisLedger)
    game = loaded
    game.launch()
    game.admitPendingCargo()
    #expect(game.bodies.contains { $0.physical?.payload != nil })
    game.dock()
    #expect(game.commander.cargoDebrisLedger.pendingPayloads.count == 1)
    game.selectedSystem = 8
    game.arrive()
    #expect(game.commander.cargoDebrisLedger.pendingPayloads.isEmpty)
  }

  @Test func failedSavePublishesNeitherDeathSettlementNorChangedRuntime() async throws {
    let game = try cargoRuntimeGame(manifest: [.init(commodity: .food, quantity: 2)])
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let runtime = GameRuntime(game: game)
    var failed = false
    do { try await runtime.save(to: directory) } catch { failed = true }
    #expect(failed)
    let after = await runtime.snapshot()
    #expect(after.commander == game.commander && after.bodies == game.bodies)
    let url = directory.appendingPathComponent("commander.json")
    try await runtime.save(to: url)
    let saved = await runtime.snapshot()
    #expect(saved.commander.cargoDebrisLedger.pendingPayloads.count == 1)
    try await runtime.save(to: url)
    #expect(
      await runtime.snapshot().commander.cargoDebrisLedger == saved.commander.cargoDebrisLedger)
  }
}
