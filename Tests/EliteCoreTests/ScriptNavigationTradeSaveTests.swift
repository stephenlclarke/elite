import Foundation
import Testing

@testable import EliteCore

/// Rehash actual generation bytes to exercise semantic and version gates rather than checksums.
func rewriteNavigationTradeChunk(
  save: URL, pointer: ScriptSavePointer, name: String,
  change: ([String: Any]) throws -> [String: Any]
) throws -> Data {
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
  let file = directory.appendingPathComponent(name)
  let originalBytes = try Data(contentsOf: file)
  let originalObject = try JSONSerialization.jsonObject(with: originalBytes)
  let object = try #require(originalObject as? [String: Any])
  let changed = try change(object)
  let bytes = try JSONSerialization.data(withJSONObject: changed, options: .sortedKeys)
  try bytes.write(to: file)
  var hashes = pointer.hashes
  hashes[name] = ScriptPackLibrary.hash(bytes)
  return try JSONEncoder().encode(
    ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
      hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec))
}

@Test func navigationTradeCurrentReaderRejectsDowngradeNullForeignOwnerAndInventedAuthorization()
  async throws
{
  let fixture = try ScriptNavigationTradeFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.initial, saveURL: fixture.save)
  let id = try await fixture.ready(runtime)
  let originalPointerBytes = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointerBytes)
  let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  let missionsURL = generation.appendingPathComponent("missions.json")
  let originalMissions = try Data(contentsOf: missionsURL)
  let headerURL = generation.appendingPathComponent("commander.json")
  let originalHeader = try Data(contentsOf: headerURL)
  let reader = GameRuntime(game: Game(executive: false))
  let before = await reader.snapshot()
  for version in [21, 26, 28, 29, 30, 31, 32, 34, 35] {
    let changed = ScriptSavePointer(
      format: pointer.format, schemaVersion: version, generation: pointer.generation,
      hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    let bytes = try JSONEncoder().encode(changed)
    try bytes.write(to: fixture.save)
    await #expect(throws: (any Error).self) {
      try await reader.loadNativeCommander(
        from: fixture.save, persistMigrations: false, navigationBinding: fixture.binding)
    }
  }
  try originalPointerBytes.write(to: fixture.save)
  for mutation in ["null", "removed", "owner", "binding", "credits", "root"] {
    try originalMissions.write(to: missionsURL)
    let changed = try rewriteNavigationTradeChunk(
      save: fixture.save, pointer: pointer, name: "missions.json"
    ) { original in
      var root = original
      var pairs = try #require(root["instances"] as? [Any])
      let index = try #require(pairs.firstIndex { ($0 as? String) == id.uuidString })
      var instance = try #require(pairs[index + 1] as? [String: Any])
      var record = try #require(instance["savedNavigationTrade"] as? [String: Any])
      switch mutation {
      case "null": instance["savedNavigationTrade"] = NSNull()
      case "removed": instance.removeValue(forKey: "savedNavigationTrade")
      case "owner":
        record["owner"] = UUID().uuidString
        instance["savedNavigationTrade"] = record
      case "binding":
        record["binding"] = ["approved": true]
        instance["savedNavigationTrade"] = record
      case "credits":
        var buy = try #require(record["buy"] as? [String: Any])
        let price = try #require(buy["price"] as? Int)
        buy["price"] = price + 1
        record["buy"] = buy
        instance["savedNavigationTrade"] = record
      default: root["savedNavigationTrade"] = record
      }
      pairs[index + 1] = instance
      root["instances"] = pairs
      return root
    }
    try changed.write(to: fixture.save)
    await #expect(throws: (any Error).self) {
      try await reader.loadNativeCommander(
        from: fixture.save, persistMigrations: false, navigationBinding: fixture.binding)
    }
  }
  try originalMissions.write(to: missionsURL)
  let noCargo = try rewriteNavigationTradeChunk(
    save: fixture.save, pointer: pointer, name: "commander.json"
  ) { original in
    var root = original
    var cargo = try #require(root["cargo"] as? [Int])
    cargo[fixture.commodity] = 0
    root["cargo"] = cargo
    return root
  }
  try noCargo.write(to: fixture.save)
  await #expect(throws: (any Error).self) {
    try await reader.loadNativeCommander(
      from: fixture.save, persistMigrations: false, navigationBinding: fixture.binding)
  }
  try originalHeader.write(to: headerURL)
  try originalPointerBytes.write(to: fixture.save)
  let after = await reader.snapshot()
  #expect(after.commander == before.commander)
  // Actual original endpoints are re-authenticated by the production loader without a fixture binding.
  try await reader.load(from: fixture.save)
  let production = await reader.snapshot()
  #expect(production.commander.scriptState == before.commander.scriptState)
}

@Test func navigationTradeRawCommanderFieldsCannotDisappearThroughNullDecoding() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "navigation-raw-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  for atInstance in [false, true] {
    let commanderBytes = try JSONEncoder().encode(Commander())
    let commanderObject = try JSONSerialization.jsonObject(with: commanderBytes)
    var raw = try #require(commanderObject as? [String: Any])
    if atInstance {
      raw["savedScriptState"] = [
        "instances": [UUID().uuidString, ["savedNavigationTrade": NSNull()]]
      ]
    } else {
      raw["savedNavigationTrade"] = NSNull()
    }
    let bytes = try JSONSerialization.data(withJSONObject: raw)
    let file = root.appendingPathComponent("raw.json")
    try bytes.write(to: file)
    let runtime = GameRuntime(game: Game(executive: false))
    let before = await runtime.snapshot()
    await #expect(throws: (any Error).self) { try await runtime.load(from: file) }
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander)
  }
}
