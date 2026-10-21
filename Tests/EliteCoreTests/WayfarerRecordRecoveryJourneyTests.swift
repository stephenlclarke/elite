import Foundation
import Testing

@testable import EliteCore

struct WayfarerRecordRecoveryFixture {
  let flight: OriginalSealedDispatchFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { flight.files }
  var save: URL { files.save }

  init() throws {
    flight = try OriginalSealedDispatchFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledRecordRecoveryDirectory)
  }

  func runtime(freeTonnes: Int? = nil, tools: Bool = true, escapeReady: Bool = false)
    async throws -> GameRuntime
  {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    // Initial world/funds only; real launch, travel, docking and all purchases remain native.
    game.commander.system = 85
    game.selectedSystem = 85
    game.market = MarketItem.at(game.currentSystem)
    game.commander.credits = 300000
    try game.prepareG03FlightEquipment()
    var equipment = tools ? ["Fuel Scoops", "Targeting: Salvage Module"] : []
    if escapeReady { equipment.append("Escape Pod") }
    for name in equipment {
      let item = try #require(Equipment.all.first { $0.name == name })
      let quote = try game.quoteEquipmentPurchase(item)
      let bought = try game.applyEquipmentPurchase(quote)
      try #require(bought)
    }
    game.scriptPacks = [pack]
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await flight.dock(runtime)
    if let freeTonnes {
      await runtime.nativeCommand { game in
        game.commander.cargo[0] +=
          game.commander.standardCargoCapacity - game.commander.cargoTonnes - freeTonnes
      }
      let actual = await runtime.snapshot().commander
      try #require(actual.standardCargoCapacity - actual.cargoTonnes == freeTonnes)
    }
    return runtime
  }

  func review(_ runtime: GameRuntime, _ action: WayfarerRecordRecoveryAction) async throws
    -> ScriptPagePresentation
  {
    await runtime.key("contracts-open")
    let game = await runtime.snapshot()
    let index = try #require(game.contractBoard.rows.firstIndex { $0.recordRecovery == action })
    for _ in 0..<abs(index - game.contractBoard.selection) {
      await runtime.key(index < game.contractBoard.selection ? "up" : "down")
    }
    let page = await runtime.snapshot().scriptPagePresentation
    await runtime.scriptPageKey("return", expected: page)
    try #require(await runtime.snapshot().contractBoard.action == .back)
    return await runtime.snapshot().scriptPagePresentation
  }

  func confirm(_ runtime: GameRuntime, _ action: WayfarerRecordRecoveryAction) async throws {
    let page = try await review(runtime, action)
    try #require(await runtime.snapshot().contractBoard.recordRecoveryQuote?.allowed == true)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
  }

  func state(_ runtime: GameRuntime) async throws -> WayfarerRecordRecoveryState {
    try #require(await runtime.snapshot().recordRecoveryState)
  }

  @discardableResult
  func accept(_ runtime: GameRuntime) async throws -> WayfarerRecordRecoveryState {
    try await confirm(runtime, .accept)
    return try await state(runtime)
  }

  func celalen(_ runtime: GameRuntime) async throws {
    try await flight.travel(runtime, path: [85, 241])
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.05)
    let source = try await state(runtime)
    let game = await runtime.snapshot()
    let encounter = try #require(
      game.commander.scriptState.instances[
        source.permission.mission]?.ownedEncounters[WayfarerRecordRecovery.encounterID])
    try #require(!game.docked && encounter.admitted && encounter.actors.count == 2)
  }

  func logical(_ state: WayfarerRecordRecoveryState, alias: String = "cdr-001") -> UUID {
    WayfarerRecordRecovery.actorIdentity(
      mission: state.permission.mission, digest: pack.digest, alias: alias)
  }

  func frame(_ runtime: GameRuntime, offset: Vector3) async throws {
    if await runtime.snapshot().screen != .front { await runtime.key("0") }
    let source = try await state(runtime)
    let identity = logical(source)
    await runtime.nativeCommand { game in
      guard let body = game.bodies.first(where: { $0.missionActorID == identity }) else { return }
      var pose = game.commander.flightSimulation.pose
      pose.position = pose.systemPoint(body.position) - pose.orientation.apply(offset)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 0
      game.pitch = 0
      game.yaw = 0
      game.roll = 0
    }
    let game = await runtime.snapshot()
    let body = try #require(game.bodies.first { $0.missionActorID == identity })
    try #require(game.recordRecoveryCollision(body)?.mass == 1000)
  }

  func aim(_ runtime: GameRuntime, distance: Double = 1000) async throws {
    try await frame(runtime, offset: .init(0, 0, distance))
    let identity = logical(try await state(runtime))
    for _ in 0..<4 {
      if await runtime.snapshot().workTargetFilter == .salvage { break }
      await runtime.key("f")
    }
    try #require(await runtime.snapshot().workTargetFilter == .salvage)
    for _ in 0..<100 {
      await runtime.key("tab")
      if await runtime.snapshot().informationTargetBody?.missionActorID == identity { break }
    }
    try #require(await runtime.snapshot().informationTargetBody?.missionActorID == identity)
    await runtime.key("q")
    try #require(await runtime.snapshot().informationTargetBody?.missionActorID == identity)
  }

  @discardableResult
  func identify(_ runtime: GameRuntime) async throws -> WayfarerRecordRecoveryIdentification {
    try await aim(runtime)
    try #require(await runtime.snapshot().recordRecoveryIdentificationSample() != nil)
    _ = await runtime.advance(delta: 0.05)
    let source = try await state(runtime)
    try #require(source.captures.isEmpty && source.held.isEmpty)
    return try #require(source.identification)
  }

  func collect(_ runtime: GameRuntime) async throws {
    try await frame(runtime, offset: .init(0, -45, 55))
    let game = await runtime.snapshot()
    let identity = logical(try await state(runtime))
    let body = try #require(game.bodies.first { $0.missionActorID == identity })
    let context = try #require(game.gameplayContext())
    try #require(game.automaticScoopShapeCompatible(body, context: context))
    _ = await runtime.advance(delta: 0.05)
    try #require(try await state(runtime).captures.count == 1)
  }

  func returnHome(_ runtime: GameRuntime) async throws {
    try await flight.dock(runtime)
    await runtime.procurementRefuel()
    try await flight.travel(runtime, path: [241, 85])
  }
}

struct WayfarerRecordRecoveryJourneyTests {
  @Test func completeNativeJourneyIdentifiesThenRecoversOneOriginalAndPaysSameCustodianOnce()
    async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(freeTonnes: 1)
    let before = await runtime.snapshot().commander
    let state = try await f.accept(runtime)
    let allocated = await runtime.snapshot()
    #expect(allocated.commander.cargoTonnes == before.cargoTonnes + 1)
    #expect(allocated.commander.cargo == before.cargo)
    #expect(state.identification == nil && state.captures.isEmpty)
    #expect(OriginalServiceReservationPolicy.activeCount(allocated.commander.scriptState) == 1)
    try await f.celalen(runtime)
    let identification = try await f.identify(runtime)
    let identified = await runtime.snapshot()
    #expect(identified.commander.cargoTonnes == allocated.commander.cargoTonnes)
    #expect(identified.bodies.contains { $0.missionActorID == f.logical(state) })
    #expect(identified.commander.credits == before.credits)
    try await f.collect(runtime)
    let held = await runtime.snapshot()
    let capture = try #require(held.recordRecoveryState?.captures.first)
    #expect(capture.identification == identification.operation)
    #expect(capture.operation != identification.operation)
    #expect(capture.startTime >= identification.observations[1].physicalTime)
    #expect(capture.physicalTime > identification.observations[1].physicalTime)
    #expect(held.commander.cargoTonnes == allocated.commander.cargoTonnes)
    #expect(!held.bodies.contains { $0.missionActorID == f.logical(state) })
    try await f.returnHome(runtime)
    let receptionCash = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .receive)
    let received = await runtime.snapshot()
    #expect(received.commander.credits == receptionCash + 6500)
    #expect(received.commander.cargoTonnes == before.cargoTonnes)
    #expect(received.recordRecoveryState?.reception?.complete == true)
    #expect(
      received.commander.scriptState.savedClueJournal?.awards[
        WayfarerRecordRecovery.stateID]?.clueID == "exchange-service-record-recovery")
    #expect(
      received.commander.scriptState.savedClueJournal?.awards[
        NativeIdentifiedSalvage.stateID] == nil)
    #expect(received.commander.scriptState.savedClueJournal?.awards.count == 1)
    #expect(received.recordRecoveryRows.isEmpty)
    let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(cold == received.commander && world.consistent(with: cold))
  }

  @Test(arguments: ["hold", "core", "module", "scoops"])
  func acceptanceBackAndActualMissingRequirementNeverAllocateSource(reason: String) async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(freeTonnes: reason == "hold" ? 0 : nil)
    if reason != "hold" {
      await runtime.nativeCommand { game in
        let key =
          reason == "core"
          ? game.commander.targetingTier?.equipmentName
          : (reason == "module" ? "Targeting: Salvage Module" : "Fuel Scoops")
        if let key { _ = try? game.commander.removeFittedEquipment(key) }
      }
    }
    let before = await runtime.snapshot().commander
    let page = try await f.review(runtime, .accept)
    #expect(await runtime.snapshot().contractBoard.recordRecoveryQuote?.allowed == false)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().commander.scriptState.savedRecordRecoverySource == nil)
  }

  @Test(arguments: [false, true])
  func actualCustodianCancellationReturnsOnlyHeldPropertyAndNeverRecreatesStock(held: Bool)
    async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let before = await runtime.snapshot().commander
    let accepted = try await f.accept(runtime)
    if held {
      try await f.celalen(runtime)
      try await f.identify(runtime)
      try await f.collect(runtime)
      try await f.returnHome(runtime)
    }
    let active = await runtime.snapshot()
    let activeInventory = active.inventoryInformationRows(width: 1512).map(\.text).joined(
      separator: " ")
    if held {
      #expect(activeInventory.contains("held protected property"))
      #expect(!activeInventory.contains("slot reserved"))
    } else {
      #expect(activeInventory.contains("unidentified at cradle; slot reserved"))
    }
    let returnCash = active.commander.credits
    try await f.confirm(runtime, .cancel)
    let cancelled = await runtime.snapshot()
    #expect(cancelled.recordRecoveryState?.reception?.complete == false)
    #expect(cancelled.commander.credits == returnCash)
    #expect(cancelled.commander.scriptState.savedClueJournal == nil)
    #expect(cancelled.commander.cargoTonnes == before.cargoTonnes)
    let cancelledInventory = cancelled.inventoryInformationRows(width: 1512).map(\.text).joined(
      separator: " ")
    #expect(!cancelledInventory.contains("slot reserved"))
    #expect(cancelledInventory.contains(held ? "returned to archive" : "unidentified at cradle"))
    let original = try #require(
      cancelled.commander.scriptState.savedRecordRecoverySource?.originals.first)
    if held {
      guard case .returned = original.custody else {
        Issue.record("Held original must return.")
        return
      }
    } else {
      #expect(original.custody == .cradle)
    }
    await runtime.nativeCommand { $0.scriptPacks = [f.pack] }
    #expect(await runtime.snapshot().recordRecoveryRows.isEmpty)
    #expect(
      await runtime.snapshot().commander.scriptState.savedRecordRecoverySource?.allocatedMission
        == accepted.permission.mission)
  }

  @Test(arguments: ["accept", "receive"])
  func allocationAndReceptionWriterRefusalAreAtomicAndRetrySameReview(stage: String) async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    if stage == "receive" {
      try await f.accept(runtime)
      try await f.celalen(runtime)
      try await f.identify(runtime)
      try await f.collect(runtime)
      try await f.returnHome(runtime)
    }
    let action: WayfarerRecordRecoveryAction = stage == "accept" ? .accept : .receive
    let page = try await f.review(runtime, action)
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("record-\(stage)")
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try f.files.restoreWrites(blocked, files: files)
    await runtime.scriptPageKey("return", expected: page)
    if stage == "accept" {
      #expect(await runtime.snapshot().recordRecoveryState != nil)
    } else {
      #expect(await runtime.snapshot().recordRecoveryState?.reception?.complete == true)
    }
  }
}

extension WayfarerRecordRecoveryJourneyTests {
  @Test func realSharedThreeServiceAllowanceRefusesARecorderAllocationWithoutChangingStock()
    async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-contracts")
    var packs: [ScriptPack] = []
    for index in 0..<3 {
      let folder = f.files.root.appendingPathComponent("occupied-service-\(index)")
      try FileManager.default.copyItem(at: example, to: folder)
      let manifest = folder.appendingPathComponent("manifest.toml")
      let text = try String(contentsOf: manifest, encoding: .utf8)
        .replacingOccurrences(
          of: "id = \"example.scripted-contracts\"", with: "id = \"l337.wayfarer-service\""
        )
        .replacingOccurrences(of: "id = \"sample-run\"", with: "id = \"record-cap-\(index)\"")
        .replacingOccurrences(
          of: "exclusiveGroup = \"sample-work\"", with: "exclusiveGroup = \"record-cap-\(index)\"")
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      packs.append(try ScriptPackLibrary.read(folder))
    }
    let installedPacks = packs
    await runtime.nativeCommand { $0.scriptPacks += installedPacks }
    for pack in packs {
      let key = try await runtime.generateContractBoard(packDigest: pack.digest)
      let offer = try #require(
        await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
      let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
      try #require(quote.allowed)
      _ = try await runtime.confirmContract(quote)
    }
    let page = try await f.review(runtime, .accept)
    // Opening the real board may prepare its other offers. Compare the refused confirmation
    // against the already-painted review, including the full Commander and all source claims.
    let before = await runtime.snapshot().commander
    #expect(before.scriptState.savedRecordRecoverySource == nil)
    #expect(await runtime.snapshot().contractBoard.recordRecoveryQuote?.allowed == false)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().commander.scriptState.savedRecordRecoverySource == nil)
    #expect(OriginalServiceReservationPolicy.activeCount(before.scriptState) == 3)
  }

  @Test func staleSourceReviewAndWrongActualReceiverCannotSettleOriginalProperty() async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let page = try await f.review(runtime, .accept)
    await runtime.nativeCommand { $0.invalidateNativeStationAuthority() }
    let before = await runtime.snapshot().commander
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().recordRecoveryState == nil)
    try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.identify(runtime)
    #expect(await runtime.snapshot().recordRecoveryReview(.receive).allowed == false)
    try await f.collect(runtime)
    try await f.flight.dock(runtime)
    var wrong = await runtime.snapshot()
    let review = wrong.recordRecoveryReview(.receive)
    #expect(!review.allowed)
    #expect(throws: (any Error).self) { try wrong.confirmRecordRecovery(review) }
    #expect(wrong.recordRecoveryState?.held.count == 1)
    #expect(wrong.recordRecoveryState?.reception == nil)
    #expect(wrong.commander.scriptState.savedClueJournal == nil)
  }
}
