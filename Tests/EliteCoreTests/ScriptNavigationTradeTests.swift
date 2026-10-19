import Foundation
import Testing

@testable import EliteCore

@Test func translatedNavigationPracticeRequiresNativeOriginalBindingsAndExactContent() throws {
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/l337-navigation-trade")
  let pack = try ScriptPackLibrary.read(directory)
  #expect(ScriptNavigationTradeContent.matches(pack) && pack.missingCapabilities.isEmpty)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  #expect(game.scriptUnavailable(pack)?.contains("original-world") == true)
  let offered = game.offerAvailableScriptMission()
  #expect(!offered && game.scriptAvailablePackDigest == nil)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(pack) }
  let counterfeit = ScriptPack(
    manifest: pack.manifest, source: pack.source, manifestBytes: pack.manifestBytes,
    digest: String(repeating: "0", count: 64))
  #expect(game.scriptUnavailable(counterfeit)?.contains("exact approved runtime") == true)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(counterfeit) }
}

@Test(arguments: [false, true])
func navigationTradeActualLossColdRestoreAndReceptionRetainExactAccounting(alien: Bool) async throws
{
  let fixture = try ScriptNavigationTradeFixture(alien: alien)
  defer { fixture.clean() }
  let source = GameRuntime(game: fixture.initial, saveURL: fixture.save)
  let id = try await fixture.ready(source)
  let bought = await source.snapshot()
  let buy = try #require(bought.commander.scriptState.instances[id]?.savedNavigationTrade?.buy)
  #expect(buy.cargoBefore == 0 && buy.cargoAfter == 1 && buy.stockAfter == buy.stockBefore - 1)
  #expect(buy.creditsAfter == buy.creditsBefore - buy.price)
  #expect(bought.commander.credits == fixture.initial.commander.credits - buy.price)
  #expect(bought.commander.cargo[fixture.commodity] == 1)
  #expect(bought.market[fixture.commodity].quantity == buy.stockAfter)
  #expect(bought.commander.sellableCargo(fixture.commodity) == 0)
  #expect(bought.commander.scriptState.savedClueJournal == nil)
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  #expect(pointer.schemaVersion == (alien ? 34 : 33))
  let restored = GameRuntime(game: Game(executive: false))
  try await restored.navigationTradeCommand(binding: fixture.binding) {
    $0.scriptPacks = [fixture.pack]
  }
  try await restored.loadNativeCommander(
    from: fixture.save, persistMigrations: false, navigationBinding: fixture.binding)
  let loaded = await restored.snapshot()
  #expect(
    loaded.commander.scriptState == bought.commander.scriptState && loaded.market == bought.market)
  #expect(
    loaded.commander.credits == bought.commander.credits
      && loaded.commander.cargo == bought.commander.cargo)
  #expect(
    loaded.commander.fuel == bought.commander.fuel
      && loaded.commander.equipmentOwnerID == bought.commander.equipmentOwnerID)
  #expect(loaded.nativeMainStationDockEvidenceIsCurrent)
  try await fixture.travel(restored, to: fixture.binding.destination.system.id)
  let arrived = await restored.snapshot()
  let travelled = try #require(arrived.commander.scriptState.instances[id]?.savedNavigationTrade)
  try #require(travelled.routeVerified && travelled.journeys.count == 1)
  #expect(travelled.stage == .held && arrived.commander.scriptState.savedClueJournal == nil)
  try await fixture.sell(restored)
  let sold = await restored.snapshot()
  let sale = try #require(sold.commander.scriptState.instances[id]?.savedNavigationTrade?.sale)
  #expect(sale.cargoAfter == sale.cargoBefore - 1 && sale.stockAfter == sale.stockBefore + 1)
  #expect(sale.creditsAfter == sale.creditsBefore + sale.price && sale.price < buy.price)
  #expect(sold.commander.credits == arrived.commander.credits + sale.price)
  #expect(sold.commander.cargo[fixture.commodity] == arrived.commander.cargo[fixture.commodity] - 1)
  #expect(sold.market[fixture.commodity].quantity == arrived.market[fixture.commodity].quantity + 1)
  #expect(sold.commander.scriptState.instances[id]?.outcome == .active)
  #expect(sold.commander.scriptState.savedClueJournal == nil)
  // Premature destination reception refuses safely.
  try await fixture.confirm(restored, id: id, choice: "receive")
  let premature = await restored.snapshot()
  #expect(
    premature.commander.credits == sold.commander.credits
      && premature.commander.cargo == sold.commander.cargo)
  #expect(premature.commander.scriptState.instances[id]?.savedNavigationTrade?.sale == sale)
  #expect(premature.commander.scriptState.instances[id]?.suspension == nil)
  #expect(premature.commander.scriptState.savedClueJournal == nil)
  let fuelBefore = premature.commander
  try await fixture.refuel(restored)
  let fuelAfter = await restored.snapshot().commander
  let paid = fuelBefore.credits - fuelAfter.credits
  try #require(paid > 0 && fuelAfter.fuel > fuelBefore.fuel)
  try await fixture.travel(restored, to: fixture.binding.training.system.id)
  let returned = await restored.snapshot()
  let ready = try #require(returned.commander.scriptState.instances[id]?.savedNavigationTrade)
  #expect(ready.stage == .sold && ready.journeys.count == 2)
  #expect(ready.fuelPaid == paid && ready.fuelPurchases.count == 1)
  #expect(
    ready.fuelUnitsUsed == bought.commander.fuel + (fuelAfter.fuel - fuelBefore.fuel)
      - returned.commander.fuel)
  #expect(ready.cashDifference == sale.price - buy.price - paid)
  #expect(ready.cashDifference == returned.commander.credits - fixture.initial.commander.credits)
  let beforeReception = returned.commander.credits
  try await fixture.confirm(restored, id: id, choice: "receive")
  let complete = await restored.snapshot()
  let record = try #require(complete.commander.scriptState.instances[id]?.savedNavigationTrade)
  let journal = try #require(complete.commander.scriptState.savedClueJournal)
  #expect(
    record.stage == .received && complete.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(complete.commander.credits == beforeReception)  // Reception invents no reward or profit.
  #expect(journal.progress.collectedClueIDs == ["navigation-trade-family-trace"])
  #expect(
    journal.awards[ScriptNavigationTradeContent.sourceID]?.completion
      == complete.commander.scriptState.instances[id]?.completionReceipt)
  let cold = GameRuntime(game: Game(executive: false))
  try await cold.loadNativeCommander(
    from: fixture.save, persistMigrations: false, navigationBinding: fixture.binding)
  let retained = await cold.snapshot()
  #expect(retained.commander.scriptState == complete.commander.scriptState)
  #expect(
    retained.commander.credits == complete.commander.credits
      && retained.commander.cargo == complete.commander.cargo)
  #expect(retained.commander.fuel == complete.commander.fuel)
  // No installed source required.
  #expect(retained.commander.scriptState.savedClueJournal == journal)
  // A completed tutorial without its atomically awarded journal is not a valid 33/34 save.
  let completePointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let generation = try ScriptSaveStore.generationDirectory(
    completePointer.generation, from: fixture.save)
  let missions = generation.appendingPathComponent("missions.json")
  let originalMissions = try Data(contentsOf: missions)
  let missingJournal = try rewriteNavigationTradeChunk(
    save: fixture.save, pointer: completePointer, name: "missions.json"
  ) { original in
    var root = original
    root.removeValue(forKey: "savedClueJournal")
    return root
  }
  #expect(throws: SaveError.self) {
    try ScriptSaveStore.read(missingJournal, from: fixture.save, navigationBinding: fixture.binding)
  }
  try originalMissions.write(to: missions)
  let ordinary = GameRuntime(game: Game(executive: false))
  try await ordinary.load(from: fixture.save)
  let productionReload = await ordinary.snapshot()
  #expect(productionReload.commander.scriptState == complete.commander.scriptState)
  // A new real instance may coexist with the retained first-success journal, without re-awarding it.

  try await fixture.refuel(restored)
  let current = await restored.snapshot()
  let stocked = try #require(
    Commodity.all.indices.first {
      Commodity.all[$0].unit == "t" && ![3, 6, 10, 16].contains($0)
        && current.market[$0].quantity > 0
    })
  let retry = try await fixture.acceptAndConfirm(restored, selectedCommodity: stocked)
  let repeated = await restored.snapshot()
  #expect(retry != id && repeated.commander.scriptState.savedClueJournal == journal)
  #expect(
    repeated.commander.scriptState.instances[retry]?.savedNavigationTrade?.stage == .awaitingBuy)
  let activeWithJournal = GameRuntime(game: Game(executive: false))
  try await activeWithJournal.navigationTradeCommand(binding: fixture.binding) {
    $0.scriptPacks = [fixture.pack]
  }
  try await activeWithJournal.loadNativeCommander(
    from: fixture.save, persistMigrations: false, navigationBinding: fixture.binding)
  let active = await activeWithJournal.snapshot()
  #expect(active.commander.scriptState == repeated.commander.scriptState)
  #expect(active.commander.scriptState.savedClueJournal == journal)
  let publicProgress = await activeWithJournal.baseClueProgress()
  // Internal fixture bindings never certify original-world public progress.
  #expect(publicProgress == .empty)
}

@Test(arguments: ["buy", "sale", "fuel", "reception"])
func navigationTradeFilesystemFailureRollsBackRealMutationEvidenceAndClue(boundary: String)
  async throws
{
  let fixture = try ScriptNavigationTradeFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.initial, saveURL: fixture.save)
  try await fixture.dock(runtime)
  let id = try await fixture.acceptAndConfirm(runtime)
  if boundary != "buy" {
    try await fixture.buy(runtime)
    try await fixture.travel(runtime, to: fixture.binding.destination.system.id)
  }
  if boundary == "reception" {
    try await fixture.sell(runtime)
    try await fixture.refuel(runtime)
    try await fixture.travel(runtime, to: fixture.binding.training.system.id)
  }
  let before = await runtime.snapshot()
  let published = try Data(contentsOf: fixture.save)
  let retainedDirectory = fixture.root.appendingPathComponent("retained-save", isDirectory: true)
  try FileManager.default.moveItem(
    at: fixture.save.deletingLastPathComponent(), to: retainedDirectory)
  try Data("blocked parent".utf8).write(to: fixture.save.deletingLastPathComponent())
  do {
    switch boundary {
    case "buy": try await fixture.buy(runtime)
    case "sale": try await fixture.sell(runtime)
    case "fuel": try await fixture.refuel(runtime)
    default: try await fixture.confirm(runtime, id: id, choice: "receive")
    }
    Issue.record("The actual blocked-parent filesystem publication unexpectedly succeeded.")
  } catch {
    let error = error as NSError
    #expect(error.domain == NSPOSIXErrorDomain || error.domain == NSCocoaErrorDomain)
  }
  let after = await runtime.snapshot()
  #expect(after.commander == before.commander && after.market == before.market)
  #expect(after.bodies == before.bodies && after.screen == before.screen)
  #expect(after.commander.scriptState.savedClueJournal == nil)
  let retainedBytes = try Data(
    contentsOf: retainedDirectory.appendingPathComponent("commander.json"))
  #expect(retainedBytes == published)
}

@Test(arguments: ["capacity", "stock", "illegal"])
func navigationPracticeRefusesUnconfirmedFittingStockOrIllegalCommodity(reason: String) async throws
{
  let fixture = try ScriptNavigationTradeFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.initial, saveURL: fixture.save)
  try await fixture.dock(runtime)
  let id = try await fixture.accept(runtime)
  try await runtime.navigationTradeCommand(binding: fixture.binding) { game in
    switch reason {
    case "capacity":
      game.commander.cargo[fixture.commodity == 0 ? 1 : 0] = game.commander.tradeCargoCapacity
    case "stock": game.market[fixture.commodity].quantity = 0
    default: game.selection = 3
    }
  }
  let before = await runtime.snapshot()
  let rejectedInput = try await fixture.confirm(runtime, id: id)
  let refused = await runtime.snapshot()
  #expect(
    refused.commander.credits == before.commander.credits
      && refused.commander.cargo == before.commander.cargo)
  #expect(refused.market == before.market)
  #expect(refused.commander.scriptState.instances[id]?.savedNavigationTrade == nil)
  #expect(refused.commander.scriptState.instances[id]?.outcome == .active)
  #expect(refused.commander.scriptState.savedClueJournal == nil)
  #expect(refused.commander.scriptState.instances[id]?.suspension == nil)
  if reason == "capacity" {
    // A real ordinary sale frees one slot; a fresh confirmation reserves and then transfers it.
    try await runtime.navigationTradeCommand(binding: fixture.binding) { game in
      game.selection = fixture.commodity == 0 ? 1 : 0
      game.screen = .sell
      game.key("return")
      game.selection = fixture.commodity
    }
    let freed = await runtime.snapshot()
    let replay = try #require(rejectedInput)
    try await runtime.navigationTradeCommand(binding: fixture.binding) { game in
      game.commander.scriptState.pendingEvents.append(replay)
      game.drainScriptEvents(navigationBinding: fixture.binding)
    }
    let replayed = await runtime.snapshot()
    #expect(replayed.commander == freed.commander && replayed.market == freed.market)
    #expect(replayed.commander.scriptState.instances[id]?.suspension == nil)
    try await fixture.confirm(runtime, id: id)
    let reserved = await runtime.snapshot()
    #expect(reserved.commander.cargo[fixture.commodity] == 0)
    #expect(reserved.commander.cargoTonnes == reserved.commander.tradeCargoCapacity)
    #expect(
      reserved.commander.credits == freed.commander.credits && reserved.market == freed.market)
    try await fixture.buy(runtime)
    let bought = await runtime.snapshot()
    #expect(bought.commander.cargo[fixture.commodity] == 1)
    #expect(bought.commander.cargoTonnes == reserved.commander.cargoTonnes)
    #expect(bought.commander.scriptState.instances[id]?.savedNavigationTrade?.stage == .held)
    #expect(bought.commander.scriptState.payloadTonnes == 0 && bought.commander.valid)
  }
}

@Test func navigationPracticeCancellationAndActualEscapeLossNeverRecreateStockOrSuccess()
  async throws
{
  let fixture = try ScriptNavigationTradeFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.initial, saveURL: fixture.save)
  let id = try await fixture.ready(runtime)
  let bought = await runtime.snapshot()
  try await fixture.confirm(runtime, id: id, choice: "cancel")
  let cancelled = await runtime.snapshot()
  #expect(
    cancelled.commander.credits == bought.commander.credits && cancelled.market == bought.market)
  #expect(
    cancelled.commander.cargo == bought.commander.cargo
      && cancelled.commander.sellableCargo(fixture.commodity) == 1)
  #expect(cancelled.commander.scriptState.instances[id]?.outcome == .abandoned)
  #expect(cancelled.commander.scriptState.savedClueJournal == nil)
  // Actual ordinary sale, not tutorial restoration of source stock.
  try await fixture.sell(runtime)
  let retry = try await fixture.acceptAndConfirm(runtime)
  try await fixture.buy(runtime)
  let beforeLoss = await runtime.snapshot()
  try await runtime.navigationTradeCommand(binding: fixture.binding) { game in
    game.launch()
    game.escapePod()
  }
  let lost = await runtime.snapshot()
  #expect(lost.docked && lost.commander.cargo[fixture.commodity] == 0)
  #expect(lost.commander.scriptState.instances[retry]?.savedNavigationTrade?.stage == .lost)
  #expect(lost.market == beforeLoss.market && lost.commander.scriptState.savedClueJournal == nil)
  // Obtain a replacement through the real market: loss evidence cannot be revived from cargo balance.

  try await fixture.buy(runtime)
  let replaced = await runtime.snapshot()
  #expect(replaced.commander.cargo[fixture.commodity] == 1)
  #expect(replaced.commander.scriptState.instances[retry]?.savedNavigationTrade?.stage == .lost)
  try await runtime.navigationTradeCommand(binding: fixture.binding) { $0.launch() }
  try await fixture.dock(runtime)
  let beforeReport = await runtime.snapshot()
  try await fixture.confirm(runtime, id: retry)
  let failed = await runtime.snapshot()
  #expect(failed.commander.scriptState.instances[retry]?.outcome == .failed)
  #expect(
    failed.commander.scriptState.instances[retry]?.savedNavigationTrade?.loss
      == lost.commander.scriptState.instances[retry]?.savedNavigationTrade?.loss)
  #expect(
    failed.commander.credits == beforeReport.commander.credits
      && failed.commander.cargo == beforeReport.commander.cargo)
  #expect(failed.commander.scriptState.savedClueJournal == nil)
  // Closed actual loss history must not bind a new galaxy's practice endpoint selection.
  // This is explicit selection-policy setup, not a claim of another native journey.
  var elsewhere = failed
  elsewhere.commander.galaxy = 1
  elsewhere.systems = Universe.systemsIncludingPlugh(number: 1)
  elsewhere.commander.system = 7
  elsewhere.selectedSystem = 8
  let fresh = try #require(ScriptNavigationTradeBinding.production(in: elsewhere))
  #expect(fresh.valid && fresh.matches(elsewhere))
  #expect(fresh.training.galaxy == 1 && fresh.destination.galaxy == 1)
  #expect(
    fresh.training.system == elsewhere.currentSystem
      && fresh.destination.system == elsewhere.targetSystem)
  #expect(elsewhere.navigationTradeUnavailable(fixture.pack, binding: fresh) == nil)
  #expect(
    elsewhere.commander.scriptState.instances[retry]
      == failed.commander.scriptState.instances[retry])
  #expect(
    elsewhere.commander.scriptState.instances[retry]?.savedNavigationTrade?.loss
      == lost.commander.scriptState.instances[retry]?.savedNavigationTrade?.loss)
}

@Test func navigationPracticeWrongActualDestinationAndInventedEventCannotSupplyTheSelectedSale()
  async throws
{
  let fixture = try ScriptNavigationTradeFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.initial, saveURL: fixture.save)
  let id = try await fixture.ready(runtime)
  let source = await runtime.snapshot()
  let wrong = try #require(
    source.knownSystems.first {
      $0.id != source.commander.system && $0.id != fixture.binding.destination.system.id
        && source.currentSystem.distance(to: $0) > 0
        && source.currentSystem.distance(to: $0) <= source.commander.maximumJumpDistance
    })
  try await fixture.travel(runtime, to: wrong.id)
  let arrived = await runtime.snapshot()
  try await fixture.sell(runtime)
  try await runtime.navigationTradeCommand(binding: fixture.binding) { game in
    game.emitScriptEvent(
      "market.traded",
      values: [
        "commodity": .integer(Int64(fixture.commodity)),
        "destination": .integer(Int64(fixture.binding.destination.system.id)),
      ], only: id, drain: false)
    game.drainScriptEvents(navigationBinding: fixture.binding)
  }
  let refused = await runtime.snapshot()
  #expect(
    refused.commander.credits == arrived.commander.credits
      && refused.commander.cargo == arrived.commander.cargo)
  #expect(refused.commander.scriptState.instances[id]?.savedNavigationTrade?.sale == nil)
  #expect(refused.commander.scriptState.instances[id]?.savedNavigationTrade?.routeVerified == false)
  #expect(refused.commander.scriptState.instances[id]?.outcome == .active)
  #expect(refused.commander.scriptState.savedClueJournal == nil)
}
