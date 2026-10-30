import Foundation
import Testing

@testable import L337Core

struct WayfarerRecordRecoveryAcquisitionTests {
  @Test func realIdentificationLeavesRecorderAtCradleAndCannotCollectInItsFrame() async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    let before = await runtime.snapshot()
    let receipt = try await f.identify(runtime)
    let identified = await runtime.snapshot()
    #expect(receipt.observations.count == 2)
    #expect(receipt.observations[1].physicalTime > receipt.observations[0].physicalTime)
    #expect(
      receipt.observations[1].physicalTime - receipt.observations[0].physicalTime <= 0.1 + 1e-9)
    #expect(identified.recordRecoveryState?.held.isEmpty == true)
    #expect(identified.recordRecoveryState?.captures.isEmpty == true)
    #expect(
      identified.commander.scriptState.savedRecordRecoverySource?.originals.first?.custody
        == .cradle)
    #expect(identified.commander.cargoTonnes == before.commander.cargoTonnes)
    #expect(identified.bodies.contains { $0.missionActorID == f.logical(accepted) })
    #expect(identified.commander.scriptState.savedClueJournal == nil)
    try await f.collect(runtime)
    #expect(
      await runtime.snapshot().recordRecoveryState?.captures.first?.identification
        == receipt.operation)
  }

  @Test(arguments: [
    "range", "aim", "occluded", "core", "module", "paused", "view", "zero", "binding",
  ])
  func actualNativeIdentificationRefusesUnqualifiedObservation(reason: String) async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.aim(runtime, distance: reason == "range" ? 100 : 1000)
    var game = await runtime.snapshot()
    if reason == "aim" {
      var pose = game.commander.flightSimulation.pose
      let right = pose.orientation.x
      let forward = pose.orientation.z
      pose.orientation.x = right * cos(0.2) + forward * sin(0.2)
      pose.orientation.z = forward * cos(0.2) - right * sin(0.2)
      NativeStationTestFixture.reframe(&game, to: pose)
    }
    if reason == "occluded" {
      let id = game.nextBodyID
      game.nextBodyID += 1
      game.bodies.append(.init(id: id, hull: .cargo, position: .init(0, 0, 500)))
      game.ensurePhysicalActors()
    }
    if reason == "core" || reason == "module" {
      let key =
        reason == "core" ? game.commander.targetingTier?.equipmentName : "Targeting: Salvage Module"
      if let key { _ = try game.commander.removeFittedEquipment(key) }
    }
    if reason == "paused" { game.paused = true }
    if reason == "view" { game.screen = .rear }
    if reason == "binding" {
      let logical = f.logical(accepted)
      let index = try #require(game.bodies.firstIndex { $0.missionActorID == logical })
      game.bodies[index].physical?.spawnIdentity = nil
    }
    if reason != "zero" { #expect(game.recordRecoveryIdentificationSample() == nil) }
    let collector = GameRuntime(game: game, saveURL: f.save)
    _ = await collector.advance(delta: reason == "zero" ? 0 : 0.05)
    #expect(try await f.state(collector).identification == nil, "reason: \(reason)")
    #expect(try await f.state(collector).captures.isEmpty)
  }

  @Test func actualScoopBeforeIdentificationGrantsNeitherReceiptNorCustody() async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.frame(runtime, offset: .init(0, -45, 55))
    let before = await runtime.snapshot()
    _ = await runtime.advance(delta: 0.05)
    let refused = await runtime.snapshot()
    #expect(refused.recordRecoveryState?.identification == nil)
    #expect(refused.recordRecoveryState?.captures.isEmpty == true)
    #expect(refused.bodies.contains { $0.missionActorID == f.logical(accepted) })
    #expect(refused.commander.cargoTonnes == before.commander.cargoTonnes)
  }

  @Test(arguments: ["aperture", "speed", "scoops", "module", "binding", "payload"])
  func committedIdentificationStillRequiresRealSafeCurrentCollector(reason: String) async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.identify(runtime)
    try await f.frame(
      runtime, offset: reason == "aperture" ? .init(30, -45, 55) : .init(0, -45, 55))
    var game = await runtime.snapshot()
    if reason == "speed" { game.speed = 250 }
    if reason == "scoops" || reason == "module" {
      _ = try game.commander.removeFittedEquipment(
        reason == "scoops" ? "Fuel Scoops" : "Targeting: Salvage Module")
    }
    let index = try #require(game.bodies.firstIndex { $0.missionActorID == f.logical(accepted) })
    if reason == "binding" { game.bodies[index].physical?.spawnIdentity = nil }
    if reason == "payload" {
      game.bodies[index].physical?.payload = .mission(
        instance: accepted.permission.mission, payload: "other-record")
    }
    let collector = GameRuntime(game: game, saveURL: f.save)
    _ = await collector.advance(delta: 0.05)
    #expect(try await f.state(collector).captures.isEmpty, "reason: \(reason)")
    #expect(await collector.snapshot().commander.scriptState.savedClueJournal == nil)
  }

  @Test(arguments: ["identify", "pickup"])
  func actualIdentificationAndPickupWriterRefusalPreserveAttainedStateAndRetryOnce(stage: String)
    async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    if stage == "pickup" {
      try await f.identify(runtime)
      try await f.frame(runtime, offset: .init(0, -45, 55))
    } else {
      try await f.aim(runtime)
    }
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("w05-\(stage)")
    _ = await runtime.advance(delta: 0.05)
    let failed = await runtime.snapshot()
    #expect(
      failed.commander.flightSimulation.physicalTime
        > before.commander.flightSimulation.physicalTime)
    #expect(failed.recordRecoveryState?.captures.isEmpty == true)
    #expect(failed.bodies.contains { $0.missionActorID == f.logical(accepted) })
    #expect(failed.commander.cargoTonnes == before.commander.cargoTonnes)
    #expect(failed.commander.credits == before.commander.credits)
    if stage == "identify" {
      #expect(failed.nativeRecordRecoveryIdentificationPending != nil)
      #expect(failed.recordRecoveryState?.identification == nil)
    } else {
      #expect(failed.nativeRecordRecoveryPending != nil)
    }
    if stage == "identify" {
      // Frame only the player inside the original actor's runtime. This preserves the
      // producer's pending attempt and epoch while keeping all custody changes native.
      let identity = f.logical(accepted)
      try await runtime.framePendingRecordRecoveryAtActualAperture(identity: identity)
      _ = await runtime.advance(delta: 0.05)
      let uncommitted = await runtime.snapshot()
      #expect(uncommitted.recordRecoveryState?.identification == nil)
      #expect(uncommitted.recordRecoveryState?.captures.isEmpty == true)
      #expect(uncommitted.nativeRecordRecoveryIdentificationPending != nil)
      try f.files.restoreWrites(blocked, files: files)
      _ = await runtime.advance(delta: 0.05)
      let identified = await runtime.snapshot()
      #expect(identified.recordRecoveryState?.identification != nil)
      #expect(identified.recordRecoveryState?.captures.isEmpty == true)
      #expect(identified.bodies.contains { $0.missionActorID == identity })
      _ = await runtime.advance(delta: 0.05)
    } else {
      try f.files.restoreWrites(blocked, files: files)
      try await runtime.save(to: f.save)
    }
    let retry = runtime
    try await retry.save(to: f.save)
    #expect(await retry.snapshot().recordRecoveryState?.captures.count == 1)
  }

  @Test func exactNativeFrameUsesRecorderAndCradleMeshMassAndRejectsUnprovedEndpoint() async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    var game = await runtime.snapshot()
    game.bodies = game.bodies.filter { $0.missionInstanceID == accepted.permission.mission }
    game.commander.nativeStations?.stationInertia = []
    let candidate = game.beginAsteroidContactStep(delta: 0.05)
    let frame = try #require(candidate)
    let originals = game.bodies
    for body in originals {
      let actor = try #require(body.physical?.identity)
      let snapshot = try #require(frame.identifiedSalvageSnapshot(actor))
      let mesh = try #require(game.scriptNPCMesh(body))
      #expect(snapshot.massKg == (body.missionActorID == f.logical(accepted) ? 1000 : 100000))
      #expect(snapshot.mesh.vertices == mesh.vertices && snapshot.mesh.faces == mesh.faces)
      #expect(!snapshot.debris && !snapshot.asteroid)
    }
    var unproved = game
    unproved.commander.scriptState.savedRecordRecoverySource = nil
    #expect(unproved.beginAsteroidContactStep(delta: 0.05) == nil)
    let refused = unproved.completeAsteroidContactStep(frame, delta: 0.05)
    if case .refused(let reason) = refused {
      #expect(reason == "ACTOR CHANGED")
    } else {
      Issue.record("A now-unproved original must reject the captured mesh.")
    }
    game.tick(delta: 0.05)
    #expect(!game.paused)
    let retained = game.bodies.filter { $0.missionInstanceID == accepted.permission.mission }
    #expect(
      Set(retained.compactMap(\.missionActorID)) == Set(originals.compactMap(\.missionActorID)))
    #expect(retained.allSatisfy { game.recordRecoveryCollision($0) != nil })
  }

  @Test func unrelatedMissionSameModelRetainsItsExistingCollisionPolicy() async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.celalen(runtime)
    let folder = f.files.root.appendingPathComponent("other-model")
    try FileManager.default.copyItem(
      at: ScriptPackLibrary.bundledRecordRecoveryDirectory, to: folder)
    let manifest = folder.appendingPathComponent("manifest.toml")
    let original = try String(contentsOf: manifest, encoding: .utf8)
    var skipping = false
    var lines: [String] = []
    for line in original.components(separatedBy: "\n") {
      if line == "[recordRecovery]" {
        skipping = true
        continue
      }
      if skipping && line == "[[handlers]]" { skipping = false }
      if !skipping { lines.append(line) }
    }
    let text = lines.joined(separator: "\n")
      .replacingOccurrences(
        of: "id = \"l337.wayfarer-service\"", with: "id = \"l337.w05-geometry-control\""
      )
      .replacingOccurrences(of: "\"native-record-recovery-v1\", ", with: "")
      .replacingOccurrences(of: "z=24000.0", with: "z=30000.0")
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let pack = try ScriptPackLibrary.read(folder)
    var game = await runtime.snapshot()
    game.scriptPacks.append(pack)
    let other = try game.acceptScriptMission(pack)
    game.emitScriptEvent("station.undocked", only: other)
    game.drainScriptEvents()
    let body = try #require(
      game.bodies.first {
        $0.missionInstanceID == other && $0.scriptNPC?.fit.definition.model == "catalogue:SH058"
      })
    #expect(game.recordRecoveryCollision(body) == nil)
    let actor = try #require(body.physical?.identity)
    let candidate = game.beginAsteroidContactStep(delta: 0.05)
    let frame = try #require(candidate)
    let snapshot = try #require(frame.identifiedSalvageSnapshot(actor))
    #expect(snapshot.massKg == 100000)
    #expect(snapshot.mesh.vertices == game.gameplayMesh(for: body).vertices)
    #expect(!snapshot.debris && !snapshot.asteroid)
  }

  @Test func consumedOriginalIsExcludedThroughActualVisitAndColdRebinding() async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.identify(runtime)
    try await f.collect(runtime)
    let capture = try #require(try await f.state(runtime).captures.first)
    try await f.returnHome(runtime)
    await runtime.procurementRefuel()
    try await f.celalen(runtime)
    #expect(
      !((await runtime.snapshot()).bodies.contains { $0.missionActorID == f.logical(accepted) }))
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    #expect(await runtime.snapshot().recordRecoveryState?.captures.first == capture)
    #expect(
      !((await runtime.snapshot()).bodies.contains { $0.missionActorID == f.logical(accepted) }))
  }

  @Test(arguments: [false, true])
  func actualFatalHullOrPaidEscapeLosesOnlyAnAboardOriginal(escape: Bool) async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(escapeReady: escape)
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.identify(runtime)
    try await f.collect(runtime)
    if escape {
      await runtime.key("escape-pod")
    } else {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.1)
    }
    let lost = await runtime.snapshot()
    #expect(lost.recordRecoveryState?.losses.first?.kind == (escape ? .escape : .hull))
    #expect(lost.recordRecoveryState?.held.isEmpty == true)
    #expect(lost.commander.scriptState.instances[accepted.permission.mission]?.outcome == .failed)
    #expect(
      lost.commander.scriptState.instances[accepted.permission.mission]?.payloads.isEmpty == true)
    #expect(lost.commander.scriptState.savedClueJournal == nil)
    let prepared = try GameRuntime.prepareNativeSaveState(lost)
    try await runtime.save(to: f.save)
    let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(cold == prepared.commander && world.consistent(with: cold))
  }

  @Test func actualWorldRecorderDestructionIsIrreversibleAndNeverPays() async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.aim(runtime)
    await runtime.key("u")
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<500 {
      if try await f.state(runtime).losses.count == 1 { break }
      _ = await runtime.advance(delta: 0.05)
    }
    await runtime.setControls(Controls())
    let lost = await runtime.snapshot()
    #expect(lost.recordRecoveryState?.losses.first?.kind == .destroyed)
    #expect(lost.recordRecoveryState?.held.isEmpty == true)
    #expect(lost.commander.scriptState.instances[accepted.permission.mission]?.outcome == .failed)
    #expect(
      lost.commander.scriptState.instances[accepted.permission.mission]?.payloads.isEmpty == true)
    #expect(lost.commander.scriptState.savedClueJournal == nil)
    try await runtime.save(to: f.save)
    let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(WayfarerRecordRecoverySave.validateClaims(cold, requireRecordedLoss: true))
    #expect(world.consistent(with: cold))
  }
}

extension WayfarerRecordRecoveryAcquisitionTests {
  @Test(arguments: [false, true])
  func genuineHullOrEscapeBeforePickupDoesNotConsumeUntouchedWorldRecorder(escape: Bool)
    async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(escapeReady: escape)
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.identify(runtime)
    if escape {
      await runtime.key("escape-pod")
    } else {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.1)
    }
    let actual = await runtime.snapshot()
    #expect(actual.recordRecoveryState?.losses.isEmpty == true)
    #expect(actual.recordRecoveryState?.captures.isEmpty == true)
    #expect(
      actual.commander.scriptState.savedRecordRecoverySource?.originals.first?.custody == .cradle)
    #expect(
      actual.commander.scriptState.instances[accepted.permission.mission]?.ownedEncounters[
        WayfarerRecordRecovery.encounterID]?.actors["cdr-001"]?.presence != .destroyed)
    #expect(actual.commander.scriptState.savedClueJournal == nil)
    if escape { #expect(actual.commander.fittedEquipment(at: .utility(.escapePod)) == nil) }
  }

  @Test func destroyedWorldConditionSurvivesWriterRefusalUntilItsSingleDurableLoss() async throws {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    try await f.aim(runtime)
    await runtime.key("u")
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("w05-world-loss")
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<500 {
      let game = await runtime.snapshot()
      if game.commander.scriptState.instances[accepted.permission.mission]?.ownedEncounters[
        WayfarerRecordRecovery.encounterID]?.actors["cdr-001"]?.presence == .destroyed
      {
        break
      }
      _ = await runtime.advance(delta: 0.05)
    }
    await runtime.setControls(Controls())
    let attained = await runtime.snapshot()
    #expect(
      attained.commander.scriptState.instances[accepted.permission.mission]?.ownedEncounters[
        WayfarerRecordRecovery.encounterID]?.actors["cdr-001"]?.presence == .destroyed)
    #expect(attained.recordRecoveryState?.losses.isEmpty == true)
    #expect(attained.recordRecoveryLossIsPending)
    try f.files.restoreWrites(blocked, files: files)
    try await runtime.save(to: f.save)
    let saved = await runtime.snapshot()
    #expect(saved.recordRecoveryState?.losses.count == 1)
    #expect(saved.recordRecoveryState?.losses.first?.kind == .destroyed)
    #expect(
      saved.commander.scriptState.instances[accepted.permission.mission]?.payloads.isEmpty == true)
    try await runtime.save(to: f.save)
    #expect(await runtime.snapshot().recordRecoveryState?.losses.count == 1)
    #expect(await runtime.snapshot().commander.scriptState.savedClueJournal == nil)
  }
}

extension GameRuntime {
  fileprivate func framePendingRecordRecoveryAtActualAperture(identity: UUID) throws {
    let pending = try #require(game.nativeRecordRecoveryIdentificationPending)
    let epoch = game.nativeStationRuntimeEpoch
    let physicalTime = game.commander.flightSimulation.physicalTime
    let state = game.recordRecoveryState
    let source = game.commander.scriptState.savedRecordRecoverySource
    let body = try #require(game.bodies.first { $0.missionActorID == identity })
    var pose = game.commander.flightSimulation.pose
    pose.position = pose.systemPoint(body.position) - pose.orientation.apply(.init(0, -45, 55))
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 0
    game.pitch = 0
    game.yaw = 0
    game.roll = 0
    #expect(game.nativeStationRuntimeEpoch == epoch)
    #expect(game.commander.flightSimulation.physicalTime == physicalTime)
    #expect(game.nativeRecordRecoveryIdentificationPending === pending)
    #expect(game.recordRecoveryState == state)
    #expect(game.commander.scriptState.savedRecordRecoverySource == source)
    let framed = try #require(game.bodies.first { $0.missionActorID == identity })
    let offset = framed.position - Vector3(0, -45, 55)
    #expect(offset.length < 1e-6)
    let context = try #require(game.gameplayContext())
    #expect(game.automaticScoopShapeCompatible(framed, context: context))
  }
}

extension WayfarerRecordRecoveryAcquisitionTests {
  @Test func actualAliasReaderKeepsCradleAndOriginalAuthorityAndRejectsUnmarkedOrForgedBodies()
    async throws
  {
    let f = try WayfarerRecordRecoveryFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.celalen(runtime)
    let game = await runtime.snapshot()
    let original = try #require(game.bodies.first { $0.missionActorID == f.logical(accepted) })
    let cradle = try #require(
      game.bodies.first { $0.missionActorID == f.logical(accepted, alias: "w05-cradle") })
    let originalAlias = game.recordRecoveryAlias(original)
    let cradleAlias = game.recordRecoveryAlias(cradle)
    #expect(originalAlias == "cdr-001")
    #expect(cradleAlias == "w05-cradle")
    let spawn = try #require(original.physical?.spawnIdentity)
    for mode in ["unmarked", "mission", "logical", "spawn", "visit", "retained-id"] {
      var changed = original
      switch mode {
      case "unmarked":
        changed.missionInstanceID = nil
        changed.missionActorID = nil
      case "mission": changed.missionInstanceID = UUID()
      case "logical": changed.missionActorID = UUID()
      case "spawn": changed.physical?.spawnIdentity = nil
      case "visit":
        changed.physical?.spawnIdentity = .init(
          system: spawn.system, visit: spawn.visit + 1, sequence: spawn.sequence,
          member: spawn.member, producer: spawn.producer)
      default: changed.id += 10000
      }
      let rejected = game.recordRecoveryAlias(changed)
      #expect(rejected == nil, "mode: \(mode)")
    }
    var unproved = game
    unproved.commander.scriptState.savedRecordRecoverySource = nil
    let revokedOriginal = unproved.recordRecoveryAlias(original)
    let revokedCradle = unproved.recordRecoveryAlias(cradle)
    #expect(revokedOriginal == nil && revokedCradle == nil)
  }
}
