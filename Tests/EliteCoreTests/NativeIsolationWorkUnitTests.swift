import Foundation
import Testing

@testable import EliteCore

/// Real native acceptance/issue followed by a test scene at the fixed Renas source.
/// The scene setup is not claimed as a flown journey. Admission, queries, ticks and writes are real.
final class IsolationWorkFixture {
  var game: Game
  let primitive: NativeIsolationWorkParentPrimitive
  init() async throws {
    var initial = Game(executive: false)
    initial.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledIsolationWorkParentDirectory),
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledIsolationWorkDirectory),
    ]
    let runtime = GameRuntime(game: initial)
    try await runtime.startNewCommander()
    _ = try await runtime.registerNewCommanderDestination(
      at: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    var prepared = await runtime.snapshot()
    let dock = try #require(prepared.commander.nativeStations?.currentMainDock)
    let context = try #require(prepared.nativeMainStationArrivalContext(for: dock.station))
    let proof = try prepared.stageIsolationParent(
      arrival: context,
      expectedInventoryRevision: #require(prepared.commander.equipmentInventory?.revision))
    try prepared.authorizeIsolationWork(parentID: proof.parentID)
    game = prepared
    primitive = proof
  }

  func admit() throws {
    game.launch()
    try #require(!game.docked)
    game.persistScriptActors(unloading: true)
    game.commander.system = 185
    game.commander.nativeStations?.currentMainDock = nil
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    let entered = game.beginGameplayVisit(arriving: true)
    try #require(entered)
    let previous = game.commander.flightSimulation.pose
    var pose = previous
    pose.position = .init(66000, 24000, -1000)
    for index in game.bodies.indices {
      game.bodies[index].position = pose.shipPoint(
        previous.systemPoint(game.bodies[index].position))
    }
    for index in game.celestials.indices {
      game.celestials[index].position = pose.shipPoint(
        previous.systemPoint(game.celestials[index].position))
    }
    game.commander.flightSimulation.pose = pose
    game.speed = 0
    game.screen = .front
    try game.registerOriginalNativeMainStation()
    let pack = try #require(game.nativeIsolationWorkPack)
    var child = try #require(game.isolationWorkChild)
    let result = try game.ensureScriptEncounter(
      NativeIsolationWorkPack.encounter, pack: pack, state: &child)
    try #require(result.0 == "encounter.admitted")
    game.commander.scriptState.instances[child.id] = child
    // Admission retains ordinary player clearance. The test scene then places the player in
    // the work envelope without moving either enclosure or claiming a flown approach.
    let admittedPose = game.commander.flightSimulation.pose
    var workPose = admittedPose
    workPose.position = .init(66000, 24000, -103)
    for index in game.bodies.indices {
      game.bodies[index].position = workPose.shipPoint(
        admittedPose.systemPoint(game.bodies[index].position))
    }
    for index in game.celestials.indices {
      game.celestials[index].position = workPose.shipPoint(
        admittedPose.systemPoint(game.celestials[index].position))
    }
    game.commander.flightSimulation.pose = workPose
    game.persistScriptActors()
    try #require(NativeIsolationWorkSave.validateClaims(game.commander))
  }

  func arm() throws {
    let selected = game.cycleIsolationWorkContact()
    try #require(selected)
    let idle = game.scriptPagePresentation
    game.key("return")
    try #require(game.isolationWorkRuntime.review != nil && game.isolationWorkRuntime.arm == nil)
    try #require(game.scriptPagePresentation != idle)
    game.key("return")
    try #require(game.isolationWorkRuntime.review == nil && game.isolationWorkRuntime.arm != nil)
    try #require(game.isolationWorkEndpoint() != nil)
  }

  func tick(_ delta: Double = 0.05) throws {
    let start = try #require(game.isolationWorkSample())
    game.tick(delta: delta)
    game.advanceIsolationWork(from: start, publish: nil)
  }

  func state() throws -> NativeIsolationWorkState {
    try #require(game.isolationWorkChild?.savedIsolationWork)
  }

  static func returnToAvenor(_ runtime: GameRuntime) async throws {
    await runtime.key("escape")
    await runtime.key("0")
    try await runtime.scriptCommand { candidate in
      var pose = candidate.commander.flightSimulation.pose
      pose.position = pose.position + pose.orientation.x * 20_000
      NativeStationTestFixture.reframe(&candidate, to: pose)
    }
    let departure = await runtime.snapshot()
    await runtime.selectSystem(x: Double(departure.systems[7].x), y: Double(departure.systems[7].y))
    await runtime.key("h")
    try #require(await runtime.snapshot().jumpCountdown != nil)
    for _ in 0..<200 {
      if await runtime.snapshot().jumpCountdown == nil { break }
      _ = await runtime.advance(delta: 0.1)
    }
    try #require(await runtime.snapshot().commander.system == 7)
    // Framing grants no dock receipt; ordinary swept native entry must mint it.
    try await runtime.scriptCommand { candidate in
      let station = try #require(candidate.bodies.first { $0.id == 0 && $0.hull == .station })
      let old = candidate.commander.flightSimulation.pose
      var pose = ShipPose()
      pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
      pose.orientation.y = old.orientation.apply(station.entranceUp)
      pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
      pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
      NativeStationTestFixture.reframe(&candidate, to: pose)
      candidate.speed = 3
      for _ in 0..<100 where !candidate.docked { candidate.tick(delta: 0.1) }
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
  }
}

struct NativeIsolationWorkUnitTests {
  @Test func exactPackOwnsTwoPassiveSixMetreEnclosuresAndStableFiniteAccounts() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledIsolationWorkDirectory)
    #expect(NativeIsolationWorkPack.matches(pack))
    let source = NativeIsolationWorkSource(owner: UUID())
    #expect(source.id == NativeIsolationWorkSource(owner: source.owner).id)
    #expect(source.id != NativeIsolationWorkSource(owner: UUID()).id)
    #expect(
      Set(
        NativeIsolationWorkRole.allCases.flatMap {
          [source.module($0), source.supply($0), source.load($0)]
        }
      ).count == 6)
    let mesh = NativeIsolationWorkSource.geometry.rawMesh
    #expect(mesh.vertices.count == 8 && mesh.faces.count == 6)
    for axis in [mesh.vertices.map(\.x), mesh.vertices.map(\.y), mesh.vertices.map(\.z)] {
      #expect(axis.min() == -3 && axis.max() == 3)
    }
    let profile = NativeIsolationWorkSource.profile
    #expect(profile.valid && profile.energy == 100 && profile.recharge == 0 && profile.speed == 0)
    #expect(
      profile.drive == nil && profile.missiles == 0 && profile.lasers == []
        && profile.components == [])
    #expect(
      NativeIsolationWorkRole.reserve.offset - NativeIsolationWorkRole.primary.offset
        == .init(300, 0, 0))
  }

  @Test func genuineParentIssueReservesOnePairAndIdempotenceCannotRefillOrIssueAgain() async throws
  {
    let fixture = try await IsolationWorkFixture()
    let state = try fixture.state()
    #expect(state.shapeValid && state.modules.count == 2 && state.producerSequence == 0)
    #expect(
      state.modules.allSatisfy {
        $0.accounts.remainingSupply == 10000 && $0.accounts.deliveredLoad == 0
          && $0.contact == .connected
      })
    let before = fixture.game.commander
    try fixture.game.authorizeIsolationWork(parentID: fixture.primitive.parentID)
    #expect(fixture.game.commander == before)
    #expect(
      fixture.game.currentIsolationWorkParentAuthority?.issueOperation
        == fixture.primitive.issueOperation)
    #expect(NativeIsolationWorkSave.validateClaims(fixture.game.commander))
    let sourcePack = try #require(fixture.game.nativeIsolationWorkPack)
    #expect(throws: (any Error).self) { _ = try fixture.game.acceptScriptMission(sourcePack) }
    #expect(fixture.game.commander == before)
    fixture.game.commander.scriptState.instances.removeValue(forKey: fixture.primitive.parentID)
    #expect(fixture.game.currentIsolationWorkParentAuthority == nil)
    #expect(!NativeIsolationWorkSave.validateClaims(fixture.game.commander))
  }

  @Test func connectedEnergyConservesFiniteSupplyAndOpenContactStopsTheActualTransfer() throws {
    var accounts = NativeIsolationEnergyAccounts()
    for _ in 0..<1200 { _ = try accounts.transfer(seconds: 1.0 / 60, contact: .connected) }
    #expect(abs(accounts.deliveredLoad - 20) < 1e-8 && accounts.valid)
    #expect(abs(accounts.remainingSupply + accounts.deliveredLoad - 10000) < 1e-8)
    let before = accounts
    #expect(
      try accounts.transfer(seconds: 0.1, contact: .latchedOpen(operation: UUID(), revision: 1))
        == 0)
    #expect(accounts == before)
    for invalid in [0, -0.1, 0.10001, Double.infinity, Double.nan] {
      #expect(throws: (any Error).self) {
        _ = try accounts.transfer(seconds: invalid, contact: .connected)
      }
      #expect(accounts == before)
    }
    // Historical boundary fixture only: conservation makes an exhausted supply/full load
    // the same unavailable circuit. Zero connected flow never implies an open contact.
    var exhausted = try JSONDecoder().decode(
      NativeIsolationEnergyAccounts.self,
      from: Data("{\"remainingSupply\":0,\"deliveredLoad\":10000}".utf8))
    #expect(exhausted.valid && exhausted.headroom == 0)
    #expect(try exhausted.transfer(seconds: 0.1, contact: .connected) == 0)
    #expect(exhausted.remainingSupply == 0 && exhausted.deliveredLoad == 10000)
  }

  @Test func sixtyHertzHistoryCoalescesIntervalsAndInterruptionsCreditNoGap() async throws {
    let fixture = try await IsolationWorkFixture()
    let state = try fixture.state()
    let permission = state.permission
    // Typed historical arithmetic fixture, never a live endpoint or an isolation receipt.
    let actor = ActorIdentity(system: NativeIsolationWorkSource.location, visit: 2, entity: 20)
    let authority = NativeIsolationMeasurementAuthority(
      parent: permission.parent, authorization: permission.authorization, owner: permission.owner,
      source: state.source, role: .primary, module: state.modules[0].module,
      issueOperation: permission.issueOperation, programmer: permission.programmer,
      carrier: permission.carrier, inventoryRevision: permission.inventoryRevision,
      actor: actor, player: .init(system: actor.system, visit: actor.visit, entity: 0))
    var history = NativeIsolationWorkHistory()
    for frame in 0..<1200 {
      let gap = frame >= 600 ? 10.0 : 0.0
      try history.record(
        authority: authority, phase: .work,
        start: Double(frame) / 60 + gap, end: Double(frame + 1) / 60 + gap,
        range: 100, speed: 0, aim: 0)
    }
    #expect(history.valid && history.segments.count == 1)
    #expect(abs(history.seconds(.work) - 20) < 1e-8 && history.seconds(.observation) == 0)
    #expect(history.segments[0].intervals == 1200 && history.segments[0].last == 30)
  }

  @Test func closedProviderCodecRejectsErasureUnknownFieldsAndEarlierEnvelope() async throws {
    let fixture = try await IsolationWorkFixture()
    let bytes = try JSONEncoder().encode(fixture.game.commander.scriptState)
    try NativeIsolationWorkSave.validateFields(bytes, part: .missions, schema: 133)
    #expect(throws: (any Error).self) {
      try NativeIsolationWorkSave.validateFields(bytes, part: .missions, schema: 115)
    }
    var child = try #require(fixture.game.isolationWorkChild)
    child.savedIsolationWork = nil
    fixture.game.commander.scriptState.instances[child.id] = child
    #expect(!NativeIsolationWorkSave.validateClaims(fixture.game.commander))
    let erased = try JSONEncoder().encode(fixture.game.commander.scriptState)
    #expect(throws: (any Error).self) {
      try NativeIsolationWorkSave.validateFields(erased, part: .missions, schema: 133)
    }
    let original = try JSONDecoder().decode(ScriptEngineState.self, from: bytes)
    let originalState = try #require(original.instances[child.id]?.savedIsolationWork)
    let state = try JSONEncoder().encode(originalState)
    var leaf = try #require(JSONSerialization.jsonObject(with: state) as? [String: Any])
    leaf["isolated"] = true
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(child)) as? [String: Any])
    raw["savedIsolationWork"] = leaf
    let injected = try JSONSerialization.data(withJSONObject: [
      "instances": [child.id.uuidString: raw]
    ])
    #expect(throws: (any Error).self) {
      try NativeIsolationWorkSave.validateFields(injected, part: .missions, schema: 133)
    }
  }

  @Test func actualOriginalReturnKeepsHistoricalSourceButCannotMintFreshWorkAuthority() async throws
  {
    let fixture = try await IsolationWorkFixture()
    let saved = try fixture.state()
    let dock = try #require(fixture.game.commander.nativeStations?.currentMainDock)
    let arrival = try #require(fixture.game.nativeMainStationArrivalContext(for: dock.station))
    let receipt = try fixture.game.stageIsolationProgrammerReturn(
      parentID: fixture.primitive.parentID, arrival: arrival)
    #expect(receipt.operation == .returned)
    #expect(fixture.game.currentIsolationWorkParentAuthority == nil)
    #expect(try fixture.state() == saved)
    #expect(NativeIsolationWorkSave.validateClaims(fixture.game.commander))
    #expect(
      fixture.game.isolationWorkEndpoint() == nil && fixture.game.isolationWorkSample() == nil)
  }

  @Test func nativeWorkNeedsActualPairAndFreshWriteBeforeLaterZeroFlowObservation() async throws {
    let fixture = try await IsolationWorkFixture()
    #expect(fixture.game.isolationWorkEndpoint() == nil)
    try fixture.admit()
    try fixture.arm()
    for _ in 0..<400 { try fixture.tick() }
    let attained = try fixture.state()
    #expect(abs(attained.modules[0].history.seconds(.work) - 20) < 1e-8)
    #expect(attained.modules[0].contact == .connected && attained.modules[0].opening == nil)
    #expect(attained.modules[0].history.seconds(.observation) == 0)
    #expect(abs(attained.modules[1].accounts.deliveredLoad - 20) < 1e-7)
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let runtime = GameRuntime(game: fixture.game)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    // Genuine exclusive pointer refusal; all attained flow remains outside its candidate.
    try Data("occupied".utf8).write(to: files.save)
    let refused = await runtime.advance(delta: 0.05)
    let refusedModule = try #require(refused.isolationWorkChild?.savedIsolationWork?.modules.first)
    #expect(refusedModule.contact == .connected && refusedModule.opening == nil)
    #expect(refusedModule.accounts.deliveredLoad > attained.modules[0].accounts.deliveredLoad)
    #expect(try String(contentsOf: files.save, encoding: .utf8) == "occupied")
    try FileManager.default.removeItem(at: files.save)
    let opened = await runtime.advance(delta: 0.05)
    let openModule = try #require(opened.isolationWorkChild?.savedIsolationWork?.modules.first)
    #expect(openModule.opening != nil && openModule.verification == nil)
    #expect(openModule.history.seconds(.observation) == 0)
    for _ in 0..<21 {
      let current = await runtime.advance(delta: 0.05)
      if current.isolationWorkChild?.savedIsolationWork?.modules.first?.verification != nil {
        break
      }
    }
    let verified = await runtime.snapshot()
    let module = try #require(verified.isolationWorkChild?.savedIsolationWork?.modules.first)
    #expect(module.verification != nil && abs(module.history.seconds(.observation) - 1) < 1e-8)
    #expect(module.accounts == openModule.accounts)
    let verification = try #require(module.verification)
    let opening = try #require(openModule.opening)
    #expect(verification.first.sequence > opening.meter.sequence)
    try await runtime.scriptCommand { candidate in
      let previous = candidate.commander.flightSimulation.pose
      var pose = previous
      pose.position = .init(66300, 24000, -103)
      for index in candidate.bodies.indices {
        candidate.bodies[index].position = pose.shipPoint(
          previous.systemPoint(candidate.bodies[index].position))
      }
      for index in candidate.celestials.indices {
        candidate.celestials[index].position = pose.shipPoint(
          previous.systemPoint(candidate.celestials[index].position))
      }
      candidate.commander.flightSimulation.pose = pose
    }
    await runtime.key("tab")
    await runtime.key("return")
    await runtime.key("return")
    for _ in 0..<422 {
      let current = await runtime.advance(delta: 0.05)
      if current.isolationWorkChild?.savedIsolationWork?.modules.allSatisfy({
        $0.verification != nil
      }) == true {
        break
      }
    }
    let both = await runtime.snapshot()
    let pair = try #require(both.isolationWorkChild?.savedIsolationWork)
    let receipts = pair.modules.compactMap(\.verification)
    #expect(receipts.count == 2 && Set(receipts.map(\.operation)).count == 2)
    #expect(pair.modules[0].accounts == module.accounts)
    let saved = try Data(contentsOf: files.save)
    let (cold, _) = try ScriptSaveStore.read(saved, from: files.save)
    let job = NativeIsolationWorkPack.instance(source: verification.authority.source)
    #expect(
      cold.scriptState.instances[job]?.savedIsolationWork
        == pair)
    try await runtime.load(from: files.save, persistMigrations: false)
    let restored = await runtime.snapshot()
    #expect(restored.isolationWorkRuntime.arm == nil && restored.isolationWorkRuntime.review == nil)
    #expect(
      restored.isolationWorkChild?.savedIsolationWork?.modules.first?.accounts == module.accounts)
    #expect(
      restored.isolationWorkChild?.savedIsolationWork?.modules.compactMap(\.verification)
        == receipts)
    try await IsolationWorkFixture.returnToAvenor(runtime)
    let beforeReception = await runtime.snapshot()
    let pointer = try Data(contentsOf: files.save)
    let backup = files.save.appendingPathExtension("receiving-backup")
    try FileManager.default.moveItem(at: files.save, to: backup)
    try FileManager.default.createDirectory(at: files.save, withIntermediateDirectories: false)
    await #expect(throws: (any Error).self) {
      try await runtime.scriptCommand { candidate in
        let dock = try #require(candidate.commander.nativeStations?.currentMainDock)
        let arrival = try #require(candidate.nativeMainStationArrivalContext(for: dock.station))
        try candidate.receiveIsolationWork(at: arrival)
      }
    }
    #expect(await runtime.snapshot().commander == beforeReception.commander)
    try FileManager.default.removeItem(at: files.save)
    try FileManager.default.moveItem(at: backup, to: files.save)
    #expect(try Data(contentsOf: files.save) == pointer)
    try await runtime.scriptCommand { candidate in
      try candidate.confirmIsolationWorkParent(candidate.isolationWorkParentReview(.receive))
    }
    let received = await runtime.snapshot()
    let parent = try #require(received.isolationWorkParentMission)
    #expect(parent.outcome == .complete && parent.contract?.settlementAmount == 9700)
    #expect(received.commander.credits == beforeReception.commander.credits + 9700)
    #expect(received.commander.cargoTonnes == beforeReception.commander.cargoTonnes - 1)
    #expect(
      received.commander.scriptState.savedClueJournal?.awards[NativeIsolationWorkParent.stateID]?
        .clueID == "isolation-work-family-trace")
    #expect(OriginalServiceReservationPolicy.activeCount(received.commander.scriptState) == 0)
    try await runtime.scriptCommand { candidate in
      let dock = try #require(candidate.commander.nativeStations?.currentMainDock)
      let arrival = try #require(candidate.nativeMainStationArrivalContext(for: dock.station))
      try candidate.receiveIsolationWork(at: arrival)
    }
    #expect(await runtime.snapshot().commander == received.commander)
    let completedBytes = try Data(contentsOf: files.save)
    let (completedCold, _) = try ScriptSaveStore.read(completedBytes, from: files.save)
    #expect(
      completedCold.scriptState.instances[parent.id]?.completionReceipt == parent.completionReceipt)
    #expect(NativeIsolationContractSave.validateClaims(completedCold))
  }

  @Test func cullingPauseAndWrongViewCannotCreditTimeOrLeaveAnArmedEndpoint() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.arm()
    let state = try fixture.state()
    let start = try #require(fixture.game.isolationWorkSample())
    fixture.game.bodies.removeAll {
      $0.missionActorID == NativeIsolationWorkPack.actor(job: state.job, role: .reserve)
    }
    fixture.game.tick(delta: 0.1)
    fixture.game.advanceIsolationWork(from: start, publish: nil)
    #expect(try fixture.state() == state)
    fixture.game.paused = true
    #expect(
      fixture.game.isolationWorkEndpoint() == nil && fixture.game.isolationWorkSample() == nil)
    fixture.game.paused = false
    fixture.game.screen = .rear
    fixture.game.advanceIsolationWork(from: nil, publish: nil)
    #expect(fixture.game.isolationWorkRuntime.arm == nil)
    #expect(try fixture.state() == state)
  }

  @Test func combatIntentDisarmsEvenWhenNoInventoryRevisionChanges() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.arm()
    let before = try fixture.state()
    for token in ["t", "u", "m", "e", "energy-bomb"] {
      fixture.game.key(token)
      #expect(
        fixture.game.isolationWorkRuntime.arm == nil
          && fixture.game.isolationWorkRuntime.review == nil)
      #expect(try fixture.state() == before)
      fixture.game.key("return")
      fixture.game.key("return")
      try #require(fixture.game.isolationWorkRuntime.arm != nil)
    }
    fixture.game.missileArmed = false
    let automaticArm = fixture.game.isolationWorkRuntime.arm
    let retaliated = fixture.game.fireMissile(retaliating: true)
    #expect(!retaliated)
    #expect(fixture.game.isolationWorkRuntime.arm == automaticArm)
    fixture.game.ecm(automatic: true)
    #expect(fixture.game.isolationWorkRuntime.arm == automaticArm)
    let refusedManual = fixture.game.fireMissile()
    #expect(!refusedManual)
    #expect(fixture.game.isolationWorkRuntime.arm == nil)
    #expect(try fixture.state() == before)
    fixture.game.key("return")
    fixture.game.key("return")
    try #require(fixture.game.isolationWorkRuntime.arm != nil)
    try fixture.tick()
    fixture.game.commander.unlimitedMissiles = true
    fixture.game.missileArmed = true
    fixture.game.weaponsTargetID = try #require(fixture.game.isolationWorkContactBody?.id)
    let attained = try fixture.state()
    let inventory = fixture.game.commander.equipmentInventory
    var launch = fixture.game
    let launched = launch.fireMissile()
    try #require(launched)
    #expect(launch.bodies.count > fixture.game.bodies.count)
    #expect(launch.commander.equipmentInventory == inventory)
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: fixture.game)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    let baseline = await runtime.snapshot()
    try Data("occupied".utf8).write(to: files.save)
    await runtime.key("m")
    let refused = await runtime.snapshot()
    #expect(refused.commander == baseline.commander && refused.bodies == baseline.bodies)
    #expect(refused.isolationWorkRuntime.arm == nil && refused.isolationWorkRuntime.review == nil)
    #expect(refused.isolationWorkChild?.savedIsolationWork == attained)
    #expect(try String(contentsOf: files.save, encoding: .utf8) == "occupied")
  }
}
