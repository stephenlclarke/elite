/// Exact original authored values, without runtime JSON/TOML decoding or dynamic Any storage.
public indirect enum OriginalFleetValue: Sendable, Equatable {
  case string(String)
  case boolean(Bool)
  case integer(Int64)
  /// A truthful decimal representation when a source integer exceeds Int64; never parsed implicitly.
  case largeInteger(String)
  case number(Double)
  case array([OriginalFleetValue])
  case object([String: OriginalFleetValue])
}

/// Staged definition input for later single-catalogue integration, not a live ship resolver.
public struct OriginalFleetDefinition: Sendable {
  public let id: String
  public let name: String
  public let family: String
  public let role: String
  public let playerFlyable: Bool
  public let purchasePolicy: String
  public let authored: [String: OriginalFleetValue]
  public let sourcePath: String
  public let sourceSHA256: String
  public let nativePerformance: ShipPerformance?
  public let approvedMeshAvailable: Bool
  public let integrationBlockers: [String]
  public var runtimeReady: Bool {
    OriginalLlamaActivation.supports(self)
      || OriginalJaguarActivation.supports(self)
      || OriginalHareExplorerActivation.supports(self)
      || OriginalCarabaoHighlinerActivation.supports(self)
      || OriginalCarabaoCarrierActivation.supports(self)
      || OriginalOryxVoyagerActivation.supports(self)
      || OriginalTamarawActivation.supports(self)
      || OriginalDzoMkIIActivation.supports(self)
      || OriginalDzoActivation.supports(self)
      || OriginalBazaMkIIActivation.supports(self)
      || OriginalBazaFighterActivation.supports(self)
      || OriginalBadgerActivation.supports(self)
      || OriginalVultureRaiderActivation.supports(self)
      || OriginalArnaCutterActivation.supports(self)
      || OriginalMooseClipperActivation.supports(self)
      || OriginalBarbaryActivation.supports(self)
      || OriginalFalconetActivation.supports(self)
      || OriginalCondorActivation.supports(self)
      || OriginalHobbyFighterActivation.supports(self)
      || OriginalErneCorvetteActivation.supports(self)
      || OriginalHarpyFamilyActivation.supports(self)
      || OriginalSakerActivation.supports(self)
      || OriginalServalFighterActivation.supports(self)
      || OriginalZebuActivation.supports(self)
      || OriginalEagleCruiserActivation.supports(self)
      || OriginalStagLinerActivation.supports(self)
      || OriginalPantherFamilyActivation.supports(self)
      || OriginalKiteInterceptorActivation.supports(self)
      || OriginalSparrowhawkActivation.supports(self)
      || OriginalIbexActivation.supports(self)
      || OriginalGazelleExplorerActivation.supports(self)
      || OriginalDonkeyActivation.supports(self)
      || OriginalSableLinerActivation.supports(self)
      || OriginalImpalaVoyagerActivation.supports(self)
      || OriginalGyrfalconFamilyActivation.supports(self)
      || OriginalGyrfalconAssaultActivation.supports(self)
      || OriginalBurroActivation.supports(self) || OriginalHaflingerActivation.supports(self)
  }
}

extension OriginalFleetDefinitionData {
  private static let byID = Dictionary(uniqueKeysWithValues: staged.map { ($0.id, $0) })

  /// Exact authored identities only; no predecessor-name or loosely formatted ID fallback.
  public static func definition(for id: String) -> OriginalFleetDefinition? { byID[id] }
}

extension OriginalFleetValue {
  /// Preserve integers and explicit out-of-range decimal text without a Double conversion.
  var sourceText: String {
    switch self {
    case .string(let value): return String(reflecting: value)
    case .boolean(let value): return value ? "true" : "false"
    case .integer(let value): return String(value)
    case .largeInteger(let value): return value
    case .number(let value): return String(value)
    case .array(let values): return "[" + values.map(\.sourceText).joined(separator: ", ") + "]"
    case .object(let fields):
      return "{"
        + fields.keys.sorted().map {
          String(reflecting: $0) + ": " + fields[$0]!.sourceText
        }.joined(separator: ", ") + "}"
    }
  }
}

extension OriginalFleetDefinition {
  static let sourceProfileGroup = "l337-original-authored"

  private static func sourceLabel(_ key: String) -> String {
    switch key {
    case "id": "Original ID"
    case "name": "Original name"
    case "family": "Family"
    case "role": "Role"
    case "playerFlyable": "Player flyable"
    case "purchasePolicy": "Access policy"
    case "game": "Authored flight specifications"
    case "balance": "Authoring basis"
    case "license": "Source licence"
    case "status": "Source status"
    default: key
    }
  }

  var sourceProfile: ShipProfile {
    let basis = "Original authored specification; not an active fitting or calibration claim"
    var fields = authored.keys.sorted().map { key in
      ShipSpec(
        key: "original." + key, label: Self.sourceLabel(key), text: authored[key]!.sourceText,
        number: nil, unit: "authored", status: "source", basis: basis)
    }
    for (key, label, text) in [
      ("original.sourcePath", "Source file", sourcePath),
      ("original.sourceSHA256", "Source fingerprint", sourceSHA256),
      (
        "original.stagedBlockers", "Staged blocker snapshot",
        integrationBlockers.joined(separator: ", ")
      ),
    ] {
      fields.append(
        .init(
          key: key, label: label, text: text, number: nil, unit: "authored", status: "source",
          basis: basis))
    }
    return .init(
      id: id + "/original-authored", title: "Original source: " + name,
      group: Self.sourceProfileGroup,
      context:
        "Authored source values; current game fittings and hull activation are separate. Staged blockers are historical input metadata.",
      fields: fields)
  }
}
