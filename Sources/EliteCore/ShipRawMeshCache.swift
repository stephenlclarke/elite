extension ShipCatalogue {
  // Physical geometry stays in authored units; showroom meshes are normalized separately.
  private static let rawMeshesByID: [String: Mesh] = Dictionary(
    uniqueKeysWithValues: all.map { ship in
      if ship.id == "SH061", let physical = try? OriginalHullPhysicalContract.haflinger.get() {
        return (ship.id, physical.physicalMesh)
      }
      return (ship.id, ship.design.rawMesh)
    })

  static func rawMesh(_ id: String) -> Mesh? { rawMeshesByID[id] }
}
