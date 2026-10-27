import Foundation
import Testing

@testable import EliteCore

let crimeTestSystem = SystemIdentity(galaxy: 0, system: 7)

func crimeTestID(_ entity: UInt64, visit: UInt64 = 1) -> ActorIdentity {
  .init(system: crimeTestSystem, visit: visit, entity: entity)
}

func crimeTestActor(
  _ entity: UInt64, position: Vector3 = .init(0, 0, 3000), role: NPCRole? = .trader,
  legal: LegalRecord = .init(), hull: Hull = .cobra, visit: UInt64 = 1,
  intention: NPCAction? = nil, energy: Double = 100
) -> ActorSnapshot {
  .init(
    identity: crimeTestID(entity, visit: visit), hull: hull, position: position,
    orientation: .init(), velocity: .init(0, 0, 0), energy: energy, maximumEnergy: 100,
    maximumSpeedUnitsPerSecond: 576, legal: legal,
    npc: role.map {
      .init(
        role: $0, legal: legal, intention: intention,
        origin: crimeTestSystem, destination: crimeTestSystem)
    },
    rock: nil, payload: nil)
}

func crimeTestContext(
  _ time: Double, player: ActorSnapshot? = nil, actors: [ActorSnapshot] = [],
  government: Int = 7, visit: UInt64 = 1, protection: MissionProtection = .init(),
  budget: AdmissionBudget = .init()
) -> EncounterContext {
  .init(
    system: crimeTestSystem, seed: 42, government: government, visit: visit, revision: 1,
    physicalTime: time,
    anchors: .init(
      system: crimeTestSystem,
      station: .init(
        identity: crimeTestID(0, visit: visit), position: .init(0, 0, 0), orientation: .init(),
        exitPosition: .init(0, 0, -90), exitDirection: .init(0, 0, -1)),
      arrival: .init(0, 0, 16000), planet: .init(position: .init(8000, 0, 0), radius: 1500),
      sun: .init(position: .init(16000, 3000, 8000), radius: 1100)),
    player: player ?? crimeTestActor(1, position: .init(0, 0, 2000), role: nil, visit: visit),
    actors: actors, protection: protection, budget: budget, perceptionRadius: 8000)
}

func crimeTestIncident(
  _ id: UInt64, time: Double, owner: ActorSnapshot, victim: ActorSnapshot? = nil,
  kind: AttackKind = .laser, outcome: AttackOutcome = .hit, station: Bool = false,
  ordnance: ActorIdentity? = nil, emissionID: UInt64 = 10
) -> CombatIncident {
  .init(
    id: id, physicalTime: time,
    origin: .init(
      emissionID: emissionID, owner: owner.identity, ordnance: ordnance, emittedAt: 1,
      ownerLegalAtEmission: owner.legal, sourcePart: "source-emitter"),
    victim: victim?.identity, kind: kind, outcome: outcome,
    position: victim?.position ?? owner.position,
    victimLegalBeforeAttack: victim?.legal, firstAggressor: nil, victimRole: victim?.npc?.role,
    victimIsStation: station, laser: kind == .laser ? .pulse : nil, mount: .front,
    victimPart: "hull")
}

struct CrimeLedgerTests {
  @Test func cleanPoliceDutyInsideNoFireZoneIsLawfulButBystanderAssaultIsNot() {
    var ledger = CrimeLedger()
    let officer = crimeTestActor(2, position: .init(0, 0, 500), role: .police, hull: .viper)
    let fugitive = crimeTestActor(
      3, position: .init(0, 0, 600), legal: .init(value: 64, bountyTenths: 500))
    let duty = ledger.record(
      crimeTestIncident(1, time: 1, owner: officer, victim: fugitive),
      context: crimeTestContext(1, actors: [officer, fugitive]))
    #expect(!duty.unlawful && duty.legalPenalty == 0 && duty.report == nil)
    let activeOfficer = crimeTestActor(
      2, position: officer.position, role: .police, hull: .viper,
      intention: .engage(fugitive.identity))
    for id in UInt64(2)...3 {
      let missedDuty = ledger.record(
        crimeTestIncident(id, time: Double(id), owner: activeOfficer, outcome: .discharge),
        context: crimeTestContext(Double(id), actors: [activeOfficer, fugitive]))
      #expect(!missedDuty.unlawful && missedDuty.notices.isEmpty)
    }
    let clean = crimeTestActor(4, position: .init(50, 0, 600))
    let rogue = ledger.record(
      crimeTestIncident(4, time: 4, owner: officer, victim: clean),
      context: crimeTestContext(4, actors: [officer, clean]))
    #expect(rogue.unlawful && rogue.legalPenalty == 8 && rogue.report?.offender == officer.identity)
    let wantedOfficer = crimeTestActor(
      5, position: officer.position, role: .police, legal: .init(value: 8, bountyTenths: 0),
      hull: .viper)
    let rogueDuty = ledger.record(
      crimeTestIncident(5, time: 5, owner: wantedOfficer, victim: fugitive),
      context: crimeTestContext(5, actors: [wantedOfficer, fugitive]))
    #expect(rogueDuty.unlawful && rogueDuty.legalPenalty == 2)
  }

  @Test func cleanPoliceCanInterveneAgainstVerifiedAggressorBeforeItsSnapshotChanges() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, position: .init(0, 0, 500), role: nil)
    let aggressor = crimeTestActor(2, position: .init(0, 0, 600), role: .pirate)
    let officer = crimeTestActor(3, position: .init(0, 0, 700), role: .police, hull: .viper)
    _ = ledger.record(
      crimeTestIncident(1, time: 1, owner: aggressor, victim: player),
      context: crimeTestContext(1, player: player, actors: [aggressor, officer]))
    let response = ledger.record(
      crimeTestIncident(2, time: 2, owner: officer, victim: aggressor),
      context: crimeTestContext(2, player: player, actors: [aggressor, officer]))
    #expect(!response.unlawful && !response.lawfulSelfDefence && response.legalPenalty == 0)
  }

  @Test func delayedDefensiveMissileRetainsLawfulLaunchDecision() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, position: .init(0, 0, 500), role: nil)
    let attacker = crimeTestActor(2, position: .init(0, 0, 600), role: .pirate)
    _ = ledger.record(
      crimeTestIncident(1, time: 1, owner: attacker, victim: player),
      context: crimeTestContext(1, player: player, actors: [attacker]))
    let launch = ledger.record(
      crimeTestIncident(
        2, time: 2, owner: player, victim: attacker, kind: .missile,
        outcome: .targetedLaunch, ordnance: crimeTestID(99)),
      context: crimeTestContext(2, player: player, actors: [attacker]))
    #expect(launch.lawfulSelfDefence && !launch.unlawful)
    let death = ledger.record(
      crimeTestIncident(
        3, time: 30, owner: player, victim: attacker, kind: .missile,
        outcome: .destruction, ordnance: crimeTestID(99)),
      context: crimeTestContext(30, player: player, actors: [attacker]))
    #expect(!death.unlawful && death.death?.lawful == true && death.legalPenalty == 0)
  }

  @Test func delayedMissilesKeepLaunchLegalityAndConcurrentOrdnanceHasSeparateIdentity() throws {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, role: nil)
    let victim = crimeTestActor(2)
    for (id, emission) in [(UInt64(1), UInt64(100)), (2, 101)] {
      let launch = ledger.record(
        crimeTestIncident(
          id, time: Double(id), owner: player, victim: victim, kind: .missile,
          outcome: .targetedLaunch, ordnance: crimeTestID(emission), emissionID: emission),
        context: crimeTestContext(Double(id), player: player, actors: [victim]))
      #expect(launch.legalPenalty == (id == 1 ? 8 : 0))
    }
    ledger = try JSONDecoder().decode(CrimeLedger.self, from: JSONEncoder().encode(ledger))
    let hit = ledger.record(
      crimeTestIncident(
        3, time: 30, owner: player, victim: victim, kind: .missile, emissionID: 100),
      context: crimeTestContext(30, player: player, actors: [victim]))
    #expect(hit.unlawful && hit.legalPenalty == 0)
    let death = ledger.record(
      crimeTestIncident(
        4, time: 31, owner: player, victim: victim, kind: .missile,
        outcome: .destruction, emissionID: 101),
      context: crimeTestContext(31, player: player, actors: [victim]))
    #expect(death.legalPenalty == 32 && death.death?.bountyTenths == 0)
    ledger.finishEmission(100)
  }

  @Test func lawfulDelayedMissileUsesItsOriginalOwnerEvenAfterThatNPCDisappears() {
    var ledger = CrimeLedger()
    let shooter = crimeTestActor(2)
    let wanted = crimeTestActor(3, legal: .init(value: 80, bountyTenths: 1200))
    _ = ledger.record(
      crimeTestIncident(
        1, time: 1, owner: shooter, victim: wanted, kind: .missile,
        outcome: .targetedLaunch, ordnance: crimeTestID(99)),
      context: crimeTestContext(1, actors: [shooter, wanted]))
    let death = ledger.record(
      crimeTestIncident(
        2, time: 30, owner: shooter, victim: wanted, kind: .missile,
        outcome: .destruction, ordnance: crimeTestID(99)),
      context: crimeTestContext(30, actors: [wanted]))
    #expect(death.death?.owner == shooter.identity && death.death?.bountyTenths == 1200)
    #expect(death.legalPenalty == 0)
  }

  @Test func firstCleanHitRetaliationAndMurderNeverBecomeHostileBounty() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, position: .init(0, 0, 500), role: nil)
    let victim = crimeTestActor(2, position: .init(0, 0, 600))
    let first = ledger.record(
      crimeTestIncident(1, time: 1, owner: player, victim: victim),
      context: crimeTestContext(1, player: player, actors: [victim]))
    #expect(first.legalPenalty == 8 && first.unlawful && first.report?.offender == player.identity)
    let retaliation = ledger.record(
      crimeTestIncident(2, time: 2, owner: victim, victim: player),
      context: crimeTestContext(2, player: player, actors: [victim]))
    #expect(retaliation.lawfulSelfDefence && !retaliation.unlawful && retaliation.legalPenalty == 0)
    #expect(retaliation.firstAggressor == player.identity)
    let death = ledger.record(
      crimeTestIncident(3, time: 3, owner: player, victim: victim, outcome: .destruction),
      context: crimeTestContext(3, player: player, actors: [victim]))
    #expect(
      death.legalPenalty == 32 && death.death?.bountyTenths == 0 && death.death?.lawful == false)
    let duplicate = ledger.record(
      crimeTestIncident(4, time: 30, owner: player, victim: victim, outcome: .destruction),
      context: crimeTestContext(30, player: player, actors: [victim]))
    #expect(duplicate.death == nil && duplicate.legalPenalty == 0 && duplicate.report == nil)
  }

  @Test(arguments: [AttackKind.laser, .missile, .bomb, .plasma])
  func everyWeaponUsesTheSameAssaultWindowAndOriginalOwner(_ kind: AttackKind) {
    var ledger = CrimeLedger()
    let owner = crimeTestActor(1, role: nil)
    let victim = crimeTestActor(2)
    let context = crimeTestContext(1, player: owner, actors: [victim])
    let outcome: AttackOutcome = kind == .missile ? .targetedLaunch : .hit
    let launch = ledger.record(
      crimeTestIncident(
        1, time: 1, owner: owner, victim: victim,
        kind: kind, outcome: outcome, ordnance: crimeTestID(99)), context: context)
    #expect(launch.legalPenalty == 8 && launch.firstAggressor == owner.identity)
    let hit = ledger.record(
      crimeTestIncident(
        2, time: 5, owner: owner, victim: victim,
        kind: kind, ordnance: crimeTestID(99)),
      context: crimeTestContext(5, player: owner, actors: [victim]))
    #expect(hit.legalPenalty == 0)
    let death = ledger.record(
      crimeTestIncident(
        3, time: 6, owner: owner, victim: victim,
        kind: kind, outcome: .destruction, ordnance: crimeTestID(99)),
      context: crimeTestContext(6, player: owner, actors: [victim]))
    #expect(death.legalPenalty == 32 && death.death?.owner == owner.identity)
    #expect(death.death?.owner != crimeTestID(99))
  }

  @Test func defenceIsAgainstTheActualActiveAggressorAndExpiresWhenThreatEnds() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, position: .init(0, 0, 500), role: nil)
    let aggressor = crimeTestActor(
      2, position: .init(0, 0, 600), role: .pirate,
      intention: .engage(player.identity))
    let bystander = crimeTestActor(3, position: .init(100, 0, 700))
    _ = ledger.record(
      crimeTestIncident(1, time: 1, owner: aggressor, victim: player),
      context: crimeTestContext(1, player: player, actors: [aggressor, bystander]))
    let defence = ledger.record(
      crimeTestIncident(2, time: 20, owner: player, victim: aggressor),
      context: crimeTestContext(20, player: player, actors: [aggressor, bystander]))
    #expect(defence.lawfulSelfDefence && defence.legalPenalty == 0)
    let missedDefence = ledger.record(
      crimeTestIncident(3, time: 21, owner: player, outcome: .discharge),
      context: crimeTestContext(21, player: player, actors: [aggressor, bystander]))
    #expect(missedDefence.lawfulSelfDefence && missedDefence.notices.isEmpty)
    let unrelated = ledger.record(
      crimeTestIncident(4, time: 22, owner: player, victim: bystander),
      context: crimeTestContext(22, player: player, actors: [aggressor, bystander]))
    #expect(!unrelated.lawfulSelfDefence && unrelated.legalPenalty == 8)
    ledger.endThreat(aggressor.identity)
    let ended = ledger.record(
      crimeTestIncident(5, time: 23, owner: player, victim: aggressor),
      context: crimeTestContext(23, player: player, actors: [aggressor]))
    #expect(!ended.lawfulSelfDefence && ended.legalPenalty == 8)
  }

  @Test func lawfulWantedBountyUsesPreexistingValueOnceAndZoneStillMatters() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, role: nil)
    let wanted = crimeTestActor(2, legal: .init(value: 70, bountyTenths: 750))
    let first = ledger.record(
      crimeTestIncident(1, time: 1, owner: player, victim: wanted),
      context: crimeTestContext(1, player: player, actors: [wanted]))
    #expect(!first.unlawful && first.legalPenalty == 0)
    let changed = crimeTestActor(2, legal: .init(value: 100, bountyTenths: 5000))
    let death = ledger.record(
      crimeTestIncident(2, time: 2, owner: player, victim: changed, outcome: .destruction),
      context: crimeTestContext(2, player: player, actors: [changed]))
    #expect(death.death?.bountyTenths == 750 && death.death?.lawful == true)
    let duplicate = ledger.record(
      crimeTestIncident(3, time: 3, owner: player, victim: changed, outcome: .destruction),
      context: crimeTestContext(3, player: player, actors: [changed]))
    #expect(duplicate.death == nil)
    let closePlayer = crimeTestActor(1, position: .init(0, 0, 500), role: nil)
    let another = crimeTestActor(3, legal: .init(value: 70, bountyTenths: 750))
    let prohibited = ledger.record(
      crimeTestIncident(4, time: 4, owner: closePlayer, victim: another),
      context: crimeTestContext(4, player: closePlayer, actors: [another]))
    #expect(prohibited.unlawful && prohibited.legalPenalty == 2)
  }

  @Test func firstMissWarnsRepeatChargesAndContinuousFireExtendsOneWindow() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, position: .init(0, 0, 500), role: nil)
    for (id, time, penalty, warning) in [
      (1, 1.0, 0, true), (2, 10, 2, false), (3, 19, 0, false), (4, 28, 0, false), (5, 39, 0, true),
    ] {
      let result = ledger.record(
        crimeTestIncident(UInt64(id), time: time, owner: player, outcome: .discharge),
        context: crimeTestContext(time, player: player))
      #expect(result.legalPenalty == penalty)
      #expect(result.notices.contains(.weaponsProhibited) == warning)
    }
    let outside = crimeTestActor(1, role: nil)
    let result = ledger.record(
      crimeTestIncident(6, time: 40, owner: outside, outcome: .discharge),
      context: crimeTestContext(40, player: outside))
    #expect(!result.unlawful && result.notices.isEmpty)
  }

  @Test func specialisedPoliceAndInvulnerableStationPenaltiesReplaceGenericAssault() {
    let player = crimeTestActor(1, position: .init(0, 0, 50_000), role: nil)
    let station = crimeTestActor(0, position: .init(0, 0, 0), role: nil, hull: .station)
    var ledger = CrimeLedger()
    let alarm = ledger.record(
      crimeTestIncident(1, time: 1, owner: player, victim: station, station: true),
      context: crimeTestContext(1, player: player, actors: [station]))
    #expect(alarm.legalPenalty == 64 && alarm.report?.kind == .stationAttack && alarm.death == nil)
    let police = crimeTestActor(2, role: .police, hull: .viper)
    let assault = ledger.record(
      crimeTestIncident(2, time: 2, owner: player, victim: police),
      context: crimeTestContext(2, player: player, actors: [police]))
    #expect(assault.legalPenalty == 32)
    let murder = ledger.record(
      crimeTestIncident(3, time: 3, owner: player, victim: police, outcome: .destruction),
      context: crimeTestContext(3, player: player, actors: [police]))
    #expect(murder.legalPenalty == 64)
    let collision = ledger.record(
      crimeTestIncident(
        4, time: 4, owner: player, victim: station, kind: .collision, station: true),
      context: crimeTestContext(4, player: player, actors: [station]))
    #expect(collision.legalPenalty == 0 && collision.report == nil)
  }

  @Test func deepSpaceOffenceReportsOnlyWhenThereIsAnActualWitness() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, position: .init(0, 0, 25000), role: nil)
    let victim = crimeTestActor(2, position: .init(0, 0, 27000))
    let unobserved = ledger.record(
      crimeTestIncident(1, time: 1, owner: player, victim: victim),
      context: crimeTestContext(1, player: player, actors: [victim]))
    #expect(unobserved.unlawful && unobserved.report == nil)
    let witness = crimeTestActor(3, position: .init(0, 0, 28000), role: .police, hull: .viper)
    let observed = ledger.record(
      crimeTestIncident(2, time: 2, owner: player, victim: victim),
      context: crimeTestContext(2, player: player, actors: [victim, witness]))
    #expect(observed.report?.offender == player.identity && observed.legalPenalty == 0)
  }

  @Test func persistencePreservesRecentWindowDeathsAndRejectsOldVisitIdentity() throws {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, role: nil)
    let victim = crimeTestActor(2)
    let first = crimeTestIncident(1, time: 1, owner: player, victim: victim)
    _ = ledger.record(first, context: crimeTestContext(1, player: player, actors: [victim]))
    ledger = try JSONDecoder().decode(CrimeLedger.self, from: JSONEncoder().encode(ledger))
    #expect(
      !ledger.record(first, context: crimeTestContext(1, player: player, actors: [victim])).accepted
    )
    let continuous = ledger.record(
      crimeTestIncident(2, time: 11, owner: player, victim: victim),
      context: crimeTestContext(11, player: player, actors: [victim]))
    #expect(continuous.legalPenalty == 0)
    let renewed = ledger.record(
      crimeTestIncident(3, time: 22, owner: player, victim: victim),
      context: crimeTestContext(22, player: player, actors: [victim]))
    #expect(renewed.legalPenalty == 8)
    ledger.beginVisit(system: crimeTestSystem, visit: 2)
    #expect(
      !ledger.record(
        crimeTestIncident(4, time: 23, owner: player, victim: victim),
        context: crimeTestContext(23, visit: 2)
      ).accepted)
  }

  @Test func componentsInterceptionResourcesAndMissionEntitlementsHaveDistinctSettlements() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, role: nil)
    let target = crimeTestActor(2)
    let part = ledger.record(
      crimeTestIncident(1, time: 1, owner: player, victim: target, outcome: .componentDestruction),
      context: crimeTestContext(1, player: player, actors: [target]))
    #expect(part.legalPenalty == 8 && part.death == nil)
    let intercepted = ledger.record(
      crimeTestIncident(2, time: 2, owner: player, victim: target, outcome: .ordnanceInterception),
      context: crimeTestContext(2, player: player, actors: [target]))
    #expect(intercepted.legalPenalty == 0 && intercepted.death == nil)
    let rock = crimeTestActor(3, role: nil, hull: .asteroid)
    let mined = ledger.record(
      crimeTestIncident(3, time: 3, owner: player, victim: rock, outcome: .destruction),
      context: crimeTestContext(3, player: player, actors: [rock]))
    #expect(!mined.unlawful && mined.death == nil)
    let mission = crimeTestActor(4, role: .mission, hull: .constrictor)
    let entitled = ledger.record(
      crimeTestIncident(4, time: 4, owner: player, victim: mission, outcome: .destruction),
      context: crimeTestContext(4, player: player, actors: [mission]),
      missionEntitlement: .init(
        owner: player.identity, victim: mission.identity,
        amountTenths: 2500, authorizesAttack: true))
    #expect(!entitled.unlawful && entitled.death?.bountyTenths == 2500)
  }
}
