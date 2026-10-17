import Foundation
import Testing

@testable import EliteCore

struct NativeCrimboRuntimeTests {
  @Test func actualAdmissionCreatesSevenOrdinaryOriginalsAndNeverRefreshesLoadout() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    #expect(CrimboFixture.convoyBodies(game).count == 7 && game.commander.npcPersistence.count == 7)
    let identities = CrimboFixture.convoyBodies(game).compactMap { $0.physical?.identity }
    #expect(Set(identities).count == 7)
    #expect(
      game.bodies.allSatisfy {
        $0.missionActorID == nil && $0.missionInstanceID == nil && $0.scriptNPC == nil
          && $0.physical?.population == .civilian
          && $0.physical?.spawnIdentity?.producer == .provider
      })
    #expect(game.bodies.filter { $0.physical?.catalogueShipID == "SH151" }.count == 6)
    let santaIndex = try #require(
      game.bodies.firstIndex { $0.physical?.catalogueShipID == "SH150" })
    game.bodies[santaIndex].energy = 17
    game.bodies[santaIndex].missiles = 0
    game.bodies[santaIndex].physical?.npc?.resources?.frontShield = 3
    let before = game.bodies.map(\.position)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    game.advanceNativeCrimbo(delta: 0.1)
    #expect(CrimboFixture.convoyBodies(game).compactMap { $0.physical?.identity } == identities)
    #expect(game.bodies[santaIndex].energy == 17 && game.bodies[santaIndex].missiles == 0)
    #expect(game.bodies[santaIndex].physical?.npc?.resources?.frontShield == 3)
    #expect(game.bodies.map(\.position) == before)
  }

  @Test func realCivilianCapacityRefusesWholeCohortAndRetainsPendingOriginals() throws {
    var game = try CrimboFixture.game()
    for i in 0..<2 {
      let actor = try #require(game.commander.flightSimulation.allocateActor())
      var body = SpaceBody(
        id: 100 + i, hull: .cobra, position: .init(Double(i) * 1000, 1000, -5000))
      body.physical = .init(
        identity: actor, population: .civilian,
        npc: .init(role: .trader, origin: CrimboFixture.system, destination: CrimboFixture.system))
      game.bodies.append(body)
    }
    let registry = game.commander.savedCrimboState
    let nextActor = game.commander.flightSimulation.nextActor
    game.advanceNativeCrimbo(delta: 0.1)
    #expect(game.bodies.filter { $0.physical?.population == .civilian }.count == 2)
    #expect(game.commander.savedCrimboState == registry)
    #expect(game.commander.flightSimulation.nextActor == nextActor)
  }

  @Test func parkingAndRealReadmissionKeepOriginalLogicalIDsAndSpentResources() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    #expect(CrimboFixture.convoyBodies(game).count == 7)
    let before = try #require(game.commander.savedCrimboState)
    let santa = try #require(game.bodies.firstIndex { $0.physical?.catalogueShipID == "SH150" })
    game.bodies[santa].energy = 23
    game.bodies[santa].physical?.npc?.resources?.fuel = 11
    game.bodies[santa].physical?.npc?.resources?.laserHeat = 77
    game.bodies[santa].missiles = 0
    try game.parkNativeCrimboBeforeDeparture()
    #expect(game.commander.npcPersistence.count == 0)
    #expect(
      game.commander.savedCrimboState?.members.allSatisfy {
        if case .parked = $0.ownership { true } else { false }
      } == true)
    // This is the integrator-owned world clear in the same unpublished candidate.
    game.bodies = []
    game.commander.npcPersistence.depart(system: CrimboFixture.system)
    game.commander.flightSimulation.enter(.init(galaxy: 7, system: 9), arriving: true)
    game.commander.flightSimulation.enter(CrimboFixture.system, arriving: true)
    game.commander.flightSimulation.advancePhysicalTime(1)
    game.advanceNativeCrimbo(delta: 0.1)
    #expect(CrimboFixture.convoyBodies(game).count == 7 && game.commander.npcPersistence.count == 7)
    let after = try #require(game.commander.savedCrimboState)
    #expect(after.members.map(\.identity) == before.members.map(\.identity))
    #expect(
      after.members.map { $0.ownership.logical } == before.members.map { $0.ownership.logical })
    let restored = try #require(game.bodies.first { $0.physical?.catalogueShipID == "SH150" })
    #expect(restored.energy == 23 && restored.missiles == 0)
    #expect(restored.physical?.npc?.resources?.fuel == 11)
    #expect(restored.physical?.npc?.resources?.laserHeat == 77)
  }

  @Test func sweptGeometryRejectsCrossingEvenWhenBothEndpointsAreClear() {
    #expect(
      NativeCrimboMotion.closestDistance(
        offset: .init(-100, 0, 0), displacement: .init(200, 0, 0)) == 0)
    #expect(
      NativeCrimboMotion.closestDistance(
        offset: .init(-100, 30, 0), displacement: .init(200, 0, 0)) == 30)
    #expect(
      NativeCrimboMotion.closestDistance(
        offset: .init(10, 0, 0), displacement: .init(20, 0, 0)) == 10)
  }

  @Test func steeringIsTurnLimitedAndPreservesWholeBasis() {
    let result = NativeCrimboMotion.turned(Basis3(), toward: .init(1, 0, 0), maximum: 0.05)
    #expect(abs(acos(result.z.dot(Vector3(0, 0, 1))) - 0.05) < 1e-10)
    #expect(result.validRotation)
    #expect(abs(result.x.cross(result.y).dot(result.z) - 1) < 1e-10)
  }

  @Test func desiredOrbitPhaseCannotSupplyActualMotionAndSampleIsSingleUse() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let sample = try #require(game.nativeCrimboMotionSample)
    // No translation has occurred. The requested positive movement is not attained evidence.
    #expect(throws: NativeCrimboError.invalidMotion) {
      try game.finishNativeCrimboMotion(admitted: true)
    }
    #expect(game.nativeCrimboMotionSample == nil)
    #expect(try game.finishNativeCrimboMotion(admitted: true) == nil)
    game.nativeCrimboMotionSample = sample
    #expect(try game.finishNativeCrimboMotion(admitted: false) == nil)
  }

  @Test func staleEpochAndActualTeleportInvalidateMotion() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let sample = try #require(game.nativeCrimboMotionSample)
    game.nativeStationRuntimeEpoch = UUID()
    #expect(try game.finishNativeCrimboMotion(admitted: true) == nil)
    game.nativeStationRuntimeEpoch = sample.runtimeEpoch
    game.nativeCrimboMotionSample = sample
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == sample.actor })
    game.bodies[index].position.x += 1000
    #expect(throws: NativeCrimboError.invalidMotion) {
      try game.finishNativeCrimboMotion(admitted: true)
    }
  }
  @Test func stationContactInvalidatesEvenTinyActualMovement() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    _ = try #require(game.nativeCrimboMotionSample)
    game.stationImpactRevision = game.gameplayRevision
    #expect(try game.finishNativeCrimboMotion(admitted: true) == nil)
    #expect(game.nativeCrimboMotionSample == nil)
  }

  @Test func overspeedCannotBeClippedPastActualAccelerationLimit() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let index = try #require(game.bodies.firstIndex { $0.physical?.catalogueShipID == "SH150" })
    let performance = try #require(ShipCatalogue.ship("SH150")?.game)
    let before = Vector3(0, 1000, 0)
    game.bodies[index].physical?.velocity = before
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    game.advanceNativeCrimbo(delta: 0.1)
    let after = try #require(game.bodies[index].physical?.velocity)
    #expect((after - before).length <= performance.acceleration * 18 * 0.1 + 1e-8)
  }

  @Test func nativeTickTranslationProducesWorldUnitAttainmentOnce() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    game.tick(delta: 0.01)
    let sample = try #require(game.nativeCrimboMotionSample)
    let result = try #require(game.finishNativeCrimboMotion(admitted: true))
    #expect(result.actor == sample.actor && result.provider == sample.provider)
    #expect(result.endTime > result.startTime)
    let actual = result.subjectEnd.position - result.subjectStart.position
    #expect(abs(result.tangentialDisplacementWorldUnits - actual.dot(sample.tangent)) < 1e-8)
    #expect(result.tangentialDisplacementWorldUnits > 0)
    #expect(try game.finishNativeCrimboMotion(admitted: true) == nil)
  }

  @Test func actualLaunchBirthAndDockRelaunchRetainSevenOriginalLogicalKeys() throws {
    var game = Game(executive: false)
    game.commander.galaxy = 7
    game.commander.system = 8
    game.systems = Universe.systemsIncludingPlugh(number: 7)
    // Source boundary fixture injection, not native save/durability readiness evidence.
    game.nativeCrimboLifecycleAvailable = true
    game.launch()
    let first = try #require(game.commander.savedCrimboState)
    #expect(!game.docked && CrimboFixture.convoyBodies(game).count == 7)
    let santa = try #require(
      CrimboFixture.convoyBodies(game).first { $0.physical?.catalogueShipID == "SH150" })
    let index = try #require(game.bodies.firstIndex { $0.id == santa.id })
    game.bodies[index].energy = 37
    game.bodies[index].physical?.npc?.resources?.frontShield = 7
    game.dock()
    game.launch()
    let again = try #require(game.commander.savedCrimboState)
    #expect(CrimboFixture.convoyBodies(game).count == 7)
    #expect(again.provider == first.provider && again.manifest == first.manifest)
    #expect(
      again.members.map { $0.ownership.logical } == first.members.map { $0.ownership.logical })
    #expect(again.spawnSequence == first.spawnSequence)
    let restored = try #require(
      CrimboFixture.convoyBodies(game).first { $0.physical?.catalogueShipID == "SH150" })
    #expect(restored.energy == 37 && restored.physical?.npc?.resources?.frontShield == 7)
    let planet = try #require(game.celestials.first { $0.kind == .planet })
    #expect(
      (game.commander.flightSimulation.pose.systemPoint(planet.position) - first.orbit.anchor.center)
        .length < 1e-8)
  }

  @Test func actualTravelParksBeforeLedgerClearAndReturningCannotCloneSurvivors() throws {
    var game = Game(executive: false)
    game.commander.galaxy = 7
    game.commander.system = 8
    game.systems = Universe.systemsIncludingPlugh(number: 7)
    game.nativeCrimboLifecycleAvailable = true
    game.launch()
    let first = try #require(game.commander.savedCrimboState)
    game.selectedSystem = 9
    game.arrive()
    #expect(game.commander.system == 9)
    let parked = try #require(game.commander.savedCrimboState)
    #expect(parked.members.allSatisfy { if case .parked = $0.ownership { true } else { false } })
    let phase = parked.orbit.phase
    let originals = parked.members.map { $0.ownership.logical }
    game.tick(delta: 0.1)
    #expect(game.commander.savedCrimboState == parked)
    game.selectedSystem = 8
    game.arrive()
    #expect(game.commander.system == 8 && CrimboFixture.convoyBodies(game).count == 7)
    let returned = try #require(game.commander.savedCrimboState)
    #expect(returned.provider == first.provider && returned.manifest == first.manifest)
    #expect(
      returned.members.map { $0.ownership.logical } == originals && returned.orbit.phase == phase)
    #expect(returned.members.allSatisfy { if case .live = $0.ownership { true } else { false } })
  }

  @Test func productionGateRefusesDecodedPopulatedRegistryAtAutomaticEntry() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let encoded = try JSONEncoder().encode(game.commander)
    game.commander = try JSONDecoder().decode(Commander.self, from: encoded)
    game.nativeCrimboLifecycleAvailable = false
    let registry = game.commander.savedCrimboState
    let members = game.bodies.compactMap { $0.physical?.identity }
    #expect(!Game(executive: false).nativeCrimboLifecycleAvailable)
    #expect(members.allSatisfy { !game.isNativeCrimboMember($0) })
    try game.prepareNativeCrimboVisit()
    game.advanceGameplayEncounters(delta: 0.1)
    #expect(game.commander.savedCrimboState == registry)
    #expect(game.nativeCrimboMotionSample == nil)
    #expect(game.nativeCrimboDefenceIntents().isEmpty)
    #expect(try game.nativeProviderMissionFacts(instance: nil) == nil)
    let serialized = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander)) as? [String: Any])
    #expect(serialized["nativeCrimboLifecycleAvailable"] == nil)
  }

  @Test func absentOriginalFreezesWhileUnownedSameCatalogueNPCKeepsCoasting() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    #expect(game.persistNPCStates().isEmpty)
    let santa = try #require(
      CrimboFixture.convoyBodies(game).first { $0.physical?.catalogueShipID == "SH150" }?.physical?
        .identity)
    let logical = try #require(game.commander.npcPersistence.logicalIdentity(for: santa))
    game.commander.npcPersistence.cull(actor: santa)
    game.bodies.removeAll { $0.physical?.identity == santa }
    let before = try #require(game.commander.npcPersistence.snapshot(for: logical))
    let unownedActor = try #require(game.commander.flightSimulation.allocateActor())
    let unowned = try CrimboFixture.snapshot(
      entity: unownedActor.entity, slot: 0,
      visit: unownedActor.visit, time: game.commander.flightSimulation.physicalTime)
    #expect(
      game.commander.npcPersistence.capture(unowned, protection: .init())
        == .registered(unowned.actor))
    game.commander.npcPersistence.cull(actor: unowned.actor)
    game.commander.flightSimulation.advancePhysicalTime(50)
    game.advanceUnboundNPCs()
    let coasted = try #require(game.commander.npcPersistence.snapshot(for: unowned.actor))
    #expect(coasted.position == unowned.position + unowned.velocity * 50)
    #expect(coasted.energy > unowned.energy)
    let after = try #require(game.commander.npcPersistence.snapshot(for: logical))
    #expect(after.position == before.position && after.energy == before.energy)
    #expect(after.missiles == before.missiles && after.laserCooldown == before.laserCooldown)
    #expect(after.npc.resources == before.npc.resources)
    #expect(after.physicalTime == game.commander.flightSimulation.physicalTime)
    #expect(game.commander.savedCrimboState?.members[6].ownership.logical?.firstActor == logical)
  }

  @Test func galacticArrivalFailureRollsBackConsumedDriveFuelAndOriginalCustody() throws {
    var game = Game(executive: false)
    game.commander.galaxy = 6
    game.commander.system = 8
    game.systems = Universe.systemsIncludingPlugh(number: 6)
    game.nativeCrimboLifecycleAvailable = true
    game.launch()
    let owner = try #require(game.commander.equipmentOwnerID)
    let registry = try CrimboFixture.registry(owner: owner)
    let actual = registry.orbit.anchor
    let mismatched = try OrbitFormationState(
      incarnation: registry.provider.incarnation,
      anchor: .init(
        identity: actual.identity, center: actual.center + .init(1, 0, 0), basis: actual.basis,
        planetRadius: actual.planetRadius, orbitRadius: actual.orbitRadius,
        surfaceClearance: actual.surfaceClearance),
      configuration: registry.orbit.configuration, phase: registry.orbit.phase)
    var invalidArrival = registry
    invalidArrival.orbit = mismatched
    // Deliberate actual-arrival boundary failure; this value is not a valid G1-loaded native world.
    let allocated = try #require(game.commander.flightSimulation.allocateSpawn())
    #expect(allocated >= invalidArrival.spawnSequence)
    game.commander.savedCrimboState = invalidArrival
    try game.commander.grantEquipment(
      "Galactic Hyperdrive", at: .utility(.galacticHyperdrive),
      provenance: .grant("arrival-rollback-fixture"))
    game.commander.fuel = 11
    game.commander.cargo[CommodityIdentity.food.rawValue] = 7
    let before = game.commander
    let bodies = game.bodies
    game.galacticJump()
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.commander.galaxy == 6 && game.commander.system == 8 && game.commander.fuel == 11)
    #expect(game.commander.equipment.contains("Galactic Hyperdrive"))
    #expect(game.commander.cargo[CommodityIdentity.food.rawValue] == 7)
    #expect(game.commander.savedCrimboState == before.savedCrimboState)
  }

  @Test func failedVisitProjectionCannotPublishPartialParkedClockRebase() throws {
    var game = Game(executive: false)
    game.commander.galaxy = 7
    game.commander.system = 8
    game.systems = Universe.systemsIncludingPlugh(number: 7)
    game.nativeCrimboLifecycleAvailable = true
    game.launch()
    let actors = Set(CrimboFixture.convoyBodies(game).compactMap { $0.physical?.identity })
    try game.parkNativeCrimboBeforeDeparture()
    // Continue preparing an unpublished departure/return fixture, retaining the actual main station.
    game.bodies.removeAll { $0.physical.map { actors.contains($0.identity) } ?? false }
    var registry = try #require(game.commander.savedCrimboState)
    let orbit = registry.orbit
    registry.orbit = try .init(
      incarnation: orbit.incarnation,
      anchor: .init(
        identity: orbit.anchor.identity, center: orbit.anchor.center + .init(1, 0, 0),
        basis: orbit.anchor.basis, planetRadius: orbit.anchor.planetRadius,
        orbitRadius: orbit.anchor.orbitRadius, surfaceClearance: orbit.anchor.surfaceClearance),
      configuration: orbit.configuration, phase: orbit.phase)
    game.commander.savedCrimboState = registry
    game.commander.flightSimulation.advancePhysicalTime(200)
    let before = game.commander
    let bodies = game.bodies
    #expect(throws: NativeCrimboError.invalidMotion) { try game.prepareNativeCrimboVisit() }
    #expect(game.commander == before && game.bodies == bodies)
  }

}
