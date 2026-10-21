import Foundation
import Testing

@testable import EliteCore

struct NativeCrewCaptureTests {
  @Test func actualCutterCapturesRemainingOriginalPeopleFittingRealHold() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    let source = try NativePeopleTestFixture.source(game)
    let original = try #require(game.commander.savedEMPState?.records[source])
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 2
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    let captured = await NativePeopleTestFixture.capture(runtime)
    let record = try #require(captured.commander.savedEMPState?.records[source])
    #expect(captured.commander.nativeCaptiveCount == 2 && captured.commander.cargo[3] == 2)
    #expect(captured.commander.cargoTonnes == game.commander.standardCargoCapacity)
    #expect(
      record.pods.count == original.pods.count && record.crewAboard == original.crewAboard - 2)
    #expect(record.crewCaptures.first?.ordinals == Array(original.aboardOrdinals.prefix(2)))
    #expect(record.crewCaptures.first?.count == 2)
    #expect(
      captured.commander.nativePeople?.heldCaptives.map { $0.person.emp.ordinal }.sorted()
        == Array(original.aboardOrdinals.prefix(2)))
    #expect(captured.commander.valid && captured.commander.sellableCargo(3) == 0)
    #expect(!captured.commander.ordinaryCommodityAmounts.contains { $0.commodity == .slaves })
    let again = await NativePeopleTestFixture.capture(runtime)
    #expect(
      again.commander.nativeCaptiveCount == 2
        && again.commander.savedEMPState?.records[source]?.capturedCrewCount == 2)
  }
  @Test(arguments: ["writer", "full", "late", "scoops", "module", "ray"])
  func refusedActualInteractionLeavesEveryOriginalPersonAtSource(reason: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    if reason == "late" { for _ in 0..<301 { game.tick(delta: 0.1) } }
    try NativePeopleTestFixture.aimCutter(&game)
    if reason == "full" { game.commander.cargo[0] = game.commander.standardCargoCapacity }
    if reason == "ray" {
      let index = try #require(game.bodies.firstIndex { $0.physical?.empSource != nil })
      game.bodies[index].position.x += 2000
    }
    if reason == "scoops" || reason == "module" {
      let name = reason == "scoops" ? "Fuel Scoops" : "Targeting: Salvage Module"
      try game.commander.removeFittedEquipment(name)
    }
    let source = try NativePeopleTestFixture.source(game)
    let before = try #require(game.commander.savedEMPState?.records[source])
    let runtime = GameRuntime(game: game, saveURL: reason == "writer" ? nil : storage.url)
    let after = await NativePeopleTestFixture.capture(runtime)
    #expect(after.commander.nativePeople == nil && after.commander.cargo[3] == 0)
    #expect(after.commander.savedEMPState?.records[source]?.crewCaptures == before.crewCaptures)
  }
  @Test func failedWriterRetainsPostPhysicsCrewAndRetriesOnlyAfterExplicitSuccessfulSave()
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    let time = await runtime.snapshot().commander.flightSimulation.physicalTime
    try storage.blockWriter()
    let failed = await NativePeopleTestFixture.capture(runtime)
    #expect(failed.commander.flightSimulation.physicalTime > time)
    #expect(failed.commander.nativePeople == nil && failed.commander.cargo[3] == 0)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    try await runtime.save(to: storage.url)
    let rescued = await NativePeopleTestFixture.capture(runtime)
    #expect(rescued.commander.nativeCaptiveCount == 1 && rescued.commander.valid)
  }
}
