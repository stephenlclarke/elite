import Foundation
import Testing

@testable import EliteCore

struct PledgeFixture {
  let directory: URL
  let pack: ScriptPack
  var save: URL { directory.appendingPathComponent("commander.json") }
  init(scriptEdit: ((String) -> String)? = nil, manifestEdit: ((String) -> String)? = nil) throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "pledge-" + UUID().uuidString)
    directory = folder
    var ready = false
    defer { if !ready { try? FileManager.default.removeItem(at: folder) } }
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/station-donation")
    try FileManager.default.copyItem(at: example, to: directory)
    if let scriptEdit {
      let file = directory.appendingPathComponent("scripts/main.lua")
      try scriptEdit(String(contentsOf: file, encoding: .utf8)).write(
        to: file, atomically: true, encoding: .utf8)
    }
    if let manifestEdit {
      let file = directory.appendingPathComponent("manifest.toml")
      try manifestEdit(String(contentsOf: file, encoding: .utf8)).write(
        to: file, atomically: true, encoding: .utf8)
    }
    pack = try ScriptPackLibrary.read(directory)
    ready = true
  }
  func game(galaxy: Int = 0, system: Int = 7, cash: Int = 100000, food: Int = 0) -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    game.scriptDurabilityAvailable = true
    game.commander.galaxy = galaxy
    game.commander.system = system
    game.commander.credits = cash
    game.commander.cargo[Game.pledgeFood] = food
    game.systems = Universe.systemsIncludingPlugh(number: galaxy)
    return game
  }
  func offer(_ game: inout Game, tier: Int = 1, variant: ScriptPledgeVariant = .credits)
    throws -> (String, ScriptContractOffer)
  {
    let board = try game.ensureContractBoard(pack)
    let offer = try #require(
      game.commander.contracts.boards[board]?.offers.first {
        $0.key == variant.rawValue + "-" + String(tier)
      })
    return (board, offer)
  }
  func clean() { try? FileManager.default.removeItem(at: directory) }
}

struct PledgeScenario: Sendable {
  let tier: Int
  let variant: ScriptPledgeVariant
  let offset: Int
  static let boundaries = (1...3).flatMap { tier in
    [ScriptPledgeVariant.credits, .food].flatMap { variant in
      [-1, 0, 1].map { PledgeScenario(tier: tier, variant: variant, offset: $0) }
    }
  }
}

@Test(arguments: PledgeScenario.boundaries)
func pledgeFullNativeThresholdsNeverTransferPartialAmounts(scenario: PledgeScenario) throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  let declaration = try #require(fixture.pack.manifest.pledge)
  let amount = try #require(
    declaration.amount(difficulty: scenario.tier, variant: scenario.variant))
  var game = fixture.game(
    cash: scenario.variant == .credits ? amount + scenario.offset : 100000,
    food: scenario.variant == .food ? amount + scenario.offset : 4)
  let (board, offer) = try fixture.offer(&game, tier: scenario.tier, variant: scenario.variant)
  let before = game.commander
  let quote = game.contractAcceptanceQuote(board: board, offer: offer.id)
  #expect(game.commander == before && quote.pledge?.amount == amount)
  #expect(quote.allowed == (scenario.offset >= 0))
  if scenario.offset < 0 {
    #expect(throws: MissionPackError.self) { try game.confirmContract(quote) }
    #expect(game.commander == before && game.commander.scriptState.pledgeLedger == nil)
    return
  }
  let id = try game.confirmContract(quote)
  let receipt = try #require(game.commander.scriptState.pledgeLedger?.receipt(instance: id))
  #expect(game.commander.valid && receipt.valid(engine: game.commander.scriptState))
  #expect(receipt.amount == amount && receipt.variant == scenario.variant)
  let completedState = try #require(game.commander.scriptState.instances[id])
  let query = game.pledgeQuery(completedState)
  #expect(query["amount"]?.integer == Int64(amount) && query["unit"]?.string == receipt.unit)
  #expect(
    query["provider"]?.string == receipt.declaration.provider
      && query["receipt"]?.string == receipt.id.uuidString)
  #expect(receipt.before.standing == 0 && receipt.after.standing == 1)
  #expect(game.commander.credits == before.credits - (scenario.variant == .credits ? amount : 0))
  #expect(
    game.commander.cargo[Game.pledgeFood] == before.cargo[Game.pledgeFood]
      - (scenario.variant == .food ? amount : 0))
  #expect(game.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(game.commander.scriptState.instances[id]?.contract?.settlementAmount == 0)
  #expect(game.commander.scriptState.instances[id]?.contract?.deadline == nil)
  #expect(game.scriptPledgeAdmission == nil)
  let completed = game.commander
  #expect(try game.confirmContract(quote) == id)
  #expect(try game.acceptContract(board: board, offer: offer.id) == id)
  #expect(game.commander == completed && completed.scriptState.pledgeLedger?.receipts.count == 1)
}

@Test func pledgeSixFixedOffersQuotesAndBackPreserveActualProperty() throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var game = fixture.game(food: 5)
  let key = try game.ensureContractBoard(fixture.pack)
  let board = try #require(game.commander.contracts.boards[key])
  #expect(board.offers.count == 6 && Set(board.offers.map(\.key)).count == 6)
  let expectedTitles = [
    "credits-1": "Station Aid / difficulty 1 / 500.0 CR",
    "credits-2": "Station Aid / difficulty 2 / 1500.0 CR",
    "credits-3": "Station Aid / difficulty 3 / 3000.0 CR",
    "food-1": "Station Aid / difficulty 1 / 1 tonne Food",
    "food-2": "Station Aid / difficulty 2 / 3 tonnes Food",
    "food-3": "Station Aid / difficulty 3 / 5 tonnes Food",
  ]
  let before = game.commander
  for offer in board.offers {
    #expect(offer.title == expectedTitles[offer.key])
    let quote = game.contractAcceptanceQuote(board: key, offer: offer.id)
    #expect(quote.allowed && quote.pledge?.profileSeed != 0)
    #expect(offer.reward == 0 && offer.deposit == 0 && offer.duration == 0)
    #expect(game.commander == before)
  }
  game.openContractBoard()
  game.contractBoardKey("return")
  #expect(game.contractBoard.detail && game.contractBoard.action == .back)
  game.contractBoardKey("return")
  game.contractBoardKey("down")
  game.contractBoardKey("return")
  game.contractBoardKey("pagedown")
  game.contractBoardKey("escape")
  #expect(game.commander == before && game.commander.scriptState.instances.isEmpty)
  #expect(try game.ensureContractBoard(fixture.pack) == key)
  #expect(game.commander.contracts.boards[key] == board)
  #expect(Game.pledgeProfileSeed(0) == 0x6D2B_79F5)
  #expect(Game.pledgeProfileSeed(0x1234_5678_0000_0001) == 1)
}

@Test func pledgeSupportsEveryOrdinaryChartStationAndRefusesSyntheticOrSecondarySites() throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  for galaxy in 0..<8 {
    for system in 0..<256 {
      var game = fixture.game(galaxy: galaxy, system: system, cash: 5000)
      let (key, offer) = try fixture.offer(&game)
      let id = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
      let receipt = try #require(game.commander.scriptState.pledgeLedger?.receipt(instance: id))
      #expect(receipt.origin == game.contractStation && receipt.donatedAt == receipt.origin)
      #expect(receipt.creditedAt == receipt.origin && game.commander.credits == 0)
      #expect(game.commander.valid)
    }
  }
  var synthetic = fixture.game(system: 256)
  // A valid previously discovered native host-site fixture.
  synthetic.commander.plughDiscoveryMask = 1
  #expect(synthetic.commander.valid)
  #expect(throws: MissionPackError.self) { try synthetic.ensureContractBoard(fixture.pack) }
  synthetic.openContractBoard()
  #expect(synthetic.contractBoard.rows.count == 1)
  #expect(synthetic.contractBoard.rows.first?.offer == nil)
  #expect(synthetic.contractBoard.rows.first?.reason?.contains("synthetic") == true)
  #expect(synthetic.commander.scriptState.pledgeLedger == nil)
  var secondary = fixture.game()
  secondary.dockedAtMainStation = false
  let before = secondary.commander
  secondary.openContractBoard()
  #expect(secondary.screen == .status && secondary.commander == before)
}

@Test func pledgeAssistsAndProtectedPayloadsNeverSupplyFoodOrMoney() throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var game = fixture.game(cash: 4999, food: 0)
  game.commander.unlimitedCash = true
  game.commander.unlimitedCargo = true
  let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs")
  let courier = try ScriptPackLibrary.read(examples.appendingPathComponent("scripted-courier"))
  game.scriptPacks.append(courier)
  let protectedID = try game.acceptScriptMission(courier)
  let protected = try #require(game.commander.scriptState.instances[protectedID])
  #expect(!protected.payloads.isEmpty)
  let (key, cash) = try fixture.offer(&game)
  let food = try #require(game.commander.contracts.boards[key]?.offers.first { $0.key == "food-1" })
  let before = game.commander
  #expect(!game.contractAcceptanceQuote(board: key, offer: cash.id).allowed)
  #expect(!game.contractAcceptanceQuote(board: key, offer: food.id).allowed)
  #expect(game.commander == before)
  game.commander.cargo[Game.pledgeFood] = 1  // Transparent starting ordinary-goods fixture.
  let chargeBefore = game.commander.credits
  _ = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: food.id))
  #expect(game.commander.cargo[Game.pledgeFood] == 0 && game.commander.credits == chargeBefore)
  #expect(game.commander.scriptState.instances[protectedID] == protected)
  #expect(game.commander.scriptState.payloadTonnes == before.scriptState.payloadTonnes)
  let largeFood = Int(Int32.max) + 10
  var stocked = fixture.game(food: largeFood)
  stocked.commander.unlimitedCargo = true  // Finite native starting stock, not created by a pledge.
  #expect(stocked.commander.valid)
  let (largeBoard, largeOffer) = try fixture.offer(&stocked, variant: .food)
  let largeBefore = stocked.commander
  let largeQuote = stocked.contractAcceptanceQuote(board: largeBoard, offer: largeOffer.id)
  let largePreview = try #require(largeQuote.pledge)
  #expect(largePreview.difficulty == 1 && largePreview.variant == .food && largePreview.amount == 1)
  #expect(largePreview.before.food == largeFood && largePreview.before.unreservedFood == largeFood)
  #expect(largePreview.before.cash == largeBefore.credits)
  try stocked.requirePledgeResources(largePreview)
  #expect(!largeQuote.allowed)
  #expect(largeQuote.issues == ["Invalid accommodation quantities."])
  #expect(
    largeQuote.pledge?.terms.contains { $0.contains("\(largeFood - 1) tonnes Food.") } == true)
  #expect(stocked.commander.cargo[Game.pledgeFood] == largeFood)
  #expect(stocked.commander == largeBefore)
  #expect(throws: MissionPackError.self) { try stocked.confirmContract(largeQuote) }
  #expect(stocked.commander == largeBefore)
  #expect(stocked.scriptPledgeAdmission == nil)
}

@Test func pledgeCanReduceLegacyExcessFoodIntoTheActualPhysicalHold() throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  let hold = try #require(ShipCatalogue.ship("SH023")?.game?.cargo)
  let excessFood = hold + 1
  let remainingFood = excessFood - 5  // The authored tier-three donation stays five tonnes.
  var game = fixture.game(food: excessFood)
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.commander.unlimitedCargo = true
  try #require(game.commander.standardCargoCapacity == hold)
  #expect(game.commander.cargoTonnes == excessFood && game.commander.valid)
  #expect(game.commander.passengerFit?.allowed == false)
  let (board, offer) = try fixture.offer(&game, tier: 3, variant: .food)
  let before = game.commander
  let quote = game.contractAcceptanceQuote(board: board, offer: offer.id)
  let preview = try #require(quote.pledge)
  #expect(
    preview.amount == 5 && preview.before.food == excessFood
      && preview.before.unreservedFood == excessFood)
  try game.requirePledgeResources(preview)
  try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
  #expect(game.commander == before)
  let id = try game.confirmContract(quote)
  let receipt = try #require(game.commander.scriptState.pledgeLedger?.receipt(instance: id))
  #expect(
    game.commander.cargo[Game.pledgeFood] == remainingFood
      && game.commander.cargoTonnes == remainingFood)
  #expect(
    game.commander.standardCargoCapacity == hold && game.commander.passengerFit?.allowed == true)
  #expect(game.commander.credits == before.credits && game.commander.valid)
  #expect(receipt.amount == 5 && receipt.variant == .food)
  #expect(receipt.before.food == excessFood && receipt.after.food == remainingFood)
  #expect(
    receipt.before.unreservedFood == excessFood && receipt.after.unreservedFood == remainingFood)
  #expect(receipt.before.cash == before.credits && receipt.after.cash == before.credits)
  #expect(receipt.before.standing == 0 && receipt.after.standing == 1)
  #expect(receipt.valid(engine: game.commander.scriptState))
  #expect(game.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(game.commander.scriptState.instances[id]?.contract?.settlementAmount == 0)
  #expect(game.scriptPledgeAdmission == nil)
  let completed = game.commander
  #expect(try game.confirmContract(quote) == id)
  #expect(game.commander == completed && completed.scriptState.pledgeLedger?.receipts.count == 1)
}

@Test(arguments: [
  "omission", "milestone", "late-command", "early-debit", "fault", "deferred", "backlog",
])
func pledgeRejectedAcceptedHandlersNeverPublishAnUnpaidAssignment(mode: String) throws {
  let fixture = try PledgeFixture(
    scriptEdit: { text in
      switch mode {
      case "omission": return text.replacingOccurrences(of: "{op = \"pledge.commit\"}", with: "")
      case "milestone":
        return text.replacingOccurrences(of: "{op = \"milestone.ensure\", index = 0},", with: "")
      case "late-command":
        return text.replacingOccurrences(
          of: "{op = \"pledge.commit\"}",
          with: "{op = \"pledge.commit\"}, {op = \"journal.append\", text = \"too late\"}")
      case "early-debit":
        return text.replacingOccurrences(
          of: "{op = \"pledge.commit\"}",
          with: "{op = \"credits\", id = \"early\", amount = -1}, {op = \"pledge.commit\"}")
      case "fault":
        return text.replacingOccurrences(
          of: "accepted = function(e, w, d)",
          with: "accepted = function(e, w, d) error('declined proposal')")
      default: return text
      }
    },
    manifestEdit: { text in
      mode == "early-debit"
        ? text.replacingOccurrences(of: "\"story-v2\"", with: "\"story-v2\", \"economy-v2\"") : text
    })
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, offer) = try fixture.offer(&game)
  if mode == "deferred" { game.scriptEventsDeferred = true }
  if mode == "backlog" {
    // A genuine retained mission receives more envelopes than one actor turn can drain.
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-courier")
    let courier = try ScriptPackLibrary.read(source)
    game.scriptPacks.append(courier)
    let id = try game.acceptScriptMission(courier)
    for _ in 0..<65 { game.emitScriptEvent("contact.requested", only: id, drain: false) }
  }
  let before = game.commander
  let quote = game.contractAcceptanceQuote(board: key, offer: offer.id)
  #expect(!quote.allowed)
  #expect(throws: MissionPackError.self) { try game.acceptContract(board: key, offer: offer.id) }
  #expect(game.commander == before && game.scriptPledgeAdmission == nil)
}

@Test func pledgeFilesystemFailureRetainsOfferAndOneValidRetryPublishesExactlyOnce() async throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let snapshot = await runtime.snapshot()
  let offer = try #require(snapshot.commander.contracts.boards[key]?.offers.first)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let pointer = try Data(contentsOf: fixture.save)
  let storage = fixture.save.appendingPathExtension("missions")
  let backup = fixture.directory.appendingPathComponent("generations-backup")
  try FileManager.default.moveItem(at: storage, to: backup)
  try Data("not a directory".utf8).write(to: storage)
  await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
  #expect(await runtime.snapshot().commander == snapshot.commander)
  #expect(try Data(contentsOf: fixture.save) == pointer)
  try FileManager.default.removeItem(at: storage)
  try FileManager.default.moveItem(at: backup, to: storage)
  let id = try await runtime.confirmContract(quote)
  let completed = await runtime.snapshot().commander
  #expect(completed.scriptState.pledgeLedger?.receipts.count == 1)
  #expect(try await runtime.confirmContract(quote) == id)
  #expect(await runtime.snapshot().commander == completed)
  let loaded = GameRuntime(game: fixture.game())
  try await loaded.load(from: fixture.save)
  #expect(await loaded.snapshot().commander == completed)
}

@Test func pledgeStationAndProviderStandingNeverMergeAndStaleStationQuoteRefuses() throws {
  let fixture = try PledgeFixture()
  let other = try PledgeFixture(manifestEdit: {
    $0.replacingOccurrences(of: "project.station-aid", with: "test.other-aid")
  })
  defer {
    fixture.clean()
    other.clean()
  }
  var game = fixture.game()
  game.scriptPacks.append(other.pack)
  let (a, first) = try fixture.offer(&game)
  let oldQuote = game.contractAcceptanceQuote(board: a, offer: first.id)
  game.commander.system = 129  // Station-location fixture; board identities are native.
  let unchanged = game.commander
  #expect(throws: MissionPackError.self) { try game.confirmContract(oldQuote) }
  #expect(game.commander == unchanged)
  let (b, second) = try fixture.offer(&game)
  _ = try game.confirmContract(game.contractAcceptanceQuote(board: b, offer: second.id))
  let otherBoard = try game.ensureContractBoard(other.pack)
  let otherOffer = try #require(game.commander.contracts.boards[otherBoard]?.offers.first)
  _ = try game.confirmContract(
    game.contractAcceptanceQuote(board: otherBoard, offer: otherOffer.id))
  game.commander.system = 7
  _ = try game.confirmContract(game.contractAcceptanceQuote(board: a, offer: first.id))
  let ledger = try #require(game.commander.scriptState.pledgeLedger)
  #expect(ledger.issuers.count == 3 && ledger.receipts.count == 3 && game.commander.valid)
  #expect(ledger.issuers.values.allSatisfy { $0.standing == 1 })
  let before = game.commander
  #expect(try game.confirmContract(oldQuote) == Game.contractJobIdentity(first.id))
  #expect(game.commander == before)
}

@Test func pledgeCadenceDeclineAndBackKeepStableTermsWithoutExpiry() throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  // Boundary-clock fixture followed by native loaded/unpaused clock advancement.
  game.commander.scriptState.localSeconds = 3599.9
  let (key, first) = try fixture.offer(&game)
  let original = try #require(game.commander.contracts.boards[key])
  let quote = game.contractAcceptanceQuote(board: key, offer: first.id)
  try game.declineContract(board: key, offer: first.id)
  #expect(game.commander.credits == 100000 && game.commander.scriptState.pledgeLedger == nil)
  #expect(try game.ensureContractBoard(fixture.pack) == key)
  #expect(game.commander.contracts.boards[key]?.offers[0].status == .declined)
  game.paused = true
  let pausedAdvance = game.advanceScriptClockValues(
    delta: 0.1, flight: false, local: true, calendar: false)
  #expect(!pausedAdvance)
  game.paused = false
  let activeAdvance = game.advanceScriptClockValues(
    delta: 0.1, flight: false, local: true, calendar: false)
  #expect(activeAdvance)
  #expect(game.commander.scriptState.localSeconds == 3600)
  _ = try game.ensureContractBoard(fixture.pack)
  let next = try #require(game.commander.contracts.boards[key])
  #expect(next.revision == 1 && next.offers.count == 6)
  #expect(Set(next.offers.map(\.id)).isDisjoint(with: Set(original.offers.map(\.id))))
  #expect(throws: MissionPackError.self) { try game.confirmContract(quote) }
  #expect(game.commander.scriptState.pledgeLedger == nil)
}

@Test func pledgeRetainedBudgetNeverEvictsStandingOrReceipts() throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var game = fixture.game(cash: 10_000_000, food: 220)
  game.commander.shipID = "SH005"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  try #require(game.commander.standardCargoCapacity >= game.commander.cargoTonnes)
  game.commander.unlimitedCargo = true  // Finite actual stock is still consumed.
  for index in 0..<128 {
    if index > 0, index % 6 == 0 {
      let definition = try #require(fixture.pack.manifest.board)
      let revision = game.contractRevision(definition)
      while game.contractRevision(definition) == revision {
        _ = game.advanceScriptClockValues(delta: 0.1, flight: false, local: true, calendar: false)
      }
    }
    let key = try game.ensureContractBoard(fixture.pack)
    let offer = try #require(
      game.commander.contracts.boards[key]?.offers.first { $0.status == .available })
    let quote = game.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(
      quote.allowed,
      Comment(rawValue: "Donation \(index + 1): " + quote.issues.joined(separator: "; ")))
    _ = try game.confirmContract(quote)
  }
  let before = game.commander
  #expect(
    before.scriptState.instances.count == 128
      && before.scriptState.pledgeLedger?.receipts.count == 128)
  #expect(before.scriptState.pledgeLedger?.issuers.values.first?.standing == 128 && before.valid)
  let (key, offer) = try fixture.offer(&game, tier: 3, variant: .food)
  #expect(!game.contractAcceptanceQuote(board: key, offer: offer.id).allowed)
  #expect(throws: MissionPackError.self) { try game.acceptContract(board: key, offer: offer.id) }
  #expect(game.commander == before)
}

@Test(arguments: [
  "amount", "station", "standing", "variant", "sequence", "revision", "cause-overflow", "seed",
])
func pledgeMalformedReceiptsRefuseBeforeArithmeticOrStandingUse(field: String) throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, offer) = try fixture.offer(&game)
  let id = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
  var ledger = try #require(game.commander.scriptState.pledgeLedger)
  let receipt = try #require(ledger.receipt(instance: id))
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
  switch field {
  case "amount": object["amount"] = 1
  case "station":
    var station = try #require(object["creditedAt"] as? [String: Any])
    station["system"] = 129
    object["creditedAt"] = station
  case "standing":
    var after = try #require(object["after"] as? [String: Any])
    after["standing"] = 2
    object["after"] = after
  case "variant": object["variant"] = "food"
  case "sequence": object["sequence"] = 0
  case "revision": object["revision"] = 0
  case "cause-overflow":
    var cause = try #require(object["cause"] as? [String: Any])
    cause["revision"] = NSNumber(value: UInt64.max)
    object["cause"] = cause
  default: object["boardSeed"] = 1
  }
  let damaged = try JSONDecoder().decode(
    ScriptPledgeReceipt.self, from: JSONSerialization.data(withJSONObject: object))
  ledger.receipts[receipt.id] = damaged
  game.commander.scriptState.pledgeLedger = ledger
  #expect(!game.commander.valid)
}

@Test func pledgeOlderPointersCannotConcealRehashedNewLedgerAndOldSavesInventNothing() throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var plain = fixture.game()
  plain.ensureScriptCalendar(origin: .newCommander)
  // Preserve a genuine pre-owned-equipment header, separately from canonical publication.
  _ = try plain.ensureContractBoard(fixture.pack)
  let legacy = plain
  #expect(legacy.commander.equipmentInventory == nil)
  #expect(legacy.commander.savedEquipmentVersion == nil)
  #expect(!legacy.commander.usesEconomyMiningSaveVersion)
  func oldEnvelope(version: Int, missions: ScriptEngineState, contracts: ScriptContractState)
    throws -> ScriptSavePointer
  {
    let encoder = version >= 13 ? ScriptValueStorage.encoder() : JSONEncoder()
    var header = legacy.commander
    header.scriptState = ScriptEngineState()
    header.contracts = ScriptContractState()
    var chunks = [
      "commander.json": try encoder.encode(header),
      "missions.json": try encoder.encode(missions),
      "world.json": try encoder.encode(legacy.scriptWorldSave),
    ]
    if version >= 8 { chunks["contracts.json"] = try encoder.encode(contracts) }
    let generation = UUID().uuidString
    let directory = fixture.save.appendingPathExtension("missions").appendingPathComponent(
      generation)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for (name, bytes) in chunks { try bytes.write(to: directory.appendingPathComponent(name)) }
    return ScriptSavePointer(
      format: "elite-script-save", schemaVersion: version,
      generation: generation, hashes: chunks.mapValues(ScriptPackLibrary.hash), scope: "commander",
      valueCodec: version >= 13 ? ScriptValueStorage.codec : nil)
  }
  var compatibleHeaderHash: String?
  for version in 2...19 {
    let old = try oldEnvelope(
      version: version, missions: legacy.commander.scriptState,
      contracts: legacy.commander.contracts)
    let pointerBytes = try JSONEncoder().encode(old)
    let (loaded, _) = try ScriptSaveStore.read(pointerBytes, from: fixture.save)
    #expect(loaded.scriptState.pledgeLedger == nil)
    #expect(loaded.credits == legacy.commander.credits && loaded.cargo == legacy.commander.cargo)
    #expect(loaded.name == legacy.commander.name && loaded.shipID == legacy.commander.shipID)
    #expect(loaded.scriptState == legacy.commander.scriptState)
    #expect(loaded.contracts == (version >= 8 ? legacy.commander.contracts : ScriptContractState()))
    if version == 19 { compatibleHeaderHash = old.hashes["commander.json"] }
  }
  let acceptedHeaderHash = try #require(compatibleHeaderHash)
  try GameRuntime.writeCommander(&plain, to: fixture.save)
  let (key, offer) = try fixture.offer(&plain)
  _ = try plain.confirmContract(plain.contractAcceptanceQuote(board: key, offer: offer.id))
  try GameRuntime.writeCommander(&plain, to: fixture.save)
  let donatedBytes = try Data(contentsOf: fixture.save)
  let donated = try JSONDecoder().decode(ScriptSavePointer.self, from: donatedBytes)
  #expect(donated.schemaVersion == 26 && donated.scope == "commander")
  let (stored, _) = try ScriptSaveStore.read(donatedBytes, from: fixture.save)
  #expect(stored == plain.commander)
  let ledger = try #require(stored.scriptState.pledgeLedger)
  try #require(!ledger.receipts.isEmpty)
  // Modern native fields remain forbidden under an older claimed format.
  let hidden = ScriptSavePointer(
    format: donated.format, schemaVersion: 19,
    generation: donated.generation, hashes: donated.hashes, scope: donated.scope,
    valueCodec: donated.valueCodec)
  let hiddenBytes = try JSONEncoder().encode(hidden)
  #expect(throws: SaveError.self) { try ScriptSaveStore.read(hiddenBytes, from: fixture.save) }
  // The exact accepted legacy header cannot conceal the actual newer pledge ledger either.
  let concealed = try oldEnvelope(
    version: 19, missions: stored.scriptState, contracts: stored.contracts)
  #expect(concealed.hashes["commander.json"] == acceptedHeaderHash)
  #expect(concealed.hashes["missions.json"] == donated.hashes["missions.json"])
  #expect(concealed.hashes["contracts.json"] == donated.hashes["contracts.json"])
  let concealedBytes = try JSONEncoder().encode(concealed)
  #expect(throws: SaveError.self) { try ScriptSaveStore.read(concealedBytes, from: fixture.save) }
  let unchanged = try Data(contentsOf: fixture.save)
  #expect(unchanged == donatedBytes)
}

@Test func pledgeRealMarketFoodTrialSaveLoadRestartAndReturnKeepLiveCommander() async throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var live = fixture.game()
  live.commander.name = "LIVE AID OWNER"
  let (key, offer) = try fixture.offer(&live)
  let liveID = try live.confirmContract(live.contractAcceptanceQuote(board: key, offer: offer.id))
  let runtime = GameRuntime(game: live, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot().commander
  let bytes = try Data(contentsOf: fixture.save)
  #expect(live.missionCatalogue.first { $0.savedInstance == liveID }?.trialDigest == nil)
  await runtime.key("gallery-open")
  try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let trial = await runtime.snapshot()
  #expect(
    trial.screen == .contracts && trial.contractBoard.detail && trial.contractBoard.action == .back)
  #expect(
    trial.commander.scriptState.instances.isEmpty && trial.commander.scriptState.pledgeLedger == nil
  )
  #expect(trial.isMissionTrial)
  await runtime.key("screen:7")
  let market = await runtime.snapshot()
  try #require(market.screen == .buy && market.selection == Game.pledgeFood)
  let price = market.market[Game.pledgeFood].price
  #expect(market.market[Game.pledgeFood].quantity >= 5)
  let marketLayout = MarketLayout(
    game: market, width: market.viewportWidth, height: market.viewportHeight)
  for _ in 0..<5 {
    await runtime.marketClick(x: marketLayout.trade.x + 1, y: marketLayout.trade.y + 1)
  }
  let bought = await runtime.snapshot()
  #expect(bought.commander.cargo[Game.pledgeFood] == 5)
  #expect(bought.commander.credits == market.commander.credits - 5 * price)
  #expect(bought.market[Game.pledgeFood].quantity == market.market[Game.pledgeFood].quantity - 5)
  await runtime.key("contracts-open")
  let board = await runtime.snapshot()
  let index = try #require(board.contractBoard.rows.firstIndex { $0.offer?.key == "food-3" })
  for _ in 0..<index { await runtime.key("down") }
  await runtime.key("return")
  let proof = await runtime.snapshot().scriptPagePresentation
  await runtime.scriptPageKey("right", expected: proof)
  await runtime.scriptPageKey("return", expected: proof)
  let completed = await runtime.snapshot()
  #expect(completed.commander.cargo[Game.pledgeFood] == 0)
  #expect(completed.commander.credits == bought.commander.credits)
  #expect(completed.commander.scriptState.pledgeLedger?.receipts.values.first?.variant == .food)
  let receipt = try await runtime.saveForInterface(expectedEpoch: completed.ecmControl.epoch)
  #expect(receipt.isTrial && receipt.url.path.hasPrefix(namespace.path + "/"))
  _ = try await runtime.loadForInterface(expectedEpoch: completed.ecmControl.epoch)
  #expect(await runtime.snapshot().commander == completed.commander)
  #expect(try Data(contentsOf: fixture.save) == bytes)
  try await runtime.restartScriptGalleryTrial()
  #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  #expect(await runtime.snapshot().commander.scriptState.pledgeLedger == nil)
  #expect(await runtime.snapshot().contractBoard.action == .back)
  await runtime.scriptPageKey("return", expected: proof)
  #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  try await runtime.returnFromScriptGalleryTrial()
  #expect(await runtime.snapshot().commander == before)
  #expect(try Data(contentsOf: fixture.save) == bytes)
  let missing = GameRuntime(game: Game(executive: false))
  try await missing.load(from: fixture.save)
  #expect(await missing.snapshot().commander == before)
  #expect(await missing.snapshot().commander.scriptState.instances[liveID]?.outcome == .complete)
}

@Test(arguments: [
  "ledger-deleted", "ledger-empty", "marker-deleted", "foreign-marker", "duplicate-marker",
  "failed-marker", "old-marker-only", "old-ledger-only",
])
func pledgeRehashedReceiptLinkContradictionsAndOldFormatHiddenDataRefuse(mode: String) throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, offer) = try fixture.offer(&game)
  let first = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
  let (_, next) = try fixture.offer(&game, tier: 2)
  let second = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: next.id))
  let marker = try #require(game.commander.scriptState.instances[first]?.pledgeReceiptID)
  #expect(
    game.commander.contractQuoteResources.scriptState.instances[first]?.pledgeReceiptID == marker)
  try GameRuntime.writeCommander(&game, to: fixture.save)
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  var state = game.commander.scriptState
  switch mode {
  case "ledger-deleted", "old-marker-only": state.pledgeLedger = nil
  case "ledger-empty": state.pledgeLedger = ScriptPledgeLedger()
  case "marker-deleted": state.instances[first]?.pledgeReceiptID = nil
  case "foreign-marker": state.instances[first]?.pledgeReceiptID = UUID()
  case "duplicate-marker": state.instances[second]?.pledgeReceiptID = marker
  case "failed-marker": state.instances[first]?.outcome = .failed
  default:
    state.instances[first]?.pledgeReceiptID = nil
    state.instances[second]?.pledgeReceiptID = nil
  }
  let bytes = try ScriptValueStorage.encoder().encode(state)
  try bytes.write(to: directory.appendingPathComponent("missions.json"))
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
  let rehashed = ScriptSavePointer(
    format: pointer.format,
    schemaVersion: mode.hasPrefix("old-") ? 19 : 20, generation: pointer.generation,
    hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
  #expect(throws: SaveError.self) {
    try ScriptSaveStore.read(JSONEncoder().encode(rehashed), from: fixture.save)
  }
}

@Test(arguments: [
  "unknown", "provider", "capability", "zero", "missing-tier", "seed", "reward", "partial-family",
])
func pledgeClosedDeclarationAndGeneratedTermsRefuseUnsupportedAuthority(mode: String) throws {
  if ["unknown", "provider", "capability", "zero", "missing-tier"].contains(mode) {
    #expect(throws: (any Error).self) {
      _ = try PledgeFixture(manifestEdit: { text in
        switch mode {
        case "unknown":
          return text.replacingOccurrences(of: "[pledge]", with: "[pledge]\narbitraryStanding=100")
        case "provider":
          return text.replacingOccurrences(
            of: "provider = \"project.station-aid\"", with: "provider = \"foreign.station-aid\"")
        case "capability":
          return text.replacingOccurrences(of: "\"station-pledges-basic-v2\", ", with: "")
        case "zero":
          return text.replacingOccurrences(of: "[5000, 15000, 30000]", with: "[0, 15000, 30000]")
        default: return text.replacingOccurrences(of: "[1, 3, 5]", with: "[1, 3]")
        }
      })
    }
    return
  }
  let fixture = try PledgeFixture(scriptEdit: { text in
    switch mode {
    case "seed":
      return text.replacingOccurrences(
        of: "profile_seed = w.board_seed_u32", with: "profile_seed = 0")
    case "reward": return text.replacingOccurrences(of: "reward = 0", with: "reward = 1")
    default: return text.replacingOccurrences(of: "for tier = 1, 3 do", with: "for tier = 1, 2 do")
    }
  })
  defer { fixture.clean() }
  var game = fixture.game()
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.ensureContractBoard(fixture.pack) }
  #expect(game.commander == before)
}

@Test func pledgeKeepsRealLegacyPayloadAndLivingPassengerCustodyOutsideOrdinaryFood() throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs")
  let legacy = try MissionPackLibrary.read(examples.appendingPathComponent("courier.toml"))
  game.missionPacks = try .checked(MissionPackLibrary.bundled.entries + [legacy])
  game.key("b")
  #expect(game.offeredPack?.pack.id == legacy.pack.id)
  game.key("return")
  #expect(game.commander.missionProgress[legacy.pack.stateID]?.payloads["parcel"] == 1)
  game.screen = .status
  try game.confirmPassengerBerth(game.passengerBerthQuote)
  let passengers = try ScriptPackLibrary.read(
    examples.appendingPathComponent("scripted-passengers"))
  game.scriptPacks.append(passengers)
  _ = try game.acceptScriptMission(passengers)
  #expect(game.commander.accommodation.people.count == 1)
  let protectedFolder = fixture.directory.appendingPathComponent("protected-food")
  try FileManager.default.copyItem(
    at: examples.appendingPathComponent("scripted-courier"), to: protectedFolder)
  let module = protectedFolder.appendingPathComponent("scripts/main.lua")
  let text = try String(contentsOf: module, encoding: .utf8).replacingOccurrences(
    of: "\"supplies\"", with: "\"food\"")
  try text.write(to: module, atomically: true, encoding: .utf8)
  let protected = try ScriptPackLibrary.read(protectedFolder)
  game.scriptPacks.append(protected)
  let id = try game.acceptScriptMission(protected)
  #expect(game.commander.scriptState.instances[id]?.payloads["food"] == 1)
  let (key, offer) = try fixture.offer(&game, variant: .food)
  let before = game.commander
  #expect(before.cargo[Game.pledgeFood] == 0 && before.cargoTonnes > 0)
  #expect(!game.contractAcceptanceQuote(board: key, offer: offer.id).allowed)
  game.commander.cargo[Game.pledgeFood] = 1  // Separate actual starting ordinary Food fixture.
  _ = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
  #expect(game.commander.cargo[Game.pledgeFood] == 0)
  #expect(game.commander.missionProgress == before.missionProgress)
  #expect(game.commander.accommodation == before.accommodation)
  #expect(game.commander.scriptState.instances[id] == before.scriptState.instances[id])
  #expect(game.commander.cargoTonnes == before.cargoTonnes)
}

@Test func pledgeHullChangesMissingPackAndNewContentKeepOriginalStandingAndReceipt() async throws {
  let fixture = try PledgeFixture()
  let updated = try PledgeFixture(manifestEdit: {
    $0.replacingOccurrences(of: "version = \"1.0.0\"", with: "version = \"1.0.1\"")
  })
  defer {
    fixture.clean()
    updated.clean()
  }
  var game = fixture.game(cash: 10_000_000)
  let target = try #require(ShipCatalogue.ship("SH013")?.game)
  game.commander.fuel = target.fuel
  let (key, offer) = try fixture.offer(&game)
  let id = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
  let ledger = try #require(game.commander.scriptState.pledgeLedger)
  let marker = game.commander.scriptState.instances[id]?.pledgeReceiptID
  game.key("6")
  game.showroom.selection = "SH013"
  try #require(game.shipTradeQuote?.allowed == true)
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander.shipID == "SH013")
  #expect(
    game.commander.scriptState.pledgeLedger == ledger
      && game.commander.scriptState.instances[id]?.pledgeReceiptID == marker)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  var changed = updated.game()
  changed.scriptPacks = [updated.pack]
  let missing = GameRuntime(game: changed)
  for _ in 0..<3 { try await missing.load(from: fixture.save) }
  let restored = await missing.snapshot()
  #expect(restored.commander.scriptState.pledgeLedger == ledger)
  #expect(restored.commander.scriptState.instances[id]?.outcome == .complete)
  let row = try #require(restored.missionCatalogue.first { $0.savedInstance == id })
  #expect(row.status == .complete && row.briefing.contains("Donation: 500.0 CR."))
  let next = try await missing.generateContractBoard(packDigest: updated.pack.digest)
  let nextOffer = try #require(
    await missing.snapshot().commander.contracts.boards[next]?.offers.first)
  let quote = await missing.contractAcceptanceQuote(board: next, offer: nextOffer.id)
  #expect(quote.pledge?.before.standing == 1)
  _ = try await missing.confirmContract(quote)
  #expect(await missing.snapshot().commander.scriptState.pledgeLedger?.receipts.count == 2)
  #expect(
    await missing.snapshot().commander.scriptState.pledgeLedger?.receipt(instance: id)
      == ledger.receipt(instance: id))
}

struct PledgeRawLoadCase: Sendable {
  let shape: String
  let persistMigrations: Bool
  static let cases = ["both", "ledger-only", "marker-only"].flatMap { shape in
    [false, true].map { PledgeRawLoadCase(shape: shape, persistMigrations: $0) }
  }
}

@Test(arguments: PledgeRawLoadCase.cases)
func pledgeRawLegacyEvidenceRefusesBeforeChangingLiveContext(testcase: PledgeRawLoadCase)
  async throws
{
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var donated = fixture.game()
  let (board, offer) = try fixture.offer(&donated)
  let id = try donated.confirmContract(
    donated.contractAcceptanceQuote(board: board, offer: offer.id))
  #expect(
    donated.commander.valid && donated.commander.scriptState.instances[id]?.outcome == .complete)
  var raw = donated.commander
  if testcase.shape == "ledger-only" { raw.scriptState.instances[id]?.pledgeReceiptID = nil }
  if testcase.shape == "marker-only" { raw.scriptState.pledgeLedger = nil }
  let bytes = try JSONEncoder().encode(raw)
  let input = fixture.directory.appendingPathComponent("raw-downgrade.json")
  try bytes.write(to: input)
  if testcase.shape == "both" {
    let decoded = try ScriptValueStorage.decoder(typed: false).decode(Commander.self, from: bytes)
    #expect(decoded.valid)  // A genuine native donation, not a malformed-Commander rejection.
    var trusted = fixture.game()
    let loaded = trusted.load(decoded)
    #expect(
      loaded
        && trusted.commander.scriptState.pledgeLedger == donated.commander.scriptState.pledgeLedger)
  }
  var live = fixture.game(cash: 34321, food: 2)
  live.commander.name = "LIVE OWNER"
  live.openContractBoard()
  live.contractBoardKey("return")
  let runtime = GameRuntime(game: live, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let world = try ScriptValueStorage.encoder().encode(before.scriptWorldSave)
  let pointer = try Data(contentsOf: fixture.save)
  let target = await runtime.scriptSaveURL
  await #expect(throws: SaveError.self) {
    try await runtime.load(from: input, persistMigrations: testcase.persistMigrations)
  }
  let after = await runtime.snapshot()
  let afterWorld = try ScriptValueStorage.encoder().encode(after.scriptWorldSave)
  #expect(after.commander == before.commander && afterWorld == world)
  #expect(after.screen == before.screen && after.ecmControl.epoch == before.ecmControl.epoch)
  #expect(after.scriptPagePresentation == before.scriptPagePresentation)
  #expect(await runtime.scriptSaveURL == target)
  #expect(try Data(contentsOf: input) == bytes)
  #expect(try Data(contentsOf: fixture.save) == pointer)
  // The same genuine pledge still loads through its required versioned chunked save.
  let versioned = fixture.directory.appendingPathComponent("versioned-pledge.json")
  try GameRuntime.writeCommander(&donated, to: versioned)
  let missing = GameRuntime(game: Game(executive: false))
  try await missing.load(from: versioned, persistMigrations: testcase.persistMigrations)
  #expect(
    await missing.snapshot().commander.scriptState.pledgeLedger
      == donated.commander.scriptState.pledgeLedger)
  #expect(
    await missing.snapshot().commander.scriptState.instances[id]?.pledgeReceiptID
      == donated.commander.scriptState.instances[id]?.pledgeReceiptID)
}

@Test(arguments: [false, true])
func pledgeRawLegacyWithoutNativeEvidenceStillLoadsWithoutInventedStanding(persistMigrations: Bool)
  async throws
{
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var legacy = Commander()
  legacy.name = "OLD OWNER"
  legacy.credits = 12345
  legacy.cargo[Game.pledgeFood] = 1
  let bytes = try JSONEncoder().encode(legacy)
  let input = fixture.directory.appendingPathComponent("genuine-legacy.json")
  try bytes.write(to: input)
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  try await runtime.load(from: input, persistMigrations: persistMigrations)
  let loaded = await runtime.snapshot()
  #expect(loaded.commander.name == legacy.name && loaded.commander.credits == legacy.credits)
  #expect(
    loaded.commander.cargo == legacy.cargo && loaded.commander.scriptState.pledgeLedger == nil)
  #expect(loaded.commander.scriptState.instances.values.allSatisfy { $0.pledgeReceiptID == nil })
  #expect(await runtime.scriptSaveURL == input)
  if !persistMigrations { #expect(try Data(contentsOf: input) == bytes) }
}

@Test(arguments: ["start", "standalone", "restart-write"])
func pledgeTrialPreparationAndRestartWriteFailuresKeepThePreviousRuntime(mode: String) async throws
{
  let fixture = try PledgeFixture(
    manifestEdit: {
      mode == "restart-write" ? $0 : $0.replacingOccurrences(of: "offer = 0", with: "offer = 15")
    })
  defer { fixture.clean() }
  var live = fixture.game()
  live.openGallery()
  let runtime = GameRuntime(game: live, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let liveBytes = try Data(contentsOf: fixture.save)
  var namespace: URL?
  var backup: URL?
  var trialBytes: Data?
  defer {
    if let namespace { try? FileManager.default.removeItem(at: namespace) }
    if let backup { try? FileManager.default.removeItem(at: backup) }
  }
  if mode == "restart-write" {
    try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest)
    let own = try #require(await runtime.gallerySaveDirectory())
    let copy = fixture.directory.appendingPathComponent("trial-backup")
    trialBytes = try Data(contentsOf: own.appendingPathComponent("commander.json"))
    try FileManager.default.moveItem(at: own, to: copy)
    namespace = own
    backup = copy
    try Data("blocked trial folder".utf8).write(to: own)
  }
  var held = Controls()
  held.roll = 0.25
  held.fire = true
  await runtime.setControls(held)
  let before = await runtime.snapshot()
  let beforeNamespace = await runtime.gallerySaveDirectory()
  let beforeURL = await runtime.scriptSaveURL
  let beforeParent = await runtime.galleryParent?.game.commander
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  let world = try encoder.encode(before.scriptWorldSave)
  await #expect(throws: (any Error).self) {
    switch mode {
    case "start": try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest)
    case "standalone": _ = try await runtime.scriptGalleryTrial(packDigest: fixture.pack.digest)
    default: try await runtime.restartScriptGalleryTrial()
    }
  }
  let after = await runtime.snapshot()
  let controls = await runtime.controls
  #expect(after.commander == before.commander && after.ecmControl.epoch == before.ecmControl.epoch)
  #expect(after.screen == before.screen && after.isMissionTrial == before.isMissionTrial)
  #expect(try encoder.encode(after.scriptWorldSave) == world)
  #expect(controls.roll == held.roll && controls.fire == held.fire)
  #expect(await runtime.gallerySaveDirectory() == beforeNamespace)
  #expect(await runtime.scriptSaveURL == beforeURL)
  #expect(await runtime.galleryParent?.game.commander == beforeParent)
  #expect(try Data(contentsOf: fixture.save) == liveBytes)
  if let backup {
    #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == trialBytes)
  }
}
