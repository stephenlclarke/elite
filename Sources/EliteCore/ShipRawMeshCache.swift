extension ShipCatalogue {
  // Physical geometry stays in authored units; showroom meshes are normalized separately.
  private static let rawMeshesByID: [String: Mesh] = Dictionary(
    uniqueKeysWithValues: all.map { ship in
      if ship.id == "SH061", let physical = try? OriginalHullPhysicalContract.haflinger.get() {
        return (ship.id, physical.physicalMesh)
      }
      // Reuse the authored geometry already retained by ordinary salvage profiles.
      if let profile = SalvageCatalogue.profile(catalogueShipID: ship.id) {
        return (ship.id, profile.mesh)
      }
      return (ship.id, ship.design.rawMesh)
    })

  static func rawMesh(_ id: String) -> Mesh? { rawMeshesByID[id] }
}
