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

}
