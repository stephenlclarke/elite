import Foundation

private typealias MissionActorAdmissionOwnerFacts = (
  id: UUID, definition: String, version: String, digest: String, revision: UInt64,
  outcome: ScriptOutcome
)

/// Immutable values for one admission validation; never a shared simulation owner.
private final class MissionActorAdmissionOwnerSnapshot: Sendable {
  private let storedOwner: ScriptInstance
  private let storedPack: ScriptPack

  var owner: ScriptInstance {
    _read { yield storedOwner }
  }

  var pack: ScriptPack {
    _read { yield storedPack }
  }

  var authorityFacts: MissionActorAdmissionOwnerFacts {
    (
      storedOwner.id, storedOwner.definition, storedOwner.version, storedOwner.digest,
      storedOwner.revision, storedOwner.outcome
    )
  }

  func installedEncounter(_ id: String) -> ScriptOwnedEncounter? {
    storedOwner.ownedEncounters[id]
  }

  init(
    original: borrowing Game, source: MissionActorAdmissionSource,
    instances: [UUID: ScriptInstance]
  ) throws {
    guard let owner = instances[source.instanceID],
      owner.id == source.instanceID, owner.revision == source.instanceRevision,
      owner.digest == source.packDigest, owner.definition == source.definition,
      owner.version == source.version,
      let pack = Self.installedPack(for: owner, in: original.scriptPacks),
      pack.digest == source.packDigest,
      owner.ownedEncounters[source.encounterID] == source.installedBaseEncounter,
      source.retention.id == source.encounterID,
      source.transitContext != nil
        || source.actors.indices.allSatisfy({
          source.retention.actors[source.actors[$0].alias]?.location(in: source.retention)
            == source.system
        })
    else { throw MissionPackError("Actor admission source no longer matches its installed owner.") }
    storedOwner = consume owner
    storedPack = consume pack
  }

  /// Match the first installed pack without capturing the full owner or iterating full pack values.
  @inline(never)
  private static func installedPack(
    for owner: borrowing ScriptInstance, in packs: [ScriptPack]
  ) -> ScriptPack? {
    let definition = owner.definition
    let version = owner.version
    let digest = owner.digest
    for index in packs.indices {
      if packs[index].manifest.stateID == definition, packs[index].manifest.version == version,
        packs[index].digest == digest
      {
        return packs[index]
      }
    }
    return nil
  }
}

// Attempt-local scratch only: never Sendable, stored simulation state or admission authority.
private final class ScriptEncounterAttemptScratch {
  let definition: ScriptEncounterDefinition
  let previousGeometry: [String: ShipDesign]
  var publishesGeometry = false
  var alreadyAdmitted = false
  var encounter: ScriptOwnedEncounter?
  var source: MissionActorAdmissionSource?
  var preparation: NativeMissionActorAdmissionPreparation?
  var nativePlan: NativeMissionActorAdmissionPlan?
  var selected: ScriptInstance?
  var staged: ScriptInstance?
  var count = 0
  init(definition: consuming ScriptEncounterDefinition, previousGeometry: [String: ShipDesign]) {
    self.definition = consume definition
    self.previousGeometry = previousGeometry
  }
}

public struct ScriptActorDefinition: Codable, Sendable {
  public let id: String
  public let hull: Hull?
  public var npc: String? = nil
  public let x: Double
  public let y: Double
  public let z: Double
  public let hostile: Bool
}
public struct ScriptEncounterDefinition: Codable, Sendable {
  public let id: String
  public let galaxy: Int
  public let system: Int
  public let profile: String
  public let actors: [ScriptActorDefinition]
}
public enum ScriptActorPresence: String, Codable, Sendable {
  case prepared, present, outside, unloaded, destroyed, inTransit, arrivalPending
}
public struct ScriptOwnedActor: Codable, Sendable, Equatable {
  public let identity: UUID
  public let alias: String
  /// Canonical pose is relative to the main station's non-spinning reference basis.
  public var body: SpaceBody
  public var presence: ScriptActorPresence
  public var destroyedByPlayer: Bool?
  /// Relocation requires a retained successful native transit arrival; nil is the declared origin.
  var transitLocation: SystemIdentity?
  func location(in encounter: ScriptOwnedEncounter) -> SystemIdentity {
    transitLocation ?? .init(galaxy: encounter.galaxy, system: encounter.system)
  }
  var valid: Bool {
    PackValidation.localID(alias) && body.missionActorID == identity
      && body.position.finite && body.position.length <= 1e9 && body.orientation.validRotation
      && body.energy.isFinite && (0...10_000_000).contains(body.energy)
      && Self.npcValid(body)
      && body.rotation.isFinite && body.rotationRate.isFinite && (0...32).contains(body.missiles)
      && (-1..<1_000_000_000).contains(body.id)
      && (presence != .destroyed || body.energy == 0)
  }

  @inline(never)
  private static func npcValid(_ body: borrowing SpaceBody) -> Bool {
    if case .none = body.scriptNPC { return true }
    guard body.scriptNPC!.valid,
      body.energy <= body.scriptNPC!.fit.definition.energy,
      body.missiles <= body.scriptNPC!.fit.definition.missiles
    else { return false }
    return true
  }
}
public struct ScriptOwnedEncounter: Codable, Sendable, Equatable {
  public let id: String
  public let galaxy: Int
  public let system: Int
  public var admitted = false
  public var actors: [String: ScriptOwnedActor]
  var legacyProvenance: LegacyMissionEncounterProvenance? = nil
  public var destroyed: Bool {
    admitted && !actors.isEmpty && actors.values.allSatisfy { $0.presence == .destroyed }
  }
  var valid: Bool {
    PackValidation.localID(id) && (0..<8).contains(galaxy) && (0...256).contains(system)
      && (1...128).contains(actors.count)
      && Set(actors.values.map(\.identity)).count == actors.count
      && actorsValid()
      && (admitted
        ? actors.values.allSatisfy { $0.presence != .prepared && $0.body.id >= 0 }
        : actors.values.allSatisfy { $0.presence == .prepared && $0.transitLocation == nil })
  }
  @inline(never)
  private func actorsValid() -> Bool {
    for index in actors.indices {
      guard Self.actorValid(actors.values[index], key: actors.keys[index]) else { return false }
    }
    return true
  }

  @inline(never)
  private static func actorValid(_ actor: borrowing ScriptOwnedActor, key: String) -> Bool {
    guard key == actor.alias else { return false }
    return actor.valid
  }
}

/// Unencoded authority from the actual encounter handler or installed retained record.
enum MissionActorAdmissionMode: Sendable, Equatable { case prepared, retained }

enum MissionActorAdmissionAuthority: Sendable, Equatable {
  case missionHandler
  case worldJob(identity: UUID, pulse: UInt64)
  case retained
  case transit(UUID)
  case inductionArkBerth(UUID)
  case inductionRescueBerth(UUID)
}

struct MissionActorAdmissionPart: Sendable {
  let alias: String?
  let componentID: UUID?
  let energy: Double
  let maximumEnergy: Double
  let solid: Bool
  /// Measured vertices in actor-local coordinates, with authored transforms already applied.
  let mesh: Mesh

  fileprivate init(
    alias: String?, componentID: UUID?, energy: Double, maximumEnergy: Double,
    solid: Bool, mesh: Mesh
  ) {
    self.alias = alias
    self.componentID = componentID
    self.energy = energy
    self.maximumEnergy = maximumEnergy
    self.solid = solid
    self.mesh = mesh
  }
}

struct MissionActorAdmissionTemplate: Sendable {
  let actorID: UUID
  let alias: String
  let presence: ScriptActorPresence
  /// Station-relative condition. The old scene ID and physical identity are stripped.
  let canonicalBody: SpaceBody
  let maximumHullEnergy: Double
  let declaredHostile: Bool
  let parts: [MissionActorAdmissionPart]
  let minimum: Vector3
  let maximum: Vector3
  let radius: Double
  let nativeUnits: Int
  /// Condition only: historical NPC targets/attribution must be rebound by native policy.
  let retainedNativeCondition: NPCState?
  let retainedNativeVelocity: Vector3?
  let retainedNativeLaserCooldown: Double?

  fileprivate init(
    actor: ScriptOwnedActor, canonicalBody: SpaceBody, maximumHullEnergy: Double,
    declaredHostile: Bool, parts: [MissionActorAdmissionPart], minimum: Vector3,
    maximum: Vector3, radius: Double, nativeUnits: Int, initialNativeCondition: NPCState? = nil
  ) {
    actorID = actor.identity
    alias = actor.alias
    presence = actor.presence
    self.canonicalBody = canonicalBody
    self.maximumHullEnergy = maximumHullEnergy
    self.declaredHostile = declaredHostile
    self.parts = parts
    self.minimum = minimum
    self.maximum = maximum
    self.radius = radius
    self.nativeUnits = nativeUnits
    retainedNativeCondition = actor.body.physical?.npc ?? initialNativeCondition
    retainedNativeVelocity = actor.body.physical?.velocity
    retainedNativeLaserCooldown = actor.body.physical?.laserCooldown
  }
}

struct MissionActorAdmissionSource: Sendable {
  let mode: MissionActorAdmissionMode
  let authority: MissionActorAdmissionAuthority
  let instanceID: UUID
  let instanceRevision: UInt64
  let packDigest: String
  let definition: String
  let version: String
  let encounterID: String
  let system: SystemIdentity
  let profile: String
  /// Exact pre-admission retention snapshot, for a prevalidated native retention patch.
  let retention: ScriptOwnedEncounter
  let actors: [MissionActorAdmissionTemplate]
  fileprivate let installedBaseEncounter: ScriptOwnedEncounter?
  fileprivate let transitContext: OriginalWorldJourneyContext?

  fileprivate init(
    mode: MissionActorAdmissionMode, authority: MissionActorAdmissionAuthority,
    instance: borrowing ScriptInstance, pack: borrowing ScriptPack, encounter: ScriptOwnedEncounter,
    definition: borrowing ScriptEncounterDefinition, actors: [MissionActorAdmissionTemplate],
    installedBaseEncounter: ScriptOwnedEncounter?,
    transitContext: OriginalWorldJourneyContext? = nil
  ) {
    self.mode = mode
    self.authority = authority
    instanceID = instance.id
    instanceRevision = instance.revision
    packDigest = pack.digest
    self.definition = instance.definition
    version = instance.version
    encounterID = encounter.id
    system =
      transitContext?.route.destination.location ?? actors.first.flatMap { template in
        encounter.actors[template.alias]?.transitLocation
      } ?? .init(galaxy: encounter.galaxy, system: encounter.system)
    profile = definition.profile
    retention = encounter
    self.actors = actors
    self.installedBaseEncounter = installedBaseEncounter
    self.transitContext = transitContext
  }
}

/// Prepared before native publication; the owned adapter applies it without lookup or failure.
struct MissionActorRetentionPatch: Sendable {
  let instanceID: UUID
  let instanceRevision: UInt64
  let packDigest: String
  let encounterID: String
  let expectedEncounter: ScriptOwnedEncounter
  let updatedEncounter: ScriptOwnedEncounter
  private let definition: String
  private let version: String

  fileprivate init(source: MissionActorAdmissionSource, updated: ScriptOwnedEncounter) {
    instanceID = source.instanceID
    instanceRevision = source.instanceRevision
    packDigest = source.packDigest
    encounterID = source.encounterID
    expectedEncounter = source.retention
    updatedEncounter = updated
    definition = source.definition
    version = source.version
  }

  func matches(_ instance: ScriptInstance) -> Bool {
    instance.id == instanceID && instance.revision == instanceRevision
      && instance.definition == definition && instance.version == version
      && instance.digest == packDigest && instance.ownedEncounters[encounterID] == expectedEncounter
  }

  /// Stage an entire selected instance before native commit, for direct postcommit publication.
  func preparingInstance(_ instance: ScriptInstance) throws -> ScriptInstance {
    guard matches(instance) else {
      throw MissionPackError("Actor retention changed before admission.")
    }
    var staged = instance
    apply(to: &staged)
    return staged
  }

  fileprivate func apply(to instance: inout ScriptInstance) {
    instance.ownedEncounters[encounterID] = updatedEncounter
  }
}

extension MissionActorAdmissionSource {
  /// Only the native preparation supplies new scene addresses; no historical address is reused.
  func prepareRetentionPatch(sceneBodyIDs: [UUID: Int], nativeBodies: [SpaceBody] = []) throws
    -> MissionActorRetentionPatch
  {
    var eligible = Set<UUID>()
    for index in actors.indices {
      if actors[index].presence != .destroyed, actors[index].canonicalBody.energy > 0 {
        eligible.insert(actors[index].actorID)
      }
    }
    guard Set(sceneBodyIDs.keys).isSubset(of: eligible),
      Set(sceneBodyIDs.values).count == sceneBodyIDs.count,
      sceneBodyIDs.values.allSatisfy({ (1..<1_000_000_000).contains($0) }),
      mode != .prepared || Set(sceneBodyIDs.keys) == eligible
    else { throw MissionPackError("Native actor addresses must cover the exact eligible cohort.") }
    var updated = retention
    for index in actors.indices {
      let alias = actors[index].alias
      let actorID = actors[index].actorID
      guard let bodyID = sceneBodyIDs[actorID] else { continue }
      guard var actor = updated.actors[alias], actor.identity == actorID else {
        throw MissionPackError("Actor retention mapping changed before native admission.")
      }
      switch authority {
      case .transit:
        actor.body = actors[index].canonicalBody
        actor.transitLocation = system
      case .inductionArkBerth, .inductionRescueBerth:
        actor.body = actors[index].canonicalBody
      default: break
      }
      if definition == NativeGlassMeridian.stateID, packDigest == NativeGlassMeridian.digest,
        encounterID == NativeC01Surveyor.encounter
      {
        guard
          let admitted = nativeBodies.first(where: {
            $0.missionActorID == actorID && $0.missionInstanceID == instanceID && $0.id == bodyID
          }), let physical = admitted.physical,
          NativeC01Surveyor.passiveFit(admitted),
          NativeC01Surveyor.nativeValid(
            physical, recorder: actor.alias == NativeC01Surveyor.aliases[1])
        else { throw NativeMissionActorAdmissionError.invalidCondition }
        // These are the actual staged native addresses and conserved inertia, before any commit.
        actor.body.physical = physical
      }
      actor.body.id = bodyID
      actor.presence = .present
      updated.actors[alias] = actor
    }
    if mode == .prepared {
      updated.admitted = true
      updated.legacyProvenance = updated.legacyProvenance?.afterAdmission()
    }
    guard updated.valid else { throw MissionPackError("Native actor retention patch is invalid.") }
    return .init(source: self, updated: updated)
  }
}

extension Game {
  /// End the computed Commander receiver's lifetime before nested admission starts.
  /// Every call reads the current Game and returns only immutable COW/scalar source facts.
  @inline(never)
  private func currentMissionActorAdmissionSourceValues() -> (
    instances: [UUID: ScriptInstance], geometry: [String: ShipDesign], galaxy: Int, system: Int
  ) {
    retainedMissionActorAdmissionSourceValues()
  }

  @inline(never)
  private func currentMissionActorAdmissionOwner(_ id: UUID) -> MissionActorAdmissionOwnerFacts? {
    withReadOnlyScriptState { state in
      guard let owner = state.instances[id] else { return nil }
      return (
        owner.id, owner.definition, owner.version, owner.digest, owner.revision, owner.outcome
      )
    }
  }

  /// A normal command still reads actual installed retention; its full-owner temporary returns here.
  @inline(never)
  private func currentMissionActorAdmissionInstalledEncounter(
    instanceID: UUID, encounterID: String
  ) -> ScriptOwnedEncounter? {
    withReadOnlyScriptState { $0.instances[instanceID]?.ownedEncounters[encounterID] }
  }

  @inline(never)
  private func currentMissionActorAdmissionWorldJob(_ id: UUID) -> ScriptWorldJob? {
    retainedMissionActorAdmissionWorldJob(id)
  }

  /// Rechecks a sealed source against actual installed authority without a caller snapshot.
  /// Prepared retention stays private to its adapter and must also match the staged patch.
  @inline(never)
  func validateMissionActorAdmissionSource(_ source: MissionActorAdmissionSource) throws {
    let currentInputs = currentMissionActorAdmissionSourceValues()
    let snapshot = try validatedMissionActorAdmissionOwner(
      source, instances: currentInputs.instances)
    // No mutation or suspension occurs between this actual-owner validation and its refresh.
    // Reuse only this invocation-local snapshot; it is never stored in an admission plan.
    let refreshed = try Self.refreshMissionActorAdmissionSource(
      original: self, source: source, owner: snapshot.owner, pack: snapshot.pack,
      installedOwner: snapshot,
      galaxy: currentInputs.galaxy, system: currentInputs.system)
    guard refreshed.profile == source.profile else {
      throw MissionPackError("Actor admission profile changed before publication.")
    }
  }

  @inline(never)
  private static func refreshMissionActorAdmissionSource(
    original: borrowing Game, source: borrowing MissionActorAdmissionSource,
    owner: borrowing ScriptInstance, pack: borrowing ScriptPack,
    installedOwner: MissionActorAdmissionOwnerSnapshot, galaxy: Int, system: Int
  ) throws -> MissionActorAdmissionSource {
    switch source.mode {
    case .retained:
      if case .transit(let leg) = source.authority, let context = source.transitContext {
        return try original.transitMissionActorAdmissionSource(leg, context: context)
      }
      if case .inductionArkBerth(let job) = source.authority {
        return try original.inductionArkBerthAdmissionSource(job)
      }
      if case .inductionRescueBerth(let job) = source.authority {
        return try original.inductionRescueBerthAdmissionSource(job)
      }
      guard source.authority == .retained,
        owner.ownedEncounters[source.encounterID] == source.retention,
        source.system == .init(galaxy: galaxy, system: system)
      else { throw MissionPackError("Retained actor admission source changed before publication.") }
      return try original.sealMissionActorAdmissionSource(
        mode: .retained, authority: .retained, pack: pack, state: owner,
        encounter: source.retention, installedOwner: installedOwner)
    case .prepared:
      switch source.authority {
      case .missionHandler:
        return try original.preparedMissionActorAdmissionSource(
          pack: pack, state: owner, encounter: source.retention, installedOwner: installedOwner)
      case .worldJob(let identity, let pulse):
        return try original.preparedMissionActorAdmissionSource(
          pack: pack, state: owner, encounter: source.retention,
          worldJob: identity, pulse: pulse, installedOwner: installedOwner)
      case .retained, .transit, .inductionArkBerth, .inductionRescueBerth:
        throw MissionPackError("A prepared cohort cannot substitute retained admission authority.")
      }
    }
  }

  /// Finish installed-owner lookup/comparison temporaries before nested source refresh.
  @inline(never)
  private func validatedMissionActorAdmissionOwner(
    _ source: MissionActorAdmissionSource, instances: [UUID: ScriptInstance]
  ) throws -> MissionActorAdmissionOwnerSnapshot {
    try MissionActorAdmissionOwnerSnapshot(original: self, source: source, instances: instances)
  }

  /// Reads only actual installed retained ownership; there is no caller-supplied state/body path.
  func retainedMissionActorAdmissionSources() throws -> [MissionActorAdmissionSource] {
    let instances = retainedMissionActorInstances
    var sources: [MissionActorAdmissionSource] = []
    for id in instances.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let instance = instances[id], let pack = scriptPack(for: instance)
      else { continue }
      guard instance.id == id else {
        throw MissionPackError("Retained actor instance key mismatch.")
      }
      for key in instance.ownedEncounters.keys.sorted() {
        guard let encounter = instance.ownedEncounters[key], encounter.admitted,
          encounter.actors.values.contains(where: {
            $0.location(in: encounter) == missionActorAdmissionSystemIdentity
              && ![.inTransit, .arrivalPending].contains($0.presence)
          })
        else { continue }
        guard encounter.id == key else {
          throw MissionPackError("Retained encounter key mismatch.")
        }
        sources.append(
          try sealMissionActorAdmissionSource(
            mode: .retained, authority: .retained, pack: pack, state: instance,
            encounter: encounter))
      }
    }
    return sources
  }

  /// The destination adapter reuses the whole native admission transaction. Its input is an
  /// installed due journey, never a caller-built body, synthetic arrival or source-system restore.
  func transitMissionActorAdmissionSource(_ legID: UUID, context: OriginalWorldJourneyContext)
    throws
    -> MissionActorAdmissionSource
  {
    guard let leg = withReadOnlyScriptState({ $0.wormholeTransit?.legs[legID] }),
      leg.valid,
      [.inTransit, .arrivalPending].contains(leg.phase), let departure = leg.departure,
      let due = leg.dueAt, withReadOnlyScriptState({ $0.calendarSeconds }) >= due,
      context.route == leg.route, context.matches(self, at: missionActorAdmissionSystemIdentity),
      missionActorAdmissionSystemIdentity == context.route.destination.location, !docked,
      let owner = withReadOnlyScriptState({ $0.instances[leg.instance] }),
      let pack = scriptPack(for: owner),
      let encounter = owner.ownedEncounters[leg.encounter],
      var actor = encounter.actors[leg.alias], actor.identity == leg.actor,
      [.inTransit, .arrivalPending].contains(actor.presence), actor.body == departure.body,
      !bodies.indices.contains(where: { bodies[$0].missionActorID == leg.actor }),
      let anchor = scriptAnchor
    else {
      throw MissionPackError(
        "Native transit arrival requires its exact due retained actor and destination world.")
    }
    let definition = try validateMissionActorAdmissionEncounter(
      mode: .retained, pack: pack, state: owner, encounter: encounter)
    guard let spec = definition.actors.first(where: { $0.id == leg.alias }) else {
      throw MissionPackError("The transit actor is no longer declared.")
    }
    let pose = withReadOnlyCommander { $0.flightSimulation.pose }
    actor.body.position = anchor.orientation.inverse(
      pose.shipPoint(context.route.exit.position) - anchor.position)
    actor.body.orientation = context.route.exit.orientation.relative(to: pose.orientation).relative(
      to: anchor.orientation)
    // The source-frame transit steering ends here. No local approach/escort arrival is emitted.
    actor.body.scriptNPC?.intent = nil
    if let velocity = departure.body.physical?.velocity {
      actor.body.scriptNPC?.velocity = anchor.orientation.inverse(pose.shipVector(velocity))
    }
    let template = try Self.missionActorAdmissionTemplate(
      actor, specification: spec, npcDefinitions: pack.manifest.npcs ?? [],
      installedModels: pack.models, geometry: withReadOnlyScriptState { $0.geometry },
      legacy: nil)
    return .init(
      mode: .retained, authority: .transit(legID), instance: owner, pack: pack,
      encounter: encounter, definition: definition, actors: [template],
      installedBaseEncounter: encounter, transitContext: context)
  }

  /// Called only by this file's validated prepared-encounter handler when native admission is wired.
  /// A world job supplies its actual UUID and pending pulse, never a Boolean authorization.
  private func preparedMissionActorAdmissionSource(
    pack: borrowing ScriptPack, state: borrowing ScriptInstance, encounter: ScriptOwnedEncounter,
    worldJob: UUID? = nil, pulse: UInt64? = nil,
    installedOwner: MissionActorAdmissionOwnerSnapshot? = nil
  ) throws -> MissionActorAdmissionSource {
    let installedEncounter: ScriptOwnedEncounter?
    if let installedOwner {
      installedEncounter = installedOwner.installedEncounter(encounter.id)
    } else {
      installedEncounter = currentMissionActorAdmissionInstalledEncounter(
        instanceID: state.id, encounterID: encounter.id)
    }
    guard installedEncounter?.admitted != true
    else {
      throw MissionPackError("An admitted retained cohort cannot become a fresh prepared source.")
    }
    let authority = try missionActorAdmissionAuthority(
      pack: pack, state: state, encounterID: encounter.id,
      galaxy: encounter.galaxy, system: encounter.system, worldJob: worldJob, pulse: pulse,
      installedOwner: installedOwner)
    return try sealMissionActorAdmissionSource(
      mode: .prepared, authority: authority, pack: pack, state: state, encounter: encounter,
      installedOwner: installedOwner)
  }

  private func missionActorAdmissionAuthority(
    pack: borrowing ScriptPack, state: borrowing ScriptInstance, encounterID: String,
    galaxy: Int, system: Int, worldJob: UUID?, pulse: UInt64?,
    installedOwner: MissionActorAdmissionOwnerSnapshot? = nil
  ) throws -> MissionActorAdmissionAuthority {
    let storedFacts: MissionActorAdmissionOwnerFacts?
    if let installedOwner {
      storedFacts = installedOwner.authorityFacts
    } else {
      storedFacts = currentMissionActorAdmissionOwner(state.id)
    }
    guard let stored = storedFacts, stored.id == state.id,
      stored.definition == state.definition, stored.version == state.version,
      stored.digest == state.digest, stored.revision == state.revision
    else { throw MissionPackError("Prepared actors require the actual command candidate owner.") }
    guard state.definition == pack.manifest.stateID, state.version == pack.manifest.version,
      state.digest == pack.digest,
      scriptPacks.contains(where: {
        $0.manifest.stateID == stored.definition && $0.manifest.version == stored.version
          && $0.digest == stored.digest
      })
    else { throw MissionPackError("Prepared authority requires its exact installed content.") }
    let authority: MissionActorAdmissionAuthority
    if let worldJob, let pulse {
      guard let job = currentMissionActorAdmissionWorldJob(worldJob), job.identity == worldJob,
        job.origin == state.id, job.status == .active, job.suspension == nil,
        job.pending?.sequence == pulse, job.valid, worldJobOwnerAlive(job),
        pack.manifest.worldJobs?.contains(job.definition) == true,
        job.definition.controlledEncounters?.contains(encounterID) == true,
        job.definition.galaxy == galaxy, job.definition.system == system
      else { throw MissionPackError("The actual pending world job must control this encounter.") }
      authority = .worldJob(identity: worldJob, pulse: pulse)
    } else {
      guard worldJob == nil, pulse == nil, state.outcome == .active, stored.outcome == .active
      else {
        throw MissionPackError("Prepared actors require an active mission command authority.")
      }
      authority = .missionHandler
    }
    return authority
  }

  private func sealMissionActorAdmissionSource(
    mode: MissionActorAdmissionMode, authority: MissionActorAdmissionAuthority,
    pack: borrowing ScriptPack, state: borrowing ScriptInstance, encounter: ScriptOwnedEncounter,
    installedOwner: MissionActorAdmissionOwnerSnapshot? = nil
  ) throws -> MissionActorAdmissionSource {
    let definition = try validateMissionActorAdmissionEncounter(
      mode: mode, pack: pack, state: state, encounter: encounter)
    return try constructMissionActorAdmissionSource(
      mode: mode, authority: authority, pack: pack, state: state, encounter: encounter,
      definition: definition, installedOwner: installedOwner)
  }

  /// Finish full record validation before any template-construction frame becomes active.
  private func validateMissionActorAdmissionEncounter(
    mode: MissionActorAdmissionMode, pack: borrowing ScriptPack, state: borrowing ScriptInstance,
    encounter: ScriptOwnedEncounter
  ) throws -> ScriptEncounterDefinition {
    let ownerDefinition = state.definition
    let ownerVersion = state.version
    let ownerDigest = state.digest
    guard state.definition == pack.manifest.stateID, state.version == pack.manifest.version,
      state.digest == pack.digest,
      scriptPacks.contains(where: {
        $0.manifest.stateID == ownerDefinition && $0.manifest.version == ownerVersion
          && $0.digest == ownerDigest
      }),
      encounter.valid,
      let definition = NativeC01Surveyor.encounterDefinition(
        pack: pack, state: state, id: encounter.id),
      definition.valid, definition.galaxy == encounter.galaxy,
      definition.system == encounter.system,
      Set(definition.actors.map(\.id)) == Set(encounter.actors.keys),
      mode == .retained ? encounter.admitted : !encounter.admitted,
      pack.manifest.capabilities.contains(
        definition.profile == "classic-local-freeze-v1"
          ? "classic-encounters-v2" : "profiled-encounters-v2")
    else { throw MissionPackError("The actor source must match its exact installed encounter.") }
    return definition
  }

  /// The encounter and every actor/NPC were validated above on this same immutable value.
  private func constructMissionActorAdmissionSource(
    mode: MissionActorAdmissionMode, authority: MissionActorAdmissionAuthority,
    pack: borrowing ScriptPack, state: borrowing ScriptInstance,
    encounter: borrowing ScriptOwnedEncounter, definition: borrowing ScriptEncounterDefinition,
    installedOwner: MissionActorAdmissionOwnerSnapshot? = nil
  ) throws -> MissionActorAdmissionSource {
    let currentInputs = currentMissionActorAdmissionSourceValues()
    let installedEncounter: ScriptOwnedEncounter?
    if let installedOwner {
      installedEncounter = installedOwner.installedEncounter(encounter.id)
    } else {
      installedEncounter = currentMissionActorAdmissionInstalledEncounter(
        instanceID: state.id, encounterID: encounter.id)
    }
    try Self.validateMissionActorAdmissionLegacy(
      state: state, encounter: encounter, installedEncounter: installedEncounter,
      legacy: encounter.legacyProvenance)
    let templates = try Self.constructMissionActorAdmissionTemplates(
      original: self, mode: mode, pack: pack, state: state,
      encounter: encounter, definition: definition,
      geometry: currentInputs.geometry)
    return Self.finishMissionActorAdmissionSource(
      mode: mode, authority: authority, pack: pack, state: state, encounter: encounter,
      definition: definition, templates: consume templates, installedEncounter: installedEncounter)
  }

  /// Reserve template-construction values only after the actual Game facts have been read.
  @inline(never)
  private static func constructMissionActorAdmissionTemplates(
    original: borrowing Game, mode: MissionActorAdmissionMode, pack: borrowing ScriptPack,
    state: borrowing ScriptInstance, encounter: borrowing ScriptOwnedEncounter,
    definition: borrowing ScriptEncounterDefinition,
    geometry: borrowing [String: ShipDesign]
  ) throws -> [MissionActorAdmissionTemplate] {
    let legacy = encounter.legacyProvenance
    var templates: [MissionActorAdmissionTemplate] = []
    for spec in definition.actors.sorted(by: { $0.id < $1.id }) {
      var actor = try Self.validatedMissionActorAdmissionActor(
        spec, encounter: encounter, instanceID: state.id, packDigest: pack.digest, legacy: legacy,
        glassMeridian: state.savedGlassMeridian)
      if mode == .retained {
        if actor.location(in: encounter) != original.missionActorAdmissionSystemIdentity
          || [.inTransit, .arrivalPending].contains(actor.presence)
        {
          continue
        }
        actor = try original.isolationWorkRetainedActor(actor, in: state)
      }
      let template = try Self.missionActorAdmissionTemplate(
        actor, specification: spec,
        npcDefinitions: NativeC01Surveyor.profiles(pack: pack, state: state),
        installedModels: NativeC01Surveyor.designs(pack: pack, state: state), geometry: geometry,
        legacy: legacy?.actors[spec.id],
        initialNativeCondition: mode == .prepared
          ? try Self.preparedNativeMissionResources(state: state, actor: actor) : nil)
      if mode == .prepared {
        try Self.validatePreparedMissionActorCondition(
          actor, spec: spec, template: template, legacy: legacy,
          mechanicallyDisabled: NativeInductionCrewLogPack.mechanicallyDisabled(
            actor, state: state),
          preparedOrientation: NativeC01Surveyor.preparedOrientation(state: state, actor: actor)
        )
      }
      templates.append(template)
    }
    return templates
  }

  private static func preparedNativeMissionResources(
    state: borrowing ScriptInstance, actor: ScriptOwnedActor
  ) throws -> NPCState? {
    if NativeIsolationWorkPack.marked(state) {
      return try NativeIsolationWorkPack.initialResources(state: state, actor: actor)
    }
    if NativeInductionUtilityPack.marked(state) {
      return try NativeInductionUtilityPack.initialResources(state: state, actor: actor)
    }
    if NativeInductionCrewLogPack.marked(state) {
      return try NativeInductionCrewLogPack.initialResources(state: state, actor: actor)
    }
    return try NativeInductionArkPack.initialCondition(state: state, actor: actor)
  }

  /// Construct the owned result only after per-actor validation and template frames have returned.
  @inline(never)
  private static func finishMissionActorAdmissionSource(
    mode: MissionActorAdmissionMode, authority: MissionActorAdmissionAuthority,
    pack: borrowing ScriptPack, state: borrowing ScriptInstance,
    encounter: borrowing ScriptOwnedEncounter, definition: borrowing ScriptEncounterDefinition,
    templates: consuming [MissionActorAdmissionTemplate], installedEncounter: ScriptOwnedEncounter?
  ) -> MissionActorAdmissionSource {
    return .init(
      mode: mode, authority: authority, instance: state, pack: pack,
      encounter: copy encounter, definition: definition, actors: consume templates,
      installedBaseEncounter: installedEncounter)
  }

  /// Finish full legacy comparison before any per-actor construction frame starts.
  @inline(never)
  private static func validateMissionActorAdmissionLegacy(
    state: borrowing ScriptInstance, encounter: borrowing ScriptOwnedEncounter,
    installedEncounter: ScriptOwnedEncounter?, legacy: borrowing LegacyMissionEncounterProvenance?
  ) throws {
    if let legacy = copy legacy {
      guard legacy.matches(owner: state, encounter: encounter),
        installedEncounter == copy encounter
      else {
        throw MissionPackError("Historical actor provenance differs from its installed owner.")
      }
    }
  }

  /// Return the same selected actor after its identity/body-read temporaries have ended.
  @inline(never)
  private static func validatedMissionActorAdmissionActor(
    _ spec: ScriptActorDefinition, encounter: ScriptOwnedEncounter, instanceID: UUID,
    packDigest: String, legacy: LegacyMissionEncounterProvenance?,
    glassMeridian: NativeGlassMeridianState? = nil
  ) throws -> ScriptOwnedActor {
    guard let actor = encounter.actors[spec.id], actor.alias == spec.id,
      legacy?.actors[spec.id]?.identity == actor.identity
        || actor.identity
          == ScriptIdentity.uuid(
            "script-actor-v2:\(instanceID):\(packDigest):\(encounter.id):\(spec.id)")
        || NativeGlassMeridian.authorizesReplacement(
          glassMeridian, actor: actor,
          encounter: encounter.id, instance: instanceID, packDigest: packDigest),
      actor.body.missionInstanceID == instanceID, actor.body.scriptShot == nil
    else { throw MissionPackError("Actor source identity or canonical condition is invalid.") }
    return actor
  }

  /// These stock-only temporaries are needed after measured template construction returns.
  /// Retained actors keep their existing spent condition and never enter this phase.
  @inline(never)
  private static func validatePreparedMissionActorCondition(
    _ actor: ScriptOwnedActor, spec: ScriptActorDefinition,
    template: MissionActorAdmissionTemplate, legacy: LegacyMissionEncounterProvenance?,
    mechanicallyDisabled: Bool = false, preparedOrientation: Basis3? = nil
  ) throws {
    try validatePreparedMissionActorPose(
      actor, spec: spec, orientation: preparedOrientation ?? Basis3())
    if legacy != nil {
      try validatePreparedMissionActorLegacy(actor, spec: spec, legacy: legacy)
    } else {
      try validatePreparedMissionActorEnergy(
        actor, template: template, mechanicallyDisabled: mechanicallyDisabled)
      if let resources = preparedMissionActorNPCResources(actor) {
        try validatePreparedMissionActorNPCResources(resources)
      } else {
        try validatePreparedMissionActorClassicResources(actor)
      }
    }
  }

  @inline(never)
  private static func validatePreparedMissionActorPose(
    _ actor: borrowing ScriptOwnedActor, spec: ScriptActorDefinition, orientation: Basis3
  ) throws {
    guard actor.body.id == -1, actor.body.physical == nil,
      actor.body.position == .init(spec.x, spec.y, spec.z),
      actor.body.orientation == orientation, actor.body.hostile == spec.hostile
    else {
      throw MissionPackError(
        "A prepared actor must retain its actual authored initial condition.")
    }
  }

  @inline(never)
  private static func validatePreparedMissionActorLegacy(
    _ actor: borrowing ScriptOwnedActor, spec: ScriptActorDefinition,
    legacy: LegacyMissionEncounterProvenance?
  ) throws {
    guard legacy?.actors[spec.id]?.prepared == (copy actor) else {
      throw MissionPackError(
        "Prepared historical condition differs from its imported snapshot.")
    }
  }

  @inline(never)
  private static func validatePreparedMissionActorEnergy(
    _ actor: borrowing ScriptOwnedActor, template: borrowing MissionActorAdmissionTemplate,
    mechanicallyDisabled: Bool = false
  ) throws {
    guard actor.body.energy == template.maximumHullEnergy,
      template.parts.allSatisfy({ part in
        mechanicallyDisabled && part.alias == "drive"
          ? part.energy == 0 && !part.solid : part.energy == part.maximumEnergy
      })
    else {
      throw MissionPackError(
        "A prepared actor must retain its actual authored initial condition.")
    }
  }

  private struct PreparedMissionActorNPCResources: Sendable {
    let npc: ScriptNPCState
    let missiles: Int
    let ecmEnabled: Bool
  }

  /// End body-read temporaries before validating only the immutable NPC resource facts.
  @inline(never)
  private static func preparedMissionActorNPCResources(
    _ actor: borrowing ScriptOwnedActor
  ) -> PreparedMissionActorNPCResources? {
    guard let npc = actor.body.scriptNPC else { return nil }
    return .init(npc: npc, missiles: actor.body.missiles, ecmEnabled: actor.body.ecmEnabled)
  }

  @inline(never)
  private static func validatePreparedMissionActorNPCResources(
    _ resources: borrowing PreparedMissionActorNPCResources
  ) throws {
    guard preparedMissionActorNPCScalarsArePristine(resources),
      preparedMissionActorGunsArePristine(resources.npc.guns),
      preparedMissionActorComponentGunsArePristine(resources.npc.components)
    else {
      throw MissionPackError(
        "Prepared NPC resources cannot substitute spent retained state.")
    }
  }

  @inline(never)
  private static func preparedMissionActorNPCScalarsArePristine(
    _ resources: borrowing PreparedMissionActorNPCResources
  ) -> Bool {
    let npc = resources.npc
    guard npc.shots == 0, npc.fuel == npc.fit.definition.fuel,
      npc.velocity == .init(0, 0, 0),
      resources.missiles == npc.fit.definition.missiles,
      resources.ecmEnabled == npc.fit.definition.ecm
    else { return false }
    return true
  }

  @inline(never)
  private static func preparedMissionActorGunsArePristine(
    _ guns: borrowing [String: ScriptNPCGunState]
  ) -> Bool {
    guns.values.allSatisfy({ $0 == ScriptNPCGunState() })
  }

  @inline(never)
  private static func preparedMissionActorComponentGunsArePristine(
    _ components: borrowing [String: ScriptNPCComponentState]
  ) -> Bool {
    components.values.allSatisfy({
      $0.guns.values.allSatisfy { $0 == ScriptNPCGunState() }
    })
  }

  @inline(never)
  private static func validatePreparedMissionActorClassicResources(
    _ actor: borrowing ScriptOwnedActor
  ) throws {
    guard actor.body.missiles == actor.body.hull.navalMissiles,
      actor.body.ecmEnabled == actor.body.hull.hasECM
    else {
      throw MissionPackError(
        "Prepared classic stock differs from its actual hull defaults.")
    }
  }

  /// Uses the current invocation's immutable dictionaries; no Game or interpreter is captured.
  @inline(never)
  private static func measuredMissionActorAdmissionMesh(
    _ reference: String, modelHashes: [String: String], installedModels: [String: ShipDesign],
    geometry: [String: ShipDesign], scale: Double, offset: Vector3, pose: Basis3
  ) throws -> Mesh {
    let installed = try validatedMissionActorAdmissionGeometry(
      reference, modelHashes: modelHashes, installedModels: installedModels, geometry: geometry)
    return transformedMissionActorAdmissionMesh(installed, scale: scale, offset: offset, pose: pose)
  }

  /// Keep the full installed-design equality and validity frame out of mesh transformation.
  @inline(never)
  private static func validatedMissionActorAdmissionGeometry(
    _ reference: String, modelHashes: [String: String], installedModels: [String: ShipDesign],
    geometry: [String: ShipDesign]
  ) throws -> ShipDesign {
    guard let digest = modelHashes[reference], let installed = installedModels[reference],
      geometry[digest] == installed, ScriptPackLibrary.scriptGeometryValid(installed)
    else { throw MissionPackError("Exact admitted NPC geometry is unavailable or changed.") }
    return installed
  }

  @inline(never)
  private static func transformedMissionActorAdmissionMesh(
    _ installed: ShipDesign, scale: Double, offset: Vector3, pose: Basis3
  ) -> Mesh {
    let raw: Mesh
    if installed.source.hasSuffix("; C01 mission-only 65m fore-aft uniform calibration"),
      let geometry = try? NativeC01SurveyorGeometry.harrier.get(), installed == geometry.design
    {
      raw = geometry.collision
    } else {
      raw = installed.rawMesh
    }
    return Mesh(
      vertices: raw.vertices.map { offset + pose.apply($0 * scale) }, faces: raw.faces,
      preserveWinding: true)
  }

  /// Private to this invocation's declaration validation and subsequent construction.
  private enum MissionActorAdmissionFit: Sendable {
    case npc(ScriptNPCState, ScriptNPCDefinition)
    case classic(Hull)
  }

  @inline(never)
  private static func missionActorAdmissionTemplate(
    _ actor: ScriptOwnedActor, specification: ScriptActorDefinition,
    npcDefinitions: [ScriptNPCDefinition], installedModels: [String: ShipDesign],
    geometry: [String: ShipDesign], legacy: LegacyMissionActorProvenance?,
    initialNativeCondition: NPCState? = nil
  ) throws -> MissionActorAdmissionTemplate {
    let fit = try validateMissionActorAdmissionFit(
      actor, specification: specification, npcDefinitions: npcDefinitions)
    return try constructMissionActorAdmissionTemplate(
      actor, specification: specification, fit: fit, installedModels: installedModels,
      geometry: geometry, legacy: legacy, initialNativeCondition: initialNativeCondition)
  }

  /// Full structural equality finishes before any mesh, bounds or canonical-body frame starts.
  @inline(never)
  private static func validateMissionActorAdmissionFit(
    _ actor: ScriptOwnedActor, specification: ScriptActorDefinition,
    npcDefinitions: [ScriptNPCDefinition]
  ) throws -> MissionActorAdmissionFit {
    if let npcID = specification.npc {
      guard actor.body.hull == .cobra, let npc = actor.body.scriptNPC,
        let definition = npcDefinitions.first(where: { $0.id == npcID }),
        definition == npc.fit.definition
      else { throw MissionPackError("Retained NPC fit differs from its actual declaration.") }
      return .npc(npc, definition)
    } else {
      guard let hull = specification.hull, actor.body.hull == hull, actor.body.scriptNPC == nil
      else {
        throw MissionPackError("Retained classic hull differs from its actual declaration.")
      }
      return .classic(hull)
    }
  }

  /// Uses only the exact selected fit returned by the immediately preceding validation phase.
  @inline(never)
  private static func constructMissionActorAdmissionTemplate(
    _ actor: ScriptOwnedActor, specification: ScriptActorDefinition,
    fit: MissionActorAdmissionFit, installedModels: [String: ShipDesign],
    geometry: [String: ShipDesign], legacy: LegacyMissionActorProvenance?,
    initialNativeCondition: NPCState? = nil
  ) throws -> MissionActorAdmissionTemplate {
    let constructed = try constructMissionActorAdmissionParts(
      actor, fit: fit, installedModels: installedModels, geometry: geometry, legacy: legacy)
    return try finalizeMissionActorAdmissionTemplate(
      actor, specification: specification, parts: constructed.parts,
      maximumEnergy: constructed.maximumEnergy, initialNativeCondition: initialNativeCondition)
  }

  private struct MissionActorAdmissionParts: Sendable {
    let parts: [MissionActorAdmissionPart]
    let maximumEnergy: Double
  }

  /// Parts and their full geometry checks finish before bounds/canonical-body storage is needed.
  @inline(never)
  private static func constructMissionActorAdmissionParts(
    _ actor: ScriptOwnedActor, fit: MissionActorAdmissionFit,
    installedModels: [String: ShipDesign], geometry: [String: ShipDesign],
    legacy: LegacyMissionActorProvenance?
  ) throws -> MissionActorAdmissionParts {
    var parts: [MissionActorAdmissionPart] = []
    let maximumEnergy: Double
    switch fit {
    case .npc(let npc, let definition):
      maximumEnergy = definition.energy
      parts.append(
        .init(
          alias: nil, componentID: nil, energy: actor.body.energy, maximumEnergy: maximumEnergy,
          solid: true,
          mesh: try measuredMissionActorAdmissionMesh(
            definition.model, modelHashes: npc.fit.models, installedModels: installedModels,
            geometry: geometry, scale: definition.scale, offset: .init(0, 0, 0), pose: Basis3())))
      for spec in definition.components ?? [] {
        guard let state = npc.components[spec.id],
          legacy?.components[spec.id] == state.identity
            || state.identity
              == ScriptIdentity.uuid("script-component-v2:\(actor.identity):\(spec.id)")
        else { throw MissionPackError("Retained component identity differs from its owner.") }
        parts.append(
          .init(
            alias: spec.id, componentID: state.identity, energy: state.energy,
            maximumEnergy: spec.energy, solid: spec.solid,
            mesh: try measuredMissionActorAdmissionMesh(
              spec.model, modelHashes: npc.fit.models, installedModels: installedModels,
              geometry: geometry, scale: spec.scale * definition.scale,
              offset: spec.position * definition.scale, pose: spec.orientation)))
      }
    case .classic(let hull):
      maximumEnergy = hull.navalEnergy ?? 100
      parts.append(
        .init(
          alias: nil, componentID: nil, energy: actor.body.energy, maximumEnergy: maximumEnergy,
          solid: true, mesh: Mesh.hull(hull)))
    }
    return .init(parts: parts, maximumEnergy: maximumEnergy)
  }

  @inline(never)
  private static func finalizeMissionActorAdmissionTemplate(
    _ actor: ScriptOwnedActor, specification: ScriptActorDefinition,
    parts: [MissionActorAdmissionPart], maximumEnergy: Double, initialNativeCondition: NPCState?
  ) throws -> MissionActorAdmissionTemplate {
    guard actor.body.energy <= maximumEnergy,
      actor.body.physical?.npc?.resources?.valid ?? true,
      actor.body.physical?.velocity.finite ?? true,
      actor.body.physical.map({ $0.laserCooldown.isFinite && $0.laserCooldown >= 0 }) ?? true
    else { throw MissionPackError("Retained actor condition exceeds its actual source bounds.") }
    let solids = parts.filter { $0.solid && ($0.alias == nil || $0.energy > 0) }
    let vertices = solids.flatMap(\.mesh.vertices)
    guard let first = vertices.first,
      vertices.allSatisfy({ $0.finite && $0.length.isFinite }),
      parts.allSatisfy({ part in
        !part.mesh.faces.isEmpty
          && part.mesh.faces.allSatisfy {
            $0.count >= 3 && $0.allSatisfy(part.mesh.vertices.indices.contains)
          }
      })
    else { throw MissionPackError("Actor admission requires measured finite collision geometry.") }
    var minimum = first
    var maximum = first
    for vertex in vertices.dropFirst() {
      minimum = .init(min(minimum.x, vertex.x), min(minimum.y, vertex.y), min(minimum.z, vertex.z))
      maximum = .init(max(maximum.x, vertex.x), max(maximum.y, vertex.y), max(maximum.z, vertex.z))
    }
    var canonical = actor.body
    canonical.id = -1
    canonical.physical = nil
    canonical.destroyedByPlayer = nil
    canonical.navalTarget = false
    canonical.playerMissileTarget = nil
    canonical.enemyMissile = false
    canonical.missileSourceID = nil
    canonical.blackjackIdentity = nil
    canonical.blackjackRole = nil
    canonical.blackjackLaserCooldown = nil
    return .init(
      actor: actor, canonicalBody: canonical, maximumHullEnergy: maximumEnergy,
      declaredHostile: specification.hostile, parts: parts, minimum: minimum, maximum: maximum,
      radius: vertices.map(\.length).max() ?? 0, nativeUnits: solids.count,
      initialNativeCondition: initialNativeCondition)
  }
}

extension ScriptEncounterDefinition {
  static let classicHulls: Set<Hull> = [
    .cobra, .viper, .sidewinder, .constrictor, .thargoid, .thargon,
  ]
  var valid: Bool {
    PackValidation.localID(id) && (0..<8).contains(galaxy) && (0...256).contains(system)
      && ["classic-local-freeze-v1", "profiled-local-freeze-v1"].contains(profile)
      && (1...128).contains(actors.count)
      && Set(actors.map(\.id)).count == actors.count
      && actors.allSatisfy {
        PackValidation.localID($0.id)
          && (profile == "classic-local-freeze-v1"
            ? $0.hull.map(Self.classicHulls.contains) == true && $0.npc == nil
            : $0.hull == nil && $0.npc.map(PackValidation.localID) == true)
          && [$0.x, $0.y, $0.z].allSatisfy { $0.isFinite && abs($0) <= 1_000_000 }
      }
  }
}

public struct ScriptReferenceFrame: Codable, Sendable, Equatable {
  public var galaxy: Int
  public var system: Int
  public var station: SpaceBody
  var valid: Bool {
    (0..<8).contains(galaxy) && (0...256).contains(system) && station.id == 0
      && station.hull == .station
      && station.position.finite && station.orientation.validRotation && station.energy.isFinite
      && station.rotation.isFinite && station.rotationRate.isFinite
  }
}

extension Game {
  var scriptAnchor: SpaceBody? {
    let system = missionActorAdmissionSystemIdentity
    return Self.resolveScriptAnchor(
      bodies: bodies, frame: scriptReferenceFrame, galaxy: system.galaxy, system: system.system)
  }

  // Borrow only the inputs used by anchor selection; do not materialize a Game or Commander.
  @inline(never)
  private static func resolveScriptAnchor(
    bodies: borrowing [SpaceBody], frame: borrowing ScriptReferenceFrame?,
    galaxy: Int, system: Int
  ) -> SpaceBody? {
    for index in bodies.indices where bodies[index].id == 0 && bodies[index].hull == .station {
      return bodies[index].energy > 0 ? bodies[index] : nil
    }
    guard let frame = copy frame, frame.galaxy == galaxy,
      frame.system == system, frame.station.energy > 0
    else { return nil }
    return frame.station
  }
  mutating func advanceScriptReferenceFrame(delta: Double) {
    guard !bodies.contains(where: { $0.id == 0 && $0.hull == .station }),
      var frame = scriptReferenceFrame, frame.galaxy == commander.galaxy,
      frame.system == commander.system
    else { return }
    frame.station.position = frame.station.position.rotated(
      pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
    frame.station.orientation.rotate(pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
    frame.station.position =
      frame.station.position - autoPilot.velocity * delta - Vector3(0, 0, speed * delta * 18)
    frame.station.rotation += frame.station.rotationRate * delta
    scriptReferenceFrame = frame
  }
  func scriptEncounterSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    .object(
      instance.ownedEncounters.mapValues { encounter in
        .object([
          "admitted": .bool(encounter.admitted), "destroyed": .bool(encounter.destroyed),
          "total": .integer(Int64(encounter.actors.count)),
          "destroyed_count": .integer(
            Int64(encounter.actors.values.filter { $0.presence == .destroyed }.count)),
          "actors": .object(
            encounter.actors.mapValues { actor in
              .object([
                "identity": .string(actor.identity.uuidString),
                "presence": .string(actor.presence.rawValue),
                "energy": .number(actor.body.energy),
                "position": [.inTransit, .arrivalPending].contains(actor.presence)
                  ? .null
                  : .array([
                    .number(actor.body.position.x), .number(actor.body.position.y),
                    .number(actor.body.position.z),
                  ]),
                "npc": scriptNPCSnapshot(actor.body.scriptNPC),
                "missiles": .integer(Int64(actor.body.missiles)),
              ])
            }),
        ])
      })
  }
  /// Returns a later native result. A saved plan is not an admission receipt.
  @inline(never)
  mutating func ensureScriptEncounter(
    _ id: String, pack: ScriptPack, state: inout ScriptInstance,
    worldJobID: UUID? = nil, worldJobPulse: UInt64? = nil
  )
    throws -> (String, [String: ScriptValue])
  {
    let attempt = try makeScriptEncounterAttempt(
      id, pack: pack, state: state, worldJobID: worldJobID, worldJobPulse: worldJobPulse)
    defer { restoreScriptEncounterGeometry(attempt) }
    try prepareScriptEncounterPlan(attempt, id: id, pack: pack, state: state)
    if attempt.alreadyAdmitted {
      return ("encounter.admitted", ["encounter_id": .string(id), "existing": .bool(true)])
    }
    try Self.prepareScriptEncounterAdmissionSource(
      self, attempt: attempt, pack: pack, state: state,
      worldJobID: worldJobID, worldJobPulse: worldJobPulse)
    try Self.prepareScriptEncounterNativeAdmission(self, attempt: attempt)
    return try publishScriptEncounterAdmission(attempt, id: id, state: &state)
  }

  @inline(never)
  private mutating func makeScriptEncounterAttempt(
    _ id: String, pack: ScriptPack, state: borrowing ScriptInstance,
    worldJobID: UUID?, worldJobPulse: UInt64?
  ) throws -> ScriptEncounterAttemptScratch {
    guard state.outcome == .active || worldJobID != nil,
      pack.manifest.capabilities.contains("classic-encounters-v2")
        || pack.manifest.capabilities.contains("profiled-encounters-v2"),
      let definition = pack.manifest.encounters?.first(where: { $0.id == id })
    else {
      throw MissionPackError(
        "Declare the classic encounter capability and an exact encounter definition.")
    }
    try Self.validateScriptEncounterAdmissionAuthority(
      self, id: id, pack: pack, state: state, definition: definition,
      worldJobID: worldJobID, worldJobPulse: worldJobPulse)
    let previousGeometry = withReadOnlyScriptState { $0.geometry }
    return .init(definition: consume definition, previousGeometry: previousGeometry)
  }

  @inline(never)
  private mutating func restoreScriptEncounterGeometry(_ attempt: ScriptEncounterAttemptScratch) {
    if !attempt.publishesGeometry { commander.scriptState.geometry = attempt.previousGeometry }
  }

  /// Each borrowed Game read ends before the next admission phase starts.
  @inline(never)
  private static func validateScriptEncounterAdmissionAuthority(
    _ game: borrowing Game, id: String, pack: ScriptPack, state: borrowing ScriptInstance,
    definition: ScriptEncounterDefinition, worldJobID: UUID?, worldJobPulse: UInt64?
  ) throws {
    _ = try game.missionActorAdmissionAuthority(
      pack: pack, state: state, encounterID: id, galaxy: definition.galaxy,
      system: definition.system, worldJob: worldJobID, pulse: worldJobPulse)
  }

  @inline(never)
  private static func prepareScriptEncounterAdmissionSource(
    _ game: borrowing Game, attempt: ScriptEncounterAttemptScratch,
    pack: ScriptPack, state: borrowing ScriptInstance, worldJobID: UUID?, worldJobPulse: UInt64?
  ) throws {
    attempt.source = try game.preparedMissionActorAdmissionSource(
      pack: pack, state: state, encounter: attempt.encounter!,
      worldJob: worldJobID, pulse: worldJobPulse)
  }

  @inline(never)
  private static func prepareScriptEncounterNativeAdmission(
    _ game: borrowing Game, attempt: ScriptEncounterAttemptScratch
  ) throws {
    attempt.preparation = try game.prepareMissionActorAdmission(attempt.source!)
  }

  /// Actor/body construction storage returns before source/native validation starts.
  @inline(never)
  private mutating func prepareScriptEncounterPlan(
    _ attempt: ScriptEncounterAttemptScratch, id: String, pack: ScriptPack,
    state: borrowing ScriptInstance
  ) throws {
    let definition = attempt.definition
    var plan = state.ownedEncounters[id]
    if plan == nil {
      var actors: [String: ScriptOwnedActor] = [:]
      for spec in definition.actors {
        let identity = ScriptIdentity.uuid(
          "script-actor-v2:\(state.id):\(pack.digest):\(id):\(spec.id)")
        var body = SpaceBody(
          id: -1, hull: spec.hull ?? .cobra, position: .init(spec.x, spec.y, spec.z),
          hostile: spec.hostile)
        if let npcID = spec.npc,
          let definition = pack.manifest.npcs?.first(where: { $0.id == npcID })
        {
          body.scriptNPC = try makeScriptNPC(definition, pack: pack, identity: identity)
          body.energy = definition.energy
          body.missiles = definition.missiles
          body.ecmEnabled = definition.ecm
          body.rotationRate = 0
        }
        body.missionActorID = identity
        body.missionInstanceID = state.id
        try NativeInductionCrewLogPack.initialBody(&body, state: state, alias: spec.id)
        actors[spec.id] = ScriptOwnedActor(
          identity: identity, alias: spec.id, body: body, presence: .prepared)
      }
      plan = ScriptOwnedEncounter(
        id: id, galaxy: definition.galaxy, system: definition.system, actors: actors)
    }
    guard let encounter = plan else { throw MissionPackError("Encounter plan was not prepared.") }
    attempt.encounter = consume encounter
    attempt.alreadyAdmitted = attempt.encounter!.admitted
  }

  /// Native preparation returns before selected-instance staging and commit storage starts.
  @inline(never)
  private mutating func publishScriptEncounterAdmission(
    _ attempt: ScriptEncounterAttemptScratch, id: String, state: inout ScriptInstance
  ) throws -> (String, [String: ScriptValue]) {
    func pending(_ reason: String) -> (String, [String: ScriptValue]) {
      ("encounter.pending", ["encounter_id": .string(id), "reason": .string(reason)])
    }
    switch attempt.preparation! {
    case .pending(let reason):
      Self.publishPendingScriptEncounter(attempt, id: id, state: &state)
      switch reason {
      case .unavailableArrival:
        return pending("Enter the declared system in flight with its main station available.")
      case .outsideLocalBubble:
        return pending("The complete cohort must fit the currently loaded space region.")
      case .nativeUnits, .allocatorCapacity:
        return pending("The whole encounter needs more native actor capacity.")
      case .native:
        return pending("The whole encounter awaits native capacity or unobstructed placement.")
      }
    case .unchanged:
      throw MissionPackError("A fresh prepared cohort requires complete native admission.")
    case .ready(let plan):
      attempt.nativePlan = plan
      try Self.stageScriptEncounterRetention(attempt, id: id, state: state)
      _ = try commitMissionActorAdmission(plan)
      Self.publishStagedScriptEncounter(attempt, state: &state)
      try recordIsolationWorkAdmission(in: &state)
      return (
        "encounter.admitted",
        [
          "encounter_id": .string(id), "count": .integer(Int64(attempt.count)),
          "existing": .bool(false),
        ]
      )
    }
  }

  @inline(never)
  private static func publishPendingScriptEncounter(
    _ attempt: ScriptEncounterAttemptScratch, id: String, state: inout ScriptInstance
  ) {
    state.ownedEncounters[id] = attempt.encounter!
    attempt.publishesGeometry = true
  }

  @inline(never)
  private static func stageScriptEncounterRetention(
    _ attempt: ScriptEncounterAttemptScratch, id: String, state: borrowing ScriptInstance
  ) throws {
    attempt.selected = copy state
    attempt.selected!.ownedEncounters[id] = attempt.encounter!
    attempt.staged = try attempt.nativePlan!.retentionPatch.preparingInstance(attempt.selected!)
    attempt.count = attempt.nativePlan!.sceneBodyIDs.count
  }

  @inline(never)
  private static func publishStagedScriptEncounter(
    _ attempt: ScriptEncounterAttemptScratch, state: inout ScriptInstance
  ) {
    state = attempt.staged!
    attempt.publishesGeometry = true
  }
  /// Native facts retain canonical location/condition and never infer death from disappearance.
  mutating func persistScriptActors(unloading: Bool = false) {
    guard !commander.scriptState.instances.isEmpty else { return }
    refreshScriptPersistenceStation()
    let system = missionActorAdmissionSystemIdentity
    guard
      let anchor = Self.resolveScriptAnchor(
        bodies: bodies, frame: scriptReferenceFrame, galaxy: system.galaxy, system: system.system)
    else { return }
    persistScriptShots(anchor: anchor, unloading: unloading)
    captureScriptActors(anchor: anchor, unloading: unloading)
  }

  // Station loss and reference-frame refresh finish before actor capture allocates its records.
  @inline(never)
  private mutating func refreshScriptPersistenceStation() {
    if let actual = bodies.first(where: { $0.id == 0 && $0.hull == .station }) {
      if actual.energy <= 0 { recordScriptWorldResourceLoss(actual) }
      if commander.scriptState.stationResources[contractStation.key] != nil {
        commander.scriptState.stationResources[contractStation.key]?.energy = max(0, actual.energy)
      }
      scriptReferenceFrame = ScriptReferenceFrame(
        galaxy: commander.galaxy, system: commander.system, station: actual)
    }
  }

  @inline(never)
  private mutating func captureScriptActors(anchor: borrowing SpaceBody, unloading: Bool) {
    if unloading {
      for body in bodies where body.missionActorID != nil && body.energy <= 0 {
        recordScriptActorRemoval(body, destroyed: true)
      }
    }
    let actual = Dictionary(
      bodies.compactMap { body in body.missionActorID.map { ($0, body) } },
      uniquingKeysWith: { first, _ in first })
    for instanceID in commander.scriptState.instances.keys {
      guard var instance = commander.scriptState.instances[instanceID] else { continue }
      for encounterID in instance.ownedEncounters.keys {
        guard var encounter = instance.ownedEncounters[encounterID], encounter.admitted
        else { continue }
        for alias in encounter.actors.keys {
          guard var saved = encounter.actors[alias],
            ![.destroyed, .inTransit, .arrivalPending].contains(saved.presence),
            saved.location(in: encounter) == systemIdentity,
            let body = actual[saved.identity], body.missionInstanceID == instanceID
          else { continue }
          captureIsolationWorkPose(body, in: &instance)
          saved.body = body
          saved.body.energy = max(0, body.energy)
          saved.body.position = anchor.orientation.inverse(body.position - anchor.position)
          saved.body.orientation = body.orientation.relative(to: anchor.orientation)
          saved.body.scriptNPC?.velocity = anchor.orientation.inverse(
            body.scriptNPC?.velocity ?? .init(0, 0, 0))
          if unloading && saved.presence == .present { saved.presence = .unloaded }
          encounter.actors[alias] = saved
        }
        instance.ownedEncounters[encounterID] = encounter
      }
      commander.scriptState.instances[instanceID] = instance
    }
  }
  /// Every cohort's hard native/source checks precede any restoration publication. Plans are
  /// deliberately discarded here; later preparation uses fresh counters after earlier commits.
  @discardableResult
  func validateRetainedMissionActorRestoration() throws -> [MissionActorAdmissionSource] {
    let sources = try retainedMissionActorAdmissionSources()
    try validateRetainedMissionActorSources(sources)
    return sources
  }

  /// Source collection returns before the later admission-validation loop reserves its values.
  @inline(never)
  private func validateRetainedMissionActorSources(
    _ sources: borrowing [MissionActorAdmissionSource]
  ) throws {
    for index in sources.indices { _ = try prepareMissionActorAdmission(sources[index]) }
  }

  /// Reprojects the same world actor after genuine native launch/arrival/camera travel.
  mutating func restoreScriptActors() throws {
    try validateRetainedMissionProjectileRestoration()
    let sources = try validateRetainedMissionActorRestoration()
    guard !retainedMissionActorInstances.isEmpty, !docked, let anchor = scriptAnchor else {
      return
    }
    // All hard source/current-binding checks finished before even the station can reappear.
    restoreNativeMissionStationIfEligible()
    try restoreRetainedMissionActors(sources)
    try restoreScriptShots(anchor: anchor)
  }

  /// Retire actor admission temporaries before the subsequent projectile restoration phase.
  @inline(never)
  private mutating func restoreRetainedMissionActors(
    _ sources: borrowing [MissionActorAdmissionSource]
  ) throws {
    for index in sources.indices {
      let source = sources[index]
      switch try prepareMissionActorAdmission(source) {
      case .pending, .unchanged: continue
      case .ready(let plan):
        let instanceID = source.instanceID
        guard let current = withReadOnlyScriptState({ $0.instances[instanceID] }) else {
          throw MissionPackError("Retained actor owner disappeared before native preparation.")
        }
        let staged = try plan.retentionPatch.preparingInstance(current)
        _ = try commitMissionActorAdmission(plan)
        commander.scriptState.instances[instanceID] = staged
      }
    }
  }
  mutating func recordScriptActorRemoval(_ body: SpaceBody, destroyed: Bool) {
    if destroyed { recordScriptWorldResourceLoss(body) }
    recordScriptShotRemoval(body)
    guard let identity = body.missionActorID, let instanceID = body.missionInstanceID,
      var instance = commander.scriptState.instances[instanceID]
    else { return }
    for key in instance.ownedEncounters.keys.sorted() {
      guard var encounter = instance.ownedEncounters[key], encounter.admitted,
        let alias = encounter.actors.first(where: { $0.value.identity == identity })?.key,
        var actor = encounter.actors[alias], actor.presence == .present, actor.body.id == body.id
      else { continue }
      if destroyed {
        guard body.energy <= 0 else { return }
        let previous = actor.body
        actor.body = body
        actor.body.energy = 0
        if let anchor = scriptAnchor {
          actor.body.position = anchor.orientation.inverse(body.position - anchor.position)
          actor.body.orientation = body.orientation.relative(to: anchor.orientation)
          actor.body.scriptNPC?.velocity = anchor.orientation.inverse(
            body.scriptNPC?.velocity ?? .init(0, 0, 0))
        } else {
          // Without a station frame, retain the last canonical pose while preserving actual
          // terminal condition. Never label the current camera pose as station-relative.
          actor.body.position = previous.position
          actor.body.orientation = previous.orientation
          actor.body.scriptNPC?.velocity = previous.scriptNPC?.velocity ?? .init(0, 0, 0)
        }
        actor.presence = .destroyed
        actor.destroyedByPlayer = body.destroyedByPlayer == true
      } else {
        actor.presence = .outside
      }
      encounter.actors[alias] = actor
      instance.ownedEncounters[key] = encounter
      captureIsolationWorkPose(body, in: &instance)
      if destroyed { recordIsolationWorkModuleLoss(body, in: &instance) }
      commander.scriptState.instances[instanceID] = instance
      emitScriptEvent(
        destroyed ? "actor.destroyed" : "actor.removed",
        values: [
          "actor_id": .string(identity.uuidString), "alias": .string(alias),
          "encounter_id": .string(key),
          "destroyed_by_player": .bool(body.destroyedByPlayer == true),
        ], only: instanceID, drain: false)
      return
    }
  }
}

extension Commander {
  /// Borrow only the same immutable source fields before nested admission validation.
  /// This transient tuple is neither an authority token nor a cached state owner.
  fileprivate func missionActorAdmissionSourceValues() -> (
    instances: [UUID: ScriptInstance], geometry: [String: ShipDesign], galaxy: Int, system: Int
  ) {
    let state = scriptState
    return (state.instances, state.geometry, galaxy, system)
  }
}

extension Game {
  /// A real facility launches its retained original hull via the existing native admission policy.
  func inductionArkBerthAdmissionSource(_ id: UUID) throws -> MissionActorAdmissionSource {
    guard !docked, !paused, let owner = commander.scriptState.instances[id],
      owner.definition == NativeInductionArkPack.stateID,
      owner.digest == NativeInductionArkPack.digest,
      let state = owner.savedNativeArk, let dock = state.dockedContact, state.loss == nil,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station,
      let pack = nativeInductionArkPack,
      let encounter = owner.ownedEncounters[NativeInductionArkPack.encounter], encounter.admitted,
      var actor = encounter.actors[NativeInductionArkPack.alias], actor.presence == .unloaded,
      actor.body.energy > 0, actor.identity == state.authorization.actor,
      !bodies.contains(where: { $0.missionActorID == actor.identity }),
      let exit = currentNativeMainStationAnchor(at: commander.flightSimulation.physicalTime),
      let anchor = scriptAnchor, let profile = actor.body.scriptNPC?.fit.definition
    else { throw SaveError.invalidCommander }
    let definition = try validateMissionActorAdmissionEncounter(
      mode: .retained, pack: pack, state: owner, encounter: encounter)
    guard let spec = definition.actors.first(where: { $0.id == actor.alias }) else {
      throw SaveError.invalidCommander
    }
    let pose = commander.flightSimulation.pose
    let direction = exit.exitDirection.unit
    var orientation = Basis3()
    orientation.z = direction
    orientation.y = exit.orientation.y
    orientation.x = orientation.y.cross(orientation.z).unit
    actor.body.position = anchor.orientation.inverse(
      pose.shipPoint(exit.exitPosition) - anchor.position)
    actor.body.orientation = orientation.relative(to: pose.orientation).relative(
      to: anchor.orientation)
    let stationVelocity =
      commander.nativeStations?.stationInertia.first(where: {
        if case .main(let identity) = $0.station { return identity == dock.station }
        return false
      })?.velocity ?? .init(0, 0, 0)
    guard stationVelocity.length <= profile.speed else {
      throw NativeMissionActorAdmissionError.invalidCondition
    }
    actor.body.scriptNPC?.velocity = anchor.orientation.inverse(pose.shipVector(stationVelocity))
    let goal = exit.position + direction * 1200
    actor.body.scriptNPC?.intent = .init(
      request: "native-ark-berth-exit", mode: .approach, target: nil, player: false,
      offset: anchor.orientation.inverse(pose.shipPoint(goal) - anchor.position),
      speed: min(1, 144 / profile.speed), tolerance: 50)
    let template = try Self.missionActorAdmissionTemplate(
      actor, specification: spec,
      npcDefinitions: pack.manifest.npcs ?? [], installedModels: pack.models,
      geometry: commander.scriptState.geometry, legacy: nil)
    return .init(
      mode: .retained, authority: .inductionArkBerth(id), instance: owner, pack: pack,
      encounter: encounter, definition: definition, actors: [template],
      installedBaseEncounter: encounter)
  }
}

extension Game {
  func inductionRescueBerthAdmissionSource(_ id: UUID) throws -> MissionActorAdmissionSource {
    guard !docked, !paused, let owner = commander.scriptState.instances[id],
      owner.definition == NativeInductionCrewLogPack.stateID,
      owner.digest == NativeInductionCrewLogPack.digest,
      let state = owner.savedNativeCrewLog, let flight = state.flight,
      let dock = flight.dockedContact, state.livingCrew.count == 2,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station,
      let pack = nativeInductionCrewLogPack,
      let encounter = owner.ownedEncounters[NativeInductionCrewLogPack.encounter],
      encounter.admitted,
      var actor = encounter.actors["launch"], actor.presence == .unloaded,
      actor.body.energy > 0, actor.identity == flight.authorization.actor,
      !bodies.contains(where: { $0.missionActorID == actor.identity }),
      let exit = currentNativeMainStationAnchor(at: commander.flightSimulation.physicalTime),
      let anchor = scriptAnchor, let profile = actor.body.scriptNPC?.fit.definition
    else { throw SaveError.invalidCommander }
    let definition = try validateMissionActorAdmissionEncounter(
      mode: .retained, pack: pack, state: owner, encounter: encounter)
    guard let spec = definition.actors.first(where: { $0.id == actor.alias }) else {
      throw SaveError.invalidCommander
    }
    let pose = commander.flightSimulation.pose
    let direction = exit.exitDirection.unit
    var orientation = Basis3()
    orientation.z = direction
    orientation.y = exit.orientation.y
    orientation.x = orientation.y.cross(orientation.z).unit
    actor.body.position = anchor.orientation.inverse(
      pose.shipPoint(exit.exitPosition) - anchor.position)
    actor.body.orientation = orientation.relative(to: pose.orientation).relative(
      to: anchor.orientation)
    let stationVelocity =
      commander.nativeStations?.stationInertia.first(where: {
        if case .main(let identity) = $0.station { return identity == dock.station }
        return false
      })?.velocity ?? .init(0, 0, 0)
    guard stationVelocity.length <= profile.speed else {
      throw NativeMissionActorAdmissionError.invalidCondition
    }
    actor.body.scriptNPC?.velocity = anchor.orientation.inverse(pose.shipVector(stationVelocity))
    let goal = exit.position + direction * 1200
    actor.body.scriptNPC?.intent = .init(
      request: "native-rescue-berth-exit", mode: .approach, target: nil, player: false,
      offset: anchor.orientation.inverse(pose.shipPoint(goal) - anchor.position),
      speed: min(1, 144 / profile.speed), tolerance: 50)
    let template = try Self.missionActorAdmissionTemplate(
      actor, specification: spec,
      npcDefinitions: pack.manifest.npcs ?? [], installedModels: pack.models,
      geometry: commander.scriptState.geometry, legacy: nil)
    return .init(
      mode: .retained, authority: .inductionRescueBerth(id), instance: owner, pack: pack,
      encounter: encounter, definition: definition, actors: [template],
      installedBaseEncounter: encounter)
  }
}

extension Game {
  /// Closed native C01 extension; no caller-supplied body can add another encounter or source.
  func c01SurveyorAdmissionSource(
    pack: ScriptPack, state: ScriptInstance, encounter: ScriptOwnedEncounter
  ) throws -> MissionActorAdmissionSource {
    guard pack.manifest.stateID == NativeGlassMeridian.stateID,
      pack.digest == NativeGlassMeridian.digest,
      NativeC01Surveyor.definition(state, id: encounter.id) != nil,
      let opening = state.savedGlassMeridian, NativeC01Surveyor.shapeValid(opening),
      NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening)
    else { throw NativeMissionActorAdmissionError.invalidTemplate }
    return try preparedMissionActorAdmissionSource(pack: pack, state: state, encounter: encounter)
  }
}
