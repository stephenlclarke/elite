import Foundation
import Testing

@testable import EliteCore

struct InitialMainStationDockingTests {
  private func preparedGame() throws -> Game {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    let origin = try #require(
      game.systems.first {
        $0.original != nil && $0.government == 7 && $0.technology >= 12
      })
    game.commander.system = origin.id
    game.selectedSystem = origin.id
    game.market = MarketItem.at(game.currentSystem)
    try game.prepareG03FlightEquipment()
    try ScriptProcurementFixture.requirePaidG03Preparation(game)
    try #require(game.commander.shipID == "SH025" && game.commander.valid)
    return game
  }

  @Test func paidFreshSH025LaunchReturnsThroughRealAutoDockWithinOriginalStepBudget() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let game = try preparedGame()
    let cash = game.commander.credits
    let cargo = game.commander.cargo
    let fuel = game.commander.fuel
    let hull = game.commander.hullInstanceID
    let items = game.commander.equipmentInventory
    let purchases = game.commander.equipmentPurchaseHistory
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let before = try Data(contentsOf: storage.url)
    await runtime.key("0")
    let launched = await runtime.snapshot()
    try #require(!launched.docked && launched.screen.isFlight && !launched.paused)
    #expect(launched.autoTargetBody == nil && !launched.dockingComputer)
    let start = launched.commander.flightSimulation.physicalTime
    // This existing helper uses only TAB and real 0.1-second advances, with its
    // unchanged 3000-step budget. It neither removes traffic nor forces a dock.
    try await ScriptProcurementFixture.dock(runtime)
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    let elapsed = arrived.commander.flightSimulation.physicalTime - start
    #expect(elapsed > 0 && elapsed < 300)
    #expect(!arrived.paused && arrived.energy > 0 && arrived.commander.valid)
    #expect(arrived.commander.shipID == "SH025" && arrived.commander.hullInstanceID == hull)
    #expect(arrived.commander.credits == cash && arrived.commander.cargo == cargo)
    #expect(arrived.commander.fuel == fuel && arrived.commander.equipmentInventory == items)
    #expect(arrived.commander.equipmentPurchaseHistory == purchases)
    let saved = try Data(contentsOf: storage.url)
    let (disk, scene) = try ScriptSaveStore.read(saved, from: storage.url)
    #expect(saved != before && scene.consistent(with: disk))
    #expect(disk.shipID == "SH025" && disk.credits == cash && disk.hullInstanceID == hull)
    #expect(
      disk.nativeStations?.currentMainDock == arrived.commander.nativeStations?.currentMainDock)
    #expect(disk.nativeStations?.currentMainDock != nil)
  }

  /// Pure geometry/control inputs, not a flown journey or docking authority. The
  /// endpoint follows the ordinary native constant-world-velocity/Euler-rate step.
  private func geometricStep(lateral: Double = 0) throws -> (Game, ShipPose) {
    var game = try preparedGame()
    game.launch()
    try #require(!game.docked && !game.paused)
    for _ in 0..<32 where game.autoTargetBody?.id != 0 { game.key("tab") }
    try #require(game.autoTargetBody?.id == 0 && game.dockingComputer)
    var before = ShipPose()
    before.position = .init(lateral, 0, -96)
    NativeStationTestFixture.reframe(&game, to: before)
    game.speed = 0
    game.pitch = 0
    game.yaw = 0
    game.roll = -0.3
    game.autoPilot.setApproachVelocity(.init(0, 0, 48))
    var after = before
    after.advanceView(pitch: 0, roll: -0.03, yaw: 0, translation: .init(0, 0, 4.8))
    NativeStationTestFixture.reframe(&game, to: after)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let index = try #require(game.bodies.firstIndex { $0.id == 0 })
    try #require(game.bodies[index].rotationRate == 0.3)
    game.bodies[index].rotation = 0.03
    return (game, before)
  }

  @Test func matchedSpinSH025StepRefinesWholeHullProofWithoutChangingTheAperture() throws {
    let (game, before) = try geometricStep()
    let station = try #require(game.bodies.first { $0.id == 0 })
    let player = game.commander.playerMesh
    let port = MainStationGeometry.docking
    let radius = try #require(player.vertices.map(\.length).max())
    let stationRadius = try #require(MainStationGeometry.mesh.vertices.map(\.length).max())
    let coarse = (radius + stationRadius) * (abs(game.roll) + abs(station.rotationRate)) * 0.1
    #expect(port.aperture.map(\.y).max() == 32)
    #expect(try #require(player.vertices.map(\.y).max()) + coarse > 32)
    #expect(port.fits(player) && !port.fits(player, margin: coarse))
    #expect(
      game.nativeMainStationHullCourseIsClear(
        station, from: before, to: game.commander.flightSimulation.pose, delta: 0.1))
    #expect(game.commander.nativeStations?.currentMainDock == nil)
    #expect(!game.nativeMainStationDockEvidenceIsCurrent)
  }

  @Test func wallContactsAndUnsupportedNativeMotionStillRefuseTheWholeStep() throws {
    let (wall, wallStart) = try geometricStep(lateral: 50)
    let wallStation = try #require(wall.bodies.first { $0.id == 0 })
    #expect(
      !wall.nativeMainStationHullCourseIsClear(
        wallStation, from: wallStart, to: wall.commander.flightSimulation.pose, delta: 0.1))
    #expect(
      !wall.nativeMainStationHullCourseIsClear(
        wallStation, from: wallStart, to: wall.commander.flightSimulation.pose,
        delta: 0.1, requireAperture: false))
    var (game, before) = try geometricStep()
    let station = try #require(game.bodies.first { $0.id == 0 })
    let end = game.commander.flightSimulation.pose
    game.dockingComputer = false
    #expect(!game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
    game.dockingComputer = true
    game.speed = 1
    #expect(!game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
    game.speed = 0
    game.autoPilot.setApproachVelocity(.init(0, 0, 24))
    #expect(!game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
    game.autoPilot.setApproachVelocity(.init(0, 0, 48))
    game.roll = 0.3
    #expect(!game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
    game.roll = -0.3
    for delta in [-0.1, 0.10001, Double.nan] {
      #expect(
        !game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: delta))
    }
    game.bodies.append(station)
    #expect(!game.nativeMainStationHullCourseIsClear(station, from: before, to: end, delta: 0.1))
    #expect(!game.docked && game.commander.nativeStations?.currentMainDock == nil)
  }
}
