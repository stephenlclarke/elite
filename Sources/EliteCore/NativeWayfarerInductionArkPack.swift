import Foundation

/// A separately pinned native service; it never changes the accepted C08 opening content.
enum NativeInductionArkPack {
  static let stateID = "l337.wayfarer-seed-ark/registered-ark"
  static let version = "1.0.0"
  static let digest = "3fcfc81995febbaa6db7e2d0989a2c489f6c288e44463fdadf16137d5df402b7"
  static let encounter = "registered-ark"
  static let alias = "ark"
  static let launchTimer = "native-launch"
  private static let profile = Result { try NativeInductionArkSource.profile() }

  static func instance(registeredArk: UUID) -> UUID {
    ScriptIdentity.uuid("native-induction-ark-job-v1:\(registeredArk)")
  }
  static func actor(instance: UUID) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(instance):\(digest):\(encounter):\(alias)")
  }
  static func marked(_ state: borrowing ScriptInstance) -> Bool {
    state.definition == stateID || state.digest == digest || state.savedNativeArk != nil
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    guard pack.manifest.stateID == stateID, pack.manifest.version == version,
      pack.digest == digest, let expected = try? profile.get(),
      pack.manifest.npcs == [expected], pack.models.count == 1,
      pack.models[NativeInductionArkSource.model] != nil,
      let group = pack.manifest.encounters?.first, pack.manifest.encounters?.count == 1,
      group.id == encounter, group.galaxy == 0, group.system == 162,
      group.profile == "profiled-local-freeze-v1", group.actors.count == 1,
      group.actors.first?.id == alias, group.actors.first?.npc == expected.id,
      group.actors.first?.hostile == false,
      pack.manifest.trial == nil, pack.manifest.board == nil,
      pack.manifest.providerContract == nil, pack.manifest.mission.parentOnly == nil,
      (pack.manifest.children ?? []).isEmpty,
      pack.manifest.handlers.map(\.event) == [
        "mission.accepted", "timer.fired", "encounter.admitted",
      ]
    else { return false }
    return Set(pack.manifest.capabilities)
      == Set([
        "script-lua-v1", "story-v2", "durable-commands-v2", "local-flight-clocks-v2",
        "mission-calendar-v2", "profiled-encounters-v2", "npc-wormhole-transit-v2",
      ])
  }
}

extension Game {
  var nativeInductionArkPack: ScriptPack? {
    scriptPacks.first(where: NativeInductionArkPack.matches)
  }
}

extension ScriptPackLibrary {
  static var bundledInductionArkDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-wayfarer-seed-ark")
  }
}
