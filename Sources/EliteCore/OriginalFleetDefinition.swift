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
  public var runtimeReady: Bool { false }
}
