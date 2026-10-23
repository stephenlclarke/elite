import Foundation
import Testing

@testable import EliteCore

/// Native mesh/policy and archive units. The plain-load test exercises only the refusal boundary.
struct PracticeTargetUnitTests {
  private struct Fixture {
    var flight: FlightSimulationState
    var state: NativePracticeState
    var instance: ScriptInstance
    var engine: ScriptEngineState
    var bodies: [SpaceBody] {
      state.beacons.enumerated().map { index, beacon in
        state.body(for: beacon, id: 50 + index, pose: flight.pose)
      }
    }
    var meshes: [Int: Mesh] {
      Dictionary(uniqueKeysWithValues: bodies.map { ($0.id, NativePracticeSource.mesh()) })
    }
    mutating func origin() throws -> AttackOrigin {
      let emission = flight.allocateEmission()
      return .init(
        emissionID: try #require(emission),
        owner: try #require(flight.player), emittedAt: flight.physicalTime,
        ownerLegalAtEmission: .init())
    }
    func shoot(_ origin: AttackOrigin, ordinal: Int = 1) throws -> NativePracticeHitReceipt {
      try NativePracticeHitPolicy.laser(
        state: state, pose: flight.pose, bodies: bodies, meshes: meshes, celestials: [],
        direction: NativePracticeSource.offsets[ordinal].unit, range: 6000,
        origin: origin, time: flight.physicalTime, nextEmission: flight.nextEmission)
    }
  }

  private func fixture(_ lesson: NativePracticeLesson = .gunnery) throws -> Fixture {
    let mission = ScriptIdentity.uuid("practice-unit-mission")
    var flight = FlightSimulationState()
    flight.enter(.init(galaxy: 0, system: 7), arriving: false)
    flight.pose.position = .init(20000, 0, 0)
    flight.physicalTime = 10
    func context(_ revision: UInt64) -> ScriptEventContext {
      .init(
        galaxy: 0, system: 7, docked: true, mainStation: true, revision: revision,
        frameSeconds: 0, localSeconds: 0, flightSeconds: 0, calendarSeconds: 0,
        transitSeconds: 0, playerPosition: nil)
    }
    let consent = ScriptChoiceReceipt(
      instance: mission, group: NativePracticeSource.consentGroup,
      choice: NativePracticeSource.consentChoice, label: "Begin uncrewed practice",
      dialogue: "practice-review", sequence: 1, revision: 1,
      cause: context(0), committed: context(1))
    var instance = ScriptInstance(
      id: mission, definition: lesson.rawValue, version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.revision = 1
    instance.acknowledge(1)
    instance.choiceReceipts[NativePracticeSource.consentGroup] = consent
    let permission = NativePracticePermission(
      mission: mission, owner: ScriptIdentity.uuid("practice-unit-owner"),
      carrier: ScriptIdentity.uuid("practice-unit-carrier"), lesson: lesson,
      digest: instance.digest, consent: consent, player: try #require(flight.player),
      frame: flight.pose, begunAt: flight.physicalTime)
    let state = try NativePracticeState.prepare(permission: permission, flight: &flight)
    instance.savedNativePractice = state
    var engine = ScriptEngineState()
    engine.nextEvent = 1
    engine.instances[mission] = instance
    return .init(flight: flight, state: state, instance: instance, engine: engine)
  }

  private func replacing<T: Codable>(_ value: T, key: String, with replacement: Any) throws -> T {
    var raw = try object(value)
    raw[key] = replacement
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: raw))
  }
  private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
  }
  private func archive(_ instance: ScriptInstance) throws -> Data {
    try JSONSerialization.data(withJSONObject: [
      "instances": [instance.id.uuidString: object(instance)]
    ])
  }

  @Test func plainCommanderLoadRefusesPracticeWithoutChangingTheExistingCommanderOrScene() throws {
    let f = try fixture()
    var legacy = Commander()
    #expect(legacy.equipmentOwnerID == nil)
    #expect(NativePracticeSave.validateClaims(legacy))
    legacy.scriptState = f.engine
    legacy.flightSimulation = f.flight
    #expect(!NativePracticeSave.validateClaims(legacy))
    var game = Game(executive: false)
    let before = game.commander
    let beforeBodies = game.bodies
    let revision = game.gameplayRevision
    var supplied = before
    try supplied.prepareEquipment()
    let owner = try #require(supplied.equipmentOwnerID)
    let ownerPermission = try replacing(
      f.state.permission, key: "owner", with: owner.uuidString)
    let permission = try replacing(
      ownerPermission, key: "carrier", with: try #require(supplied.hullInstanceID).uuidString)
    let practice = NativePracticeState(permission: permission, beacons: f.state.beacons)
    var instance = f.instance
    instance.savedNativePractice = practice
    supplied.scriptState = f.engine
    supplied.scriptState.instances[instance.id] = instance
    supplied.flightSimulation = f.flight
    #expect(supplied.valid && NativePracticeSave.validateClaims(supplied))
    let loaded = game.load(supplied)
    #expect(!loaded)
    #expect(game.commander == before && game.bodies == beforeBodies)
    #expect(game.gameplayRevision == revision)
  }

  @Test func wholePracticeVolumeRequiresActualGeometryAndRefusesTrafficPlanetAndUnknownScene()
    throws
  {
    let f = try fixture()
    let player = crimeTestActor(0, position: f.flight.pose.position, role: nil)
    let clear = crimeTestContext(10, player: player)
    #expect(
      NativePracticeAdmission.volumeClear(
        f.state, context: clear, bodies: [], meshes: [:], pose: f.flight.pose, playerRadius: 80))
    let actor = crimeTestActor(
      20, position: f.state.permission.volume.position, role: nil, hull: .cargo)
    var body = SpaceBody(id: 90, hull: .cargo, position: f.flight.pose.shipPoint(actor.position))
    body.physical = .init(identity: actor.identity, population: .cargo)
    let traffic = crimeTestContext(10, player: player, actors: [actor])
    #expect(
      !NativePracticeAdmission.volumeClear(
        f.state, context: traffic, bodies: [body], meshes: [90: NativePracticeSource.mesh()],
        pose: f.flight.pose, playerRadius: 80))
    #expect(
      !NativePracticeAdmission.volumeClear(
        f.state, context: traffic, bodies: [], meshes: [:], pose: f.flight.pose, playerRadius: 80))
    #expect(
      !NativePracticeAdmission.volumeClear(
        f.state, context: clear, bodies: [body], meshes: [:], pose: f.flight.pose, playerRadius: 80)
    )
    let remote = crimeTestActor(
      20, position: actor.position + Vector3(2000, 0, 0), role: nil, hull: .cargo)
    body.position.x += 2000
    let original = NativePracticeSource.mesh()
    let appendage = Mesh(
      vertices: original.vertices.map { $0 - Vector3(2000, 0, 0) }, faces: original.faces)
    #expect(
      !NativePracticeAdmission.volumeClear(
        f.state, context: crimeTestContext(10, player: player, actors: [remote]),
        bodies: [body], meshes: [90: appendage], pose: f.flight.pose, playerRadius: 80))
    let nearPlanet = try replacing(
      f.state.permission, key: "frame",
      with: object(ShipPose(position: clear.anchors.planet.position - Vector3(0, 0, 1800))))
    let unsafe = NativePracticeState(permission: nearPlanet, beacons: f.state.beacons)
    #expect(
      !NativePracticeAdmission.volumeClear(
        unsafe, context: clear, bodies: [], meshes: [:], pose: f.flight.pose, playerRadius: 80))
  }

  @Test
  func ordinaryTrafficStillRecordsActualLawAndDeathSettlementWhilePracticePolicyCannotMutateThem()
    throws
  {
    var f = try fixture()
    let player = crimeTestActor(0, position: f.flight.pose.position, role: nil)
    let trader = crimeTestActor(20, position: .init(21000, 0, 0))
    var body = SpaceBody(id: 90, hull: .cobra, position: .init(1000, 0, 0))
    body.physical = .init(identity: trader.identity, population: .civilian, npc: trader.npc)
    #expect(!f.state.reserves(body))
    var law = CrimeLedger()
    let hit = law.record(
      crimeTestIncident(1, time: 10, owner: player, victim: trader),
      context: crimeTestContext(10, player: player, actors: [trader]))
    #expect(hit.accepted && hit.unlawful && hit.legalPenalty > 0)
    let wanted = crimeTestActor(
      21, position: .init(21000, 0, 0), role: .pirate, legal: .init(value: 64, bountyTenths: 500))
    let death = law.record(
      crimeTestIncident(
        2, time: 10, owner: player, victim: wanted,
        outcome: .destruction, emissionID: 11),
      context: crimeTestContext(10, player: player, actors: [wanted]))
    #expect(death.accepted && death.death?.bountyTenths == 500)
    let before = law
    let origin = try f.origin()
    let practiceHit = try f.shoot(origin)
    try f.state.record(practiceHit)
    #expect(law == before)
    #expect(f.state.hits.count == 1 && f.bodies.allSatisfy { $0.physical?.npc == nil })
  }

  @Test(arguments: [false, true])
  func mixedC08ArchivesKeepClosedLowerFeatureValidationAndHighestRequiredFormat(alien: Bool) throws
  {
    let f = try fixture()
    let original = try InductionSeedFixture()
    var commander = try original.commander()
    try original.restoreOriginalParentSaveClaims(&commander)
    try original.restoreOriginalNetworkChildren(&commander)
    #expect(NativeInductionCrewLogSave.validateClaims(commander))
    var instances = commander.scriptState.instances
    instances[f.instance.id] = f.instance
    let engine = ScriptEngineState()
    var raw = try object(engine)
    raw["instances"] = try Dictionary(
      uniqueKeysWithValues: instances.values.map {
        ($0.id.uuidString, try object($0))
      })
    let schema = alien ? 122 : 121
    let bytes = try JSONSerialization.data(withJSONObject: raw)
    try NativePracticeSave.validateArchiveFields(
      bytes, part: .missions, schema: schema, alien: alien)
    #expect(
      NativePracticeSave.publicationVersion(practice: true, crewLog: false, alien: alien) == schema)
    #expect(
      NativePracticeSave.publicationVersion(practice: true, crewLog: true, alien: alien)
        == max(
          schema,
          alien ? NativeInductionCrewLogSave.alienVersion : NativeInductionCrewLogSave.version))
    #expect(
      NativePracticeSave.publicationVersion(practice: false, crewLog: true, alien: alien) == nil)
    for future in [123, 124, 125, 126] {
      try NativePracticeSave.validateFields(
        try archive(f.instance), part: .missions, schema: future)
    }
    // A higher practice envelope must not hide corrupt lower native authority.
    var corrupt = try object(f.instance)
    corrupt["savedNativeInductionSeed"] = ["inventedSeedAuthority": true]
    let badSeed = try JSONSerialization.data(withJSONObject: ["instances": ["own": corrupt]])
    #expect(throws: (any Error).self) {
      try NativePracticeSave.validateArchiveFields(
        badSeed, part: .missions, schema: schema, alien: alien)
    }
  }

  @Test func authoredCubesUseExactMetresFrozenFrameAndThreeFiniteUncrewedAllocations() throws {
    let f = try fixture()
    #expect(f.state.valid && f.flight.nextActor == 5 && f.flight.nextSpawn == 2)
    #expect(f.state.permission.volume.position == .init(20000, 0, 1800))
    #expect(f.state.permission.volume.radius == 650)
    let mesh = NativePracticeSource.mesh()
    #expect(mesh.vertices.count == 8 && mesh.faces.count == 6)
    #expect(mesh.vertices.allSatisfy { abs($0.x) == 3 && abs($0.y) == 3 && abs($0.z) == 3 })
    for (index, body) in f.bodies.enumerated() {
      #expect(body.position == NativePracticeSource.offsets[index])
      #expect(body.physical?.npc == nil && body.physical?.payload == nil)
      #expect(body.scriptNPC == nil && !body.hostile && body.missiles == 0 && !body.ecmEnabled)
      #expect(body.physical?.velocity == .init(0, 0, 0))
      #expect(body.physical?.angularVelocity == .init(0, 0, 0) && body.rotationRate == 0)
      #expect(f.state.beacon(for: body, pose: f.flight.pose) == f.state.beacons[index])
    }
  }

  @Test func foreignVisitOrChangedFrozenPoseRefusesBeforeAllocatingAnyOriginal() throws {
    let f = try fixture()
    var flight = f.flight
    flight.enter(.init(galaxy: 0, system: 7), arriving: false)
    let before = flight
    #expect(throws: NativePracticeError.staleContext) {
      try NativePracticeState.prepare(permission: f.state.permission, flight: &flight)
    }
    #expect(flight == before)
    flight = f.flight
    flight.pose.position.x += 1
    let moved = flight
    #expect(throws: NativePracticeError.staleContext) {
      try NativePracticeState.prepare(permission: f.state.permission, flight: &flight)
    }
    #expect(flight == moved)
  }

  @Test func realNearestCubeIntersectionsYieldThreeDistinctReceiptsWithoutDamageOrOrdinaryFacts()
    throws
  {
    var f = try fixture()
    let bodies = f.bodies
    for ordinal in 0..<3 {
      let origin = try f.origin()
      let receipt = try f.shoot(origin, ordinal: ordinal)
      try f.state.record(receipt)
      #expect(receipt.target == f.state.beacons[ordinal].identity)
      #expect(receipt.actor == f.state.beacons[ordinal].actor && receipt.origin == origin)
      #expect(receipt.kind == .laser && receipt.valid(in: f.state))
    }
    #expect(f.state.hits.count == 3 && f.state.valid)
    #expect(f.bodies == bodies)
    #expect(f.bodies.allSatisfy { $0.energy == 100 && $0.physical?.deathOrigin == nil })
    #expect(
      f.bodies.allSatisfy { $0.physical?.deathIncidentID == nil && $0.destroyedByPlayer == nil })
    #expect(f.instance.outcome == .active && f.instance.milestones.isEmpty)
    #expect(f.instance.completionReceipt == nil && f.instance.payloads.isEmpty)
  }

  @Test func duplicateTargetOrEmissionCannotCreateAnotherFirstHitIncludingAfterColdRestore() throws
  {
    var f = try fixture()
    let origin = try f.origin()
    let receipt = try f.shoot(origin)
    try f.state.record(receipt)
    let recorded = f.state
    #expect(throws: NativePracticeError.duplicateHit) { try f.state.record(receipt) }
    #expect(throws: NativePracticeError.duplicateHit) { try f.shoot(origin, ordinal: 0) }
    let another = try f.origin()
    #expect(throws: NativePracticeError.duplicateHit) { try f.shoot(another) }
    f.state = try JSONDecoder().decode(
      NativePracticeState.self, from: JSONEncoder().encode(f.state))
    #expect(f.state == recorded)
    #expect(throws: NativePracticeError.duplicateHit) { try f.shoot(another) }
    #expect(f.bodies[1].physical?.identity == receipt.actor)
  }

  @Test func ordinaryOcclusionMissesAndTargetDisappearanceCannotBecomePracticeHits() throws {
    var f = try fixture()
    let origin = try f.origin()
    var bodies = f.bodies
    let traffic = SpaceBody(id: 99, hull: .cargo, position: .init(0, 0, 900))
    bodies.append(traffic)
    var meshes = f.meshes
    meshes[99] = NativePracticeSource.mesh()
    #expect(throws: (any Error).self) {
      try NativePracticeHitPolicy.laser(
        state: f.state, pose: f.flight.pose, bodies: bodies, meshes: meshes,
        celestials: [], direction: .init(0, 0, 1), range: 6000,
        origin: origin, time: 10, nextEmission: f.flight.nextEmission)
    }
    for direction in [Vector3(0, 1, 0), Vector3(0, 0, -1)] {
      #expect(throws: (any Error).self) {
        try NativePracticeHitPolicy.laser(
          state: f.state, pose: f.flight.pose, bodies: f.bodies, meshes: f.meshes,
          celestials: [], direction: direction, range: 6000,
          origin: origin, time: 10, nextEmission: f.flight.nextEmission)
      }
    }
    #expect(throws: (any Error).self) {
      try NativePracticeHitPolicy.laser(
        state: f.state, pose: f.flight.pose, bodies: [], meshes: [:],
        celestials: [], direction: .init(0, 0, 1), range: 6000,
        origin: origin, time: 10, nextEmission: f.flight.nextEmission)
    }
    #expect(f.state.hits.isEmpty && !f.state.reserves(traffic))
  }

  @Test func copiedLabelsForeignAllocationsCrewAndOrdinaryGoodsNeverGainHarmlessOrScoopExemption()
    throws
  {
    let f = try fixture()
    let original = f.bodies[1]
    var ordinary = original
    ordinary.hull = .cobra
    #expect(!f.state.reserves(ordinary))
    ordinary = original
    ordinary.physical?.npc = .init(
      role: .trader, origin: .init(galaxy: 0, system: 7), destination: .init(galaxy: 0, system: 7))
    #expect(!f.state.reserves(ordinary))
    ordinary = original
    ordinary.physical?.payload = .mission(instance: UUID(), payload: "goods")
    #expect(!f.state.reserves(ordinary))
    ordinary = SpaceBody(id: original.id, hull: .cargo, position: original.position)
    ordinary.missionActorID = f.state.beacons[1].identity
    ordinary.missionInstanceID = f.state.permission.mission
    #expect(!f.state.reserves(ordinary))
    ordinary.physical = .init(
      identity: .init(system: f.state.permission.player.system, visit: 1, entity: 77),
      population: .cargo)
    #expect(!f.state.reserves(ordinary))
    #expect(f.state.reserves(original))
    ordinary = original
    ordinary.position.z += 1
    #expect(f.state.beacon(for: ordinary, pose: f.flight.pose) == nil)
  }

  @Test func foreignEmitterUnallocatedEmissionAndEndedProviderRefuseAttributedCredit() throws {
    var f = try fixture(.defensiveFlight)
    let origin = try f.origin()
    let foreign = AttackOrigin(
      emissionID: origin.emissionID,
      owner: .init(system: origin.owner.system, visit: origin.owner.visit + 1, entity: 0),
      emittedAt: 10, ownerLegalAtEmission: .init())
    #expect(throws: (any Error).self) { try f.shoot(foreign) }
    let unallocated = AttackOrigin(
      emissionID: f.flight.nextEmission, owner: origin.owner, emittedAt: 10,
      ownerLegalAtEmission: .init())
    #expect(throws: (any Error).self) { try f.shoot(unallocated) }
    f.state.endedAt = 10
    #expect(f.state.valid)
    #expect(throws: (any Error).self) { try f.shoot(origin) }
    #expect(f.state.hits.isEmpty)
  }

  @Test func archivedProjectileReceiptRequiresAllocatedSameVisitPlayerAndSeparateProjectileOrigin()
    throws
  {
    var f = try fixture()
    let laserOrigin = try f.origin()
    let laserReceipt = try f.shoot(laserOrigin)
    let allocatedProjectile = f.flight.allocateActor()
    let projectile = try #require(allocatedProjectile)
    let origin = AttackOrigin(
      emissionID: laserOrigin.emissionID, owner: laserOrigin.owner, ordnance: projectile,
      emittedAt: 10, ownerLegalAtEmission: .init())
    #expect(
      OrdnanceState(
        profile: .standardMissile, origin: origin, target: f.state.beacons[1].actor,
        position: f.flight.pose.position, direction: .init(0, 0, 1))?.valid == true)
    var raw = try object(laserReceipt)
    raw["kind"] = "missile"
    raw["origin"] = try object(origin)
    let stored = try JSONDecoder().decode(
      NativePracticeHitReceipt.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(stored.valid(in: f.state))
    try f.state.record(stored)
    f.instance.savedNativePractice = f.state
    #expect(
      NativePracticeSave.valid(
        f.state, instance: f.instance, engine: f.engine, owner: f.state.permission.owner,
        flight: f.flight))
    let wrongVisit = ActorIdentity(
      system: projectile.system, visit: projectile.visit + 1, entity: projectile.entity)
    for ordnance in [wrongVisit, f.state.beacons[0].actor, laserOrigin.owner] {
      let invalid = AttackOrigin(
        emissionID: origin.emissionID, owner: origin.owner, ordnance: ordnance,
        emittedAt: 10, ownerLegalAtEmission: .init())
      let changed = try replacing(stored, key: "origin", with: object(invalid))
      #expect(!changed.valid(in: f.state))
    }
    let missing = try replacing(stored, key: "origin", with: object(laserOrigin))
    #expect(!missing.valid(in: f.state))
    let proximity = try replacing(
      stored, key: "position", with: object(f.state.permission.position(1)))
    #expect(!proximity.valid(in: f.state))
  }

  @Test(arguments: [false, true])
  func closedPracticeEnvelopeRejectsOldEmbeddedUnknownAndForeignNativeClaims(alien: Bool) throws {
    let f = try fixture()
    let schema = alien ? 122 : 121
    let bytes = try archive(f.instance)
    try NativePracticeSave.validateArchiveFields(
      bytes, part: .missions, schema: schema, alien: alien)
    for old in [nil, 59, 117, 118, 119, 120] as [Int?] {
      #expect(throws: (any Error).self) {
        try NativePracticeSave.validateFields(bytes, part: .missions, schema: old)
      }
    }
    var instance = try object(f.instance)
    var leaf = try object(f.state)
    leaf["inventedHit"] = true
    instance["savedNativePractice"] = leaf
    let unknown = try JSONSerialization.data(withJSONObject: ["instances": ["own": instance]])
    #expect(throws: (any Error).self) {
      try NativePracticeSave.validateFields(unknown, part: .missions, schema: schema)
    }
    instance = try object(f.instance)
    instance["digest"] = String(repeating: "b", count: 64)
    let foreign = try JSONSerialization.data(withJSONObject: ["instances": ["own": instance]])
    #expect(throws: (any Error).self) {
      try NativePracticeSave.validateFields(foreign, part: .missions, schema: schema)
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": ["instances": ["own": object(f.instance)]]
    ])
    #expect(throws: (any Error).self) {
      try NativePracticeSave.validateFields(embedded, part: .commander, schema: schema)
    }
    #expect(
      NativePracticeSave.valid(
        f.state, instance: f.instance, engine: f.engine,
        owner: f.state.permission.owner, flight: f.flight))
    var noConsent = f.instance
    noConsent.choiceReceipts = [:]
    #expect(
      !NativePracticeSave.valid(
        f.state, instance: noConsent, engine: f.engine,
        owner: f.state.permission.owner, flight: f.flight))
  }
}
