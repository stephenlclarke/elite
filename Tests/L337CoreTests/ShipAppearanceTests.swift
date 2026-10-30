import Foundation
import Testing

@testable import L337Core

@Test func sourceTextureMetadataRoundTripsWithoutInventingRenderedPixels() throws {
  let base = try #require(ShipCatalogue.ship("SH002"))
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(base.design)) as? [String: Any])
  // Archival metadata is a separate dialect from authored rendered texture assets.
  object.removeValue(forKey: "textures")
  object.removeValue(forKey: "faceTextures")
  object["sourceFaceColours"] = base.design.faces.map { _ in [1.0, 0, 0] }
  object["sourceTextures"] = [
    [
      "name": "hull.png", "source": "verified.dat sha256:fixture",
      "license": "Source texture rights not established",
    ]
  ]
  object["sourceFaceTextures"] = base.design.faces.enumerated().map { index, face in
    ["texture": index == 0 ? -1 : 0, "uv": index == 0 ? [] : face.map { _ in [0.5, 1.0] }]
      as [String: Any]
  }
  let source = try JSONDecoder().decode(
    ShipDesign.self, from: JSONSerialization.data(withJSONObject: object))
  #expect(source.valid && source.sourceTextures?.first?.name == "hull.png")
  #expect(source.rawMesh.faceMaterials == base.design.rawMesh.faceMaterials)
  let restored = try JSONDecoder().decode(ShipDesign.self, from: JSONEncoder().encode(source))
  #expect(restored == source)
  for mutation in [
    "count", "reference", "corners", "coordinate", "untextured", "provenance", "colour",
  ] {
    var invalid = object
    var mappings = invalid["sourceFaceTextures"] as! [[String: Any]]
    switch mutation {
    case "count": mappings.removeLast()
    case "reference": mappings[1]["texture"] = 5
    case "corners": mappings[1]["uv"] = [[0, 0]]
    case "coordinate": mappings[1]["uv"] = base.design.faces[1].map { _ in [0] }
    case "untextured": mappings[0]["uv"] = [[0, 0]]
    case "provenance":
      invalid["sourceTextures"] = [["name": "hull.png", "source": "", "license": "MIT"]]
    default: invalid["sourceFaceColours"] = [[1, 0, 0]]
    }
    invalid["sourceFaceTextures"] = mappings
    let decoded = try JSONDecoder().decode(
      ShipDesign.self, from: JSONSerialization.data(withJSONObject: invalid))
    #expect(!decoded.valid, "Must reject malformed source appearance: \(mutation)")
  }
}
