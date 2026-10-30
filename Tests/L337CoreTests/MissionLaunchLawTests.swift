import Foundation
import Testing

@testable import L337Core

struct MissionLaunchLawTests {
  @Test(arguments: [false, true])
  func purePlasmaFreezeMatchesActualNativeLawWithoutCreatingAnIncident(police: Bool) throws {
    let owner = crimeTestActor(
      2, position: .init(0, 0, 500), role: police ? .police : .mission)
    let victim = crimeTestActor(3, legal: .init(value: 32, bountyTenths: 500))
    let context = crimeTestContext(2, actors: [owner, victim])
    let origin = AttackOrigin(
      emissionID: 40, owner: owner.identity, emittedAt: 2,
      ownerLegalAtEmission: owner.legal, sourcePart: "actual-turret")
    var ledger = CrimeLedger()
    let before = ledger
    let frozen = try ledger.freezeMissionLaunchJudgement(
      origin: origin, intendedVictim: victim, emissionPosition: owner.position, context: context)
    #expect(ledger == before && frozen.valid && !frozen.launchEffectsApplied)
    #expect(frozen.origin == origin && frozen.victim == victim.identity && frozen.inNoFireZone)
    #expect(frozen.lawful == police && frozen.authorityAction == police)
    let incident = CombatIncident(
      id: 1, physicalTime: 2, origin: origin, victim: victim.identity, kind: .plasma, outcome: .hit,
      position: victim.position, victimLegalBeforeAttack: victim.legal, firstAggressor: nil,
      victimRole: victim.npc?.role, victimIsStation: false)
    let resolution = ledger.record(incident, context: context, emissionPosition: owner.position)
    #expect(resolution.accepted && resolution.unlawful == frozen.unlawful)
    #expect(resolution.lawfulSelfDefence == frozen.lawfulSelfDefence)
    let bytes = try JSONEncoder().encode(frozen)
    let restored = try JSONDecoder().decode(MissionLaunchJudgement.self, from: bytes)
    #expect(restored == frozen && restored.valid)
  }

  @Test func launchFreezeUsesActualExistingSelfDefenceAndLeavesTheLedgerUnchanged() throws {
    let source = crimeTestActor(2, role: .mission)
    let aggressor = crimeTestActor(3, role: .pirate)
    var ledger = CrimeLedger()
    let initial = ledger.record(
      crimeTestIncident(1, time: 1, owner: aggressor, victim: source, kind: .plasma),
      context: crimeTestContext(1, actors: [source, aggressor]))
    try #require(initial.accepted && initial.unlawful)
    let before = ledger
    let origin = AttackOrigin(
      emissionID: 41, owner: source.identity, emittedAt: 2, ownerLegalAtEmission: source.legal)
    let frozen = try ledger.freezeMissionLaunchJudgement(
      origin: origin, intendedVictim: aggressor, emissionPosition: source.position,
      context: crimeTestContext(2, actors: [source, aggressor]))
    #expect(
      frozen.lawful && frozen.lawfulSelfDefence && frozen.firstAggressor == aggressor.identity)
    #expect(ledger == before)
  }

  @Test func freezeRefusesStaleVisitAndChangedTargetWithoutRelaxingOrdinaryIncidentGuards() throws {
    let owner = crimeTestActor(2, role: .mission)
    let victim = crimeTestActor(3)
    let origin = AttackOrigin(
      emissionID: 42, owner: owner.identity, emittedAt: 2, ownerLegalAtEmission: owner.legal)
    var ledger = CrimeLedger()
    let before = ledger
    #expect(throws: MissionLaunchLawError.self) {
      try ledger.freezeMissionLaunchJudgement(
        origin: origin, intendedVictim: victim, emissionPosition: owner.position,
        context: crimeTestContext(2, actors: [owner, victim], visit: 2))
    }
    let changed = crimeTestActor(3, legal: .init(value: 64, bountyTenths: 500))
    #expect(throws: MissionLaunchLawError.self) {
      try ledger.freezeMissionLaunchJudgement(
        origin: origin, intendedVictim: victim, emissionPosition: owner.position,
        context: crimeTestContext(2, actors: [owner, changed]))
    }
    let refused = ledger.record(
      crimeTestIncident(1, time: 2, owner: owner, victim: victim, kind: .plasma),
      context: crimeTestContext(2, actors: [owner, victim], visit: 2))
    #expect(!refused.accepted && ledger == before)
  }
}
