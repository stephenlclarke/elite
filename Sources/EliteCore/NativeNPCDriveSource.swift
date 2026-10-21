import Foundation

enum NativeWormholeRefusal: String, Error, Sendable {
  case worldUnavailable, actorUnavailable, driveUnavailable, disabled, massLocked
  case outOfRange, insufficientFuel, expired, wrongWake, unsafeSweep, stale, capacity
}

/// Turn-local source, sealed from the actual owned body and fitted live component.
struct NativeNPCDriveSource {
  let actor: ActorIdentity
  let component: UUID
  let body: SpaceBody
  let terms: ScriptNPCDriveDefinition
  let fuel: Double
  let radius: Double
  private init(
    actor: ActorIdentity, component: UUID, body: SpaceBody,
    terms: ScriptNPCDriveDefinition, fuel: Double, radius: Double
  ) {
    self.actor = actor
    self.component = component
    self.body = body
    self.terms = terms
    self.fuel = fuel
    self.radius = radius
  }

  static func resolve(
    in game: borrowing Game, leg: NativeWormholeLeg,
    context: OriginalWorldJourneyContext
  ) throws -> Self {
    guard context.matches(game, at: game.systemIdentity),
      context.route.origin.location == game.systemIdentity,
      context.route.destination.worldID == leg.destinationWorld
    else { throw NativeWormholeRefusal.worldUnavailable }
    guard !game.docked, let instance = game.commander.scriptState.instances[leg.instance],
      instance.outcome == .active, instance.suspension == nil,
      let encounter = instance.ownedEncounters[leg.encounter],
      let retained = encounter.actors[leg.alias], retained.identity == leg.actor,
      retained.presence == .present, retained.location(in: encounter) == game.systemIdentity,
      let body = game.bodies.first(where: { $0.missionActorID == leg.actor }),
      body.missionInstanceID == leg.instance, body.energy > 0,
      let descriptor = game.currentMissionActorDescriptor(bodyID: body.id),
      let actualContext = game.gameplayContext(),
      let physical = body.physical, let npc = body.scriptNPC, npc.valid
    else { throw NativeWormholeRefusal.actorUnavailable }
    _ = try MissionNativeBridge.bindActor(
      descriptor: descriptor, body: body, context: actualContext)
    guard !game.isEMPDisabled(body) else { throw NativeWormholeRefusal.disabled }
    guard let drive = npc.fit.definition.drive, drive.valid,
      let component = npc.components[drive.component], component.energy > 0,
      let mesh = game.scriptNPCMesh(body), let hull = try? PreparedHull(mesh: mesh)
    else { throw NativeWormholeRefusal.driveUnavailable }
    guard context.route.distanceLightYears <= drive.rangeLightYears else {
      throw NativeWormholeRefusal.outOfRange
    }
    guard npc.fuel >= context.route.distanceLightYears else {
      throw NativeWormholeRefusal.insufficientFuel
    }
    let distance = 600 * drive.massLockScale
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
      terms: drive, fuel: npc.fuel, radius: hull.radius)
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
}

enum NativeWormholeSweep {
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
