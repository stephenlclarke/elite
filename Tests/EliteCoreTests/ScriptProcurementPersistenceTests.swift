import Foundation
import Testing

@testable import EliteCore

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

@Test(arguments: ["draw", "owner", "content", "template", "clock"])
func procurementDirectContainerReadAndWriteRejectForgedNativeProof(field: String) throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let (game, id) = try fixture.policyContainer()
  let original = try #require(game.commander.scriptState.instances[id]?.contract)
  let changed = try ScriptProcurementFixture.changingParameters(original.offer) { plan in
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
    default: break
    }
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
