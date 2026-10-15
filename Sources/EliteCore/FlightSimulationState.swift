import Foundation

/// Persisted identities and physical time are independent of presentation time.
public struct FlightSimulationState: Equatable, Codable, Sendable {
  public var physicalTime = 0.0
  public private(set) var visit: UInt64 = 0
  public private(set) var nextActor: UInt64 = 2
  public private(set) var nextEmission: UInt64 = 1
  public private(set) var nextIncident: UInt64 = 1
  public private(set) var nextSpawn: UInt64 = 1
  public private(set) var system: SystemIdentity?
  public var pose = ShipPose()
  public private(set) var anchors: SystemAnchors?

  public var valid: Bool {
    physicalTime.isFinite && physicalTime >= 0 && visit < UInt64.max
      && nextActor >= 2 && nextActor < UInt64.max
      && nextEmission > 0 && nextEmission < UInt64.max
      && nextIncident > 0 && nextIncident < UInt64.max
      && nextSpawn > 0 && nextSpawn < UInt64.max
      && (system.map { (0..<8).contains($0.galaxy) && (0...256).contains($0.system) } ?? true)
  }

  public var player: ActorIdentity? {
    system.map { .init(system: $0, visit: visit, entity: 0) }
  }

  /// Canonical system anchors stay fixed across launches, arrivals and revisits.
  public mutating func enter(_ system: SystemIdentity, arriving: Bool) {
    guard visit < UInt64.max else { return }
    visit += 1
    self.system = system
    pose = ShipPose(position: .init(0, 0, arriving ? -16000 : 500))
    anchors = .init(
      system: system,
      station: .init(
        identity: .init(system: system, visit: visit, entity: 1),
        position: .init(0, 0, 0), orientation: Basis3(),
        exitPosition: .init(0, 0, -500), exitDirection: .init(0, 0, -1)),
      arrival: .init(0, 0, -16000),
      planet: .init(position: .init(2600, -700, 7500), radius: 1500),
      sun: .init(position: .init(-5000, 1500, 12500), radius: 1100))
  }

  public mutating func allocateActor() -> ActorIdentity? {
    guard let system, nextActor < UInt64.max else { return nil }
    defer { nextActor += 1 }
    return .init(system: system, visit: visit, entity: nextActor)
  }

  public mutating func allocateEmission() -> UInt64? {
    guard nextEmission < UInt64.max else { return nil }
    defer { nextEmission += 1 }
    return nextEmission
  }

  public mutating func allocateIncident() -> UInt64? {
    guard nextIncident < UInt64.max else { return nil }
    defer { nextIncident += 1 }
    return nextIncident
  }

  public mutating func allocateSpawn() -> UInt64? {
    guard nextSpawn < UInt64.max else { return nil }
    defer { nextSpawn += 1 }
    return nextSpawn
  }

  public mutating func advancePhysicalTime(_ delta: Double) {
    guard delta.isFinite, delta > 0, (physicalTime + delta).isFinite else { return }
    physicalTime += delta
  }
}

extension ShipPose {
  /// Existing scene motion is R * relativePoint - translation. Preserve its
  /// inverse transform so fixed system anchors project into precisely that frame.
  mutating func advanceView(pitch: Double, roll: Double, yaw: Double, translation: Vector3) {
    var inverse = orientation.transposed
    inverse.rotate(pitch: pitch, roll: roll, yaw: yaw)
    orientation = inverse.transposed
    position = position + orientation.apply(translation)
  }
}

extension Basis3 {
  var transposed: Basis3 {
    var result = Basis3()
    result.x = .init(x.x, y.x, z.x)
    result.y = .init(x.y, y.y, z.y)
    result.z = .init(x.z, y.z, z.z)
    return result
  }
}

/// Optional on legacy bodies. All ownership is assigned before their first action.
public struct PhysicalActorState: Equatable, Codable, Sendable {
  public let identity: ActorIdentity
  public var population: PopulationClass
  public var npc: NPCState?
  public var velocity = Vector3(0, 0, 0)
  public var laserCooldown = 0.0
  public var rock: RockIdentity?
  public var payload: PayloadIdentity?
  public var attackOrigin: AttackOrigin?
  public var emissionPosition: Vector3?
  public var deathOrigin: AttackOrigin?
  public var spawnIdentity: SpawnIdentity?
  public var blocksNavalEncounter = false
  public var catalogueShipID: String?
  public var angularVelocity = Vector3(0, 0, 0)
  public var salvage: SalvageTargetMetadata?
}
