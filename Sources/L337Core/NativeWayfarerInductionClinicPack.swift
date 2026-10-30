import Foundation

enum NativeInductionClinicPack {
  static let stateID = "l337.induction-consignment/clinic"
  static let version = "1.0.0"
  static let digest = "90a867f9ddde2c95ecc1fb84b3132c11c6bc4abc2485199aace5285a0a5e3e82"
  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    instance.definition == stateID || instance.digest == digest
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    pack.manifest.stateID == stateID && pack.manifest.version == version && pack.digest == digest
      && pack.manifest.mission.milestones == ["Original clinic sample received"]
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
  static var bundledInductionClinicDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-induction-clinic")
  }
}

extension Game {
  var nativeInductionClinicPack: ScriptPack? {
    scriptPacks.first(where: NativeInductionClinicPack.matches)
  }
}
