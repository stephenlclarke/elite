import Foundation

/// Authoritative native mechanics, calibrated once from the retained common source refit.
public struct ShipPerformance: Codable, Sendable, Equatable {
  public let cargo: Int
  public let speed: Double
  public let acceleration: Double
  public var energy: Double
  public let recharge: Double
  public let roll: Double
  public let pitch: Double
  public let yaw: Double
  public let shield: Double
  public let shieldRecharge: Double
  public let fuel: Int
  public let jump: Double
  public var spool: Double
  public let missiles: Int
  public let facings: Int
  public let cargoExpansion: Int
  /// Credits, unlike Commander.credits which stores tenths of a credit.
  public let price: Int
  /// Optional on historical TOMLs: absent work-tool support is fail-closed.
  public var workTools: Set<ComponentUtility>?
  public var valid: Bool {
    [speed, acceleration, energy, recharge, roll, pitch, yaw, shield, shieldRecharge, jump, spool]
      .allSatisfy { $0.isFinite && $0 > 0 && $0 <= 100000 }
      && (0...100000).contains(cargo) && (1...10000).contains(fuel)
      && (1...32).contains(missiles) && (1...15).contains(facings)
      && (0...100000).contains(cargoExpansion) && (1...100_000_000).contains(price)
      && (workTools?.isSubset(of: [.miningLaser, .salvageCutter]) ?? true)
  }
  public func supports(_ mount: LaserMount) -> Bool {
    let bit: Int
    switch mount {
    case .front: bit = 1
    case .rear: bit = 2
    case .left: bit = 4
    case .right: bit = 8
    }
    return facings & bit != 0
  }
}
extension Commander {
  public var ship: CatalogueShip { ShipCatalogue.ship(shipID)! }
  public var nativePerformance: ShipPerformance { ship.game! }
  public var performance: ShipPerformance {
    var result = nativePerformance
    if let ratio = fittedComponent(at: .energy)?.statistics[.energyCapacity] {
      result.energy *= ratio
    }
    if let policy = hyperspaceDrivePolicy, case .timed(let seconds) = policy.activation {
      result.spool = seconds
    }
    return result
  }
  public var missileCapacity: Int { performance.missiles }
  public var standardCargoCapacity: Int {
    performance.cargo + (equipment.contains("Large Cargo Bay") ? performance.cargoExpansion : 0)
  }
  public var playerMesh: Mesh {
    let source = ship.previewMesh!
    return Mesh(
      vertices: source.vertices.map { $0 * 0.69 }, faces: source.faces, details: source.details,
      materials: source.materials, faceMaterials: source.faceMaterials,
      faceTextures: source.faceTextures, preserveWinding: true)
  }
}
