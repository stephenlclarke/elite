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
  case unsupportedWeapon, invalidShot, invalidArchive
}

/// Seals only the checked native binding and projected facts, not the external durable join.
/// It is deliberately non-Codable: a load must resolve actual retained facts again.
struct MissionActorBinding: Sendable {
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
struct MissionNativeImpactProof: Sendable {
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
    shot: MissionShotDescriptor, archive: MissionLaunchArchive?, hit: GameplayHit,
    victimPart: String?, victimComponentID: UUID?, currentSource: ActorIdentity?,
    currentVictim: ActorIdentity?, attribution: MissionImpactAttribution,
    system: SystemIdentity, visit: UInt64, sceneRevision: UInt64, instanceRevision: UInt64,
    projectileBody: SpaceBody, targetBody: SpaceBody?
  ) {
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
