import Foundation
import Testing

@testable import EliteCore

struct ScriptProviderPersistenceTests {
  @Test func boundedStateRoundTripsWithStableIDsAndPendingReview() throws {
    var state = ProviderContractFixture.state()
    ProviderContractEffects.authorizeManifest(&state)
    state.pending = .init(
      action: .confirmUrgent, token: ProviderContractFixture.id(70),
      runtimeEpoch: ProviderContractFixture.epoch)
    state.progress.distanceMeters = 6000
    state.progress.checkpointBits = 1
    let loaded = try JSONDecoder().decode(
      ScriptProviderContractState.self, from: JSONEncoder().encode(state))
    #expect(loaded == state && loaded.valid)
    #expect(
      loaded.provider.incarnation == state.provider.incarnation && loaded.subject == state.subject)
    #expect(
      loaded.item == state.item && loaded.pending?.runtimeEpoch != ProviderContractFixture.id(71))
  }
  @Test func oversizedReceiptArrayFailsBeforeDecodingMalformedChildren() throws {
    let state = ProviderContractFixture.state()
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    object["receipts"] = Array(repeating: ["malformed": true], count: 10)
    do {
      _ = try JSONDecoder().decode(
        ScriptProviderContractState.self, from: JSONSerialization.data(withJSONObject: object))
      Issue.record("Oversized provider receipts were accepted.")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.debugDescription == "Provider collection limit exceeded.")
    }
  }
  @Test func oldRawCommanderAndMissionPartsRejectReservedKeyIncludingNull() throws {
    let values: [Any] = [NSNull(), ["invalid": true]]
    for value in values {
      let instance: [String: Any] = ["savedProviderContract": value]
      let representations: [Any] = [["one": instance], ["one", instance]]
      for instances in representations {
        let missions: [String: Any] = ["instances": instances]
        #expect(throws: (any Error).self) {
          try ScriptProviderVersionedSave.rejectFields(
            JSONSerialization.data(withJSONObject: missions), part: .missions)
        }
        #expect(throws: (any Error).self) {
          try ScriptProviderVersionedSave.rejectFields(
            JSONSerialization.data(withJSONObject: ["savedScriptState": missions]), part: .commander
          )
        }
      }
    }
    try ScriptProviderVersionedSave.rejectFields(Data("{}".utf8), part: .commander)
    try ScriptProviderVersionedSave.rejectFields(Data("{\"instances\":{}}".utf8), part: .missions)
    #expect(ScriptProviderVersionedSave.version == 28)
  }
  @Test func foreignManifestAndFabricatedNativeCareAreRejected() throws {
    var state = ProviderContractFixture.state()
    state.manifest = .init(
      identity: ProviderContractFixture.id(72), revision: 1,
      provider: state.provider, subject: state.subject)
    state.receipts.insert(.manifest)
    #expect(!state.valid)
    var commander = Commander()
    try commander.prepareEquipment()
    state = ProviderContractFixture.state()
    state.crew = ProviderContractFixture.crew(state)
    state.receipts.insert(.care)
    var instance = ScriptInstance(
      id: state.instance, definition: "project.crimbo/guiding-light", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.savedProviderContract = state
    instance.payloads[state.terms.payload] = 1
    commander.scriptState.instances[instance.id] = instance
    #expect(!ScriptProviderVersionedSave.validateClaims(commander))
  }
}
