import Foundation

enum NativeInductionUtilityPack {
  static let stateID = "l337.induction-utility/original-utility-source"
  static let version = "1.0.0"
  static let digest = "22ea4026c6a63eebe18c7b8b4c1edb4a33596bfe0ca514e64592edb2660b7549"
  static let encounter = "enron-handoffs"
  static let timer = "native-deploy"
  static func instance(issue: UUID) -> UUID {
    ScriptIdentity.uuid("induction-enron-utility-job-v1:\(issue)")
  }
  static func actor(job: UUID, role: NativeInductionUtilityRole) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(job):\(digest):\(encounter):\(role.rawValue)")
  }
  @inline(never)
  static func marked(_ state: borrowing ScriptInstance) -> Bool {
    if state.definition == stateID { return true }
    if state.digest == digest { return true }
    if case .some = state.savedNativeInductionUtility { return true }
    return false
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    guard pack.manifest.stateID == stateID, pack.manifest.version == version, pack.digest == digest,
      pack.manifest.npcs == [NativeInductionUtilitySource.profile],
      pack.models == [NativeInductionUtilitySource.model: NativeInductionUtilitySource.geometry],
      pack.manifest.models?.count == 1, pack.manifest.trial == nil, pack.manifest.board == nil,
      pack.manifest.providerContract == nil, pack.manifest.mission.parentOnly == nil,
      (pack.manifest.children ?? []).isEmpty, pack.manifest.encounters?.count == 1,
      let group = pack.manifest.encounters?.first, group.id == encounter,
      group.galaxy == 0, group.system == 190, group.profile == "profiled-local-freeze-v1",
      group.actors.count == 3,
      pack.manifest.handlers.map(\.event) == [
        "mission.accepted", "timer.fired", "encounter.admitted",
      ],
      Set(pack.manifest.capabilities)
        == Set([
          "script-lua-v1", "story-v2", "durable-commands-v2", "local-flight-clocks-v2",
          "profiled-encounters-v2",
        ])
    else { return false }
    return NativeInductionUtilityRole.allCases.allSatisfy { role in
      guard let actor = group.actors.first(where: { $0.id == role.rawValue }) else { return false }
      return actor.npc == NativeInductionUtilitySource.profile.id && !actor.hostile
        && Vector3(actor.x, actor.y, actor.z) == role.offset
    }
  }
  static func initialResources(state: borrowing ScriptInstance, actor: ScriptOwnedActor) throws
    -> NPCState?
  {
    guard marked(state) else { return nil }
    guard state.definition == stateID, state.digest == digest,
      let source = state.savedNativeInductionUtility, source.authorization.job == state.id,
      source.admission == nil, actor.presence == .prepared,
      let role = NativeInductionUtilityRole(rawValue: actor.alias),
      actor.identity == Self.actor(job: state.id, role: role)
    else { throw SaveError.invalidCommander }
    let resources = NPCResources(
      profile: .nativeHull, energyCapacity: 100, energyRecharge: 0,
      frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0, frontShield: 0, rearShield: 0,
      heatCapacity: 240, heatCooling: 0, fuel: nil, fuelCapacity: nil)
    guard resources.valid else { throw SaveError.invalidCommander }
    return .init(
      role: .mission, origin: NativeInductionUtilitySource.location,
      destination: NativeInductionUtilitySource.location, legalProvenance: .recorded,
      cargoProvenance: .recorded, routeProvenance: .recorded, resources: resources,
      hasFuelScoops: false)
  }
}

extension ScriptPackLibrary {
  static var bundledInductionUtilityDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-induction-utility")
  }
}

extension Game {
  var nativeInductionUtilityPack: ScriptPack? {
    scriptPacks.first(where: NativeInductionUtilityPack.matches)
  }
  var inductionUtilityChild: ScriptInstance? {
    commander.scriptState.instances.values.first {
      $0.definition == NativeInductionUtilityPack.stateID
    }
  }
}
