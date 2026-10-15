import Foundation

public enum MiningHitResult: Equatable, Codable, Sendable {
  case ignored
  case damaged(Double)
  case extracted([TypedCargoPayload])
  case destroyed, capacityRefused
}

/// Compact irreversible depletion survives visits; live cargo bindings do not.
public struct MiningLedger: Equatable, Codable, Sendable {
  public static let maximumPending = 256
  public static let maximumPartial = 256
  private let seed: UInt64
  private var terminal: [SystemIdentity: UInt64] = [:]
  private var partial: [RockIdentity: Double] = [:]
  private var pending: [PayloadIdentity: TypedCargoPayload] = [:]
  private var offers: [SpawnIdentity: PayloadIdentity] = [:]
  private var bindings: [PayloadIdentity: ActorIdentity] = [:]
  private var lastIncident: UInt64?
  private var sequence: UInt64 = 0

  public init(seed: UInt64 = 0) { self.seed = seed }
  public var pendingPayloads: [TypedCargoPayload] {
    pending.values.sorted { key($0.identity) < key($1.identity) }
  }

  public func isDepleted(_ identity: RockIdentity) -> Bool {
    guard let bit = bit(identity) else { return false }
    return terminal[identity.system, default: 0] & bit != 0
  }

  public func remainingEnergy(for rock: MiningRock) -> Double {
    isDepleted(rock.identity) ? 0 : partial[rock.identity, default: rock.energy]
  }

  /// G1 must resolve the nearest physical rock and pass its matching incident.
  public mutating func hit(rock: MiningRock, incident: CombatIncident, damage: Double)
    -> MiningHitResult
  {
    guard incident.victimPart == nil, damage.isFinite, damage > 0, rock.energy.isFinite,
      rock.energy > 0,
      bit(rock.identity) != nil, !isDepleted(rock.identity),
      incident.outcome == .hit || incident.outcome == .destruction,
      lastIncident.map({ incident.id > $0 }) ?? true
    else { return .ignored }
    let remaining = max(0, remainingEnergy(for: rock) - damage)
    let mining = incident.kind == .laser && incident.laser == .mining
    let payloads = remaining == 0 && mining ? yield(for: rock) : []
    guard pending.count + payloads.count <= Self.maximumPending,
      remaining == 0 || partial[rock.identity] != nil || partial.count < Self.maximumPartial
    else { return .capacityRefused }
    lastIncident = incident.id
    if remaining > 0 {
      partial[rock.identity] = remaining
      return .damaged(remaining)
    }
    // Commit the tombstone before offering any physical spawn.
    terminal[rock.identity.system, default: 0] |= bit(rock.identity)!
    partial.removeValue(forKey: rock.identity)
    for payload in payloads { pending[payload.identity] = payload }
    return mining ? .extracted(payloads) : .destroyed
  }

  public mutating func pendingSpawnRequests(context: EncounterContext, fields: [MiningField])
    -> [SpawnRequest]
  {
    let identities = Set(fields.flatMap(\.rocks).map(\.identity))
    var requests: [SpawnRequest] = []
    let reserved = Set(offers.values)
    let capacity = max(
      0,
      min(
        context.budget.ordinaryRemaining,
        PopulationClass.cargo.maximum - context.budget.active[.cargo, default: 0]) - offers.count)
    for payload in pendingPayloads {
      guard requests.count < capacity, case .ore(let rock, _) = payload.identity,
        rock.system == context.system, identities.contains(rock), bindings[payload.identity] == nil,
        !reserved.contains(payload.identity),
        !context.protection.protectedPayloads.contains(payload.identity)
      else { continue }
      sequence &+= 1
      let identity = SpawnIdentity(
        system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .mining)
      offers[identity] = payload.identity
      requests.append(
        SpawnRequest(
          identity: identity, population: .cargo, hull: .cargo,
          position: payload.position, orientation: Basis3(), velocity: payload.velocity,
          npc: nil, rock: nil, payload: payload.identity, priority: .ordinary))
    }
    return requests
  }

  public mutating func acknowledge(receipts: [SpawnReceipt]) {
    for receipt in receipts {
      guard let payload = offers.removeValue(forKey: receipt.request), pending[payload] != nil
      else {
        continue
      }
      if let actor = receipt.actor, receipt.refusal == nil,
        actor.system == receipt.request.system, actor.visit == receipt.request.visit
      {
        bindings[payload] = actor
      }
    }
  }

  public mutating func collect(
    payload: PayloadIdentity, into cargo: inout [Int], freeTonnes: Int,
    hasScoops: Bool, approachAllowed: Bool, protection: MissionProtection
  ) -> CargoCollectionReceipt {
    guard let item = pending[payload] else { return .refused(.unavailable) }
    let receipt = item.collect(
      into: &cargo, freeTonnes: freeTonnes, hasScoops: hasScoops,
      approachAllowed: approachAllowed, protection: protection)
    if case .collected = receipt {
      pending.removeValue(forKey: payload)
      bindings.removeValue(forKey: payload)
      offers = offers.filter { $0.value != payload }
    }
    return receipt
  }

  /// Culling releases a physical binding, never the collectible or depletion record.
  public mutating func cull(actor: ActorIdentity) {
    bindings = bindings.filter { $0.value != actor }
  }

  /// Physical destruction settles a pod without credit; culling merely hides it.
  @discardableResult
  public mutating func destroy(
    payload: PayloadIdentity, protection: MissionProtection? = nil
  ) -> Bool {
    guard case .ore = payload, protection?.protectedPayloads.contains(payload) != true,
      pending.removeValue(forKey: payload) != nil
    else { return false }
    bindings.removeValue(forKey: payload)
    offers = offers.filter { $0.value != payload }
    return true
  }

  /// Use after rebuilding a scene from a save; old physical actors no longer exist.
  /// Pending cargo keeps its identity and amount and can be admitted again once.
  public mutating func resetPhysicalBindings(system: SystemIdentity) {
    offers = offers.filter { $0.key.system != system }
    bindings = bindings.filter { $0.value.system != system }
  }

  /// Explicitly expire abandoned ore on departure; depleted rocks never regenerate.
  public mutating func depart(system: SystemIdentity) {
    pending = pending.filter {
      if case .ore(let rock, _) = $0.key { return rock.system != system }
      return true
    }
    offers = offers.filter { $0.key.system != system }
    bindings = bindings.filter { $0.value.system != system }
  }

  private func bit(_ rock: RockIdentity) -> UInt64? {
    guard (0..<8).contains(rock.system.galaxy), (0...256).contains(rock.system.system),
      rock.field < 4, rock.rock < 12
    else { return nil }
    return UInt64(1) << (UInt64(rock.field) * 12 + UInt64(rock.rock))
  }

  private func key(_ identity: PayloadIdentity) -> String {
    if case .ore(let rock, let fragment) = identity {
      return "\(rock.system.galaxy):\(rock.system.system):\(rock.field):\(rock.rock):\(fragment)"
    }
    return ""
  }

  private func yield(for rock: MiningRock) -> [TypedCargoPayload] {
    var state =
      seed ^ UInt64(truncatingIfNeeded: rock.identity.system.galaxy) &* 0x9E37_79B9_7F4A_7C15
    state ^= UInt64(truncatingIfNeeded: rock.identity.system.system) &* 0xBF58_476D_1CE4_E5B9
    state ^= UInt64(rock.identity.field) << 32 | UInt64(rock.identity.rock)
    func draw() -> UInt64 {
      state &+= 0x9E37_79B9_7F4A_7C15
      var value = state
      value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
      value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
      return value ^ (value >> 31)
    }
    var amounts = Array(
      repeating: CommodityAmount(commodity: .minerals, quantity: 1),
      count: Int(draw() % 5) + 1)
    if draw() % 100 < 20 { amounts.append(.init(commodity: .alloys, quantity: 1)) }
    if draw() % 100 < 2 {
      amounts.append(.init(commodity: draw() % 2 == 0 ? .gold : .platinum, quantity: 1))
    }
    return amounts.enumerated().map { index, amount in
      let offset = Vector3(Double(index + 1) * 12, Double(index % 2) * 16, 10)
      return TypedCargoPayload(
        identity: .ore(rock.identity, fragment: UInt16(index)), amount: amount,
        position: rock.position + offset, velocity: Vector3(Double(index + 1), 2, 3))
    }
  }
}
