import Foundation
import Testing

@testable import L337Core

private struct ReservationCapFixture {
  let root: URL
  let packs: [ScriptPack]
  var save: URL { root.appendingPathComponent("save/commander.json") }

  init(provider: String = "l337.contract") throws {
    root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("reservation-cap-" + UUID().uuidString)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-contracts")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    var loaded: [ScriptPack] = []
    for index in 0..<4 {
      let folder = root.appendingPathComponent("pack-\(index)")
      try FileManager.default.copyItem(at: example, to: folder)
      let manifest = folder.appendingPathComponent("manifest.toml")
      let text = try String(contentsOf: manifest, encoding: .utf8)
        .replacingOccurrences(
          of: "id = \"example.scripted-contracts\"", with: "id = \"\(provider)\""
        )
        .replacingOccurrences(of: "id = \"sample-run\"", with: "id = \"cap-\(index)\"")
        .replacingOccurrences(
          of: "exclusiveGroup = \"sample-work\"", with: "exclusiveGroup = \"cap-\(index)\"")
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      loaded.append(try ScriptPackLibrary.read(folder))
    }
    packs = loaded
  }

  func clean() { try? FileManager.default.removeItem(at: root) }

  func game() throws -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = packs
    game.scriptDurabilityAvailable = true
    game.commander.credits = 100_000
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    return game
  }

  func quote(_ game: inout Game, index: Int, row: Int = 0) throws -> ContractAcceptanceQuote {
    let key = try game.ensureContractBoard(packs[index])
    let offer = try #require(game.commander.contracts.boards[key]?.offers[row])
    return game.contractAcceptanceQuote(board: key, offer: offer.id)
  }

  func quote(_ runtime: GameRuntime, index: Int, row: Int = 0) async throws
    -> ContractAcceptanceQuote
  {
    let key = try await runtime.generateContractBoard(packDigest: packs[index].digest)
    let snapshot = await runtime.snapshot()
    let offer = try #require(snapshot.commander.contracts.boards[key]?.offers[row])
    return await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  }

  /// A shape-correct over-cap save input, assembled from separate ordinary native admissions.
  /// It is invalid input to the writer, never a claimed live fourth acceptance or journey.
  func overCapGame() throws -> Game {
    let initial = try game()
    var game = initial
    for index in 0..<3 {
      let quote = try quote(&game, index: index)
      try #require(quote.allowed)
      _ = try game.confirmContract(quote)
    }
    var separate = initial
    let fourth = try quote(&separate, index: 3)
    let id = try separate.confirmContract(fourth)
    let state = try #require(separate.commander.scriptState.instances[id])
    let board = try #require(separate.commander.contracts.boards[fourth.board])
    game.commander.scriptState.instances[id] = state
    game.commander.contracts.boards[fourth.board] = board
    return game
  }
}

/// Descriptive custody value for policy classification only. It supplies no live dock seal,
/// stock authority, physical pickup, successful mission or valid native save claim.
private func reservationPolicyWayfarer(_ id: UUID) throws -> ScriptInstance {
  let owner = UUID()
  let site = WayfarerColdChainSite(galaxy: 0, system: 7, resourceKey: "main-orbital:0:7")
  let definition = WayfarerColdChainDefinition(
    source: site, objective: site, receiver: site, batch: "policy", stockUnits: 1, tonnes: 1,
    maximumActive: 3, route: [7, 185, 7], hazardTier: 0, flightAllowance: 3600, rewardNative: 4900)
  let station = NativeMainStationIdentity(
    world: owner, system: .init(galaxy: 0, system: 7),
    resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
  let dock = NativeMainStationDockReceipt(
    station: station, actor: .init(system: station.system, visit: 1, entity: 1),
    commanderOwner: owner, sequence: 1, calendarSeconds: 0)
  let context = ScriptEventContext(
    galaxy: 0, system: 7, docked: true, mainStation: true, revision: 1,
    frameSeconds: 0, localSeconds: 0, flightSeconds: 0, calendarSeconds: 0,
    transitSeconds: 0, playerPosition: nil)
  let timer = ScriptTimer(
    id: WayfarerColdChainDefinition.timerID, domain: .flight, due: 3600, interval: 0, policy: .once)
  let unit = UUID()
  let integrity = try WayfarerColdChain(
    snapshot: .init(
      binding: .init(
        owner: owner, instance: id, consignment: unit, receiver: station.resource, timerID: timer.id
      ), timer: timer, context: context),
    allowance: 3600, issueSequence: 1)
  var state = ScriptInstance(
    id: id, definition: WayfarerColdChainDefinition.stateID, version: "1.0.0",
    digest: String(repeating: "a", count: 64))
  state.savedWayfarerColdChain = .init(
    owner: owner, source: UUID(), unit: unit, definition: definition,
    issue: .init(sequence: 1, dock: dock, context: context), timer: timer, integrity: integrity)
  return state
}

struct OriginalServiceReservationPolicyTests {
  @Test func countsAcceptedMixedStateOnceAndExcludesLegacyAndStory() throws {
    let fixture = try ReservationCapFixture()
    defer { fixture.clean() }
    var game = try fixture.game()
    for index in 0..<2 {
      let quote = try fixture.quote(&game, index: index)
      _ = try game.confirmContract(quote)
    }
    let id = UUID()
    var wayfarer = try reservationPolicyWayfarer(id)
    game.commander.scriptState.instances[id] = wayfarer
    #expect(OriginalServiceReservationPolicy.activeCount(game.commander.scriptState) == 3)
    // Both authoritative reservation shapes on one synthetic classification input count once.
    wayfarer.contract = game.commander.scriptState.instances.values.first?.contract
    game.commander.scriptState.instances[id] = wayfarer
    for definition in [
      "l337.contract/story", "l337.wayfarer-service/story", "l337.glass-meridian/story",
      "project.generated-couriers/courier-jobs",
    ] {
      let story = ScriptInstance(
        id: UUID(), definition: definition, version: "1.0.0",
        digest: String(repeating: "b", count: 64))
      game.commander.scriptState.instances[story.id] = story
    }
    #expect(OriginalServiceReservationPolicy.activeCount(game.commander.scriptState) == 3)
    #expect(throws: MissionPackError.self) {
      try OriginalServiceReservationPolicy.requireAvailableSlot(game.commander.scriptState)
    }
    let encoded = try JSONEncoder().encode(game.commander.scriptState)
    let decoded = try JSONDecoder().decode(ScriptEngineState.self, from: encoded)
    #expect(OriginalServiceReservationPolicy.activeCount(decoded) == 3)
    for outcome: ScriptOutcome in [.complete, .failed, .abandoned] {
      var terminal = decoded
      terminal.instances[id]?.outcome = outcome
      #expect(OriginalServiceReservationPolicy.activeCount(terminal) == 2)
      try OriginalServiceReservationPolicy.requireAvailableSlot(terminal)
    }
  }

  @Test func fourthQuoteConfirmStaleAndDuplicateKeepMoneyCustodyAndSlots() async throws {
    let fixture = try ReservationCapFixture()
    defer { fixture.clean() }
    let runtime = GameRuntime(game: try fixture.game(), saveURL: fixture.save)
    for index in 0..<2 {
      _ = try await runtime.confirmContract(fixture.quote(runtime, index: index))
    }
    let staleFourth = try await fixture.quote(runtime, index: 3)
    try #require(staleFourth.allowed)
    let third = try await fixture.quote(runtime, index: 2)
    let id = try await runtime.confirmContract(third)
    let full = await runtime.snapshot()
    let repeated = try await runtime.confirmContract(third)
    #expect(repeated == id)
    let fourth = try await fixture.quote(runtime, index: 3)
    #expect(!fourth.allowed && fourth.issues.contains { $0.contains("Three Original") })
    let before = await runtime.snapshot()
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(fourth) }
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(staleFourth) }
    let after = await runtime.snapshot()
    #expect(
      after.commander == before.commander && after.commander.credits == full.commander.credits)
    #expect(OriginalServiceReservationPolicy.activeCount(after.commander.scriptState) == 3)
    await #expect(throws: (any Error).self) {
      try await runtime.wayfarerColdChainQuote(sourceID: "unavailable")
    }
    do { _ = try await runtime.wayfarerColdChainQuote(sourceID: "unavailable") } catch {
      #expect(error.localizedDescription.contains("Three Original"))
    }
  }

  @Test func actualAbandonmentReleasesOneSlotAndKeepsProviderRestriction() async throws {
    let fixture = try ReservationCapFixture()
    defer { fixture.clean() }
    let runtime = GameRuntime(game: try fixture.game(), saveURL: fixture.save)
    let first = try await fixture.quote(runtime, index: 0)
    _ = try await runtime.confirmContract(first)
    let sibling = try await fixture.quote(runtime, index: 0, row: 1)
    #expect(!sibling.allowed && sibling.issues.contains { $0.contains("this provider") })
    for index in 1..<3 {
      _ = try await runtime.confirmContract(fixture.quote(runtime, index: index))
    }
    await runtime.key("contacts-open")
    let contact = await runtime.snapshot()
    try #require(contact.scriptPresentedDialogue?.id == "cancel-samples")
    if !contact.scriptConfirmSelected { await runtime.key("left") }
    await runtime.key("return")
    let released = await runtime.snapshot()
    #expect(OriginalServiceReservationPolicy.activeCount(released.commander.scriptState) == 2)
    #expect(
      released.commander.scriptState.instances.values.filter { $0.outcome == .abandoned }.count == 1
    )
    let fourth = try await fixture.quote(runtime, index: 3)
    try #require(fourth.allowed)
    _ = try await runtime.confirmContract(fourth)
    #expect(
      OriginalServiceReservationPolicy.activeCount(await runtime.snapshot().commander.scriptState)
        == 3)
  }

  @Test func failedThirdWriterKeepsTwoSlotsThenRetryAndReloadCountExactlyThree() async throws {
    let fixture = try ReservationCapFixture()
    defer { fixture.clean() }
    let runtime = GameRuntime(game: try fixture.game(), saveURL: fixture.save)
    for index in 0..<2 {
      _ = try await runtime.confirmContract(fixture.quote(runtime, index: index))
    }
    let third = try await fixture.quote(runtime, index: 2)
    let before = await runtime.snapshot()
    let directory = fixture.save.deletingLastPathComponent()
    let preserved = fixture.root.appendingPathComponent("preserved")
    let files = try ScriptFinanceTestFixture.files(directory)
    try FileManager.default.moveItem(at: directory, to: preserved)
    try Data([1]).write(to: directory)
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(third) }
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(try ScriptFinanceTestFixture.files(preserved) == files)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: preserved, to: directory)
    _ = try await runtime.confirmContract(third)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(OriginalServiceReservationPolicy.activeCount(loaded.commander.scriptState) == 3)
    #expect(loaded.commander.valid)
  }

  @Test func currentSaveValidationRejectsFourOriginalJobsWithoutWayfarerStock() async throws {
    let fixture = try ReservationCapFixture()
    defer { fixture.clean() }
    let invalid = try fixture.overCapGame()
    #expect(OriginalServiceReservationPolicy.activeCount(invalid.commander.scriptState) == 4)
    #expect(
      !invalid.commander.contractsValid
        && !WayfarerColdChainSave.engineValid(invalid.commander.scriptState))
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.write(
        commander: invalid.commander, world: invalid.scriptWorldSave, to: fixture.save)
    }
    // Removing precisely one recomposed admission returns a valid ordinary native container.
    var three = invalid
    let removed = try #require(three.commander.scriptState.instances.values.first)
    let board = try #require(removed.contract?.boardKey)
    three.commander.scriptState.instances.removeValue(forKey: removed.id)
    three.commander.contracts.boards.removeValue(forKey: board)
    #expect(
      three.commander.contractsValid
        && WayfarerColdChainSave.engineValid(three.commander.scriptState))
    let runtime = GameRuntime(game: three, saveURL: fixture.save)
    try await runtime.save(to: fixture.save)
    let bytes = try Data(contentsOf: fixture.save)
    let (cold, world) = try ScriptSaveStore.read(bytes, from: fixture.save)
    #expect(
      OriginalServiceReservationPolicy.activeCount(cold.scriptState) == 3
        && world.consistent(with: cold))
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.write(
        commander: invalid.commander, world: invalid.scriptWorldSave, to: fixture.save)
    }
    #expect(try Data(contentsOf: fixture.save) == bytes)
    // Authenticate edited chunks so rejection exercises semantic cap validation, not checksum failure.
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
    let encoder = ScriptValueStorage.encoder()
    for fourth in [false, true] {
      var engine = cold.scriptState
      var contracts = cold.contracts
      if fourth {
        engine.instances[removed.id] = removed
        contracts.boards[board] = invalid.commander.contracts.boards[board]
      }
      var hashes = pointer.hashes
      for (name, data) in [
        ("missions.json", try encoder.encode(engine)),
        ("contracts.json", try encoder.encode(contracts)),
      ] {
        try data.write(to: directory.appendingPathComponent(name))
        hashes[name] = ScriptPackLibrary.hash(data)
      }
      let rewritten = try encoder.encode(
        ScriptSavePointer(
          format: pointer.format, schemaVersion: pointer.schemaVersion,
          generation: pointer.generation, hashes: hashes, scope: pointer.scope,
          valueCodec: pointer.valueCodec))
      if fourth {
        #expect(throws: (any Error).self) {
          try ScriptSaveStore.read(rewritten, from: fixture.save)
        }
      } else {
        let (control, _) = try ScriptSaveStore.read(rewritten, from: fixture.save)
        #expect(OriginalServiceReservationPolicy.activeCount(control.scriptState) == 3)
      }
    }
  }

  @Test func legacyAcceptedContractsRemainOutsideOriginalServiceCapacity() throws {
    let fixture = try ReservationCapFixture(provider: "project.legacy-couriers")
    defer { fixture.clean() }
    var game = try fixture.game()
    for index in 0..<4 {
      let quote = try fixture.quote(&game, index: index)
      try #require(quote.allowed)
      _ = try game.confirmContract(quote)
    }
    #expect(OriginalServiceReservationPolicy.activeCount(game.commander.scriptState) == 0)
    #expect(game.commander.contractsValid)
  }
}
