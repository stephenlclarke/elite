import Foundation
import Testing

@testable import L337Core

@Test func procurementDirectCurrentContainerRetainsFrozenPlansWithoutNewSaveFields() throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let (game, id) = try fixture.policyContainer()
  #expect(game.commander.contractsValid && game.commander.valid)
  let publication = try ScriptSaveStore.write(
    commander: game.commander, world: game.scriptWorldSave, to: fixture.save)
  #expect(publication == nil)
  let bytes = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  let (commander, world) = try ScriptSaveStore.read(bytes, from: fixture.save)
  #expect(pointer.schemaVersion == 26 && pointer.valueCodec == ScriptValueStorage.codec)
  #expect(commander.scriptState.instances[id] == game.commander.scriptState.instances[id])
  #expect(commander.contracts == game.commander.contracts && world.consistent(with: commander))
  let object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(commander)) as? [String: Any])
  #expect(object["procurement"] == nil && object["savedProcurement"] == nil)
}

@Test(arguments: [
  "draw", "owner", "content", "template", "clock", "revision", "cross-revision", "route",
])
func procurementDirectContainerReadAndWriteRejectForgedNativeProof(field: String) throws {
  let fixture = try ScriptProcurementFixture(legacyV1: field == "cross-revision")
  defer { fixture.clean() }
  let (game, id) = try fixture.policyContainer()
  let original = try #require(game.commander.scriptState.instances[id]?.contract)
  let originalPlan = try #require(ScriptProcurementPlan.read(original.offer.parameters))
  var rejectedPath: [Int] = []
  if field == "route" {
    let routes = ScriptCourierGeneration.routes(
      origin: originalPlan.origin, reach: originalPlan.reach)
    rejectedPath = try #require(
      routes.first {
        ScriptProcurementPlan.calendarCost($0, galaxy: originalPlan.origin.galaxy)
          >= originalPlan.duration
      })
  }
  var changed = try ScriptProcurementFixture.changingParameters(original.offer) { plan in
    switch field {
    case "draw": plan["draws"] = [UInt32](repeating: 2, count: 6)
    case "owner": plan["owner"] = UUID().uuidString
    case "content":
      var content = plan["content"] as! [String: Any]
      content["digest"] = String(repeating: "f", count: 64)
      plan["content"] = content
    case "template":
      var template = plan["template"] as! [String: Any]
      template["title"] = "Counterfeit requirement"
      plan["template"] = template
    case "revision": plan["generator_revision"] = 3
    case "cross-revision": plan["generator_revision"] = 2
    case "route":
      plan["path"] = rejectedPath
      plan["calendar_lower_bound_seconds"] = ScriptProcurementPlan.calendarCost(
        rejectedPath, galaxy: originalPlan.origin.galaxy)
    default: break
    }
  }
  if field == "route" {
    let bad = try #require(ScriptProcurementPlan.read(changed.parameters))
    #expect(!bad.valid)
    changed = .init(
      id: changed.id, key: changed.key, title: changed.title, briefing: changed.briefing,
      destinationGalaxy: bad.origin.galaxy, destinationSystem: bad.path.last!, reward: bad.reward,
      deposit: changed.deposit, failureReward: changed.failureReward,
      refundOnFailure: changed.refundOnFailure, duration: bad.duration,
      parameters: changed.parameters)
  }
  var jobObject = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
  jobObject["offer"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(changed))
  if field == "clock" {
    jobObject["acceptedAt"] = 10.0
    jobObject["deadline"] = original.offer.duration + 10
  }
  let job = try JSONDecoder().decode(
    ScriptContractJob.self, from: JSONSerialization.data(withJSONObject: jobObject))
  var forged = game.commander
  forged.scriptState.instances[id]?.contract = job
  if field == "route" {
    let bad = try #require(ScriptProcurementPlan.read(changed.parameters))
    forged.scriptState.instances[id]?.collections[bad.template.id] = .init(
      definition: try #require(bad.collection))
  }
  var listed = changed
  listed.status = .accepted(id)
  let row = try #require(ScriptProcurementPlan.read(original.offer.parameters)).row
  forged.contracts.boards[original.boardKey]?.offers[row] = listed
  if field == "draw", let offers = forged.contracts.boards[original.boardKey]?.offers {
    for index in offers.indices {
      let value = try ScriptProcurementFixture.changingParameters(offers[index]) {
        $0["draws"] = [UInt32](repeating: 2, count: 6)
      }
      forged.contracts.boards[original.boardKey]?.offers[index] = value
    }
  }
  if field == "cross-revision", let offers = forged.contracts.boards[original.boardKey]?.offers {
    // Retag the entire old board consistently, not just one cross-record field.
    let first = try #require(ScriptProcurementPlan.read(offers[0].parameters))
    try #require(first.calendarLowerBoundSeconds >= first.duration)
    for index in offers.indices {
      let value = try ScriptProcurementFixture.changingParameters(offers[index]) {
        $0["generator_revision"] = 2
      }
      forged.contracts.boards[original.boardKey]?.offers[index] = value
    }
  }
  #expect(!forged.contractsValid)
  #expect(throws: (any Error).self) {
    _ = try ScriptSaveStore.write(commander: forged, world: game.scriptWorldSave, to: fixture.save)
  }
  _ = try ScriptSaveStore.write(
    commander: game.commander, world: game.scriptWorldSave, to: fixture.save)
  var pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  let file = directory.appendingPathComponent("missions.json")
  let changedBytes = try ScriptValueStorage.encoder().encode(forged.scriptState)
  try changedBytes.write(to: file)
  let contractBytes = try ScriptValueStorage.encoder().encode(forged.contracts)
  try contractBytes.write(to: directory.appendingPathComponent("contracts.json"))
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(changedBytes)
  hashes["contracts.json"] = ScriptPackLibrary.hash(contractBytes)
  pointer = .init(
    format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
    hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
  let pointerBytes = try JSONEncoder().encode(pointer)
  #expect(throws: (any Error).self) {
    _ = try ScriptSaveStore.read(pointerBytes, from: fixture.save)
  }
}

@Test func procurementStoryFlagsCannotCreateANativeLastLotAdmission() throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.policyContainer()
  var state = try #require(game.commander.scriptState.instances[id])
  state.milestones = [0]
  let before = game.commander
  #expect(throws: MissionPackError.self) {
    try game.finishScriptMission(
      .complete, pack: fixture.pack, state: &state, candidate: &game.commander)
  }
  #expect(game.commander == before && state.outcome == .active)
}

/// Codec/load compatibility input; this does not manufacture an old native acceptance receipt.
@Test func procurementLegacyV1FrozenBoardAndFeasibleJobLoadWithoutRewritingTerms() async throws {
  let fixture = try ScriptProcurementFixture(legacyV1: true)
  defer { fixture.clean() }
  let (game, id) = try fixture.policyContainer()
  let original = try #require(game.commander.scriptState.instances[id])
  let job = try #require(original.contract)
  let board = try #require(game.commander.contracts.boards[job.boardKey])
  let unavailable = try #require(ScriptProcurementPlan.read(board.offers[0].parameters))
  try #require(unavailable.generatorRevision == 1 && unavailable.valid)
  try #require(unavailable.calendarLowerBoundSeconds >= unavailable.duration)
  let publication = try ScriptSaveStore.write(
    commander: game.commander, world: game.scriptWorldSave, to: fixture.save)
  #expect(publication == nil)
  let bytes = try Data(contentsOf: fixture.save)
  let (decoded, world) = try ScriptSaveStore.read(bytes, from: fixture.save)
  #expect(decoded == game.commander && world.consistent(with: decoded))
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let runtime = GameRuntime(game: game)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let loaded = await runtime.snapshot()
  #expect(loaded.commander.scriptState.instances[id]?.contract == job)
  #expect(loaded.commander.scriptState.instances[id]?.collections == original.collections)
  #expect(loaded.commander.contracts.boards[job.boardKey] == board)
  #expect(loaded.commander.cargo == decoded.cargo && loaded.commander.credits == decoded.credits)
  let after = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  #expect(after == files)
  let current = try ScriptProcurementFixture()
  defer { current.clean() }
  var newContentOnly = game
  newContentOnly.scriptPacks = [current.pack]
  let missingOriginal = GameRuntime(game: newContentOnly)
  try await missingOriginal.load(from: fixture.save, persistMigrations: false)
  let suspended = await missingOriginal.snapshot()
  #expect(suspended.commander.scriptState.instances[id]?.suspension != nil)
  #expect(suspended.commander.scriptState.instances[id]?.contract == job)
  #expect(suspended.commander.scriptState.instances[id]?.collections == original.collections)
  #expect(suspended.commander.contracts.boards[job.boardKey] == board)
  let unchanged = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  #expect(unchanged == files)
}
