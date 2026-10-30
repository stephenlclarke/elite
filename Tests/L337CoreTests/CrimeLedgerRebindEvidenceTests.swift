import Foundation
import Testing

@testable import L337Core

struct CrimeLedgerRebindEvidenceTests {
  @Test func recentAggressionAndFirstAggressorFollowTheSurvivingLogicalCraft() {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, position: .init(0, 0, 500), role: nil)
    let original = crimeTestActor(2, position: .init(0, 0, 600), role: .pirate)
    let current = crimeTestActor(20, position: original.position, role: .pirate)
    _ = ledger.record(
      crimeTestIncident(1, time: 1, owner: original, victim: player),
      context: crimeTestContext(1, player: player, actors: [original]))
    ledger.rebindActors([original.identity: current.identity])
    let response = ledger.record(
      crimeTestIncident(2, time: 2, owner: player, victim: current),
      context: crimeTestContext(2, player: player, actors: [current]))
    #expect(response.accepted && response.lawfulSelfDefence && !response.unlawful)
    #expect(response.legalPenalty == 0 && response.firstAggressor == current.identity)
  }

  @Test func liveMissileThreatPreservesDefenceAfterOwnerRebindBeyondBeamWindow() throws {
    var ledger = CrimeLedger()
    let player = crimeTestActor(1, position: .init(0, 0, 500), role: nil)
    let original = crimeTestActor(2, position: .init(0, 0, 600), role: .pirate)
    let current = crimeTestActor(20, position: original.position, role: .pirate)
    let missile = crimeTestActor(99, role: nil, hull: .missile)
    _ = ledger.record(
      crimeTestIncident(
        1, time: 1, owner: original, victim: player,
        kind: .missile, outcome: .targetedLaunch, ordnance: missile.identity, emissionID: 100),
      context: crimeTestContext(1, player: player, actors: [original, missile]))
    let frozen = try launchEvidence(ledger)
    ledger.rebindActors([original.identity: current.identity])
    #expect(try launchEvidence(ledger) == frozen)
    ledger = try JSONDecoder().decode(CrimeLedger.self, from: JSONEncoder().encode(ledger))
    let response = ledger.record(
      crimeTestIncident(2, time: 30, owner: player, victim: current),
      context: crimeTestContext(30, player: player, actors: [current, missile]))
    #expect(response.lawfulSelfDefence && !response.unlawful && response.legalPenalty == 0)
    #expect(response.firstAggressor == current.identity)
  }

  @Test func delayedMissileKeepsLaunchJudgementOriginalOwnerAndOnceOnlyBountyAfterRebind() throws {
    var ledger = CrimeLedger()
    let shooter = crimeTestActor(2)
    let wanted = crimeTestActor(3, legal: .init(value: 80, bountyTenths: 1200))
    let currentShooter = crimeTestActor(20)
    let currentVictim = crimeTestActor(30)
    _ = ledger.record(
      crimeTestIncident(
        1, time: 1, owner: shooter, victim: wanted,
        kind: .missile, outcome: .targetedLaunch, ordnance: crimeTestID(99), emissionID: 100),
      context: crimeTestContext(1, actors: [shooter, wanted]))
    let frozen = try launchEvidence(ledger)
    ledger.rebindActors([
      shooter.identity: currentShooter.identity,
      wanted.identity: currentVictim.identity,
    ])
    #expect(try launchEvidence(ledger) == frozen)
    let death = ledger.record(
      crimeTestIncident(
        2, time: 30, owner: shooter, victim: currentVictim,
        kind: .missile, outcome: .destruction, ordnance: crimeTestID(99), emissionID: 100),
      context: crimeTestContext(30, actors: [currentShooter, currentVictim]))
    #expect(death.death?.owner == shooter.identity && death.death?.victim == currentVictim.identity)
    #expect(death.death?.bountyTenths == 1200 && death.death?.lawful == true)
    #expect(death.legalPenalty == 0 && !death.unlawful)
    let duplicate = ledger.record(
      crimeTestIncident(
        3, time: 31, owner: shooter, victim: currentVictim,
        kind: .missile, outcome: .destruction, ordnance: crimeTestID(99), emissionID: 100),
      context: crimeTestContext(31, actors: [currentShooter, currentVictim]))
    #expect(duplicate.accepted && duplicate.death == nil && duplicate.legalPenalty == 0)
    let object = try crimeObject(ledger)
    let attacks = try #require(object["attacks"] as? [[String: Any]])
    #expect(attacks.count == 1)
    let owner = try #require(attacks.first?["owner"] as? [String: Any])
    #expect((owner["entity"] as? NSNumber)?.uint64Value == currentShooter.identity.entity)
  }

  @Test func missedDischargeChargeWindowSurvivesOwnerRebind() {
    var ledger = CrimeLedger()
    let original = crimeTestActor(2, position: .init(0, 0, 500))
    let current = crimeTestActor(20, position: original.position)
    let warning = ledger.record(
      crimeTestIncident(1, time: 1, owner: original, outcome: .discharge),
      context: crimeTestContext(1, actors: [original]))
    #expect(warning.notices == [.weaponsProhibited] && warning.legalPenalty == 0)
    ledger.rebindActors([original.identity: current.identity])
    let charge = ledger.record(
      crimeTestIncident(2, time: 2, owner: current, outcome: .discharge),
      context: crimeTestContext(2, actors: [current]))
    #expect(charge.unlawful && charge.legalPenalty == 2)
  }

  @Test func delayedUnlawfulSettlementCapsCurrentLegalButKeepsOriginalDeathOwner() {
    var ledger = CrimeLedger()
    let original = crimeTestActor(2)
    let victim = crimeTestActor(3)
    _ = ledger.record(
      crimeTestIncident(
        1, time: 1, owner: original, victim: victim,
        kind: .missile, outcome: .targetedLaunch, ordnance: crimeTestID(99)),
      context: crimeTestContext(1, actors: [original, victim]))
    let current = crimeTestActor(20, legal: .init(value: 250, bountyTenths: 0))
    ledger.rebindActors([original.identity: current.identity])
    let death = ledger.record(
      crimeTestIncident(
        2, time: 30, owner: original, victim: victim,
        kind: .missile, outcome: .destruction, ordnance: crimeTestID(99)),
      context: crimeTestContext(30, actors: [current, victim]))
    #expect(death.offender == current.identity && death.firstAggressor == current.identity)
    #expect(death.report?.offender == current.identity && death.legalPenalty == 5)
    #expect(death.death?.owner == original.identity && death.death?.lawful == false)
  }

  @Test func crossVisitAndNonAdvancingMappingsDoNotCarryCrimeIntoAnotherIdentity() {
    var ledger = CrimeLedger()
    let original = crimeTestActor(2)
    let victim = crimeTestActor(3)
    _ = ledger.record(
      crimeTestIncident(1, time: 1, owner: original, victim: victim),
      context: crimeTestContext(1, actors: [original, victim]))
    let before = ledger
    for replacement in [crimeTestID(20, visit: 2), crimeTestID(2), crimeTestID(1)] {
      ledger.rebindActors([original.identity: replacement])
      #expect(ledger == before)
    }
  }

  @Test func legacyMissileEvidenceWithoutCurrentBindingsStillDecodes() throws {
    var ledger = CrimeLedger()
    let shooter = crimeTestActor(2)
    let victim = crimeTestActor(3)
    _ = ledger.record(
      crimeTestIncident(
        1, time: 1, owner: shooter, victim: victim,
        kind: .missile, outcome: .targetedLaunch, ordnance: crimeTestID(99)),
      context: crimeTestContext(1, actors: [shooter, victim]))
    var object = try crimeObject(ledger)
    var missiles = try #require(object["missiles"] as? [[String: Any]])
    for index in missiles.indices {
      missiles[index].removeValue(forKey: "currentOwner")
      missiles[index].removeValue(forKey: "currentVictim")
    }
    object["missiles"] = missiles
    let data = try JSONSerialization.data(withJSONObject: object)
    let restored = try JSONDecoder().decode(CrimeLedger.self, from: data)
    #expect(try launchEvidence(restored) == launchEvidence(ledger))
  }

  @Test func mergingRetiredAddressesKeepsTheLatestJudgementAndDischargeWindow() {
    let original = crimeTestActor(2)
    let current = crimeTestActor(20)
    let clean = crimeTestActor(3)
    let wanted = crimeTestActor(3, legal: .init(value: 64, bountyTenths: 100))
    var ledger = CrimeLedger()
    _ = ledger.record(
      crimeTestIncident(1, time: 1, owner: original, victim: clean),
      context: crimeTestContext(1, actors: [original, clean]))
    _ = ledger.record(
      crimeTestIncident(2, time: 30, owner: current, victim: wanted),
      context: crimeTestContext(30, actors: [current, wanted]))
    ledger.rebindActors([original.identity: current.identity])
    let followUp = ledger.record(
      crimeTestIncident(3, time: 31, owner: current, victim: wanted),
      context: crimeTestContext(31, actors: [current, wanted]))
    #expect(!followUp.unlawful && followUp.legalPenalty == 0)

    ledger = CrimeLedger()
    let nearOriginal = crimeTestActor(2, position: .init(0, 0, 500))
    let nearCurrent = crimeTestActor(20, position: nearOriginal.position)
    for id in UInt64(1)...2 {
      _ = ledger.record(
        crimeTestIncident(
          id, time: Double(id), owner: nearOriginal,
          outcome: .discharge), context: crimeTestContext(Double(id), actors: [nearOriginal]))
    }
    _ = ledger.record(
      crimeTestIncident(3, time: 100, owner: nearCurrent, outcome: .discharge),
      context: crimeTestContext(100, actors: [nearCurrent]))
    ledger.rebindActors([nearOriginal.identity: nearCurrent.identity])
    let charge = ledger.record(
      crimeTestIncident(
        4, time: 101, owner: nearCurrent,
        outcome: .discharge), context: crimeTestContext(101, actors: [nearCurrent]))
    #expect(charge.unlawful && charge.legalPenalty == 2)
  }

  private func crimeObject(_ ledger: CrimeLedger) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
  }

  private func launchEvidence(_ ledger: CrimeLedger) throws -> Data {
    let object = try crimeObject(ledger)
    let missiles = try #require(object["missiles"] as? [[String: Any]])
    let attack = try #require(missiles.first?["attack"] as? [String: Any])
    return try JSONSerialization.data(withJSONObject: attack, options: [.sortedKeys])
  }
}
