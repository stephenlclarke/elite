import Foundation
import Testing

@testable import EliteCore

/// Structural source/native-address fixtures only; no test here executes native admission or flight.
final class CrewLogProducerFixture {
  let originalSale: NativeFirstCommoditySale
  let parent: NativeWayfarerInductionState
  let source: NativeInductionCrewLogSource
  let authorization: NativeCrewLogAuthorization
  init() throws {
    let f = try ArkReceivingFixture()
    originalSale = f.f.originalSale
    parent = try f.f.parent.registeringArk(f.f.link).receivingSeedArk(f.receipt())
    source = try .init(parent: parent)
    authorization = try .init(
      parent: parent,
      stationActor: .init(system: NativeInductionCrewLogSource.location, visit: 30, entity: 1),
      physicalTime: 20_000, flightSeconds: 10_000, sequence: 100)
  }
  func child(_ state: NativeInductionCrewLogState? = nil) -> ScriptInstance {
    var child = ScriptInstance(
      id: authorization.job, definition: NativeInductionCrewLogPack.stateID,
      version: NativeInductionCrewLogPack.version, digest: NativeInductionCrewLogPack.digest)
    child.savedNativeCrewLog = state ?? .init(authorization: authorization)
    child.acknowledge(authorization.sequence)
    return child
  }
  func prepared(_ role: NativeInductionCrewLogRole) throws -> ScriptOwnedActor {
    let profile = role == .recorder ? source.recorder : source.ship
    let hash = ScriptPackLibrary.hash(
      try ScriptPackLibrary.canonicalGeometry(source.models[profile.model]!))
    let logical = NativeInductionCrewLogPack.actor(job: authorization.job, role: role)
    let components: [String: ScriptNPCComponentState] = Dictionary(
      uniqueKeysWithValues: (profile.components ?? []).map { spec in
        (
          spec.id,
          .init(
            identity: ScriptIdentity.uuid("script-component-v2:\(logical):\(spec.id)"),
            energy: spec.energy, guns: [:])
        )
      })
    var body = SpaceBody(id: -1, hull: .cobra, position: role.offset, hostile: false)
    body.energy = profile.energy
    body.missiles = profile.missiles
    body.missionInstanceID = authorization.job
    body.missionActorID = logical
    body.scriptNPC = .init(
      fit: .init(definition: profile, models: [profile.model: hash]), fuel: profile.fuel, guns: [:],
      components: components)
    try NativeInductionCrewLogPack.initialBody(&body, state: child(), alias: role.rawValue)
    return .init(identity: logical, alias: role.rawValue, body: body, presence: .prepared)
  }
  var admission: NativeCrewLogAdmission {
    .init(
      tender: .init(system: NativeInductionCrewLogSource.location, visit: 30, entity: 2),
      launch: .init(system: NativeInductionCrewLogSource.location, visit: 30, entity: 3),
      recorder: .init(system: NativeInductionCrewLogSource.location, visit: 30, entity: 4),
      physicalTime: 20_001)
  }
}

struct NativeWayfarerInductionCrewLogProducerUnitTests {
  @Test func sourceGraphNeedsTheSameParentOwnerAcknowledgedIssueAndRetainedMainStation() throws {
    let f = try CrewLogProducerFixture()
    var commander = Commander()
    commander.savedEquipmentInventory = try .init(
      owner: f.source.manifest.owner, activeHull: UUID())
    for _ in 0..<30 {
      commander.flightSimulation.enter(NativeInductionCrewLogSource.location, arriving: true)
    }
    commander.flightSimulation.physicalTime = 20_000
    commander.scriptState.flightSeconds = 10_000
    commander.scriptState.nextEvent = 100
    commander.nativeStations = try .init(owner: f.source.manifest.owner)
    commander.nativeStations?.mainStations = [
      NativeWayfarerInductionUnitTests().dock(
        owner: f.source.manifest.owner, system: 211, visit: 30, sequence: 30
      ).station
    ]
    var parent = ScriptInstance(
      id: f.parent.permission.mission, definition: NativeWayfarerInduction.stateID,
      version: NativeWayfarerInduction.version, digest: NativeWayfarerInduction.digest)
    parent.savedWayfarerInduction = f.parent
    parent.acknowledge(100)
    commander.scriptState.instances = [parent.id: parent, f.authorization.job: f.child()]
    #expect(NativeInductionCrewLogSave.hasClaims(commander))
    #expect(NativeInductionCrewLogSave.validateClaims(commander))
    commander.nativeStations?.mainStations = []
    #expect(!NativeInductionCrewLogSave.validateClaims(commander))
    commander.nativeStations?.mainStations = [
      NativeWayfarerInductionUnitTests().dock(
        owner: f.source.manifest.owner, system: 211, visit: 30, sequence: 30
      ).station
    ]
    commander.scriptState.instances[parent.id] = nil
    #expect(!NativeInductionCrewLogSave.validateClaims(commander))
    commander.scriptState.instances[parent.id] = parent
    var unacknowledged = ScriptInstance(
      id: f.authorization.job,
      definition: NativeInductionCrewLogPack.stateID, version: NativeInductionCrewLogPack.version,
      digest: NativeInductionCrewLogPack.digest)
    unacknowledged.savedNativeCrewLog = .init(authorization: f.authorization)
    commander.scriptState.instances[f.authorization.job] = unacknowledged
    #expect(!NativeInductionCrewLogSave.validateClaims(commander))
    commander.scriptState.instances[f.authorization.job] = f.child()
    commander.savedEquipmentInventory = try .init(owner: UUID(), activeHull: UUID())
    #expect(!NativeInductionCrewLogSave.validateClaims(commander))
  }

  @Test func registrationBindsOneOwningOriginalManifestActualCevilisVisitAndPriorReceiving() throws
  {
    let f = try CrewLogProducerFixture()
    #expect(f.authorization.valid(parent: f.parent))
    #expect(f.authorization.manifest == f.source.manifest)
    #expect(
      f.authorization.job
        == NativeInductionCrewLogPack.instance(recorder: f.source.manifest.recorder))
    let foreign = try CrewLogProducerFixture()
    #expect(!f.authorization.valid(parent: foreign.parent))
    for actor in [
      ActorIdentity(system: .init(galaxy: 0, system: 241), visit: 30, entity: 1),
      .init(system: NativeInductionCrewLogSource.location, visit: 1, entity: 1),
      .init(system: NativeInductionCrewLogSource.location, visit: 30, entity: 2),
    ] {
      #expect(throws: (any Error).self) {
        try NativeCrewLogAuthorization(
          parent: f.parent, stationActor: actor,
          physicalTime: 20_000, flightSeconds: 10_000, sequence: 100)
      }
    }
    #expect(throws: (any Error).self) {
      try NativeCrewLogAuthorization(
        parent: f.parent, stationActor: f.authorization.stationActor,
        physicalTime: .nan, flightSeconds: 10_000, sequence: 100)
    }
    #expect(throws: (any Error).self) {
      try NativeCrewLogAuthorization(
        parent: f.parent, stationActor: f.authorization.stationActor,
        physicalTime: 20_000, flightSeconds: 10_000, sequence: 20)
    }
  }

  @Test func livingCrewRequiresDistinctActualAdmissionAndLaunchLossCannotBecomeARescue() throws {
    let f = try CrewLogProducerFixture()
    var state = NativeInductionCrewLogState(authorization: f.authorization)
    #expect(state.shapeValid(parent: f.parent) && state.livingCrew.isEmpty)
    state.admission = f.admission
    #expect(state.shapeValid(parent: f.parent) && state.livingCrew == f.source.manifest.crew)
    state.losses = [.init(role: "tender", actor: f.admission.tender, physicalTime: 20_002)]
    #expect(state.shapeValid(parent: f.parent) && state.livingCrew.count == 2)
    state.losses.append(.init(role: "launch", actor: f.admission.launch, physicalTime: 20_002))
    #expect(state.shapeValid(parent: f.parent) && state.livingCrew.isEmpty)
    let restored = try JSONDecoder().decode(
      NativeInductionCrewLogState.self, from: JSONEncoder().encode(state))
    #expect(restored == state && restored.livingCrew.isEmpty)
    state.losses.append(state.losses[0])
    #expect(!state.shapeValid(parent: f.parent))
    state.losses = []
    state.admission = .init(
      tender: f.admission.tender, launch: f.admission.tender,
      recorder: f.admission.recorder, physicalTime: 20_001)
    #expect(!state.shapeValid(parent: f.parent))
    #expect(f.parent.payloads.isEmpty && f.parent.milestones == [0, 1, 2, 3, 4, 5, 6])
  }

  @Test func mechanicalFailureDisablesOnlyTheOriginalTenderDriveWithoutSpentHullOrEmpCredit() throws
  {
    let f = try CrewLogProducerFixture()
    let tender = try f.prepared(.tender)
    let launch = try f.prepared(.launch)
    let recorder = try f.prepared(.recorder)
    #expect(tender.body.scriptNPC?.fit.definition == launch.body.scriptNPC?.fit.definition)
    #expect(tender.body.scriptNPC?.components["drive"]?.energy == 0)
    #expect(launch.body.scriptNPC?.components["drive"]?.energy == f.source.ship.energy)
    #expect(tender.body.energy == f.source.ship.energy && tender.body.physical == nil)
    #expect(tender.body.hostile == false && tender.body.scriptNPC?.shots == 0)
    #expect(NativeInductionCrewLogPack.mechanicallyDisabled(tender, state: f.child()))
    #expect(!NativeInductionCrewLogPack.mechanicallyDisabled(launch, state: f.child()))
    #expect(recorder.body.scriptNPC?.components.isEmpty == true)
    var admitted = NativeInductionCrewLogState(authorization: f.authorization)
    admitted.admission = f.admission
    var body = launch.body
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogPack.initialBody(&body, state: f.child(admitted), alias: "launch")
    }
  }

  @Test func initialNativeResourcesUseSourceShieldsAndOnlyOneScriptFuelReservoir() throws {
    let f = try CrewLogProducerFixture()
    for role in NativeInductionCrewLogRole.allCases {
      let actor = try f.prepared(role)
      let initial = try NativeInductionCrewLogPack.initialResources(state: f.child(), actor: actor)
      let npc = try #require(initial)
      let resources = try #require(npc.resources)
      #expect(resources.valid && resources.profile == .nativeHull)
      #expect(resources.fuel == nil && resources.fuelCapacity == nil)
      #expect(resources.energyCapacity == (role == .recorder ? 100 : 270))
      #expect(resources.frontShield == (role == .recorder ? 0 : 230))
      #expect(resources.rearShield == resources.frontShield)
      #expect(npc.role == .mission && npc.hasFuelScoops == false)
      #expect(actor.body.scriptNPC?.fuel == (role == .recorder ? 0 : 13))
    }
  }

  @Test func internalPackPinsAllThreePhysicalSourcesAndCannotGrantPickupOrReceivingFromLua() throws
  {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledInductionCrewLogDirectory)
    let f = try CrewLogProducerFixture()
    #expect(NativeInductionCrewLogPack.matches(pack))
    #expect(pack.models[NativeInductionCrewLogSource.model] == f.source.physical.model.nativeDesign)
    #expect(pack.models[NativeInductionCrewLogSource.recorderModel] == f.source.recorderDesign)
    #expect(pack.manifest.npcs == [f.source.ship, f.source.recorder])
    #expect(pack.manifest.encounters?.first?.actors.count == 3)
    #expect(pack.manifest.trial == nil && pack.manifest.board == nil)
    #expect(
      pack.manifest.handlers.map(\.event) == [
        "mission.accepted", "timer.fired", "encounter.admitted",
      ])
    #expect(
      Set(
        NativeInductionCrewLogRole.allCases.map {
          NativeInductionCrewLogPack.actor(job: f.authorization.job, role: $0)
        }
      ).count == 3)
  }

  @Test func closedSourceEnvelopeRejectsOldEmbeddedForeignAndUnknownNestedClaims() throws {
    let f = try CrewLogProducerFixture()
    let leaf = try #require(
      JSONSerialization.jsonObject(
        with: JSONEncoder().encode(NativeInductionCrewLogState(authorization: f.authorization)))
        as? [String: Any])
    func bytes(
      _ leaf: [String: Any], embedded: Bool = false,
      digest: String = NativeInductionCrewLogPack.digest
    ) throws -> Data {
      let mission: [String: Any] = [
        "definition": NativeInductionCrewLogPack.stateID, "digest": digest,
        "savedNativeCrewLog": leaf,
      ]
      let root: [String: Any] = ["instances": [f.authorization.job.uuidString: mission]]
      let object: [String: Any] = embedded ? ["savedScriptState": root] : root
      return try JSONSerialization.data(withJSONObject: object)
    }
    for schema in [83, 84] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        bytes(leaf), part: .missions, schema: schema)
      #expect(
        NativeInductionArkSave.contains(schema) && NativeInductionArkSave.supportsReserve(schema))
    }
    for schema in [75, 76, 79, 80, 81, 82, Int.max] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(bytes(leaf), part: .missions, schema: schema)
      }
    }
    #expect(NativeInductionArkSave.isAlien(84) && !NativeInductionArkSave.isAlien(83))
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(
        bytes(leaf, embedded: true), part: .commander, schema: 83)
    }
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(
        bytes(leaf, digest: String(repeating: "0", count: 64)), part: .missions, schema: 83)
    }
    var changed = leaf
    changed["inventedReceiving"] = true
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(bytes(changed), part: .missions, schema: 83)
    }
  }
}
