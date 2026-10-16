import Foundation
import Testing

@testable import EliteCore

struct NativeMissionSimulationSaveTests {
  @Test func presentNullAndWrongTypeECMTimeRefuseActualLoadWithoutPublishingLiveState() async throws
  {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    game.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let before = await runtime.snapshot()
    let originalPointer = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    let world = directory.appendingPathComponent("world.json")
    let originalWorld = try Data(contentsOf: world)
    for malformed in [NSNull(), "wrong-type"] as [Any] {
      var object = try #require(JSONSerialization.jsonObject(with: originalWorld) as? [String: Any])
      var simulation = try #require(object["simulation"] as? [String: Any])
      simulation["ecmRemainingDuration"] = malformed
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(
          ScriptSimulationSave.self, from: JSONSerialization.data(withJSONObject: simulation))
      }
      object["simulation"] = simulation
      let bytes = try JSONSerialization.data(withJSONObject: object)
      try bytes.write(to: world)
      var published = try #require(
        JSONSerialization.jsonObject(with: originalPointer) as? [String: Any])
      var hashes = try #require(published["hashes"] as? [String: String])
      hashes["world.json"] = ScriptPackLibrary.hash(bytes)
      published["hashes"] = hashes
      let input = try JSONSerialization.data(withJSONObject: published)
      try input.write(to: url)
      var refused = false
      do { try await runtime.load(from: url, persistMigrations: false) } catch { refused = true }
      let after = await runtime.snapshot()
      #expect(refused && after.commander == before.commander && after.bodies == before.bodies)
      #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
      #expect(after.ecmControl.epoch == before.ecmControl.epoch)
      #expect(try Data(contentsOf: url) == input)
      #expect(try Data(contentsOf: world) == bytes)
    }
  }

  @Test func loadingAnUnrelatedRawCommanderClearsRetainedLegacySpawnMetadata() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let oldURL = folder.appendingPathComponent("old.json")
    let rawURL = folder.appendingPathComponent("raw.json")
    let nextURL = folder.appendingPathComponent("next.json")
    var old = Game(executive: false)
    old.screen = .status
    let legacy = try decoded(old.scriptSimulationSave) { object in object["spawnClock"] = 12.5 }
    old.restoreScriptSimulation(legacy)
    old.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    let runtime = GameRuntime(game: old)
    try await runtime.save(to: oldURL)
    try await runtime.load(from: oldURL, persistMigrations: false)
    #expect(await runtime.snapshot().scriptSimulationSave.spawnClock == 12.5)
    var raw = Commander()
    raw.name = "MODERN"
    let bytes = try JSONEncoder().encode(raw)
    try bytes.write(to: rawURL)
    try await runtime.load(from: rawURL, persistMigrations: false)
    var next = await runtime.snapshot()
    #expect(next.scriptSimulationSave.spawnClock == nil)
    #expect(next.commander.encounterDirector == raw.encounterDirector)
    #expect(try Data(contentsOf: rawURL) == bytes)
    next.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    let writer = GameRuntime(game: next)
    try await writer.save(to: nextURL)
    let saved = try ScriptSaveStore.read(Data(contentsOf: nextURL), from: nextURL)
    #expect(saved.1?.simulation?.spawnClock == nil)
    #expect(saved.0.encounterDirector == raw.encounterDirector)
  }

  private func decoded(
    _ state: ScriptSimulationSave, changing edit: (inout [String: Any]) -> Void
  ) throws -> ScriptSimulationSave {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    edit(&object)
    return try JSONDecoder().decode(
      ScriptSimulationSave.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func legacyFramesAndSpawnMetadataRestoreWithoutChangingTheNativeDirector() throws {
    var game = Game(executive: false)
    game.launch()
    let director = game.commander.encounterDirector
    let old = try decoded(game.scriptSimulationSave) { object in
      object.removeValue(forKey: "ecmRemainingDuration")
      object["ecmFrames"] = 1024
      object["spawnClock"] = 12.5
    }
    try #require(old.valid)
    game.restoreScriptSimulation(old)
    #expect(game.ecmControl.remainingDuration == 1024.0 / ECMControl.referenceFramesPerSecond)
    #expect(game.ecmFrames == 1024 && !game.ecmControl.ownFieldActive)
    #expect(game.ecmControl.activation == 0 && game.ecmControl.events.isEmpty)
    #expect(game.activeECMActivation == nil && game.commander.encounterDirector == director)
    let saved = game.scriptSimulationSave
    #expect(saved.spawnClock == 12.5 && saved.valid)
    let bytes = try JSONEncoder().encode(saved)
    let restored = try JSONDecoder().decode(ScriptSimulationSave.self, from: bytes)
    #expect(restored.spawnClock == 12.5)
  }

  @Test func modernFractionalECMTimeRoundTripsExactlyAndClearsPreviousLiveOwnership() throws {
    var source = Game(executive: false)
    source.ecmControl.activateExternalField()
    source.ecmControl.advance(delta: 0.007)
    let state = source.scriptSimulationSave
    try #require(state.valid && state.spawnClock == nil)
    let bytes = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(ScriptSimulationSave.self, from: bytes)
    var loaded = Game(executive: false)
    loaded.ecmControl.activate(destroyed: 2)
    try #require(loaded.ecmControl.ownFieldActive)
    loaded.restoreScriptSimulation(decoded)
    #expect(loaded.ecmControl.remainingDuration == source.ecmControl.remainingDuration)
    #expect(loaded.ecmFrames == source.ecmFrames && !loaded.ecmControl.ownFieldActive)
    #expect(loaded.ecmControl.activation == 0 && loaded.ecmControl.events.isEmpty)
    #expect(loaded.scriptSimulationSave.spawnClock == nil && loaded.activeECMActivation == nil)
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect(object["spawnClock"] == nil)
  }

  @Test func presentInconsistentOrOutOfBoundsECMTimeCannotFallBackToLegacyFrames() throws {
    var game = Game(executive: false)
    game.ecmControl.activateExternalField()
    let state = game.scriptSimulationSave
    for duration in [0.0, -0.1, 1024.0 / ECMControl.referenceFramesPerSecond + 1] {
      let invalid = try decoded(state) { object in object["ecmRemainingDuration"] = duration }
      #expect(!invalid.valid)
    }
    let invalidLegacy = try decoded(state) { object in object["spawnClock"] = -1 }
    #expect(!invalidLegacy.valid)
  }
}
