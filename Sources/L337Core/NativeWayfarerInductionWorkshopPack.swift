import Foundation

enum NativeInductionWorkshopPack {
  static let stateID = "l337.induction-consignment/workshop"
  static let version = "1.0.0"
  static let digest = "853bcac4938a22642c7b4b9f655fb2aed3ad34460a37d55fda11e61f9ff90c36"
  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    instance.definition == stateID || instance.digest == digest
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    pack.manifest.stateID == stateID && pack.manifest.version == version && pack.digest == digest
      && pack.manifest.mission.milestones == ["Original serviced workshop unit returned"]
      && Set(pack.manifest.capabilities)
        == Set(["script-lua-v1", "story-v2", "durable-commands-v2"])
      && pack.manifest.handlers.count == 1
      && pack.manifest.handlers.first?.event == "mission.accepted"
      && pack.manifest.handlers.first?.function == "retain"
      && pack.manifest.board == nil && pack.manifest.repairLoop == nil && pack.manifest.trial == nil
      && pack.manifest.providerContract == nil && pack.models.isEmpty
      && (pack.manifest.encounters ?? []).isEmpty && (pack.manifest.npcs ?? []).isEmpty
      && (pack.manifest.children ?? []).isEmpty
  }
}
extension ScriptPackLibrary {
  static var bundledInductionWorkshopDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-induction-workshop")
  }
}
extension Game {
  var nativeInductionWorkshopPack: ScriptPack? {
    scriptPacks.first(where: NativeInductionWorkshopPack.matches)
  }
}
