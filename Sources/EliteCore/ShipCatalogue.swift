import Foundation
import TOMLDecoder

public struct ShipSpec: Codable, Sendable, Equatable {
  public let key: String
  public let label: String
  public let text: String
  public let number: Double?
  public let unit: String
  public let status: String
  public let basis: String
}
public struct ShipProfile: Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let group: String
  public let context: String
  public let fields: [ShipSpec]
}
public struct CatalogueShip: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let name: String
  public let shipClass: String
  public let appearances: String
  public let evidence: String
  public let refit: Bool
  public let model: String?
  public let modelSource: String?
  public let dimensions: [Double]?
  public let geometryContext: String
  public let profiles: [ShipProfile]
  public let game: ShipPerformance?
  public let design: ShipDesign
  public let nativeHull: Hull?
  public let nativeDesign: ShipDesign?
  public let nativeCombat: NativeCombat?
  public var searchText: String {
    [id, name, shipClass, appearances, evidence].joined(separator: " ")
  }
  public var previewMesh: Mesh? { ShipCatalogue.meshes[id] }
  public var availability: String {
    game == nil ? "Display object; not a flyable ship" : "Available for exchange at a main station"
  }
}
public struct ShipDesign: Codable, Sendable, Equatable {
  public let vertices: [[Double]]
  public let faces: [[Int]]
  public let license: String
  public let source: String
  public let details: [MeshDetail]?
  var valid: Bool {
    guard vertices.count >= 4, faces.count >= 4,
      vertices.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
      vertices.contains(where: { $0.contains(where: { $0 != 0 }) })
    else { return false }
    let indicesValid = faces.allSatisfy {
      $0.count >= 3 && $0.allSatisfy { vertices.indices.contains($0) }
    }
    guard indicesValid,
      (details ?? []).allSatisfy({
        vertices.indices.contains($0.start) && vertices.indices.contains($0.end)
          && faces.indices.contains($0.face)
      })
    else { return false }
    return faces.filter { face in
      let p = face.prefix(3).map { Vector3(vertices[$0][0], vertices[$0][1], vertices[$0][2]) }
      return (p[1] - p[0]).cross(p[2] - p[0]).length > 0.000001
    }.count >= 4
  }

  var rawMesh: Mesh {
    Mesh(
      vertices: vertices.map { Vector3($0[0], $0[1], $0[2]) }, faces: faces,
      details: details ?? [], preserveWinding: true)
  }
  var mesh: Mesh { rawMesh.showroomNormalised }
}
public enum ShipFileError: Error {
  case missingFolder
  case invalid(String)
  case duplicate(String)
}
public enum ShipCatalogue {
  public static let all: [CatalogueShip] = {
    do { return try load(from: folder) } catch {
      preconditionFailure("Invalid packaged ship definitions: \(error)")
    }
  }()
  static let meshes = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.design.mesh) })
  private static let nativeRecords = Dictionary(
    uniqueKeysWithValues: all.compactMap { ship in ship.nativeHull.map { ($0, ship) } })
  private static let nativeMeshes: [Hull: Mesh] = nativeRecords.mapValues { ship in
    if let design = ship.nativeDesign { return design.rawMesh }
    let mesh = ship.design.mesh
    return Mesh(
      vertices: mesh.vertices.map { $0 * 0.69 }, faces: mesh.faces, details: mesh.details,
      preserveWinding: true)
  }
  public static func nativeShip(_ hull: Hull) -> CatalogueShip? { nativeRecords[hull] }
  static func nativeMesh(_ hull: Hull) -> Mesh? { nativeMeshes[hull] }
  private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
  public static func ship(_ id: String) -> CatalogueShip? { byID[id] }
  public static var modelCount: Int { all.count }
  private static let resources: Bundle =
    Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("Elite_EliteCore.bundle"))
    } ?? Bundle.module
  public static var folder: URL { resources.resourceURL!.appendingPathComponent("Ships") }
  public static func load(from directory: URL) throws -> [CatalogueShip] {
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "toml" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard !files.isEmpty else { throw ShipFileError.missingFolder }
    var ids = Set<String>()
    var nativeKinds = Set<Hull>()
    return try files.map { url in
      let ship = try TOMLDecoder().decode(CatalogueShip.self, from: Data(contentsOf: url))
      guard ship.id == url.deletingPathExtension().lastPathComponent,
        ship.id.range(of: "^SH[0-9]{3}$", options: .regularExpression) != nil,
        !ship.name.isEmpty, ship.design.valid, ship.game?.valid ?? true,
        ship.nativeDesign?.valid ?? true, ship.nativeCombat?.valid ?? true
      else { throw ShipFileError.invalid(url.lastPathComponent) }
      if let hull = ship.nativeHull, !nativeKinds.insert(hull).inserted {
        throw ShipFileError.invalid("Duplicate native hull: " + hull.rawValue)
      }
      guard ids.insert(ship.id).inserted else { throw ShipFileError.duplicate(ship.id) }
      return ship
    }
  }
}
public struct ShipComparisonRow: Sendable {
  public let label: String
  public let baseline: String
  public let selected: String
  public let difference: String
  public var rating: ComparisonRating = .unavailable
  public static func difference(_ left: ShipSpec?, _ right: ShipSpec?, comparable: Bool) -> String {
    guard comparable, let left, let right, left.unit == right.unit,
      let a = left.number, let b = right.number
    else { return "" }
    let delta = b - a
    let estimate = [left.status, right.status].contains {
      $0.localizedCaseInsensitiveContains("estimated")
    }
    return String(format: "Diff %+.3g", delta) + (left.unit.isEmpty ? "" : " " + left.unit)
      + (estimate ? " (estimated)" : "")
  }
}
