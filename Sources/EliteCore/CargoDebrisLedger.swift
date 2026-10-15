import Foundation

public enum CargoDeathRefusal: String, Codable, Sendable {
  case protectedSource, notDestroyedNPC, invalidManifest, unrepresentableManifest
  case invalidPose, capacity, earlierSettlement, invalidLedger
}

public enum CargoDeathRegistration: Equatable, Codable, Sendable {
  case registered(lots: Int)
  case alreadyRegistered
  case refused(CargoDeathRefusal)
}

private struct DebrisSource: Equatable, Codable, Sendable {
  let actor: ActorIdentity
  let settlementID: UInt64
  let manifest: [CommodityAmount]
  var remaining: [CommodityAmount]
  let position: Vector3
  let orientation: Basis3
  let velocity: Vector3
  let physicalTime: Double
  let lotCount: Int
  var nextLot = 0
}

private struct DebrisLot: Equatable, Codable, Sendable {
  var payload: TypedCargoPayload
  var updatedAt: Double
}

private struct BlockedCargoDeath: Equatable, Codable, Sendable {
  let actor: ActorIdentity
  let settlementID: UInt64
}

/// Ordinary manifests settle by authoritative destruction event, never by removal/camera cull.
public struct CargoDebrisLedger: Equatable, Codable, Sendable {
  public static let maximumPending = 256
  public static let maximumSources = 256
  public static let maximumRecentDeaths = 256
  private var sources: [ActorIdentity: DebrisSource] = [:]
  private var pending: [PayloadIdentity: DebrisLot] = [:]
  private var offers: [SpawnIdentity: PayloadIdentity] = [:]
  private var bindings: [PayloadIdentity: ActorIdentity] = [:]
  private var recentDeaths: [ActorIdentity] = []
  private var lastSettlementID: UInt64?
  private var blocked: BlockedCargoDeath?
  private var issuanceCursor: UInt64 = 0
  private var sequence: UInt64 = 0
  public init() {}

  public var pendingPayloads: [TypedCargoPayload] {
    pending.values.map(\.payload).sorted { Self.precedes($0.identity, $1.identity) }
  }

  public var valid: Bool {
    sources.count <= Self.maximumSources && pending.count <= Self.maximumPending
      && offers.count + bindings.count <= PopulationClass.cargo.maximum
      && recentDeaths.count <= Self.maximumRecentDeaths
      && sources.values.allSatisfy {
        (1...65536).contains($0.lotCount) && (0...$0.lotCount).contains($0.nextLot)
          && $0.manifest.allSatisfy(\.valid) && $0.remaining.allSatisfy(\.valid)
          && Self.lotCount($0.manifest) == $0.lotCount
          && Self.lotCount($0.remaining) == $0.lotCount - $0.nextLot
          && $0.position.finite && $0.velocity.finite && $0.physicalTime.isFinite
          && $0.physicalTime >= 0
          && $0.orientation.x.finite && $0.orientation.y.finite && $0.orientation.z.finite
      }
      && pending.values.allSatisfy {
        $0.payload.amount.valid && $0.payload.position.finite && $0.payload.velocity.finite
          && $0.updatedAt.isFinite
      }
  }

  public func unissuedManifest(for actor: ActorIdentity) -> [CommodityAmount] {
    sources[actor]?.remaining ?? []
  }

  /// Root processes destruction IDs in order and retains the same ID across capacity retries.
  @discardableResult
  public mutating func registerDeath(
    actor: ActorSnapshot, manifest: [CommodityAmount], settlementID: UInt64,
    physicalTime: Double, protection: MissionProtection
  ) -> CargoDeathRegistration {
    guard valid else { return .refused(.invalidLedger) }
    if lastSettlementID.map({ settlementID <= $0 }) == true
      || sources[actor.identity] != nil || recentDeaths.contains(actor.identity)
    {
      return .alreadyRegistered
    }
    if let blocked, blocked.settlementID != settlementID || blocked.actor != actor.identity {
      return .refused(.earlierSettlement)
    }
    guard !protection.protectedActors.contains(actor.identity), actor.npc?.role != .mission else {
      return .refused(.protectedSource)
    }
    guard actor.energy.isFinite, actor.energy <= 0, actor.hull.isTargetShip, actor.npc != nil else {
      return .refused(.notDestroyedNPC)
    }
    guard settlementID > 0, physicalTime.isFinite, physicalTime >= 0,
      actor.position.finite, actor.velocity.finite,
      actor.orientation.x.finite, actor.orientation.y.finite, actor.orientation.z.finite
    else { return .refused(.invalidPose) }
    guard let canonical = Self.canonical(manifest) else { return .refused(.invalidManifest) }
    guard let lots = Self.lotCount(canonical) else { return .refused(.unrepresentableManifest) }
    if protection.protectedPayloads.contains(where: {
      if case .wreck(let source, let lot) = $0 {
        return source == actor.identity && Int(lot) < lots
      }
      return false
    }) {
      return .refused(.protectedSource)
    }
    guard lots == 0 || sources.count < Self.maximumSources else {
      blocked = .init(actor: actor.identity, settlementID: settlementID)
      return .refused(.capacity)
    }
    lastSettlementID = settlementID
    blocked = nil
    if lots == 0 {
      rememberDeath(actor.identity)
    } else {
      sources[actor.identity] = .init(
        actor: actor.identity, settlementID: settlementID, manifest: canonical,
        remaining: canonical,
        position: actor.position, orientation: actor.orientation, velocity: actor.velocity,
        physicalTime: physicalTime, lotCount: lots)
      fillPending(physicalTime: physicalTime)
    }
    return .registered(lots: lots)
  }

  public mutating func pendingSpawnRequests(context: EncounterContext) -> [SpawnRequest] {
    guard valid, context.physicalTime.isFinite, context.physicalTime >= 0 else { return [] }
    fillPending(physicalTime: context.physicalTime)
    refreshPositions(context: context)
    let current = offers.filter { $0.key.system == context.system && $0.key.visit == context.visit }
    offers = current
    let capacity = min(
      PopulationClass.cargo.maximum,
      max(
        0,
        min(
          context.budget.ordinaryRemaining,
          PopulationClass.cargo.maximum - context.budget.active[.cargo, default: 0],
          PopulationClass.cargo.maximum - bindings.count)))
    let reserved = Set(offers.values)
    for item in pendingPayloads where offers.count < capacity {
      guard Self.system(of: item.identity) == context.system, bindings[item.identity] == nil,
        !reserved.contains(item.identity), !protected(item.identity, by: context.protection),
        sequence < UInt64.max
      else { continue }
      sequence += 1
      let identity = SpawnIdentity(
        system: context.system, visit: context.visit, sequence: sequence, member: 0,
        producer: .cargo)
      offers[identity] = item.identity
    }
    let requests: [SpawnRequest] = offers.sorted { $0.key.sequence < $1.key.sequence }.compactMap {
      identity, payload in
      guard let item = pending[payload]?.payload, !protected(payload, by: context.protection) else {
        return nil
      }
      return .init(
        identity: identity, population: .cargo, hull: .cargo, position: item.position,
        orientation: Basis3(), velocity: item.velocity, npc: nil, rock: nil,
        payload: payload, priority: .ordinary)
    }
    return Array(requests.prefix(capacity))
  }

  /// Refusal retains the exact offer key; replayed/late receipts cannot bind a new pod.
  public mutating func acknowledge(receipts: [SpawnReceipt]) {
    for receipt in receipts {
      guard let payload = offers[receipt.request], pending[payload] != nil,
        let actor = receipt.actor, receipt.refusal == nil,
        actor.system == receipt.request.system, actor.visit == receipt.request.visit,
        !bindings.values.contains(actor), bindings.count < PopulationClass.cargo.maximum
      else { continue }
      offers.removeValue(forKey: receipt.request)
      bindings[payload] = actor
    }
  }

  @discardableResult
  public mutating func updatePhysicalPose(
    actor: ActorIdentity, position: Vector3, velocity: Vector3, physicalTime: Double
  ) -> Bool {
    guard position.finite, velocity.finite, physicalTime.isFinite,
      let payload = bindings.first(where: { $0.value == actor })?.key,
      let lot = pending[payload], physicalTime >= lot.updatedAt
    else { return false }
    pending[payload] = .init(
      payload: .init(
        identity: payload, amount: lot.payload.amount, position: position, velocity: velocity),
      updatedAt: physicalTime)
    return true
  }

  public mutating func cull(actor: ActorIdentity) {
    bindings = bindings.filter { $0.value != actor }
  }

  public mutating func collect(
    payload: PayloadIdentity, into cargo: inout [Int], freeTonnes: Int,
    hasScoops: Bool, approachAllowed: Bool, protection: MissionProtection
  ) -> CargoCollectionReceipt {
    guard valid, let item = pending[payload]?.payload else { return .refused(.unavailable) }
    guard !protected(payload, by: protection) else { return .refused(.protectedPayload) }
    let receipt = item.collect(
      into: &cargo, freeTonnes: freeTonnes, hasScoops: hasScoops,
      approachAllowed: approachAllowed, protection: protection)
    if case .collected = receipt { settle(payload) }
    return receipt
  }

  @discardableResult
  public mutating func destroy(payload: PayloadIdentity, protection: MissionProtection? = nil)
    -> Bool
  {
    guard valid, pending[payload] != nil,
      !protected(payload, by: protection ?? MissionProtection())
    else { return false }
    settle(payload)
    return true
  }

  /// Dock/load may rebuild physical actors; neither expires the manifest or its lots.
  public mutating func resetPhysicalBindings(system: SystemIdentity) {
    offers = offers.filter { $0.key.system != system }
    bindings = bindings.filter { Self.system(of: $0.key) != system }
  }

  /// Travel is the only explicit abandonment operation; camera culling never calls this.
  public mutating func depart(system: SystemIdentity) {
    let abandoned = sources.keys.filter { $0.system == system }
    for actor in abandoned {
      sources.removeValue(forKey: actor)
      rememberDeath(actor)
    }
    pending = pending.filter { Self.system(of: $0.key) != system }
    resetPhysicalBindings(system: system)
    if let blocked, blocked.actor.system == system {
      lastSettlementID = max(lastSettlementID ?? 0, blocked.settlementID)
      rememberDeath(blocked.actor)
      self.blocked = nil
    }
  }

  private mutating func fillPending(physicalTime: Double) {
    while pending.count < Self.maximumPending {
      let available = sources.values.filter { !$0.remaining.isEmpty }.sorted {
        $0.settlementID < $1.settlementID
      }
      guard
        let next = available.first(where: { $0.settlementID > issuanceCursor }) ?? available.first
      else { return }
      guard let amount = next.remaining.first else { return }
      let quantity = min(amount.quantity, Self.chunkLimit(amount.commodity))
      let identity = PayloadIdentity.wreck(next.actor, lot: UInt16(next.nextLot))
      let slot = next.nextLot % Self.maximumPending
      let offset = Vector3(
        Double(slot % 8 - 4) * 80, Double(slot / 8 % 8 - 4) * 80, Double(slot / 64 + 1) * 80)
      let velocity = next.velocity + next.orientation.apply(offset.unit * 8)
      let position =
        next.position + next.orientation.apply(offset) + velocity
        * max(0, physicalTime - next.physicalTime)
      guard position.finite, velocity.finite else { return }
      pending[identity] = .init(
        payload: .init(
          identity: identity, amount: .init(commodity: amount.commodity, quantity: quantity),
          position: position, velocity: velocity), updatedAt: physicalTime)
      sources[next.actor]?.nextLot += 1
      sources[next.actor]?.remaining.removeFirst()
      if quantity < amount.quantity {
        sources[next.actor]?.remaining.insert(
          .init(commodity: amount.commodity, quantity: amount.quantity - quantity), at: 0)
      }
      issuanceCursor = next.settlementID
    }
  }

  private mutating func refreshPositions(context: EncounterContext) {
    for (payload, lot) in pending {
      if let actor = bindings[payload] {
        if let snapshot = context.actors.first(where: { $0.identity == actor }) {
          _ = updatePhysicalPose(
            actor: actor, position: snapshot.position, velocity: snapshot.velocity,
            physicalTime: context.physicalTime)
        }
      } else {
        let position =
          lot.payload.position + lot.payload.velocity * max(0, context.physicalTime - lot.updatedAt)
        if position.finite, context.physicalTime >= lot.updatedAt {
          pending[payload] = .init(
            payload: .init(
              identity: payload, amount: lot.payload.amount, position: position,
              velocity: lot.payload.velocity), updatedAt: context.physicalTime)
        }
      }
    }
  }

  private mutating func settle(_ payload: PayloadIdentity) {
    pending.removeValue(forKey: payload)
    bindings.removeValue(forKey: payload)
    offers = offers.filter { $0.value != payload }
    if case .wreck(let actor, _) = payload, sources[actor]?.remaining.isEmpty == true,
      !pending.keys.contains(where: {
        if case .wreck(let source, _) = $0 { return source == actor }
        return false
      })
    {
      sources.removeValue(forKey: actor)
      rememberDeath(actor)
    }
  }

  private mutating func rememberDeath(_ actor: ActorIdentity) {
    recentDeaths.append(actor)
    if recentDeaths.count > Self.maximumRecentDeaths {
      recentDeaths.removeFirst(recentDeaths.count - Self.maximumRecentDeaths)
    }
  }

  private func protected(_ payload: PayloadIdentity, by protection: MissionProtection) -> Bool {
    guard case .wreck(let actor, _) = payload else { return true }
    return protection.protectedActors.contains(actor)
      || protection.protectedPayloads.contains(payload)
  }

  private static func canonical(_ manifest: [CommodityAmount]) -> [CommodityAmount]? {
    var totals: [CommodityIdentity: Int] = [:]
    for amount in manifest {
      guard amount.valid, totals[amount.commodity, default: 0] <= Int.max / 17 - amount.quantity
      else { return nil }
      totals[amount.commodity, default: 0] += amount.quantity
    }
    return CommodityIdentity.allCases.compactMap { commodity in
      totals[commodity].map { .init(commodity: commodity, quantity: $0) }
    }
  }

  private static func lotCount(_ manifest: [CommodityAmount]) -> Int? {
    var total = 0
    for amount in manifest {
      let count = (amount.quantity - 1) / chunkLimit(amount.commodity) + 1
      guard count <= 65536 - total else { return nil }
      total += count
    }
    return total
  }

  private static func chunkLimit(_ commodity: CommodityIdentity) -> Int {
    switch commodity.unit {
    case "kg": 1000
    case "g": 1_000_000
    default: 5
    }
  }

  private static func system(of payload: PayloadIdentity) -> SystemIdentity? {
    if case .wreck(let actor, _) = payload { return actor.system }
    return nil
  }

  private static func precedes(_ lhs: PayloadIdentity, _ rhs: PayloadIdentity) -> Bool {
    guard case .wreck(let a, let first) = lhs, case .wreck(let b, let second) = rhs else {
      return false
    }
    return (first, a.system.galaxy, a.system.system, a.visit, a.entity)
      < (second, b.system.galaxy, b.system.system, b.visit, b.entity)
  }
}
