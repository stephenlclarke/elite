import Foundation
import Testing

@testable import EliteCore

/// Receipt policy only; no station action, flight journey or terminal award is simulated.
struct NativeSafeGunneryUnitTests {
  private struct Fixture {
    var flight: FlightSimulationState
    var provider: NativePracticeState
    var bodies: [SpaceBody] {
      provider.beacons.enumerated().map { ordinal, beacon in
        provider.body(for: beacon, id: 40 + ordinal, pose: flight.pose)
      }
    }
    mutating func emission() throws -> AttackOrigin {
      let allocated = flight.allocateEmission()
      let sequence = try #require(allocated)
      return .init(
        emissionID: sequence, owner: try #require(flight.player),
        emittedAt: flight.physicalTime, ownerLegalAtEmission: .init())
    }
    func hit(_ ordinal: Int, origin: AttackOrigin) throws -> NativePracticeHitReceipt {
      try NativePracticeHitPolicy.laser(
        state: provider, pose: flight.pose, bodies: bodies,
        meshes: Dictionary(
          uniqueKeysWithValues: bodies.map { ($0.id, NativePracticeSource.mesh()) }),
        celestials: [], direction: NativePracticeSource.offsets[ordinal].unit, range: 6000,
        origin: origin, time: flight.physicalTime, nextEmission: flight.nextEmission)
    }
    mutating func observedHit(_ ordinal: Int) throws -> NativePracticeHitReceipt {
      let origin = try emission()
      let receipt = try hit(ordinal, origin: origin)
      try provider.record(receipt)
      return receipt
    }
  }

  private func fixture(
    _ suffix: String = "original", lesson: NativePracticeLesson = .gunnery
  ) throws -> Fixture {
    let mission = ScriptIdentity.uuid("safe-gunnery-unit-mission:" + suffix)
    var flight = FlightSimulationState()
    flight.enter(.init(galaxy: 0, system: 7), arriving: false)
    flight.enter(.init(galaxy: 0, system: 7), arriving: false)
    flight.pose.position = .init(20000, 0, 0)
    flight.physicalTime = 10
    let owner = ScriptIdentity.uuid("safe-gunnery-unit-owner")
    let dock = NativeMainStationDockReceipt(
      station: .init(
        world: owner, system: .init(galaxy: 0, system: 7),
        resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7")),
      actor: .init(system: .init(galaxy: 0, system: 7), visit: 1, entity: 1),
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    func context(_ revision: UInt64) -> ScriptEventContext {
      var result = ScriptEventContext(
        galaxy: 0, system: 7, docked: true, mainStation: true, revision: revision,
        frameSeconds: 0, localSeconds: 0, flightSeconds: 0, calendarSeconds: 0,
        transitSeconds: 0, playerPosition: nil)
      result.nativeMainDock = dock
      return result
    }
    let permission = NativePracticePermission(
      mission: mission, owner: owner,
      carrier: ScriptIdentity.uuid("safe-gunnery-unit-carrier"), lesson: lesson,
      digest: NativeSafeGunnery.digest,
      consent: .init(
        instance: mission, group: NativePracticeSource.consentGroup,
        choice: NativePracticeSource.consentChoice, label: "Begin practice",
        dialogue: "practice-review", sequence: 1, revision: 1,
        cause: context(0), committed: context(1)),
      player: try #require(flight.player), frame: flight.pose, begunAt: 10)
    let provider = try NativePracticeState.prepare(permission: permission, flight: &flight)
    return .init(flight: flight, provider: provider)
  }

  private func lesson(_ f: Fixture) throws -> NativeSafeGunneryState {
    let scope = f.provider.permission
    var state = NativeSafeGunneryState(
      permission: .init(
        mission: scope.mission, owner: scope.owner, carrier: scope.carrier,
        dock: try #require(scope.consent.committed.nativeMainDock), consent: scope.consent,
        acceptedAt: 0))
    try state.begin(f.provider)
    return state
  }

  private func threeHits(_ f: inout Fixture, state: inout NativeSafeGunneryState) throws {
    for ordinal in 0..<3 {
      let receipt = try f.observedHit(ordinal)
      try state.synchronize(f.provider)
      state.discharge(time: f.flight.physicalTime, emission: receipt.origin.emissionID)
    }
  }

  private func replacing<T: Codable>(_ value: T, key: String, with replacement: Any) throws -> T {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    object[key] = replacement
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func bundledLessonUsesTheExactCompiledProductionPinAndZeroCashReceptionEvent() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledSafeGunneryDirectory)
    #expect(pack.manifest.stateID == NativeSafeGunnery.stateID)
    #expect(pack.manifest.version == NativeSafeGunnery.version)
    #expect(pack.digest == NativeSafeGunnery.digest)
    #expect(pack.manifest.mission.milestones.count == 5)
    let f = try fixture()
    let consent = f.provider.permission.consent
    func receipt(event: String, digest: String) -> ScriptCompletionReceipt {
      .init(
        instance: f.provider.permission.mission, definition: pack.manifest.stateID,
        version: pack.manifest.version, digest: digest, outcome: .complete, sequence: 2,
        causeKind: event, cause: consent.committed, committed: consent.committed, revision: 2,
        milestones: [0, 1, 2, 3, 4], destroyedEncounters: [], deliveredParties: [],
        returnedEquipment: [], settlementAmount: 0,
        choices: [NativePracticeSource.consentGroup: consent])
    }
    let trust = ScriptClueTrustCatalog.production
    let approved = receipt(event: "mission.receipted", digest: pack.digest)
    #expect(trust.pin(for: approved)?.sourceID == NativeSafeGunnery.stateID)
    #expect(trust.pin(for: receipt(event: "mission.accepted", digest: pack.digest)) == nil)
    #expect(
      trust.pin(for: receipt(event: "mission.receipted", digest: String(repeating: "f", count: 64)))
        == nil)
  }

  @Test func changedQuietCounterOrTerminalFieldsCannotSupplyMissingNativeTimeOrFailure() throws {
    var f = try fixture()
    var state = try lesson(f)
    try threeHits(&f, state: &state)
    let premature = try replacing(state, key: "quietSeconds", with: 3.0)
    #expect(!premature.valid && !premature.ready)
    try state.observeFlight(time: 13, delta: 3)
    #expect(state.ready)
    let changedAnchor = try replacing(state, key: "quietAnchorAt", with: 13.0)
    #expect(!changedAnchor.valid && !changedAnchor.ready)
    state.terminalOutcome = .failed
    state.terminalOperation = ScriptIdentity.uuid(
      "safe-gunnery-terminal-v1:\(state.permission.mission):failed")
    #expect(!state.valid && !state.ready && state.ordinaryHit == nil)
  }

  @Test func thirdHitRequiresThreeFurtherQuietNativeSecondsAndCannotCreditItsOwnFrame() throws {
    var f = try fixture()
    var state = try lesson(f)
    try threeHits(&f, state: &state)
    #expect(state.progress?.threeDistinctHits == true && !state.ready && state.quietSeconds == 0)
    try state.observeFlight(time: 10, delta: 0.05)
    #expect(state.quietSeconds == 0)
    try state.observeFlight(time: 12.99, delta: 2.99)
    #expect(!state.ready && abs(state.quietSeconds - 2.99) < 1e-9)
    try state.observeFlight(time: 13, delta: 0.01)
    #expect(state.ready && state.quietSeconds == 3)
  }

  @Test func thirdNativeImpactRestartsAtItsEndpointWithoutCreditingTheEarlierFrame() throws {
    var f = try fixture()
    var state = try lesson(f)
    for ordinal in 0..<2 {
      _ = try f.observedHit(ordinal)
      try state.synchronize(f.provider)
    }
    try state.observeFlight(time: 11, delta: 1)
    f.flight.physicalTime = 12
    _ = try f.observedHit(2)
    try state.synchronize(f.provider)
    try state.observeFlight(time: 12, delta: 1)
    #expect(state.quietSeconds == 0 && !state.ready)
    try state.observeFlight(time: 14.99, delta: 2.99)
    #expect(!state.ready)
    try state.observeFlight(time: 15, delta: 0.01)
    #expect(state.ready)
  }

  @Test func actualDischargesRestartQuietTimeWhilePauseAndRepeatedEndpointsAddNothing() throws {
    var f = try fixture()
    var state = try lesson(f)
    try threeHits(&f, state: &state)
    try state.observeFlight(time: 13, delta: 3)
    #expect(state.ready)
    state.discharge(time: 13, emission: 20)
    #expect(!state.ready && state.quietSeconds == 0 && state.progress?.hits.count == 3)
    let stopped = state
    #expect(throws: (any Error).self) { try state.observeFlight(time: 13, delta: 0) }
    #expect(state == stopped)
    try state.observeFlight(time: 13, delta: 0.05)
    #expect(state == stopped)
    try state.observeFlight(time: 16, delta: 3)
    #expect(state.ready)
    state.discharge(time: 16)
    #expect(!state.ready && state.quietSeconds == 0 && state.ordinaryHit == nil)
  }

  @Test func unresolvedAttemptMissilesBlockCeasefireUntilTheirExactNativeOriginEnds() throws {
    var f = try fixture()
    var state = try lesson(f)
    try threeHits(&f, state: &state)
    let allocated = f.flight.allocateActor()
    let projectile = try #require(allocated)
    let emitted = try f.emission()
    let origin = AttackOrigin(
      emissionID: emitted.emissionID, owner: emitted.owner, ordnance: projectile,
      emittedAt: 10, ownerLegalAtEmission: .init())
    try state.launch(origin, time: 10)
    try state.observeFlight(time: 13, delta: 3)
    #expect(!state.ready && state.quietSeconds == 0 && state.pendingProjectiles.count == 1)
    let foreign = AttackOrigin(
      emissionID: origin.emissionID, owner: origin.owner,
      ordnance: .init(
        system: projectile.system, visit: projectile.visit + 1, entity: projectile.entity),
      emittedAt: 10, ownerLegalAtEmission: .init())
    state.endedProjectile(foreign, time: 13)
    #expect(state.pendingProjectiles.count == 1)
    state.endedProjectile(origin, time: 13)
    #expect(state.pendingProjectiles.isEmpty && !state.ready)
    try state.observeFlight(time: 16, delta: 3)
    #expect(state.ready && state.progress?.hits.count == 3)
  }

  @Test func ordinaryActorHitIrreversiblyFailsWithoutErasingHitsOrChangingNormalLaw() throws {
    var f = try fixture()
    var state = try lesson(f)
    try threeHits(&f, state: &state)
    try state.observeFlight(time: 13, delta: 3)
    let player = crimeTestActor(0, role: nil, visit: f.flight.visit)
    let ordinary = crimeTestActor(90, visit: f.flight.visit)
    let incident = crimeTestIncident(1, time: 13, owner: player, victim: ordinary)
    var law = CrimeLedger()
    let result = law.record(
      incident,
      context: crimeTestContext(13, player: player, actors: [ordinary], visit: f.flight.visit))
    #expect(result.accepted && result.unlawful && result.legalPenalty > 0)
    let normal = law
    state.recordOrdinaryHit(incident)
    #expect(state.valid && state.ordinaryHit == incident && !state.ready)
    #expect(state.progress?.hits.count == 3 && state.quietSeconds == 0 && law == normal)
    let failed = state
    #expect(throws: (any Error).self) { try state.observeFlight(time: 16, delta: 3) }
    state.discharge(time: 16, emission: 100)
    #expect(state == failed)
    #expect(throws: (any Error).self) { try state.synchronize(f.provider) }
    #expect(state.ordinaryHit == incident)
  }

  @Test func ordinaryHarmOnALaterNativeVisitStillFailsTheSameAcceptedAttempt() throws {
    let f = try fixture()
    var state = try lesson(f)
    let player = crimeTestActor(0, role: nil, visit: f.flight.visit + 1)
    let ordinary = crimeTestActor(91, visit: f.flight.visit + 1)
    let incident = crimeTestIncident(2, time: 20, owner: player, victim: ordinary)
    state.recordOrdinaryHit(incident)
    #expect(state.valid && state.ordinaryHit == incident && !state.ready)
  }

  @Test func coldQuietProgressSurvivesWithoutWallClockCreditAndDiscontinuousFramesRestartIt() throws
  {
    var f = try fixture()
    var state = try lesson(f)
    try threeHits(&f, state: &state)
    try state.observeFlight(time: 11, delta: 1)
    var restored = try JSONDecoder().decode(
      NativeSafeGunneryState.self, from: JSONEncoder().encode(state))
    #expect(restored == state && restored.valid && restored.quietSeconds == 1)
    try restored.observeFlight(time: 11, delta: 0.05)
    #expect(restored == state)
    try restored.observeFlight(time: 12, delta: 1)
    #expect(restored.quietSeconds == 2 && !restored.ready)
    try restored.observeFlight(time: 1000, delta: 1)
    #expect(restored.quietSeconds == 0 && !restored.ready && restored.progress?.hits.count == 3)
  }

  @Test func receptionNeedsQuietProofOriginalOwnerCarrierAndLaterActualAvenorDock() throws {
    var f = try fixture()
    var state = try lesson(f)
    try threeHits(&f, state: &state)
    let original = state.permission.dock
    let arrival = NativeMainStationDockReceipt(
      station: original.station,
      actor: .init(system: original.actor.system, visit: f.flight.visit, entity: 1),
      commanderOwner: original.commanderOwner, sequence: original.sequence + 1, calendarSeconds: 1)
    #expect(
      !NativeSafeGunneryReception.allowed(
        state: state, provider: f.provider, dock: arrival,
        owner: state.permission.owner, carrier: state.permission.carrier))
    try state.observeFlight(time: 13, delta: 3)
    #expect(
      NativeSafeGunneryReception.allowed(
        state: state, provider: f.provider, dock: arrival,
        owner: state.permission.owner, carrier: state.permission.carrier))
    #expect(
      !NativeSafeGunneryReception.allowed(
        state: state, provider: f.provider, dock: original,
        owner: state.permission.owner, carrier: state.permission.carrier))
    #expect(
      !NativeSafeGunneryReception.allowed(
        state: state, provider: f.provider, dock: arrival,
        owner: UUID(), carrier: state.permission.carrier))
    #expect(
      !NativeSafeGunneryReception.allowed(
        state: state, provider: f.provider, dock: arrival,
        owner: state.permission.owner, carrier: UUID()))
  }

  @Test(arguments: [false, true])
  func closedLessonEnvelopeRejectsEarlyEmbeddedUnknownAndMissingNativeClaims(alien: Bool) throws {
    let f = try fixture()
    let state = try lesson(f)
    var instance = ScriptInstance(
      id: state.permission.mission, definition: NativeSafeGunnery.stateID,
      version: NativeSafeGunnery.version, digest: NativeSafeGunnery.digest)
    instance.savedSafeGunnery = state
    instance.savedNativePractice = f.provider
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(instance))
    func bytes(_ raw: Any) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": ["lesson": raw]])
    }
    let schema = alien ? 128 : 127
    try NativeSafeGunnerySave.validateArchiveFields(
      bytes(object), part: .missions, schema: schema, alien: alien)
    for earlier in [nil, 59, 121, 122, 125, 126] as [Int?] {
      #expect(throws: (any Error).self) {
        try NativeSafeGunnerySave.validateFields(bytes(object), part: .missions, schema: earlier)
      }
    }
    var unknown = try #require(object as? [String: Any])
    var leaf = try #require(unknown["savedSafeGunnery"] as? [String: Any])
    leaf["rewardClaim"] = true
    unknown["savedSafeGunnery"] = leaf
    #expect(throws: (any Error).self) {
      try NativeSafeGunnerySave.validateFields(bytes(unknown), part: .missions, schema: schema)
    }
    unknown.removeValue(forKey: "savedSafeGunnery")
    #expect(throws: (any Error).self) {
      try NativeSafeGunnerySave.validateFields(bytes(unknown), part: .missions, schema: schema)
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": ["instances": ["lesson": object]]
    ])
    #expect(throws: (any Error).self) {
      try NativeSafeGunnerySave.validateFields(embedded, part: .commander, schema: schema)
    }
  }

  @Test func threeDistinctRetainedNativeHitsPreserveEachOriginalWithoutInferringATerminal() throws {
    var f = try fixture()
    var progress = try NativeSafeGunneryProgress(beginning: f.provider)
    #expect(progress.valid && progress.hits.isEmpty && !progress.threeDistinctHits)
    for ordinal in 0..<3 {
      let receipt = try f.observedHit(ordinal)
      try progress.record(receipt, provider: f.provider)
      #expect(progress.hits.count == ordinal + 1)
      #expect(progress.hits.last?.target == f.provider.beacons[ordinal].identity)
    }
    #expect(progress.valid && progress.matches(f.provider) && progress.threeDistinctHits)
    #expect(progress.original.hits.isEmpty && progress.original.endedAt == nil)
    #expect(f.provider.endedAt == nil)
  }

  @Test func detachedNativeObservationsAndRepeatedTargetsCannotEnterLessonHistory() throws {
    var f = try fixture()
    var progress = try NativeSafeGunneryProgress(beginning: f.provider)
    let origin = try f.emission()
    let receipt = try f.hit(1, origin: origin)
    let before = progress
    #expect(throws: NativeSafeGunneryProgressError.foreignReceipt) {
      try progress.record(receipt, provider: f.provider)
    }
    #expect(progress == before)
    try f.provider.record(receipt)
    try progress.record(receipt, provider: f.provider)
    let recorded = progress
    #expect(throws: NativeSafeGunneryProgressError.duplicateReceipt) {
      try progress.record(receipt, provider: f.provider)
    }
    #expect(progress == recorded && progress.hits.count == 1)
  }

  @Test func otherInstancesAndPracticeFamiliesCannotLendTheirHitsOrBeginWithEarlierCredit() throws {
    var own = try fixture()
    var foreign = try fixture("foreign-instance")
    var progress = try NativeSafeGunneryProgress(beginning: own.provider)
    let foreignHit = try foreign.observedHit(0)
    #expect(throws: NativeSafeGunneryProgressError.foreignReceipt) {
      try progress.record(foreignHit, provider: own.provider)
    }
    #expect(throws: NativeSafeGunneryProgressError.foreignReceipt) {
      try progress.record(foreignHit, provider: foreign.provider)
    }
    let defensive = try fixture(lesson: .defensiveFlight)
    #expect(throws: NativeSafeGunneryProgressError.invalidPractice) {
      try NativeSafeGunneryProgress(beginning: defensive.provider)
    }
    _ = try own.observedHit(0)
    #expect(throws: NativeSafeGunneryProgressError.invalidPractice) {
      try NativeSafeGunneryProgress(beginning: own.provider)
    }
    #expect(progress.hits.isEmpty)
  }

  @Test func coldRestorationCatchesUpOnlyFromExactRetainedReceiptsWithoutReplayOrCountFlags() throws
  {
    var f = try fixture()
    let initial = try NativeSafeGunneryProgress(beginning: f.provider)
    _ = try f.observedHit(0)
    _ = try f.observedHit(2)
    let observed = try initial.observing(f.provider)
    let restored = try JSONDecoder().decode(
      NativeSafeGunneryProgress.self, from: JSONEncoder().encode(observed))
    let provider = try JSONDecoder().decode(
      NativePracticeState.self, from: JSONEncoder().encode(f.provider))
    #expect(restored == observed && restored.matches(provider))
    #expect(try restored.observing(provider) == restored)
    #expect(restored.hits.count == 2 && !restored.threeDistinctHits)
    #expect(!restored.matches(initial.original))
    #expect(throws: NativeSafeGunneryProgressError.invalidPractice) {
      try restored.observing(initial.original)
    }
  }

  @Test func providerEndOrMissingTargetsCannotSupplyAHitOrACompletedLesson() throws {
    var f = try fixture()
    let progress = try NativeSafeGunneryProgress(beginning: f.provider)
    let origin = try f.emission()
    #expect(throws: (any Error).self) {
      try NativePracticeHitPolicy.laser(
        state: f.provider, pose: f.flight.pose, bodies: [], meshes: [:], celestials: [],
        direction: .init(0, 0, 1), range: 6000, origin: origin,
        time: 10, nextEmission: f.flight.nextEmission)
    }
    f.provider.endedAt = 10
    #expect(throws: NativeSafeGunneryProgressError.invalidPractice) {
      try progress.observing(f.provider)
    }
    #expect(progress.hits.isEmpty && !progress.threeDistinctHits)
  }
}
