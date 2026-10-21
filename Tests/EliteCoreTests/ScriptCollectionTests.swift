import Foundation
import Testing

@testable import EliteCore

private struct CollectionFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(source: String? = nil, edits: [(String, String)] = []) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-collection-" + UUID().uuidString)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/material-collection")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let cleanupRoot = root
    var retained = false
    defer { if !retained { try? FileManager.default.removeItem(at: cleanupRoot) } }
    let folder = root.appendingPathComponent("pack")
    try FileManager.default.copyItem(at: example, to: folder)
    if let source {
      try source.write(
        to: folder.appendingPathComponent("scripts/main.lua"), atomically: true,
        encoding: .utf8)
    }
    let file = folder.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: file, encoding: .utf8)
    for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
    try text.write(to: file, atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(folder)
    retained = true
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    return game
  }
  func offer(_ runtime: GameRuntime) async throws -> UUID {
    await runtime.key("contacts-open")
    await runtime.key("return")
    let id = try #require(await runtime.snapshot().commander.scriptState.instances.keys.first)
    await runtime.key("contacts-open")
    #expect(await runtime.snapshot().scriptOffer == id)
    return id
  }
}

@Test func genuinePartialCommodityLotsConsumeOnlyOutstandingNativeUnitsAndPersist() async throws {
  let fixture = try CollectionFixture()
  defer { fixture.clean() }
  var initial = fixture.game()
  initial.commander.cargo[2] = 3
  initial.commander.cargo[9] = 2
  initial.commander.cargo[14] = 1
  initial.commander.cargo[0] = 1
  let runtime = GameRuntime(game: initial, saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  let quoted = await runtime.snapshot()
  let quote = try #require(quoted.scriptPresentedDialogue?.collectionQuote)
  #expect(quote.items.first?.quantity == 3 && quote.items.last?.unit == "kg")
  #expect(quoted.offeredScriptText?.contains("Platinum: transfer 1 kg") == true)
  await runtime.key("return")
  let partial = await runtime.snapshot()
  let collection = try #require(
    partial.commander.scriptState.instances[id]?.collections["materials"])
  let first = try #require(collection.lots.values.first)
  #expect(first.massGrams == 5_001_000 && first.cause.mainStation && first.committed.mainStation)
  #expect(collection.delivered(2) == 3 && collection.delivered(9) == 2 && !collection.complete)
  #expect(partial.commander.cargo[2] == 0 && partial.commander.cargo[14] == 0)
  #expect(partial.commander.cargo[0] == 1 && partial.commander.credits == initial.commander.credits)
  try await runtime.save(to: fixture.save)
  let restored = GameRuntime(game: fixture.game())
  try await restored.load(from: fixture.save, persistMigrations: false)
  #expect(
    await restored.snapshot().commander.scriptState.instances[id]?.collections["materials"]
      == collection)
  // A second real aboard manifest models another acquired consignment; collection state is not reset.
  var next = await restored.snapshot()
  next.commander.cargo[2] = 9
  next.commander.cargo[9] = 4
  next.commander.cargo[12] = 2
  next.commander.cargo[16] = 2
  next.commander.cargo[14] = 3
  let second = GameRuntime(game: next, saveURL: fixture.save)
  await second.key("contacts-open")
  await second.key("return")
  let complete = await second.snapshot()
  let final = try #require(complete.commander.scriptState.instances[id]?.collections["materials"])
  #expect(final.complete && final.lots.count == 2 && final.lots[first.sequence] == first)
  #expect(final.lots.values.reduce(0) { $0 + $1.massGrams } == 19_001_000)
  #expect(complete.commander.cargo[2] == 2 && complete.commander.cargo[9] == 1)
  #expect(complete.commander.cargo[14] == 3 && complete.commander.cargo[0] == 1)
  #expect(
    complete.commander.scriptState.instances[id]?.outcome == .complete && complete.commander.valid)
  try await second.save(to: fixture.save)
  let loaded = GameRuntime()
  try await loaded.load(from: fixture.save, persistMigrations: false)
  #expect(await loaded.snapshot().commander == complete.commander)
}

@Test func zeroAvailableMaterialsBackHelpAndRenderingNeverCreateALotOrConsumeStock() async throws {
  let fixture = try CollectionFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  let before = await runtime.snapshot()
  #expect(before.scriptPresentedDialogue?.collectionQuote?.positive == false)
  for _ in 0..<3 { _ = Display.blackjackHandoff(before, width: 512, height: 518) }
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander == before.commander && denied.screen == .handoff)
  #expect(denied.commander.scriptState.instances[id]?.suspension == nil)
  await runtime.key("k")
  await runtime.key("escape")
  await runtime.key("escape")
  #expect(await runtime.snapshot().commander == before.commander)
}

@Test func changedMaterialStockRejectsDisplayedQuoteBeforeLuaAndReopeningRefreshesIt() async throws
{
  let fixture = try CollectionFixture()
  defer { fixture.clean() }
  var initial = fixture.game()
  initial.commander.cargo[2] = 3
  let runtime = GameRuntime(game: initial, saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  var changed = await runtime.snapshot()
  changed.commander.cargo[2] = 1
  #expect(changed.scriptDialogueStale)
  let stale = GameRuntime(game: changed, saveURL: fixture.save)
  await stale.key("return")
  let denied = await stale.snapshot()
  #expect(denied.commander == changed.commander && denied.screen == .status)
  #expect(denied.commander.scriptState.instances[id]?.suspension == nil)
  await stale.key("contacts-open")
  #expect(
    await stale.snapshot().scriptPresentedDialogue?.collectionQuote?.items.first?.quantity == 1)
  await stale.key("return")
  let delivered = await stale.snapshot()
  #expect(delivered.commander.cargo[2] == 0)
  #expect(
    delivered.commander.scriptState.instances[id]?.collections["materials"]?.delivered(2) == 1)
}

@Test func failedPartialLotPublicationKeepsTheExactCargoOfferAndEarlierReceiptsForRetry()
  async throws
{
  let fixture = try CollectionFixture()
  defer { fixture.clean() }
  var initial = fixture.game()
  initial.commander.cargo[2] = 3
  let runtime = GameRuntime(game: initial, saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  let before = await runtime.snapshot()
  let parent = fixture.save.deletingLastPathComponent()
  let backup = fixture.root.appendingPathComponent("saved-generation")
  try FileManager.default.moveItem(at: parent, to: backup)
  try Data([1]).write(to: parent)
  await runtime.key("return")
  let failed = await runtime.snapshot()
  #expect(
    failed.commander == before.commander
      && failed.scriptPresentedDialogue == before.scriptPresentedDialogue)
  #expect(
    failed.commander.scriptState.instances[id]?.collections["materials"]?.lots.isEmpty == true)
  try FileManager.default.removeItem(at: parent)
  try FileManager.default.moveItem(at: backup, to: parent)
  await runtime.key("return")
  let retried = await runtime.snapshot()
  #expect(retried.commander.cargo[2] == 0)
  #expect(retried.commander.scriptState.instances[id]?.collections["materials"]?.lots.count == 1)
}

@Test func collectionNativeFinishGateRejectsNarrativeFlagsAndInvalidCommandFields() throws {
  let fixture = try CollectionFixture(
    source: """
      return {accepted=function(e,w,d) return {data={materials=true},commands={
        {op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}} end,
        contact=function(e,w,d) return {data=d,commands={}} end,
        confirm=function(e,w,d) return {data=d,commands={}} end}
      """)
  defer { fixture.clean() }
  var game = fixture.game()
  #expect(throws: (any Error).self) { try game.acceptScriptMission(fixture.pack) }
  #expect(game.commander.scriptState.instances.isEmpty)
  for command in [
    ScriptValue.object([
      "op": .string("collection.ensure"), "id": .string("materials"), "quantity": .integer(1),
    ]),
    .object([
      "op": .string("collection.deliver"), "id": .string("materials"), "token": .string("fake"),
    ]),
  ] {
    var state = ScriptInstance(
      id: UUID(), definition: fixture.pack.manifest.stateID,
      version: fixture.pack.manifest.version, digest: fixture.pack.digest)
    var commander = game.commander
    let event = ScriptEvent(
      sequence: 1, kind: "contact.requested", instance: state.id, values: [:], context: nil)
    #expect(throws: (any Error).self) {
      try game.applyCollectionCommand(
        command, event: event, pack: fixture.pack, state: &state, candidate: &commander)
    }
  }
}

@Test func malformedCommodityUnitsIndicesQuantitiesAndReferencesFailBeforeInstallation() throws {
  for edit in [
    ("commodity=14, unit=\"kg\"", "commodity=14, unit=\"t\""),
    ("commodity=14", "commodity=17"), ("commodity=14", "commodity=-1"),
    ("quantity=10", "quantity=0"), ("quantity=10", "quantity=1.5"),
    ("quantity=10", "quantity=1000001"), ("commodity=9", "commodity=2"),
    ("requiredCollections = [\"materials\"]", "requiredCollections = [\"missing\"]"),
    ("collection = \"materials\"", "collection = \"missing\""),
    ("\"partial-collections-v2\", ", ""), ("items = [", "unknown = true\nitems = ["),
  ] { #expect(throws: (any Error).self) { try CollectionFixture(edits: [edit]) } }
}

@Test func partialCollectionLeavesARealMarkedFirearmAndUnrelatedGoodsAboard() async throws {
  let fixture = try CollectionFixture(edits: [
    ("{commodity=2, unit=\"t\", quantity=10}", "{commodity=10, unit=\"t\", quantity=2}"),
    ("  {commodity=9, unit=\"t\", quantity=5},\n", ""),
    ("  {commodity=12, unit=\"t\", quantity=2},\n", ""),
    ("  {commodity=16, unit=\"t\", quantity=2},\n", ""),
    ("  {commodity=14, unit=\"kg\", quantity=1}\n", ""),
  ])
  defer { fixture.clean() }
  var initial = fixture.game()
  initial.commander.cargo[10] = 3
  initial.commander.cargo[0] = 1
  initial.commander.blackjack.stage = .deliverFirearm
  initial.commander.blackjack.transfers = [
    .contact, .goldAward, .goldDelivery, .report, .firearmPickup,
  ]
  let runtime = GameRuntime(game: initial, saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  let quote = try #require(await runtime.snapshot().scriptPresentedDialogue?.collectionQuote)
  #expect(quote.items.first?.aboard == 3 && quote.items.first?.available == 2)
  await runtime.key("return")
  let delivered = await runtime.snapshot()
  #expect(delivered.commander.cargo[10] == 1 && delivered.commander.markedFirearms == 1)
  #expect(
    delivered.commander.cargo[0] == 1
      && delivered.commander.blackjack == initial.commander.blackjack)
  #expect(delivered.commander.scriptState.instances[id]?.collections["materials"]?.complete == true)
  #expect(delivered.commander.valid)
}

@Test func materialOfferRequiresTheActualAssignedMainStationAndCannotUseAnEmptyStoryLedger() throws
{
  let fixture = try CollectionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try game.acceptScriptMission(fixture.pack)
  var state = try #require(game.commander.scriptState.instances[id])
  var commander = game.commander
  let event = ScriptEvent(
    sequence: game.commander.scriptState.nextEvent + 1,
    kind: "contact.requested", instance: id, values: [:], context: game.scriptEventContext(state))
  let offer = ScriptValue.object(["op": .string("dialogue.offer"), "id": .string("handoff")])
  for (galaxy, system, main) in [(1, 7, true), (0, 8, true), (0, 7, false)] {
    game.commander.galaxy = galaxy
    game.commander.system = system
    game.dockedAtMainStation = main
    commander = game.commander
    #expect(game.collectionQuote("materials", state: state) == nil)
    #expect(throws: (any Error).self) {
      try game.applyScriptCommand(
        offer, event: event, pack: fixture.pack, state: &state, candidate: &commander)
    }
  }
  game.commander.galaxy = 0
  game.commander.system = 7
  game.dockedAtMainStation = true
  state.collections = [:]
  commander = game.commander
  #expect(throws: (any Error).self) {
    try game.applyScriptCommand(
      offer, event: event, pack: fixture.pack, state: &state, candidate: &commander)
  }
}

@Test func anAdmittedFullMaterialReceiptLedgerRefusesAnotherWholeLotWithoutTruncation() async throws
{
  let fixture = try CollectionFixture(edits: [("quantity=10", "quantity=1000000")])
  defer { fixture.clean() }
  var initial = fixture.game()
  initial.commander.cargo[2] = 1
  let runtime = GameRuntime(game: initial, saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  await runtime.key("return")
  var boundary = await runtime.snapshot()
  var state = try #require(boundary.commander.scriptState.instances[id])
  var collection = try #require(state.collections["materials"])
  let first = try #require(collection.lots.values.first)
  // Admitted saved-state quota fixture; this does not claim 1024 played source handoffs.
  collection.lots = Dictionary(
    uniqueKeysWithValues: (1...1024).map { index in
      let sequence = UInt64(index)
      return (
        sequence,
        ScriptCollectionLot(
          instance: id, sequence: sequence,
          revision: first.revision, dialogue: first.dialogue, items: first.items,
          cause: first.cause, committed: first.committed)
      )
    })
  state.collections["materials"] = collection
  state.revision = 1025
  state.acknowledgedThrough = 1024
  state.acknowledgedEvents = []
  boundary.commander.scriptState.instances[id] = state
  boundary.commander.scriptState.nextEvent = 1024
  boundary.commander.scriptState.pendingEvents = []
  boundary.commander.cargo[2] = 1
  #expect(boundary.commander.valid)
  let full = GameRuntime(game: boundary, saveURL: fixture.save)
  await full.key("contacts-open")
  let offered = await full.snapshot()
  #expect(offered.scriptPresentedDialogue?.collectionQuote?.items.first?.delivered == 1024)
  await full.key("return")
  let refused = await full.snapshot()
  #expect(refused.commander.cargo == offered.commander.cargo)
  #expect(refused.commander.scriptState.instances[id]?.collections["materials"] == collection)
  #expect(refused.commander.scriptState.instances[id]?.suspension != nil && refused.commander.valid)
}

@Test(arguments: ["unit", "owner", "quantity", "quantity-overflow", "quote-index", "quote-request"])
func corruptedMaterialReceiptsAndQuotesRefuseLoadEvenWithAnUpdatedChunkHash(field: String)
  async throws
{
  let fixture = try CollectionFixture()
  defer { fixture.clean() }
  var initial = fixture.game()
  initial.commander.cargo[2] = 1
  let runtime = GameRuntime(game: initial, saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  await runtime.key("return")
  await runtime.key("contacts-open")
  let before = await runtime.snapshot()
  var pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  let file = directory.appendingPathComponent("missions.json")
  var engine = try ScriptValueStorage.decoder(typed: true).decode(
    ScriptEngineState.self,
    from: Data(contentsOf: file))
  var state = try #require(engine.instances[id])
  var collection = try #require(state.collections["materials"])
  let first = try #require(collection.lots.values.first)
  var items = first.items
  if field == "unit" || field.hasPrefix("quantity") {
    let item = items[0]
    items[0] = ScriptCollectionItem(
      commodity: item.commodity,
      unit: field == "unit" ? "kg" : item.unit,
      quantity: field == "quantity-overflow" ? Int.max : field == "quantity" ? -1 : item.quantity)
  }
  if field.hasPrefix("quote-") {
    let quote = try #require(state.dialogue?.collectionQuote)
    var rows = quote.items
    let row = rows[0]
    rows[0] = ScriptCollectionQuoteItem(
      commodity: field == "quote-index" ? 17 : row.commodity,
      unit: row.unit, requested: field == "quote-request" ? row.requested + 1 : row.requested,
      delivered: row.delivered, aboard: row.aboard, available: row.available)
    state.dialogue?.collectionQuote = ScriptCollectionQuote(
      collection: quote.collection, items: rows)
  } else {
    collection.lots[first.sequence] = ScriptCollectionLot(
      instance: field == "owner" ? UUID() : id, sequence: first.sequence, revision: first.revision,
      dialogue: first.dialogue, items: items, cause: first.cause, committed: first.committed)
    if field == "quantity-overflow" {
      collection.lots[first.sequence + 1] = ScriptCollectionLot(
        instance: id, sequence: first.sequence + 1, revision: first.revision,
        dialogue: first.dialogue, items: items, cause: first.cause, committed: first.committed)
    }
    state.collections["materials"] = collection
  }
  engine.instances[id] = state
  let changed = try ScriptValueStorage.encoder().encode(engine)
  try changed.write(to: file)
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(changed)
  pointer = ScriptSavePointer(
    format: pointer.format, schemaVersion: pointer.schemaVersion,
    generation: pointer.generation, hashes: hashes, scope: pointer.scope,
    valueCodec: pointer.valueCodec)
  try JSONEncoder().encode(pointer).write(to: fixture.save)
  await #expect(throws: (any Error).self) { try await runtime.load(from: fixture.save) }
  #expect(await runtime.snapshot().commander == before.commander)
}

@Test func aLateInvalidCommandCannotKeepAPartialLotAndAnEnsureCannotResetEarlierLots() async throws
{
  let fixture = try CollectionFixture(edits: [])
  defer { fixture.clean() }
  var initial = fixture.game()
  initial.commander.cargo[2] = 2
  let runtime = GameRuntime(game: initial, saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  let offered = await runtime.snapshot()
  let faulty = offered
  let pack = try ScriptPackLibrary.read(fixture.root.appendingPathComponent("pack"))
  let original = try #require(faulty.commander.scriptState.instances[id])
  let dialogue = try #require(original.dialogue)
  var next = original
  var candidate = faulty.commander
  let event = ScriptEvent(
    sequence: candidate.scriptState.nextEvent + 1, kind: "dialogue.confirmed",
    instance: id, values: ["dialogue_id": .string(dialogue.id), "token": .string(dialogue.token)],
    context: faulty.scriptEventContext(original))
  _ = try faulty.applyCollectionCommand(
    .object([
      "op": .string("collection.deliver"),
      "id": .string("materials"), "token": .string(dialogue.token),
    ]), event: event, pack: pack,
    state: &next, candidate: &candidate)
  let delivered = try #require(next.collections["materials"])
  _ = try faulty.applyCollectionCommand(
    .object([
      "op": .string("collection.ensure"),
      "id": .string("materials"),
    ]), event: event, pack: pack, state: &next, candidate: &candidate)
  #expect(next.collections["materials"] == delivered)
  #expect(throws: (any Error).self) {
    try faulty.applyScriptCommand(
      .object(["op": .string("unknown")]), event: event,
      pack: pack, state: &next, candidate: &candidate)
  }
  #expect(await runtime.snapshot().commander == offered.commander)
  // The real runtime batch is tested below, rather than publishing this local rejected draft.
  let rejecting = try CollectionFixture(
    source: """
      return {accepted=function(e,w,d) return {data=d,commands={{op='collection.ensure',id='materials'}}} end,
        contact=function(e,w,d) return {data=d,commands={{op='dialogue.offer',id='handoff'}}} end,
        confirm=function(e,w,d) return {data=d,commands={
          {op='collection.deliver',id='materials',token=e.token},{op='unknown'}}} end}
      """)
  defer { rejecting.clean() }
  var game = rejecting.game()
  game.commander.cargo[2] = 2
  let actual = GameRuntime(game: game, saveURL: rejecting.save)
  let owner = try await rejecting.offer(actual)
  await actual.key("return")
  let refused = await actual.snapshot()
  #expect(refused.commander.cargo[2] == 2)
  #expect(
    refused.commander.scriptState.instances[owner]?.collections["materials"]?.lots.isEmpty == true)
  #expect(refused.commander.scriptState.instances[owner]?.suspension != nil)
}

@Test func actualHullExchangeAndReloadKeepPreviouslyDeliveredMaterialLots() async throws {
  let fixture = try CollectionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.credits = 10_000_000
  game.commander.cargo[2] = 2
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  await runtime.key("return")
  var trading = await runtime.snapshot()
  let collection = try #require(
    trading.commander.scriptState.instances[id]?.collections["materials"])
  trading.key("6")
  trading.showroom.selection = "SH013"
  #expect(trading.shipTradeQuote?.allowed == true)
  let exchange = GameRuntime(game: trading, saveURL: fixture.save)
  await exchange.key("showroom-trade")
  await exchange.key("right")
  await exchange.key("return")
  let changed = await exchange.snapshot()
  #expect(changed.commander.shipID == "SH013" && changed.commander.valid)
  #expect(changed.commander.scriptState.instances[id]?.collections["materials"] == collection)
  #expect(changed.commander.cargo == trading.commander.cargo)
  try await exchange.save(to: fixture.save)
  let restored = GameRuntime(game: fixture.game())
  try await restored.load(from: fixture.save, persistMigrations: false)
  #expect(
    await restored.snapshot().commander.scriptState.instances[id]?.collections["materials"]
      == collection)
  #expect(await restored.snapshot().commander.shipID == "SH013")
}
