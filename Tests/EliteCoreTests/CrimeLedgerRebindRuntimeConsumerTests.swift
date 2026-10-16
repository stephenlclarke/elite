import Foundation
import Testing

@testable import EliteCore

struct CrimeLedgerRebindRuntimeConsumerTests {
  @Test func delayedUnlawfulMissileChargesCurrentSurvivorAndTargetsCurrentAggressor() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.speed = 0
    game.bodies = []
    game.celestials = []
    game.miningFields = []
    game.salvageSites = []
    game.commander.npcPersistence = .init()
    let pose = game.commander.flightSimulation.pose
    let context = try #require(game.gameplayContext())
    var requests: [SpawnRequest] = []
    for (sequence, offset) in [(UInt64(701), Vector3(1000, 0, 2000)), (702, .init(0, 0, 3000))] {
      var npc = NPCState(role: .trader, origin: context.system, destination: context.system)
      npc.resources = NPCResources.stock(game.commander.performance)
      let position = pose.systemPoint(offset)
      npc.intention = .navigate(position: position, speedUnitsPerSecond: 0)
      requests.append(
        .init(
          identity: .init(
            system: context.system, visit: context.visit, sequence: sequence, member: 0),
          population: .civilian, hull: .cobra, position: position, orientation: .init(),
          velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil, priority: .ordinary,
          catalogueShipID: "SH023"))
    }
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: true)], intents: []))
    let shooter = try #require(receipts.first?.actor)
    let victim = try #require(receipts.last?.actor)
    let initialVictim = try #require(game.bodies.first { $0.physical?.identity == victim })
    let allocated = game.makeAttackOrigin(owner: shooter)
    let origin = try #require(allocated)
    // A real targeted-launch record freezes the judgement. The consumer under test is impact,
    // so this bounded fixture does not advance a homing projectile or invent a different target.
    let launch = game.recordCombat(
      origin: origin, kind: .missile, outcome: .targetedLaunch,
      target: .body(initialVictim.id), worldPosition: pose.systemPoint(initialVictim.position),
      emissionPosition: pose.systemPoint(.init(1000, 0, 2000)))
    #expect(launch?.origin == origin && launch?.victim == victim)
    let launchLegal = try #require(
      game.bodies.first { $0.physical?.identity == shooter }?.physical?.npc?.legal.value)
    #expect(launchLegal == 8)

    relocateConsumerObserver(&game, to: .init(position: pose.position + .init(0, 0, 45000)))
    game.tick(delta: 0.001)
    #expect(game.commander.npcPersistence.binding(for: shooter) == nil)
    #expect(game.commander.npcPersistence.binding(for: victim) == nil)
    relocateConsumerObserver(&game, to: pose)
    game.tick(delta: 0.001)
    let currentShooter = try #require(game.commander.npcPersistence.binding(for: shooter))
    let currentVictim = try #require(game.commander.npcPersistence.binding(for: victim))
    #expect(currentShooter != shooter && currentVictim != victim)
    #expect(game.commander.npcPersistence.count == 2)
    let body = try #require(game.bodies.first { $0.physical?.identity == currentVictim })
    let hit = GameplayHit(
      target: .body(body.id), distance: body.position.length, point: body.position)
    let impact = game.applyCombatHit(
      hit, origin: origin, kind: .missile, damage: 0.01,
      emissionPosition: pose.systemPoint(.init(1000, 0, 2000)))
    #expect(impact?.origin.owner == shooter && impact?.victim == currentVictim)
    let attacked = try #require(game.bodies.first { $0.physical?.identity == currentVictim })
    #expect(attacked.energy > 0)
    #expect(attacked.physical?.npc?.firstAggressor == currentShooter)
    #expect(attacked.physical?.npc?.intention == .engage(currentShooter))
    #expect(try latestReport(game.commander.stationSecurity)?.offender == currentShooter)

    let murder = game.applyCombatHit(
      hit, origin: origin, kind: .missile, damage: 10000,
      emissionPosition: pose.systemPoint(.init(1000, 0, 2000)))
    #expect(murder?.origin.owner == shooter)
    let dead = try #require(game.bodies.first { $0.physical?.identity == currentVictim })
    #expect(dead.energy == 0 && dead.physical?.deathOrigin?.owner == shooter)
    let offender = try #require(game.bodies.first { $0.physical?.identity == currentShooter })
    #expect(offender.physical?.npc?.legal.value == launchLegal + 32)
    let report = try #require(try latestReport(game.commander.stationSecurity))
    #expect(
      report.kind == .murder && report.offender == currentShooter && report.victim == currentVictim)
    let saved = try JSONEncoder().encode(game.commander.stationSecurity)
    let restored = try JSONDecoder().decode(StationSecurity.self, from: saved)
    #expect(try latestReport(restored) == report)
  }

  private func latestReport(_ security: StationSecurity) throws -> VerifiedCrimeReport? {
    struct Threat: Decodable { let report: VerifiedCrimeReport }
    struct Evidence: Decodable { let threats: [Threat] }
    let evidence = try JSONDecoder().decode(Evidence.self, from: JSONEncoder().encode(security))
    return evidence.threats.map(\.report).max { $0.incidentID < $1.incidentID }
  }

  private func relocateConsumerObserver(_ game: inout Game, to pose: ShipPose) {
    let old = game.commander.flightSimulation.pose
    for index in game.bodies.indices {
      game.bodies[index].position = pose.shipPoint(old.systemPoint(game.bodies[index].position))
      game.bodies[index].orientation.x = pose.shipVector(
        old.orientation.apply(game.bodies[index].orientation.x))
      game.bodies[index].orientation.y = pose.shipVector(
        old.orientation.apply(game.bodies[index].orientation.y))
      game.bodies[index].orientation.z = pose.shipVector(
        old.orientation.apply(game.bodies[index].orientation.z))
    }
    game.commander.flightSimulation.pose = pose
  }
}
