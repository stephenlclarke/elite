import Foundation
import Testing

@testable import EliteCore

private struct NavigationTradeDeliveryFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack
  var save: URL { files.save }
  init() throws {
    files = try ScriptFreightFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledNavigationTradeDirectory)
  }
  func runtime() async throws -> GameRuntime {
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    let errors = await runtime.loadDefaultScriptPacks(
      directory: files.root.appendingPathComponent("empty-installed"))
    try #require(errors.isEmpty)
    await runtime.key("0")
    try await dock(runtime)
    return runtime
  }
  // Standard near-door scene setup supplies no endpoint, journey, trade or docking receipt.
  // Real swept station entry below creates the current native dock evidence.
  func dock(_ runtime: GameRuntime) async throws {
    await runtime.nativeCommand { game in
      guard let station = game.bodies.first(where: { $0.id == 0 && $0.hull == .station }) else {
        return
      }
      let old = game.commander.flightSimulation.pose
      var pose = ShipPose()
      pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
      pose.orientation.y = old.orientation.apply(station.entranceUp)
      pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
      pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 3
      for _ in 0..<100 where !game.docked { game.tick(delta: 0.1) }
    }
    let game = await runtime.snapshot()
    try #require(game.docked && game.nativeMainStationDockEvidenceIsCurrent)
  }
  func selectRouteAndCommodity(_ runtime: GameRuntime) async throws -> (Int, Int) {
    let game = await runtime.snapshot()
    let choices = game.knownSystems.filter {
      let distance = game.currentSystem.distance(to: $0)
      return $0.id != game.commander.system && distance > 0
        && distance <= game.commander.maximumJumpDistance
        && game.commander.jumpFuelCost(distance: distance) * 2 <= game.commander.fuel
    }.flatMap { destination in
      Commodity.all.indices.compactMap { index -> (StarSystem, Int)? in
        guard Commodity.all[index].unit == "t", ![3, 6, 10, 16].contains(index),
          game.commander.cargo[index] == 0, game.market[index].quantity > 0,
          game.market[index].price <= game.commander.availableCredits / 2
        else { return nil }
        return (destination, index)
      }
    }
    let (destination, commodity) = try #require(choices.first)
    await runtime.key("screen:4")
    await runtime.selectSystem(x: Double(destination.x), y: Double(destination.y))
    await runtime.key("screen:7")
    for _ in 0..<commodity { await runtime.key("down") }
    let selected = await runtime.snapshot()
    try #require(selected.selectedSystem == destination.id && selected.selection == commodity)
    try #require(ScriptNavigationTradeBinding.production(in: selected) != nil)
    return (destination.id, commodity)
  }
  func accept(_ runtime: GameRuntime) async throws -> UUID {
    await runtime.key("contacts-open")
    try #require(await runtime.snapshot().scriptAvailablePackDigest == pack.digest)
    await runtime.key("return")
    let game = await runtime.snapshot()
    return try #require(
      game.commander.scriptState.instances.values.first {
        $0.definition == ScriptNavigationTradeContent.sourceID && $0.outcome == .active
      }?.id)
  }
  func contact(_ runtime: GameRuntime, choice: String? = nil) async throws {
    await runtime.key("contacts-open")
    let shown = await runtime.snapshot()
    try #require(shown.scriptOffer != nil && shown.scriptPresentedDialogue != nil)
    if let choice {
      let index = try #require(shown.offeredScriptChoices.firstIndex { $0.id == choice })
      for _ in 0..<index { await runtime.key("down") }
    }
    if !shown.scriptConfirmSelected { await runtime.key("right") }
    await runtime.key("return")
  }
  func market(_ runtime: GameRuntime, commodity: Int, buying: Bool) async {
    await runtime.key("screen:7")
    for _ in 0..<commodity { await runtime.key("down") }
    await runtime.key(buying ? "right" : "left")
  }
  func travel(_ runtime: GameRuntime, to destination: Int) async throws {
    await runtime.key("0")
    await runtime.nativeCommand { game in
      // Fixture clearance changes no world/visit/fuel/calendar evidence. H and countdown own travel.
      var pose = game.commander.flightSimulation.pose
      pose.position = pose.position + pose.orientation.x * 20_000
      NativeStationTestFixture.reframe(&game, to: pose)
    }
    let game = await runtime.snapshot()
    await runtime.selectSystem(
      x: Double(game.systems[destination].x), y: Double(game.systems[destination].y))
    await runtime.key("h")
    let admitted = await runtime.snapshot()
    try #require(admitted.jumpCountdown != nil)
    for _ in 0..<200 {
      if await runtime.snapshot().jumpCountdown == nil { break }
      _ = await runtime.advance(delta: 0.1)
    }
    try #require(await runtime.snapshot().commander.system == destination)
    try await dock(runtime)
  }
}

struct OriginalNavigationTradeDeliveryTests {
  @Test func bundledTutorialCopiesExactApprovedBytesAndDeduplicatesWithoutManualInstallation()
    throws
  {
    let fixture = try NavigationTradeDeliveryFixture()
    defer { fixture.files.clean() }
    let docs = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/l337-navigation-trade")
    for name in ["manifest.toml", "scripts/main.lua", "README.md"] {
      #expect(
        try Data(contentsOf: docs.appendingPathComponent(name))
          == Data(
            contentsOf: ScriptPackLibrary.bundledNavigationTradeDirectory.appendingPathComponent(
              name)))
    }
    #expect(fixture.pack.digest == ScriptNavigationTradeContent.digest)
    #expect(fixture.pack.manifest.version == "1.0.0" && fixture.pack.missingCapabilities.isEmpty)
    let installed = fixture.files.root.appendingPathComponent("installed")
    _ = try ScriptPackLibrary.install(fixture.pack, directory: installed)
    let library = ScriptPackLibrary.defaultLibrary(directory: installed)
    #expect(
      library.errors.isEmpty && library.packs.filter { $0.digest == fixture.pack.digest }.count == 1
    )
    #expect(library.packs.first?.digest == fixture.pack.digest)
    #expect(throws: (any Error).self) {
      try ScriptPackLibrary.read(fixture.files.root.appendingPathComponent("missing-pack"))
    }
  }

  @Test func selfDestinationShowsActionableChartHintWithoutCreatingAnEndpointOrMission()
    async throws
  {
    let fixture = try NavigationTradeDeliveryFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let current = await runtime.snapshot().currentSystem
    await runtime.selectSystem(x: Double(current.x), y: Double(current.y))
    let before = await runtime.snapshot()
    let reason = try #require(before.scriptUnavailable(fixture.pack))
    #expect(
      reason.contains("Select a different reachable original-world destination")
        && reason.contains("Mission Contacts"))
    var refused = before
    #expect(throws: (any Error).self) { try refused.acceptScriptMission(fixture.pack) }
    #expect(refused.commander == before.commander && refused.market == before.market)
    var missing = before
    missing.systems = []
    #expect(
      missing.navigationTradeUnavailable(fixture.pack, binding: nil)?.contains(
        "Restore the installed original-world") == true)
    await runtime.key("gallery-open")
    #expect(
      await runtime.snapshot().scriptGallery.contains {
        $0.name == fixture.pack.manifest.mission.title && $0.status == .locked
      })
    #expect(await runtime.snapshot().commander == before.commander)
  }

  @Test func ordinaryDefaultContactsBuyFlySellAndReturnWithRealCostsAndColdReload() async throws {
    let fixture = try NavigationTradeDeliveryFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (destination, commodity) = try await fixture.selectRouteAndCommodity(runtime)
    let start = await runtime.snapshot()
    #expect(
      !start.isMissionTrial && !start.commander.unlimitedCash && !start.commander.unlimitedFuel)
    #expect(start.scriptPacks.contains { $0.digest == fixture.pack.digest })
    await runtime.key("gallery-open")
    #expect(
      await runtime.snapshot().scriptGallery.contains {
        $0.name == fixture.pack.manifest.mission.title && $0.status == .available
      })
    await runtime.key("escape")
    await runtime.key("contacts-open")
    try #require(await runtime.snapshot().scriptAvailablePackDigest == fixture.pack.digest)
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == start.commander)
    #expect(await runtime.snapshot().market == start.market)
    let id = try await fixture.accept(runtime)
    try await fixture.contact(runtime)
    try #require(
      await runtime.snapshot().commander.scriptState.instances[id]?.savedNavigationTrade?.stage
        == .awaitingBuy)
    await fixture.market(runtime, commodity: commodity, buying: true)
    let bought = await runtime.snapshot()
    let buy = try #require(bought.commander.scriptState.instances[id]?.savedNavigationTrade?.buy)
    #expect(buy.price == start.market[commodity].price && bought.commander.cargo[commodity] == 1)
    #expect(bought.commander.credits == start.commander.credits - buy.price)
    let cold = GameRuntime(game: Game(executive: false), saveURL: fixture.save)
    let errors = await cold.loadDefaultScriptPacks(
      directory: fixture.files.root.appendingPathComponent("empty-installed"))
    try #require(errors.isEmpty)
    try await cold.load(from: fixture.save, persistMigrations: false)
    if await cold.snapshot().paused { await cold.key("pause") }
    let loaded = await cold.snapshot()
    #expect(
      loaded.commander.scriptState.instances[id]?.savedNavigationTrade
        == bought.commander.scriptState.instances[id]?.savedNavigationTrade)
    #expect(
      loaded.scriptPack(for: try #require(loaded.commander.scriptState.instances[id]))?.digest
        == fixture.pack.digest)
    try await fixture.travel(cold, to: destination)
    await fixture.market(cold, commodity: commodity, buying: false)
    let sold = await cold.snapshot()
    let sale = try #require(sold.commander.scriptState.instances[id]?.savedNavigationTrade?.sale)
    #expect(sold.commander.scriptState.savedClueJournal == nil)
    #expect(sold.commander.credits == bought.commander.credits + sale.price)
    await cold.key("screen:3")
    let shop = await cold.snapshot()
    let fuel = try #require(Equipment.all.firstIndex { $0.name == "Fuel" })
    try #require(shop.selection == fuel)
    await cold.key("return")
    let refuelled = await cold.snapshot()
    let fuelPaid = sold.commander.credits - refuelled.commander.credits
    try #require(fuelPaid > 0 && refuelled.commander.fuel > sold.commander.fuel)
    try await fixture.travel(cold, to: start.commander.system)
    let returned = await cold.snapshot()
    let record = try #require(returned.commander.scriptState.instances[id]?.savedNavigationTrade)
    #expect(record.stage == .sold && record.routeVerified && record.journeys.count == 2)
    #expect(record.fuelPaid == fuelPaid && record.fuelUnitsUsed > 0)
    #expect(record.cashDifference == sale.price - buy.price - fuelPaid)
    #expect(returned.commander.credits - start.commander.credits == record.cashDifference)
    try await fixture.contact(cold, choice: "receive")
    let completed = await cold.snapshot()
    #expect(completed.commander.credits == returned.commander.credits)
    #expect(completed.commander.scriptState.instances[id]?.outcome == .complete)
    let award = try #require(
      completed.commander.scriptState.savedClueJournal?.awards[
        ScriptNavigationTradeContent.sourceID])
    #expect(award.clueID == "navigation-trade-family-trace" && award.completion.instance == id)
    #expect(completed.commander.scriptState.savedClueJournal?.awards.count == 1)
  }

  @Test func normalDefaultFittingWriterFailureRollsBackPlanAndOneRetryResumesCurrentSave()
    async throws
  {
    let fixture = try NavigationTradeDeliveryFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    _ = try await fixture.selectRouteAndCommodity(runtime)
    let id = try await fixture.accept(runtime)
    await runtime.key("contacts-open")
    try #require(await runtime.snapshot().scriptPresentedDialogue?.id == "fit")
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("fitting")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.market == before.market)
    #expect(refused.commander.scriptState.instances[id]?.savedNavigationTrade == nil)
    try fixture.files.restoreWrites(blocked, files: disk)
    if await runtime.snapshot().screen == .handoff { await runtime.key("escape") }
    try await fixture.contact(runtime)
    let confirmed = await runtime.snapshot()
    #expect(
      confirmed.commander.scriptState.instances[id]?.savedNavigationTrade?.stage == .awaitingBuy)
    #expect(
      confirmed.market == before.market && confirmed.commander.credits == before.commander.credits)
    #expect(confirmed.commander.scriptState.savedClueJournal == nil)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(
      await runtime.snapshot().commander.scriptState.instances[id]?.savedNavigationTrade
        == confirmed.commander.scriptState.instances[id]?.savedNavigationTrade)
  }
}
