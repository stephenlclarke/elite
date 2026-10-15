import Foundation

private struct EncounterRandom: Codable, Sendable {
  var state: UInt64
  mutating func next() -> UInt64 {
    state &+= 0x9e37_79b9_7f4a_7c15
    return Self.mix(state)
  }
  static func mix(_ input: UInt64) -> UInt64 {
    var value = input
    value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
    return value ^ (value >> 31)
  }
  static func unit(_ word: UInt64) -> Double { Double(word >> 11) / 9_007_199_254_740_992 }
}

/// Runtime-owned deterministic proposals. Only receipts establish actual admission.
public struct EncounterDirector: Codable, Sendable {
  public private(set) var system: SystemIdentity
  public private(set) var visit: UInt64
  public private(set) var nextDecisionTime: Double
  public private(set) var decisionCount: UInt64 = 0
  public private(set) var admittedCount: UInt64 = 0
  public private(set) var pendingRequests: [SpawnRequest] = []
  private var random: EncounterRandom

  public init(context: EncounterContext) {
    system = context.system
    visit = context.visit
    random = .init(
      state: context.seed ^ 0x454e_434f_554e_5445
        ^ EncounterRandom.mix(UInt64(context.system.galaxy) &* 257 &+ UInt64(context.system.system))
        ^ EncounterRandom.mix(context.visit))
    nextDecisionTime =
      (context.physicalTime.isFinite ? context.physicalTime : 0) + 8 + EncounterRandom.unit(
        random.next()) * 4
  }

  public mutating func advance(context: EncounterContext) -> EncounterPlan {
    guard context.physicalTime.isFinite else {
      return .init(
        system: context.system, visit: context.visit, revision: context.revision, batches: [],
        intents: [])
    }
    if context.system != system || context.visit != visit { self = .init(context: context) }
    var budget = context.budget
    budget.missionReserve = max(budget.missionReserve, context.protection.reservedSlots)
    for request in pendingRequests {
      budget.total += 1
      budget.active[request.population, default: 0] += 1
    }
    var batches: [SpawnBatch] = []
    while nextDecisionTime <= context.physicalTime {
      decisionCount &+= 1
      // All decisions consume the same draw schedule, including suppression/refusal.
      let draws = (0..<8).map { _ in random.next() }
      nextDecisionTime += 8 + EncounterRandom.unit(random.next()) * 4
      guard !context.protection.suppressAmbientShips else { continue }
      let region = EncounterGeography.region(at: context.player.position, anchors: context.anchors)
      let pirate =
        EncounterRandom.unit(draws[0]) < EncounterGeography.piratePressure(
          government: context.government, region: region) * 0.65
      let civilianChance: Double
      switch region {
      case .stationSecurity: civilianChance = 0.65
      case .tradeLane: civilianChance = 0.55
      case .miningBand: civilianChance = 0.5
      case .deepSpace: civilianChance = 0.12
      }
      guard pirate || EncounterRandom.unit(draws[1]) < civilianChance else { continue }
      let role: NPCRole =
        pirate ? .pirate : (region == .miningBand || draws[2] % 4 == 0 ? .miner : .trader)
      let population: PopulationClass = pirate ? .pirate : .civilian
      let highPressure = context.government <= 1 && region == .tradeLane
      let count = pirate ? (highPressure ? 2 + Int(draws[2] % 4) : 1 + Int(draws[2] % 3)) : 1
      guard budget.ordinaryRemaining >= count,
        budget.active[population, default: 0] + count <= population.maximum
      else { continue }
      guard let requests = spawn(role: role, count: count, draws: draws, context: context) else {
        continue
      }
      batches.append(.init(requests: requests, atomic: pirate))
      pendingRequests.append(contentsOf: requests)
      budget.total += count
      budget.active[population, default: 0] += count
    }
    return .init(
      system: system, visit: visit, revision: context.revision,
      batches: batches, intents: TrafficIntent.intents(context: context))
  }

  public mutating func acknowledge(receipts: [SpawnReceipt]) {
    for receipt in receipts {
      guard let index = pendingRequests.firstIndex(where: { $0.identity == receipt.request }) else {
        continue
      }
      pendingRequests.remove(at: index)
      if let actor = receipt.actor, receipt.refusal == nil,
        actor.system == system, actor.visit == visit
      {
        admittedCount &+= 1
      }
    }
  }

  private func spawn(role: NPCRole, count: Int, draws: [UInt64], context: EncounterContext)
    -> [SpawnRequest]?
  {
    let pirate = role == .pirate
    let outbound = draws[3] & 1 == 0
    let nearby = SystemIdentity(
      galaxy: system.galaxy, system: (system.system + 1 + Int(draws[6] % 255)) % 256)
    let origin = outbound ? system : nearby
    let destination = outbound ? nearby : system
    var npc = NPCState(role: role, origin: origin, destination: destination)
    if pirate { npc.legal = .init(value: 16, bountyTenths: 50) }
    if role == .trader {
      let commodities: [CommodityIdentity] = [
        .food, .textiles, .liquor, .luxuries, .computers, .machinery, .alloys, .furs, .minerals,
        .gold, .platinum,
      ]
      npc.ordinaryCargo = [
        .init(
          commodity: commodities[Int(draws[6] % UInt64(commodities.count))],
          quantity: 1 + Int(draws[7] % 12))
      ]
    }
    npc.intention =
      outbound
      ? .navigate(position: context.anchors.arrival, speedUnitsPerSecond: 100)
      : .dock(context.anchors.station.identity)
    var positions: [Vector3] = []
    for attempt in 0..<16 {
      if !pirate && attempt > 0 { break }
      let salt = UInt64(attempt) &* 0x9e37_79b9_7f4a_7c15
      var direction = Vector3(
        EncounterRandom.unit(EncounterRandom.mix(draws[3] &+ salt)) * 2 - 1,
        EncounterRandom.unit(EncounterRandom.mix(draws[4] &+ salt)) * 2 - 1,
        EncounterRandom.unit(EncounterRandom.mix(draws[5] &+ salt)) * 2 - 1)
      direction = direction * (1 / max(0.001, direction.length))
      let base =
        pirate
        ? context.player.position + direction
          * (max(5000, context.perceptionRadius + 1200) + Double(attempt) * 700)
        : (outbound ? context.anchors.station.exitPosition : context.anchors.arrival)
      positions = (0..<count).map { base + Vector3(Double($0) * 240, 0, Double($0) * 200) }
      if positions.allSatisfy({ position in
        EncounterGeography.safe(position, context: context, civilianEntry: !pirate)
          && !pendingRequests.contains { ($0.position - position).length < 180 }
      }) {
        break
      }
      positions = []
    }
    guard positions.count == count else { return nil }
    return positions.enumerated().map { member, position in
      let heading =
        (!pirate && outbound
        ? context.anchors.station.exitDirection : context.anchors.station.position - position).unit
      var orientation = Basis3()
      orientation.z = heading.length > 0 ? heading : .init(0, 0, 1)
      let up = abs(orientation.z.y) > 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)
      orientation.x = up.cross(orientation.z).unit
      orientation.y = orientation.z.cross(orientation.x).unit
      return
        .init(
          identity: .init(
            system: system, visit: visit, sequence: decisionCount, member: UInt16(member),
            producer: .ambient),
          population: pirate ? .pirate : .civilian, hull: pirate ? .sidewinder : .cobra,
          position: position, orientation: orientation, velocity: heading * 60, npc: npc,
          rock: nil, payload: nil, priority: .ordinary)
    }
  }
}
