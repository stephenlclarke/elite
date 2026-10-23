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

extension GameRuntime {
  /// Explicit new-commander creation, never an admission path for a caller-supplied Game or save.
  public func startNewCommander() throws {
    guard galleryNamespace == nil, galleryParent == nil, scriptSaveURL == nil,
      !game.isMissionTrial, game.pendingNewSaveDestination == nil
    else { throw NativeStationRuntimeError.invalidState }
    if let world = game.commander.nativeStations {
      // Retrying destination registration preserves the already trusted commander in full.
      guard game.commander.valid, game.nativeMainStationDockEvidenceIsCurrent,
        let receipt = world.currentMainDock,
        case .living(let destination) = game.nativeOriginalMainStationDestination,
        receipt.station == destination.identity, receipt.actor == destination.observation.actor,
        world.sceneIsConsistent(
          bodies: game.bodies, docked: game.docked, mainStation: game.dockedAtMainStation,
          system: game.systemIdentity, flight: game.commander.flightSimulation)
      else { throw NativeStationRuntimeError.invalidState }
      return
    }
    let startupScreen: Screen = game.screen == .demo ? .demo : .title
    var candidate = try Game.bornBerthedCommander(screen: startupScreen)
    candidate.scriptPacks = game.scriptPacks
    candidate.missionPacks = game.missionPacks
    guard candidate.commander.valid else { throw NativeStationRuntimeError.invalidState }
    game = candidate
    controls = Controls()
  }
}

extension Game {
  /// Game-over input creates a new commander; bound publication remains the actor's transaction.
  mutating func restartBornBerthedCommander() throws {
    guard screen == .gameOver, !isMissionTrial else {
      throw NativeStationRuntimeError.invalidState
    }
    let startupScreen: Screen = commander.executive ? .demo : .title
    self = try Self.bornBerthedCommander(screen: startupScreen)
  }

  /// This producer owns construction of the entire fresh value. No existing dock flags confer trust.
  fileprivate static func bornBerthedCommander(screen: Screen) throws -> Game {
    var candidate = Game(executive: screen == .demo)
    candidate.screen = screen
    try candidate.commander.prepareEquipment(legacy: false)
    candidate.commander.mirrorFittedEquipment()
    try candidate.activateNativeStationWorld()
    guard candidate.commander.galaxy == NewCommanderDefaults.galaxy,
      candidate.commander.system == NewCommanderDefaults.system,
      candidate.commander.shipID == NewCommanderDefaults.shipID,
      candidate.commander.flightSimulation.visit == 0,
      candidate.commander.flightSimulation.physicalTime == 0,
      candidate.commander.scriptState.calendarSeconds == 0,
      candidate.bodies.isEmpty
    else { throw NativeStationRuntimeError.invalidState }

    // Establish the real source anchor and its reserved original-main actor, without a flight visit
    // producer, movement, launch, doorway crossing, station events or gameplay clock advancement.
    candidate.commander.flightSimulation.enter(candidate.systemIdentity, arriving: false)
    guard let anchor = candidate.commander.flightSimulation.anchors?.station else {
      throw NativeStationRuntimeError.invalidState
    }
    var station = SpaceBody(
      id: 0, hull: .station,
      position: candidate.commander.flightSimulation.pose.shipPoint(anchor.position))
    station.physical = candidate.nativePhysicalActorState(for: station, identity: anchor.identity)
    candidate.bodies = [station]
    try candidate.registerOriginalNativeMainStation()
    guard var world = candidate.commander.nativeStations,
      let owner = candidate.commander.equipmentOwnerID,
      world.ledger.world == owner, world.mainStations.count == 1,
      let identity = world.mainStations.first, identity.system == candidate.systemIdentity,
      let observation = world.mainObservations.first, observation.station == identity,
      observation.actor == anchor.identity, observation.calendarSeconds == 0,
      let resource = candidate.commander.scriptState.stationResources[identity.key],
      resource.valid, resource.identity == identity.resource, !resource.destroyed,
      resource.energy == station.energy, resource.energy > 0,
      world.currentMainDock == nil, world.nextMainDockSequence == 1
    else { throw NativeStationRuntimeError.invalidState }
    let receipt = NativeMainStationDockReceipt(
      station: identity, actor: anchor.identity, commanderOwner: owner, sequence: 1,
      calendarSeconds: 0)
    world.currentMainDock = receipt
    world.nextMainDockSequence = 2
    candidate.commander.nativeStations = world
    candidate.bodies = []
    candidate.nativeMainStationDockEvidence = .init(
      receipt: receipt, runtimeEpoch: candidate.nativeStationRuntimeEpoch)
    guard receipt.valid, world.valid, candidate.commander.valid,
      candidate.nativeMainStationDockEvidenceIsCurrent,
      world.sceneIsConsistent(
        bodies: candidate.bodies, docked: candidate.docked,
        mainStation: candidate.dockedAtMainStation, system: candidate.systemIdentity,
        flight: candidate.commander.flightSimulation)
    else { throw NativeStationRuntimeError.invalidState }
    return candidate
  }
}

extension SpaceBody {
  /// Checked payload access follows the existing flight-state read coroutine pattern.
  /// No mutation or suspension can invalidate the presence check before projection.
  fileprivate var nativeStationPhysicalIdentity: ActorIdentity? {
    _read {
      if case .some = physical {
        let identity: ActorIdentity? = physical!.identity
        yield identity
      } else {
        let absent: ActorIdentity? = nil
        yield absent
      }
    }
  }
}

extension Commander {
  var nativeStationStateValid: Bool {
    Self.nativeStationStateIsValid(self)
  }

  @inline(never)
  fileprivate static func nativeStationStateIsValid(_ commander: borrowing Commander) -> Bool {
    NativeStationStateValidation.check(
      readWorld: { commander.nativeStations },
      readResources: { commander.withReadOnlyScriptState { $0.stationResources } },
      readSystem: { SystemIdentity(galaxy: commander.galaxy, system: commander.system) },
      readOwner: { commander.equipmentOwnerID },
      readPhysicalTime: { commander.flightSimulation.physicalTime },
      readStationPosition: { commander.flightSimulation.anchors?.station.position },
      readCalendar: { commander.withReadOnlyScriptState { $0.calendarLedger } })
  }
}

// One full policy body serves normal Commander validation and private storage projections.
// Reader closures are synchronous and nonescaping; each is called only at its original read point.
enum NativeStationStateValidation {
  @inline(never)
  static func check(
    readWorld: () -> NativeStationWorld?,
    readResources: () -> [String: ScriptStationResource],
    readSystem: () -> SystemIdentity,
    readOwner: () -> UUID?,
    readPhysicalTime: () -> Double,
    readStationPosition: () -> Vector3?,
    readCalendar: () -> ScriptCalendarLedger?
  ) -> Bool {
    guard let world = readWorld() else { return true }
    let resources = readResources()
    let currentSystem = readSystem()
    guard world.valid, readOwner() == world.ledger.world else { return false }
    let physicalTime = readPhysicalTime()
    guard world.stationInertia.allSatisfy({ $0.physicalTime <= physicalTime }) else { return false }
    if world.stationInertia.contains(where: { $0.station.system == currentSystem }) {
      guard readStationPosition() == Vector3(0, 0, 0) else {
        return false
      }
    }
    guard let calendar = readCalendar(), calendar.valid
    else {
      return false
    }
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
      let utilityBonus =
        commander.nativeStations?.ledger.records.first(where: { $0.identity == identity })?.utility?
        .rechargeBonus ?? 0
      bodies[index].energy = min(
        source.maximumEnergy, bodies[index].energy + (source.recharge + utilityBonus) * delta)
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
  @inline(never)
  mutating func populateNativeStations() throws {
    guard var world = commander.nativeStations else { return }
    guard let cohort = try nativeStationPopulationCohort(world: world) else { return }
    let flightBefore = commander.flightSimulation
    let selected = try selectNativeStationPopulation(
      world: world, anchors: cohort.anchors, absent: cohort.absent, flightBefore: flightBefore)
    try admitNativeStationPopulation(world: &world, flightBefore: flightBefore, selected: selected)
  }

  // Retire the existing-body census before any geometry or candidate-body temporaries exist.
  // An empty cohort returns here without entering either allocation/placement phase.
  @inline(never)
  private mutating func nativeStationPopulationCohort(world: NativeStationWorld) throws -> (
    anchors: SystemAnchors, absent: [NativeStationRecord]
  )? {
    let header = try nativeStationPopulationHeader()
    let system = header.system
    let anchors = header.anchors
    guard !docked else { throw NativeStationRuntimeError.invalidState }
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
    guard !absent.isEmpty else { return nil }
    guard bodies.filter({ $0.energy > 0 }).count + absent.count <= 128,
      bodies.reduce(0, { $0 + $1.scriptNativeUnits }) + absent.count <= 1024,
      nextBodyID > 0, nextBodyID < 1_000_000_000 - absent.count
    else { throw NativeStationRuntimeError.capacity }
    return (anchors, absent)
  }

  @inline(never)
  private mutating func selectNativeStationPopulation(
    world: NativeStationWorld, anchors: SystemAnchors, absent: [NativeStationRecord],
    flightBefore: FlightSimulationState
  ) throws -> [(NativeStationRecord, NativeStationSavedPose, NativeStationSourceBinding)] {
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
    return selected
  }

  // Placement has returned before actor construction. Publish only the same fully valid cohort.
  @inline(never)
  private mutating func admitNativeStationPopulation(
    world: inout NativeStationWorld, flightBefore: FlightSimulationState,
    selected: [(NativeStationRecord, NativeStationSavedPose, NativeStationSourceBinding)]
  ) throws {
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
    Self.nativeStationMeshRadius(mesh)
  }

  private static func nativeStationMeshRadius(_ mesh: Mesh) -> Double {
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

  @inline(never)
  mutating func nativeStationApproachBodyIsCurrent(_ body: SpaceBody) -> Bool {
    withNativeStationReadOnlyCommander { commander in
      Self.nativeStationBodyIsCurrent(body, commander: commander)
    }
  }

  private static func nativeStationBodyIsCurrent(
    _ body: borrowing SpaceBody, commander: borrowing Commander
  ) -> Bool {
    guard let identity = body.nativeStationIdentity,
      let physicalIdentity = body.nativeStationPhysicalIdentity,
      let world = commander.nativeStations, Commander.nativeStationStateIsValid(commander),
      let record = world.ledger.records.first(where: { $0.identity == identity })
    else { return false }
    let currentSystem = SystemIdentity(galaxy: commander.galaxy, system: commander.system)
    guard identity.system == currentSystem, record.tombstone == nil, body.energy > 0,
      physicalIdentity.system == currentSystem,
      physicalIdentity.visit == commander.flightSimulation.visit,
      record.binding == .init(actor: physicalIdentity, bodyID: body.id)
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
    guard evidence.runtimeEpoch == nativeStationRuntimeEpoch else { return false }
    return evidence.receipt == retainedNativeMainStationDockReceipt
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
    observeFleetDocking(body: station, main: receipt)
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
    _ station: borrowing SpaceBody, from start: ShipPose, to end: ShipPose,
    delta: Double = 0, requireAperture: Bool = true
  ) -> Bool {
    var observation: [String: String]?
    return nativeMainStationHullCourseIsClear(
      station, from: start, to: end, delta: delta, requireAperture: requireAperture,
      observation: &observation)
  }

  private func nativeMainStationHullCourseIsClear(
    _ station: borrowing SpaceBody, from start: ShipPose, to end: ShipPose,
    delta: Double = 0, requireAperture: Bool = true, observation: inout [String: String]?
  ) -> Bool {
    let flight = commander.flightSimulation
    observation?["refusal"] = "main.current-source"
    guard delta.isFinite, delta >= 0, delta <= 0.1,
      station.id == 0, station.hull == .station, station.nativeStationIdentity == nil,
      let world = commander.nativeStations,
      let identity = world.mainStations.first(where: { $0.system == systemIdentity }),
      station.physical?.identity == flight.anchors?.station.identity,
      NativeStationSnapshot.matches(station, in: bodies),
      let current = currentNativeMainStationAnchor(at: flight.physicalTime),
      let previous = currentNativeMainStationAnchor(at: max(0, flight.physicalTime - delta)),
      (flight.pose.systemPoint(station.position) - current.position).length < 1e-5
    else { return false }
    let stationOrientation = station.orientation
    guard
      [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)].allSatisfy({
        (flight.pose.orientation.apply(stationOrientation.apply($0))
          - current.orientation.apply($0)).length < 1e-5
      })
    else { return false }
    let player = commander.playerMesh
    let geometry = MainStationGeometry.mesh
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
    if nativeMainStationSweepIntervalIsClear(
      player, from: start, to: end, position: previous.position, endPosition: current.position,
      fromOrientation: startOrientation, toOrientation: endOrientation,
      margin: margin, delta: delta, requireAperture: requireAperture, observation: &observation)
    {
      return true
    }
    // Refinement proves the same attained native step, never an arbitrary predicted corridor.
    guard delta > 0, flight.physicalTime >= delta, end == flight.pose,
      stationAutoDockingActive, dockingComputer, speed == 0,
      !playerEMPDisabled, !isEMPDisabled(station),
      workGuidance == nil, workBraking == nil,
      approvedWorkMotion == nil, lastAppliedWorkMotion == nil,
      world.inertia(for: .main(identity)) == nil, previous.position == current.position,
      start.position.finite, end.position.finite,
      start.orientation.validRotation, end.orientation.validRotation,
      endOrientation.validRotation,
      [pitch, roll, yaw, station.rotationRate].allSatisfy(\.isFinite),
      autoPilot.velocity.finite
    else { return false }
    var expected = start
    expected.advanceView(
      pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta,
      translation: .init(0, 0, 0))
    let axes = [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)]
    guard
      axes.allSatisfy({
        (expected.orientation.apply($0) - end.orientation.apply($0)).length < 1e-8
      }),
      (end.position - start.position - end.orientation.apply(autoPilot.velocity * delta)).length
        < 1e-8
    else { return false }
    guard let count = nativeMainStationRefinementCount(player, margin: margin, delta: delta) else {
      return false
    }
    let interval = delta / Double(count)
    guard interval <= 0.02 else { return false }
    let intervalMargin =
      (nativeStationRadius(player) + nativeStationRadius(geometry))
      * (abs(pitch) + abs(roll) + abs(yaw) + abs(station.rotationRate)) * interval
    var priorShip = start
    var priorStation = startOrientation
    for index in 1...count {
      let fraction = Double(index) / Double(count)
      let elapsed = delta * fraction
      var nextShip = start
      nextShip.advanceView(
        pitch: pitch * elapsed, roll: roll * elapsed, yaw: yaw * elapsed,
        translation: .init(0, 0, 0))
      nextShip.position = start.position + (end.position - start.position) * fraction
      if index == count { nextShip = end }
      var remainingSpin = Basis3()
      remainingSpin.rotate(pitch: 0, roll: -station.rotationRate * (delta - elapsed), yaw: 0)
      let nextStation = endOrientation.composed(with: remainingSpin)
      guard
        nativeMainStationSweepIntervalIsClear(
          player, from: priorShip, to: nextShip,
          position: previous.position, endPosition: current.position,
          fromOrientation: priorStation, toOrientation: nextStation,
          margin: intervalMargin, delta: interval, requireAperture: requireAperture,
          observation: &observation)
      else { return false }
      priorShip = nextShip
      priorStation = nextStation
    }
    return true
  }

  /// Spend at most half the real aperture clearance on each interval's unchanged sweep margin.
  /// A finite cap keeps narrow or unsupported courses fail-closed without a geometry search.
  private func nativeMainStationRefinementCount(
    _ player: Mesh, margin: Double, delta: Double
  ) -> Int? {
    let port = MainStationGeometry.docking
    guard port.fits(player), margin.isFinite, margin >= 0 else { return nil }
    var clearance = Double.infinity
    for index in port.aperture.indices {
      let a = port.aperture[index]
      let b = port.aperture[(index + 1) % port.aperture.count]
      let edge = b - a
      let length = edge.length
      for vertex in player.vertices {
        let distance = (edge.x * (vertex.y - a.y) - edge.y * (vertex.x - a.x)) / length
        clearance = min(clearance, distance)
      }
    }
    guard clearance.isFinite, clearance > 0 else { return nil }
    let requested = max(2, max(ceil(delta / 0.02), ceil(margin / (clearance * 0.5))))
    guard requested.isFinite, requested <= 64 else { return nil }
    return Int(requested)
  }

  /// Each interval retains the original full-hull, aperture and triangle-structure proof.
  private func nativeMainStationSweepIntervalIsClear(
    _ player: Mesh, from start: ShipPose, to end: ShipPose,
    position: Vector3, endPosition: Vector3,
    fromOrientation: Basis3, toOrientation: Basis3,
    margin: Double, delta: Double, requireAperture: Bool,
    observation: inout [String: String]?
  ) -> Bool {
    observation?["refusal"] = "main.margin"
    observation?["geometryMargin"] = String(margin)
    observation?["geometryDelta"] = String(delta)
    guard margin.isFinite else { return false }
    let port = MainStationGeometry.docking
    if requireAperture {
      observation?["refusal"] = "main.aperture-shape"
      guard port.fits(player, margin: margin) else { return false }
      observation?["refusal"] = "main.aperture-start"
      guard
        nativeStationHullFits(
          player, ship: start, station: position, orientation: fromOrientation,
          port: port, margin: margin)
      else { return false }
      observation?["refusal"] = "main.aperture-end"
      guard
        nativeStationHullFits(
          player, ship: end, station: endPosition, orientation: toOrientation,
          port: port, margin: margin)
      else { return false }
    }
    observation?["refusal"] = "main.structure"
    return nativeStructureHullSweepClear(
      player, from: start, to: end, position: position, endPosition: endPosition,
      fromOrientation: fromOrientation, toOrientation: toOrientation,
      margin: margin, mesh: MainStationGeometry.mesh)
  }

  /// Reuse native source, aperture and corridor checks for a proposed approach.
  /// The relative frame at the door is geometry only and is never installed or minted as entry.
  mutating func nativeStationAutoEntryCourseIsClear(
    _ station: borrowing SpaceBody, advance: Vector3, terminalSpeed: Double
  ) -> Bool {
    var observation: [String: String]?
    var bodyCourseRefused = false
    return nativeStationAutoEntryCourseIsClear(
      station, advance: advance, terminalSpeed: terminalSpeed, observation: &observation,
      bodyCourseRefused: &bodyCourseRefused)
  }

  /// Finish the full physical-state read before entering deeper course geometry.
  /// These fields are not authority; the complete current-body comparison still follows.
  @inline(never)
  private static func nativeStationEntryPhysicalFields(
    _ station: borrowing SpaceBody
  ) -> (identity: ActorIdentity, velocity: Vector3)? {
    guard let physical = station.physical else { return nil }
    return (identity: physical.identity, velocity: physical.velocity)
  }

  mutating func nativeStationAutoEntryCourseIsClear(
    _ station: borrowing SpaceBody, advance: Vector3, terminalSpeed: Double,
    observation: inout [String: String]?, bodyCourseRefused: inout Bool
  ) -> Bool {
    bodyCourseRefused = false
    guard
      let corridor = nativeStationAutoEntryCorridorInputs(
        station, advance: advance, terminalSpeed: terminalSpeed, observation: &observation)
    else { return false }
    let clear = nativeStationApproachClear(
      from: corridor.start, to: corridor.end,
      excluding: corridor.stationID, radius: corridor.radius, observation: &observation,
      refineCourse: true, bodyCourseRefused: &bodyCourseRefused)
    if clear { observation?["refusal"] = "none" }
    return clear
  }

  @inline(never)
  private mutating func nativeStationAutoEntryCorridorInputs(
    _ station: borrowing SpaceBody, advance: Vector3, terminalSpeed: Double,
    observation: inout [String: String]?
  ) -> (start: Vector3, end: Vector3, stationID: Int, radius: Double)? {
    observation?["refusal"] = "native.state"
    let stateValid = commander.nativeStationStateValid
    observation?["nativeStateValid"] = String(stateValid)
    guard stateValid, let world = commander.nativeStations,
      let physical = Self.nativeStationEntryPhysicalFields(station)
    else { return nil }
    observation?["refusal"] = "native.advance"
    guard advance.finite else { return nil }
    observation?["refusal"] = "native.motion-binding"
    let velocityError = (physical.velocity - nativeStationVelocity(station)).length
    observation?["stationVelocityError"] = String(velocityError)
    guard velocityError < 1e-7,
      NativeStationSnapshot.matches(station, in: bodies)
    else { return nil }
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
      else { return nil }
      observation?["refusal"] = "rrs.aperture-shape"
      guard source.geometry.docking.fits(player) else { return nil }
      observation?["refusal"] = "rrs.aperture-start"
      guard
        nativeStationHullFits(
          player, ship: flight.pose, station: position, orientation: orientation,
          port: source.geometry.docking, margin: 0)
      else { return nil }
      observation?["refusal"] = "rrs.aperture-end"
      guard
        nativeStationHullFits(
          player, ship: endpoint, station: position, orientation: orientation,
          port: source.geometry.docking, margin: 0)
      else { return nil }
      observation?["refusal"] = "rrs.structure"
      guard
        nativeStructureHullSweepClear(
          player, from: flight.pose, to: endpoint, position: position,
          fromOrientation: orientation, toOrientation: orientation, margin: 0,
          mesh: source.geometry.mesh)
      else { return nil }
    } else {
      observation?["refusal"] = "main.actor-source"
      guard station.id == 0, physical.identity == flight.anchors?.station.identity,
        let anchor = currentNativeMainStationAnchor(at: flight.physicalTime)
      else { return nil }
      observation?["refusal"] = "main.position-source"
      let positionError = (flight.pose.systemPoint(station.position) - anchor.position).length
      observation?["stationPositionError"] = String(positionError)
      guard positionError < 1e-5 else { return nil }
      observation?["refusal"] = "main.basis-source"
      let stationOrientation = station.orientation
      guard
        [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)].allSatisfy({
          let error =
            (flight.pose.orientation.apply(stationOrientation.apply($0))
            - anchor.orientation.apply($0)).length
          observation?["stationBasisError"] = String(error)
          return error < 1e-5
        })
      else { return nil }
      observation?["refusal"] = "main.resource-source"
      guard let identity = world.mainStations.first(where: { $0.system == systemIdentity }),
        let resource = commander.scriptState.stationResources[identity.key],
        resource.identity == identity.resource, !resource.destroyed, resource.energy > 0
      else { return nil }
      var atDoor = copy station
      atDoor.position = atDoor.position - advance
      observation?["refusal"] = "main.centre-entry"
      guard atDoor.canEnter(roll: autoPilot.rollRate, speed: terminalSpeed) else { return nil }
      guard
        nativeMainStationHullCourseIsClear(
          station, from: flight.pose, to: endpoint, observation: &observation)
      else { return nil }
    }
    let radius = nativeStationRadius(player)
    observation?["playerRadius"] = String(radius)
    observation?["refusal"] = "corridor.player-radius"
    guard radius.isFinite else { return nil }
    return (flight.pose.position, flight.pose.systemPoint(advance), station.id, radius)
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

  @inline(never)
  private mutating func nativeStationApproachClear(
    from start: Vector3, to end: Vector3, excluding stationID: Int, radius: Double,
    observation: inout [String: String]?, refineCourse: Bool, bodyCourseRefused: inout Bool
  ) -> Bool {
    bodyCourseRefused = false
    observation?["refusal"] = "corridor.context"
    guard let anchors = withReadOnlyCommander({ $0.flightSimulation.anchors }), radius.isFinite
    else { return false }
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
    let candidates = bodies
    for index in candidates.indices {
      guard
        nativeStationApproachBodyClear(
          candidates[index], from: start, to: end, excluding: stationID, radius: radius,
          observation: &observation, refineCourse: refineCourse,
          bodyCourseRefused: &bodyCourseRefused)
      else { return false }
    }
    return true
  }

  @inline(never)
  private mutating func nativeStationApproachBodyClear(
    _ body: borrowing SpaceBody, from start: Vector3, to end: Vector3,
    excluding stationID: Int, radius: Double, observation: inout [String: String]?,
    refineCourse: Bool, bodyCourseRefused: inout Bool
  ) -> Bool {
    if !(body.energy > 0) {
      guard refineCourse else { return true }
      guard !body.energy.isFinite else { return true }
    }
    guard body.id != stationID else { return true }
    guard
      let inputs = nativeStationApproachBodyInputs(
        body, from: start, to: end, refineCourse: refineCourse)
    else { return false }
    let (point, distance, mesh, bodyRadius) = inputs
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
        if assessment == .clear { return true }
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
    return true
  }

  @inline(never)
  private mutating func nativeStationApproachBodyInputs(
    _ body: borrowing SpaceBody, from start: Vector3, to end: Vector3, refineCourse: Bool
  ) -> (point: Vector3, distance: Double, mesh: Mesh, bodyRadius: Double)? {
    let pose = withNativeStationReadOnlyCommander { $0.flightSimulation.pose }
    let point = pose.systemPoint(body.position)
    let distance = Self.nativeStationSegmentDistance(point, start: start, end: end)
    let mesh: Mesh
    if refineCourse, body.scriptNPC != nil {
      guard let source = scriptNPCMesh(body) else { return nil }
      mesh = source
    } else {
      mesh = nativeStationApproachGameplayMesh(for: body)
    }
    let bodyRadius = Self.nativeStationMeshRadius(mesh)
    return (point, distance, mesh, bodyRadius)
  }

  /// Keep the optional scripted fallback's ordinary reader frame out of assessment.
  @inline(never)
  private mutating func nativeStationAssessmentScriptMesh(_ body: SpaceBody) -> Mesh? {
    scriptNPCMesh(body)
  }

  /// Current-course geometry only. Native entry retains its independent clearance gate.
  /// Exact maintained mesh distance and containment distinguish material contact
  /// from overlapping enclosing spheres. Prepared geometry uses the existing bounded cache.
  @inline(never)
  mutating func nativeStationCourseObstacleAssessment(
    _ body: SpaceBody, from start: Vector3, to end: Vector3, radius: Double,
    mesh actualMesh: Mesh? = nil
  ) -> StationEntryCourseObstacleAssessment {
    let flight = withNativeStationReadOnlyCommander { $0.flightSimulation }
    guard let physical = body.physical,
      physical.identity.system
        == withNativeStationReadOnlyCommander({
          SystemIdentity(galaxy: $0.galaxy, system: $0.system)
        }), physical.identity.visit == flight.visit,
      physical.velocity.finite, body.rotation.isFinite, body.rotationRate.isFinite,
      bodies.filter({ $0.id == body.id }).count == 1,
      NativeStationSnapshot.matches(body, in: bodies),
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1
    else { return .invalid }
    if let id = physical.catalogueShipID, ShipCatalogue.ship(id) == nil { return .invalid }
    let mesh: Mesh
    if let actualMesh {
      mesh = actualMesh
    } else if body.scriptNPC != nil {
      guard let source = nativeStationAssessmentScriptMesh(body) else { return .invalid }
      mesh = source
    } else {
      mesh = nativeStationApproachGameplayMesh(for: body)
    }
    guard mesh.vertices.count >= 4, mesh.faces.count >= 4,
      mesh.vertices.allSatisfy({ $0.finite }),
      mesh.faces.allSatisfy({
        $0.count >= 3 && $0.allSatisfy { mesh.vertices.indices.contains($0) }
      })
    else { return .invalid }
    let observerPose = withNativeStationReadOnlyCommander { $0.flightSimulation.pose }
    let obstacle = Self.modelPose(of: body, player: observerPose)
    let frame = flight.pose.orientation
    let bodyRadius = Self.nativeStationMeshRadius(mesh)
    let player = withNativeStationReadOnlyCommander { $0.playerMesh }
    let playerRadius = Self.nativeStationMeshRadius(player)
    guard obstacle.position.finite, obstacle.orientation.validRotation, frame.validRotation,
      bodyRadius.isFinite, bodyRadius > 0, playerRadius.isFinite, radius >= playerRadius
    else { return .invalid }
    guard
      let playerHull = preparedWorkHull(
        mesh: player,
        key: "station-entry-player:" + withNativeStationReadOnlyCommander { $0.shipID }),
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
    observeFleetDocking(body: body, secondary: receipt)
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
    Self.nativeStationSegmentDistance(point, start: start, end: end)
  }

  private static func nativeStationSegmentDistance(
    _ point: Vector3, start: Vector3, end: Vector3
  ) -> Double {
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

/// Created only by the attained full-hull proof below; a saved contact is never this authority.
struct NativeArkDockWitness {
  let contact: NativeArkFuelContact
  let body: SpaceBody
  fileprivate init(contact: NativeArkFuelContact, body: SpaceBody) {
    self.contact = contact
    self.body = body
  }
}

extension Game {
  func nativeInductionArkDockWitness(
    state: NativeInductionArkState, sample: NativeWormholeMotionSample
  ) -> NativeArkDockWitness? {
    guard state.admission != nil, state.loss == nil, state.dockedContact == nil,
      state.fuelContacts.count < 128,
      let profile = try? NativeInductionArkSource.profile(),
      let physical = try? OriginalHullPhysicalContract.haflinger.get()
    else { return nil }
    return nativeCustodianDockWitness(
      sample: sample, job: state.authorization.job,
      actor: state.authorization.actor, mission: state.authorization.parent,
      vessel: state.authorization.registeredArk, nextContact: UInt64(state.fuelContacts.count + 1),
      profile: profile, source: physical)
  }

  func nativeInductionRescueDockWitness(
    state: NativeInductionCrewLogState, sample: NativeWormholeMotionSample
  ) -> NativeArkDockWitness? {
    guard let flight = state.flight, state.livingCrew.count == 2, flight.dockedContact == nil,
      flight.fuelContacts.count < 128,
      let profile = try? NativeInductionCrewLogSource.flightProfile.get(),
      let physical = try? OriginalHullPhysicalContract.burro.get()
    else { return nil }
    return nativeCustodianDockWitness(
      sample: sample, job: state.authorization.job,
      actor: flight.authorization.actor, mission: state.authorization.manifest.mission,
      vessel: state.authorization.manifest.launch,
      nextContact: UInt64(flight.fuelContacts.count + 1),
      profile: profile, source: physical)
  }

  /// The sealed result still requires the same attained full-hull/native facility proof.
  private func nativeCustodianDockWitness(
    sample: NativeWormholeMotionSample, job: UUID,
    actor: UUID, mission: UUID, vessel: UUID, nextContact: UInt64,
    profile: ScriptNPCDefinition, source: OriginalHullPhysicalContract
  ) -> NativeArkDockWitness? {
    let flight = commander.flightSimulation
    let delta = flight.physicalTime - sample.physicalTime
    guard !docked, sample.system == systemIdentity, sample.visit == flight.visit,
      delta.isFinite, delta > 0, delta <= 0.100001,
      let body = bodies.first(where: { $0.missionActorID == actor }),
      body.energy > 0, body.missionInstanceID == job,
      body.scriptNPC?.fit.definition == profile,
      let physical = body.physical,
      let beforeBody = sample.bodies.first(where: { $0.physical?.identity == physical.identity }),
      let station = bodies.first(where: { $0.id == 0 && $0.hull == .station && $0.energy > 0 }),
      let stationActor = station.physical?.identity,
      let beforeStation = sample.bodies.first(where: { $0.physical?.identity == stationActor }),
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.observation.actor == stationActor,
      let current = currentNativeMainStationAnchor(at: flight.physicalTime),
      let previous = currentNativeMainStationAnchor(at: sample.physicalTime),
      (sample.pose.systemPoint(beforeStation.position) - previous.position).length < 1e-5,
      (flight.pose.systemPoint(station.position) - current.position).length < 1e-5
    else { return nil }
    let start = Self.arkModelPose(beforeBody, player: sample.pose)
    let end = modelPose(of: body)
    let fromStation = Self.arkModelPose(beforeStation, player: sample.pose)
    let toStation = modelPose(of: station)
    guard
      NativeArkDockCrossing.admits(
        from: start, to: end,
        stationFrom: fromStation, stationTo: toStation, delta: delta),
      nativeInductionArkHullSweepIsClear(
        source.physicalMesh, from: start, to: end,
        stationFrom: fromStation, stationTo: toStation, delta: delta, requireAperture: true),
      inductionArkOtherMotionIsClear(
        body: body, from: start.position, to: end.position,
        sample: sample, radius: source.envelope.clearanceRadius)
    else { return nil }
    let contact = NativeArkFuelContact(
      mission: mission, ark: vessel,
      station: facility.identity, stationActor: stationActor, arkActor: physical.identity,
      sequence: nextContact, physicalTime: flight.physicalTime)
    guard contact.valid else { return nil }
    return .init(contact: contact, body: body)
  }

  /// Same aperture and solid-triangle sweep as native main-station docking, with the actual NPC mesh.
  func nativeInductionArkHullSweepIsClear(
    _ mesh: Mesh, from: ShipPose, to: ShipPose,
    stationFrom: ShipPose, stationTo: ShipPose, delta: Double, requireAperture: Bool
  ) -> Bool {
    guard delta.isFinite, delta >= 0, delta <= 0.100001 else { return false }
    let angle =
      Self.arkTurnAngle(from.orientation, to.orientation)
      + Self.arkTurnAngle(stationFrom.orientation, stationTo.orientation)
    let margin = (nativeStationRadius(mesh) + nativeStationRadius(MainStationGeometry.mesh)) * angle
    guard margin.isFinite else { return false }
    if requireAperture {
      guard
        nativeStationHullFits(
          mesh, ship: from, station: stationFrom.position,
          orientation: stationFrom.orientation, port: MainStationGeometry.docking, margin: margin),
        nativeStationHullFits(
          mesh, ship: to, station: stationTo.position,
          orientation: stationTo.orientation, port: MainStationGeometry.docking, margin: margin)
      else { return false }
    }
    return nativeStructureHullSweepClear(
      mesh, from: from, to: to,
      position: stationFrom.position, endPosition: stationTo.position,
      fromOrientation: stationFrom.orientation, toOrientation: stationTo.orientation,
      margin: margin, mesh: MainStationGeometry.mesh)
  }

  private static func arkTurnAngle(_ a: Basis3, _ b: Basis3) -> Double {
    acos(max(-1, min(1, (a.x.dot(b.x) + a.y.dot(b.y) + a.z.dot(b.z) - 1) / 2)))
  }
  private static func arkModelPose(_ body: SpaceBody, player: ShipPose) -> ShipPose {
    var orientation = Basis3()
    orientation.x = player.orientation.apply(body.modelVector(.init(1, 0, 0)))
    orientation.y = player.orientation.apply(body.modelVector(.init(0, 1, 0)))
    orientation.z = player.orientation.apply(body.modelVector(.init(0, 0, 1)))
    return .init(position: player.systemPoint(body.position), orientation: orientation)
  }
  func inductionArkOtherMotionIsClear(
    body: SpaceBody, from: Vector3, to: Vector3, sample: NativeWormholeMotionSample, radius: Double
  ) -> Bool {
    func clear(_ start: Vector3, _ end: Vector3, _ obstacleRadius: Double) -> Bool {
      let a = from - start
      let d = to - end - a
      let squared = d.dot(d)
      let t = squared > 1e-12 ? max(0, min(1, -a.dot(d) / squared)) : 0
      return (a + d * t).length > radius + obstacleRadius
    }
    let pose = commander.flightSimulation.pose
    if !clear(sample.pose.position, pose.position, nativeStationRadius(commander.playerMesh)) {
      return false
    }
    for other in bodies where other.id != body.id && other.id != 0 && other.energy > 0 {
      guard let identity = other.physical?.identity,
        let before = sample.bodies.first(where: { $0.physical?.identity == identity })
      else { return false }
      guard
        clear(
          sample.pose.systemPoint(before.position), pose.systemPoint(other.position),
          nativeStationRadius(gameplayMesh(for: other)))
      else { return false }
    }
    return true
  }
}
