import Foundation
import Testing

@testable import EliteCore

private func securityReport(
  _ id: UInt64 = 1, offender: ActorIdentity = crimeTestID(1), time: Double = 0,
  kind: CrimeKind = .stationAttack, position: Vector3 = .init(0, 0, 500)
) -> VerifiedCrimeReport {
  .init(
    incidentID: id, offender: offender, victim: crimeTestID(0), kind: kind,
    physicalTime: time, position: position)
}

private func securityPolice(
  _ entity: UInt64, position: Vector3 = .init(0, 0, -500), visit: UInt64 = 1
) -> ActorSnapshot {
  crimeTestActor(entity, position: position, role: .police, hull: .viper, visit: visit)
}

private func securityAdmitted(_ plan: SecurityPlan, startingAt: UInt64 = 10) -> [SpawnReceipt] {
  plan.encounters.batches.flatMap(\.requests).enumerated().map {
    .init(
      request: $0.element.identity, actor: crimeTestID(startingAt + UInt64($0.offset)), refusal: nil
    )
  }
}

struct StationSecurityTests {
  @Test func ordinaryReportsDelayGovernmentDependentDispatchAndExistingPatrolsRespondImmediately() {
    for (government, delay) in [(1, 8.0), (7, 4.0)] {
      var security = StationSecurity()
      security.receive(securityReport(kind: .assault))
      let before = security.advance(context: crimeTestContext(3.99, government: government))
      #expect(before.encounters.batches.isEmpty && before.notices == [.distressReceived])
      let launched = security.advance(context: crimeTestContext(delay, government: government))
      #expect(launched.encounters.batches.flatMap(\.requests).count == 2)
      #expect(launched.notices.isEmpty)
    }
    var security = StationSecurity()
    let pirate = crimeTestActor(2, legal: .init(value: 8, bountyTenths: 0))
    let officer = securityPolice(10)
    security.receive(
      securityReport(offender: pirate.identity, kind: .assault, position: pirate.position))
    let immediate = security.advance(context: crimeTestContext(0, actors: [pirate, officer]))
    #expect(
      immediate.encounters.intents == [
        .init(actor: officer.identity, action: .engage(pirate.identity))
      ])
    #expect(!immediate.encounters.intents.contains { $0.action == .engage(crimeTestID(1)) })
  }

  @Test func stationAlarmLaunchesThreeThenBoundedWavesAtTheActualExit() {
    var security = StationSecurity()
    let player = crimeTestActor(
      1, position: .init(0, 0, 500), role: nil, legal: .init(value: 64, bountyTenths: 0))
    security.receive(securityReport())
    let initial = security.advance(context: crimeTestContext(0, player: player))
    #expect(initial.notices == [.stationAlarm] && initial.encounters.batches.isEmpty)
    #expect(security.phase == .alarm)
    var first = security.advance(context: crimeTestContext(4, player: player))
    #expect(
      first.encounters.batches.flatMap(\.requests).count == 3 && security.phase == .reinforcing)
    let firstKeys = first.encounters.batches.flatMap(\.requests).map(\.identity)
    security.receive(securityReport(2, time: 4.1))
    first = security.advance(context: crimeTestContext(4.2, player: player))
    #expect(first.encounters.batches.flatMap(\.requests).map(\.identity) == firstKeys)
    #expect(first.notices.isEmpty)
    for request in first.encounters.batches.flatMap(\.requests) {
      #expect(
        request.population == .police && request.priority == .police && request.hull == .viper)
      #expect(request.identity.producer == .security && request.npc?.role == .police)
      #expect(request.position.z < -200 && (request.position - player.position).length > 500)
      #expect(request.velocity == .init(0, 0, -180))
    }
    var officers = [ActorSnapshot]()
    for (time, expected) in [(4.2, 3), (14.0, 2), (24.0, 2), (34.0, 1)] {
      if time > 10 {
        security.receive(securityReport(UInt64(time), time: time - 0.1))
      }
      let plan = security.advance(context: crimeTestContext(time, player: player, actors: officers))
      let receipts = securityAdmitted(plan, startingAt: UInt64(10 + officers.count))
      #expect(receipts.count == expected)
      security.acknowledge(receipts: receipts)
      officers += receipts.map { securityPolice($0.actor!.entity) }
    }
    let capped = security.advance(context: crimeTestContext(44, player: player, actors: officers))
    #expect(officers.count == 8 && capped.encounters.batches.isEmpty)
  }

  @Test func refusedAdmissionPersistsWithoutRepeatedLaunchKeysOrBudgetOverflow() throws {
    var security = StationSecurity()
    security.receive(securityReport())
    let initial = security.advance(context: crimeTestContext(4, budget: .init(total: 128)))
    let keys = initial.encounters.batches.flatMap(\.requests).map(\.identity)
    security.acknowledge(
      receipts: keys.map { .init(request: $0, actor: nil, refusal: .reservedCapacity) })
    security = try JSONDecoder().decode(StationSecurity.self, from: JSONEncoder().encode(security))
    let retry = security.advance(context: crimeTestContext(5, budget: .init(total: 128)))
    #expect(retry.encounters.batches.flatMap(\.requests).map(\.identity) == keys)
    let caughtUp = security.advance(context: crimeTestContext(1_000_000_000))
    #expect(caughtUp.encounters.batches.flatMap(\.requests).count <= 8)
  }

  @Test func isolatedStationHitDoesNotCreateContinuingReinforcementWaves() {
    var security = StationSecurity()
    security.receive(securityReport())
    let initial = security.advance(context: crimeTestContext(4))
    let receipts = securityAdmitted(initial)
    #expect(receipts.count == 3)
    security.acknowledge(receipts: receipts)
    let officers = receipts.map { securityPolice($0.actor!.entity) }
    for time in [14.0, 24, 34, 100] {
      let quiet = security.advance(context: crimeTestContext(time, actors: officers))
      #expect(quiet.encounters.batches.isEmpty)
    }
  }

  @Test func stationScheduleIsIndependentOfTickPartitionAndSurvivesSaveReload() throws {
    var oneStep = StationSecurity()
    var partitioned = StationSecurity()
    oneStep.receive(securityReport())
    partitioned.receive(securityReport())
    _ = oneStep.advance(context: crimeTestContext(34))
    for time in [0.0, 1, 4, 9, 14, 17, 24, 30, 34] {
      _ = partitioned.advance(context: crimeTestContext(time))
      partitioned = try JSONDecoder().decode(
        StationSecurity.self, from: JSONEncoder().encode(partitioned))
    }
    #expect(oneStep == partitioned)
  }

  @Test func policeSearchLastKnownPositionThenReturnWithoutOmniscientTracking() {
    var security = StationSecurity()
    let officer = securityPolice(10)
    let wanted = crimeTestActor(2, legal: .init(value: 70, bountyTenths: 500))
    let contact = security.advance(context: crimeTestContext(0, actors: [officer, wanted]))
    #expect(contact.encounters.intents.first?.action == .engage(wanted.identity))
    let disappeared = security.advance(context: crimeTestContext(20, actors: [officer]))
    #expect(security.assignments.first?.phase == .search)
    #expect(
      disappeared.encounters.intents.first?.action
        == .navigate(position: wanted.position, speedUnitsPerSecond: 240))
    let returned = security.advance(context: crimeTestContext(60, actors: [officer]))
    #expect(security.assignments.first?.phase == .returning)
    #expect(returned.encounters.intents.first?.action == .dock(crimeTestID(0)))
    let stillReturning = security.advance(context: crimeTestContext(60.1, actors: [officer]))
    #expect(stillReturning.encounters.intents.first?.action == .dock(crimeTestID(0)))
    let outside = securityPolice(10, position: .init(0, 0, 21_000))
    let leashed = security.advance(context: crimeTestContext(61, actors: [outside, wanted]))
    #expect(leashed.encounters.intents.first?.action == .dock(crimeTestID(0)))
    var unaware = StationSecurity()
    let remote = crimeTestActor(
      3, position: .init(0, 0, 30_000), legal: .init(value: 70, bountyTenths: 500))
    let deep = unaware.advance(context: crimeTestContext(0, actors: [officer, remote]))
    #expect(!deep.encounters.intents.contains { $0.action == .engage(remote.identity) })
  }

  @Test func reacquiringActualContactRestartsTheLostContactSearchClock() {
    var security = StationSecurity()
    let officer = securityPolice(10)
    let fugitive = crimeTestActor(2, legal: .init(value: 70, bountyTenths: 500))
    _ = security.advance(context: crimeTestContext(0, actors: [officer, fugitive]))
    _ = security.advance(context: crimeTestContext(20, actors: [officer]))
    let contact = security.advance(context: crimeTestContext(40, actors: [officer, fugitive]))
    #expect(contact.encounters.intents.first?.action == .engage(fugitive.identity))
    _ = security.advance(context: crimeTestContext(70, actors: [officer]))
    #expect(security.assignments.first?.phase == .search)
    let returned = security.advance(context: crimeTestContext(100, actors: [officer]))
    #expect(returned.encounters.intents.first?.action == .dock(crimeTestID(0)))
  }

  @Test func reportedOffenderIsInvestigatedBeforeActualContactRatherThanTrackedOmnisciently() {
    var security = StationSecurity()
    let officer = securityPolice(10)
    let offender = crimeTestActor(2, position: .init(0, 0, 9000))
    let lastKnown = Vector3(0, 0, 7000)
    security.receive(
      securityReport(offender: offender.identity, kind: .assault, position: lastKnown))
    let investigation = security.advance(context: crimeTestContext(0, actors: [officer, offender]))
    #expect(security.assignments.first?.phase == .investigate)
    #expect(
      investigation.encounters.intents.first?.action
        == .navigate(position: lastKnown, speedUnitsPerSecond: 240))
    _ = security.advance(context: crimeTestContext(10, actors: [officer, offender]))
    #expect(security.assignments.first?.phase == .investigate)
  }

  @Test func quietRetreatEndsAlarmButLegalStatusAndFugitiveDockingRemain() {
    var security = StationSecurity()
    let player = crimeTestActor(
      1, position: .init(0, 0, 15000), role: nil, legal: .init(value: 64, bountyTenths: 0))
    security.receive(securityReport())
    _ = security.advance(context: crimeTestContext(0, player: player))
    let quiet = security.advance(context: crimeTestContext(30, player: player))
    #expect(security.phase == .cooldown && quiet.notices == [.securityCooldown])
    #expect(
      !security.dockingPermission(
        for: player.identity, context: crimeTestContext(30, player: player)
      ).allowed)
    _ = security.advance(context: crimeTestContext(40, player: player))
    #expect(security.phase == .calm)
    let offender = crimeTestActor(1, role: nil, legal: .init(value: 8, bountyTenths: 0))
    let permission = security.dockingPermission(
      for: offender.identity, context: crimeTestContext(40, player: offender))
    #expect(permission.allowed && permission.notice == .offenderDockingWarning)
    let clean = crimeTestActor(1, role: nil)
    #expect(
      security.dockingPermission(for: clean.identity, context: crimeTestContext(40, player: clean))
        .notice == nil)
  }

  @Test func anarchyHasNoRoutinePatrolButItsStationStillDefendsItself() {
    var security = StationSecurity()
    #expect(
      security.advance(context: crimeTestContext(0, government: 0)).encounters.batches.isEmpty)
    security.receive(securityReport(kind: .assault))
    let ordinary = security.advance(context: crimeTestContext(8, government: 0))
    #expect(ordinary.encounters.batches.isEmpty && ordinary.notices.isEmpty)
    security.receive(securityReport(2, time: 9))
    let station = security.advance(context: crimeTestContext(13, government: 0))
    #expect(
      station.encounters.batches.flatMap(\.requests).count == 3
        && station.notices == [.stationAlarm])
  }

  @Test func protectedMissionActorsAndRecycledVisitIDsNeverBecomeOrdinaryPoliceTargets() {
    var security = StationSecurity()
    let officer = securityPolice(10)
    let wanted = crimeTestActor(2, legal: .init(value: 70, bountyTenths: 500))
    var protection = MissionProtection()
    protection.protectedActors.insert(wanted.identity)
    let protected = security.advance(
      context: crimeTestContext(0, actors: [officer, wanted], protection: protection))
    #expect(!protected.encounters.intents.contains { $0.action == .engage(wanted.identity) })
    _ = security.advance(context: crimeTestContext(1, actors: [officer, wanted]))
    let newOfficer = securityPolice(10, visit: 2)
    let cleanReplacement = crimeTestActor(2, visit: 2)
    let newVisit = security.advance(
      context: crimeTestContext(2, actors: [newOfficer, cleanReplacement], visit: 2))
    #expect(
      !newVisit.encounters.intents.contains { $0.action == .engage(cleanReplacement.identity) })
    #expect(security.assignments.allSatisfy { $0.target == nil })
  }

  @Test func playerAlarmRebindPreservesDockingDenialAcrossPhysicalVisitIdentity() throws {
    var security = StationSecurity()
    security.receive(securityReport())
    _ = security.advance(context: crimeTestContext(1))
    security = try JSONDecoder().decode(StationSecurity.self, from: JSONEncoder().encode(security))
    security.rebindPlayer(from: crimeTestID(1), to: crimeTestID(1, visit: 2))
    let context = crimeTestContext(2, visit: 2)
    _ = security.advance(context: context)
    #expect(!security.dockingPermission(for: context.player.identity, context: context).allowed)
  }
}

extension StationSecurityTests {
  @Test(arguments: [
    "current", "wanted-player", "outside-zone", "report-outside-zone", "foreign-source",
    "unjoined", "stale-visit", "dead-source", "old-report", "unreported",
  ])
  func anarchyStationDefendsOnlyAnActuallyReportedCurrentCleanVisitor(condition: String) {
    let player = crimeTestActor(
      1, position: .init(0, 0, condition == "outside-zone" ? 1201 : 500), role: nil,
      legal: .init(value: condition == "wanted-player" ? 1 : 0))
    let offender = crimeTestActor(
      2, position: .init(300, 0, 800), legal: .init(value: 8),
      visit: condition == "stale-visit" ? 2 : 1,
      intention: .engage(player.identity), energy: condition == "dead-source" ? 0 : 100)
    var security = StationSecurity()
    if condition != "unreported" {
      security.receive(
        .init(
          incidentID: 1,
          offender: condition == "foreign-source"
            ? ActorIdentity(system: .init(galaxy: 0, system: 8), visit: 1, entity: 2)
            : offender.identity,
          victim: player.identity, kind: .assault, physicalTime: 0,
          position: condition == "report-outside-zone" ? .init(0, 0, 1201) : player.position))
    }
    let context = crimeTestContext(
      condition == "old-report" ? 30 : 0.1, player: player,
      actors: condition == "unjoined" ? [] : [offender], government: 0)
    let plan = security.advance(context: context)
    let requests = plan.encounters.batches.flatMap(\.requests)
    #expect(requests.count == (condition == "current" ? 2 : 0))
    #expect(requests.allSatisfy { $0.population == .police && $0.priority == .police })
    #expect(!plan.encounters.intents.contains { $0.action == .engage(player.identity) })
    // A refused wave keeps exactly its queued identities; reads cannot mint reinforcements.
    let repeated = security.advance(context: context)
    #expect(
      repeated.encounters.batches.flatMap(\.requests).map(\.identity) == requests.map(\.identity))
  }
}

extension StationSecurityTests {
  @Test func actualAnarchyStationReceivesNativeAssaultAndAdmitsPoliceAgainstItsRealSource() throws {
    var game = Game(executive: false)
    game.commander.system = 27
    game.selectedSystem = 27
    game.screen = .status
    try #require(game.currentSystem.government == 0 && game.commander.legal == 0)
    game.launch()
    game.speed = 0
    let station = try #require(game.commander.flightSimulation.anchors?.station)
    NativePagedSalvageFixture.moveObserver(
      &game, to: .init(position: station.position + .init(0, 0, -1000)))
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: .init(100, 0, -500), hostile: true))
    game.ensurePhysicalActors()
    let source = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    let shields = game.frontShield + game.rearShield
    game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
    try #require(game.frontShield + game.rearShield < shields)
    let observed = try #require(game.gameplayContext())
    try #require(
      game.commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: source, against: player, context: observed))
    let response = game.commander.stationSecurity.advance(context: observed)
    try #require(response.encounters.batches.flatMap(\.requests).count == 2)
    let receipts = game.admitEncounterPlan(response.encounters)
    let officers = Set(receipts.compactMap(\.actor))
    try #require(officers.count == 2 && receipts.allSatisfy { $0.refusal == nil })
    game.commander.stationSecurity.acknowledge(receipts: receipts)
    let current = try #require(game.gameplayContext())
    let pursuit = game.commander.stationSecurity.advance(context: current)
    for actor in officers {
      let body = try #require(game.bodies.first { $0.physical?.identity == actor })
      #expect(body.hull == .viper && body.physical?.npc?.role == .police)
      #expect(body.energy > 0 && body.physical?.npc?.resources?.valid == true)
      #expect(
        pursuit.encounters.intents.contains { $0.actor == actor && $0.action == .engage(source) })
    }
    #expect(game.commander.legal == 0 && !game.docked)
    #expect(!pursuit.encounters.intents.contains { $0.action == .engage(player) })
  }
}
