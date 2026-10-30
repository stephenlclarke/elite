import Foundation
import Testing

@testable import L337Core

struct NativePreinspectionRuntimeTests {
  @Test(arguments: ["raw-cutter", "raw-mining", "inspected-cutter", "inspected-mining"])
  func actualOldUnplannedPartialSurvivesFullOrdinaryPoolsAndTheFirstNewCutterObservation(
    mode: String
  ) async throws {
    var (game, site) = try NativePagedSalvageFixture.game(requireReserved: mode.hasSuffix("mining"))
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let tool: SalvageTool = mode.hasSuffix("mining") ? .miningLaser : .cutter
    let inspected = mode.hasPrefix("inspected")
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0,
      economy: game.currentSystem.economy, technology: game.currentSystem.technology,
      ownership: .abandoned)
    var operation: UInt64 = 0
    for section in profile.sections {
      let allocatedIncident = game.commander.flightSimulation.allocateIncident()
      operation = try #require(allocatedIncident)
      let result = game.commander.salvageLedger.advance(
        wreck: site.identity, section: section,
        pose: game.modelPose(of: body), velocity: body.physical!.velocity,
        angularVelocity: body.physical!.angularVelocity, tool: tool,
        elapsed: 0.25, operation: operation, conditions: NativePagedSalvageFixture.permitted)
      #expect(result == .progress(seconds: 0.25, required: section.workSeconds))
      if inspected {
        let observedInspection = game.commander.salvageLedger.inspectLoot(
          wreck: site.identity, section: section, source: source)
        #expect(
          observedInspection != nil)
      }
    }
    game.commander.salvageLedger = try NativePagedSalvageFixture.fullOrdinaryLedger(
      starting: game.commander.salvageLedger, initialOperation: operation,
      retainedWrecks: 1, retainedPlans: inspected ? profile.sections.count : 0,
      retainedPartial: profile.sections.count)
    let original = game.commander.salvageLedger
    let energy = game.energy
    let heat = game.laserHeat
    let observedCutterResult = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult)
    let hot = try #require(game.nativeSalvageWork)
    #expect(abs(hot.cycle.currentWorkSeconds - 0.35) < 1e-12)
    #expect(hot.cycle.damagedTechnology == (tool == .miningLaser))
    for (index, item) in hot.plan.items.enumerated() {
      if case .technology = item.content {
        #expect(hot.cycle.progress.discarded[index] == (tool == .miningLaser))
      }
    }
    #expect(hot.cycle.progress.materialKind == .alloys)
    #expect(hot.cycle.progress.nextLot == 0 && hot.cycle.releases == 0)
    #expect(abs(game.energy - (energy - 0.2)) < 1e-10 && abs(game.laserHeat - (heat + 0.6)) < 1e-10)
    #expect(game.commander.alienStorageState?.current.snapshot.sources.isEmpty == true)
    var expectedOld = original
    if inspected {
      let export = try original.exportNativeSection(hot.plan.section)
      #expect(export.partialWork == 0.25 && export.progress.materialKind == nil)
      #expect(export.damagedTechnology == (tool == .miningLaser))
      try expectedOld.transferNativeSection(export)
      guard case .legacy(let id) = hot.cycle.inspection else { throw SaveError.invalidCommander }
      let record = try #require(
        game.commander.alienStorageState?.current.snapshot.world.compactMap {
          value -> AlienStorageLegacySection? in
          if case .legacySection(let item) = value, item.id == id { return item }
          return nil
        }.first)
      #expect(record.savedPartialWorkSeconds == 0.25 && record.progress.materialKind == nil)
      #expect(
        record.savedDamagedTechnology == export.damagedTechnology
          && record.savedLedgerLastOperation == export.lastOperation)
    } else {
      guard case .fresh(let id) = hot.cycle.inspection else { throw SaveError.invalidCommander }
      let record = try #require(
        game.commander.alienStorageState?.current.salvage.native.inspections[hot.plan.section])
      #expect(record.id == id && record.preinspection?.partialWorkSeconds == 0.25)
      #expect(record.preinspection?.damagedTechnology == (tool == .miningLaser))
      #expect(record.initialProgress.materialKind == nil && record.initialProgress.nextLot == 0)
      var capped = original
      let observedInspection2 = capped.inspectLoot(
        wreck: site.identity, section: hot.section, source: source)
      #expect(observedInspection2 == nil)
      #expect(capped == original)
    }
    #expect(game.commander.salvageLedger == expectedOld)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    // Preserve this direct cutter observation before the new actor invalidates
    // its predecessor's scene epoch; no stale hot authority is carried across.
    let observedWorkFlush = game.flushNativeSalvageWork()
    #expect(observedWorkFlush)
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    if tool == .miningLaser {
      let rows = try #require(saved.commander.alienStorageState?.current.snapshot.world).compactMap
      {
        record -> AlienStorageWorldLot? in
        if case .lot(let lot) = record, lot.plan == hot.cycle.inspection.id { return lot }
        return nil
      }
      if !inspected { #expect(!rows.isEmpty) }
      for row in rows {
        #expect(row.issuedAt == nil && row.state == .discarded(at: hot.cycle.observedAt))
      }
    }
    let bytes = try Data(contentsOf: file)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    #expect(
      loaded.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]
        == hot.cycle)
    #expect(loaded.commander.salvageLedger == expectedOld)
    let observedFileBytes = try Data(contentsOf: file)
    #expect(observedFileBytes == bytes)
  }
}
