import Foundation
import Testing

@testable import EliteCore

struct NativeOriginalSurveyScanTests {
  @Test func surveyOnlyOrderedDistinctRealMarkersProduceMeasuredReadings() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.aim(runtime, ordinal: 1)
    for _ in 0..<125 { _ = await runtime.advance(delta: 0.1) }
    #expect(try await f.source(runtime).readings.isEmpty)
    try await f.view(runtime, ordinal: 0)
    let first = try await f.source(runtime)
    let reading = try #require(first.readings.first)
    #expect(reading.ordinal == 0 && reading.permission == first.permission?.operation)
    #expect(reading.end - reading.start >= 12 && reading.qualifiedSeconds >= 12)
    #expect(reading.intervals >= 120 && reading.actor.visit == reading.player.visit)
    #expect(await runtime.snapshot().originalSurveyScanStatus?.contains("1/3") == true)
    try await f.aim(runtime, ordinal: 0)
    for _ in 0..<125 { _ = await runtime.advance(delta: 0.1) }
    #expect(try await f.source(runtime).readings == first.readings)
    try await f.aim(runtime, ordinal: 2)
    _ = await runtime.advance(delta: 0.1)
    #expect(try await f.source(runtime).readings == first.readings)
    try await f.view(runtime, ordinal: 1)
    try await f.view(runtime, ordinal: 2)
    let complete = try await f.source(runtime)
    #expect(complete.readings.map(\.ordinal) == [0, 1, 2])
    #expect(Set(complete.readings.map(\.marker)).count == 3)
    #expect(Set(complete.readings.map(\.operation)).count == 3)
    #expect(complete.terminalOperation == nil)
  }

  @Test(arguments: [
    "range", "aim", "occluded", "equipment", "caller-clamped", "missing-interval", "epoch", "view",
    "culled",
  ])
  func surveyNativeFrameQualificationResetsGapsAndHonorsOnlyMeasuredTime(reason: String)
    async throws
  {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.aim(runtime, ordinal: 0)
    for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
    let qualified = await runtime.snapshot()
    let previous = try #require(qualified.nativeOriginalSurveyRuntime?.observation)
    if reason == "range" { try await f.aim(runtime, ordinal: 0, distance: 2000) }
    if reason == "aim" {
      await runtime.nativeCommand { game in
        var pose = game.commander.flightSimulation.pose
        let right = pose.orientation.x
        let forward = pose.orientation.z
        pose.orientation.x = right * cos(0.2) + forward * sin(0.2)
        pose.orientation.z = forward * cos(0.2) - right * sin(0.2)
        NativeStationTestFixture.reframe(&game, to: pose)
      }
      let turned = await runtime.snapshot()
      let target = try #require(turned.informationTargetBody)
      try #require(target.position.z / target.position.length < cos(2 * .pi / 180))
      try #require(turned.originalSurveySample() == nil)
    }
    if reason == "occluded" {
      await runtime.nativeCommand { game in
        let id = game.nextBodyID
        game.nextBodyID += 1
        game.bodies.append(.init(id: id, hull: .cargo, position: .init(0, 0, 500)))
        game.ensurePhysicalActors()
      }
    }
    if reason == "equipment" {
      await runtime.nativeCommand { game in
        guard let key = game.commander.fittedEquipment(at: .targetingCore)?.node.key else { return }
        _ = try? game.commander.removeFittedEquipment(key)
      }
    }
    if reason == "epoch" { await runtime.nativeCommand { $0.invalidateNativeStationAuthority() } }
    if reason == "view" { await runtime.key("1") }
    if reason == "culled" {
      let target = try #require(qualified.informationTargetBody)
      let marker = try #require(target.missionActorID)
      let mission = try #require(target.missionInstanceID)
      await runtime.nativeCommand { game in
        var pose = game.commander.flightSimulation.pose
        pose.position = pose.position + pose.orientation.z * 100_000
        NativeStationTestFixture.reframe(&game, to: pose)
        game.tick(delta: 0.1)
      }
      let culled = await runtime.snapshot()
      try #require(!culled.bodies.contains { $0.missionActorID == marker })
      let retained = try #require(
        culled.commander.scriptState.instances[mission]?.ownedEncounters[
          NativeOriginalSurvey.encounterID]?.actors[NativeOriginalSurvey.targets[0]])
      try #require(retained.identity == marker && retained.presence == .outside)
      try #require(culled.originalSurveySample() == nil)
    }
    if reason == "missing-interval" {
      // A real native tick outside the observing ingress creates an actual unobserved time gap.
      await runtime.nativeCommand { $0.tick(delta: 0.1) }
    }
    _ = await runtime.advance(delta: reason == "caller-clamped" ? 0.2 : 0.1)
    let after = await runtime.snapshot()
    #expect(after.originalSurveyState?.readings.isEmpty == true)
    let elapsed = after.nativeOriginalSurveyRuntime?.observation?.seconds ?? 0
    if reason == "caller-clamped" {
      let nativeDelta =
        after.commander.flightSimulation.physicalTime
        - qualified.commander.flightSimulation.physicalTime
      #expect(nativeDelta > 0 && nativeDelta <= 0.1 + 1e-9)
      #expect(abs(elapsed - previous.seconds - nativeDelta) < 1e-8)
    } else {
      #expect(elapsed < 0.11)
    }
    #expect(after.commander.scriptState.savedClueJournal == nil)
  }

  @Test func surveyActuallyDestroyedMarkerCannotBeScannedOrReplacedByItsHull() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let permission = try #require(source.permission)
    try await f.renas(runtime)
    try await f.aim(runtime, ordinal: 0)
    await runtime.key("u")
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<500 {
      let game = await runtime.snapshot()
      if game.commander.scriptState.instances[permission.mission]?.ownedEncounters[
        NativeOriginalSurvey.encounterID]?.actors[NativeOriginalSurvey.targets[0]]?
        .presence == .destroyed
      {
        break
      }
      _ = await runtime.advance(delta: 0.05)
    }
    await runtime.setControls(Controls())
    let destroyed = await runtime.snapshot()
    #expect(
      destroyed.commander.scriptState.instances[permission.mission]?.ownedEncounters[
        NativeOriginalSurvey.encounterID]?.actors[NativeOriginalSurvey.targets[0]]?
        .presence == .destroyed)
    #expect(destroyed.originalSurveyState?.readings.isEmpty == true)
    #expect(destroyed.originalSurveySample() == nil)
    for _ in 0..<125 { _ = await runtime.advance(delta: 0.1) }
    #expect(try await f.source(runtime).readings.isEmpty)
    #expect(await runtime.snapshot().commander.scriptState.savedClueJournal == nil)
  }

  @Test func surveyPauseAndReadOnlyPanelDoNotAccrueAndColdLoadResetsOnlyPartialView() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    try await f.aim(runtime, ordinal: 1)
    for _ in 0..<20 { _ = await runtime.advance(delta: 0.1) }
    let before = await runtime.snapshot()
    let partial = try #require(before.nativeOriginalSurveyRuntime?.observation)
    for _ in 0..<10 {
      let game = await runtime.snapshot()
      if let info = game.targetInformation {
        _ = TargetPanelLayout(
          game: game, info: info,
          cockpit: CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
        )
      }
      _ = game.scriptCommanderQuery
      _ = game.originalSurveyScanStatus
    }
    #expect(await runtime.snapshot().nativeOriginalSurveyRuntime?.observation == partial)
    await runtime.key("pause")
    for _ in 0..<20 { _ = await runtime.advance(delta: 0.1) }
    #expect(await runtime.snapshot().nativeOriginalSurveyRuntime?.observation == partial)
    #expect(
      await runtime.snapshot().commander.flightSimulation.physicalTime
        == before.commander.flightSimulation.physicalTime)
    await runtime.key("pause")
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(
      cold.originalSurveyState?.readings
        == before.originalSurveyState?.readings)
    #expect(
      cold.nativeOriginalSurveyRuntime?.observation == nil
        && cold.nativeOriginalSurveyRuntime?.pending == nil)
    await runtime.key("0")
    try await f.aim(runtime, ordinal: 1)
    _ = await runtime.advance(delta: 0.1)
    #expect(await runtime.snapshot().nativeOriginalSurveyRuntime?.observation?.seconds ?? 0 < 0.11)
    #expect(try await f.source(runtime).readings.count == 1)
  }

  @Test func surveyCompletedAuthoritySurvivesActualTargetingRefitAndColdEpochRotation()
    async throws
  {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    let original = try await f.source(runtime)
    let reading = try #require(original.readings.first)
    try await f.base.flight.dock(runtime)
    await runtime.procurementRefuel()
    try await f.base.flight.travel(runtime, path: [185, 7])
    let before = await runtime.snapshot()
    try await runtime.surveyBuyTargetingIdentification()
    let refitted = await runtime.snapshot()
    #expect(refitted.commander.targetingTier == .identification)
    #expect(refitted.commander.fittedEquipment(at: .targetingCore)?.id != reading.equipment)
    #expect(refitted.commander.credits < before.commander.credits)
    #expect(refitted.commander.equipmentInventory?.revision != reading.inventoryRevision)
    try await runtime.save(to: f.save)
    let oldEpoch = await runtime.snapshot().nativeStationRuntimeEpoch
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(
      cold.nativeStationRuntimeEpoch != oldEpoch && cold.nativeStationRuntimeEpoch != reading.epoch)
    #expect(cold.originalSurveyState?.readings == original.readings)
    #expect(cold.originalSurveyState?.authorities == original.authorities)
    #expect(NativeOriginalSurveySave.validateClaims(cold.commander))
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 1)
    let continued = try await f.source(runtime)
    #expect(continued.readings[0] == reading)
    #expect(continued.readings[1].equipment != reading.equipment)
  }

  @Test func surveyReadingWriterRefusalRetainsOnlyMeasuredReceiptAndNeverRollsBackPhysics()
    async throws
  {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.aim(runtime, ordinal: 0)
    for _ in 0..<119 { _ = await runtime.advance(delta: 0.1) }
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("survey-scan")
    for _ in 0..<3 {
      _ = await runtime.advance(delta: 0.1)
      if await runtime.snapshot().nativeOriginalSurveyRuntime?.pending != nil { break }
    }
    let failed = await runtime.snapshot()
    let pending = try #require(failed.nativeOriginalSurveyRuntime?.pending)
    let reading = pending.reading
    #expect(
      failed.commander.flightSimulation.physicalTime
        > before.commander.flightSimulation.physicalTime)
    #expect(failed.commander.nativePeople == before.commander.nativePeople)
    #expect(failed.commander.credits == before.commander.credits)
    #expect(failed.commander.scriptState.savedClueJournal == nil)
    try f.files.restoreWrites(held, files: files)
    _ = await runtime.advance(delta: 0.1)
    let committed = await runtime.snapshot()
    #expect(committed.originalSurveyState?.readings == [reading])
    #expect(
      committed.commander.flightSimulation.physicalTime
        > failed.commander.flightSimulation.physicalTime)
    #expect(committed.nativeOriginalSurveyRuntime?.pending == nil)
    _ = await runtime.advance(delta: 0.1)
    #expect(await runtime.snapshot().originalSurveyState?.readings == [reading])
  }

  @Test func surveyReturnCareWriterFailureKeepsPeopleReadingsCashAndClueAtomic() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.allViews(runtime)
    try await f.returnHome(runtime)
    let page = try await f.review(runtime, .receive)
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("survey-return")
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try f.files.restoreWrites(held, files: files)
    try await f.confirm(runtime, .receive)
    #expect(
      await runtime.snapshot().commander.credits == before.credits + NativeOriginalSurvey.reward)
    #expect(await runtime.snapshot().originalSurveyState?.readings.count == 3)
  }

}

extension GameRuntime {
  func surveyBuyTargetingIdentification() throws {
    try scriptCommand { game in
      let item = try #require(
        Equipment.all.first { $0.name == TargetingTier.identification.equipmentName })
      let quote = try game.quoteEquipmentPurchase(item)
      try #require(try game.applyEquipmentPurchase(quote))
    }
  }
}
