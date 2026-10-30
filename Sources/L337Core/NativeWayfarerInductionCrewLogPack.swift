import Foundation

enum NativeInductionCrewLogPack {
  static let stateID = "l337.induction-crew-log/original-crew-log"
  static let version = "1.0.0"
  static let digest = "29f26ad4f1382ea23c3cced3b7cc609c00e6617ef7d07a52e669f7d067d2602b"
  static let encounter = "cevilis-source"
  static let timer = "native-deploy"
  static func instance(recorder: UUID) -> UUID {
    ScriptIdentity.uuid("native-induction-crew-log-job-v1:\(recorder)")
  }
  static func actor(job: UUID, role: NativeInductionCrewLogRole) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(job):\(digest):\(encounter):\(role.rawValue)")
  }
  static func marked(_ state: borrowing ScriptInstance) -> Bool {
    state.definition == stateID || state.digest == digest || state.savedNativeCrewLog != nil
  }
  private static let profiles: Result<[ScriptNPCDefinition], any Error> = Result {
    guard
      let p = OriginalFleetDefinitionData.definition(for: NativeInductionCrewLogSource.hull)?
        .nativePerformance, p.valid
    else { throw SaveError.invalidCommander }
    return [
      NativeInductionCrewLogSource.shipProfile(
        physical: try OriginalHullPhysicalContract.burro.get(), performance: p),
      NativeInductionCrewLogSource.recorderProfile(),
    ]
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    guard pack.manifest.stateID == stateID, pack.manifest.version == version,
      pack.digest == digest, let expected = try? profiles.get(),
      pack.manifest.npcs == expected, pack.models.count == 2,
      pack.manifest.models?.count == 1,
      pack.manifest.trial == nil, pack.manifest.board == nil,
      pack.manifest.providerContract == nil, pack.manifest.mission.parentOnly == nil,
      (pack.manifest.children ?? []).isEmpty,
      let group = pack.manifest.encounters?.first, pack.manifest.encounters?.count == 1,
      group.id == encounter, group.galaxy == 0, group.system == 211,
      group.profile == "profiled-local-freeze-v1", group.actors.count == 3,
      pack.manifest.handlers.map(\.event) == [
        "mission.accepted", "timer.fired", "encounter.admitted",
      ]
    else { return false }
    for role in NativeInductionCrewLogRole.allCases {
      guard let actor = group.actors.first(where: { $0.id == role.rawValue }),
        actor.npc == expected[role == .recorder ? 1 : 0].id,
        Vector3(actor.x, actor.y, actor.z) == role.offset, !actor.hostile
      else { return false }
    }
    return Set(pack.manifest.capabilities)
      == Set([
        "script-lua-v1", "story-v2", "durable-commands-v2", "local-flight-clocks-v2",
        "profiled-encounters-v2", "mission-calendar-v2", "npc-wormhole-transit-v2",
      ])
  }
}

extension ScriptPackLibrary {
  static var bundledInductionCrewLogDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-induction-crew-log")
  }
}

extension Game {
  var nativeInductionCrewLogPack: ScriptPack? {
    scriptPacks.first(where: NativeInductionCrewLogPack.matches)
  }
}
