import Foundation
import Testing

@testable import L337Core

struct WayfarerSeedTransferNativeFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack
  var save: URL { files.save }
  init(shortExpiry: Bool = false) throws {
    files = try ScriptFreightFixture()
    if shortExpiry {
      let folder = files.root.appendingPathComponent("short-seed-expiry")
      try FileManager.default.copyItem(
        at: ScriptPackLibrary.bundledSeedTransferDirectory, to: folder)
      let manifest = folder.appendingPathComponent("manifest.toml")
      let text = try String(contentsOf: manifest, encoding: .utf8)
        .replacingOccurrences(of: "flightAllowance = 2700", with: "flightAllowance = 0.2")
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      pack = try ScriptPackLibrary.read(folder)
    } else {
      pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledSeedTransferDirectory)
    }
  }
  func runtime(escapeReady: Bool = false, mixedServices: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame(escapeReady: escapeReady)
    try game.prepareG03FlightEquipment()
    if escapeReady {
      let pod = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(pod)
      try #require(try game.applyEquipmentPurchase(quote))
    }
    // Initial controlled world selection precedes launch; only native flight establishes this dock.
    game.commander.system = 241
    game.selectedSystem = 241
    game.market = MarketItem.at(game.currentSystem)
    game.scriptPacks = [pack]
    if mixedServices {
      game.scriptPacks += [
        try ScriptPackLibrary.read(ScriptPackLibrary.bundledColdChainDirectory),
        try ScriptPackLibrary.read(ScriptPackLibrary.bundledRepairLoopDirectory),
      ]
    }
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    return runtime
  }
  func arrive(_ runtime: GameRuntime, path: [Int]) async throws {
    let before = await runtime.snapshot()
    if before.screen == .contracts {
      if before.contractBoard.detail { await runtime.key("escape") }
      await runtime.key("escape")
    }
    try await ScriptProcurementFixture.travel(runtime, path: path, verifyDeparture: true)
  }
  func pickup(_ runtime: GameRuntime) async throws -> (UUID, WayfarerColdChainOffer) {
    let source = try await runtime.initializeWayfarerColdChainStock(packDigest: pack.digest)
    let quote = try await runtime.wayfarerColdChainQuote(sourceID: source)
    return (
      try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id), quote
    )
  }
  func receive(_ runtime: GameRuntime, id: UUID) async throws {
    try await runtime.confirmWayfarerColdChainObjective(instance: id)
    try await runtime.receiveWayfarerColdChain(instance: id)
  }
  func rejectMissionsChange(_ change: (inout [String: Any]) throws -> Void) throws {
    let originalPointer = try Data(contentsOf: save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let folder = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
    let file = folder.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer {
      try? original.write(to: file)
      try? originalPointer.write(to: save)
    }
    var raw = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    try change(&raw)
    let changed = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
    try changed.write(to: file)
    var hashes = pointer.hashes
    hashes["missions.json"] = ScriptPackLibrary.hash(changed)
    let updated = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion,
      generation: pointer.generation, hashes: hashes, scope: pointer.scope,
      valueCodec: pointer.valueCodec)
    try JSONEncoder().encode(updated).write(to: save)
    #expect(throws: (any Error).self) {
      _ = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
    }
  }
}

private func seedMutateInstance(
  _ id: UUID, raw: inout [String: Any], change: (inout [String: Any]) throws -> Void
) throws {
  if var values = raw["instances"] as? [String: Any] {
    let key = try #require(values.keys.first { UUID(uuidString: $0) == id })
    var state = try #require(values[key] as? [String: Any])
    try change(&state)
    values[key] = state
    raw["instances"] = values
  } else {
    var values = try #require(raw["instances"] as? [Any])
    let index = try #require(
      stride(from: 0, to: values.count, by: 2).first {
        (values[$0] as? String).flatMap(UUID.init(uuidString:)) == id
      })
    var state = try #require(values[index + 1] as? [String: Any])
    try change(&state)
    values[index + 1] = state
    raw["instances"] = values
  }
}
private func seedCurrentEnvelopes(_ game: consuming Game, root: URL) throws {
  let prepared = try GameRuntime.prepareNativeSaveState(game)
  let normal = root.appendingPathComponent("seed-normal-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: normal)
  let bytes = try Data(contentsOf: normal)
  #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: bytes).schemaVersion == 37)
  let (loaded, world) = try ScriptSaveStore.read(bytes, from: normal)
  #expect(
    world.consistent(with: loaded) && WayfarerColdChainSave.validateClaims(loaded)
      && WayfarerRepairLoopSave.validateClaims(loaded))
  #expect(
    loaded.scriptState.savedWayfarerColdChainStock
      == prepared.commander.scriptState.savedWayfarerColdChainStock)
  #expect(
    loaded.scriptState.savedWayfarerRepairLoopStock
      == prepared.commander.scriptState.savedWayfarerRepairLoopStock)
  var alien = game
  let owner = try #require(alien.commander.equipmentOwnerID)
  // Empty Alien storage tests current envelope composition, never acquisition authority.
  try alien.commander.replaceAlienStorage(
    with: .init(
      owner: owner, revision: 0, worldRevision: 0,
      world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
  let adapted = try GameRuntime.prepareNativeSaveState(alien)
  let url = root.appendingPathComponent("seed-alien-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: adapted.commander, world: adapted.game.scriptWorldSave, to: url)
  let alienBytes = try Data(contentsOf: url)
  #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: alienBytes).schemaVersion == 38)
  let (cold, coldWorld) = try ScriptSaveStore.read(alienBytes, from: url)
  #expect(cold.usesAlienStorageSaveVersion && coldWorld.consistent(with: cold))
  #expect(
    cold.scriptState.savedWayfarerColdChainStock
      == adapted.commander.scriptState.savedWayfarerColdChainStock)
  #expect(
    cold.scriptState.savedWayfarerRepairLoopStock
      == adapted.commander.scriptState.savedWayfarerRepairLoopStock)
}

struct WayfarerSeedTransferNativeTests {
  @Test func nativeSeedReleaseRequiresNamedCustodianAndProtectsExactlyThreeTonnes() async throws {
    let fixture = try WayfarerSeedTransferNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let source = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
    let before = await runtime.snapshot()
    let stock = try #require(
      before.commander.scriptState.savedWayfarerColdChainStock?.sources[source])
    #expect(stock.units.count == 6 && stock.definition.isSeedTransfer)
    let (id, quote) = try await fixture.pickup(runtime)
    let held = await runtime.snapshot()
    let state = try #require(held.commander.scriptState.instances[id])
    let custody = try #require(state.savedWayfarerColdChain)
    let release = try #require(custody.seedTransfer?.release)
    #expect(id == custody.definition.instanceIdentity(unit: quote.stockUnit))
    #expect(state.definition == WayfarerColdChainDefinition.seedStateID && quote.tonnes == 3)
    #expect(state.payloads == [custody.definition.payloadID: 3])
    #expect(held.commander.cargoTonnes == before.commander.cargoTonnes + 3)
    #expect(release.role == .release && release.custodian == custody.definition.sourceCustodian)
    #expect(
      release.contact == custody.issue && release.unit == quote.stockUnit && release.instance == id)
    #expect(
      custody.seedTransfer?.acceptance == nil && held.commander.credits == before.commander.credits)
    try seedCurrentEnvelopes(held, root: fixture.files.root)
    var full = before
    full.commander.cargo[0] = full.commander.standardCargoCapacity - 2
    #expect(throws: (any Error).self) {
      _ = try full.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id)
    }
    var stateCopy = state
    var commander = held.commander
    let event = ScriptEvent(
      sequence: held.commander.scriptState.nextEvent + 1, kind: "dialogue.confirmed", instance: id,
      values: [:], context: held.scriptEventContext(state))
    for op in ["credits", "payload.add", "payload.remove", "mission.finish", "dialogue.commit"] {
      #expect(throws: MissionPackError.self) {
        try held.applyScriptCommand(
          .object(["op": .string(op)]), event: event, pack: fixture.pack, state: &stateCopy,
          candidate: &commander)
      }
    }
    #expect(commander == held.commander && stateCopy == state)
  }

  @Test func nativeSeedSourcePickupAndAcceptanceWritersPublishNamedContactsAtomically() async throws
  {
    let fixture = try WayfarerSeedTransferNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let directory = fixture.save.deletingLastPathComponent()
    let initial = await runtime.snapshot()
    var files = try ScriptFinanceTestFixture.files(directory)
    var blocked = try fixture.files.blockWrites("seed-source")
    await #expect(throws: (any Error).self) {
      _ = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
    }
    #expect(await runtime.snapshot().commander == initial.commander)
    try fixture.files.restoreWrites(blocked, files: files)
    let source = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
    let quote = try await runtime.wayfarerColdChainQuote(sourceID: source)
    let before = await runtime.snapshot()
    files = try ScriptFinanceTestFixture.files(directory)
    blocked = try fixture.files.blockWrites("seed-release")
    await #expect(throws: (any Error).self) {
      _ = try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id)
    }
    #expect(await runtime.snapshot().commander == before.commander)
    try fixture.files.restoreWrites(blocked, files: files)
    let id = try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id)
    await #expect(throws: (any Error).self) {
      try await runtime.confirmWayfarerColdChainObjective(instance: id)
    }
    try await fixture.arrive(runtime, path: [241, 85])
    try await runtime.confirmWayfarerColdChainObjective(instance: id)
    let receiver = await runtime.snapshot()
    files = try ScriptFinanceTestFixture.files(directory)
    blocked = try fixture.files.blockWrites("seed-acceptance")
    await #expect(throws: (any Error).self) {
      try await runtime.receiveWayfarerColdChain(instance: id)
    }
    #expect(await runtime.snapshot().commander == receiver.commander)
    try fixture.files.restoreWrites(blocked, files: files)
    try await runtime.receiveWayfarerColdChain(instance: id)
    let paid = await runtime.snapshot()
    let state = try #require(paid.commander.scriptState.instances[id])
    let custody = try #require(state.savedWayfarerColdChain)
    let acceptance = try #require(custody.seedTransfer?.acceptance)
    #expect(
      acceptance.role == .acceptance && acceptance.custodian == custody.definition.receiverCustodian
    )
    #expect(acceptance.contact.context == state.completionReceipt?.cause)
    #expect(acceptance.contact.sequence == state.completionReceipt?.sequence)
    #expect(paid.commander.credits == receiver.commander.credits + 6050 && state.payloads.isEmpty)
    #expect(
      paid.commander.scriptState.savedClueJournal?.awards[WayfarerColdChainDefinition.seedStateID]?
        .completion.instance == id)
    #expect(
      paid.commander.scriptState.savedClueJournal?.awards[WayfarerColdChainDefinition.stateID]
        == nil)
    await #expect(throws: (any Error).self) {
      try await runtime.receiveWayfarerColdChain(instance: id)
    }
    try seedCurrentEnvelopes(paid, root: fixture.files.root)
  }

  @Test func rehashedSeedStrippingCrossProfileQuantityAndOldEnvelopeClaimsAreRejected() async throws
  {
    let fixture = try WayfarerSeedTransferNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, _) = try await fixture.pickup(runtime)
    try fixture.rejectMissionsChange { raw in raw.removeValue(forKey: "savedWayfarerColdChainStock")
    }
    try fixture.rejectMissionsChange { raw in
      try seedMutateInstance(id, raw: &raw) { state in
        var custody = try #require(state["savedWayfarerColdChain"] as? [String: Any])
        custody.removeValue(forKey: "seedTransfer")
        state["savedWayfarerColdChain"] = custody
      }
    }
    try fixture.rejectMissionsChange { raw in
      try seedMutateInstance(id, raw: &raw) { state in
        var custody = try #require(state["savedWayfarerColdChain"] as? [String: Any])
        var definition = try #require(custody["definition"] as? [String: Any])
        definition["profile"] = NSNull()
        custody["definition"] = definition
        state["savedWayfarerColdChain"] = custody
      }
    }
    try fixture.rejectMissionsChange { raw in
      try seedMutateInstance(id, raw: &raw) { state in
        var custody = try #require(state["savedWayfarerColdChain"] as? [String: Any])
        var contacts = try #require(custody["seedTransfer"] as? [String: Any])
        var release = try #require(contacts["release"] as? [String: Any])
        let definition = try #require(custody["definition"] as? [String: Any])
        release["custodian"] = definition["receiverCustodian"]
        contacts["release"] = release
        custody["seedTransfer"] = contacts
        state["savedWayfarerColdChain"] = custody
      }
    }
    try fixture.rejectMissionsChange { raw in
      try seedMutateInstance(id, raw: &raw) { state in
        state["payloads"] = ["wayfarer-sealed-seed-lot": 1]
      }
    }
    try fixture.rejectMissionsChange { raw in raw["embedded"] = [[["profile": "seed-transfer"]]] }
    let bytes = try Data(contentsOf: fixture.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    for schema in [35, 36] {
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: schema, generation: pointer.generation,
        hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        _ = try ScriptSaveStore.read(JSONEncoder().encode(changed), from: fixture.save)
      }
    }
    var raw = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    raw["profile"] = "seed-transfer"
    #expect(throws: (any Error).self) {
      _ = try ScriptSaveStore.read(JSONSerialization.data(withJSONObject: raw), from: fixture.save)
    }
    let terms = try #require(fixture.pack.manifest.coldChain)
    var stripped = terms
    stripped.profile = nil
    stripped.sourceCustodian = nil
    stripped.receiverCustodian = nil
    #expect(!stripped.valid)
    let oldTerms = try #require(
      ScriptPackLibrary.read(ScriptPackLibrary.bundledColdChainDirectory).manifest.coldChain)
    #expect(
      oldTerms.valid && oldTerms.profile == nil
        && oldTerms.instanceDefinition == WayfarerColdChainDefinition.stateID)
  }

  @Test func seedPauseCurrentReloadAndOriginalSuspendedExpiryKeepReleaseWithoutAcceptance()
    async throws
  {
    let fixture = try WayfarerSeedTransferNativeFixture(shortExpiry: true)
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, _) = try await fixture.pickup(runtime)
    let original = await runtime.snapshot()
    let before = try await runtime.wayfarerColdChainRemaining(instance: id)
    await runtime.key("pause")
    for _ in 0..<3 { _ = await runtime.advance(delta: 0.1) }
    #expect(try await runtime.wayfarerColdChainRemaining(instance: id) == before)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(try await runtime.wayfarerColdChainRemaining(instance: id) == before)
    if await runtime.snapshot().paused { await runtime.key("pause") }
    await runtime.key("0")
    let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("seed-expiry")
    for _ in 0..<8 { _ = await runtime.advance(delta: 0.1) }
    let pending = await runtime.snapshot()
    let state = try #require(pending.commander.scriptState.instances[id])
    let event = try #require(
      WayfarerColdChainSave.pendingExpiry(state, engine: pending.commander.scriptState))
    try #require(state.suspension != nil)
    try fixture.files.restoreWrites(blocked, files: files)
    try await ScriptProcurementFixture.dock(runtime)
    try await runtime.retryWayfarerColdChainExpiry(instance: id)
    let failed = await runtime.snapshot()
    let ended = try #require(failed.commander.scriptState.instances[id])
    #expect(ended.outcome == .failed && ended.completionReceipt?.sequence == event.sequence)
    #expect(
      ended.savedWayfarerColdChain?.seedTransfer?.release
        == original.commander.scriptState.instances[id]?.savedWayfarerColdChain?.seedTransfer?
        .release)
    #expect(ended.savedWayfarerColdChain?.seedTransfer?.acceptance == nil && ended.payloads.isEmpty)
    #expect(
      failed.commander.credits == original.commander.credits
        && failed.commander.scriptState.savedClueJournal == nil)
  }

  @Test func sharedEnvelopeAcceptsW02OnlyAndMixedW01W02W03ButNeverAnEmptyClaim() async throws {
    let fixture = try WayfarerSeedTransferNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(mixedServices: true)
    let emptyBytes = try Data(contentsOf: fixture.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: emptyBytes)
    for schema in [37, 38] {
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: schema, generation: pointer.generation,
        hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        _ = try ScriptSaveStore.read(JSONEncoder().encode(changed), from: fixture.save)
      }
    }
    try await fixture.arrive(runtime, path: [241, 85])
    let repair = try ScriptPackLibrary.read(ScriptPackLibrary.bundledRepairLoopDirectory)
    let source = try await runtime.initializeWayfarerRepairLoopStock(packDigest: repair.digest)
    let quote = try await runtime.wayfarerRepairLoopQuote(sourceID: source)
    _ = try await runtime.pickUpWayfarerRepairLoop(sourceID: source, quotedOfferID: quote.id)
    let w02 = await runtime.snapshot()
    #expect(!WayfarerColdChainSave.seedTransferHasClaims(w02.commander))
    try seedCurrentEnvelopes(w02, root: fixture.files.root)
    let cold = try ScriptPackLibrary.read(ScriptPackLibrary.bundledColdChainDirectory)
    let coldSource = try await runtime.initializeWayfarerColdChainStock(packDigest: cold.digest)
    let coldOffer = try await runtime.wayfarerColdChainQuote(sourceID: coldSource)
    _ = try await runtime.pickUpWayfarerColdChain(sourceID: coldSource, quotedOfferID: coldOffer.id)
    try await fixture.arrive(runtime, path: [85, 241])
    _ = try await fixture.pickup(runtime)
    let mixed = await runtime.snapshot()
    #expect(OriginalServiceReservationPolicy.activeCount(mixed.commander.scriptState) == 3)
    #expect(
      WayfarerColdChainSave.seedTransferHasClaims(mixed.commander)
        && WayfarerRepairLoopSave.hasClaims(mixed.commander))
    await #expect(throws: (any Error).self) { _ = try await fixture.pickup(runtime) }
    #expect(await runtime.snapshot().commander == mixed.commander)
    try seedCurrentEnvelopes(mixed, root: fixture.files.root)
  }

  @Test func actualSeedEscapeThenNewLotsExhaustSixWithoutRefillingTheSeedBank() async throws {
    let fixture = try WayfarerSeedTransferNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(escapeReady: true)
    var lost: Set<UUID> = []
    var source = ""
    for _ in 0..<3 {
      let (id, quote) = try await fixture.pickup(runtime)
      lost.insert(id)
      source = quote.sourceID
    }
    await runtime.key("0")
    let before = await runtime.snapshot()
    await runtime.key("escape-pod")
    let escaped = await runtime.snapshot()
    for id in lost {
      let state = try #require(escaped.commander.scriptState.instances[id])
      #expect(
        state.outcome == .failed && state.payloads.isEmpty
          && state.savedWayfarerColdChain?.loss?.cause == .escapePod)
      #expect(state.savedWayfarerColdChain?.seedTransfer?.acceptance == nil)
    }
    #expect(
      escaped.commander.credits == before.commander.credits
        && escaped.commander.scriptState.savedClueJournal == nil)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    var next: [UUID] = []
    for _ in 0..<3 {
      let (id, _) = try await fixture.pickup(runtime)
      #expect(!lost.contains(id))
      next.append(id)
    }
    try await fixture.arrive(runtime, path: [241, 85])
    for id in next { try await fixture.receive(runtime, id: id) }
    try await fixture.arrive(runtime, path: [85, 241])
    let complete = await runtime.snapshot()
    let stock = try #require(
      complete.commander.scriptState.savedWayfarerColdChainStock?.sources[source])
    #expect(stock.units.count == 6 && stock.units.values.filter { $0.status == .failed }.count == 3)
    #expect(stock.units.values.filter { $0.status == .received }.count == 3)
    _ = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
    #expect(
      await runtime.snapshot().commander.scriptState.savedWayfarerColdChainStock?.sources[source]
        == stock)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(
      await runtime.snapshot().commander.scriptState.savedWayfarerColdChainStock?.sources[source]
        == stock)
    await #expect(throws: (any Error).self) {
      _ = try await runtime.wayfarerColdChainQuote(sourceID: source)
    }
  }

  @Test func actualSeedFatalWriterRetryPreservesOriginalReleaseAndNeverMintsAcceptance()
    async throws
  {
    let fixture = try WayfarerSeedTransferNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, _) = try await fixture.pickup(runtime)
    await runtime.key("0")
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("seed-fatal")
    try await runtime.seedActualFatalHit()
    _ = await runtime.advance(delta: 0.1)
    let refused = await runtime.snapshot()
    #expect(refused.screen == .gameOver && refused.energy <= 0)
    #expect(
      refused.commander.scriptState.savedWayfarerColdChainStock
        == before.commander.scriptState.savedWayfarerColdChainStock)
    try fixture.files.restoreWrites(blocked, files: files)
    _ = await runtime.advance(delta: 0.1)
    let failed = await runtime.snapshot()
    let state = try #require(failed.commander.scriptState.instances[id])
    #expect(state.outcome == .failed && state.savedWayfarerColdChain?.loss?.cause == .shipDestroyed)
    #expect(
      state.savedWayfarerColdChain?.seedTransfer?.release
        == before.commander.scriptState.instances[id]?.savedWayfarerColdChain?.seedTransfer?.release
    )
    #expect(state.savedWayfarerColdChain?.seedTransfer?.acceptance == nil && state.payloads.isEmpty)
    #expect(
      failed.commander.credits == before.commander.credits
        && failed.commander.scriptState.savedClueJournal == nil)
  }
}

extension GameRuntime {
  fileprivate func seedActualFatalHit() throws {
    let mesh = game.commander.playerMesh
    let face = try #require(
      mesh.faces.first {
        $0.count == 3 && (mesh.vertices[$0[0]] + mesh.vertices[$0[1]] + mesh.vertices[$0[2]]).z > 0
      })
    let center =
      (mesh.vertices[face[0]] + mesh.vertices[face[1]] + mesh.vertices[face[2]]) * (1.0 / 3.0)
    let position = center.unit * 500
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: position, hostile: true))
    game.ensurePhysicalActors()
    let owner = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
    let contact = try game.nearestMissionCollision(
      from: position, direction: position.unit * -1, range: position.length + 1, radius: 0,
      excludingBodyIDs: [id], includePlayer: true)
    let hit = try #require(contact?.hit)
    try #require(hit.target == .player)
    let allocated = game.makeAttackOrigin(owner: owner)
    let origin = try #require(allocated)
    let damage = game.energy + game.frontShield + game.rearShield + 1
    let recorded = game.applyCombatHit(hit, origin: origin, kind: .laser, damage: damage)
    try #require(recorded != nil)
  }
}
