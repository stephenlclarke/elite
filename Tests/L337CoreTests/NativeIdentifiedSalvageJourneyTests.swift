import Foundation
import Testing

@testable import L337Core

struct NativeIdentifiedSalvageFixture {
  let base: NativeStationJourneyFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { base.files }
  var save: URL { base.save }

  init() throws {
    base = try NativeStationJourneyFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledIdentifiedSalvageDirectory)
  }

  func runtime(tools: Bool = true, freeTonnes: Int? = nil, escapeReady: Bool = false) async throws
    -> GameRuntime
  {
    let runtime = try await base.runtime(cabins: 0, escapeReady: escapeReady)
    await runtime.nativeCommand { $0.scriptPacks = [pack] }
    if tools {
      for name in ["Fuel Scoops", "Targeting: Salvage Module"] {
        try await runtime.buyIdentifiedSalvageEquipment(name)
      }
    }
    if let freeTonnes {
      // Controlled ordinary initial cargo only; every protected slot still comes from native acceptance.
      await runtime.nativeCommand { game in
        game.commander.cargo[0] +=
          game.commander.standardCargoCapacity - game.commander.cargoTonnes - freeTonnes
      }
    }
    try await runtime.save(to: save)
    return runtime
  }

  func review(_ runtime: GameRuntime, _ action: NativeIdentifiedSalvageAction) async throws
    -> ScriptPagePresentation
  {
    await runtime.key("contracts-open")
    let game = await runtime.snapshot()
    let index = try #require(game.contractBoard.rows.firstIndex { $0.identifiedSalvage == action })
    for _ in 0..<abs(index - game.contractBoard.selection) {
      await runtime.key(index < game.contractBoard.selection ? "up" : "down")
    }
    let page = await runtime.snapshot().scriptPagePresentation
    await runtime.scriptPageKey("return", expected: page)
    try #require(await runtime.snapshot().contractBoard.identifiedSalvageQuote?.action == action)
    return await runtime.snapshot().scriptPagePresentation
  }

  func confirm(_ runtime: GameRuntime, _ action: NativeIdentifiedSalvageAction) async throws {
    let page = try await review(runtime, action)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
  }

  func state(_ runtime: GameRuntime) async throws -> NativeIdentifiedSalvageState {
    try #require(await runtime.snapshot().identifiedSalvageState)
  }

  func accept(_ runtime: GameRuntime) async throws -> NativeIdentifiedSalvageState {
    try await confirm(runtime, .accept)
    return try await state(runtime)
  }

  func renas(_ runtime: GameRuntime) async throws {
    try await base.flight.travel(runtime, path: [7, 185])
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.05)
    let state = try await state(runtime)
    let encounter = try #require(
      await runtime.snapshot().commander.scriptState.instances[
        state.permission.mission]?.ownedEncounters[NativeIdentifiedSalvage.encounterID])
    try #require(encounter.admitted && encounter.actors.count == 3)
  }

  func approach(_ runtime: GameRuntime, ordinal: Int, offset: Vector3 = .init(0, -45, 55))
    async throws
  {
    if await runtime.snapshot().screen != .front { await runtime.key("0") }
    let state = try await state(runtime)
    let logical = NativeIdentifiedSalvage.actorIdentity(
      mission: state.permission.mission, digest: pack.digest,
      alias: NativeIdentifiedSalvage.aliases[ordinal])
    await runtime.nativeCommand { game in
      guard let body = game.bodies.first(where: { $0.missionActorID == logical }) else { return }
      var pose = game.commander.flightSimulation.pose
      let center = pose.systemPoint(body.position)
      pose.position = center - pose.orientation.apply(offset)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 0
      game.pitch = 0
      game.yaw = 0
      game.roll = 0
    }
    let game = await runtime.snapshot()
    let body = try #require(game.bodies.first { $0.missionActorID == logical })
    try #require(game.identifiedSalvageCollision(body)?.mass == 1000)
    if offset == Vector3(0, -45, 55) {
      let context = try #require(game.gameplayContext())
      try #require(game.automaticScoopShapeCompatible(body, context: context))
    }
  }

  func collect(_ runtime: GameRuntime, ordinal: Int) async throws {
    try await approach(runtime, ordinal: ordinal)
    _ = await runtime.advance(delta: 0.05)
    let state = try await state(runtime)
    let source = try #require(
      await runtime.snapshot().commander.scriptState.savedIdentifiedSalvageSource)
    try #require(state.captures.contains { $0.original == source.originals[ordinal].id })
  }

  func returnHome(_ runtime: GameRuntime) async throws {
    try await base.flight.dock(runtime)
    await runtime.procurementRefuel()
    try await base.flight.travel(runtime, path: [185, 7])
  }
}

extension GameRuntime {
  func buyIdentifiedSalvageEquipment(_ name: String) throws {
    try scriptCommand { game in
      let item = try #require(Equipment.all.first { $0.name == name })
      let quote = try game.quoteEquipmentPurchase(item)
      let bought = try game.applyEquipmentPurchase(quote)
      try #require(bought)
    }
  }
}

struct NativeIdentifiedSalvageJourneyTests {
  @Test(arguments: [0, 1])
  func depotRefusesInsufficientActualHoldWithoutAllocatingOriginals(freeTonnes: Int) async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(freeTonnes: freeTonnes)
    let before = await runtime.snapshot().commander
    let page = try await f.review(runtime, .accept)
    #expect(await runtime.snapshot().contractBoard.action == .back)
    #expect(await runtime.snapshot().contractBoard.identifiedSalvageQuote?.allowed == false)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().commander.scriptState.savedIdentifiedSalvageSource == nil)
  }

  @Test(arguments: ["core", "module", "scoops"])
  func depotRequiresActualFittedRecoveryTools(tool: String) async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    await runtime.nativeCommand { game in
      let slot: ComponentFittingSlot =
        tool == "core"
        ? .targetingCore
        : tool == "module" ? .targetingSalvage : .utility(.fuelScoops)
      if let item = game.commander.fittedEquipment(at: slot) {
        _ = try? game.commander.removeFittedEquipment(item.node.key)
      }
    }
    #expect(await runtime.snapshot().identifiedSalvageReview(.accept).allowed == false)
    #expect(await runtime.snapshot().identifiedSalvageState == nil)
  }

  @Test func actualTwoOriginalJourneyReservesOnceAndPaysOnlyAtSameOwner() async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(freeTonnes: 2)
    let before = await runtime.snapshot().commander
    let page = try await f.review(runtime, .accept)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    let accepted = try await f.accept(runtime)
    let source = try #require(
      await runtime.snapshot().commander.scriptState.savedIdentifiedSalvageSource)
    #expect(source.originals.map(\.serial) == ["PELL-01", "PELL-02"])
    #expect(source.owner.system == SystemIdentity(galaxy: 0, system: 7))
    #expect(accepted.captures.isEmpty && accepted.held.isEmpty)
    #expect(await runtime.snapshot().commander.cargoTonnes == before.cargoTonnes + 2)
    #expect(await runtime.snapshot().commander.accommodation == before.accommodation)
    try await f.renas(runtime)
    for ordinal in [1, 0] {
      try await f.collect(runtime, ordinal: ordinal)
      let game = await runtime.snapshot()
      #expect(game.commander.cargoTonnes == before.cargoTonnes + 2)
      #expect(game.commander.cargo == before.cargo)
      #expect(game.commander.scriptState.savedClueJournal == nil)
      #expect(game.identifiedSalvageReview(.receive).allowed == false)
    }
    let collected = try await f.state(runtime)
    #expect(Set(collected.held) == Set(source.originals.map(\.id)))
    #expect(Set(collected.captures.map(\.actor)).count == 2)
    try await f.returnHome(runtime)
    let cash = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .receive)
    let done = await runtime.snapshot()
    #expect(done.commander.credits == cash + 8800)
    #expect(done.commander.cargoTonnes == before.cargoTonnes)
    #expect(done.identifiedSalvageState?.held.isEmpty == true)
    #expect(done.identifiedSalvageState?.reception?.originals == source.originals.map(\.id))
    #expect(done.commander.scriptState.instances[accepted.permission.mission]?.outcome == .complete)
    #expect(
      done.commander.scriptState.savedClueJournal?.awards[NativeIdentifiedSalvage.stateID] != nil)
    #expect(done.commander.scriptState.savedIdentifiedSalvageSource?.id == source.id)
    #expect(
      done.commander.scriptState.savedIdentifiedSalvageSource?.allocatedMission
        == source.allocatedMission)
    #expect(done.identifiedSalvageRows.isEmpty)
    try await runtime.save(to: f.save)
    let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(cold == done.commander && world.consistent(with: cold))
  }

  @Test(arguments: [0, 1])
  func actualOwnerCancellationReturnsOnlyHeldOriginalsAndNeverRestocks(pickups: Int) async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let before = await runtime.snapshot().commander
    let accepted = try await f.accept(runtime)
    let source = try #require(
      await runtime.snapshot().commander.scriptState.savedIdentifiedSalvageSource)
    if pickups > 0 {
      try await f.renas(runtime)
      try await f.collect(runtime, ordinal: 0)
      #expect(await runtime.snapshot().identifiedSalvageReview(.cancel).allowed == false)
      try await f.returnHome(runtime)
    }
    let cash = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .cancel)
    let done = await runtime.snapshot()
    #expect(done.commander.credits == cash)
    #expect(done.commander.cargoTonnes == before.cargoTonnes)
    #expect(done.identifiedSalvageState?.reception?.originals.count == pickups)
    #expect(
      done.commander.scriptState.instances[accepted.permission.mission]?.outcome == .abandoned)
    #expect(done.commander.scriptState.savedClueJournal == nil)
    await runtime.nativeCommand { $0.scriptPacks = [] }
    await runtime.nativeCommand { $0.scriptPacks = [f.pack] }
    #expect(
      await runtime.snapshot().commander.scriptState.savedIdentifiedSalvageSource?.id == source.id)
    #expect(
      await runtime.snapshot().commander.scriptState.savedIdentifiedSalvageSource?.allocatedMission
        == source.allocatedMission)
    #expect(await runtime.snapshot().identifiedSalvageRows.isEmpty)
  }

  @Test func nativeAllocationAndReceptionWriterRefusalAreAtomicAndRetryOnce() async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    var page = try await f.review(runtime, .accept)
    await runtime.scriptPageKey("right", expected: page)
    var before = await runtime.snapshot().commander
    var files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    var held = try f.files.blockWrites("pell-accept")
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try f.files.restoreWrites(held, files: files)
    _ = try await f.accept(runtime)
    try await f.renas(runtime)
    try await f.collect(runtime, ordinal: 0)
    try await f.collect(runtime, ordinal: 1)
    try await f.returnHome(runtime)
    page = try await f.review(runtime, .receive)
    await runtime.scriptPageKey("right", expected: page)
    before = await runtime.snapshot().commander
    files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    held = try f.files.blockWrites("pell-receive")
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try f.files.restoreWrites(held, files: files)
    try await f.confirm(runtime, .receive)
    let done = await runtime.snapshot().commander
    #expect(done.credits == before.credits + 8800)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == done)
  }
}
