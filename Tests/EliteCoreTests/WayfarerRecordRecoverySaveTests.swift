import Foundation
import Testing

@testable import EliteCore

struct WayfarerRecordRecoverySaveTests {
  @Test(arguments: [false, true], ["allocated", "identified", "held", "failed", "received"])
  func independentlyGenuine53And54ColdReloadPreservesEveryCustodyBoundary(
    alien: Bool, phase: String
  )
    async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    if phase != "allocated" {
      try await f.celalen(runtime)
      try await f.identify(runtime)
    }
    if ["held", "failed", "received"].contains(phase) { try await f.collect(runtime) }
    if phase == "failed" {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.1)
    }
    if phase == "received" {
      try await f.returnHome(runtime)
      try await f.confirm(runtime, .receive)
    }
    var game = await runtime.snapshot()
    if alien { try attachRecordRecoveryAlien(&game) }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let url = f.files.root.appendingPathComponent("w05-cold/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 54 : 53))
    let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(WayfarerRecordRecoverySave.validateClaims(cold, requireRecordedLoss: true))
    #expect(cold.scriptState.instances[accepted.permission.mission]?.savedRecordRecovery != nil)
    #expect(!NativeIdentifiedSalvageSave.hasClaims(cold))
    #expect(!NativeOriginalSurveySave.hasClaims(cold))
    #expect(!NativeOriginalRescueJourneySave.hasClaims(cold))
  }

  @Test(arguments: [false, true])
  func genuineG09AndG10HistoryComposesWithIndependentW05AndAlien(alien: Bool) async throws {
    let f = try WayfarerRecordRecoveryFixture()
    let salvage = try NativeIdentifiedSalvageFixture()
    let survey = try NativeOriginalSurveyFixture()
    defer {
      f.files.clean()
      salvage.files.clean()
      survey.files.clean()
    }
    let runtime = try await salvage.runtime()
    await runtime.nativeCommand { $0.scriptPacks += [f.pack, survey.pack] }
    let g09 = try await salvage.accept(runtime)
    let g10 = try await survey.board(runtime)
    let g10Permission = try #require(g10.permission)
    try await salvage.renas(runtime)
    try await survey.view(runtime, ordinal: 0)
    try await salvage.collect(runtime, ordinal: 0)
    try await salvage.returnHome(runtime)
    await runtime.procurementRefuel()
    let current = await runtime.snapshot()
    let systems = current.systems
    let reach = ScriptCourierReach(current.commander)
    let adjacency = systems.indices.map { from in systems.indices.filter { $0 != from } }
    let path = try #require(
      NavigationRouteSearch.path(adjacency: adjacency, from: 7, to: 85) {
        from, to, first in
        systems[from].distance(to: systems[to]) <= (first ? reach.firstReach : reach.laterReach)
          ? 1 : nil
      })
    try await f.flight.travel(runtime, path: path)
    await runtime.procurementRefuel()
    let w05 = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.identify(runtime)
    try await f.collect(runtime)
    var game = await runtime.snapshot()
    if alien { try attachRecordRecoveryAlien(&game) }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let url = f.files.root.appendingPathComponent("w05-composed/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(WayfarerRecordRecoverySave.validateClaims(cold, requireRecordedLoss: true))
    #expect(NativeIdentifiedSalvageSave.validateClaims(cold, requireRecordedLoss: true))
    #expect(NativeOriginalSurveySave.validateClaims(cold))
    #expect(
      cold.scriptState.instances[g09.permission.mission]?.savedIdentifiedSalvage?.captures.count
        == 1)
    #expect(
      cold.scriptState.instances[g10Permission.mission]?.savedOriginalSurvey?.readings.count == 1)
    #expect(
      cold.scriptState.instances[w05.permission.mission]?.savedRecordRecovery?.held.count == 1)
    #expect(!NativeOriginalEvacuationSave.hasClaims(cold))
  }

  @Test func actualIdentificationSurvivesLaterRefitColdLoadAndNativeRebinding() async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.celalen(runtime)
    let receipt = try await f.identify(runtime)
    try await f.flight.dock(runtime)
    try await runtime.storeRecordRecoveryModule()
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(cold.recordRecoveryState?.identification == receipt)
    #expect(cold.recordRecoveryState?.captures.isEmpty == true)
    #expect(WayfarerRecordRecoverySave.validateClaims(cold.commander, requireRecordedLoss: true))
    #expect(cold.nativeRecordRecoveryIdentificationPending == nil)
    #expect(cold.nativeRecordRecoveryPending == nil)
  }

  @Test(arguments: ["allocated", "identified", "held", "received"])
  func normalizedPositiveColdSaveAndRehashedTamperingPreserveStrictOwnAuthority(phase: String)
    async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    if phase != "allocated" {
      try await f.celalen(runtime)
      try await f.identify(runtime)
    }
    if phase == "held" || phase == "received" { try await f.collect(runtime) }
    if phase == "received" {
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
    let positive = try readRecordRecoveryRehash(
      object, pointer: pointer, file: file, save: f.save, geometry: pristine.scriptState.geometry)
    #expect(positive == pristine)
    let modes =
      ["stock", "source-owner", "definition", "leaf", "slots", "flag", "older"]
      + (phase == "allocated"
        ? []
        : [
          "identification", "identify-foreign", "identify-interval", "identify-caller",
          "identify-duplicate", "identify-copied",
        ])
      + (["held", "received"].contains(phase)
        ? [
          "capture", "capture-foreign-id", "capture-same-frame", "capture-grant", "stock-reverted",
        ] : [])
      + (phase == "received" ? ["receive-duplicate", "receive-dock", "receive-stock"] : [])
    for mode in modes {
      var root = object
      var pairs = try #require(root["instances"] as? [Any])
      let index = try #require(
        stride(from: 1, to: pairs.count, by: 2).first {
          (pairs[$0] as? [String: Any])?["id"] as? String == accepted.permission.mission.uuidString
        })
      var instance = try #require(pairs[index] as? [String: Any])
      var state = try #require(instance["savedRecordRecovery"] as? [String: Any])
      var source = try #require(root["savedRecordRecoverySource"] as? [String: Any])
      var originals = try #require(source["originals"] as? [[String: Any]])
      if mode == "stock" { root.removeValue(forKey: "savedRecordRecoverySource") }
      if mode == "source-owner" {
        var owner = try #require(source["owner"] as? [String: Any])
        owner["world"] = UUID().uuidString
        source["owner"] = owner
      }
      if mode == "definition" { instance["definition"] = NativeIdentifiedSalvage.stateID }
      if mode == "leaf" { instance.removeValue(forKey: "savedRecordRecovery") }
      if mode == "slots" { instance["payloads"] = ["cdr-001": 2] }
      if mode == "flag" { state["identified"] = true }
      if mode == "identification" { state.removeValue(forKey: "identification") }
      if mode.hasPrefix("identify-") {
        var identification = try #require(state["identification"] as? [String: Any])
        if mode == "identify-foreign" { identification["original"] = UUID().uuidString }
        if mode == "identify-caller" { identification["observed"] = true }
        if mode == "identify-copied" {
          identification["permission"] = NativeIdentifiedSalvage.stateID
        }
        if mode == "identify-interval" || mode == "identify-duplicate" {
          var observations = try #require(identification["observations"] as? [[String: Any]])
          if mode == "identify-interval" {
            observations[1]["physicalTime"] = observations[0]["physicalTime"]
          } else {
            observations.append(observations[0])
          }
          identification["observations"] = observations
        }
        if mode == "identify-foreign" || mode == "identify-interval" {
          let forged = try JSONDecoder().decode(
            WayfarerRecordRecoveryIdentification.self,
            from: JSONSerialization.data(withJSONObject: identification))
          identification["authority"] = try WayfarerRecordRecovery.identificationAuthority(forged)
            .uuidString
        }
        state["identification"] = identification
      }
      if mode == "capture" { state["captures"] = [] }
      if mode.hasPrefix("capture-") {
        var captures = try #require(state["captures"] as? [[String: Any]])
        if mode == "capture-foreign-id" { captures[0]["identification"] = UUID().uuidString }
        if mode == "capture-same-frame" {
          let identification = try #require(state["identification"] as? [String: Any])
          let observations = try #require(identification["observations"] as? [[String: Any]])
          captures[0]["physicalTime"] = observations[1]["physicalTime"]
        }
        if mode == "capture-grant" {
          var equipment = try #require(captures[0]["equipment"] as? [[String: Any]])
          equipment[2]["provenance"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(EquipmentAcquisitionProvenance.grant("forged")))
          captures[0]["equipment"] = equipment
          let forged = try JSONDecoder().decode(
            WayfarerRecordRecoveryCapture.self,
            from: JSONSerialization.data(withJSONObject: captures[0]))
          captures[0]["authority"] = try WayfarerRecordRecovery.captureAuthority(forged).uuidString
        }
        if mode == "capture-foreign-id" || mode == "capture-same-frame" {
          let forged = try JSONDecoder().decode(
            WayfarerRecordRecoveryCapture.self,
            from: JSONSerialization.data(withJSONObject: captures[0]))
          captures[0]["authority"] = try WayfarerRecordRecovery.captureAuthority(forged).uuidString
        }
        state["captures"] = captures
      }
      if mode == "stock-reverted" {
        originals[0]["custody"] = try JSONSerialization.jsonObject(
          with: JSONEncoder().encode(WayfarerRecordRecoveryCustody.cradle))
      }
      if mode.hasPrefix("receive-") {
        var receipt = try #require(state["reception"] as? [String: Any])
        if mode == "receive-duplicate" {
          let items = try #require(receipt["originals"] as? [Any])
          receipt["originals"] = [items[0], items[0]]
        }
        if mode == "receive-dock" {
          let permission = try #require(state["permission"] as? [String: Any])
          var cause = try #require(receipt["cause"] as? [String: Any])
          cause["nativeMainDock"] = permission["dock"]
          receipt["cause"] = cause
        }
        if mode == "receive-stock" {
          originals[0]["custody"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(WayfarerRecordRecoveryCustody.returned(UUID())))
        }
        state["reception"] = receipt
      }
      source["originals"] = originals
      if mode != "stock" { root["savedRecordRecoverySource"] = source }
      if mode != "leaf" { instance["savedRecordRecovery"] = state }
      pairs[index] = instance
      root["instances"] = pairs
      #expect(throws: (any Error).self) {
        try readRecordRecoveryRehash(
          root, pointer: pointer, file: file, save: f.save, geometry: pristine.scriptState.geometry,
          schema: mode == "older" ? 51 : 53)
      }
    }
  }
}

private func attachRecordRecoveryAlien(_ game: inout Game) throws {
  let owner = try #require(game.commander.equipmentOwnerID)
  try game.commander.replaceAlienStorage(
    with: .init(
      owner: owner, revision: 0, worldRevision: 0, world: [], sources: [], attachments: [],
      upgrades: [],
      receipts: [], commands: []))
}

extension GameRuntime {
  func storeRecordRecoveryModule() throws {
    try scriptCommand { game in
      let inventory = try #require(game.commander.equipmentInventory)
      let item = try #require(game.commander.fittedEquipment(at: .targetingSalvage))
      try game.storeEquipment(item, expectedRevision: inventory.revision)
    }
  }
}

private func readRecordRecoveryRehash(
  _ object: [String: Any], pointer: ScriptSavePointer, file: URL, save: URL,
  geometry: [String: ShipDesign], schema: Int? = nil
) throws -> Commander {
  var root = object
  let hadGeometry = root.removeValue(forKey: "savedGeometry") != nil
  var bytes = try JSONSerialization.data(withJSONObject: root)
  if hadGeometry {
    try #require(bytes.last == 125 && !root.isEmpty)
    bytes.removeLast()
    bytes.append(contentsOf: Data(",\"savedGeometry\":".utf8))
    bytes.append(try JSONEncoder().encode(geometry))
    bytes.append(125)
  }
  try bytes.write(to: file)
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
  let changed = ScriptSavePointer(
    format: pointer.format, schemaVersion: schema ?? pointer.schemaVersion,
    generation: pointer.generation, hashes: hashes, scope: pointer.scope,
    valueCodec: pointer.valueCodec)
  return try ScriptSaveStore.read(JSONEncoder().encode(changed), from: save).0
}
