import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

@MainActor
private struct FreshMainStationFixture {
  let files: ScriptFreightFixture
  let identifier: String
  let preferences: UserDefaults
  let delegate: AppDelegate
  var runtime: GameRuntime { delegate.runtime }

  init() throws {
    _ = NSApplication.shared
    files = try ScriptFreightFixture()
    identifier = UUID().uuidString
    preferences = try #require(UserDefaults(suiteName: identifier))
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: files.save)
    delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
  }

  func clean() {
    preferences.removePersistentDomain(forName: identifier)
    files.clean()
  }

  func start(afterFailedRestore: Bool = false) async throws {
    let errors = await runtime.loadDefaultScriptPacks(
      directory: files.root.appendingPathComponent("installed"))
    try #require(errors.isEmpty)
    if afterFailedRestore {
      let previous = files.root.appendingPathComponent("unrestorable.json")
      let bytes = Data("invalid previous commander".utf8)
      try bytes.write(to: previous)
      await #expect(throws: (any Error).self) { try await runtime.restoreStartup(from: previous) }
      try await delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: true)
      #expect(try Data(contentsOf: previous) == bytes)
    } else {
      try await delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: false)
    }
    // Exercise the same introductory title transition as the ordinary default app runtime.
    for _ in 0..<121 { _ = await runtime.advance(delta: 0.1) }
    try #require(await runtime.snapshot().screen == .title)
    await runtime.key(" ")
    try #require(await runtime.snapshot().screen == .status)
  }
}

private func freshSupplySource(_ game: Game) throws -> OriginalConsentedFreightSupplySource {
  let stock = try #require(game.commander.scriptState.savedOriginalConsentedFreightSupply)
  return try #require(stock.sources[OriginalConsentedFreightSupply.sourceKey(owner: stock.owner)])
}

private func reviewFreshSupply(_ runtime: GameRuntime) async throws -> ContractAcceptanceQuote {
  await runtime.key("contracts-open")
  let board = await runtime.snapshot()
  try #require(board.screen == .contracts)
  let pack = try #require(
    board.scriptPacks.first { $0.manifest.stateID == OriginalConsentedFreightSupply.stateID })
  try #require(pack.manifest.board?.title == "ARLEN / Consented freight supply")
  let selected = try #require(
    board.contractBoard.rows.firstIndex { $0.offer?.freightPlan?.isConsented == true })
  // The normal contract page starts at the first row; select ARLEN through native input.
  for _ in 0..<board.contractBoard.selection { await runtime.key("up") }
  for _ in 0..<selected { await runtime.key("down") }
  await runtime.key("return")
  let terms = await runtime.snapshot()
  try #require(terms.contractBoard.detail)
  return try #require(terms.contractBoard.quote)
}

private func acceptFreshSupply(_ runtime: GameRuntime) async throws -> (
  UUID, ContractAcceptanceQuote
) {
  let quote = try await reviewFreshSupply(runtime)
  try #require(quote.allowed, "\(quote.issues)")
  await runtime.key("right")  // Back -> Accept.
  try #require(await runtime.snapshot().contractBoard.action == .accept)
  await runtime.key("return")
  let id = Game.contractJobIdentity(quote.offer)
  try #require(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .active)
  return (id, quote)
}

private func abandonFreshSupply(_ runtime: GameRuntime, id: UUID) async throws {
  await runtime.key("escape")
  await runtime.key("contacts-open")
  try #require(await runtime.snapshot().scriptPresentedDialogue?.id == "freight-abandon")
  try await ScriptFreightFixture.confirm(runtime)
  try #require(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .abandoned)
}

enum FreshDockChange: CaseIterable, Sendable { case owner, replacement, destroyed, launch }

@Suite(.serialized)
struct FreshMainStationStartTests {
  @MainActor @Test(arguments: [false, true])
  func ordinaryFreshOrRecoveryStartAcceptsRealArlenTermsWithoutFlight(recovery: Bool) async throws {
    let f = try FreshMainStationFixture()
    defer { f.clean() }
    try await f.start(afterFailedRestore: recovery)
    let started = await f.runtime.snapshot()
    let owner = try #require(started.commander.equipmentOwnerID)
    let world = try #require(started.commander.nativeStations)
    let receipt = try #require(world.currentMainDock)
    let anchor = try #require(started.commander.flightSimulation.anchors?.station)
    #expect(started.commander.name == "Rowan Calder" && started.commander.shipID == "SH025")
    #expect(started.currentSystem.name == "Avenor" && started.commander.system == 7)
    #expect(started.commander.credits == 7200 && started.commander.fuel == 130)
    #expect(started.docked && started.dockedAtMainStation && started.bodies.isEmpty)
    #expect(started.commander.valid && started.nativeMainStationDockEvidenceIsCurrent)
    #expect(receipt.station.world == owner && receipt.commanderOwner == owner)
    #expect(receipt.station.system == .init(galaxy: 0, system: 7))
    #expect(
      receipt.actor == anchor.identity && receipt.actor.entity == 1 && receipt.actor.visit == 1)
    #expect(receipt.sequence == 1 && world.nextMainDockSequence == 2)
    #expect(world.mainObservations.first?.actor == receipt.actor)
    let resource = try #require(started.commander.scriptState.stationResources[receipt.station.key])
    #expect(
      resource.identity == receipt.station.resource && !resource.destroyed && resource.energy > 0)
    #expect(started.commander.flightSimulation.physicalTime == 0)
    #expect(started.commander.scriptState.calendarSeconds == 0 && receipt.calendarSeconds == 0)
    #expect(started.commander.scriptState.calendarLedger?.operation == 0)
    #expect(started.commander.scriptState.instances.isEmpty)
    let (id, quote) = try await acceptFreshSupply(f.runtime)
    let accepted = await f.runtime.snapshot()
    let cargo = try #require(accepted.commander.scriptState.instances[id]?.savedOwnedCargo)
    let source = try freshSupplySource(accepted)
    #expect(source.units.count == 16 && source.remaining.count == 8)
    #expect(cargo.issued == Array(source.units.prefix(8)) && cargo.held.count == 8)
    #expect(source.allocations[id] == cargo.issued && accepted.commander.cargo[8] == 8)
    #expect(accepted.commander.credits == 7200 && accepted.commander.fuel == 130)
    #expect(accepted.commander.nativeStations?.currentMainDock == receipt)
    #expect(accepted.commander.scriptState.calendarSeconds == 0)
    #expect(accepted.commander.flightSimulation.physicalTime == 0)
    #expect(try await f.runtime.confirmContract(quote) == id)
    #expect(await f.runtime.snapshot().commander == accepted.commander)
    let unbound = GameRuntime(game: accepted)
    let retained = await unbound.snapshot()
    try await unbound.startNewCommander()
    #expect(await unbound.snapshot().commander == retained.commander)
    #expect(try freshSupplySource(await unbound.snapshot()) == source)
  }

  @MainActor @Test func currentColdReloadKeepsBerthAndFiniteStockWithoutReissuing() async throws {
    let f = try FreshMainStationFixture()
    defer { f.clean() }
    try await f.start()
    let (first, _) = try await acceptFreshSupply(f.runtime)
    let before = await f.runtime.snapshot()
    let receipt = try #require(before.commander.nativeStations?.currentMainDock)
    let context = try #require(before.nativeMainStationArrivalContext(for: receipt.station))
    let url = f.delegate.saves.activeURL
    try await f.runtime.save(to: url)
    let cold = GameRuntime()
    _ = await cold.loadDefaultScriptPacks(
      directory: f.files.root.appendingPathComponent("installed"))
    try await cold.restoreStartup(from: url)
    await cold.key(" ")
    let loaded = await cold.snapshot()
    let fresh = try #require(loaded.nativeMainStationArrivalContext(for: receipt.station))
    #expect(loaded.commander == before.commander)
    #expect(fresh.receipt == receipt && fresh.runtimeEpoch != context.runtimeEpoch)
    #expect(!loaded.acceptsNativeMainStationArrivalContext(context))
    #expect(try freshSupplySource(loaded).remaining.count == 8)
    try await abandonFreshSupply(cold, id: first)
    let (second, quote) = try await acceptFreshSupply(cold)
    let exhausted = await cold.snapshot()
    let source = try freshSupplySource(exhausted)
    #expect(first != second && source.remaining.isEmpty && source.allocations.count == 2)
    #expect(source.allocations[second] == Array(source.units.suffix(8)))
    #expect(exhausted.commander.credits == 7200)
    #expect(try await cold.confirmContract(quote) == second)
    #expect(await cold.snapshot().commander == exhausted.commander)
    await #expect(throws: (any Error).self) { try await cold.startNewCommander() }
    #expect(await cold.snapshot().commander == exhausted.commander)
    try await abandonFreshSupply(cold, id: second)
    let unavailable = try await reviewFreshSupply(cold)
    #expect(!unavailable.allowed)
    #expect(
      unavailable.issues.contains(
        "ARLEN's original finite batch cannot supply another eight tonnes."))
    let final = await cold.snapshot().commander
    await #expect(throws: (any Error).self) { try await cold.confirmContract(unavailable) }
    #expect(await cold.snapshot().commander == final)
  }

  @Test func unboundRetryKeepsActualOwnerStockAndClockButRawCallerFlagsDoNotQualify() async throws {
    let runtime = GameRuntime()
    try await runtime.startNewCommander()
    let before = await runtime.snapshot()
    try await runtime.startNewCommander()
    let repeated = await runtime.snapshot()
    #expect(repeated.commander == before.commander)
    #expect(repeated.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
    var raw = Game(executive: false)
    raw.screen = .status
    raw.dock(atMainStation: true)
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let rawRuntime = GameRuntime(game: raw, saveURL: files.save)
    _ = await rawRuntime.loadDefaultScriptPacks(
      directory: files.root.appendingPathComponent("installed"))
    let rawBefore = await rawRuntime.snapshot()
    #expect(!rawBefore.nativeMainStationDockEvidenceIsCurrent)
    await #expect(throws: (any Error).self) {
      _ = try await rawRuntime.generateContractBoard(
        packDigest: OriginalConsentedFreightSupply.digest)
    }
    #expect(await rawRuntime.snapshot().commander == rawBefore.commander)
    // A copied receipt without the non-serializable native evidence cannot enable startup retry.
    var forged = before
    forged.nativeMainStationDockEvidence = nil
    let forgedRuntime = GameRuntime(game: forged)
    let forgedBefore = await forgedRuntime.snapshot()
    await #expect(throws: (any Error).self) { try await forgedRuntime.startNewCommander() }
    #expect(await forgedRuntime.snapshot().commander == forgedBefore.commander)
  }

  @Test(arguments: FreshDockChange.allCases)
  func genuineStartupContextRefusesChangedOwnerActorDestroyedResourceOrLaunch(
    change: FreshDockChange
  ) async throws {
    let runtime = GameRuntime()
    try await runtime.startNewCommander()
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    var changed = await runtime.snapshot()
    let receipt = try #require(changed.commander.nativeStations?.currentMainDock)
    let original = try #require(changed.nativeMainStationArrivalContext(for: receipt.station))
    switch change {
    case .owner:
      let inventory = try #require(changed.commander.equipmentInventory)
      changed.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: UUID(), activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items)
    case .replacement:
      let observation = try #require(changed.commander.nativeStations?.mainObservations.first)
      changed.commander.nativeStations?.mainObservations[0] = .init(
        station: observation.station,
        actor: .init(
          system: observation.actor.system, visit: observation.actor.visit + 1, entity: 1),
        calendarSeconds: observation.calendarSeconds)
    case .destroyed:
      changed.commander.scriptState.stationResources[receipt.station.key]?.energy = 0
      changed.commander.scriptState.stationResources[receipt.station.key]?.destroyed = true
    case .launch: changed.launch()
    }
    let before = changed.commander
    #expect(changed.nativeMainStationArrivalContext(for: receipt.station) == nil)
    #expect(!changed.acceptsNativeMainStationArrivalContext(original))
    #expect(changed.commander == before)
    if change != .launch {
      let refusing = GameRuntime(game: changed)
      await #expect(throws: (any Error).self) { try await refusing.startNewCommander() }
      #expect(await refusing.snapshot().commander == before)
    } else {
      #expect(!changed.docked && changed.commander.nativeStations?.currentMainDock == nil)
    }
  }

  @MainActor @Test func failedDestinationBindingRetriesWithoutResettingTheGenuineCommander()
    async throws
  {
    let f = try FreshMainStationFixture()
    defer { f.clean() }
    let blocker = f.files.save.deletingLastPathComponent()
    try Data([1]).write(to: blocker)
    await #expect(throws: (any Error).self) {
      try await f.delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: false)
    }
    let before = await f.runtime.snapshot()
    try #require(before.commander.valid && before.nativeMainStationDockEvidenceIsCurrent)
    #expect(!(await f.runtime.hasCommanderSaveDestination()))
    try FileManager.default.removeItem(at: blocker)
    try await f.delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: false)
    let bound = await f.runtime.snapshot()
    #expect(bound.commander == before.commander)
    #expect(bound.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
    #expect(bound.nativeMainStationDockEvidenceIsCurrent && bound.scriptDurabilityAvailable)
    #expect(await f.runtime.hasCommanderSaveDestination())
  }

  @MainActor @Test func actualFreshSourceWriterRefusalRollsBackAllPropertyThenRetries() async throws
  {
    let f = try FreshMainStationFixture()
    defer { f.clean() }
    try await f.start()
    let quote = try await reviewFreshSupply(f.runtime)
    try #require(quote.allowed)
    let before = await f.runtime.snapshot()
    let url = f.delegate.saves.activeURL
    let saved = try ScriptFinanceTestFixture.files(url.deletingLastPathComponent())
    let held = try f.files.blockWrites("fresh-source", destination: url)
    await #expect(throws: (any Error).self) { _ = try await f.runtime.confirmContract(quote) }
    let refused = await f.runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.nativeMainStationDockEvidenceIsCurrent)
    #expect(refused.commander.scriptState.savedOriginalConsentedFreightSupply == nil)
    try f.files.restoreWrites(held, files: saved, destination: url)
    let id = try await f.runtime.confirmContract(quote)
    #expect(try freshSupplySource(await f.runtime.snapshot()).allocations[id]?.count == 8)
  }
}
