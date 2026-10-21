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
  private var generation: Int? = 2
  private var legacyClusters: Bool? = false
  private var presenceOverrides: [SystemIdentity: Bool]? = [:]
  public var retainsLegacyFields: Bool { legacyClusters ?? (generation == nil) }
  public var usesEconomyWeightedPresence: Bool { generation == 2 }

  /// Includes legacy terminal history conservatively, not just currently live rocks.
  public var requiredPresencePinSystems: Set<SystemIdentity> {
    var systems = Set(terminal.keys).union(ringTerminal?.keys.map { $0 } ?? [])
    systems.formUnion(partial.keys.map(\.system))
    for payload in Array(pending.keys) + Array(offers.values) + Array(bindings.keys) {
      if case .ore(let rock, _) = payload { systems.insert(rock.system) }
    }
    return systems
  }

  private var ringHistorySystems: Set<SystemIdentity> {
    var systems = Set(ringTerminal?.keys.map { $0 } ?? [])
    systems.formUnion(partial.keys.filter { $0.field >= 4 }.map(\.system))
    for payload in Array(pending.keys) + Array(offers.values) + Array(bindings.keys) {
      if case .ore(let rock, _) = payload, rock.field >= 4 { systems.insert(rock.system) }
    }
    return systems
  }

  public func ringPresence(system: StarSystem, galaxy: Int) -> Bool {
    let identity = SystemIdentity(galaxy: galaxy, system: system.id)
    if let pinned = presenceOverrides?[identity] { return pinned }
    return AsteroidBeltDefinition.isPresent(
      system: system, galaxy: galaxy,
      policy: usesEconomyWeightedPresence ? .economyWeighted : .legacyUniform)
  }

  /// The load boundary supplies actual current/history systems before rebuilding fields.
  /// Once migrated, original pins remain immutable across subsequent visits and loads.
  public mutating func migratePresence(
    current: AsteroidPresencePin, historical: [AsteroidPresencePin]
  ) throws {
    guard valid else { throw SaveError.invalidCommander }
    if usesEconomyWeightedPresence { return }
    guard Self.validSystem(current.system), historical.count <= 8 * 257 - 1 else {
      throw SaveError.invalidCommander
    }
    var pins: [SystemIdentity: Bool] = [current.system: current.present]
    for pin in historical {
      guard Self.validSystem(pin.system), pins[pin.system] == nil else {
        throw SaveError.invalidCommander
      }
      pins[pin.system] = pin.present
    }
    guard Set(pins.keys) == requiredPresencePinSystems.union([current.system]),
      ringHistorySystems.allSatisfy({ pins[$0] == true })
    else { throw SaveError.invalidCommander }
    let retainClusters = retainsLegacyFields
    // All fallible work precedes this transaction's first mutation.
    presenceOverrides = pins
    legacyClusters = retainClusters
    generation = 2
  }
  public var usesRingSaveVersion: Bool {
    generation != nil || ringTerminal != nil || partial.keys.contains { $0.field >= 4 }
      || pending.keys.contains { if case .ore(let rock, _) = $0 { rock.field >= 4 } else { false } }
  }
  var breakups: [RockIdentity: AsteroidBreakup] = [:]
  private var partial: [RockIdentity: Double] = [:]
  private var pending: [PayloadIdentity: TypedCargoPayload] = [:]
  private var offers: [SpawnIdentity: PayloadIdentity] = [:]
  private var bindings: [PayloadIdentity: ActorIdentity] = [:]
  private var lastIncident: UInt64?
  private var sequence: UInt64 = 0

  public init(seed: UInt64 = 0) { self.seed = seed }
  /// Missing old commander state has the historical unworked cluster policy at load.
  static func legacyUnworked() -> Self {
    var ledger = Self()
    ledger.generation = nil
    ledger.ringTerminal = nil
    ledger.legacyClusters = nil
    ledger.presenceOverrides = nil
    return ledger
  }
  private enum CodingKeys: String, CodingKey {
    case seed, terminal, ringTerminal, generation, legacyClusters, presenceOverrides, partial,
      pending, offers, bindings, lastIncident,
      sequence, breakups
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    seed = try values.decode(UInt64.self, forKey: .seed)
    terminal = try Self.decodeBounded(
      SystemIdentity.self, UInt64.self,
      from: values, key: .terminal, maximum: 8 * 257, keyAllowed: Self.validSystem)
    generation =
      values.contains(.generation) ? try values.decode(Int.self, forKey: .generation) : nil
    legacyClusters =
      values.contains(.legacyClusters) ? try values.decode(Bool.self, forKey: .legacyClusters) : nil
    if values.contains(.presenceOverrides) {
      presenceOverrides = try Self.decodeBounded(
        SystemIdentity.self, Bool.self, from: values, key: .presenceOverrides,
        maximum: 8 * 257, keyAllowed: Self.validSystem)
    } else {
      presenceOverrides = nil
    }
    if values.contains(.ringTerminal), try !values.decodeNil(forKey: .ringTerminal) {
      ringTerminal = try Self.decodeBounded(
        SystemIdentity.self, UInt64.self, from: values, key: .ringTerminal, maximum: 8 * 257,
        keyAllowed: Self.validSystem)
    } else {
      ringTerminal = nil
    }
    let mask = (UInt64(1) << 48) - 1
    guard presenceStateValid,
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
    breakups = try Self.decodeBounded(
      RockIdentity.self, AsteroidBreakup.self, from: values, key: .breakups,
      maximum: Self.maximumPartial, keyAllowed: Self.validRock)
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
    guard presenceStateValid,
      (ringTerminal?.count ?? 0) <= 8 * 257,
      ringTerminal?.allSatisfy({ Self.validSystem($0.key) && $0.value > 0 && $0.value & ~mask == 0 }
      ) ?? true,
      terminal.count <= 8 * 257, partial.count <= Self.maximumPartial,
      breakups.count <= Self.maximumPartial,
      Set(breakups.values.compactMap(\.binding)).count
        == breakups.values.compactMap(\.binding).count,
      Set(breakups.values.compactMap(\.binding)).isDisjoint(with: Set(bindings.values)),
      breakups.allSatisfy({ identity, breakup in
        guard breakup.valid && breakup.rock == identity && isDepleted(identity) else {
          return false
        }
        let retained = pending.values.filter {
          if case .ore(let root, let fragment) = $0.identity {
            return root == identity && Int(fragment) < breakup.issuedUnits
          }
          return false
        }
        let retainedFragments = Set(
          retained.compactMap { item -> UInt16? in
            if case .ore(_, let fragment) = item.identity { return fragment }
            return nil
          })
        let issuedFragments = Set((0..<breakup.issuedUnits).map { UInt16($0) })
        let boundFragments = Set(
          retainedFragments.filter {
            bindings[.ore(identity, fragment: $0)] != nil
          })
        return retained.count == breakup.issuedUnits - breakup.collectedUnits
          && Set(breakup.payloadTimes.keys) == retainedFragments
          && breakup.materialized.isSuperset(of: issuedFragments.subtracting(retainedFragments))
          && breakup.materialized.isSuperset(of: boundFragments)
          && breakup.rubble.allSatisfy { pending[.ore(identity, fragment: $0)] != nil }
      }),
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
          Int(fragment)
            < (breakups[rock]?.issuedUnits
              ?? AsteroidBeltDefinition.chunk(for: rock)?.units ?? 7),
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

  private var presenceStateValid: Bool {
    if generation == 2 {
      guard legacyClusters != nil, let presenceOverrides,
        presenceOverrides.count <= 8 * 257,
        presenceOverrides.keys.allSatisfy(Self.validSystem)
      else { return false }
      return ringHistorySystems.allSatisfy { presenceOverrides[$0] != false }
    }
    return (generation == nil || generation == 1)
      && legacyClusters == nil && presenceOverrides == nil
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
  /// Read-only cross-backend custody join; this does not expose mutable bindings.
  func ownsPhysicalActor(_ actor: ActorIdentity) -> Bool { bindings.values.contains(actor) }

  public func isDepleted(_ identity: RockIdentity) -> Bool {
    guard let bit = bit(identity) else { return false }
    let mask =
      identity.field < 4
      ? terminal[identity.system, default: 0] : ringTerminal?[identity.system] ?? 0
    return mask & bit != 0
  }

  public func remainingEnergy(for rock: MiningRock) -> Double {
    breakups[rock.identity] != nil
      ? rock.energy
      : isDepleted(rock.identity) ? 0 : partial[rock.identity, default: rock.energy]
  }

  /// Resource admission is checked before the emitter allocates an attack or spends power.
  func canAdmitMiningHit(rock: MiningRock, damage: Double) -> Bool {
    if let breakup = breakups[rock.identity] {
      return valid && damage.isFinite && damage > 0
        && (damage < breakup.workEnergy
          || pending.count + breakup.maximumCollectibleUnits - breakup.issuedUnits
            <= Self.maximumPending)
    }
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

  mutating func hit(
    rock: MiningRock, incident: CombatIncident, damage: Double, motion: AsteroidMotion
  ) -> MiningHitResult {
    guard incident.victimPart == nil,
      incident.outcome == .hit || incident.outcome == .destruction
    else { return .ignored }
    return physicalHit(
      rock: rock, eventID: incident.id, damage: damage,
      mining: incident.kind == .laser && incident.laser == .mining, motion: motion)
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
      let actor = context.actors.first(where: {
        $0.identity == identity && $0.rock == rock.identity && $0.hull == body.hull
          && $0.energy == body.energy
      }), context.actors.filter({ $0.identity == identity }).count == 1
    else { return .ignored }
    return physicalHit(
      rock: rock, eventID: eventID, damage: proof.damage, mining: false,
      motion: .init(
        position: actor.position, velocity: actor.velocity,
        physicalTime: context.physicalTime))
  }

  private mutating func physicalHit(
    rock: MiningRock, eventID: UInt64, damage: Double, mining: Bool,
    motion: AsteroidMotion? = nil
  ) -> MiningHitResult {
    if breakups[rock.identity] != nil {
      return workBreakup(
        rock: rock, eventID: eventID, damage: damage, mining: mining, motion: motion)
    }
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
    if remaining == 0, !mining, AsteroidBeltDefinition.chunk(for: rock.identity) != nil {
      guard breakups.count < Self.maximumPartial, let motion,
        let breakup = AsteroidBreakup(rock: rock, motion: motion)
      else { return .capacityRefused }
      breakups[rock.identity] = breakup
    }
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
    if breakups[rock.identity] != nil { return .damaged(rock.energy) }
    return mining ? .extracted(payloads) : .destroyed
  }

  public mutating func pendingSpawnRequests(context: EncounterContext, fields: [MiningField])
    -> [SpawnRequest]
  {
    let identities = Set(fields.flatMap(\.rocks).map(\.identity))
    var requests: [SpawnRequest] = []
    let reserved = Set(offers.values)
    var remaining = max(0, context.budget.ordinaryRemaining - offers.count)
    var offered: [PopulationClass: Int] = [:]
    for payload in offers.values {
      offered[isRubble(payload) ? .asteroid : .cargo, default: 0] += 1
    }
    for payload in pendingPayloads {
      let population: PopulationClass = isRubble(payload.identity) ? .asteroid : .cargo
      guard remaining > 0,
        context.budget.active[population, default: 0] + offered[population, default: 0]
          < population.maximum,
        case .ore(let rock, _) = payload.identity,
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
      var position = payload.position
      if case .ore(let root, let fragment) = payload.identity,
        let time = breakups[root]?.payloadTimes[fragment], context.physicalTime >= time
      {
        position = position + payload.velocity * (context.physicalTime - time)
        guard Self.validMotion(position) else {
          offers.removeValue(forKey: identity)
          continue
        }
        pending[payload.identity] = .init(
          identity: payload.identity, amount: payload.amount,
          position: position, velocity: payload.velocity)
        breakups[root]?.payloadTimes[fragment] = context.physicalTime
      }
      requests.append(
        SpawnRequest(
          identity: identity, population: population,
          hull: isRubble(payload.identity) ? .asteroid : .cargo,
          position: position, orientation: Basis3(), velocity: payload.velocity,
          npc: nil, rock: nil, payload: payload.identity, priority: .ordinary))
      remaining -= 1
      offered[population, default: 0] += 1
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
        !bindings.values.contains(actor), !breakups.values.contains(where: { $0.binding == actor })
      {
        bindings[payload] = actor
        if case .ore(let root, let fragment) = payload, breakups[root] != nil {
          breakups[root]?.materialized.insert(fragment)
        }
      }
    }
  }

  /// Persist canonical world motion only for the currently acknowledged ore actor.
  /// The caller supplies its latest live snapshot before releasing the binding.
  @discardableResult
  public mutating func updateOreMotion(
    payload: PayloadIdentity, actor: ActorIdentity, position: Vector3, velocity: Vector3,
    physicalTime: Double? = nil
  ) -> Bool {
    guard case .ore(let rock, let fragment) = payload, rock.system == actor.system,
      let item = pending[payload], item.identity == payload, bindings[payload] == actor,
      position.finite, velocity.finite, position.length.isFinite, velocity.length.isFinite,
      item.position != position || item.velocity != velocity
        || (breakups[rock] != nil && physicalTime != nil
          && physicalTime != breakups[rock]?.payloadTimes[fragment])
    else { return false }
    if case .ore(let root, let fragment) = payload, breakups[root] != nil, let physicalTime {
      guard physicalTime.isFinite, physicalTime >= (breakups[root]?.payloadTimes[fragment] ?? 0)
      else { return false }
      breakups[root]?.payloadTimes[fragment] = physicalTime
    }
    pending[payload] = TypedCargoPayload(
      identity: item.identity, amount: item.amount, position: position, velocity: velocity)
    return true
  }

  public mutating func collect(
    payload: PayloadIdentity, into cargo: inout [Int], freeTonnes: Int,
    hasScoops: Bool, approachAllowed: Bool, protection: MissionProtection
  ) -> CargoCollectionReceipt {
    guard let item = pending[payload], !isRubble(payload) else { return .refused(.unavailable) }
    let receipt = item.collect(
      into: &cargo, freeTonnes: freeTonnes, hasScoops: hasScoops,
      approachAllowed: approachAllowed, protection: protection)
    if case .collected = receipt {
      if case .ore(let rock, _) = payload, var breakup = breakups[rock] {
        breakup.collectedUnits += item.amount.quantity
        if case .ore(_, let fragment) = payload {
          breakup.payloadTimes.removeValue(forKey: fragment)
          breakup.materialized.insert(fragment)
        }
        breakups[rock] = breakup
      }
      pending.removeValue(forKey: payload)
      bindings.removeValue(forKey: payload)
      offers = offers.filter { $0.value != payload }
    }
    return receipt
  }

  /// Culling releases a physical binding, never the collectible or depletion record.
  public mutating func cull(actor: ActorIdentity) {
    bindings = bindings.filter { $0.value != actor }
    for rock in Array(breakups.keys) where breakups[rock]?.binding == actor {
      breakups[rock]?.binding = nil
    }
  }

  /// Physical destruction settles a pod without credit; culling merely hides it.
  @discardableResult
  public mutating func destroy(
    payload: PayloadIdentity, protection: MissionProtection? = nil
  ) -> Bool {
    guard case .ore(let rock, let fragment) = payload,
      protection?.protectedPayloads.contains(payload) != true, pending[payload] != nil
    else { return false }
    if var breakup = breakups[rock] {
      guard !breakup.rubble.contains(fragment) else { return false }
      breakup.rubble.insert(fragment)
      breakups[rock] = breakup
    } else {
      pending.removeValue(forKey: payload)
    }
    bindings.removeValue(forKey: payload)
    offers = offers.filter { $0.value != payload }
    return true
  }

  /// Use after rebuilding a scene from a save; old physical actors no longer exist.
  /// Pending cargo keeps its identity and amount and can be admitted again once.
  public mutating func resetPhysicalBindings(system: SystemIdentity) {
    for rock in Array(breakups.keys) where rock.system == system { breakups[rock]?.binding = nil }
    offers = offers.filter { $0.key.system != system }
    bindings = bindings.filter { $0.value.system != system }
  }

  /// Ordinary mined ore expires on departure. Breakup descendants retain mass custody;
  /// depleted intact rocks never regenerate.
  public mutating func depart(system: SystemIdentity) {
    pending = pending.filter {
      if case .ore(let rock, _) = $0.key {
        return rock.system != system || breakups[rock] != nil
      }
      return true
    }
    for rock in Array(breakups.keys) where rock.system == system { breakups[rock]?.binding = nil }
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
      let radius = Mesh.hull(.cargo).vertices.map(\.length).max() ?? 0
      let spacing = 2 * radius + 16
      let columns = min(5, chunk.units)
      let rows = chunk.units / columns
      // Expand symmetrically about the original birth centroid, preserving every velocity.
      let center = Vector3(Double(columns - 1) * 6, Double(rows - 1) * 6, 10)
      return (0..<chunk.units).map { (index: Int) -> TypedCargoPayload in
        let amount = CommodityAmount(commodity: chunk.content.commodity, quantity: 1)
        let offset =
          center
          + Vector3(
            (Double(index % columns) - Double(columns - 1) / 2) * spacing,
            (Double(index / columns) - Double(rows - 1) / 2) * spacing, 0)
        let position: Vector3 = rock.position + offset
        let velocity = Vector3(Double(index % 5), 2, 3)
        return TypedCargoPayload(
          identity: .ore(rock.identity, fragment: UInt16(index)),
          amount: amount, position: position, velocity: velocity)
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

extension MiningLedger {
  func isRubble(_ payload: PayloadIdentity) -> Bool {
    guard case .ore(let rock, let fragment) = payload else { return false }
    return breakups[rock]?.rubble.contains(fragment) == true
  }

  private mutating func workBreakup(
    rock: MiningRock, eventID: UInt64, damage: Double, mining: Bool, motion: AsteroidMotion?
  ) -> MiningHitResult {
    guard var breakup = breakups[rock.identity],
      let chunk = AsteroidBeltDefinition.chunk(for: rock.identity),
      rock.energy == chunk.energy, rock.radius == chunk.radius,
      damage.isFinite, damage > 0,
      eventID > 0, eventID < UInt64.max,
      lastIncident.map({ eventID > $0 }) ?? true
    else { return .ignored }
    if let motion {
      guard motion.valid, motion.physicalTime >= breakup.motion.physicalTime else {
        return .ignored
      }
      breakup.motion = motion
    }
    let available = breakup.maximumCollectibleUnits - breakup.issuedUnits
    let workRemaining = mining ? max(0, breakup.workEnergy - damage) : breakup.workEnergy
    guard !mining || workRemaining > 0 || pending.count + available <= Self.maximumPending else {
      return .capacityRefused
    }
    if mining { breakup.workEnergy = workRemaining }
    if mining, workRemaining == 0, available > 0 {
      let unit = AsteroidBreakup.kilogramsPerUnit(breakup.commodity)
      for fragment in breakup.issuedUnits..<breakup.maximumCollectibleUnits {
        breakup.payloadTimes[UInt16(fragment)] = breakup.motion.physicalTime
        let identity = PayloadIdentity.ore(rock.identity, fragment: UInt16(fragment))
        pending[identity] = .init(
          identity: identity, amount: .init(commodity: breakup.commodity, quantity: 1),
          position: breakup.motion.position
            + Vector3(0, 0, rock.radius + 100 + Double(fragment) * 80),
          velocity: breakup.motion.velocity)
      }
      breakup.aggregateMassKg -= Double(available) * unit
      breakup.issuedUnits += available
    }
    breakups[rock.identity] = breakup
    lastIncident = eventID
    return .damaged(rock.energy)
  }
}

extension MiningLedger {
  mutating func bindBreakup(rock: RockIdentity, actor: ActorIdentity) {
    guard actor.system == rock.system, actor.entity >= 2, actor.entity < UInt64.max,
      actor.visit > 0, actor.visit < UInt64.max,
      breakups[rock]?.binding == nil || breakups[rock]?.binding == actor,
      !breakups.contains(where: { $0.key != rock && $0.value.binding == actor }),
      !bindings.values.contains(actor)
    else { return }
    breakups[rock]?.binding = actor
  }

  mutating func bindRubble(payload: PayloadIdentity, actor: ActorIdentity) {
    guard case .ore(let rock, _) = payload, isRubble(payload), pending[payload] != nil,
      actor.system == rock.system, actor.entity >= 2, actor.entity < UInt64.max,
      actor.visit > 0, actor.visit < UInt64.max, !bindings.values.contains(actor),
      !breakups.values.contains(where: { $0.binding == actor })
    else { return }
    bindings[payload] = actor
  }
}

extension MiningLedger {
  /// Read only: prior work, hidden offers and old bindings cannot become a fresh consent source.
  func measuredSourceIsPristine(_ rock: MiningRock) -> Bool {
    guard rock.identity == NativeMeasuredExtraction.root, valid,
      let chunk = AsteroidBeltDefinition.chunk(for: rock.identity),
      chunk.content.commodity == .minerals, chunk.units == 20,
      rock.energy == chunk.energy, rock.radius == chunk.radius,
      !isDepleted(rock.identity), partial[rock.identity] == nil, breakups[rock.identity] == nil
    else { return false }
    for payload in Array(pending.keys) + Array(offers.values) + Array(bindings.keys) {
      if case .ore(let root, _) = payload, root == rock.identity { return false }
    }
    return true
  }

  func appliedMeasuredExtraction(rock: RockIdentity, incident: UInt64, emitted: [TypedCargoPayload])
    -> Bool
  {
    guard rock == NativeMeasuredExtraction.root, lastIncident == incident, isDepleted(rock),
      breakups[rock] == nil, emitted.count == 20
    else { return false }
    for (index, item) in emitted.enumerated() {
      guard item.identity == .ore(rock, fragment: UInt16(index)),
        item.amount == CommodityAmount(commodity: .minerals, quantity: 1),
        pending[item.identity] == item
      else { return false }
    }
    return true
  }

  /// Only the real native intake producer can construct this permit. No commodity credit,
  /// caller free-tonnes allowance or mutable binding escapes this bounded adapter.
  mutating func takeMeasuredOriginal(_ permit: MeasuredProtectedIntakePermit) -> TypedCargoPayload?
  {
    let receipt = permit.receipt
    guard case .ore(let root, let fragment) = receipt.payload.identity,
      root == NativeMeasuredExtraction.root, fragment < 12, !isRubble(receipt.payload.identity),
      let actor = receipt.body.first?.physical?.identity,
      bindings[receipt.payload.identity] == actor,
      let item = pending[receipt.payload.identity], item.identity == receipt.payload.identity,
      item.amount == .init(commodity: .minerals, quantity: 1)
    else { return nil }
    pending.removeValue(forKey: item.identity)
    bindings.removeValue(forKey: item.identity)
    offers = offers.filter { $0.value != item.identity }
    return item
  }
}
