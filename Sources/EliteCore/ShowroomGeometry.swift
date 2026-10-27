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
      details: details, materials: materials, faceMaterials: faceMaterials,
      faceTextures: faceTextures, preserveWinding: true)
  }
}

public enum ShowroomViewAxis: String, Sendable, CaseIterable {
  case pitch = "Pitch"
  case roll = "Roll"
  case yaw = "Yaw"
  var next: Self { Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % Self.allCases.count] }
}

/// Display scale consumes existing physical contracts; it never calibrates or activates a hull.
struct ShowroomPreviewScale {
  let factor: Double
  let caption: String

  private static let calibratedRadii: [String: Double] = {
    var result: [String: Double] = [:]
    for ship in ShipCatalogue.all {
      if let contract = ship.physicalSourceContract {
        result[ship.id] = contract.physicalMesh.showroomRadius
      } else if ship.id == "SH025", ship.geometryContext.hasPrefix("F01-SH025-CALIBRATION-v1:"),
        ship.nativeDesign != nil
      {
        result[ship.id] = ship.design.rawMesh.showroomRadius
      }
    }
    return result
  }()
  init(ship: CatalogueShip, comparedWith other: CatalogueShip?, physicalSource: Bool) {
    func radiusFor(_ candidate: CatalogueShip) -> Double? {
      if physicalSource && candidate.physicalSourceContract == nil { return nil }
      return Self.calibratedRadii[candidate.id]
    }
    guard let radius = radiusFor(ship) else {
      factor = 1
      caption = "Uncalibrated scale"
      return
    }
    guard let other else {
      factor = 1
      caption = "Calibrated metres"
      return
    }
    guard let otherRadius = radiusFor(other) else {
      factor = 1
      caption = "Scale not comparable"
      return
    }
    factor = radius / max(radius, otherRadius)
    caption = "Shared metre scale"
  }
}

extension Mesh {
  var showroomRadius: Double {
    let minimum = Vector3(
      vertices.map(\.x).min()!, vertices.map(\.y).min()!, vertices.map(\.z).min()!)
    let maximum = Vector3(
      vertices.map(\.x).max()!, vertices.map(\.y).max()!, vertices.map(\.z).max()!)
    let center = (minimum + maximum) * 0.5
    return vertices.map { ($0 - center).length }.max()!
  }
}
