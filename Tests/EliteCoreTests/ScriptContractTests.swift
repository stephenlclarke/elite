import Foundation
import Testing

@testable import EliteCore

private var contractExample: URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-contracts")
}
private struct ContractFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(edits: [(String, String)] = [], source: String? = nil) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "contracts-" + UUID().uuidString)
    root = directory
    var ready = false
    defer { if !ready { try? FileManager.default.removeItem(at: directory) } }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let copy = directory.appendingPathComponent("pack")
    try FileManager.default.copyItem(at: contractExample, to: copy)
    let module = copy.appendingPathComponent("scripts/main.lua")
    var text = try source ?? String(contentsOf: module, encoding: .utf8)
    for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
    try text.write(to: module, atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(copy)
    ready = true
  }
  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    return game
  }
  /// Freeze the cash boundary independently of the approved fresh commander.
  func cashGame() -> Game {
    var game = Game(executive: false)
    game.commander.credits = 1000
    game.screen = .status
    game.scriptPacks = [pack]
    return game
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test func frozenContractReviewRejectsChangedPropertyAndFreshReviewCanAccept() async throws {
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  var game = await runtime.snapshot()
  let offer = try #require(game.commander.contracts.boards[key]?.offers.first)
  let quote = game.contractAcceptanceQuote(board: key, offer: offer.id)
  try #require(quote.allowed)
  let captured = quote.resources

  game.commander.credits += 1
  game.commander.cargo[0] = 1
  let changed = game.commander
  #expect(throws: MissionPackError.self) { try game.confirmContract(quote) }
  #expect(game.commander == changed && quote.resources == captured)
  #expect(quote.resources != game.commander.contractQuoteResources)

  let fresh = game.contractAcceptanceQuote(board: key, offer: offer.id)
  try #require(fresh.allowed)
  #expect(fresh.resources == game.commander.contractQuoteResources)
  let accepted = try game.confirmContract(fresh)
  #expect(game.commander.contracts.boards[key]?.offers.first?.status == .accepted(accepted))
}

@Test func nativeBoardBrowsingBackAndReloadPreserveTermsWithoutAcceptingOrStartingADeadline()
  async throws
{
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.cashGame(), saveURL: fixture.save)
  await runtime.key("contracts-open")
  let opened = await runtime.snapshot()
  #expect(opened.screen == .contracts && opened.contractBoard.rows.count == 2)
  #expect(opened.commander.credits == 1000 && opened.commander.cargoTonnes == 0)
  #expect(opened.commander.scriptState.instances.isEmpty)
  let terms = opened.commander.contracts
  let pointer = try Data(contentsOf: fixture.save)
  await runtime.key("return")
  #expect(await runtime.snapshot().contractBoard.detail)
  #expect(await runtime.snapshot().contractBoard.action == .back)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == opened.commander)
  #expect(try Data(contentsOf: fixture.save) == pointer)
  let restored = GameRuntime(game: fixture.cashGame())
  try await restored.load(from: fixture.save)
  #expect(await restored.snapshot().commander.contracts == terms)
  #expect(await restored.snapshot().screen == .contracts)
  #expect(await restored.snapshot().commander.scriptState.instances.isEmpty)
  await restored.key("contracts-open")
  #expect(await restored.snapshot().commander.contracts == terms)
}

@Test func acceptanceAnchorsDeadlineOnceAndRepeatedConfirmationReturnsTheSameJobReceipt()
  async throws
{
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.cashGame(), saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let board = try #require(await runtime.snapshot().commander.contracts.boards[key])
  let offer = try #require(board.offers.first)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  #expect(quote.allowed)
  for _ in 0..<50 { _ = await runtime.advance(delta: 0.1) }
  let acceptedAt = await runtime.snapshot().commander.scriptState.localSeconds
  let id = try await runtime.confirmContract(quote)
  let accepted = await runtime.snapshot().commander
  #expect(accepted.credits == 1000 - offer.deposit)
  #expect(accepted.cargoTonnes == Int(offer.parameters["tonnes"]!.integer!))
  #expect(accepted.scriptState.instances[id]?.contract?.acceptedAt == acceptedAt)
  #expect(accepted.scriptState.instances[id]?.contract?.deadline == acceptedAt + offer.duration)
  #expect(accepted.contracts.boards[key]?.offers.first?.status == .accepted(id))
  let repeated = try await runtime.confirmContract(quote)
  #expect(repeated == id)
  #expect(await runtime.snapshot().commander == accepted)
  let other = board.offers[1]
  #expect(!(await runtime.contractAcceptanceQuote(board: key, offer: other.id)).allowed)
  let restored = GameRuntime(game: fixture.cashGame())
  try await restored.load(from: fixture.save)
  #expect(await restored.snapshot().commander == accepted)
}

@Test func hourlyRefreshRefusesAStaleOfferAndNeverRerollsTheAcceptedContract() async throws {
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.credits = 1000
  game.commander.scriptState.localSeconds = 3599.95
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let old = try #require(await runtime.snapshot().commander.contracts.boards[key])
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: old.offers[0].id)
  _ = await runtime.advance(delta: 0.1)
  await #expect(throws: MissionPackError.self) { try await runtime.confirmContract(quote) }
  #expect(await runtime.snapshot().commander.credits == 1000)
  #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  _ = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let current = try #require(await runtime.snapshot().commander.contracts.boards[key])
  #expect(current.revision == 1 && current.offers[0].id != old.offers[0].id)
  let acceptedQuote = await runtime.contractAcceptanceQuote(board: key, offer: current.offers[0].id)
  let id = try await runtime.confirmContract(acceptedQuote)
  let frozen = try #require(await runtime.snapshot().commander.scriptState.instances[id]?.contract)
  _ = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.contract == frozen)
}

@Test func declineAndFitFailuresLeaveAllPropertyAndOtherOffersIntact() async throws {
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.cargo[0] = game.commander.tradeCargoCapacity
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let board = try #require(await runtime.snapshot().commander.contracts.boards[key])
  #expect(!(await runtime.contractAcceptanceQuote(board: key, offer: board.offers[0].id)).allowed)
  let before = await runtime.snapshot().commander
  try await runtime.declineContract(board: key, offer: board.offers[0].id)
  let declined = await runtime.snapshot().commander
  #expect(declined.cargo == before.cargo && declined.credits == before.credits)
  #expect(declined.scriptState.instances.isEmpty)
  #expect(declined.contracts.boards[key]?.offers[0].status == .declined)
  #expect(declined.contracts.boards[key]?.offers[1] == board.offers[1])
  _ = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  #expect(await runtime.snapshot().commander.contracts == declined.contracts)
  let restored = GameRuntime(game: fixture.game())
  try await restored.load(from: fixture.save)
  #expect(await restored.snapshot().commander.contracts == declined.contracts)
}

@Test func theAuthoredBoardJobTravelsDeliversPaysOnceAndCreatesASeparateRepeatInstance()
  async throws
{
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.installTargetingComputer(.docking)
  game.commander.installShieldBooster(.capital)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let offer = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let id = try await runtime.confirmContract(quote)
  let destination = game.systems[offer.destinationSystem]
  await runtime.selectSystem(x: destination.x, y: destination.y)
  await runtime.key("0")
  var controls = Controls()
  controls.throttle = 1
  await runtime.setControls(controls)
  var scene = await runtime.snapshot()
  for _ in 0..<200 where scene.massLocked { scene = await runtime.advance(delta: 0.1) }
  await runtime.setControls(Controls())
  await runtime.key("h")
  #expect(await runtime.snapshot().jumpCountdown != nil)
  for _ in 0..<200 {
    scene = await runtime.advance(delta: 0.1)
    if scene.commander.system == offer.destinationSystem { break }
  }
  #expect(scene.commander.system == offer.destinationSystem)
  for _ in 0..<8 {
    await runtime.key("tab")
    if await runtime.snapshot().autoPilot.targetID == 0 { break }
  }
  for _ in 0..<10000 where !scene.docked && scene.screen != .gameOver {
    scene = await runtime.advance(delta: 0.02)
  }
  #expect(scene.docked && scene.dockedAtMainStation)
  let beforePayment = scene.commander.credits
  await runtime.key("contacts-open")
  await runtime.key("return")
  let completed = await runtime.snapshot().commander
  #expect(completed.scriptState.instances[id]?.outcome == .complete)
  #expect(
    completed.cargoTonnes == 0 && completed.credits == beforePayment + offer.reward + offer.deposit)
  #expect(
    completed.scriptState.instances[id]?.contract?.settlementAmount == offer.reward + offer.deposit)
  await runtime.key("contacts-open")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.credits == completed.credits)
  await runtime.key("3")
  await runtime.key("return")
  let newBoard = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let nextOffer = try #require(
    await runtime.snapshot().commander.contracts.boards[newBoard]?.offers.first)
  let nextQuote = await runtime.contractAcceptanceQuote(board: newBoard, offer: nextOffer.id)
  let next = try await runtime.confirmContract(nextQuote)
  let final = await runtime.snapshot()
  #expect(next != id && final.commander.scriptState.instances.count == 2)
  #expect(final.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(final.commander.scriptState.instances[next]?.outcome == .active)
  #expect(final.scriptGallery.filter { $0.savedInstance != nil }.count == 2)
  #expect(
    final.commander.scriptState.instances[next]?.contract?.station.system == offer.destinationSystem
  )
}

@Test func hullChangesInvalidateOldQuotesAndRevealTheSameOfferWithItsNewActualFit() throws {
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.scriptDurabilityAvailable = true
  game.commander.credits = 10_000_000
  let destinationHull = try #require(ShipCatalogue.ship("SH013")?.game)
  game.commander.fuel = destinationHull.fuel
  try #require(game.commander.valid)
  let ordinaryCargo = game.commander.tradeCargoCapacity
  game.commander.cargo[0] = ordinaryCargo
  let key = try game.ensureContractBoard(fixture.pack)
  let board = try #require(game.commander.contracts.boards[key])
  let before = game.contractAcceptanceQuote(board: key, offer: board.offers[0].id)
  #expect(!before.allowed)
  game.key("6")
  game.showroom.selection = "SH013"
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander.shipID == "SH013")
  #expect(throws: MissionPackError.self) { try game.confirmContract(before) }
  let after = game.contractAcceptanceQuote(board: key, offer: board.offers[0].id)
  #expect(after.allowed && game.commander.contracts.boards[key] == board)
  game.selection = Equipment.all.firstIndex { $0.name == "Missile" }!
  game.purchase()
  #expect(throws: MissionPackError.self) { try game.confirmContract(after) }
  let latest = game.contractAcceptanceQuote(board: key, offer: board.offers[0].id)
  _ = try game.confirmContract(latest)
  #expect(
    game.commander.cargoTonnes == ordinaryCargo
      + Int(board.offers[0].parameters["tonnes"]!.integer!))
}

@Test func genuineDeadlinePulsesAndLateHandoffsUseFrozenFailureTermsWithoutRevivingSuccess()
  async throws
{
  for fullPay in [false, true] {
    let fixture = try ContractFixture(
      edits: fullPay
        ? [
          ("failure_reward = 0", "failure_reward = 500 + 100 * tonnes"),
          ("refund_on_failure = false", "refund_on_failure = true"),
        ] : [])
    defer { fixture.clean() }
    var game = fixture.game()
    game.commander.credits = 1000
    game.scriptDurabilityAvailable = true
    let key = try game.ensureContractBoard(fixture.pack)
    let offer = try #require(game.commander.contracts.boards[key]?.offers.first)
    let id = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
    game.commander.system = offer.destinationSystem
    game.commander.scriptState.localSeconds = offer.duration - 0.05
    let runtime = GameRuntime(game: game, saveURL: fixture.save)
    _ = await runtime.advance(delta: 0.1)
    let expired = await runtime.snapshot()
    #expect(expired.commander.scriptState.instances[id]?.timers["contract-deadline"] == nil)
    #expect(expired.commander.scriptState.instances[id]?.outcome == .active)
    #expect(expired.activeContractSummary.first?.contains("OVERDUE") == true)
    #expect(expired.commander.cargoTonnes > 0)
    await runtime.key("contacts-open")
    await runtime.key("return")
    let settled = await runtime.snapshot().commander
    let amount = fullPay ? offer.reward + offer.deposit : 0
    #expect(settled.credits == 1000 - offer.deposit + amount && settled.cargoTonnes == 0)
    #expect(settled.scriptState.instances[id]?.outcome == .failed)
    #expect(settled.scriptState.instances[id]?.contract?.settlementOutcome == .failed)
    #expect(settled.scriptState.instances[id]?.contract?.settlementAmount == amount)
    let restored = GameRuntime(game: fixture.game())
    try await restored.load(from: fixture.save)
    #expect(await restored.snapshot().commander == settled)
    await restored.key("contacts-open")
    await restored.key("return")
    #expect(await restored.snapshot().commander.credits == settled.credits)
  }
}

@Test func legacyFreeRefitPreservesOwnedEquipmentAndVirtualCargoButContractsStillRequireRealFit()
  async throws
{
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.screen = .secret
  game.commander = Commander()
  game.commander.shipID = "SH013"
  game.commander.xyzzyActive = true
  game.commander.cargo[0] = 80
  game.commander.equipment.insert(TargetingTier.basic.equipmentName)
  try game.commander.prepareEquipment(legacy: false)
  let original = try #require(
    game.commander.equipmentInventory?.items.first {
      $0.node.key == TargetingTier.basic.equipmentName
    })
  let cash = game.commander.credits
  try #require(!game.commander.xyzzyCashGranted)
  // Settle the existing XYZZY policy before testing refit and exact save/load identity.
  game.commander.migrateXYZzyPolicy()
  try #require(game.commander.xyzzyActive && game.commander.xyzzyCashGranted)
  #expect(game.commander.credits == cash && !game.commander.unlimitedCash)
  #expect(!game.commander.unlimitedJumps)
  let before = game.commander
  let inventory = try #require(before.equipmentInventory)
  try #require(inventory.items.allSatisfy { $0.boundHull == nil })
  try #require(!game.requiresScriptDurability && !before.usesEMPSaveVersion)
  try #require(before.scriptState.calendarLedger == nil && !before.usesEconomyMiningSaveVersion)
  #expect(game.commander == before)
  var expectedInitialized = before
  expectedInitialized.mirrorFittedEquipment()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let initialized = await runtime.snapshot()
  try #require(initialized.commander == expectedInitialized)
  try #require(!initialized.requiresScriptDurability && !initialized.commander.usesEMPSaveVersion)
  try #require(initialized.commander.scriptState.calendarLedger == nil)
  #expect(!FileManager.default.fileExists(atPath: fixture.save.path))
  await runtime.key("c")
  let published = await runtime.snapshot()
  let refitted = published.commander
  #expect(refitted.shipID == "SH023" && refitted.cargo[0] == 80 && refitted.credits == cash)
  #expect(refitted.unlimitedCargo && refitted.valid)
  #expect(refitted.equipmentInventory?.items.first { $0.id == original.id }?.location == nil)
  #expect(published.requiresScriptDurability && refitted.usesEMPSaveVersion)
  try #require(refitted.fittedEquipment(at: .utility(.empPirateBlaster)) != nil)
  #expect(refitted.scriptState.calendarLedger == ScriptCalendarLedger(origin: .newCommander))
  #expect(refitted.usesEconomyMiningSaveVersion && refitted.miningLedger == MiningLedger())
  #expect(refitted.xyzzyActive && refitted.xyzzyCashGranted && !refitted.unlimitedCash)
  #expect(!refitted.unlimitedJumps && refitted.scriptState.instances.isEmpty)
  let refittedInventory = try #require(refitted.equipmentInventory)
  #expect(
    refittedInventory.owner == inventory.owner
      && refittedInventory.activeHull != inventory.activeHull)
  for item in inventory.items {
    let retained = try #require(refittedInventory.items.first { $0.id == item.id })
    #expect(retained.moved(to: nil) == item.moved(to: nil))
  }
  #expect(refitted.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  let autoBytes = try Data(contentsOf: fixture.save)
  let autoPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: autoBytes)
  try #require(autoPointer.format == "elite-script-save" && autoPointer.schemaVersion == 26)
  try #require(
    autoPointer.scope == "commander" && autoPointer.valueCodec == ScriptValueStorage.codec)
  let autoDirectory = try ScriptSaveStore.generationDirectory(
    autoPointer.generation, from: fixture.save)
  let names = Set(["commander.json", "missions.json", "world.json", "contracts.json"])
  try #require(Set(autoPointer.hashes.keys) == names)
  try #require(
    Set(try FileManager.default.contentsOfDirectory(atPath: autoDirectory.path)) == names)
  var autoChunks: [String: Data] = [:]
  for name in names {
    let chunk = try Data(contentsOf: autoDirectory.appendingPathComponent(name))
    try #require(ScriptPackLibrary.hash(chunk) == autoPointer.hashes[name])
    autoChunks[name] = chunk
  }
  let (autoSaved, autoWorld) = try ScriptSaveStore.read(autoBytes, from: fixture.save)
  #expect(autoSaved == refitted && autoWorld.valid && autoWorld.consistent(with: autoSaved))
  let encoder = ScriptValueStorage.encoder()
  #expect(try encoder.encode(autoWorld) == encoder.encode(published.scriptWorldSave))
  try await runtime.save(to: fixture.save)
  let explicitlySaved = await runtime.snapshot().commander
  #expect(explicitlySaved == refitted)
  let explicitBytes = try Data(contentsOf: fixture.save)
  let explicitPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: explicitBytes)
  #expect(
    explicitPointer.schemaVersion == 26 && explicitPointer.generation != autoPointer.generation)
  let (persisted, explicitWorld) = try ScriptSaveStore.read(explicitBytes, from: fixture.save)
  #expect(explicitWorld.valid && explicitWorld.consistent(with: persisted))
  #expect(try encoder.encode(explicitWorld) == encoder.encode(autoWorld))
  for (name, chunk) in autoChunks {
    #expect(try Data(contentsOf: autoDirectory.appendingPathComponent(name)) == chunk)
  }
  #expect(persisted == refitted && persisted.xyzzyCashGranted)
  let decoded = GameRuntime(game: fixture.game())
  try await decoded.load(from: fixture.save, persistMigrations: false)
  let reloaded = await decoded.snapshot().commander
  #expect(reloaded.xyzzyCashGranted == refitted.xyzzyCashGranted && reloaded.credits == cash)
  #expect(reloaded == refitted)
  #expect(try Data(contentsOf: fixture.save) == explicitBytes)
  await runtime.key("escape")
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let offer = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
  let beforeQuote = await runtime.snapshot().commander
  try #require(beforeQuote.passengerFit?.allowed == false)
  try #require(beforeQuote.standardCargoCapacity < beforeQuote.cargo[0])
  let quoteBytes = try Data(contentsOf: fixture.save)
  #expect(!(await runtime.contractAcceptanceQuote(board: key, offer: offer.id)).allowed)
  #expect(await runtime.snapshot().commander == beforeQuote)
  #expect(try Data(contentsOf: fixture.save) == quoteBytes)
  #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  await runtime.key("screen:9")
  let snapshot = await runtime.snapshot()
  try #require(snapshot.screen == .inventory)
  let item = try #require(
    snapshot.commander.equipmentInventory?.items.first {
      $0.node.key == "E.C.M. System" && $0.location != nil
    })
  let store = try #require(snapshot.inventoryActionPreview(for: .equipment(item)).command)
  let stored = await runtime.equipmentTransaction(.inventory(store))
  #expect(stored.applied)
  let after = await runtime.snapshot()
  #expect(after.commander.equipmentInventory?.items.first { $0.id == item.id }?.location == nil)
  #expect(await runtime.snapshot().commander.cargo[0] == 80)
  let retained = try #require(after.commander.equipmentInventory?.items.first { $0.id == item.id })
  #expect(retained.moved(to: nil) == item.moved(to: nil))
  let (storedCommander, storedWorld) = try ScriptSaveStore.read(
    Data(contentsOf: fixture.save), from: fixture.save)
  #expect(storedCommander == after.commander)
  #expect(storedWorld.valid && storedWorld.consistent(with: storedCommander))
}

@Test func acceptedCancellationRequiresItsOriginalStationContactAndReturnsOnlyItsOwnCargo()
  async throws
{
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  await runtime.key("contracts-open")
  let scene = await runtime.snapshot()
  let key = try #require(scene.commander.contracts.boards.keys.first)
  let offer = try #require(scene.commander.contracts.boards[key]?.offers.first)
  let other = try #require(scene.commander.contracts.boards[key]?.offers.last)
  let id = try await runtime.confirmContract(
    await runtime.contractAcceptanceQuote(board: key, offer: offer.id))
  await runtime.key("b")
  #expect(await runtime.snapshot().screen == .handoff)
  await runtime.key("escape")
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .active)
  #expect(await runtime.snapshot().commander.cargoTonnes > 0)
  await runtime.key("b")
  await runtime.key("return")
  let cancelled = await runtime.snapshot()
  #expect(cancelled.screen == .contracts)
  #expect(cancelled.commander.scriptState.instances[id]?.outcome == .abandoned)
  #expect(
    cancelled.commander.cargoTonnes == 0
      && cancelled.commander.credits == scene.commander.credits - offer.deposit)
  #expect(cancelled.commander.scriptState.instances[id]?.contract?.settlementAmount == 0)
  #expect(cancelled.commander.contracts.boards[key]?.offers.last == other)
  #expect(cancelled.contractBoard.rows.count == 1 && cancelled.contractBoard.rows[0].reason == nil)
}

@Test func rejectedGeneratorsCannotPaySpawnConsumeRandomnessOrPublishPartialBoards() async throws {
  let offer =
    "{key='a',title='Test',briefing='Test',destination_galaxy=0,destination_system=129,reward=500,deposit=0,failure_reward=0,refund_on_failure=false,duration=300,parameters={}}"
  let bodies = [
    "return {data={},commands={}}",
    "return {data={offers={\(offer)}},commands={{op='credits',id='illegal',amount=100000}}}",
    "return {data={offers={{key='incomplete'}}},commands={}}",
    "return {data={offers={\(offer),\(offer)}},commands={}}",
    "local a={} for i=1,17 do a[i]=\(offer) end return {data={offers=a},commands={}}",
    "return {data={offers={\(offer.replacingOccurrences(of: "reward=500", with: "reward=9223372036854775807"))}},commands={}}",
    "while true do end",
  ]
  for body in bodies {
    let source =
      "local function no(e,w,d) return {data=d,commands={}} end return {generate=function(e,w,d) \(body) end,accepted=no,contact=no,confirm=no,expired=no}"
    let fixture = try ContractFixture(source: source)
    defer { fixture.clean() }
    let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
    let before = await runtime.snapshot()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let physics = try encoder.encode(before.scriptSimulationSave)
    await #expect(throws: MissionPackError.self) {
      try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
    }
    #expect(await runtime.snapshot().commander == before.commander)
    #expect(try encoder.encode(await runtime.snapshot().scriptSimulationSave) == physics)
    #expect(!FileManager.default.fileExists(atPath: fixture.save.path))
  }
}

@Test func contractTrialsKeepTheLiveCommanderWriterAndCargoIsolated() async throws {
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.name = "KEEP"
  game.commander.credits = 7654
  let live = GameRuntime(game: game, saveURL: fixture.save)
  try await live.save(to: fixture.save)
  // Saving publishes canonical policy/calendar state; isolate trial effects after that barrier.
  let before = await live.snapshot().commander
  #expect(before.name == "KEEP" && before.credits == 7654)
  #expect(before.cargo == game.commander.cargo && before.cargoTonnes == 0)
  let bytes = try Data(contentsOf: fixture.save)
  let trial = try await live.scriptGalleryTrial(packDigest: fixture.pack.digest, seed: 123)
  let directory = await trial.gallerySaveDirectory()
  let namespace = try #require(directory)
  defer { try? FileManager.default.removeItem(at: namespace) }
  let scene = await trial.snapshot()
  #expect(scene.isMissionTrial && scene.commander.scriptState.instances.count == 1)
  #expect(scene.commander.credits == 900 && scene.commander.cargoTonnes > 0)
  let key = try #require(scene.commander.contracts.boards.keys.first)
  let offer = try #require(scene.commander.contracts.boards[key]?.offers.first)
  let foreignQuote = await live.contractAcceptanceQuote(board: key, offer: offer.id)
  await #expect(throws: MissionPackError.self) { try await trial.confirmContract(foreignQuote) }
  _ = try await trial.saveForInterface()
  _ = try await trial.loadForInterface()
  let restoredTrial = await trial.snapshot()
  let retainedLive = await live.snapshot()
  let retainedBytes = try Data(contentsOf: fixture.save)
  #expect(restoredTrial.commander == scene.commander)
  #expect(retainedLive.commander == before)
  #expect(retainedBytes == bytes)
}

@Test func realContractFitRejectsAZeroHoldDespiteTheLegacyUnlimitedCargoSwitch() throws {
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  var game = fixture.cashGame()
  game.commander.shipID = "SH168"
  game.commander.fuel = game.commander.fuelCapacity
  game.commander.missiles = 1
  try #require(game.commander.nativePerformance.cargo == 0)
  game.commander.unlimitedCargo = true
  game.scriptDurabilityAvailable = true
  let key = try game.ensureContractBoard(fixture.pack)
  let offer = try #require(game.commander.contracts.boards[key]?.offers.first)
  let quote = game.contractAcceptanceQuote(board: key, offer: offer.id)
  #expect(!quote.allowed && game.commander.scriptState.instances.isEmpty)
  #expect(game.commander.cargoTonnes == 0 && game.commander.credits == 1000)
}

@Test func alteredOrLinkedContractChunksCannotChangeAcceptedTermsOrReplaceLiveState() async throws {
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let offer = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
  _ = try await runtime.confirmContract(
    await runtime.contractAcceptanceQuote(board: key, offer: offer.id))
  let before = await runtime.snapshot().commander
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  let chunk = generation.appendingPathComponent("contracts.json")
  var root = try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: chunk)) as? [String: Any])
  var boards = try #require(root["boards"] as? [String: Any])
  var board = try #require(boards[key] as? [String: Any])
  var offers = try #require(board["offers"] as? [[String: Any]])
  offers[0]["reward"] = offer.reward + 1
  board["offers"] = offers
  boards[key] = board
  root["boards"] = boards
  let altered = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
  try altered.write(to: chunk)
  var hashes = pointer.hashes
  hashes["contracts.json"] = ScriptPackLibrary.hash(altered)
  let changed = ScriptSavePointer(
    format: pointer.format, schemaVersion: pointer.schemaVersion,
    generation: pointer.generation, hashes: hashes, scope: pointer.scope,
    valueCodec: pointer.valueCodec)
  try JSONEncoder().encode(changed).write(to: fixture.save)
  await #expect(throws: (any Error).self) { try await runtime.load(from: fixture.save) }
  #expect(await runtime.snapshot().commander == before)
  try await runtime.save(to: fixture.save)
  let repaired = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let next = try ScriptSaveStore.generationDirectory(repaired.generation, from: fixture.save)
    .appendingPathComponent("contracts.json")
  let outside = fixture.root.appendingPathComponent("outside-contracts.json")
  try FileManager.default.moveItem(at: next, to: outside)
  try FileManager.default.createSymbolicLink(at: next, withDestinationURL: outside)
  await #expect(throws: (any Error).self) { try await runtime.load(from: fixture.save) }
  #expect(await runtime.snapshot().commander == before)
}

@Test func failedContractAcceptancePublicationKeepsTheOfferDepositAndCargoForRetry() async throws {
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let offer = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let before = await runtime.snapshot().commander
  let bytes = try Data(contentsOf: fixture.save)
  let directory = fixture.save.deletingLastPathComponent()
  let backup = fixture.root.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: directory, to: backup)
  try Data("blocked".utf8).write(to: directory)
  await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
  #expect(await runtime.snapshot().commander == before)
  #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
  try FileManager.default.removeItem(at: directory)
  try FileManager.default.moveItem(at: backup, to: directory)
  let id = try await runtime.confirmContract(quote)
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .active)
}

@Test func savedBoardSelectionSurvivesLeavingTheBoardAndReloadingWithoutRegeneratingOffers()
  async throws
{
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  await runtime.key("contracts-open")
  await runtime.key("down")
  let selected = try #require(await runtime.snapshot().contractBoard.selected?.offer?.id)
  let terms = await runtime.snapshot().commander.contracts
  await runtime.key("8")
  try await runtime.save(to: fixture.save)
  let restored = GameRuntime(game: fixture.game())
  try await restored.load(from: fixture.save)
  await restored.key("contracts-open")
  #expect(await restored.snapshot().contractBoard.selected?.offer?.id == selected)
  #expect(await restored.snapshot().commander.contracts == terms)
  #expect(await restored.snapshot().commander.scriptState.instances.isEmpty)
}

@Test func invalidSettlementAmountsAreRejectedBeforeAnyIntegerArithmeticOrPayment() throws {
  let bad = ScriptContractOffer(
    id: UUID(), key: "bad", title: "Bad", briefing: "Bad",
    destinationGalaxy: 0, destinationSystem: 129, reward: Int.max, deposit: Int.max,
    failureReward: 0, refundOnFailure: true, duration: 1, parameters: .object([:]))
  let digest = String(repeating: "a", count: 64)
  let station = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  let job = ScriptContractJob(
    boardKey: digest + "/board/" + station.key,
    provider: "test.provider", version: "1.0.0", digest: digest, station: station,
    boardRevision: 0, group: "test.provider/jobs", offer: bad, clock: .local,
    acceptedAt: 0, deadline: 1, settled: true, settlementOutcome: .complete,
    settlementAmount: 0, settledAt: 0)
  #expect(!bad.valid && !job.valid)
}

@Test func aScriptCannotPayLateSuccessByIgnoringTheActualContractDeadline() async throws {
  let fixture = try ContractFixture(edits: [
    (
      "outcome = w.contract.deadline_passed and \"failed\" or \"complete\"",
      "outcome = \"complete\""
    )
  ])
  defer { fixture.clean() }
  var game = fixture.cashGame()
  game.scriptDurabilityAvailable = true
  let key = try game.ensureContractBoard(fixture.pack)
  let offer = try #require(game.commander.contracts.boards[key]?.offers.first)
  let id = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
  game.commander.system = offer.destinationSystem
  game.commander.scriptState.localSeconds = offer.duration + 1
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  await runtime.key("contacts-open")
  let cargo = await runtime.snapshot().commander.cargoTonnes
  await runtime.key("return")
  let denied = await runtime.snapshot().commander
  #expect(denied.scriptState.instances[id]?.outcome == .active)
  #expect(denied.scriptState.instances[id]?.suspension != nil)
  #expect(denied.scriptState.instances[id]?.contract?.settled == false)
  #expect(denied.cargoTonnes == cargo && denied.credits == 1000 - offer.deposit)
}

@Test func unavailableClockProvidersRemainReferenceRowsWithoutGeneratingOrAcceptingJobs()
  async throws
{
  let fixture = try ContractFixture()
  defer { fixture.clean() }
  let directory = fixture.root.appendingPathComponent("pack")
  let manifest = directory.appendingPathComponent("manifest.toml")
  let text = try String(contentsOf: manifest, encoding: .utf8)
    .replacingOccurrences(of: "clock = \"local\"", with: "clock = \"calendar\"")
    .replacingOccurrences(
      of: "\"contracts-basic-v2\"", with: "\"contracts-basic-v2\", \"world-clocks-v1\"")
  try text.write(to: manifest, atomically: true, encoding: .utf8)
  let pack = try ScriptPackLibrary.read(directory)
  var game = fixture.game()
  game.scriptPacks = [pack]
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let before = await runtime.snapshot().commander
  await runtime.key("contracts-open")
  let reference = await runtime.snapshot()
  #expect(reference.screen == .contracts && reference.contractBoard.rows.count == 1)
  #expect(
    reference.contractBoard.rows[0].offer == nil && reference.contractBoard.rows[0].reason != nil)
  #expect(
    reference.commander.contracts.boards.isEmpty
      && reference.commander.scriptState.instances.isEmpty)
  #expect(reference.commander.credits == game.commander.credits)
  await runtime.key("return")
  await runtime.key("right")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == before)
}
