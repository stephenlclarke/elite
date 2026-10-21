import Foundation
import Testing

@testable import EliteCore

private struct LedgerImpactFixture {
  var game: Game
  let proof: MissionNativeImpactProof
  let context: EncounterContext
  let origin: AttackOrigin
  let eventID: UInt64
  let rock: MiningRock?
}

private struct LedgerImpactFacts {
  let proof: MissionNativeImpactProof
  let context: EncounterContext
  let origin: AttackOrigin
  let eventID: UInt64
  let rock: MiningRock?
}

/// Real retained pack, native allocators and geometric producer; no sealed constructor is used.
private func ledgerImpactFixture(
  reentry: Bool = false, absentSource: Bool = false, incidental: Bool = false,
  mining: Bool = false, fragileRock: Bool = false, emissionTime: Double = 0
) throws -> LedgerImpactFixture {
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/profiled-skirmish")
  let pack = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  let instance = try prepareLedgerImpactLaunch(&game, pack: pack, emissionTime: emissionTime)
  let facts = try prepareLedgerImpactContact(
    &game, instance: instance, reentry: reentry, absentSource: absentSource,
    incidental: incidental, mining: mining, fragileRock: fragileRock)
  return .init(
    game: game, proof: facts.proof, context: facts.context, origin: facts.origin,
    eventID: facts.eventID, rock: facts.rock)
}

// Finish native launch before reserving the contact producer's later whole-Game temporaries.
private func prepareLedgerImpactLaunch(
  _ game: inout Game, pack: ScriptPack, emissionTime: Double
) throws -> UUID {
  game.screen = .status
  game.scriptPacks = [pack]
  let instance = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  game.commander.flightSimulation.advancePhysicalTime(emissionTime)
  game.ensurePhysicalActors()
  return instance
}

private func prepareLedgerImpactContact(
  _ game: inout Game, instance: UUID, reentry: Bool, absentSource: Bool,
  incidental: Bool, mining: Bool, fragileRock: Bool
) throws -> LedgerImpactFacts {
  let source = try #require(
    game.bodies.first { $0.missionInstanceID == instance && $0.scriptNPC != nil })
  let descriptor = try #require(game.currentMissionActorDescriptor(bodyID: source.id))
  let launchContext = try #require(game.gameplayContext())
  let binding = try MissionNativeBridge.bindActor(
    descriptor: descriptor, body: source, context: launchContext)
  let weapon = try #require(source.scriptNPC?.fit.definition.components?.first?.weapons?.first)
  let component = try #require(source.scriptNPC?.components.values.first?.identity)
  let allocatedOrigin = game.makeAttackOrigin(
    owner: binding.nativeActor, sourcePart: component.uuidString)
  let origin = try #require(allocatedOrigin)
  let launchActor = try #require(launchContext.actors.first { $0.identity == binding.nativeActor })
  let frozen = try game.commander.crimeLedger.freezeMissionLaunchJudgement(
    origin: origin, intendedVictim: launchContext.player,
    emissionPosition: launchActor.position, context: launchContext)
  let id = UUID()
  let shot = ScriptNPCShot(
    identity: id, owner: descriptor.actorID, instance: instance, weapon: weapon.id,
    component: component, velocity: .init(0, 0, -(try #require(weapon.projectileSpeed))),
    age: 0.1, lifetime: try #require(weapon.lifetime), damage: weapon.damage,
    radius: try #require(weapon.collisionRadius),
    collisionDelay: try #require(weapon.collisionDelay))
  let archive = try MissionNativeBridge.makeLaunchArchive(
    shot: #require(shot.missionDescriptor), source: binding, intendedTarget: nil, judgement: frozen)
  let archived = ScriptNPCShot(
    identity: shot.identity, owner: shot.owner, instance: shot.instance, weapon: shot.weapon,
    component: shot.component, velocity: shot.velocity, age: shot.age, lifetime: shot.lifetime,
    damage: shot.damage, radius: shot.radius, collisionDelay: shot.collisionDelay,
    nativeAttribution: archive)
  game.bodies = absentSource ? [] : [source]
  game.celestials = []
  if reentry {
    let system = try #require(game.commander.flightSimulation.system)
    game.commander.flightSimulation.enter(system, arriving: false)
    game.commander.crimeLedger.beginVisit(
      system: system, visit: game.commander.flightSimulation.visit)
    for index in game.bodies.indices { game.bodies[index].physical = nil }
  }
  var rock: MiningRock?
  if incidental || mining {
    var target = SpaceBody(id: 101, hull: mining ? .asteroid : .cobra, position: .init(0, 0, 500))
    if mining {
      let generated = try #require(game.miningFields.first?.rocks.first)
      rock = .init(
        identity: generated.identity, position: generated.position, radius: generated.radius,
        energy: fragileRock ? weapon.damage / 2 : generated.energy)
      target.energy = rock!.energy
      game.miningFields = [.init(position: rock!.position, rocks: [rock!])]
      game.ensurePhysicalActors()
      let evaluatedResult1 = game.commander.flightSimulation.allocateActor()
      let identity = try #require(evaluatedResult1)
      target.physical = .init(identity: identity, population: .asteroid, rock: generated.identity)
    }
    game.bodies.append(target)
  }
  game.ensurePhysicalActors()
  let context = try #require(game.gameplayContext())
  let evaluatedResult2 = game.commander.flightSimulation.allocateSpawn()
  let sequence = try #require(evaluatedResult2)
  let request = SpawnRequest(
    identity: .init(
      system: context.system, visit: context.visit, sequence: sequence, member: 0,
      producer: .ordnance),
    population: .projectile, hull: .missile,
    position: game.commander.flightSimulation.pose.systemPoint(.init(0, 0, 1000)),
    orientation: .init(), velocity: archived.velocity, npc: nil, rock: nil, payload: nil,
    priority: .mission)
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: true)], intents: []))
  let actor = try #require(receipts.first?.actor)
  let index = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
  game.bodies[index].scriptShot = archived
  game.bodies[index].physical?.attackOrigin = archive.origin
  game.commander.scriptState.projectiles[id] = .init(
    galaxy: game.commander.galaxy, system: game.commander.system, body: game.bodies[index],
    presence: .present)
  let evaluatedResult3 = try game.missionNativeImpactProof(projectileID: id, delta: 0.6)
  let proof = try #require(evaluatedResult3)
  let current = try #require(game.gameplayContext())
  let evaluatedResult4 = game.commander.flightSimulation.allocateIncident()
  let event = try #require(evaluatedResult4)
  return .init(proof: proof, context: current, origin: origin, eventID: event, rock: rock)
}

struct MissionLedgerImpactTests {
  @Test func actualReentryProofUsesFrozenLawAndCurrentAddressesWithoutRelaxingOrdinaryVisitGuard()
    throws
  {
    let fixture = try ledgerImpactFixture(reentry: true)
    try #require(fixture.proof.frozenJudgement != nil)
    #expect(fixture.origin.owner.visit != fixture.context.visit)
    var ordinary = CrimeLedger()
    let incident = CombatIncident(
      id: fixture.eventID, physicalTime: fixture.context.physicalTime, origin: fixture.origin,
      victim: fixture.proof.currentVictim, kind: .plasma, outcome: .hit,
      position: fixture.context.player.position,
      victimLegalBeforeAttack: fixture.context.player.legal,
      firstAggressor: nil, victimRole: nil, victimIsStation: false)
    let evaluatedResult5 = !ordinary.record(incident, context: fixture.context).accepted
    #expect(evaluatedResult5)
    let beforeArchive = fixture.proof.archive
    var ledger = CrimeLedger()
    let result = ledger.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .hit, context: fixture.context)
    #expect(result.accepted && result.unlawful)
    #expect(result.offender == fixture.proof.currentSource)
    #expect(result.firstAggressor == fixture.proof.currentSource)
    #expect(result.death == nil && fixture.proof.archive == beforeArchive)
    let saved = ledger
    let evaluatedResult6 = !ledger.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .hit, context: fixture.context
    ).accepted
    #expect(evaluatedResult6)
    #expect(ledger == saved)
  }

  @Test(arguments: [false, true])
  func actualAbsentSourceAndIncidentalContactNeverInventCrimeOrBenefits(incidental: Bool) throws {
    let fixture = try ledgerImpactFixture(absentSource: !incidental, incidental: incidental)
    #expect(fixture.proof.frozenJudgement == nil)
    var ledger = CrimeLedger()
    let result = ledger.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .destruction, context: fixture.context)
    #expect(result.accepted && result.offender == nil && result.report == nil)
    #expect(result.death == nil && result.legalPenalty == 0 && result.notices.isEmpty)
    #expect(!result.unlawful && !result.lawfulSelfDefence && result.firstAggressor == nil)
  }

  @Test func scopedCrimeMatchesOrdinaryCurrentVisitPlasmaAndRejectsStaleContext() throws {
    var fixture = try ledgerImpactFixture()
    try verifyScopedCrime(&fixture)
  }

  @Test func sealedPlasmaRockHitSharesOrdinaryArithmeticAndNeverExtractsMiningOre() throws {
    let fixture = try ledgerImpactFixture(mining: true)
    let rock = try #require(fixture.rock)
    try #require(fixture.proof.targetBody?.physical?.rock == rock.identity)
    var ordinary = MiningLedger(seed: 17)
    var scoped = ordinary
    let incident = CombatIncident(
      id: fixture.eventID, physicalTime: fixture.context.physicalTime, origin: fixture.origin,
      victim: fixture.proof.currentVictim, kind: .plasma, outcome: .hit,
      position: fixture.context.player.position, victimLegalBeforeAttack: nil,
      firstAggressor: nil, victimRole: nil, victimIsStation: false)
    let expected = ordinary.hit(rock: rock, incident: incident, damage: fixture.proof.damage)
    let actual = scoped.hit(
      rock: rock, proof: fixture.proof, eventID: fixture.eventID, context: fixture.context)
    #expect(actual == expected && scoped == ordinary && scoped.pendingPayloads.isEmpty)
    let before = scoped
    let evaluatedResult8 =
      scoped.hit(
        rock: rock, proof: fixture.proof, eventID: fixture.eventID, context: fixture.context)
      == .ignored
    #expect(evaluatedResult8)
    #expect(scoped == before)
  }
  @Test func unknownPhysicalDeathPreventsALaterOrdinaryDeathBenefit() throws {
    var fixture = try ledgerImpactFixture(incidental: true)
    var ledger = CrimeLedger()
    let unknown = ledger.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .destruction, context: fixture.context)
    try #require(unknown.accepted && unknown.death == nil)
    let victim = try #require(
      fixture.context.actors.first { $0.identity == fixture.proof.currentVictim })
    let evaluatedResult9 = fixture.game.commander.flightSimulation.allocateIncident()
    let next = try #require(evaluatedResult9)
    let incident = CombatIncident(
      id: next, physicalTime: fixture.context.physicalTime, origin: fixture.origin,
      victim: victim.identity, kind: .plasma, outcome: .destruction, position: victim.position,
      victimLegalBeforeAttack: victim.legal, firstAggressor: nil, victimRole: victim.npc?.role,
      victimIsStation: false)
    var control = CrimeLedger()
    let evaluatedResult10 = control.record(incident, context: fixture.context).death != nil
    try #require(evaluatedResult10)
    let replay = ledger.record(incident, context: fixture.context)
    #expect(replay.accepted && replay.death == nil && replay.report == nil)
    #expect(replay.legalPenalty == 0 && replay.firstAggressor == nil)
  }

  @Test(arguments: ["missing-source", "source-role", "target"])
  func aChangedActualSourceOrTargetRefusesAnOlderSealedContact(change: String) throws {
    var fixture = try ledgerImpactFixture(incidental: true)
    try verifyChangedActualContact(&fixture, change: change)
  }

  @Test func fullPartialCapacityRefusesPlasmaWithoutAdvancingEventOrLosingCustody() throws {
    var fixture = try ledgerImpactFixture(mining: true)
    try verifyFullPartialCapacity(&fixture)
  }

  @Test func plasmaTerminalDamageCommitsOnlyTheTombstoneAndHasNoOreYield() throws {
    let fixture = try ledgerImpactFixture(mining: true, fragileRock: true)
    let rock = try #require(fixture.rock)
    var ordinary = MiningLedger(seed: 17)
    var scoped = ordinary
    let incident = CombatIncident(
      id: fixture.eventID, physicalTime: fixture.context.physicalTime, origin: fixture.origin,
      victim: fixture.proof.currentVictim, kind: .plasma, outcome: .destruction,
      position: fixture.context.player.position, victimLegalBeforeAttack: nil,
      firstAggressor: nil, victimRole: nil, victimIsStation: false)
    let expected = ordinary.hit(rock: rock, incident: incident, damage: fixture.proof.damage)
    #expect(expected == .destroyed)
    let evaluatedResult14 =
      scoped.hit(
        rock: rock, proof: fixture.proof, eventID: fixture.eventID,
        context: fixture.context) == expected
    #expect(evaluatedResult14)
    #expect(
      scoped == ordinary && scoped.isDepleted(rock.identity) && scoped.pendingPayloads.isEmpty)
    #expect(scoped.valid)
  }

  @Test func plasmaDestructionPreservesAFullOrdinaryOreQueueInsteadOfRequiringYieldCapacity() throws
  {
    var fixture = try ledgerImpactFixture(mining: true, fragileRock: true)
    var ledger = MiningLedger(seed: 17)
    var reachedCapacity = false
    // Seed retained custody through the unchanged ordinary ledger API. Only the new plasma
    // operation below uses the actual geometric sealed producer; no mission capability is faked.
    for index in 0..<300 {
      let rock = MiningRock(
        identity: .init(
          system: .init(galaxy: 1, system: index / 48),
          field: UInt16((index % 48) / 12), rock: UInt16(index % 12)),
        position: .init(100, 200, 300), radius: 40, energy: 1)
      let evaluatedResult15 = fixture.game.commander.flightSimulation.allocateIncident()
      let event = try #require(evaluatedResult15)
      let ordinary = CombatIncident(
        id: event, physicalTime: fixture.context.physicalTime, origin: fixture.origin,
        victim: fixture.proof.currentVictim, kind: .laser, outcome: .destruction,
        position: rock.position, victimLegalBeforeAttack: nil, firstAggressor: nil,
        victimRole: nil, victimIsStation: false, laser: .mining)
      if ledger.hit(rock: rock, incident: ordinary, damage: 2) == .capacityRefused {
        reachedCapacity = true
        break
      }
    }
    try #require(reachedCapacity && ledger.valid && !ledger.pendingPayloads.isEmpty)
    let custody = ledger.pendingPayloads
    let rock = try #require(fixture.rock)
    let evaluatedResult16 = fixture.game.commander.flightSimulation.allocateIncident()
    let event = try #require(evaluatedResult16)
    let evaluatedResult17 =
      ledger.hit(
        rock: rock, proof: fixture.proof, eventID: event,
        context: fixture.context) == .destroyed
    #expect(evaluatedResult17)
    #expect(ledger.pendingPayloads == custody && ledger.isDepleted(rock.identity) && ledger.valid)
  }

  @Test func futurePresentLaunchRefusesBeforeEventOrDeathWhileExactNowAndOlderRemainValid() throws {
    var fixture = try ledgerImpactFixture(reentry: true, emissionTime: 2)
    try verifyLaunchTimes(&fixture)
  }

  // Keep verification-only Game copies out of the caller frame during fixture launch.
  private func verifyScopedCrime(_ fixture: inout LedgerImpactFixture) throws {
    var ordinary = CrimeLedger()
    var scoped = CrimeLedger()
    let point =
      fixture.context.player.position
      + fixture.context.player.orientation.apply(fixture.proof.hit.point)
    let incident = CombatIncident(
      id: fixture.eventID, physicalTime: fixture.context.physicalTime, origin: fixture.origin,
      victim: fixture.proof.currentVictim, kind: .plasma, outcome: .destruction,
      position: point, victimLegalBeforeAttack: fixture.context.player.legal,
      firstAggressor: nil, victimRole: nil, victimIsStation: false)
    let expected = ordinary.record(incident, context: fixture.context)
    let actual = scoped.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .destruction, context: fixture.context)
    #expect(actual == expected)
    var changed = fixture.game
    changed.gameplayRevision += 1
    let stale = try #require(changed.gameplayContext())
    let before = scoped
    let evaluatedResult7 = !scoped.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID + 1, outcome: .hit, context: stale
    ).accepted
    #expect(evaluatedResult7)
    #expect(scoped == before)
  }

  private func verifyChangedActualContact(_ fixture: inout LedgerImpactFixture, change: String)
    throws
  {
    var changed = fixture.game
    if change == "target" {
      let index = try #require(changed.bodies.firstIndex { $0.id == fixture.proof.targetBody?.id })
      changed.bodies[index].energy -= 1
    } else if change == "source-role" {
      let index = try #require(
        changed.bodies.firstIndex { $0.physical?.identity == fixture.proof.currentSource })
      changed.bodies[index].physical?.npc = .init(
        role: .police, origin: fixture.context.system, destination: fixture.context.system)
    } else {
      changed.bodies.removeAll { $0.physical?.identity == fixture.proof.currentSource }
    }
    let current = try #require(changed.gameplayContext())
    var ledger = CrimeLedger()
    let before = ledger
    let evaluatedResult11 = !ledger.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .hit, context: current
    ).accepted
    #expect(evaluatedResult11)
    #expect(ledger == before)
  }

  private func verifyFullPartialCapacity(_ fixture: inout LedgerImpactFixture) throws {
    let rock = try #require(fixture.rock)
    try #require(rock.energy > fixture.proof.damage)
    var encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(MiningLedger(seed: 17)))
        as? [String: Any])
    var pairs: [Any] = []
    for index in 0..<(MiningLedger.maximumPartial + 1) {
      let id = RockIdentity(
        system: .init(galaxy: 1, system: index / 48),
        field: UInt16((index % 48) / 12), rock: UInt16(index % 12))
      pairs.append(try JSONSerialization.jsonObject(with: JSONEncoder().encode(id)))
      pairs.append(100.0)
      if pairs.count == MiningLedger.maximumPartial * 2 { break }
    }
    encoded["partial"] = pairs
    encoded["lastIncident"] = fixture.eventID - 1 == 0 ? 1 : fixture.eventID - 1
    var ledger = try JSONDecoder().decode(
      MiningLedger.self,
      from: JSONSerialization.data(withJSONObject: encoded))
    let before = ledger
    // The next native allocation is newer than the retained ledger's previous physical event.
    var host = fixture.game
    let evaluatedResult12 = host.commander.flightSimulation.allocateIncident()
    let event = try #require(evaluatedResult12)
    let evaluatedResult13 =
      ledger.hit(
        rock: rock, proof: fixture.proof, eventID: event,
        context: fixture.context) == .capacityRefused
    #expect(evaluatedResult13)
    #expect(ledger == before && !ledger.isDepleted(rock.identity))
    #expect(ledger.remainingEnergy(for: rock) == rock.energy && ledger.pendingPayloads.isEmpty)
  }

  private func verifyLaunchTimes(_ fixture: inout LedgerImpactFixture) throws {
    try #require(fixture.proof.archive?.origin.emittedAt == 2)
    var earlier = fixture.game
    // Model an admitted persisted clock older than the retained launch; the proof itself
    // came from the real producer at time two, without a fabricated sealed constructor.
    earlier.commander.flightSimulation.physicalTime = 1
    let current = try #require(earlier.gameplayContext())
    var ledger = CrimeLedger()
    let before = ledger
    let evaluatedResult18 = !ledger.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .destruction, context: current
    ).accepted
    #expect(evaluatedResult18)
    #expect(ledger == before)
    let exact = ledger.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .hit, context: fixture.context)
    #expect(exact.accepted && exact.unlawful)
    var later = fixture.game
    later.commander.flightSimulation.advancePhysicalTime(1)
    let olderLaunch = try #require(later.gameplayContext())
    var independent = CrimeLedger()
    let evaluatedResult19 = independent.recordMissionReentryImpact(
      fixture.proof, eventID: fixture.eventID, outcome: .hit, context: olderLaunch
    ).accepted
    #expect(evaluatedResult19)
  }

}
