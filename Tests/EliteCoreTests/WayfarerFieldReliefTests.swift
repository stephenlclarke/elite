import Foundation
import Testing

@testable import EliteCore

/// Native doorway fixtures supply authority; JSON mutations below are rejection tests only.
struct WayfarerFieldReliefFixture {
  let native: NativeUtilityRuntimeFixture
  init() throws { native = try NativeUtilityRuntimeFixture() }
  func runtime(stage: NativeUtilityPhase = .received) async throws -> GameRuntime {
    var runtime = try await native.source()
    let collect = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(collect)
    if stage == .held { return runtime }
    runtime = try await native.target(from: runtime)
    let install = try await runtime.nativeUtilityQuote(.install)
    try await runtime.confirmNativeUtility(install)
    if stage == .installed { return runtime }
    let receive = try await runtime.nativeUtilityQuote(.receive)
    try await runtime.confirmNativeUtility(receive)
    return runtime
  }
  func mission(_ commander: Commander) throws -> ScriptInstance {
    let job = try #require(commander.nativeUtility?.consignments.last)
    return try #require(commander.scriptState.instances[WayfarerFieldRelief.instance(job.id)])
  }
  func object<T: Encodable>(_ value: T) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
  }
}

struct WayfarerFieldReliefTests {
  @Test(arguments: [
    "01234567-89AB-CDEF-0123-456789ABCDEF", "ABCDEF01-2345-6789-ABCD-EF0123456789",
  ])
  func originalUUIDOfferKeysPassLocalGrammar(text: String) throws {
    let original = try #require(UUID(uuidString: text))
    let key = WayfarerFieldRelief.offerKey(original)
    #expect(PackValidation.localID(key) && key.utf8.count <= 80)
    let offer = ScriptContractOffer(
      id: ScriptIdentity.uuid("field-relief-offer-v1:\(original)"), key: key,
      title: "W04 local key regression", briefing: "Syntactic offer validation only.",
      destinationGalaxy: 0, destinationSystem: 237, reward: 6100, deposit: 0,
      failureReward: 0, refundOnFailure: false, duration: 0, parameters: .object([:]))
    #expect(offer.valid)
    #expect(offer.id == WayfarerFieldRelief.offer(original))
    #expect(Game.contractJobIdentity(offer.id) == WayfarerFieldRelief.instance(original))
    if text.hasPrefix("0") {
      #expect(!PackValidation.localID(original.uuidString.lowercased()))
    } else {
      #expect(PackValidation.localID(original.uuidString.lowercased()))
    }
  }

  @Test func authoredPackAndPinCannotAuthorizeGenericOrLuaSettlement() async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    let runtime = try await f.native.source()
    var game = await runtime.snapshot()
    let pack = try #require(game.fieldReliefPack)
    #expect(pack.digest == WayfarerFieldRelief.digest && pack.manifest.fieldRelief?.valid == true)
    #expect(pack.manifest.stateID == "l337.wayfarer-service/field-relief")
    #expect(game.scriptUnavailable(pack) != nil)
    #expect(throws: (any Error).self) { try game.acceptScriptMission(pack) }
    var state = ScriptInstance(
      id: UUID(), definition: WayfarerFieldRelief.stateID, version: "1.0.0", digest: pack.digest)
    var candidate = game.commander
    let before = candidate
    let event = ScriptEvent(sequence: 1, kind: "mission.accepted", instance: state.id, values: [:])
    #expect(throws: (any Error).self) {
      try game.applyScriptCommand(
        .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
        event: event, pack: pack, state: &state, candidate: &candidate)
    }
    #expect(candidate == before && state.completionReceipt == nil)
    let completed = try await f.runtime()
    let commander = await completed.snapshot().commander
    let actual = try f.mission(commander)
    let receipt = try #require(actual.completionReceipt)
    #expect(ScriptClueTrustCatalog.production.pin(for: receipt)?.sourceID == WayfarerFieldRelief.stateID)
    #expect(commander.scriptState.savedClueJournal?.awards.count == 1)
  }

  @Test(arguments: [
    "owner", "consignment", "original", "hull", "source", "route", "payout",
    "install-operation", "engineer", "socket", "reception-operation", "duplicate-instance",
  ])
  func originalTypedChainRejectsUnjoinedMissionClaims(fault: String) async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    let runtime = try await f.runtime()
    var commander = await runtime.snapshot().commander
    try #require(WayfarerFieldReliefSave.validateClaims(commander, requireRecordedLoss: true))
    var state = try f.mission(commander)
    let leaf = try #require(state.savedFieldRelief)
    if fault == "duplicate-instance" {
      var duplicate = ScriptInstance(
        id: UUID(), definition: state.definition, version: state.version, digest: state.digest)
      duplicate.savedFieldRelief = leaf
      duplicate.contract = state.contract
      commander.scriptState.instances[duplicate.id] = duplicate
    } else {
      var raw = try f.object(leaf)
      var job = try #require(raw["job"] as? [String: Any])
      switch fault {
      case "owner": raw["owner"] = UUID().uuidString
      case "consignment": job["id"] = UUID().uuidString
      case "original": job["originalUnits"] = [UUID(), UUID(), UUID(), UUID()].map(\.uuidString)
      case "hull": job["hull"] = UUID().uuidString
      case "source":
        var source = try #require(job["source"] as? [String: Any])
        source["sequence"] = 999
        job["source"] = source
      case "route": job["route"] = [237, 7]
      case "payout": job["rewardTenths"] = 1
      case "install-operation", "engineer", "socket":
        var installation = try #require(job["installation"] as? [String: Any])
        if fault == "socket" { installation["socket"] = 99 }
        else { installation[fault == "engineer" ? "engineer" : "operation"] = UUID().uuidString }
        job["installation"] = installation
      default:
        var reception = try #require(job["reception"] as? [String: Any])
        reception["operation"] = UUID().uuidString
        job["reception"] = reception
      }
      raw["job"] = job
      state.savedFieldRelief = try JSONDecoder().decode(
        WayfarerFieldReliefCustody.self, from: JSONSerialization.data(withJSONObject: raw))
      commander.scriptState.instances[state.id] = state
    }
    #expect(!WayfarerFieldReliefSave.validateClaims(commander, requireRecordedLoss: true))
    #expect(!commander.valid)
  }

  @Test(arguments: [
    "missing", "null", "foreign", "unknown", "oversize", "stripped", "embedded", "wrong-envelope",
  ])
  func closedCurrentFieldReliefCodecRejectsHiddenOrDroppedEvidence(fault: String) async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    let runtime = try await f.runtime(stage: .held)
    let state = try f.mission(await runtime.snapshot().commander)
    var instance = try f.object(state)
    var leaf = try #require(instance["savedFieldRelief"] as? [String: Any])
    switch fault {
    case "missing": leaf.removeValue(forKey: "accepted")
    case "null": instance["savedFieldRelief"] = NSNull()
    case "foreign": instance["definition"] = "example/foreign"
    case "unknown": leaf["invented"] = true
    case "oversize":
      var job = try #require(leaf["job"] as? [String: Any])
      job["route"] = Array(repeating: 7, count: 257)
      leaf["job"] = job
    case "stripped": instance.removeValue(forKey: "savedFieldRelief")
    default: break
    }
    if !["null", "stripped"].contains(fault) { instance["savedFieldRelief"] = leaf }
    let root: [String: Any] = ["instances": [state.id.uuidString: instance]]
    let object: [String: Any]
    if fault == "embedded" {
      object = ["savedScriptState": root]
    } else {
      object = root
    }
    let bytes = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) {
      try WayfarerFieldReliefSave.validateFields(
        bytes, part: fault == "embedded" ? .commander : .missions,
        schema: fault == "wrong-envelope" ? 53 : 57)
    }
  }

  @Test func currentAdapterEnvelopeReservesItsOwnNumbersAndPreservesExactLeaf() async throws {
    #expect(WayfarerFieldReliefSave.version == 57 && WayfarerFieldReliefSave.alienVersion == 58)
    #expect(!WayfarerFieldReliefSave.contains(55) && !WayfarerFieldReliefSave.contains(56))
    #expect(WayfarerFieldReliefSave.lowerSchema(57) == 55)
    #expect(WayfarerFieldReliefSave.lowerSchema(58) == 56)
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    let runtime = try await f.runtime()
    let commander = await runtime.snapshot().commander
    let state = try f.mission(commander)
    let leaf = try #require(state.savedFieldRelief)
    #expect(try JSONDecoder().decode(
      WayfarerFieldReliefCustody.self, from: JSONEncoder().encode(leaf)) == leaf)
    let bytes = try JSONSerialization.data(
      withJSONObject: ["instances": [state.id.uuidString: try f.object(state)]])
    try ScriptSaveJSONPreflight.validateRepairLoopFields(bytes, part: .missions, schema: 57)
    try ScriptSaveJSONPreflight.validateRepairLoopFields(bytes, part: .missions, schema: 58)
    // These are structural current-envelope checks, not a G12 coexistence qualification.
    _ = try await f.native.reloaded(runtime)
  }
}
