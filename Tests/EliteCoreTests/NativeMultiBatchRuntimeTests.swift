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

extension NativeMultiBatchRuntimeTests {
  private final class ContinuationSavedState {
    let commander: Commander
    let world: ScriptWorldSave

    init(file: URL) throws {
      let decoded = try ScriptSaveStore.read(Data(contentsOf: file), from: file)
      commander = decoded.0
      world = decoded.1
    }
  }

  private struct ContinuationEvent: Encodable {
    let events: [String]
    let stage: String
    let record: Int
    let inputManifest: String
    let ownedDirectory: String?
    let setupWallSeconds: Double
    let work: WorkTrace?
    let error: String?
  }

  @Test(
    .enabled(
      if: ProcessInfo.processInfo.environment["ELITE_NATIVE_WORK_CONTINUATION"] == "1"
        && ProcessInfo.processInfo.environment["ELITE_NATIVE_WORK_CONTINUATION_SOURCE"]?.isEmpty
          == false,
      "Requires explicit diagnostic opt-in and the private retained run 542 directory")
  )
  func retained542SecondCycleContinuationDiagnostic() async throws {
    let expectedManifest = "977264133e75c7900694f7f3b5ca206a943c3be90fd79c3db57dfb7fddad066d"
    let began = ProcessInfo.processInfo.systemUptime
    var stage = "input"
    var records = 0
    var setupWall = 0.0
    var lastTrace: WorkTrace?
    var ownedFolder: URL?
    defer {
      if let ownedFolder { try? FileManager.default.removeItem(at: ownedFolder) }
    }
    do {
      let path = try #require(
        ProcessInfo.processInfo.environment["ELITE_NATIVE_WORK_CONTINUATION_SOURCE"])
      let source = URL(fileURLWithPath: path, isDirectory: true).resolvingSymlinksInPath()
      let sourceFiles = try continuationFiles(in: source)
      let inputMatches =
        sourceFiles.count == 25
        && continuationManifest(sourceFiles) == expectedManifest
      try #require(inputMatches, "Only the exact retained run 542 input is permitted")
      let folder = try NativePagedSalvageFixture.folder()
      ownedFolder = folder
      let copy = folder.appendingPathComponent("continuation", isDirectory: true)
      try FileManager.default.copyItem(at: source, to: copy)
      let copiedFiles = try continuationFiles(in: copy)
      let unchangedSource = try continuationFiles(in: source)
      let exactCopy = copiedFiles == sourceFiles && unchangedSource == sourceFiles
      try #require(exactCopy, "Copy must preserve every input byte without changing the source")
      let file = copy.appendingPathComponent("commander.json")
      let expected = try ContinuationSavedState(file: file)
      stage = "authenticated-load"
      let loader = GameRuntime(game: Game(executive: false))
      try await loader.load(from: file, persistMigrations: false)
      var loaded = await loader.snapshot()
      let afterLoadFiles = try continuationFiles(in: copy)
      let noWrite = afterLoadFiles == copiedFiles
      try #require(noWrite, "The initial authenticated reload must not write")
      stage = continuationRestoreMismatch(loaded, expected: expected) ?? "saved-stage"
      try #require(stage == "saved-stage", "Restored state must match its authenticated input")
      let native = try #require(loaded.commander.alienStorageState?.current.salvage.native)
      try #require(native.works.count == 1)
      let reference = try #require(native.works.keys.first)
      let cycle = try #require(native.works[reference])
      let inspection = try #require(native.plans[reference])
      let section = try #require(native.sectionProfiles[reference])
      let identity = inspection.plan.section
      let profile = try #require(SalvageCatalogue.profile(catalogueShipID: "SH127"))
      let stageMatches =
        loaded.commander.flightSimulation.physicalTime == 19.299999999999677
        && loaded.systemIdentity == .init(galaxy: 0, system: 5)
        && loaded.commander.shipID == "SH023" && loaded.bodies.count == 5
        && cycle.releases == 1 && cycle.currentWorkSeconds == 0.02
        && cycle.progress.nextLot == 8 && !cycle.damagedTechnology && !cycle.depleted
        && cycle.lastRelease?.creditedWorkSeconds == 16
        && loaded.commander.alienStorageState?.current.salvage.pending.count == 8
        && loaded.nativeSalvageWork == nil && section.index == 1 && section.workSeconds == 16
        && inspection.plan.source.roles == profile.sourceRoles
        && inspection.seed == loaded.commander.salvageLedger.nativeInspectionSeed
        && loaded.commander.fittedEquipment(at: .utility(.fuelScoops)) == nil
        && loaded.commander.fittedEquipment(at: .utility(.salvageCutter)) != nil
        && loaded.commander.fittedEquipment(at: .targetingSalvage) != nil
        && loaded.commander.fittedEquipment(at: .targetingCore) != nil
      try #require(
        stageMatches, "Retained input must be the actual post-observer second-cycle stage")
      let parent = try #require(
        loaded.bodies.first {
          $0.physical?.salvage?.wreck == identity.wreck && $0.physical?.payload == nil
        })
      let physical = try #require(parent.physical)
      let bindingMatches =
        physical.catalogueShipID == "SH127"
        && native.wrecks[identity.wreck]?.binding == physical.identity
        && physical.identity.system == loaded.systemIdentity
        && physical.identity.visit == loaded.commander.flightSimulation.visit
        && cycle.owner == loaded.commander.equipmentOwnerID
        && inspection.owner == loaded.commander.equipmentOwnerID
        && native.wrecks[identity.wreck]?.owner == loaded.commander.equipmentOwnerID
        && native.wrecks[identity.wreck]?.seed == inspection.seed
      try #require(bindingMatches, "Current owner, parent and native binding must join")
      stage = "reacquisition"
      // This generation already contains the observer pose. Do not move or normalize it.
      loaded.selectFlightTool(.salvageCutter)
      try NativePagedSalvageFixture.engageSalvageTarget(&loaded, body: parent, section: identity)
      let resumed = GameRuntime(game: loaded)
      try await resumed.save(to: file)
      await resumed.setControls(NativePagedSalvageFixture.firingControls)
      var current = await resumed.snapshot()
      var before = observeWork(current, reference: reference, baselineWork: 0.02, baselineSerial: 8)
      var readiness = continuationReadiness(current)
      setupWall = ProcessInfo.processInfo.systemUptime - began
      let phaseBegan = ProcessInfo.processInfo.systemUptime
      lastTrace = continuationTrace(
        iteration: -1, began: phaseBegan, before: before, after: before,
        beforeReadiness: readiness, afterReadiness: readiness)
      try emitContinuation(
        events: ["start"], stage: "held-work", terminal: false, records: &records,
        manifest: expectedManifest, setupWall: setupWall, trace: lastTrace, owned: ownedFolder)
      var firstHold = readiness.holding == true
      var firstCredit = false
      var completed = false
      stage = "held-work"
      for iteration in 0..<2500 {
        current = await NativePagedSalvageFixture.advanceHeldWork(resumed, delta: 0.02)
        let after = observeWork(
          current, reference: reference, baselineWork: 0.02, baselineSerial: 8)
        let afterReadiness = continuationReadiness(current)
        lastTrace = continuationTrace(
          iteration: iteration, began: phaseBegan, before: before, after: after,
          beforeReadiness: readiness, afterReadiness: afterReadiness)
        checkEarnedWork(before: before, after: after, required: 16, delta: 0.02)
        let earnedStepValid = continuationEarnedStep(before: before, after: after)
        try #require(earnedStepValid, "The original earned-work predicates must hold")
        var events: [String] = []
        if iteration == 9 || (iteration >= 109 && (iteration - 109).isMultiple(of: 100)) {
          events.append("checkpoint")
        }
        if !firstHold && afterReadiness.holding == true {
          firstHold = true
          events.append("first-hold")
        }
        if !firstCredit && (after.releases > before.releases || after.seconds > before.seconds) {
          firstCredit = true
          events.append("first-earned-work")
        }
        if after.releases == 2 {
          completed = true
          break
        }
        if !events.isEmpty {
          try emitContinuation(
            events: events, stage: stage, terminal: false, records: &records,
            manifest: expectedManifest, setupWall: setupWall, trace: lastTrace, owned: ownedFolder)
        }
        before = after
        readiness = afterReadiness
      }
      stage = completed ? "release-validation" : "original-loop-exhausted"
      try #require(completed, "The original 2500-frame budget exhausted without a second release")
      let finalMatches = continuationFinalMatches(current, reference: reference, expected: expected)
      try #require(finalMatches, "Second release and preserved ownership/custody must match")
      let sourceStillUnchanged = try continuationFiles(in: source) == sourceFiles
      try #require(sourceStillUnchanged, "Only the owned clone may have been written")
      try emitContinuation(
        events: ["completed-second-release"], stage: "completed", terminal: true, records: &records,
        manifest: expectedManifest, setupWall: setupWall, trace: lastTrace, owned: ownedFolder)
    } catch let failure {
      if setupWall == 0 { setupWall = ProcessInfo.processInfo.systemUptime - began }
      do {
        try emitContinuation(
          events: ["error"], stage: stage, terminal: true, records: &records,
          manifest: expectedManifest, setupWall: setupWall, trace: lastTrace, owned: ownedFolder,
          error: String(describing: failure))
      } catch {
        try? emitContinuation(
          events: ["trace-error"], stage: stage, terminal: true, records: &records,
          manifest: expectedManifest, setupWall: setupWall, trace: nil, owned: ownedFolder,
          error: String(describing: failure))
      }
      throw failure
    }
  }

  private func continuationReadiness(_ game: borrowing Game) -> WorkReadiness {
    .init(
      physicalTime: game.commander.flightSimulation.physicalTime,
      holding: game.workGuidance?.holding,
      controllerStatus: game.workGuidance.map { String(describing: $0.controller.status) },
      workFireSuspended: game.workFireSuspended, weaponStatus: game.flightWeaponDisplay.status,
      selectedTool: game.selectedFlightTool.label, hotSessionPresent: game.nativeSalvageWork != nil,
      lastAppliedMotionPresent: game.lastAppliedWorkMotion != nil)
  }

  private func continuationTrace(
    iteration: Int, began: Double, before: WorkObservation, after: WorkObservation,
    beforeReadiness: WorkReadiness, afterReadiness: WorkReadiness
  ) -> WorkTrace {
    .init(
      phase: "retained-542-second-cycle", iteration: iteration,
      monotonicElapsedSeconds: ProcessInfo.processInfo.systemUptime - began,
      before: before, after: after, beforeReadiness: beforeReadiness,
      afterReadiness: afterReadiness, required: 16, delta: 0.02)
  }

  private func continuationEarnedStep(before: WorkObservation, after: WorkObservation) -> Bool {
    let epsilon = 1e-9
    if after.releases == before.releases {
      return after.seconds >= before.seconds - epsilon
        && after.seconds - before.seconds <= 0.02 + epsilon
        && after.serial == before.serial && after.pending == before.pending
    }
    return after.releases == before.releases + 1 && before.seconds + 0.02 + epsilon >= 16
      && after.seconds == 0 && !after.damaged && after.serial == before.serial + 8
      && after.pending == before.pending + 8 && after.credited == 16
  }

  private func continuationRestoreMismatch(
    _ game: borrowing Game, expected: ContinuationSavedState
  ) -> String? {
    if game.commander.flightSimulation != expected.commander.flightSimulation { return "flight" }
    if game.bodies != expected.world.bodies { return "bodies" }
    if game.docked != expected.world.docked || game.screen != expected.world.screen
      || game.speed != expected.world.speed || game.time != expected.world.time
    {
      return "world-phase"
    }
    if game.commander.fuel != expected.commander.fuel
      || game.commander.missiles != expected.commander.missiles
    {
      return "fuel-ammunition"
    }
    if game.energy != expected.world.energy || game.laserHeat != expected.world.laserHeat
      || game.frontShield != expected.world.frontShield
      || game.rearShield != expected.world.rearShield
    {
      return "resources"
    }
    if game.commander.cargo != expected.commander.cargo
      || game.commander.credits != expected.commander.credits
      || game.commander.equipmentInventory != expected.commander.equipmentInventory
      || game.commander.equipmentOwnerID != expected.commander.equipmentOwnerID
      || game.commander.hullInstanceID != expected.commander.hullInstanceID
    {
      return "property"
    }
    if game.commander.salvageLedger != expected.commander.salvageLedger { return "old-ledger" }
    if game.commander.alienStorageState?.current.snapshot
      != expected.commander.alienStorageState?.current.snapshot
    {
      return "native-custody"
    }
    return nil
  }

  private func continuationFinalMatches(
    _ game: borrowing Game, reference: UUID, expected: ContinuationSavedState
  ) -> Bool {
    guard let saved = expected.commander.alienStorageState?.current,
      let actual = game.commander.alienStorageState?.current,
      let originalCycle = saved.salvage.native.works[reference],
      let cycle = actual.salvage.native.works[reference], cycle.releases == 2,
      cycle.id == originalCycle.id, cycle.owner == originalCycle.owner,
      cycle.inspection == originalCycle.inspection, cycle.beganAt == originalCycle.beganAt,
      cycle.progress.nextLot == 16, cycle.currentWorkSeconds == 0,
      !cycle.damagedTechnology, cycle.lastRelease?.creditedWorkSeconds == 16,
      actual.salvage.pending.count == 16,
      actual.salvage.native.plans[reference]?.plan == saved.salvage.native.plans[reference]?.plan,
      actual.salvage.native.plans[reference]?.seed == saved.salvage.native.plans[reference]?.seed,
      actual.salvage.native.plans[reference]?.owner == saved.salvage.native.plans[reference]?.owner,
      actual.salvage.native.sectionProfiles[reference]
        == saved.salvage.native.sectionProfiles[reference],
      game.commander.cargo == expected.commander.cargo,
      game.commander.credits == expected.commander.credits,
      game.commander.equipmentInventory == expected.commander.equipmentInventory,
      game.commander.salvageLedger.pendingLots.isEmpty
    else { return false }
    for (id, pending) in saved.salvage.pending {
      if actual.salvage.pending[id]?.lot.loot != pending.lot.loot { return false }
    }
    for record in saved.snapshot.world {
      if case .legacySection = record, !actual.snapshot.world.contains(record) { return false }
    }
    return true
  }

  private func continuationFiles(in directory: URL) throws -> [String: String] {
    let base = directory.resolvingSymlinksInPath()
    guard
      let entries = FileManager.default.enumerator(
        at: base, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    else { throw SaveError.invalidCommander }
    var result: [String: String] = [:]
    for case let file as URL in entries {
      let properties = try file.resourceValues(
        forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
      guard properties.isSymbolicLink != true else { throw SaveError.invalidCommander }
      if properties.isRegularFile != true { continue }
      guard result.count < 25, (properties.fileSize ?? Int.max) <= 4_194_304 else {
        throw SaveError.invalidCommander
      }
      let relative = String(file.path.dropFirst(base.path.count + 1))
      result[relative] = ScriptPackLibrary.hash(try Data(contentsOf: file))
    }
    return result
  }

  private func continuationManifest(_ files: [String: String]) -> String {
    var bytes = Data()
    for path in files.keys.sorted() {
      bytes.append(contentsOf: path.utf8)
      bytes.append(0)
      bytes.append(contentsOf: files[path]!.utf8)
      bytes.append(0x0A)
    }
    return ScriptPackLibrary.hash(bytes)
  }

  private func emitContinuation(
    events: [String], stage: String, terminal: Bool, records: inout Int,
    manifest: String, setupWall: Double, trace: WorkTrace?, owned: URL?, error: String? = nil
  ) throws {
    guard records < 30 else { throw SaveError.invalidCommander }
    records += 1
    let event = ContinuationEvent(
      events: events, stage: stage, record: records, inputManifest: manifest,
      ownedDirectory: owned?.path, setupWallSeconds: setupWall, work: trace, error: error)
    let encoded = try JSONEncoder().encode(event)
    let marker =
      terminal ? "ELITE_NATIVE_WORK_CONTINUATION_TERMINAL" : "ELITE_NATIVE_WORK_CONTINUATION_EVENT"
    var line = Data((marker + " ").utf8)
    line.append(encoded)
    line.append(0x0A)
    FileHandle.standardError.write(line)
  }
}
