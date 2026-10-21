import Foundation

struct OriginalHullEnvelope: Sendable, Equatable {
  let minimum: Vector3
  let maximum: Vector3
  /// Rotation is about the authored origin, which need not be the AABB centre.
  let clearanceRadius: Double
  var dimensions: Vector3 { maximum - minimum }

  init(vertices: [Vector3]) throws {
    guard vertices.count >= 4, vertices.allSatisfy(\.finite) else {
      throw OriginalHullPhysicalContract.Failure.invalidGeometry
    }
    minimum = .init(
      vertices.map(\.x).min()!, vertices.map(\.y).min()!, vertices.map(\.z).min()!)
    maximum = .init(
      vertices.map(\.x).max()!, vertices.map(\.y).max()!, vertices.map(\.z).max()!)
    clearanceRadius = vertices.map(\.length).max()!
    let size = maximum - minimum
    guard size.finite, size.x > 0, size.y > 0, size.z > 0,
      clearanceRadius.isFinite, clearanceRadius > 0
    else { throw OriginalHullPhysicalContract.Failure.invalidGeometry }
  }
}

/// One deliberate physical-source binding, separate from display normalization and actor admission.
/// This contract alone never replaces a saved ship, enables a fitting or certifies a docking route.
struct OriginalHullPhysicalContract: Sendable {
  enum Failure: Error { case unsupportedSource, invalidGeometry }
  let id: String
  let specificationSHA256: String
  let model: OriginalFleetShowroomModel
  let envelope: OriginalHullEnvelope
  let nativeTriangles: Int

  static let burro: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH029") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH029"))
  }

  init(definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel) throws {
    guard definition.id == "SH029", definition.name == "Burro",
      definition.sourceSHA256
        == "8f94df2d92f9cd5a93c2a3eb8ee8c057a1093b922235f0ec8c01a2c8c4b3826f",
      definition.approvedMeshAvailable, model.id == definition.id,
      model.coordinateUnits == "metres",
      model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH029-design.toml",
      model.sourceSHA256 == "585cb9a7f47fb13f6249c09f2ccc262eb852c98ad10721a95730b68fc4eb7b5c",
      model.nativeDesign.valid
    else { throw Failure.unsupportedSource }
    let mesh = model.displayMesh
    id = definition.id
    specificationSHA256 = definition.sourceSHA256
    self.model = model
    envelope = try OriginalHullEnvelope(vertices: mesh.vertices)
    nativeTriangles = mesh.faces.reduce(0) { $0 + max(0, $1.count - 2) }
  }

  var sourceFields: [ShipSpec] {
    let size = envelope.dimensions
    let basis =
      "Exact approved native LOD in authored metres; independent of display normalization. "
      + "Derived bounds are not a docking-route or activated-hull claim."
    func field(_ key: String, _ label: String, _ value: Double, unit: String) -> ShipSpec {
      .init(
        key: "original.physical." + key, label: label,
        text: String(format: "%.2f", value) + " " + unit, number: value,
        unit: unit, status: "source", basis: basis)
    }
    return [
      field("width", "Native LOD width X", size.x, unit: "m"),
      field("height", "Native LOD height Y", size.y, unit: "m"),
      field("length", "Native LOD length Z", size.z, unit: "m"),
      field(
        "clearanceRadius", "Native origin clearance radius", envelope.clearanceRadius, unit: "m"),
      .init(
        key: "original.physical.source", label: "Physical source",
        text: model.sourcePath + " / " + model.sourceSHA256,
        number: nil, unit: "authored", status: "source", basis: basis),
    ]
  }
}

extension CatalogueShip {
  /// Keep the complete original-source profile intact; physical evidence has its own units/group.
  var physicalSourceContract: OriginalHullPhysicalContract? {
    guard id == "SH029", case .success(let contract) = OriginalHullPhysicalContract.burro else {
      return nil
    }
    return contract
  }

  var physicalSourcePreview: Mesh? {
    physicalSourceContract?.model.displayMesh.showroomNormalised
  }

  var sourceProfilesIncludingPhysical: [ShipProfile] {
    let retained = sourceProfilesIncludingOriginal
    guard let contract = physicalSourceContract else { return retained }
    return retained + [
      .init(
        id: id + "/original-physical", title: "Physical source: Burro",
        group: "original-physical-metres",
        context:
          "Approved native LOD in authored metres. Active fitting and docking remain separate.",
        fields: contract.sourceFields)
    ]
  }
}
