import Foundation
import Testing

@testable import EliteCore

private func combatRequire<T>(_ value: T?) throws -> T {
  try #require(value)
}

private func combatGame(position: Vector3 = .init(0, 0, -3000)) -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.speed = 0
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  game.commander.flightSimulation.pose.position = position
  return game
}

@discardableResult
private func combatBody(
  _ game: inout Game, id: Int = 10, hull: Hull = .cobra, role: NPCRole? = .trader,
  legal: LegalRecord = .init(), position: Vector3 = .init(0, 0, 1000), energy: Double = 40
) throws -> ActorIdentity {
  let identity = try combatRequire(game.commander.flightSimulation.allocateActor())
  var body = SpaceBody(id: id, hull: hull, position: position)
  body.energy = energy
  body.physical = .init(
    identity: identity, population: role == .police ? .police : .civilian,
    npc: role.map {
      .init(role: $0, legal: legal, origin: game.systemIdentity, destination: game.systemIdentity)
    })
  game.bodies.append(body)
  return identity
}

private func combatPlayerOrigin(_ game: inout Game) throws -> AttackOrigin {
  let player = try combatRequire(game.commander.flightSimulation.player)
  return try combatRequire(game.makeAttackOrigin(owner: player))
}

private func combatBodyHit(_ game: Game, id: Int = 10) throws -> GameplayHit {
  let body = try combatRequire(game.bodies.first { $0.id == id })
  return .init(target: .body(id), distance: body.position.length, point: body.position)
}

struct GameplayCombatTests {
  @Test(arguments: [250, Int.max])
  func legalPenaltiesSaturateWithoutOverflowOrWeakeningLegacyRecords(_ initial: Int) throws {
    var game = combatGame()
    game.commander.legal = initial
    try combatBody(&game)
    let origin = try combatPlayerOrigin(&game)
    let hit = try combatBodyHit(game)
    game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 50, laser: .pulse)
    #expect(game.commander.legal == max(initial, 255))
  }

  @Test func cleanHitIsRecordedBeforeRetaliationAndMurderGetsNoHostileBounty() throws {
    var game = combatGame()
    let trader = try combatBody(&game)
    let origin = try combatPlayerOrigin(&game)
    let hit = try combatBodyHit(game)
    let incident = try combatRequire(
      game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 10, laser: .pulse))
    #expect(incident.victimLegalBeforeAttack == LegalRecord() && incident.victim == trader)
    #expect(game.commander.legal == 8 && game.bodies[0].energy == 30 && game.bodies[0].hostile)
    #expect(game.bodies[0].physical?.npc?.legal == LegalRecord())
    #expect(game.bodies[0].physical?.npc?.firstAggressor == origin.owner)
    #expect(game.bodies[0].physical?.npc?.intention == .engage(origin.owner))
    #expect(game.commander.stationSecurity.phase == .investigating)
    let retaliation = try combatRequire(game.makeAttackOrigin(owner: trader))
    game.applyCombatHit(
      .init(target: .player, distance: 1, point: .init(0, 0, 1)), origin: retaliation, kind: .laser,
      damage: 5)
    #expect(game.bodies[0].physical?.npc?.legal == LegalRecord())
    game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 50)
    #expect(
      game.commander.legal == 40 && game.commander.kills == 1 && game.commander.credits == 1000)
    #expect(game.bodies[0].energy == 0 && game.bodies[0].physical?.deathOrigin == origin)
    #expect(game.bodies[0].destroyedByPlayer == true)
    #expect(game.applyCombatHit(hit, origin: retaliation, kind: .laser, damage: 50) == nil)
    game.recordCombat(
      origin: origin, kind: .laser, outcome: .destruction, target: hit.target,
      worldPosition: incident.position)
    #expect(
      game.commander.kills == 1 && game.commander.credits == 1000 && game.commander.legal == 40)
    #expect(game.bodies.count == 1 && game.bodies[0].physical?.deathOrigin == origin)
  }

  @Test(arguments: [false, true])
  func knownBountyAndImmediateDefenceCreditOneKillAndRankChange(_ insideZone: Bool) throws {
    var game = combatGame(position: .init(0, 0, insideZone ? -500 : -3000))
    game.commander.kills = 7
    let pirate = try combatBody(
      &game, role: .pirate, legal: .init(value: 70, bountyTenths: 750), position: .init(0, 0, -100),
      energy: 10)
    if insideZone {
      let attack = try combatRequire(game.makeAttackOrigin(owner: pirate))
      game.applyCombatHit(
        .init(target: .player, distance: 1, point: .init(0, 0, -1)), origin: attack, kind: .laser,
        damage: 1)
    }
    let origin = try combatPlayerOrigin(&game)
    let hit = try combatBodyHit(game)
    game.applyCombatHit(hit, origin: origin, kind: .missile, damage: 20)
    #expect(
      game.commander.legal == 0 && game.commander.credits == 1750 && game.commander.kills == 8)
    #expect(game.commander.rank == "Mostly Harmless" && game.message == "RIGHT ON, COMMANDER")
    game.recordCombat(
      origin: origin, kind: .missile, outcome: .destruction, target: hit.target,
      worldPosition: game.commander.flightSimulation.pose.systemPoint(hit.point))
    #expect(game.commander.credits == 1750 && game.commander.kills == 8)
  }

  @Test func policeAndInvulnerableStationUseSpecialisedPenaltiesAndVerifiedAlarm() throws {
    var game = combatGame()
    try combatBody(&game, hull: .viper, role: .police, energy: 10)
    let player = try combatPlayerOrigin(&game)
    game.applyCombatHit(try combatBodyHit(game), origin: player, kind: .plasma, damage: 10)
    #expect(game.commander.legal == 96 && game.commander.credits == 1000)
    let stationPosition = game.commander.flightSimulation.pose.shipPoint(.init(0, 0, 0))
    game.bodies.append(.init(id: 0, hull: .station, position: stationPosition))
    game.ensurePhysicalActors()
    let stationEnergy = try combatRequire(game.bodies.last?.energy)
    let stationHit = try combatBodyHit(game, id: 0)
    game.applyCombatHit(stationHit, origin: player, kind: .laser, damage: 100000)
    game.applyCombatHit(stationHit, origin: player, kind: .missile, damage: 100000)
    #expect(game.commander.legal == 160 && game.commander.stationSecurity.phase == .alarm)
    #expect(
      game.bodies.last?.energy == stationEnergy && game.bodies.last?.physical?.deathOrigin == nil)
    game.commander.flightSimulation.advancePhysicalTime(4)
    let context = try combatRequire(game.gameplayContext())
    let plan = game.commander.stationSecurity.advance(context: context)
    #expect(plan.encounters.batches.flatMap(\.requests).count == 3)
    #expect(game.commander.kills == 1 && game.bodies.count == 2)
  }

  @Test func targetedMissileChargesBeforeDamageAndKeepsItsOriginalVictimEvidenceUntilImpact() throws
  {
    var game = combatGame()
    try combatBody(&game)
    let ordnance = try combatRequire(game.commander.flightSimulation.allocateActor())
    let player = try combatRequire(game.commander.flightSimulation.player)
    let origin = try combatRequire(game.makeAttackOrigin(owner: player, ordnance: ordnance))
    let hit = try combatBodyHit(game)
    let launchPosition = game.commander.flightSimulation.pose.position
    let launch = try combatRequire(
      game.recordCombat(
        origin: origin, kind: .missile, outcome: .targetedLaunch, target: hit.target,
        worldPosition: game.commander.flightSimulation.pose.systemPoint(hit.point),
        emissionPosition: launchPosition))
    #expect(launch.victimLegalBeforeAttack == LegalRecord())
    #expect(game.commander.legal == 8 && game.bodies[0].energy == 40)
    game.commander.flightSimulation.advancePhysicalTime(31)
    game.bodies[0].physical?.npc?.legal = .init(value: 64, bountyTenths: 9999)
    game.applyCombatHit(
      hit, origin: origin, kind: .missile, damage: 40, emissionPosition: launchPosition)
    #expect(game.commander.legal == 40 && game.commander.credits == 1000)
    #expect(game.commander.kills == 1 && game.bodies[0].physical?.deathOrigin == origin)
  }

  @Test func absentOriginalNPCShooterStillOwnsMissileDamageAndPlayerShieldsApplyInOrder() throws {
    var game = combatGame()
    let shooter = try combatBody(&game)
    let ordnance = try combatRequire(game.commander.flightSimulation.allocateActor())
    let origin = try combatRequire(
      game.makeAttackOrigin(owner: shooter, ordnance: ordnance, sourcePart: "launcher"))
    game.bodies = []
    game.energy = 30
    game.frontShield = 5
    game.rearShield = 10
    let front = GameplayHit(target: .player, distance: 1, point: .init(0, 0, 1))
    let first = try combatRequire(
      game.applyCombatHit(front, origin: origin, kind: .missile, damage: 12))
    #expect(
      first.origin.owner == shooter && first.origin.ordnance == ordnance
        && first.origin.sourcePart == "launcher")
    #expect(game.energy == 23 && game.frontShield == 0 && game.rearShield == 10)
    let rear = GameplayHit(target: .player, distance: 1, point: .init(0, 0, -1))
    game.applyCombatHit(rear, origin: origin, kind: .missile, damage: 30, energyMultiplier: 2)
    #expect(game.energy == -17 && game.frontShield == 0 && game.rearShield == 0)
    #expect(
      game.commander.legal == 0 && game.commander.kills == 0 && game.commander.credits == 1000)
    #expect(game.applyCombatHit(rear, origin: origin, kind: .missile, damage: 30) == nil)
  }

  @Test func interceptedOrdnanceNeverBecomesAShipKillOrBounty() throws {
    var game = combatGame()
    let shooter = try combatBody(&game, id: 11, role: .pirate)
    let missile = try combatBody(&game, hull: .missile, role: nil, energy: 1)
    let incoming = try combatRequire(game.makeAttackOrigin(owner: shooter, ordnance: missile))
    game.bodies[1].physical?.attackOrigin = incoming
    let player = try combatPlayerOrigin(&game)
    let hit = try combatBodyHit(game)
    let incident = try combatRequire(
      game.applyCombatHit(hit, origin: player, kind: .laser, damage: 15))
    #expect(incident.outcome == .ordnanceInterception && game.bodies[1].energy == 0)
    #expect(
      game.commander.legal == 0 && game.commander.credits == 1000 && game.commander.kills == 0)
    #expect(game.bodies[1].physical?.deathOrigin == player && game.bodies.count == 2)
  }

  @Test func npcAssaultAttributesLegalDamageAndDefenceToItsActualVictimWithoutPlayerCredit() throws
  {
    var game = combatGame()
    let attacker = try combatBody(&game, id: 11, role: .pirate)
    try combatBody(&game, energy: 10)
    let origin = try combatRequire(game.makeAttackOrigin(owner: attacker))
    game.applyCombatHit(try combatBodyHit(game), origin: origin, kind: .laser, damage: 10)
    #expect(game.bodies[0].physical?.npc?.legal.value == 40)
    #expect(game.bodies[1].physical?.npc?.intention == .engage(attacker))
    #expect(game.bodies[1].physical?.npc?.firstAggressor == attacker)
    #expect(!game.bodies[1].hostile && game.bodies[1].destroyedByPlayer == false)
    #expect(game.bodies[1].physical?.deathOrigin == origin)
    #expect(
      game.commander.legal == 0 && game.commander.kills == 0 && game.commander.credits == 1000)
    #expect(game.commander.stationSecurity.phase == .investigating)
  }

  @Test func lawfulPoliceFireOnWantedPlayerInsideStationZoneDoesNotCreateRoguePolice() throws {
    var game = combatGame(position: .init(0, 0, -500))
    game.commander.legal = 64
    let officer = try combatBody(&game, hull: .viper, role: .police)
    let origin = try combatRequire(game.makeAttackOrigin(owner: officer))
    game.applyCombatHit(
      .init(target: .player, distance: 1, point: .init(0, 0, 1)), origin: origin, kind: .laser,
      damage: 5)
    #expect(game.bodies[0].physical?.npc?.legal == LegalRecord())
    #expect(game.commander.stationSecurity.phase == .calm && game.commander.legal == 64)
    #expect(game.frontShield == 250 && game.energy == 256)
  }

  @Test(arguments: [LaserKind.mining, .pulse])
  func onlyMiningLaserExtractionPublishesOreFromTheActuallyHitRock(_ laser: LaserKind) throws {
    var game = combatGame()
    let rock = MiningRock(
      identity: .init(system: game.systemIdentity, field: 0, rock: 0),
      position: .init(100, 200, -1000), radius: 40, energy: 100)
    game.miningFields = [.init(position: rock.position, rocks: [rock])]
    try combatBody(
      &game, hull: .asteroid, role: nil,
      position: game.commander.flightSimulation.pose.shipPoint(rock.position), energy: rock.energy)
    game.bodies[0].physical?.rock = rock.identity
    let origin = try combatPlayerOrigin(&game)
    let hit = try combatBodyHit(game)
    let first = try combatRequire(
      game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 50, laser: laser, mount: .rear)
    )
    #expect(first.mount == .rear && first.laser == laser && first.victimPart == nil)
    #expect(
      game.bodies[0].energy == 50 && game.commander.miningLedger.remainingEnergy(for: rock) == 50)
    #expect(game.commander.miningLedger.pendingPayloads.isEmpty)
    game.applyCombatHit(hit, origin: origin, kind: .laser, damage: 50, laser: laser)
    #expect(game.bodies[0].energy == 0 && game.commander.miningLedger.isDepleted(rock.identity))
    #expect(game.commander.miningLedger.pendingPayloads.isEmpty == (laser != .mining))
    #expect(
      game.commander.legal == 0 && game.commander.kills == 0 && game.commander.credits == 1000)
    #expect(game.commander.cargo.allSatisfy { $0 == 0 } && game.bodies.count == 1)
  }

  @Test func pendingOreCapacityRefusalLeavesPhysicalRockAndDepletionUnchanged() throws {
    var game = combatGame()
    let origin = try combatPlayerOrigin(&game)
    for index in 0..<1000
    where game.commander.miningLedger.pendingPayloads.count < MiningLedger.maximumPending {
      let system = SystemIdentity(galaxy: 0, system: index / 48)
      if system == game.systemIdentity { continue }
      let rock = MiningRock(
        identity: .init(system: system, field: UInt16(index % 48 / 12), rock: UInt16(index % 12)),
        position: .init(0, 0, 0), radius: 40, energy: 1)
      let id = try combatRequire(game.commander.flightSimulation.allocateIncident())
      let incident = CombatIncident(
        id: id, physicalTime: 0, origin: origin, victim: nil, kind: .laser, outcome: .hit,
        position: rock.position, victimLegalBeforeAttack: nil, firstAggressor: nil, victimRole: nil,
        victimIsStation: false, laser: .mining)
      _ = game.commander.miningLedger.hit(rock: rock, incident: incident, damage: 1)
    }
    #expect(game.commander.miningLedger.pendingPayloads.count == MiningLedger.maximumPending)
    let rock = MiningRock(
      identity: .init(system: game.systemIdentity, field: 0, rock: 0), position: .init(0, 0, -2000),
      radius: 40, energy: 100)
    game.miningFields = [.init(position: rock.position, rocks: [rock])]
    try combatBody(&game, hull: .asteroid, role: nil, energy: rock.energy)
    game.bodies[0].physical?.rock = rock.identity
    game.applyCombatHit(
      try combatBodyHit(game), origin: origin, kind: .laser, damage: 100, laser: .mining)
    #expect(game.bodies[0].energy == rock.energy && game.bodies[0].physical?.deathOrigin == nil)
    #expect(!game.commander.miningLedger.isDepleted(rock.identity))
    #expect(game.commander.miningLedger.remainingEnergy(for: rock) == rock.energy)
  }

  @Test(arguments: [BlackjackTarget.bolts, .witness])
  func matchedActiveMissionUsesItsSourceRewardWithoutDispatchingRemovalEvents(
    _ role: BlackjackTarget
  ) throws {
    var game = combatGame()
    game.commander.galaxy = 1
    game.commander.system = role.system
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    var encounter = BlackjackEncounter(role: role, id: 10)
    encounter.body.position = .init(0, 0, 1000)
    encounter.body.energy = 10
    game.commander.blackjack.stage = role.requiredStage
    if role == .bolts {
      game.commander.blackjack.bolts = encounter
    } else {
      game.commander.blackjack.witness = encounter
    }
    game.bodies = [encounter.body]
    game.ensurePhysicalActors()
    game.bodies[0].physical?.npc?.legal = .init(value: 64, bountyTenths: 9999)
    let origin = try combatPlayerOrigin(&game)
    game.applyCombatHit(try combatBodyHit(game), origin: origin, kind: .laser, damage: 10)
    #expect(game.commander.credits == 1000 + role.bountyCredits * 10 && game.commander.kills == 1)
    #expect(game.commander.blackjack.stage == role.requiredStage && game.bodies.count == 1)
  }

  @Test func navalBombImmunityAndExplicitHuntEntitlementStaySeparateFromHullBounty() throws {
    var game = combatGame()
    game.commander.missionStage = .huntingConstrictor
    try combatBody(&game, hull: .constrictor, role: .mission, energy: 10)
    game.bodies[0].navalTarget = true
    let player = try combatPlayerOrigin(&game)
    let hit = try combatBodyHit(game)
    game.applyCombatHit(hit, origin: player, kind: .bomb, damage: 10000)
    #expect(game.bodies[0].energy == 10 && game.commander.kills == 0)
    game.applyCombatHit(hit, origin: player, kind: .laser, damage: 10, laser: .military)
    #expect(
      game.commander.legal == 0
        && game.commander.credits == 1000 + (Hull.constrictor.navalBounty ?? 0))
    #expect(game.commander.kills == 1 && game.commander.missionStage == .huntingConstrictor)
    var ordinary = combatGame()
    try combatBody(&ordinary, hull: .constrictor, role: .trader, energy: 10)
    let otherOrigin = try combatPlayerOrigin(&ordinary)
    ordinary.applyCombatHit(
      try combatBodyHit(ordinary), origin: otherOrigin, kind: .laser, damage: 10, laser: .military)
    #expect(ordinary.commander.legal == 40 && ordinary.commander.credits == 1000)
  }

  @Test func originCountersPersistAndInvalidOrStaleHitsCannotChangePhysicalState() throws {
    var game = combatGame()
    try combatBody(&game)
    let first = try combatPlayerOrigin(&game)
    game.commander = try JSONDecoder().decode(
      Commander.self, from: JSONEncoder().encode(game.commander))
    game.commander.legal = 23
    let next = try combatPlayerOrigin(&game)
    #expect(next.emissionID > first.emissionID && next.ownerLegalAtEmission.value == 23)
    #expect(first.ownerLegalAtEmission.value == 0)
    let hit = try combatBodyHit(game)
    for damage in [Double.nan, -Double.infinity, -1] {
      #expect(game.applyCombatHit(hit, origin: first, kind: .laser, damage: damage) == nil)
    }
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    #expect(game.applyCombatHit(hit, origin: first, kind: .laser, damage: 10) == nil)
    #expect(game.bodies[0].energy == 40 && game.commander.legal == 23)
    #expect(
      game.recordCombat(
        origin: next, kind: .laser, outcome: .hit, target: .body(999), worldPosition: .init(0, 0, 0)
      ) == nil)
  }
}
