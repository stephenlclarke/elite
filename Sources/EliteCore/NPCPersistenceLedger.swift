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
      && (npc.resources?.legacyElectricalRecharge.map {
        $0
          == (catalogueShipID.flatMap { ShipCatalogue.ship($0)?.game?.recharge }
            ?? ShipCatalogue.nativeShip(hull)?.game?.recharge)
      } ?? true)
      && (npc.resources?.electrical.map { $0.physicalTime <= physicalTime } ?? true)
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
      physical.empSource == nil, physical.empCrewPod == nil,
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
  case destroyed, docked, jumped, expired, empTransferred
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

  var hasElectricalState: Bool {
    entries.values.contains { $0.snapshot.npc.resources?.electrical != nil }
  }

  var empTransfers: [ActorIdentity: NPCPersistenceSnapshot] {
    entries.compactMapValues { $0.terminal == .empTransferred ? $0.snapshot : nil }
  }
  func terminalReason(for logical: ActorIdentity) -> NPCTerminalReason? {
    entries[logical]?.terminal
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

  /// A private EMP transition returns this current snapshot under the original logical key.
  /// A departed ledger can import the retained archive unbound, without bypassing actor allocation.
  mutating func returnEMPTransfer(
    logical: ActorIdentity, expectedTransfer: NPCPersistenceSnapshot,
    current: NPCPersistenceSnapshot, bind: Bool, protection: MissionProtection
  ) -> SpawnIdentity? {
    guard valid, current.valid, expectedTransfer.valid,
      logical.system == current.actor.system, expectedTransfer.actor.system == logical.system,
      logical.visit <= current.actor.visit, current.physicalTime >= expectedTransfer.physicalTime,
      current.hull == expectedTransfer.hull, current.npc.role == expectedTransfer.npc.role,
      system == nil || system == logical.system,
      !protection.protectedActors.contains(logical),
      !protection.protectedActors.contains(current.actor),
      entries.allSatisfy({ $0.key == logical || $0.value.binding != current.actor }),
      nextOffer < UInt64.max - 1
    else { return nil }
    if let prior = entries[logical] {
      guard prior.terminal == .empTransferred, prior.snapshot == expectedTransfer,
        prior.binding == nil, prior.offer == nil
      else { return nil }
    } else {
      guard entries.count < Self.maximumEntries else { return nil }
    }
    var candidate = self
    candidate.system = logical.system
    candidate.highestActor = max(highestActor, max(logical.entity, current.actor.entity))
    let spawn = SpawnIdentity(
      system: current.actor.system, visit: current.actor.visit,
      sequence: nextOffer, member: 0, producer: .persistence)
    candidate.nextOffer += 1
    candidate.entries[logical] = .init(
      snapshot: candidate.bindingReferences(
        current,
        previous: entries[logical]?.snapshot, protection: protection),
      binding: bind ? current.actor : nil)
    guard candidate.valid else { return nil }
    self = candidate
    return spawn
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
    case .provider:
      return spawn.system == NativeCrimboRegistry.system && spawn.sequence > 0
        && snapshot.population == .civilian
        && ((spawn.member < 6 && snapshot.catalogueShipID == "SH151"
          && snapshot.hull == .viper && snapshot.npc.role == .escort)
          || (spawn.member == 6 && snapshot.catalogueShipID == "SH150"
            && snapshot.hull == .cobra && snapshot.npc.role == .trader))
    case .persistence:
      return (civilian || pirate || police) && spawn.sequence > 0
        && spawn.sequence < nextOffer && spawn.member == 0
    default: return false
    }
  }

  /// Removes the exact originals atomically. The caller must park these in the same world candidate.
  /// High-water marks survive removal; a replay cannot register an old physical actor again.
  mutating func takeProviderOriginals(
    expected: [NPCLogicalIdentity: NPCPersistenceSnapshot], protection: MissionProtection
  ) throws -> [NPCLogicalIdentity: NPCPersistenceSnapshot] {
    guard valid, !expected.isEmpty, expected.count <= 7,
      expected.allSatisfy({ logical, snapshot in
        let entry = entries[logical.firstActor]
        return Self.validProviderOriginal(logical, snapshot: snapshot, protection: protection)
          && entry?.snapshot == snapshot && entry?.terminal == nil
      })
    else { throw NativeCrimboError.invalidTransfer }
    var candidate = self
    for logical in expected.keys { candidate.entries.removeValue(forKey: logical.firstActor) }
    candidate.normalizeProviderReferences(protection: protection)
    guard candidate.valid else { throw NativeCrimboError.invalidTransfer }
    self = candidate
    return expected
  }

  /// Replaces only exact fresh provisional registrations created by native admission.
  /// Actual bodies must already contain the parked resources; importing never supplies stock.
  mutating func importProviderOriginals(
    parked: [NPCLogicalIdentity: NPCPersistenceSnapshot],
    admitted: [NPCLogicalIdentity: NPCPersistenceSnapshot], protection: MissionProtection
  ) throws {
    guard valid, !parked.isEmpty, parked.count <= 7, Set(parked.keys) == Set(admitted.keys),
      Set(admitted.values.map(\.actor)).count == admitted.count,
      let firstAdmission = admitted.values.map({ $0.actor.entity }).min(),
      parked.values.allSatisfy({ $0.actor.entity < firstAdmission })
    else { throw NativeCrimboError.invalidTransfer }
    var candidate = self
    for (logical, original) in parked {
      guard let current = admitted[logical],
        Self.validProviderOriginal(logical, snapshot: original, protection: protection),
        Self.validProviderOriginal(logical, snapshot: current, protection: protection),
        logical.firstActor.entity <= highestActor, entries[logical.firstActor] == nil,
        current.actor.entity > original.actor.entity, current.actor.visit >= original.actor.visit,
        current.actor.system == system, current.physicalTime >= original.physicalTime,
        let provisional = entries[current.actor], provisional.binding == current.actor,
        provisional.terminal == nil, provisional.offer == nil,
        Self.providerOriginalStateMatches(provisional.snapshot, current)
          && Self.providerGeometryMatches(provisional.snapshot, current)
      else { throw NativeCrimboError.invalidTransfer }
      var expected = original
      expected.actor = current.actor
      expected.physicalTime = current.physicalTime
      guard Self.providerOriginalStateMatches(expected, current),
        Self.providerGeometryMatches(expected, current)
      else {
        throw NativeCrimboError.invalidTransfer
      }
      candidate.entries.removeValue(forKey: current.actor)
      candidate.entries[logical.firstActor] = .init(snapshot: current, binding: current.actor)
    }
    candidate.normalizeProviderReferences(protection: protection)
    guard candidate.valid else { throw NativeCrimboError.invalidTransfer }
    self = candidate
  }

  private static func validProviderOriginal(
    _ logical: NPCLogicalIdentity, snapshot: NPCPersistenceSnapshot,
    protection: MissionProtection
  ) -> Bool {
    let slot = snapshot.catalogueShipID == "SH150" ? 6 : 0
    return logical.firstActor.system == NativeCrimboRegistry.system
      && logical.firstActor.entity >= 2 && logical.firstActor.entity < UInt64.max
      && logical.firstActor.visit > 0 && logical.firstActor.visit <= snapshot.actor.visit
      && snapshot.actor.entity >= logical.firstActor.entity
      && !protection.protectedActors.contains(logical.firstActor)
      && !protection.protectedActors.contains(snapshot.actor)
      && snapshot.valid && snapshot.actor.system == NativeCrimboRegistry.system
      && snapshot.population == .civilian
      && snapshot.catalogueShipID == (slot == 6 ? "SH150" : "SH151")
      && snapshot.hull == (slot == 6 ? .cobra : .viper)
      && snapshot.npc.role == (slot == 6 ? .trader : .escort)
  }

  /// Geometry alone may round during world/camera projection. Consumables, clocks and motion may not.
  private static func providerOriginalStateMatches(
    _ lhs: NPCPersistenceSnapshot, _ rhs: NPCPersistenceSnapshot
  ) -> Bool {
    lhs.actor == rhs.actor && lhs.population == rhs.population && lhs.hull == rhs.hull
      && lhs.velocity == rhs.velocity && lhs.angularVelocity == rhs.angularVelocity
      && lhs.rotation == rhs.rotation && lhs.rotationRate == rhs.rotationRate
      && lhs.energy == rhs.energy && lhs.missiles == rhs.missiles
      && lhs.ecmEnabled == rhs.ecmEnabled && lhs.hostile == rhs.hostile
      && lhs.laserCooldown == rhs.laserCooldown && lhs.catalogueShipID == rhs.catalogueShipID
      && lhs.npc == rhs.npc && lhs.physicalTime == rhs.physicalTime
  }

  private static func providerGeometryMatches(
    _ lhs: NPCPersistenceSnapshot, _ rhs: NPCPersistenceSnapshot
  ) -> Bool {
    guard lhs.position.finite, rhs.position.finite,
      lhs.orientation.validRotation, rhs.orientation.validRotation
    else { return false }
    // Never exceeds the native main-station projection tolerance; relative scale handles roundoff.
    let scale = max(1, lhs.position.length, rhs.position.length)
    let positionTolerance = min(1e-5, scale * 1e-10)
    return (lhs.position - rhs.position).length <= positionTolerance
      && (lhs.orientation.x - rhs.orientation.x).length <= 1e-10
      && (lhs.orientation.y - rhs.orientation.y).length <= 1e-10
      && (lhs.orientation.z - rhs.orientation.z).length <= 1e-10
  }

  private mutating func normalizeProviderReferences(protection: MissionProtection) {
    for logical in Array(entries.keys) {
      guard var entry = entries[logical] else { continue }
      let snapshot = entry.snapshot
      entry.snapshot = bindingReferences(
        snapshot, previous: snapshot, protection: protection)
      entries[logical] = entry
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

  /// A checked native owner may restore its exact eligible originals as one ordinary cohort.
  /// Offers remain in this ledger; no original keys or reference bindings are removed.
  mutating func pendingProviderSpawnRequests(
    context: EncounterContext, originals: [NPCLogicalIdentity: NPCPersistenceSnapshot]
  ) -> [SpawnRequest] {
    guard !originals.isEmpty else { return [] }
    guard valid, context.system == system, context.system == NativeCrimboRegistry.system,
      context.visit > 0, context.visit < UInt64.max,
      context.physicalTime.isFinite, context.physicalTime >= 0,
      context.player.identity.system == context.system,
      context.player.identity.visit == context.visit,
      context.player.position.finite, !context.protection.suppressAmbientShips,
      originals.count <= 7,
      Set(originals.values.map(\.actor)).count == originals.count
    else { return [] }
    var candidate = self
    var budget = context.budget
    var requests: [SpawnRequest] = []
    for logical in originals.keys.sorted(by: { $0.firstActor.entity < $1.firstActor.entity }) {
      guard let snapshot = originals[logical], var entry = candidate.entries[logical.firstActor],
        entry.snapshot == snapshot, entry.binding == nil, entry.terminal == nil,
        Self.validProviderOriginal(logical, snapshot: snapshot, protection: context.protection),
        snapshot.actor.visit <= context.visit, context.physicalTime >= snapshot.physicalTime,
        snapshot.npc.resources?.electrical?.disabledAt == nil,
        !context.actors.contains(where: { $0.identity == snapshot.actor }),
        !SpaceBody(
          id: -1, hull: snapshot.hull,
          position: snapshot.position - context.player.position
        ).leavesLocalBubble,
        canOffer(snapshot.population, budget: budget)
      else { return [] }
      if entry.offer?.visit != context.visit { entry.offer = nil }
      if let offer = entry.offer {
        guard offer.system == context.system, offer.producer == .persistence,
          offer.member == 0, offer.sequence > 0, offer.sequence < candidate.nextOffer
        else { return [] }
      } else {
        guard candidate.nextOffer < UInt64.max - 1 else { return [] }
        entry.offer = .init(
          system: context.system, visit: context.visit, sequence: candidate.nextOffer,
          member: 0, producer: .persistence)
        candidate.nextOffer += 1
      }
      guard let offer = entry.offer else { return [] }
      candidate.entries[logical.firstActor] = entry
      requests.append(
        .init(
          identity: offer, population: snapshot.population, hull: snapshot.hull,
          position: snapshot.position, orientation: snapshot.orientation,
          velocity: snapshot.velocity,
          npc: snapshot.npc, rock: nil, payload: nil, priority: .ordinary,
          catalogueShipID: snapshot.catalogueShipID, energy: snapshot.energy,
          angularVelocity: snapshot.angularVelocity))
      budget.total += 1
      budget.active[snapshot.population, default: 0] += 1
    }
    guard candidate.valid else { return [] }
    self = candidate
    return requests
  }

  public mutating func pendingSpawnRequests(
    context: EncounterContext, excludedLogicalKeys: Set<ActorIdentity> = []
  ) -> [SpawnRequest] {
    guard valid, context.system == system, context.physicalTime.isFinite,
      context.perceptionRadius.isFinite, context.perceptionRadius > 0,
      context.player.position.finite
    else { return [] }
    var budget = context.budget
    var requests: [SpawnRequest] = []
    for logical in entries.keys.sorted(by: { $0.entity < $1.entity }) {
      guard !excludedLogicalKeys.contains(logical), var entry = entries[logical],
        entry.terminal == nil, entry.binding == nil
      else {
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
