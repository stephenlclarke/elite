import Foundation
import TOMLDecoder

/// C08 retains its original package before any live showroom hull activation is applied.
/// This is the existing shipped source, not a second asset or a live catalogue fallback.
enum NativeInductionCrewLogHistoricalGeometry {
  private struct RetainedSource: Decodable {
    let id: String
    let design: ShipDesign
  }

  static let design: Result<ShipDesign, any Error> = Result {
    try decode(Data(contentsOf: ShipCatalogue.folder.appendingPathComponent("SH058.toml")))
  }

  static func decode(_ data: Data) throws -> ShipDesign {
    let retained = try TOMLDecoder().decode(RetainedSource.self, from: data)
    return try authenticate(retained.design, sourceID: retained.id)
  }

  static func authenticate(_ design: ShipDesign, sourceID: String) throws -> ShipDesign {
    guard sourceID == "SH058",
      ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
        == NativeInductionCrewLogSource.recorderGeometry
    else { throw SaveError.invalidCommander }
    return design
  }
}
