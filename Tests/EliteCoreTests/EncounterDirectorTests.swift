import Foundation
import Testing

@testable import EliteCore

func ecologyActor(
  _ entity: UInt64, role: NPCRole? = nil, position: Vector3 = .init(0, 0, 6000),
  energy: Double = 100, cargo: [CommodityAmount] = [], intention: NPCAction? = nil,
  aggressor: ActorIdentity? = nil, rock: RockIdentity? = nil, payload: PayloadIdentity? = nil
) -> ActorSnapshot {
  let system = SystemIdentity(galaxy: 0, system: 7)
  var npc = role.map { NPCState(role: $0, origin: system, destination: system) }
  npc?.ordinaryCargo = cargo
  npc?.intention = intention
  npc?.firstAggressor = aggressor
  return .init(
    identity: .init(system: system, visit: 1, entity: entity),
    hull: role == .police ? .viper : .cobra,
    position: position, orientation: .init(), velocity: .init(0, 0, 0), energy: energy,
    maximumEnergy: 100, maximumSpeedUnitsPerSecond: 144, legal: .init(), npc: npc,
    rock: rock, payload: payload, ordinaryCargo: cargo)
}

func ecologyContext(
  time: Double = 0, seed: UInt64 = 1, government: Int = 0,
  position: Vector3 = .init(0, 0, 6000), actors: [ActorSnapshot] = [],
  protection: MissionProtection = .init(), budget: AdmissionBudget = .init(),
  playerCargo: [CommodityAmount] = []
) -> EncounterContext {
  let system = SystemIdentity(galaxy: 0, system: 7)
  let station = StationAnchor(
    identity: .init(system: system, visit: 1, entity: 1),
    position: .init(0, 0, 0), orientation: .init(), exitPosition: .init(0, 0, 600),
    exitDirection: .init(0, 0, 1))
  let anchors = SystemAnchors(
    system: system, station: station, arrival: .init(0, 0, 12000),
    planet: .init(position: .init(20000, 0, 0), radius: 1000),
    sun: .init(position: .init(50000, 0, 0), radius: 1000))
  return .init(
    system: system, seed: seed, government: government, visit: 1, revision: 1,
    physicalTime: time, anchors: anchors,
    player: ecologyActor(0, position: position, cargo: playerCargo),
    actors: actors, protection: protection, budget: budget, perceptionRadius: 3000)
}

@Test func encounterDeadlinePartitionAndSaveReplayProduceIdenticalRequests() throws {
  let start = ecologyContext()
  var whole = EncounterDirector(context: start)
  #expect((8...12).contains(whole.nextDecisionTime))
  let expected = whole.advance(context: ecologyContext(time: 120))
  var partitioned = EncounterDirector(context: start)
  var batches: [SpawnBatch] = []
  for time in 1...120 {
    batches += partitioned.advance(context: ecologyContext(time: Double(time))).batches
  }
  #expect(batches == expected.batches)
  #expect(partitioned.decisionCount == whole.decisionCount)
  #expect(partitioned.nextDecisionTime == whole.nextDecisionTime)
  let data = try JSONEncoder().encode(partitioned)
  var restored = try JSONDecoder().decode(EncounterDirector.self, from: data)
  #expect(restored == partitioned)
  #expect(
    restored.advance(context: ecologyContext(time: 160))
      == partitioned.advance(context: ecologyContext(time: 160)))
}

@Test func encounterSuppressionAndBudgetDenialDoNotAccumulateBurstsOrAdmitActors() {
  let start = ecologyContext()
  var director = EncounterDirector(context: start)
  var protection = MissionProtection()
  protection.suppressAmbientShips = true
  let suppressed = director.advance(context: ecologyContext(time: 120, protection: protection))
  #expect(
    suppressed.batches.isEmpty && director.decisionCount >= 10 && director.pendingRequests.isEmpty)
  let resumed = director.advance(context: ecologyContext(time: 120))
  #expect(resumed.batches.isEmpty && director.admittedCount == 0)
  var budget = AdmissionBudget()
  budget.total = 128
  #expect(director.advance(context: ecologyContext(time: 240, budget: budget)).batches.isEmpty)
  #expect(director.advance(context: ecologyContext(time: 240)).batches.isEmpty)
}

@Test func encounterReceiptsOnlyCountActualAdmissionAndIgnoreDuplicates() {
  var director = EncounterDirector(context: ecologyContext())
  let plan = director.advance(context: ecologyContext(time: 120))
  let requests = plan.batches.flatMap(\.requests)
  #expect(!requests.isEmpty && director.admittedCount == 0)
  let receipts = requests.enumerated().map { index, request in
    SpawnReceipt(
      request: request.identity,
      actor: index == 0
        ? .init(system: request.identity.system, visit: request.identity.visit, entity: 100) : nil,
      refusal: index == 0 ? nil : .reservedCapacity)
  }
  director.acknowledge(receipts: receipts)
  director.acknowledge(receipts: receipts)
  #expect(director.admittedCount == 1 && director.pendingRequests.isEmpty)
  #expect(director.advance(context: ecologyContext(time: 120)).batches.isEmpty)
}

@Test func encounterPacksAreAtomicBoundedSeparatedAndRespectSharedReserves() {
  var director = EncounterDirector(context: ecologyContext())
  var budget = AdmissionBudget()
  budget.maximum = 20
  let context = ecologyContext(time: 120, budget: budget)
  let plan = director.advance(context: context)
  let requests = plan.batches.flatMap(\.requests)
  #expect(requests.count <= 8)
  #expect(Set(requests.map(\.identity)).count == requests.count)
  for batch in plan.batches {
    if batch.requests.first?.population == .pirate {
      #expect(batch.atomic && (2...5).contains(batch.requests.count))
      #expect(
        batch.requests.allSatisfy {
          ($0.position - context.player.position).length > context.perceptionRadius
        })
    }
    for request in batch.requests {
      #expect(request.priority == .ordinary)
      #expect(
        EncounterGeography.safe(
          request.position, context: context, civilianEntry: request.population == .civilian))
    }
  }
  budget.active[.pirate] = 7
  var full = EncounterDirector(context: ecologyContext())
  let constrained = full.advance(context: ecologyContext(time: 120, budget: budget))
  #expect(!constrained.batches.contains { $0.requests.first?.population == .pirate })
}

@Test func encounterSeededA11SamplesRetainGovernmentGeographyAndLawfulDeepSpaceRisk() {
  func pirateCount(government: Int, position: Vector3) -> Int {
    (1...1000).reduce(0) { total, seed in
      let initial = ecologyContext(seed: UInt64(seed), government: government, position: position)
      var director = EncounterDirector(context: initial)
      return total
        + director.advance(
          context: ecologyContext(
            time: 12, seed: UInt64(seed), government: government,
            position: position)
        ).batches.flatMap(\.requests).filter { $0.population == .pirate }.count
    }
  }
  let anarchyLane = pirateCount(government: 0, position: .init(0, 0, 6000))
  let corporateLane = pirateCount(government: 7, position: .init(0, 0, 6000))
  let anarchyStation = pirateCount(government: 0, position: .init(0, 0, 0))
  let corporateDeep = pirateCount(government: 7, position: .init(0, 15000, 6000))
  #expect(anarchyLane > corporateLane * 4)
  #expect(anarchyLane > anarchyStation * 4)
  #expect(corporateDeep > 0 && corporateDeep < corporateLane)
}

@Test func encounterGeographyUsesSegmentsPriorityAndRigidCoordinateTransforms() {
  let anchors = ecologyContext().anchors
  #expect(
    EncounterGeography.region(at: anchors.station.position, anchors: anchors) == .stationSecurity)
  #expect(EncounterGeography.region(at: .init(0, 0, 6000), anchors: anchors) == .tradeLane)
  #expect(EncounterGeography.region(at: .init(32000, 0, 0), anchors: anchors) == .miningBand)
  #expect(EncounterGeography.region(at: .init(0, 15000, 6000), anchors: anchors) == .deepSpace)
  #expect(
    EncounterGeography.distanceToSegment(.init(20, 4, 0), from: .init(0, 0, 0), to: .init(10, 0, 0))
      == sqrt(116))
  #expect(
    EncounterGeography.distanceToSegment(.init(0, 3, 4), from: .init(0, 0, 0), to: .init(0, 0, 0))
      == 5)
  func transform(_ value: Vector3) -> Vector3 {
    value.rotated(pitch: 0.4, roll: 0.7, yaw: -0.3) + .init(500, 600, 700)
  }
  let station = StationAnchor(
    identity: anchors.station.identity, position: transform(anchors.station.position),
    orientation: .init(), exitPosition: transform(anchors.station.exitPosition),
    exitDirection: anchors.station.exitDirection)
  let moved = SystemAnchors(
    system: anchors.system, station: station, arrival: transform(anchors.arrival),
    planet: .init(position: transform(anchors.planet.position), radius: anchors.planet.radius),
    sun: .init(position: transform(anchors.sun.position), radius: anchors.sun.radius))
  for position in [Vector3(0, 0, 6000), .init(32000, 0, 0), .init(0, 15000, 6000)] {
    #expect(
      EncounterGeography.region(at: position, anchors: anchors)
        == EncounterGeography.region(at: transform(position), anchors: moved))
  }
}
