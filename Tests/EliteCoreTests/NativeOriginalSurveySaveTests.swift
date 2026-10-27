import Foundation
import Testing

@testable import EliteCore

struct NativeOriginalSurveySaveTests {
  @Test(arguments: ["grant", "standard"])
  func surveyHistoricalPaidEquipmentRejectsProvenanceReplacement(provenance: String) async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let permission = try #require(source.permission)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    try await runtime.save(to: f.save)
    let pointerBytes = try Data(contentsOf: f.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let (pristine, world) = try ScriptSaveStore.read(pointerBytes, from: f.save)
    let measured = try #require(
      pristine.scriptState.instances[permission.mission]?.savedOriginalSurvey)
    let authority = try #require(measured.authorities.first)
    let reading = try #require(measured.readings.first)
    guard case .paid = authority.equipment.provenance else {
      throw MissionPackError("The native fixture must use genuinely purchased targeting equipment.")
    }
    #expect(world.consistent(with: pristine))
    #expect(measured.readings.count == 1 && NativeOriginalSurveySave.validateClaims(pristine))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    let file = directory.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    let replacement: EquipmentAcquisitionProvenance =
      provenance == "grant" ? .grant("forged") : .standard
    let changedItem = EquipmentPurchaseItem(
      id: authority.equipment.id, node: authority.equipment.node,
      location: authority.equipment.location, provenance: replacement)
    let replacementJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(replacement))
    // First alter the witness alone, then rebind its seal too. Genuine paid acquisition
    // history must reject the second mismatch independently of the immutable reading seal.
    for rebind in [false, true] {
      let changedID = try NativeOriginalSurvey.authorityIdentity(
        operation: reading.operation, equipment: changedItem,
        inventoryRevision: reading.inventoryRevision, epoch: reading.epoch, actor: reading.actor)
      let bytes = try surveyMutatedMission(original, mission: permission.mission) { instance in
        var state = try #require(instance["savedOriginalSurvey"] as? [String: Any])
        var authorities = try #require(state["authorities"] as? [[String: Any]])
        var equipment = try #require(authorities[0]["equipment"] as? [String: Any])
        equipment["provenance"] = replacementJSON
        authorities[0]["equipment"] = equipment
        if rebind {
          authorities[0]["id"] = changedID.uuidString
          var readings = try #require(state["readings"] as? [[String: Any]])
          readings[0]["authority"] = changedID.uuidString
          state["readings"] = readings
        }
        state["authorities"] = authorities
        instance["savedOriginalSurvey"] = state
      }
      try NativeOriginalSurveySave.validateFields(bytes, part: .missions, schema: 49)
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: pointer.schemaVersion,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try original.write(to: file)
    }
  }

  @Test func surveyCompletedColdReadRejectsAnotherGenuineAvenorDock() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let permission = try #require(source.permission)
    try await f.renas(runtime)
    try await f.allViews(runtime)
    try await f.returnHome(runtime)
    try await f.confirm(runtime, .receive)
    let received = await runtime.snapshot()
    let originalDock = try #require(received.originalSurveyState?.terminalDock)
    try await runtime.save(to: f.save)
    let (completed, completedWorld) = try ScriptSaveStore.read(
      Data(contentsOf: f.save), from: f.save)
    #expect(completedWorld.consistent(with: completed))
    #expect(completed.scriptState.instances[permission.mission]?.outcome == .complete)
    #expect(NativeOriginalSurveySave.validateClaims(completed))

    await runtime.procurementRefuel()
    try await f.base.flight.travel(runtime, path: [7, 185])
    await runtime.procurementRefuel()
    try await f.base.flight.travel(runtime, path: [185, 7])
    let revisited = await runtime.snapshot()
    let otherDock = try #require(revisited.commander.nativeStations?.currentMainDock)
    try #require(otherDock != originalDock && otherDock.sequence > originalDock.sequence)
    #expect(revisited.originalSurveyState?.terminalDock == originalDock)
    try await runtime.save(to: f.save)
    let pointerBytes = try Data(contentsOf: f.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let (pristine, world) = try ScriptSaveStore.read(pointerBytes, from: f.save)
    #expect(world.consistent(with: pristine))
    #expect(pristine.credits == revisited.commander.credits)
    #expect(
      pristine.scriptState.instances[permission.mission]?.savedOriginalSurvey?.terminalDock
        == originalDock)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    let file = directory.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    let replacement = try JSONSerialization.jsonObject(with: JSONEncoder().encode(otherDock))
    let bytes = try surveyMutatedMission(original, mission: permission.mission) { instance in
      var state = try #require(instance["savedOriginalSurvey"] as? [String: Any])
      state["terminalDock"] = replacement
      instance["savedOriginalSurvey"] = state
    }
    try NativeOriginalSurveySave.validateFields(bytes, part: .missions, schema: 49)
    try bytes.write(to: file)
    var hashes = pointer.hashes
    hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
    let changed = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion,
      generation: pointer.generation, hashes: hashes, scope: pointer.scope,
      valueCodec: pointer.valueCodec)
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
    }
  }

  @Test func surveyRehashedMissionsRejectStrippedForeignAndForgedMeasurements() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let permission = try #require(source.permission)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    try await runtime.save(to: f.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: f.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    let file = directory.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    for mode in [
      "stripped", "null", "unknown", "duplicate", "ordinal", "marker", "family", "older",
    ] {
      var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
      var pairs = try #require(object["instances"] as? [Any])
      let index = try #require(
        stride(from: 1, to: pairs.count, by: 2).first {
          (pairs[$0] as? [String: Any])?["id"] as? String == permission.mission.uuidString
        })
      var instance = try #require(pairs[index] as? [String: Any])
      var state = try #require(instance["savedOriginalSurvey"] as? [String: Any])
      if mode == "stripped" { instance.removeValue(forKey: "savedOriginalSurvey") }
      if mode == "null" { instance["savedOriginalSurvey"] = NSNull() }
      if mode == "unknown" { state["partialSeconds"] = 12 }
      if mode == "family" { instance["definition"] = NativeOrbitalOutlookJourney.stateID }
      var readings = try #require(state["readings"] as? [[String: Any]])
      if mode == "duplicate" { readings.append(readings[0]) }
      if mode == "ordinal" { readings[0]["ordinal"] = 2 }
      if mode == "marker" { readings[0]["marker"] = UUID().uuidString }
      state["readings"] = readings
      if mode != "stripped" && mode != "null" { instance["savedOriginalSurvey"] = state }
      pairs[index] = instance
      object["instances"] = pairs
      let bytes = try JSONSerialization.data(withJSONObject: object)
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: mode == "older" ? 47 : 49,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try original.write(to: file)
    }
  }

  @Test(arguments: [false, true], [false, true])
  func surveyGenuine49And50ColdJoinsIndependentlyPreservePriorFamilies(alien: Bool, composed: Bool)
    async throws
  {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(cabins: composed ? 2 : 0, coexist: composed)
    if composed {
      _ = try await f.base.board(runtime)
      let supply = try ScriptPackLibrary.read(ScriptPackLibrary.bundledConsentedFreightDirectory)
      await runtime.nativeCommand { $0.scriptPacks.append(supply) }
      let key = try await runtime.generateContractBoard(packDigest: supply.digest)
      let offer = try #require(
        await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
      let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
      try #require(quote.allowed)
      _ = try await runtime.confirmContract(quote)
      try await f.base.flight.travel(runtime, path: [7, 185])
      await runtime.key("contacts-open")
      try await ScriptFreightFixture.confirm(runtime, all: true)
      try await f.base.confirm(runtime, .receive)
      await runtime.procurementRefuel()
      try await f.base.flight.travel(runtime, path: [185, 7])
    }
    let source = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    let permission = try #require(source.permission)
    var game = await runtime.snapshot()
    if alien {
      let owner = try #require(game.commander.equipmentOwnerID)
      try game.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: 0,
          world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
    }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let url = f.files.root.appendingPathComponent("survey-envelope/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander,
      world: prepared.game.scriptWorldSave, to: url)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 50 : 49))
    let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(
      cold.scriptState.instances[permission.mission]?.savedOriginalSurvey?.permission
        == source.permission)
    #expect(
      cold.scriptState.instances[permission.mission]?.savedOriginalSurvey?.readings.count == 1)
    #expect((cold.nativePeople?.stationJourney != nil) == composed)
    #expect((cold.scriptState.savedOriginalConsentedFreightSupply != nil) == composed)
    #expect(NativeOriginalSurveySave.validateClaims(cold))
    #expect(NativeStationPassengerJourneySave.validateClaims(cold))
    #expect(OriginalConsentedFreightSupplySave.validateClaims(cold))
  }

}

private func surveyMutatedMission(
  _ bytes: Data, mission: UUID, mutation: (inout [String: Any]) throws -> Void
) throws -> Data {
  var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  var pairs = try #require(object["instances"] as? [Any])
  let index = try #require(
    stride(from: 1, to: pairs.count, by: 2).first {
      (pairs[$0] as? [String: Any])?["id"] as? String == mission.uuidString
    })
  var instance = try #require(pairs[index] as? [String: Any])
  try mutation(&instance)
  pairs[index] = instance
  object["instances"] = pairs
  return try JSONSerialization.data(withJSONObject: object)
}
