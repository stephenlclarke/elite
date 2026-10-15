import Foundation
import Testing

@testable import EliteCore

private struct HistoryFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "event-history-" + UUID().uuidString)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-courier")
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    text = text.replacingOccurrences(
      of: "capabilities = [",
      with: "capabilities = [\"event-history-v2\", \"local-flight-clocks-v2\", ")
    text += """

      [[handlers]]
      event='timer.fired'
      function='pulse'
      [[handlers]]
      event='station.docked'
      function='dock'
      [[handlers]]
      event='station.undocked'
      function='undock'
      """
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    try """
    local M={}
    function M.accepted(e,w,d)
      return {data={count=0,seen={}},commands={{op='timer.ensure',id='pulse',domain='local',after=0,interval=0.1,policy='skip'}}}
    end
    function M.pulse(e,w,d) d.count=d.count+1; return {data=d,commands={}} end
    function M.dock(e,w,d)
      assert(w.local_seconds>=1,'Wait for a native local second before retry.')
      d.seen[#d.seen+1]={sequence=e.sequence,context=e.context,current_docked=w.docked}
      return {data=d,commands={}}
    end
    function M.undock(e,w,d)
      d.seen[#d.seen+1]={sequence=e.sequence,context=e.context,current_docked=w.docked}
      return {data=d,commands={}}
    end
    function M.contact(e,w,d) return {data=d,commands={}} end
    M.confirm=M.contact
    return M
    """.write(
      to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
  }
  func game() throws -> (Game, UUID) {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let id = try game.acceptScriptMission(pack)
    return (game, id)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test func moreThanFiveThousandActualCallbacksKeepAcknowledgementsBoundedAcrossSaveReload()
  async throws
{
  let fixture = try HistoryFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  for _ in 0..<10000 {
    if (game.commander.scriptState.instances[id]?.timers["pulse"]?.pulses ?? 0) >= 5000 { break }
    game.advanceScriptClocks(delta: 0.1, flight: false, local: true)
  }
  let state = try #require(game.commander.scriptState.instances[id])
  #expect(state.timers["pulse"]?.pulses == 5000 && state.data["count"] == .integer(5000))
  #expect(state.suspension == nil && state.acknowledgedEvents.isEmpty)
  #expect(state.acknowledgedThrough == game.commander.scriptState.nextEvent)
  #expect(game.commander.scriptState.pendingEvents.isEmpty && game.commander.valid)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  #expect(await loaded.snapshot().commander.scriptState.instances[id] == state)
}

@Test func faultedQueuedFactsRetainTheirOriginalLocationClocksAndOrderThroughReloadAndRetry()
  async throws
{
  let fixture = try HistoryFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.scriptEventsDeferred = true
  game.emitScriptEvent("station.docked", only: id)
  game.launch()
  game.observeScriptLocation(wasDocked: true, galaxy: 0, system: 7)
  game.scriptEventsDeferred = false
  let original = game.commander.scriptState.pendingEvents
  #expect(original.count == 2)
  #expect(original[0].context?.docked == true && original[0].context?.calendarSeconds == 0)
  #expect(original[1].context?.docked == false && original[1].context?.calendarSeconds == 600)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  #expect(game.commander.scriptState.pendingEvents == original)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  for _ in 0..<12 { _ = await loaded.advance(delta: 0.1) }
  try await loaded.resumeScriptMission(id)
  let result = await loaded.snapshot()
  let seen = try #require(result.commander.scriptState.instances[id]?.data["seen"]?.array)
  #expect(seen.count == 2)
  #expect(seen[0]["sequence"] == .integer(Int64(original[0].sequence)))
  #expect(seen[1]["sequence"] == .integer(Int64(original[1].sequence)))
  #expect(seen[0]["context"]?["docked"] == .bool(true))
  #expect(seen[1]["context"]?["docked"] == .bool(false))
  #expect(seen[0]["context"]?["calendar_seconds"] == .number(0))
  #expect(seen[1]["context"]?["calendar_seconds"] == .number(600))
  #expect(seen[0]["current_docked"] == .bool(false))
  #expect(result.commander.scriptState.pendingEvents.isEmpty && result.commander.valid)
}

@Test func nativeEnvelopeHeadersCannotBeOverwrittenAndLegacyFactsKeepUnknownProvenance() throws {
  var game = Game(executive: false)
  game.ensureScriptCalendar(origin: .newCommander)
  let instance = ScriptInstance(
    id: UUID(), definition: "test/mission", version: "1.0.0",
    digest: String(repeating: "a", count: 64))
  let context = game.scriptEventContext(instance)
  let event = ScriptEvent(
    sequence: 1, kind: "station.docked", instance: instance.id,
    values: [
      "kind": .string("fake"), "sequence": .integer(99), "instance_id": .string("foreign"),
      "context": .string("fake"),
    ], context: context)
  #expect(
    event.value["kind"] == .string("station.docked") && event.value["sequence"] == .integer(1))
  #expect(event.value["instance_id"] == .string(instance.id.uuidString))
  #expect(event.value["context"] == context.value)
  var legacy = event
  legacy.context = nil
  let bytes = try JSONEncoder().encode(legacy)
  let restored = try JSONDecoder().decode(ScriptEvent.self, from: bytes)
  #expect(restored.context == nil && restored.value["context"] == .null)
}

@Test func legacyAcknowledgementSetsCompactAndReplayedNativeFactsDoNotRunTheHandlerAgain() throws {
  let fixture = try HistoryFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.commander.scriptState.instances[id]?.acknowledgedThrough = nil
  game.commander.scriptState.instances[id]?.acknowledgedEvents = [1]
  game.commander.scriptState.pendingEvents.append(
    ScriptEvent(sequence: 1, kind: "mission.accepted", instance: id, values: [:]))
  let revision = game.commander.scriptState.instances[id]?.revision
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.revision == revision)
  #expect(game.commander.scriptState.instances[id]?.acknowledgedEvents == [1])
  game.scriptEventsDeferred = true
  game.advanceScriptClocks(delta: 0.1, flight: false, local: true)
  let event = try #require(game.commander.scriptState.pendingEvents.first)
  game.scriptEventsDeferred = false
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.acknowledgedEvents.isEmpty == true)
  #expect(game.commander.scriptState.instances[id]?.acknowledgedThrough == event.sequence)
  #expect(game.commander.scriptState.instances[id]?.data["count"] == .integer(1))
  game.commander.scriptState.pendingEvents.append(event)
  #expect(game.commander.valid)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["count"] == .integer(1))
  #expect(game.commander.scriptState.pendingEvents.isEmpty && game.commander.valid)
}

@Test func unorderedNativeFactsCannotSkipAnEarlierUnacknowledgedEvent() throws {
  let fixture = try HistoryFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.scriptEventsDeferred = true
  game.emitScriptEvent("station.docked", only: id)
  game.launch()
  game.observeScriptLocation(wasDocked: true, galaxy: 0, system: 7)
  #expect(game.commander.valid && game.commander.scriptState.pendingEvents.count == 2)
  game.commander.scriptState.pendingEvents.reverse()
  #expect(!game.commander.valid)
  game.commander.scriptState.pendingEvents.reverse()
  #expect(game.commander.valid)
  let future = game.commander.scriptState.nextEvent + 1
  game.commander.scriptState.instances[id]?.acknowledgedThrough = future
  #expect(!game.commander.valid)
}

@Test func corruptFrozenEventContextIsRejectedBeforeReplacingTheLiveCommander() async throws {
  let fixture = try HistoryFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.scriptEventsDeferred = true
  game.emitScriptEvent("station.docked", only: id)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  let file = directory.appendingPathComponent("missions.json")
  var state = try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
  var events = try #require(state["pendingEvents"] as? [[String: Any]])
  var context = try #require(events[0]["context"] as? [String: Any])
  context["galaxy"] = 8
  events[0]["context"] = context
  state["pendingEvents"] = events
  let corrupt = try JSONSerialization.data(withJSONObject: state, options: .sortedKeys)
  try corrupt.write(to: file)
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(corrupt)
  let changed = ScriptSavePointer(
    format: pointer.format, schemaVersion: pointer.schemaVersion,
    generation: pointer.generation, hashes: hashes, scope: pointer.scope,
    valueCodec: pointer.valueCodec)
  try JSONEncoder().encode(changed).write(to: fixture.save, options: .atomic)
  let restored = GameRuntime(game: Game(executive: false))
  let before = await restored.snapshot()
  await #expect(throws: SaveError.self) { try await restored.load(from: fixture.save) }
  #expect(await restored.snapshot().commander == before.commander)
  #expect(await restored.snapshot().bodies == before.bodies)
}

@Test func reviewingAnOfferWhileTimersAndWorldJobsRunDoesNotInvalidateUnchangedProperty()
  async throws
{
  let fixture = try HistoryFixture()
  defer { fixture.clean() }
  let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs")
  let provider = try ScriptPackLibrary.read(examples.appendingPathComponent("calendar-contracts"))
  let service = try ScriptPackLibrary.read(examples.appendingPathComponent("station-maintenance"))
  var (game, history) = try fixture.game()
  game.scriptPacks += [provider, service]
  let authorization = try game.acceptScriptMission(service)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: provider.digest)
  let offer = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  #expect(quote.allowed)
  await runtime.key("contracts-open")
  for _ in 0..<60 { _ = await runtime.advance(delta: 0.1) }
  let during = await runtime.snapshot()
  #expect((during.commander.scriptState.instances[history]?.data["count"]?.integer ?? 0) > 40)
  #expect(during.commander.scriptState.instances[authorization]?.ownedEncounters["support"] != nil)
  #expect(during.commander.scriptState.worldJobs.values.first?.elapsed ?? 0 > 5)
  #expect(during.commander.credits == 1000 && during.commander.cargoTonnes == 0)
  let accepted = try await runtime.confirmContract(quote)
  let result = await runtime.snapshot()
  #expect(result.commander.scriptState.instances[accepted]?.contract?.offer == offer)
  #expect(result.commander.credits == 1000 - offer.deposit)
  #expect(
    result.commander.scriptState.instances[history]?.data
      == during.commander.scriptState.instances[history]?.data)
  #expect(
    result.commander.scriptState.instances[authorization]?.ownedEncounters
      == during.commander.scriptState.instances[authorization]?.ownedEncounters)
  #expect(result.commander.scriptState.worldJobs == during.commander.scriptState.worldJobs)
  #expect(result.commander.valid)
}
