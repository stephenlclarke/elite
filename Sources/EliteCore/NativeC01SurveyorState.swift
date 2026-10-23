import Foundation

struct NativeC01SurveyorSource: Codable, Sendable, Equatable {
  let mission: UUID
  let permission: UUID
  let anchors: SystemAnchors
  let reference: ShipPose
  let visit: UInt64
  let physicalTime: Double
  var position: Vector3 {
    anchors.planet.position + (anchors.sun.position - anchors.planet.position).unit
      * (anchors.planet.radius + 25_000)
  }
  var valid: Bool {
    var native = FlightSimulationState()
    native.enter(NativeC01Surveyor.location, arriving: true)
    guard let expected = native.anchors else { return false }
    return anchors.system == NativeC01Surveyor.location
      && anchors.planet == expected.planet && anchors.sun == expected.sun
      && reference.position.finite && reference.orientation.validRotation
      && visit > 0 && visit < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && position.finite && (anchors.sun.position - anchors.planet.position).length > 0
  }
}

struct NativeC01SurveyorCapture: Codable, Sendable, Equatable {
  let operation: UUID
  let marker: ScriptOwnedActor
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let scoop: EquipmentPurchaseItem
  let capturePoint: Vector3
  let relativeSpeed: Double
  let startTime: Double
  let physicalTime: Double
  let epoch: UUID
}
struct NativeC01SurveyorLoss: Codable, Sendable, Equatable {
  enum Kind: String, Codable, Sendable { case recorderDestroyed, carrierDestroyed, escape }
  let kind: Kind
  let marker: ScriptOwnedActor?
  let collector: ActorIdentity
  let carrier: UUID
  let energy: Double
  let escapePod: EquipmentPurchaseItem?
  let physicalTime: Double
}
struct NativeC01SurveyorState: Codable, Sendable, Equatable {
  let source: NativeC01SurveyorSource
  var capture: NativeC01SurveyorCapture?
  var loss: NativeC01SurveyorLoss?
  var held: Bool { capture != nil && loss == nil }
}

enum NativeC01Surveyor {
  static let location = SystemIdentity(galaxy: 0, system: 164)
  static let encounter = "meridian-surveyor"
  static let aliases = ["disabled-harrier", "original-recorder"]
  static let harrierModel = "asset:c01-harrier-65m"
  static let recorderModel = "asset:c01-recorder-8kg"
  static func actor(mission: UUID, alias: String) -> UUID {
    ScriptIdentity.uuid(
      "script-actor-v2:\(mission):\(NativeGlassMeridian.digest):\(encounter):\(alias)")
  }
  static func captureOperation(permission: UUID) -> UUID {
    ScriptIdentity.uuid("c01-original-recorder-custody-v1:\(permission)")
  }
  static func profile(recorder: Bool) -> ScriptNPCDefinition {
    .init(
      id: recorder ? "c01-original-recorder" : "c01-disabled-harrier",
      name: recorder
        ? "Original Glass Meridian flight recorder" : "Disabled Glass Meridian Harrier",
      source: "L337 C01 explicit mission authoring, 22 October 2026",
      basis: recorder
        ? "Protected original 8kg recorder; closed 0.8 x 0.5 x 0.3m box."
        : "Original SH026 Harrier identity, ROC-SH056 visual adapter; uniform65m calibration, conservative closed convex collision,18000kg. Uncrewed; mechanical propulsion and weapon failure, no EMP timer or fleet activation.",
      model: recorder ? recorderModel : harrierModel, scale: 1,
      energy: recorder ? 16 : 64, recharge: 0, speed: 0, acceleration: 0,
      pitch: 0, yaw: 0, roll: 0, missiles: 0, fuel: 0, drive: nil,
      ecm: false, bounty: 0, lasers: [], components: [])
  }
  static let models: Result<[String: ShipDesign], any Error> = Result {
    [
      harrierModel: try NativeC01SurveyorGeometry.harrier.get().design,
      recorderModel: NativeC01SurveyorGeometry.recorder,
    ]
  }

  static let modelHashes: Result<[String: String], any Error> = Result {
    try models.get().mapValues {
      ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry($0))
    }
  }
  static func approachAllowed(point: Vector3, radius: Double, speed: Double) -> Bool {
    let offset = point - Vector3(0, -45, 55)
    return point.finite && point.z > 0 && point.y < 0 && point.length < 85
      && radius.isFinite && radius > 0 && radius <= 16
      && abs(offset.x) + radius <= 16 && abs(offset.y) + radius <= 16
      && abs(offset.z) + radius <= 16 && speed.isFinite
      && speed >= 0 && speed <= ScoopApproachController.maximumRelativeSpeed
  }
  static func definition(_ mission: ScriptInstance, id: String) -> ScriptEncounterDefinition? {
    guard id == encounter, mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest, mission.version == NativeGlassMeridian.version,
      let state = mission.savedGlassMeridian, state.readings.count == 2,
      let surveyor = state.surveyor, surveyor.source.valid,
      surveyor.source.mission == mission.id,
      surveyor.source.permission == state.permission.operation
    else { return nil }
    let source = surveyor.source
    return .init(
      id: encounter, galaxy: 0, system: 164, profile: "profiled-local-freeze-v1",
      actors: aliases.enumerated().map { ordinal, alias in
        let world = source.position + Vector3(ordinal == 0 ? 0 : 80, 0, 0)
        let point = source.reference.shipPoint(world)
        return .init(
          id: alias, hull: nil, npc: profile(recorder: ordinal == 1).id,
          x: point.x, y: point.y, z: point.z, hostile: false)
      })
  }
  static func original(_ actor: ScriptOwnedActor, mission: UUID, recorder: Bool) -> Bool {
    let alias = aliases[recorder ? 1 : 0]
    guard actor.alias == alias, actor.identity == self.actor(mission: mission, alias: alias),
      actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == mission,
      actor.body.scriptNPC?.fit.definition == profile(recorder: recorder),
      let hashes = try? modelHashes.get(),
      actor.body.scriptNPC?.fit.models == [
        recorder ? recorderModel : harrierModel: hashes[recorder ? recorderModel : harrierModel]!
      ]
    else { return false }
    return actor.valid && actor.body.hull == .cobra && !actor.body.hostile
      && actor.body.missiles == 0 && actor.body.rotationRate == 0
  }
  static func passiveFit(_ body: SpaceBody) -> Bool {
    guard let mission = body.missionInstanceID, let npc = body.scriptNPC,
      let index = aliases.indices.first(where: {
        actor(mission: mission, alias: aliases[$0]) == body.missionActorID
      }),
      npc.fit.definition == profile(recorder: index == 1),
      let hashes = try? modelHashes.get(),
      npc.fit.models == [npc.fit.definition.model: hashes[npc.fit.definition.model]!]
    else { return false }
    return true
  }
  static func nativeValid(_ physical: PhysicalActorState, recorder: Bool) -> Bool {
    guard physical.population == .mission, physical.npc?.role == .mission,
      physical.velocity.finite, physical.angularVelocity.finite,
      physical.ordnance == nil, physical.payload == nil, physical.rock == nil,
      physical.salvage == nil, physical.empSource == nil, physical.empCrewPod == nil,
      let spawn = physical.spawnIdentity, spawn.producer == .mission,
      spawn.system == physical.identity.system, spawn.visit == physical.identity.visit,
      spawn.sequence > 0, spawn.sequence < UInt64(Int64.max),
      let resources = physical.npc?.resources, resources.valid,
      resources.profile == .legacyEnergyOnly,
      resources.energyCapacity == profile(recorder: recorder).energy,
      resources.energyRecharge == 0, resources.frontCapacity == 0, resources.rearCapacity == 0,
      resources.electrical == nil
    else { return false }
    return true
  }
  static func consumed(_ id: UUID, commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains { mission in
      mission.savedGlassMeridian?.surveyor?.capture != nil
        && id == actor(mission: mission.id, alias: aliases[1])
    }
  }
  @inline(never)
  static func shapeValid(_ state: borrowing NativeGlassMeridianState) -> Bool {
    if case .none = state.surveyor { return true }
    let source = state.surveyor!.source
    guard state.readings.count == 2, source.valid, source.mission == state.permission.mission,
      source.permission == state.permission.operation,
      source.visit > state.permission.dock.actor.visit,
      source.physicalTime >= (state.readings.map { $0.reading.end }.max() ?? .infinity)
    else { return false }
    return captureShapeValid(state) && lossShapeValid(state)
  }

  // Keep capture and loss payload temporaries out of the common validation frame.
  @inline(never)
  private static func captureShapeValid(_ state: borrowing NativeGlassMeridianState) -> Bool {
    guard let capture = state.surveyor!.capture else { return true }
    let source = state.surveyor!.source
    let marker = capture.marker
    let radius = NativeC01SurveyorGeometry.recorder.rawMesh.vertices.map(\.length).max()!
    guard capture.operation == captureOperation(permission: source.permission),
      original(marker, mission: source.mission, recorder: true), marker.presence == .present,
      marker.body.energy > 0, marker.body.position == capture.capturePoint,
      let native = marker.body.physical, nativeValid(native, recorder: true),
      native.identity.system == location, native.identity.visit >= source.visit,
      native.identity.entity > 1, native.identity.system == capture.collector.system,
      native.identity.visit == capture.collector.visit, capture.collector.entity == 0,
      capture.scoop.node == EquipmentRuntimeCatalog.node(for: "Fuel Scoops"),
      capture.scoop.location?.hull == capture.carrier,
      capture.scoop.location?.slot == "utility.fuelScoops",
      capture.inventoryRevision < UInt64(Int64.max),
      capture.startTime.isFinite, capture.startTime >= source.physicalTime,
      capture.physicalTime.isFinite, capture.physicalTime > capture.startTime,
      capture.physicalTime - capture.startTime <= 0.1 + 1e-9,
      approachAllowed(point: capture.capturePoint, radius: radius, speed: capture.relativeSpeed)
    else { return false }
    return true
  }

  @inline(never)
  private static func lossShapeValid(_ state: borrowing NativeGlassMeridianState) -> Bool {
    guard let loss = state.surveyor!.loss else { return true }
    let source = state.surveyor!.source
    guard loss.physicalTime.isFinite, loss.physicalTime >= source.physicalTime,
      loss.energy.isFinite, loss.collector.entity == 0
    else { return false }
    switch loss.kind {
    case .recorderDestroyed:
      guard state.surveyor!.capture == nil, let marker = loss.marker,
        original(marker, mission: source.mission, recorder: true), marker.presence == .destroyed,
        marker.body.energy == 0, loss.escapePod == nil,
        marker.body.physical?.identity.system == location,
        marker.body.physical?.identity.visit ?? 0 >= source.visit,
        marker.body.physical.map({ nativeValid($0, recorder: true) }) == true
      else { return false }
    case .carrierDestroyed, .escape:
      guard let capture = state.surveyor!.capture, loss.marker == nil,
        loss.physicalTime >= capture.physicalTime
      else { return false }
      if loss.kind == .carrierDestroyed {
        guard loss.energy <= 0, loss.escapePod == nil else { return false }
      } else {
        guard loss.energy > 0, let pod = loss.escapePod,
          pod.node == EquipmentRuntimeCatalog.node(for: "Escape Pod"),
          pod.location?.hull == loss.carrier, pod.location?.slot == "utility.escapePod"
        else { return false }
      }
    }
    return true
  }
}
