import Foundation
import Testing

@testable import EliteCore

struct ProcurementHistoryForgery: Sendable {
  let stage: String
  let field: String
  static let cases: [Self] = ["partial", "complete", "abandoned"].flatMap { stage in
    ["owner-world", "unissued-sequence", "future-visit", "future-dock-clock"].map {
      .init(stage: stage, field: $0)
    }
  }
}

@Test(arguments: ProcurementHistoryForgery.cases)
func procurementGenuineHistoricalDockProofRejectsPairedForgeriesWithoutChangingLiveState(
  forgery: ProcurementHistoryForgery
) async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let (runtime, id) = try await fixture.genuineProcurementHistory(stage: forgery.stage)
  let live = await runtime.snapshot()
  let state = try #require(live.commander.scriptState.instances[id])
  let historical = try #require(
    state.collections["procurement-goods"]?.lots.values.first?.cause.nativeMainDock
      ?? state.completionReceipt?.cause?.nativeMainDock)
  let current = try #require(live.commander.nativeStations?.currentMainDock)
  // The earlier real contact survives a later real launch and docking. It is historical,
  // not a copy of the current receipt or newly minted authority after load.
  #expect(historical != current && historical.sequence < current.sequence)
  #expect(historical.actor.visit < current.actor.visit && live.commander.valid)
  let pointerBytes = try Data(contentsOf: fixture.save)
  let (genuine, world) = try ScriptSaveStore.read(pointerBytes, from: fixture.save)
  #expect(genuine == live.commander)
  #expect(genuine.scriptState.instances[id] == state && world.consistent(with: genuine))
  let originalFiles = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let forged = try procurementForgedHistory(genuine, id: id, field: forgery.field)
  let changed = try #require(forged.scriptState.instances[id])
  // Keep the paired lot/terminal facts internally equal and structurally valid, so
  // refusal depends on the owning native world's semantic history joins.
  let lots = changed.collections["procurement-goods"]?.lots ?? [:]
  for lot in lots.values {
    #expect(lot.cause.valid && lot.committed.valid)
    #expect(lot.cause.nativeMainDock == lot.committed.nativeMainDock)
  }
  if let receipt = changed.completionReceipt {
    #expect(receipt.cause?.valid == true && receipt.committed.valid)
    #expect(receipt.cause?.nativeMainDock == receipt.committed.nativeMainDock)
  }
  #expect(forged.nativeStations == genuine.nativeStations)
  #expect(forged.cargo == genuine.cargo && forged.credits == genuine.credits)
  #expect(!forged.contractsValid && !forged.valid)
  #expect(throws: (any Error).self) {
    _ = try ScriptSaveStore.write(commander: forged, world: world, to: fixture.save)
  }
  let filesAfterWrite = try ScriptFinanceTestFixture.files(
    fixture.save.deletingLastPathComponent())
  #expect(filesAfterWrite == originalFiles)

  // Copy the actual current container, change only missions and its checksum, and
  // retain every native-world chunk, original receipt cursor and other pointer field.
  let forgedFolder = fixture.root.appendingPathComponent("forged-history")
  try FileManager.default.copyItem(
    at: fixture.save.deletingLastPathComponent(), to: forgedFolder)
  let forgedFile = forgedFolder.appendingPathComponent(fixture.save.lastPathComponent)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
  let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: forgedFile)
  let missions = try ScriptValueStorage.encoder().encode(forged.scriptState)
  try missions.write(to: generation.appendingPathComponent("missions.json"))
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(missions)
  let changedPointer = ScriptSavePointer(
    format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
    hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
  let changedBytes = try JSONEncoder().encode(changedPointer)
  try changedBytes.write(to: forgedFile)
  let storedMissions = try Data(contentsOf: generation.appendingPathComponent("missions.json"))
  #expect(ScriptPackLibrary.hash(storedMissions) == changedPointer.hashes["missions.json"])
  #expect(throws: (any Error).self) {
    _ = try ScriptSaveStore.read(changedBytes, from: forgedFile)
  }
  await #expect(throws: (any Error).self) {
    try await runtime.load(from: forgedFile, persistMigrations: false)
  }
  let refused = await runtime.snapshot()
  let filesAfterRead = try ScriptFinanceTestFixture.files(
    fixture.save.deletingLastPathComponent())
  #expect(refused.commander == live.commander && refused.bodies == live.bodies)
  #expect(refused.scriptPresentedDialogue == live.scriptPresentedDialogue)
  #expect(filesAfterRead == originalFiles)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let restored = await runtime.snapshot()
  #expect(restored.commander == live.commander && restored.bodies == live.bodies)
  #expect(restored.commander.scriptState.instances[id] == state)
}

extension ScriptProcurementFixture {
  /// Every historical receipt below is produced by the existing actual runtime flow.
  /// Stock, route, fuel, docking and survival premises are checked, never injected.
  fileprivate func genuineProcurementHistory(stage: String) async throws -> (GameRuntime, UUID) {
    let runtime = try await nativeRuntime()
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    let generated = await runtime.snapshot()
    let row = stage == "partial" ? 1 : 0
    let offer = try #require(generated.commander.contracts.boards[key]?.offers[row])
    let plan = try #require(ScriptProcurementPlan.read(offer.parameters))
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed)
    let id = try await runtime.confirmContract(quote)
    if stage != "abandoned" {
      let commodity = try #require(plan.commodity).rawValue
      try #require(generated.market[commodity].quantity > 0)
      await runtime.procurementBuy(commodity)
      try await Self.travel(runtime, path: plan.path)
    }
    await Self.contact(runtime)
    let delivered = await runtime.snapshot()
    let state = try #require(delivered.commander.scriptState.instances[id])
    switch stage {
    case "partial":
      let collection = try #require(state.collections[plan.template.id])
      try #require(
        state.outcome == .active && collection.lots.count == 1
          && collection.delivered(plan.commodity!.rawValue) == 1 && !collection.complete)
    case "complete":
      try #require(state.outcome == .complete && state.completionReceipt != nil)
    default:
      try #require(state.outcome == .abandoned && state.completionReceipt != nil)
    }
    await runtime.key("0")
    try await Self.dock(runtime)
    try await runtime.save(to: save)
    return (runtime, id)
  }
}

private func procurementForgedHistory(_ original: Commander, id: UUID, field: String) throws
  -> Commander
{
  let world = try #require(original.nativeStations)
  let foreignOwner = UUID()
  func context(_ originalContext: ScriptEventContext) throws -> ScriptEventContext {
    let old = try #require(originalContext.nativeMainDock)
    let owner = field == "owner-world" ? foreignOwner : old.commanderOwner
    let station = NativeMainStationIdentity(
      world: field == "owner-world" ? foreignOwner : old.station.world,
      system: old.station.system, resource: old.station.resource)
    let actor = ActorIdentity(
      system: old.actor.system,
      visit: field == "future-visit" ? original.flightSimulation.visit + 1 : old.actor.visit,
      entity: old.actor.entity)
    var next = originalContext
    next.nativeMainDock = .init(
      station: station, actor: actor, commanderOwner: owner,
      sequence: field == "unissued-sequence" ? world.nextMainDockSequence : old.sequence,
      calendarSeconds: field == "future-dock-clock"
        ? original.scriptState.calendarSeconds + 1 : old.calendarSeconds)
    return next
  }
  var state = try #require(original.scriptState.instances[id])
  if var collection = state.collections["procurement-goods"] {
    for (sequence, lot) in collection.lots {
      let cause = try context(lot.cause)
      let committed = try context(lot.committed)
      collection.lots[sequence] = .init(
        instance: lot.instance, sequence: lot.sequence, revision: lot.revision,
        dialogue: lot.dialogue, items: lot.items, cause: cause, committed: committed)
    }
    state.collections["procurement-goods"] = collection
  }
  if let receipt = state.completionReceipt {
    let cause = try context(try #require(receipt.cause))
    let committed = try context(receipt.committed)
    state.completionReceipt = .init(
      instance: receipt.instance, definition: receipt.definition, version: receipt.version,
      digest: receipt.digest, outcome: receipt.outcome, sequence: receipt.sequence,
      causeKind: receipt.causeKind, cause: cause, committed: committed,
      revision: receipt.revision, milestones: receipt.milestones,
      destroyedEncounters: receipt.destroyedEncounters, deliveredParties: receipt.deliveredParties,
      returnedEquipment: receipt.returnedEquipment, settlementAmount: receipt.settlementAmount,
      choices: receipt.choices)
  }
  var forged = original
  forged.scriptState.instances[id] = state
  return forged
}
