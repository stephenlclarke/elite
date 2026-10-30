import Foundation

enum NativeInductionSeedPack {
  static let stateID = "l337.induction-consignment/seed"
  static let version = "1.0.0"
  static let digest = "53250aa0d61c99d5cc940d1b4c22d0fd49912d908251a672fbdc47986bf92520"
  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    instance.definition == stateID || instance.digest == digest
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    pack.manifest.stateID == stateID && pack.manifest.version == version && pack.digest == digest
      && pack.manifest.mission.milestones == ["Original seed lot received"]
      && pack.manifest.handlers.count == 1 && pack.manifest.handlers.first?.event == "timer.fired"
      && pack.manifest.handlers.first?.function == "expire"
      && Set(pack.manifest.capabilities)
        == Set(["script-lua-v1", "story-v2", "durable-commands-v2", "local-flight-clocks-v2"])
      && pack.manifest.board == nil && pack.manifest.coldChain == nil && pack.manifest.trial == nil
      && pack.manifest.providerContract == nil && pack.models.isEmpty
      && (pack.manifest.encounters ?? []).isEmpty && (pack.manifest.npcs ?? []).isEmpty
      && (pack.manifest.children ?? []).isEmpty
  }
}

extension ScriptPackLibrary {
  static var bundledInductionSeedDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-induction-seed")
  }
}

extension Game {
  var nativeInductionSeedPack: ScriptPack? {
    scriptPacks.first(where: NativeInductionSeedPack.matches)
  }
}
