import Foundation
import Testing

@testable import EliteCore

private func publishClueFixture(_ game: Game, fixture: ScriptClueFixture) throws -> Game {
  var candidate = game
  try candidate.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
  let prepared = try GameRuntime.prepareNativeSaveState(candidate)
  candidate = prepared.game
  let publication = try ScriptSaveStore.write(
    commander: prepared.commander, world: candidate.scriptWorldSave, to: fixture.save,
    clueTrust: fixture.trust)
  candidate.commander.publishAlienStorage(publication)
  return candidate
}

/// Rehash modified bytes so rejection exercises native semantic/version gates, not checksum failure.
private func alteredClueSave(
  _ fixture: ScriptClueFixture, schema: Int? = nil, chunk: String? = nil,
  edit: ([String: Any]) throws -> [String: Any] = { $0 }
) throws -> Data {
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  var hashes = pointer.hashes
  if let chunk {
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
    let file = directory.appendingPathComponent(chunk)
    let object = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    let changed = try edit(object)
    let bytes = try JSONSerialization.data(withJSONObject: changed, options: .sortedKeys)
    try bytes.write(to: file)
    hashes[chunk] = ScriptPackLibrary.hash(bytes)
  }
  return try JSONEncoder().encode(
    ScriptSavePointer(
      format: pointer.format, schemaVersion: schema ?? pointer.schemaVersion,
      generation: pointer.generation, hashes: hashes, scope: pointer.scope,
      valueCodec: pointer.valueCodec))
}

@Test func clueJournalColdRoundTripUsesExact31Or32AndProductionRejectsFixtureTrust() async throws {
  for alien in [false, true] {
    let fixture = try ScriptClueFixture()
    defer { fixture.clean() }
    var game = try fixture.game(alien: alien)
    let id = try fixture.queueSettlement(&game)
    game.drainScriptEvents(clueTrust: fixture.trust)
    game.scriptPacks = []
    let published = try publishClueFixture(game, fixture: fixture)
    let bytes = try Data(contentsOf: fixture.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 32 : 31))
    #expect((pointer.hashes["alien-root.json"] != nil) == alien)
    let (loaded, world) = try ScriptSaveStore.read(
      bytes, from: fixture.save, clueTrust: fixture.trust)
    #expect(loaded == published.commander && world.valid)
    var rawTarget = Game(executive: false)
    let rawAccepted = rawTarget.load(loaded)
    #expect(!rawAccepted)
    #expect(loaded.scriptState.instances[id]?.completionReceipt != nil)
    #expect(loaded.scriptState.savedClueJournal == game.commander.scriptState.savedClueJournal)
    #expect(throws: SaveError.self) { try ScriptSaveStore.read(bytes, from: fixture.save) }
    #expect(throws: SaveError.self) {
      try ScriptSaveStore.write(
        commander: loaded, world: world, to: fixture.root.appendingPathComponent("untrusted.json"))
    }
    let runtime = GameRuntime(game: Game(executive: false))
    let before = await runtime.snapshot()
    await #expect(throws: SaveError.self) { try await runtime.load(from: fixture.save) }
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander)
  }
}

@Test func clueEnvelopeDowngradeAndAlienCrossProductFailAtTheActualReader() throws {
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  let (game, _) = try fixture.completed()
  _ = try publishClueFixture(game, fixture: fixture)
  for version in [2, 21, 26, 27, 28, 29, 30, 32, 33] {
    let bytes = try alteredClueSave(fixture, schema: version)
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.read(bytes, from: fixture.save, clueTrust: fixture.trust)
    }
  }
}

@Test func nullEmptyRemovedOrMisplacedJournalFailsAfterAuthenticatedChunkRehash() throws {
  for mutation in [
    "null", "empty", "missing", "instance", "owner", "source", "unknown-source", "proof",
  ] {
    let fixture = try ScriptClueFixture()
    defer { fixture.clean() }
    let (game, id) = try fixture.completed()
    _ = try publishClueFixture(game, fixture: fixture)
    let bytes = try alteredClueSave(fixture, chunk: "missions.json") { original in
      var root = original
      var journal = try #require(root["savedClueJournal"] as? [String: Any])
      switch mutation {
      case "null": root["savedClueJournal"] = NSNull()
      case "empty":
        journal["awards"] = [:] as [String: Any]
        root["savedClueJournal"] = journal
      case "missing": root.removeValue(forKey: "savedClueJournal")
      case "instance":
        // UUID-keyed Codable dictionaries use alternating key/value arrays.
        var pairs = try #require(root["instances"] as? [Any])
        let index = try #require(pairs.firstIndex { ($0 as? String) == id.uuidString })
        var instance = try #require(pairs[index + 1] as? [String: Any])
        instance["savedClueJournal"] = journal
        pairs[index + 1] = instance
        root["instances"] = pairs
      case "owner":
        journal["owner"] = UUID().uuidString
        root["savedClueJournal"] = journal
      default:
        var awards = try #require(journal["awards"] as? [String: Any])
        var award = try #require(awards["l337.glass-meridian"] as? [String: Any])
        if mutation == "source" {
          award["clueID"] = "unknown-clue"
        } else if mutation == "proof" {
          var proof = try #require(award["completion"] as? [String: Any])
          proof["sequence"] = 0
          award["completion"] = proof
        }
        if mutation == "unknown-source" {
          award["sourceID"] = "unknown-source"
          awards.removeValue(forKey: "l337.glass-meridian")
          awards["unknown-source"] = award
        } else {
          awards["l337.glass-meridian"] = award
        }
        journal["awards"] = awards
        root["savedClueJournal"] = journal
      }
      return root
    }
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.read(bytes, from: fixture.save, clueTrust: fixture.trust)
    }
  }
  for chunk in ["commander.json", "contracts.json", "world.json"] {
    let fixture = try ScriptClueFixture()
    defer { fixture.clean() }
    let (game, _) = try fixture.completed()
    _ = try publishClueFixture(game, fixture: fixture)
    let bytes = try alteredClueSave(fixture, chunk: chunk) { original in
      var root = original
      root["savedClueJournal"] = NSNull()
      return root
    }
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.read(bytes, from: fixture.save, clueTrust: fixture.trust)
    }
  }
}

@Test func rawCommanderFrontdoorRejectsJournalFieldsEvenWhenNull() async throws {
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  for nested in [false, true] {
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(Commander())) as? [String: Any])
    if nested {
      raw["savedScriptState"] = ["savedClueJournal": NSNull()]
    } else {
      raw["savedClueJournal"] = NSNull()
    }
    let bytes = try JSONSerialization.data(withJSONObject: raw)
    let file = fixture.root.appendingPathComponent("raw.json")
    try bytes.write(to: file)
    let runtime = GameRuntime(game: Game(executive: false))
    let before = await runtime.snapshot()
    await #expect(throws: SaveError.self) { try await runtime.load(from: file) }
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander)
  }
}

@Test func emptyJournalKeepsExistingSaveSelectionAndRejects31WithoutEvidence() throws {
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  var game = try fixture.game()
  _ = try fixture.queueSettlement(&game)
  game.drainScriptEvents()
  let published = try publishClueFixture(game, fixture: fixture)
  let bytes = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == 26 && published.commander.scriptState.savedClueJournal == nil)
  let upgraded = try alteredClueSave(fixture, schema: 31)
  #expect(throws: (any Error).self) {
    try ScriptSaveStore.read(upgraded, from: fixture.save, clueTrust: fixture.trust)
  }
}
