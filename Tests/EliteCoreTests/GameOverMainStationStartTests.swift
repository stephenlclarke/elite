import Foundation
import Testing

@testable import EliteCore

private struct GameOverStationFixture {
  let files: ScriptFreightFixture
  init() throws { files = try ScriptFreightFixture() }
  func clean() { files.clean() }

  func deadRuntime(withFreight: Bool = false) async throws -> GameRuntime {
    let runtime = GameRuntime(game: Game(executive: false))
    let errors = await runtime.loadDefaultScriptPacks(
      directory: files.root.appendingPathComponent("installed"))
    try #require(errors.isEmpty)
    try await runtime.startNewCommander()
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    await runtime.key(" ")
    if withFreight { _ = try await acceptRestartSupply(runtime) }
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    try #require(await runtime.snapshot().screen.isFlight)
    // Existing native collision helper emits a real player-hull hit, rather than setting gameOver.
    try await runtime.supplyFatalHullHit()
    _ = await runtime.advance(delta: 0.1)
    try #require(await runtime.snapshot().screen == .gameOver)
    try await runtime.save(to: files.save)
    return runtime
  }
}

private func acceptRestartSupply(_ runtime: GameRuntime) async throws -> UUID {
  await runtime.key("contracts-open")
  let board = await runtime.snapshot()
  try #require(board.screen == .contracts)
  let index = try #require(
    board.contractBoard.rows.firstIndex { $0.offer?.freightPlan?.isConsented == true })
  for _ in 0..<board.contractBoard.selection { await runtime.key("up") }
  for _ in 0..<index { await runtime.key("down") }
  await runtime.key("return")
  let quote = try #require(await runtime.snapshot().contractBoard.quote)
  try #require(quote.allowed, "\(quote.issues)")
  await runtime.key("right")
  try #require(await runtime.snapshot().contractBoard.action == .accept)
  await runtime.key("return")
  let id = Game.contractJobIdentity(quote.offer)
  try #require(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .active)
  return id
}

private func gameOverSupply(_ game: Game) throws -> OriginalConsentedFreightSupplySource {
  let stock = try #require(game.commander.scriptState.savedOriginalConsentedFreightSupply)
  return try #require(stock.sources[OriginalConsentedFreightSupply.sourceKey(owner: stock.owner)])
}

@Suite(.serialized)
struct GameOverMainStationStartTests {
  @Test(arguments: ["return", " "])
  func actualFatalRestartPublishesNewOwnerAndRealArlenBerthAtTheSameDestination(key: String)
    async throws
  {
    let f = try GameOverStationFixture()
    defer { f.clean() }
    let runtime = try await f.deadRuntime(withFreight: true)
    let dead = await runtime.snapshot()
    let oldOwner = try #require(dead.commander.equipmentOwnerID)
    let oldSource = try gameOverSupply(dead)
    try #require(oldSource.remaining.count == 8)
    let libraries = dead.scriptPacks.map(\.digest)
    await runtime.key(key)
    let restarted = await runtime.snapshot()
    let owner = try #require(restarted.commander.equipmentOwnerID)
    let receipt = try #require(restarted.commander.nativeStations?.currentMainDock)
    #expect(restarted.screen == .status && restarted.docked && restarted.bodies.isEmpty)
    #expect(restarted.commander.valid && restarted.nativeMainStationDockEvidenceIsCurrent)
    #expect(owner != oldOwner && receipt.commanderOwner == owner && receipt.station.world == owner)
    #expect(receipt.station.system == .init(galaxy: 0, system: 7))
    #expect(receipt.sequence == 1 && restarted.commander.nativeStations?.nextMainDockSequence == 2)
    #expect(restarted.currentSystem.name == "Avenor" && restarted.commander.shipID == "SH025")
    #expect(restarted.commander.name == "Rowan Calder")
    #expect(restarted.commander.credits == 7200 && restarted.commander.fuel == 130)
    #expect(restarted.commander.cargo.allSatisfy { $0 == 0 })
    #expect(restarted.commander.scriptState.instances.isEmpty)
    #expect(restarted.commander.scriptState.savedOriginalConsentedFreightSupply == nil)
    #expect(restarted.commander.scriptState.savedClueJournal == nil)
    #expect(restarted.commander.scriptState.calendarSeconds == 0)
    #expect(restarted.commander.scriptState.calendarLedger?.operation == 0)
    #expect(restarted.commander.flightSimulation.physicalTime == 0)
    #expect(restarted.scriptPacks.map(\.digest) == libraries)
    #expect(await runtime.hasCommanderSaveDestination())
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: f.files.save), from: f.files.save)
    #expect(
      saved.equipmentOwnerID == owner && saved.nativeStations == restarted.commander.nativeStations)
    let id = try await acceptRestartSupply(runtime)
    let accepted = await runtime.snapshot()
    let source = try gameOverSupply(accepted)
    let cargo = try #require(accepted.commander.scriptState.instances[id]?.savedOwnedCargo)
    #expect(
      source.owner == owner && source.units == OriginalConsentedFreightSupply.unitIDs(owner: owner))
    #expect(Set(source.units).isDisjoint(with: oldSource.units))
    #expect(source.units.count == 16 && source.remaining.count == 8)
    #expect(cargo.held == cargo.issued && cargo.issued == Array(source.units.prefix(8)))
    #expect(source.allocations[id] == cargo.issued)
    #expect(accepted.commander.cargo == restarted.commander.cargo)
    #expect(accepted.commander.checkedCargoTonnes == 8 && accepted.commander.credits == 7200)
    #expect(accepted.commander.nativeStations?.currentMainDock == receipt)
    let unchanged = CommanderSnapshot(accepted.commander)
    await #expect(throws: (any Error).self) { try await runtime.startNewCommander() }
    #expect(await runtime.snapshot().commander == unchanged.value)
  }

  @Test(arguments: ["return", " "])
  func failedBoundRestartKeepsDeadCommanderOwnerAndSaveThenRetries(key: String) async throws {
    let f = try GameOverStationFixture()
    defer { f.clean() }
    let runtime = try await f.deadRuntime()
    let before = await runtime.snapshot()
    let oldOwner = try #require(before.commander.equipmentOwnerID)
    let beforeFiles = try ScriptFinanceTestFixture.files(f.files.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("restart", destination: f.files.save)
    await runtime.key(key)
    let refused = await runtime.snapshot()
    #expect(refused.screen == .gameOver && refused.commander == before.commander)
    #expect(refused.commander.equipmentOwnerID == oldOwner)
    #expect(refused.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
    #expect(refused.scriptPacks.map(\.digest) == before.scriptPacks.map(\.digest))
    #expect(refused.newCommanderSaveReceipt?.url == before.newCommanderSaveReceipt?.url)
    #expect(refused.pendingNewSaveDestination == before.pendingNewSaveDestination)
    try f.files.restoreWrites(held, files: beforeFiles, destination: f.files.save)
    await runtime.key(key)
    let restarted = await runtime.snapshot()
    #expect(restarted.screen == .status && restarted.commander.valid)
    #expect(restarted.commander.equipmentOwnerID != oldOwner)
    #expect(restarted.nativeMainStationDockEvidenceIsCurrent)
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: f.files.save), from: f.files.save)
    #expect(saved.equipmentOwnerID == restarted.commander.equipmentOwnerID)
    #expect(saved.nativeStations == restarted.commander.nativeStations)
  }

  @Test(arguments: ["escape", "q"])
  func nonRestartInputDoesNotDiscardTheDeadCommanderOrPublishANewOwner(key: String) async throws {
    let f = try GameOverStationFixture()
    defer { f.clean() }
    let runtime = try await f.deadRuntime()
    let before = await runtime.snapshot()
    let bytes = try Data(contentsOf: f.files.save)
    await runtime.key(key)
    let unchanged = await runtime.snapshot()
    #expect(unchanged.screen == .gameOver && unchanged.commander == before.commander)
    #expect(unchanged.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
    #expect(try Data(contentsOf: f.files.save) == bytes)
  }

  @Test(arguments: ["return", " "], [false, true])
  func directNativeGameRestartUsesTheSameBornBerthProducer(key: String, executive: Bool) throws {
    var game = Game(executive: executive)
    game.screen = .gameOver
    try game.commander.prepareEquipment(legacy: false)
    let owner = try #require(game.commander.equipmentOwnerID)
    game.key(key)
    #expect(game.screen == .status && game.commander.valid)
    #expect(game.commander.executive == executive)
    #expect(game.commander.equipmentOwnerID != owner)
    #expect(game.nativeMainStationDockEvidenceIsCurrent && game.bodies.isEmpty)
    #expect(game.commander.nativeStations?.currentMainDock?.sequence == 1)
    #expect(game.commander.scriptState.calendarSeconds == 0)
    #expect(game.commander.flightSimulation.physicalTime == 0)
    #expect(game.commander.scriptState.instances.isEmpty)
  }

  @Test func aRawTrialFlagCannotUseTheLiveGameOverBerthProducer() throws {
    var game = Game(executive: false)
    game.screen = .gameOver
    game.isMissionTrial = true
    let before = CommanderSnapshot(game.commander)
    game.key("return")
    #expect(game.screen == .gameOver && game.commander == before.value)
    #expect(!game.nativeMainStationDockEvidenceIsCurrent && game.commander.nativeStations == nil)
  }
}
