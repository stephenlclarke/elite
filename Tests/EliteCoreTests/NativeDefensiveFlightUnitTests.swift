import Foundation
import Testing

@testable import EliteCore

/// Geometric component fixtures only; these cannot grant native tutorial observations or awards.
struct NativeDefensiveFlightUnitTests {
  private func fixture(
    lesson: NativePracticeLesson = .defensiveFlight, frame: ShipPose = .init(),
    owner: UUID = ScriptIdentity.uuid("defensive-flight-owner"),
    carrier: UUID = ScriptIdentity.uuid("defensive-flight-carrier")
  ) throws -> NativePracticeState {
    var flight = FlightSimulationState()
    flight.enter(.init(galaxy: 0, system: 7), arriving: false)
    flight.enter(.init(galaxy: 0, system: 7), arriving: false)
    flight.pose = frame
    flight.physicalTime = 10
    let mission = ScriptIdentity.uuid("defensive-flight-geometry-unit")
    let dock = NativeMainStationDockReceipt(
      station: .init(
        world: owner, system: .init(galaxy: 0, system: 7),
        resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7")),
      actor: .init(system: .init(galaxy: 0, system: 7), visit: 1, entity: 1),
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    func context(_ revision: UInt64) -> ScriptEventContext {
      var value = ScriptEventContext(
        galaxy: 0, system: 7, docked: true, mainStation: true, revision: revision,
        frameSeconds: 0, localSeconds: 0, flightSeconds: 0, calendarSeconds: 0,
        transitSeconds: 0, playerPosition: nil)
      value.nativeMainDock = dock
      return value
    }
    let permission = NativePracticePermission(
      mission: mission, owner: owner, carrier: carrier, lesson: lesson,
      digest: NativeDefensiveFlight.digest,
      consent: .init(
        instance: mission, group: NativePracticeSource.consentGroup,
        choice: NativePracticeSource.consentChoice, label: "Review defensive flight",
        dialogue: "defensive-flight-review", sequence: 1, revision: 1,
        cause: context(0), committed: context(1)),
      player: try #require(flight.player), frame: frame, begunAt: 10)
    return try NativePracticeState.prepare(permission: permission, flight: &flight)
  }

  private func reading(
    _ practice: NativePracticeState, position: Vector3, velocity: Vector3,
    yaw: Double = 0, time: Double = 10
  ) throws -> NativeDefensiveFlightGeometry.Reading {
    var local = Basis3()
    local.rotate(pitch: 0, roll: 0, yaw: yaw)
    var orientation = Basis3()
    orientation.x = practice.permission.frame.orientation.apply(local.x)
    orientation.y = practice.permission.frame.orientation.apply(local.y)
    orientation.z = practice.permission.frame.orientation.apply(local.z)
    let pose = ShipPose(
      position: practice.permission.position(1)
        + practice.permission.frame.orientation.apply(position), orientation: orientation)
    return try #require(
      NativeDefensiveFlightGeometry.reading(
        practice: practice, player: practice.permission.player, pose: pose,
        worldVelocity: practice.permission.frame.orientation.apply(velocity), time: time))
  }

  private func state(_ provider: NativePracticeState, radius: Double = 10) throws
    -> NativeDefensiveFlightState
  {
    let p = provider.permission
    var value = NativeDefensiveFlightState(
      permission: .init(
        mission: p.mission, owner: p.owner, carrier: p.carrier,
        dock: try #require(p.consent.committed.nativeMainDock), consent: p.consent, acceptedAt: 0))
    try value.begin(provider, radius: radius)
    return value
  }

  private func sample(
    _ provider: NativePracticeState, position: Vector3, velocity: Vector3, time: Double,
    yaw: Double = 0, clear: Bool = true, manual: Bool = true, visible: Bool = true
  ) throws -> NativeDefensiveFlightSample {
    let value = try reading(provider, position: position, velocity: velocity, yaw: yaw, time: time)
    return .init(
      reading: value, manual: manual, clear: clear,
      centreContact: visible ? value.centreActor : nil)
  }

  private func acquiring(
    _ provider: NativePracticeState, state: inout NativeDefensiveFlightState, steps: Int
  ) throws -> NativeDefensiveFlightSample {
    var current = try sample(
      provider, position: .init(0, 0, -450), velocity: .init(0, 0, 0), time: 10)
    try state.observe(before: nil, after: current, delta: 0.1)
    for _ in 0..<steps {
      let next = try sample(
        provider, position: current.reading.position, velocity: .init(0, 0, 0),
        time: current.reading.time + 0.1)
      try state.observe(before: current, after: next, delta: 0.1)
      current = next
    }
    return current
  }

  /// Component interval reducer only. No Game.tick, native journey or terminal is executed.
  private func completedWindows(_ provider: NativePracticeState, radius: Double = 10) throws
    -> NativeDefensiveFlightState
  {
    var value = try state(provider, radius: radius)
    var current = try acquiring(provider, state: &value, steps: 21)
    try #require(value.windows.count == 1)
    func move(to position: Vector3, velocity: Vector3, yaw: Double) throws {
      let next = try sample(
        provider, position: position, velocity: velocity,
        time: current.reading.time + 0.1, yaw: yaw)
      try value.observe(before: current, after: next, delta: 0.1)
      current = next
    }
    while value.windows.count == 1 {
      try move(
        to: current.reading.position + Vector3(0.5, 0, 0), velocity: .init(5, 0, 0), yaw: -.pi / 2)
      try #require(current.reading.position.x < 200)
    }
    while value.windows.count == 2 {
      try move(
        to: current.reading.position - Vector3(0.5, 0, 0), velocity: .init(-5, 0, 0), yaw: .pi / 2)
      try #require(current.reading.position.x > -200)
    }
    while value.windows.count == 3 {
      try move(
        to: current.reading.position - Vector3(0, 0, 0.6), velocity: .init(0, 0, -6), yaw: .pi)
      try #require(current.reading.position.z > -1450)
    }
    try value.sealDisengagement(calendar: 500)
    return value
  }

  private func nativeObservationGame() throws -> Game {
    var game = Game(executive: false)
    try game.commander.prepareEquipment()
    let owner = try #require(game.commander.equipmentOwnerID)
    let carrier = try #require(game.commander.hullInstanceID)
    let provider = try fixture(owner: owner, carrier: carrier)
    var flight = FlightSimulationState()
    flight.enter(provider.permission.player.system, arriving: false)
    flight.enter(provider.permission.player.system, arriving: false)
    flight.physicalTime = 10
    let allocated = try NativePracticeState.prepare(
      permission: provider.permission, flight: &flight)
    try #require(allocated == provider)
    flight.pose.position = provider.permission.position(1) + Vector3(0, 0, -450)
    game.commander.flightSimulation = flight
    game.commander.system = 7
    game.docked = false
    game.screen = .front
    game.speed = 0
    let radius = try #require(game.commander.playerMesh.vertices.map(\.length).max())
    var lesson = NativeDefensiveFlightState(
      permission: .init(
        mission: provider.permission.mission, owner: owner, carrier: carrier,
        dock: try #require(provider.permission.consent.committed.nativeMainDock),
        consent: provider.permission.consent, acceptedAt: 0))
    try lesson.begin(provider, radius: radius)
    var instance = ScriptInstance(
      id: provider.permission.mission,
      definition: NativeDefensiveFlight.stateID, version: NativeDefensiveFlight.version,
      digest: NativeDefensiveFlight.digest)
    instance.revision = 1
    instance.acknowledge(1)
    instance.choiceReceipts[NativePracticeSource.consentGroup] = provider.permission.consent
    instance.savedNativePractice = provider
    instance.savedDefensiveFlight = lesson
    instance.milestones = lesson.milestones
    game.commander.scriptState.nextEvent = 1
    game.commander.scriptState.instances[instance.id] = instance
    game.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledDefensiveFlightDirectory)
    ]
    game.bodies = provider.beacons.enumerated().map {
      provider.body(for: $0.element, id: 50 + $0.offset, pose: flight.pose)
    }
    return game
  }

  /// Actual command helpers with component course receipts; no Game.tick, native journey or disk store.
  private func receivingGame() throws -> Game {
    var game = Game(executive: false)
    try game.commander.prepareEquipment()
    let owner = try #require(game.commander.equipmentOwnerID)
    let carrier = try #require(game.commander.hullInstanceID)
    let system = NativeDefensiveFlight.location
    game.commander.system = system.system
    game.commander.flightSimulation.enter(system, arriving: false)
    let station = NativeMainStationIdentity(
      world: owner, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
    let dock = NativeMainStationDockReceipt(
      station: station, actor: .init(system: system, visit: 1, entity: 1),
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    var world = try NativeStationWorld(owner: owner)
    world.mainStations = [station]
    world.currentMainDock = dock
    world.nextMainDockSequence = 2
    game.commander.nativeStations = world
    game.docked = true
    game.dockedAtMainStation = true
    try game.rebindNativeStationsAfterLoad()
    game.scriptDurabilityAvailable = true
    game.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledDefensiveFlightDirectory)
    ]
    let review = game.defensiveFlightReview(.accept)
    try #require(review.allowed)
    try game.confirmDefensiveFlight(review)
    let active = try #require(game.activeDefensiveFlight)
    var flight = game.commander.flightSimulation
    flight.enter(system, arriving: false)
    flight.pose.position = .init(20000, 0, 0)
    flight.physicalTime = 10
    let provider = try NativePracticeState.prepare(
      permission: .init(
        mission: active.instance.id, owner: owner, carrier: carrier, lesson: .defensiveFlight,
        digest: NativeDefensiveFlight.digest, consent: active.state.permission.consent,
        player: try #require(flight.player), frame: flight.pose, begunAt: 10), flight: &flight)
    let radius = try #require(game.commander.playerMesh.vertices.map(\.length).max())
    let complete = try completedWindows(provider, radius: radius)
    flight.physicalTime = try #require(complete.windows.last?.last.reading.time) + 1
    var retired = provider
    retired.endedAt = flight.physicalTime
    var mission = active.instance
    mission.savedDefensiveFlight = complete
    mission.savedNativePractice = retired
    mission.milestones = complete.milestones
    game.commander.flightSimulation = flight
    game.commander.scriptState.instances[mission.id] = mission
    game.commander.scriptState.calendarSeconds = 501
    let arrival = NativeMainStationDockReceipt(
      station: station, actor: .init(system: system, visit: flight.visit, entity: 1),
      commanderOwner: owner, sequence: 2, calendarSeconds: 501)
    game.commander.nativeStations?.currentMainDock = arrival
    game.commander.nativeStations?.nextMainDockSequence = 3
    try game.rebindNativeStationsAfterLoad()
    try #require(NativeDefensiveFlightSave.validateClaims(game.commander))
    return game
  }

  @Test func receivingCandidateIsZeroCashOnceAndProtectedCommandRefusalRetainsAttainedProof()
    async throws
  {
    let game = try receivingGame()
    let id = try #require(game.activeDefensiveFlight?.instance.id)
    let credits = game.commander.credits
    var received = game
    try received.confirmDefensiveFlight(received.defensiveFlightReview(.receive))
    let terminal = try #require(received.commander.scriptState.instances[id])
    #expect(terminal.outcome == .complete && terminal.contract?.settlementAmount == 0)
    #expect(received.commander.credits == credits)
    #expect(received.commander.scriptState.savedClueJournal?.awards.count == 1)
    #expect(
      received.commander.scriptState.savedClueJournal?.awards[NativeDefensiveFlight.stateID]?.clueID
        == "defensive-flight-family-trace")
    #expect(NativeDefensiveFlightSave.validateClaims(received.commander))
    let frozen = received.commander
    #expect(throws: (any Error).self) { try received.finishDefensiveFlight(.complete) }
    #expect(received.commander == frozen)

    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    do {
      try await runtime.defensiveFlightReceivingComponent { _ in
        throw DefensiveFlightWriteRefusal.refused
      }
      Issue.record("The injected publication refusal must reach the protected command.")
    } catch DefensiveFlightWriteRefusal.refused {}
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.activeDefensiveFlight?.state.ready == true)
    #expect(refused.commander.scriptState.savedClueJournal == nil)
    try await runtime.defensiveFlightReceivingComponent { _ in
      // Successful in-memory publisher fixture; disk-store integration is outside this unit.
    }
    let retried = await runtime.snapshot()
    #expect(retried.commander.scriptState.instances[id]?.outcome == .complete)
    #expect(retried.commander.scriptState.savedClueJournal?.awards.count == 1)
    #expect(retried.commander.credits == credits)
  }

  @Test func exactBundledPinUsesOnlyTheExistingFamilyClueAndFirstReceiptIsRetained() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledDefensiveFlightDirectory)
    #expect(pack.manifest.stateID == NativeDefensiveFlight.stateID)
    #expect(pack.manifest.version == NativeDefensiveFlight.version)
    #expect(pack.digest == NativeDefensiveFlight.digest)
    #expect(pack.manifest.mission.milestones.count == 7)
    let provider = try fixture()
    let consent = provider.permission.consent
    func receipt(event: String, digest: String, sequence: UInt64) -> ScriptCompletionReceipt {
      .init(
        instance: provider.permission.mission, definition: pack.manifest.stateID,
        version: pack.manifest.version, digest: digest, outcome: .complete, sequence: sequence,
        causeKind: event, cause: consent.committed, committed: consent.committed, revision: 2,
        milestones: Array(0...6), destroyedEncounters: [], deliveredParties: [],
        returnedEquipment: [], settlementAmount: 0,
        choices: [NativePracticeSource.consentGroup: consent])
    }
    let approved = receipt(event: "mission.receipted", digest: pack.digest, sequence: 2)
    let trust = ScriptClueTrustCatalog.production
    #expect(trust.pin(for: approved)?.sourceID == NativeDefensiveFlight.stateID)
    #expect(
      trust.pin(for: receipt(event: "mission.accepted", digest: pack.digest, sequence: 2)) == nil)
    #expect(
      trust.pin(
        for: receipt(
          event: "mission.receipted", digest: NativeSafeGunnery.digest,
          sequence: 2)) == nil)
    let source = try #require(ScriptBaseClueCatalog.bySource[NativeDefensiveFlight.stateID])
    #expect(source.clueID == "defensive-flight-family-trace")
    var journal = ScriptClueJournal(owner: provider.permission.owner)
    journal.record(approved, source: source)
    journal.record(
      receipt(event: "mission.receipted", digest: pack.digest, sequence: 3), source: source)
    #expect(journal.awards.count == 1 && journal.awards[source.sourceID]?.completion == approved)
  }

  @Test func acquisitionUsesTheOriginalCentreAndFiveDegreeActualNoseAlignment() throws {
    let practice = try fixture()
    let aligned = try reading(practice, position: .init(0, 0, -450), velocity: .init(0, 0, 0))
    #expect(NativeDefensiveFlightGeometry.acquisitionAligned(aligned))
    #expect(aligned.centreActor == practice.beacons[1].actor)
    #expect(aligned.operation == practice.permission.operation)
    let outside = try reading(
      practice, position: .init(0, 0, -450), velocity: .init(0, 0, 0), yaw: 5.01 * .pi / 180)
    #expect(!NativeDefensiveFlightGeometry.acquisitionAligned(outside))
    let atCentre = try reading(practice, position: .init(0, 0, 0), velocity: .init(0, 0, 0))
    #expect(!NativeDefensiveFlightGeometry.acquisitionAligned(atCentre))
  }

  @Test func gatesRequireMeasuredHullFitActualSpeedAndTheRequestedSignedLateralMotion() throws {
    let practice = try fixture()
    for gate in NativeDefensiveFlightGeometry.Gate.allCases {
      let valid = try reading(
        practice, position: gate.offset, velocity: .init(5 * gate.direction, 0, 0),
        yaw: -gate.direction * .pi / 2)
      #expect(
        NativeDefensiveFlightGeometry.insideGate(gate, reading: valid, measuredHullRadius: 10))
      let withoutAcquisitionContact = NativeDefensiveFlightSample(
        reading: valid, manual: true, clear: true, centreContact: nil)
      #expect(withoutAcquisitionContact.qualifies(phase: gate == .positive ? 1 : 2, radius: 10))
      #expect(
        !NativeDefensiveFlightGeometry.insideGate(gate, reading: valid, measuredHullRadius: 100))
      let backwards = try reading(
        practice, position: gate.offset, velocity: .init(-5 * gate.direction, 0, 0))
      #expect(
        !NativeDefensiveFlightGeometry.insideGate(gate, reading: backwards, measuredHullRadius: 10))
      let tooFast = try reading(
        practice, position: gate.offset, velocity: .init(31 * gate.direction, 0, 0))
      #expect(
        !NativeDefensiveFlightGeometry.insideGate(gate, reading: tooFast, measuredHullRadius: 10))
      let crossesEdge = try reading(
        practice, position: gate.offset + Vector3(41, 0, 0),
        velocity: .init(5 * gate.direction, 0, 0), yaw: -gate.direction * .pi / 2)
      #expect(
        !NativeDefensiveFlightGeometry.insideGate(
          gate, reading: crossesEdge, measuredHullRadius: 10))
    }
  }

  @Test func withdrawalRequiresBehindTheRangeBeyond1100FacingAwayAndActualSeparation() throws {
    let practice = try fixture()
    let valid = try reading(
      practice, position: .init(0, 0, -1200), velocity: .init(0, 0, -5), yaw: .pi)
    #expect(NativeDefensiveFlightGeometry.withdrawing(valid, measuredHullRadius: 10))
    let threshold = try reading(
      practice, position: .init(0, 0, -1099), velocity: .init(0, 0, -5), yaw: .pi)
    #expect(!NativeDefensiveFlightGeometry.withdrawing(threshold, measuredHullRadius: 10))
    let facingCentre = try reading(
      practice, position: .init(0, 0, -1200), velocity: .init(0, 0, -5))
    #expect(!NativeDefensiveFlightGeometry.withdrawing(facingCentre, measuredHullRadius: 10))
    let closing = try reading(
      practice, position: .init(0, 0, -1200), velocity: .init(0, 0, 5), yaw: .pi)
    #expect(!NativeDefensiveFlightGeometry.withdrawing(closing, measuredHullRadius: 10))
  }

  @Test func rotatedFrozenFrameKeepsTheSamePhysicalGateAndVelocityMeaning() throws {
    var basis = Basis3()
    basis.rotate(pitch: 0.2, roll: 0.3, yaw: 0.7)
    let practice = try fixture(frame: .init(position: .init(20000, 500, -300), orientation: basis))
    let gate = NativeDefensiveFlightGeometry.Gate.positive
    let sample = try reading(
      practice, position: gate.offset, velocity: .init(8, 0, 0), yaw: -.pi / 2)
    #expect((sample.position - gate.offset).length < 1e-8)
    #expect(abs(sample.velocity.x - 8) < 1e-8)
    #expect(NativeDefensiveFlightGeometry.insideGate(gate, reading: sample, measuredHullRadius: 10))
  }

  @Test func actualStarterHullFitsThePublishedCourseWithoutRescaling() throws {
    let commander = Commander()
    let mesh = commander.playerMesh
    let radius = try #require(mesh.vertices.map(\.length).max())
    #expect(NativeDefensiveFlightGeometry.hullFits(radius: radius))
    #expect(!NativeDefensiveFlightGeometry.hullFits(radius: 100))
    #expect(!NativeDefensiveFlightGeometry.hullFits(radius: .nan))
  }

  @Test func foreignPlayerEarlierTimeNonfinitePoseAndTheOtherLessonCannotSupplyReadings() throws {
    let practice = try fixture()
    let own = practice.permission.player
    let pose = practice.permission.frame
    #expect(
      NativeDefensiveFlightGeometry.reading(
        practice: practice, player: .init(system: own.system, visit: own.visit + 1, entity: 0),
        pose: pose, worldVelocity: .init(0, 0, 0), time: 10) == nil)
    #expect(
      NativeDefensiveFlightGeometry.reading(
        practice: practice, player: own, pose: pose, worldVelocity: .init(0, 0, 0), time: 9) == nil)
    #expect(
      NativeDefensiveFlightGeometry.reading(
        practice: practice, player: own, pose: pose, worldVelocity: .init(.nan, 0, 0), time: 10)
        == nil)
    let other = try fixture(lesson: .gunnery)
    #expect(
      NativeDefensiveFlightGeometry.reading(
        practice: other, player: other.permission.player, pose: pose,
        worldVelocity: .init(0, 0, 0), time: 10) == nil)
  }
  @Test func nativeCentreDirectedMeshQueryNeedsNoComputerAndOrdinaryOcclusionStaysOrdinary() throws
  {
    var game = try nativeObservationGame()
    #expect(game.commander.targetingTier == nil)
    let own = try #require(game.defensiveFlightSample())
    #expect(own.manual && own.clear && own.centreContact == own.reading.centreActor)
    let actor = game.commander.flightSimulation.allocateActor()
    var ordinary = SpaceBody(id: 90, hull: .cargo, position: .init(0, 0, 100))
    ordinary.physical = .init(identity: try #require(actor), population: .cargo)
    game.bodies.append(ordinary)
    let law = game.commander.crimeLedger
    let blocked = try #require(game.defensiveFlightSample())
    #expect(blocked.centreContact == nil && !blocked.clear)
    #expect(game.bodies.last == ordinary && game.commander.crimeLedger == law)
    #expect(game.commander.targetingTier == nil && game.autoPilot.targetID == nil)
  }

  @Test func observationRefusesMissingOriginalsForeignBodyLabelsAndAutomatedOrCameraCredit() throws
  {
    var game = try nativeObservationGame()
    game.dockingComputer = true
    #expect(game.defensiveFlightSample()?.manual == false)
    game.dockingComputer = false
    let radius = try #require(game.activeDefensiveFlight?.state.hullRadius)
    let pose = game.commander.flightSimulation.pose
    for view in [Screen.rear, .left, .right] {
      game.screen = .front
      let front = try #require(game.defensiveFlightSample())
      #expect(front.qualifies(phase: 0, radius: radius))
      game.screen = view
      let alternate = try #require(game.defensiveFlightSample())
      #expect(alternate.reading == front.reading)
      #expect(alternate.manual == front.manual && alternate.clear == front.clear)
      #expect(alternate.centreContact == nil && !alternate.qualifies(phase: 0, radius: radius))
      // Fresh native observations bracket actual clock advancement with unchanged zero-speed
      // physical pose and sight. More than two seconds in each other view must earn nothing.
      game.advanceDefensiveFlight(before: nil, delta: 0.1)
      for _ in 0..<25 {
        let before = try #require(game.defensiveFlightObservation())
        game.commander.flightSimulation.advancePhysicalTime(0.1)
        game.advanceDefensiveFlight(before: before, delta: 0.1)
      }
      let state = try #require(game.activeDefensiveFlight?.state)
      #expect(state.windows.isEmpty && state.pending == nil && state.failure == nil)
      #expect(game.commander.flightSimulation.pose == pose)
    }
    game.screen = .front
    game.bodies[1].hostile = true
    #expect(game.defensiveFlightSample() == nil)
    game.bodies.remove(at: 1)
    #expect(game.defensiveFlightSample() == nil)
  }

  @Test func corridorClearanceUsesFullOrdinaryMeshBoundsAndRefusesUnknownSceneBodies() throws {
    var game = try nativeObservationGame()
    let provider = try #require(game.activeDefensiveFlight?.instance.savedNativePractice)
    let radius = try #require(game.activeDefensiveFlight?.state.hullRadius)
    let pose = game.commander.flightSimulation.pose
    let identity = game.commander.flightSimulation.allocateActor()
    var traffic = SpaceBody(id: 90, hull: .cargo, position: .init(0, 0, -600))
    traffic.physical = .init(identity: try #require(identity), population: .cargo)
    game.bodies.append(traffic)
    // This actor is beyond the original sphere but inside the withdrawal corridor.
    #expect(!game.defensiveFlightCourseIsClear(provider, radius: radius))
    game.bodies[3].position.x = 1200
    let context = try #require(game.gameplayContext())
    let cube = NativePracticeSource.mesh()
    var meshes = Dictionary(uniqueKeysWithValues: game.bodies.map { ($0.id, cube) })
    #expect(
      NativeDefensiveFlightAdmission.clear(
        practice: provider, pose: pose, context: context,
        bodies: game.bodies, meshes: meshes, radius: radius))
    // Its centre is clear; its full native mesh still reaches into the corridor.
    meshes[90] = Mesh(
      vertices: cube.vertices.map { .init($0.x * 500, $0.y, $0.z) }, faces: cube.faces,
      preserveWinding: true)
    #expect(
      !NativeDefensiveFlightAdmission.clear(
        practice: provider, pose: pose, context: context,
        bodies: game.bodies, meshes: meshes, radius: radius))
    game.bodies.append(SpaceBody(id: 91, hull: .cargo, position: .init(10000, 0, 0)))
    #expect(!game.defensiveFlightCourseIsClear(provider, radius: radius))
  }

  @Test func ordinaryAcceptedHarmKeepsNormalLawAndSealedBreakoffEndsTheFailureScope() throws {
    let provider = try fixture()
    let player = crimeTestActor(
      0, position: .init(0, 0, 0), role: nil, visit: provider.permission.player.visit)
    let trader = crimeTestActor(
      20, position: .init(21000, 0, 0), visit: provider.permission.player.visit)
    let incident = crimeTestIncident(1, time: 10, owner: player, victim: trader)
    var law = CrimeLedger()
    let result = law.record(
      incident,
      context: crimeTestContext(
        10, player: player, actors: [trader], visit: provider.permission.player.visit))
    #expect(result.accepted && result.unlawful && result.legalPenalty > 0)
    let ordinaryLaw = law
    var value = try state(provider)
    value.recordFailure(.ordinaryHit(incident))
    #expect(value.failure == .ordinaryHit(incident) && !value.ready)
    #expect(law == ordinaryLaw && provider.hits.isEmpty)
    var complete = try completedWindows(provider)
    let sealed = complete
    complete.recordFailure(.ordinaryHit(incident))
    complete.recordFailure(.collision(player: provider.permission.player, time: 500))
    #expect(complete == sealed && complete.ready)
  }

  @Test func orderedActualIntervalsNeedGateEntriesCrossingAndASealedWithdrawal() throws {
    let provider = try fixture()
    let complete = try completedWindows(provider)
    #expect(complete.valid && complete.ready && complete.windows.map(\.phase) == [0, 1, 2, 3])
    #expect(
      complete.positiveEntry != nil && complete.negativeEntry != nil
        && complete.crossing?.valid == true)
    #expect(complete.disengagedCalendar == 500 && complete.terminalOutcome == nil)
    #expect(complete.original == provider && complete.milestones == [0, 1, 2, 3, 4, 5])
  }

  @Test func startingInsideAGateOrAssigningAPoseDoesNotSupplyItsNativeEntry() throws {
    let provider = try fixture()
    var value = try state(provider)
    _ = try acquiring(provider, state: &value, steps: 21)
    var current = try sample(
      provider, position: .init(180, 0, -450), velocity: .init(5, 0, 0), time: 20, yaw: -.pi / 2)
    try value.observe(before: nil, after: current, delta: 0.1)
    for _ in 0..<10 {
      let next = try sample(
        provider, position: current.reading.position + Vector3(0.5, 0, 0),
        velocity: .init(5, 0, 0), time: current.reading.time + 0.1, yaw: -.pi / 2)
      try value.observe(before: current, after: next, delta: 0.1)
      current = next
    }
    #expect(value.windows.count == 1 && value.positiveEntry == nil && value.pending == nil)
  }

  @Test func pauseColdRestoreGapsOcclusionAndIntrusionCannotInventActiveTime() throws {
    let provider = try fixture()
    var value = try state(provider)
    var current = try acquiring(provider, state: &value, steps: 8)
    let earned = try #require(value.pending?.duration)
    try value.observe(before: current, after: current, delta: 0)
    #expect(value.pending?.duration == earned)
    var restored = try JSONDecoder().decode(
      NativeDefensiveFlightState.self, from: JSONEncoder().encode(value))
    #expect(restored.pending?.duration == earned && restored.windows == value.windows)
    let next = try sample(
      provider, position: current.reading.position, velocity: .init(0, 0, 0),
      time: current.reading.time + 0.1)
    try restored.observe(before: current, after: next, delta: 0.1)
    #expect(abs((restored.pending?.duration ?? 0) - earned - 0.1) < 1e-8)
    current = next
    let blocked = try sample(
      provider, position: current.reading.position, velocity: .init(0, 0, 0),
      time: current.reading.time + 0.1, clear: false, visible: false)
    try restored.observe(before: current, after: blocked, delta: 0.1)
    #expect(restored.pending == nil && restored.windows.isEmpty && restored.failure == nil)
    let gap = try sample(
      provider, position: current.reading.position, velocity: .init(0, 0, 0), time: 100)
    try restored.observe(before: blocked, after: gap, delta: 0.1)
    #expect(restored.pending == nil && restored.windows.isEmpty)
  }

  @Test func measuredNearPassFailsOnlyThisExerciseAndDischargeFailureCannotBeReplaced() throws {
    let provider = try fixture()
    var near = try state(provider)
    let first = try sample(provider, position: .init(0, 0, -42), velocity: .init(0, 0, 5), time: 10)
    let last = try sample(
      provider, position: .init(0, 0, -41.5), velocity: .init(0, 0, 5), time: 10.1)
    try near.observe(before: nil, after: first, delta: 0.1)
    try near.observe(before: first, after: last, delta: 0.1)
    #expect(near.failure != nil && !near.ready && near.valid)
    var fired = try state(provider)
    let reason = NativeDefensiveFlightFailure.discharge(
      player: provider.permission.player, emission: 1, time: 10)
    fired.recordFailure(reason)
    fired.recordFailure(.collision(player: provider.permission.player, time: 11))
    #expect(fired.failure == reason && fired.valid && !fired.ready)
    #expect(provider.hits.isEmpty && provider.endedAt == nil)
  }

  @Test func sealedBreakoffRequiresRetiredProviderAndActualLaterOwnerCarrierReception() throws {
    let provider = try fixture()
    let complete = try completedWindows(provider)
    var retired = provider
    retired.endedAt = 500
    let old = complete.permission.dock
    let arrival = NativeMainStationDockReceipt(
      station: old.station,
      actor: .init(system: old.actor.system, visit: provider.permission.player.visit, entity: 1),
      commanderOwner: old.commanderOwner, sequence: old.sequence + 1, calendarSeconds: 501)
    #expect(
      !NativeDefensiveFlightReception.allowed(
        state: complete, provider: provider,
        dock: arrival, owner: complete.permission.owner, carrier: complete.permission.carrier))
    #expect(
      NativeDefensiveFlightReception.allowed(
        state: complete, provider: retired,
        dock: arrival, owner: complete.permission.owner, carrier: complete.permission.carrier))
    #expect(
      !NativeDefensiveFlightReception.allowed(
        state: complete, provider: retired,
        dock: old, owner: complete.permission.owner, carrier: complete.permission.carrier))
    #expect(
      !NativeDefensiveFlightReception.allowed(
        state: complete, provider: retired,
        dock: arrival, owner: UUID(), carrier: complete.permission.carrier))
    #expect(
      !NativeDefensiveFlightReception.allowed(
        state: complete, provider: retired,
        dock: arrival, owner: complete.permission.owner, carrier: UUID()))
  }

  @Test func pendingAdmissionKeepsTheFirstActualLaunchVisitAndCannotRestartOnReturn() throws {
    var game = try nativeObservationGame()
    let active = try #require(game.activeDefensiveFlight)
    let player = try #require(game.commander.flightSimulation.player)
    var pending = NativeDefensiveFlightState(permission: active.state.permission)
    try pending.launched(player: player)
    var instance = active.instance
    instance.savedDefensiveFlight = pending
    instance.savedNativePractice = nil
    instance.milestones = [0]
    game.commander.scriptState.instances[instance.id] = instance
    game.bodies = [SpaceBody(id: 90, hull: .cargo, position: .init(10000, 0, 0))]
    let bodies = game.bodies
    let law = game.commander.crimeLedger
    let credits = game.commander.credits
    #expect(pending.original == nil && pending.attemptPlayer == player && pending.valid)
    game.commander.flightSimulation.enter(NativeDefensiveFlight.location, arriving: false)
    game.closeDefensiveFlightIfNeeded()
    let failed = try #require(game.commander.scriptState.instances[instance.id])
    #expect(failed.outcome == .failed)
    #expect(
      failed.savedDefensiveFlight?.failure
        == .interruption(
          player: player, time: 10, reason: .visitChanged))
    #expect(failed.savedDefensiveFlight?.original == nil && failed.savedNativePractice == nil)
    #expect(game.bodies == bodies && game.commander.crimeLedger == law)
    #expect(game.commander.credits == credits && game.commander.scriptState.savedClueJournal == nil)
  }

  @Test func reorderedForeignErasedAndInventedDurationProofsCannotBecomeReady() throws {
    let provider = try fixture()
    let complete = try completedWindows(provider)
    let original = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(complete)) as? [String: Any])
    func decode(_ raw: [String: Any]) throws -> NativeDefensiveFlightState {
      try JSONDecoder().decode(
        NativeDefensiveFlightState.self, from: JSONSerialization.data(withJSONObject: raw))
    }
    var raw = original
    var windows = try #require(raw["windows"] as? [[String: Any]])
    windows.swapAt(0, 1)
    raw["windows"] = windows
    #expect(!(try decode(raw)).valid)
    raw = original
    windows = try #require(raw["windows"] as? [[String: Any]])
    windows[0]["duration"] = 200
    raw["windows"] = windows
    #expect(!(try decode(raw)).valid)
    raw = original
    raw.removeValue(forKey: "crossing")
    #expect(!(try decode(raw)).ready)
    raw = original
    var entry = try #require(raw["negativeEntry"] as? [String: Any])
    var last = try #require(entry["last"] as? [String: Any])
    var reading = try #require(last["reading"] as? [String: Any])
    reading["operation"] = UUID().uuidString
    last["reading"] = reading
    entry["last"] = last
    raw["negativeEntry"] = entry
    #expect(!(try decode(raw)).valid)
    #expect(complete.valid && complete.ready)
  }

  func archiveFixture() throws -> ScriptInstance {
    let provider = try fixture()
    var instance = ScriptInstance(
      id: provider.permission.mission, definition: NativeDefensiveFlight.stateID,
      version: NativeDefensiveFlight.version, digest: NativeDefensiveFlight.digest)
    instance.savedDefensiveFlight = try state(provider)
    instance.savedNativePractice = provider
    return instance
  }

  @Test(arguments: [false, true])
  func closed135136RejectEarlierEmbeddedUnknownAndMissingNativeProofs(alien: Bool) throws {
    let provider = try fixture()
    let value = try state(provider)
    let initial = NativeDefensiveFlightState(permission: value.permission)
    #expect(initial.valid && initial.permission == value.permission && !initial.ready)
    #expect(initial.original == nil && initial.attemptPlayer == nil && initial.hullRadius == nil)
    #expect(initial.windows.isEmpty && initial.pending == nil && initial.previous == nil)
    #expect(initial.positiveEntry == nil && initial.negativeEntry == nil && initial.crossing == nil)
    #expect(initial.failure == nil && initial.disengagedCalendar == nil)
    #expect(
      initial.terminalOperation == nil && initial.terminalDock == nil
        && initial.terminalOutcome == nil)
    var instance = ScriptInstance(
      id: provider.permission.mission, definition: NativeDefensiveFlight.stateID,
      version: NativeDefensiveFlight.version, digest: NativeDefensiveFlight.digest)
    instance.savedDefensiveFlight = value
    instance.savedNativePractice = provider
    func object(_ value: some Encodable) throws -> [String: Any] {
      try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
    func bytes(_ raw: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [instance.id.uuidString: raw]])
    }
    let initialRaw = try object(initial)
    #expect(!initialRaw.keys.contains("liveEndpoint"))
    let raw = try object(instance)
    let schema = alien ? 136 : 135
    try NativeDefensiveFlightSave.validateArchiveFields(
      bytes(raw), part: .missions, schema: schema, alien: alien)
    let surveyor = try trainingSurveyorArchiveFixture()
    let lesson = try NativeSafeGunneryUnitTests().archiveFixture()
    var entries: [String: Any] = [
      instance.id.uuidString: raw, surveyor.id.uuidString: try object(surveyor),
      lesson.id.uuidString: try object(lesson),
    ]
    let mixed = try JSONSerialization.data(withJSONObject: ["instances": entries])
    try NativeDefensiveFlightSave.validateArchiveFields(
      mixed, part: .missions, schema: schema, alien: alien)
    var changedSurveyor = try object(surveyor)
    var changedOpening = try #require(changedSurveyor["savedGlassMeridian"] as? [String: Any])
    var changedSource = try #require(changedOpening["surveyor"] as? [String: Any])
    changedSource["inventedCompletion"] = true
    changedOpening["surveyor"] = changedSource
    changedSurveyor["savedGlassMeridian"] = changedOpening
    entries[surveyor.id.uuidString] = changedSurveyor
    let mixedUnknown = try JSONSerialization.data(withJSONObject: ["instances": entries])
    #expect(throws: (any Error).self) {
      try NativeDefensiveFlightSave.validateArchiveFields(
        mixedUnknown, part: .missions, schema: schema, alien: alien)
    }
    for earlier in [nil, 121, 127, 129, 131, 133, 134] as [Int?] {
      #expect(throws: (any Error).self) {
        try NativeDefensiveFlightSave.validateFields(bytes(raw), part: .missions, schema: earlier)
      }
    }
    var altered = raw
    var leaf = try object(value)
    leaf["inventedCompletion"] = true
    altered["savedDefensiveFlight"] = leaf
    #expect(throws: (any Error).self) {
      try NativeDefensiveFlightSave.validateFields(bytes(altered), part: .missions, schema: schema)
    }
    altered.removeValue(forKey: "savedDefensiveFlight")
    #expect(throws: (any Error).self) {
      try NativeDefensiveFlightSave.validateFields(bytes(altered), part: .missions, schema: schema)
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": ["instances": ["own": raw]]
    ])
    #expect(throws: (any Error).self) {
      try NativeDefensiveFlightSave.validateFields(embedded, part: .commander, schema: schema)
    }
  }

}

private enum DefensiveFlightWriteRefusal: Error { case refused }

extension GameRuntime {
  /// Exercise the existing command rollback with a bounded injected publisher, without a disk store.
  fileprivate func defensiveFlightReceivingComponent(publish: ScriptPublisher) throws {
    try scriptCommand { candidate in
      guard candidate.commander.nativeStations?.currentMainDock != nil else {
        throw SaveError.invalidCommander
      }
      candidate.scriptDurabilityAvailable = true
      try candidate.rebindNativeStationsAfterLoad()
      try candidate.confirmDefensiveFlight(candidate.defensiveFlightReview(.receive))
      try publish(&candidate)
    }
  }
}
