import Foundation
import Testing

@testable import EliteCore

struct NativeMultiBatchRuntimeTests {
  @Test func originalHumanManifestImportRequiresAFullSecondBudgetAcrossActualSaveAndReload()
    async throws
  {
    let traceStarted =
      ProcessInfo.processInfo.environment["ELITE_NATIVE_WORK_TRACE"] == "1"
      ? ProcessInfo.processInfo.systemUptime : nil
    var (game, site) = try NativePagedSalvageFixture.game(humanCargo: true)
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
    let section = try #require(profile.sections.first { $0.index == 1 })
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    #expect(!profile.sourceRoles.contains(.thargoid))
    #expect(game.commander.fittedEquipment(at: .utility(.fuelScoops)) == nil)
    let identity = WreckSectionIdentity(wreck: site.identity, section: section.index)
    // Compatibility input is an original human producer and its sealed section export.
    // This neither grants a Thargoid manifest nor claims a current human bootstrap path.
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
      technology: game.currentSystem.technology, ownership: .abandoned,
      manifest: [.init(commodity: .food, quantity: 120)])
    let allocatedIncident = game.commander.flightSimulation.allocateIncident()
    let operation = try #require(allocatedIncident)
    guard
      case .progress = game.commander.salvageLedger.advance(
        wreck: site.identity, section: section, pose: game.modelPose(of: body),
        velocity: body.physical!.velocity, angularVelocity: body.physical!.angularVelocity,
        tool: .cutter, elapsed: 0.25, operation: operation,
        conditions: NativePagedSalvageFixture.permitted, source: source)
    else { throw SaveError.invalidCommander }
    let originalLedger = game.commander.salvageLedger
    let original = try originalLedger.exportNativeSection(identity)
    let imported = try NativeSalvageImport(
      ledger: originalLedger, section: identity,
      owner: try #require(game.commander.equipmentOwnerID),
      at: game.commander.flightSimulation.physicalTime,
      previous: game.commander.alienStorageState?.current.snapshot)
    try imported.apply(to: &game.commander)
    let oldRecord = try #require(imported.snapshot.world.first { $0.id == imported.section })
    let cargo = game.commander.cargo
    let property = game.commander.equipmentInventory
    let credits = game.commander.credits
    game.selectFlightTool(.salvageCutter)
    try NativePagedSalvageFixture.engageSalvageTarget(&game, body: body, section: identity)
    try #require(game.workGuidance?.surface.section == identity)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    var first = await runtime.snapshot()
    for iteration in 0..<2500 {
      let prior = observeWork(
        first, reference: imported.section,
        baselineWork: original.partialWork ?? 0, baselineSerial: original.progress.nextLot)
      let priorReadiness = observeWorkReadiness(
        first, iteration: iteration, enabled: traceStarted != nil)
      first = await NativePagedSalvageFixture.advanceHeldWork(runtime, delta: 0.02)
      let currentWork = observeWork(
        first, reference: imported.section,
        baselineWork: original.partialWork ?? 0, baselineSerial: original.progress.nextLot)
      checkEarnedWork(before: prior, after: currentWork, required: section.workSeconds, delta: 0.02)
      traceWork(
        phase: "first-release", iteration: iteration, started: traceStarted,
        before: prior, after: currentWork, beforeReadiness: priorReadiness,
        afterReadiness: observeWorkReadiness(
          first, iteration: iteration, enabled: traceStarted != nil),
        required: section.workSeconds, delta: 0.02)
      if first.commander.alienStorageState?.current.salvage.native.works[imported.section]?.releases
        == 1
      {
        break
      }
    }
    let firstCycle = try #require(
      first.commander.alienStorageState?.current.salvage.native.works[imported.section])
    #expect(firstCycle.releases == 1 && firstCycle.progress.nextLot == 8)
    #expect(
      firstCycle.currentWorkSeconds == 0 && !firstCycle.damagedTechnology && !firstCycle.depleted)
    var oracle = originalLedger
    var oracleOperation = operation
    let expectedFirst = try NativePagedSalvageFixture.originalRelease(
      ledger: &oracle, section: section, identity: identity, source: source,
      remaining: section.workSeconds - (original.partialWork ?? 0), operation: &oracleOperation)
    #expect(expectedFirst.count == 8)
    let firstPending = try #require(first.commander.alienStorageState?.current.salvage.pending)
    #expect(Set(firstPending.keys) == Set(expectedFirst.map(\.identity)))
    for lot in expectedFirst { #expect(firstPending[lot.identity]?.lot.loot == lot.loot) }
    #expect(first.commander.alienStorageState?.current.snapshot.world.contains(oldRecord) == true)

    var partial = first
    for iteration in 0..<2500 {
      let prior = observeWork(
        partial, reference: imported.section,
        baselineWork: original.partialWork ?? 0, baselineSerial: original.progress.nextLot)
      let priorReadiness = observeWorkReadiness(
        partial, iteration: iteration, enabled: traceStarted != nil)
      partial = await runtime.advance(delta: 0.02)
      let currentWork = observeWork(
        partial, reference: imported.section,
        baselineWork: original.partialWork ?? 0, baselineSerial: original.progress.nextLot)
      checkEarnedWork(before: prior, after: currentWork, required: section.workSeconds, delta: 0.02)
      traceWork(
        phase: "second-cycle-start", iteration: iteration, started: traceStarted,
        before: prior, after: currentWork, beforeReadiness: priorReadiness,
        afterReadiness: observeWorkReadiness(
          partial, iteration: iteration, enabled: traceStarted != nil),
        required: section.workSeconds, delta: 0.02)
      if (partial.nativeSalvageWork?.cycle.currentWorkSeconds ?? 0) > 0 { break }
    }
    let hot = try #require(partial.nativeSalvageWork)
    #expect(hot.cycle.releases == 1 && hot.cycle.progress == firstCycle.progress)
    #expect(hot.cycle.currentWorkSeconds > 0 && hot.cycle.currentWorkSeconds < section.workSeconds)
    #expect(partial.commander.alienStorageState?.current.salvage.pending.count == 8)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let savedCycle = try #require(
      saved.commander.alienStorageState?.current.salvage.native.works[imported.section])
    #expect(savedCycle == hot.cycle)
    let bytes = try Data(contentsOf: file)
    try await runtime.load(from: file, persistMigrations: false)
    var loaded = await runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    let observedFileBytes = try Data(contentsOf: file)
    #expect(loaded.nativeSalvageWork == nil && (observedFileBytes) == bytes)
    #expect(loaded.commander.alienStorageState?.current.snapshot.world.contains(oldRecord) == true)
    let retainedBody = try #require(
      loaded.bodies.first {
        $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
      })
    let retainedModel = loaded.modelPose(of: retainedBody)
    let retainedTime = loaded.commander.flightSimulation.physicalTime
    let retainedCustody = loaded.commander.alienStorageState?.current.snapshot
    let retainedPhysical = loaded.bodies.map(\.physical)
    var retainedModels: [ShipPose] = []
    for body in loaded.bodies { retainedModels.append(loaded.modelPose(of: body)) }
    // Equality and no-write reload checks above precede this unit observer setup.
    NativePagedSalvageFixture.moveObserver(
      &loaded, to: NativePagedSalvageFixture.cargoObserverPose(retainedModel, section: section))
    #expect(loaded.commander.flightSimulation.physicalTime == retainedTime)
    #expect(loaded.commander.alienStorageState?.current.snapshot == retainedCustody)
    #expect(loaded.bodies.map(\.physical) == retainedPhysical)
    for (body, model) in zip(loaded.bodies, retainedModels) {
      let current = loaded.modelPose(of: body)
      #expect((current.position - model.position).length < 1e-8)
      #expect((current.orientation.x - model.orientation.x).length < 1e-8)
      #expect((current.orientation.y - model.orientation.y).length < 1e-8)
      #expect((current.orientation.z - model.orientation.z).length < 1e-8)
    }
    let reacquiredBody = try #require(
      loaded.bodies.first { $0.physical?.identity == retainedBody.physical?.identity })
    loaded.selectFlightTool(.salvageCutter)
    try NativePagedSalvageFixture.engageSalvageTarget(
      &loaded, body: reacquiredBody, section: identity)
    try #require(loaded.workGuidance?.surface.section == identity)
    let resumed = GameRuntime(game: loaded)
    try await resumed.save(to: file)
    await resumed.setControls(NativePagedSalvageFixture.firingControls)
    var second = await resumed.snapshot()
    for iteration in 0..<2500 {
      let prior = observeWork(
        second, reference: imported.section,
        baselineWork: original.partialWork ?? 0, baselineSerial: original.progress.nextLot)
      let priorReadiness = observeWorkReadiness(
        second, iteration: iteration, enabled: traceStarted != nil)
      second = await NativePagedSalvageFixture.advanceHeldWork(resumed, delta: 0.02)
      let currentWork = observeWork(
        second, reference: imported.section,
        baselineWork: original.partialWork ?? 0, baselineSerial: original.progress.nextLot)
      checkEarnedWork(before: prior, after: currentWork, required: section.workSeconds, delta: 0.02)
      traceWork(
        phase: "resumed-release", iteration: iteration, started: traceStarted,
        before: prior, after: currentWork, beforeReadiness: priorReadiness,
        afterReadiness: observeWorkReadiness(
          second, iteration: iteration, enabled: traceStarted != nil),
        required: section.workSeconds, delta: 0.02)
      let current = second.commander.alienStorageState?.current.salvage.native.works[
        imported.section]
      if current?.releases == 2 { break }
      #expect(current?.releases == 1)
      #expect(second.commander.alienStorageState?.current.salvage.pending.count == 8)
    }
    let secondCycle = try #require(
      second.commander.alienStorageState?.current.salvage.native.works[imported.section])
    #expect(secondCycle.releases == 2 && secondCycle.progress.nextLot == 16)
    #expect(secondCycle.currentWorkSeconds == 0 && !secondCycle.damagedTechnology)
    #expect(secondCycle.lastRelease?.creditedWorkSeconds == section.workSeconds)
    let expectedSecond = try NativePagedSalvageFixture.originalRelease(
      ledger: &oracle, section: section, identity: identity, source: source,
      remaining: section.workSeconds, operation: &oracleOperation)
    #expect(expectedSecond.count == 8)
    let secondPending = try #require(second.commander.alienStorageState?.current.salvage.pending)
    #expect(Set(secondPending.keys) == Set((expectedFirst + expectedSecond).map(\.identity)))
    for lot in expectedFirst + expectedSecond {
      #expect(secondPending[lot.identity]?.lot.loot == lot.loot)
    }
    #expect(second.commander.alienStorageState?.current.snapshot.world.contains(oldRecord) == true)
    #expect(second.commander.cargo == cargo && second.commander.equipmentInventory == property)
    #expect(second.commander.credits == credits)
    #expect(second.commander.salvageLedger.pendingLots.isEmpty)
  }

  private struct WorkObservation: Sendable, Encodable {
    let seconds: Double
    let releases: UInt64
    let serial: UInt32
    let pending: Int
    let damaged: Bool
    let credited: Double?
  }

  private struct WorkReadiness: Encodable {
    let physicalTime: Double
    let holding: Bool?
    let controllerStatus: String?
    let workFireSuspended: Bool
    let weaponStatus: String
    let selectedTool: String
    let hotSessionPresent: Bool
    let lastAppliedMotionPresent: Bool
  }

  private func observeWorkReadiness(
    _ game: borrowing Game, iteration: Int, enabled: Bool
  ) -> WorkReadiness? {
    guard enabled, iteration == 9 || iteration == 109 else { return nil }
    return .init(
      physicalTime: game.commander.flightSimulation.physicalTime,
      holding: game.workGuidance?.holding,
      controllerStatus: game.workGuidance.map { String(describing: $0.controller.status) },
      workFireSuspended: game.workFireSuspended, weaponStatus: game.flightWeaponDisplay.status,
      selectedTool: game.selectedFlightTool.label,
      hotSessionPresent: game.nativeSalvageWork != nil,
      lastAppliedMotionPresent: game.lastAppliedWorkMotion != nil)
  }

  private struct WorkTrace: Encodable {
    let phase: String
    let iteration: Int
    let monotonicElapsedSeconds: Double
    let before: WorkObservation
    let after: WorkObservation
    let beforeReadiness: WorkReadiness?
    let afterReadiness: WorkReadiness?
    let required: Double
    let delta: Double
  }

  private func traceWork(
    phase: String, iteration: Int, started: Double?,
    before: WorkObservation, after: WorkObservation,
    beforeReadiness: WorkReadiness?, afterReadiness: WorkReadiness?,
    required: Double, delta: Double
  ) {
    guard let started, iteration == 9 || iteration == 109 else { return }
    let trace = WorkTrace(
      phase: phase, iteration: iteration,
      monotonicElapsedSeconds: ProcessInfo.processInfo.systemUptime - started,
      before: before, after: after, beforeReadiness: beforeReadiness,
      afterReadiness: afterReadiness, required: required, delta: delta)
    do {
      let encoded = try JSONEncoder().encode(trace)
      var line = Data("ELITE_NATIVE_WORK_TRACE ".utf8)
      line.append(encoded)
      line.append(0x0A)
      FileHandle.standardError.write(line)
    } catch {
      FileHandle.standardError.write(
        Data("ELITE_NATIVE_WORK_TRACE_ERROR phase=\(phase) iteration=\(iteration)\n".utf8))
    }
  }

  private func observeWork(
    _ game: Game, reference: UUID, baselineWork: Double, baselineSerial: UInt32
  ) -> WorkObservation {
    let cycle: NativeSalvageWorkCycle?
    if let hot = game.nativeSalvageWork, hot.cycle.inspection.id == reference {
      cycle = hot.cycle
    } else {
      cycle = game.commander.alienStorageState?.current.salvage.native.works[reference]
    }
    return .init(
      seconds: cycle?.currentWorkSeconds ?? baselineWork, releases: cycle?.releases ?? 0,
      serial: cycle?.progress.nextLot ?? baselineSerial,
      pending: game.commander.alienStorageState?.current.salvage.pending.count ?? 0,
      damaged: cycle?.damagedTechnology ?? false, credited: cycle?.lastRelease?.creditedWorkSeconds)
  }

  private func checkEarnedWork(
    before: WorkObservation, after: WorkObservation, required: Double, delta: Double
  ) {
    let epsilon = 1e-9
    if after.releases == before.releases {
      // Guidance can pause or cold-flush the session; elapsed flight is not earned work.
      #expect(
        after.seconds >= before.seconds - epsilon
          && after.seconds - before.seconds <= delta + epsilon)
      #expect(after.serial == before.serial && after.pending == before.pending)
    } else {
      // A fabricated full creditedWorkSeconds cannot stand in for actual earlier work.
      #expect(after.releases == before.releases + 1)
      #expect(before.seconds + delta + epsilon >= required)
      #expect(after.seconds == 0 && !after.damaged)
      #expect(after.serial == before.serial + 8 && after.pending == before.pending + 8)
      #expect(after.credited == required)
    }
  }
}
