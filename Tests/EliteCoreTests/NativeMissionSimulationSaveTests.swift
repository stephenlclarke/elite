import Foundation
import Testing

@testable import EliteCore

struct NativeMissionSimulationSaveTests {
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
