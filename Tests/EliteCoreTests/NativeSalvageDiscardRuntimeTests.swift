import Foundation
import Testing

@testable import EliteCore

struct NativeSalvageDiscardRuntimeTests {
  @Test(arguments: ["work-flush", "wreck-flush", "actual-death", "writer-refusal"])
  func actualOldMiningDamageDiscardsOnlyUnissuedRowsAtEveryColdBoundary(boundary: String)
    async throws
  {
    var (game, site) = try NativePagedSalvageFixture.game(requireReserved: true)
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    for section in profile.sections {
      let allocatedIncident = game.commander.flightSimulation.allocateIncident()
      let operation = try #require(allocatedIncident)
      let observedWorkResult = game.commander.salvageLedger.advance(
        wreck: site.identity, section: section, pose: game.modelPose(of: body),
        velocity: body.physical!.velocity, angularVelocity: body.physical!.angularVelocity,
        tool: .miningLaser, elapsed: 0.25, operation: operation,
        conditions: NativePagedSalvageFixture.permitted)
      #expect(
        observedWorkResult
          == .progress(seconds: 0.25, required: section.workSeconds))
    }
    let originalLedger = game.commander.salvageLedger
    game.selectFlightTool(.salvageCutter)
    let originalRuntime = GameRuntime(game: game)
    await originalRuntime.setControls(NativePagedSalvageFixture.firingControls)
    game = await originalRuntime.advance(delta: 0.1)
    let hot = try #require(game.nativeSalvageWork)
    let original = try #require(game.commander.alienStorageState?.current.snapshot)
    let rows = original.world.compactMap { record -> AlienStorageWorldLot? in
      if case .lot(let row) = record, row.plan == hot.cycle.inspection.id { return row }
      return nil
    }
    #expect(!rows.isEmpty && rows.allSatisfy { $0.issuedAt == nil && $0.state == .unissued })
    #expect(hot.cycle.damagedTechnology && hot.cycle.progress.discarded.contains(true))
    #expect(hot.cycle.releases == 0 && hot.cycle.progress.nextLot == 0)
    switch boundary {
    case "work-flush":
      let observedWorkFlush = game.flushNativeSalvageWork()
      #expect(observedWorkFlush)
    case "wreck-flush":
      let actual = try #require(game.bodies.first { $0.physical?.identity == hot.actor })
      let observedWreck = game.observeNativeSalvageWreck(actual)
      let observedWreckFlush = game.flushNativeSalvageWrecks()
      #expect(observedWreck && observedWreckFlush)
    case "actual-death":
      let actual = try #require(game.bodies.first { $0.physical?.identity == hot.actor })
      let player = try #require(game.commander.flightSimulation.player)
      let allocatedAttackOrigin = game.makeAttackOrigin(owner: player)
      let origin = try #require(allocatedAttackOrigin)
      let observedCombatResult = game.applyCombatHit(
        .init(target: .body(actual.id), distance: actual.position.length, point: actual.position),
        origin: origin, kind: .laser, damage: actual.energy + 1, laser: .pulse)
      #expect(
        observedCombatResult != nil)
      game.commander.crimeLedger.finishEmission(origin.emissionID)
      game.resolveDestroyed()
      #expect(!game.bodies.contains { $0.physical?.identity == hot.actor })
    default: break
    }
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = boundary == "writer-refusal" ? originalRuntime : GameRuntime(game: game)
    if boundary == "writer-refusal" {
      try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
      let before = await runtime.snapshot()
      await #expect(throws: (any Error).self) { try await runtime.save(to: file) }
      let refused = await runtime.snapshot()
      #expect(refused.commander == before.commander && refused.bodies == before.bodies)
      #expect(refused.nativeSalvageWork?.cycle == hot.cycle)
      #expect(refused.commander.alienStorageState?.current.snapshot == original)
      try FileManager.default.removeItem(at: file)
    }
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let snapshot = try #require(saved.commander.alienStorageState?.current.snapshot)
    try snapshot.validate()
    let cycle = try #require(
      saved.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id])
    #expect(
      cycle.releases == 0 && cycle.progress.nextLot == 0
        && cycle.currentWorkSeconds == hot.cycle.currentWorkSeconds)
    #expect(cycle.depleted == (boundary == "actual-death"))
    for row in rows {
      let retained = try #require(snapshot.world.first { $0.id == row.id })
      #expect(
        retained
          == .lot(
            .init(
              id: row.id, owner: row.owner, plan: row.plan,
              itemIndex: row.itemIndex, issuedAt: nil, state: .discarded(at: hot.cycle.observedAt)))
      )
    }
    #expect(snapshot.sources.isEmpty && snapshot.attachments.isEmpty && snapshot.upgrades.isEmpty)
    #expect(saved.commander.salvageLedger == originalLedger)
    let bytes = try Data(contentsOf: file)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    let observedFileBytes = try Data(contentsOf: file)
    #expect(observedFileBytes == bytes)
  }
}
