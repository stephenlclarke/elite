import Foundation
import Testing

@testable import L337Core

struct NativeOldV27CompatibilityTests {
  @Test(arguments: ["native-single-budget", "legacy-section", "ordinary-only"])
  func frozenOriginalV27PagesHydrateWithoutWritesAndContinueThroughTheRealCutter(format: String)
    async throws
  {
    var (game, site) = try NativePagedSalvageFixture.game(humanCargo: true)
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
    let section = try #require(profile.sections.first { $0.index == 1 })
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let identity = WreckSectionIdentity(wreck: site.identity, section: section.index)
    let owner = try #require(game.commander.equipmentOwnerID)
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
      technology: game.currentSystem.technology, ownership: .abandoned,
      manifest: [.init(commodity: .food, quantity: 120)])
    var originalProducer = game.commander.salvageLedger
    let allocatedIncident = game.commander.flightSimulation.allocateIncident()
    let operation = try #require(allocatedIncident)
    guard
      case .progress = originalProducer.advance(
        wreck: site.identity, section: section, pose: game.modelPose(of: body),
        velocity: body.physical!.velocity, angularVelocity: body.physical!.angularVelocity,
        tool: .cutter, elapsed: 0.25, operation: operation,
        conditions: NativePagedSalvageFixture.permitted, source: source)
    else { throw SaveError.invalidCommander }
    let export = try originalProducer.exportNativeSection(identity)
    let reference: UUID?
    if format == "legacy-section" {
      game.commander.salvageLedger = originalProducer
      let imported = try NativeSalvageImport(
        ledger: originalProducer, section: identity, owner: owner,
        at: game.commander.flightSimulation.physicalTime, previous: nil)
      try imported.apply(to: &game.commander)
      reference = imported.section
    } else {
      let world: [AlienStorageWorldRecord]
      if format == "native-single-budget" {
        let id = UUID()
        reference = id
        world = [
          .plan(
            .init(
              id: id, owner: owner, seed: export.seed, plan: export.plan, inspectedAt: 0,
              requiredWorkSeconds: section.workSeconds, workSeconds: export.partialWork ?? 0,
              damagedTechnology: export.damagedTechnology, depleted: export.depleted,
              destroyed: false, lastOperation: export.lastOperation, progress: export.progress))
        ]
      } else {
        reference = nil
        world = []
        game.commander.salvageLedger = originalProducer
      }
      try game.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: world.isEmpty ? 0 : 1, world: world,
          sources: [],
          attachments: [], upgrades: [], receipts: [], commands: []))
    }
    let oldSnapshot = try #require(game.commander.alienStorageState?.current.snapshot)
    // These exact old records are generated before any current native inspection/work.
    // The independent oracle rejects every new native tag rather than roundtripping it.
    let (oldRoot, oldPages) = try FrozenV27SalvageFormat.encode(oldSnapshot)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let pointerBytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    #expect(pointer.schemaVersion == 27)
    let pointerEncoder = JSONEncoder()
    pointerEncoder.outputFormatting = [.sortedKeys]
    let observedEncoding = try pointerEncoder.encode(
      FrozenV27SavePointer(
        generation: pointer.generation, hashes: pointer.hashes))
    #expect(
      observedEncoding == pointerBytes)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let store = try AlienStoragePageStore(directory: directory)
    let observedRoot = try store.readGenerationRoot()
    #expect(observedRoot == oldRoot)
    #expect(pointer.hashes["alien-root.json"] == ScriptPackLibrary.hash(oldRoot))
    #expect(saved.commander.savedAlienStorageReference?.rootHash == ScriptPackLibrary.hash(oldRoot))
    for (hash, bytes) in oldPages {
      let observedPage = try store.readPage(hash: hash)
      #expect(observedPage == bytes)
    }
    let beforeLoad = try files(in: folder)
    try await runtime.load(from: file, persistMigrations: false)
    var loaded = await runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    #expect(loaded.commander.alienStorageState?.current.snapshot == oldSnapshot)
    let observedFiles = try files(in: folder)
    #expect(observedFiles == beforeLoad)
    #expect(loaded.nativeSalvageWork == nil)
    let oldOrdinary = loaded.commander.salvageLedger
    let observedCutterResult = loaded.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult)
    if let reference {
      let hot = try #require(loaded.nativeSalvageWork)
      #expect(hot.cycle.inspection.id == reference)
      #expect(abs(hot.cycle.currentWorkSeconds - 0.35) < 1e-12)
      #expect(hot.cycle.releases == 0 && hot.cycle.progress.nextLot == export.progress.nextLot)
      #expect(hot.plan == export.plan && hot.seed == export.seed)
      #expect(loaded.commander.salvageLedger == oldOrdinary)
      let originalRecord = try #require(oldSnapshot.world.first)
      #expect(
        loaded.commander.alienStorageState?.current.snapshot.world.contains(originalRecord) == true)
      let observedWorkFlush = loaded.flushNativeSalvageWork()
      #expect(observedWorkFlush)
      let continuation = GameRuntime(game: loaded)
      try await continuation.save(to: file)
      let continued = await continuation.snapshot()
      try await continuation.load(from: file, persistMigrations: false)
      let reloaded = await continuation.snapshot()
      #expect(reloaded.commander == continued.commander && reloaded.bodies == continued.bodies)
      #expect(
        reloaded.commander.alienStorageState?.current.salvage.native.works[reference] == hot.cycle)
      // The authenticated old generation stays byte-identical after a new generation is saved.
      for (relative, bytes) in beforeLoad
      where relative.hasPrefix(file.lastPathComponent + ".missions/" + pointer.generation + "/") {
        let observedFileBytes = try Data(contentsOf: folder.appendingPathComponent(relative))
        #expect(observedFileBytes == bytes)
      }
    } else {
      #expect(loaded.nativeSalvageWork == nil)
      #expect(loaded.commander.salvageLedger.progress(identity) == 0.35)
      #expect(loaded.commander.alienStorageState?.current.snapshot == oldSnapshot)
    }
  }

  private func files(in folder: URL) throws -> [String: Data] {
    var result: [String: Data] = [:]
    let enumerator = try #require(
      FileManager.default.enumerator(
        at: folder, includingPropertiesForKeys: [.isRegularFileKey]))
    for case let url as URL in enumerator {
      if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
        result[String(url.path.dropFirst(folder.path.count + 1))] = try Data(contentsOf: url)
      }
    }
    return result
  }
}
