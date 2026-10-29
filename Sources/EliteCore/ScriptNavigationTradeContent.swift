import Foundation

/// Exact translated runtime bytes, with endpoints resolved by the installed original world authority.
enum ScriptNavigationTradeContent {
  static let sourceID = "l337.training/navigation-trade"
  static let version = "1.0.0"
  static let capability = "navigation-trade-training-v2"
  static let digest = "8c23ce72936e8bdfa47978f7d7d4240171babe05c2da5ac49727d2616e38d802"
  static let cluePin = ScriptClueExecutionPin(
    sourceID: sourceID, definition: sourceID, version: version, digest: digest,
    terminalEvents: ["dialogue.confirmed"])
  static func matches(_ pack: ScriptPack) -> Bool {
    pack.manifest.stateID == sourceID && pack.manifest.version == version
      && pack.digest == digest && pack.manifest.capabilities.contains(capability)
  }
}
