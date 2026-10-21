import Foundation
import Testing

@testable import EliteCore

struct MarketCargoBoundsTests {
  @Test(arguments: [13, 14, 15])
  func maximumSupportedPreciousCargoRefusesAnActorPurchaseWithoutLosingSaveValidity(index: Int)
    async throws
  {
    var game = Game(executive: false)
    game.screen = .buy
    game.selection = index
    game.commander.cargo[index] = Int.max / 17
    game.market[index] = .init(price: 2, quantity: 2)
    try #require(game.commander.valid && Commodity.all[index].unit != "t")
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    #expect(before.marketAvailability(index) == "HOLD FULL")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.market == before.market)
    #expect(refused.commander.valid && refused.message == "CANNOT BUY")
  }

  @Test(arguments: [13, 14, 15])
  func lastSupportedPreciousUnitCanBeBoughtSavedAndReloadedButTheNextIsRefused(index: Int)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .buy
    game.selection = index
    game.commander.cargo[index] = Int.max / 17 - 1
    game.market[index] = .init(price: 2, quantity: 2)
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    #expect(before.marketAvailability(index) == "BUY")
    await runtime.key("return")
    let accepted = await runtime.snapshot()
    #expect(accepted.commander.cargo[index] == Int.max / 17 && accepted.commander.valid)
    #expect(accepted.commander.credits == before.commander.credits - 2)
    #expect(
      accepted.market[index].quantity == 1 && accepted.marketAvailability(index) == "HOLD FULL")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == accepted.commander && refused.market == accepted.market)
    try #require(accepted.commander.scriptState.calendarLedger == nil)
    let expected = try BodylessCurrentPublicationFixture.commander(accepted)
    try await runtime.save(to: url)
    #expect(await runtime.snapshot().commander == expected)
    try BodylessCurrentPublicationFixture.read(url, expecting: expected)
    let files = try ScriptFinanceTestFixture.files(directory)
    let loaded = GameRuntime()
    try await loaded.load(from: url, persistMigrations: false)
    #expect(await loaded.snapshot().commander == expected)
    #expect(try ScriptFinanceTestFixture.files(directory) == files)
  }

  @Test func fittedCabinsAndFreightShowTheSameHoldLimitAsTheActorPurchase() async throws {
    var game = Game(executive: false)
    game.commander.credits = 100000
    game.commander.unlimitedCargo = true
    var berths: [UUID] = []
    var cabinDebit = 0
    for _ in 0..<4 {
      let quote = game.passengerBerthQuote
      cabinDebit += quote.price
      let id = try game.confirmPassengerBerth(quote)
      berths.append(id)
    }
    let remaining = game.commander.standardCargoCapacity - game.commander.cargoTonnes
    try #require(remaining == 10 && game.commander.cargoTonnes == 4 * 5)
    try #require(game.commander.standardCargoCapacity == 30)
    #expect(game.commander.accommodation.fitted == Set(berths))
    #expect(game.commander.credits == 100000 - cabinDebit)
    try #require(Commodity.all[0].unit == "t")
    game.commander.cargo[0] = remaining
    game.screen = .buy
    game.selection = 0
    game.market[0] = .init(price: 2, quantity: 2)
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    try #require(before.commander.unlimitedCargo)
    try #require(before.commander.accommodation.fitted == Set(berths))
    try #require(before.commander.cargoTonnes == before.commander.tradeCargoCapacity)
    #expect(before.marketAvailability(0) == "HOLD FULL")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.market == before.market)
    #expect(refused.commander.valid)
  }
}

/// These three fixtures have no live bodies or mutable encounter state to capture at publication.
enum BodylessCurrentPublicationFixture {
  static func commander(_ before: Game) throws -> Commander {
    try #require(before.bodies.isEmpty && before.jumpCountdown == nil)
    try #require(
      before.commander.nativeStations == nil && before.commander.npcPersistence.count == 0)
    try #require(before.commander.savedEMPState == nil && before.commander.alienStorageState == nil)
    try #require(
      before.commander.scriptState.instances.values.allSatisfy {
        $0.outcome == .complete && $0.ownedEncounters.isEmpty
      })
    var expected = before.commander
    try expected.prepareEquipment()
    expected.mirrorFittedEquipment()
    try #require(expected == before.commander && expected.savedEquipmentVersion == 3)
    let mining = expected.miningLedgerForMigration(legacyMissing: false)
    try #require(mining.usesEconomyWeightedPresence && mining.requiredPresencePinSystems.isEmpty)
    // Persist the existing current ledger; do not replay a legacy migration or change its policy.
    expected.miningLedger = mining
    if expected.scriptState.calendarLedger == nil {
      try #require(!before.requiresScriptDurability && expected.legacyOwnedEquipment == nil)
      expected.scriptState.calendarLedger = .init(origin: .newCommander)
    }
    try #require(expected.valid)
    return expected
  }

  static func read(_ file: URL, expecting expected: Commander) throws {
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    try #require(pointer.format == "elite-script-save" && pointer.schemaVersion == 26)
    try #require(pointer.scope == "commander" && pointer.valueCodec == ScriptValueStorage.codec)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let names = Set(["commander.json", "missions.json", "world.json", "contracts.json"])
    try #require(Set(pointer.hashes.keys) == names)
    try #require(Set(try FileManager.default.contentsOfDirectory(atPath: generation.path)) == names)
    for name in names {
      let bytes = try Data(contentsOf: generation.appendingPathComponent(name))
      try #require(ScriptPackLibrary.hash(bytes) == pointer.hashes[name])
    }
    let (stored, world) = try ScriptSaveStore.read(bytes, from: file)
    #expect(stored == expected)
    #expect(world.valid && world.consistent(with: stored))
  }
}
