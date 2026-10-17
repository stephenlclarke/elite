import Foundation

/// Actual mutable craft state in system coordinates. Presentation projection and
/// any off-scene simulation remain the caller's responsibility.
public struct NPCPersistenceSnapshot: Equatable, Codable, Sendable {
  public var actor: ActorIdentity
  public var population: PopulationClass
  public var hull: Hull
  public var position: Vector3
  public var orientation: Basis3
  public var velocity: Vector3
  public var angularVelocity: Vector3
  public var rotation: Double
  public var rotationRate: Double
  public var energy: Double
  public var missiles: Int
  public var ecmEnabled: Bool
  public var hostile: Bool
  public var laserCooldown: Double
  public var catalogueShipID: String?
  public var npc: NPCState
  public var physicalTime: Double
  public var firstAggressorBinding: NPCReferenceBinding? = nil
  public var intentionTargetBinding: NPCReferenceBinding? = nil

  public var valid: Bool {
    (0..<8).contains(actor.system.galaxy) && (0...256).contains(actor.system.system)
      && actor.entity >= 2 && actor.entity < UInt64.max && actor.visit > 0
      && [.civilian, .pirate, .police].contains(population) && hull.isTargetShip
      && npc.role != .mission && (0...255).contains(npc.legal.value)
      && npc.legal.bountyTenths >= 0 && npc.ordinaryCargo.allSatisfy(\.valid)
      && (npc.resources?.valid ?? true)
      && energy.isFinite && energy > 0 && energy <= (npc.resources?.energyCapacity ?? 100000)
      && missiles >= 0 && position.finite && orientation.validRotation
      && velocity.finite && angularVelocity.finite && rotation.isFinite && rotationRate.isFinite
      && laserCooldown.isFinite && laserCooldown >= 0 && physicalTime.isFinite && physicalTime >= 0
      && (firstAggressorBinding?.valid(for: npc.firstAggressor, system: actor.system) ?? true)
      && (intentionTargetBinding?.valid(for: npc.intention?.referencedActor, system: actor.system)
        ?? true)
  }

  public static func capture(
    body: SpaceBody, pose: ShipPose, physicalTime: Double, protection: MissionProtection
  ) -> Self? {
    guard let physical = body.physical, var npc = physical.npc,
      !body.navalTarget, body.blackjackRole == nil, body.blackjackIdentity == nil,
      !physical.blocksNavalEncounter, physical.rock == nil, physical.payload == nil,
      physical.ordnance == nil, physical.salvage == nil,
      !protection.protectedActors.contains(physical.identity),
      pose.position.finite, pose.orientation.validRotation
    else { return nil }
    if npc.intention == nil, let suspended = physical.suspendedNPCIntention {
      npc.intention = suspended
    }
    let snapshot = Self(
      actor: physical.identity, population: physical.population, hull: body.hull,
      position: pose.systemPoint(body.position),
      orientation: body.orientation.transformed(by: pose.orientation),
      velocity: physical.velocity, angularVelocity: physical.angularVelocity,
      rotation: body.rotation, rotationRate: body.rotationRate,
      energy: body.energy, missiles: body.missiles, ecmEnabled: body.ecmEnabled,
      hostile: body.hostile, laserCooldown: physical.laserCooldown,
      catalogueShipID: physical.catalogueShipID, npc: npc, physicalTime: physicalTime)
    return snapshot.valid ? snapshot : nil
  }
}

public enum NPCPersistenceRefusal: String, Codable, Sendable {
  case invalidSnapshot, invalidLedger, protectedActor, wrongSystem, staleActor, staleTime, capacity
}

public enum NPCPersistenceCapture: Equatable, Codable, Sendable {
  case registered(ActorIdentity)
  case updated(ActorIdentity)
  case refused(NPCPersistenceRefusal)
}

public enum NPCTerminalReason: String, Codable, Sendable {
  case destroyed, docked, jumped, expired
}

/// Applying an accepted rebind once restores recorded consumables, never stock.
public struct NPCRebind: Equatable, Codable, Sendable {
  public let logicalIdentity: ActorIdentity
  public let actor: ActorIdentity
  public let snapshot: NPCPersistenceSnapshot

  public func restore(body: inout SpaceBody, pose: ShipPose) -> Bool {
    guard snapshot.valid, body.hull == snapshot.hull,
      var physical = body.physical, physical.identity == actor,
      !body.navalTarget, body.blackjackRole == nil, physical.npc?.role != .mission,
      pose.position.finite, pose.orientation.validRotation
    else { return false }
    body.position = pose.shipPoint(snapshot.position)
    body.orientation = snapshot.orientation.relative(to: pose.orientation)
    body.rotation = snapshot.rotation
    body.rotationRate = snapshot.rotationRate
    body.energy = snapshot.energy
    body.missiles = snapshot.missiles
    body.ecmEnabled = snapshot.ecmEnabled
    body.hostile = snapshot.hostile
    physical.population = snapshot.population
    physical.npc = snapshot.npc
    physical.suspendedNPCIntention = nil
    physical.velocity = snapshot.velocity
    physical.angularVelocity = snapshot.angularVelocity
    physical.laserCooldown = snapshot.laserCooldown
    physical.catalogueShipID = snapshot.catalogueShipID
    body.physical = physical
    return true
  }
}

private struct PersistentNPC: Equatable, Codable, Sendable {
  var snapshot: NPCPersistenceSnapshot
  var binding: ActorIdentity?
  var offer: SpawnIdentity?
  var terminal: NPCTerminalReason?
}

enum NPCSceneRestorationError: Error, Equatable {
  case invalidScene, invalidRecord
}

/// One current system, including terminal identities. Capacity is never recovered
/// by evicting a craft; explicit system departure ends this ledger's lifetime.
public struct NPCPersistenceLedger: Equatable, Codable, Sendable {
  public static let maximumEntries = 128
  public private(set) var system: SystemIdentity?
  private var entries: [ActorIdentity: PersistentNPC] = [:]
  private var highestActor: UInt64 = 1
  private var nextOffer: UInt64 = 1

  public init() {}

  public var count: Int { entries.count }
  public var livingCount: Int { entries.values.filter { $0.terminal == nil }.count }
  public var unboundSnapshots: [ActorIdentity: NPCPersistenceSnapshot] {
    entries.compactMapValues { entry in
      entry.binding == nil && entry.terminal == nil ? entry.snapshot : nil
    }
  }
  public var valid: Bool {
    guard count <= Self.maximumEntries, highestActor < UInt64.max,
      nextOffer > 0, nextOffer < UInt64.max,
      system != nil || entries.isEmpty
    else { return false }
    let bindings = entries.values.compactMap(\.binding)
    let offers = entries.values.compactMap(\.offer)
    return Set(bindings).count == bindings.count && Set(offers).count == offers.count
      && entries.allSatisfy { logical, entry in
        logical.system == system && logical.entity >= 2 && logical.entity <= highestActor
          && entry.snapshot.valid && entry.snapshot.actor.system == system
          && entry.snapshot.actor.entity <= highestActor
          && (entry.binding == nil || entry.binding == entry.snapshot.actor)
          && !(entry.binding != nil && entry.offer != nil)
          && (entry.terminal == nil || (entry.binding == nil && entry.offer == nil))
          && (entry.offer.map { $0.system == system && $0.producer == .persistence } ?? true)
          && [entry.snapshot.firstAggressorBinding, entry.snapshot.intentionTargetBinding]
            .compactMap { $0 }.allSatisfy {
              entries[$0.logicalNPC.firstActor] != nil && $0.sceneActor.entity <= highestActor
            }
      }
  }

  public func snapshot(for logical: ActorIdentity) -> NPCPersistenceSnapshot? {
    entries[logical]?.snapshot
  }

  public func binding(for logical: ActorIdentity) -> ActorIdentity? { entries[logical]?.binding }

  public func binding(for logical: NPCLogicalIdentity) -> ActorIdentity? {
    guard let entry = entries[logical.firstActor], entry.terminal == nil else { return nil }
    return entry.binding
  }

  public func logicalIdentity(for actor: ActorIdentity) -> ActorIdentity? {
    entries.first { $0.value.binding == actor }?.key
  }

  /// Rejoin only an already-restored saved actor, never allocate or refresh its condition.
  mutating func restoreSceneBindings(
    _ observed: [NPCPersistenceSnapshot], sceneActors: Set<ActorIdentity>,
    spawnIdentities: [ActorIdentity: SpawnIdentity],
    system: SystemIdentity, visit: UInt64,
    physicalTime: Double, nextActor: UInt64, protection: MissionProtection
  ) throws {
    guard valid, self.system == system, visit > 0, visit < UInt64.max,
      nextActor > 1, nextActor < UInt64.max,
      physicalTime.isFinite, physicalTime >= 0, observed.count <= Self.maximumEntries,
      Set(observed.map(\.actor)).count == observed.count,
      Set(observed.map(\.actor)).isSubset(of: sceneActors),
      Set(spawnIdentities.keys).isSubset(of: Set(observed.map(\.actor))),
      Set(spawnIdentities.values).count == spawnIdentities.count
    else { throw NPCSceneRestorationError.invalidScene }
    var logicalByActor: [ActorIdentity: ActorIdentity] = [:]
    let observedActors = Set(observed.map(\.actor))
    for (logical, entry) in entries where entry.terminal == nil {
      guard
        !sceneActors.contains(entry.snapshot.actor) || observedActors.contains(entry.snapshot.actor)
      else { throw NPCSceneRestorationError.invalidScene }
      guard logicalByActor.updateValue(logical, forKey: entry.snapshot.actor) == nil else {
        throw NPCSceneRestorationError.invalidRecord
      }
    }
    var staged = self
    for snapshot in observed {
      guard snapshot.valid, snapshot.actor.system == system, snapshot.actor.visit == visit,
        snapshot.actor.entity < nextActor, snapshot.physicalTime == physicalTime,
        validRestoredSpawn(spawnIdentities[snapshot.actor], for: snapshot),
        !protection.protectedActors.contains(snapshot.actor),
        let logical = logicalByActor[snapshot.actor],
        !protection.protectedActors.contains(logical), var entry = staged.entries[logical],
        entry.terminal == nil, entry.offer == nil,
        entry.binding == nil || entry.binding == snapshot.actor,
        bindingReferences(snapshot, previous: entry.snapshot, protection: protection)
          == entry.snapshot
      else { throw NPCSceneRestorationError.invalidRecord }
      entry.binding = snapshot.actor
      staged.entries[logical] = entry
    }
    guard staged.valid else { throw NPCSceneRestorationError.invalidRecord }
    self = staged
  }

  private func validRestoredSpawn(_ spawn: SpawnIdentity?, for snapshot: NPCPersistenceSnapshot)
    -> Bool
  {
    guard let spawn else { return true }  // Historical native bodies can lack a spawn address.
    guard spawn.system == snapshot.actor.system, spawn.visit == snapshot.actor.visit,
      spawn.sequence < UInt64.max
    else { return false }
    let civilian =
      snapshot.population == .civilian && [.trader, .miner, .escort].contains(snapshot.npc.role)
    let pirate = snapshot.population == .pirate && snapshot.npc.role == .pirate
    let police = snapshot.population == .police && snapshot.npc.role == .police
    // Native ambient wings have at most five members; security waves have at most eight.
    // Persistence alone uses this ledger's positive offer counter, never the flight spawn cursor.
    switch spawn.producer {
    case .ambient:
      return (civilian && snapshot.npc.role != .escort && spawn.member == 0)
        || (pirate && spawn.member < 5)
    case .security:
      return police && snapshot.hull == .viper && spawn.member < 8
    case .persistence:
      return (civilian || pirate || police) && spawn.sequence > 0
        && spawn.sequence < nextOffer && spawn.member == 0
    default: return false
    }
  }

  /// The runtime may advance a retained craft in world space without admitting
  /// another physical actor. Its logical identity and outstanding offer stay fixed.
  public mutating func updateUnbound(
    logicalIdentity: ActorIdentity, snapshot: NPCPersistenceSnapshot
  ) -> Bool {
    guard valid, snapshot.valid, var entry = entries[logicalIdentity],
      entry.binding == nil, entry.terminal == nil,
      snapshot.actor == entry.snapshot.actor, snapshot.actor.system == system,
      snapshot.firstAggressorBinding == entry.snapshot.firstAggressorBinding,
      snapshot.intentionTargetBinding == entry.snapshot.intentionTargetBinding,
      snapshot.physicalTime >= entry.snapshot.physicalTime
    else { return false }
    entry.snapshot = snapshot
    entries[logicalIdentity] = entry
    return true
  }

  /// First registrations must follow the global actor allocator's increasing
  /// entity order. The high-water barrier rejects retired physical-ID replays
  /// without accumulating an unbounded alias/tombstone list after every rebind.
  public mutating func capture(
    _ snapshot: NPCPersistenceSnapshot, protection: MissionProtection
  ) -> NPCPersistenceCapture {
    guard valid else { return .refused(.invalidLedger) }
    guard snapshot.valid else { return .refused(.invalidSnapshot) }
    guard !protection.protectedActors.contains(snapshot.actor) else {
      return .refused(.protectedActor)
    }
    guard system == nil || system == snapshot.actor.system else { return .refused(.wrongSystem) }
    if let logical = logicalIdentity(for: snapshot.actor), var entry = entries[logical] {
      guard !protection.protectedActors.contains(logical) else { return .refused(.protectedActor) }
      guard snapshot.physicalTime >= entry.snapshot.physicalTime else {
        return .refused(.staleTime)
      }
      entry.snapshot = bindingReferences(snapshot, previous: entry.snapshot, protection: protection)
      entries[logical] = entry
      return .updated(logical)
    }
    guard snapshot.actor.entity > highestActor else { return .refused(.staleActor) }
    guard count < Self.maximumEntries else { return .refused(.capacity) }
    system = snapshot.actor.system
    highestActor = snapshot.actor.entity
    entries[snapshot.actor] = .init(
      snapshot: bindingReferences(snapshot, previous: nil, protection: protection),
      binding: snapshot.actor)
    // A just-registered actor can be an existing snapshot's previously unregistered target.
    // One bounded pass handles an initial batch without maintaining historical aliases.
    for logical in entries.keys {
      guard let previous = entries[logical]?.snapshot else { continue }
      let normalized = bindingReferences(
        previous, previous: previous, protection: protection)
      entries[logical]?.snapshot = normalized
    }
    return .registered(snapshot.actor)
  }

  private func bindingReferences(
    _ snapshot: NPCPersistenceSnapshot, previous: NPCPersistenceSnapshot?,
    protection: MissionProtection
  ) -> NPCPersistenceSnapshot {
    var result = snapshot
    result.firstAggressorBinding = bindingReference(
      snapshot.npc.firstAggressor, previous: previous?.firstAggressorBinding, protection: protection
    )
    result.intentionTargetBinding = bindingReference(
      snapshot.npc.intention?.referencedActor, previous: previous?.intentionTargetBinding,
      protection: protection)
    return result
  }

  private func bindingReference(
    _ actor: ActorIdentity?, previous: NPCReferenceBinding?, protection: MissionProtection
  ) -> NPCReferenceBinding? {
    guard let actor, actor.system == system, !protection.protectedActors.contains(actor) else {
      return nil
    }
    if let logical = logicalIdentity(for: actor), !protection.protectedActors.contains(logical) {
      return .init(sceneActor: actor, logicalNPC: .init(firstActor: logical))
    }
    if let previous, previous.sceneActor == actor,
      entries[previous.logicalNPC.firstActor] != nil,
      !protection.protectedActors.contains(previous.logicalNPC.firstActor)
    {
      return previous
    }
    return nil
  }

  /// Capture the final actual world state first; culling only releases a binding.
  public mutating func cull(actor: ActorIdentity) {
    guard let logical = logicalIdentity(for: actor) else { return }
    entries[logical]?.binding = nil
  }

  public mutating func terminal(actor: ActorIdentity, reason: NPCTerminalReason) -> Bool {
    guard let logical = logicalIdentity(for: actor), var entry = entries[logical] else {
      return false
    }
    entry.binding = nil
    entry.offer = nil
    entry.terminal = reason
    entries[logical] = entry
    return true
  }

  public mutating func pendingSpawnRequests(context: EncounterContext) -> [SpawnRequest] {
    guard valid, context.system == system, context.physicalTime.isFinite,
      context.perceptionRadius.isFinite, context.perceptionRadius > 0,
      context.player.position.finite
    else { return [] }
    var budget = context.budget
    var requests: [SpawnRequest] = []
    for logical in entries.keys.sorted(by: { $0.entity < $1.entity }) {
      guard var entry = entries[logical], entry.terminal == nil, entry.binding == nil else {
        continue
      }
      if entry.offer?.visit != context.visit { entry.offer = nil }
      let snapshot = entry.snapshot
      guard context.physicalTime >= snapshot.physicalTime,
        (snapshot.position - context.player.position).length <= context.perceptionRadius,
        !context.protection.protectedActors.contains(logical),
        !context.protection.protectedActors.contains(snapshot.actor),
        !(context.protection.suppressAmbientShips && snapshot.population != .police),
        canOffer(snapshot.population, budget: budget)
      else {
        entries[logical] = entry
        continue
      }
      if entry.offer == nil {
        guard nextOffer < UInt64.max - 1 else { continue }
        entry.offer = .init(
          system: context.system, visit: context.visit, sequence: nextOffer, member: 0,
          producer: .persistence)
        nextOffer += 1
      }
      entries[logical] = entry
      guard let offer = entry.offer else { continue }
      requests.append(
        .init(
          identity: offer, population: snapshot.population, hull: snapshot.hull,
          position: snapshot.position, orientation: snapshot.orientation,
          velocity: snapshot.velocity, npc: snapshot.npc, rock: nil, payload: nil,
          priority: snapshot.population == .police ? .police : .ordinary,
          catalogueShipID: snapshot.catalogueShipID, energy: snapshot.energy,
          angularVelocity: snapshot.angularVelocity))
      budget.total += 1
      budget.active[snapshot.population, default: 0] += 1
    }
    return requests
  }

  /// A consumed offer cannot restore resources again on a duplicate receipt.
  public mutating func acknowledge(receipts: [SpawnReceipt]) -> [NPCRebind] {
    var rebindings: [NPCRebind] = []
    for receipt in receipts.sorted(by: { ($0.actor?.entity ?? 0) < ($1.actor?.entity ?? 0) }) {
      guard receipt.refusal == nil, let actor = receipt.actor,
        actor.system == system, actor.visit == receipt.request.visit,
        actor.entity > highestActor, actor.entity < UInt64.max,
        logicalIdentity(for: actor) == nil,
        let logical = entries.first(where: { $0.value.offer == receipt.request })?.key,
        var entry = entries[logical], entry.terminal == nil, entry.binding == nil,
        actor.entity > entry.snapshot.actor.entity
      else { continue }
      entry.binding = actor
      entry.offer = nil
      entry.snapshot.actor = actor
      highestActor = max(highestActor, actor.entity)
      entries[logical] = entry
      rebindings.append(.init(logicalIdentity: logical, actor: actor, snapshot: entry.snapshot))
    }
    return rebindings
  }

  /// Save/load and docking preserve the craft; scene-local bindings do not survive.
  public mutating func resetPhysicalBindings(system: SystemIdentity) {
    guard self.system == system else { return }
    for logical in entries.keys {
      entries[logical]?.binding = nil
      entries[logical]?.offer = nil
    }
  }

  /// Only explicit system travel abandons this finite ordinary population.
  public mutating func depart(system: SystemIdentity) {
    guard self.system == system else { return }
    self.system = nil
    entries.removeAll()
    // Physical entity allocation is global, so departure must retain replay and
    // request high-water marks even when returning to the same system later.
  }

  private func canOffer(_ population: PopulationClass, budget: AdmissionBudget) -> Bool {
    let reserve: Int
    if population == .police {
      reserve = max(0, budget.missionReserve - budget.active[.mission, default: 0])
    } else {
      reserve =
        max(0, budget.policeReserve - budget.active[.police, default: 0])
        + max(0, budget.missionReserve - budget.active[.mission, default: 0])
    }
    return budget.total < budget.maximum - reserve
      && budget.active[population, default: 0] < population.maximum
  }
}
