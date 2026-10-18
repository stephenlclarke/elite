import Foundation
import Testing

@testable import EliteCore

/// Requires G1's separately reviewed Game caller hooks before compilation/execution.
enum CrimboContactMotion: CaseIterable, Equatable, Sendable { case straight, turning, work }
enum CrimboContactTamper: CaseIterable, Sendable {
  case missingBirth, substituteActor, fitRevision, disabledBus, staleEpoch, lostMotion, inactiveView
}

private enum ContactFixture {
  static func game() throws -> Game {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let registry = try #require(game.commander.savedCrimboState)
    let actor = try #require(
      registry.binding(of: registry.members[6], ledger: game.commander.npcPersistence))
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    let position = game.commander.flightSimulation.pose.systemPoint(body.position)
    NativeStationTestFixture.reframe(&game, to: .init(position: position - .init(0, 0, 1000)))
    game.speed = 3
    return game
  }

  static func directStep(
    _ game: inout Game, delta: Double = 0.01,
    previous: NativeCrimboContactContinuity? = nil
  )
    -> (receipt: NativeCrimboContactReceipt?, next: NativeCrimboContactContinuity?)
  {
    let seed = game.beginNativeCrimboContactStep()
    let start = game.commander.flightSimulation.physicalTime
    let player = game.commander.flightSimulation.player
    game.tick(delta: delta)
    game.observeNativeCrimboAttainedMotion(
      delta: delta, flightWasActive: true, startTime: start, startPlayer: player,
      stationEntryAttempted: false)
    return game.consumeNativeCrimboContactStep(seed: seed, previous: previous)
  }

  static func santa(_ game: Game) throws -> SpaceBody {
    let registry = try #require(game.commander.savedCrimboState)
    let actor = try #require(
      registry.binding(of: registry.members[6], ledger: game.commander.npcPersistence))
    return try #require(game.bodies.first { $0.physical?.identity == actor })
  }
}

struct NativeCrimboContactTests {
  @Test func actualOriginalACKBirthsOnceAndRepeatedStepPreservesCrew() throws {
    var game = try ContactFixture.game()
    let original = try #require(game.commander.savedCrimboState)
    let births = original.members.compactMap(\.originalBirth)
    #expect(births.count == 7 && births.allSatisfy { $0.crewCount == 1 })
    #expect(births.allSatisfy { $0.admittedAt == 0.1 })
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    game.advanceNativeCrimbo(delta: 0.1)
    let after = try #require(game.commander.savedCrimboState)
    #expect(after.members.compactMap(\.originalBirth) == births)
    let bytes = try JSONEncoder().encode(after)
    let restored = try JSONDecoder().decode(NativeCrimboRegistry.self, from: bytes)
    #expect(restored.members.compactMap(\.originalBirth) == births)
    let value = try JSONSerialization.jsonObject(with: bytes)
    var object = try #require(value as? [String: Any])
    var members = try #require(object["members"] as? [[String: Any]])
    for index in members.indices { members[index].removeValue(forKey: "originalBirth") }
    object["members"] = members
    let oldBytes = try JSONSerialization.data(withJSONObject: object)
    let unknown = try JSONDecoder().decode(NativeCrimboRegistry.self, from: oldBytes)
    #expect(unknown.members.allSatisfy { $0.originalBirth == nil })
    game.commander.savedCrimboState = unknown
    let unavailable = game.beginNativeCrimboContactStep()
    #expect(unavailable == nil)
    #expect(game.commander.savedNativePeopleCustody == nil && game.commander.savedEMPState == nil)
  }

  @Test func refusedActualAtomicAdmissionCannotBirthAnyOriginalCrew() throws {
    var game = try CrimboFixture.game()
    let allocation = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocation)
    let context = try #require(game.gameplayContext())
    let requests: [SpawnRequest] = (0..<8).map { index in
      .init(
        identity: .init(
          system: context.system, visit: context.visit, sequence: sequence,
          member: UInt16(index)),
        population: .civilian, hull: .cobra, position: .init(20000 + Double(index) * 300, 0, 0),
        orientation: Basis3(), velocity: .init(0, 0, 0), npc: nil, rock: nil, payload: nil,
        priority: .ordinary)
    }
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: requests, atomic: true)], intents: [])
    )
    try #require(
      receipts.count == 8 && receipts.allSatisfy { $0.actor != nil && $0.refusal == nil })
    let next = game.commander.flightSimulation.nextActor
    game.advanceNativeCrimbo(delta: 0.1)
    let registry = try #require(game.commander.savedCrimboState)
    #expect(registry.members.allSatisfy { $0.ownership == .pending && $0.originalBirth == nil })
    #expect(game.commander.flightSimulation.nextActor == next && game.bodies.count == 8)
  }

  @Test func actualDockAndRelaunchPreserveEveryOriginalBirthIdentity() throws {
    var game = Game(executive: false)
    game.commander.galaxy = 7
    game.commander.system = 8
    game.systems = Universe.systemsIncludingPlugh(number: 7)
    // Explicit fixture activation; G1 exclusively owns shipped readiness.
    game.nativeCrimboLifecycleAvailable = true
    game.launch()
    let first = try #require(game.commander.savedCrimboState)
    let births = first.members.compactMap(\.originalBirth)
    try #require(births.count == 7 && !game.docked)
    game.dock()
    game.launch()
    let second = try #require(game.commander.savedCrimboState)
    #expect(!game.docked && CrimboFixture.convoyBodies(game).count == 7)
    #expect(second.members.compactMap(\.originalBirth) == births)
    #expect(
      second.members.map { $0.ownership.logical } == first.members.map { $0.ownership.logical })
  }

  @Test(arguments: CrimboContactMotion.allCases)
  func actualActorContactUsesIntrinsicHardwareAndSealedReply(motion: CrimboContactMotion)
    async throws
  {
    var game = try ContactFixture.game()
    if motion == .work {
      game.workBraking = .init(velocity: .init(25, 2, 8), angularVelocity: .init(0, 0, 0))
    }
    let runtime = GameRuntime(game: game)
    if motion == .turning {
      var controls = Controls()
      controls.pitch = 0.2
      controls.yaw = -0.1
      controls.roll = 0.1
      await runtime.setControls(controls)
    }
    let first = await runtime.advance(delta: 0.01)
    let one = try #require(first.nativeCrimboContactReceipt)
    #expect(!one.continuous && one.nonce == one.replyNonce)
    #expect(one.senderDevice != one.receiverDevice && one.trackingThroughout)
    #expect(first.commander.targetingTier == nil)
    #expect(
      one.metric.forwardMeters == first.nativeCrimboAttainedMotion?.tangentialDisplacementWorldUnits
    )
    let second = await runtime.advance(delta: 0.01)
    let two = try #require(second.nativeCrimboContactReceipt)
    #expect(two.continuous && two.trackingThroughout && two.nonce != one.nonce)
    #expect(two.nonce == two.replyNonce && two.manifest == one.manifest)
    let current = two.isCurrent(in: second)
    let duplicate = two.isCurrent(in: second, after: two.metric.nextBaseline)
    let stale = one.isCurrent(in: second)
    #expect(current && !duplicate && !stale)
    if motion == .turning {
      #expect(
        first.nativeCrimboAttainedMotion?.playerStart.orientation
          != first.nativeCrimboAttainedMotion?.playerEnd.orientation)
    } else if motion == .work {
      #expect(first.lastAppliedWorkMotion != nil)
    }
    #expect(two.metric.missionInterval == nil)
  }

  @Test func actualCapturingMotionHasRadioWithoutFormationCalibration() async throws {
    var game = try ContactFixture.game()
    let santa = try ContactFixture.santa(game)
    let index = try #require(game.bodies.firstIndex { $0.id == santa.id })
    let registry = try #require(game.commander.savedCrimboState)
    let world = game.commander.flightSimulation.pose.systemPoint(santa.position)
    let shift = (world - registry.orbit.anchor.center).unit * 50
    game.bodies[index].position =
      santa.position + game.commander.flightSimulation.pose.shipVector(shift)
    game.bodies[index].physical?.velocity = .init(0, 0, 0)
    let runtime = GameRuntime(game: game)
    let frame = await runtime.advance(delta: 0.01)
    let receipt = try #require(frame.nativeCrimboContactReceipt)
    let fact = try #require(frame.nativeCrimboAttainedMotion)
    #expect(!receipt.trackingThroughout && !receipt.continuous)
    #expect(receipt.nonce == receipt.replyNonce)
    #expect(receipt.metric.forwardMeters == fact.tangentialDisplacementWorldUnits)
    #expect(receipt.metric.missionInterval == nil)
  }

  @Test func actualTickConsumesCurrentFrameOnceAndRejectsReplay() throws {
    var game = try ContactFixture.game()
    let seed = game.beginNativeCrimboContactStep()
    let time = game.commander.flightSimulation.physicalTime
    let player = game.commander.flightSimulation.player
    game.tick(delta: 0.01)
    game.observeNativeCrimboAttainedMotion(
      delta: 0.01, flightWasActive: true, startTime: time,
      startPlayer: player, stationEntryAttempted: false)
    let first = game.consumeNativeCrimboContactStep(seed: seed, previous: nil)
    let receipt = try #require(first.receipt)
    _ = try #require(first.next)
    let replay = game.consumeNativeCrimboContactStep(seed: seed, previous: first.next)
    #expect(replay.receipt == nil && replay.next == nil)
    let current = receipt.isCurrent(in: game)
    #expect(current)
  }

  @Test func actualMovingBlockerOccludesInteriorWithClearEndpointRays() throws {
    var game = try ContactFixture.game()
    game.speed = 0
    let santa = try ContactFixture.santa(game)
    let source = try #require(santa.physical?.identity)
    let allocation = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocation)
    let pose = game.commander.flightSimulation.pose
    let offset = santa.position * 0.5
    let request = SpawnRequest(
      identity: .init(system: source.system, visit: source.visit, sequence: sequence, member: 0),
      population: .civilian, hull: .cargo,
      position: pose.systemPoint(offset + .init(-60, 0, 0)), orientation: Basis3(),
      velocity: .init(1200, 0, 0), npc: nil, rock: nil, payload: nil, priority: .ordinary)
    let receipts = game.admitEncounterPlan(
      .init(
        system: source.system, visit: source.visit,
        revision: game.gameplayRevision, batches: [.init(requests: [request], atomic: true)],
        intents: []))
    let blocker = try #require(receipts.first?.actor)
    let beforeRay = try game.nearestMissionCollision(
      from: .init(0, 0, 0),
      direction: santa.position.unit, range: santa.position.length, radius: 0,
      excludingBodyIDs: [santa.id], includePlayer: false)
    try #require(beforeRay == nil)
    let result = ContactFixture.directStep(&game, delta: 0.1)
    let moved = try #require(game.bodies.first { $0.physical?.identity == blocker })
    let currentSanta = try ContactFixture.santa(game)
    let afterRay = try game.nearestMissionCollision(
      from: .init(0, 0, 0),
      direction: currentSanta.position.unit, range: currentSanta.position.length, radius: 0,
      excludingBodyIDs: [currentSanta.id], includePlayer: false)
    #expect(afterRay == nil && moved.position.x > 0)
    #expect(game.nativeCrimboAttainedMotion?.contactMotion != nil)
    #expect(result.receipt == nil && result.next == nil)
  }

  @Test func canonicalPlanetOccludesEvenWhenPresentationBodiesAreAbsent() async throws {
    var game = try ContactFixture.game()
    let registry = try #require(game.commander.savedCrimboState)
    let santa = try ContactFixture.santa(game)
    let world = game.commander.flightSimulation.pose.systemPoint(santa.position)
    let opposite = registry.orbit.anchor.center - (world - registry.orbit.anchor.center)
    NativeStationTestFixture.reframe(&game, to: .init(position: opposite))
    game.speed = 0
    try #require(game.celestials.isEmpty)
    let runtime = GameRuntime(game: game)
    let frame = await runtime.advance(delta: 0.01)
    let fact = try #require(frame.nativeCrimboAttainedMotion)
    let projected = NativeCrimboMetricProjection.project(
      fact, in: frame, expectedMetricRevision: NativeCrimboMetric.revision)
    let metric = try #require(projected)
    #expect(metric.maximumRangeMeters < NativeCrimboContactReceipt.radioRangeMeters)
    #expect(fact.contactMotion != nil && frame.nativeCrimboContactReceipt == nil)
  }

  @Test(arguments: CrimboContactTamper.allCases)
  func retainedReceiptRejectsMissingOrChangedCurrentAuthority(tamper: CrimboContactTamper)
    async throws
  {
    let runtime = GameRuntime(game: try ContactFixture.game())
    var frame = await runtime.advance(delta: 0.01)
    let receipt = try #require(frame.nativeCrimboContactReceipt)
    switch tamper {
    case .missingBirth: frame.commander.savedCrimboState?.members[6].originalBirth = nil
    case .substituteActor:
      let santa = try ContactFixture.santa(frame)
      let index = try #require(frame.bodies.firstIndex { $0.id == santa.id })
      let actor = frame.commander.flightSimulation.allocateActor()
      let replacement = try #require(actor)
      let physical = try #require(frame.bodies[index].physical)
      frame.bodies[index].physical = .init(
        identity: replacement, population: physical.population, npc: physical.npc,
        velocity: physical.velocity, spawnIdentity: physical.spawnIdentity,
        catalogueShipID: physical.catalogueShipID)
    case .fitRevision:
      try frame.commander.grantEquipment(
        "Fuel Scoops", at: .utility(.fuelScoops),
        provenance: .grant("contact fit boundary"))
    case .disabledBus:
      var reserve = try #require(
        ElectricalReserve(
          capacity: frame.commander.performance.energy,
          recharge: frame.commander.performance.recharge,
          at: frame.commander.flightSimulation.physicalTime))
      let drained = reserve.drain(reserve.capacity, at: reserve.physicalTime)
      try #require(drained)
      frame.commander.savedPlayerElectrical = reserve
    case .staleEpoch: frame.nativeStationRuntimeEpoch = UUID()
    case .lostMotion: frame.nativeCrimboAttainedMotion?.contactMotion = nil
    case .inactiveView: frame.screen = .help
    }
    let current = receipt.isCurrent(in: frame)
    #expect(!current)
  }

  @Test func actualPauseAndNoTickBreakActorContinuityWithoutMovingTime() async throws {
    let runtime = GameRuntime(game: try ContactFixture.game())
    _ = await runtime.advance(delta: 0.01)
    let continuous = await runtime.advance(delta: 0.01)
    try #require(continuous.nativeCrimboContactReceipt?.continuous == true)
    // Pause/resume with no intervening advance must also invalidate the actor window.
    await runtime.key("pause")
    await runtime.key("pause")
    let quickResume = await runtime.advance(delta: 0.01)
    try #require(quickResume.nativeCrimboContactReceipt?.continuous == false)
    await runtime.key("pause")
    let paused = await runtime.advance(delta: 0.1)
    #expect(paused.nativeCrimboContactReceipt == nil)
    #expect(
      paused.commander.flightSimulation.physicalTime
        == quickResume.commander.flightSimulation.physicalTime)
    await runtime.key("pause")
    let warmup = await runtime.advance(delta: 0.01)
    try #require(warmup.nativeCrimboContactReceipt?.continuous == false)
    let noTick = await runtime.advance(delta: 0)
    #expect(noTick.nativeCrimboContactReceipt == nil)
    let next = await runtime.advance(delta: 0.01)
    #expect(next.nativeCrimboContactReceipt?.continuous == false)
  }

  @Test func completeSceneBudgetRefusesWithoutTruncatingBlockers() throws {
    var game = try ContactFixture.game()
    let santa = try ContactFixture.santa(game)
    let actor = try #require(santa.physical?.identity)
    // Negative boundary injection only; no fake contact or admitted-actor claim is made.
    for index in 0..<NativeCrimboContactMotionFrame.maximumBlockers {
      game.bodies.append(
        .init(
          id: 10000 + index, hull: .cargo,
          position: .init(10000 + Double(index), 0, 0)))
    }
    let proof = NativeCrimboContactMotionFrame.capture(in: game, subject: actor, formation: nil)
    #expect(proof == nil)
    let result = ContactFixture.directStep(&game)
    #expect(result.receipt == nil && result.next == nil)
  }

  @Test func actualEMPReleaseTransfersSameOriginalCrewWithoutRebirth() throws {
    var game = try ContactFixture.game()
    game.speed = 0
    try game.commander.grantEquipment(
      Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
      provenance: .grant("original crew EMP boundary"))
    game.selectFlightTool(.empPirateBlaster)
    let original = try #require(game.commander.savedCrimboState)
    let birth = try #require(original.members[6].originalBirth)
    // Existing controlled release boundary uses real owned weapon/ray/drain/custody;
    // its clock/damage preparation is not a native flight/timing acceptance claim.
    let released = try releaseDamagedEMPBoundary(&game)
    try #require(released)
    let record = try #require(game.commander.savedEMPState?.records[birth.logical.firstActor])
    let joined = game.observeNativeCrimboEMPTransition(source: record.source)
    try #require(joined)
    #expect(record.source == birth.logical.firstActor && record.crewTotal == birth.crewCount)
    #expect(record.aboardOrdinals == [0])
    #expect(game.commander.savedCrimboState?.members[6].originalBirth == birth)
    #expect(
      game.commander.savedCrimboState?.members[6].ownership
        == .electrical(birth.logical, record.source))
    #expect(game.commander.savedNativePeopleCustody == nil)
    let contact = game.beginNativeCrimboContactStep()
    #expect(contact == nil)
    let persisted = game.persistEMPState()
    try #require(persisted)
    game.commander.flightSimulation.advancePhysicalTime(30)
    game.advanceEMPActors()
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    game.advanceEMPActors()
    let recovered = try #require(game.commander.savedEMPState?.records[record.source])
    let recoveryJoined = game.observeNativeCrimboEMPTransition(source: record.source)
    try #require(recoveryJoined && recovered.isRecovered)
    // Mirror the normal encounter resource/persistence owners after this controlled clock step.
    game.advanceNPCResources(delta: 0.1)
    let refusedNPCs = game.persistNPCStates()
    try #require(refusedNPCs.isEmpty)
    game.advancePlayerElectrical()
    #expect(recovered.aboardOrdinals == [0] && recovered.crewTotal == birth.crewCount)
    #expect(game.commander.savedCrimboState?.members[6].originalBirth == birth)
    let powered = game.beginNativeCrimboContactStep()
    try #require(powered != nil)
    // A stripped reserve after a genuine episode cannot become an untouched healthy baseline.
    game.commander.savedPlayerElectrical = nil
    let missingPower = game.beginNativeCrimboContactStep()
    #expect(missingPower == nil)
    #expect(game.commander.savedNativePeopleCustody == nil)
  }
}
