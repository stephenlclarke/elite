import Foundation
import Testing

@testable import EliteCore

private struct CompleteLegacyGearFixture {
  let mission = UUID(uuidString: "71000000-0000-0000-0000-000000000001")!
  let original = UUID(uuidString: "72000000-0000-0000-0000-000000000001")!
  let absentGift = UUID(uuidString: "72000000-0000-0000-0000-000000000002")!
  let receipts: Set<String> = ["legacy-issue"]

  func commander(calendar: Bool) -> Commander {
    var commander = Commander()
    commander.equipment = []
    commander.laserMounts = LaserMounts()
    commander.missiles = 0
    var instance = ScriptInstance(
      id: mission, definition: "fixture.unavailable/legacy-gear", version: "1.0.0",
      digest: String(repeating: "b", count: 64))
    instance.revision = 1
    instance.acknowledgedThrough = 1
    instance.receipts = receipts
    instance.data = .object(["historical": .string("retained")])
    instance.journal = ["Original legacy loan retained."]
    instance.gearIssues["kit"] = .init(
      resource: "kit", kind: .module("E.C.M. System"), items: [original], loan: true,
      returnRemaining: false)
    instance.gearIssues["gift"] = .init(
      resource: "gift", kind: .missile, items: [absentGift], loan: false,
      returnRemaining: false)
    commander.scriptState.instances[mission] = instance
    commander.scriptState.nextEvent = 1
    if calendar { commander.scriptState.calendarLedger = .init(origin: .newCommander) }
    var item = OwnedGear(
      id: original, kind: .module("E.C.M. System"), slot: .module("E.C.M. System"))
    item.fittedSlot = nil
    item.issuedBy = mission
    item.sourceResource = "kit"
    item.loanOwner = mission
    item.condition = 7300
    item.modifications = ["historical-adjustment": -25]
    var legacy = LegacyOwnedEquipmentInventory()
    legacy.items = [item]
    commander.legacyOwnedEquipment = legacy
    return commander
  }

  func verify(_ commander: Commander) throws {
    #expect(
      commander.valid && commander.issuedEquipmentValid && commander.legacyOwnedEquipment == nil)
    let instance = try #require(commander.scriptState.instances[mission])
    #expect(
      instance.receipts == receipts && instance.revision == 1 && instance.acknowledgedThrough == 1)
    #expect(instance.data == .object(["historical": .string("retained")]))
    #expect(instance.journal == ["Original legacy loan retained."])
    let record = try #require(instance.gearIssues["kit"])
    #expect(record.savedGearVersion == 2 && record.items == [original] && record.status == .issued)
    #expect(record.loan && record.consumed.isEmpty)
    let item = try #require(commander.equipmentInventory?.items.first { $0.id == original })
    #expect(
      item.provenance
        == .missionIssue(
          mission: mission, resource: "kit", index: 0, packDigest: instance.digest))
    #expect(item.location == nil && item.preferredSlot == .utility(.ecm))
    #expect(item.retainedLegacyState?.conditionBasisPoints == 7300)
    #expect(item.retainedLegacyState?.modifications == ["historical-adjustment": -25])
    let gift = try #require(instance.gearIssues["gift"])
    #expect(gift.items == [absentGift] && gift.legacyMissingItems == [absentGift])
    #expect(gift.consumed.isEmpty && !gift.loan && gift.status == .issued)
    #expect(commander.equipmentInventory?.items.contains { $0.id == absentGift } == false)
    #expect(commander.missiles == 0)
  }
}

struct ScriptLegacyGearPersistenceTests {
  @Test func completeHistoricalRawCommanderMigratesOriginalRightsWithoutRewritingSourceBytes()
    async throws
  {
    let fixture = CompleteLegacyGearFixture()
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    let old = fixture.commander(calendar: false)
    let bytes = try JSONEncoder().encode(old)
    try bytes.write(to: file)
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    try fixture.verify(loaded.commander)
    #expect(loaded.commander.scriptState.calendarLedger?.origin == .inactiveLegacyMigration)
    #expect(try Data(contentsOf: file) == bytes)
    _ = await runtime.advance(delta: 0.1)
    let unavailable = await runtime.snapshot()
    try fixture.verify(unavailable.commander)
    #expect(unavailable.commander.scriptState.instances[fixture.mission]?.suspension != nil)
  }

  @Test func genuineContainer20LegacyChunksJoinThenMigrateAndReturnTheActualHeldOriginal() throws {
    let fixture = CompleteLegacyGearFixture()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let generation = "73000000-0000-0000-0000-000000000001"
    let directory = file.appendingPathExtension("missions").appendingPathComponent(generation)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let old = fixture.commander(calendar: true)
    var header = old
    header.scriptState = ScriptEngineState()
    header.contracts = ScriptContractState()
    var game = Game(executive: false)
    game.commander = old
    let encoder = ScriptValueStorage.encoder()
    // Complete historical schema-20 chunks contain v1 records directly, never rewritten v2 fields.
    let chunks = [
      "commander.json": try encoder.encode(header),
      "missions.json": try encoder.encode(old.scriptState),
      "contracts.json": try encoder.encode(old.contracts),
      "world.json": try encoder.encode(game.scriptWorldSave),
    ]
    for (name, bytes) in chunks { try bytes.write(to: directory.appendingPathComponent(name)) }
    let pointer = ScriptSavePointer(
      format: "elite-script-save", schemaVersion: 20, generation: generation,
      hashes: chunks.mapValues(ScriptPackLibrary.hash), scope: "commander",
      valueCodec: ScriptValueStorage.codec)
    let bytes = try encoder.encode(pointer)
    try bytes.write(to: file)
    let (loaded, _) = try ScriptSaveStore.read(bytes, from: file)
    try fixture.verify(loaded)
    #expect(loaded.scriptState.calendarLedger == old.scriptState.calendarLedger)
    #expect(try Data(contentsOf: file) == bytes)
    for (name, original) in chunks {
      #expect(try Data(contentsOf: directory.appendingPathComponent(name)) == original)
    }
    let inventory = try #require(loaded.equipmentInventory)
    let obligations = try loaded.equipmentIssueObligations()
    let obligation = try #require(obligations.first { $0.source.resource == "kit" })
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: loaded.nativePerformance)
    let projection = try EquipmentIssueTransactions.projectSettlement(
      operation: .returnOriginals, obligation: obligation, inventory: inventory,
      context: context, obligations: obligations)
    let budget = try loaded.equipmentFitBudget(projectedItems: projection.items)
    let quote = try EquipmentIssueTransactions.quoteSettlement(
      command: UUID(uuidString: "74000000-0000-0000-0000-000000000001")!,
      operation: .returnOriginals, obligation: obligation, inventory: inventory,
      context: context, obligations: obligations, budget: budget)
    let returned = try EquipmentIssueTransactions.applySettlement(
      quote: quote, inventory: inventory, context: context, obligations: obligations, budget: budget
    )
    let staged = try loaded.scriptState.applying(returned.receipt)
    #expect(returned.receipt.affectedItems == [fixture.original])
    #expect(!returned.inventory.items.contains { $0.id == fixture.original })
    #expect(staged.instances[fixture.mission]?.gearIssues["kit"]?.status == .returned)
    #expect(staged.instances[fixture.mission]?.receipts == fixture.receipts)
  }
}
