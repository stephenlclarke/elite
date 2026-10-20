import Foundation

/// Long-course uncertainty denies entry; only a separate finite stop may be proved safe.
enum StationEntryCourseObstacleAssessment: Equatable {
  case clear, contact
  case unresolved(HullSweepFailure)
  case invalid

  var permitsFiniteStopAssessment: Bool {
    switch self {
    case .contact, .unresolved: true
    case .clear, .invalid: false
    }
  }
}

/// Ephemeral evidence created only by the actual swept entry path, never decoded from a save.
struct NativeStationEntryProof: Sendable {
  let station: NativeStationIdentity
  let binding: NativeStationBinding
  let playerPose: ShipPose
  let physicalTime: Double
  let revision: UInt64
  fileprivate init(
    station: NativeStationIdentity, binding: NativeStationBinding, playerPose: ShipPose,
    physicalTime: Double, revision: UInt64
  ) {
    self.station = station
    self.binding = binding
    self.playerPose = playerPose
    self.physicalTime = physicalTime
    self.revision = revision
  }
}

/// Non-serializable custody minted by native entry or validated save restoration only.
struct NativeStationDockEvidence: Sendable {
  let receipt: NativeStationDockReceipt
  let runtimeEpoch: UUID
  fileprivate init(receipt: NativeStationDockReceipt, runtimeEpoch: UUID) {
    self.receipt = receipt
    self.runtimeEpoch = runtimeEpoch
  }
}

struct NativeMainStationDockEvidence: Sendable {
  let receipt: NativeMainStationDockReceipt
  let runtimeEpoch: UUID
  fileprivate init(receipt: NativeMainStationDockReceipt, runtimeEpoch: UUID) {
    self.receipt = receipt
    self.runtimeEpoch = runtimeEpoch
  }
}

extension Commander {
  var nativeStationStateValid: Bool {
    guard let world = nativeStations else { return true }
    let resources = scriptState.stationResources
    let currentSystem = SystemIdentity(galaxy: galaxy, system: system)
    guard world.valid, equipmentOwnerID == world.ledger.world else { return false }
    let physicalTime = flightSimulation.physicalTime
    guard world.stationInertia.allSatisfy({ $0.physicalTime <= physicalTime }) else { return false }
    if world.stationInertia.contains(where: { $0.station.system == currentSystem }) {
      guard flightSimulation.anchors?.station.position == Vector3(0, 0, 0) else { return false }
    }
    guard let calendar = scriptState.calendarLedger, calendar.valid else { return false }
    guard
      world.mainStations.allSatisfy({ identity in
        guard let resource = resources[identity.key] else { return false }
        return resource.identity == identity.resource && resource.key == identity.key
      })
    else { return false }
    if let receipt = world.currentMainDock {
      guard receipt.station.system == currentSystem else {
        return false
      }
    }
    return world.ledger.currentDock.map {
      $0.station.system == currentSystem
    } ?? true
  }
}

extension Game {
  /// Arrival can admit a station after this tick has advanced physical time. Project its
  /// source spin from that clock instead of integrating the already-current phase again.
  mutating func advanceBodyModelRotation(at index: Int, delta: Double) {
    if let identity = bodies[index].nativeStationIdentity,
      let source = NativeStationSource.binding(for: identity)
    {
      guard
        let time = commander.nativeStations?.motionTime(
          for: .rrs(identity), at: commander.flightSimulation.physicalTime)
      else { return }
      bodies[index].rotation =
        (time * source.rotationRate)
        .truncatingRemainder(dividingBy: 2 * .pi)
    } else {
      bodies[index].rotation += delta * bodies[index].rotationRate
    }
  }

  /// Physical recharge is independent of whether manual or guided movement owns the camera.
  mutating func advanceNativeStationRecharge(delta: Double) {
    guard delta.isFinite, delta > 0, delta <= 0.1 else { return }
    for index in bodies.indices {
      guard let identity = bodies[index].nativeStationIdentity,
        let source = NativeStationSource.binding(for: identity),
        bodies[index].energy > 0, nativeStationBodyIsCurrent(bodies[index])
      else { continue }
      bodies[index].energy = min(
        source.maximumEnergy, bodies[index].energy + source.recharge * delta)
    }
  }

  mutating func activateNativeStationWorld() throws {
    try commander.prepareEquipment()
    guard commander.nativeStations == nil else {
      guard commander.nativeStationStateValid else { throw NativeStationRuntimeError.invalidState }
      return
    }
    guard let owner = commander.equipmentOwnerID else {
      throw NativeStationRuntimeError.invalidState
    }
    let world = try NativeStationWorld(owner: owner)
    ensureScriptCalendar(origin: .newCommander)
    commander.nativeStations = world
  }

  /// All actual geometry and actor-budget checks finish before allocating or publishing a cohort.
  mutating func populateNativeStations() throws {
    guard var world = commander.nativeStations else { return }
    let system = systemIdentity
    guard commander.nativeStationStateValid, let anchors = commander.flightSimulation.anchors,
      anchors.system == systemIdentity, !docked
    else { throw NativeStationRuntimeError.invalidState }
    let current = world.ledger.records.filter { $0.identity.system == system }
    let stationBodies = bodies.filter { $0.nativeStationIdentity != nil }
    guard Set(stationBodies.compactMap(\.nativeStationIdentity)).count == stationBodies.count,
      stationBodies.allSatisfy({ body in
        guard let identity = body.nativeStationIdentity, let physical = body.physical,
          let record = current.first(where: { $0.identity == identity })
        else { return false }
        return record.tombstone == nil
          && record.binding == .init(actor: physical.identity, bodyID: body.id)
      })
    else { throw NativeStationRuntimeError.invalidState }
    let absent = current.filter { record in
      record.tombstone == nil
        && !stationBodies.contains { $0.nativeStationIdentity == record.identity }
    }
    guard !absent.isEmpty else { return }
    guard bodies.filter({ $0.energy > 0 }).count + absent.count <= 128,
      bodies.reduce(0, { $0 + $1.scriptNativeUnits }) + absent.count <= 1024,
      nextBodyID > 0, nextBodyID < 1_000_000_000 - absent.count
    else { throw NativeStationRuntimeError.capacity }
    let flightBefore = commander.flightSimulation
    var selected: [(NativeStationRecord, NativeStationSavedPose, NativeStationSourceBinding)] = []
    for record in absent {
      guard let source = NativeStationSource.binding(for: record.identity),
        let saved = world.pose(for: record.identity),
        source.geometry.position(in: anchors) == saved.position,
        world.currentOrientation(for: saved.station, at: flightBefore.physicalTime) != nil,
        let position = world.currentPosition(
          for: .rrs(record.identity), at: flightBefore.physicalTime)
      else { throw NativeStationRuntimeError.invalidSource }
      let radius = nativeStationRadius(source.geometry.mesh)
      for celestial in [anchors.planet, anchors.sun] {
        guard (position - celestial.position).length > radius + celestial.radius + 8 else {
          throw NativeStationRuntimeError.unsafePlacement
        }
      }
      for body in bodies where body.energy > 0 {
        let point = flightBefore.pose.systemPoint(body.position)
        guard
          (position - point).length > radius + nativeStationRadius(gameplayMesh(for: body))
            + 8
        else { throw NativeStationRuntimeError.unsafePlacement }
      }
      for (_, other, otherSource) in selected {
        guard
          (position
            - (world.currentPosition(for: .rrs(other.station), at: flightBefore.physicalTime)
              ?? other.position))
            .length > radius
            + nativeStationRadius(otherSource.geometry.mesh) + 8
        else { throw NativeStationRuntimeError.unsafePlacement }
      }
      selected.append((record, saved, source))
    }
    var flight = flightBefore
    guard let sequence = flight.allocateSpawn() else { throw NativeStationRuntimeError.capacity }
    var admitted: [SpaceBody] = []
    for (member, entry) in selected.enumerated() {
      let (record, saved, source) = entry
      guard let actor = flight.allocateActor() else { throw NativeStationRuntimeError.capacity }
      let id = nextBodyID + member
      guard
        let currentPosition = world.currentPosition(
          for: .rrs(record.identity), at: flight.physicalTime)
      else { throw NativeStationRuntimeError.invalidState }
      var body = SpaceBody(id: id, hull: .station, position: flight.pose.shipPoint(currentPosition))
      body.nativeStationIdentity = record.identity
      body.orientation = saved.orientation.relative(to: flight.pose.orientation)
      guard let phase = world.motionTime(for: .rrs(record.identity), at: flight.physicalTime) else {
        throw NativeStationRuntimeError.invalidState
      }
      body.rotation = (phase * source.rotationRate).truncatingRemainder(dividingBy: 2 * .pi)
      body.rotationRate = source.rotationRate
      body.energy = saved.energy
      body.missiles = 0
      body.ecmEnabled = source.kind == .waystation
      body.physical = nativePhysicalActorState(
        for: body, identity: actor,
        spawnIdentity: .init(
          system: systemIdentity, visit: flight.visit, sequence: sequence,
          member: UInt16(member), producer: .mission))
      body.physical?.velocity =
        world.inertia(for: .rrs(record.identity))?.velocity ?? .init(0, 0, 0)
      try world.ledger.rebind(record.identity, to: .init(actor: actor, bodyID: id))
      admitted.append(body)
    }
    guard world.valid, flight.valid else { throw NativeStationRuntimeError.invalidState }
    commander.nativeStations = world
    commander.flightSimulation = flight
    nextBodyID += admitted.count
    bodies.append(contentsOf: admitted)
  }

  private func nativeStationRadius(_ mesh: Mesh) -> Double {
    mesh.vertices.map(\.length).max() ?? .infinity
  }

  /// Save damage and genuine destruction before any scene body can be removed or rebound.
  mutating func persistNativeStationConditions() throws {
    let system = systemIdentity
    guard var world = commander.nativeStations else {
      guard !bodies.contains(where: { $0.nativeStationIdentity != nil }) else {
        throw NativeStationRuntimeError.invalidState
      }
      return
    }
    try persistKnownNativeStationConditions(world: &world, system: system)
  }

  private mutating func persistKnownNativeStationConditions(
    world: inout NativeStationWorld, system: SystemIdentity
  ) throws {
    guard world.valid else { throw NativeStationRuntimeError.invalidState }
    if let main = bodies.first(where: { $0.id == 0 && $0.hull == .station }),
      let original = world.mainStations.first(where: { $0.system == system }),
      main.physical?.identity == commander.flightSimulation.anchors?.station.identity,
      var resource = commander.scriptState.stationResources[original.key],
      resource.identity == original.resource
    {
      guard main.energy.isFinite else {
        throw NativeStationRuntimeError.invalidState
      }
      if !resource.destroyed {
        resource.energy = max(0, main.energy)
        if main.energy <= 0 { resource.destroyed = true }
        commander.scriptState.stationResources[original.key] = resource
      }
    }
    for body in bodies where body.nativeStationIdentity != nil {
      guard let identity = body.nativeStationIdentity, let physical = body.physical,
        let record = world.ledger.records.first(where: { $0.identity == identity }),
        let index = world.poses.firstIndex(where: { $0.station == identity }),
        (record.binding ?? record.tombstone?.destroyedBinding)
          == .init(actor: physical.identity, bodyID: body.id),
        let source = NativeStationSource.binding(for: identity), body.energy.isFinite,
        body.energy <= source.maximumEnergy
      else { throw NativeStationRuntimeError.invalidState }
      if record.tombstone != nil {
        guard body.energy <= 0 else { throw NativeStationRuntimeError.invalidState }
        continue
      }
      let condition = max(0, body.energy)
      if world.poses[index].energy != condition { world.poses[index].energy = condition }
      if body.energy <= 0 {
        try world.ledger.destroy(
          identity, binding: .init(actor: physical.identity, bodyID: body.id))
      }
    }
    guard world.valid else { throw NativeStationRuntimeError.invalidState }
    commander.nativeStations = world
  }

  func nativeStationBodyIsCurrent(_ body: SpaceBody) -> Bool {
    withReadOnlyCommander { commander in
      Self.nativeStationBodyIsCurrent(body, commander: commander)
    }
  }

  private static func nativeStationBodyIsCurrent(
    _ body: borrowing SpaceBody, commander: borrowing Commander
  ) -> Bool {
    guard let identity = body.nativeStationIdentity, let physical = body.physical,
      let world = commander.nativeStations, commander.nativeStationStateValid,
      let record = world.ledger.records.first(where: { $0.identity == identity })
    else { return false }
    let currentSystem = SystemIdentity(galaxy: commander.galaxy, system: commander.system)
    guard identity.system == currentSystem, record.tombstone == nil, body.energy > 0,
      physical.identity.system == currentSystem,
      physical.identity.visit == commander.flightSimulation.visit,
      record.binding == .init(actor: physical.identity, bodyID: body.id)
    else { return false }
    return true
  }

  mutating func invalidateNativeStationAuthority() {
    let retainedRRS = nativeStationDockEvidenceIsCurrent
    let retainedMain = nativeMainStationDockEvidenceIsCurrent
    nativeStationRuntimeEpoch = UUID()
    pendingNativeStationDock = nil
    nativeStationDockEvidence =
      retainedRRS
      ? commander.nativeStations?.ledger.currentDock.map {
        .init(receipt: $0, runtimeEpoch: nativeStationRuntimeEpoch)
      } : nil
    nativeMainStationDockEvidence =
      retainedMain
      ? commander.nativeStations?.currentMainDock.map {
        .init(receipt: $0, runtimeEpoch: nativeStationRuntimeEpoch)
      } : nil
  }

  var nativeStationDockEvidenceIsCurrent: Bool {
    guard docked, !dockedAtMainStation, let evidence = nativeStationDockEvidence else {
      return false
    }
    return evidence.runtimeEpoch == nativeStationRuntimeEpoch
      && evidence.receipt == commander.nativeStations?.ledger.currentDock
  }

  var nativeMainStationDockEvidenceIsCurrent: Bool {
    guard docked, dockedAtMainStation, let evidence = nativeMainStationDockEvidence else {
      return false
    }
    return evidence.runtimeEpoch == nativeStationRuntimeEpoch
      && evidence.receipt == commander.nativeStations?.currentMainDock
  }

  /// Rebind a validated retained scene without replaying docking or reissuing station condition.
  mutating func rebindNativeStationsAfterLoad() throws {
    invalidateNativeStationAuthority()
    guard var world = commander.nativeStations else { return }
    guard
      world.sceneIsConsistent(
        bodies: bodies, docked: docked, mainStation: dockedAtMainStation,
        system: systemIdentity, flight: commander.flightSimulation)
    else { throw NativeStationRuntimeError.invalidState }
    if docked, !dockedAtMainStation, let receipt = world.ledger.currentDock {
      nativeStationDockEvidence = .init(receipt: receipt, runtimeEpoch: nativeStationRuntimeEpoch)
    }
    if docked, dockedAtMainStation, let receipt = world.currentMainDock {
      nativeMainStationDockEvidence = .init(
        receipt: receipt, runtimeEpoch: nativeStationRuntimeEpoch)
    }
    let originalBodies = bodies
    let indices = originalBodies.indices.filter { originalBodies[$0].nativeStationIdentity != nil }
    guard !indices.isEmpty else { return }
    guard nextBodyID > 0, nextBodyID < 1_000_000_000 - indices.count else {
      throw NativeStationRuntimeError.capacity
    }
    var flight = commander.flightSimulation
    guard let sequence = flight.allocateSpawn() else { throw NativeStationRuntimeError.capacity }
    var replacements: [(Int, SpaceBody)] = []
    for (member, index) in indices.enumerated() {
      var body = bodies[index]
      guard let station = body.nativeStationIdentity, let old = body.physical,
        let actor = flight.allocateActor()
      else { throw NativeStationRuntimeError.invalidState }
      body.id = nextBodyID + member
      body.physical = .init(
        identity: actor, population: old.population, npc: old.npc, velocity: old.velocity,
        laserCooldown: old.laserCooldown, rock: old.rock, payload: old.payload,
        attackOrigin: old.attackOrigin, emissionPosition: old.emissionPosition,
        deathOrigin: old.deathOrigin, deathIncidentID: old.deathIncidentID, ordnance: old.ordnance,
        spawnIdentity: .init(
          system: systemIdentity, visit: flight.visit, sequence: sequence,
          member: UInt16(member), producer: .mission),
        blocksNavalEncounter: old.blocksNavalEncounter, catalogueShipID: old.catalogueShipID,
        angularVelocity: old.angularVelocity, canonicalSpin: old.canonicalSpin,
        salvage: old.salvage, suspendedNPCIntention: old.suspendedNPCIntention)
      try world.ledger.rebind(station, to: .init(actor: actor, bodyID: body.id))
      replacements.append((index, body))
    }
    guard world.valid, flight.valid else { throw NativeStationRuntimeError.invalidState }
    for (index, body) in replacements { bodies[index] = body }
    commander.nativeStations = world
    commander.flightSimulation = flight
    nextBodyID += replacements.count
    gameplayRevision &+= 1
  }

  /// Register only an actually loaded original body, after existing main-resource restoration.
  mutating func registerOriginalNativeMainStation() throws {
    try projectRegisteredMainStationForScene()
    guard var world = commander.nativeStations, let anchors = commander.flightSimulation.anchors,
      let currentAnchor = currentNativeMainStationAnchor(
        at: commander.flightSimulation.physicalTime),
      let station = bodies.first(where: { $0.id == 0 && $0.hull == .station }), station.energy > 0,
      station.physical?.identity == anchors.station.identity,
      bodies.filter({ $0.physical?.identity == anchors.station.identity }).count == 1,
      anchors.station.identity.entity == 1, anchors.system == systemIdentity,
      (commander.flightSimulation.pose.systemPoint(station.position) - currentAnchor.position)
        .length < 1e-5
    else { return }
    let key = contractStation.key
    let identity = NativeMainStationIdentity(
      world: world.ledger.world, system: systemIdentity,
      resource: Self.worldResourceIdentity("main-station-v1:\(key)"))
    if let resource = commander.scriptState.stationResources[key] {
      guard resource.identity == identity.resource else {
        throw NativeStationRuntimeError.invalidSource
      }
      if resource.destroyed { return }
    } else {
      guard commander.scriptState.stationResources.count < NativeMainStationIdentity.maximumCount
      else { return }
      var resource = ScriptStationResource(
        identity: identity.resource, galaxy: commander.galaxy, system: commander.system)
      resource.energy = station.energy
      commander.scriptState.stationResources[key] = resource
    }
    if !world.mainStations.contains(identity) {
      guard world.mainStations.count < NativeMainStationIdentity.maximumCount else {
        throw NativeStationRuntimeError.capacity
      }
      world.mainStations.append(identity)
    }
    let observation = NativeMainStationObservation(
      station: identity, actor: anchors.station.identity,
      calendarSeconds: commander.scriptState.calendarSeconds)
    if let index = world.mainObservations.firstIndex(where: { $0.station == identity }) {
      world.mainObservations[index] = observation
    } else {
      guard world.mainObservations.count < NativeMainStationIdentity.maximumCount else {
        throw NativeStationRuntimeError.capacity
      }
      world.mainObservations.append(observation)
    }
    guard world.valid else { throw NativeStationRuntimeError.invalidState }
    commander.nativeStations = world
  }

  /// The legacy Boolean dock API issues no arrival. Only actual native doorway entry calls this.
  mutating func dockAtOriginalNativeMainStation(
    _ station: SpaceBody, from before: ShipPose, delta: Double
  ) {
    guard delta.isFinite, delta > 0, delta <= 0.1,
      nativeMainStationHullCourseIsClear(
        station, from: before, to: commander.flightSimulation.pose, delta: delta)
    else { return }
    let system = systemIdentity
    guard let world = commander.nativeStations else {
      dock()
      return
    }
    let pose = commander.flightSimulation.pose
    let normal = pose.orientation.apply(station.entranceNormal)
    let entrance = pose.systemPoint(station.entrancePosition)
    let oldEntrance: Vector3
    if let id = world.mainStations.first(where: { $0.system == system }),
      world.inertia(for: .main(id)) != nil
    {
      guard
        let previous = world.currentPosition(
          for: .main(id), at: max(0, commander.flightSimulation.physicalTime - delta)),
        let current = world.currentPosition(
          for: .main(id), at: commander.flightSimulation.physicalTime)
      else {
        dock()
        return
      }
      oldEntrance = entrance + previous - current
    } else {
      oldEntrance = entrance
    }
    guard let actor = station.physical?.identity,
      bodies.first(where: { $0.id == 0 }) == station,
      bodies.filter({ $0.id == 0 }).count == 1,
      station.containsPlayer,
      station.canEnter(roll: roll, speed: nativeStationRelativeEntrySpeed(station)),
      (before.position - oldEntrance).dot(normal) >= 0,
      (pose.position - entrance).dot(normal) < 0,
      let identity = world.mainStations.first(where: { $0.system == system }),
      actor == commander.flightSimulation.anchors?.station.identity,
      station.id == 0, station.energy > 0, actor.entity == 1,
      let resource = commander.scriptState.stationResources[identity.key],
      resource.identity == identity.resource, !resource.destroyed, resource.energy > 0,
      world.nextMainDockSequence < UInt64(Int64.max) - 1
    else {
      dock()
      return
    }
    let receipt = NativeMainStationDockReceipt(
      station: identity, actor: actor, commanderOwner: world.ledger.world,
      sequence: world.nextMainDockSequence, calendarSeconds: commander.scriptState.calendarSeconds)
    dock()
    guard docked, dockedAtMainStation, var updated = commander.nativeStations else { return }
    updated.ledger.depart()
    updated.currentMainDock = receipt
    updated.nextMainDockSequence += 1
    guard updated.valid else { return }
    commander.nativeStations = updated
    invalidateNativeStationAuthority()
    nativeMainStationDockEvidence = .init(receipt: receipt, runtimeEpoch: nativeStationRuntimeEpoch)
  }

  /// This is evaluated by native movement, with the real effective hull at both sweep endpoints.
  mutating func detectNativeStationEntry(from before: ShipPose, delta: Double) {
    guard !docked, pendingNativeStationDock == nil, delta.isFinite, delta > 0, delta <= 0.1,
      let world = commander.nativeStations
    else { return }
    let flight = commander.flightSimulation
    for body in bodies where body.nativeStationIdentity != nil && nativeStationBodyIsCurrent(body) {
      guard world.bodyRigidPoseIsConsistent(body, flight: flight),
        let identity = body.nativeStationIdentity, let physical = body.physical,
        let saved = world.pose(for: identity),
        let source = NativeStationSource.binding(for: identity),
        let orientation = world.currentOrientation(for: saved.station, at: flight.physicalTime),
        let oldOrientation = world.currentOrientation(
          for: saved.station, at: max(0, flight.physicalTime - delta)),
        let oldPosition = world.currentPosition(
          for: .rrs(identity), at: max(0, flight.physicalTime - delta)),
        let currentPosition = world.currentPosition(for: .rrs(identity), at: flight.physicalTime)
      else { continue }
      let port = source.geometry.docking
      let start = oldOrientation.inverse(before.position - oldPosition) - port.center
      let end = orientation.inverse(flight.pose.position - currentPosition) - port.center
      let oldDepth = start.dot(port.outward)
      let depth = end.dot(port.outward)
      guard oldDepth > 0, depth <= 0, depth > -port.tunnelDepth,
        nativeStationRelativeEntrySpeed(body) < 144,
        flight.pose.orientation.z.dot(orientation.apply(port.outward)) < -0.995,
        flight.pose.orientation.y.dot(orientation.apply(port.up)) > 0.995,
        abs(roll + source.rotationRate * body.orientation.z.z) < 0.1
      else { continue }
      let player = commander.playerMesh
      let radius = nativeStationRadius(player)
      let angularSweep = (abs(pitch) + abs(roll) + abs(yaw) + source.rotationRate) * delta
      let margin =
        (radius + max(start.length, end.length)) * angularSweep
        + world.stationSweepMargin(
          .rrs(identity), from: max(0, flight.physicalTime - delta),
          to: flight.physicalTime)
      guard margin.isFinite, port.fits(player, margin: margin),
        nativeStationHullFits(
          player, ship: before, station: oldPosition, orientation: oldOrientation, port: port,
          margin: margin),
        nativeStationHullFits(
          player, ship: flight.pose, station: currentPosition, orientation: orientation, port: port,
          margin: margin),
        nativeStationHullSweepClear(
          player, from: before, to: flight.pose, saved: saved,
          fromOrientation: oldOrientation, toOrientation: orientation, margin: margin,
          mesh: source.geometry.mesh, fromPosition: oldPosition, toPosition: currentPosition),
        nativeStationApproachClear(
          from: before.position, to: flight.pose.position,
          excluding: body.id, radius: radius + margin)
      else { continue }
      pendingNativeStationDock = .init(
        station: identity, binding: .init(actor: physical.identity, bodyID: body.id),
        playerPose: flight.pose, physicalTime: flight.physicalTime, revision: gameplayRevision)
      return
    }
  }

  /// Real effective-hull clearance against the same main-port mesh used by rendering and rays.
  /// The optional elapsed step uses the station's actual prior translation and spin.
  func nativeMainStationHullCourseIsClear(
    _ station: SpaceBody, from start: ShipPose, to end: ShipPose,
    delta: Double = 0, requireAperture: Bool = true
  ) -> Bool {
    var observation: [String: String]?
    return nativeMainStationHullCourseIsClear(
      station, from: start, to: end, delta: delta, requireAperture: requireAperture,
      observation: &observation)
  }

  private func nativeMainStationHullCourseIsClear(
    _ station: SpaceBody, from start: ShipPose, to end: ShipPose,
    delta: Double = 0, requireAperture: Bool = true, observation: inout [String: String]?
  ) -> Bool {
    let flight = commander.flightSimulation
    observation?["refusal"] = "main.current-source"
    guard delta.isFinite, delta >= 0, delta <= 0.1,
      station.id == 0, station.hull == .station, station.nativeStationIdentity == nil,
      let world = commander.nativeStations,
      let identity = world.mainStations.first(where: { $0.system == systemIdentity }),
      station.physical?.identity == flight.anchors?.station.identity,
      bodies.filter({ $0.id == 0 }).count == 1,
      bodies.first(where: { $0.id == 0 }) == station,
      let current = currentNativeMainStationAnchor(at: flight.physicalTime),
      let previous = currentNativeMainStationAnchor(at: max(0, flight.physicalTime - delta)),
      (flight.pose.systemPoint(station.position) - current.position).length < 1e-5,
      [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)].allSatisfy({
        (flight.pose.orientation.apply(station.orientation.apply($0))
          - current.orientation.apply($0)).length < 1e-5
      })
    else { return false }
    let player = commander.playerMesh
    let geometry = MainStationGeometry.mesh
    let port = MainStationGeometry.docking
    let endOrientation = modelPose(of: station).orientation
    var unspin = Basis3()
    unspin.rotate(pitch: 0, roll: -station.rotationRate * delta, yaw: 0)
    let startOrientation = endOrientation.composed(with: unspin)
    let angularBound = (abs(pitch) + abs(roll) + abs(yaw) + abs(station.rotationRate)) * delta
    let translationMargin = world.stationSweepMargin(
      .main(identity), from: max(0, flight.physicalTime - delta), to: flight.physicalTime)
    let margin =
      (nativeStationRadius(player) + nativeStationRadius(geometry)) * angularBound
      + translationMargin
    observation?["refusal"] = "main.margin"
    observation?["geometryMargin"] = String(margin)
    observation?["geometryDelta"] = String(delta)
    guard margin.isFinite else { return false }
    if requireAperture {
      observation?["refusal"] = "main.aperture-shape"
      guard port.fits(player, margin: margin) else { return false }
      observation?["refusal"] = "main.aperture-start"
      guard
        nativeStationHullFits(
          player, ship: start, station: previous.position, orientation: startOrientation,
          port: port, margin: margin)
      else { return false }
      observation?["refusal"] = "main.aperture-end"
      guard
        nativeStationHullFits(
          player, ship: end, station: current.position, orientation: endOrientation,
          port: port, margin: margin)
      else { return false }
    }
    observation?["refusal"] = "main.structure"
    return nativeStructureHullSweepClear(
      player, from: start, to: end, position: previous.position, endPosition: current.position,
      fromOrientation: startOrientation, toOrientation: endOrientation,
      margin: margin, mesh: geometry)
  }

  /// Reuse native source, aperture and corridor checks for a proposed approach.
  /// The relative frame at the door is geometry only and is never installed or minted as entry.
  mutating func nativeStationAutoEntryCourseIsClear(
    _ station: SpaceBody, advance: Vector3, terminalSpeed: Double
  ) -> Bool {
    var observation: [String: String]?
    var bodyCourseRefused = false
    return nativeStationAutoEntryCourseIsClear(
      station, advance: advance, terminalSpeed: terminalSpeed, observation: &observation,
      bodyCourseRefused: &bodyCourseRefused)
  }

  mutating func nativeStationAutoEntryCourseIsClear(
    _ station: SpaceBody, advance: Vector3, terminalSpeed: Double,
    observation: inout [String: String]?, bodyCourseRefused: inout Bool
  ) -> Bool {
    bodyCourseRefused = false
    observation?["refusal"] = "native.state"
    let stateValid = commander.nativeStationStateValid
    observation?["nativeStateValid"] = String(stateValid)
    guard stateValid, let world = commander.nativeStations, let physical = station.physical
    else { return false }
    observation?["refusal"] = "native.advance"
    guard advance.finite else { return false }
    observation?["refusal"] = "native.motion-binding"
    let velocityError = (physical.velocity - nativeStationVelocity(station)).length
    observation?["stationVelocityError"] = String(velocityError)
    guard velocityError < 1e-7,
      bodies.filter({ $0.id == station.id }).count == 1,
      bodies.first(where: { $0.id == station.id }) == station
    else { return false }
    let flight = commander.flightSimulation
    let player = commander.playerMesh
    observation?["playerShip"] = commander.shipID
    var endpoint = flight.pose
    endpoint.position = flight.pose.systemPoint(advance)
    if let identity = station.nativeStationIdentity {
      observation?["refusal"] = "rrs.current-source"
      guard nativeStationBodyIsCurrent(station),
        world.bodyRigidPoseIsConsistent(station, flight: flight),
        let source = NativeStationSource.binding(for: identity),
        let position = world.currentPosition(for: .rrs(identity), at: flight.physicalTime),
        let orientation = world.currentOrientation(for: identity, at: flight.physicalTime)
      else { return false }
      observation?["refusal"] = "rrs.aperture-shape"
      guard source.geometry.docking.fits(player) else { return false }
      observation?["refusal"] = "rrs.aperture-start"
      guard
        nativeStationHullFits(
          player, ship: flight.pose, station: position, orientation: orientation,
          port: source.geometry.docking, margin: 0)
      else { return false }
      observation?["refusal"] = "rrs.aperture-end"
      guard
        nativeStationHullFits(
          player, ship: endpoint, station: position, orientation: orientation,
          port: source.geometry.docking, margin: 0)
      else { return false }
      observation?["refusal"] = "rrs.structure"
      guard
        nativeStructureHullSweepClear(
          player, from: flight.pose, to: endpoint, position: position,
          fromOrientation: orientation, toOrientation: orientation, margin: 0,
          mesh: source.geometry.mesh)
      else { return false }
    } else {
      observation?["refusal"] = "main.actor-source"
      guard station.id == 0, physical.identity == flight.anchors?.station.identity,
        let anchor = currentNativeMainStationAnchor(at: flight.physicalTime)
      else { return false }
      observation?["refusal"] = "main.position-source"
      let positionError = (flight.pose.systemPoint(station.position) - anchor.position).length
      observation?["stationPositionError"] = String(positionError)
      guard positionError < 1e-5 else { return false }
      observation?["refusal"] = "main.basis-source"
      guard
        [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)].allSatisfy({
          let error =
            (flight.pose.orientation.apply(station.orientation.apply($0))
            - anchor.orientation.apply($0)).length
          observation?["stationBasisError"] = String(error)
          return error < 1e-5
        })
      else { return false }
      observation?["refusal"] = "main.resource-source"
      guard let identity = world.mainStations.first(where: { $0.system == systemIdentity }),
        let resource = commander.scriptState.stationResources[identity.key],
        resource.identity == identity.resource, !resource.destroyed, resource.energy > 0
      else { return false }
      var atDoor = station
      atDoor.position = atDoor.position - advance
      observation?["refusal"] = "main.centre-entry"
      guard atDoor.canEnter(roll: autoPilot.rollRate, speed: terminalSpeed) else { return false }
      guard
        nativeMainStationHullCourseIsClear(
          station, from: flight.pose, to: endpoint, observation: &observation)
      else { return false }
    }
    let radius = nativeStationRadius(player)
    observation?["playerRadius"] = String(radius)
    observation?["refusal"] = "corridor.player-radius"
    guard radius.isFinite else { return false }
    let clear = nativeStationApproachClear(
      from: flight.pose.position, to: flight.pose.systemPoint(advance),
      excluding: station.id, radius: radius, observation: &observation,
      refineCourse: true, bodyCourseRefused: &bodyCourseRefused)
    if clear { observation?["refusal"] = "none" }
    return clear
  }

  private mutating func nativeStationApproachClear(
    from start: Vector3, to end: Vector3, excluding stationID: Int, radius: Double
  ) -> Bool {
    var observation: [String: String]?
    var bodyCourseRefused = false
    return nativeStationApproachClear(
      from: start, to: end, excluding: stationID, radius: radius, observation: &observation,
      refineCourse: false, bodyCourseRefused: &bodyCourseRefused)
  }

  private mutating func nativeStationApproachClear(
    from start: Vector3, to end: Vector3, excluding stationID: Int, radius: Double,
    observation: inout [String: String]?, refineCourse: Bool, bodyCourseRefused: inout Bool
  ) -> Bool {
    bodyCourseRefused = false
    observation?["refusal"] = "corridor.context"
    guard let anchors = commander.flightSimulation.anchors, radius.isFinite else { return false }
    for (index, celestial) in [anchors.planet, anchors.sun].enumerated() {
      let distance = distanceFromNativeSegment(celestial.position, start: start, end: end)
      let bound = radius + celestial.radius
      if refineCourse {
        guard celestial.position.finite, celestial.radius.isFinite, celestial.radius > 0,
          distance.isFinite, bound.isFinite
        else {
          observation?["refusal"] = "corridor.unproven-celestial"
          return false
        }
      }
      if distance <= bound {
        observation?["refusal"] = "corridor.celestial"
        observation?["blocker"] = index == 0 ? "planet" : "sun"
        observation?["blockerDistance"] = String(distance)
        observation?["blockerBound"] = String(bound)
        return false
      }
    }
    for body in bodies
    where (body.energy > 0 || (refineCourse && !body.energy.isFinite)) && body.id != stationID {
      let point = commander.flightSimulation.pose.systemPoint(body.position)
      let distance = distanceFromNativeSegment(point, start: start, end: end)
      let mesh: Mesh
      if refineCourse, body.scriptNPC != nil {
        guard let source = scriptNPCMesh(body) else { return false }
        mesh = source
      } else {
        mesh = gameplayMesh(for: body)
      }
      let bodyRadius = nativeStationRadius(mesh)
      if refineCourse {
        guard body.energy.isFinite, point.finite, distance.isFinite,
          bodyRadius.isFinite, bodyRadius > 0,
          mesh.vertices.count >= 4, mesh.faces.count >= 4,
          mesh.vertices.allSatisfy({ $0.finite }),
          mesh.faces.allSatisfy({
            $0.count >= 3 && $0.allSatisfy { mesh.vertices.indices.contains($0) }
          })
        else {
          observation?["refusal"] = "corridor.unproven-body"
          observation?["blocker"] = String(body.id)
          return false
        }
      }
      let bound = radius + bodyRadius
      if distance <= bound {
        if refineCourse {
          let assessment = nativeStationCourseObstacleAssessment(
            body, from: start, to: end, radius: radius, mesh: mesh)
          if assessment == .clear { continue }
          bodyCourseRefused = assessment.permitsFiniteStopAssessment
          if assessment != .contact {
            if case .unresolved(let failure) = assessment {
              observation?["refusal"] = "corridor.unproven-body.\(failure)"
            } else {
              observation?["refusal"] = "corridor.unproven-body"
            }
            observation?["blocker"] = String(body.id)
            return false
          }
        }
        observation?["refusal"] = "corridor.body"
        observation?["blocker"] = String(body.id)
        observation?["blockerActor"] = body.physical.map { String($0.identity.entity) } ?? "nil"
        observation?["blockerHull"] = body.hull.rawValue
        observation?["blockerCatalogue"] = body.physical?.catalogueShipID ?? "nil"
        observation?["blockerPosition"] = "\(point.x),\(point.y),\(point.z)"
        observation?["blockerDistance"] = String(distance)
        observation?["blockerBound"] = String(bound)
        return false
      }
    }
    return true
  }

  /// Current-course geometry only. Native entry retains its independent clearance gate.
  /// Exact maintained mesh distance and containment distinguish material contact
  /// from overlapping enclosing spheres. Prepared geometry uses the existing bounded cache.
  mutating func nativeStationCourseObstacleAssessment(
    _ body: SpaceBody, from start: Vector3, to end: Vector3, radius: Double,
    mesh actualMesh: Mesh? = nil
  ) -> StationEntryCourseObstacleAssessment {
    let flight = commander.flightSimulation
    guard let physical = body.physical,
      physical.identity.system == systemIdentity, physical.identity.visit == flight.visit,
      physical.velocity.finite, body.rotation.isFinite, body.rotationRate.isFinite,
      bodies.filter({ $0.id == body.id }).count == 1,
      bodies.first(where: { $0.id == body.id }) == body,
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1
    else { return .invalid }
    if let id = physical.catalogueShipID, ShipCatalogue.ship(id) == nil { return .invalid }
    let mesh: Mesh
    if let actualMesh {
      mesh = actualMesh
    } else if body.scriptNPC != nil {
      guard let source = scriptNPCMesh(body) else { return .invalid }
      mesh = source
    } else {
      mesh = gameplayMesh(for: body)
    }
    guard mesh.vertices.count >= 4, mesh.faces.count >= 4,
      mesh.vertices.allSatisfy({ $0.finite }),
      mesh.faces.allSatisfy({
        $0.count >= 3 && $0.allSatisfy { mesh.vertices.indices.contains($0) }
      })
    else { return .invalid }
    let obstacle = modelPose(of: body)
    let frame = flight.pose.orientation
    let bodyRadius = nativeStationRadius(mesh)
    let player = commander.playerMesh
    let playerRadius = nativeStationRadius(player)
    guard obstacle.position.finite, obstacle.orientation.validRotation, frame.validRotation,
      bodyRadius.isFinite, bodyRadius > 0, playerRadius.isFinite, radius >= playerRadius
    else { return .invalid }
    guard
      let playerHull = preparedWorkHull(
        mesh: player, key: "station-entry-player:" + commander.shipID),
      let bodyHull = preparedWorkHull(mesh: mesh, key: "station-entry-body:\(body.id)")
    else { return .invalid }
    // Unit-duration interpolation describes the current geometric corridor only;
    // it predicts no NPC motion and creates no native crossing authority.
    let motion = HullSceneMotion(
      start: .init(position: start, orientation: frame),
      end: .init(position: end, orientation: frame), initialVelocity: end - start,
      acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0), duration: 1,
      playerRadius: radius, requiredClearance: radius - playerRadius)
    let result = HullSweepSafety.validateSceneMotion(
      motion, player: playerHull,
      obstacles: [.init(identity: physical.identity, hull: bodyHull, pose: obstacle)],
      budget: .standard)
    switch result.failure {
    case nil: return .clear
    case .insideHull, .clearanceViolation: return .contact
    case .unproven: return .unresolved(.unproven)
    case .workBudgetExceeded: return .unresolved(.workBudgetExceeded)
    default: return .invalid
    }
  }

  /// A conservative box encloses every effective-hull vertex at both sweep ends and
  /// expands by the angular-motion bound. Triangle clipping detects face/edge contacts too.
  func nativeStationHullSweepClear(
    _ player: Mesh, from start: ShipPose, to end: ShipPose, saved: NativeStationSavedPose,
    fromOrientation: Basis3, toOrientation: Basis3, margin: Double, mesh: Mesh,
    fromPosition: Vector3? = nil, toPosition: Vector3? = nil
  ) -> Bool {
    nativeStructureHullSweepClear(
      player, from: start, to: end,
      position: fromPosition ?? saved.position,
      endPosition: toPosition ?? fromPosition ?? saved.position,
      fromOrientation: fromOrientation, toOrientation: toOrientation, margin: margin, mesh: mesh)
  }

  private func nativeStructureHullSweepClear(
    _ player: Mesh, from start: ShipPose, to end: ShipPose, position: Vector3,
    endPosition: Vector3? = nil,
    fromOrientation: Basis3, toOrientation: Basis3, margin: Double, mesh: Mesh
  ) -> Bool {
    let points = player.vertices.flatMap { vertex in
      [
        fromOrientation.inverse(start.systemPoint(vertex) - position),
        toOrientation.inverse(end.systemPoint(vertex) - (endPosition ?? position)),
      ]
    }
    guard !points.isEmpty, points.allSatisfy({ $0.finite }), margin.isFinite, margin >= 0 else {
      return false
    }
    let bounds = [
      (points.map(\.x).min()! - margin, points.map(\.x).max()! + margin),
      (points.map(\.y).min()! - margin, points.map(\.y).max()! + margin),
      (points.map(\.z).min()! - margin, points.map(\.z).max()! + margin),
    ]
    for face in mesh.faces {
      guard face.count >= 3, face.allSatisfy({ mesh.vertices.indices.contains($0) }) else {
        return false
      }
      for index in 1..<(face.count - 1) {
        var clipped = [
          mesh.vertices[face[0]], mesh.vertices[face[index]], mesh.vertices[face[index + 1]],
        ]
        for axis in 0..<3 {
          clipped = clipNativeStationTriangle(
            clipped, axis: axis, bound: bounds[axis].0, lower: true)
          clipped = clipNativeStationTriangle(
            clipped, axis: axis, bound: bounds[axis].1, lower: false)
        }
        if !clipped.isEmpty { return false }
      }
    }
    return true
  }

  private func clipNativeStationTriangle(
    _ vertices: [Vector3], axis: Int, bound: Double, lower: Bool
  ) -> [Vector3] {
    guard let last = vertices.last else { return [] }
    func coordinate(_ point: Vector3) -> Double {
      axis == 0 ? point.x : axis == 1 ? point.y : point.z
    }
    func inside(_ point: Vector3) -> Bool {
      lower ? coordinate(point) >= bound : coordinate(point) <= bound
    }
    var result: [Vector3] = []
    var previous = last
    for point in vertices {
      if inside(point) != inside(previous) {
        let denominator = coordinate(point) - coordinate(previous)
        guard denominator != 0 else { return vertices }
        result.append(
          previous + (point - previous) * ((bound - coordinate(previous)) / denominator))
      }
      if inside(point) { result.append(point) }
      previous = point
    }
    return result
  }

  mutating func collideWithNativeStationStructures(from before: ShipPose, delta: Double) {
    guard !docked, pendingNativeStationDock == nil, let world = commander.nativeStations else {
      return
    }
    let flight = commander.flightSimulation
    let player = commander.playerMesh
    let playerRadius = nativeStationRadius(player)
    if let main = bodies.first(where: { $0.id == 0 && $0.hull == .station }),
      let identity = world.mainStations.first(where: { $0.system == systemIdentity }),
      let previous = currentNativeMainStationAnchor(at: max(0, flight.physicalTime - delta)),
      let current = currentNativeMainStationAnchor(at: flight.physicalTime)
    {
      let displacement = (flight.pose.position - before.position).length
      let translationMargin = world.stationSweepMargin(
        .main(identity), from: max(0, flight.physicalTime - delta), to: flight.physicalTime)
      let stationDisplacement = (current.position - previous.position).length + translationMargin
      let radius = nativeStationRadius(MainStationGeometry.mesh)
      if main.position.length <= radius + playerRadius + displacement + stationDisplacement,
        !nativeMainStationHullCourseIsClear(
          main, from: before, to: flight.pose, delta: delta, requireAperture: false)
      {
        stopAtStationImpact(at: before)
        applyDamage(delta * 100, front: true)
        notify("DOCKING COLLISION", voiced: false)
        return
      }
    }
    for body in bodies where body.nativeStationIdentity != nil && nativeStationBodyIsCurrent(body) {
      guard let identity = body.nativeStationIdentity, let saved = world.pose(for: identity),
        let source = NativeStationSource.binding(for: identity),
        let end = world.currentOrientation(for: saved.station, at: flight.physicalTime),
        let start = world.currentOrientation(
          for: saved.station, at: max(0, flight.physicalTime - delta)),
        let oldPosition = world.currentPosition(
          for: .rrs(identity), at: max(0, flight.physicalTime - delta)),
        let currentPosition = world.currentPosition(for: .rrs(identity), at: flight.physicalTime)
      else { continue }
      let translationMargin = world.stationSweepMargin(
        .rrs(identity), from: max(0, flight.physicalTime - delta), to: flight.physicalTime)
      let displacement =
        (flight.pose.position - before.position).length
        + (currentPosition - oldPosition).length + translationMargin
      let radius = nativeStationRadius(source.geometry.mesh)
      guard (currentPosition - flight.pose.position).length <= radius + playerRadius + displacement
      else { continue }
      let angle = (abs(pitch) + abs(roll) + abs(yaw) + source.rotationRate) * delta
      let margin =
        (radius + playerRadius + displacement) * angle
        + translationMargin
      if !nativeStationHullSweepClear(
        player, from: before, to: flight.pose, saved: saved,
        fromOrientation: start, toOrientation: end, margin: margin, mesh: source.geometry.mesh,
        fromPosition: oldPosition, toPosition: currentPosition)
      {
        guard
          let retained = nativeStationImpactPose(
            before: before, body: body, saved: saved, from: start, to: end,
            delta: delta, player: player, source: source,
            oldPosition: oldPosition, currentPosition: currentPosition)
        else {
          stopAtStationImpact(at: before)
          applyDamage(delta * 100, front: true)
          paused = true
          notify("STATION CONTACT UNRESOLVED - FLIGHT PAUSED", voiced: false)
          return
        }
        stopAtStationImpact(at: retained)
        applyDamage(delta * 100, front: true)
        notify("RRS DOCKING COLLISION", voiced: false)
        return
      }
    }
  }

  /// A moving surface may reach the prior ship pose. Carry that pose by the actual
  /// station rotation only when necessary; this preserves its prior relative hull
  /// clearance and bounds displacement by the material surface's real movement.
  private mutating func nativeStationImpactPose(
    before: ShipPose, body: SpaceBody, saved: NativeStationSavedPose,
    from start: Basis3, to end: Basis3, delta: Double, player: Mesh,
    source: NativeStationSourceBinding, oldPosition: Vector3, currentPosition: Vector3
  ) -> ShipPose? {
    let mesh = source.geometry.mesh
    if nativeStationHullSweepClear(
      player, from: before, to: before, saved: saved,
      fromOrientation: end, toOrientation: end, margin: 0, mesh: mesh,
      fromPosition: currentPosition, toPosition: currentPosition)
    {
      return before
    }
    guard
      nativeStationHullSweepClear(
        player, from: before, to: before, saved: saved,
        fromOrientation: start, toOrientation: start, margin: 0, mesh: mesh,
        fromPosition: oldPosition, toPosition: oldPosition)
    else { return nil }
    let rotation = end.composed(with: start.transposed)
    let retained = ShipPose(
      position: currentPosition + end.apply(start.inverse(before.position - oldPosition)),
      orientation: rotation.composed(with: before.orientation))
    let angle = source.rotationRate * delta
    let displacement = (retained.position - before.position).length
    guard retained.position.finite, retained.orientation.validRotation,
      displacement <= (before.position - oldPosition).length * angle
        + (currentPosition - oldPosition).length + 1e-7,
      nativeStationHullSweepClear(
        player, from: retained, to: retained, saved: saved,
        fromOrientation: end, toOrientation: end, margin: 0, mesh: mesh,
        fromPosition: currentPosition, toPosition: currentPosition),
      nativeStationPushClearsScene(
        player, from: before, to: retained, excluding: body.id, angle: angle)
    else { return nil }
    return retained
  }

  private func nativeStationPushClearsScene(
    _ player: Mesh, from before: ShipPose, to retained: ShipPose, excluding stationID: Int,
    angle: Double
  ) -> Bool {
    let radius = nativeStationRadius(player)
    let distance = (retained.position - before.position).length
    let camera = commander.flightSimulation.pose
    for other in bodies where other.id != stationID && other.energy > 0 {
      let pose = modelPose(of: other)
      let mesh = gameplayMesh(for: other)
      let otherRadius = nativeStationRadius(mesh)
      if (pose.position - before.position).length > radius + otherRadius + distance { continue }
      guard
        nativeStructureHullSweepClear(
          player, from: before, to: retained, position: pose.position,
          fromOrientation: pose.orientation, toOrientation: pose.orientation,
          margin: radius * angle, mesh: mesh)
      else { return false }
    }
    for celestial in celestials {
      let center = camera.systemPoint(celestial.position)
      guard (center - before.position).length > celestial.radius + radius + distance else {
        return false
      }
    }
    return true
  }

  /// Refuse the player's attempted endpoint without undoing earlier physical
  /// effects or translating any other actor twice. Reproject their current world
  /// poses through the retained player frame; station rotation/time still advances.
  mutating func stopAtStationImpact(at before: ShipPose) {
    stationImpactRevision = gameplayRevision
    let attempted = commander.flightSimulation.pose
    rotateScriptNPCVelocities(from: attempted, to: before)
    for index in bodies.indices {
      let worldPoint = attempted.systemPoint(bodies[index].position)
      let worldOrientation = bodies[index].orientation.transformed(by: attempted.orientation)
      bodies[index].position = before.shipPoint(worldPoint)
      bodies[index].orientation = worldOrientation.relative(to: before.orientation)
    }
    for index in celestials.indices {
      celestials[index].position = before.shipPoint(
        attempted.systemPoint(celestials[index].position))
    }
    commander.flightSimulation.pose = before
    speed = 0
    pitch = 0
    roll = 0
    yaw = 0
    spin.stop(immediate: true)
    autoPilot.disengage()
    dockingComputer = false
    workGuidance = nil
    workBraking = nil
    approvedWorkMotion = nil
    lastAppliedWorkMotion = nil
    clearManualResidualFlight()
    workFireSuspended = true
  }

  private func nativeStationHullFits(
    _ mesh: Mesh, ship: ShipPose, station: Vector3, orientation: Basis3,
    port: NativeStationGeometry.Port, margin: Double
  ) -> Bool {
    for vertex in mesh.vertices {
      let point = orientation.inverse(ship.systemPoint(vertex) - station) - port.center
      guard point.finite else { return false }
      for index in port.aperture.indices {
        let a = port.aperture[index]
        let edge = port.aperture[(index + 1) % port.aperture.count] - a
        guard edge.length > 0,
          (edge.x * (point.y - a.y) - edge.y * (point.x - a.x)) / edge.length > margin
        else { return false }
      }
    }
    return true
  }

  fileprivate mutating func commitNativeStationEntry(_ proof: NativeStationEntryProof) throws {
    guard !docked, !paused, screen != .gameOver, energy > 0,
      commander.flightSimulation.pose == proof.playerPose,
      commander.flightSimulation.physicalTime == proof.physicalTime,
      gameplayRevision == proof.revision, scriptDurabilityAvailable,
      let body = bodies.first(where: { $0.id == proof.binding.bodyID }),
      body.nativeStationIdentity == proof.station, nativeStationBodyIsCurrent(body),
      body.physical?.identity == proof.binding.actor, var world = commander.nativeStations,
      world.bodyRigidPoseIsConsistent(body, flight: commander.flightSimulation)
    else { throw NativeStationRuntimeError.unsafeEntry }
    try persistNativeStationConditions()
    dock(atMainStation: false)
    guard docked, !dockedAtMainStation else { throw NativeStationRuntimeError.unsafeEntry }
    // Earlier persistence preflights may retain newer ordinary/cargo state in Commander.
    guard let persisted = commander.nativeStations else {
      throw NativeStationRuntimeError.invalidState
    }
    world = persisted
    world.currentMainDock = nil
    try world.ledger.recordDock(
      at: proof.station, binding: proof.binding, commanderOwner: commander.equipmentOwnerID)
    commander.nativeStations = world
    invalidateNativeStationAuthority()
    guard let receipt = world.ledger.currentDock else {
      throw NativeStationRuntimeError.invalidState
    }
    nativeStationDockEvidence = .init(receipt: receipt, runtimeEpoch: nativeStationRuntimeEpoch)
  }

  func prepareNativeStationExit(_ receipt: NativeStationDockReceipt) throws -> ShipPose {
    guard scriptDurabilityAvailable, let world = commander.nativeStations,
      world.valid, receipt.station.system == systemIdentity,
      let saved = world.pose(for: receipt.station),
      let record = world.ledger.records.first(where: { $0.identity == receipt.station }),
      record.tombstone == nil, record.revision == receipt.lifecycleRevision,
      receipt.commanderOwner == commander.equipmentOwnerID,
      let source = NativeStationSource.binding(for: receipt.station),
      let orientation = world.currentOrientation(
        for: saved.station, at: commander.flightSimulation.physicalTime),
      let exit = source.geometry.exit(for: commander.playerMesh)
    else { throw NativeStationRuntimeError.unsafeExit }
    guard
      let stationPosition = world.currentPosition(
        for: .rrs(receipt.station),
        at: commander.flightSimulation.physicalTime)
    else { throw NativeStationRuntimeError.unsafeExit }
    let center = stationPosition + orientation.apply(exit.center)
    let direction = orientation.apply(exit.direction)
    let end = center + direction * exit.clearance
    let radius = nativeStationRadius(commander.playerMesh)
    guard center.finite, end.finite, let anchors = commander.flightSimulation.anchors else {
      throw NativeStationRuntimeError.unsafeExit
    }
    for celestial in [anchors.planet, anchors.sun] {
      guard
        distanceFromNativeSegment(celestial.position, start: center, end: end) > radius
          + celestial.radius
      else { throw NativeStationRuntimeError.unsafeExit }
    }
    for body in bodies where body.energy > 0 && body.nativeStationIdentity != receipt.station {
      let position = commander.flightSimulation.pose.systemPoint(body.position)
      guard
        distanceFromNativeSegment(position, start: center, end: end) > radius
          + nativeStationRadius(gameplayMesh(for: body)) + 8
      else { throw NativeStationRuntimeError.unsafeExit }
    }
    var pose = ShipPose()
    pose.position = center
    pose.orientation.x = orientation.apply(exit.orientation.x)
    pose.orientation.y = orientation.apply(exit.orientation.y)
    pose.orientation.z = orientation.apply(exit.orientation.z)
    guard pose.orientation.validRotation else { throw NativeStationRuntimeError.unsafeExit }
    return pose
  }

  func distanceFromNativeSegment(_ point: Vector3, start: Vector3, end: Vector3) -> Double {
    let segment = end - start
    let denominator = segment.dot(segment)
    guard denominator > 0 else { return (point - start).length }
    let fraction = min(1, max(0, (point - start).dot(segment) / denominator))
    return (point - (start + segment * fraction)).length
  }

  mutating func launchFromNativeStation(_ receipt: NativeStationDockReceipt) throws {
    let old = commander.flightSimulation.pose
    let pose = try prepareNativeStationExit(receipt)
    let velocity =
      commander.nativeStations?.inertia(for: .rrs(receipt.station))?.velocity
      ?? .init(0, 0, 0)
    let combined = pose.orientation.apply(.init(0, 0, speed * 18)) + velocity
    guard combined.finite, combined.length <= AsteroidImpactPolicy.maximumSpeed else {
      throw NativeStationRuntimeError.unsafeExit
    }
    for index in bodies.indices {
      let position = old.systemPoint(bodies[index].position)
      let orientation = bodies[index].orientation.transformed(by: old.orientation)
      bodies[index].position = pose.shipPoint(position)
      bodies[index].orientation = orientation.relative(to: pose.orientation)
    }
    for index in celestials.indices {
      celestials[index].position = pose.shipPoint(old.systemPoint(celestials[index].position))
    }
    commander.flightSimulation.pose = pose
    if velocity != .init(0, 0, 0) {
      autoPilot.setApproachVelocity(pose.shipVector(velocity))
      manualResidualFlight = true
    }
    commander.nativeStations?.ledger.depart()
    commander.nativeStations?.currentMainDock = nil
    invalidateNativeStationAuthority()
  }
}

extension NativeStationWorld {
  /// End-of-movement admission joins the actual rendered actor to its saved rigid station pose.
  /// Planning earlier in a tick still uses the preceding body frame, so this is not a global
  /// eligibility predicate for weapon queries made before movement.
  func bodyRigidPoseIsConsistent(
    _ body: borrowing SpaceBody, flight: borrowing FlightSimulationState
  ) -> Bool {
    guard let identity = body.nativeStationIdentity, let saved = pose(for: identity),
      let source = NativeStationSource.binding(for: identity), body.hull == .station,
      let physical = body.physical, physical.population == .mission, physical.npc == nil,
      (physical.velocity - (inertia(for: .rrs(identity))?.velocity ?? .init(0, 0, 0))).length
        < 1e-7,
      physical.canonicalSpin != true,
      physical.angularVelocity == Vector3(0, 0, 0),
      body.rotationRate == source.rotationRate,
      let currentPosition = currentPosition(for: .rrs(identity), at: flight.physicalTime),
      (flight.pose.systemPoint(body.position) - currentPosition).length < 1e-5,
      let orientation = currentOrientation(for: saved.station, at: flight.physicalTime)
    else { return false }
    for axis in [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)] {
      guard
        (flight.pose.orientation.apply(body.modelVector(axis)) - orientation.apply(axis)).length
          < 1e-5
      else { return false }
    }
    return true
  }

  func sceneIsConsistent(
    bodies: [SpaceBody], docked: Bool, mainStation: Bool,
    system: SystemIdentity, flight: FlightSimulationState
  ) -> Bool {
    guard valid, flight.pose.position.finite, flight.pose.position.length.isFinite,
      flight.pose.orientation.validRotation
    else { return false }
    if let id = mainStations.first(where: { $0.system == system }),
      let motion = inertia(for: .main(id)), let body = bodies.first(where: { $0.id == 0 })
    {
      guard let source = flight.anchors?.station, source.position == .init(0, 0, 0),
        body.hull == .station, body.physical?.identity == source.identity,
        let current = currentPosition(for: .main(id), at: flight.physicalTime),
        (flight.pose.systemPoint(body.position) - current).length < 1e-5,
        let velocity = body.physical?.velocity, (velocity - motion.velocity).length < 1e-7
      else { return false }
    }
    if let receipt = ledger.currentDock {
      guard docked, !mainStation, receipt.station.system == system else { return false }
    }
    if let receipt = currentMainDock {
      guard docked, mainStation, receipt.station.system == system else { return false }
    }
    let actual = bodies.filter { $0.nativeStationIdentity != nil }
    guard !docked || actual.isEmpty, actual.count <= 2,
      Set(actual.compactMap(\.nativeStationIdentity)).count == actual.count
    else { return false }
    for body in actual {
      guard let identity = body.nativeStationIdentity, identity.system == system,
        let record = ledger.records.first(where: { $0.identity == identity }),
        record.tombstone == nil,
        let saved = pose(for: identity), let source = NativeStationSource.binding(for: identity),
        let physical = body.physical, physical.population == .mission, physical.npc == nil,
        physical.identity.system == system, physical.identity.visit == flight.visit,
        record.binding == .init(actor: physical.identity, bodyID: body.id),
        body.hull == .station, body.energy == saved.energy, body.energy > 0,
        body.rotationRate == source.rotationRate,
        bodyRigidPoseIsConsistent(body, flight: flight)
      else { return false }
    }
    return true
  }
}

extension GameRuntime {
  /// Physical movement stays committed on failed saving; docking itself publishes only durably.
  func commitPendingNativeStationEntry() {
    guard let proof = game.pendingNativeStationDock else { return }
    guard let publish = scriptPublisher() else {
      game.pendingNativeStationDock = nil
      game.notify("CHOOSE A SAVE LOCATION BEFORE RRS DOCKING")
      return
    }
    var candidate = game
    do {
      try candidate.commitNativeStationEntry(proof)
      try publish(&candidate)
      game = candidate
      controls = Controls()
    } catch {
      game.pendingNativeStationDock = nil
      game.notify("RRS DOCKING REFUSED - STATE NOT COMMITTED")
    }
  }
}
