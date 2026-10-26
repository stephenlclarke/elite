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

  static let sableLiner: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH012") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH012"))
  }

  static let donkey: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH018") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH018"))
  }

  static let gazelleExplorer: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH019") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH019"))
  }

  static let ibex: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH027") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH027"))
  }

  static let sparrowhawk: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH030") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH030"))
  }

  static let kiteInterceptor: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH031") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH031"))
  }

  static let pantherExplorer: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH032") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH032"))
  }

  static let pantherScout: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH033") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH033"))
  }

  static let stagLiner: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH035") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH035"))
  }

  static let zebu: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH036") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH036"))
  }

  static let servalFighter: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH041") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH041"))
  }

  static let saker: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH042") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH042"))
  }

  static let eagleCruiser: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH043") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH043"))
  }

  static let harpyAssault: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH044") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH044"))
  }

  static let harpyDropship: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH046") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH046"))
  }

  static let harpyGunship: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH047") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH047"))
  }

  static let erneCorvette: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH045") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH045"))
  }

  static let hobbyFighter: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH054") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH054"))
  }

  static let condor: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH055") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH055"))
  }

  static let falconet: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH057") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH057"))
  }

  static let barbary: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH059") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH059"))
  }

  static let mooseClipper: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH062") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH062"))
  }

  static let arnaCutter: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH064") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH064"))
  }

  static let vultureRaider: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH065") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH065"))
  }

  static let badger: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH068") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH068"))
  }

  static let bazaFighter: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH069") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH069"))
  }

  static let bazaMkII: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH070") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH070"))
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
    case "SH012":
      guard definition.name == "Sable Liner",
        definition.sourceSHA256
          == "c297a5eb32c875abd4bd8a54de8f0d66a4be0762bee53f50d124b46969c1de04",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH012-design.toml",
        model.sourceSHA256 == "980854a3c77366b6c0e1d8f559ffcbdad7bbf2fe510988fdd86a380477f6e297"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH018":
      guard definition.name == "Donkey",
        definition.sourceSHA256
          == "19a2b23e90ae2831df5322c33a19d74b1f12e8bf25b76fe06d0a711bc3d00805",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH018-design.toml",
        model.sourceSHA256 == "40e2a5fdd0f7945141cb55701deab76a64f974a38133f86333bb4fd8d199fbf6"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH019":
      guard definition.name == "Gazelle Explorer",
        definition.sourceSHA256
          == "b238e019f63d5675f48ddb8e4bcb0339fc9ca5b7b582dc996348e52eac10dc2e",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-01-native-lod/SH019-design.toml",
        model.sourceSHA256 == "56172839f14cc1aca09814de34d181b98832e87e071130d0c4c930a760d66944"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH027":
      guard definition.name == "Ibex",
        definition.sourceSHA256
          == "8683efc69a92c85add48be7022fa1a76040b4407413c5c2a349156d47425b2ed",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH027-design.toml",
        model.sourceSHA256 == "db3494ecc09b427242eed021bae074124aad87c38fe03b654161d49269952484"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH030":
      guard definition.name == "Sparrowhawk",
        definition.sourceSHA256
          == "f069a8d048fe7eb978673a2229d420a79eba020505157a7bd941d8beb8007fb1",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH030-design.toml",
        model.sourceSHA256 == "92a8ba49e684eca12580df930e999bd6f21186821b92b87f8c381b0a3e017e66"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH031":
      guard definition.name == "Kite Interceptor",
        definition.sourceSHA256
          == "a31f939eef99eb861e9a0d3699c6b106872e4d9b824fb6029b830202f058827a",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH031-design.toml",
        model.sourceSHA256 == "099246e4cea539c64042a0749ba1873e3fdbe2dfba92c53bc7370c03719dea56"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH032", "SH033":
      guard let approved = OriginalPantherFamilyActivation.registration(for: definition.id),
        definition.name == approved.name, definition.role == approved.role.rawValue,
        definition.sourceSHA256 == approved.specificationSHA256,
        model.coordinateUnits == "metres", model.sourcePath == approved.modelPath,
        model.sourceSHA256 == approved.modelSHA256
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH035":
      guard definition.name == "Stag Liner",
        definition.sourceSHA256
          == "cebf4ffeceac7b4df4b5fb971a04c08cfc61eb8e45ed5224de99b703bc9ebd59",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH035-design.toml",
        model.sourceSHA256 == "78f0f2a3940b7c50c9dafc17323320da23173b25af19c16a0be427167949334a"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH036":
      guard definition.name == "Zebu",
        definition.sourceSHA256
          == "51120ed809842d4804ea8a2fea0fcf50e9d8ce466c0f44706bbebef54fb6ac24",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH036-design.toml",
        model.sourceSHA256 == "3dd03d7688ee39b0009b257bb5cb0b65f20f5c4ac4580549396b07a48fceb1de"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH041":
      guard definition.name == "Serval Fighter",
        definition.sourceSHA256
          == "eb4fd7cee87979618eac213914f9b764bcd016c7aba19385418fdb1b57406344",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH041-design.toml",
        model.sourceSHA256 == "5d3e7b5da7bee8f62a47aeac58f13064e185d6dc49c842863da82e2a97679fa6"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH042":
      guard definition.name == "Saker",
        definition.sourceSHA256
          == "6ec7baa6ca072273a2195afaa992512ca59aa9e176daead003112d025eba8c92",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH042-design.toml",
        model.sourceSHA256 == "8b64ebb1529abe86018b7b2553c45f961c06f0e0a9182321ec1b528cb0a716c8"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH043":
      guard definition.name == "Eagle Cruiser",
        definition.sourceSHA256
          == "eb40037811544aa169c98bbb7246e50472d63e6272a0c65d21b8a16a794b09f1",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH043-design.toml",
        model.sourceSHA256 == "1c7a31a989c833da95651924fa5f44ce9d7fbb56be68b4b6cffe710b1c393216"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH044", "SH046", "SH047":
      guard let approved = OriginalHarpyFamilyActivation.registration(for: definition.id),
        definition.name == approved.name,
        definition.sourceSHA256 == approved.specificationSHA256,
        model.coordinateUnits == "metres", model.sourcePath == approved.modelPath,
        model.sourceSHA256 == approved.modelSHA256
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH045":
      guard definition.name == "Erne Corvette",
        definition.sourceSHA256
          == "9feca7316dcfb0350e65964177d4d6b7c739fbd08dbdbe7d139ed3b63a5b42bc",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH045-design.toml",
        model.sourceSHA256 == "af9e790882ec54bdc368ba1adc7edd757a032c3557d381a50a109bff5abc1ca9"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH054":
      guard definition.name == "Hobby Fighter",
        definition.sourceSHA256
          == "4ef1644733090c261783433886fb7200f79ec64cd3be81f4fb75cd18c84ef114",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH054-design.toml",
        model.sourceSHA256 == "1a933aff0cb9f12bfb23ef4d8a834350e33021f5d7942934db94401ce350ab54"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH055":
      guard definition.name == "Condor",
        definition.sourceSHA256
          == "4042afa6a7081598eb33637ce2a1002776c354d88cc99986ca8fab0d9197a2cc",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH055-design.toml",
        model.sourceSHA256 == "770a05d0e3faacffb915e1bc5ccfc3bb0e5142d940132843e182ca0b71d9752f"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH057":
      guard definition.name == "Falconet",
        definition.sourceSHA256
          == "96e8038ebb2a3545c430869bfd9d76acfafe0c772275a89f9e448780d76cf482",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH057-design.toml",
        model.sourceSHA256 == "08f2a4ceeb05e5ba652c2691301d17a285ec99de0c4f79d9fcdcdaec18bb5fa9"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH059":
      guard definition.name == "Barbary",
        definition.sourceSHA256
          == "da1a6cf678ebe36676dcf76706067c36a6c26cf6d869f931b33dc5ab841c1c52",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH059-design.toml",
        model.sourceSHA256 == "1c642950f8d6c5ef773cc36b9c73c249e87e582de19d412e62e4e76e8f7b8b14"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH062":
      guard definition.name == "Moose Clipper",
        definition.sourceSHA256
          == "39fc71f28c9597a79b7f06ab1d1e578703bc77ff9cb9e1d2f2b823504e224833",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-03/SH062-design.toml",
        model.sourceSHA256 == "ec91173e7ff65ed64271fabdae0c237519774c07d5ef6a97a2e21c36287324f0"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH064":
      guard definition.name == "Arna Cutter",
        definition.sourceSHA256
          == "38d6360e261ce6fa95abdd0a79b8fd284c7ec15b01d0473151f80137be870777",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-03/SH064-design.toml",
        model.sourceSHA256 == "470c4f3530d75eb55cd74e896922e26b26df6771b65af04112639db4209d5c80"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH065":
      guard definition.name == "Vulture Raider",
        definition.sourceSHA256
          == "24bd731a4b4e35b11e20b541d6159cc98cdd79658a7cd7c45c290570f5206ff9",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-04/SH065-design.toml",
        model.sourceSHA256 == "b29e5447be715c56e804b43d4ef5b71ecad354d18c48cf7e6e16d2aac78771af"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH068":
      guard definition.name == "Badger",
        definition.sourceSHA256
          == "53d9e1b1a354a02f096792d93f576c3ec8a347b4e21d2531383144491f021840",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-03/SH068-design.toml",
        model.sourceSHA256 == "9a793c007844bbb9fe72ebc51cfe0e5d671739ac087b63628a3d91857e868fe5"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH069":
      guard definition.name == "Baza Fighter",
        definition.sourceSHA256
          == "25c5ec42383b56910654e79f1f6d07fb219fbd8792dc80724c5e2f74c942d366",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-04/SH069-design.toml",
        model.sourceSHA256 == "02c42c3c40b2a4542db58570f3b689c31dcaa49503c9b8d930f3aae52e1a6bb4"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    case "SH070":
      guard definition.name == "Baza Mk II",
        definition.sourceSHA256
          == "54d7ba9ab091c2c04bf5dcda32ac844dd3d2ce1ffe6c1e99209838de5e577ed6",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-04/SH070-design.toml",
        model.sourceSHA256 == "25c56839704deba785e7c381a9db70ddc7e225d94ca37d144a4becb150f7c4fd"
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
    case "SH012": result = OriginalHullPhysicalContract.sableLiner
    case "SH018": result = OriginalHullPhysicalContract.donkey
    case "SH019": result = OriginalHullPhysicalContract.gazelleExplorer
    case "SH027": result = OriginalHullPhysicalContract.ibex
    case "SH030": result = OriginalHullPhysicalContract.sparrowhawk
    case "SH031": result = OriginalHullPhysicalContract.kiteInterceptor
    case "SH032": result = OriginalHullPhysicalContract.pantherExplorer
    case "SH033": result = OriginalHullPhysicalContract.pantherScout
    case "SH035": result = OriginalHullPhysicalContract.stagLiner
    case "SH036": result = OriginalHullPhysicalContract.zebu
    case "SH041": result = OriginalHullPhysicalContract.servalFighter
    case "SH042": result = OriginalHullPhysicalContract.saker
    case "SH043": result = OriginalHullPhysicalContract.eagleCruiser
    case "SH044": result = OriginalHullPhysicalContract.harpyAssault
    case "SH046": result = OriginalHullPhysicalContract.harpyDropship
    case "SH047": result = OriginalHullPhysicalContract.harpyGunship
    case "SH045": result = OriginalHullPhysicalContract.erneCorvette
    case "SH054": result = OriginalHullPhysicalContract.hobbyFighter
    case "SH055": result = OriginalHullPhysicalContract.condor
    case "SH057": result = OriginalHullPhysicalContract.falconet
    case "SH059": result = OriginalHullPhysicalContract.barbary
    case "SH062": result = OriginalHullPhysicalContract.mooseClipper
    case "SH064": result = OriginalHullPhysicalContract.arnaCutter
    case "SH065": result = OriginalHullPhysicalContract.vultureRaider
    case "SH068": result = OriginalHullPhysicalContract.badger
    case "SH069": result = OriginalHullPhysicalContract.bazaFighter
    case "SH070": result = OriginalHullPhysicalContract.bazaMkII
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
