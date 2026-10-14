import Foundation

extension Mesh {
  /// Both previews use a unit radius; the displayed source dimensions carry physical scale.
  var showroomNormalised: Mesh {
    let minimum = Vector3(
      vertices.map(\.x).min()!, vertices.map(\.y).min()!, vertices.map(\.z).min()!)
    let maximum = Vector3(
      vertices.map(\.x).max()!, vertices.map(\.y).max()!, vertices.map(\.z).max()!)
    let center = (minimum + maximum) * 0.5
    let radius = vertices.map { ($0 - center).length }.max()!
    return Mesh(
      vertices: vertices.map { ($0 - center) * (100 / radius) }, faces: faces,
      details: details, materials: materials, faceMaterials: faceMaterials, preserveWinding: true)
  }
}
