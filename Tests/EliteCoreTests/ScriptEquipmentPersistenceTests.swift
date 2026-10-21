import Foundation
import Testing

@testable import EliteCore

struct ScriptEquipmentPersistenceTests {
  @Test(arguments: ["savedGearVersion", "source", "node", "displacements", "legacyMissingItems"])
  func pre21AndRawGuardsRejectNewGearFieldsOnlyAtNativeRecordPaths(field: String) throws {
    let id = "51000000-0000-0000-0000-000000000001"
    let value: Any
    if field == "savedGearVersion" { value = 2 } else { value = NSNull() }
    let record: [String: Any] = [field: value]
    let instance: [String: Any] = ["savedGearIssues": ["kit": record]]
    for instances: Any in [[id: instance], [id, instance]] {
      let missions: [String: Any] = ["instances": instances]
      #expect(throws: SaveError.self) {
        try ScriptSaveJSONPreflight.rejectCourierFields(
          JSONSerialization.data(withJSONObject: missions), location: .missions)
      }
      #expect(throws: SaveError.self) {
        try ScriptSaveJSONPreflight.rejectCourierFields(
          JSONSerialization.data(withJSONObject: ["savedScriptState": missions]),
          location: .rawCommander)
      }
    }
  }

  @Test func authoredPayloadAndDataKeysAndOrdinaryCanonicalRawVersionRemainCompatible() throws {
    let id = "51000000-0000-0000-0000-000000000001"
    let keys = ["savedGearVersion", "source", "node", "displacements", "legacyMissingItems"]
    let authored = Dictionary(uniqueKeysWithValues: keys.map { ($0, 1) })
    let missions: [String: Any] = [
      "instances": [id, ["data": ["savedGearIssues": ["kit": authored]], "payloads": authored]]
    ]
    try ScriptSaveJSONPreflight.rejectCourierFields(
      JSONSerialization.data(withJSONObject: missions), location: .missions)
    let raw: [String: Any] = [
      "savedEquipmentVersion": 2, "savedScriptState": missions,
      "savedEquipmentInventory": ["items": []],
    ]
    try ScriptSaveJSONPreflight.rejectCourierFields(
      JSONSerialization.data(withJSONObject: raw), location: .rawCommander)
    let legacy = ScriptGearIssue(
      resource: "kit", kind: .missile, items: [UUID()], loan: false, returnRemaining: false)
    let old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy))
    let legacyMissions: [String: Any] = [
      "instances": [id: ["savedGearIssues": ["kit": old]]]
    ]
    try ScriptSaveJSONPreflight.rejectCourierFields(
      JSONSerialization.data(withJSONObject: ["savedScriptState": legacyMissions]),
      location: .rawCommander)
  }

  @Test func canonicalGearRecordsJoinAllChunksBeforeAdmissionAndCannotClaimContainer20() throws {
    let fixture = try GearScriptFixture()
    defer { fixture.clean() }
    var game = try fixture.game()
    let state = try #require(game.commander.scriptState.instances.values.first)
    let issue = try #require(state.gearIssues["kit"])
    try #require(issue.savedGearVersion == 2 && game.commander.issuedEquipmentValid)
    let file = fixture.root.appendingPathComponent("commander.json")
    try GameRuntime.writeCommander(&game, to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 21)
    let (loaded, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(loaded.valid && loaded.issuedEquipmentValid)
    #expect(loaded.equipmentInventory == game.commander.equipmentInventory)
    #expect(loaded.scriptState.instances[state.id]?.gearIssues["kit"] == issue)
    let claimed20 = ScriptSavePointer(
      format: pointer.format, schemaVersion: 20, generation: pointer.generation,
      hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    #expect(throws: SaveError.self) {
      try ScriptSaveStore.read(JSONEncoder().encode(claimed20), from: file)
    }
    #expect(try Data(contentsOf: file) == bytes)
  }
}
