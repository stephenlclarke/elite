import Foundation
import Testing

@testable import EliteCore

/// Real native acceptance/issue followed by a test scene at the fixed Renas source.
/// The scene setup is not claimed as a flown journey. Admission, queries, ticks and writes are real.
private final class IsolationWorkFixture {
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
    try #require(game.beginGameplayVisit(arriving: true))
    let previous = game.commander.flightSimulation.pose
    var pose = previous
    pose.position = .init(66000, 24000, -103)
    for index in game.bodies.indices {
      game.bodies[index].position = pose.shipPoint(
        previous.systemPoint(game.bodies[index].position))
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
    game.persistScriptActors()
    try #require(NativeIsolationWorkSave.validateClaims(game.commander))
  }

  func arm() throws {
    try #require(game.cycleIsolationWorkContact())
    game.key("return")
    try #require(game.isolationWorkRuntime.review != nil && game.isolationWorkRuntime.arm == nil)
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
      profile.drive == nil && profile.missiles == 0 && profile.lasers.isEmpty
        && profile.components.isEmpty)
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
    for _ in 0..<21 { _ = await runtime.advance(delta: 0.05) }
    let verified = await runtime.snapshot()
    let module = try #require(verified.isolationWorkChild?.savedIsolationWork?.modules.first)
    #expect(module.verification != nil && abs(module.history.seconds(.observation) - 1) < 1e-8)
    #expect(module.accounts == openModule.accounts)
    let verification = try #require(module.verification)
    let opening = try #require(openModule.opening)
    #expect(verification.first.sequence > opening.meter.sequence)
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
}
