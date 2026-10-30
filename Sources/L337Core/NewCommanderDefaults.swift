import Foundation

/// Approved current fresh-start values. Restoring a save preserves its stored identity.
public enum NewCommanderDefaults {
  public static let name = "Rowan Calder"
  public static let title = "L337"
  public static let galaxy = 0
  public static let system = 7
  public static let shipID = Universe.originalWorlds.authoring.startingShipID
  public static let credits: Int = {
    let tenths = Universe.originalWorlds.authoring.startingCreditsCR * 10
    precondition(tenths.isFinite && tenths >= 0 && tenths <= 4_294_967_295)
    precondition(tenths.rounded() == tenths)
    return Int(tenths)
  }()
  public static let fuel: Int = {
    guard let performance = ShipCatalogue.ship(shipID)?.game else {
      preconditionFailure("The approved starting ship is unavailable")
    }
    let fraction = Universe.originalWorlds.authoring.startingFuelFraction
    precondition(fraction == 1)
    return performance.fuel
  }()
}

/// Display framing only; SH123 gains no native physics, ownership or purchase authority.
enum L337Branding {
  static let shipID = "SH123"
  static let titleMesh = mesh(radius: 65)
  static let iconMesh = mesh(radius: 115)
  private static let normalized: Mesh = {
    do {
      return try OriginalFleetShowroomModels.model(for: shipID).displayMesh.showroomNormalised
    } catch {
      preconditionFailure("The approved L337 branding model is unavailable: \(error)")
    }
  }()

  private static func mesh(radius: Double) -> Mesh {
    let source = normalized
    return Mesh(
      vertices: source.vertices.map { $0 * (radius / 100) }, faces: source.faces,
      details: source.details, materials: source.materials, faceMaterials: source.faceMaterials,
      faceTextures: source.faceTextures, preserveWinding: true)
  }
}
