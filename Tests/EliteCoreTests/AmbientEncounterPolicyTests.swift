import Foundation
import Testing

@testable import EliteCore

struct AmbientEncounterPolicyTests {
  @Test func perMemberIndependentSamplesCoverBothMixedOutcomesAndNinetyPercentRates() throws {
    var hostile = 0
    var wanted = 0
    var mixed = 0
    var neither = 0
    for index in 1...10000 {
      let identity = SpawnIdentity(
        system: .init(galaxy: 0, system: 7), visit: 1,
        sequence: UInt64(index / 5 + 1), member: UInt16(index % 5), producer: .ambient)
      let value = try #require(
        AmbientEncounterPolicy.sample(identity: identity, seed: 42, government: 0, role: .pirate))
      #expect(
        value
          == AmbientEncounterPolicy.sample(
            identity: identity, seed: 42, government: 0, role: .pirate))
      if value.hostile { hostile += 1 }
      if value.wanted == true { wanted += 1 }
      if value.hostile != (value.wanted == true) { mixed += 1 }
      if !value.hostile && value.wanted == false { neither += 1 }
      #expect(value.legalOverride?.wanted == value.wanted)
      #expect(value.legalOverride?.bountyTenths == (value.wanted == true ? 50 : 0))
    }
    #expect((8700...9300).contains(hostile) && (8700...9300).contains(wanted))
    #expect((1400...2200).contains(mixed) && (50...180).contains(neither))
  }

  @Test func occurrenceAndSuppressionKeepTheirOriginalDrawAndDeadlineSchedule() {
    var anarchy = EncounterDirector(context: ecologyContext(seed: 31, government: 0))
    var corporate = EncounterDirector(context: ecologyContext(seed: 31, government: 7))
    var suppressed = EncounterDirector(context: ecologyContext(seed: 31, government: 0))
    var protection = MissionProtection()
    protection.suppressAmbientShips = true
    _ = anarchy.advance(context: ecologyContext(time: 120, seed: 31, government: 0))
    _ = corporate.advance(context: ecologyContext(time: 120, seed: 31, government: 7))
    let absent = suppressed.advance(
      context: ecologyContext(time: 120, seed: 31, government: 0, protection: protection))
    #expect(absent.batches.isEmpty && suppressed.pendingRequests.isEmpty)
    #expect(
      anarchy.decisionCount == corporate.decisionCount
        && anarchy.decisionCount == suppressed.decisionCount)
    #expect(
      anarchy.nextDecisionTime == corporate.nextDecisionTime
        && anarchy.nextDecisionTime == suppressed.nextDecisionTime)
  }

  @Test func exactGovernmentHostilityTablePreservesOtherGovernmentsLegalPolicy() throws {
    #expect(AmbientEncounterPolicy.hostilityPercentages == [90, 70, 50, 40, 30, 20, 10, 0])
    for government in 0..<8 {
      var hostiles = 0
      for index in 1...3000 {
        let identity = SpawnIdentity(
          system: .init(galaxy: 0, system: 7), visit: 1, sequence: UInt64(index), member: 0,
          producer: .ambient)
        let sampled = try #require(
          AmbientEncounterPolicy.sample(
            identity: identity, seed: 42, government: government, role: .trader))
        if sampled.hostile { hostiles += 1 }
        if government != 0 { #expect(sampled.legalOverride == nil) }
      }
      let expected = Double(AmbientEncounterPolicy.hostilityPercentages[government]) / 100
      #expect(abs(Double(hostiles) / 3000 - expected) < 0.04)
      if government == 7 { #expect(hostiles == 0) }
      if government != 0 {
        var director = EncounterDirector(context: ecologyContext(government: government))
        let requests = director.advance(context: ecologyContext(time: 120, government: government))
          .batches.flatMap(\.requests)
        for request in requests {
          #expect(request.npc?.legal.wanted == (request.npc?.role == .pirate))
          #expect(request.npc?.legal.bountyTenths == (request.npc?.role == .pirate ? 50 : 0))
        }
      }
    }
    let identity = SpawnIdentity(
      system: .init(galaxy: 0, system: 7), visit: 1, sequence: 1, member: 0, producer: .ambient)
    for role in [NPCRole.police, .escort, .mission] {
      #expect(
        AmbientEncounterPolicy.sample(identity: identity, seed: 1, government: 0, role: role) == nil
      )
    }
    let authored = SpawnIdentity(
      system: identity.system, visit: 1, sequence: 1, member: 0, producer: .mission)
    #expect(
      AmbientEncounterPolicy.sample(identity: authored, seed: 1, government: 0, role: .trader)
        == nil)
  }

  @Test(arguments: 0..<8)
  func actualAdmittedShipsAndNextProductionIntentsRetainSampledFacts(government: Int) throws {
    var base = Game(executive: false)
    let anarchy = try #require(base.systems.first { $0.government == government })
    base.commander.system = anarchy.id
    base.docked = false
    base.screen = .front
    base.bodies = []
    base.commander.cargo[CommodityIdentity.food.rawValue] = 1
    var flight = FlightSimulationState()
    var total = 0
    var hostile = 0
    var wanted = 0
    var peacefulPirates = 0
    for _ in 0..<300 {
      flight.enter(base.systemIdentity, arriving: false)
      flight.pose.position = .init(0, 0, -6000)
      var game = base
      game.commander.flightSimulation = flight
      game.ensurePhysicalActors()
      let initial = try #require(game.gameplayContext())
      try #require(initial.government == government)
      var director = EncounterDirector(context: initial)
      game.commander.flightSimulation.advancePhysicalTime(12)
      let context = try #require(game.gameplayContext())
      let plan = director.advance(context: context)
      let receipts = game.admitEncounterPlan(plan)
      director.acknowledge(receipts: receipts)
      let accepted = Set(receipts.compactMap(\.actor))
      let current = try #require(game.gameplayContext())
      let intents = TrafficIntent.intents(context: current)
      for body in game.bodies where body.physical.map({ accepted.contains($0.identity) }) == true {
        let physical = try #require(body.physical)
        let request = try #require(
          plan.batches.flatMap(\.requests).first { $0.identity == physical.spawnIdentity })
        let npc = try #require(physical.npc)
        let sampled = try #require(
          AmbientEncounterPolicy.sample(
            identity: request.identity, seed: initial.seed, government: government, role: npc.role))
        let expectedLegal =
          sampled.legalOverride
          ?? (npc.role == .pirate ? LegalRecord(value: 16, bountyTenths: 50) : .init())
        #expect(body.hostile == sampled.hostile && npc.legal == expectedLegal)
        let intent = try #require(intents.first { $0.actor == physical.identity })
        #expect((intent.action == .engage(current.player.identity)) == sampled.hostile)
        if !sampled.hostile && npc.role == .pirate { peacefulPirates += 1 }
        let snapshot = try #require(
          NPCPersistenceSnapshot.capture(
            body: body, pose: game.commander.flightSimulation.pose,
            physicalTime: context.physicalTime, protection: context.protection))
        #expect(
          try JSONDecoder().decode(
            NPCPersistenceSnapshot.self, from: JSONEncoder().encode(snapshot)) == snapshot)
        total += 1
        if body.hostile { hostile += 1 }
        if npc.legal.wanted { wanted += 1 }
      }
      let restored = try JSONDecoder().decode(
        EncounterDirector.self, from: JSONEncoder().encode(director))
      #expect(restored == director)
    }
    #expect(total > 100)
    let expected = Double(AmbientEncounterPolicy.hostilityPercentages[government]) / 100
    #expect(abs(Double(hostile) / Double(total) - expected) < 0.08)
    if government == 7 { #expect(hostile == 0 && peacefulPirates > 0) }
    if government == 0 {
      #expect(peacefulPirates > 0)
      #expect(Double(wanted) / Double(total) > 0.84 && Double(wanted) / Double(total) < 0.96)
    }
  }

  @Test(arguments: [NPCRole.trader, .miner])
  func actualFirstIllegalBeamKeepsGeneratedEngagementAfterLegalHistoryBecomesRecorded(role: NPCRole)
    throws
  {
    var base = Game(executive: false)
    base.commander.system = try #require(base.systems.first { $0.government == 0 }?.id)
    base.docked = false
    base.screen = .front
    base.bodies = []
    var flight = FlightSimulationState()
    var selected: (Game, ActorIdentity)?
    for _ in 0..<500 {
      flight.enter(base.systemIdentity, arriving: false)
      flight.pose.position = .init(0, 0, -6000)
      var game = base
      game.commander.flightSimulation = flight
      game.ensurePhysicalActors()
      let initial = try #require(game.gameplayContext())
      var director = EncounterDirector(context: initial)
      game.commander.flightSimulation.advancePhysicalTime(12)
      let context = try #require(game.gameplayContext())
      let plan = director.advance(context: context)
      let receipts = game.admitEncounterPlan(plan)
      let accepted = Set(receipts.compactMap(\.actor))
      if let body = game.bodies.first(where: {
        $0.hostile && $0.physical?.npc?.role == role
          && $0.physical.map { accepted.contains($0.identity) } == true
      }), let actor = body.physical?.identity {
        selected = (game, actor)
        break
      }
    }
    let choice = try #require(selected)
    var game = choice.0
    let actor = choice.1
    let player = try #require(game.commander.flightSimulation.player)
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    let original = try #require(game.bodies[index].physical?.npc)
    try #require(original.legalProvenance == .generated && original.routeProvenance == .generated)
    try #require(original.intention == .engage(player))
    // Reposition the actually admitted source for its real occluded beam path, not a fake crime flag.
    game.commander.flightSimulation.pose.position = .init(0, 0, -30000)
    game.bodies[index].position = .init(0, 0, 500)
    let source = game.bodies[index].id
    game.bodies.removeAll { $0.physical?.identity != actor }
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    game.emitLegacyNPCBeam(bodyID: source, damage: 1)
    let afterShot = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(game.energy < energy || game.frontShield < front || game.rearShield < rear)
    #expect((afterShot.physical?.npc?.legal.value ?? 0) > original.legal.value)
    #expect(afterShot.physical?.npc?.legalProvenance == .recorded)
    #expect(afterShot.physical?.npc?.routeProvenance == .generated)
    let current = try #require(game.gameplayContext())
    #expect(
      TrafficIntent.intents(context: current).first { $0.actor == actor }?.action == .engage(player)
    )
    game.advanceGameplayEncounters(delta: 0.01)
    let continued = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(continued.hostile && continued.physical?.npc?.intention == .engage(player))
    #expect(continued.physical?.npc?.legalProvenance == .recorded)
  }

  @Test func realRetreatSelfDefenceRetargetAndProtectionOverrideIdleDispositionRetention() throws {
    let base = ecologyContext()
    let id = ActorIdentity(system: base.system, visit: 1, entity: 30)
    func actor(intent: NPCAction, aggressor: ActorIdentity? = nil) -> ActorSnapshot {
      var npc = NPCState(role: .pirate, origin: base.system, destination: base.system)
      npc.legalProvenance = .generated
      npc.routeProvenance = .generated
      npc.intention = intent
      npc.firstAggressor = aggressor
      return .init(
        identity: id, hull: .sidewinder, position: .init(0, 0, 9000), orientation: .init(),
        velocity: .init(0, 0, 0), energy: 100, maximumEnergy: 100, maximumSpeedUnitsPerSecond: 144,
        legal: .init(), npc: npc, rock: nil, payload: nil)
    }
    let engagement = NPCAction.engage(base.player.identity)
    let destination = NPCAction.navigate(position: base.anchors.arrival, speedUnitsPerSecond: 100)
    let aggressive = actor(intent: engagement)
    #expect(
      AmbientEncounterPolicy.preserveIntent(of: aggressive, context: base, proposed: destination)
        == engagement)
    let peaceful = actor(intent: destination)
    #expect(
      AmbientEncounterPolicy.preserveIntent(of: peaceful, context: base, proposed: engagement)
        == destination)
    #expect(
      AmbientEncounterPolicy.preserveIntent(of: peaceful, context: base, proposed: .engage(id))
        == destination)
    #expect(
      AmbientEncounterPolicy.preserveIntent(
        of: peaceful, context: ecologyContext(government: 7), proposed: engagement) == destination)
    let attacked = actor(intent: destination, aggressor: base.player.identity)
    #expect(
      AmbientEncounterPolicy.preserveIntent(of: attacked, context: base, proposed: engagement)
        == engagement)
    #expect(
      AmbientEncounterPolicy.preserveIntent(
        of: attacked, context: ecologyContext(government: 7), proposed: engagement) == engagement)
    for action in [
      NPCAction.flee(base.player.identity), .engage(id),
      .scoop(.ore(.init(system: base.system, field: 0, rock: 0), fragment: 0)),
    ] {
      #expect(
        AmbientEncounterPolicy.preserveIntent(of: aggressive, context: base, proposed: action)
          == action)
    }
    var protection = MissionProtection()
    protection.protectedActors.insert(id)
    #expect(
      AmbientEncounterPolicy.preserveIntent(
        of: aggressive, context: ecologyContext(protection: protection), proposed: destination)
        == destination)
  }
}

extension AmbientEncounterPolicyTests {
  @Test(arguments: Array(0..<8))
  func actualFreshLaunchTrafficUsesGovernmentPolicyBeforeItsFirstPersistentCapture(
    government: Int
  ) throws {
    var game = Game(executive: false)
    game.commander.system = try #require(game.systems.first { $0.government == government }?.id)
    game.launch()
    try #require(!game.docked && game.screen == .front)
    let body = try #require(game.bodies.first { $0.id == 1 && $0.hull == .cobra })
    let physical = try #require(body.physical)
    let npc = try #require(physical.npc)
    let policy = try #require(
      AmbientEncounterPolicy.nativeLaunch(
        actor: physical.identity, seed: game.gameplaySeed, government: government, role: .trader))
    #expect(physical.spawnIdentity == nil && body.hostile == policy.hostile)
    #expect(npc.routeProvenance == .generated && npc.legalProvenance == .generated)
    #expect(
      npc.intention
        == (policy.hostile
          ? .engage(try #require(game.commander.flightSimulation.player))
          : .dock(try #require(game.commander.flightSimulation.anchors?.station.identity))))
    if government == 0 { #expect(npc.legal == policy.legalOverride) }
    if government == 7 { #expect(!body.hostile && !npc.legal.wanted) }
    let snapshot = try #require(game.commander.npcPersistence.snapshot(for: physical.identity))
    #expect(snapshot.npc == npc && snapshot.energy == body.energy)
    #expect(game.commander.valid)
  }
}
