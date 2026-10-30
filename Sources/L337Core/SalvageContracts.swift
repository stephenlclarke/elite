import Foundation

/// Site and lineage persist when a derelict leaves and re-enters the local scene.
public struct WreckIdentity: Hashable, Codable, Sendable {
  public let system: SystemIdentity
  public let site: UInt32
  public let lineage: UInt64
}

public struct WreckSectionIdentity: Hashable, Codable, Sendable {
  public let wreck: WreckIdentity
  public let section: UInt16
}

public struct SalvageLotIdentity: Hashable, Codable, Sendable {
  public let section: WreckSectionIdentity
  public let lot: UInt16
}

public enum SalvageOwnership: String, Codable, Sendable {
  case abandoned, claimed, occupied, missionProtected
}

public enum SalvageTargetCategory: String, Codable, Sendable {
  case wreck, section, rock, cargo, technology, module, disabledDrone, emptyPod, occupiedPod
}

/// Bounds and work surfaces are model-local, in native simulation units.
public struct SalvageBounds: Equatable, Codable, Sendable {
  public let center: Vector3
  public let radius: Double
}

public struct SalvageWorkSurface: Equatable, Codable, Sendable {
  public let section: WreckSectionIdentity
  public let position: Vector3
  public let normal: Vector3
  public let radius: Double
}

public struct SalvageTargetMetadata: Equatable, Codable, Sendable {
  public let category: SalvageTargetCategory
  public let ownership: SalvageOwnership
  public let claimant: ActorIdentity?
  public let wreck: WreckIdentity?
  public let section: WreckSectionIdentity?
  public let lot: SalvageLotIdentity?
  public let bounds: SalvageBounds
  public let workSurfaces: [SalvageWorkSurface]
}
