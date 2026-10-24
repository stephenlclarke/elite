import Foundation
import Testing

@testable import EliteCore

func supplyCurrentEnvelope(_ game: consuming Game, alien: Bool, root: URL) throws {
  var value = game
  if alien {
    let owner = try #require(value.commander.equipmentOwnerID)
    try value.commander.replaceAlienStorage(
      with: .init(
        owner: owner, revision: 0, worldRevision: 0,
        world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
  }
  let prepared = try GameRuntime.prepareNativeSaveState(value)
  let url = root.appendingPathComponent("supply-envelope-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url)
  let bytes = try Data(contentsOf: url)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == (alien ? 40 : 39))
  let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
  #expect(cold.scriptState == prepared.commander.scriptState && world.consistent(with: cold))
  #expect(OriginalConsentedFreightSupplySave.validateClaims(cold))
}

extension GameRuntime {
  /// The real player mesh need not intersect its origin axis. Aim at an actual native triangle.
  func supplyFatalHullHit() throws {
    let mesh = game.commander.playerMesh
    let triangles = mesh.faces.filter { face in
      face.count == 3
        && (mesh.vertices[face[1]] - mesh.vertices[face[0]])
          .cross(mesh.vertices[face[2]] - mesh.vertices[face[0]]).length > 1e-9
    }
    let selected = triangles.max { a, b in
      a.reduce(0.0) { $0 + mesh.vertices[$1].z } < b.reduce(0.0) { $0 + mesh.vertices[$1].z }
    }
    let face = try #require(selected)
    let a = mesh.vertices[face[0]]
    let b = mesh.vertices[face[1]]
    let c = mesh.vertices[face[2]]
    let target = (a + b + c) * (1.0 / 3)
    let centre = mesh.vertices.reduce(Vector3(0, 0, 0), +) * (1.0 / Double(mesh.vertices.count))
    var normal = (b - a).cross(c - a).unit
    if normal.dot(target - centre) < 0 { normal = normal * -1 }
    let distance = (mesh.vertices.map { ($0 - centre).length }.max() ?? 0) * 2 + 1000
    let emitter = target + normal * distance
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: emitter, hostile: true))
    game.ensurePhysicalActors()
    let owner = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
    let contact = try game.nearestMissionCollision(
      from: emitter, direction: normal * -1,
      range: distance + 1, radius: 0, excludingBodyIDs: [id], includePlayer: true)
    let hit = try #require(contact?.hit)
    try #require(hit.target == .player)
    let emitted = game.makeAttackOrigin(owner: owner)
    let origin = try #require(emitted)
    let damage = game.energy + game.frontShield + game.rearShield + 1
    let impact = game.applyCombatHit(hit, origin: origin, kind: .laser, damage: damage)
    try #require(impact != nil)
  }
}

struct OriginalConsentedFreightSupplyLifecycleTests {
  @Test func supplyReceiverWriterFailureRetainsSevenReceiptsStockCashAndClueThenRetries()
    async throws
  {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let id = try await f.accept(runtime)
    try await f.partialSeven(runtime, id: id)
    await runtime.key("contacts-open")
    let ready = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("supply-receiver")
    try await ScriptFreightFixture.confirm(runtime)
    #expect(await runtime.snapshot().commander == ready.commander)
    try f.files.restoreWrites(held, files: files)
    await runtime.key("return")
    let done = await runtime.snapshot()
    #expect(done.commander.scriptState.instances[id]?.outcome == .complete)
    #expect(done.commander.credits == ready.commander.credits + 7300)
    #expect(done.commander.scriptState.savedClueJournal?.awards.count == 1)
    #expect(
      done.commander.scriptState.savedOriginalConsentedFreightSupply
        == ready.commander.scriptState.savedOriginalConsentedFreightSupply)
    try supplyCurrentEnvelope(done, alien: false, root: f.files.root)
  }

  @Test func supplyActualAbandonmentNeverRestocksOriginalAllocation() async throws {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let id = try await f.accept(runtime)
    let before = await runtime.snapshot()
    await runtime.key("contacts-open")
    try #require(await runtime.snapshot().scriptPresentedDialogue?.id == "freight-abandon")
    try await ScriptFreightFixture.confirm(runtime)
    let done = await runtime.snapshot()
    #expect(
      done.commander.scriptState.instances[id]?.outcome == .abandoned
        && done.commander.credits == before.commander.credits)
    #expect(try f.stock(done).remaining.count == 8)
    #expect(
      done.commander.scriptState.savedOriginalConsentedFreightSupply
        == before.commander.scriptState.savedOriginalConsentedFreightSupply)
    #expect(done.commander.scriptState.savedClueJournal == nil)
    try supplyCurrentEnvelope(done, alien: false, root: f.files.root)
  }

  @Test(arguments: [false, true])
  func supplyActualFatalOrEscapeLossNeverReplenishesBatch(escape: Bool) async throws {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(escapeReady: escape)
    let id = try await f.accept(runtime)
    let before = await runtime.snapshot()
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    let launched = await runtime.snapshot()
    try #require(!launched.docked && launched.screen.isFlight)
    if escape {
      await runtime.key("escape-pod")
    } else {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.1)
    }
    let lost = await runtime.snapshot()
    let state = try #require(lost.commander.scriptState.instances[id])
    #expect(state.outcome == .failed && state.contract?.settlementAmount == 0)
    #expect(state.savedOwnedCargo?.terminal?.removed.count == 8)
    #expect(
      lost.commander.scriptState.savedOriginalConsentedFreightSupply
        == before.commander.scriptState.savedOriginalConsentedFreightSupply)
    #expect(lost.commander.scriptState.savedClueJournal == nil)
    try supplyCurrentEnvelope(lost, alien: false, root: f.files.root)
  }

  @Test(arguments: [false, true])
  func supplyCurrentNormalAndAlienColdReloadPreservesPartialOriginalUnitJoins(alien: Bool)
    async throws
  {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let id = try await f.accept(runtime)
    try await f.partialSeven(runtime, id: id)
    let partial = await runtime.snapshot()
    try supplyCurrentEnvelope(partial, alien: alien, root: f.files.root)
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander == partial.commander)
    try await f.receive(runtime)
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  }

  @Test func supplyClosedCurrentEnvelopeRejectsStrippedNullUnknownAndOlderStockClaims() async throws
  {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: f.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    let file = directory.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    for mode in ["stripped", "null", "unknown", "older"] {
      let raw = try JSONSerialization.jsonObject(with: original)
      var object = try #require(raw as? [String: Any])
      if mode == "stripped" { object.removeValue(forKey: OriginalConsentedFreightSupplySave.field) }
      if mode == "null" { object[OriginalConsentedFreightSupplySave.field] = NSNull() }
      if mode == "unknown" {
        var stock = try #require(object[OriginalConsentedFreightSupplySave.field] as? [String: Any])
        stock["restock"] = 16
        object[OriginalConsentedFreightSupplySave.field] = stock
      }
      let bytes = try JSONSerialization.data(withJSONObject: object)
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: mode == "older" ? 29 : 39,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try original.write(to: file)
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": [OriginalConsentedFreightSupplySave.field: [:]]
    ])
    #expect(throws: (any Error).self) {
      try OriginalConsentedFreightSupplySave.validateFields(embedded, part: .commander, schema: 39)
    }
  }

  @Test func supplyDefaultDiscoveryBoardBackAndProductionCluePinAreActual() async throws {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(defaults: true)
    await runtime.key("contracts-open")
    let board = await runtime.snapshot().contractBoard
    let index = try #require(
      board.rows.firstIndex { $0.board.hasPrefix(f.pack.digest + "/") && $0.offer != nil })
    for _ in 0..<abs(index - board.selection) {
      await runtime.key(index < board.selection ? "up" : "down")
    }
    await runtime.key("return")
    let shown = await runtime.snapshot()
    let detail = Display.contractDetailRows(shown, width: shown.viewportWidth).joined(
      separator: "\n")
    #expect(
      detail.contains("730") && detail.contains("untimed") && shown.contractBoard.action == .back)
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == shown.commander)
    #expect(
      shown.commander.scriptState.savedOriginalConsentedFreightSupply == nil
        && shown.commander.scriptState.savedClueJournal == nil)
    let id = try await f.accept(runtime)
    try await f.receiver(runtime, id: id)
    try await f.receive(runtime, all: true)
    let done = await runtime.snapshot()
    let receipt = try #require(done.commander.scriptState.instances[id]?.completionReceipt)
    #expect(
      ScriptClueTrustCatalog.production.pin(for: receipt)?.sourceID
        == OriginalConsentedFreightSupply.stateID)
    #expect(
      done.commander.scriptState.savedClueJournal?.awards[OriginalConsentedFreightSupply.stateID]?
        .clueID == "consented-freight-family-trace")
  }
}
