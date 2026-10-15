import Foundation

public struct SystemIdentity: Hashable, Codable, Sendable {
  public let galaxy: Int
  public let system: Int
}

/// Physical identities belong to one visit; persistent ore identities do not.
public struct ActorIdentity: Hashable, Codable, Sendable {
  public let system: SystemIdentity
  public let visit: UInt64
  public let entity: UInt64
}

public struct RockIdentity: Hashable, Codable, Sendable {
  public let system: SystemIdentity
  public let field: UInt16
  public let rock: UInt16
}

public enum PayloadIdentity: Hashable, Codable, Sendable {
  case ore(RockIdentity, fragment: UInt16)
  case wreck(ActorIdentity, lot: UInt16)
  case mission(instance: UUID, payload: String)
  case salvage(SalvageLotIdentity)
}

public enum SpawnProducer: String, Codable, Sendable {
  case ambient, mining, salvage, security, mission
}

public struct SpawnIdentity: Hashable, Codable, Sendable {
  public let system: SystemIdentity
  public let visit: UInt64
  public let sequence: UInt64
  public let member: UInt16
  public var producer: SpawnProducer = .ambient
}

/// Raw values are the existing market/save indices. Units have one authority.
public enum CommodityIdentity: Int, CaseIterable, Codable, Sendable {
  case food, textiles, radioactives, slaves, liquor, luxuries, narcotics, computers,
    machinery, alloys, firearms, furs, minerals, gold, platinum, gemstones, alienItems
  public var unit: String { Commodity.all[rawValue].unit }
  public var name: String { Commodity.all[rawValue].name }
}

public struct CommodityAmount: Equatable, Codable, Sendable {
  public let commodity: CommodityIdentity
  public let quantity: Int
  public var valid: Bool { quantity > 0 && quantity <= Int.max / 17 }
  public var tonnes: Int { commodity.unit == "t" ? quantity : 0 }
}

public struct LegalRecord: Equatable, Codable, Sendable {
  public var value: Int = 0
  public var bountyTenths: Int = 0
  public var wanted: Bool { value > 0 }
}

public enum NPCRole: String, CaseIterable, Codable, Sendable {
  case trader, miner, pirate, police, escort, mission
}

public enum NPCAction: Equatable, Codable, Sendable {
  case navigate(position: Vector3, speedUnitsPerSecond: Double)
  case engage(ActorIdentity)
  case flee(ActorIdentity)
  case dock(ActorIdentity)
  case mine(RockIdentity)
  case scoop(PayloadIdentity)
}

public struct NPCState: Equatable, Codable, Sendable {
  public var role: NPCRole
  public var legal = LegalRecord()
  public var firstAggressor: ActorIdentity?
  public var intention: NPCAction?
  public var origin: SystemIdentity
  public var destination: SystemIdentity
  public var ordinaryCargo: [CommodityAmount] = []
}

public struct ShipPose: Equatable, Codable, Sendable {
  public var position = Vector3(0, 0, 0)
  public var orientation = Basis3()
  public func systemPoint(_ relative: Vector3) -> Vector3 {
    position + orientation.apply(relative)
  }
  public func shipPoint(_ world: Vector3) -> Vector3 { shipVector(world - position) }
  public func shipVector(_ world: Vector3) -> Vector3 {
    .init(world.dot(orientation.x), world.dot(orientation.y), world.dot(orientation.z))
  }
}

public struct SphereAnchor: Equatable, Codable, Sendable {
  public let position: Vector3
  public let radius: Double
}

public struct StationAnchor: Equatable, Codable, Sendable {
  public let identity: ActorIdentity
  public let position: Vector3
  public let orientation: Basis3
  public let exitPosition: Vector3
  public let exitDirection: Vector3
}

public struct SystemAnchors: Equatable, Codable, Sendable {
  public let system: SystemIdentity
  public let station: StationAnchor
  public let arrival: Vector3
  public let planet: SphereAnchor
  public let sun: SphereAnchor
}

public struct ActorSnapshot: Equatable, Codable, Sendable {
  public let identity: ActorIdentity
  public let hull: Hull
  public let position: Vector3
  public let orientation: Basis3
  public let velocity: Vector3
  public let energy: Double
  public let maximumEnergy: Double
  public let maximumSpeedUnitsPerSecond: Double
  public let legal: LegalRecord
  public let npc: NPCState?
  public let rock: RockIdentity?
  public let payload: PayloadIdentity?
  /// Available native units only; mission-owned cargo is not pirate loot.
  public var ordinaryCargo: [CommodityAmount] = []
  public var catalogueShipID: String?
  public var angularVelocity = Vector3(0, 0, 0)
  public var salvage: SalvageTargetMetadata?
}

public struct MissionProtection: Equatable, Codable, Sendable {
  public var protectedActors: Set<ActorIdentity> = []
  public var protectedPayloads: Set<PayloadIdentity> = []
  public var suppressAmbientShips = false
  public var blocksNavalEncounter = false
  public var reservedSlots = 4
}

public enum PopulationClass: String, CaseIterable, Codable, Sendable {
  case civilian, pirate, police, asteroid, cargo, projectile, mission
  public var maximum: Int {
    switch self {
    case .civilian, .pirate, .police: return 8
    case .asteroid: return 24
    case .cargo, .projectile: return 32
    case .mission: return Int.max
    }
  }
}

/// G1 supplies counts and makes the final atomic admission decision.
public struct AdmissionBudget: Equatable, Codable, Sendable {
  public var active: [PopulationClass: Int] = [:]
  public var total = 0
  public var maximum = 128
  public var policeReserve = 8
  public var missionReserve = 4
  public var ordinaryRemaining: Int {
    max(
      0,
      maximum - total - max(0, policeReserve - active[.police, default: 0])
        - max(0, missionReserve - active[.mission, default: 0]))
  }
}

public struct EncounterContext: Equatable, Codable, Sendable {
  public let system: SystemIdentity
  public let seed: UInt64
  public let government: Int
  public let visit: UInt64
  public let revision: UInt64
  public let physicalTime: Double
  public let anchors: SystemAnchors
  public let player: ActorSnapshot
  public let actors: [ActorSnapshot]
  public let protection: MissionProtection
  public let budget: AdmissionBudget
  public let perceptionRadius: Double
  /// Current-system terminal rocks, independent of scene admission/culling.
  public var depletedRocks: Set<RockIdentity> = []
}

public enum AdmissionPriority: Int, Comparable, Codable, Sendable {
  case mission, police, ordinary
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct SpawnRequest: Equatable, Codable, Sendable {
  public let identity: SpawnIdentity
  public let population: PopulationClass
  public let hull: Hull
  public let position: Vector3
  public let orientation: Basis3
  public let velocity: Vector3
  public let npc: NPCState?
  public let rock: RockIdentity?
  public let payload: PayloadIdentity?
  public let priority: AdmissionPriority
  public var catalogueShipID: String?
  public var angularVelocity = Vector3(0, 0, 0)
  public var salvage: SalvageTargetMetadata?
}

public struct SpawnBatch: Equatable, Codable, Sendable {
  public let requests: [SpawnRequest]
  public let atomic: Bool
}

public enum AdmissionRefusal: String, Codable, Sendable {
  case staleContext, populationLimit, reservedCapacity, missionSuppression, unsafePosition
}

public struct SpawnReceipt: Equatable, Codable, Sendable {
  public let request: SpawnIdentity
  public let actor: ActorIdentity?
  public let refusal: AdmissionRefusal?
}

/// Intents request physical actions, never direct damage or cargo credit.
public struct NPCIntent: Equatable, Codable, Sendable {
  public let actor: ActorIdentity
  public let action: NPCAction
}

public struct EncounterPlan: Equatable, Codable, Sendable {
  public let system: SystemIdentity
  public let visit: UInt64
  public let revision: UInt64
  public let batches: [SpawnBatch]
  public let intents: [NPCIntent]
}

public struct AttackOrigin: Equatable, Codable, Sendable {
  public let emissionID: UInt64
  public let owner: ActorIdentity
  public let ordnance: ActorIdentity?
  public let emittedAt: Double
  public let ownerLegalAtEmission: LegalRecord
  public var sourcePart: String?
}

public enum AttackKind: String, Codable, Sendable {
  case laser, missile, bomb, plasma, collision
}

public enum AttackOutcome: String, Codable, Sendable {
  case discharge, targetedLaunch, hit, destruction, componentDestruction, ordnanceInterception
}

public struct CombatIncident: Equatable, Codable, Sendable {
  public let id: UInt64
  public let physicalTime: Double
  public let origin: AttackOrigin
  public let victim: ActorIdentity?
  public let kind: AttackKind
  public let outcome: AttackOutcome
  public let position: Vector3
  public let victimLegalBeforeAttack: LegalRecord?
  public let firstAggressor: ActorIdentity?
  public let victimRole: NPCRole?
  public let victimIsStation: Bool
  public var laser: LaserKind?
  public var mount: LaserMount?
  public var victimPart: String?
}
