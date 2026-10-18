import Foundation
import Testing

@testable import EliteCore

struct ScriptFinancePersistenceTests {
  @Test(arguments: [false, true])
  func currentSchemaRoundtripRetainsDebtAndOptionalRealEMPDevice(emp: Bool) async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    var game = await runtime.snapshot()
    if emp {
      try game.commander.grantEquipment(
        Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
        provenance: .grant("Finance save compatibility fixture"))
      game.commander.mirrorFittedEquipment()
    }
    let writer = GameRuntime(game: game, saveURL: fixture.storage.url)
    try await writer.save(to: fixture.storage.url)
    let saved = await writer.snapshot()
    let bytes = try Data(contentsOf: fixture.storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 26)
    let (stored, world) = try ScriptSaveStore.read(bytes, from: fixture.storage.url)
    #expect(stored == saved.commander && world.consistent(with: stored))
    let reader = GameRuntime(game: financeLibrary(fixture.pack))
    try await reader.load(from: fixture.storage.url, persistMigrations: false)
    let loaded = await reader.snapshot()
    #expect(loaded.commander == saved.commander && loaded.commander.valid)
    #expect(loaded.commander.usesEMPSaveVersion == emp)
    #expect(loaded.nativeStationRuntimeEpoch != saved.nativeStationRuntimeEpoch)
    #expect(loaded.commander.scriptState.financeLedger == saved.commander.scriptState.financeLedger)
    // A fresh native review uses rebound live authority; historical receipt epochs are unchanged.
    try await ScriptFinanceTestFixture.confirm(reader)
    let repaid = await reader.snapshot()
    let receipt = try #require(repaid.commander.scriptState.financeLedger?.records.first)
    #expect(receipt.status == .paid)
  }

  @Test(arguments: [false, true])
  func currentNonFinanceRoundtripDoesNotInventAnObligation(emp: Bool) async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    var instance = ScriptInstance(
      id: UUID(), definition: "example/innocent-data", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.data = .object(["financeLedger": .string("fictional ledger in authored data")])
    game.commander.scriptState.instances[instance.id] = instance
    if emp {
      try game.commander.grantEquipment(
        Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
        provenance: .grant("Old schema fixture"))
      game.commander.mirrorFittedEquipment()
    }
    let writer = GameRuntime(game: game)
    try await writer.save(to: fixture.storage.url)
    let bytes = try Data(contentsOf: fixture.storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 26)
    let saved = await writer.snapshot()
    let (stored, world) = try ScriptSaveStore.read(bytes, from: fixture.storage.url)
    #expect(stored == saved.commander && world.consistent(with: stored))
    let reader = GameRuntime()
    try await reader.load(from: fixture.storage.url, persistMigrations: false)
    let loaded = await reader.snapshot()
    #expect(loaded.commander.scriptState.financeLedger == nil)
    #expect(loaded.commander.scriptState.instances[instance.id]?.data == instance.data)
    #expect(loaded.commander.usesEMPSaveVersion == emp)
  }

  @Test(arguments: [false, true])
  func genuinePreDriveNonFinance21And22RetainAuthoredDataAndDevice(emp: Bool) throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    var historical = Game(executive: false)
    historical.screen = .status
    historical.commander = try PreDriveCommanderSaveFixture.commander(emp: emp)
    historical.commander.name = emp ? "HISTORY22" : "HISTORY21"
    historical.commander.credits = 4567
    historical.commander.fuel = 23
    historical.commander.cargo[0] = 2
    historical.ensureScriptCalendar(origin: .newCommander)
    var instance = ScriptInstance(
      id: UUID(), definition: "historical/innocent-data", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.data = .object(["financeLedger": .string("fictional ledger in authored data")])
    historical.commander.scriptState.instances[instance.id] = instance
    let original = historical.commander
    try #require(original.scriptState.financeLedger == nil)
    try #require(!original.usesModularDriveSaveVersion && !original.usesEconomyMiningSaveVersion)
    try ScriptSaveStore.write(
      commander: original, world: historical.scriptWorldSave, to: fixture.storage.url)
    let bytes = try Data(contentsOf: fixture.storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (emp ? 22 : 21) && pointer.scope == "commander")
    let files = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    let (loaded, world) = try ScriptSaveStore.read(bytes, from: fixture.storage.url)
    try PreDriveCommanderSaveFixture.verifyMigration(from: original, to: loaded)
    #expect(world.valid && world.consistent(with: loaded))
    #expect(loaded.scriptState.financeLedger == nil && loaded.usesEMPSaveVersion == emp)
    #expect(loaded.scriptState.instances[instance.id]?.data == instance.data)
    #expect(
      loaded.fittedEquipment(at: .utility(.empPirateBlaster))
        == original.fittedEquipment(at: .utility(.empPirateBlaster)))
    let afterFiles = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    #expect(afterFiles == files)
  }

  @Test(arguments: [false, true], [false, true])
  func genuinePreDriveFinance23RetainsOriginalDebtAndReceipts(paid: Bool, emp: Bool) throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    var historical = Game(executive: false)
    historical.screen = .status
    historical.commander = try PreDriveCommanderSaveFixture.commander(emp: emp)
    historical.commander.name = "HISTORY23"
    historical.commander.credits = 4567
    historical.commander.fuel = 23
    historical.commander.cargo[0] = 2
    historical.ensureScriptCalendar(origin: .newCommander)
    let owner = try #require(historical.commander.equipmentOwnerID)
    let terms = ScriptFinanceDefinition(
      id: "historical-loan", profile: "fixed-principal-v1", creditor: "workshop",
      title: "Retained historical loan", principal: 777, galaxy: 0, system: 7)
    let station = terms.station(owner: owner)
    // These are retained historical facts, not fresh native arrival authority.
    let dock = NativeMainStationDockReceipt(
      station: station, actor: .init(system: station.system, visit: 1, entity: 1),
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    let cause = ScriptEventContext(
      galaxy: 0, system: 7, docked: true, mainStation: true, revision: 0,
      frameSeconds: 0, localSeconds: 0, flightSeconds: 0, calendarSeconds: 0,
      transitSeconds: 0, playerPosition: nil, nativeMainDock: dock)
    let source = ScriptFinanceSource(
      instance: UUID(), definition: "historical/finance", version: "1.0.0",
      digest: String(repeating: "b", count: 64), sequence: 1, cause: cause)
    let identity = source.identity(owner: owner, loan: terms.id)
    var record = ScriptFinanceRecord(id: identity, terms: terms, source: source, createdRevision: 1)
    let cash = historical.commander.credits
    record.receipts = [
      .init(
        id: ScriptFinanceReceipt.identity(identity, revision: 2), token: UUID(),
        obligation: identity,
        operation: .borrow, revision: 2, beforeCash: cash, afterCash: cash + terms.principal,
        beforePrincipal: 0, afterPrincipal: terms.principal, amount: terms.principal,
        dock: dock, calendarSeconds: 0, epoch: UUID())
    ]
    if paid {
      record.receipts.append(
        .init(
          id: ScriptFinanceReceipt.identity(identity, revision: 3), token: UUID(),
          obligation: identity,
          operation: .repay, revision: 3, beforeCash: cash + terms.principal, afterCash: cash,
          beforePrincipal: terms.principal, afterPrincipal: 0, amount: terms.principal,
          dock: dock, calendarSeconds: 0, epoch: UUID()))
    }
    var ledger = ScriptFinanceLedger(owner: owner)
    ledger.revision = paid ? 3 : 2
    ledger.records = [record]
    historical.commander.scriptState.nextEvent = 1
    historical.commander.scriptState.financeLedger = ledger
    historical.commander.credits = paid ? cash : cash + terms.principal
    var stations = try NativeStationWorld(owner: owner)
    stations.mainStations = [station]
    stations.nextMainDockSequence = 2
    historical.commander.nativeStations = stations
    historical.commander.scriptState.stationResources[station.key] = .init(
      identity: station.resource, galaxy: station.system.galaxy, system: station.system.system)
    let original = historical.commander
    let originalEMP = original.fittedEquipment(at: .utility(.empPirateBlaster))
    #expect(original.usesEMPSaveVersion == emp)
    try #require(
      original.valid && original.financeStateValid && ledger.valid(engine: original.scriptState))
    try #require(!original.usesModularDriveSaveVersion && !original.usesEconomyMiningSaveVersion)
    try ScriptSaveStore.write(
      commander: original, world: historical.scriptWorldSave, to: fixture.storage.url)
    let bytes = try Data(contentsOf: fixture.storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 23 && pointer.scope == "commander")
    let files = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    let (loaded, world) = try ScriptSaveStore.read(bytes, from: fixture.storage.url)
    try PreDriveCommanderSaveFixture.verifyMigration(from: original, to: loaded)
    #expect(loaded.usesEMPSaveVersion == emp)
    #expect(loaded.fittedEquipment(at: .utility(.empPirateBlaster)) == originalEMP)
    #expect(world.valid && world.consistent(with: loaded))
    #expect(loaded.scriptState.financeLedger == ledger && loaded.credits == original.credits)
    #expect(loaded.scriptState.financeLedger?.records.first?.remaining == (paid ? 0 : 777))
    #expect(
      loaded.scriptState.financeLedger?.records.first?.status == (paid ? .paid : .outstanding))
    #expect(loaded.scriptState.financeLedger?.records.first?.receipts == record.receipts)
    #expect(loaded.nativeStations?.currentMainDock == nil)
    let afterFiles = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    #expect(afterFiles == files)
  }

  @Test func acceptedLiabilitySurvivesValidatedAbsentParentAndMissingLibrary() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    var retained = await runtime.snapshot()
    let original = try #require(retained.commander.scriptState.financeLedger)
    // An explicitly absent-parent save tests independent custody; no cleanup API is simulated.
    retained.commander.scriptState.instances.removeAll()
    retained.scriptPacks = []
    try #require(retained.commander.valid)
    let writer = GameRuntime(game: retained, saveURL: fixture.storage.url)
    try await writer.save(to: fixture.storage.url)
    let reader = GameRuntime()
    try await reader.load(from: fixture.storage.url, persistMigrations: false)
    #expect(await reader.snapshot().commander.scriptState.financeLedger == original)
    #expect(await reader.snapshot().commander.scriptState.instances.isEmpty == true)
    #expect(await reader.snapshot().scriptPacks.isEmpty == true)
    try await ScriptFinanceTestFixture.confirm(reader)
    #expect(await reader.snapshot().commander.scriptState.financeLedger?.records[0].status == .paid)
  }

  @Test(arguments: ["borrow", "repay", "decline"])
  func actualFailedWriterPreservesWholeCommanderAndEveryPriorFile(action: String) async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    if action == "repay" { try await ScriptFinanceTestFixture.confirm(runtime) }
    let page = try await ScriptFinanceTestFixture.review(runtime)
    await runtime.scriptPageKey("right", expected: page)
    if action == "decline" { await runtime.scriptPageKey("right", expected: page) }
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    try fixture.storage.blockWriter()
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(try ScriptFinanceTestFixture.files(fixture.storage.backup) == files)
    try fixture.storage.restoreWriter()
    // Same retained page can be deliberately retried after the actual save failure.
    await runtime.scriptPageKey("return", expected: page)
    let committed = await runtime.snapshot().commander
    #expect(committed != before && committed.valid)
    #expect(
      committed.scriptState.financeLedger?.receiptCount
        == (before.scriptState.financeLedger?.receiptCount ?? 0) + 1)
    let current = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    for (path, bytes) in files where path != "commander.json" {
      #expect(current[path] == bytes)
    }
  }

  @Test(arguments: [21, 22])
  func downgradeCannotHideFinanceInAnOlderVersion(schema: Int) async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    _ = try await fixture.runtime()
    let bytes = try Data(contentsOf: fixture.storage.url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let downgraded = ScriptSavePointer(
      format: pointer.format, schemaVersion: schema, generation: pointer.generation,
      hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    #expect(throws: SaveError.invalidCommander) {
      try ScriptSaveStore.read(
        ScriptValueStorage.encoder().encode(downgraded), from: fixture.storage.url)
    }
    #expect(try Data(contentsOf: fixture.storage.url) == bytes)
  }

  @Test(arguments: ["source-dock", "payment-dock", "source", "owner", "amount", "duplicate"])
  func foreignSourceDocksAndMalformedReceiptsCannotBecomeCommanderState(field: String) async throws
  {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    let original = await runtime.snapshot().commander
    let ledger = try #require(original.scriptState.financeLedger)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
    var records = try #require(object["records"] as? [[String: Any]])
    var receipts = try #require(records[0]["receipts"] as? [[String: Any]])
    switch field {
    case "source-dock":
      var source = try #require(records[0]["source"] as? [String: Any])
      var cause = try #require(source["cause"] as? [String: Any])
      var dock = try #require(cause["nativeMainDock"] as? [String: Any])
      try makeFinanceDockForeign(&dock)
      // This receipt still satisfies its own internal validity; it belongs to another borrower.
      #expect(
        try JSONDecoder().decode(
          NativeMainStationDockReceipt.self, from: JSONSerialization.data(withJSONObject: dock)
        ).valid)
      cause["nativeMainDock"] = dock
      source["cause"] = cause
      records[0]["source"] = source
    case "payment-dock":
      var dock = try #require(receipts[0]["dock"] as? [String: Any])
      try makeFinanceDockForeign(&dock)
      receipts[0]["dock"] = dock
    case "source":
      var source = try #require(records[0]["source"] as? [String: Any])
      source["digest"] = String(repeating: "b", count: 64)
      records[0]["source"] = source
    case "owner": object["owner"] = UUID().uuidString
    case "amount": receipts[0]["amount"] = 1
    default: receipts.append(receipts[0])
    }
    records[0]["receipts"] = receipts
    object["records"] = records
    var forged = original
    forged.scriptState.financeLedger = try JSONDecoder().decode(
      ScriptFinanceLedger.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(!forged.valid && original.valid)
    #expect(await runtime.snapshot().commander == original)
  }

  @Test func reservedFieldsRejectHeadersAndRawStateButAllowAuthoredWords() throws {
    for part in [ScriptFinanceVersionedSave.Part.commander, .missions] {
      let forbidden: [String: Any] =
        part == .missions
        ? ["financeLedger": NSNull()] : ["savedScriptState": ["financeLedger": NSNull()]]
      #expect(throws: SaveError.invalidCommander) {
        try ScriptFinanceVersionedSave.rejectFields(
          JSONSerialization.data(withJSONObject: forbidden), part: part)
      }
    }
    let innocent: [String: Any] = ["instances": ["data": ["financeLedger": "fiction"]]]
    try ScriptFinanceVersionedSave.rejectFields(
      JSONSerialization.data(withJSONObject: innocent), part: .missions)
  }

  @Test func actualVersionedReaderRejectsFinanceHiddenInItsHeader() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    let before = await runtime.snapshot().commander
    let pointer = try JSONDecoder().decode(
      ScriptSavePointer.self, from: Data(contentsOf: fixture.storage.url))
    let directory = try ScriptSaveStore.generationDirectory(
      pointer.generation, from: fixture.storage.url)
    let file = directory.appendingPathComponent("commander.json")
    var header = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    header["savedScriptState"] = ["financeLedger": NSNull()]
    let bytes = try JSONSerialization.data(withJSONObject: header)
    try bytes.write(to: file)
    var hashes = pointer.hashes
    hashes["commander.json"] = ScriptPackLibrary.hash(bytes)
    let forged = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
      hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    #expect(throws: SaveError.invalidCommander) {
      try ScriptSaveStore.read(
        ScriptValueStorage.encoder().encode(forged), from: fixture.storage.url)
    }
    #expect(await runtime.snapshot().commander == before)
  }

  @Test func rawCommanderAndUnversionedGameLoadCannotDropFinancialCustody() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    let commander = await runtime.snapshot().commander
    try #require(commander.valid && !commander.usesEMPSaveVersion)
    var game = Game(executive: false)
    let before = game.commander
    let loaded = game.load(commander)
    #expect(!loaded && game.commander == before)
    let raw = fixture.storage.root.appendingPathComponent("raw-finance.json")
    try JSONEncoder().encode(commander).write(to: raw)
    let reader = GameRuntime()
    let original = await reader.snapshot().commander
    await #expect(throws: (any Error).self) {
      try await reader.load(from: raw, persistMigrations: false)
    }
    #expect(await reader.snapshot().commander == original)
  }

  @Test func oversizedReceiptsRejectBeforeAnInvalidReceiptCanDecode() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    let record = try #require(
      await runtime.snapshot().commander.scriptState.financeLedger?.records.first)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
    object["receipts"] = Array(
      repeating: "must not decode", count: ScriptFinanceLedger.maximumReceipts + 1)
    do {
      _ = try JSONDecoder().decode(
        ScriptFinanceRecord.self, from: JSONSerialization.data(withJSONObject: object))
      Issue.record("Oversized finance receipts decoded")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.debugDescription == "Finance receipt limit exceeded.")
    }
  }

  @Test func oversizedRecordArrayRejectsBeforeAnInvalidChildCanDecode() throws {
    let object: [String: Any] = [
      "owner": UUID().uuidString, "revision": 1,
      "records": Array(repeating: "must not decode", count: ScriptFinanceLedger.maximumRecords + 1),
    ]
    do {
      _ = try JSONDecoder().decode(
        ScriptFinanceLedger.self, from: JSONSerialization.data(withJSONObject: object))
      Issue.record("Oversized finance array decoded")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.debugDescription == "Finance record limit exceeded.")
    }
  }
}

private func financeLibrary(_ pack: ScriptPack) -> Game {
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  return game
}

private func makeFinanceDockForeign(_ dock: inout [String: Any]) throws {
  let foreign = UUID().uuidString
  var station = try #require(dock["station"] as? [String: Any])
  station["world"] = foreign
  dock["station"] = station
  dock["commanderOwner"] = foreign
}
