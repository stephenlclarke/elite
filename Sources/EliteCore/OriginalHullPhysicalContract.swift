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
  let name: String
  let metresPerSourceUnit: Double
  let unitBasis: String
  let physicalMesh: Mesh
  let specificationSHA256: String
  let model: OriginalFleetShowroomModel
  let envelope: OriginalHullEnvelope
  let nativeTriangles: Int

  static let gyrfalconAssault: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH002") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH002"))
  }

  static let gyrfalconCommand: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH003") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH003"))
  }

  static let gyrfalconPatrol: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH004") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH004"))
  }

  static let impalaVoyager: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH007") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH007"))
  }

  static let burro: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH029") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH029"))
  }

  static let haflinger: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH061") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH061"))
  }

  init(definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel) throws {
    guard definition.approvedMeshAvailable, model.id == definition.id, model.nativeDesign.valid
    else {
      throw Failure.unsupportedSource
    }
    switch definition.id {
    case "SH002":
      guard definition.name == "Gyrfalcon Assault",
        definition.sourceSHA256
          == "39cd712ae422c7dc47d16ff5ad7a0fd5b01f18cc6cb2b9e30fa965c1505dd7fb",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-01-native-lod/SH002-design.toml",
        model.sourceSHA256 == "5e665c3443a3f1fb2341d418dc9d5cbde7bc1f11d2761c67289defeb26e3c51a"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH003", "SH004":
      guard let approved = OriginalGyrfalconFamilyActivation.registration(for: definition.id),
        definition.name == approved.name,
        definition.sourceSHA256 == approved.specificationSHA256,
        model.coordinateUnits == "metres", model.sourcePath == approved.modelPath,
        model.sourceSHA256 == approved.modelSHA256
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH007":
      guard definition.name == "Impala Voyager",
        definition.sourceSHA256
          == "a75681f60d15795e2db03b783671fbe3d572bfd75a39f62658a7dca09ac666ea",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-01-native-lod/SH007-design.toml",
        model.sourceSHA256 == "911be33ac10be443afd3d33c6d20f65079bb9a5c20b58752597c52d50d12aad3"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH029":
      guard definition.name == "Burro",
        definition.sourceSHA256
          == "8f94df2d92f9cd5a93c2a3eb8ee8c057a1093b922235f0ec8c01a2c8c4b3826f",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH029-design.toml",
        model.sourceSHA256 == "585cb9a7f47fb13f6249c09f2ccc262eb852c98ad10721a95730b68fc4eb7b5c"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH061":
      guard definition.name == "Haflinger",
        definition.sourceSHA256
          == "71000f32ab2cc28cacc3406e49bee33550fb339f89d43a64e04dad3a15ca46db",
        model.coordinateUnits == nil,
        model.sourcePath == "replacement-hulls/SH061-design.toml",
        model.sourceSHA256 == "fad88f0e9cfc1f9a3748ab995b9fca058f675a0c8a6fc89bc72ccefd8399e26b"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 20
      unitBasis =
        "Explicit project calibration approved 21 October 2026: 20 metres per SH061 source unit. Source coordinates did not declare SI units."
    default: throw Failure.unsupportedSource
    }
    let mesh = model.displayMesh
    id = definition.id
    name = definition.name
    specificationSHA256 = definition.sourceSHA256
    self.model = model
    let scale = metresPerSourceUnit
    physicalMesh = .init(
      vertices: mesh.vertices.map { $0 * scale }, faces: mesh.faces,
      details: mesh.details, materials: mesh.materials, faceMaterials: mesh.faceMaterials,
      faceTextures: mesh.faceTextures, preserveWinding: true)
    envelope = try OriginalHullEnvelope(vertices: physicalMesh.vertices)
    nativeTriangles = mesh.faces.reduce(0) { $0 + max(0, $1.count - 2) }
  }

  var sourceFields: [ShipSpec] {
    let size = envelope.dimensions
    let basis =
      unitBasis
      + " Independent of display normalization; derived bounds do not certify a docking route or activate a hull."
    func field(_ key: String, _ label: String, _ value: Double, unit: String) -> ShipSpec {
      .init(
        key: "original.physical." + key, label: label,
        text: String(format: "%.2f", value) + " " + unit, number: value,
        unit: unit, status: metresPerSourceUnit == 1 ? "source" : "calibration", basis: basis)
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
    let result: Result<OriginalHullPhysicalContract, any Error>
    switch id {
    case "SH002": result = OriginalHullPhysicalContract.gyrfalconAssault
    case "SH003": result = OriginalHullPhysicalContract.gyrfalconCommand
    case "SH004": result = OriginalHullPhysicalContract.gyrfalconPatrol
    case "SH007": result = OriginalHullPhysicalContract.impalaVoyager
    case "SH029": result = OriginalHullPhysicalContract.burro
    case "SH061": result = OriginalHullPhysicalContract.haflinger
    default: return nil
    }
    return try? result.get()
  }

  var physicalSourcePreview: Mesh? {
    physicalSourceContract?.model.displayMesh.showroomNormalised
  }

  var sourceProfilesIncludingPhysical: [ShipProfile] {
    let retained = sourceProfilesIncludingOriginal
    guard let contract = physicalSourceContract else { return retained }
    return retained + [
      .init(
        id: id + "/original-physical", title: "Physical source: " + contract.name,
        group: "original-physical-metres",
        context:
          contract.unitBasis + " Active fitting and docking remain separate.",
        fields: contract.sourceFields)
    ]
  }
}
