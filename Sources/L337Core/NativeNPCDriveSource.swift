import Foundation

enum NativeWormholeRefusal: String, Error, Sendable, Equatable {
  case worldUnavailable, actorUnavailable, driveUnavailable, disabled, massLocked
  case outOfRange, insufficientFuel, expired, wrongWake, unsafeSweep, stale, capacity,
    custodyUnavailable
}

/// Turn-local source, sealed from the actual owned body and fitted live component.
struct NativeNPCDriveSource {
  let actor: ActorIdentity
  let component: UUID
  let position: Vector3
  let orientation: Basis3
  let terms: ScriptNPCDriveDefinition
  let policy: HyperspaceDrivePolicy
  let fuel: Double
  let radius: Double
  private init(
    actor: ActorIdentity, component: UUID, body: borrowing SpaceBody,
    terms: ScriptNPCDriveDefinition, policy: HyperspaceDrivePolicy, fuel: Double, radius: Double
  ) {
    self.actor = actor
    self.component = component
    position = body.position
    orientation = body.orientation
    self.terms = terms
    self.policy = policy
    self.fuel = fuel
    self.radius = radius
  }

  static func resolve(
    in game: borrowing Game, leg: NativeWormholeLeg,
    context: OriginalWorldJourneyContext
  ) throws -> Self {
    try validateWorld(in: game, destinationWorld: leg.destinationWorld, context: context)
    return try resolveCurrentActor(in: game, leg: leg, context: context)
  }

  @inline(never)
  private static func validateWorld(
    in game: borrowing Game, destinationWorld: String, context: OriginalWorldJourneyContext
  ) throws {
    guard context.matches(game, at: game.systemIdentity),
      context.route.origin.location == game.systemIdentity,
      context.route.destination.worldID == destinationWorld
    else { throw NativeWormholeRefusal.worldUnavailable }
  }

  // Retained actor, physical condition and geometry values begin only after world validation.
  @inline(never)
  private static func resolveCurrentActor(
    in game: borrowing Game, leg: NativeWormholeLeg,
    context: OriginalWorldJourneyContext
  ) throws -> Self {
    let actorID = leg.actor
    guard !game.docked, game.commander.scriptState.wormholeTransit?.legs[leg.id] == leg,
      let instance = game.commander.scriptState.instances[leg.instance],
      instance.outcome == .active, instance.suspension == nil,
      let encounter = instance.ownedEncounters[leg.encounter],
      let retained = encounter.actors[leg.alias], retained.identity == leg.actor,
      retained.presence == .present, retained.location(in: encounter) == game.systemIdentity,
      let body = game.bodies.first(where: { $0.missionActorID == actorID }),
      body.missionInstanceID == leg.instance, body.energy > 0,
      let descriptor = game.currentMissionActorDescriptor(bodyID: body.id),
      let actualContext = game.gameplayContext(),
      let physical = body.physical, let npc = body.scriptNPC, npc.valid
    else { throw NativeWormholeRefusal.actorUnavailable }
    _ = try MissionNativeBridge.bindActor(
      descriptor: descriptor, body: body, context: actualContext)
    guard !game.isEMPDisabled(body),
      physical.npc?.resources?.electrical.map({ $0.remaining > 0 }) ?? true
    else { throw NativeWormholeRefusal.disabled }
    guard physical.empSource == nil, physical.empCrewPod == nil, physical.salvage == nil else {
      throw NativeWormholeRefusal.custodyUnavailable
    }
    guard let drive = npc.fit.definition.drive, drive.valid,
      let component = npc.components[drive.component], component.energy > 0,
      let mesh = game.scriptNPCMesh(body), let radius = try? NativeWormholeSweep.radius(mesh)
    else { throw NativeWormholeRefusal.driveUnavailable }
    guard context.route.distanceLightYears <= drive.rangeLightYears else {
      throw NativeWormholeRefusal.outOfRange
    }
    guard npc.fuel >= context.route.distanceLightYears else {
      throw NativeWormholeRefusal.insufficientFuel
    }
    let policy = try HyperspaceDrivePolicy.authoredNPC(drive)
    let distance = try policy.massLockDistance(base: 600)
    guard body.position.length >= distance,
      !game.bodies.contains(where: {
        $0.id != body.id && $0.hull != .cargo && ($0.position - body.position).length < distance
      }),
      !game.celestials.contains(where: {
        ($0.position - body.position).length < $0.radius * 4 * drive.massLockScale
      })
    else { throw NativeWormholeRefusal.massLocked }
    return .init(
      actor: physical.identity, component: component.identity, body: body,
      terms: drive, policy: policy, fuel: npc.fuel, radius: radius)
  }
}

/// Retained attained scene endpoints, captured outside the physical simulation call stack.
struct NativeWormholeMotionSample {
  let system: SystemIdentity
  let visit: UInt64
  let physicalTime: Double
  let pose: ShipPose
  let bodies: [SpaceBody]
  init(_ game: borrowing Game) {
    system = game.systemIdentity
    visit = game.commander.flightSimulation.visit
    physicalTime = game.commander.flightSimulation.physicalTime
    pose = game.commander.flightSimulation.pose
    bodies = game.bodies
  }
  static func profiledMotion(in game: borrowing Game, before: [SpaceBody], delta: Double) -> Self {
    let flight = game.commander.flightSimulation
    return Self(
      system: game.systemIdentity, visit: flight.visit,
      physicalTime: flight.physicalTime - delta, pose: flight.pose, bodies: before)
  }
  private init(
    system: SystemIdentity, visit: UInt64, physicalTime: Double,
    pose: ShipPose, bodies: [SpaceBody]
  ) {
    self.system = system
    self.visit = visit
    self.physicalTime = physicalTime
    self.pose = pose
    self.bodies = bodies
  }
}

enum NativeWormholeSweep {
  static func radius(_ mesh: Mesh) throws -> Double {
    guard !mesh.vertices.isEmpty, mesh.vertices.allSatisfy({ $0.finite && $0.length.isFinite }),
      let radius = mesh.vertices.map(\.length).max(), radius > 0
    else { throw NativeWormholeRefusal.unsafeSweep }
    return radius
  }
  /// The centre crosses the oriented disk; an enclosing actual hull must fit inside its aperture.
  static func crosses(
    opening: NativeWormholeOpening, from: Vector3, to: Vector3,
    hullRadius: Double
  ) -> Bool {
    guard opening.valid, from.finite, to.finite, hullRadius.isFinite,
      hullRadius > 0, hullRadius < opening.radius
    else { return false }
    let a = opening.entrance.orientation.inverse(from - opening.entrance.position)
    let b = opening.entrance.orientation.inverse(to - opening.entrance.position)
    guard a.z > 0, b.z <= 0 else { return false }
    let t = a.z / (a.z - b.z)
    let point = a + (b - a) * t
    return hypot(point.x, point.y) + hullRadius < opening.radius
  }
}
