import Foundation
import Testing

@testable import EliteCore

struct OriginalHullPhysicalContractUnitTests {
  @Test func burroUsesExactAuthoredNativeMetresAndKeepsOriginalSpecificationsSeparate() throws {
    let contract = try OriginalHullPhysicalContract.burro.get()
    #expect(contract.id == "SH029" && contract.model.coordinateUnits == "metres")
    #expect((contract.envelope.dimensions - Vector3(20, 10.04, 34.09)).length < 1e-9)
    #expect(contract.nativeTriangles == 120)
    let mesh = contract.model.displayMesh
    #expect(mesh.vertices.allSatisfy { $0.length <= contract.envelope.clearanceRadius })
    #expect(contract.envelope.minimum == .init(-10, -4.36, -18.09))
    #expect(contract.envelope.maximum == .init(10, 5.68, 16))
    let ship = try #require(ShipCatalogue.ship("SH029"))
    let retained = ship.sourceProfilesIncludingOriginal
    let shown = ship.sourceProfilesIncludingPhysical
    #expect(Array(shown.dropLast()) == retained)
    let physical = try #require(shown.last)
    #expect(physical.group == "original-physical-metres")
    #expect(physical.fields.first { $0.key == "original.physical.width" }?.text == "20.00 m")
    #expect(physical.fields.first { $0.key == "original.physical.height" }?.text == "10.04 m")
    #expect(ship.originalDefinition?.runtimeReady == false)
    let preview = try #require(ship.physicalSourcePreview)
    #expect(abs((preview.vertices.map(\.length).max() ?? 0) - 100) < 1e-9)
    #expect(contract.model.displayMesh.vertices == mesh.vertices)
    #expect(contract.envelope.clearanceRadius < 25)
  }

  @Test func missingUnitsForeignIdentityAndChangedSourceCannotBecomePhysicalAuthority() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH029"))
    let model = try OriginalFleetShowroomModels.model(for: "SH029")
    func changed(
      id: String = "SH029", units: String? = "metres",
      sha: String? = nil, path: String? = nil
    ) -> OriginalFleetShowroomModel {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: sha ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(id: "SH030"), changed(units: nil), changed(units: "source units"),
      changed(sha: String(repeating: "0", count: 64)), changed(path: "other-hull.toml"),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let other = try #require(OriginalFleetDefinitionData.definition(for: "SH030"))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: other, model: model)
    }
    let untouched = try #require(ShipCatalogue.ship("SH030"))
    #expect(untouched.sourceProfilesIncludingPhysical == untouched.sourceProfilesIncludingOriginal)
    #expect(untouched.physicalSourcePreview == nil)
  }

  @Test func offCentreOriginRequiresLargerClearanceThanNormalisedOrCentredHalfExtents() throws {
    let vertices = [
      Vector3(10, -2, -3), .init(14, -2, -3), .init(10, 2, -3), .init(10, -2, 3),
    ]
    let envelope = try OriginalHullEnvelope(vertices: vertices)
    #expect(envelope.dimensions == .init(4, 4, 6))
    #expect(envelope.clearanceRadius == sqrt(209))
    #expect(envelope.clearanceRadius > (envelope.dimensions * 0.5).length)
    for invalid in [
      [], [.init(0, 0, 0)],
      [Vector3(.nan, 0, 0)] + vertices,
      [Vector3(Double.greatestFiniteMagnitude, 0, 0)] + vertices,
      [Vector3(0, 0, 0), .init(1, 0, 0), .init(2, 0, 0), .init(3, 0, 0)],
    ] {
      #expect(throws: (any Error).self) { try OriginalHullEnvelope(vertices: invalid) }
    }
  }
}
