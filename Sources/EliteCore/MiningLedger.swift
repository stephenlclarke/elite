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
  private var ringTerminal: [SystemIdentity: UInt64]? = [:]
  private var generation: Int? = 1
  public var retainsLegacyFields: Bool { generation == nil }
  public var usesRingSaveVersion: Bool {
    generation != nil || ringTerminal != nil || partial.keys.contains { $0.field >= 4 }
      || pending.keys.contains { if case .ore(let rock, _) = $0 { rock.field >= 4 } else { false } }
  }
  private var partial: [RockIdentity: Double] = [:]
  private var pending: [PayloadIdentity: TypedCargoPayload] = [:]
  private var offers: [SpawnIdentity: PayloadIdentity] = [:]
  private var bindings: [PayloadIdentity: ActorIdentity] = [:]
  private var lastIncident: UInt64?
  private var sequence: UInt64 = 0

  public init(seed: UInt64 = 0) { self.seed = seed }
  private enum CodingKeys: String, CodingKey {
    case seed, terminal, ringTerminal, generation, partial, pending, offers, bindings, lastIncident,
      sequence
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    seed = try values.decode(UInt64.self, forKey: .seed)
    terminal = try Self.decodeBounded(
      SystemIdentity.self, UInt64.self,
      from: values, key: .terminal, maximum: 8 * 257, keyAllowed: Self.validSystem)
    generation = try values.decodeIfPresent(Int.self, forKey: .generation)
    if values.contains(.ringTerminal), try !values.decodeNil(forKey: .ringTerminal) {
      ringTerminal = try Self.decodeBounded(
        SystemIdentity.self, UInt64.self, from: values, key: .ringTerminal, maximum: 8 * 257,
        keyAllowed: Self.validSystem)
    } else {
      ringTerminal = nil
    }
    let mask = (UInt64(1) << 48) - 1
    guard generation == nil || generation == 1,
      terminal.values.allSatisfy({ $0 > 0 && $0 & ~mask == 0 }),
      ringTerminal?.values.allSatisfy({ $0 > 0 && $0 & ~mask == 0 }) ?? true
    else { throw SaveError.invalidCommander }
    partial = try Self.decodeBounded(
      RockIdentity.self, Double.self,
      from: values, key: .partial, maximum: Self.maximumPartial, keyAllowed: Self.validRock)
    pending = try Self.decodeBounded(
      PayloadIdentity.self, TypedCargoPayload.self,
      from: values, key: .pending, maximum: Self.maximumPending,
      keyAllowed: { identity in
        guard case .ore(let rock, let fragment) = identity else { return false }
        return Self.validRock(rock)
          && Int(fragment) < (AsteroidBeltDefinition.chunk(for: rock)?.units ?? 7)
      })
    offers = try Self.decodeBounded(
      SpawnIdentity.self, PayloadIdentity.self,
      from: values, key: .offers, maximum: Self.maximumPending)
    bindings = try Self.decodeBounded(
      PayloadIdentity.self, ActorIdentity.self,
      from: values, key: .bindings, maximum: Self.maximumPending)
    lastIncident = try values.decodeIfPresent(UInt64.self, forKey: .lastIncident)
    sequence = try values.decode(UInt64.self, forKey: .sequence)
    guard valid else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath, debugDescription: "Invalid mining ledger"))
    }
  }

  private static func decodeBounded<Key: Hashable & Decodable, Value: Decodable>(
    _ keyType: Key.Type, _ valueType: Value.Type,
    from values: KeyedDecodingContainer<CodingKeys>, key: CodingKeys, maximum: Int,
    keyAllowed: (Key) -> Bool = { _ in true }
  ) throws -> [Key: Value] {
    var records = try values.nestedUnkeyedContainer(forKey: key)
    guard (records.count ?? 0) <= maximum * 2 else { throw SaveError.invalidCommander }
    var result: [Key: Value] = [:]
    while !records.isAtEnd {
      guard result.count < maximum else {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: records.codingPath, debugDescription: "Mining collection exceeds bound"))
      }
      let identity = try records.decode(Key.self)
      guard keyAllowed(identity), result[identity] == nil else {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: records.codingPath, debugDescription: "Invalid or duplicate mining key"))
      }
      result[identity] = try records.decode(Value.self)
    }
    return result
  }

  public var valid: Bool {
    let mask = (UInt64(1) << 48) - 1
    guard generation == nil || generation == 1,
      (ringTerminal?.count ?? 0) <= 8 * 257,
      ringTerminal?.allSatisfy({ Self.validSystem($0.key) && $0.value > 0 && $0.value & ~mask == 0 }
      ) ?? true,
      terminal.count <= 8 * 257, partial.count <= Self.maximumPartial,
      pending.count <= Self.maximumPending, offers.count <= Self.maximumPending,
      bindings.count <= Self.maximumPending,
      terminal.allSatisfy({ Self.validSystem($0.key) && $0.value > 0 && $0.value & ~mask == 0 }),
      partial.allSatisfy({ identity, energy in
        bit(identity) != nil && (identity.field < 4 || ringTerminal != nil) && !isDepleted(identity)
          && energy.isFinite && energy > 0
          && (AsteroidBeltDefinition.chunk(for: identity).map { energy <= $0.energy } ?? true)
      }),
      pending.allSatisfy({ identity, item in
        guard identity == item.identity, case .ore(let rock, let fragment) = identity,
          bit(rock) != nil, isDepleted(rock),
          Int(fragment) < (AsteroidBeltDefinition.chunk(for: rock)?.units ?? 7),
          item.amount.quantity == 1,
          [.minerals, .alloys, .gold, .platinum].contains(item.amount.commodity)
        else { return false }
        let canonical = self.yield(
          for: MiningRock(
            identity: rock, position: .init(0, 0, 0), radius: 1, energy: 1))
        return canonical.contains { $0.identity == identity && $0.amount == item.amount }
          && Self.validMotion(item.position) && Self.validMotion(item.velocity)
      }),
      offers.allSatisfy({ spawn, payload in
        guard case .ore(let rock, _) = payload else { return false }
        return pending[payload] != nil && bindings[payload] == nil
          && spawn.system == rock.system && Self.validSystem(spawn.system)
          && spawn.producer == .mining && spawn.member == 0
          && spawn.visit > 0 && spawn.visit < UInt64.max
          && spawn.sequence > 0 && spawn.sequence < UInt64.max && spawn.sequence <= sequence
      }),
      Set(offers.values).count == offers.count,
      Set(bindings.values).count == bindings.count,
      bindings.allSatisfy({ payload, actor in
        guard case .ore(let rock, _) = payload else { return false }
        return pending[payload] != nil && actor.system == rock.system
          && Self.validSystem(actor.system) && actor.entity >= 2 && actor.entity < UInt64.max
          && actor.visit > 0 && actor.visit < UInt64.max
      })
    else { return false }
    guard sequence < UInt64.max,
      lastIncident.map({ $0 > 0 && $0 < UInt64.max }) ?? true
    else { return false }
    return
      (terminal.isEmpty && (ringTerminal?.isEmpty ?? true) && partial.isEmpty && pending.isEmpty)
      || lastIncident != nil
  }

  private static func validRock(_ rock: RockIdentity) -> Bool {
    validSystem(rock.system) && rock.field < 8 && rock.rock < 12
  }

  private static func validSystem(_ system: SystemIdentity) -> Bool {
    (0..<8).contains(system.galaxy) && (0...256).contains(system.system)
  }

  private static func validMotion(_ vector: Vector3) -> Bool {
    vector.x.isFinite && vector.y.isFinite && vector.z.isFinite && vector.length.isFinite
  }

  public var pendingPayloads: [TypedCargoPayload] {
    pending.values.sorted { key($0.identity) < key($1.identity) }
  }
  public func boundActor(for payload: PayloadIdentity) -> ActorIdentity? { bindings[payload] }

  public func isDepleted(_ identity: RockIdentity) -> Bool {
    guard let bit = bit(identity) else { return false }
    let mask =
      identity.field < 4
      ? terminal[identity.system, default: 0] : ringTerminal?[identity.system] ?? 0
    return mask & bit != 0
  }

  public func remainingEnergy(for rock: MiningRock) -> Double {
    isDepleted(rock.identity) ? 0 : partial[rock.identity, default: rock.energy]
  }

  /// Resource admission is checked before the emitter allocates an attack or spends power.
  func canAdmitMiningHit(rock: MiningRock, damage: Double) -> Bool {
    guard valid, damage.isFinite, damage > 0, rock.energy.isFinite, rock.energy > 0,
      Self.validMotion(rock.position), bit(rock.identity) != nil, !isDepleted(rock.identity)
    else { return false }
    if let chunk = AsteroidBeltDefinition.chunk(for: rock.identity),
      rock.energy != chunk.energy || rock.radius != chunk.radius
    {
      return false
    }
    let remaining = max(0, remainingEnergy(for: rock) - damage)
    return hitStorageFits(rock: rock, remaining: remaining, mining: true)
  }
  private func hitStorageFits(rock: MiningRock, remaining: Double, mining: Bool) -> Bool {
    let count = remaining == 0 && mining ? yield(for: rock).count : 0
    return pending.count + count <= Self.maximumPending
      && (remaining == 0 || partial[rock.identity] != nil || partial.count < Self.maximumPartial)
  }

  /// G1 must resolve the nearest physical rock and pass its matching incident.
  public mutating func hit(rock: MiningRock, incident: CombatIncident, damage: Double)
    -> MiningHitResult
  {
    guard incident.victimPart == nil,
      incident.outcome == .hit || incident.outcome == .destruction
    else { return .ignored }
    return physicalHit(
      rock: rock, eventID: incident.id, damage: damage,
      mining: incident.kind == .laser && incident.laser == .mining)
  }

  /// Only an actual sealed plasma contact may enter without an ordinary combat incident.
  mutating func hit(
    rock: MiningRock, proof: MissionNativeImpactProof, eventID: UInt64,
    context: EncounterContext
  ) -> MiningHitResult {
    guard proof.system == context.system, proof.visit == context.visit,
      proof.sceneRevision == context.revision, context.physicalTime.isFinite,
      context.physicalTime >= 0, proof.kind == .plasma, proof.victimPart == nil,
      let projectile = proof.projectileBody.physical?.identity,
      context.actors.filter({
        $0.identity == projectile && $0.energy == proof.projectileBody.energy && $0.energy > 0
      }).count == 1,
      case .body(let id) = proof.hit.target, let body = proof.targetBody,
      body.id == id, body.physical?.rock == rock.identity,
      rock.identity.system == context.system,
      let identity = body.physical?.identity, identity == proof.currentVictim,
      context.actors.filter({
        $0.identity == identity && $0.rock == rock.identity && $0.hull == body.hull
          && $0.energy == body.energy
      }).count == 1
    else { return .ignored }
    return physicalHit(rock: rock, eventID: eventID, damage: proof.damage, mining: false)
  }

  private mutating func physicalHit(
    rock: MiningRock, eventID: UInt64, damage: Double, mining: Bool
  ) -> MiningHitResult {
    guard damage.isFinite, damage > 0, rock.energy.isFinite,
      rock.energy > 0, Self.validMotion(rock.position),
      bit(rock.identity) != nil, !isDepleted(rock.identity),
      eventID > 0, eventID < UInt64.max,
      lastIncident.map({ eventID > $0 }) ?? true
    else { return .ignored }
    if let chunk = AsteroidBeltDefinition.chunk(for: rock.identity),
      rock.energy != chunk.energy || rock.radius != chunk.radius
    {
      return .ignored
    }
    let remaining = max(0, remainingEnergy(for: rock) - damage)
    let payloads = remaining == 0 && mining ? yield(for: rock) : []
    guard hitStorageFits(rock: rock, remaining: remaining, mining: mining)
    else { return .capacityRefused }
    if rock.identity.field >= 4, ringTerminal == nil { ringTerminal = [:] }
    lastIncident = eventID
    if remaining > 0 {
      partial[rock.identity] = remaining
      return .damaged(remaining)
    }
    // Commit the tombstone before offering any physical spawn.
    if rock.identity.field < 4 {
      terminal[rock.identity.system, default: 0] |= bit(rock.identity)!
    } else {
      var mask = ringTerminal ?? [:]
      mask[rock.identity.system, default: 0] |= bit(rock.identity)!
      ringTerminal = mask
    }
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
        !context.protection.protectedPayloads.contains(payload.identity),
        context.visit > 0, context.visit < UInt64.max, sequence < UInt64.max - 1
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
        actor.system == receipt.request.system, actor.visit == receipt.request.visit,
        actor.entity >= 2, actor.entity < UInt64.max, actor.visit > 0, actor.visit < UInt64.max,
        !bindings.values.contains(actor)
      {
        bindings[payload] = actor
      }
    }
  }

  /// Persist canonical world motion only for the currently acknowledged ore actor.
  /// The caller supplies its latest live snapshot before releasing the binding.
  @discardableResult
  public mutating func updateOreMotion(
    payload: PayloadIdentity, actor: ActorIdentity, position: Vector3, velocity: Vector3
  ) -> Bool {
    guard case .ore(let rock, _) = payload, rock.system == actor.system,
      let item = pending[payload], item.identity == payload, bindings[payload] == actor,
      position.finite, velocity.finite, position.length.isFinite, velocity.length.isFinite,
      item.position != position || item.velocity != velocity
    else { return false }
    pending[payload] = TypedCargoPayload(
      identity: item.identity, amount: item.amount, position: position, velocity: velocity)
    return true
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
    guard Self.validRock(rock) else { return nil }
    return UInt64(1) << (UInt64(rock.field % 4) * 12 + UInt64(rock.rock))
  }

  private func key(_ identity: PayloadIdentity) -> String {
    if case .ore(let rock, let fragment) = identity {
      return "\(rock.system.galaxy):\(rock.system.system):\(rock.field):\(rock.rock):\(fragment)"
    }
    return ""
  }

  private func yield(for rock: MiningRock) -> [TypedCargoPayload] {
    if let chunk = AsteroidBeltDefinition.chunk(for: rock.identity) {
      return (0..<chunk.units).map { index in
        TypedCargoPayload(
          identity: .ore(rock.identity, fragment: UInt16(index)),
          amount: .init(commodity: chunk.content.commodity, quantity: 1),
          position: rock.position + Vector3(Double(index % 5) * 12, Double(index / 5) * 12, 10),
          velocity: .init(Double(index % 5), 2, 3))
      }
    }
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
