import Foundation
import Testing

@testable import L337Core

private struct StableOfferFixture {
  let root: URL
  let packs: [ScriptPack]
  var save: URL { root.appendingPathComponent("save/commander.json") }

  init(provider: String = "l337.contract") throws {
    root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("stable-offers-" + UUID().uuidString)
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

}

struct OriginalContractOfferPolicyTests {
  @Test func originalReopenClockPauseDeclineAndPageFactsStayStable() throws {
    let fixture = try StableOfferFixture()
    defer { fixture.clean() }
    var game = try fixture.game()
    let key = try game.ensureContractBoard(fixture.packs[0])
    let original = try #require(game.commander.contracts.boards[key])
    game.refreshContractRows()
    let page = game.scriptContractPageIdentity
    game.commander.scriptState.localSeconds += 7200
    game.commander.scriptState.flightSeconds += 7200
    game.commander.scriptState.calendarSeconds += 7200
    game.refreshContractRows()
    #expect(game.scriptContractPageIdentity == page)
    #expect(try game.ensureContractBoard(fixture.packs[0]) == key)
    #expect(game.commander.contracts.boards[key] == original)
    game.paused = true
    #expect(throws: MissionPackError.self) { try game.ensureContractBoard(fixture.packs[0]) }
    game.paused = false
    try game.declineContract(board: key, offer: original.offers[0].id)
    _ = try game.ensureContractBoard(fixture.packs[0])
    let declined = try #require(game.commander.contracts.boards[key])
    #expect(declined.revision == original.revision && declined.seed == original.seed)
    #expect(declined.offers.map(\.id) == original.offers.map(\.id))
    #expect(declined.offers[0].status == .declined)
  }

  @Test func acceptanceAdvancesOnceAndNativeAbandonmentAdvancesAgain() async throws {
    let fixture = try StableOfferFixture()
    defer { fixture.clean() }
    let runtime = GameRuntime(game: try fixture.game(), saveURL: fixture.save)
    let quote = try await fixture.quote(runtime, index: 0)
    let staleSibling = try await fixture.quote(runtime, index: 0, row: 1)
    let id = try await runtime.confirmContract(quote)
    let accepted = await runtime.snapshot()
    let frozen = try #require(accepted.commander.scriptState.instances[id]?.contract)
    #expect(try await runtime.confirmContract(quote) == id)
    _ = try await runtime.generateContractBoard(packDigest: fixture.packs[0].digest)
    let next = await runtime.snapshot()
    let board = try #require(next.commander.contracts.boards[quote.board])
    #expect(board.revision == frozen.boardRevision + 1)
    #expect(!board.offers.contains { $0.id == frozen.offer.id })
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(staleSibling) }
    #expect(next.commander.scriptState.instances[id]?.contract == frozen)
    await runtime.key("contacts-open")
    let contact = await runtime.snapshot()
    try #require(contact.scriptPresentedDialogue?.id == "cancel-samples")
    if !contact.scriptConfirmSelected { await runtime.key("left") }
    await runtime.key("return")
    let ended = await runtime.snapshot()
    let terminal = try #require(ended.commander.scriptState.instances[id])
    #expect(terminal.outcome == .abandoned && terminal.contract?.settled == true)
    _ = try await runtime.generateContractBoard(packDigest: fixture.packs[0].digest)
    let final = await runtime.snapshot()
    #expect(final.commander.contracts.boards[quote.board]?.revision == frozen.boardRevision + 2)
    let fresh = try await fixture.quote(runtime, index: 0)
    try #require(fresh.allowed)
    let newID = try await runtime.confirmContract(fresh)
    #expect(newID != id)
    // Check native identity derivation without claiming a freight pickup in this generic fixture.
    let owner = try #require(final.commander.equipmentOwnerID)
    let oldUnits = ScriptOwnedCargoState.unitIDs(
      consignment: ScriptOwnedCargoState.consignmentID(owner: owner, instance: id), quantity: 3)
    let newUnits = ScriptOwnedCargoState.unitIDs(
      consignment: ScriptOwnedCargoState.consignmentID(owner: owner, instance: newID), quantity: 3)
    #expect(Set(oldUnits).isDisjoint(with: newUnits))
    #expect(await runtime.snapshot().commander.scriptState.instances[id] == terminal)
  }

  @Test func failedWriterPreservesGenerationThenRetryAndCurrentReloadRetainTerms() async throws {
    let fixture = try StableOfferFixture()
    defer { fixture.clean() }
    let runtime = GameRuntime(game: try fixture.game(), saveURL: fixture.save)
    let quote = try await fixture.quote(runtime, index: 0)
    let before = await runtime.snapshot()
    let directory = fixture.save.deletingLastPathComponent()
    let preserved = fixture.root.appendingPathComponent("preserved")
    let files = try ScriptFinanceTestFixture.files(directory)
    try FileManager.default.moveItem(at: directory, to: preserved)
    try Data([1]).write(to: directory)
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    #expect(await runtime.snapshot().commander == before.commander)
    #expect(try ScriptFinanceTestFixture.files(preserved) == files)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: preserved, to: directory)
    let id = try await runtime.confirmContract(quote)
    _ = try await runtime.generateContractBoard(packDigest: fixture.packs[0].digest)
    let accepted = await runtime.snapshot()
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander.contracts == accepted.commander.contracts)
    #expect(
      loaded.commander.scriptState.instances[id] == accepted.commander.scriptState.instances[id])
    #expect(loaded.commander.valid)
    _ = try await runtime.generateContractBoard(packDigest: fixture.packs[0].digest)
    #expect(await runtime.snapshot().commander.contracts == loaded.commander.contracts)
  }

  @Test func retainedEvidenceRequiresExactSourceAndNativeSettlement() throws {
    let fixture = try StableOfferFixture()
    defer { fixture.clean() }
    var game = try fixture.game()
    let quote = try fixture.quote(&game, index: 0)
    let id = try game.confirmContract(quote)
    let pack = fixture.packs[0]
    #expect(
      try OriginalContractOfferPolicy.revision(
        pack: pack, station: game.contractStation, commander: game.commander) == 1)
    #expect(
      try OriginalContractOfferPolicy.revision(
        pack: fixture.packs[1], station: game.contractStation, commander: game.commander) == 0)
    let foreign = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
    if foreign != game.contractStation {
      #expect(
        try OriginalContractOfferPolicy.revision(
          pack: pack, station: foreign, commander: game.commander) == 0)
    }
    // A Lua-shaped terminal flag alone supplies no native settlement authority.
    game.commander.scriptState.instances[id]?.outcome = .complete
    #expect(
      try OriginalContractOfferPolicy.revision(
        pack: pack, station: game.contractStation, commander: game.commander) == 0)
    game.commander.scriptState.instances[id]?.contract?.settled = true
    game.commander.scriptState.instances[id]?.contract?.settlementOutcome = .complete
    #expect(
      try OriginalContractOfferPolicy.revision(
        pack: pack, station: game.contractStation, commander: game.commander) == 0)
  }

  @Test func cachedFloorSurvivesAdoptionAndOverflowRefusesBeforeAdmission() throws {
    let fixture = try StableOfferFixture()
    defer { fixture.clean() }
    var game = try fixture.game()
    let key = try game.ensureContractBoard(fixture.packs[0])
    let old = try #require(game.commander.contracts.boards[key])
    let floor = OriginalContractOfferPolicy.maximumRevision
    // A valid preexisting generic board is adopted verbatim, regardless of its old hour.
    let adopted = ScriptContractBoard(
      id: old.id, provider: old.provider, version: old.version, digest: old.digest,
      title: old.title, station: old.station, revision: floor, seed: old.seed,
      clock: old.clock, period: old.period, group: old.group, offers: old.offers)
    try #require(adopted.valid)
    game.commander.contracts.boards[key] = adopted
    #expect(try game.ensureContractBoard(fixture.packs[0]) == key)
    #expect(game.commander.contracts.boards[key] == adopted)
    let before = game.commander
    #expect(throws: MissionPackError.self) {
      try game.acceptContract(board: key, offer: adopted.offers[0].id)
    }
    #expect(game.commander == before)
    #expect(try OriginalContractOfferPolicy.advanced(floor - 2, by: 2) == floor)
    #expect(throws: MissionPackError.self) {
      try OriginalContractOfferPolicy.advanced(floor - 1, by: 2)
    }
    #expect(throws: MissionPackError.self) {
      try OriginalContractOfferPolicy.advanced(Int64.max, by: 1)
    }
    // There is no pruning API: any future removal must retain this persisted floor first.
  }

  @Test func legacyBoardsKeepHourlyRevisionAndWithinHourNoReroll() throws {
    let fixture = try StableOfferFixture(provider: "project.legacy-couriers")
    defer { fixture.clean() }
    var game = try fixture.game()
    let key = try game.ensureContractBoard(fixture.packs[0])
    let old = try #require(game.commander.contracts.boards[key])
    game.commander.scriptState.localSeconds += 100
    _ = try game.ensureContractBoard(fixture.packs[0])
    #expect(game.commander.contracts.boards[key] == old)
    // Legacy decline never required the provider to remain installed.
    game.scriptPacks = []
    try game.declineContract(board: key, offer: old.offers[0].id)
    #expect(game.commander.contracts.boards[key]?.offers[0].status == .declined)
    game.scriptPacks = fixture.packs
    game.commander.scriptState.localSeconds += 3600
    #expect(throws: MissionPackError.self) {
      try game.declineContract(board: key, offer: old.offers[0].id)
    }
    _ = try game.ensureContractBoard(fixture.packs[0])
    let refreshed = try #require(game.commander.contracts.boards[key])
    #expect(refreshed.revision == old.revision + 1)
    #expect(refreshed.offers.map(\.id) != old.offers.map(\.id))
  }
}
