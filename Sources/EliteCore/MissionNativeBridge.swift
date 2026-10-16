import Foundation

/// Untrusted projected facts, never proof of a retained mission or installed pack.
/// The Game resolver must obtain these from MC1's actual retained-record/pack/fit join.
struct MissionActorDescriptor: Equatable, Sendable {
  let instanceID: UUID
  let instanceRevision: UInt64
  let packDigest: String
  let encounterID: String
  let encounterAdmitted: Bool
  let system: SystemIdentity
  let alias: String
  let actorID: UUID
  /// Exact ScriptActorPresence.rawValue; a string alone grants no mission authority.
  let presence: String
  let missionActorID: UUID?
  let missionInstanceID: UUID?
  let body: SpaceBody
}

/// Authored values projected from an actual joined fit, not caller-selected damage authority.
struct MissionWeaponDescriptor: Equatable, Sendable {
  let id: String
  let kind: AttackKind
  let damage: Double
  let range: Double
  let projectileSpeed: Double?
  let lifetime: Double?
  let collisionRadius: Double?
  let collisionDelay: Double?
  /// Actual transformed muzzle and aim in the same frame used for collision queries.
  let muzzle: Vector3
  let direction: Vector3
}

/// Exact existing ScriptNPCShot fields. Archive and native judgement await their real provider.
struct MissionShotDescriptor: Equatable, Sendable {
  let identity: UUID
  let owner: UUID
  let instance: UUID
  let weapon: String
  let component: UUID?
  let velocity: Vector3
  let age: Double
  let lifetime: Double
  let damage: Double
  let radius: Double
  let collisionDelay: Double
}

enum MissionNativeBridgeError: Error, Equatable, Sendable {
  case invalidDescriptor, sourceMismatch, missingActor, invalidNativeBinding, staleBinding
  case unsupportedWeapon, invalidShot, invalidArchive, invalidGeometry
}

/// Seals only the checked native binding and projected facts, not the external durable join.
/// It is deliberately non-Codable: a load must resolve actual retained facts again.
struct MissionActorBinding: Equatable, Sendable {
  let instanceID: UUID
  let actorID: UUID
  let bodyID: Int
  let nativeActor: ActorIdentity
  fileprivate let descriptor: MissionActorDescriptor
  fileprivate let actorSnapshot: ActorSnapshot
  fileprivate let sceneRevision: UInt64

  fileprivate init(
    descriptor: MissionActorDescriptor, actorSnapshot: ActorSnapshot, sceneRevision: UInt64
  ) {
    instanceID = descriptor.instanceID
    actorID = descriptor.actorID
    bodyID = descriptor.body.id
    nativeActor = actorSnapshot.identity
    self.descriptor = descriptor
    self.actorSnapshot = actorSnapshot
    self.sceneRevision = sceneRevision
  }
}

/// Pure native checks only. G1's Game resolver must call the real MC1 descriptor factory
/// and revalidate that durable join before every use; no generic combat/admission bypass.
enum MissionNativeBridge {
  static func bindActor(
    descriptor: MissionActorDescriptor, body: SpaceBody, context: EncounterContext
  ) throws -> MissionActorBinding {
    let actor = try checkedActor(descriptor: descriptor, body: body, context: context)
    return .init(
      descriptor: descriptor, actorSnapshot: actor, sceneRevision: context.revision)
  }

  static func validateBinding(
    _ binding: MissionActorBinding, descriptor: MissionActorDescriptor,
    body: SpaceBody, context: EncounterContext
  ) throws {
    guard binding.descriptor == descriptor, descriptor.body == body,
      binding.sceneRevision == context.revision
    else { throw MissionNativeBridgeError.staleBinding }
    let actor = try checkedActor(descriptor: descriptor, body: body, context: context)
    guard actor == binding.actorSnapshot else { throw MissionNativeBridgeError.staleBinding }
  }

  private static func checkedActor(
    descriptor: MissionActorDescriptor, body: SpaceBody, context: EncounterContext
  ) throws -> ActorSnapshot {
    guard PackValidation.localID(descriptor.encounterID), PackValidation.localID(descriptor.alias),
      descriptor.packDigest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
      (0..<8).contains(descriptor.system.galaxy), (0...256).contains(descriptor.system.system),
      descriptor.encounterAdmitted, descriptor.presence == "present"
    else { throw MissionNativeBridgeError.invalidDescriptor }
    guard descriptor.missionActorID == descriptor.actorID,
      descriptor.missionInstanceID == descriptor.instanceID,
      body.missionActorID == descriptor.actorID, body.missionInstanceID == descriptor.instanceID,
      descriptor.body == body,
      descriptor.system == context.system
    else { throw MissionNativeBridgeError.sourceMismatch }
    guard body.id >= 0, body.energy.isFinite, body.energy > 0,
      body.position.finite, body.orientation.validRotation,
      body.rotation.isFinite, body.rotationRate.isFinite, let physical = body.physical,
      physical.velocity.finite, physical.angularVelocity.finite,
      context.visit > 0, context.visit < UInt64.max,
      context.physicalTime.isFinite, context.physicalTime >= 0,
      physical.identity.entity >= 2, physical.identity.entity < UInt64.max,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      physical.population == .mission, physical.npc?.role == .mission,
      context.protection.protectedActors.contains(physical.identity)
    else { throw MissionNativeBridgeError.invalidNativeBinding }
    let actors = context.actors.filter { $0.identity == physical.identity }
    guard actors.count == 1, let actor = actors.first else {
      throw MissionNativeBridgeError.missingActor
    }
    guard actor.hull == body.hull, actor.energy == body.energy,
      actor.position.finite, actor.orientation.validRotation,
      actor.velocity.finite, actor.angularVelocity.finite,
      actor.maximumEnergy.isFinite, actor.maximumEnergy >= 0,
      actor.maximumSpeedUnitsPerSecond.isFinite, actor.maximumSpeedUnitsPerSecond >= 0,
      actor.npc == physical.npc, actor.npc?.role == .mission
    else { throw MissionNativeBridgeError.invalidNativeBinding }
    return actor
  }

  /// Structural compatibility only; the Game resolver must prove this is the actual weapon.
  static func validateWeapon(_ weapon: MissionWeaponDescriptor) throws {
    guard PackValidation.localID(weapon.id), weapon.muzzle.finite, weapon.direction.finite,
      abs(weapon.direction.length - 1) < 1e-6,
      [weapon.damage, weapon.range].allSatisfy({
        $0.isFinite && (0.001...100_000).contains($0)
      })
    else { throw MissionNativeBridgeError.unsupportedWeapon }
    switch weapon.kind {
    case .laser:
      guard
        [weapon.projectileSpeed, weapon.lifetime, weapon.collisionRadius, weapon.collisionDelay]
          .allSatisfy({ $0 == nil })
      else { throw MissionNativeBridgeError.unsupportedWeapon }
    case .plasma:
      guard let speed = weapon.projectileSpeed, speed.isFinite, (1...100_000).contains(speed),
        let lifetime = weapon.lifetime, lifetime.isFinite, (0.01...60).contains(lifetime),
        let radius = weapon.collisionRadius, radius.isFinite, (0.01...100).contains(radius),
        let delay = weapon.collisionDelay, delay.isFinite, (0...10).contains(delay),
        delay < lifetime
      else { throw MissionNativeBridgeError.unsupportedWeapon }
    default:
      throw MissionNativeBridgeError.unsupportedWeapon
    }
  }

  /// Mirrors the existing shot bounds without allocating or deriving an attack owner.
  static func validateShot(_ shot: MissionShotDescriptor) throws {
    guard PackValidation.localID(shot.weapon), shot.velocity.finite,
      (1...100_000).contains(shot.velocity.length), shot.age.isFinite, (0...60).contains(shot.age),
      shot.lifetime.isFinite, (0.01...60).contains(shot.lifetime),
      shot.damage.isFinite, (0.001...100_000).contains(shot.damage),
      shot.radius.isFinite, (0.01...100).contains(shot.radius), shot.collisionDelay.isFinite,
      (0...shot.lifetime).contains(shot.collisionDelay)
    else { throw MissionNativeBridgeError.invalidShot }
  }
}

/// Durable target identity is distinct from a native address allocated for one visit.
public enum MissionLaunchTarget: Equatable, Codable, Sendable {
  case player
  case actor(instance: UUID, actor: UUID, packDigest: String)
}

/// Bounded historical data, never a capability after decoding.
/// MC1 retains this unchanged as ScriptNPCShot.nativeAttribution and revalidates every join.
public struct MissionLaunchArchive: Equatable, Codable, Sendable {
  public let schemaVersion: Int
  public let shotID: UUID
  public let instanceID: UUID
  public let packDigest: String
  public let sourceActorID: UUID
  public let sourceComponentID: UUID?
  public let intendedTarget: MissionLaunchTarget
  public let judgement: MissionLaunchJudgement
  public var origin: AttackOrigin { judgement.origin }

  fileprivate init(
    shotID: UUID, instanceID: UUID, packDigest: String, sourceActorID: UUID,
    sourceComponentID: UUID?, intendedTarget: MissionLaunchTarget,
    judgement: MissionLaunchJudgement
  ) {
    schemaVersion = 1
    self.shotID = shotID
    self.instanceID = instanceID
    self.packDigest = packDigest
    self.sourceActorID = sourceActorID
    self.sourceComponentID = sourceComponentID
    self.intendedTarget = intendedTarget
    self.judgement = judgement
  }

  /// Shape checks do not prove the archive belongs to an actual retained shot.
  public var valid: Bool {
    guard schemaVersion == 1, judgement.valid, origin.owner.entity >= 2,
      origin.playerAmmunition == nil,
      packDigest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
      origin.sourcePart == sourceComponentID?.uuidString
    else { return false }
    switch intendedTarget {
    case .player:
      return judgement.victim.entity == 0
    case .actor(_, _, let digest):
      return judgement.victim.entity >= 2
        && digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    }
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion, shotID, instanceID, packDigest, sourceActorID, sourceComponentID
    case intendedTarget, judgement
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
    shotID = try values.decode(UUID.self, forKey: .shotID)
    instanceID = try values.decode(UUID.self, forKey: .instanceID)
    packDigest = try values.decode(String.self, forKey: .packDigest)
    sourceActorID = try values.decode(UUID.self, forKey: .sourceActorID)
    sourceComponentID = try values.decodeIfPresent(UUID.self, forKey: .sourceComponentID)
    intendedTarget = try values.decode(MissionLaunchTarget.self, forKey: .intendedTarget)
    judgement = try values.decode(MissionLaunchJudgement.self, forKey: .judgement)
    guard valid else { throw MissionNativeBridgeError.invalidArchive }
  }
}

/// Only a verified same intended durable victim/current binding can use frozen law.
/// Historical source data remains available even when current adjudication is unknown.
enum MissionImpactAttribution: Equatable, Sendable {
  case unknown
  case frozenLaunch
}

/// Mission-shot-only capability for G1's single damage kernel. Not persisted or constructible
/// by native consumers. The actual resolver/geometry producer remains in this provider file.
struct MissionNativeImpactProof: Equatable, Sendable {
  /// Actual finite step segment, clipped to the shot's remaining lifetime (at most 60 seconds).
  let delta: Double
  let physicalTime: Double
  fileprivate let sourceBinding: MissionActorBinding?
  let shot: MissionShotDescriptor
  let archive: MissionLaunchArchive?
  let hit: GameplayHit
  let victimPart: String?
  let victimComponentID: UUID?
  let currentSource: ActorIdentity?
  let currentVictim: ActorIdentity?
  let attribution: MissionImpactAttribution
  let system: SystemIdentity
  let visit: UInt64
  let sceneRevision: UInt64
  let instanceRevision: UInt64
  let projectileBody: SpaceBody
  let targetBody: SpaceBody?
  var damage: Double { shot.damage }
  var kind: AttackKind { .plasma }
  var shotID: UUID { shot.identity }
  var sourceInstanceID: UUID { shot.instance }
  var sourceActorID: UUID { shot.owner }
  var sourceComponentID: UUID? { shot.component }
  var originalOrigin: AttackOrigin? { archive?.origin }
  var frozenJudgement: MissionLaunchJudgement? {
    switch attribution {
    case .unknown: nil
    case .frozenLaunch: archive?.judgement
    }
  }

  fileprivate init(
    delta: Double, physicalTime: Double, sourceBinding: MissionActorBinding?,
    shot: MissionShotDescriptor, archive: MissionLaunchArchive?, hit: GameplayHit,
    victimPart: String?, victimComponentID: UUID?, currentSource: ActorIdentity?,
    currentVictim: ActorIdentity?, attribution: MissionImpactAttribution,
    system: SystemIdentity, visit: UInt64, sceneRevision: UInt64, instanceRevision: UInt64,
    projectileBody: SpaceBody, targetBody: SpaceBody?
  ) {
    self.delta = delta
    self.physicalTime = physicalTime
    self.sourceBinding = sourceBinding
    self.shot = shot
    self.archive = archive
    self.hit = hit
    self.victimPart = victimPart
    self.victimComponentID = victimComponentID
    self.currentSource = currentSource
    self.currentVictim = currentVictim
    self.attribution = attribution
    self.system = system
    self.visit = visit
    self.sceneRevision = sceneRevision
    self.instanceRevision = instanceRevision
    self.projectileBody = projectileBody
    self.targetBody = targetBody
  }
}

extension MissionNativeBridge {
  /// G1's actual fire boundary must re-resolve the source/target factories before this call.
  /// This seals bounded historical data only; it never allocates, fires or creates law facts.
  static func makeLaunchArchive(
    shot: MissionShotDescriptor, source: MissionActorBinding,
    intendedTarget: MissionActorBinding?, judgement: MissionLaunchJudgement
  ) throws -> MissionLaunchArchive {
    try validateShot(shot)
    guard judgement.valid, shot.owner == source.actorID, shot.instance == source.instanceID,
      judgement.origin.owner == source.nativeActor,
      judgement.origin.sourcePart == shot.component?.uuidString
    else { throw MissionNativeBridgeError.invalidArchive }
    let target: MissionLaunchTarget
    if let intendedTarget {
      guard judgement.victim == intendedTarget.nativeActor else {
        throw MissionNativeBridgeError.invalidArchive
      }
      target = .actor(
        instance: intendedTarget.instanceID, actor: intendedTarget.actorID,
        packDigest: intendedTarget.descriptor.packDigest)
    } else {
      guard judgement.victim.entity == 0 else { throw MissionNativeBridgeError.invalidArchive }
      target = .player
    }
    let archive = MissionLaunchArchive(
      shotID: shot.identity, instanceID: source.instanceID,
      packDigest: source.descriptor.packDigest, sourceActorID: source.actorID,
      sourceComponentID: shot.component, intendedTarget: target, judgement: judgement)
    guard archive.valid else { throw MissionNativeBridgeError.invalidArchive }
    return archive
  }

  /// Nil is the old unknown-history case; malformed present evidence never degrades to nil.
  static func validateArchive(
    _ archive: MissionLaunchArchive?, shot: MissionShotDescriptor, packDigest: String
  ) throws {
    try validateShot(shot)
    guard let archive else { return }
    guard archive.valid, archive.shotID == shot.identity, archive.instanceID == shot.instance,
      archive.sourceActorID == shot.owner, archive.sourceComponentID == shot.component,
      archive.packDigest == packDigest
    else { throw MissionNativeBridgeError.invalidArchive }
  }
}

extension Game {
  /// Resolve the actual retained source before sealing its native binding. This read never
  /// adopts a body, allocates an identity, infers a pack or accepts a caller-built descriptor.
  func currentMissionNativeBinding(bodyID: Int) throws -> MissionActorBinding {
    guard let descriptor = currentMissionActorDescriptor(bodyID: bodyID) else {
      throw MissionNativeBridgeError.sourceMismatch
    }
    guard let body = bodies.first(where: { $0.id == bodyID }),
      let context = gameplayContext()
    else { throw MissionNativeBridgeError.invalidNativeBinding }
    return try MissionNativeBridge.bindActor(descriptor: descriptor, body: body, context: context)
  }

  /// Current pack/fit/retained ownership is resolved again, not trusted from an older proof.
  func validateMissionNativeBinding(_ binding: MissionActorBinding) throws {
    guard let descriptor = currentMissionActorDescriptor(bodyID: binding.bodyID),
      let body = bodies.first(where: { $0.id == binding.bodyID }),
      let context = gameplayContext()
    else { throw MissionNativeBridgeError.sourceMismatch }
    try MissionNativeBridge.validateBinding(
      binding, descriptor: descriptor, body: body, context: context)
  }
}

/// Constructed only by the physical query in this file; no damage or custody authority.
struct MissionCollisionContact: Equatable, Sendable {
  let hit: GameplayHit
  let victimPart: String?
  let componentUUID: UUID?
  let selectedTargetBody: SpaceBody?
  fileprivate init(hit: GameplayHit, victimPart: String?, componentUUID: UUID?, body: SpaceBody?) {
    self.hit = hit
    self.victimPart = victimPart
    self.componentUUID = componentUUID
    self.selectedTargetBody = body
  }
}

extension Game {
  /// Inputs and returned points use the current camera-relative physical frame.
  func nearestMissionCollision(
    from origin: Vector3, direction: Vector3, range: Double, radius: Double,
    excludingBodyIDs: Set<Int> = [], includePlayer: Bool
  ) throws -> MissionCollisionContact? {
    func finite(_ vector: Vector3) -> Bool { vector.finite && vector.length.isFinite }
    guard finite(origin), finite(direction), abs(direction.length - 1) <= 1e-6,
      range.isFinite, range > 0, radius.isFinite, radius >= 0
    else { throw MissionNativeBridgeError.invalidGeometry }
    let direction = direction.unit
    guard finite(origin + direction * range) else { throw MissionNativeBridgeError.invalidGeometry }
    var nearest: MissionCollisionContact?
    func rank(_ contact: MissionCollisionContact) -> (Int, Int, String) {
      switch contact.hit.target {
      case .body(let id): return (1, id, contact.victimPart ?? "")
      case .player: return (2, 0, "")
      case .celestial(.planet): return (0, 0, "")
      case .celestial(.sun): return (0, 1, "")
      }
    }
    func consider(
      _ distance: Double, target: GameplayHitTarget, body: SpaceBody? = nil,
      part: String? = nil, component: UUID? = nil
    ) {
      guard distance.isFinite, (0...range).contains(distance) else { return }
      let point = origin + direction * distance
      guard finite(point) else { return }
      let candidate = MissionCollisionContact(
        hit: .init(target: target, distance: distance, point: point),
        victimPart: part, componentUUID: component, body: body)
      if let previous = nearest {
        guard
          distance < previous.hit.distance
            || (distance == previous.hit.distance && rank(candidate) < rank(previous))
        else { return }
      }
      nearest = candidate
    }
    // The native ray path accepts rounded nonplanar polygons and skips individual
    // degenerate faces. Project into the same dominant axis to select ears, retaining the
    // original 3D vertices for the sweep instead of flattening authored geometry.
    func prepare(_ mesh: Mesh) throws -> [[Int]] {
      guard !mesh.vertices.isEmpty, !mesh.faces.isEmpty, mesh.vertices.allSatisfy(finite),
        mesh.faces.allSatisfy({
          $0.count >= 3 && $0.allSatisfy(mesh.vertices.indices.contains)
        })
      else { throw MissionNativeBridgeError.invalidGeometry }
      var result: [[Int]] = []
      var usableFaces = 0
      for face in mesh.faces {
        var polygon = face
        if polygon.first == polygon.last { polygon.removeLast() }
        let first = mesh.vertices[polygon[0]]
        guard
          let normal = (1..<(polygon.count - 1)).lazy.map({
            (mesh.vertices[polygon[$0]] - first).cross(mesh.vertices[polygon[$0 + 1]] - first)
          }).first(where: { $0.length > 0 })
        else { continue }
        guard finite(normal) else { throw MissionNativeBridgeError.invalidGeometry }
        usableFaces += 1
        // Exact zero-radius intersections use native authored-polygon clipping, not ear clips.
        if radius == 0 { continue }
        guard Set(polygon).count == polygon.count else {
          throw MissionNativeBridgeError.invalidGeometry
        }
        let scale = polygon.map { (mesh.vertices[$0] - first).length }.max() ?? 0
        guard scale.isFinite, scale > 0 else { throw MissionNativeBridgeError.invalidGeometry }
        let points = Dictionary(
          uniqueKeysWithValues: polygon.map {
            ($0, (mesh.vertices[$0] - first) * (1 / scale))
          })
        guard points.values.allSatisfy(finite) else {
          throw MissionNativeBridgeError.invalidGeometry
        }
        let axis = [abs(normal.x), abs(normal.y), abs(normal.z)].enumerated().max {
          $0.element < $1.element
        }!.offset
        func point(_ index: Int) -> (Double, Double) {
          let v = points[index]!
          return axis == 0 ? (v.y, v.z) : axis == 1 ? (v.x, v.z) : (v.x, v.y)
        }
        func cross(_ a: Int, _ b: Int, _ c: Int) -> Double {
          let p = point(a)
          let q = point(b)
          let r = point(c)
          return (q.0 - p.0) * (r.1 - p.1) - (q.1 - p.1) * (r.0 - p.0)
        }
        // Reject crossing edges rather than filling a malformed polygon's overlapping regions.
        for edge in polygon.indices {
          let next = (edge + 1) % polygon.count
          for other in polygon.indices where other > edge {
            let otherNext = (other + 1) % polygon.count
            if next == other || otherNext == edge { continue }
            let a = polygon[edge]
            let b = polygon[next]
            let c = polygon[other]
            let d = polygon[otherNext]
            let abC = cross(a, b, c)
            let abD = cross(a, b, d)
            let cdA = cross(c, d, a)
            let cdB = cross(c, d, b)
            if ((abC > 0 && abD < 0) || (abC < 0 && abD > 0))
              && ((cdA > 0 && cdB < 0) || (cdA < 0 && cdB > 0))
            {
              throw MissionNativeBridgeError.invalidGeometry
            }
          }
        }
        let area = polygon.indices.reduce(0.0) { total, index in
          let p = point(polygon[index])
          let q = point(polygon[(index + 1) % polygon.count])
          return total + p.0 * q.1 - q.0 * p.1
        }
        guard area.isFinite, area != 0 else { throw MissionNativeBridgeError.invalidGeometry }
        let sign = area > 0 ? 1.0 : -1.0
        let convex = polygon.indices.allSatisfy { index in
          cross(
            polygon[(index + polygon.count - 1) % polygon.count],
            polygon[index], polygon[(index + 1) % polygon.count]) * sign >= 0
        }
        if convex {
          // Preserve the native fan's diagonal and original warped surface on convex faces.
          for index in 1..<(polygon.count - 1) {
            result.append([polygon[0], polygon[index], polygon[index + 1]])
          }
          continue
        }
        // Concave sweeps use projected ears with original vertices: inflated fan triangles
        // would otherwise fill authored notches that the zero-radius native path clips away.
        while polygon.count > 3 {
          var removed = false
          for index in polygon.indices {
            let a = polygon[(index + polygon.count - 1) % polygon.count]
            let b = polygon[index]
            let c = polygon[(index + 1) % polygon.count]
            let turn = cross(a, b, c) * sign
            if turn == 0 {
              polygon.remove(at: index)
              removed = true
              break
            }
            guard turn > 0 else { continue }
            let occupied = polygon.contains { other in
              other != a && other != b && other != c
                && cross(a, b, other) * sign >= 0
                && cross(b, c, other) * sign >= 0
                && cross(c, a, other) * sign >= 0
            }
            if !occupied {
              result.append([a, b, c])
              polygon.remove(at: index)
              removed = true
              break
            }
          }
          guard removed else { throw MissionNativeBridgeError.invalidGeometry }
        }
        result.append(polygon)
      }
      guard usableFaces > 0 else { throw MissionNativeBridgeError.invalidGeometry }
      return result
    }
    // Finite transformed vertex bounds conservatively reject meshes before any face work.
    // Nil means invalid bounds; false is a genuine bounded miss, not an invalid-face fallback.
    func intersectsBounds(_ vertices: [Vector3]) -> Bool? {
      guard vertices.allSatisfy(finite), let first = vertices.first else { return nil }
      var lower = first
      var upper = first
      for vertex in vertices.dropFirst() {
        lower = .init(min(lower.x, vertex.x), min(lower.y, vertex.y), min(lower.z, vertex.z))
        upper = .init(max(upper.x, vertex.x), max(upper.y, vertex.y), max(upper.z, vertex.z))
      }
      lower = lower - .init(radius, radius, radius)
      upper = upper + .init(radius, radius, radius)
      guard finite(lower), finite(upper) else { return nil }
      var entry = 0.0
      var exit = range
      for (start, motion, low, high) in [
        (origin.x, direction.x, lower.x, upper.x),
        (origin.y, direction.y, lower.y, upper.y),
        (origin.z, direction.z, lower.z, upper.z),
      ] {
        if motion == 0 {
          if start < low || start > high { return false }
        } else {
          let a = (low - start) / motion
          let b = (high - start) / motion
          entry = max(entry, min(a, b))
          exit = min(exit, max(a, b))
          if entry > exit { return false }
        }
      }
      return true
    }
    func swept(
      _ mesh: Mesh, transform: (Vector3) -> Vector3, target: GameplayHitTarget,
      body: SpaceBody? = nil, part: String? = nil, component: UUID? = nil
    ) -> Bool {
      let vertices = mesh.vertices.map(transform)
      guard let candidate = intersectsBounds(vertices) else { return false }
      guard candidate else { return true }
      guard let faces = try? prepare(mesh) else { return false }
      for face in faces {
        if let distance = ScriptSweptCollision.triangle(
          origin: origin, direction: direction, range: range, radius: radius,
          a: vertices[face[0]], b: vertices[face[1]], c: vertices[face[2]])
        {
          consider(distance, target: target, body: body, part: part, component: component)
        }
      }
      return true
    }
    var activeIDs: Set<Int> = []
    for body in bodies where body.energy > 0 {
      guard activeIDs.insert(body.id).inserted else {
        throw MissionNativeBridgeError.invalidGeometry
      }
    }
    let live = bodies.filter { $0.energy > 0 && !excludingBodyIDs.contains($0.id) }
    for body in live {
      let axes = [
        body.modelVector(.init(1, 0, 0)), body.modelVector(.init(0, 1, 0)),
        body.modelVector(.init(0, 0, 1)),
      ]
      guard finite(body.position), body.rotation.isFinite, body.orientation.validRotation,
        axes.allSatisfy(finite), axes.allSatisfy({ abs($0.dot($0) - 1) < 1e-6 }),
        abs(axes[0].dot(axes[1])) < 1e-6, abs(axes[0].dot(axes[2])) < 1e-6,
        abs(axes[1].dot(axes[2])) < 1e-6
      else { throw MissionNativeBridgeError.invalidGeometry }
    }
    // Native zero-radius rays retain the existing exact authored-polygon clipping path.
    if radius == 0 {
      let overrides = gameplayMeshOverrides
      var native: [SpaceBody] = []
      for body in live where body.scriptNPC == nil {
        let mesh = overrides[body.id] ?? Mesh.hull(body.hull)
        guard
          let candidate = intersectsBounds(
            mesh.vertices.map { body.position + body.modelVector($0) })
        else { throw MissionNativeBridgeError.invalidGeometry }
        if candidate {
          _ = try prepare(mesh)
          native.append(body)
        }
      }
      var playerMesh: Mesh?
      if includePlayer {
        let mesh = commander.playerMesh
        guard let candidate = intersectsBounds(mesh.vertices) else {
          throw MissionNativeBridgeError.invalidGeometry
        }
        if candidate {
          _ = try prepare(mesh)
          playerMesh = mesh
        }
      }
      if let hit = GameplayRaycast.nearest(
        origin: origin, direction: direction, maxDistance: range,
        bodies: native, playerMesh: playerMesh, meshOverrides: overrides)
      {
        let body: SpaceBody?
        if case .body(let id) = hit.target {
          body = native.first { $0.id == id }
        } else {
          body = nil
        }
        consider(hit.distance, target: hit.target, body: body)
      }
    }
    for body in live {
      guard finite(body.position), body.orientation.validRotation,
        body.rotation.isFinite
      else { throw MissionNativeBridgeError.invalidGeometry }
      if let npc = body.scriptNPC {
        guard npc.valid, let root = scriptModel(npc.fit.definition.model, fit: npc.fit)
        else { throw MissionNativeBridgeError.invalidGeometry }
        func custom(
          _ mesh: Mesh, position: Vector3, orientation: Basis3, scale: Double,
          part: String? = nil, component: UUID? = nil
        ) -> Bool {
          guard finite(position), orientation.validRotation, scale.isFinite, scale > 0,
            npc.fit.definition.scale.isFinite, npc.fit.definition.scale > 0
          else { return false }
          let local = Mesh(
            vertices: mesh.vertices.map {
              (position + orientation.apply($0 * scale)) * npc.fit.definition.scale
            }, faces: mesh.faces, preserveWinding: true)
          if radius == 0 {
            guard
              let candidate = intersectsBounds(
                local.vertices.map { body.position + body.modelVector($0) })
            else { return false }
            guard candidate else { return true }
            guard (try? prepare(local)) != nil else { return false }
            if let hit = GameplayRaycast.nearest(
              origin: origin, direction: direction,
              maxDistance: range, bodies: [body], meshOverrides: [body.id: local])
            {
              consider(
                hit.distance, target: hit.target, body: body, part: part, component: component)
            }
            return true
          }
          return swept(
            local, transform: { body.position + body.modelVector($0) },
            target: .body(body.id), body: body, part: part, component: component)
        }
        guard custom(root, position: .init(0, 0, 0), orientation: .init(), scale: 1) else {
          throw MissionNativeBridgeError.invalidGeometry
        }
        for spec in npc.fit.definition.components ?? [] where spec.solid {
          guard let state = npc.components[spec.id], state.energy > 0 else { continue }
          guard let mesh = scriptModel(spec.model, fit: npc.fit),
            custom(
              mesh, position: spec.position, orientation: spec.orientation, scale: spec.scale,
              part: spec.id, component: state.identity)
          else { throw MissionNativeBridgeError.invalidGeometry }
        }
      } else if radius > 0 {
        guard
          swept(
            gameplayMesh(for: body), transform: { body.position + body.modelVector($0) },
            target: .body(body.id), body: body)
        else { throw MissionNativeBridgeError.invalidGeometry }
      }
    }
    if radius > 0, includePlayer {
      guard swept(commander.playerMesh, transform: { $0 }, target: .player) else {
        throw MissionNativeBridgeError.invalidGeometry
      }
    }
    for celestial in celestials {
      let inflated = celestial.radius + radius
      guard finite(celestial.position), celestial.radius.isFinite, celestial.radius > 0,
        inflated.isFinite, inflated > 0
      else {
        throw MissionNativeBridgeError.invalidGeometry
      }
      if let distance = ScriptSweptCollision.sphere(
        origin: origin - celestial.position,
        direction: direction, radius: inflated)
      {
        consider(distance, target: .celestial(celestial.kind))
      }
    }
    return nearest
  }
}

/// Current-visit instant emission. A miss remains a real laser discharge without inventing a shot.
struct MissionNativeLaserProof: Sendable {
  let source: MissionActorBinding
  let weapon: MissionWeaponDescriptor
  let sourceComponentID: UUID?
  let origin: AttackOrigin
  let contact: MissionCollisionContact?
  let system: SystemIdentity
  let visit: UInt64
  let sceneRevision: UInt64
  let instanceRevision: UInt64
  var kind: AttackKind { .laser }
  var damage: Double { weapon.damage }
  var hit: GameplayHit? { contact?.hit }
  var victimPart: String? { contact?.victimPart }
  var victimComponentID: UUID? { contact?.componentUUID }
  var targetBody: SpaceBody? { contact?.selectedTargetBody }
  var sourceInstanceID: UUID { source.instanceID }
  var sourceActorID: UUID { source.actorID }

  fileprivate init(
    source: MissionActorBinding, weapon: MissionWeaponDescriptor, component: UUID?,
    origin: AttackOrigin, contact: MissionCollisionContact?, context: EncounterContext
  ) {
    self.source = source
    self.weapon = weapon
    sourceComponentID = component
    self.origin = origin
    self.contact = contact
    system = context.system
    visit = context.visit
    sceneRevision = context.revision
    instanceRevision = source.descriptor.instanceRevision
  }
}

extension Game {
  /// Called within the fire turn after the actual gun's resource preflight. Collision and durable
  /// joins can refuse before the native emission allocator is touched; no simulated shot is made.
  mutating func makeMissionNativeLaserProof(
    sourceBodyID: Int, weapon: ScriptNPCWeapon, component: UUID?,
    muzzle: Vector3, direction: Vector3
  ) throws -> MissionNativeLaserProof {
    guard let context = gameplayContext() else {
      throw MissionNativeBridgeError.invalidNativeBinding
    }
    let source = try resolveMissionNativeBinding(bodyID: sourceBodyID, context: context)
    guard
      let actual = missionWeaponDescriptor(
        weapon, source: source.descriptor.body, component: component,
        muzzle: muzzle, direction: direction), actual.kind == .laser,
      commander.flightSimulation.valid,
      commander.flightSimulation.nextEmission < UInt64.max
    else { throw MissionNativeBridgeError.unsupportedWeapon }
    let contact = try nearestMissionCollision(
      from: actual.muzzle, direction: actual.direction, range: actual.range, radius: 0,
      excludingBodyIDs: [sourceBodyID], includePlayer: true)
    // Use the native allocator directly after every fallible physical/source check. Unlike the
    // general adoption helper, this path must not adopt unrelated bodies while sealing a hit.
    guard let emission = commander.flightSimulation.allocateEmission() else {
      throw MissionNativeBridgeError.invalidNativeBinding
    }
    let origin = AttackOrigin(
      emissionID: emission, owner: source.nativeActor, emittedAt: context.physicalTime,
      ownerLegalAtEmission: source.actorSnapshot.legal, sourcePart: component?.uuidString)
    return .init(
      source: source, weapon: actual, component: component,
      origin: origin, contact: contact, context: context)
  }
}

extension Game {
  /// Derive an impact only from the actual live shot, retained record and this step's motion.
  /// It never accepts caller-selected damage, a target index or a historical native owner.
  func missionNativeImpactProof(projectileID: UUID, delta: Double) throws
    -> MissionNativeImpactProof?
  {
    guard delta.isFinite, delta > 0,
      let body = bodies.first(where: { $0.scriptShot?.identity == projectileID }),
      bodies.lazy.filter({ $0.scriptShot?.identity == projectileID }).count == 1,
      bodies.lazy.filter({ $0.id == body.id }).count == 1,
      let shot = body.scriptShot, let descriptor = shot.missionDescriptor,
      let record = commander.scriptState.projectiles[projectileID], record.valid,
      commander.scriptState.projectileArchiveValid(record),
      record.presence == .present, record.body.id == body.id,
      record.galaxy == commander.galaxy, record.system == commander.system,
      let retained = record.body.scriptShot,
      retained.identity == shot.identity, retained.owner == shot.owner,
      retained.instance == shot.instance, retained.weapon == shot.weapon,
      retained.component == shot.component, retained.lifetime == shot.lifetime,
      abs(retained.velocity.length - shot.velocity.length)
        <= max(1, max(retained.velocity.length, shot.velocity.length)) * 1e-6,
      retained.damage == shot.damage, retained.radius == shot.radius,
      retained.collisionDelay == shot.collisionDelay,
      retained.nativeAttribution == shot.nativeAttribution,
      let instance = commander.scriptState.instances[shot.instance], instance.id == shot.instance,
      let context = gameplayContext(), let physical = body.physical,
      physical.population == .projectile, physical.npc == nil, physical.ordnance == nil,
      physical.spawnIdentity?.system == context.system,
      physical.spawnIdentity?.visit == context.visit,
      physical.spawnIdentity?.producer == .ordnance,
      physical.attackOrigin == shot.nativeAttribution?.origin,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      physical.identity.entity >= 2, physical.identity.entity < UInt64.max,
      bodies.lazy.filter({ $0.physical?.identity == physical.identity }).count == 1,
      body.hull == .missile, body.scriptNPC == nil,
      body.missionActorID == nil, body.missionInstanceID == nil,
      body.energy.isFinite, body.energy > 0, body.position.finite
    else { throw MissionNativeBridgeError.invalidShot }
    try MissionNativeBridge.validateArchive(
      shot.nativeAttribution, shot: descriptor, packDigest: instance.digest)
    if let archive = shot.nativeAttribution {
      // Archive shape is context-free. Its historical emission must also be possible in the
      // actual persisted native clock before this producer can grant an impact capability.
      guard archive.origin.owner.system == context.system,
        context.physicalTime.isFinite, context.physicalTime >= 0,
        archive.origin.emittedAt <= context.physicalTime
      else { throw MissionNativeBridgeError.invalidArchive }
    }
    // Stored pose, velocity and age may be older or in the station frame. Immutable source and
    // tuning join above; motion below comes exclusively from the current physical shot.
    let duration = min(delta, shot.lifetime - shot.age)
    let inactive = max(0, shot.collisionDelay - shot.age)
    guard duration > inactive else { return nil }
    let ownerBodies = bodies.filter {
      $0.missionInstanceID == shot.instance && $0.missionActorID == shot.owner && $0.energy > 0
    }
    let source: MissionActorBinding?
    if ownerBodies.count == 1 {
      source = try? resolveMissionNativeBinding(bodyID: ownerBodies[0].id, context: context)
    } else {
      source = nil
    }
    var excluded: Set<Int> = [body.id]
    if let source { excluded.insert(source.bodyID) }
    let direction = shot.velocity.unit
    let origin = body.position + shot.velocity * inactive
    let range = shot.velocity.length * (duration - inactive)
    guard
      let contact = try nearestMissionCollision(
        from: origin, direction: direction, range: range, radius: shot.radius,
        excludingBodyIDs: excluded, includePlayer: true)
    else { return nil }
    let victim: ActorIdentity?
    let targetBinding: MissionActorBinding?
    switch contact.hit.target {
    case .player:
      victim = context.player.identity
      targetBinding = nil
    case .body(let id):
      guard let identity = contact.selectedTargetBody?.physical?.identity,
        identity.system == context.system, identity.visit == context.visit,
        context.actors.filter({ $0.identity == identity }).count == 1
      else { throw MissionNativeBridgeError.invalidNativeBinding }
      victim = identity
      targetBinding = try? resolveMissionNativeBinding(bodyID: id, context: context)
    case .celestial:
      victim = nil
      targetBinding = nil
    }
    var attribution = MissionImpactAttribution.unknown
    if source != nil, let archive = shot.nativeAttribution {
      switch archive.intendedTarget {
      case .player:
        if case .player = contact.hit.target { attribution = .frozenLaunch }
      case .actor(let targetInstance, let targetActor, let digest):
        if let targetBinding,
          targetBinding.instanceID == targetInstance, targetBinding.actorID == targetActor,
          targetBinding.descriptor.packDigest == digest
        {
          attribution = .frozenLaunch
        }
      }
    }
    return .init(
      delta: duration, physicalTime: context.physicalTime, sourceBinding: source,
      shot: descriptor, archive: shot.nativeAttribution, hit: contact.hit,
      victimPart: contact.victimPart, victimComponentID: contact.componentUUID,
      currentSource: source?.nativeActor, currentVictim: victim, attribution: attribution,
      system: context.system, visit: context.visit, sceneRevision: context.revision,
      instanceRevision: instance.revision, projectileBody: body,
      targetBody: contact.selectedTargetBody)
  }
}

extension Game {
  /// The physical producer supplies the one actual context captured within its actor turn.
  /// Kept private so a caller-built context cannot become mission authority.
  private func resolveMissionNativeBinding(bodyID: Int, context: EncounterContext) throws
    -> MissionActorBinding
  {
    guard let descriptor = currentMissionActorDescriptor(bodyID: bodyID),
      let body = bodies.first(where: { $0.id == bodyID })
    else { throw MissionNativeBridgeError.sourceMismatch }
    return try MissionNativeBridge.bindActor(descriptor: descriptor, body: body, context: context)
  }
}

extension Game {
  /// Re-query the sealed bounded step against current retained/native facts. No counters,
  /// bodies, law, gun resources or event queues are changed by capability validation.
  func validateMissionNativeImpactProof(_ proof: MissionNativeImpactProof) throws {
    guard proof.delta.isFinite, proof.delta > 0, proof.delta <= 60,
      proof.physicalTime.isFinite, proof.physicalTime >= 0
    else { throw MissionNativeBridgeError.staleBinding }
    do {
      guard
        let current = try missionNativeImpactProof(
          projectileID: proof.shotID, delta: proof.delta), current == proof
      else { throw MissionNativeBridgeError.staleBinding }
    } catch {
      throw MissionNativeBridgeError.staleBinding
    }
  }

  /// An already allocated instant emission is checked without calling its allocating producer.
  /// The kernel independently consumes its current-visit emission watermark on successful apply.
  func validateMissionNativeLaserProof(_ proof: MissionNativeLaserProof) throws {
    do {
      guard let context = gameplayContext(),
        proof.system == context.system, proof.visit == context.visit,
        proof.sceneRevision == context.revision, proof.origin.emittedAt == context.physicalTime,
        context.physicalTime.isFinite, context.physicalTime >= 0,
        proof.origin.owner == proof.source.nativeActor,
        proof.origin.ownerLegalAtEmission == proof.source.actorSnapshot.legal,
        proof.origin.sourcePart == proof.sourceComponentID?.uuidString,
        proof.origin.ordnance == nil, proof.origin.playerAmmunition == nil,
        proof.origin.emissionID > 0, proof.origin.emissionID < UInt64.max,
        proof.origin.emissionID + 1 == commander.flightSimulation.nextEmission,
        proof.instanceRevision == proof.source.descriptor.instanceRevision
      else { throw MissionNativeBridgeError.staleBinding }
      let source = try resolveMissionNativeBinding(bodyID: proof.source.bodyID, context: context)
      guard source == proof.source, let npc = source.descriptor.body.scriptNPC else {
        throw MissionNativeBridgeError.staleBinding
      }
      let weapon: ScriptNPCWeapon?
      if let component = proof.sourceComponentID {
        guard let alias = npc.components.first(where: { $0.value.identity == component })?.key
        else { throw MissionNativeBridgeError.staleBinding }
        weapon = npc.fit.definition.components?.first(where: { $0.id == alias })?
          .weapons?.first(where: { $0.id == proof.weapon.id })
      } else {
        weapon = npc.fit.definition.lasers?.first(where: { $0.id == proof.weapon.id })
      }
      guard let weapon,
        let current = missionWeaponDescriptor(
          weapon, source: source.descriptor.body, component: proof.sourceComponentID,
          muzzle: proof.weapon.muzzle, direction: proof.weapon.direction),
        current.kind == .laser, current == proof.weapon
      else { throw MissionNativeBridgeError.staleBinding }
      let contact = try nearestMissionCollision(
        from: current.muzzle, direction: current.direction, range: current.range, radius: 0,
        excludingBodyIDs: [source.bodyID], includePlayer: true)
      guard contact == proof.contact else { throw MissionNativeBridgeError.staleBinding }
    } catch {
      throw MissionNativeBridgeError.staleBinding
    }
  }
}
