import Foundation
import Testing

@testable import EliteCore

/// Shared actual native dock/travel setup; board tests own their UI interaction proofs.
struct WayfarerRepairLoopNativeFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack
  var save: URL { files.save }
  init() throws {
    files = try ScriptFreightFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledRepairLoopDirectory)
  }
  func runtime(escapeReady: Bool = false, mixedColdChain: Bool = false) async throws -> GameRuntime
  {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    game.commander.system = 85
    game.selectedSystem = 85
    game.market = MarketItem.at(game.currentSystem)
    game.scriptPacks = [pack]
    if mixedColdChain {
      game.scriptPacks.append(
        try ScriptPackLibrary.read(ScriptPackLibrary.bundledColdChainDirectory))
    }
    try game.prepareG03FlightEquipment()
    if escapeReady {
      let pod = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(pod)
      try #require(try game.applyEquipmentPurchase(quote))
    }
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    return runtime
  }
  func arrive(_ runtime: GameRuntime, path: [Int]) async throws {
    let snapshot = await runtime.snapshot()
    if snapshot.screen == .contracts {
      if snapshot.contractBoard.detail { await runtime.key("escape") }
      await runtime.key("escape")
    }
    try await ScriptProcurementFixture.travel(runtime, path: path, verifyDeparture: true)
  }
  func pickup(_ runtime: GameRuntime) async throws -> (UUID, WayfarerRepairLoopOffer) {
    let source = try await runtime.initializeWayfarerRepairLoopStock(packDigest: pack.digest)
    let quote = try await runtime.wayfarerRepairLoopQuote(sourceID: source)
    let id = try await runtime.pickUpWayfarerRepairLoop(sourceID: source, quotedOfferID: quote.id)
    return (id, quote)
  }
  func service(_ runtime: GameRuntime, id: UUID) async throws {
    let quote = try await runtime.wayfarerRepairLoopStageQuote(instance: id, returning: false)
    try await runtime.serviceWayfarerRepairLoop(instance: id, quotedOperationID: quote.id)
  }
  func receive(_ runtime: GameRuntime, id: UUID) async throws {
    let quote = try await runtime.wayfarerRepairLoopStageQuote(instance: id, returning: true)
    try await runtime.returnWayfarerRepairLoop(instance: id, quotedOperationID: quote.id)
  }
}

private func repairLoopCurrentRoundTrips(_ game: consuming Game, root: URL) throws {
  let prepared = try GameRuntime.prepareNativeSaveState(game)
  let normal = root.appendingPathComponent("normal-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: normal)
  let (loaded, world) = try ScriptSaveStore.read(Data(contentsOf: normal), from: normal)
  #expect(world.consistent(with: loaded) && WayfarerRepairLoopSave.validateClaims(loaded))
  #expect(
    loaded.scriptState.savedWayfarerRepairLoopStock
      == prepared.commander.scriptState.savedWayfarerRepairLoopStock)
  #expect(loaded.equipmentInventory == prepared.commander.equipmentInventory)
  var alien = game
  let owner = try #require(alien.commander.equipmentOwnerID)
  // Storage composition only; this empty state asserts no invented Alien acquisition authority.
  try alien.commander.replaceAlienStorage(
    with: .init(
      owner: owner, revision: 0, worldRevision: 0,
      world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
  let adapted = try GameRuntime.prepareNativeSaveState(alien)
  let url = root.appendingPathComponent("alien-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: adapted.commander, world: adapted.game.scriptWorldSave, to: url)
  let (cold, alienWorld) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
  #expect(cold.usesAlienStorageSaveVersion && alienWorld.consistent(with: cold))
  #expect(WayfarerRepairLoopSave.validateClaims(cold))
  #expect(
    cold.scriptState.savedWayfarerRepairLoopStock
      == adapted.commander.scriptState.savedWayfarerRepairLoopStock)
  #expect(cold.equipmentInventory == adapted.commander.equipmentInventory)
}

struct WayfarerRepairLoopNativeTests {
  @Test func currentSourcePredeclaresFailedSerialsAndTransportLoanSurvivesHullTransfer()
    async throws
  {
    let fixture = try WayfarerRepairLoopNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let source = try await runtime.initializeWayfarerRepairLoopStock(
      packDigest: fixture.pack.digest)
    let initialized = await runtime.snapshot()
    let stock = try #require(
      initialized.commander.scriptState.savedWayfarerRepairLoopStock?.sources[source])
    #expect(stock.units.count == 6 && Set(stock.units.values.map(\.serial)).count == 6)
    #expect(
      stock.units.values.allSatisfy {
        $0.original.nativeRepairLoopCondition == .failed(sourceUnit: $0.id)
          && $0.status == .available && $0.instance == nil
      })
    _ = try await runtime.initializeWayfarerRepairLoopStock(packDigest: fixture.pack.digest)
    #expect(await runtime.snapshot().commander == initialized.commander)
    let quote = try await runtime.wayfarerRepairLoopQuote(sourceID: source)
    let original = try #require(stock.units[quote.stockUnit.uuidString]?.original)
    let id = try await runtime.pickUpWayfarerRepairLoop(sourceID: source, quotedOfferID: quote.id)
    let held = await runtime.snapshot()
    let state = try #require(held.commander.scriptState.instances[id])
    let gear = try #require(state.gearIssues[WayfarerRepairLoopDefinition.gearKey])
    #expect(held.commander.equipmentInventory?.items.first { $0.id == quote.serial } == original)
    #expect(
      gear.loan && !gear.returnRemaining && gear.status == .issued && gear.items == [quote.serial])
    #expect(state.payloads == [WayfarerRepairLoopDefinition.payloadKey: 2])
    #expect(held.commander.credits == initialized.commander.credits)
    await #expect(throws: (any Error).self) {
      try await runtime.pickUpWayfarerRepairLoop(sourceID: source, quotedOfferID: quote.id)
    }
    var transferred = held.commander
    try transferred.transferEquipment(to: held.commander.shipID, hullID: UUID())
    #expect(transferred.equipmentInventory?.items.first { $0.id == quote.serial } == original)
    #expect(transferred.scriptState.instances[id]?.gearIssues == state.gearIssues)
    #expect(transferred.scriptState.instances[id]?.payloads == state.payloads)
    #expect(WayfarerRepairLoopSave.validateClaims(transferred))
    var inventory = try #require(held.commander.equipmentInventory)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull,
      performance: held.commander.nativePerformance)
    let slot = try #require(original.preferredSlot)
    #expect(throws: OwnedEquipmentError.self) {
      try inventory.fit(
        expected: original, at: .init(hullInstanceID: inventory.activeHull, slot: slot),
        expectedRevision: inventory.revision, context: context)
    }
    var candidate = held.commander
    var stagedState = state
    #expect(throws: (any Error).self) {
      _ = try held.settleScriptGear(
        gear, release: true, command: UUID(), state: &stagedState, candidate: &candidate)
    }
    #expect(candidate == held.commander && stagedState == state)
    let event = ScriptEvent(
      sequence: held.commander.scriptState.nextEvent + 1, kind: "dialogue.confirmed", instance: id,
      values: [:], context: held.scriptEventContext(state))
    for operation in ["credits", "mission.finish", "gear.issue", "gear.return", "gear.release"] {
      #expect(throws: MissionPackError.self) {
        try held.applyScriptCommand(
          .object(["op": .string(operation)]), event: event, pack: fixture.pack,
          state: &stagedState, candidate: &candidate)
      }
    }
    #expect(candidate == held.commander && stagedState == state)
  }

  @Test func nativeInitializationPickupAndWorkshopWriterFailuresConserveOriginalAuthority()
    async throws
  {
    let fixture = try WayfarerRepairLoopNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let before = await runtime.snapshot()
    let directory = fixture.save.deletingLastPathComponent()
    var files = try ScriptFinanceTestFixture.files(directory)
    var blocked = try fixture.files.blockWrites("repair-source")
    await #expect(throws: (any Error).self) {
      _ = try await runtime.initializeWayfarerRepairLoopStock(packDigest: fixture.pack.digest)
    }
    #expect(await runtime.snapshot().commander == before.commander)
    try fixture.files.restoreWrites(blocked, files: files)
    let source = try await runtime.initializeWayfarerRepairLoopStock(
      packDigest: fixture.pack.digest)
    let quote = try await runtime.wayfarerRepairLoopQuote(sourceID: source)
    let initialized = await runtime.snapshot()
    files = try ScriptFinanceTestFixture.files(directory)
    blocked = try fixture.files.blockWrites("repair-pickup")
    await #expect(throws: (any Error).self) {
      _ = try await runtime.pickUpWayfarerRepairLoop(sourceID: source, quotedOfferID: quote.id)
    }
    #expect(await runtime.snapshot().commander == initialized.commander)
    try fixture.files.restoreWrites(blocked, files: files)
    let id = try await runtime.pickUpWayfarerRepairLoop(sourceID: source, quotedOfferID: quote.id)
    await #expect(throws: (any Error).self) {
      _ = try await runtime.wayfarerRepairLoopStageQuote(instance: id, returning: false)
    }
    try await fixture.arrive(runtime, path: [85, 241])
    let workshop = await runtime.snapshot()
    let operation = try await runtime.wayfarerRepairLoopStageQuote(instance: id, returning: false)
    files = try ScriptFinanceTestFixture.files(directory)
    blocked = try fixture.files.blockWrites("repair-service")
    await #expect(throws: (any Error).self) {
      try await runtime.serviceWayfarerRepairLoop(instance: id, quotedOperationID: operation.id)
    }
    #expect(await runtime.snapshot().commander == workshop.commander)
    try fixture.files.restoreWrites(blocked, files: files)
    try await runtime.serviceWayfarerRepairLoop(instance: id, quotedOperationID: operation.id)
    let serviced = await runtime.snapshot()
    let custody = try #require(
      serviced.commander.scriptState.instances[id]?.savedWayfarerRepairLoop)
    let receipt = try #require(custody.service)
    #expect(receipt.before.id == receipt.after.id && receipt.after.id == quote.serial)
    #expect(receipt.before.nativeRepairLoopCondition == .failed(sourceUnit: quote.stockUnit))
    #expect(
      receipt.after.nativeRepairLoopCondition
        == .operational(sourceUnit: quote.stockUnit, operation: receipt.operation))
    #expect(
      serviced.commander.credits == workshop.commander.credits
        && serviced.commander.scriptState.savedClueJournal == nil)
    await #expect(throws: (any Error).self) {
      try await runtime.serviceWayfarerRepairLoop(instance: id, quotedOperationID: operation.id)
    }
  }

  @Test func exactOwnerReturnRollbackAndAllCurrentEnvelopesRetainTheSameUnitChain() async throws {
    let fixture = try WayfarerRepairLoopNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, quote) = try await fixture.pickup(runtime)
    try repairLoopCurrentRoundTrips(await runtime.snapshot(), root: fixture.files.root)
    try await fixture.arrive(runtime, path: [85, 241])
    try await fixture.service(runtime, id: id)
    try repairLoopCurrentRoundTrips(await runtime.snapshot(), root: fixture.files.root)
    await #expect(throws: (any Error).self) {
      _ = try await runtime.wayfarerRepairLoopStageQuote(instance: id, returning: true)
    }
    try await fixture.arrive(runtime, path: [241, 85])
    let operation = try await runtime.wayfarerRepairLoopStageQuote(instance: id, returning: true)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("repair-owner-return")
    await #expect(throws: (any Error).self) {
      try await runtime.returnWayfarerRepairLoop(instance: id, quotedOperationID: operation.id)
    }
    #expect(await runtime.snapshot().commander == before.commander)
    try fixture.files.restoreWrites(blocked, files: files)
    try await runtime.returnWayfarerRepairLoop(instance: id, quotedOperationID: operation.id)
    let after = await runtime.snapshot()
    let state = try #require(after.commander.scriptState.instances[id])
    let receipt = try #require(state.savedWayfarerRepairLoop?.returned)
    #expect(state.outcome == .complete && state.payloads.isEmpty)
    #expect(receipt.originalItems == [quote.serial] && receipt.amount == 6100)
    #expect(state.gearIssues[WayfarerRepairLoopDefinition.gearKey]?.status == .returned)
    #expect(after.commander.equipmentInventory?.items.contains { $0.id == quote.serial } == false)
    #expect(after.commander.credits == before.commander.credits + 6100)
    #expect(
      after.commander.scriptState.savedClueJournal?.awards[WayfarerRepairLoopDefinition.stateID]?
        .completion.instance == id)
    await #expect(throws: (any Error).self) {
      try await runtime.returnWayfarerRepairLoop(instance: id, quotedOperationID: operation.id)
    }
    try repairLoopCurrentRoundTrips(after, root: fixture.files.root)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(
      await runtime.snapshot().commander.scriptState.instances[id]?.savedWayfarerRepairLoop
        == state.savedWayfarerRepairLoop)
  }

  @Test func currentClaimsRejectStrippedConditionsOrUnjoinedServiceProofs() async throws {
    let fixture = try WayfarerRepairLoopNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, quote) = try await fixture.pickup(runtime)
    let held = await runtime.snapshot()
    let inventory = try #require(held.commander.equipmentInventory)
    let original = try #require(inventory.items.first { $0.id == quote.serial })
    var stripped = held.commander
    let plain = OwnedEquipmentItem(
      id: original.id, node: original.node, provenance: original.provenance,
      component: original.component, preferredSlot: original.preferredSlot)
    stripped.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items.map { $0.id == original.id ? plain : $0 },
      expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: stripped.nativePerformance)
    )
    #expect(!WayfarerRepairLoopSave.validateClaims(stripped))
    var orphan = held.commander
    orphan.scriptState.savedWayfarerRepairLoopStock = nil
    #expect(
      !WayfarerRepairLoopSave.validateClaims(orphan) && WayfarerRepairLoopSave.hasClaims(orphan))
    try await fixture.arrive(runtime, path: [85, 241])
    try await fixture.service(runtime, id: id)
    let serviced = await runtime.snapshot()
    let custody = try #require(
      serviced.commander.scriptState.instances[id]?.savedWayfarerRepairLoop)
    var missing = serviced.commander
    missing.scriptState.instances[id]?.savedWayfarerRepairLoop = .init(
      owner: custody.owner, source: custody.source,
      unit: custody.unit, serial: custody.serial, definition: custody.definition,
      issue: custody.issue, admission: custody.admission)
    #expect(!WayfarerRepairLoopSave.validateClaims(missing))
    let receipt = try #require(custody.service)
    let swapped = WayfarerRepairLoopServiceReceipt(
      operation: UUID(), recipe: receipt.recipe,
      inventoryRevision: receipt.inventoryRevision, instance: id, sourceUnit: receipt.sourceUnit,
      ownerResource: receipt.ownerResource, issue: receipt.issue, contact: receipt.contact,
      epoch: receipt.epoch, before: receipt.before, after: receipt.after)
    var forged = serviced.commander
    forged.scriptState.instances[id]?.savedWayfarerRepairLoop = custody.replacing(service: swapped)
    #expect(!WayfarerRepairLoopSave.validateClaims(forged))
    for raw: [String: Any] in [
      ["nativeRepairLoopCondition": NSNull()], ["savedWayfarerRepairLoopStock": NSNull()],
    ] {
      let bytes = try JSONSerialization.data(withJSONObject: raw)
      #expect(throws: (any Error).self) {
        try WayfarerRepairLoopSave.validateFields(bytes, part: .commander, schema: 37)
      }
    }
    let currentBytes = try JSONEncoder().encode(serviced.commander)
    #expect(throws: (any Error).self) {
      try WayfarerRepairLoopSave.validateFields(currentBytes, part: .commander, schema: 35)
    }
    try WayfarerRepairLoopSave.validateFields(currentBytes, part: .commander, schema: 37)
  }

  @Test func mixedOriginalAndColdChainReservationsRefuseFourthAndRetainCurrentComposition()
    async throws
  {
    let fixture = try WayfarerRepairLoopNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(mixedColdChain: true)
    let cold = try ScriptPackLibrary.read(ScriptPackLibrary.bundledColdChainDirectory)
    let source = try await runtime.initializeWayfarerColdChainStock(packDigest: cold.digest)
    let offer = try await runtime.wayfarerColdChainQuote(sourceID: source)
    _ = try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: offer.id)
    _ = try await fixture.pickup(runtime)
    _ = try await fixture.pickup(runtime)
    let before = await runtime.snapshot()
    #expect(OriginalServiceReservationPolicy.activeCount(before.commander.scriptState) == 3)
    await #expect(throws: (any Error).self) { _ = try await fixture.pickup(runtime) }
    #expect(await runtime.snapshot().commander == before.commander)
    try repairLoopCurrentRoundTrips(before, root: fixture.files.root)
  }

  @Test func actualEscapeWriterRollbackThenSixFiniteUnitsNeverReplenish() async throws {
    let fixture = try WayfarerRepairLoopNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(escapeReady: true)
    var lost: [UUID] = []
    var source = ""
    for _ in 0..<3 {
      let (id, quote) = try await fixture.pickup(runtime)
      lost.append(id)
      source = quote.sourceID
    }
    await runtime.key("0")
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("repair-escape")
    await runtime.key("escape-pod")
    #expect(await runtime.snapshot().commander == before.commander)
    try fixture.files.restoreWrites(blocked, files: files)
    await runtime.key("escape-pod")
    let escaped = await runtime.snapshot()
    for id in lost {
      let state = try #require(escaped.commander.scriptState.instances[id])
      let custody = try #require(state.savedWayfarerRepairLoop)
      #expect(
        state.outcome == .failed && custody.loss?.cause == .escapePod && state.payloads.isEmpty)
      #expect(state.gearIssues[WayfarerRepairLoopDefinition.gearKey]?.consumed == [custody.serial])
      #expect(
        escaped.commander.equipmentInventory?.items.contains { $0.id == custody.serial } == false)
    }
    #expect(
      escaped.commander.credits == before.commander.credits
        && escaped.commander.scriptState.savedClueJournal == nil)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    var returned: [UUID] = []
    for _ in 0..<3 {
      let (id, _) = try await fixture.pickup(runtime)
      #expect(!lost.contains(id))
      returned.append(id)
    }
    try await fixture.arrive(runtime, path: [85, 241])
    for id in returned { try await fixture.service(runtime, id: id) }
    try await fixture.arrive(runtime, path: [241, 85])
    for id in returned { try await fixture.receive(runtime, id: id) }
    let exhausted = await runtime.snapshot()
    let stock = try #require(
      exhausted.commander.scriptState.savedWayfarerRepairLoopStock?.sources[source])
    #expect(stock.units.count == 6 && stock.units.values.filter { $0.status == .lost }.count == 3)
    #expect(
      stock.units.values.filter { $0.status == .returned && $0.returnedItem != nil }.count == 3)
    _ = try await runtime.initializeWayfarerRepairLoopStock(packDigest: fixture.pack.digest)
    #expect(
      await runtime.snapshot().commander.scriptState.savedWayfarerRepairLoopStock?.sources[source]
        == stock)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(
      await runtime.snapshot().commander.scriptState.savedWayfarerRepairLoopStock?.sources[source]
        == stock)
    await #expect(throws: (any Error).self) {
      _ = try await runtime.wayfarerRepairLoopQuote(sourceID: source)
    }
  }

  @Test func measuredFatalHitWriterRetryConsumesOriginalLoanWithoutPayment() async throws {
    let fixture = try WayfarerRepairLoopNativeFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, quote) = try await fixture.pickup(runtime)
    await runtime.key("0")
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("repair-fatal")
    try await runtime.repairLoopActualFatalHit()
    _ = await runtime.advance(delta: 0.1)
    let refused = await runtime.snapshot()
    #expect(refused.screen == .gameOver && refused.energy <= 0)
    #expect(
      refused.commander.scriptState.savedWayfarerRepairLoopStock
        == before.commander.scriptState.savedWayfarerRepairLoopStock)
    #expect(
      refused.commander.scriptState.instances[id]?.savedWayfarerRepairLoop
        == before.commander.scriptState.instances[id]?.savedWayfarerRepairLoop)
    try fixture.files.restoreWrites(blocked, files: files)
    _ = await runtime.advance(delta: 0.1)
    let failed = await runtime.snapshot()
    let state = try #require(failed.commander.scriptState.instances[id])
    #expect(
      state.outcome == .failed && state.savedWayfarerRepairLoop?.loss?.cause == .shipDestroyed)
    #expect(state.gearIssues[WayfarerRepairLoopDefinition.gearKey]?.consumed == [quote.serial])
    #expect(failed.commander.equipmentInventory?.items.contains { $0.id == quote.serial } == false)
    #expect(
      failed.commander.credits == before.commander.credits
        && failed.commander.scriptState.savedClueJournal == nil)
    let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
    #expect(
      cold.scriptState.instances[id]?.savedWayfarerRepairLoop == state.savedWayfarerRepairLoop)
  }
}

extension GameRuntime {
  /// Controlled native actor/ray/origin/hit, never assigned energy/game-over or a forged loss.
  fileprivate func repairLoopActualFatalHit() throws {
    let mesh = game.commander.playerMesh
    let face = try #require(
      mesh.faces.first { indices in
        indices.count == 3
          && (mesh.vertices[indices[0]] + mesh.vertices[indices[1]] + mesh.vertices[indices[2]]).z
            > 0
      })
    let center =
      (mesh.vertices[face[0]] + mesh.vertices[face[1]] + mesh.vertices[face[2]]) * (1.0 / 3.0)
    let position = center.unit * 500
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: position, hostile: true))
    game.ensurePhysicalActors()
    let actor = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
    let contact = try game.nearestMissionCollision(
      from: position, direction: position.unit * -1,
      range: position.length + 1, radius: 0, excludingBodyIDs: [id], includePlayer: true)
    let hit = try #require(contact?.hit)
    try #require(hit.target == .player)
    let allocated = game.makeAttackOrigin(owner: actor)
    let origin = try #require(allocated)
    let damage = game.energy + game.frontShield + game.rearShield + 1
    let result = game.applyCombatHit(hit, origin: origin, kind: .laser, damage: damage)
    try #require(result != nil)
  }
}
