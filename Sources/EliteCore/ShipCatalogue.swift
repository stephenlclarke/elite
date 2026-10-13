import Foundation

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
  public var searchText: String {
    [id, name, shipClass, appearances, evidence].joined(separator: " ")
  }
  public var previewMesh: Mesh? { model.flatMap { ShipCatalogue.meshes[$0] } }
  public var availability: String {
    id == "SH023"
      ? "Current player hull: native Cobra Mk III"
      : "Research catalogue; not available as a player hull"
  }
}
public enum ShipCatalogue {
  private struct Snapshot: Decodable { let records: [CatalogueShip] }
  public static let all: [CatalogueShip] =
    decode(Snapshot.self, name: "ShipCatalogue")?.records ?? []
  static let meshes: [String: Mesh] = Dictionary(
    uniqueKeysWithValues: (decode([SourceMesh].self, name: "ShowroomModels") ?? []).map {
      ($0.id, $0.mesh)
    })
  public static func ship(_ id: String) -> CatalogueShip? { all.first { $0.id == id } }
  public static var modelCount: Int { all.filter { $0.previewMesh != nil }.count }
  // Prefer packaged app resources explicitly, including older SwiftPM accessor layouts.
  private static let resources: Bundle =
    Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("Elite_EliteCore.bundle"))
    } ?? Bundle.module
  private static func decode<T: Decodable>(_ type: T.Type, name: String) -> T? {
    guard let url = resources.url(forResource: name, withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
  private struct SourceMesh: Decodable {
    let id: String
    let vertices: [[Double]]
    let faces: [[Int]]
    var mesh: Mesh {
      let points = vertices.map { Vector3($0[0], $0[1], $0[2]) }
      return Mesh(vertices: points, faces: faces, preserveWinding: true).showroomNormalised
    }
  }
}
public struct ShipComparisonRow: Sendable {
  public let label: String
  public let baseline: String
  public let selected: String
  public let difference: String
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
