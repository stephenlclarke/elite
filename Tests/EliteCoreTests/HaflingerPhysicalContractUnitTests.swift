import Foundation
import Testing

@testable import EliteCore

struct HaflingerPhysicalContractUnitTests {
  @Test func explicitTwentyMetreCalibrationPreservesEveryOriginalCoordinateAndPhysicalFeature()
    throws
  {
    let contract = try OriginalHullPhysicalContract.haflinger.get()
    let source = try OriginalFleetShowroomModels.model(for: "SH061")
    #expect(contract.id == "SH061" && contract.name == "Haflinger")
    #expect(contract.metresPerSourceUnit == 20 && source.coordinateUnits == nil)
    #expect(contract.unitBasis.contains("Explicit project calibration"))
    #expect((contract.envelope.dimensions - Vector3(41.536, 35.7, 80)).length < 1e-9)
    #expect(contract.physicalMesh.vertices.count == source.displayMesh.vertices.count)
    for (physical, raw) in zip(contract.physicalMesh.vertices, source.displayMesh.vertices) {
      #expect((physical - raw * 20).length < 1e-12)
      #expect(physical.length <= contract.envelope.clearanceRadius)
    }
    #expect(contract.physicalMesh.faces == source.displayMesh.faces)
    #expect(contract.physicalMesh.details == source.displayMesh.details)
    #expect(contract.physicalMesh.materials == source.displayMesh.materials)
    #expect(contract.physicalMesh.faceMaterials == source.displayMesh.faceMaterials)
    #expect(contract.physicalMesh.faceTextures == source.displayMesh.faceTextures)
    #expect(contract.model.displayMesh.vertices == source.displayMesh.vertices)
    let radius = try #require(source.displayMesh.vertices.map(\.length).max()) * 20
    #expect(abs(contract.envelope.clearanceRadius - radius) < 1e-12)
  }

  @Test func calibrationRejectsForeignOrChangedSourceAndNeverConvertsAnUnapprovedHull() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH061"))
    let model = try OriginalFleetShowroomModels.model(for: "SH061")
    func changed(
      id: String = "SH061", units: String? = nil, path: String? = nil, hash: String? = nil
    ) -> OriginalFleetShowroomModel {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: hash ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(id: "SH062"), changed(units: "metres"), changed(units: "showroom"),
      changed(path: "other-model.toml"), changed(hash: String(repeating: "0", count: 64)),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let other = try #require(OriginalFleetDefinitionData.definition(for: "SH062"))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: other, model: model)
    }
    let untouched = try #require(ShipCatalogue.ship("SH062"))
    #expect(untouched.physicalSourceContract == nil)
  }

  @Test func physicalSourcePresentationLabelsCalibrationAndKeepsPerformanceAndActivationSeparate()
    throws
  {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH061"))
    let contract = try OriginalHullPhysicalContract.haflinger.get()
    let ship = try #require(ShipCatalogue.ship("SH061"))
    let profiles = ship.sourceProfilesIncludingPhysical
    #expect(Array(profiles.dropLast()) == ship.sourceProfilesIncludingOriginal)
    let physical = try #require(profiles.last)
    #expect(physical.title == "Physical source: Haflinger")
    #expect(physical.context.contains("20 metres per SH061 source unit"))
    let length = try #require(physical.fields.first { $0.key == "original.physical.length" })
    #expect(length.text == "80.00 m" && length.status == "calibration")
    #expect(definition.runtimeReady == true && definition.nativePerformance?.cargo == 78)
    #expect(definition.nativePerformance?.fuel == 130 && definition.nativePerformance?.jump == 9)
    #expect(ship.originalDefinition?.sourceSHA256 == definition.sourceSHA256)
    let preview = try #require(ship.physicalSourcePreview)
    #expect(abs((preview.vertices.map(\.length).max() ?? 0) - 100) < 1e-9)
    #expect(contract.envelope.clearanceRadius != 100)
    #expect(contract.physicalMesh.vertices != preview.vertices)
    let burro = try OriginalHullPhysicalContract.burro.get()
    #expect(burro.metresPerSourceUnit == 1 && burro.model.coordinateUnits == "metres")
    #expect(burro.physicalMesh.vertices == burro.model.displayMesh.vertices)
  }
}
