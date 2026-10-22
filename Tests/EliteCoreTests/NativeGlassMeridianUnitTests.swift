import Foundation
import Testing

@testable import EliteCore

/// Structural policy/codec values only; live proofs are created by the native producer.
struct NativeGlassMeridianUnitTests {
  private func station(owner: UUID, system: Int) -> NativeMainStationIdentity {
    .init(
      world: owner, system: .init(galaxy: 0, system: system),
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:\(system)"))
  }
  func fixture() throws -> NativeGlassMeridianState {
    let owner = UUID()
    let mission = UUID()
    let carrier = UUID()
    let origin = station(owner: owner, system: 7)
    let dock = NativeMainStationDockReceipt(
      station: origin,
      actor: .init(system: origin.system, visit: 1, entity: 1),
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    let node = try #require(
      EquipmentRuntimeCatalog.node(for: TargetingTier.identification.equipmentName))
    let equipment = EquipmentPurchaseItem(
      id: UUID(), node: node,
      location: .init(hull: carrier, slot: "targeting.core"),
      provenance: .grant("structural fixture"))
    let types = ShipCatalogue.all.filter {
      $0.originalDefinition != nil && $0.catalogue.discoveryEligible
        && $0.catalogue.objectKind == .ship
    }.prefix(2)
    let identified: [FleetDiscoveryEvidence] = types.enumerated().map { index, ship in
      .init(
        owner: owner, ship: ship.id, kind: .identification,
        actor: .init(system: origin.system, visit: 1, entity: UInt64(index + 2)),
        player: .init(system: origin.system, visit: 1, entity: 0), physicalTime: 0,
        death: nil, mainDock: nil, secondaryDock: nil)
    }
    return .init(
      permission: .init(
        mission: mission,
        operation: try NativeGlassMeridian.operation(mission: mission, owner: owner, dock: dock),
        owner: owner, dock: dock, carrier: carrier, inventoryRevision: 1, fit: [equipment],
        visited: [origin, station(owner: owner, system: 185), station(owner: owner, system: 93)],
        identified: identified, physicalTime: 0))
  }
  func sealed(_ state: NativeGlassMeridianState, ordinal: Int, start: Double = 10) throws
    -> NativeGlassMeridianReading
  {
    let p = state.permission
    let epoch = UUID()
    let generation = state.losses.filter { $0.ordinal == ordinal }.count
    let actor = ActorIdentity(
      system: NativeGlassMeridian.objective, visit: 2,
      entity: UInt64(10 + ordinal + generation * 2))
    let markerID = NativeGlassMeridian.actor(
      mission: p.mission, ordinal: ordinal, generation: generation)
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)
    let definition = try #require(pack.manifest.npcs?.first)
    let design = try #require(pack.models[definition.model])
    let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
    var body = SpaceBody(
      id: 10 + ordinal, hull: .cobra,
      position: NativeGlassMeridian.positions[ordinal])
    body.energy = 100
    body.missiles = 0
    body.rotationRate = 0
    body.missionActorID = markerID
    body.missionInstanceID = p.mission
    body.scriptNPC = .init(
      fit: .init(definition: definition, models: [definition.model: hash]),
      fuel: 0, guns: [:], components: [:])
    body.physical = .init(identity: actor, population: .mission, npc: nil)
    let marker = ScriptOwnedActor(
      identity: markerID, alias: NativeGlassMeridian.targets[ordinal],
      body: body, presence: .present)
    let equipment = try #require(p.fit.first)
    let operation = NativeGlassMeridian.readingOperation(permission: p.operation, ordinal: ordinal)
    let authority = try NativeOriginalSurvey.authorityIdentity(
      operation: operation,
      equipment: equipment, inventoryRevision: 1, epoch: epoch, actor: actor)
    return .init(
      reading: .init(
        operation: operation, authority: authority,
        mission: p.mission, permission: p.operation, owner: p.owner, carrier: p.carrier,
        equipment: equipment.id, inventoryRevision: 1, ordinal: ordinal, marker: markerID,
        actor: actor, player: .init(system: actor.system, visit: actor.visit, entity: 0),
        start: start, end: start + 12, qualifiedSeconds: 12, intervals: 120, epoch: epoch,
        revision: UInt64(ordinal + 1)),
      authority: .init(
        id: authority, operation: operation, permission: p.operation,
        owner: p.owner, carrier: p.carrier, inventoryRevision: 1, epoch: epoch,
        equipment: equipment, marker: marker, observedAt: start + 12))
  }
  private func sample(_ state: NativeGlassMeridianState, ordinal: Int, time: Double, epoch: UUID)
    -> NativeOriginalSurveySample
  {
    let p = state.permission
    return .init(
      mission: p.mission, permission: p.operation, owner: p.owner, carrier: p.carrier,
      equipment: p.fit[0].id, inventoryRevision: 1, ordinal: ordinal,
      marker: NativeGlassMeridian.actor(mission: p.mission, ordinal: ordinal),
      actor: .init(system: NativeGlassMeridian.objective, visit: 2, entity: UInt64(10 + ordinal)),
      player: .init(system: NativeGlassMeridian.objective, visit: 2, entity: 0),
      time: time, epoch: epoch)
  }

  @Test func entryRequiresThreeDistinctActualWorldsAndTwoIdentifiedTypesFromTheSameOwner() throws {
    let state = try fixture()
    let p = state.permission
    #expect(
      NativeGlassMeridian.qualified(visited: p.visited, identified: p.identified, owner: p.owner))
    #expect(
      !NativeGlassMeridian.qualified(
        visited: [p.visited[0], p.visited[0], p.visited[1]],
        identified: p.identified, owner: p.owner))
    #expect(
      !NativeGlassMeridian.qualified(
        visited: p.visited,
        identified: [p.identified[0], p.identified[0]], owner: p.owner))
    #expect(
      !NativeGlassMeridian.qualified(visited: p.visited, identified: p.identified, owner: UUID()))

    let nonship = try #require(
      ShipCatalogue.all.first {
        $0.originalDefinition != nil && $0.catalogue.discoveryEligible
          && $0.catalogue.objectKind == .station
      })
    let stationType = FleetDiscoveryEvidence(
      owner: p.owner, ship: nonship.id, kind: .identification,
      actor: p.identified[1].actor, player: p.identified[1].player, physicalTime: 0,
      death: nil, mainDock: nil, secondaryDock: nil)
    #expect(
      !NativeGlassMeridian.qualified(
        visited: p.visited,
        identified: [p.identified[0], stationType], owner: p.owner))
  }

  @Test func contiguousNativeDwellSealsTwelveSecondsAndChangingTargetOrClockRestartsIt() throws {
    let state = try fixture()
    let epoch = UUID()
    var observation: NativeOriginalSurveyObservation?
    for index in 0..<120 {
      observation = try NativeGlassMeridian.observe(
        previous: observation,
        first: sample(state, ordinal: 1, time: 10 + Double(index) * 0.1, epoch: epoch),
        last: sample(state, ordinal: 1, time: 10 + Double(index + 1) * 0.1, epoch: epoch))
    }
    #expect(try #require(observation).intervals == 120)
    #expect(abs(try #require(observation).seconds - 12) < 1e-8)
    let changed = try NativeGlassMeridian.observe(
      previous: observation,
      first: sample(state, ordinal: 0, time: 22, epoch: epoch),
      last: sample(state, ordinal: 0, time: 22.1, epoch: epoch))
    #expect(changed.intervals == 1 && changed.seconds < 0.101)
    #expect(throws: (any Error).self) {
      try NativeGlassMeridian.observe(
        previous: nil,
        first: sample(state, ordinal: 0, time: 22, epoch: epoch),
        last: sample(state, ordinal: 0, time: 22.2, epoch: epoch))
    }
    #expect(throws: (any Error).self) {
      try NativeGlassMeridian.observe(
        previous: nil,
        first: sample(state, ordinal: 0, time: 22, epoch: epoch),
        last: sample(state, ordinal: 0, time: 22.1, epoch: UUID()))
    }
  }

  @Test func eitherClockOrderIsValidButDuplicateForeignAndOverlappingReadingsCannotAdvance() throws
  {
    var state = try fixture()
    state.readings = [try sealed(state, ordinal: 1), try sealed(state, ordinal: 0, start: 22)]
    #expect(NativeGlassMeridian.readingsValid(state))
    let valid = state
    state.readings.append(state.readings[0])
    #expect(!NativeGlassMeridian.readingsValid(state))
    state = valid
    state.readings[1] = try sealed(state, ordinal: 0)
    #expect(!NativeGlassMeridian.readingsValid(state))
    state = valid
    let other = try fixture()
    state.readings[1] = try sealed(other, ordinal: 0, start: 22)
    #expect(!NativeGlassMeridian.readingsValid(state))
    #expect(
      try JSONDecoder().decode(
        NativeGlassMeridianState.self,
        from: JSONEncoder().encode(valid)) == valid)
  }

  @Test
  func destroyedUnreadClockRequiresNewLogicalAndPhysicalIdentityWhileKeepingCompletedEvidence()
    throws
  {
    var state = try fixture()
    let completed = try sealed(state, ordinal: 1)
    state.readings = [completed]
    let old = try sealed(state, ordinal: 0).authority.marker
    var deadBody = old.body
    deadBody.energy = 0
    let dead = ScriptOwnedActor(
      identity: old.identity, alias: old.alias, body: deadBody, presence: .destroyed)
    state.losses = [.init(ordinal: 0, generation: 0, marker: dead, physicalTime: 22)]
    #expect(NativeGlassMeridian.lossesValid(state))
    let replacement = try sealed(state, ordinal: 0, start: 22)
    #expect(replacement.reading.marker != old.identity)
    #expect(replacement.reading.actor != old.body.physical?.identity)
    #expect(
      NativeGlassMeridian.authorizesReplacement(
        state, actor: replacement.authority.marker,
        encounter: NativeGlassMeridian.encounters[0], instance: state.permission.mission,
        packDigest: NativeGlassMeridian.digest))
    #expect(
      !NativeGlassMeridian.authorizesReplacement(
        state, actor: old,
        encounter: NativeGlassMeridian.encounters[0], instance: state.permission.mission,
        packDigest: NativeGlassMeridian.digest))
    state.readings.append(replacement)
    #expect(NativeGlassMeridian.readingsValid(state))
    #expect(state.readings[0] == completed && state.losses[0].marker == dead)
  }

  @Test(arguments: [false, true])
  func strictOpeningSchemaLowersThroughFleetAndRejectsOldOrUnknownClaims(alien: Bool) throws {
    let state = try fixture()
    let leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    var instance: [String: Any] = [
      "definition": NativeGlassMeridian.stateID,
      "digest": NativeGlassMeridian.digest, "savedGlassMeridian": leaf,
    ]
    func bytes(_ instance: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": ["opening": instance]])
    }
    let schema = alien ? 64 : 63
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      try bytes(instance), part: .missions, schema: schema)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        try bytes(instance), part: .missions, schema: schema - 2)
    }
    var unknown = leaf
    unknown["terminalReward"] = 48000
    instance["savedGlassMeridian"] = unknown
    #expect(throws: (any Error).self) {
      try NativeGlassMeridianSave.validateFields(
        try bytes(instance), part: .missions, schema: schema)
    }
    instance.removeValue(forKey: "savedGlassMeridian")
    #expect(throws: (any Error).self) {
      try NativeGlassMeridianSave.validateFields(
        try bytes(instance), part: .missions, schema: schema)
    }
    let fleet = NativeGlassMeridianSave.lowerSchema(schema)
    #expect(fleet == (alien ? 62 : 61))
    #expect(NativeFleetDiscoverySave.lowerSchema(fleet) == (alien ? 60 : 59))
  }

  @Test func unacceptedOpeningRoutesToTheActualBoardAndRejectsChangedPackPins() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)
    #expect(
      NativeGlassMeridian.availability(pack, accepted: false)?.contains("Station Contracts") == true
    )
    #expect(NativeGlassMeridian.availability(pack, accepted: true) == nil)
    let changed = ScriptPack(
      manifest: pack.manifest, source: pack.source, manifestBytes: pack.manifestBytes,
      digest: String(repeating: "0", count: 64), models: pack.models)
    #expect(NativeGlassMeridian.availability(changed, accepted: true)?.contains("Restore") == true)
  }

  @Test func openingPackPinsRealClockGeometryAndAllNineAuthoredMilestonesWithoutATerminal() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)
    #expect(pack.digest == NativeGlassMeridian.digest && pack.missingCapabilities.isEmpty)
    #expect(pack.manifest.mission.milestones.count == 9)
    #expect(pack.manifest.handlers.map(\.event) == ["mission.accepted"])
    #expect(pack.manifest.trial == nil && pack.manifest.board == nil)
    #expect(pack.manifest.encounters?.map(\.id) == NativeGlassMeridian.encounters)
    var mixed = pack.manifest
    mixed.flightReception = .init(profile: "native-main-berth-flight-v1")
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateGlassMeridian(mixed) }
    mixed = pack.manifest
    mixed.glassMeridian = nil
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateGlassMeridian(mixed) }
  }
}
