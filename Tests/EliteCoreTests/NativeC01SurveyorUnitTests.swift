import Foundation
import Testing

@testable import EliteCore

/// Component records only: these tests never claim an executed Navidor recovery journey.
final class C01SurveyorFixture {
  let state: NativeGlassMeridianState
  let player: ActorIdentity
  let marker: ScriptOwnedActor
  init(commission: NativeGlassMeridianState? = nil) throws {
    let opening = NativeGlassMeridianUnitTests()
    var state = try commission ?? opening.fixture()
    let scanner =
      try state.permission.fit.first { $0.location?.slot == "targeting.core" }
      ?? EquipmentPurchaseItem(
        id: UUID(),
        node: #require(
          EquipmentRuntimeCatalog.node(for: TargetingTier.identification.equipmentName)),
        location: .init(hull: state.permission.carrier, slot: "targeting.core"),
        provenance: .grant("C01 component historical scanner"))
    state.readings = [
      try opening.sealed(state, ordinal: 0, scanEquipment: scanner),
      try opening.sealed(state, ordinal: 1, start: 22, scanEquipment: scanner),
    ]
    var native = FlightSimulationState()
    for _ in 0..<3 { native.enter(NativeC01Surveyor.location, arriving: true) }
    _ = native.allocateSpawn()
    let source = NativeC01SurveyorSource(
      mission: state.permission.mission, permission: state.permission.operation,
      anchors: try #require(native.anchors), reference: .init(), visit: 3, physicalTime: 40)
    state.surveyor = .init(source: source)
    self.state = state
    player = try #require(native.player)
    let alias = NativeC01Surveyor.aliases[1]
    let identity = NativeC01Surveyor.actor(mission: source.mission, alias: alias)
    let profile = NativeC01Surveyor.profile(recorder: true)
    let hashes = try NativeC01Surveyor.modelHashes.get()
    var body = SpaceBody(id: 10, hull: .cobra, position: .init(0, -45, 55), hostile: false)
    body.missionActorID = identity
    body.missionInstanceID = source.mission
    body.energy = profile.energy
    body.missiles = 0
    body.rotationRate = 0
    body.scriptNPC = .init(
      fit: .init(definition: profile, models: [profile.model: try #require(hashes[profile.model])]),
      fuel: 0, guns: [:], components: [:])
    body.physical = .init(
      identity: .init(system: NativeC01Surveyor.location, visit: 3, entity: 40),
      population: .mission,
      npc: .init(
        role: .mission, origin: NativeC01Surveyor.location, destination: NativeC01Surveyor.location)
    )
    body.physical?.spawnIdentity = .init(
      system: NativeC01Surveyor.location, visit: 3, sequence: 1, member: 0, producer: .mission)
    body.physical?.npc?.resources = .legacyEnergyOnly(maximumEnergy: profile.energy)
    marker = .init(identity: identity, alias: alias, body: body, presence: .present)
  }
  func capture(
    speed: Double = 0, collector: ActorIdentity? = nil, scoop: EquipmentPurchaseItem? = nil
  ) throws -> NativeC01SurveyorCapture {
    let item =
      try scoop
      ?? EquipmentPurchaseItem(
        id: UUID(), node: #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops")),
        location: .init(hull: state.permission.carrier, slot: "utility.fuelScoops"),
        provenance: .grant("C01 component fixture"))
    return .init(
      operation: NativeC01Surveyor.captureOperation(permission: state.permission.operation),
      marker: marker, collector: collector ?? player, carrier: state.permission.carrier,
      inventoryRevision: 1, scoop: item, capturePoint: marker.body.position, relativeSpeed: speed,
      startTime: 50, physicalTime: 50.05, epoch: UUID())
  }
  func held() throws -> NativeGlassMeridianState {
    var result = state
    result.surveyor?.capture = try capture()
    return result
  }
  func commander(_ state: NativeGlassMeridianState) throws -> Commander {
    var commander = Commander()
    commander.galaxy = 0
    commander.system = 164
    commander.savedEquipmentInventory = try .init(
      owner: state.permission.owner, activeHull: state.permission.carrier)
    for _ in 0..<3 { commander.flightSimulation.enter(NativeC01Surveyor.location, arriving: true) }
    while commander.flightSimulation.nextActor <= 41 {
      _ = commander.flightSimulation.allocateActor()
    }
    _ = commander.flightSimulation.allocateSpawn()
    commander.flightSimulation.physicalTime = 60
    var mission = self.mission(state)
    var recorder = marker
    if state.surveyor?.capture != nil { recorder.presence = .outside }
    let alias = NativeC01Surveyor.aliases[0]
    let logical = NativeC01Surveyor.actor(mission: mission.id, alias: alias)
    let profile = NativeC01Surveyor.profile(recorder: false)
    var body = marker.body
    body.id = 11
    body.energy = profile.energy
    body.missionActorID = logical
    body.scriptNPC = .init(
      fit: .init(
        definition: profile,
        models: [profile.model: try #require(NativeC01Surveyor.modelHashes.get()[profile.model])]),
      fuel: 0, guns: [:], components: [:])
    body.physical = .init(
      identity: .init(system: NativeC01Surveyor.location, visit: 3, entity: 41),
      population: .mission,
      npc: .init(
        role: .mission, origin: NativeC01Surveyor.location, destination: NativeC01Surveyor.location)
    )
    body.physical?.spawnIdentity = .init(
      system: NativeC01Surveyor.location, visit: 3, sequence: 1, member: 1, producer: .mission)
    body.physical?.npc?.resources = .legacyEnergyOnly(maximumEnergy: profile.energy)
    var group = ScriptOwnedEncounter(
      id: NativeC01Surveyor.encounter, galaxy: 0, system: 164,
      actors: [
        recorder.alias: recorder,
        alias: .init(identity: logical, alias: alias, body: body, presence: .present),
      ])
    group.admitted = true
    mission.ownedEncounters[group.id] = group
    commander.scriptState.instances[mission.id] = mission
    let hashes = try NativeC01Surveyor.modelHashes.get()
    for (reference, design) in try NativeC01Surveyor.models.get() {
      commander.scriptState.geometry[try #require(hashes[reference])] = design
    }
    return commander
  }
  func physicsGame(velocity: Vector3 = .init(0, 0, 0)) throws -> Game {
    var game = Game(executive: false)
    game.commander = try commander(state)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)]
    game.screen = .front
    game.docked = false
    game.speed = 0
    game.messageTime = 10
    let source = try #require(state.surveyor?.source)
    // Observe the authored source nearby. The arrival pose is far enough away
    // for the normal culler to remove both actors before this unit's assertions.
    game.commander.flightSimulation.pose = .init(
      position: source.position + .init(0, 0, -1000), orientation: source.reference.orientation)
    var mission = try #require(game.commander.scriptState.instances[source.mission])
    for (index, alias) in NativeC01Surveyor.aliases.enumerated() {
      var actor = try #require(mission.ownedEncounters[NativeC01Surveyor.encounter]?.actors[alias])
      let point = source.position + Vector3(index == 0 ? 0 : 80, 0, 0)
      actor.body.position = source.reference.shipPoint(point)
      actor.body.physical?.velocity = velocity
      mission.ownedEncounters[NativeC01Surveyor.encounter]?.actors[alias] = actor
      var body = actor.body
      body.position = game.commander.flightSimulation.pose.shipPoint(point)
      game.bodies.append(body)
    }
    game.nextBodyID = 12
    game.commander.scriptState.instances[mission.id] = mission
    return game
  }
  func mission(_ state: NativeGlassMeridianState) -> ScriptInstance {
    var mission = ScriptInstance(
      id: state.permission.mission, definition: NativeGlassMeridian.stateID,
      version: NativeGlassMeridian.version, digest: NativeGlassMeridian.digest)
    mission.savedGlassMeridian = state
    mission.milestones = state.surveyor?.capture == nil ? [0, 1] : [0, 1, 2]
    return mission
  }
}

struct NativeC01SurveyorUnitTests {
  @Test func harrierKeepsEveryVisualFaceAt65MetresAndUsesClosedConservativeCollision() throws {
    let geometry = try NativeC01SurveyorGeometry.harrier.get()
    let original = try #require(ShipCatalogue.ship("SH056"))
    #expect(original.name == "Harrier" && ShipCatalogue.ship("SH026")?.name == "Constrictor")
    #expect(geometry.design.faces == original.design.faces)
    #expect(geometry.design.vertices.count == original.design.vertices.count)
    #expect(
      abs(try OriginalHullEnvelope(vertices: geometry.design.rawMesh.vertices).dimensions.z - 65)
        < 1e-9)
    #expect(try PreparedHull(mesh: geometry.collision).isClosed)
    #expect(geometry.collision.faces.allSatisfy { $0.count == 3 })
    #expect(NativeC01Surveyor.profile(recorder: false).energy == 64)
    #expect(NativeC01Surveyor.profile(recorder: false).speed == 0)
    #expect(NativeC01Surveyor.profile(recorder: false).drive == nil)
    let radius = NativeC01SurveyorGeometry.recorder.rawMesh.vertices.map(\.length).max()!
    #expect(
      NativeC01Surveyor.pairSeparated(harrier: .init(), recorder: .init(80, 0, 0), radius: radius))
    #expect(
      !NativeC01Surveyor.pairSeparated(harrier: .init(), recorder: .init(0, 0, 0), radius: radius))
    #expect(
      !NativeC01Surveyor.pairSeparated(
        harrier: .init(), recorder: .init(.nan, 0, 0), radius: radius))
    let f = try C01SurveyorFixture()
    var game = Game(executive: false)
    game.commander = try f.commander(f.state)
    let mission = try #require(game.commander.scriptState.instances[f.state.permission.mission])
    let group = try #require(mission.ownedEncounters[NativeC01Surveyor.encounter])
    game.bodies = group.actors.values.map(\.body)
    let harrier = try #require(group.actors[NativeC01Surveyor.aliases[0]])
    let recorder = try #require(group.actors[NativeC01Surveyor.aliases[1]])
    #expect(game.c01SurveyorCollision(harrier.body)?.mass == 18_000)
    #expect(game.c01SurveyorCollision(recorder.body)?.mass == 8)
    #expect(game.c01SurveyorCollision(harrier.body)?.mesh.faces == geometry.collision.faces)
    var foreign = harrier.body
    foreign.missionActorID = UUID()
    #expect(game.c01SurveyorCollision(foreign) == nil)
    var drifting = harrier.body
    drifting.physical?.velocity = .init(3, 0, 0)
    if let index = game.bodies.firstIndex(where: { $0.id == drifting.id }) {
      game.bodies[index] = drifting
    }
    game.commander.scriptState.instances[mission.id]?.ownedEncounters[NativeC01Surveyor.encounter]?
      .actors[harrier.alias]?.body.physical?.velocity = .init(3, 0, 0)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)]
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.encounterID == NativeC01Surveyor.encounter })
    let ids = Dictionary(
      uniqueKeysWithValues: game.bodies.compactMap { body in
        body.missionActorID.map { ($0, body.id) }
      })
    #expect(throws: (any Error).self) { try source.prepareRetentionPatch(sceneBodyIDs: ids) }
    let patch = try source.prepareRetentionPatch(sceneBodyIDs: ids, nativeBodies: game.bodies)
    #expect(patch.updatedEncounter.actors[recorder.alias]?.body.physical == recorder.body.physical)
    #expect(patch.updatedEncounter.actors[harrier.alias]?.body.physical == drifting.physical)
  }
  @Test func unchangedOriginalContactFrameCompletesWithTheSameClosedC01Geometry() throws {
    let f = try C01SurveyorFixture()
    var game = try f.physicsGame()
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let captured = game.beginAsteroidContactStep(delta: 0.1)
    let frame = try #require(captured)
    let before = game.bodies
    let completed = game.completeAsteroidContactStep(frame, delta: 0.1)
    #expect(completed.admitted && !game.paused && game.bodies == before)
    var changed = try f.physicsGame()
    changed.commander.flightSimulation.advancePhysicalTime(0.1)
    let secondCapture = changed.beginAsteroidContactStep(delta: 0.1)
    let second = try #require(secondCapture)
    changed.bodies[0].id += 100
    let refused = changed.completeAsteroidContactStep(second, delta: 0.1)
    #expect(!refused.admitted)
    var remeshed = try f.physicsGame()
    remeshed.commander.flightSimulation.advancePhysicalTime(0.1)
    let thirdCapture = remeshed.beginAsteroidContactStep(delta: 0.1)
    let third = try #require(thirdCapture)
    remeshed.bodies[0].hull = .viper
    let wrongGeometry = remeshed.completeAsteroidContactStep(third, delta: 0.1)
    #expect(!wrongGeometry.admitted)
  }

  @Test(arguments: [false, true])
  func passiveOriginalInertiaMovesOnceInsideManualAndWorkSweeps(work: Bool) throws {
    let f = try C01SurveyorFixture()
    let drift = Vector3(3, -1, 2)
    var game = try f.physicsGame(velocity: drift)
    let original = Dictionary(
      uniqueKeysWithValues: game.bodies.map { ($0.id, game.modelPose(of: $0).position) })
    if work {
      game.workBraking = .init(velocity: .init(100, 0, 0), angularVelocity: .init(0, 0, 0))
    }
    try #require(game.bodies.count == 2)
    for body in game.bodies { try #require(body.position.length < 1200) }
    let before = game.commander.flightSimulation.physicalTime
    game.tick(delta: 0.1)
    #expect(!game.paused && game.screen == .front)
    #expect(abs(game.commander.flightSimulation.physicalTime - before - 0.1) < 1e-9)
    if work { #expect(game.workBraking != nil) }
    for body in game.bodies where body.missionInstanceID == f.state.permission.mission {
      let start = try #require(original[body.id])
      let end = game.modelPose(of: body).position
      #expect((end - start - drift * 0.1).length < 1e-8)
      #expect(body.physical?.velocity == drift)
      #expect(body.scriptNPC?.velocity == .init(0, 0, 0))
    }
    #expect(game.bodies.filter { $0.missionInstanceID == f.state.permission.mission }.count == 2)
    // A fast original recorder crosses the Harrier within one step although both endpoints are clear.
    // The Harrier is encountered first in the cohort, so this also exercises C01 as the NPC target.
    var crossing = try f.physicsGame()
    if work {
      crossing.workBraking = .init(velocity: .init(100, 0, 0), angularVelocity: .init(0, 0, 0))
    }
    let moving = try #require(crossing.bodies.firstIndex { $0.missionActorID == f.marker.identity })
    crossing.bodies[moving].physical?.velocity = .init(-2000, 0, 0)
    let oldKills = crossing.commander.kills
    let oldCredits = crossing.commander.credits
    crossing.tick(delta: 0.1)
    let retained = try #require(
      crossing.commander.scriptState.instances[f.state.permission.mission]?
        .ownedEncounters[NativeC01Surveyor.encounter])
    let terminal = retained.actors.values.contains {
      $0.presence == .destroyed && $0.body.energy == 0
    }
    if !crossing.paused && !terminal {
      let recorder = try #require(crossing.bodies.first { $0.missionActorID == f.marker.identity })
      let harrierID = NativeC01Surveyor.actor(
        mission: f.state.permission.mission, alias: NativeC01Surveyor.aliases[0])
      let harrier = try #require(crossing.bodies.first { $0.missionActorID == harrierID })
      let left = try #require(
        NativeC01SurveyorGeometry.harrier.get().collision.vertices.map(\.x).min())
      let recorderEnd = crossing.modelPose(of: recorder).position
      let harrierEnd = crossing.modelPose(of: harrier).position
      #expect(recorderEnd.x >= harrierEnd.x + left - 1e-5)
    }
    #expect(!crossing.message.contains("MISSION INERTIA AUTHORITY UNAVAILABLE"))
    #expect(crossing.commander.kills == oldKills && crossing.commander.credits == oldCredits)
  }

  @Test func convexEnvelopeRejectsNonfiniteFlatAndDegenerateGeometry() throws {
    for points in [
      [Vector3(0, 0, 0), .init(1, 0, 0), .init(0, 1, 0), .init(1, 1, 0)],
      Array(repeating: Vector3(0, 0, 0), count: 4),
      [Vector3(.nan, 0, 0), .init(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)],
    ] {
      #expect(throws: (any Error).self) { try NativeC01SurveyorGeometry.convexEnvelope(points) }
    }
    let valid = try NativeC01SurveyorGeometry.convexEnvelope([
      .init(0, 0, 0), .init(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1), .init(0.1, 0.1, 0.1),
    ])
    #expect(try PreparedHull(mesh: valid).isClosed)
    #expect(valid.vertices.count == 4)
  }
  @Test
  func originalSourceUsesActualPlanetStarFrameAndDetached80MetreRecorderWithoutGrantingCustody()
    throws
  {
    let f = try C01SurveyorFixture()
    let source = try #require(f.state.surveyor?.source)
    #expect(source.valid && NativeC01Surveyor.shapeValid(f.state))
    #expect(
      abs(
        (source.position - source.anchors.planet.position).length - source.anchors.planet.radius
          - 25_000) < 1e-8)
    #expect(
      (source.position - source.anchors.planet.position).unit.dot(
        (source.anchors.sun.position - source.anchors.planet.position).unit) > 0.999999)
    let definition = try #require(
      NativeC01Surveyor.definition(f.mission(f.state), id: NativeC01Surveyor.encounter))
    let a = definition.actors[0]
    let b = definition.actors[1]
    #expect(Vector3(b.x - a.x, b.y - a.y, b.z - a.z) == .init(80, 0, 0))
    #expect(f.state.surveyor?.capture == nil && f.state.surveyor?.held == false)
    #expect(f.mission(f.state).payloads.isEmpty)
  }
  @Test func captureRequiresOriginalNativeRecorderFittedScoopsAndMeasuredSafeIngress() throws {
    let f = try C01SurveyorFixture()
    let held = try f.held()
    #expect(NativeC01Surveyor.shapeValid(held))
    var wrong = held
    wrong.surveyor?.capture = try f.capture(speed: ScoopApproachController.maximumRelativeSpeed + 1)
    #expect(!NativeC01Surveyor.shapeValid(wrong))
    wrong = held
    wrong.surveyor?.capture = try f.capture(
      collector: .init(system: .init(galaxy: 0, system: 7), visit: 3, entity: 0))
    #expect(!NativeC01Surveyor.shapeValid(wrong))
    let node = try #require(EquipmentRuntimeCatalog.node(for: "Escape Pod"))
    wrong.surveyor?.capture = try f.capture(
      scoop: .init(id: UUID(), node: node, provenance: .grant("wrong tool")))
    #expect(!NativeC01Surveyor.shapeValid(wrong))
    #expect(!NativeC01Surveyor.approachAllowed(point: .init(40, -45, 55), radius: 0.5, speed: 0))
  }
  @Test func heldRecorderProjectionKeepsAbsentFalseTrueAndRetainedCodecValuesIndependent() throws {
    let f = try C01SurveyorFixture()
    let absent = ScriptInstance(
      id: UUID(), definition: "test.projection", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    var withoutRecorder = f.state
    withoutRecorder.surveyor = nil
    let held = f.mission(try f.held())
    let samples: [(ScriptInstance, Bool)] = [
      (absent, false), (f.mission(withoutRecorder), false), (f.mission(f.state), false),
      (held, true),
    ]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for (instance, expected) in samples {
      let retained = instance
      let bytes = try encoder.encode(instance)
      #expect(instance.hasHeldGlassMeridianRecorder == expected)
      #expect(instance == retained)
      #expect(try encoder.encode(instance) == bytes)
      let decoded = try JSONDecoder().decode(ScriptInstance.self, from: bytes)
      #expect(decoded.hasHeldGlassMeridianRecorder == expected && decoded == retained)
    }
    var changed = held
    changed.savedGlassMeridian?.surveyor = nil
    #expect(!changed.hasHeldGlassMeridianRecorder && held.hasHeldGlassMeridianRecorder)
  }

  @Test func protectedRecorderUsesEightKilogramsAndNoFabricatedMissionTonne() throws {
    let f = try C01SurveyorFixture()
    var commander = Commander()
    commander.scriptState.instances[f.state.permission.mission] = f.mission(f.state)
    let before = commander.checkedCargoTonnes
    let held = try f.held()
    commander.scriptState.instances[f.state.permission.mission] = f.mission(held)
    #expect(commander.checkedCargoTonnes == before.map { $0 + 1 })
    #expect(commander.scriptState.instances[f.state.permission.mission]?.payloads.isEmpty == true)
    let dimensions = try OriginalHullEnvelope(
      vertices: NativeC01SurveyorGeometry.recorder.rawMesh.vertices
    ).dimensions
    #expect(dimensions == .init(0.8, 0.5, 0.3))
  }
  @Test func recorderDestructionIsTerminalAndHarrierLossAfterSeparationDoesNotDuplicateRecorder()
    throws
  {
    let f = try C01SurveyorFixture()
    var failed = f.state
    var dead = f.marker
    dead.body.energy = 0
    dead.presence = .destroyed
    failed.surveyor?.loss = .init(
      kind: .recorderDestroyed, marker: dead,
      collector: f.player, carrier: f.state.permission.carrier, energy: 100, escapePod: nil,
      physicalTime: 51)
    #expect(NativeC01Surveyor.shapeValid(failed) && failed.surveyor?.held == false)
    failed.surveyor?.capture = try f.capture()
    #expect(!NativeC01Surveyor.shapeValid(failed))
    let held = try f.held()
    var commander = Commander()
    commander.scriptState.instances[held.permission.mission] = f.mission(held)
    #expect(NativeC01Surveyor.consumed(f.marker.identity, commander: commander))
    #expect(
      !NativeC01Surveyor.consumed(
        NativeC01Surveyor.actor(
          mission: held.permission.mission, alias: NativeC01Surveyor.aliases[0]),
        commander: commander))
    #expect(held.surveyor?.capture?.marker.identity == f.marker.identity)
  }
  @Test func currentRecorderFormatsRejectEarlierEmbeddedUnknownAndExtraClaims() throws {
    let f = try C01SurveyorFixture()
    let held = try f.held()
    let mission = f.mission(held)
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(mission))
    let bytes = try JSONSerialization.data(withJSONObject: [
      "instances": [mission.id.uuidString: object]
    ])
    for schema in [129, 130] {
      try NativeC01SurveyorSave.validateFields(bytes, part: .missions, schema: schema)
      try ScriptSaveJSONPreflight.validateRepairLoopFields(bytes, part: .missions, schema: schema)
    }
    for schema in [63, 64, 115, 116, Int.max] {
      #expect(throws: (any Error).self) {
        try NativeC01SurveyorSave.validateFields(bytes, part: .missions, schema: schema)
      }
    }
    #expect(throws: (any Error).self) {
      try NativeGlassMeridianSave.validateFields(bytes, part: .missions, schema: 63)
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": ["instances": [mission.id.uuidString: object]]
    ])
    #expect(throws: (any Error).self) {
      try NativeC01SurveyorSave.validateFields(embedded, part: .commander, schema: 129)
    }
    var leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(held)) as? [String: Any])
    var source = try #require(leaf["surveyor"] as? [String: Any])
    source["inventedCompletion"] = true
    leaf["surveyor"] = source
    let bad = try JSONSerialization.data(withJSONObject: [
      "instances": [
        mission.id.uuidString: [
          "definition": NativeGlassMeridian.stateID, "digest": NativeGlassMeridian.digest,
          "savedGlassMeridian": leaf,
        ]
      ]
    ])
    #expect(throws: (any Error).self) {
      try NativeC01SurveyorSave.validateFields(bad, part: .missions, schema: 129)
    }
  }
  @Test func stageThreeRetainsBothReadingsAndHasNoStageFourRewardClueOrTerminalReceipt() throws {
    let f = try C01SurveyorFixture()
    let held = try f.held()
    let mission = f.mission(held)
    #expect(held.readings == f.state.readings && NativeGlassMeridian.readingsValid(held))
    #expect(mission.milestones == [0, 1, 2] && mission.outcome == .active)
    #expect(mission.completionReceipt == nil && mission.payloads.isEmpty)
    let commander = try f.commander(held)
    var joined = try #require(commander.scriptState.instances[mission.id])
    #expect(NativeC01SurveyorSave.valid(joined, commander: commander))
    joined.ownedEncounters[NativeC01Surveyor.encounter]?.actors[NativeC01Surveyor.aliases[1]] = nil
    #expect(!NativeC01SurveyorSave.valid(joined, commander: commander))
    #expect(
      try JSONDecoder().decode(NativeGlassMeridianState.self, from: JSONEncoder().encode(held))
        == held)
    #expect(
      try JSONDecoder().decode(
        NativeGlassMeridianState.self,
        from: JSONEncoder().encode(NativeGlassMeridianUnitTests().fixture())
      ).surveyor == nil)
    var premature = f.state
    premature.readings.removeLast()
    #expect(!NativeC01Surveyor.shapeValid(premature))
  }
}
