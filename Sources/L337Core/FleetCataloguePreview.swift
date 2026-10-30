import Foundation

enum FleetCataloguePreview: Sendable, Equatable {
  case silhouette, recordedWireframe, shaded

  /// Viewing source specifications never creates a discovery or a purchase entitlement.
  static func mode(
    ship: CatalogueShip, owner: UUID?, ownedShip: String, discovery: NativeFleetDiscovery?
  ) -> Self {
    guard ship.originalDefinition != nil, ship.catalogue.discoveryEligible else { return .shaded }
    if ship.id == ownedShip { return .shaded }
    guard let owner, let discovery, discovery.owner == owner,
      let entry = discovery.entries[ship.id], entry.encounter.owner == owner, entry.valid
    else { return .silhouette }
    return .recordedWireframe
  }

  var caption: String? {
    switch self {
    case .silhouette: "Unknown silhouette"
    case .recordedWireframe: "Recorded wireframe"
    case .shaded: nil
    }
  }

  /// Union the visible source panels in one flat colour. No materials, textures, internal
  /// edges or detail lines reveal an unencountered hull's surface.
  static func drawSilhouette(
    _ mesh: Mesh, body: SpaceBody, projection: FlightProjection, into frame: inout Frame
  ) {
    let vertices = mesh.vertices.map { body.modelVector($0) + body.position }
    guard vertices.allSatisfy(\.finite) else { return }
    for face in mesh.faces {
      let a = vertices[face[0]]
      let b = vertices[face[1]]
      let c = vertices[face[2]]
      guard (b - a).cross(c - a).dot(a) < 0 else { continue }
      frame.panel(
        ShipProjection.polygon(face.map { vertices[$0] }, projection: projection),
        colour: Ink.white.rawValue)
    }
  }
}
