import Foundation
import Testing

@testable import EliteCore

struct NativePagedSalvageRuntimeTests {
  @Test func genuineGeneratedInspectionAndWorkBypassEveryFullOrdinaryLifetimePool() async throws {
    var (game, site) = try NativePagedSalvageFixture.game(fullOrdinaryPools: true)
    let original = game.commander.salvageLedger
    #expect(original.wreckMotion(for: site.identity) == nil)
    let wreck = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(wreck.source == .generated(site) && wreck.seed == original.nativeInspectionSeed)
    let observedCutterResult = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult)
    let hot = try #require(game.nativeSalvageWork)
    let expected = SalvageLootProfiles.plan(
      section: hot.plan.section, seed: original.nativeInspectionSeed, source: hot.plan.source)
    #expect(hot.plan == expected && hot.cycle.currentWorkSeconds == 0.1)
    #expect(hot.cycle.releases == 0 && hot.cycle.progress.nextLot == 0)
    #expect(game.commander.salvageLedger == original)
    #expect(game.commander.alienStorageState?.current.snapshot.sources.isEmpty == true)
    let observedWorkFlush = game.flushNativeSalvageWork()
    #expect(observedWorkFlush)
    #expect(game.commander.salvageLedger == original)
    let snapshot = try #require(game.commander.alienStorageState?.current.snapshot)
    try snapshot.validate()
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: snapshot, previous: nil, into: &pages)
    let observedDecodedSnapshot = try AlienStoragePageCodec.decode(
      reference: archive.reference, expectedOwner: snapshot.owner, rootData: archive.rootData,
      from: pages)
    #expect(
      observedDecodedSnapshot == snapshot)
    #expect(pages.pages.values.allSatisfy { $0.count <= AlienStoragePageCodec.maximumPageBytes })
    let body = try #require(
      game.bodies.first {
        $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
      })
    game.selectFlightTool(.salvageCutter)
    try NativePagedSalvageFixture.engageSalvageTarget(&game, body: body, section: hot.plan.section)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    var released = await runtime.snapshot()
    for _ in 0..<2000 {
      released = await runtime.advance(delta: 0.02)
      if released.commander.alienStorageState?.current.salvage.native.works[
        hot.cycle.inspection.id]?.releases == 1
      {
        break
      }
    }
    let native = try #require(released.commander.alienStorageState?.current.salvage)
    #expect(native.native.works[hot.cycle.inspection.id]?.releases == 1)
    #expect(!native.pending.isEmpty && native.pending.count <= 8)
    #expect(released.commander.salvageLedger.pendingLots == original.pendingLots)
    #expect(released.commander.salvageLedger.inventory == original.inventory)
    // Actual native spawn admission shares only the original producer sequence.
    // Compare the complete old semantic ledger after accounting for that one allocator.
    var actualFields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(released.commander.salvageLedger))
        as? [String: Any])
    let oldFields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    actualFields["sequence"] = oldFields["sequence"]
    let retained = try JSONDecoder().decode(
      SalvageLedger.self, from: JSONSerialization.data(withJSONObject: actualFields))
    #expect(retained == original)
    #expect(native.native.plans[hot.cycle.inspection.id]?.plan == expected)
    #expect(native.native.works[hot.cycle.inspection.id]?.currentWorkSeconds == 0)

  }

  @Test func originalInspectionPartialBudgetAndActualMovingPoseSurviveNativeSaveAndNoWriteReload()
    async throws
  {
    var (game, site) = try NativePagedSalvageFixture.game()
    game.selectFlightTool(.salvageCutter)
    let original = game.commander.salvageLedger
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    let worked = await runtime.advance(delta: 0.1)
    let hot = try #require(worked.nativeSalvageWork)
    try await runtime.save(to: file)
    let ready = await runtime.snapshot()
    let snapshot = try #require(ready.commander.alienStorageState?.current.snapshot)
    let native = try NativeSalvagePlanView(snapshot.world)
    let cycle = try #require(native.works[hot.cycle.inspection.id])
    #expect(cycle.currentWorkSeconds == 0.1 && cycle.releases == 0)
    #expect(native.plans[hot.cycle.inspection.id]?.plan == hot.plan)
    #expect(ready.commander.salvageLedger == original)
    let body = try #require(
      ready.bodies.first {
        $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
      })
    #expect(native.wrecks[site.identity]?.motion.pose == ready.modelPose(of: body))
    #expect(snapshot.sources.isEmpty && snapshot.attachments.isEmpty && snapshot.upgrades.isEmpty)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 27)
    var expectedDisk = ready.commander
    expectedDisk.npcPersistence.resetPhysicalBindings(system: ready.systemIdentity)
    let observedDiskCommander = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(observedDiskCommander == expectedDisk)
    try await runtime.load(from: file, persistMigrations: false)
    let restored = await runtime.snapshot()
    #expect(restored.commander == ready.commander && restored.bodies == ready.bodies)
    let observedFileBytes = try Data(contentsOf: file)
    #expect(observedFileBytes == bytes)
    #expect(restored.nativeSalvageWork == nil)
  }

  @Test
  func actualActorWriterRefusalRetainsCompletedBudgetAndRetryMovesReleasedFragmentsInTheSameFrame()
    async throws
  {
    var (game, site) = try NativePagedSalvageFixture.game()
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    game.selectFlightTool(.salvageCutter)
    let metadata = try #require(body.physical?.salvage)
    let originalSurface = game.workSurface(for: body, metadata: metadata)
    let originalSection = try #require(originalSurface?.section)
    try NativePagedSalvageFixture.engageSalvageTarget(&game, body: body, section: originalSection)
    let folder = try NativePagedSalvageFixture.folder()
    let preserved = folder.appendingPathExtension("preserved")
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: preserved)
    }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    try FileManager.default.moveItem(at: folder, to: preserved)
    try Data("writer blocked".utf8).write(to: folder)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    var refused = await runtime.snapshot()
    for _ in 0..<2000 {
      refused = await runtime.advance(delta: 0.02)
      if refused.message == "SALVAGE SAVE FAILED - COMPLETED WORK RETAINED" { break }
    }
    #expect(refused.message == "SALVAGE SAVE FAILED - COMPLETED WORK RETAINED")
    let hot = try #require(refused.nativeSalvageWork)
    #expect(hot.cycle.currentWorkSeconds == hot.section.workSeconds && hot.cycle.releases == 0)
    #expect(refused.commander.alienStorageState?.current.snapshot.sources.isEmpty == true)
    #expect(refused.commander.alienStorageState?.current.salvage.pending.isEmpty == true)
    #expect(
      !refused.bodies.contains {
        $0.physical?.payload.map { if case .salvage = $0 { true } else { false } } == true
      })
    let observedFileBytes2 = try Data(
      contentsOf: preserved.appendingPathComponent("commander.json"))
    #expect(observedFileBytes2 == bytes)
    var noWriterGame = refused
    // A new actor invalidates scene authority. Retain the completed budget at the
    // genuine cold value boundary, then reacquire it in that actor's own epoch.
    let observedWorkFlush2 = noWriterGame.flushNativeSalvageWork()
    #expect(observedWorkFlush2)
    let control = GameRuntime(game: noWriterGame)
    await control.setControls(NativePagedSalvageFixture.firingControls)
    let noWriter = await control.advance(delta: 0.02)
    try FileManager.default.removeItem(at: folder)
    try FileManager.default.moveItem(at: preserved, to: folder)
    let retry = await runtime.advance(delta: 0.02)
    // The completed budget spends no second cutter work, energy or heat. Guidance
    // and ordinary frame recharge still run identically in both actual simulations.
    #expect(abs(retry.energy - noWriter.energy) < 1e-8)
    #expect(abs(retry.laserHeat - noWriter.laserHeat) < 1e-8)
    let native = try #require(retry.commander.alienStorageState?.current.salvage)
    let cycle = try #require(native.native.works[hot.cycle.inspection.id])
    #expect(cycle.releases == 1 && cycle.currentWorkSeconds == 0 && !cycle.damagedTechnology)
    #expect(!native.pending.isEmpty && native.pending.count <= 8)
    for pending in native.pending.values {
      let released = try #require(retry.bodies.first { $0.physical?.identity == pending.binding })
      let position = retry.commander.flightSimulation.pose.systemPoint(released.position)
      #expect((position - pending.lot.position - pending.lot.velocity * 0.02).length < 1e-7)
      #expect(retry.currentSalvageLot(for: released)?.identity == pending.lot.identity)
    }
    let after = await runtime.advance(delta: 0.02)
    #expect(
      after.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]?
        .releases == 1)
    #expect(
      after.commander.alienStorageState?.current.salvage.pending.count == native.pending.count)
  }

  @Test func nativeActualDeathPreservesThePartialInspectionAndNeverReadmitsTheGeneratedParent()
    throws
  {
    var (game, site) = try NativePagedSalvageFixture.game()
    let observedCutterResult2 = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult2)
    let index = try #require(
      game.bodies.firstIndex {
        $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
      })
    let player = try #require(game.commander.flightSimulation.player)
    let allocatedAttackOrigin = game.makeAttackOrigin(owner: player)
    let origin = try #require(allocatedAttackOrigin)
    let before = game.bodies[index]
    let hit = GameplayHit(
      target: .body(before.id), distance: before.position.length, point: before.position)
    let observedCombatResult = game.applyCombatHit(
      hit, origin: origin, kind: .laser, damage: before.energy + 1, laser: .pulse)
    #expect(
      observedCombatResult != nil)
    game.commander.crimeLedger.finishEmission(origin.emissionID)
    game.resolveDestroyed()
    #expect(!game.bodies.contains { $0.id == before.id })
    let native = try #require(game.commander.alienStorageState?.current.salvage.native)
    #expect(native.wrecks[site.identity]?.destroyedAt != nil)
    #expect(native.wrecks[site.identity]?.motion.energy.map { $0 <= 0 } == true)
    #expect(native.depletedSections.contains { $0.wreck == site.identity })
    let snapshot = try #require(game.commander.alienStorageState?.current.snapshot)
    game.activateNearbySalvageSites()
    #expect(game.commander.alienStorageState?.current.snapshot == snapshot)
    #expect(!game.bodies.contains { $0.physical?.salvage?.wreck == site.identity })
    #expect(game.commander.salvageLedger.wreckMotion(for: site.identity) == nil)
  }
}

extension NativePagedSalvageRuntimeTests {
  @Test(arguments: [SalvageTool.cutter, .miningLaser])
  func actualCutterContinuesTheOriginalImportedPartialBudgetWithoutRewritingUnknownHistory(
    originalTool: SalvageTool
  ) async throws {
    var (game, site) = try NativePagedSalvageFixture.game()
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
      technology: game.currentSystem.technology, ownership: .abandoned)
    // The old producer builds its genuine allocator and optional partial work. No
    // inspection, issuance or acquisition date is invented for those old values.
    for section in profile.sections {
      let allocatedIncident = game.commander.flightSimulation.allocateIncident()
      let operation = try #require(allocatedIncident)
      let result = game.commander.salvageLedger.advance(
        wreck: site.identity, section: section, pose: game.modelPose(of: body),
        velocity: body.physical!.velocity, angularVelocity: body.physical!.angularVelocity,
        tool: originalTool, elapsed: min(0.25, section.workSeconds / 4), operation: operation,
        conditions: NativePagedSalvageFixture.permitted, source: source)
      guard case .progress = result else { throw SaveError.invalidCommander }
    }
    let ledger = game.commander.salvageLedger
    let cargo = game.commander.cargo
    let inventory = game.commander.equipmentInventory
    let credits = game.commander.credits
    let observedCutterResult3 = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult3)
    let hot = try #require(game.nativeSalvageWork)
    guard case .legacy(let reference) = hot.cycle.inspection else {
      throw SaveError.invalidCommander
    }
    let original = try ledger.exportNativeSection(hot.plan.section)
    let imported = try #require(
      game.commander.alienStorageState?.current.snapshot.world.compactMap {
        record -> AlienStorageLegacySection? in
        if case .legacySection(let item) = record, item.id == reference { return item }
        return nil
      }.first)
    #expect(imported.plan == original.plan && imported.progress == original.progress)
    #expect(imported.savedPartialWorkSeconds == original.partialWork)
    #expect(imported.savedDamagedTechnology == original.damagedTechnology)
    #expect(imported.savedLedgerLastOperation == original.lastOperation)
    #expect(
      hot.cycle.currentWorkSeconds
        == min(hot.section.workSeconds, (original.partialWork ?? 0) + 0.1))
    #expect(hot.cycle.releases == 0 && hot.cycle.lastRelease == nil)
    #expect(hot.cycle.progress.discarded == original.progress.discarded)
    #expect(hot.plan == original.plan && hot.seed == original.seed)
    #expect(
      game.commander.cargo == cargo && game.commander.equipmentInventory == inventory
        && game.commander.credits == credits)
    #expect(game.commander.salvageLedger.isNativeTransferred(hot.plan.section))
    #expect(game.commander.alienStorageState?.current.snapshot.sources.isEmpty == true)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let observedWorkFlush3 = game.flushNativeSalvageWork()
    #expect(observedWorkFlush3)
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    try await runtime.load(from: file, persistMigrations: false)
    let restored = await runtime.snapshot()
    let restoredCycle = try #require(
      restored.commander.alienStorageState?.current.salvage.native.works[reference])
    #expect(restoredCycle == hot.cycle)
    #expect(
      restored.commander.alienStorageState?.current.snapshot.world.contains(
        .legacySection(imported)) == true)
  }
}

extension NativePagedSalvageRuntimeTests {
  @Test func genuineCullRevisitAndReloadPreserveTheExactRetainedMotionAndPartialBudget()
    async throws
  {
    var (game, site) = try NativePagedSalvageFixture.game()
    let observedCutterResult4 = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult4)
    let hot = try #require(game.nativeSalvageWork)
    let parent = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let actor = try #require(parent.physical?.identity)
    let pose = game.commander.flightSimulation.pose
    game.tick(delta: 0.1)
    let moved = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect((game.modelPose(of: moved).position - game.modelPose(of: parent).position).length > 0)
    NativePagedSalvageFixture.moveObserver(
      &game, to: .init(position: pose.position + .init(50000, 0, 0), orientation: pose.orientation))
    game.tick(delta: 0.02)
    #expect(!game.bodies.contains { $0.physical?.identity == actor })
    let parked = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(parked.binding == nil && parked.destroyedAt == nil)
    #expect(
      game.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]?
        .currentWorkSeconds == 0.1)
    NativePagedSalvageFixture.moveObserver(&game, to: pose)
    game.activateNearbySalvageSites()
    let returned = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    #expect(returned.physical?.identity != actor)
    #expect((game.modelPose(of: returned).position - parked.motion.pose.position).length < 1e-8)
    #expect(
      (game.modelPose(of: returned).orientation.x - parked.motion.pose.orientation.x).length < 1e-8)
    #expect(returned.energy == parked.motion.energy)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let ready = await runtime.snapshot()
    let bytes = try Data(contentsOf: file)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == ready.commander && loaded.bodies == ready.bodies)
    #expect(
      loaded.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]?
        .currentWorkSeconds == 0.1)
    let observedFileBytes3 = try Data(contentsOf: file)
    #expect(observedFileBytes3 == bytes)
    let anchors = try #require(loaded.commander.flightSimulation.anchors)
    let expectedSites = SalvageSites.generate(anchors: anchors, seed: loaded.gameplaySeed)
    #expect(loaded.salvageSites == expectedSites && expectedSites.contains(site))
    #expect(!loaded.salvageHUDLines.isEmpty)
    let loadedView = try #require(loaded.commander.alienStorageState?.current.salvage.native)
    let originalInspection = try #require(loadedView.inspections[hot.plan.section])
    let originalCycle = try #require(loadedView.works[hot.cycle.inspection.id])
    let loadedParent = try #require(
      loaded.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let loadedActor = try #require(loadedParent.physical?.identity)
    let observer = loaded.commander.flightSimulation.pose
    var revisiting = loaded
    NativePagedSalvageFixture.moveObserver(
      &revisiting,
      to: .init(position: observer.position + .init(50000, 0, 0), orientation: observer.orientation)
    )
    revisiting.tick(delta: 0.02)
    #expect(!revisiting.bodies.contains { $0.physical?.identity == loadedActor })
    let retained = try #require(
      revisiting.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(retained.binding == nil && retained.destroyedAt == nil)
    #expect(
      revisiting.commander.alienStorageState?.current.salvage.native.inspections[hot.plan.section]
        == originalInspection)
    #expect(
      revisiting.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]
        == originalCycle)
    NativePagedSalvageFixture.moveObserver(&revisiting, to: observer)
    revisiting.activateNearbySalvageSites()
    let admitted = revisiting.bodies.filter {
      $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
    }
    #expect(admitted.count == 1)
    let returnedAfterLoad = try #require(admitted.first)
    let returnedPose = revisiting.modelPose(of: returnedAfterLoad)
    #expect(returnedAfterLoad.physical?.identity != loadedActor)
    #expect((returnedPose.position - retained.motion.pose.position).length < 1e-8)
    #expect((returnedPose.orientation.x - retained.motion.pose.orientation.x).length < 1e-8)
    #expect((returnedPose.orientation.y - retained.motion.pose.orientation.y).length < 1e-8)
    #expect((returnedPose.orientation.z - retained.motion.pose.orientation.z).length < 1e-8)
    #expect(returnedAfterLoad.energy == retained.motion.energy)
    #expect(returnedAfterLoad.physical?.velocity == retained.motion.velocity)
    #expect(returnedAfterLoad.physical?.angularVelocity == retained.motion.angularVelocity)
    #expect(
      revisiting.commander.alienStorageState?.current.salvage.native.works[hot.cycle.inspection.id]
        == originalCycle)
    #expect(revisiting.commander.salvageLedger == loaded.commander.salvageLedger)
    let observedFileBytes4 = try Data(contentsOf: file)
    #expect(observedFileBytes4 == bytes)
  }

  @Test func coldSceneCensusRejectsMissingDuplicateAndReboundNativeWreckActors() throws {
    var (game, site) = try NativePagedSalvageFixture.game()
    let observedPosePersistence = game.persistSalvagePoses()
    #expect(observedPosePersistence)
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    #expect(
      game.commander.nativeSalvageSceneIsConsistent(
        game.bodies, docked: false, atColdBoundary: true))
    let missing = game.bodies.filter { $0.id != body.id }
    #expect(
      !game.commander.nativeSalvageSceneIsConsistent(missing, docked: false, atColdBoundary: true))
    var duplicate = body
    duplicate.id = game.nextBodyID + 1
    #expect(
      !game.commander.nativeSalvageSceneIsConsistent(
        game.bodies + [duplicate], docked: false, atColdBoundary: true))
    var rebound = body
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let originalPhysical = try #require(body.physical)
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(originalPhysical)) as? [String: Any])
    fields["identity"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(actor))
    rebound.physical = try JSONDecoder().decode(
      PhysicalActorState.self, from: JSONSerialization.data(withJSONObject: fields))
    let replacement = game.bodies.map { $0.id == body.id ? rebound : $0 }
    #expect(
      !game.commander.nativeSalvageSceneIsConsistent(
        replacement, docked: false, atColdBoundary: true))
    var moved = body
    moved.position.x += 1
    #expect(
      !game.commander.nativeSalvageSceneIsConsistent(
        game.bodies.map { $0.id == body.id ? moved : $0 }, docked: false, atColdBoundary: true))
  }
}

extension NativePagedSalvageRuntimeTests {
  @Test(arguments: ["save", "dock", "arrival", "galactic"])
  func invalidActualMotionRefusesColdBoundariesWithoutLosingTheHotSession(boundary: String)
    async throws
  {
    var (game, site) = try NativePagedSalvageFixture.game()
    if boundary == "galactic" {
      try game.commander.grantEquipment(
        "Galactic Hyperdrive", at: .utility(.galacticHyperdrive),
        provenance: .grant("cold boundary test"))
    }
    let observedNPCRefusals = game.persistNPCStates()
    #expect(observedNPCRefusals.isEmpty)
    let observedPosePersistence2 = game.persistSalvagePoses()
    #expect(observedPosePersistence2)
    let observedCutterResult5 = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult5)
    let index = try #require(
      game.bodies.firstIndex {
        $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
      })
    game.bodies[index].physical?.angularVelocity = .init(.infinity, 0, 0)
    let original = game.commander
    let work = try #require(game.nativeSalvageWork)
    let originalScreen = game.screen
    switch boundary {
    case "save":
      let folder = try NativePagedSalvageFixture.folder()
      defer { try? FileManager.default.removeItem(at: folder) }
      let file = folder.appendingPathComponent("commander.json")
      // Exercise the actual native save barrier while this hot epoch is still
      // current, before checking the actor's separate refused value handoff.
      #expect(game.nativeSalvageHotWorkIsCurrent(work))
      #expect(throws: SaveError.invalidCommander) {
        _ = try GameRuntime.prepareNativeSaveState(game)
      }
      let runtime = GameRuntime(game: game)
      let before = await runtime.snapshot()
      var refused = false
      do { try await runtime.save(to: file) } catch { refused = true }
      #expect(refused && !FileManager.default.fileExists(atPath: file.path))
      let after = await runtime.snapshot()
      #expect(after.commander == before.commander)
      #expect(after.nativeSalvageWork?.cycle == work.cycle && after.bodies == before.bodies)
      return
    case "dock": game.dock()
    case "arrival": game.arrive()
    case "galactic": game.galacticJump()
    default: throw SaveError.invalidCommander
    }
    #expect(game.commander == original && game.screen == originalScreen && !game.docked)
    #expect(game.nativeSalvageWork?.cycle == work.cycle)
    #expect(game.commander.alienStorageState?.current.salvage.pending.isEmpty == true)
  }
}
