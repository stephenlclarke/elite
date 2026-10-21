import Foundation
import Testing

@testable import EliteCore

private func crimboAttack(_ game: inout Game, attacker: ActorIdentity, victim: ActorIdentity)
  throws -> CombatIncident
{
  let emissionAllocation = game.commander.flightSimulation.allocateEmission()
  let emission = try #require(emissionAllocation)
  let incidentAllocation = game.commander.flightSimulation.allocateIncident()
  let incident = try #require(incidentAllocation)
  return .init(
    id: incident, physicalTime: game.commander.flightSimulation.physicalTime,
    origin: .init(
      emissionID: emission, owner: attacker,
      emittedAt: game.commander.flightSimulation.physicalTime,
      ownerLegalAtEmission: .init()),
    victim: victim, kind: .laser, outcome: .hit, position: .init(0, 0, 0),
    victimLegalBeforeAttack: .init(), firstAggressor: attacker,
    victimRole: .trader, victimIsStation: false)
}

struct NativeCrimboProviderTests {
  @Test func discoveryIsPeacefulAndMissingNativeOperationsStayUnavailable() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    #expect(game.nativeCrimboDefenceIntents().isEmpty)
    #expect(try game.nativeProviderMissionFacts(instance: nil) == nil)
    let owner = try #require(game.commander.equipmentOwnerID)
    game.commander.savedCrimboState?.destination = CrimboFixture.station(
      owner: owner, system: .init(galaxy: 7, system: 202))
    let resolvedFacts = try game.nativeProviderMissionFacts(instance: nil)
    let facts = try #require(resolvedFacts)
    #expect(facts.source.provider.definition == "crimbo-convoy")
    #expect(facts.source.operationsReady.isEmpty && !facts.source.routeAvailable)
    #expect(facts.source.interval == nil && facts.source.core == nil && facts.source.relay == nil)
    #expect(
      facts.source.personOperations.isEmpty && facts.source.destinationContactAvailable == nil)
    #expect(!facts.source.playerThreat && facts.source.betrayal == nil)
    #expect(game.nativeCrimboDefenceIntents().isEmpty)
  }

  @Test func refusedCombatCannotCreateThreatAndAcceptedPlayerAttackHasSixExactRequests() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let santa = try #require(
      game.bodies.first { $0.physical?.catalogueShipID == "SH150" }?.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    let incident = try crimboAttack(&game, attacker: player, victim: santa)
    let before = game.commander.savedCrimboState
    try game.observeNativeCrimboCombat(incident: incident, resolution: .init())
    #expect(game.commander.savedCrimboState == before)
    var accepted = CrimeResolution()
    accepted.accepted = true
    accepted.unlawful = true
    try game.observeNativeCrimboCombat(incident: incident, resolution: accepted)
    let intents = game.nativeCrimboDefenceIntents()
    #expect(
      intents.count == 6
        && intents.allSatisfy { $0.attacker == player && $0.incident == incident.id })
    #expect(game.commander.savedCrimboState?.betrayal?.incident == incident)
    let recorded = game.commander.savedCrimboState
    try game.observeNativeCrimboCombat(incident: incident, resolution: accepted)
    #expect(game.commander.savedCrimboState == recorded)
    try game.endNativeCrimboThreat(incident: incident.id + 1)
    #expect(game.nativeCrimboDefenceIntents().count == 6)
    try game.endNativeCrimboThreat(incident: incident.id)
    #expect(game.nativeCrimboDefenceIntents().isEmpty)
    #expect(game.commander.savedCrimboState?.betrayal?.incident == incident)
  }

  @Test func npcAggressorNeverFallsBackToPlayerWhenItsLogicalBindingIsLost() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let attackerAllocation = game.commander.flightSimulation.allocateActor()
    let attacker = try #require(attackerAllocation)
    var npc = NPCState(
      role: .pirate, origin: CrimboFixture.system, destination: CrimboFixture.system)
    npc.resources = NPCResources.stock(game.commander.performance)
    var body = SpaceBody(id: 999, hull: .cobra, position: .init(0, 0, -5000))
    body.physical = .init(identity: attacker, population: .pirate, npc: npc)
    game.bodies.append(body)
    let persistenceRefusals = game.persistNPCStates()
    #expect(persistenceRefusals.isEmpty)
    let santa = try #require(
      game.bodies.first { $0.physical?.catalogueShipID == "SH150" }?.physical?.identity)
    let incident = try crimboAttack(&game, attacker: attacker, victim: santa)
    var accepted = CrimeResolution()
    accepted.accepted = true
    accepted.unlawful = true
    try game.observeNativeCrimboCombat(incident: incident, resolution: accepted)
    #expect(game.nativeCrimboDefenceIntents().count == 6)
    #expect(game.nativeCrimboDefenceIntents().allSatisfy { $0.attacker == attacker })
    #expect(game.commander.savedCrimboState?.betrayal == nil)
    game.commander.npcPersistence.cull(actor: attacker)
    game.bodies.removeAll { $0.physical?.identity == attacker }
    #expect(game.nativeCrimboDefenceIntents().isEmpty)
    #expect(game.commander.savedCrimboState?.threat?.incident == incident.id)
  }

  @Test func counterfeitMissionBodyAndForeignWorldCannotSupplyOriginalFacts() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let owner = try #require(game.commander.equipmentOwnerID)
    game.commander.savedCrimboState?.destination = CrimboFixture.station(
      owner: owner, system: .init(galaxy: 7, system: 202))
    let santa = try #require(game.bodies.firstIndex { $0.physical?.catalogueShipID == "SH150" })
    game.bodies[santa].missionActorID = UUID()
    #expect(try game.nativeProviderMissionFacts(instance: nil) == nil)
    game.bodies[santa].missionActorID = nil
    game.commander.savedCrimboState = try CrimboFixture.registry(owner: UUID())
    #expect(try game.nativeProviderMissionFacts(instance: nil) == nil)
  }

  @Test func spentAndDisabledEscortsProduceNoWeaponRequest() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let santa = try #require(
      game.bodies.first { $0.physical?.catalogueShipID == "SH150" }?.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    let incident = try crimboAttack(&game, attacker: player, victim: santa)
    var accepted = CrimeResolution()
    accepted.accepted = true
    try game.observeNativeCrimboCombat(incident: incident, resolution: accepted)
    for i in game.bodies.indices where game.bodies[i].physical?.catalogueShipID == "SH151" {
      game.bodies[i].physical?.npc?.resources?.laserHeat = 240
    }
    #expect(game.nativeCrimboDefenceIntents().isEmpty)
    #expect(game.bodies.allSatisfy { !$0.hostile })
  }
  @Test func gateRejectsDecodedThreatFactsAndDefenceAsWellAsBirth() throws {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let owner = try #require(game.commander.equipmentOwnerID)
    game.commander.savedCrimboState?.destination = CrimboFixture.station(
      owner: owner, system: .init(galaxy: 7, system: 202))
    let santa = try #require(
      CrimboFixture.convoyBodies(game).first { $0.physical?.catalogueShipID == "SH150" }?.physical?
        .identity)
    let player = try #require(game.commander.flightSimulation.player)
    let incident = try crimboAttack(&game, attacker: player, victim: santa)
    var accepted = CrimeResolution()
    accepted.accepted = true
    accepted.unlawful = true
    try game.observeNativeCrimboCombat(incident: incident, resolution: accepted)
    #expect(game.nativeCrimboDefenceIntents().count == 6)
    game.commander = try JSONDecoder().decode(
      Commander.self, from: JSONEncoder().encode(game.commander))
    game.nativeCrimboLifecycleAvailable = false
    let before = game.commander.savedCrimboState
    #expect(game.nativeCrimboDefenceIntents().isEmpty)
    #expect(try game.nativeProviderMissionFacts(instance: nil) == nil)
    #expect(!game.isNativeCrimboMember(santa))
    try game.endNativeCrimboThreat(incident: incident.id)
    let next = try crimboAttack(&game, attacker: player, victim: santa)
    try game.observeNativeCrimboCombat(incident: next, resolution: accepted)
    #expect(game.commander.savedCrimboState == before)
  }

}
