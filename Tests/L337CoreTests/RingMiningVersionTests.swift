import Foundation
import Testing

@testable import L337Core

struct RingMiningVersionTests {
  @Test func legacyHeaderRejectsEveryReservedRingFieldIncludingNullBeforeDecoding() throws {
    for key in ["generation", "ringTerminal", "legacyClusters", "presenceOverrides"] {
      let bytes = try JSONSerialization.data(withJSONObject: ["savedMiningLedger": [key: NSNull()]])
      #expect(throws: SaveError.self) { try RingMiningVersionedSave.rejectFields(bytes) }
    }
    for key in ["partial", "pending", "offers", "bindings"] {
      let bytes = try JSONSerialization.data(withJSONObject: [
        "savedMiningLedger": [key: [["field": 4]]]
      ])
      #expect(throws: SaveError.self) { try RingMiningVersionedSave.rejectFields(bytes) }
    }
    try RingMiningVersionedSave.rejectFields(
      try JSONSerialization.data(withJSONObject: [
        "savedMiningLedger": ["terminal": [], "partial": [["field": 3]]],
        "savedScriptState": ["data": ["generation": 1, "field": 6]],
      ]))
  }

  @Test func actualRingFlightSaveUsesNewHeaderAndCannotBeDowngraded() async throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try #require(game.commander.usesRingMiningSaveVersion)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 26)
    let (saved, world) = try ScriptSaveStore.read(bytes, from: file)
    #expect(saved.miningLedger == game.commander.miningLedger)
    #expect(world.bodies == game.bodies)
    var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    object["schemaVersion"] = 24
    let downgraded = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: SaveError.self) { _ = try ScriptSaveStore.read(downgraded, from: file) }
  }
}
