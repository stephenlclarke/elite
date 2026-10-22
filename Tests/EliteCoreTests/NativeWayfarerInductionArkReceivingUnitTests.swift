import Foundation
import Testing

@testable import EliteCore

/// Structural receipt/route fixture only; it neither executes a native journey nor admits actors.
struct ArkReceivingFixture {
  let f: InductionArkProducerFixture
  let dock: NativeMainStationDockReceipt
  let contact: NativeArkFuelContact
  init() throws {
    let f = try InductionArkProducerFixture()
    self.f = f
    let visit = UInt64(6 + f.authorization.route.legDistancesLY.count)
    dock = try InductionVaultKeyFixture().helpers.helpers.helpers.dock(
      owner: f.source.owner, system: 91, visit: visit, sequence: 20)
    contact = .init(
      mission: f.source.mission, ark: f.source.actor, station: dock.station,
      stationActor: dock.actor,
      arkActor: .init(system: dock.station.system, visit: visit, entity: 2),
      sequence: 1, physicalTime: 10_000)
  }
  func receipt(
    unit: UUID? = nil, target: String? = nil, seeds: [UUID]? = nil,
    crew: [UUID]? = nil, dock: NativeMainStationDockReceipt? = nil
  ) throws -> NativeInductionSeedReception {
    let dock = dock ?? self.dock
    let seeds = seeds ?? f.source.seeds
    let crew = crew ?? f.source.crew
    let operation = try NativeInductionSeedReception.identity(
      link: f.link, arkDock: contact,
      playerDock: dock, carrier: f.key.carrier, revision: 1, physicalTime: 10_001,
      seeds: seeds, crew: crew)
    return .init(
      operation: operation, sequence: 20, owner: f.source.owner, parent: f.source.mission,
      job: f.authorization.job, registeredArk: f.source.actor, loanOperation: f.key.operation,
      keyUnit: unit ?? f.key.unit, target: target ?? NativeWayfarerInduction.seedReceivingTarget,
      arkDock: contact, playerDock: dock, carrier: f.key.carrier, inventoryRevision: 1,
      physicalTime: 10_001, flightSeconds: 9000, seeds: seeds, crew: crew)
  }

  func routeLegs() throws -> [(NativeArkHopReference, NativeWormholeLeg)] {
    let systems = Universe.galaxy()
    let catalogue = Universe.originalWorlds
    let plan = f.authorization.route
    let profile = f.source.definition
    let hash = ScriptPackLibrary.hash(
      try ScriptPackLibrary.canonicalGeometry(f.source.physical.model.nativeDesign))
    let fit = ScriptNPCFit(definition: profile, models: [NativeInductionArkSource.model: hash])
    var result: [(NativeArkHopReference, NativeWormholeLeg)] = []
    for hop in plan.legDistancesLY.indices {
      let request = "native-ark-hop-\(hop)-0"
      let id = NativeWormholeLeg.identity(
        instance: f.authorization.job, actor: f.authorization.actor, request: request)
      let reference = NativeArkHopReference(hop: hop, attempt: 0, leg: id)
      let origin = try catalogue.world(key: plan.worldKeys[hop])
      let destination = try catalogue.world(key: plan.worldKeys[hop + 1])
      var exit = FlightSimulationState()
      exit.enter(.init(galaxy: destination.galaxy, system: destination.system), arriving: true)
      let route = NativeWormholeRoute(
        catalogueRevision: plan.catalogueRevision,
        origin: .init(worldID: origin.key, galaxy: 0, system: systems[origin.system]),
        destination: .init(
          worldID: destination.key, galaxy: 0, system: systems[destination.system]),
        distanceLightYears: plan.legDistancesLY[hop], exit: exit.pose)
      let native = ActorIdentity(system: route.origin.location, visit: UInt64(6 + hop), entity: 2)
      let component = UUID()
      let time = Double(hop) * 1_000_000 + 1000
      let physicalTime = Double(hop) * 1000 + 1000
      let opening = NativeWormholeOpening(
        id: ScriptIdentity.uuid("native-wormhole-v1:\(id)"),
        leg: id, route: route, sourceActor: native, entrance: .init(position: .init(0, 0, 500)),
        radius: 100, openedAt: time, openedPhysicalTime: physicalTime, expiresAt: time + 120)
      var body = SpaceBody(id: 5, hull: .cobra, position: .init(0, 0, 0), hostile: false)
      body.energy = profile.energy
      body.missionInstanceID = f.authorization.job
      body.missionActorID = f.authorization.actor
      body.physical = .init(identity: native, population: .mission)
      body.scriptNPC = .init(
        fit: fit, fuel: profile.fuel - route.distanceLightYears,
        guns: [:],
        components: ["drive": .init(identity: component, energy: profile.energy, guns: [:])])
      var leg = NativeWormholeLeg(
        id: id, instance: f.authorization.job, actor: f.authorization.actor,
        encounter: NativeInductionArkPack.encounter, alias: NativeInductionArkPack.alias,
        request: request, destinationWorld: destination.key, requestedAt: time - 20)
      leg.route = route
      leg.spooledAt = time - 12
      leg.spoolActor = native
      leg.spoolPhysicalTime = physicalTime - 12
      leg.driveComponent = component
      leg.driveTerms = profile.drive
      leg.opening = opening
      leg.departure = .init(
        hole: opening.id, nativeActor: native, calendarSeconds: time + 1,
        physicalTime: physicalTime + 1, revision: 1, fuelBefore: profile.fuel,
        fuelAfter: body.scriptNPC!.fuel, body: body)
      leg.arrival = .init(
        nativeActor: .init(
          system: route.destination.location,
          visit: UInt64(7 + hop), entity: 2), calendarSeconds: time + 1 + route.seconds)
      leg.phase = .arrived
      try #require(leg.valid)
      result.append((reference, leg))
    }
    return result
  }
}

struct NativeWayfarerInductionArkReceivingUnitTests {
  @Test func originalKeyReturnReleasesExactlyOneTonneAndUnlocksOnlyStageSevenOnce() throws {
    let f = try ArkReceivingFixture()
    let registered = try f.f.parent.registeringArk(f.f.link)
    let receipt = try f.receipt()
    let next = try registered.receivingSeedArk(receipt)
    #expect(next.valid && next.seedReception == receipt && next.payloads.isEmpty)
    #expect(next.milestones == [0, 1, 2, 3, 4, 5, 6] && !next.milestones.contains(7))
    #expect(
      next.seedKey == registered.seedKey && next.cassetteService == registered.cassetteService)
    #expect(next.reception == registered.reception && next.permission == registered.permission)
    #expect(next.action(at: NativeWayfarerInduction.seedReceiver) == .progress)
    #expect(throws: (any Error).self) { try next.receivingSeedArk(receipt) }
    #expect(throws: (any Error).self) { try f.f.parent.receivingSeedArk(receipt) }
    let restored = try JSONDecoder().decode(
      NativeWayfarerInductionState.self, from: JSONEncoder().encode(next))
    #expect(restored == next && restored.payloads.isEmpty && restored.valid)
  }

  @Test func foreignKeyWrongCradleAndAlteredOriginalManifestCannotCompleteReceiving() throws {
    let f = try ArkReceivingFixture()
    let registered = try f.f.parent.registeringArk(f.f.link)
    let wrongDock = f.f.key.dock
    for receipt in [
      try f.receipt(unit: UUID()), try f.receipt(target: "other-cradle"),
      try f.receipt(seeds: Array(f.f.source.seeds.dropLast())),
      try f.receipt(crew: Array(repeating: f.f.source.crew[0], count: 6)),
      try f.receipt(dock: wrongDock),
    ] {
      #expect(!receipt.valid(key: f.f.key, link: f.f.link))
      #expect(throws: (any Error).self) { try registered.receivingSeedArk(receipt) }
    }
    let foreign = try ArkReceivingFixture()
    #expect(throws: (any Error).self) { try registered.receivingSeedArk(foreign.receipt()) }
    #expect(
      registered.payloads == [NativeWayfarerInduction.keyPayload: 1]
        && registered.seedReception == nil)
  }

  @Test func unusedEscrowReturnsOnlyToItsCustodianOnceAndCannotFundFurtherFuel() throws {
    let f = try ArkReceivingFixture()
    let bank = try NativeArkFuelEscrow(source: f.f.source)
    let receipt = try f.receipt()
    let closed = try bank.closing(at: receipt)
    #expect(closed.valid && closed.remainingCredits == 0 && closed.purchases.isEmpty)
    #expect(closed.closure?.returnedCredits == 10_000 && closed.closure?.balanceBefore == 10_000)
    #expect(closed.closure?.recipient == NativeArkFuelClosure.custodian(owner: bank.owner))
    #expect(closed.closure?.recipient != bank.owner)
    #expect(throws: (any Error).self) { try closed.closing(at: receipt) }
    let foreign = try ArkReceivingFixture()
    #expect(throws: (any Error).self) { try bank.closing(at: foreign.receipt()) }
    #expect(try NativeArkFuelEscrow.decodeClosed(JSONEncoder().encode(closed)) == closed)
    #expect(bank.remainingCredits == 10_000 && bank.closure == nil)
  }

  @Test func everyOriginalRouteLegMustHaveItsActualOwnedArrivalBeforeReceivingCanJoin() throws {
    let f = try ArkReceivingFixture()
    let legs = try f.routeLegs()
    let references = legs.map { $0.0 }.sorted { $0.hop < $1.hop }
    let state = try f.f.state().replacing(legs: references)
    var engine = ScriptEngineState()
    engine.wormholeTransit = .init(owner: f.f.source.owner)
    engine.wormholeTransit?.legs = Dictionary(uniqueKeysWithValues: legs.map { ($0.0.leg, $0.1) })
    #expect(NativeInductionArkSave.allHopsReceived(state, engine: engine))
    let last = try #require(references.last)
    engine.wormholeTransit?.legs[last.leg]?.phase = .arrivalPending
    engine.wormholeTransit?.legs[last.leg]?.arrival = nil
    #expect(!NativeInductionArkSave.allHopsReceived(state, engine: engine))
    engine.wormholeTransit?.legs[last.leg] = nil
    #expect(!NativeInductionArkSave.allHopsReceived(state, engine: engine))
    #expect(!NativeInductionArkSave.allHopsReceived(try f.f.state(), engine: engine))
  }

  @Test func sourceJoinRefusesSubstituteFortyUnitLoadsOrCrewAndAnyLostOriginalArk() throws {
    let f = try ArkReceivingFixture()
    let initial = try f.f.state()
    let admitted = initial.replacing(
      admission: .init(
        actor: .init(system: NativeWayfarerInduction.seedSource, visit: 6, entity: 2),
        physicalTime: 401))
    let parked = admitted.replacing(fuelContacts: [f.contact], dockedContact: f.contact)
    let original = try f.receipt()
    let received = parked.replacing(
      fuel: try parked.fuel.closing(at: original), reception: original)
    #expect(received.shapeValid(source: f.f.source, key: f.f.key))
    #expect(
      received.intactSeedTonnes == 0 && received.deliveredSeedTonnes == 40
        && received.livingCrew == 6)
    var substituteSeeds = f.f.source.seeds
    substituteSeeds[0] = UUID()
    var substituteCrew = f.f.source.crew
    substituteCrew[0] = UUID()
    for receipt in [try f.receipt(seeds: substituteSeeds), try f.receipt(crew: substituteCrew)] {
      let forged = parked.replacing(fuel: try parked.fuel.closing(at: receipt), reception: receipt)
      #expect(!forged.shapeValid(source: f.f.source, key: f.f.key))
    }
    let lost = received.replacing(
      loss: .init(actor: f.contact.arkActor, observedPhysicalTime: 10_001))
    #expect(!lost.shapeValid(source: f.f.source, key: f.f.key))
    var parent = ScriptInstance(
      id: f.f.source.mission, definition: NativeWayfarerInduction.stateID,
      version: NativeWayfarerInduction.version, digest: NativeWayfarerInduction.digest)
    parent.acknowledge(original.sequence)
    var child = f.f.child(received)
    child.acknowledge(original.sequence)
    var engine = ScriptEngineState()
    engine.nextEvent = original.sequence
    engine.flightSeconds = original.flightSeconds
    #expect(
      !NativeInductionArkSave.receivingClaimsValid(
        received, parent: parent, child: child, engine: engine))
  }

  @Test func receivingSchemaRejectsEarlyParentReturnAndEscrowClosureClaims() throws {
    let f = try ArkReceivingFixture()
    let receipt = try f.receipt()
    let next = try f.f.parent.registeringArk(f.f.link).receivingSeedArk(receipt)
    let leaf = try JSONSerialization.jsonObject(with: JSONEncoder().encode(next))
    let data = try JSONSerialization.data(withJSONObject: [
      "instances": [
        f.f.source.mission.uuidString:
          [
            "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
            "savedWayfarerInduction": leaf,
          ]
      ]
    ])
    try ScriptSaveJSONPreflight.validateRepairLoopFields(data, part: .missions, schema: 79)
    try ScriptSaveJSONPreflight.validateRepairLoopFields(data, part: .missions, schema: 80)
    for schema in [73, 75, 76, 77, 78] {
      #expect(throws: (any Error).self) {
        try NativeInductionArkSave.validateFields(data, part: .missions, schema: schema)
      }
    }
    #expect(
      NativeInductionArkSave.lowerSchema(78) == 74 && NativeInductionArkSave.lowerSchema(80) == 74)
  }
}
