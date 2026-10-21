import Foundation
import Testing

@testable import EliteCore

struct NativeOriginalRescueCapsuleTests {
  @Test func rescueGenuineNativeGrantCapturesAndRetainsCareAfterToolRemovalAndColdLoad()
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    let before = await runtime.snapshot().commander
    let digest = f.pack.digest
    await runtime.nativeCommand { game in
      do {
        _ = try game.commander.removeFittedEquipment("Fuel Scoops")
        try game.commander.grantMissionEquipment("Fuel Scoops", digest: digest)
      } catch { return }
    }
    let granted = await runtime.snapshot().commander
    let tool = try #require(granted.fittedEquipment(at: .utility(.fuelScoops)))
    try #require(tool.provenance == .grant("mission-pack:" + digest))
    #expect(granted.savedEquipmentPurchaseHistory == before.savedEquipmentPurchaseHistory)
    #expect(granted.credits == before.credits)
    try await f.collect(runtime, alias: "neri-capsule")
    let collected = try await f.source(runtime)
    let capture = try #require(collected.captures.first)
    #expect(capture.tool.id == tool.id && capture.tool.provenance == tool.provenance)
    try await f.flight.dock(runtime)
    try await f.confirm(runtime, .care)
    await runtime.nativeCommand { game in
      _ = try? game.commander.removeFittedEquipment("Fuel Scoops")
    }
    let removed = await runtime.snapshot()
    try #require(removed.commander.fittedEquipment(at: .utility(.fuelScoops)) == nil)
    let source = try #require(removed.commander.nativePeople?.originalRescue)
    #expect(source.captures == [capture])
    #expect(removed.commander.nativePeople?.transfers.first?.members == [source.references[0]])
    for alien in [false, true] {
      let cold = try f.roundTrip(removed, label: "native-grant", alien: alien)
      #expect(cold.nativePeople == removed.commander.nativePeople)
    }
  }

  @Test func rescueActualTabGuidanceCollectsTheRegisteredOriginalCapsule() async throws {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.accept(runtime)
    try await f.approach(runtime, alias: "neri-capsule", distance: 500)
    let before = await runtime.snapshot()
    let logical = NativeOriginalRescueJourney.actorIdentity(
      mission: source.mission, alias: "neri-capsule")
    let body = try #require(before.bodies.first { $0.missionActorID == logical })
    let actor = try #require(body.physical?.identity)
    let context = try #require(before.gameplayContext())
    let shapeFits = before.automaticScoopShapeCompatible(body, context: context)
    try #require(shapeFits)
    try #require(before.workTargetFilter == .ships)
    await runtime.key("f")
    await runtime.key("f")
    try #require(await runtime.snapshot().workTargetFilter == .salvage)
    await runtime.key("tab")
    let engaged = await runtime.snapshot()
    try #require(engaged.workGuidance?.parent == actor)
    try #require(engaged.workGuidance?.mode == .autoScoop(.salvage))
    for _ in 0..<600 {
      if try await f.source(runtime).captures.contains(where: { $0.actor == actor }) { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let after = await runtime.snapshot()
    let captured = try #require(after.commander.nativePeople?.originalRescue?.captures.first)
    #expect(captured.actor == actor && captured.logicalActor == logical)
    #expect(after.bodies.contains { $0.physical?.identity == actor } == false)
    #expect(after.commander.nativePeople?.admissions.count == 1)
    #expect(after.commander.rescuedPodTonnes == 1)
    #expect(after.commander.credits == before.commander.credits)
    #expect(after.commander.scriptState.savedClueJournal == nil)
    #expect(after.commander.valid)
  }

  @Test func rescueAcceptanceBackStaleAndFiniteReservationUseActualPaidCapacity() async throws {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(freeCargoTonnes: 1)
    let before = await runtime.snapshot().commander
    let page = try await NativePeopleTestFixture.review(runtime, row: .rescue(.accept))
    #expect(await runtime.snapshot().contractBoard.action == .back)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    let stale = try await NativePeopleTestFixture.review(runtime, row: .rescue(.accept))
    await runtime.nativeCommand { game in
      guard let item = Equipment.all.first(where: { $0.name == "E.C.M. System" }),
        let quote = try? game.quoteEquipmentPurchase(item)
      else { return }
      _ = try? game.applyEquipmentPurchase(quote)
    }
    await runtime.scriptPageKey("right", expected: stale)
    await runtime.scriptPageKey("return", expected: stale)
    #expect(await runtime.snapshot().commander.nativePeople?.originalRescue == nil)
    let source = try await f.accept(runtime)
    let accepted = await runtime.snapshot()
    #expect(accepted.commander.cargoTonnes == accepted.commander.standardCargoCapacity)
    #expect(accepted.commander.nativePeople?.admissions.isEmpty == true)
    #expect(accepted.commander.accommodation.fittedBerths.filter { $0.use.used }.count == 2)
    #expect(accepted.originalRescueQuote(.accept).allowed == false)
    #expect(
      accepted.commander.scriptState.instances[source.mission]?.contract?.offer.reward == 10200)
    #expect(accepted.commander.savedEMPState == nil)
  }

  @Test(arguments: ["one-cabin", "full-hold", "missing-tools"])
  func rescueQuoteRefusesAnActualMissingRequirement(reason: String) async throws {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(
      cabins: reason == "one-cabin" ? 1 : 2,
      freeCargoTonnes: reason == "full-hold" ? 0 : nil, tools: reason != "missing-tools")
    let before = await runtime.snapshot().commander
    #expect(await runtime.snapshot().originalRescueQuote(.accept).allowed == false)
    try await f.confirm(runtime, .accept)
    #expect(await runtime.snapshot().commander == before)
    #expect(before.nativePeople?.originalRescue == nil)
  }

  @Test func rescueFirstPodBlocksSecondUntilActualCareAndColdReentryCannotRepopulateIt()
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(freeCargoTonnes: 1)
    let source = try await f.accept(runtime)
    try await f.collect(runtime, alias: "neri-capsule")
    try await f.approach(runtime, alias: "ilan-capsule")
    let before = await runtime.snapshot()
    let second = try #require(
      before.bodies.first {
        $0.missionActorID
          == NativeOriginalRescueJourney.actorIdentity(
            mission: source.mission, alias: "ilan-capsule")
      })
    let context = try #require(before.gameplayContext())
    #expect(before.originalRescueFacts(second, context: context)?.fits == false)
    _ = await runtime.advance(delta: 0.05)
    #expect(try await f.source(runtime).captures.count == 1)
    #expect(await runtime.snapshot().commander.rescuedPodTonnes == 1)
    try await f.flight.dock(runtime)
    try await f.confirm(runtime, .care)
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    try await f.launch(runtime)
    let reentered = await runtime.snapshot()
    let first = NativeOriginalRescueJourney.actorIdentity(
      mission: source.mission, alias: "neri-capsule")
    #expect(!reentered.bodies.contains { $0.missionActorID == first })
    #expect(reentered.commander.nativePeople?.admissions.count == 1)
    #expect(reentered.commander.nativePeople?.transfers.first?.members == [source.references[0]])
    #expect(reentered.commander.nativePeople?.held.isEmpty == true)
    #expect(reentered.commander.cargoTonnes == reentered.commander.standardCargoCapacity)
    try await f.collect(runtime, alias: "ilan-capsule")
    #expect(try await f.source(runtime).captures.count == 2)
    #expect(await runtime.snapshot().commander.rescuedPodTonnes == 1)
  }

  @Test(arguments: ["range", "motion", "tools", "paused", "record-before-boarding"])
  func rescueCaptureRequiresActualToolsApertureMotionAndStage(reason: String) async throws {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    let alias = reason == "record-before-boarding" ? "emergency-record" : "neri-capsule"
    try await f.approach(runtime, alias: alias, distance: reason == "range" ? 500 : nil)
    if reason == "motion" { await runtime.nativeCommand { $0.speed = 10 } }
    if reason == "tools" {
      await runtime.nativeCommand { _ = try? $0.commander.removeFittedEquipment("Fuel Scoops") }
      try #require(await runtime.snapshot().hasNativeRescueTools == false)
    }
    if reason == "paused" { await runtime.key("pause") }
    let before = await runtime.snapshot()
    _ = await runtime.advance(delta: 0.05)
    let after = await runtime.snapshot()
    #expect(after.commander.nativePeople?.originalRescue?.captures.isEmpty == true)
    #expect(after.commander.nativePeople?.originalRescue?.record == nil)
    #expect(after.commander.nativePeople?.admissions.isEmpty == true)
    #expect(after.commander.cargo == before.commander.cargo)
    #expect(after.commander.scriptState.savedClueJournal == nil)
  }

  @Test func rescueClassifierRejectsDeadForeignEmptyAndReplacedActorsWithoutEMPPersonImpersonation()
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let state = try await f.accept(runtime)
    try await f.launch(runtime)
    let game = await runtime.snapshot()
    let actual = try #require(
      game.bodies.first {
        $0.missionActorID
          == NativeOriginalRescueJourney.actorIdentity(
            mission: state.mission, alias: "neri-capsule")
      })
    let context = try #require(game.gameplayContext())
    let facts = game.originalRescueFacts(actual, context: context)
    let metadata = game.originalRescueMetadata(actual, context: context)
    let expectedMetadata = SalvageTargetMetadata(
      category: .occupiedPod, ownership: .missionProtected,
      claimant: nil, wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: 5.892836433645515), workSurfaces: [])
    #expect(facts?.isPerson == true)
    #expect(metadata == expectedMetadata)
    #expect(game.nativePodFacts(actual, context: context) == nil)
    for mode in ["dead", "foreign", "empty", "body-id", "npc", "emp"] {
      var changed = actual
      if mode == "dead" { changed.energy = 0 }
      if mode == "foreign" { changed.missionInstanceID = UUID() }
      if mode == "empty" { changed.missionActorID = UUID() }
      if mode == "body-id" { changed.id += 10000 }
      if mode == "npc" { changed.scriptNPC = nil }
      if mode == "emp" {
        changed.physical?.empCrewPod = .init(source: context.player.identity, ordinal: 0)
      }
      let changedFacts = game.originalRescueFacts(changed, context: context)
      let changedMetadata = game.originalRescueMetadata(changed, context: context)
      #expect(changedFacts == nil)
      #expect(changedMetadata == nil)
    }
    #expect(
      game.commander.savedEMPState == nil && game.commander.nativePeople?.admissions.isEmpty == true
    )
  }

  @Test func rescueMetadataLeavesOrdinaryNativeFlightShipSelectableWithoutRescueState() throws {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    try game.prepareG03FlightEquipment()
    try ScriptProcurementFixture.requirePaidG03Preparation(game)
    game.ensureMissionCalendar()
    game.launch()
    try #require(!game.docked)
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: .init(0, 0, 1000), hostile: true))
    game.ensurePhysicalActors()
    let body = try #require(game.bodies.first { $0.id == id })
    let actor = try #require(body.physical?.identity)
    let context = try #require(game.gameplayContext())
    let hasRescue = game.withReadOnlyCommander { $0.nativePeople?.originalRescue != nil }
    let facts = game.originalRescueFacts(body, context: context)
    let metadata = game.originalRescueMetadata(body, context: context)
    let candidate = game.workTargetCandidate(for: body, context: context, frontVisible: true)
    #expect(!hasRescue)
    #expect(facts == nil && metadata == nil)
    #expect(candidate?.identity == actor)
    #expect(candidate?.kind == .ship && candidate?.originalRescue == nil)
    #expect(candidate?.isLive == true && candidate?.frontVisible == true)
  }

  @Test func rescueActualCapsuleDestructionSurvivesWriterFailureAndCannotCreateAReplacementPerson()
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.accept(runtime)
    try await f.approach(runtime, alias: "neri-capsule", distance: 1000)
    let saved = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("actual-capsule-death")
    await runtime.key("u")
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<500 {
      if await runtime.snapshot().commander.scriptState.instances[source.mission]?.ownedEncounters[
        NativeOriginalRescueJourney.encounterID]?.actors["neri-capsule"]?.presence == .destroyed
      {
        break
      }
      _ = await runtime.advance(delta: 0.05)
    }
    await runtime.setControls(Controls())
    let dead = await runtime.snapshot()
    #expect(
      dead.commander.scriptState.instances[source.mission]?.ownedEncounters[
        NativeOriginalRescueJourney.encounterID]?.actors["neri-capsule"]?.presence == .destroyed)
    #expect(dead.commander.nativePeople?.admissions.isEmpty == true)
    #expect(dead.commander.scriptState.savedClueJournal == nil)
    let retained = try #require(
      dead.commander.scriptState.instances[source.mission]?.ownedEncounters[
        NativeOriginalRescueJourney.encounterID]?.actors["neri-capsule"])
    let player = try #require(dead.commander.flightSimulation.player)
    #expect(retained.body.hostile && retained.destroyedByPlayer == true)
    #expect(retained.body.physical?.npc?.firstAggressor == player)
    // Diagnose the actual destruction boundary without replacing the native damage/history.
    let validity = [
      ("equipment", dead.commander.equipmentStateValid),
      ("stations", dead.commander.nativeStationStateValid),
      ("EMP", dead.commander.empCustodyStateValid),
      ("original salvage", dead.commander.nativeSalvageOriginalSourcesValid),
      ("freight", dead.commander.freightCargoValid),
      ("scripts", dead.commander.scriptState.valid),
      ("people", dead.commander.nativePeopleStateValid),
      ("accommodation", dead.commander.accommodationValid),
      ("contracts", dead.commander.contractsValid),
      ("flight", dead.commander.flightSimulation.valid),
      ("NPC persistence", dead.commander.npcPersistence.valid),
    ]
    for (component, valid) in validity {
      #expect(valid, "Actual destruction must retain valid \(component).")
    }
    try #require(
      NativeOriginalRescueJourney.validSource(
        dead.commander.nativePeople?.originalRescue,
        custody: try #require(dead.commander.nativePeople), commander: dead.commander),
      "Actual destroyed source must retain valid original rescue joins.")
    let commanderValid = dead.commander.valid
    try #require(commanderValid, "Actual capsule destruction must retain a valid commander.")
    try f.files.restoreWrites(blocked, files: saved)
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(
      cold.commander.scriptState.instances[source.mission]?.ownedEncounters[
        NativeOriginalRescueJourney.encounterID]?.actors["neri-capsule"]?.presence == .destroyed)
    #expect(cold.commander.nativePeople?.admissions.isEmpty == true)
    #expect(cold.originalRescueQuote(.receive).allowed == false)
  }

  @Test(arguments: ["neri-capsule", "emergency-record"])
  func rescueActualCollectionWriterRefusalRetainsTheOriginalBodyAndOnlyCurrentMotionCanRetry(
    alias: String
  ) async throws {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    if alias == "emergency-record" { try await f.board(runtime) }
    try await f.approach(runtime, alias: alias)
    let before = await runtime.snapshot()
    let saved = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("collection")
    _ = await runtime.advance(delta: 0.05)
    let failed = await runtime.snapshot()
    #expect(failed.commander.nativePeople == before.commander.nativePeople)
    #expect(failed.commander.cargo == before.commander.cargo)
    #expect(failed.commander.credits == before.commander.credits)
    #expect(
      failed.commander.flightSimulation.physicalTime
        > before.commander.flightSimulation.physicalTime)
    #expect(
      failed.bodies.contains {
        $0.missionActorID
          == NativeOriginalRescueJourney.actorIdentity(
            mission: before.commander.nativePeople!.originalRescue!.mission, alias: alias)
      })
    try f.files.restoreWrites(blocked, files: saved)
    try await f.approach(runtime, alias: alias, distance: 500)
    _ = await runtime.advance(delta: 0.05)
    try await f.collect(runtime, alias: alias)
    let final = try await f.source(runtime)
    if alias == "emergency-record" {
      #expect(final.record?.physicalTime ?? 0 > failed.commander.flightSimulation.physicalTime)
    } else {
      #expect(
        final.captures.count == 1
          && final.captures[0].physicalTime > failed.commander.flightSimulation.physicalTime)
    }
    #expect(await runtime.snapshot().commander.valid)
  }
}
