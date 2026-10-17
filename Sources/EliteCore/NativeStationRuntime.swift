import Foundation

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
    guard world.valid, equipmentOwnerID == world.ledger.world,
      let calendar = scriptState.calendarLedger, calendar.valid
    else { return false }
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
        saved.orientation(at: flightBefore.physicalTime) != nil
      else { throw NativeStationRuntimeError.invalidSource }
      let radius = nativeStationRadius(source.geometry.mesh)
      for celestial in [anchors.planet, anchors.sun] {
        guard (saved.position - celestial.position).length > radius + celestial.radius + 8 else {
          throw NativeStationRuntimeError.unsafePlacement
        }
      }
      for body in bodies where body.energy > 0 {
        let point = flightBefore.pose.systemPoint(body.position)
        guard
          (saved.position - point).length > radius + nativeStationRadius(gameplayMesh(for: body))
            + 8
        else { throw NativeStationRuntimeError.unsafePlacement }
      }
      for (_, other, otherSource) in selected {
        guard
          (saved.position - other.position).length > radius
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
      var body = SpaceBody(id: id, hull: .station, position: flight.pose.shipPoint(saved.position))
      body.nativeStationIdentity = record.identity
      body.orientation = saved.orientation.relative(to: flight.pose.orientation)
      body.rotation = (flight.physicalTime * source.rotationRate).truncatingRemainder(
        dividingBy: 2 * .pi)
      body.rotationRate = source.rotationRate
      body.energy = saved.energy
      body.missiles = 0
      body.ecmEnabled = source.kind == .waystation
      body.physical = nativePhysicalActorState(
        for: body, identity: actor,
        spawnIdentity: .init(
          system: systemIdentity, visit: flight.visit, sequence: sequence,
          member: UInt16(member), producer: .mission))
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
      world.poses[index].energy = max(0, body.energy)
      if body.energy <= 0 {
        try world.ledger.destroy(
          identity, binding: .init(actor: physical.identity, bodyID: body.id))
      }
    }
    guard world.valid else { throw NativeStationRuntimeError.invalidState }
    commander.nativeStations = world
  }

  func nativeStationBodyIsCurrent(_ body: SpaceBody) -> Bool {
    guard let identity = body.nativeStationIdentity, let physical = body.physical,
      let world = commander.nativeStations, commander.nativeStationStateValid,
      let record = world.ledger.records.first(where: { $0.identity == identity })
    else { return false }
    return identity.system == systemIdentity && record.tombstone == nil && body.energy > 0
      && physical.identity.system == systemIdentity
      && physical.identity.visit == commander.flightSimulation.visit
      && record.binding == .init(actor: physical.identity, bodyID: body.id)
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
    guard var world = commander.nativeStations, let anchors = commander.flightSimulation.anchors,
      let station = bodies.first(where: { $0.id == 0 && $0.hull == .station }), station.energy > 0,
      station.physical?.identity == anchors.station.identity,
      bodies.filter({ $0.physical?.identity == anchors.station.identity }).count == 1,
      anchors.station.identity.entity == 1, anchors.system == systemIdentity,
      (commander.flightSimulation.pose.systemPoint(station.position) - anchors.station.position)
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
      guard commander.scriptState.stationResources.count < 256 else { return }
      var resource = ScriptStationResource(
        identity: identity.resource, galaxy: commander.galaxy, system: commander.system)
      resource.energy = station.energy
      commander.scriptState.stationResources[key] = resource
    }
    if !world.mainStations.contains(identity) {
      guard world.mainStations.count < 256 else { throw NativeStationRuntimeError.capacity }
      world.mainStations.append(identity)
    }
    let observation = NativeMainStationObservation(
      station: identity, actor: anchors.station.identity,
      calendarSeconds: commander.scriptState.calendarSeconds)
    if let index = world.mainObservations.firstIndex(where: { $0.station == identity }) {
      world.mainObservations[index] = observation
    } else {
      guard world.mainObservations.count < 256 else { throw NativeStationRuntimeError.capacity }
      world.mainObservations.append(observation)
    }
    guard world.valid else { throw NativeStationRuntimeError.invalidState }
    commander.nativeStations = world
  }

  /// The legacy Boolean dock API issues no arrival. Only actual native doorway entry calls this.
  mutating func dockAtOriginalNativeMainStation(_ station: SpaceBody, from before: ShipPose) {
    let system = systemIdentity
    guard let world = commander.nativeStations else {
      dock()
      return
    }
    let pose = commander.flightSimulation.pose
    let normal = pose.orientation.apply(station.entranceNormal)
    let entrance = pose.systemPoint(station.entrancePosition)
    guard let actor = station.physical?.identity,
      bodies.first(where: { $0.id == 0 }) == station,
      bodies.filter({ $0.id == 0 }).count == 1,
      station.containsPlayer,
      station.canEnter(roll: roll, speed: max(speed * 18, autoPilot.velocity.length)),
      (before.position - entrance).dot(normal) >= 0,
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
        let orientation = saved.orientation(at: flight.physicalTime),
        let oldOrientation = saved.orientation(at: max(0, flight.physicalTime - delta))
      else { continue }
      let port = source.geometry.docking
      let start = oldOrientation.inverse(before.position - saved.position) - port.center
      let end = orientation.inverse(flight.pose.position - saved.position) - port.center
      let oldDepth = start.dot(port.outward)
      let depth = end.dot(port.outward)
      guard oldDepth > 0, depth <= 0, depth > -port.tunnelDepth,
        max(speed * 18, autoPilot.velocity.length) < 144,
        flight.pose.orientation.z.dot(orientation.apply(port.outward)) < -0.995,
        flight.pose.orientation.y.dot(orientation.apply(port.up)) > 0.995,
        abs(roll + source.rotationRate * body.orientation.z.z) < 0.1
      else { continue }
      let player = commander.playerMesh
      let radius = nativeStationRadius(player)
      let angularSweep = (abs(pitch) + abs(roll) + abs(yaw) + source.rotationRate) * delta
      let margin = (radius + max(start.length, end.length)) * angularSweep
      guard margin.isFinite, port.fits(player, margin: margin),
        nativeStationHullFits(
          player, ship: before, station: saved.position, orientation: oldOrientation, port: port,
          margin: margin),
        nativeStationHullFits(
          player, ship: flight.pose, station: saved.position, orientation: orientation, port: port,
          margin: margin),
        nativeStationHullSweepClear(
          player, from: before, to: flight.pose, saved: saved,
          fromOrientation: oldOrientation, toOrientation: orientation, margin: margin,
          mesh: source.geometry.mesh),
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

  private func nativeStationApproachClear(
    from start: Vector3, to end: Vector3, excluding stationID: Int, radius: Double
  ) -> Bool {
    guard let anchors = commander.flightSimulation.anchors, radius.isFinite else { return false }
    for celestial in [anchors.planet, anchors.sun] {
      if distanceFromNativeSegment(celestial.position, start: start, end: end) <= radius
        + celestial.radius
      {
        return false
      }
    }
    for body in bodies where body.energy > 0 && body.id != stationID {
      let point = commander.flightSimulation.pose.systemPoint(body.position)
      if distanceFromNativeSegment(point, start: start, end: end) <= radius
        + nativeStationRadius(gameplayMesh(for: body))
      {
        return false
      }
    }
    return true
  }

  /// A conservative box encloses every effective-hull vertex at both sweep ends and
  /// expands by the angular-motion bound. Triangle clipping detects face/edge contacts too.
  private func nativeStationHullSweepClear(
    _ player: Mesh, from start: ShipPose, to end: ShipPose, saved: NativeStationSavedPose,
    fromOrientation: Basis3, toOrientation: Basis3, margin: Double, mesh: Mesh
  ) -> Bool {
    let points = player.vertices.flatMap { vertex in
      [
        fromOrientation.inverse(start.systemPoint(vertex) - saved.position),
        toOrientation.inverse(end.systemPoint(vertex) - saved.position),
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
    for body in bodies where body.nativeStationIdentity != nil && nativeStationBodyIsCurrent(body) {
      guard let identity = body.nativeStationIdentity, let saved = world.pose(for: identity),
        let source = NativeStationSource.binding(for: identity),
        let end = saved.orientation(at: flight.physicalTime),
        let start = saved.orientation(at: max(0, flight.physicalTime - delta))
      else { continue }
      let displacement = (flight.pose.position - before.position).length
      let radius = nativeStationRadius(source.geometry.mesh)
      guard (saved.position - flight.pose.position).length <= radius + playerRadius + displacement
      else { continue }
      let angle = (abs(pitch) + abs(roll) + abs(yaw) + source.rotationRate) * delta
      let margin = (radius + playerRadius + displacement) * angle
      if !nativeStationHullSweepClear(
        player, from: before, to: flight.pose, saved: saved,
        fromOrientation: start, toOrientation: end, margin: margin, mesh: source.geometry.mesh)
      {
        applyDamage(delta * 100, front: true)
        notify("RRS DOCKING COLLISION", voiced: false)
        return
      }
    }
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
      let orientation = saved.orientation(at: commander.flightSimulation.physicalTime),
      let exit = source.geometry.exit(for: commander.playerMesh)
    else { throw NativeStationRuntimeError.unsafeExit }
    let center = saved.position + orientation.apply(exit.center)
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

  private func distanceFromNativeSegment(_ point: Vector3, start: Vector3, end: Vector3) -> Double {
    let segment = end - start
    let denominator = segment.dot(segment)
    guard denominator > 0 else { return (point - start).length }
    let fraction = min(1, max(0, (point - start).dot(segment) / denominator))
    return (point - (start + segment * fraction)).length
  }

  mutating func launchFromNativeStation(_ receipt: NativeStationDockReceipt) throws {
    let old = commander.flightSimulation.pose
    let pose = try prepareNativeStationExit(receipt)
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
    commander.nativeStations?.ledger.depart()
    commander.nativeStations?.currentMainDock = nil
    invalidateNativeStationAuthority()
  }
}

extension NativeStationWorld {
  /// End-of-movement admission joins the actual rendered actor to its saved rigid station pose.
  /// Planning earlier in a tick still uses the preceding body frame, so this is not a global
  /// eligibility predicate for weapon queries made before movement.
  func bodyRigidPoseIsConsistent(_ body: SpaceBody, flight: FlightSimulationState) -> Bool {
    guard let identity = body.nativeStationIdentity, let saved = pose(for: identity),
      let source = NativeStationSource.binding(for: identity), body.hull == .station,
      let physical = body.physical, physical.population == .mission, physical.npc == nil,
      physical.velocity == Vector3(0, 0, 0), physical.canonicalSpin != true,
      physical.angularVelocity == Vector3(0, 0, 0),
      body.rotationRate == source.rotationRate,
      (flight.pose.systemPoint(body.position) - saved.position).length < 1e-5,
      let orientation = saved.orientation(at: flight.physicalTime)
    else { return false }
    return [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)].allSatisfy {
      (flight.pose.orientation.apply(body.modelVector($0)) - orientation.apply($0)).length < 1e-5
    }
  }

  func sceneIsConsistent(
    bodies: [SpaceBody], docked: Bool, mainStation: Bool,
    system: SystemIdentity, flight: FlightSimulationState
  ) -> Bool {
    guard valid, flight.pose.position.finite, flight.pose.position.length.isFinite,
      flight.pose.orientation.validRotation
    else { return false }
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
