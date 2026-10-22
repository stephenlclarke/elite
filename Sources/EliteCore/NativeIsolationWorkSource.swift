import Foundation

enum NativeIsolationWorkRole: String, CaseIterable, Codable, Sendable {
  case primary = "primary-feed"
  case reserve = "reserve-feed"

  var name: String {
    self == .primary ? "Renas primary-feed isolator" : "Renas reserve-feed isolator"
  }
  var offset: Vector3 {
    self == .primary ? .init(66000, 24000, 0) : .init(66300, 24000, 0)
  }
}

/// One original pair per world owner. Authorization and actual programmer custody
/// are separate native boundaries; constructing identities never reserves or admits it.
struct NativeIsolationWorkSource: Sendable {
  static let location = SystemIdentity(galaxy: 0, system: 185)
  static let issuerLocation = SystemIdentity(galaxy: 0, system: 7)
  static let programmerResource = "g11-isolation-programmer"
  static let model = "asset:g11-renas-isolation-enclosure"
  static let geometry = ShipDesign(
    vertices: [
      [-3, -3, -3], [3, -3, -3], [3, 3, -3], [-3, 3, -3], [-3, -3, 3], [3, -3, 3], [3, 3, 3],
      [-3, 3, 3],
    ],
    faces: [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ], license: "MIT",
    source: "Original Renas dual-feed isolation enclosure, six-metre native box")
  static let profile = ScriptNPCDefinition(
    id: "g11-renas-isolation-module", name: "Renas uncrewed feeder isolator",
    source: "Original Lerr Renas dual-feed service spur",
    basis: "Stationary uncrewed six-metre control enclosure; no cargo, salvage or equipment grant.",
    model: model, scale: 1, energy: 100, recharge: 0, speed: 0, acceleration: 0,
    pitch: 0, yaw: 0, roll: 0, missiles: 0, fuel: 0, drive: nil,
    ecm: false, bounty: 0, lasers: [], components: [])

  let owner: UUID
  var id: UUID { ScriptIdentity.uuid("g11-renas-dual-feed-v1:\(owner):pair-001") }
  var issuer: UUID { ScriptIdentity.uuid("g11-lerr-utility-owner-v1:\(owner)") }
  func module(_ role: NativeIsolationWorkRole) -> UUID {
    ScriptIdentity.uuid("\(id):module:\(role.rawValue)")
  }
  func supply(_ role: NativeIsolationWorkRole) -> UUID {
    ScriptIdentity.uuid("\(module(role)):supply")
  }
  func load(_ role: NativeIsolationWorkRole) -> UUID {
    ScriptIdentity.uuid("\(module(role)):load")
  }
  func initialPose(_ role: NativeIsolationWorkRole, reference: StationAnchor) throws -> ShipPose {
    guard reference.identity.system == Self.location, reference.identity.visit > 0,
      reference.identity.entity == 1, reference.position.finite,
      reference.orientation.validRotation,
      reference.orientation.x.cross(reference.orientation.y).dot(reference.orientation.z) > 0.9999
    else { throw SaveError.invalidCommander }
    let pose = ShipPose(
      position: reference.position + reference.orientation.apply(role.offset),
      orientation: reference.orientation)
    guard pose.position.finite, pose.position.length <= 1e9 else {
      throw SaveError.invalidCommander
    }
    return pose
  }
  private static let geometryDigest = Result {
    ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(geometry))
  }
  static var geometryHash: String { get throws { try geometryDigest.get() } }
  func matches(_ fit: ScriptNPCFit) -> Bool {
    fit.valid && fit.definition == Self.profile
      && fit.models == [Self.model: (try? Self.geometryHash) ?? ""]
  }
}

enum NativeIsolationWorkPack {
  static let stateID = "l337.isolation-work-source/native-source"
  static let version = "1.0.0"
  static let digest = "3116ca9aa3caed74781f79138d329796bd6ffb52711df2f3f65dccd353fbb42e"
  static let encounter = "renas-feeders"
  static let timer = "native-deploy"

  static func instance(source: UUID) -> UUID {
    ScriptIdentity.uuid("g11-native-isolation-provider-v1:\(source)")
  }
  static func actor(job: UUID, role: NativeIsolationWorkRole) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(job):\(digest):\(encounter):\(role.rawValue)")
  }
  static func marked(_ state: borrowing ScriptInstance) -> Bool {
    let definition = state.definition
    let pin = state.digest
    let claim = state.savedIsolationWork != nil
    return definition == stateID || pin == digest || claim
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    guard pack.manifest.stateID == stateID, pack.manifest.version == version, pack.digest == digest,
      pack.manifest.npcs == [NativeIsolationWorkSource.profile],
      pack.models == [NativeIsolationWorkSource.model: NativeIsolationWorkSource.geometry],
      pack.manifest.models?.count == 1, pack.manifest.trial == nil, pack.manifest.board == nil,
      pack.manifest.providerContract == nil, pack.manifest.mission.parentOnly == nil,
      (pack.manifest.children ?? []).isEmpty, pack.manifest.encounters?.count == 1,
      let group = pack.manifest.encounters?.first, group.id == encounter,
      group.galaxy == 0, group.system == 185, group.profile == "profiled-local-freeze-v1",
      group.actors.count == 2,
      pack.manifest.handlers.map(\.event) == [
        "mission.accepted", "timer.fired", "encounter.admitted",
      ],
      Set(pack.manifest.capabilities)
        == Set([
          "script-lua-v1", "story-v2", "durable-commands-v2", "local-flight-clocks-v2",
          "profiled-encounters-v2",
        ])
    else { return false }
    return NativeIsolationWorkRole.allCases.allSatisfy { role in
      guard let actor = group.actors.first(where: { $0.id == role.rawValue }) else { return false }
      return actor.npc == NativeIsolationWorkSource.profile.id && !actor.hostile
        && Vector3(actor.x, actor.y, actor.z) == role.offset
    }
  }

  static func initialResources(state: borrowing ScriptInstance, actor: ScriptOwnedActor) throws
    -> NPCState?
  {
    guard marked(state) else { return nil }
    guard state.definition == stateID, state.version == version, state.digest == digest,
      let source = state.savedIsolationWork, source.job == state.id,
      let role = NativeIsolationWorkRole(rawValue: actor.alias),
      let module = source.modules.first(where: { $0.role == role }), module.admission == nil,
      actor.presence == .prepared, actor.identity == Self.actor(job: source.job, role: role)
    else { throw SaveError.invalidCommander }
    let resources = NPCResources(
      profile: .nativeHull, energyCapacity: 100, energyRecharge: 0,
      frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0, frontShield: 0, rearShield: 0,
      heatCapacity: 240, heatCooling: 0, fuel: nil, fuelCapacity: nil)
    guard resources.valid else { throw SaveError.invalidCommander }
    return .init(
      role: .mission, origin: NativeIsolationWorkSource.location,
      destination: NativeIsolationWorkSource.location,
      legalProvenance: .recorded, cargoProvenance: .recorded, routeProvenance: .recorded,
      resources: resources, hasFuelScoops: false)
  }
}
