import Foundation
import Testing

@testable import EliteCore

struct NativeMeasuredExtractionSaveTests {
  @Test(
    arguments: [false, true], ["allocated", "extracted", "held", "processed", "received", "failed"])
  func genuine55And56ColdReloadPreservesEachNativeBoundary(alien: Bool, phase: String) async throws
  {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    if phase != "allocated" { try await f.extract(runtime) }
    if ["held", "processed", "received", "failed"].contains(phase) { try await f.collect(runtime) }
    if ["processed", "received"].contains(phase) {
      try await f.renas(runtime)
      try await f.confirm(runtime, .process)
    }
    if phase == "received" { try await f.confirm(runtime, .receive) }
    if phase == "failed" {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.05)
    }
    var game = await runtime.snapshot()
    if alien { try measuredAlien(&game) }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let save = f.files.root.appendingPathComponent("g12-cold/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: save)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 56 : 55))
    let (cold, world) = try ScriptSaveStore.read(bytes, from: save)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(NativeMeasuredExtractionSave.validateClaims(cold, requireRecordedLoss: true))
    #expect(
      !WayfarerRecordRecoverySave.hasClaims(cold) && !NativeIdentifiedSalvageSave.hasClaims(cold))
    #expect(!NativeOriginalSurveySave.hasClaims(cold))
  }

  @Test(arguments: [false, true])
  func genuineW05G09G10PermissionsComposeUnderOwnEnvelopeWithoutFabricatedHistory(alien: Bool)
    async throws
  {
    let f = try NativeMeasuredExtractionFixture()
    let w05 = try WayfarerRecordRecoveryFixture()
    let g09 = try NativeIdentifiedSalvageFixture()
    let g10 = try NativeOriginalSurveyFixture()
    defer {
      f.files.clean()
      w05.files.clean()
      g09.files.clean()
      g10.files.clean()
    }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.extract(runtime)
    try await f.collect(runtime)
    try await f.renas(runtime)
    try await f.confirm(runtime, .process)
    try await f.confirm(runtime, .receive)
    await runtime.procurementRefuel()
    try await f.flight.travel(runtime, path: [185, 7])
    await runtime.procurementRefuel()
    await runtime.nativeCommand { $0.scriptPacks += [w05.pack, g09.pack, g10.pack] }
    let salvage = try await g09.accept(runtime)
    let survey = try await g10.board(runtime)
    let current = await runtime.snapshot()
    let systems = current.systems
    let reach = ScriptCourierReach(current.commander)
    let adjacency = systems.indices.map { from in systems.indices.filter { $0 != from } }
    let path = try #require(
      NavigationRouteSearch.path(adjacency: adjacency, from: 7, to: 85) { from, to, first in
        systems[from].distance(to: systems[to]) <= (first ? reach.firstReach : reach.laterReach)
          ? 1 : nil
      })
    try await f.flight.travel(runtime, path: path)
    await runtime.procurementRefuel()
    let recovery = try await w05.accept(runtime)
    var game = await runtime.snapshot()
    if alien { try measuredAlien(&game) }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let save = f.files.root.appendingPathComponent("g12-composed/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: save)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 56 : 55))
    let (cold, world) = try ScriptSaveStore.read(bytes, from: save)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(NativeMeasuredExtractionSave.validateClaims(cold, requireRecordedLoss: true))
    #expect(WayfarerRecordRecoverySave.validateClaims(cold, requireRecordedLoss: true))
    #expect(NativeIdentifiedSalvageSave.validateClaims(cold, requireRecordedLoss: true))
    #expect(NativeOriginalSurveySave.validateClaims(cold))
    #expect(cold.scriptState.instances[salvage.permission.mission]?.savedIdentifiedSalvage != nil)
    let surveyPermission = try #require(survey.permission)
    #expect(cold.scriptState.instances[surveyPermission.mission]?.savedOriginalSurvey != nil)
    #expect(cold.scriptState.instances[recovery.permission.mission]?.savedRecordRecovery != nil)
  }

  @Test(arguments: ["allocated", "held", "processed", "received"])
  func normalizedPositiveSaveAndRehashedMutationRefuseBrokenOwnProvenance(phase: String)
    async throws
  {
    var stage = "fixture"
    do {
      let f = try NativeMeasuredExtractionFixture()
      defer { f.files.clean() }
      stage = "runtime"
      let runtime = try await f.runtime()
      stage = "accept"
      try await f.accept(runtime)
      if phase != "allocated" {
        stage = "extract"
        try await f.extract(runtime)
        stage = "collect"
        try await f.collect(runtime)
      }
      if ["processed", "received"].contains(phase) {
        stage = "travel"
        try await f.renas(runtime)
        stage = "process"
        try await f.confirm(runtime, .process)
      }
      if phase == "received" {
        stage = "receive"
        try await f.confirm(runtime, .receive)
      }
      let state = try await f.state(runtime)
      stage = "save"
      try await runtime.save(to: f.save)
      let bytes = try Data(contentsOf: f.save)
      let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
      stage = "pristine-read"
      let (pristine, _) = try ScriptSaveStore.read(bytes, from: f.save)
      let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
      let file = directory.appendingPathComponent("missions.json")
      let original = try Data(contentsOf: file)
      defer { try? original.write(to: file) }
      let object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
      stage = "positive-rehash"
      #expect(
        try measuredReadRehash(
          object, pointer: pointer, file: file, save: f.save,
          geometry: pristine.scriptState.geometry, diagnostic: pristine)
          == pristine)
      var modes = [
        "source", "leaf", "slots", "owner", "original", "unknown", "older-normal", "older-alien",
      ]
      if phase != "allocated" { modes += ["witness", "capture", "fragment", "copied"] }
      if ["processed", "received"].contains(phase) { modes += ["mass", "input", "product"] }
      if phase == "received" { modes += ["receiver", "raw-delivery"] }
      for mode in modes {
        stage = "forgery-" + mode
        var root = object
        var pairs = try #require(root["instances"] as? [Any])
        let index = try #require(
          stride(from: 1, to: pairs.count, by: 2).first {
            (pairs[$0] as? [String: Any])?["id"] as? String == state.permission.mission.uuidString
          })
        var instance = try #require(pairs[index] as? [String: Any])
        var leaf = try #require(instance["savedMeasuredExtraction"] as? [String: Any])
        var source = try #require(root["savedMeasuredExtractionSource"] as? [String: Any])
        if mode == "source" { root.removeValue(forKey: "savedMeasuredExtractionSource") }
        if mode == "leaf" { instance.removeValue(forKey: "savedMeasuredExtraction") }
        if mode == "slots" { instance["payloads"] = ["input-0": 24] }
        if mode == "owner" { source["id"] = UUID().uuidString }
        if mode == "original" {
          var originals = try #require(source["originals"] as? [[String: Any]])
          originals[0]["id"] = UUID().uuidString
          source["originals"] = originals
        }
        if mode == "unknown" { leaf["refined"] = true }
        if mode == "witness" { leaf.removeValue(forKey: "extraction") }
        if mode == "capture" { leaf["captures"] = [] }
        if mode == "fragment" || mode == "copied" {
          var captures = try #require(leaf["captures"] as? [[String: Any]])
          if mode == "fragment" {
            captures[0]["original"] = UUID().uuidString
          } else {
            captures[0]["permission"] = NativeIdentifiedSalvage.stateID
          }
          leaf["captures"] = captures
        }
        if ["mass", "input", "product"].contains(mode) {
          var processing = try #require(leaf["processing"] as? [String: Any])
          var products = try #require(processing["products"] as? [[String: Any]])
          if mode == "mass" { products[0]["massKg"] = 2000 }
          if mode == "input" { products[0]["input"] = UUID().uuidString }
          if mode == "product" { products[0]["id"] = products[1]["id"] }
          processing["products"] = products
          leaf["processing"] = processing
        }
        if mode == "receiver" || mode == "raw-delivery" {
          var receipt = try #require(leaf["reception"] as? [String: Any])
          if mode == "receiver" {
            let permission = try #require(leaf["permission"] as? [String: Any])
            receipt["dock"] = permission["dock"]
          } else {
            receipt["products"] = []
          }
          leaf["reception"] = receipt
        }
        if mode != "source" { root["savedMeasuredExtractionSource"] = source }
        if mode != "leaf" { instance["savedMeasuredExtraction"] = leaf }
        pairs[index] = instance
        root["instances"] = pairs
        #expect(throws: (any Error).self) {
          try measuredReadRehash(
            root, pointer: pointer, file: file, save: f.save,
            geometry: pristine.scriptState.geometry,
            schema: mode == "older-normal" ? 53 : mode == "older-alien" ? 54 : 55)
        }
      }
    } catch {
      FileHandle.standardError.write(
        Data(
          "G12 positive phase=\(phase) stage=\(stage) error=\(String(reflecting: type(of: error)))\n"
            .utf8))
      throw error
    }
  }
}

private func measuredAlien(_ game: inout Game) throws {
  let owner = try #require(game.commander.equipmentOwnerID)
  try game.commander.replaceAlienStorage(
    with: .init(
      owner: owner, revision: 0, worldRevision: 0,
      world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
}

private func measuredReadRehash(
  _ object: [String: Any], pointer: ScriptSavePointer, file: URL,
  save: URL, geometry: [String: ShipDesign], schema: Int? = nil, diagnostic: Commander? = nil
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
  do {
    return try ScriptSaveStore.read(JSONEncoder().encode(changed), from: save).0
  } catch {
    if let diagnostic { measuredPositiveFailure(bytes, pointer: changed, original: diagnostic) }
    throw error
  }
}

private func measuredPositiveFailure(_ bytes: Data, pointer: ScriptSavePointer, original: Commander)
{
  let rawFieldsPass: Bool
  do {
    try NativeMeasuredExtractionSave.validateFields(
      bytes, part: .missions, schema: pointer.schemaVersion)
    rawFieldsPass = true
  } catch { rawFieldsPass = false }
  let decoder = ScriptValueStorage.decoder(typed: pointer.valueCodec == ScriptValueStorage.codec)
  decoder.userInfo[LegacyMissionEncounterProvenance.storageKey] = true
  let decoded = try? decoder.decode(ScriptEngineState.self, from: bytes)
  var facts = "rawFieldsPass=\(rawFieldsPass) typedDecodePass=\(decoded != nil)"
  if let decoded {
    let leaf = decoded.instances.values.compactMap(\.savedMeasuredExtraction).first
    let witnessMatches = leaf?.extraction.map {
      (try? NativeMeasuredExtraction.extractionAuthority($0)) == $0.authority
    }
    let firstBadIntake = leaf?.captures.firstIndex {
      (try? NativeMeasuredExtraction.intakeAuthority($0)) != $0.authority
    }
    if let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
      if let source = decoded.savedMeasuredExtractionSource,
        let raw = root["savedMeasuredExtractionSource"],
        let canonical = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(source))
      {
        facts += " sourceCanonicalDifference=\(measuredRawDifference(raw, canonical) ?? "none")"
      }
      if let leaf,
        let instances = root["instances"] as? [Any],
        let raw = instances.compactMap({ $0 as? [String: Any] })
          .compactMap({ $0["savedMeasuredExtraction"] }).first,
        let canonical = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(leaf))
      {
        facts += " stateCanonicalDifference=\(measuredRawDifference(raw, canonical) ?? "none")"
        if let rawState = raw as? [String: Any],
          let extraction = rawState["extraction"] as? [String: Any]
        {
          facts +=
            " bodyCount=\((extraction["body"] as? [Any])?.count ?? -1) emittedCount=\((extraction["emitted"] as? [Any])?.count ?? -1) equipmentCount=\((extraction["equipment"] as? [Any])?.count ?? -1)"
        }
      }
    }
    var candidate = original
    candidate.scriptState = decoded
    facts +=
      " sourceStateEqual=\(decoded.savedMeasuredExtractionSource == original.scriptState.savedMeasuredExtractionSource) witnessAuthorityMatch=\(String(describing: witnessMatches)) firstBadIntakeAuthorityIndex=\(String(describing: firstBadIntake)) measuredClaimsPass=\(NativeMeasuredExtractionSave.validateClaims(candidate, requireRecordedLoss: true))"
  }
  FileHandle.standardError.write(Data("G12 positive-rehash \(facts)\n".utf8))
}

extension NativeMeasuredExtractionSaveTests {
  @Test func actualMovingOriginalIntakePreservesIssuedIdentityAndAmount() async throws {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.extract(runtime)
    let extracted = await runtime.snapshot()
    let ordinaryCargo = extracted.commander.cargo
    // Use real elapsed native motion; never replace the source, payload or its velocity.
    _ = await runtime.advance(delta: 0.05)
    try await f.collect(runtime, count: 1)
    let collected = await runtime.snapshot()
    let state = try #require(collected.measuredExtractionState)
    let source = try #require(collected.commander.scriptState.savedMeasuredExtractionSource)
    let extraction = try #require(state.extraction)
    let intake = try #require(state.captures.first)
    let issued = try #require(extraction.emitted.first { $0.identity == intake.payload.identity })
    #expect(intake.payload.identity == issued.identity && intake.payload.amount == issued.amount)
    #expect(intake.payload.position != issued.position)
    #expect(intake.payload.position.finite && intake.payload.velocity.finite)
    #expect(
      NativeMeasuredExtractionSave.intakeValid(
        intake, source: source, state: state, commander: collected.commander))
    #expect(
      NativeMeasuredExtractionSave.validateClaims(collected.commander, requireRecordedLoss: true))
    #expect(collected.commander.cargo == ordinaryCargo)

    func reauthorized(_ payload: TypedCargoPayload) throws -> MeasuredIntake {
      var changed = MeasuredIntake(
        operation: intake.operation, permission: intake.permission, extraction: intake.extraction,
        original: intake.original, payload: payload, body: intake.body,
        player: intake.player, carrier: intake.carrier, inventoryRevision: intake.inventoryRevision,
        scoops: intake.scoops, relativeSpeed: intake.relativeSpeed,
        physicalTime: intake.physicalTime,
        epoch: intake.epoch, authority: intake.authority)
      changed.authority = try NativeMeasuredExtraction.intakeAuthority(changed)
      return changed
    }
    let forgeries: [TypedCargoPayload] = [
      .init(
        identity: .ore(NativeMeasuredExtraction.root, fragment: 12), amount: intake.payload.amount,
        position: intake.payload.position, velocity: intake.payload.velocity),
      .init(
        identity: intake.payload.identity, amount: .init(commodity: .minerals, quantity: 2),
        position: intake.payload.position, velocity: intake.payload.velocity),
      .init(
        identity: intake.payload.identity, amount: .init(commodity: .food, quantity: 1),
        position: intake.payload.position, velocity: intake.payload.velocity),
    ]
    for payload in forgeries {
      let changed = try reauthorized(payload)
      #expect(
        !NativeMeasuredExtractionSave.intakeValid(
          changed, source: source, state: state, commander: collected.commander))
    }
  }
}

// Report only the first raw canonical mismatch. This does not change validation or saved bytes.
private func measuredRawDifference(_ raw: Any, _ canonical: Any, path: String = "$", depth: Int = 0)
  -> String?
{
  guard depth < 32 else { return path + ":depth" }
  if let left = raw as? [String: Any], let right = canonical as? [String: Any] {
    for key in Set(left.keys).union(right.keys).sorted() {
      guard let a = left[key], let b = right[key] else { return path + "." + key + ":key" }
      if let difference = measuredRawDifference(a, b, path: path + "." + key, depth: depth + 1) {
        return difference
      }
    }
    return nil
  }
  if let left = raw as? [Any], let right = canonical as? [Any] {
    guard left.count == right.count else { return path + ":count" }
    for index in left.indices {
      if let difference = measuredRawDifference(
        left[index], right[index], path: path + "[\(index)]", depth: depth + 1)
      {
        return difference
      }
    }
    return nil
  }
  if NSDictionary(dictionary: ["value": raw]).isEqual(["value": canonical]) { return nil }
  return path + ":" + String(String(describing: raw).prefix(80))
    + "/" + String(String(describing: canonical).prefix(80))
}
