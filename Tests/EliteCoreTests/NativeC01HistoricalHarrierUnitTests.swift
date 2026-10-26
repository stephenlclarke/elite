import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

/// Pure historical-source components; no native recovery, permission or save migration is executed.
struct NativeC01HistoricalHarrierUnitTests {
  private func historical() throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent("SH056.toml")))
  }

  private func replacing(
    _ record: CatalogueShip, fields: [String: Any]
  ) throws -> CatalogueShip {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
    for (key, value) in fields { object[key] = value }
    return try JSONDecoder().decode(
      CatalogueShip.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func historicalHarrierKeepsCompleteDesignAppearanceAndCanonicalModelHash() throws {
    let record = try historical()
    let geometry = try NativeC01SurveyorGeometry.harrier.get()
    #expect(record.id == "SH056" && record.name == "Harrier" && record.model == "ROC-SH056")
    #expect(geometry.design.vertices == record.design.vertices)
    #expect(geometry.design.vertices.count == 1426 && geometry.design.faces.count == 1065)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(record.design)) as? [String: Any])
    object["source"] =
      record.design.source + "; C01 mission-only 65m fore-aft uniform calibration"
    let expected = try JSONDecoder().decode(
      ShipDesign.self, from: JSONSerialization.data(withJSONObject: object))
    // Full equality covers faces, provenance and every optional appearance/UV field.
    #expect(geometry.design == expected)
    #expect(geometry.design.rawMesh.materials == record.design.rawMesh.materials)
    #expect(geometry.design.rawMesh.faceMaterials == record.design.rawMesh.faceMaterials)
    #expect(geometry.design.rawMesh.faceTextures == record.design.rawMesh.faceTextures)
    let canonical = try ScriptPackLibrary.canonicalGeometry(expected)
    #expect(try ScriptPackLibrary.canonicalGeometry(geometry.design) == canonical)
    let models = try NativeC01Surveyor.models.get()
    let hashes = try NativeC01Surveyor.modelHashes.get()
    #expect(models["asset:c01-harrier-65m"] == expected)
    #expect(hashes["asset:c01-harrier-65m"] == ScriptPackLibrary.hash(canonical))
    #expect(models["asset:c01-recorder-8kg"] == NativeC01SurveyorGeometry.recorder)
  }

  @Test func calibratedBoundsAndClosedConvexCollisionContainEveryHistoricalPoint() throws {
    let record = try historical()
    let geometry = try NativeC01SurveyorGeometry.harrier.get()
    let visual = geometry.design.rawMesh
    let bounds = try OriginalHullEnvelope(vertices: visual.vertices)
    #expect(bounds.minimum == .init(-21.02621, -7.79609, -32.5))
    #expect(bounds.maximum == .init(21.02621, 7.79609, 32.5))
    #expect(abs(bounds.dimensions.z - 65) < 1e-9)
    let scale =
      65 / (try OriginalHullEnvelope(vertices: record.design.rawMesh.vertices)).dimensions.z
    #expect(visual.vertices == record.design.rawMesh.vertices.map { $0 * scale })
    #expect(geometry.collision.vertices.allSatisfy(visual.vertices.contains))
    #expect(geometry.collision.faces.allSatisfy { $0.count == 3 })
    #expect(try PreparedHull(mesh: geometry.collision).isClosed)
    #expect(try OriginalHullEnvelope(vertices: geometry.collision.vertices) == bounds)
    for face in geometry.collision.faces {
      let x = geometry.collision.vertices[face[0]]
      let normal = (geometry.collision.vertices[face[1]] - x)
        .cross(geometry.collision.vertices[face[2]] - x)
      #expect(normal.length > 1e-8)
      #expect(visual.vertices.allSatisfy { normal.dot($0 - x) <= 4e-8 * normal.length })
    }
    let rebuilt = try NativeC01SurveyorGeometry.historicalHarrier(record)
    #expect(rebuilt.collision.vertices == geometry.collision.vertices)
    #expect(rebuilt.collision.faces == geometry.collision.faces)
  }

  @Test func aplomadoGeometryCannotReplaceHistoricalSourceOrAuthenticateAsC01Harrier() throws {
    let record = try historical()
    let before = try NativeC01SurveyorGeometry.harrier.get()
    let original = try #require(OriginalFleetDefinitionData.definition(for: "SH056"))
    let aplomado = try OriginalFleetShowroomModels.model(for: "SH056").nativeDesign
    #expect(original.name == "Aplomado" && aplomado.valid)
    #expect(aplomado != record.design && aplomado.vertices != before.design.vertices)
    let designObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(aplomado))
    let replacement = try replacing(
      record, fields: ["name": original.name, "model": "L337-SH056", "design": designObject])
    #expect(throws: (any Error).self) {
      try NativeC01SurveyorGeometry.historicalHarrier(replacement)
    }
    let mission = UUID()
    let profile = NativeC01Surveyor.profile(recorder: false)
    let hashes = try NativeC01Surveyor.modelHashes.get()
    var body = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 0), hostile: false)
    body.missionInstanceID = mission
    body.missionActorID = NativeC01Surveyor.actor(
      mission: mission, alias: NativeC01Surveyor.aliases[0])
    body.scriptNPC = .init(
      fit: .init(definition: profile, models: [profile.model: try #require(hashes[profile.model])]),
      fuel: 0, guns: [:], components: [:])
    #expect(NativeC01Surveyor.passiveFit(body))
    let foreignHash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(aplomado))
    body.scriptNPC = .init(
      fit: .init(definition: profile, models: [profile.model: foreignHash]),
      fuel: 0, guns: [:], components: [:])
    #expect(!NativeC01Surveyor.passiveFit(body))
    let after = try NativeC01SurveyorGeometry.harrier.get()
    #expect(after.design == before.design && after.collision.vertices == before.collision.vertices)
    #expect(after.collision.faces == before.collision.faces)
  }

  @Test func foreignAndMalformedHistoricalRecordsCannotSupplyGeometry() throws {
    let record = try historical()
    let identities: [[String: Any]] = [
      ["id": "SH026"], ["name": "Aplomado"], ["model": "L337-SH056"],
    ]
    for fields in identities {
      let changed = try replacing(record, fields: fields)
      #expect(throws: (any Error).self) {
        try NativeC01SurveyorGeometry.historicalHarrier(changed)
      }
    }
    var design = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(record.design)) as? [String: Any])
    for (field, value) in [
      ("vertices", [[0.0, 0.0, 0.0]] as Any),
      ("faces", [[-1, 0, 1], [0, 1, 2], [0, 1, 2], [0, 1, 2]] as Any),
      ("faceMaterials", [-1] as Any),
    ] {
      let saved = design[field]
      design[field] = value
      let changed = try replacing(record, fields: ["design": design])
      #expect(!changed.design.valid)
      #expect(throws: (any Error).self) {
        try NativeC01SurveyorGeometry.historicalHarrier(changed)
      }
      design[field] = saved
    }
    #expect(try NativeC01SurveyorGeometry.historicalHarrier(record).design.valid)
  }
}
