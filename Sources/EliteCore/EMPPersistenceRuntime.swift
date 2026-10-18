import Foundation

extension Game {
  /// Every admitted person remains in custody if an actor slot or safe placement is unavailable.
  mutating func advanceEMPActors() {
    guard !docked, persistEMPState() else { return }
    recoverEMPHulls()
    guard let sources = coastEMPArchives() else { return }
    for source in sources {
      if admitEMPArchiveObjects(source: source) { ejectOneEMPCrewMember(source: source) }
    }
  }

  // Finish the archive pass before entering real actor admission and crew ejection.
  private mutating func coastEMPArchives() -> [ActorIdentity]? {
    guard var state = commander.savedEMPState else { return nil }
    let now = commander.flightSimulation.physicalTime
    for source in state.sources {
      guard var record = state.records[source] else { continue }
      if record.disableEpisodes.isEmpty, !record.terminal, !record.isRecovered,
        record.crewAboard > 0
      {
        guard record.installLegacyCrewEpisode()
        else { continue }
      }
      if !record.terminal, !record.isRecovered, record.hull.binding == nil {
        do {
          if let native = try joinedNativeEMPWreck(record) {
            // Native custody keeps the last actual pose while parked; the original
            // ordinary EMP archive retains its existing offscreen coast behaviour.
            guard nativeEMPArchiveMatches(record.hull, wreck: native) else { return nil }
          } else {
            coastEMPObject(&record.hull, to: now)
          }
        } catch { return nil }
      }
      for i in record.pods.indices
      where record.pods[i].binding == nil
        && record.pods[i].body.physical?.empCrewPod.map({ commander.worldOwnedPod($0) }) == true
      {
        coastEMPObject(&record.pods[i], to: now)
      }
      state.records[source] = record
    }
    commander.savedEMPState = state
    return state.sources
  }

  private mutating func admitEMPArchiveObjects(source: ActorIdentity) -> Bool {
    guard let record = commander.savedEMPState?.records[source], source.system == systemIdentity
    else { return false }
    if !record.terminal, !record.isRecovered, record.hull.binding == nil {
      _ = admitEMPObject(record.hull, source: source, sequence: record.sequence, member: 0)
    }
    for i in record.pods.indices
    where record.pods[i].binding == nil
      && record.pods[i].body.physical?.empCrewPod.map({ commander.worldOwnedPod($0) }) == true
    {
      guard let person = record.pods[i].body.physical?.empCrewPod else { continue }
      _ = admitEMPObject(
        record.pods[i], source: source, sequence: record.sequence,
        member: UInt16(person.ordinal + 1))
    }
    return !record.isRecovered
  }

  private func coastEMPObject(_ object: inout EMPStoredObject, to now: Double) {
    let dt = now - object.physicalTime
    guard dt.isFinite, dt > 0, let physical = object.body.physical else { return }
    object.body.position = object.body.position + physical.velocity * dt
    object.body.rotation += object.body.rotationRate * dt
    object.body.orientation = RelativeWorkController.rotated(
      object.body.orientation, omega: physical.angularVelocity, delta: dt)
    object.physicalTime = now
  }

  @discardableResult
  private mutating func admitEMPObject(
    _ object: EMPStoredObject, source: ActorIdentity, sequence: UInt64, member: UInt16
  ) -> Bool {
    if member == 0, let record = commander.savedEMPState?.records[source],
      commander.alienStorageState?.current.salvage.native.wrecks[record.wreck] != nil
    {
      return admitJoinedNativeEMPObject(object, source: source, sequence: sequence)
    }
    return admitEMPObjectInPlace(object, source: source, sequence: sequence, member: member)
  }

  private mutating func admitJoinedNativeEMPObject(
    _ object: EMPStoredObject, source: ActorIdentity, sequence: UInt64
  ) -> Bool {
    guard let record = commander.savedEMPState?.records[source],
      let wreck = try? joinedNativeEMPWreck(record), wreck.binding == nil,
      nativeEMPArchiveMatches(object, wreck: wreck)
    else { return false }
    var candidate = self
    guard candidate.admitEMPObjectInPlace(object, source: source, sequence: sequence, member: 0),
      let actor = candidate.commander.savedEMPState?.records[source]?.hull.binding,
      let actual = candidate.bodies.first(where: { $0.physical?.identity == actor }),
      candidate.retainNativeSalvageWreck(actual)
    else { return false }
    self = candidate
    return true
  }

  @discardableResult
  private mutating func admitEMPObjectInPlace(
    _ object: EMPStoredObject, source: ActorIdentity, sequence: UInt64, member: UInt16
  ) -> Bool {
    if member == 0, let episode = commander.savedEMPState?.records[source]?.disableEpisodes.last,
      episode.actorBindings.count >= EMPState.maximumPeople
    {
      return false
    }
    guard member == 0 || commander.worldOwnedPod(.init(source: source, ordinal: Int(member) - 1))
    else { return false }
    guard let context = gameplayContext(), object.body.energy > 0,
      (object.body.position - context.player.position).length <= context.perceptionRadius,
      let saved = object.body.physical
    else { return false }
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: member, producer: .emp),
      population: saved.population, hull: object.body.hull, position: object.body.position,
      orientation: object.body.orientation, velocity: saved.velocity, npc: saved.npc,
      rock: nil, payload: nil, priority: .ordinary, catalogueShipID: saved.catalogueShipID,
      energy: object.body.energy, angularVelocity: saved.angularVelocity, salvage: saved.salvage)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: [request], atomic: true)], intents: []
      ))
    guard let actor = receipts.first?.actor,
      let index = bodies.firstIndex(where: { $0.physical?.identity == actor }),
      var physical = bodies[index].physical
    else { return false }
    var restored = object.body
    restored.id = bodies[index].id
    restored.position = commander.flightSimulation.pose.shipPoint(object.body.position)
    restored.orientation = object.body.orientation.relative(
      to: commander.flightSimulation.pose.orientation)
    if physical.npc?.firstAggressor?.entity == 0 {
      physical.npc?.firstAggressor = commander.flightSimulation.player
    }
    if let intention = physical.npc?.intention,
      intention.referencedActor?.entity == 0, let player = commander.flightSimulation.player
    {
      physical.npc?.intention = intention.replacingReferencedActor(with: player)
    }
    physical.empSource = saved.empSource
    physical.empCrewPod = saved.empCrewPod
    physical.laserCooldown = saved.laserCooldown
    physical.canonicalSpin = saved.canonicalSpin
    physical.suspendedNPCIntention = saved.suspendedNPCIntention
    restored.physical = physical
    bodies[index] = restored
    let captured = EMPStoredObject(
      body: restored, pose: commander.flightSimulation.pose,
      time: commander.flightSimulation.physicalTime)
    if member == 0 {
      if commander.savedEMPState?.records[source]?.savedDisableEpisodes != nil {
        guard commander.savedEMPState?.records[source]?.recordCrewActorBinding(actor) == true
        else { return false }
      }
      commander.savedEMPState?.records[source]?.hull = captured
    } else {
      guard let index = commander.savedEMPState?.records[source]?.podIndex(for: Int(member) - 1)
      else { return false }
      commander.savedEMPState?.records[source]?.pods[index] = captured
    }
    // Legal aggression is retained by stable source; the surviving record follows its current actor.
    commander.crimeLedger.rebindActors([saved.identity: actor])
    return true
  }

  private mutating func ejectOneEMPCrewMember(source: ActorIdentity) {
    guard var record = commander.savedEMPState?.records[source], !record.terminal,
      record.crewAboard > 0, let binding = record.hull.binding,
      let index = bodies.firstIndex(where: { $0.physical?.identity == binding }),
      let hull = bodies[index].physical, let context = gameplayContext(),
      let ordinal = record.nextDueCrew(at: context.physicalTime),
      record.crewDeadline.map({ context.physicalTime < $0 }) == true,
      let podShip = ShipCatalogue.ship("SH040"),
      let profile = record.hull.body.physical?.catalogueShipID
        .flatMap({ SalvageCatalogue.empProfile(catalogueShipID: $0) })
    else { return }
    let radius = podShip.design.rawMesh.vertices.map(\.length).max() ?? 32
    let pose = modelPose(of: bodies[index])
    let direction = pose.orientation.x
    let position =
      pose.position + direction
      * (profile.bounds.radius + profile.bounds.center.length + radius + 24)
    let person = EMPCrewIdentity(source: source, ordinal: ordinal)
    let metadata = SalvageTargetMetadata(
      category: .occupiedPod, ownership: .occupied,
      claimant: source, wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: radius), workSurfaces: [])
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: record.sequence,
        member: UInt16(person.ordinal + 1), producer: .emp),
      population: .cargo, hull: .cargo, position: position, orientation: pose.orientation,
      velocity: hull.velocity + direction * 80, npc: nil, rock: nil, payload: nil,
      priority: .ordinary, catalogueShipID: "SH040", energy: podShip.game?.energy ?? 100,
      angularVelocity: .init(0, 0, 0), salvage: metadata)
    var candidate = self
    let receipts = candidate.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: [request], atomic: true)], intents: []
      ))
    guard let actor = receipts.first?.actor,
      let podIndex = candidate.bodies.firstIndex(where: { $0.physical?.identity == actor })
    else { return }
    candidate.bodies[podIndex].physical?.empCrewPod = person
    candidate.bodies[podIndex].rotationRate = 0
    guard record.recordCrewEjection(ordinal: ordinal, at: context.physicalTime) else { return }
    record.pods.append(
      .init(
        body: candidate.bodies[podIndex], pose: candidate.commander.flightSimulation.pose,
        time: context.physicalTime))
    record.nextEjectionAt =
      record.disableEpisodes.last?.legacyTiming == true
      ? context.physicalTime + 1
      : record.disableEpisodes.last?.ejections.filter {
        record.crewOutcome(ordinal: $0.ordinal) == .aboard
      }.map { record.currentCrewDisableIncident.physicalTime + $0.delay }.min()
        ?? record.crewDeadline ?? context.physicalTime
    let birthNativeWreck =
      record.crewAboard == 0
      && (profile.sourceRoles.contains(.thargoid)
        || candidate.commander.alienStorageState?.current.salvage.native.wrecks[record.wreck] != nil)
    if record.crewAboard == 0 {
      let bodyIndex = candidate.bodies.firstIndex(where: { $0.physical?.identity == binding })!
      candidate.bodies[bodyIndex].physical?.npc = nil
      candidate.bodies[bodyIndex].physical?.blocksNavalEncounter = false
      candidate.bodies[bodyIndex].physical?.population = .wreck
      candidate.bodies[bodyIndex].hostile = false
      candidate.bodies[bodyIndex].physical?.salvage = .init(
        category: .wreck, ownership: .abandoned, claimant: nil, wreck: record.wreck,
        section: nil, lot: nil, bounds: profile.bounds,
        workSurfaces: profile.surfaces(wreck: record.wreck))
      record.hull = .init(
        body: candidate.bodies[bodyIndex], pose: candidate.commander.flightSimulation.pose,
        time: context.physicalTime)
      guard
        birthNativeWreck
          || candidate.commander.salvageLedger.updateWreck(
            identity: record.wreck,
            motion: .init(
              pose: candidate.modelPose(of: candidate.bodies[bodyIndex]),
              velocity: hull.velocity, angularVelocity: hull.angularVelocity,
              energy: candidate.bodies[bodyIndex].energy))
      else { return }
      candidate.notify("CREW EJECTED - UNOCCUPIED SALVAGE")
    }
    guard record.valid else { return }
    candidate.commander.savedEMPState?.records[source] = record
    if birthNativeWreck {
      guard let body = candidate.bodies.first(where: { $0.physical?.identity == binding }),
        candidate.retainNativeSalvageWreck(body)
      else { return }
    }
    self = candidate
  }

  /// Capture irreversible death before scene removal so a saved hull cannot be re-admitted alive.
  mutating func registerEMPHullDeaths() -> Bool {
    guard var state = commander.savedEMPState else { return true }
    for body in bodies where body.energy <= 0 {
      if body.physical?.empCrewPod != nil { return false }
      guard let source = body.physical?.empSource else { continue }
      guard var record = state.records[source],
        record.hull.binding == body.physical?.identity
          || (record.terminal && record.hull.body.physical?.identity == body.physical?.identity)
      else { return false }
      record.hull = .init(
        body: body, pose: commander.flightSimulation.pose,
        time: commander.flightSimulation.physicalTime)
      record.hull.binding = nil
      if !record.terminal, !record.disableEpisodes.isEmpty {
        record.savedDeceasedOrdinals = record.aboardOrdinals.isEmpty ? nil : record.aboardOrdinals
      }
      record.terminal = true
      record.lostCrewCount = record.crewTotal - record.pods.count - record.capturedCrewCount
      state.records[source] = record
    }
    guard state.valid else { return false }
    commander.savedEMPState = state
    return true
  }

  /// Save/departure/culling capture the same physical objects. Missing actors become unbound, never replenished.
  @discardableResult
  mutating func persistEMPState() -> Bool {
    // Keep the absent-archive path outside the value-heavy capture frame.
    guard commander.savedEMPState != nil else {
      return !bodies.contains {
        $0.physical?.empSource != nil || $0.physical?.empCrewPod != nil
          || $0.physical?.spawnIdentity?.producer == .emp
      }
    }
    guard captureEMPArchiveState() else { return false }
    return validateCapturedEMPScene()
  }

  @inline(never)
  private mutating func validateCapturedEMPScene() -> Bool {
    guard let state = commander.savedEMPState else { return true }
    return state.sceneIsConsistent(
      bodies, flight: commander.flightSimulation, people: commander.nativePeople)
  }

  /// Capture keeps its original initial/final state guards and publication point.
  @inline(never)
  private mutating func captureEMPArchiveState() -> Bool {
    guard var state = commander.savedEMPState else { return false }
    guard state.valid else { return false }
    for source in state.records.keys {
      guard var record = state.records[source] else { return false }
      guard captureEMPArchiveRecord(&record) else { return false }
      state.records[source] = record
    }
    guard state.valid else { return false }
    commander.savedEMPState = state
    return true
  }

  /// Record temporaries finish before the archive's final validation and publication.
  @inline(never)
  private mutating func captureEMPArchiveRecord(_ record: inout EMPHullRecord) -> Bool {
    let pose = commander.flightSimulation.pose
    let now = commander.flightSimulation.physicalTime
    if record.isRecovered {
      guard updateRecoveredEMPArchive(&record, pose: pose, now: now) else { return false }
    } else if let binding = record.hull.binding {
      if let body = bodies.first(where: { $0.physical?.identity == binding }) {
        record.hull = .init(body: body, pose: pose, time: now)
        if body.energy <= 0, !record.terminal, !record.disableEpisodes.isEmpty {
          record.savedDeceasedOrdinals =
            record.aboardOrdinals.isEmpty ? nil : record.aboardOrdinals
        }
        record.terminal = body.energy <= 0
        if record.terminal {
          record.hull.binding = nil
          record.lostCrewCount = record.crewTotal - record.pods.count - record.capturedCrewCount
        }
      } else {
        record.hull.binding = nil
      }
    }
    for i in record.pods.indices {
      guard let person = record.pods[i].body.physical?.empCrewPod else { return false }
      guard commander.worldOwnedPod(person) else {
        guard record.pods[i].binding == nil else { return false }
        continue
      }
      if let binding = record.pods[i].binding {
        if let body = bodies.first(where: { $0.physical?.identity == binding }) {
          guard body.energy > 0 else { return false }
          record.pods[i] = .init(body: body, pose: pose, time: now)
        } else {
          record.pods[i].binding = nil
        }
      }
    }
    return true
  }
}

extension Game {
  /// This is compatibility for an exactly retained imported EMP source. It does not
  /// admit a new source class or change ordinary occupied/recoverable EMP archives.
  private func joinedNativeEMPWreck(_ record: EMPHullRecord) throws -> NativeSalvageWreck? {
    guard let wreck = commander.alienStorageState?.current.salvage.native.wrecks[record.wreck]
    else { return nil }
    guard case .emp(let logical, let sequence) = wreck.source,
      logical == record.source, sequence == record.sequence,
      wreck.owner == commander.equipmentOwnerID,
      wreck.catalogueShipID == record.hull.body.physical?.catalogueShipID,
      record.crewAboard == 0, record.lostCrewCount == 0,
      record.pods.count + record.capturedCrewCount == record.crewTotal, !record.isRecovered
    else { throw AlienStorageError.invalidJoin }
    return wreck
  }

  /// Stage only an exactly joined native EMP hull's parking. Both custody records
  /// become unbound in the same cold publication before the caller removes its body.
  func stagedNativeEMPParking(
    _ world: [AlienStorageWorldRecord], parking actors: Set<ActorIdentity>,
    parkingSystem: SystemIdentity?
  ) throws -> EMPState? {
    var staged = commander.savedEMPState
    for case .nativeWreck(let parked) in world {
      guard case .emp(let logical, let sequence) = parked.source,
        let old = commander.alienStorageState?.current.salvage.native.wrecks[parked.identity],
        let binding = old.binding,
        actors.contains(binding) || binding.system == parkingSystem,
        parked.destroyedAt == nil
      else { continue }
      guard parked.binding == nil, let record = staged?.records[logical], record.valid,
        record.source == logical, record.sequence == sequence,
        record.weaponOwner == commander.equipmentOwnerID,
        try joinedNativeEMPWreck(record) == old,
        record.hull.binding == binding, record.hull.physicalTime == parked.observedAt,
        binding.system == systemIdentity, binding.visit == commander.flightSimulation.visit,
        let body = bodies.first(where: { $0.physical?.identity == binding }),
        body.physical?.empSource == logical, body.physical?.salvage?.wreck == parked.identity,
        body.physical?.catalogueShipID == parked.catalogueShipID,
        body.physical?.npc == nil, body.physical?.payload == nil
      else { throw AlienStorageError.invalidJoin }
      try parked.preserve(old)
      var archive = record.hull
      archive.binding = nil
      var observed = EMPStoredObject(
        body: body, pose: commander.flightSimulation.pose,
        time: commander.flightSimulation.physicalTime)
      observed.binding = nil
      guard nativeEMPArchiveMatches(archive, wreck: parked),
        nativeEMPArchiveMatches(observed, wreck: parked),
        observed.physicalTime == parked.observedAt
      else { throw AlienStorageError.invalidJoin }
      staged?.records[logical]?.hull = archive
    }
    guard staged == commander.savedEMPState || staged?.valid == true else {
      throw AlienStorageError.invalidJoin
    }
    return staged
  }

  private func nativeEMPArchiveMatches(_ object: EMPStoredObject, wreck: NativeSalvageWreck) -> Bool
  {
    guard let physical = object.body.physical else { return false }
    var orientation = Basis3()
    orientation.x = object.body.modelVector(.init(1, 0, 0))
    orientation.y = object.body.modelVector(.init(0, 1, 0))
    orientation.z = object.body.modelVector(.init(0, 0, 1))
    return (object.body.position - wreck.motion.pose.position).length < 1e-8
      && (orientation.x - wreck.motion.pose.orientation.x).length < 1e-8
      && (orientation.y - wreck.motion.pose.orientation.y).length < 1e-8
      && (orientation.z - wreck.motion.pose.orientation.z).length < 1e-8
      && physical.velocity == wreck.motion.velocity
      && physical.angularVelocity == wreck.motion.angularVelocity
      && object.body.energy == wreck.motion.energy && object.binding == wreck.binding
  }
}
