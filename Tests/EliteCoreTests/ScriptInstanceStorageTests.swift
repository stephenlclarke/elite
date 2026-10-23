import Foundation
import Testing

@testable import EliteCore

private let storedInstanceID = UUID(uuidString: "6D627A65-6D0A-4D44-8ABD-F08178A03DD7")!

private func storedInstance() -> ScriptInstance {
  var value = ScriptInstance(
    id: storedInstanceID, definition: "test.storage", version: "1.0.0",
    digest: String(repeating: "a", count: 64))
  let context = ScriptEventContext(
    galaxy: 0, system: 7, docked: true, mainStation: true, revision: 1,
    frameSeconds: 0, localSeconds: 0, flightSeconds: 0, calendarSeconds: 0,
    transitSeconds: 0, playerPosition: nil)
  let receipt = ScriptChoiceReceipt(
    instance: value.id, group: "job", choice: "accept", label: "Accept",
    dialogue: "offer", sequence: 1, revision: 1, cause: context, committed: context)
  value.choiceReceipts = ["job": receipt]
  value.savedConversationReceipts = [1: receipt]
  value.receiptJoins = ["job": [value.id]]
  value.data = .object(["nested": .array([.integer(2)])])
  value.dialogue = .init(
    collectionQuote: .init(collection: "supplies", items: []),
    id: "offer", token: "original", galaxy: 0, system: 7, revision: 1)
  let station = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  let offer = ScriptContractOffer(
    id: value.id, key: "job", title: "Job", briefing: "Supplies",
    destinationGalaxy: 0, destinationSystem: 7, reward: 100, deposit: 0,
    failureReward: 0, refundOnFailure: false, duration: 60, parameters: .object([:]))
  value.contract = .init(
    boardKey: value.digest + "/board/" + station.key, provider: "test.storage",
    version: value.version, digest: value.digest, station: station, boardRevision: 0,
    group: "test.storage/jobs", offer: offer, clock: .local, acceptedAt: 0, deadline: 60)
  value.payloads = ["supplies": 2]
  value.journal = ["Accepted"]
  value.acknowledgedEvents = [1]
  value.receipts = ["accepted"]
  value.milestones = [1]
  value.ownedEncounters = ["escort": .init(id: "escort", galaxy: 0, system: 7, actors: [:])]
  return value
}

/// The original synthesized instance shape, independent of the backing value's encoder.
private func originalInstanceObject() -> [String: Any] {
  [
    "id": storedInstanceID.uuidString, "definition": "test.storage", "version": "1.0.0",
    "digest": String(repeating: "a", count: 64), "data": [String: Any](),
    "outcome": "active", "revision": 0, "acknowledgedEvents": [UInt64](),
    "receipts": [String](), "milestones": [Int](), "payloads": [String: Int](),
    "timers": [String: Any](), "journal": [String](), "randomState": UInt64(0x45_4c49_5445),
  ]
}

struct ScriptInstanceStorageTests {
  @Test func copiesDetachNestedContractsDialogueReceiptsAndEncounterMutation() throws {
    var original = storedInstance()
    let retained = original
    let bytes = try JSONEncoder().encode(original)
    var copy = original
    #expect(copy == original)
    copy.contract?.settled = true
    copy.contract?.settlementAmount = 100
    copy.dialogue?.token = "copy"
    copy.dialogue?.collectionQuote = nil
    copy.choiceReceipts.removeValue(forKey: "job")
    copy.savedConversationReceipts?.removeValue(forKey: 1)
    copy.receiptJoins?["job"]?.append(UUID())
    copy.payloads["supplies"] = 9
    copy.journal.append("Copy")
    copy.ownedEncounters["escort"]?.admitted = true
    copy.data = .object(["nested": .array([.integer(9)])])
    #expect(copy != original && original == retained)
    #expect(original.contract?.settled == false && original.contract?.settlementAmount == nil)
    #expect(original.dialogue?.token == "original" && original.dialogue?.collectionQuote != nil)
    #expect(original.choiceReceipts["job"] != nil && original.savedConversationReceipts?[1] != nil)
    #expect(original.receiptJoins?["job"] == [original.id])
    #expect(original.payloads["supplies"] == 2 && original.journal == ["Accepted"])
    #expect(original.ownedEncounters["escort"]?.admitted == false)
    #expect(original.data == .object(["nested": .array([.integer(2)])]))
    #expect(try JSONDecoder().decode(ScriptInstance.self, from: bytes) == original)
    original.payloads["supplies"] = 4
    original.dialogue?.token = "original changed"
    #expect(retained.payloads["supplies"] == 2 && copy.payloads["supplies"] == 9)
    #expect(retained.dialogue?.token == "original" && copy.dialogue?.token == "copy")
    for value in [original, retained, copy] {
      #expect(value.id == storedInstanceID && value.definition == "test.storage")
      #expect(value.version == "1.0.0" && value.digest == String(repeating: "a", count: 64))
    }
  }

  @Test func originalUnwrappedJSONAndEngineDictionaryRoundTripWithoutStorageKeys() throws {
    let object = originalInstanceObject()
    let bytes = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: bytes)
    let fresh = ScriptInstance(
      id: storedInstanceID, definition: "test.storage", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    #expect(decoded == fresh)
    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? NSDictionary)
    #expect(encoded == object as NSDictionary)
    #expect(decoded.savedChoiceReceipts == nil && decoded.savedConversationReceipts == nil)
    #expect(decoded.dialogue == nil && decoded.contract == nil)
    let populated = storedInstance()
    let typed = try ScriptValueStorage.encoder().encode(populated)
    #expect(
      try ScriptValueStorage.decoder(typed: true).decode(ScriptInstance.self, from: typed)
        == populated)
    var engine = ScriptEngineState()
    engine.instances[populated.id] = populated
    let engineBytes = try JSONEncoder().encode(engine)
    #expect(try JSONDecoder().decode(ScriptEngineState.self, from: engineBytes) == engine)
    let engineObject = try #require(
      JSONSerialization.jsonObject(with: engineBytes) as? [String: Any])
    let entries = try #require(engineObject["instances"] as? [Any])
    try #require(entries.count == 2)
    let instanceObject = try #require(entries[1] as? NSDictionary)
    let directObject = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(populated)) as? NSDictionary)
    #expect(entries[0] as? String == populated.id.uuidString && instanceObject == directObject)
    #expect(instanceObject["savedChoiceReceipts"] != nil)
    #expect(
      instanceObject["savedOwnedEncounters"] != nil && instanceObject["ownedEncounters"] == nil)
    #expect(instanceObject["storage"] == nil && instanceObject["value"] == nil)
  }

  @Test func decodingKeepsOriginalRequiredKeysOptionalOmissionAndMalformedRefusal() throws {
    let object = originalInstanceObject()
    for key in object.keys {
      var missing = object
      missing.removeValue(forKey: key)
      let bytes = try JSONSerialization.data(withJSONObject: missing)
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(ScriptInstance.self, from: bytes)
      }
    }
    for (key, value) in [
      ("id", "not-a-uuid" as Any), ("outcome", "unknown" as Any),
      ("revision", -1 as Any), ("payloads", [1, 2] as Any),
      ("savedChoiceReceipts", 7 as Any),
    ] {
      var malformed = object
      malformed[key] = value
      let bytes = try JSONSerialization.data(withJSONObject: malformed)
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(ScriptInstance.self, from: bytes)
      }
    }
    var emptyOptional = object
    emptyOptional["savedChoiceReceipts"] = [String: Any]()
    emptyOptional["savedGearIssues"] = [String: Any]()
    emptyOptional["savedOwnedEncounters"] = [String: Any]()
    let bytes = try JSONSerialization.data(withJSONObject: emptyOptional)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: bytes)
    #expect(decoded.savedChoiceReceipts == [:] && decoded.gearIssues.isEmpty)
    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
    #expect(encoded["savedChoiceReceipts"] != nil && encoded["savedGearIssues"] != nil)
    #expect(encoded["savedOwnedEncounters"] != nil)
  }

  @Test(arguments: [
    "id", "definition", "version", "digest", "data", "savedCollections",
    "savedCampaignChildren", "savedCampaignReceiptScopes", "savedConversationReceipts",
    "savedChoiceReceipts", "receiptJoins", "savedGearIssues", "savedOwnedEncounters",
    "pledgeReceiptID", "suspension", "acknowledgedThrough", "outcome-complete",
    "outcome-failed", "outcome-abandoned", "revision", "acknowledgedEvents", "receipts",
    "milestones", "payloads", "timers", "dialogue", "journal", "contract", "randomState",
  ])
  func equalityDistinguishesChangedValuesAndAbsentVersusEmptyStoredCollections(field: String) throws
  {
    let object = originalInstanceObject()
    let original = try JSONDecoder().decode(
      ScriptInstance.self, from: JSONSerialization.data(withJSONObject: object))
    let populated = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(storedInstance())) as? [String: Any])
    var changed = object
    switch field {
    case "id", "pledgeReceiptID": changed[field] = UUID().uuidString
    case "definition": changed[field] = "test.changed"
    case "version": changed[field] = "2.0.0"
    case "digest": changed[field] = String(repeating: "b", count: 64)
    case "data": changed[field] = ["changed": 1]
    case "savedCollections", "savedCampaignChildren", "savedCampaignReceiptScopes",
      "savedChoiceReceipts", "receiptJoins", "savedGearIssues", "savedOwnedEncounters":
      changed[field] = [String: Any]()
    case "savedConversationReceipts": changed[field] = [Any]()
    case "suspension": changed[field] = "Paused"
    case "acknowledgedThrough", "revision": changed[field] = 1
    case "outcome-complete": changed["outcome"] = "complete"
    case "outcome-failed": changed["outcome"] = "failed"
    case "outcome-abandoned": changed["outcome"] = "abandoned"
    case "acknowledgedEvents", "milestones": changed[field] = [1]
    case "receipts", "journal": changed[field] = ["changed"]
    case "payloads": changed[field] = ["changed": 1]
    case "timers":
      let timer = ScriptTimer(id: "pulse", domain: .flight, due: 1, interval: 2, policy: .skip)
      changed[field] = [
        "pulse": try JSONSerialization.jsonObject(with: JSONEncoder().encode(timer))
      ]
    case "dialogue", "contract": changed[field] = try #require(populated[field])
    case "randomState": changed[field] = UInt64(0x45_4c49_5446)
    default: Issue.record(Comment(rawValue: "Unrecognised equality fixture: " + field))
    }
    let different = try JSONDecoder().decode(
      ScriptInstance.self, from: JSONSerialization.data(withJSONObject: changed))
    #expect(original != different && different != original)
    let retained = different
    let reloaded = try JSONDecoder().decode(
      ScriptInstance.self, from: JSONEncoder().encode(different))
    #expect(different == retained && retained == reloaded)
    #expect(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? NSDictionary
        == object as NSDictionary)
  }

  @Test(arguments: [
    "savedCollections", "savedCampaignChildren", "campaignParent", "savedCampaignReceiptScopes",
    "savedConversationReceipts", "savedChoiceReceipts", "completionReceipt",
    "savedProviderContract",
    "savedOwnedCargo", "savedWayfarerColdChain", "savedWayfarerRepairLoop", "savedFieldRelief",
    "savedNavigationTrade", "savedOriginalSurvey", "savedGlassMeridian", "savedArkReserve",
    "savedArkRecovery", "savedNativeArk", "savedNativeCrewLog", "savedNativeInductionUtility",
    "savedNativeInductionClinic", "savedNativeInductionWorkshop", "savedNativeInductionSeed",
    "savedWayfarerInduction", "savedFlightReception", "savedMeasuredExtraction",
    "savedRecordRecovery",
    "savedIdentifiedSalvage", "courier", "pledgeReceiptID", "receiptJoins", "suspension",
    "acknowledgedThrough", "dialogue", "contract", "savedGearIssues", "savedOwnedEncounters",
  ])
  func explicitNullOptionalKeysRetainTheOriginalAbsentSchema(key: String) throws {
    let original = originalInstanceObject()
    var withNull = original
    withNull[key] = NSNull()
    let decoded = try JSONDecoder().decode(
      ScriptInstance.self, from: JSONSerialization.data(withJSONObject: withNull))
    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? NSDictionary)
    // All fourteen original required keys survive; an optional null has no storage envelope.
    #expect(encoded == original as NSDictionary)
    let independent = try JSONDecoder().decode(
      ScriptInstance.self, from: JSONSerialization.data(withJSONObject: original))
    #expect(decoded == independent)
  }

  @Test func sharedCloneKeepsLargeNativePayloadsWhenTheContractIsModified() throws {
    let fixture = try InductionSeedFixture()
    var original = storedInstance()
    original.savedNativeInductionSeed = fixture.child().savedNativeInductionSeed
    original.savedWayfarerInduction = fixture.held
    let retained = original
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let before = try encoder.encode(original)
    var changed = original
    // This is the required Array COW plus inner payload clone at the observed settlement boundary.
    changed.contract?.settled = true
    changed.contract?.settlementAmount = 100
    #expect(changed.contract?.settled == true && original.contract?.settled == false)
    #expect(changed.savedNativeInductionSeed == original.savedNativeInductionSeed)
    #expect(changed.savedWayfarerInduction == original.savedWayfarerInduction)
    #expect(changed.reservedSeedCargoTonnes == original.reservedSeedCargoTonnes)
    #expect(original == retained)
    #expect(try encoder.encode(retained) == before)
    changed.savedNativeInductionSeed = nil
    changed.savedWayfarerInduction = nil
    #expect(retained.savedNativeInductionSeed != nil && retained.savedWayfarerInduction != nil)
    #expect(try encoder.encode(original) == before)
    #expect(try JSONDecoder().decode(ScriptInstance.self, from: before) == retained)
  }

  @Test func throwingNestedInoutMutationDetachesAndRemainsWritable() throws {
    enum Expected: Error { case stop }
    let original = storedInstance()
    let retained = original
    var changed = original
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let before = try encoder.encode(original)
    func mutateThenThrow(_ job: inout ScriptContractJob?) throws {
      job?.settled = true
      job?.settlementAmount = 100
      throw Expected.stop
    }
    #expect(throws: Expected.self) { try mutateThenThrow(&changed.contract) }
    #expect(changed.contract?.settled == true && changed.contract?.settlementAmount == 100)
    #expect(original.contract?.settled == false && original.contract?.settlementAmount == nil)
    changed.receiptJoins?["job"]?.append(UUID())
    changed.journal.append("After throw")
    #expect(changed.receiptJoins?["job"]?.count == 2 && changed.journal.count == 2)
    #expect(original.receiptJoins?["job"] == [original.id] && original.journal == ["Accepted"])
    #expect(original == retained)
    #expect(try encoder.encode(original) == before)
    #expect(try JSONDecoder().decode(ScriptInstance.self, from: encoder.encode(changed)) == changed)
  }

  @Test func sharedPayloadEqualityPreservesNaNAndSignedZeroMemberSemantics() {
    var value = storedInstance()
    value.timers["pulse"] = .init(
      id: "pulse", domain: .flight, due: .nan, interval: 1, policy: .skip)
    let shared = value
    // Existing Array equality accepts the same outer buffer without visiting its element.
    #expect(value == shared && shared == value)
    var independentlyCloned = shared
    independentlyCloned.revision += 1
    independentlyCloned.revision -= 1
    // Detaching the payload still shares the original timer dictionary's COW buffer.
    #expect(value == independentlyCloned && independentlyCloned == value)
    // A separately allocated dictionary reaches the original timer member comparison.
    independentlyCloned.timers = [
      "pulse": .init(id: "pulse", domain: .flight, due: .nan, interval: 1, policy: .skip)
    ]
    #expect(value != independentlyCloned && independentlyCloned != value)
    value.timers["pulse"]?.due = -0.0
    independentlyCloned.timers["pulse"]?.due = 0.0
    #expect(value == independentlyCloned && independentlyCloned == value)
    #expect(shared.timers["pulse"]?.due.isNaN == true)
  }

  @Test func suppliedAndActorSnapshotInstancesKeepIndependentNestedValues() async throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-courier")
    let pack = try ScriptPackLibrary.read(directory)
    var supplied = Game(executive: false)
    supplied.screen = .status
    supplied.scriptPacks = [pack]
    let id = try supplied.acceptScriptMission(pack, drainAccepted: false)
    let original = try #require(supplied.commander.scriptState.instances[id])
    let runtime = GameRuntime(game: supplied)
    let retained = await runtime.snapshot()
    let actorInstance = try #require(retained.commander.scriptState.instances[id])
    var caller = retained
    caller.commander.scriptState.instances[id]?.data = .object(["caller": .integer(1)])
    caller.commander.scriptState.instances[id]?.journal.append("Caller only")
    supplied.commander.scriptState.instances[id]?.payloads["supplied"] = 1
    supplied.commander.scriptState.instances[id]?.revision += 1
    let latest = await runtime.snapshot()
    #expect(latest.commander.scriptState.instances[id] == actorInstance)
    #expect(retained.commander.scriptState.instances[id] == actorInstance)
    #expect(actorInstance == original)
    #expect(caller.commander.scriptState.instances[id] != actorInstance)
    #expect(supplied.commander.scriptState.instances[id] != actorInstance)
    #expect(actorInstance.payloads["supplied"] == nil && actorInstance.journal.isEmpty)
  }

  @Test(arguments: ["absent", "populated"])
  func fieldBuffersDetachLargeNestedValuesAndKeepRetainedNilAndCodec(scenario: String) throws {
    enum Expected: Error { case stop }
    var original = storedInstance()
    if scenario == "populated" {
      let fixture = NativeGlassMeridianUnitTests()
      var glass = try fixture.fixture()
      glass.readings = [
        try fixture.sealed(glass, ordinal: 0), try fixture.sealed(glass, ordinal: 1, start: 22),
      ]
      original.savedGlassMeridian = glass
    }
    let retained = original
    let ownedChild = original.savedGlassMeridian
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(original)
    var changed = original
    changed.contract?.settled = true
    changed.contract?.settlementAmount = 100
    #expect(changed.savedGlassMeridian == ownedChild)
    #expect(original.contract?.settled == false && original.contract?.settlementAmount == nil)
    func clearReadingsThenThrow(_ child: inout NativeGlassMeridianState?) throws {
      child?.readings.removeAll()
      throw Expected.stop
    }
    #expect(throws: Expected.self) { try clearReadingsThenThrow(&changed.savedGlassMeridian) }
    if scenario == "populated" {
      #expect(changed.savedGlassMeridian?.readings.isEmpty == true)
      #expect(original.savedGlassMeridian?.readings.count == 2)
      #expect(ownedChild?.readings.count == 2 && retained.savedGlassMeridian == ownedChild)
      var ownedMutation = ownedChild
      ownedMutation?.readings.removeAll()
      #expect(ownedMutation != ownedChild && original.savedGlassMeridian == ownedChild)
    } else {
      #expect(changed.savedGlassMeridian == nil && original.savedGlassMeridian == nil)
    }
    changed.savedGlassMeridian = nil
    #expect(changed.savedGlassMeridian == nil)
    #expect(original == retained)
    #expect(try encoder.encode(retained) == bytes)
    #expect(try JSONDecoder().decode(ScriptInstance.self, from: bytes) == original)
    let fields = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(retained)) as? [String: Any])
    #expect((fields["savedGlassMeridian"] != nil) == (scenario == "populated"))
    #expect(fields["payload"] == nil && fields["storage"] == nil && fields["values"] == nil)
  }

}
