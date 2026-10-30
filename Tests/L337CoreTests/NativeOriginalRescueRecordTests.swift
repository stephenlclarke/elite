import Foundation
import Testing

@testable import L337Core

struct NativeOriginalRescueRecordTests {
  @Test func rescueOrdinaryCargoCannotBecomeTheOriginalRecordOrARescuedPerson() async throws {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    try await f.launch(runtime)
    let before = await runtime.snapshot().commander
    await runtime.nativeCommand { game in
      let id = game.nextBodyID
      game.nextBodyID += 1
      game.bodies.append(.init(id: id, hull: .cargo, position: .init(0, -45, 55)))
      game.ensurePhysicalActors()
    }
    _ = await runtime.advance(delta: 0.05)
    let after = await runtime.snapshot().commander
    #expect(after.cargo[0] == before.cargo[0] + 1)
    #expect(after.nativePeople?.originalRescue?.record == nil)
    #expect(after.nativePeople?.admissions.isEmpty == true)
    #expect(after.credits == before.credits && after.scriptState.savedClueJournal == nil)
  }

  @Test(arguments: ["accept", "care", "request", "board", "receive", "cancel"])
  func rescueActualActionWriterRefusalPreservesCustodyCabinsCargoCashAndPriorFiles(stage: String)
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let action: NativeOriginalRescueAction
    if stage == "accept" {
      action = .accept
    } else {
      _ = try await f.accept(runtime)
      if stage == "care" || stage == "cancel" {
        try await f.collect(runtime, alias: "neri-capsule")
        try await f.flight.dock(runtime)
      } else {
        try await f.serialCare(runtime)
      }
      if stage == "board" || stage == "receive" { try await f.confirm(runtime, .request) }
      if stage == "receive" {
        try await f.confirm(runtime, .board)
        try await f.collect(runtime, alias: "emergency-record")
        try await f.celalen(runtime)
      }
      action = try #require(NativeOriginalRescueAction(rawValue: stage))
    }
    let page = try await NativePeopleTestFixture.review(runtime, row: .rescue(action))
    try #require(await runtime.snapshot().contractBoard.peopleQuote?.allowed == true)
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let saved = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("action-" + stage)
    await runtime.scriptPageKey("return", expected: page)
    let failed = await runtime.snapshot().commander
    #expect(failed == before)
    #expect(failed.nativePeople == before.nativePeople)
    #expect(failed.accommodation == before.accommodation && failed.cargo == before.cargo)
    #expect(
      failed.credits == before.credits
        && failed.scriptState.savedClueJournal == before.scriptState.savedClueJournal)
    try f.files.restoreWrites(blocked, files: saved)
    try await f.confirm(runtime, action)
    #expect(await runtime.snapshot().commander.valid)
    if stage == "receive" {
      #expect(await runtime.snapshot().commander.credits == before.credits + 10200)
    }
  }

  @Test func rescueAuthenticatedColdReaderRejectsStrippingForeignDuplicateAndForgedPhysicalJoins()
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    try await f.board(runtime)
    try await f.collect(runtime, alias: "emergency-record")
    let beforeSave = await runtime.snapshot()
    try await runtime.save(to: f.save)
    let (pristine, pristineWorld) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(pristine.valid && pristineWorld.valid && pristineWorld.consistent(with: pristine))
    #expect(NativeOriginalRescueJourneySave.validateClaims(pristine))
    #expect(pristine.nativePeople?.originalRescue != nil)
    #expect(pristine.nativePeople == beforeSave.commander.nativePeople)
    #expect(pristine.equipmentOwnerID == beforeSave.commander.equipmentOwnerID)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: f.save))
    #expect(pointer.schemaVersion == 45)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    let file = directory.appendingPathComponent("commander.json")
    let original = try Data(contentsOf: file)
    #expect(throws: SaveError.self) {
      try NativeStationPassengerJourneySave.validateFields(original, part: .commander, schema: 41)
    }
    defer { try? original.write(to: file) }
    for mode in [
      "stripped", "null", "unknown", "duplicate", "actor", "epoch", "inventory", "tool",
      "provenance", "record", "record-stripped",
      "boarding", "care", "older",
    ] {
      var root = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
      var custody = try #require(root["savedNativePeopleCustody"] as? [String: Any])
      var source = try #require(custody["originalRescue"] as? [String: Any])
      var captures = try #require(source["captures"] as? [[String: Any]])
      if mode == "stripped" { custody.removeValue(forKey: "originalRescue") }
      if mode == "null" { custody["originalRescue"] = NSNull() }
      if mode == "unknown" { source["consentAsserted"] = true }
      if mode == "duplicate" { captures.append(captures[0]) }
      if mode == "actor" {
        var actor = try #require(captures[0]["actor"] as? [String: Any])
        actor["entity"] = 1
        captures[0]["actor"] = actor
      }
      if mode == "epoch" { captures[0]["epoch"] = UUID().uuidString }
      if mode == "inventory" { captures[0]["inventoryRevision"] = 999999 }
      if mode == "tool" {
        var tool = try #require(captures[0]["tool"] as? [String: Any])
        tool["id"] = UUID().uuidString
        captures[0]["tool"] = tool
      }
      if mode == "provenance" {
        var tool = try #require(captures[0]["tool"] as? [String: Any])
        tool["provenance"] = try JSONSerialization.jsonObject(
          with: JSONEncoder().encode(EquipmentAcquisitionProvenance.xyzzy))
        captures[0]["tool"] = tool
      }
      if mode == "record" {
        var record = try #require(source["record"] as? [String: Any])
        record["logicalActor"] = captures[0]["logicalActor"]
        source["record"] = record
      }
      if mode == "record-stripped" { source.removeValue(forKey: "record") }
      if mode == "boarding" { source.removeValue(forKey: "boarding") }
      if mode == "care" { custody["transfers"] = [] }
      source["captures"] = captures
      if mode != "stripped" && mode != "null" { custody["originalRescue"] = source }
      root["savedNativePeopleCustody"] = custody
      let bytes = try JSONSerialization.data(withJSONObject: root)
      if ["actor", "epoch", "inventory", "tool", "provenance", "record", "record-stripped"]
        .contains(mode)
      {
        // Well-formed claims must reach semantic joins rather than fail basic field decoding.
        try NativeOriginalRescueJourneySave.validateFields(bytes, part: .commander, schema: 45)
      }
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes["commander.json"] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: mode == "older" ? 43 : 45,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try original.write(to: file)
    }
    let missionsFile = directory.appendingPathComponent("missions.json")
    let originalMissions = try Data(contentsOf: missionsFile)
    defer { try? originalMissions.write(to: missionsFile) }
    for mode in ["marker-stripped", "marker-wrong-operation", "marker-extra"] {
      var missions = try #require(
        JSONSerialization.jsonObject(with: originalMissions) as? [String: Any])
      var instances = try #require(missions["instances"] as? [Any])
      let index = try #require(
        instances.indices.first(where: { index in
          (instances[index] as? [String: Any])?["definition"] as? String
            == NativeOriginalRescueJourney.stateID
        }))
      var mission = try #require(instances[index] as? [String: Any])
      var receipts = try #require(mission["receipts"] as? [String])
      let originalKey = try #require(
        receipts.first(where: {
          $0.hasPrefix(NativeOriginalRescueJourney.recordCaptureReceiptPrefix)
        }))
      if mode != "marker-extra" { receipts.removeAll { $0 == originalKey } }
      if mode != "marker-stripped" {
        receipts.append(NativeOriginalRescueJourney.recordCaptureReceipt(UUID()))
      }
      mission["receipts"] = receipts
      instances[index] = mission
      missions["instances"] = instances
      let bytes = try JSONSerialization.data(withJSONObject: missions)
      try bytes.write(to: missionsFile)
      var hashes = pointer.hashes
      hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: 45,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try originalMissions.write(to: missionsFile)
    }
  }

  @Test func rescueRealHullLossClosesOriginalCustodyWithoutPaymentAndOccupiedCabinsRefuseEscape()
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(escapeReady: true)
    let source = try await f.accept(runtime)
    try await f.board(runtime)
    try await f.launch(runtime)
    let before = await runtime.snapshot().commander
    try #require(before.fittedEquipment(at: .utility(.escapePod)) != nil)
    await runtime.key("escape-pod")
    #expect(await runtime.snapshot().commander.nativePeople == before.nativePeople)
    try await runtime.supplyFatalHullHit()
    _ = await runtime.advance(delta: 0.05)
    let lost = await runtime.snapshot()
    #expect(lost.screen == .gameOver)
    #expect(lost.commander.scriptState.instances[source.mission]?.outcome == .failed)
    #expect(lost.commander.credits == before.credits)
    #expect(lost.commander.nativePeople?.held.isEmpty == true)
    #expect(lost.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(lost.commander.scriptState.savedClueJournal == nil)
  }

  @Test func rescueActualSourceReturnTransfersTheOriginalRecordWithBothPeopleWithoutMissionPay()
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.accept(runtime)
    try await f.board(runtime)
    try await f.collect(runtime, alias: "emergency-record")
    try await f.flight.dock(runtime)
    let before = await runtime.snapshot().commander
    try await f.confirm(runtime, .cancel)
    let cancelled = await runtime.snapshot()
    #expect(cancelled.commander.credits == before.credits)
    #expect(cancelled.commander.scriptState.instances[source.mission]?.outcome == .abandoned)
    #expect(
      cancelled.commander.nativePeople?.originalRescue?.recordReception?.dock
        == cancelled.commander.nativeStations?.currentMainDock)
    #expect(cancelled.commander.nativePeople?.held.isEmpty == true)
    #expect(cancelled.commander.cargoTonnes == before.cargoTonnes - 1)
    #expect(cancelled.commander.scriptState.savedClueJournal == nil)
    #expect(cancelled.commander.valid)
  }
}
