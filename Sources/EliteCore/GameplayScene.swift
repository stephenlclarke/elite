import Foundation

extension Commander {
  var ordinaryCommodityAmounts: [CommodityAmount] {
    CommodityIdentity.allCases.compactMap { commodity in
      let reserved =
        commodity == .firearms ? markedFirearms : commodity == .slaves ? nativeCaptiveCount : 0
      let quantity = max(0, cargo[commodity.rawValue] - reserved)
      return quantity > 0 ? .init(commodity: commodity, quantity: quantity) : nil
    }
  }
}

extension Game {
  var systemIdentity: SystemIdentity {
    .init(galaxy: commander.galaxy, system: commander.system)
  }

  var gameplaySeed: UInt64 {
    UInt64(currentSystem.seed.a) << 32 | UInt64(currentSystem.seed.b) << 16
      | UInt64(currentSystem.seed.c)
  }

  @discardableResult
  mutating func beginGameplayVisit(arriving: Bool, freshLaunchTrafficID: Int? = nil) -> Bool {
    do { try migrateMiningPresence(legacyMissing: false) } catch { return false }
    commander.savedEMPCharge = nil
    if var state = commander.savedEMPState {
      for source in state.records.keys {
        state.records[source]?.hull.binding = nil
        for i in state.records[source]!.pods.indices {
          state.records[source]?.pods[i].binding = nil
        }
      }
      commander.savedEMPState = state
    }
    invalidateNativeStationAuthority()
    activeECMActivation = nil
    let oldPlayer = commander.flightSimulation.player
    commander.flightSimulation.enter(systemIdentity, arriving: arriving)
    if let oldPlayer, let player = commander.flightSimulation.player {
      commander.stationSecurity.rebindPlayer(from: oldPlayer, to: player)
    }
    let flight = commander.flightSimulation
    commander.crimeLedger.beginVisit(system: systemIdentity, visit: flight.visit)
    if let anchors = flight.anchors {
      celestials = [
        .init(
          kind: .planet, position: flight.pose.shipPoint(anchors.planet.position),
          radius: anchors.planet.radius),
        .init(
          kind: .sun, position: flight.pose.shipPoint(anchors.sun.position),
          radius: anchors.sun.radius),
      ]
      rebuildMiningFields()
      salvageSites = SalvageSites.generate(anchors: anchors, seed: gameplaySeed)
    }
    commander.miningLedger.resetPhysicalBindings(system: systemIdentity)
    commander.cargoDebrisLedger.resetPhysicalBindings(system: systemIdentity)
    commander.salvageLedger.resetPhysicalBindings(system: systemIdentity)
    commander.npcPersistence.resetPhysicalBindings(system: systemIdentity)
    gameplayRevision &+= 1
    ensurePhysicalActors()
    if let freshLaunchTrafficID { initializeNativeLaunchDisposition(bodyID: freshLaunchTrafficID) }
    _ = persistNPCStates()
    admitPersistentNPCs()
    if let context = gameplayContext() {
      commander.encounterDirector = EncounterDirector(context: context)
    }
    return true
  }

  /// Called only for the actual new launch or hyperspace-arrival body before first capture.
  private mutating func initializeNativeLaunchDisposition(bodyID: Int) {
    let flight = commander.flightSimulation
    guard let index = bodies.firstIndex(where: { $0.id == bodyID }),
      [.cobra, .sidewinder].contains(bodies[index].hull), !bodies[index].navalTarget,
      bodies[index].missionInstanceID == nil, bodies[index].blackjackRole == nil,
      let physical = bodies[index].physical, physical.spawnIdentity == nil,
      physical.empSource == nil, physical.salvage == nil,
      physical.identity.system == systemIdentity, physical.identity.visit == flight.visit,
      var npc = physical.npc, npc.routeProvenance == .inferredLocal,
      let player = flight.player, let station = flight.anchors?.station.identity,
      let disposition = AmbientEncounterPolicy.nativeLaunch(
        actor: physical.identity, seed: gameplaySeed,
        government: currentSystem.government, role: npc.role)
    else { return }
    npc.legal = disposition.legalOverride ?? npc.legal
    npc.legalProvenance = .generated
    npc.routeProvenance = .generated
    npc.intention = disposition.hostile ? .engage(player) : .dock(station)
    bodies[index].hostile = disposition.hostile
    bodies[index].physical?.npc = npc
  }

  /// Legacy/native encounter creators are adopted before their first attack.
  mutating func ensurePhysicalActors() {
    if commander.flightSimulation.system != systemIdentity {
      commander.flightSimulation.enter(systemIdentity, arriving: false)
    }
    let flight = commander.flightSimulation
    for index in bodies.indices
    where bodies[index].physical == nil && bodies[index].scriptShot == nil
      && bodies[index].nativeStationIdentity == nil
    {
      let identity: ActorIdentity?
      if bodies[index].id == 0 && bodies[index].hull == .station {
        identity = flight.anchors?.station.identity
      } else {
        identity = commander.flightSimulation.allocateActor()
      }
      guard let identity else { continue }
      let body = bodies[index]
      bodies[index].physical = nativePhysicalActorState(for: body, identity: identity)
    }
    do { try populateNativeStations() } catch {
      notify("RRS STATION ADMISSION UNAVAILABLE", voiced: false)
    }
  }

  /// The same native adoption policy serves fresh mission admissions without allocating identities.
  func nativePhysicalActorState(
    for body: SpaceBody, identity: ActorIdentity, spawnIdentity: SpawnIdentity? = nil,
    velocity: Vector3 = .init(0, 0, 0)
  ) -> PhysicalActorState {
    let role = legacyNPCRole(body)
    var npc = role.map {
      NPCState(role: $0, origin: systemIdentity, destination: systemIdentity)
    }
    npc?.routeProvenance = .inferredLocal
    npc?.resources = NPCResources.legacyEnergyOnly(
      maximumEnergy: body.scriptNPC?.fit.definition.energy
        ?? (body.blackjackRole == nil
          ? (body.hull.navalEnergy ?? 100) : BlackjackTarget.energy))
    if [.constrictor, .thargoid, .thargon].contains(body.hull) {
      npc?.legal = .init(value: 64, bountyTenths: body.hull.navalBounty ?? 0)
      npc?.legalProvenance = .recorded
    }
    if body.hostile, let player = commander.flightSimulation.player {
      npc?.intention = .engage(player)
    }
    return .init(
      identity: identity, population: population(of: body, role: role), npc: npc,
      velocity: velocity, spawnIdentity: spawnIdentity, blocksNavalEncounter: body.hull == .viper)
  }

  private func legacyNPCRole(_ body: SpaceBody) -> NPCRole? {
    if body.missionInstanceID != nil { return .mission }
    guard body.hull.isTargetShip else { return nil }
    if body.hull == .viper { return .police }
    if body.blackjackRole != nil || body.navalTarget
      || [.constrictor, .thargoid, .thargon].contains(body.hull)
    {
      return .mission
    }
    return body.hostile ? .pirate : .trader
  }

  private func population(of body: SpaceBody, role: NPCRole?) -> PopulationClass {
    switch body.hull {
    case .asteroid: return .asteroid
    case .cargo: return .cargo
    case .missile: return .projectile
    case .station: return .mission
    default: break
    }
    switch role {
    case .police: return .police
    case .pirate: return .pirate
    case .mission: return .mission
    default: return .civilian
    }
  }

  func gameplayContext() -> EncounterContext? {
    let flight = commander.flightSimulation
    guard let playerID = flight.player, let canonical = flight.anchors else { return nil }
    var anchors = canonical
    if let station = bodies.first(where: { $0.id == 0 && $0.hull == .station }) {
      var orientation = Basis3()
      orientation.x = flight.pose.orientation.apply(station.modelVector(.init(1, 0, 0)))
      orientation.y = flight.pose.orientation.apply(station.modelVector(.init(0, 1, 0)))
      orientation.z = flight.pose.orientation.apply(station.modelVector(.init(0, 0, 1)))
      let normal = flight.pose.orientation.apply(station.entranceNormal)
      anchors = .init(
        system: canonical.system,
        station: .init(
          identity: canonical.station.identity,
          position: flight.pose.systemPoint(station.position), orientation: orientation,
          exitPosition: flight.pose.systemPoint(station.entrancePosition) + normal * 400,
          exitDirection: normal),
        arrival: canonical.arrival, planet: canonical.planet, sun: canonical.sun)
    }
    let actors: [ActorSnapshot] = bodies.compactMap { body -> ActorSnapshot? in
      guard let physical = body.physical else { return nil }
      let native: ShipPerformance? = physical.catalogueShipID.flatMap {
        ShipCatalogue.ship($0)?.game
      }
      let maximumEnergy: Double =
        body.nativeStationIdentity.flatMap { NativeStationSource.binding(for: $0)?.maximumEnergy }
        ?? body.scriptNPC?.fit.definition.energy
        ?? physical.npc?.resources?.energyCapacity ?? native?.energy ?? body.hull.navalEnergy ?? 100
      let maximumSpeed: Double =
        body.scriptNPC?.fit.definition.speed
        ?? ((native?.speed ?? ShipCatalogue.nativeShip(body.hull)?.game?.speed ?? 20) * 18)
      let legal: LegalRecord = physical.npc?.legal ?? LegalRecord()
      let cargo: [CommodityAmount] = physical.npc?.ordinaryCargo ?? []
      var orientation = Basis3()
      orientation.x = flight.pose.orientation.apply(body.orientation.x)
      orientation.y = flight.pose.orientation.apply(body.orientation.y)
      orientation.z = flight.pose.orientation.apply(body.orientation.z)
      return ActorSnapshot(
        identity: physical.identity, hull: body.hull,
        position: flight.pose.systemPoint(body.position), orientation: orientation,
        velocity: physical.velocity, energy: body.energy,
        maximumEnergy: maximumEnergy, maximumSpeedUnitsPerSecond: maximumSpeed,
        legal: legal, npc: physical.npc,
        rock: physical.rock, payload: physical.payload,
        ordinaryCargo: cargo,
        catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
        salvage: physical.salvage)
    }
    var protection = MissionProtection()
    protection.protectedActors = Set(
      bodies.filter {
        $0.physical?.empCrewPod != nil || $0.navalTarget || $0.blackjackRole != nil
          || $0.physical?.npc?.role == .mission
          || $0.missionInstanceID != nil
      }
      .compactMap { $0.physical?.identity })
    protection.blocksNavalEncounter = bodies.contains { $0.physical?.blocksNavalEncounter == true }
    var budget = AdmissionBudget(total: bodies.count)
    for body in bodies where body.id != 0 {
      if let population = body.physical?.population { budget.active[population, default: 0] += 1 }
    }
    let player = ActorSnapshot(
      identity: playerID, hull: .cobra, position: flight.pose.position,
      orientation: flight.pose.orientation,
      velocity: flightWorldVelocity,
      energy: energy, maximumEnergy: commander.performance.energy,
      maximumSpeedUnitsPerSecond: commander.performance.speed * 18,
      legal: .init(value: min(255, commander.legal)), npc: nil, rock: nil, payload: nil,
      ordinaryCargo: commander.ordinaryCommodityAmounts, catalogueShipID: commander.shipID)
    let miningPresence = resolvedMiningPresence
    let depleted = Set(
      miningFields.flatMap(\.rocks).filter { commander.miningLedger.isDepleted($0.identity) }
        .map(\.identity))
    return .init(
      system: systemIdentity, seed: gameplaySeed, government: currentSystem.government,
      visit: flight.visit, revision: gameplayRevision, physicalTime: flight.physicalTime,
      anchors: anchors, player: player, actors: actors, protection: protection,
      budget: budget, perceptionRadius: 6000, depletedRocks: depleted,
      miningPresence: miningPresence)
  }
}
