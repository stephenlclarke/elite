import Darwin
import Foundation
import Testing

@testable import EliteCore

/// These are native persistence tests of checked storage fixtures. The fixture
/// does not claim that its modules were obtained by a native scoop or PLUGH fit.
struct AlienCommanderSaveTests {
  private func directory() throws -> URL {
    let path = FileManager.default.temporaryDirectory.path
    let resolved = path.withCString { realpath($0, nil) }
    let physical = try #require(resolved)
    defer { free(physical) }
    return URL(fileURLWithPath: String(cString: physical), isDirectory: true)
      .appendingPathComponent("alien-commander-" + UUID().uuidString, isDirectory: true)
  }

  private func game(_ fixture: AlienStorageTestFixture) throws -> Game {
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.initializeEquipment(
      owner: AlienStorageTestFixture.owner, hull: AlienStorageTestFixture.hull,
      legacy: false, allocatingItemIDs: { UUID() })
    try game.commander.replaceAlienStorage(with: fixture.snapshot)
    return game
  }

  private func pointer(_ url: URL) throws -> ScriptSavePointer {
    try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: url))
  }

  @Test func actualRuntimeSaveHydratesBeforeValidationAndPublishesOnlyASmallReference()
    async throws
  {
    let directory = try directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    var fixture = AlienStorageTestFixture()
    let item = try fixture.acquire(kind: .energyCapacity)
    try fixture.fit(item)
    let initial = try game(fixture)
    try #require(initial.commander.valid && initial.requiresScriptDurability)
    let runtime = GameRuntime(game: initial)
    let before = await runtime.snapshot()
    try #require(before.commander.savedAlienStorageReference == nil)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let reference = try #require(saved.commander.savedAlienStorageReference)
    #expect(reference.owner == AlienStorageTestFixture.owner)
    #expect(saved.commander.alienStorageState?.current.snapshot == fixture.snapshot)
    #expect(saved.commander.alienStorageState?.durable?.snapshot == fixture.snapshot)
    #expect(before.commander.savedAlienStorageReference == nil)
    #expect(before.commander.alienStorageState?.durable == nil)
    let pointer = try pointer(file)
    #expect(pointer.schemaVersion == 27 && pointer.hashes.count == 5)
    #expect(pointer.hashes["alien-root.json"] == reference.rootHash)
    #expect(try Data(contentsOf: file).count < 262_144)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let headerData = try Data(contentsOf: generation.appendingPathComponent("commander.json"))
    let header = try #require(JSONSerialization.jsonObject(with: headerData) as? [String: Any])
    #expect(header["savedAlienStorageReference"] != nil)
    #expect(header["alienStorageState"] == nil && header["alienStorageCache"] == nil)
    #expect(headerData.count < 4_194_304)
    let unhydrated = try ScriptValueStorage.decoder(typed: true).decode(
      Commander.self, from: headerData)
    #expect(!unhydrated.alienStorageStateValid && !unhydrated.valid)
    let restored = GameRuntime(game: Game(executive: false))
    try await restored.load(from: file, persistMigrations: false)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.valid && loaded.commander == saved.commander)
    #expect(loaded.market == saved.market)
    #expect(loaded.commander.alienStorageState?.current.snapshot == fixture.snapshot)
    var rawTarget = Game(executive: false)
    let rawAccepted = rawTarget.load(saved.commander)
    #expect(!rawAccepted)
  }

  @Test func cacheUpdatesPreserveOldCopiesAndRefuseOwnerHistoryAndRevisionChanges() throws {
    var fixture = AlienStorageTestFixture()
    let attachment = try fixture.acquire(kind: .energyCapacity)
    var commander = try game(fixture).commander
    let original = commander
    let upgrade = try fixture.acquire(kind: .energyCapacity, upgrade: true)
    try fixture.apply(upgrade, to: attachment)
    try commander.replaceAlienStorage(with: fixture.snapshot)
    #expect(commander != original && original.alienStorageState?.current.revision == 1)
    #expect(commander.alienStorageState?.current.revision == 3 && commander.valid)
    let before = commander
    #expect(throws: AlienStorageError.self) {
      try commander.replaceAlienStorage(with: original.alienStorageState!.current.snapshot)
    }
    #expect(commander == before)
    var foreign = Commander()
    try foreign.prepareEquipment(legacy: false)
    let foreignBefore = foreign
    #expect(throws: AlienStorageError.self) {
      try foreign.replaceAlienStorage(with: fixture.snapshot)
    }
    #expect(foreign == foreignBefore)
    var orphan = before
    orphan.savedAlienStorageReference = .init(
      owner: fixture.snapshot.owner, revision: fixture.snapshot.revision,
      worldRevision: fixture.snapshot.worldRevision, rootHash: String(repeating: "0", count: 64))
    #expect(!orphan.alienStorageStateValid && !orphan.valid)
  }

  @Test func rawAndOlderHeadersRefuseAlienFieldsEvenWhenNull() async throws {
    for key in [
      "savedAlienStorageReference", "alienStorageState", "alienStorageCache",
      "savedAlienStorageState",
    ] {
      var raw = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(Commander())) as? [String: Any])
      raw[key] = NSNull()
      let bytes = try JSONSerialization.data(withJSONObject: raw)
      #expect(throws: SaveError.self) { try AlienStorageVersionedSave.rejectFields(bytes) }
      for version in [21, 22, 23, 24, 25, 26] {
        #expect(throws: SaveError.self) {
          try AlienStorageVersionedSave.validateHeader(bytes, schema: version)
        }
      }
      let directory = try directory()
      defer { try? FileManager.default.removeItem(at: directory) }
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let file = directory.appendingPathComponent("commander.json")
      try bytes.write(to: file)
      let runtime = GameRuntime(game: Game(executive: false))
      let before = await runtime.snapshot()
      await #expect(throws: SaveError.self) { try await runtime.load(from: file) }
      let after = await runtime.snapshot()
      #expect(after.commander == before.commander && after.bodies == before.bodies)
    }
  }

  @Test func actualPageCorruptionAndMissingRootRefuseWholeRuntimeLoad() async throws {
    let directory = try directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    var fixture = AlienStorageTestFixture()
    _ = try fixture.acquire(kind: .shieldRecharge)
    let writer = GameRuntime(game: try game(fixture))
    try await writer.save(to: file)
    let pointer = try pointer(file)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let pages = generation.appendingPathComponent("alien-pages", isDirectory: true)
    let enumerator = try #require(
      FileManager.default.enumerator(at: pages, includingPropertiesForKeys: nil))
    let page = try #require(
      enumerator.allObjects.compactMap { $0 as? URL }.first {
        $0.pathExtension == "json"
      })
    let original = try Data(contentsOf: page)
    try Data("{}".utf8).write(to: page)
    let reader = GameRuntime(game: Game(executive: false))
    let before = await reader.snapshot()
    await #expect(throws: (any Error).self) {
      try await reader.load(from: file, persistMigrations: false)
    }
    var after = await reader.snapshot()
    #expect(after.commander == before.commander && after.market == before.market)
    try original.write(to: page)
    let root = generation.appendingPathComponent("alien-root.json")
    try FileManager.default.removeItem(at: root)
    await #expect(throws: (any Error).self) {
      try await reader.load(from: file, persistMigrations: false)
    }
    after = await reader.snapshot()
    #expect(after.commander == before.commander && after.bodies == before.bodies)
  }

  @Test func failedActualPointerPublicationPreservesDirtyCacheAndPreviousSave() async throws {
    let directory = try directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    var fixture = AlienStorageTestFixture()
    let attachment = try fixture.acquire(kind: .energyCapacity)
    let original = GameRuntime(game: try game(fixture))
    try await original.save(to: file)
    let saved = await original.snapshot()
    let bytes = try Data(contentsOf: file)
    try fixture.fit(attachment)
    var dirty = saved
    try dirty.commander.replaceAlienStorage(with: fixture.snapshot)
    let runtime = GameRuntime(game: dirty)
    let before = await runtime.snapshot()
    let raced = directory.appendingPathComponent("registered.json")
    _ = try await runtime.registerNewCommanderDestination(at: raced)
    // Another writer wins after registration. Its complete existing generation
    // remains readable; our exclusive final rename must not replace that pointer.
    try FileManager.default.copyItem(
      at: file.appendingPathExtension("missions"), to: raced.appendingPathExtension("missions"))
    try bytes.write(to: raced)
    let registered = await runtime.snapshot()
    await #expect(throws: (any Error).self) { try await runtime.save(to: raced) }
    let after = await runtime.snapshot()
    #expect(after.commander == registered.commander && after.bodies == registered.bodies)
    #expect(after.pendingNewSaveDestination == registered.pendingNewSaveDestination)
    #expect(try Data(contentsOf: raced) == bytes)
    let oldReader = GameRuntime(game: Game(executive: false))
    try await oldReader.load(from: raced, persistMigrations: false)
    let oldLoaded = await oldReader.snapshot()
    #expect(oldLoaded.commander == saved.commander)
    #expect(
      after.commander.savedAlienStorageReference == saved.commander.savedAlienStorageReference)
    #expect(after.commander.alienStorageState?.current.snapshot == fixture.snapshot)
    #expect(
      after.commander.alienStorageState?.durable?.snapshot
        == saved.commander.alienStorageState?.durable?.snapshot)
    #expect(try Data(contentsOf: file) == bytes)
    try await runtime.save(to: file)
    let committed = await runtime.snapshot()
    #expect(committed.commander.alienStorageState?.current.snapshot == fixture.snapshot)
    #expect(committed.commander.alienStorageState?.durable?.snapshot == fixture.snapshot)
    #expect(
      committed.commander.savedAlienStorageReference != saved.commander.savedAlienStorageReference)
    let restored = GameRuntime(game: Game(executive: false))
    try await restored.load(from: file, persistMigrations: false)
    let loaded = await restored.snapshot()
    #expect(loaded.commander == committed.commander)
    #expect(before.commander.alienStorageState?.current.snapshot == fixture.snapshot)
  }

  @Test func actualNativeSaveExceedsOldHistoryLimitsWithOnePhysicalModule() async throws {
    let directory = try directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    var fixture = AlienStorageTestFixture()
    let kind = AlienModuleKind.energyCapacity
    let attachment = try fixture.acquire(kind: kind)
    for _ in 0..<16_385 {
      let upgrade = try fixture.acquire(kind: kind, upgrade: true)
      try fixture.apply(upgrade, to: attachment)
    }
    try fixture.fit(attachment)
    let runtime = GameRuntime(game: try game(fixture))
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let pointer = try pointer(file)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let pages = generation.appendingPathComponent("alien-pages", isDirectory: true)
    let enumerator = try #require(
      FileManager.default.enumerator(at: pages, includingPropertiesForKeys: nil))
    let pageURLs = enumerator.allObjects.compactMap { $0 as? URL }.filter {
      $0.pathExtension == "json"
    }
    let total = try pageURLs.reduce(0) { $0 + (try Data(contentsOf: $1).count) }
    #expect(total > 4_194_304 && pointer.hashes.count == 5)
    #expect(try Data(contentsOf: file).count < 262_144)
    #expect(
      try Data(contentsOf: generation.appendingPathComponent("commander.json")).count < 4_194_304)
    let restored = GameRuntime(game: Game(executive: false))
    try await restored.load(from: file, persistMigrations: false)
    let loaded = await restored.snapshot()
    let state = try #require(loaded.commander.alienStorageState)
    #expect(loaded.commander == saved.commander && loaded.commander.valid)
    #expect(state.current.snapshot == fixture.snapshot)
    #expect(state.current.snapshot.receipts.count == 16_385)
    #expect(state.current.snapshot.attachments.count == 1)
    #expect(state.current.summaries(for: AlienStorageTestFixture.hull)[kind]?.count == 1)
    #expect(state.current.snapshot.attachments.first?.id == attachment)
    #expect(state.reference == saved.commander.savedAlienStorageReference)
  }

  @Test func actualHeaderTamperingDowngradeAndPageSymlinkPreserveTheReader() async throws {
    let directory = try directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    var fixture = AlienStorageTestFixture()
    _ = try fixture.acquire(kind: .shieldCapacity)
    let writer = GameRuntime(game: try game(fixture))
    try await writer.save(to: file)
    let pointerBytes = try Data(contentsOf: file)
    let originalPointer = try pointer(file)
    let generation = try ScriptSaveStore.generationDirectory(originalPointer.generation, from: file)
    let headerURL = generation.appendingPathComponent("commander.json")
    let headerBytes = try Data(contentsOf: headerURL)
    let originalHeader = try #require(
      JSONSerialization.jsonObject(with: headerBytes) as? [String: Any])
    let reader = GameRuntime(game: Game(executive: false))
    let before = await reader.snapshot()
    for change in 0..<7 {
      var header = originalHeader
      var reference = try #require(header["savedAlienStorageReference"] as? [String: Any])
      var schema = 27
      var hashes = originalPointer.hashes
      switch change {
      case 0: header["savedAlienStorageReference"] = NSNull()
      case 1:
        reference["owner"] = UUID().uuidString
        header["savedAlienStorageReference"] = reference
      case 2:
        reference["rootHash"] = String(repeating: "0", count: 64)
        header["savedAlienStorageReference"] = reference
      case 3: header["alienStorageState"] = NSNull()
      case 4:
        schema = 26
        hashes["alien-root.json"] = nil
      case 5: header["savedAlienStorageReference"] = nil
      default:
        reference["revision"] = 999
        header["savedAlienStorageReference"] = reference
      }
      let changed = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
      try changed.write(to: headerURL)
      hashes["commander.json"] = ScriptPackLibrary.hash(changed)
      let pointer = ScriptSavePointer(
        format: originalPointer.format, schemaVersion: schema,
        generation: originalPointer.generation, hashes: hashes, scope: originalPointer.scope,
        valueCodec: originalPointer.valueCodec)
      try JSONEncoder().encode(pointer).write(to: file)
      await #expect(throws: (any Error).self) {
        try await reader.load(from: file, persistMigrations: false)
      }
      let after = await reader.snapshot()
      #expect(after.commander == before.commander && after.bodies == before.bodies)
      #expect(after.market == before.market && after.screen == before.screen)
    }
    try headerBytes.write(to: headerURL)
    try pointerBytes.write(to: file)
    let pages = generation.appendingPathComponent("alien-pages", isDirectory: true)
    let enumerator = try #require(
      FileManager.default.enumerator(at: pages, includingPropertiesForKeys: nil))
    let page = try #require(
      enumerator.allObjects.compactMap { $0 as? URL }.first { $0.pathExtension == "json" })
    let backup = page.appendingPathExtension("original")
    try FileManager.default.moveItem(at: page, to: backup)
    try FileManager.default.createSymbolicLink(at: page, withDestinationURL: backup)
    await #expect(throws: (any Error).self) {
      try await reader.load(from: file, persistMigrations: false)
    }
    let refused = await reader.snapshot()
    #expect(refused.commander == before.commander && refused.bodies == before.bodies)
    try FileManager.default.removeItem(at: page)
    try FileManager.default.moveItem(at: backup, to: page)
    try await reader.load(from: file, persistMigrations: false)
    let loaded = await reader.snapshot()
    let saved = await writer.snapshot()
    #expect(loaded.commander == saved.commander && loaded.commander.valid)
  }
}
