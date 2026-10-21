import Foundation
import Testing

@testable import EliteCore

@Test func nativePeopleWithoutRescueToolsCannotPublishACapture() async throws {
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  var game = Game(executive: false)
  game.screen = .status
  try game.commander.prepareEquipment(legacy: false)
  game.ensureMissionCalendar()
  game.launch()
  let start = game.commander.flightSimulation.physicalTime
  game.tick(delta: 0.1)
  try #require(!game.hasNativeRescueTools && game.commander.valid)
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  let before = await runtime.snapshot()
  let after = try await runtime.captureAtExistingFrameForPureGuardTest(startTime: start)
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(after.energy == before.energy && after.frontShield == before.frontShield)
  #expect(
    after.rearShield == before.rearShield && after.gameplayRevision == before.gameplayRevision)
  #expect(after.nextBodyID == before.nextBodyID)
  #expect(!FileManager.default.fileExists(atPath: storage.directory.path))
}

@Test func nativePeopleWithRescueToolsStillRejectsAnInvalidCommander() async throws {
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  var game = try NativePeopleTestFixture.podApproach()
  try #require(game.hasNativeRescueTools && game.commander.valid)
  game.commander.credits = -1
  try #require(!game.commander.valid)
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  let before = await runtime.snapshot()
  let after = try await runtime.captureAtExistingFrameForPureGuardTest(startTime: 0)
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(after.energy == before.energy && after.frontShield == before.frontShield)
  #expect(
    after.rearShield == before.rearShield && after.gameplayRevision == before.gameplayRevision)
  #expect(after.nextBodyID == before.nextBodyID)
  #expect(!FileManager.default.fileExists(atPath: storage.directory.path))
}

@Test func freightCandidateFilteringKeepsDegenerateCostsOrderAndSupportedGuards() {
  let paths = [[Int](), [0], [0, 0], [0]]
  for row in 0..<3 {
    #expect(
      ScriptFreightPlan.candidatePaths(paths, galaxy: 0, row: row, generatorRevision: 1) == paths)
    #expect(ScriptFreightPlan.candidatePaths([], galaxy: 0, row: row, generatorRevision: 1).isEmpty)
  }
  for row in [-1, 3] {
    #expect(
      ScriptFreightPlan.candidatePaths(paths, galaxy: 0, row: row, generatorRevision: 1).isEmpty)
  }
  for revision in [0, 2] {
    #expect(
      ScriptFreightPlan.candidatePaths(paths, galaxy: 0, row: 0, generatorRevision: revision)
        .isEmpty)
  }
}

@Test(arguments: [-0.1, 0.0, 0.1])
func freightFeasibilityKeepsItsStrictOriginalDeadline(offset: Double) {
  for row in 0..<3 {
    let deadline = row == 2 ? 259200.0 : 172800.0
    #expect(ScriptFreightPlan.feasible(calendarCost: deadline + offset, row: row) == (offset < 0))
  }
}

extension GameRuntime {
  fileprivate func captureAtExistingFrameForPureGuardTest(startTime: Double) throws -> Game {
    // Exercise only the real capture boundary; no extra physics frame or publisher is fabricated.
    let publisherAvailable = scriptPublisher() != nil
    try #require(publisherAvailable)
    try #require(!game.docked && !game.paused && game.screen.isFlight && game.energy > 0)
    try #require(game.jumpCountdown == nil && game.pendingNativeStationDock == nil)
    try #require(game.commander.flightSimulation.physicalTime > startTime)
    let player = try #require(game.commander.flightSimulation.player)
    commitNativePeopleCapture(
      startTime: startTime, startPlayer: player, delta: 0.1)
    return game
  }
}
