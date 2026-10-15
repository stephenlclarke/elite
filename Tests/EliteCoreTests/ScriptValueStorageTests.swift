import Foundation
import Testing

@testable import EliteCore

private struct ValueStorageFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "value-storage-" + UUID().uuidString)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-courier")
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: original, to: directory)
    try """
    return {
      accepted=function(e,w,d) return {data={floating=1.0,negative_zero=-0.0,integer=1,
        lookalike={type='number',value='3ff0000000000000'}},commands={}} end,
      contact=function(e,w,d) return {data=d,commands={{op='credits',id='strict-floating',amount=d.floating}}} end,
      confirm=function(e,w,d) return {data=d,commands={}} end
    }
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

@Test func wholeValuedFloatingDataAndNegativeZeroKeepTheirExactTypesAcrossNativeSaveReload()
  async throws
{
  let fixture = try ValueStorageFixture()
  defer { fixture.clean() }
  let (game, id) = try fixture.game()
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  let data = try #require(await loaded.snapshot().commander.scriptState.instances[id]?.data)
  guard case .number(let number) = data["floating"] else {
    Issue.record("A floating Lua value changed into an integer after save/reload.")
    return
  }
  #expect(number.bitPattern == Double(1).bitPattern)
  guard case .number(let zero) = data["negative_zero"] else {
    Issue.record("Negative floating zero lost its type after save/reload.")
    return
  }
  #expect(zero.bitPattern == (-Double.zero).bitPattern)
  #expect(data["integer"] == .integer(1))
  #expect(data["lookalike"]?["type"] == .string("number"))
  #expect(data["lookalike"]?["value"] == .string("3ff0000000000000"))
}

@Test func aFloatingCreditProposalIsRefusedBothBeforeAndAfterSavingInsteadOfChangingBehavior()
  async throws
{
  let fixture = try ValueStorageFixture()
  defer { fixture.clean() }
  let (game, id) = try fixture.game()
  let before = GameRuntime(game: game)
  try await before.save(to: fixture.save)
  let restored = GameRuntime(game: game)
  try await restored.load(from: fixture.save)
  await before.key("contacts-open")
  await restored.key("contacts-open")
  #expect(await before.snapshot().commander.credits == 1000)
  #expect(await restored.snapshot().commander.credits == 1000)
  #expect(await before.snapshot().commander.scriptState.instances[id]?.suspension != nil)
  #expect(await restored.snapshot().commander.scriptState.instances[id]?.suspension != nil)
}

@Test func typedStorageKeepsEveryValueKindAndAllFiniteFloatingBitPatternsUnambiguous() throws {
  let numbers = [
    Double.zero, -Double.zero, 1, -1, 0.1, Double.pi,
    Double.leastNonzeroMagnitude, -Double.leastNonzeroMagnitude,
    Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, Double(Int64.max),
  ]
  var fields: [String: ScriptValue] = [
    "minimum": .integer(Int64.min), "maximum": .integer(Int64.max),
    "null": .null, "false": .bool(false), "true": .bool(true),
    "text": .string("\u{0000} \\\" {}[] 汉"),
    "array": .array([.null, .integer(1), .number(1), .object([:])]),
    "lookalike": .object(["type": .string("number"), "value": .string("3ff0000000000000")]),
  ]
  for (index, value) in numbers.enumerated() { fields["number-\(index)"] = .number(value) }
  let bytes = try ScriptValueStorage.encoder().encode(ScriptValue.object(fields))
  try ScriptSaveJSONPreflight.validate(bytes)
  let restored = try ScriptValueStorage.decoder(typed: true).decode(ScriptValue.self, from: bytes)
  #expect(restored == .object(fields))
  for (index, value) in numbers.enumerated() {
    guard case .number(let actual) = restored["number-\(index)"] else {
      Issue.record("Saved floating data lost its number type.")
      continue
    }
    #expect(actual.bitPattern == value.bitPattern)
  }
  let old = Data("{\"type\":\"number\",\"value\":\"3ff0000000000000\"}".utf8)
  let legacy = try ScriptValueStorage.decoder(typed: false).decode(ScriptValue.self, from: old)
  #expect(legacy == fields["lookalike"])
}

@Test func invalidTypedNodesAndNonfiniteNumbersAreRefusedRatherThanCoerced() throws {
  for raw in [
    "{}", "{\"type\":\"unknown\"}", "{\"type\":\"null\",\"value\":null}",
    "{\"type\":\"bool\",\"value\":1}", "{\"type\":\"integer\",\"value\":\"1\"}",
    "{\"type\":\"number\",\"value\":1}", "{\"type\":\"number\",\"value\":\"3FF0000000000000\"}",
    "{\"type\":\"number\",\"value\":\"7ff0000000000000\"}",
    "{\"type\":\"number\",\"value\":\"7ff8000000000000\"}",
    "{\"type\":\"number\",\"value\":\"0\"}", "{\"type\":\"string\",\"value\":0}",
    "{\"type\":\"array\",\"value\":{}}", "{\"type\":\"object\",\"value\":[]}",
    "{\"type\":\"null\",\"extra\":true}",
  ] {
    #expect(throws: (any Error).self) {
      try ScriptValueStorage.decoder(typed: true).decode(ScriptValue.self, from: Data(raw.utf8))
    }
  }
  for number in [Double.infinity, -Double.infinity, Double.nan] {
    #expect(throws: (any Error).self) {
      try ScriptValueStorage.encoder().encode(ScriptValue.number(number))
    }
  }
}

@Test func savedValueDepthCountAndByteBudgetsRefuseOversizedTreesBeforeAcceptingData() throws {
  var nested: ScriptValue = .integer(1)
  for _ in 0..<31 { nested = .array([nested]) }
  let valid = try ScriptValueStorage.encoder().encode(nested)
  #expect(
    try ScriptValueStorage.decoder(typed: true).decode(ScriptValue.self, from: valid) == nested)
  nested = .array([nested])
  let deep = try ScriptValueStorage.encoder().encode(nested)
  #expect(throws: (any Error).self) {
    try ScriptValueStorage.decoder(typed: true).decode(ScriptValue.self, from: deep)
  }
  let boundary = ScriptValue.array(Array(repeating: .null, count: 16383))
  let bytes = try ScriptValueStorage.encoder().encode(boundary)
  #expect(
    try ScriptValueStorage.decoder(typed: true).decode(ScriptValue.self, from: bytes) == boundary)
  for oversized in [
    ScriptValue.array(Array(repeating: .null, count: 16384)),
    .string(String(repeating: "a", count: 262140)),
    .object([String(repeating: "k", count: 262140): .null]),
  ] {
    let data = try ScriptValueStorage.encoder().encode(oversized)
    #expect(throws: (any Error).self) {
      try ScriptValueStorage.decoder(typed: true).decode(ScriptValue.self, from: data)
    }
  }
}

@Test func structuralSavedJSONBoundsIgnoreQuotedDelimitersAndRejectHugeOrUnbalancedContainers()
  throws
{
  let valid = try JSONEncoder().encode([
    "escaped": "\"\\{}[],,,\n\u{0000}汉", "array": "[not an array]",
  ])
  try ScriptSaveJSONPreflight.validate(valid)
  for raw in [
    "{]", "[", "\"unterminated", "0,1",
    String(repeating: "[", count: 97) + String(repeating: "]", count: 97),
    "[" + String(repeating: "0,", count: 16384) + "0]",
    "\"" + String(repeating: "a", count: 6 * 262144 + 1) + "\"",
  ] {
    #expect(throws: SaveError.self) { try ScriptSaveJSONPreflight.validate(Data(raw.utf8)) }
  }
}

@Test func saveCodecMarkersPreventReinterpretingTypedValuesAsLegacyDataAndPreserveLiveState()
  async throws
{
  let fixture = try ValueStorageFixture()
  defer { fixture.clean() }
  let (game, _) = try fixture.game()
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let original = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  #expect(original.schemaVersion == 19 && original.valueCodec == ScriptValueStorage.codec)
  let before = await runtime.snapshot()
  for (version, codec) in [(13, nil), (13, "unknown"), (12, ScriptValueStorage.codec)]
    as [(Int, String?)]
  {
    let pointer = ScriptSavePointer(
      format: original.format, schemaVersion: version, generation: original.generation,
      hashes: original.hashes, scope: original.scope, valueCodec: codec)
    try JSONEncoder().encode(pointer).write(to: fixture.save, options: .atomic)
    await #expect(throws: SaveError.self) { try await runtime.load(from: fixture.save) }
    #expect(await runtime.snapshot().commander == before.commander)
    #expect(await runtime.snapshot().bodies == before.bodies)
  }
}

@Test func pendingNativeEventNumbersRetainTheirOriginalIntegerFloatingAndSignedZeroTypes()
  async throws
{
  let fixture = try ValueStorageFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.scriptEventsDeferred = true
  game.emitScriptEvent(
    "contact.requested",
    values: [
      "integer": .integer(1), "floating": .number(1),
      "negative_zero": .number(-Double.zero),
    ], only: id, drain: false)
  let original = try #require(game.commander.scriptState.pendingEvents.first)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let restored = GameRuntime(game: game)
  try await restored.load(from: fixture.save)
  let event = try #require(await restored.snapshot().commander.scriptState.pendingEvents.first)
  #expect(event.sequence == original.sequence && event.context == original.context)
  #expect(event.values["integer"] == .integer(1))
  guard case .number(let number) = event.values["floating"],
    case .number(let zero) = event.values["negative_zero"]
  else {
    Issue.record("Queued native numeric types changed during persistence.")
    return
  }
  #expect(number.bitPattern == Double(1).bitPattern && zero.bitPattern == (-Double.zero).bitPattern)
}

@Test func suspendedTerminalParentJobRetainsFloatingDataThroughSavedRetryAndCompletion()
  async throws
{
  let fixture = try ValueStorageFixture()
  defer { fixture.clean() }
  let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/station-maintenance")
  let directory = fixture.root.appendingPathComponent("jobpack")
  try FileManager.default.copyItem(at: original, to: directory)
  try """
  return {
    accepted=function(e,w,d) return {data={},commands={
      {op='world.job.ensure',id='patrol-service'},{op='milestone.ensure',index=0},
      {op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}}} end,
    maintenance=function(e,w,d)
      assert(w.local_seconds>=1,'Wait before retrying the service.')
      return {data=d,commands={{op='job.finish'}}}
    end
  }
  """.write(
    to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
  let pack = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let origin = try game.acceptScriptMission(pack)
  let id = try #require(game.commander.scriptState.worldJobs.keys.first)
  game.commander.scriptState.worldJobs[id]?.data = .object(["floating": .number(1)])
  let runtime = GameRuntime(game: game)
  let failed = await runtime.advance(delta: 0.1)
  let pending = try #require(failed.commander.scriptState.worldJobs[id]?.pending)
  #expect(failed.commander.scriptState.worldJobs[id]?.suspension != nil)
  try await runtime.save(to: fixture.save)
  let restored = GameRuntime(game: game)
  try await restored.load(from: fixture.save)
  for _ in 0..<12 { _ = await restored.advance(delta: 0.1) }
  try await restored.resumeScriptMission(origin)
  let result = await restored.snapshot()
  let job = try #require(result.commander.scriptState.worldJobs[id])
  #expect(job.status == .complete && job.acknowledgedThrough == pending.sequence)
  #expect(job.timer.pulses == 1)
  #expect(result.commander.scriptState.instances[origin]?.outcome == .complete)
  guard case .number(let value) = job.data["floating"] else {
    Issue.record("Saved service data lost its floating type.")
    return
  }
  #expect(value.bitPattern == Double(1).bitPattern)
  #expect(result.commander.valid)
}

@Test
func validEscapedDataNearTheSemanticByteLimitSavesAndOversizedReplacementKeepsThePriorPointer()
  async throws
{
  let fixture = try ValueStorageFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let text = String(repeating: "\u{0000}", count: 260000)
  game.commander.scriptState.instances[id]?.data = .object(["escaped": .string(text)])
  #expect(game.commander.valid)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let pointer = try Data(contentsOf: fixture.save)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  #expect(
    await loaded.snapshot().commander.scriptState.instances[id]?.data["escaped"] == .string(text))
  game.commander.scriptState.instances[id]?.data = .object([
    "escaped": .string(text + String(repeating: "x", count: 3000))
  ])
  let rejected = GameRuntime(game: game)
  await #expect(throws: SaveError.self) { try await rejected.save(to: fixture.save) }
  #expect(try Data(contentsOf: fixture.save) == pointer)
  let again = GameRuntime(game: Game(executive: false))
  try await again.load(from: fixture.save)
  #expect(
    await again.snapshot().commander.scriptState.instances[id]?.data["escaped"] == .string(text))
}

@Test func legacyPrimitiveValuesRemainReadableWithoutMistakingUserObjectsForTypedNodes() throws {
  let bytes = Data(
    """
    {"null":null,"false":false,"true":true,"minimum":-9223372036854775808,
     "maximum":9223372036854775807,"fraction":1.25,"text":"saved",
     "array":[null,false,1,1.25],"object":{"type":"number","value":"3ff0000000000000"}}
    """.utf8)
  let value = try ScriptValueStorage.decoder(typed: false).decode(ScriptValue.self, from: bytes)
  #expect(value["null"] == .null && value["false"] == .bool(false) && value["true"] == .bool(true))
  #expect(value["minimum"] == .integer(Int64.min) && value["maximum"] == .integer(Int64.max))
  #expect(value["fraction"] == .number(1.25) && value["text"] == .string("saved"))
  #expect(value["array"] == .array([.null, .bool(false), .integer(1), .number(1.25)]))
  #expect(
    value["object"] == .object(["type": .string("number"), "value": .string("3ff0000000000000")]))
}
