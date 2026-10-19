extension ShipCatalogue {
  // Physical geometry stays in authored units; showroom meshes are normalized separately.
  private static let rawMeshesByID: [String: Mesh] = Dictionary(
    uniqueKeysWithValues: all.map { ($0.id, $0.design.rawMesh) })

  static func rawMesh(_ id: String) -> Mesh? { rawMeshesByID[id] }
}
