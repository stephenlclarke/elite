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
        coastEMPObject(&record.hull, to: now)
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
        candidate.commander.salvageLedger.updateWreck(
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
    guard captureEMPArchiveState() else { return false }
    guard let state = commander.savedEMPState else { return true }
    return state.sceneIsConsistent(
      bodies, flight: commander.flightSimulation, people: commander.nativePeople)
  }

  /// Capture keeps its original initial/final state guards and publication point.
  private mutating func captureEMPArchiveState() -> Bool {
    guard var state = commander.savedEMPState else {
      return !bodies.contains {
        $0.physical?.empSource != nil || $0.physical?.empCrewPod != nil
          || $0.physical?.spawnIdentity?.producer == .emp
      }
    }
    guard state.valid else { return false }
    let pose = commander.flightSimulation.pose
    let now = commander.flightSimulation.physicalTime
    for source in state.records.keys {
      guard var record = state.records[source] else { return false }
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
      state.records[source] = record
    }
    guard state.valid else { return false }
    commander.savedEMPState = state
    return true
  }
}
