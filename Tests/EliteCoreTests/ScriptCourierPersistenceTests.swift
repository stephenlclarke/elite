import Foundation
import Testing

@testable import EliteCore

@Test func courierLegacyKeywordsAndOrdinaryPayloadNamesRemainValidFormat20AndRaw() async throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.screen = .status
  game.ensureScriptCalendar(origin: .newCommander)
  let id = UUID()
  var old = ScriptInstance(
    id: id, definition: "old.words/story", version: "1.0.0",
    digest: String(repeating: "0", count: 64))
  old.data = .object([
    "courier": .string("missionCalendar"),
    "nested": .object(["deadlinePolicy": .string("courier")]),
  ])
  old.payloads[ScriptCourierCustody.payloadKey] = 1
  game.commander.scriptState.instances[id] = old
  #expect(game.commander.valid)
  try GameRuntime.writeCommander(&game, to: fixture.save)
  let original = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let format20 = ScriptSavePointer(
    format: original.format, schemaVersion: 20,
    generation: original.generation, hashes: original.hashes, scope: original.scope,
    valueCodec: original.valueCodec)
  let bytes = try JSONEncoder().encode(format20)
  let (loaded, _) = try ScriptSaveStore.read(bytes, from: fixture.save)
  #expect(loaded.scriptState.instances[id]?.data == old.data)
  #expect(loaded.scriptState.instances[id]?.payloads[ScriptCourierCustody.payloadKey] == 1)
  let raw = fixture.root.appendingPathComponent("legacy.json")
  try JSONEncoder().encode(game.commander).write(to: raw)
  let runtime = GameRuntime()
  try await runtime.load(from: raw)
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.data == old.data)
}

@Test func courierPre21PresenceGuardsCheckNativePathsIncludingUUIDPairDictionaries() throws {
  let id = UUID().uuidString
  let nativeInstances: [[String: Any]] = [
    ["courier": NSNull()],
    ["contract": ["offer": ["courier": NSNull()]]],
    ["contract": ["deadlinePolicy": "inclusiveConfirmation"]],
    ["timers": ["deadline": ["domain": "missionCalendar"]]],
  ]
  for instance in nativeInstances {
    for encodedInstances: Any in [[id: instance], [id, instance]] {
      let root: [String: Any] = ["instances": encodedInstances]
      let bytes = try JSONSerialization.data(withJSONObject: root)
      #expect(throws: SaveError.self) {
        try ScriptSaveJSONPreflight.rejectCourierFields(bytes, location: .missions)
      }
      let raw = try JSONSerialization.data(withJSONObject: ["savedScriptState": root])
      #expect(throws: SaveError.self) {
        try ScriptSaveJSONPreflight.rejectCourierFields(raw, location: .rawCommander)
      }
    }
  }
  let authored: [String: Any] = [
    "instances": [
      id,
      [
        "data": ["courier": ["missionCalendar": true]],
        "payloads": ["courier-consignment": 1],
      ],
    ]
  ]
  try ScriptSaveJSONPreflight.rejectCourierFields(
    JSONSerialization.data(withJSONObject: authored), location: .missions)
}

@Test func courierVersionClaimsAndCorruptPhysicalProjectionAreRejectedWithoutPublication()
  async throws
{
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try fixture.accept(&game, variant: .package)
  try GameRuntime.writeCommander(&game, to: fixture.save)
  let pointerBytes = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
  let claimed20 = ScriptSavePointer(
    format: pointer.format, schemaVersion: 20,
    generation: pointer.generation, hashes: pointer.hashes, scope: pointer.scope,
    valueCodec: pointer.valueCodec)
  #expect(throws: SaveError.self) {
    try ScriptSaveStore.read(JSONEncoder().encode(claimed20), from: fixture.save)
  }
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot()
  let raw = fixture.root.appendingPathComponent("hidden-native.json")
  try JSONEncoder().encode(game.commander).write(to: raw)
  await #expect(throws: SaveError.self) { try await runtime.load(from: raw) }
  #expect(await runtime.snapshot().commander == before.commander)
  game.commander.scriptState.instances[id]?.payloads[ScriptCourierCustody.payloadKey] = 0
  #expect(!game.commander.valid)
  #expect(throws: SaveError.self) { try GameRuntime.writeCommander(&game, to: fixture.save) }
  #expect(try Data(contentsOf: fixture.save) == pointerBytes)
}

@Test func courierFailedAcceptanceAndHandoffPublicationRetainOriginalGeneration() async throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, offer) = try fixture.usable(&game)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let backup = fixture.root.appendingPathComponent("blocked-save-backup")
  try FileManager.default.moveItem(at: fixture.save.appendingPathExtension("missions"), to: backup)
  try Data("blocked native writer".utf8).write(to: fixture.save.appendingPathExtension("missions"))
  await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
  #expect(await runtime.snapshot().commander == before.commander)
  try FileManager.default.removeItem(at: fixture.save.appendingPathExtension("missions"))
  try FileManager.default.moveItem(at: backup, to: fixture.save.appendingPathExtension("missions"))
  let id = try await runtime.confirmContract(quote)
  try await fixture.travel(runtime, id: id)
  await runtime.key("contacts-open")
  await runtime.key("left")
  let offered = await runtime.snapshot()
  let pointer = try Data(contentsOf: fixture.save)
  try FileManager.default.moveItem(at: fixture.save.appendingPathExtension("missions"), to: backup)
  try Data("blocked native writer".utf8).write(to: fixture.save.appendingPathExtension("missions"))
  await runtime.key("return")
  let rejected = await runtime.snapshot()
  #expect(
    rejected.commander == offered.commander
      && rejected.scriptPresentedDialogue == offered.scriptPresentedDialogue)
  #expect(rejected.scriptCourierAdmission == nil && rejected.screen == .handoff)
  #expect(try Data(contentsOf: fixture.save) == pointer)
  try FileManager.default.removeItem(at: fixture.save.appendingPathExtension("missions"))
  try FileManager.default.moveItem(at: backup, to: fixture.save.appendingPathExtension("missions"))
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
}

extension CourierFixture {
  func failedReceiptConsumer() throws -> ScriptPack {
    let directory = root.appendingPathComponent("consumer")
    try FileManager.default.createDirectory(
      at: directory.appendingPathComponent("scripts"), withIntermediateDirectories: true)
    let manifest = """
      schemaVersion=2
      missionAPI=2
      id="project.courier-consumer"
      version="1.0.0"
      minimumEngine="2.0.0"
      capabilities=["script-lua-v1","story-v2","completion-receipts-v2","durable-commands-v2"]
      priority=570
      source="Native failed courier receipt consumer fixture"
      license="MIT"
      environments=["orbital-station"]
      module="scripts/main.lua"
      [mission]
      id="consumer"
      title="Courier failure observer"
      briefing="Observe a real failed native courier receipt exactly once."
      destination="Actual native receipt"
      reward="None"
      milestones=["Observe failure"]
      [[receiptRequirements]]
      id="courier-failed"
      stage="completion"
      definition="\(pack.manifest.stateID)"
      version="\(pack.manifest.version)"
      digest="\(pack.digest)"
      outcome="failed"
      minimumCount=1
      [[handlers]]
      event="mission.accepted"
      function="accepted"
      [[handlers]]
      event="mission.receipted"
      function="receipted"
      """
    try manifest.write(
      to: directory.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
    try """
    return {
      accepted=function(e,w,d) return {data=d,commands={}} end,
      receipted=function(e,w,d)
        d.count=(d.count or 0)+1
        return {data=d,commands={{op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}}
      end
    }
    """.write(
      to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    return try ScriptPackLibrary.read(directory)
  }
}

@Test func courierMissingContentNativeFailurePublishesSharedReceiptAndConsumerOnce() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  let consumer = try fixture.failedReceiptConsumer()
  var game = fixture.game()
  let courier = try fixture.accept(&game)
  game.scriptPacks.append(consumer)
  let dependent = try game.acceptScriptMission(consumer)
  let due = try #require(game.commander.scriptState.instances[courier]?.contract?.deadline)
  game.commander.scriptState.calendarSeconds = due + 0.1
  game.commander.scriptState.missionCalendar?.seconds = due + 0.1
  game.scriptPacks = [consumer]
  game.suspendUnavailableScriptContent()
  for _ in 0..<4095 { game.emitScriptEvent("contact.requested", only: courier, drain: false) }
  game.emitScriptEvent("contact.requested", only: dependent, drain: false)
  let unrelatedSequence = game.commander.scriptState.nextEvent
  #expect(game.commander.scriptState.pendingEvents.count == 4096)
  let before = game.commander
  game.resolveCourierTerminals(publish: { _ in throw SaveError.invalidCommander })
  #expect(game.commander == before)
  game.resolveCourierTerminals()
  #expect(!game.commander.scriptState.pendingEvents.contains { $0.instance == courier })
  #expect(game.commander.scriptState.pendingEvents.contains { $0.sequence == unrelatedSequence })
  let receipt = try #require(game.commander.scriptState.instances[courier]?.completionReceipt)
  #expect(receipt.outcome == .failed && receipt.causeKind == "courier.terminated")
  #expect(
    receipt.valid(
      for: game.commander.scriptState.instances[courier]!, engine: game.commander.scriptState))
  #expect(
    game.commander.scriptState.pendingEvents.filter {
      $0.instance == dependent && $0.kind == "mission.receipted"
    }.count == 1)
  try GameRuntime.writeCommander(&game, to: fixture.save)
  let (restored, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  game.commander = restored
  game.resolveCourierTerminals()
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[dependent]?.outcome == .complete)
  #expect(game.commander.scriptState.instances[dependent]?.data["count"] == .integer(1))
  game.resolveCourierTerminals()
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[dependent]?.data["count"] == .integer(1))
  #expect(game.commander.valid)
}

@Test func courierTerminalLoadRequiresExactSharedCompletionSequenceCauseAndRevision() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try fixture.accept(&game)
  let due = try #require(game.commander.scriptState.instances[id]?.contract?.deadline)
  game.commander.scriptState.calendarSeconds = due + 0.1
  game.commander.scriptState.missionCalendar?.seconds = due + 0.1
  game.resolveCourierTerminals()
  let original = try #require(game.commander.scriptState.instances[id])
  #expect(game.commander.valid && original.completionReceipt != nil)
  var deleted = game.commander
  deleted.scriptState.instances[id]?.completionReceipt = nil
  #expect(!deleted.valid)
  let bytes = try JSONEncoder().encode(original)
  for field in ["sequence", "causeKind", "revision", "instance", "causeSystem", "causeRevision"] {
    var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var completion = try #require(object["completionReceipt"] as? [String: Any])
    switch field {
    case "sequence": completion[field] = original.courier!.issue.sequence
    case "causeKind": completion[field] = "dialogue.confirmed"
    case "revision": completion[field] = original.revision + 1
    case "causeSystem", "causeRevision":
      var cause = try #require(completion["cause"] as? [String: Any])
      if field == "causeSystem" {
        cause["system"] = (game.commander.system + 1) % 256
      } else {
        cause["revision"] = 0
      }
      completion["cause"] = cause
    default: completion[field] = UUID().uuidString
    }
    object["completionReceipt"] = completion
    let corrupt = try JSONDecoder().decode(
      ScriptInstance.self, from: JSONSerialization.data(withJSONObject: object))
    var candidate = game.commander
    candidate.scriptState.instances[id] = corrupt
    #expect(!candidate.valid)
  }
  var held = fixture.game()
  let heldID = try fixture.accept(&held)
  held.commander.scriptState.instances[heldID]?.completionReceipt = original.completionReceipt
  #expect(!held.commander.valid)
}

@Test func courierMissingContentAndNativeHullExchangePreserveExactCustodyAndBlockBadFit()
  async throws
{
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.credits = 100_000_000
  let id = try fixture.accept(&game, variant: .package)
  let original = try #require(game.commander.scriptState.instances[id]?.courier)
  let frozen = game.commander.scriptState.instances[id]?.contract
  try GameRuntime.writeCommander(&game, to: fixture.save)
  let missing = GameRuntime(game: Game(executive: false))
  try await missing.load(from: fixture.save)
  let held = await missing.snapshot()
  #expect(held.commander.scriptState.instances[id]?.courier == original)
  #expect(
    held.commander.scriptState.instances[id]?.suspension != nil && held.commander.cargoTonnes == 1)
  #expect(
    held.courierGallerySummary(held.commander.scriptState.instances[id]).contains(
      "Held - mission content unavailable"))
  let pack = fixture.pack
  await missing.nativeCommand { @Sendable game in game.scriptPacks = [pack] }
  try await missing.resumeScriptMission(id)
  game = await missing.snapshot()
  #expect(game.commander.scriptState.instances[id]?.suspension == nil)
  game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
  game.key("6")
  game.showroom.selection = "SH001"
  let blocked = try #require(game.shipTradeQuote)
  #expect(!blocked.allowed)
  let before = game.commander
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander == before && game.commander.scriptState.instances[id]?.courier == original)
  game.key("escape")
  game.commander.cargo[0] = 0
  game.showroom.selection = "SH013"
  let permitted = try #require(game.shipTradeQuote)
  #expect(permitted.allowed)
  let missiles = game.commander.missiles
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander.shipID == "SH013" && game.commander.missiles <= missiles)
  #expect(game.commander.scriptState.instances[id]?.courier == original)
  #expect(game.commander.scriptState.instances[id]?.contract == frozen)
  #expect(game.commander.cargoTonnes == 1 && game.commander.valid)
}

@Test func courierScriptStateInoutWritebackPreservesDefaultEncodingAndThrownMutation() throws {
  enum Stop: Error { case expected }
  func change(_ state: inout ScriptEngineState) throws {
    state.flightSeconds += 1
    throw Stop.expected
  }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  var commander = Commander()
  let empty = try encoder.encode(commander)
  #expect(throws: Stop.self) { try change(&commander.scriptState) }
  #expect(commander.scriptState.flightSeconds == 1)
  let mutated = try encoder.encode(commander)
  #expect(mutated != empty)
  #expect(try JSONDecoder().decode(Commander.self, from: mutated).scriptState.flightSeconds == 1)
  commander.scriptState.flightSeconds -= 1
  #expect(try encoder.encode(commander) == empty)
}

@Test func courierScriptStateCopiedCommanderAndGameIsolateThrownNestedMutations() throws {
  enum Stop: Error { case expected }
  func change(_ state: inout ScriptEngineState, id: UUID) throws {
    state.instances[id]?.data = .object(["nested": .array([.integer(1), .integer(2)])])
    state.instances[id]?.timers["hold"]?.pulses += 1
    state.pendingEvents.append(
      .init(
        sequence: 2, kind: "contact.requested", instance: id,
        values: ["nested": .object(["value": .integer(2)])]))
    state.nextEvent = 2
    throw Stop.expected
  }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  var original = Commander()
  let empty = try encoder.encode(original)
  let id = UUID()
  var instance = ScriptInstance(
    id: id, definition: "test.copy/story", version: "1.0.0",
    digest: String(repeating: "0", count: 64))
  instance.data = .object(["nested": .array([.integer(1)])])
  instance.timers["hold"] = .init(
    id: "hold", domain: .flight, due: 1, interval: 1, policy: .delay)
  original.scriptState.instances[id] = instance
  original.scriptState.pendingEvents.append(
    .init(
      sequence: 1, kind: "contact.requested", instance: id,
      values: ["nested": .object(["value": .integer(1)])]))
  original.scriptState.nextEvent = 1
  let retained = original
  let retainedBytes = try encoder.encode(original)
  var copy = original
  #expect(throws: Stop.self) { try change(&copy.scriptState, id: id) }
  #expect(original == retained && original.scriptState.instances[id] == instance)
  #expect(try encoder.encode(original) == retainedBytes)
  #expect(copy.scriptState.instances[id]?.data["nested"]?.array == [.integer(1), .integer(2)])
  #expect(copy.scriptState.instances[id]?.timers["hold"]?.pulses == 1)
  #expect(
    copy.scriptState.pendingEvents.count == 2 && original.scriptState.pendingEvents.count == 1)
  let changed = try encoder.encode(copy)
  #expect(try JSONDecoder().decode(Commander.self, from: changed) == copy)

  var game = Game(executive: false)
  game.commander = original
  let sibling = game
  #expect(throws: Stop.self) { try change(&game.commander.scriptState, id: id) }
  #expect(sibling.commander == retained && game.commander == copy)
  copy.scriptState.instances.removeAll()
  copy.scriptState.pendingEvents.removeAll()
  copy.scriptState.nextEvent = 0
  #expect(try encoder.encode(copy) == empty)
  #expect(try encoder.encode(original) == retainedBytes)
}

@Test(arguments: [false, true])
func courierScriptStateInoutRealChildAndEventAppendPreserveContextsAndSibling(nested: Bool) throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let campaign = try fixture.startContractCampaign(&game, nested: nested)
  #expect(game.commander.scriptState.instances[campaign.child]?.campaignParent != nil)
  let ids = game.orderedScriptInstances.filter {
    game.commander.scriptState.instances[$0]?.outcome == .active
  }
  #expect(ids.count == (nested ? 3 : 2))
  let contexts = Dictionary(
    uniqueKeysWithValues: ids.map { id in
      (id, game.scriptEventContext(game.commander.scriptState.instances[id]!))
    })
  let sibling = game
  let sequence = game.commander.scriptState.nextEvent
  let values: [String: ScriptValue] = ["marker": .integer(7)]
  game.emitScriptEvent("contact.requested", values: values, drain: false)
  let appended = game.commander.scriptState.pendingEvents.filter { $0.sequence > sequence }
  #expect(appended.map(\.instance) == ids)
  #expect(game.commander.scriptState.nextEvent == sequence + UInt64(ids.count))
  for (offset, event) in appended.enumerated() {
    #expect(event.sequence == sequence + UInt64(offset) + 1)
    #expect(event.kind == "contact.requested" && event.values == values)
    #expect(event.context == contexts[event.instance])
  }
  #expect(sibling.commander.scriptState.nextEvent == sequence)
  #expect(sibling.commander.scriptState.pendingEvents.allSatisfy { $0.sequence <= sequence })
  game.drainScriptEvents()
  #expect(game.commander.valid)
  #expect(sibling.commander.scriptState.nextEvent == sequence)
}
