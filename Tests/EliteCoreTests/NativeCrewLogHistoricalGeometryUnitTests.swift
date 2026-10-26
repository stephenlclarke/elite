import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct NativeCrewLogHistoricalGeometryUnitTests {
  private func retainedBytes() throws -> Data {
    try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent("SH058.toml"))
  }

  @Test func retainedResourceKeepsExactAuthenticatedGeometryAppearanceAndRecorderRadius() throws {
    let bytes = try retainedBytes()
    let historical = try NativeInductionCrewLogHistoricalGeometry.decode(bytes)
    // This is the same ShipDesign decoding performed before live activation in ShipCatalogue.load.
    let original = try TOMLDecoder().decode(CatalogueShip.self, from: bytes)
    #expect(original.id == "SH058" && original.name == "Hauler")
    #expect(historical == original.design)
    #expect(try NativeInductionCrewLogHistoricalGeometry.design.get() == historical)
    #expect(
      try ScriptPackLibrary.hash(ScriptPackLibrary.canonicalGeometry(historical))
        == "5362f0948c8a6f1b2acc770b100f746ff3f55799db7c0c53261f02943c6a680e")
    #expect(historical.vertices.count == 2352 && historical.faces.count == 1598)
    #expect(historical.materials?.count == 6 && historical.faceMaterials?.count == 1598)
    let mesh = historical.rawMesh
    let radius = try #require(mesh.vertices.map { ($0 * 0.2).length }.max())
    #expect(abs(radius - 6.322963883093118) < 0.000000001 && radius <= 16)
    #expect(abs(try NativeInductionCrewLogSource.recorderRadius.get() - radius) < 0.000000001)
    #expect(mesh.faces == original.design.rawMesh.faces)
    #expect(mesh.materials == original.design.rawMesh.materials)
    #expect(mesh.faceMaterials == original.design.rawMesh.faceMaterials)
    #expect(mesh.faceTextures == original.design.rawMesh.faceTextures)
  }

  @Test func changedGeometryMaterialProvenanceOrSourceIdentityCannotPassTheOriginalPin() throws {
    let historical = try NativeInductionCrewLogHistoricalGeometry.design.get()
    for field in ["vertices", "faceMaterials", "source", "license"] {
      var value = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(historical)) as? [String: Any])
      switch field {
      case "vertices":
        var vertices = try #require(value[field] as? [[Double]])
        vertices[0][0] += 0.01
        value[field] = vertices
      case "faceMaterials":
        var assignments = try #require(value[field] as? [Int])
        assignments[0] = (assignments[0] + 1) % 6
        value[field] = assignments
      default: value[field] = (try #require(value[field] as? String)) + " changed"
      }
      let changed = try JSONDecoder().decode(
        ShipDesign.self, from: JSONSerialization.data(withJSONObject: value))
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogHistoricalGeometry.authenticate(changed, sourceID: "SH058")
      }
    }
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogHistoricalGeometry.authenticate(historical, sourceID: "SH059")
    }
    let text = try #require(String(data: retainedBytes(), encoding: .utf8))
    let foreign = text.replacingOccurrences(of: "id = \"SH058\"", with: "id = \"SH059\"")
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogHistoricalGeometry.decode(Data(foreign.utf8))
    }
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogHistoricalGeometry.decode(Data("id = \"SH058\"".utf8))
    }
  }

  @Test func currentBrabantDesignCannotReplaceTheHistoricalRecorderOrGrantHullAccess() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH058"))
    let brabant = try OriginalFleetShowroomModels.model(for: "SH058").nativeDesign
    #expect(definition.name == "Brabant" && definition.purchasePolicy == "blueprintFabrication")
    let historical = try NativeInductionCrewLogHistoricalGeometry.design.get()
    #expect(brabant != historical)
    #expect(
      try ScriptPackLibrary.hash(ScriptPackLibrary.canonicalGeometry(brabant))
        != NativeInductionCrewLogSource.recorderGeometry)
    // A future live design can keep the same stable ship ID and still is not the old mission unit.
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogHistoricalGeometry.authenticate(brabant, sourceID: definition.id)
    }
    #expect(try NativeInductionCrewLogHistoricalGeometry.decode(retainedBytes()) == historical)
    #expect(!definition.runtimeReady)
  }

  @Test func originalSourceFitsAndCustodyRemainExactWithoutAdvancingTheParent() throws {
    let f = try CrewLogProducerFixture()
    let parent = f.parent
    let permission = parent.permission
    let manifest = NativeInductionCrewLogManifest(permission: permission)
    let source = try NativeInductionCrewLogSource(parent: parent)
    #expect(source.manifest == manifest && manifest.valid(permission: permission))
    #expect(source.recorder.model == "catalogue:SH058" && source.recorder.scale == 0.2)
    #expect(
      source.models["catalogue:SH058"]
        == (try NativeInductionCrewLogHistoricalGeometry.design.get()))
    let fit = ScriptNPCFit(
      definition: source.recorder,
      models: [source.recorder.model: NativeInductionCrewLogSource.recorderGeometry])
    #expect(source.matchesFit(fit, recorder: true))
    #expect(!source.matchesFit(fit, recorder: false))
    #expect(
      !source.matchesFit(
        .init(
          definition: source.recorder,
          models: [source.recorder.model: String(repeating: "0", count: 64)]),
        recorder: true))
    var changedFields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(source.recorder)) as? [String: Any])
    changedFields["scale"] = 0.21
    let changed = try JSONDecoder().decode(
      ScriptNPCDefinition.self, from: JSONSerialization.data(withJSONObject: changedFields))
    #expect(changed.scale == 0.21 && source.recorder.scale == 0.2)
    #expect(!source.matchesFit(.init(definition: changed, models: fit.models), recorder: true))
    #expect(manifest.occupants(of: manifest.recorder).isEmpty && manifest.massTonnes == 1)
    #expect(manifest.occupants(of: manifest.launch) == manifest.crew && manifest.crew.count == 2)
    #expect(manifest.receivingShelter == SystemIdentity(galaxy: 0, system: 0))
    #expect(parent == f.parent && parent.permission == permission)
    #expect(parent.crewLog == nil && !parent.milestones.contains(7))
    #expect(source.manifest == (try NativeInductionCrewLogSource(parent: parent)).manifest)
  }
}
