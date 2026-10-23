import Foundation

extension NativeC01Surveyor {
  /// Native declarations supplement this one pinned campaign; original pack bytes stay untouched.
  static func encounterDefinition(
    pack: ScriptPack, state: ScriptInstance, id: String
  ) -> ScriptEncounterDefinition? {
    if pack.digest == NativeGlassMeridian.digest,
      pack.manifest.stateID == NativeGlassMeridian.stateID,
      let definition = definition(state, id: id)
    {
      return definition
    }
    return pack.manifest.encounters?.first { $0.id == id }
  }
  @inline(never)
  static func profiles(pack: borrowing ScriptPack, state: borrowing ScriptInstance)
    -> [ScriptNPCDefinition]
  {
    let original = pack.manifest.npcs ?? []
    guard pack.digest == NativeGlassMeridian.digest else { return original }
    return pinnedCampaignProfiles(original, state: state)
  }

  @inline(never)
  private static func pinnedCampaignProfiles(
    _ original: [ScriptNPCDefinition], state: borrowing ScriptInstance
  ) -> [ScriptNPCDefinition] {
    guard definition(copy state, id: encounter) != nil else { return original }
    return original + [profile(recorder: false), profile(recorder: true)]
  }

  @inline(never)
  static func designs(pack: borrowing ScriptPack, state: borrowing ScriptInstance)
    -> [String: ShipDesign]
  {
    guard pack.digest == NativeGlassMeridian.digest else { return pack.models }
    return pinnedCampaignDesigns(pack: pack, state: state)
  }

  @inline(never)
  private static func pinnedCampaignDesigns(
    pack: borrowing ScriptPack, state: borrowing ScriptInstance
  ) -> [String: ShipDesign] {
    guard definition(copy state, id: encounter) != nil,
      let additions = try? models.get()
    else { return pack.models }
    return pack.models.merging(additions) { _, native in native }
  }
  static func preparedOrientation(state: ScriptInstance, actor: ScriptOwnedActor) -> Basis3? {
    guard let source = state.savedGlassMeridian?.surveyor?.source,
      original(actor, mission: state.id, recorder: actor.alias == aliases[1])
    else { return nil }
    return Basis3().relative(to: source.reference.orientation)
  }
}

extension Game {
  func c01SurveyorActor(_ body: SpaceBody) -> ScriptOwnedActor? {
    guard let mission = glassMeridianMission,
      NativeC01Surveyor.definition(mission, id: NativeC01Surveyor.encounter) != nil,
      let actor = mission.ownedEncounters[NativeC01Surveyor.encounter]?.actors.values.first(where: {
        $0.identity == body.missionActorID
      }), actor.presence == .present, actor.body.id == body.id,
      actor.body.physical?.identity == body.physical?.identity,
      body.missionInstanceID == mission.id,
      let physical = body.physical,
      NativeC01Surveyor.nativeValid(
        physical, recorder: actor.alias == NativeC01Surveyor.aliases[1]),
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      physical.identity.entity > 1, physical.identity.entity < commander.flightSimulation.nextActor,
      body.scriptNPC?.fit == actor.body.scriptNPC?.fit
    else { return nil }
    var actual = actor
    actual.body = body
    guard
      NativeC01Surveyor.original(
        actual, mission: mission.id, recorder: actor.alias == NativeC01Surveyor.aliases[1])
    else { return nil }
    return actual
  }
  func c01SurveyorCollision(_ body: SpaceBody) -> (mesh: Mesh, mass: Double)? {
    guard let actor = c01SurveyorActor(body) else { return nil }
    if actor.alias == NativeC01Surveyor.aliases[1] {
      return (NativeC01SurveyorGeometry.recorder.rawMesh, 8)
    }
    guard let geometry = try? NativeC01SurveyorGeometry.harrier.get() else { return nil }
    return (geometry.collision, 18_000)
  }
  func isC01Surveyor(_ body: SpaceBody) -> Bool {
    guard let mission = glassMeridianMission, body.missionInstanceID == mission.id,
      let actor = mission.ownedEncounters[NativeC01Surveyor.encounter]?.actors.values.first(where: {
        $0.identity == body.missionActorID
      })
    else { return false }
    return NativeC01Surveyor.original(
      actor, mission: mission.id, recorder: actor.alias == NativeC01Surveyor.aliases[1])
  }

  mutating func prepareC01Surveyor() throws -> Bool {
    guard !docked, !paused, screen.isFlight, systemIdentity == NativeC01Surveyor.location,
      var mission = glassMeridianMission, mission.outcome == .active, mission.suspension == nil,
      var state = mission.savedGlassMeridian, state.readings.count == 2,
      let pack = glassMeridianPack, let anchor = scriptAnchor,
      let context = gameplayContext()
    else { return false }
    if mission.ownedEncounters[NativeC01Surveyor.encounter]?.admitted == true { return false }
    if state.surveyor == nil {
      let pose = commander.flightSimulation.pose
      let reference = ShipPose(
        position: pose.systemPoint(anchor.position),
        orientation: anchor.orientation.transformed(by: pose.orientation))
      state.surveyor = .init(
        source: .init(
          mission: mission.id, permission: state.permission.operation, anchors: context.anchors,
          reference: reference, visit: context.visit, physicalTime: context.physicalTime))
      guard NativeC01Surveyor.shapeValid(state) else { throw SaveError.invalidCommander }
      mission.savedGlassMeridian = state
    }
    guard let definition = NativeC01Surveyor.definition(mission, id: NativeC01Surveyor.encounter),
      let source = state.surveyor?.source,
      let models = try? NativeC01Surveyor.models.get(),
      let hashes = try? NativeC01Surveyor.modelHashes.get()
    else { throw SaveError.invalidCommander }
    // Frame and both original identities publish only with a safe whole-cohort admission.
    var actors: [String: ScriptOwnedActor] = [:]
    for (ordinal, spec) in definition.actors.enumerated() {
      let identity = NativeC01Surveyor.actor(mission: mission.id, alias: spec.id)
      let profile = NativeC01Surveyor.profile(recorder: ordinal == 1)
      var body = SpaceBody(
        id: -1, hull: .cobra, position: .init(spec.x, spec.y, spec.z), hostile: false)
      body.orientation = Basis3().relative(to: source.reference.orientation)
      body.energy = profile.energy
      body.missiles = 0
      body.ecmEnabled = false
      body.rotationRate = 0
      body.missionActorID = identity
      body.missionInstanceID = mission.id
      body.scriptNPC = .init(
        fit: .init(definition: profile, models: [profile.model: hashes[profile.model]!]), fuel: 0,
        guns: [:], components: [:])
      actors[spec.id] = .init(identity: identity, alias: spec.id, body: body, presence: .prepared)
    }
    let encounter = ScriptOwnedEncounter(id: definition.id, galaxy: 0, system: 164, actors: actors)
    mission.ownedEncounters[encounter.id] = encounter
    commander.scriptState.instances[mission.id] = mission
    for (key, design) in models { commander.scriptState.geometry[hashes[key]!] = design }
    let admission = try c01SurveyorAdmissionSource(
      pack: pack, state: mission, encounter: encounter)
    switch try prepareMissionActorAdmission(admission) {
    case .pending: return false
    case .unchanged: throw NativeMissionActorAdmissionError.invalidTemplate
    case .ready(let plan):
      let staged = try plan.retentionPatch.preparingInstance(mission)
      _ = try commitMissionActorAdmission(plan)
      commander.scriptState.instances[mission.id] = staged
      return true
    }
  }
}

extension NativeC01Surveyor {
  /// The exact recorder's enclosing sphere must be positively outside the authored closed hull.
  /// This replaces only the generic cohort padding for this one measured original pair.
  static func pairSeparated(harrier: ShipPose, recorder: Vector3, radius: Double) -> Bool {
    guard let geometry = try? NativeC01SurveyorGeometry.harrier.get(),
      let hull = try? PreparedHull(mesh: geometry.collision), hull.isClosed,
      radius == NativeC01SurveyorGeometry.recorder.rawMesh.vertices.map(\.length).max()
    else { return false }
    return HullSweepSafety.validatePlacement(
      center: recorder, radius: radius,
      hull: hull, pose: harrier
    ).safe
  }
}

extension Game {
  func c01SurveyorPairSeparated(
    _ a: SpawnRequest, _ first: MissionActorAdmissionTemplate,
    _ b: SpawnRequest, _ second: MissionActorAdmissionTemplate
  ) -> Bool {
    guard let id = first.canonicalBody.missionInstanceID,
      second.canonicalBody.missionInstanceID == id,
      let mission = commander.scriptState.instances[id],
      NativeC01Surveyor.definition(mission, id: NativeC01Surveyor.encounter) != nil,
      let opening = mission.savedGlassMeridian, NativeC01Surveyor.shapeValid(opening),
      NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening)
    else { return false }
    let harrier = NativeC01Surveyor.actor(mission: id, alias: NativeC01Surveyor.aliases[0])
    let recorder = NativeC01Surveyor.actor(mission: id, alias: NativeC01Surveyor.aliases[1])
    if first.actorID == harrier, second.actorID == recorder {
      return NativeC01Surveyor.pairSeparated(
        harrier: .init(position: a.position, orientation: a.orientation),
        recorder: b.position, radius: second.radius)
    }
    if second.actorID == harrier, first.actorID == recorder {
      return NativeC01Surveyor.pairSeparated(
        harrier: .init(position: b.position, orientation: b.orientation),
        recorder: a.position, radius: first.radius)
    }
    return false
  }
}

extension Game {
  /// A partially culled cohort still proves the same physical separation before restoring its mate.
  func c01SurveyorRetainedPairSeparated(
    _ request: SpawnRequest, _ template: MissionActorAdmissionTemplate, _ body: SpaceBody
  ) -> Bool {
    guard let other = c01SurveyorActor(body),
      let mission = template.canonicalBody.missionInstanceID, mission == body.missionInstanceID,
      let owner = commander.scriptState.instances[mission],
      let opening = owner.savedGlassMeridian, NativeC01Surveyor.shapeValid(opening)
    else { return false }
    let harrier = NativeC01Surveyor.actor(mission: mission, alias: NativeC01Surveyor.aliases[0])
    let recorder = NativeC01Surveyor.actor(mission: mission, alias: NativeC01Surveyor.aliases[1])
    let pose = modelPose(of: body)
    if template.actorID == harrier, other.identity == recorder {
      guard let radius = scriptNPCMesh(body)?.vertices.map(\.length).max() else { return false }
      return NativeC01Surveyor.pairSeparated(
        harrier: .init(position: request.position, orientation: request.orientation),
        recorder: pose.position, radius: radius)
    }
    if template.actorID == recorder, other.identity == harrier {
      return NativeC01Surveyor.pairSeparated(
        harrier: pose, recorder: request.position, radius: template.radius)
    }
    return false
  }
}
