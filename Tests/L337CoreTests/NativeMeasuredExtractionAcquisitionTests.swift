import Foundation
import Testing

@testable import L337Core

struct NativeMeasuredExtractionAcquisitionTests {
  @Test(arguments: ["aperture", "speed", "scoops", "module", "actor", "payload"])
  func exactNativeOriginalStillRequiresCurrentSafeCollector(reason: String) async throws {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.extract(runtime)
    _ = await runtime.advance(delta: 0.01)
    let snapshot = await runtime.snapshot()
    let body = try #require(
      snapshot.bodies.first { body in
        guard let payload = body.physical?.payload else { return false }
        return snapshot.measuredPayloadIsAllocated(payload)
      })
    let payload = try #require(body.physical?.payload)
    try await f.framePayload(
      runtime, payload: payload,
      offset: reason == "aperture" ? .init(40, -45, 55) : .init(0, -45, 55))
    var game = await runtime.snapshot()
    let index = try #require(game.bodies.firstIndex { $0.physical?.payload == payload })
    if reason == "speed" { game.speed = 250 }
    if reason == "scoops" || reason == "module" {
      _ = try game.commander.removeFittedEquipment(
        reason == "scoops" ? "Fuel Scoops" : "Targeting: Mining Module")
    }
    if reason == "actor" {
      game.bodies[index].physical?.spawnIdentity = nil
    }
    if reason == "payload" {
      game.bodies[index].physical?.payload = .ore(NativeMeasuredExtraction.root, fragment: 12)
    }
    let before = game.commander
    let suspect = game.bodies[index]
    game.observeMeasuredIntake(suspect)
    #expect(game.nativeMeasuredExtractionPending?.intakes.isEmpty != false, "\(reason)")
    #expect(game.commander == before)
  }

  @Test(arguments: ["extraction", "intake"])
  func refusedWriterRetainsActualNativeAttemptAndRetryConsumesItOnce(stage: String) async throws {
    struct ClockEnvelope: Decodable {
      let regularPayloadTimes: [PayloadIdentity: Double]
    }
    func clocks(_ ledger: MiningLedger) throws -> [PayloadIdentity: Double] {
      let data = try JSONEncoder().encode(ledger)
      let envelope = try JSONDecoder().decode(ClockEnvelope.self, from: data)
      return envelope.regularPayloadTimes
    }
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    if stage == "intake" {
      try await f.extract(runtime)
      _ = await runtime.advance(delta: 0.01)
      let game = await runtime.snapshot()
      let payload = try #require(
        game.bodies.first { body in
          guard let payload = body.physical?.payload else { return false }
          return game.measuredPayloadIsAllocated(payload)
        }?.physical?.payload)
      try await f.framePayload(runtime, payload: payload)
    } else {
      try await f.aim(runtime)
    }
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("g12-\(stage)")
    if stage == "extraction" {
      var controls = Controls()
      controls.fire = true
      await runtime.setControls(controls)
      for _ in 0..<1000 {
        _ = await runtime.advance(delta: 0.05)
        if await runtime.snapshot().commander.miningLedger.isDepleted(NativeMeasuredExtraction.root)
        {
          break
        }
      }
    } else {
      _ = await runtime.advance(delta: 0.01)
    }
    await runtime.setControls(Controls())
    let failed = await runtime.snapshot()
    #expect(
      failed.commander.flightSimulation.physicalTime
        > before.commander.flightSimulation.physicalTime)
    #expect(failed.measuredExtractionState?.captures.isEmpty == true)
    #expect(failed.commander.cargo == before.commander.cargo)
    #expect(failed.commander.credits == before.commander.credits)
    try #require(failed.nativeMeasuredExtractionPending != nil)
    if stage == "extraction" {
      #expect(failed.measuredExtractionState?.extraction == nil)
      #expect(failed.nativeMeasuredExtractionPending?.extraction?.emitted.count == 20)
      #expect(failed.commander.miningLedger.isDepleted(NativeMeasuredExtraction.root))
    } else {
      #expect(failed.nativeMeasuredExtractionPending?.intakes.isEmpty == false)
    }
    #expect(failed.commander.miningLedger.valid)
    let failedClocks = try clocks(failed.commander.miningLedger)
    #expect(
      Set(failedClocks.keys) == Set(failed.commander.miningLedger.pendingPayloads.map(\.identity)))
    try f.files.restoreWrites(blocked, files: files)
    try await runtime.save(to: f.save)
    let retried = await runtime.snapshot()
    #expect(retried.nativeMeasuredExtractionPending == nil)
    #expect(retried.measuredExtractionState?.extraction != nil)
    #expect(retried.commander.miningLedger.valid && retried.commander.valid)
    let retriedClocks = try clocks(retried.commander.miningLedger)
    if stage == "intake" {
      #expect(retried.measuredExtractionState?.captures.isEmpty == false)
      let captures = try #require(retried.measuredExtractionState?.captures)
      try #require(captures.count == 1)
      let consumed = captures[0].payload.identity
      #expect(failedClocks[consumed] != nil)
      #expect(retriedClocks == failedClocks.filter { $0.key != consumed })
      #expect(retried.commander.miningLedger.boundActor(for: consumed) == nil)
      let remaining = failed.commander.miningLedger.pendingPayloads.filter {
        $0.identity != consumed
      }
      #expect(retried.commander.miningLedger.pendingPayloads == remaining)
      for sibling in remaining {
        #expect(
          retried.commander.miningLedger.boundActor(for: sibling.identity)
            == failed.commander.miningLedger.boundActor(for: sibling.identity))
      }
    } else {
      #expect(retriedClocks == failedClocks)
      #expect(
        retried.commander.miningLedger.pendingPayloads
          == failed.commander.miningLedger.pendingPayloads)
    }
    let receipts = retried.measuredExtractionState?.captures
    try await runtime.save(to: f.save)
    let repeated = await runtime.snapshot()
    #expect(repeated.measuredExtractionState?.captures == receipts)
    #expect(repeated.commander.miningLedger == retried.commander.miningLedger)
    let savedFiles = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let loaded = GameRuntime()
    try await loaded.load(from: f.save, persistMigrations: false)
    let cold = await loaded.snapshot()
    #expect(cold.commander.valid && cold.commander.miningLedger.valid)
    #expect(cold.measuredExtractionState?.captures == receipts)
    #expect(try clocks(cold.commander.miningLedger) == retriedClocks)
    #expect(
      cold.commander.miningLedger.pendingPayloads == retried.commander.miningLedger.pendingPayloads)
    #expect(try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent()) == savedFiles)
  }

  @Test(arguments: ["hull", "escape"])
  func actualHullOrEscapeLossReleasesOnlyHeldOriginalsAndNeverAwardsSuccess(kind: String)
    async throws
  {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.extract(runtime)
    try await f.collect(runtime)
    let state = try await f.state(runtime)
    if kind == "hull" {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.05)
    } else {
      await runtime.key("escape-pod")
    }
    let lost = await runtime.snapshot()
    #expect(lost.commander.scriptState.instances[state.permission.mission]?.outcome == .failed)
    #expect(lost.measuredExtractionState?.losses.last?.originals.count == 12)
    #expect(
      lost.commander.scriptState.instances[state.permission.mission]?.payloads.isEmpty == true)
    #expect(lost.commander.scriptState.savedClueJournal == nil)
    #expect(NativeMeasuredExtractionSave.validateClaims(lost.commander, requireRecordedLoss: true))
  }

  @Test(arguments: ["process", "receive"])
  func nativeStationWriterRefusalKeepsActualInputsOutputsAndMoneyUntilRetry(stage: String)
    async throws
  {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.extract(runtime)
    try await f.collect(runtime)
    try await f.renas(runtime)
    if stage == "receive" { try await f.confirm(runtime, .process) }
    let action: NativeMeasuredExtractionAction = stage == "process" ? .process : .receive
    let page = try await f.review(runtime, action)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("g12-station-\(stage)")
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    let refused = await runtime.snapshot()
    #expect(refused.commander.scriptState == before.commander.scriptState)
    #expect(refused.commander.credits == before.commander.credits)
    #expect(refused.commander.cargoTonnes == before.commander.cargoTonnes)
    try f.files.restoreWrites(blocked, files: files)
    try await f.confirm(runtime, action)
    if stage == "process" {
      #expect(await runtime.snapshot().measuredExtractionState?.processing?.products.count == 12)
      #expect(await runtime.snapshot().commander.credits == before.commander.credits)
    } else {
      #expect(await runtime.snapshot().commander.credits == before.commander.credits + 8900)
    }
  }
}

extension NativeMeasuredExtractionAcquisitionTests {
  @Test(arguments: ["unselected", "combat"])
  func actualMiningWithoutSelectedPermissionOrOrdinaryBreakupCannotMintExtraction(reason: String)
    async throws
  {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.aim(runtime)
    if reason == "unselected" {
      await runtime.nativeCommand {
        $0.cancelAutoTarget()
        $0.weaponsTargetID = nil
      }
      // Release preserves the moving hold's momentum. Brake through real controls
      // before placing this manual firing scene; no target or hold is reacquired.
      var braking = Controls()
      braking.throttle = -1
      await runtime.setControls(braking)
      for _ in 0..<200 {
        if await runtime.snapshot().flightWorldVelocity.length < 1e-8 { break }
        _ = await runtime.advance(delta: 0.05)
      }
      await runtime.setControls(Controls())
      try #require(await runtime.snapshot().flightWorldVelocity.length < 1e-8)
      await runtime.nativeCommand { game in
        guard let rock = game.measuredExtractionRock else { return }
        var pose = game.commander.flightSimulation.pose
        pose.position = rock.position - pose.orientation.apply(.init(0, 0, 1000))
        NativeStationTestFixture.reframe(&game, to: pose)
      }
      let manual = await runtime.snapshot()
      try #require(manual.workGuidance == nil && manual.autoPilot.targetID == nil)
      try #require(manual.weaponsTargetID == nil)
    } else {
      for _ in 0..<4 {
        if await runtime.snapshot().selectedFlightTool == .combatLaser { break }
        await runtime.key("w")
      }
    }
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<1000 {
      _ = await runtime.advance(delta: 0.05)
      if reason == "combat" {
        // The first ordinary damage fails permission; terminal native destruction
        // must separately create the actual breakup before its yield can be checked.
        if await runtime.snapshot().commander.miningLedger.breakups[NativeMeasuredExtraction.root]
          != nil
        {
          break
        }
      } else if try await f.state(runtime).losses.isEmpty == false {
        break
      }
    }
    await runtime.setControls(Controls())
    let game = await runtime.snapshot()
    let state = try #require(game.measuredExtractionState)
    if game.commander.scriptState.instances[state.permission.mission]?.outcome != .failed {
      let body = game.bodies.first { $0.physical?.rock == NativeMeasuredExtraction.root }
      let contact = try? game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
        includePlayer: false)
      FileHandle.standardError.write(
        Data(
          "G12 no-permission reason=\(reason) tool=\(game.selectedFlightTool) rootEnergy=\(body?.energy ?? -1) depleted=\(game.commander.miningLedger.isDepleted(NativeMeasuredExtraction.root)) losses=\(state.losses.count) held=\(game.flightTrigger.held) suspended=\(game.workFireSuspended) discharges=\(game.dischargeAudio.events.count) contact=\(String(describing: contact?.hit.target)) selectedRock=\(String(describing: game.informationTargetBody?.physical?.rock)) clock=\(game.commander.flightSimulation.physicalTime)\n"
            .utf8))
    }
    #expect(state.extraction == nil && state.captures.isEmpty && state.processing == nil)
    #expect(game.commander.scriptState.instances[state.permission.mission]?.outcome == .failed)
    #expect(
      game.commander.scriptState.instances[state.permission.mission]?.payloads.isEmpty == true)
    #expect(game.commander.scriptState.savedClueJournal == nil)
    if reason == "combat" {
      let breakup = try #require(
        game.commander.miningLedger.breakups[NativeMeasuredExtraction.root])
      #expect(breakup.maximumCollectibleUnits == 0)
      #expect(breakup.birthMassKg == 20000 && breakup.aggregateMassKg == 20000)
      #expect(
        !game.commander.miningLedger.pendingPayloads.contains { item in
          if case .ore(let root, _) = item.identity { return root == NativeMeasuredExtraction.root }
          return false
        })
    }
  }

  @Test func actualOreDestructionFailsJobWhereasNativeCullOnlyReleasesBinding() async throws {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.extract(runtime)
    _ = await runtime.advance(delta: 0.01)
    var game = await runtime.snapshot()
    let body = try #require(
      game.bodies.first { body in
        guard let payload = body.physical?.payload else { return false }
        return game.measuredPayloadIsAllocated(payload)
      })
    let payload = try #require(body.physical?.payload)
    let actor = try #require(body.physical?.identity)
    let source = game.commander.scriptState.savedMeasuredExtractionSource
    let before = game.commander.miningLedger.pendingPayloads
    game.commander.miningLedger.cull(actor: actor)
    #expect(game.commander.miningLedger.pendingPayloads == before)
    #expect(game.commander.scriptState.savedMeasuredExtractionSource == source)
    #expect(game.commander.miningLedger.boundActor(for: payload) == nil)
    try await f.framePayload(runtime, payload: payload, offset: .init(0, 0, 1000))
    for _ in 0..<4 {
      if await runtime.snapshot().selectedFlightTool == .combatLaser { break }
      await runtime.key("w")
    }
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<500 {
      _ = await runtime.advance(delta: 0.05)
      if try await f.state(runtime).losses.isEmpty == false { break }
    }
    await runtime.setControls(Controls())
    let destroyed = await runtime.snapshot()
    let state = try #require(destroyed.measuredExtractionState)
    #expect(state.losses.contains { $0.kind == .destroyed })
    #expect(destroyed.commander.scriptState.instances[state.permission.mission]?.outcome == .failed)
    #expect(!destroyed.commander.miningLedger.pendingPayloads.contains { $0.identity == payload })
    #expect(destroyed.commander.scriptState.savedClueJournal == nil)
  }
}
