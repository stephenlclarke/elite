import Foundation

enum NativeCrimboError: Error, Equatable {
  case invalidRegistry, invalidTransfer, unavailable, invalidMotion
}

/// A live member owns only its original logical reference. Parked state is the sole offsite copy.
enum NativeCrimboOwnership: Equatable, Codable, Sendable {
  case pending
  case live(NPCLogicalIdentity)
  case parked(NPCLogicalIdentity, NPCPersistenceSnapshot)
  case electrical(NPCLogicalIdentity, ActorIdentity)
  case terminal(NPCLogicalIdentity, NPCTerminalReason)

  var logical: NPCLogicalIdentity? {
    switch self {
    case .pending: nil
    case .live(let logical), .parked(let logical, _), .electrical(let logical, _),
      .terminal(let logical, _):
      logical
    }
  }
}

struct NativeCrimboMember: Equatable, Codable, Sendable {
  let identity: UUID
  let slot: Int
  var ownership: NativeCrimboOwnership
  var catalogueShipID: String { slot == 6 ? "SH150" : "SH151" }
  var role: NPCRole { slot == 6 ? .trader : .escort }
  var hull: Hull { slot == 6 ? .cobra : .viper }
}

/// Explicit native birth policy. Consumed only at first admission, never at a rebind.
struct NativeCrimboLoadout: Equatable, Codable, Sendable {
  let missiles: Int
  let ecmEnabled: Bool
  func valid(catalogue: String) -> Bool {
    guard let performance = ShipCatalogue.ship(catalogue)?.game else { return false }
    return (0...performance.missiles).contains(missiles)
  }
}

struct NativeCrimboThreat: Equatable, Codable, Sendable {
  let attacker: ActorIdentity
  let logicalNPC: NPCLogicalIdentity?
  let incident: UInt64
  let physicalTime: Double
}

/// Native originals exist independently of mission acceptance. This value is not execution authority.
struct NativeCrimboRegistry: Equatable, Codable, Sendable {
  static let system = SystemIdentity(galaxy: 7, system: 8)
  let world: UUID
  let spawnSequence: UInt64
  let provider: NativeProviderIdentity
  let manifest: NativeProviderManifest
  let origin: NativeMainStationIdentity
  var destination: NativeMainStationIdentity?
  let santaLoadout: NativeCrimboLoadout
  let rudolfLoadout: NativeCrimboLoadout
  var orbit: OrbitFormationState
  var members: [NativeCrimboMember]
  var currentOrder: UInt64 = 1
  var lastCombatIncident: UInt64 = 0
  var threat: NativeCrimboThreat?
  var betrayal: NativeProviderBetrayal?

  init(
    world: UUID, spawnSequence: UInt64, origin: NativeMainStationIdentity,
    orbit: OrbitFormationState,
    santaLoadout: NativeCrimboLoadout, rudolfLoadout: NativeCrimboLoadout
  ) throws {
    self.world = world
    self.spawnSequence = spawnSequence
    self.origin = origin
    self.orbit = orbit
    self.santaLoadout = santaLoadout
    self.rudolfLoadout = rudolfLoadout
    provider = .init(
      definition: "crimbo-convoy", system: Self.system, incarnation: orbit.incarnation)
    members = (0..<7).map { .init(identity: UUID(), slot: $0, ownership: .pending) }
    manifest = .init(
      identity: UUID(), revision: 1, provider: provider, subject: members[6].identity)
    try validate()
  }

  func validate() throws {
    _ = try OrbitFormationController.step(
      state: orbit, input: .init(anchor: orbit.anchor, members: [], delta: 0.1))
    guard spawnSequence > 0, spawnSequence < UInt64.max, provider.valid,
      provider.definition == "crimbo-convoy", provider.system == Self.system,
      provider.incarnation == orbit.incarnation, manifest.valid, manifest.revision == 1,
      manifest.provider == provider,
      members.count == 7, members.map(\.slot) == Array(0..<7),
      Set(members.map(\.identity)).count == 7, manifest.subject == members[6].identity,
      origin.valid, origin.world == world, origin.system == Self.system,
      destination.map({ $0.valid && $0.world == world }) ?? true,
      santaLoadout.valid(catalogue: "SH150"), rudolfLoadout.valid(catalogue: "SH151"),
      [0, 7].contains(members.filter { $0.ownership == .pending }.count),
      currentOrder > 0, currentOrder < UInt64(Int64.max), lastCombatIncident < UInt64.max,
      Set(members.compactMap { $0.ownership.logical }).count
        == members.compactMap({ $0.ownership.logical }).count,
      orbit.slots.allSatisfy({ slot in
        members.contains { $0.identity == slot.logicalID && $0.slot == slot.slot }
      })
    else { throw NativeCrimboError.invalidRegistry }
    for member in members {
      if let logical = member.ownership.logical {
        guard logical.firstActor.system == Self.system, logical.firstActor.entity >= 2,
          logical.firstActor.entity < UInt64.max, logical.firstActor.visit > 0,
          logical.firstActor.visit < UInt64.max
        else { throw NativeCrimboError.invalidRegistry }
      }
      switch member.ownership {
      case .parked(let logical, let snapshot):
        guard Self.matches(snapshot, member: member),
          snapshot.actor.entity >= logical.firstActor.entity,
          snapshot.actor.visit >= logical.firstActor.visit
        else { throw NativeCrimboError.invalidRegistry }
      case .electrical(_, let source):
        guard source.system == Self.system, source.entity >= 2, source.entity < UInt64.max,
          source.visit > 0, source.visit < UInt64.max
        else { throw NativeCrimboError.invalidRegistry }
      case .terminal(_, let reason):
        guard reason != .empTransferred else { throw NativeCrimboError.invalidRegistry }
      default: break
      }
    }
    if let threat {
      guard threat.attacker.system == Self.system, threat.attacker.visit > 0,
        threat.attacker.entity < UInt64.max, threat.incident > 0,
        threat.incident <= lastCombatIncident, threat.physicalTime.isFinite,
        threat.physicalTime >= 0,
        threat.logicalNPC.map({ logical in
          logical.firstActor.system == Self.system && logical.firstActor.entity >= 2
            && logical.firstActor.entity <= threat.attacker.entity
            && logical.firstActor.visit > 0 && logical.firstActor.visit <= threat.attacker.visit
            && !members.contains(where: { $0.ownership.logical == logical })
        })
          ?? (threat.attacker.entity == 0)
      else { throw NativeCrimboError.invalidRegistry }
    }
    if let betrayal {
      guard betrayal.valid, betrayal.provider == provider,
        members.contains(where: { $0.identity == betrayal.member }), betrayal.order <= currentOrder
      else { throw NativeCrimboError.invalidRegistry }
    }
  }

  static func matches(_ snapshot: NPCPersistenceSnapshot, member: NativeCrimboMember) -> Bool {
    snapshot.valid && snapshot.actor.visit < UInt64.max
      && snapshot.actor.system == system && snapshot.population == .civilian
      && snapshot.catalogueShipID == member.catalogueShipID && snapshot.hull == member.hull
      && snapshot.npc.role == member.role
  }

  func binding(of member: NativeCrimboMember, ledger: NPCPersistenceLedger) -> ActorIdentity? {
    guard case .live(let logical) = member.ownership,
      let snapshot = ledger.snapshot(for: logical.firstActor),
      Self.matches(snapshot, member: member)
    else { return nil }
    return ledger.binding(for: logical)
  }

  func contains(actor: ActorIdentity, ledger: NPCPersistenceLedger) -> Bool {
    members.contains { binding(of: $0, ledger: ledger) == actor }
  }

  private enum CodingKeys: String, CodingKey {
    case world, spawnSequence, provider, manifest, origin, destination, santaLoadout, rudolfLoadout,
      orbit, members
    case currentOrder, lastCombatIncident, threat, betrayal
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    var entries = try values.nestedUnkeyedContainer(forKey: .members)
    guard (entries.count ?? 7) == 7 else { throw NativeCrimboError.invalidRegistry }
    var decoded: [NativeCrimboMember] = []
    while !entries.isAtEnd {
      guard decoded.count < 7 else { throw NativeCrimboError.invalidRegistry }
      decoded.append(try entries.decode(NativeCrimboMember.self))
    }
    members = decoded
    world = try values.decode(UUID.self, forKey: .world)
    spawnSequence = try values.decode(UInt64.self, forKey: .spawnSequence)
    provider = try values.decode(NativeProviderIdentity.self, forKey: .provider)
    manifest = try values.decode(NativeProviderManifest.self, forKey: .manifest)
    origin = try values.decode(NativeMainStationIdentity.self, forKey: .origin)
    destination = try values.decodeIfPresent(NativeMainStationIdentity.self, forKey: .destination)
    santaLoadout = try values.decode(NativeCrimboLoadout.self, forKey: .santaLoadout)
    rudolfLoadout = try values.decode(NativeCrimboLoadout.self, forKey: .rudolfLoadout)
    orbit = try values.decode(OrbitFormationState.self, forKey: .orbit)
    currentOrder = try values.decode(UInt64.self, forKey: .currentOrder)
    lastCombatIncident = try values.decode(UInt64.self, forKey: .lastCombatIncident)
    threat = try values.decodeIfPresent(NativeCrimboThreat.self, forKey: .threat)
    betrayal = try values.decodeIfPresent(NativeProviderBetrayal.self, forKey: .betrayal)
    try validate()
  }
}
