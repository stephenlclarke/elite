import Foundation
import Testing

@testable import EliteCore

struct NativeIdentifiedSalvageSaveTests {
  @Test(arguments: [false, true], ["allocated", "one", "received", "hull-loss"])
  func independentlyGenuine51And52PreserveEachCustodyBoundary(alien: Bool, phase: String)
    async throws
  {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let state = try await f.accept(runtime)
    if phase != "allocated" {
      try await f.renas(runtime)
      try await f.collect(runtime, ordinal: 0)
    }
    if phase == "received" {
      try await f.collect(runtime, ordinal: 1)
      try await f.returnHome(runtime)
      try await f.confirm(runtime, .receive)
    }
    if phase == "hull-loss" {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.1)
    }
    var game = await runtime.snapshot()
    if alien {
      let owner = try #require(game.commander.equipmentOwnerID)
      try game.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: 0, world: [], sources: [], attachments: [],
          upgrades: [], receipts: [], commands: []))
    }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let url = f.files.root.appendingPathComponent("g09-custody/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 52 : 51))
    let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(NativeIdentifiedSalvageSave.validateClaims(cold, requireRecordedLoss: true))
    #expect(cold.scriptState.instances[state.permission.mission]?.savedIdentifiedSalvage != nil)
    #expect(NativeOriginalSurveySave.hasClaims(cold) == false)
    #expect(NativeOriginalEvacuationSave.hasClaims(cold) == false)
    #expect(NativeOriginalRescueJourneySave.hasClaims(cold) == false)
  }

  @Test(arguments: [false, true])
  func genuineG10ReadingComposesWithoutManufacturingAnotherPredecessor(alien: Bool) async throws {
    let f = try NativeIdentifiedSalvageFixture()
    let survey = try NativeOriginalSurveyFixture()
    defer {
      f.files.clean()
      survey.files.clean()
    }
    let runtime = try await f.runtime()
    await runtime.nativeCommand { $0.scriptPacks.append(survey.pack) }
    let surveyState = try await survey.board(runtime)
    let permission = try #require(surveyState.permission)
    _ = try await f.accept(runtime)
    try await f.renas(runtime)
    try await survey.view(runtime, ordinal: 0)
    try await f.collect(runtime, ordinal: 0)
    var game = await runtime.snapshot()
    if alien {
      let owner = try #require(game.commander.equipmentOwnerID)
      try game.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: 0, world: [], sources: [], attachments: [],
          upgrades: [], receipts: [], commands: []))
    }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let url = f.files.root.appendingPathComponent("g09-composed/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: url)
    let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(NativeIdentifiedSalvageSave.validateClaims(cold, requireRecordedLoss: true))
    #expect(NativeOriginalSurveySave.validateClaims(cold))
    #expect(
      cold.scriptState.instances[permission.mission]?.savedOriginalSurvey?.readings.count == 1)
    #expect(
      cold.scriptState.savedIdentifiedSalvageSource?.originals.filter {
        if case .held = $0.custody { return true }
        return false
      }.count == 1)
    #expect(NativeOriginalEvacuationSave.hasClaims(cold) == false)
  }

  @Test func genuineHistoricalToolStoragePreservesTheOriginalCaptureWitness() async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let state = try await f.accept(runtime)
    try await f.renas(runtime)
    try await f.collect(runtime, ordinal: 0)
    let capture = try #require(try await f.state(runtime).captures.first)
    try await f.returnHome(runtime)
    try await runtime.storeIdentifiedSalvageScoops()
    #expect(await runtime.snapshot().commander.fittedEquipment(at: .utility(.fuelScoops)) == nil)
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(
      cold.commander.scriptState.instances[state.permission.mission]?.savedIdentifiedSalvage?
        .captures == [capture])
    #expect(cold.identifiedSalvageState?.held.count == 1)
    #expect(cold.commander.fittedEquipment(at: .utility(.fuelScoops)) == nil)
    #expect(NativeIdentifiedSalvageSave.validateClaims(cold.commander, requireRecordedLoss: true))
  }

  @Test(arguments: ["stock", "capture", "receiving"])
  func rehashedSaveRefusesMissingForeignAndUnjoinedNativeEvidence(boundary: String) async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    if boundary != "stock" {
      try await f.renas(runtime)
      try await f.collect(runtime, ordinal: 0)
    }
    if boundary == "receiving" {
      try await f.collect(runtime, ordinal: 1)
      try await f.returnHome(runtime)
      try await f.confirm(runtime, .receive)
    }
    try await runtime.save(to: f.save)
    let pointerBytes = try Data(contentsOf: f.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let (pristine, world) = try ScriptSaveStore.read(pointerBytes, from: f.save)
    #expect(world.consistent(with: pristine))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    let file = directory.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    let object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    let normalized = try JSONSerialization.data(withJSONObject: object)
    for capture in try await f.state(runtime).captures {
      let encoded = try JSONEncoder().encode(capture)
      let json = try JSONSerialization.jsonObject(with: encoded)
      let equivalent = try JSONDecoder().decode(
        NativeIdentifiedSalvageCapture.self,
        from: JSONSerialization.data(withJSONObject: json))
      #expect(try NativeIdentifiedSalvage.captureAuthority(equivalent) == capture.authority)
    }
    #expect(
      try readIdentifiedRehash(normalized, pointer: pointer, file: file, save: f.save) == pristine)
    try original.write(to: file)
    let modes: [String]
    switch boundary {
    case "stock":
      modes = [
        "stock-stripped", "stock-null", "stock-duplicate", "stock-owner", "state-stripped", "older",
      ]
    case "capture":
      modes = [
        "capture-stripped", "capture-duplicate", "capture-foreign", "capture-grant", "slots",
        "stock-reverted", "flag", "older",
      ]
    default: modes = ["receive-duplicate", "receive-context", "receive-stock", "flag", "older"]
    }
    for mode in modes {
      var root = object
      var pairs = try #require(root["instances"] as? [Any])
      let index = try #require(
        stride(from: 1, to: pairs.count, by: 2).first {
          (pairs[$0] as? [String: Any])?["id"] as? String == accepted.permission.mission.uuidString
        })
      var instance = try #require(pairs[index] as? [String: Any])
      var state = try #require(instance["savedIdentifiedSalvage"] as? [String: Any])
      var source = try #require(root["savedIdentifiedSalvageSource"] as? [String: Any])
      var originals = try #require(source["originals"] as? [[String: Any]])
      if mode == "stock-stripped" { root.removeValue(forKey: "savedIdentifiedSalvageSource") }
      if mode == "stock-null" { root["savedIdentifiedSalvageSource"] = NSNull() }
      if mode == "stock-duplicate" { originals.append(originals[0]) }
      if mode == "stock-owner" {
        var owner = try #require(source["owner"] as? [String: Any])
        owner["world"] = UUID().uuidString
        source["owner"] = owner
      }
      if mode == "state-stripped" { instance.removeValue(forKey: "savedIdentifiedSalvage") }
      if mode == "capture-stripped" {
        state["captures"] = []
        instance["milestones"] = [0]
      }
      if mode == "capture-duplicate" || mode == "capture-foreign" || mode == "capture-grant" {
        var captures = try #require(state["captures"] as? [[String: Any]])
        if mode == "capture-duplicate" { captures.append(captures[0]) }
        if mode == "capture-foreign" { captures[0]["original"] = UUID().uuidString }
        if mode == "capture-grant" {
          var equipment = try #require(captures[0]["equipment"] as? [[String: Any]])
          equipment[2]["provenance"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(EquipmentAcquisitionProvenance.grant("forged")))
          captures[0]["equipment"] = equipment
          let forged = try JSONDecoder().decode(
            NativeIdentifiedSalvageCapture.self,
            from: JSONSerialization.data(withJSONObject: captures[0]))
          captures[0]["authority"] = try NativeIdentifiedSalvage.captureAuthority(forged).uuidString
        }
        state["captures"] = captures
      }
      if mode == "slots" { instance["payloads"] = ["pell-01": 2, "pell-02": 1] }
      if mode == "stock-reverted" {
        originals[0]["custody"] = try JSONSerialization.jsonObject(
          with: JSONEncoder().encode(NativeIdentifiedSalvageCustody.cradle))
      }
      if mode.hasPrefix("receive-") {
        var reception = try #require(state["reception"] as? [String: Any])
        if mode == "receive-duplicate" {
          let items = try #require(reception["originals"] as? [Any])
          reception["originals"] = [items[0], items[0]]
        }
        if mode == "receive-context" {
          let permission = try #require(state["permission"] as? [String: Any])
          var cause = try #require(reception["cause"] as? [String: Any])
          cause["nativeMainDock"] = permission["dock"]
          reception["cause"] = cause
        }
        if mode == "receive-stock" {
          originals[0]["custody"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(NativeIdentifiedSalvageCustody.returned(UUID())))
        }
        state["reception"] = reception
      }
      if mode == "flag" { state["collected"] = true }
      source["originals"] = originals
      if mode != "stock-stripped" && mode != "stock-null" {
        root["savedIdentifiedSalvageSource"] = source
      }
      if mode != "state-stripped" { instance["savedIdentifiedSalvage"] = state }
      pairs[index] = instance
      root["instances"] = pairs
      let bytes = try JSONSerialization.data(withJSONObject: root)
      #expect(throws: (any Error).self) {
        try readIdentifiedRehash(
          bytes, pointer: pointer, file: file, save: f.save,
          schema: mode == "older" ? 49 : 51)
      }
      try original.write(to: file)
    }
  }
}

extension GameRuntime {
  func storeIdentifiedSalvageScoops() throws {
    try scriptCommand { game in
      let inventory = try #require(game.commander.equipmentInventory)
      let item = try #require(game.commander.fittedEquipment(at: .utility(.fuelScoops)))
      try game.storeEquipment(item, expectedRevision: inventory.revision)
    }
  }
}

private func readIdentifiedRehash(
  _ bytes: Data, pointer: ScriptSavePointer, file: URL, save: URL, schema: Int? = nil
) throws -> Commander {
  try bytes.write(to: file)
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
  let changed = ScriptSavePointer(
    format: pointer.format, schemaVersion: schema ?? pointer.schemaVersion,
    generation: pointer.generation, hashes: hashes, scope: pointer.scope,
    valueCodec: pointer.valueCodec)
  return try ScriptSaveStore.read(JSONEncoder().encode(changed), from: save).0
}
