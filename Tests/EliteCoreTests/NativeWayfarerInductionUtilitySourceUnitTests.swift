import Foundation
import Testing

@testable import EliteCore

/// Typed source/graph fixtures; no actual authorization, admission, repair or receiving is executed.
final class InductionUtilityFixture {
  let receivingFixture: RescueReceivingFixture
  let originalSale: NativeFirstCommoditySale
  let parent: NativeWayfarerInductionState
  let source: NativeInductionUtilitySource
  let authorization: NativeInductionUtilityAuthorization
  init() throws {
    let previous = try RescueReceivingFixture()
    receivingFixture = previous
    originalSale = previous.f.f.f.originalSale
    parent = try previous.f.f.parent.receivingOriginalRescue(previous.receipt())
    source = try .init(parent: parent)
    let received = try #require(parent.rescueReception)
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: source.owner, system: 190,
      visit: received.playerDock.actor.visit + 1, sequence: 101)
    authorization = try .init(
      parent: parent, dock: dock,
      carrier: received.carrier, revision: 1, physicalTime: 1_000_001,
      flightSeconds: 900_001, sequence: 105)
  }
  func state() -> NativeInductionUtilityState {
    .init(authorization: authorization, source: source)
  }
  func child() -> ScriptInstance {
    var child = ScriptInstance(
      id: authorization.job, definition: NativeInductionUtilityPack.stateID,
      version: NativeInductionUtilityPack.version, digest: NativeInductionUtilityPack.digest)
    child.savedNativeInductionUtility = state()
    child.acknowledge(105)
    return child
  }
  func prepared(_ role: NativeInductionUtilityRole) throws -> ScriptOwnedActor {
    let logical = NativeInductionUtilityPack.actor(job: authorization.job, role: role)
    var body = SpaceBody(id: -1, hull: .cobra, position: role.offset, hostile: false)
    body.missionActorID = logical
    body.missionInstanceID = authorization.job
    body.energy = 100
    body.rotationRate = 0
    body.scriptNPC = .init(
      fit: .init(
        definition: NativeInductionUtilitySource.profile,
        models: [NativeInductionUtilitySource.model: try NativeInductionUtilitySource.geometryHash]),
      fuel: 0, guns: [:], components: [:])
    return .init(identity: logical, alias: role.rawValue, body: body, presence: .prepared)
  }
  func commander() throws -> Commander {
    var commander = Commander()
    commander.savedEquipmentInventory = try .init(
      owner: source.owner, activeHull: authorization.carrier)
    while commander.flightSimulation.visit < authorization.dock.actor.visit {
      commander.flightSimulation.enter(NativeInductionUtilitySource.location, arriving: true)
    }
    commander.flightSimulation.physicalTime = 1_000_005
    commander.scriptState.flightSeconds = 900_005
    commander.scriptState.calendarSeconds = 1_000_005
    commander.scriptState.nextEvent = 105
    commander.nativeStations = try .init(owner: source.owner)
    commander.nativeStations?.mainStations = [authorization.dock.station]
    commander.nativeStations?.nextMainDockSequence = 102
    var parent = ScriptInstance(
      id: source.parent, definition: NativeWayfarerInduction.stateID,
      version: NativeWayfarerInduction.version, digest: NativeWayfarerInduction.digest)
    parent.savedWayfarerInduction = self.parent
    parent.acknowledge(105)
    commander.scriptState.instances = [source.parent: parent, authorization.job: child()]
    return commander
  }
}

struct NativeWayfarerInductionUtilitySourceUnitTests {
  @Test func exactInitialEnclosuresKeepPhysicalMetresSeparateFaultsAndFiniteOriginalCrewKits()
    throws
  {
    let f = try InductionUtilityFixture()
    let state = f.state()
    #expect(state.shapeValid(parent: f.parent) && state.admission == nil)
    #expect(state.modules.map(\.role) == [.inlet, .buffer, .return])
    #expect(state.modules.map(\.fault) == ["valve-closed", "relay-disconnected", "valve-closed"])
    #expect(state.modules.allSatisfy { $0.availableKits == 1 })
    #expect(Set(state.modules.map(\.module) + state.modules.map(\.kit)).count == 6)
    let mesh = NativeInductionUtilitySource.geometry.rawMesh
    #expect(mesh.vertices.count == 8 && mesh.faces.count == 6)
    for axis in [mesh.vertices.map(\.x), mesh.vertices.map(\.y), mesh.vertices.map(\.z)] {
      #expect(axis.min() == -3 && axis.max() == 3)
    }
    #expect((mesh.vertices.map(\.length).max() ?? 100) < 6)
    let p = NativeInductionUtilitySource.profile
    #expect(p.valid && p.scale == 1 && p.speed == 0 && p.acceleration == 0)
    #expect(
      p.drive == nil && p.missiles == 0 && p.fuel == 0 && p.components == [] && p.lasers == [])
    #expect(f.parent.milestones == [0, 1, 2, 3, 4, 5, 6, 7, 8] && f.parent.payloads.isEmpty)
    let same = try NativeInductionUtilitySource(parent: f.parent)
    #expect(same.issue == f.source.issue && same.kit(.inlet) == f.source.kit(.inlet))
    let restored = try JSONDecoder().decode(
      NativeInductionUtilityState.self,
      from: JSONEncoder().encode(state))
    #expect(restored == state && restored.modules.allSatisfy { $0.availableKits == 1 })
  }

  @Test func sourceAuthorizationNeedsPriorActualReceptionAndOwningLaterEnronDockWithoutProgress()
    throws
  {
    let f = try InductionUtilityFixture()
    let earlier = try RescueFlightFixture()
    #expect(throws: (any Error).self) { try NativeInductionUtilitySource(parent: earlier.f.parent) }
    #expect(f.authorization.valid(parent: f.parent))
    let foreign = try InductionUtilityFixture()
    #expect(!f.authorization.valid(parent: foreign.parent))
    let received = try #require(f.parent.rescueReception)
    #expect(throws: (any Error).self) {
      try NativeInductionUtilityAuthorization(
        parent: f.parent,
        dock: received.playerDock, carrier: f.authorization.carrier,
        revision: 1, physicalTime: 1_000_001, flightSeconds: 900_001, sequence: 105)
    }
    #expect(f.parent.action(at: NativeInductionUtilitySource.location) == .progress)
    #expect(
      NativeWayfarerInductionAction.authorizeUtility.station
        == NativeInductionUtilitySource.location)
    #expect(
      f.child().milestones.isEmpty && f.child().payloads.isEmpty && f.child().gearIssues.isEmpty)
    let reference = StationAnchor(
      identity: f.authorization.dock.actor,
      position: .init(0, 0, 0), orientation: Basis3(), exitPosition: .init(0, 0, -500),
      exitDirection: .init(0, 0, -1))
    for role in NativeInductionUtilityRole.allCases {
      #expect(try f.source.initialPose(role, reference: reference).position == role.offset)
    }
  }

  @Test func originalSourceGraphRequiresBothAcknowledgementsOwnerActualStationAndSingleIssue()
    throws
  {
    let f = try InductionUtilityFixture()
    var commander = try f.commander()
    #expect(NativeInductionUtilitySave.validateClaims(commander))
    #expect(NativeInductionCrewLogSave.hasClaims(commander))
    let parent = commander.scriptState.instances[f.source.parent]
    commander.scriptState.instances[f.source.parent] = nil
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
    commander.scriptState.instances[f.source.parent] = parent
    var unacknowledged = ScriptInstance(
      id: f.authorization.job, definition: NativeInductionUtilityPack.stateID,
      version: NativeInductionUtilityPack.version, digest: NativeInductionUtilityPack.digest)
    unacknowledged.savedNativeInductionUtility = f.state()
    commander.scriptState.instances[f.authorization.job] = unacknowledged
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
    commander.scriptState.instances[f.authorization.job] = f.child()
    commander.nativeStations?.mainStations = []
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
    commander.nativeStations?.mainStations = [f.authorization.dock.station]
    commander.savedEquipmentInventory = try .init(owner: UUID(), activeHull: UUID())
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
  }

  @Test func nativePreparedConditionKeepsActualOriginalModelAndCannotBecomeEquipmentOrCargo() throws
  {
    let f = try InductionUtilityFixture()
    for role in NativeInductionUtilityRole.allCases {
      let actor = try f.prepared(role)
      #expect(f.source.matchesFit(try #require(actor.body.scriptNPC?.fit)))
      let preparedResources = try NativeInductionUtilityPack.initialResources(
        state: f.child(), actor: actor)
      let resources = try #require(preparedResources)
      #expect(resources.role == .mission && resources.resources?.profile == .nativeHull)
      #expect(resources.resources?.energyCapacity == 100 && resources.resources?.frontShield == 0)
      #expect(resources.resources?.fuel == nil && resources.hasFuelScoops == false)
      #expect(actor.body.physical == nil && actor.body.missionInstanceID == f.authorization.job)
    }
    let foreign = try InductionUtilityFixture()
    #expect(throws: (any Error).self) {
      try NativeInductionUtilityPack.initialResources(
        state: f.child(), actor: foreign.prepared(.inlet))
    }
  }

  @Test func actualAdmissionClaimsNeedThreeOriginalNativeActorsAndKeepFaultAndKitStateUnchanged()
    throws
  {
    let f = try InductionUtilityFixture()
    var commander = try f.commander()
    var child = f.child()
    var state = f.state()
    var actors: [String: ScriptOwnedActor] = [:]
    var admitted: [String: NativeArkAdmission] = [:]
    for role in NativeInductionUtilityRole.allCases {
      var actor = try f.prepared(role)
      let allocated = commander.flightSimulation.allocateActor()
      let native = try #require(allocated)
      actor.body.id = 40 + Int(native.entity)
      actor.presence = .present
      actor.body.physical = .init(
        identity: native, population: .mission,
        npc: try NativeInductionUtilityPack.initialResources(
          state: f.child(), actor: f.prepared(role)))
      actors[role.rawValue] = actor
      admitted[role.rawValue] = .init(actor: native, physicalTime: 1_000_002)
    }
    var group = ScriptOwnedEncounter(
      id: NativeInductionUtilityPack.encounter,
      galaxy: 0, system: 190, actors: actors)
    group.admitted = true
    child.ownedEncounters[group.id] = group
    state.admission = admitted
    child.savedNativeInductionUtility = state
    commander.scriptState.instances[child.id] = child
    #expect(NativeInductionUtilitySave.validateClaims(commander))
    #expect(state.modules == f.state().modules && child.milestones.isEmpty)
    commander.scriptState.instances[child.id]?.ownedEncounters[group.id]?.actors["inlet"]?.body
      .scriptNPC?.fuel = 1
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
    commander.scriptState.instances[child.id] = child
    commander.scriptState.instances[child.id]?.ownedEncounters[group.id]?.actors["buffer"]?
      .transitLocation = NativeInductionCrewLogSource.receiver
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
    state.admission?["return"] = nil
    #expect(!state.shapeValid(parent: f.parent))
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.state())) as? [String: Any])
    var modules = try #require(raw["modules"] as? [[String: Any]])
    modules[0]["availableKits"] = 2
    raw["modules"] = modules
    let forged = try JSONDecoder().decode(
      NativeInductionUtilityState.self,
      from: JSONSerialization.data(withJSONObject: raw))
    #expect(!forged.shapeValid(parent: f.parent))
  }

  @Test func exactInternalPackPinsThreeSourcesAndLuaCannotRepairConsumeKitsOrAdvanceStageTen()
    throws
  {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledInductionUtilityDirectory)
    #expect(NativeInductionUtilityPack.matches(pack))
    #expect(
      pack.models == [NativeInductionUtilitySource.model: NativeInductionUtilitySource.geometry])
    #expect(pack.manifest.npcs == [NativeInductionUtilitySource.profile])
    let bytes = try Data(
      contentsOf: ScriptPackLibrary.bundledInductionUtilityDirectory.appendingPathComponent(
        "scripts/main.lua"))
    let code = try #require(String(data: bytes, encoding: .utf8))
    #expect(code.contains("encounter.activate") && code.contains("timer.cancel"))
    for forbidden in [
      "mission.complete", "milestone", "cash.add", "cargo.add", "gear.issue", "repair",
      "kit.consume",
    ] {
      // Journal prose may describe a fault; only executable command names are prohibited.
      #expect(!code.contains("op = \"" + forbidden))
    }
    #expect(
      pack.manifest.trial == nil && pack.manifest.providerContract == nil
        && pack.manifest.board == nil)
  }

  @Test func closedUtilityEnvelopeRejectsEarlierForeignUnknownAndExtraModuleClaims() throws {
    let f = try InductionUtilityFixture()
    let leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.state())) as? [String: Any])
    func data(_ leaf: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          f.authorization.job.uuidString: [
            "definition": NativeInductionUtilityPack.stateID,
            "digest": NativeInductionUtilityPack.digest,
            "savedNativeInductionUtility": leaf,
          ]
        ]
      ])
    }
    for schema in [97, 98] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        data(leaf), part: .missions, schema: schema)
    }
    for schema in [91, 92, 93, 94, 95, 96, Int.max] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(data(leaf), part: .missions, schema: schema)
      }
    }
    var altered = leaf
    altered["repaired"] = true
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(data(altered), part: .missions, schema: 97)
    }
    var modules = try #require(leaf["modules"] as? [[String: Any]])
    modules.append(modules[0])
    altered = leaf
    altered["modules"] = modules
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(data(altered), part: .missions, schema: 97)
    }
    #expect(NativeInductionArkSave.isAlien(96) && NativeInductionArkSave.isAlien(98))
  }
}
