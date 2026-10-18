import Foundation

extension Commander {
  var ordinaryCommodityAmounts: [CommodityAmount] {
    var amounts: [CommodityAmount] = []
    for commodity in CommodityIdentity.allCases {
      let reserved =
        commodity == .firearms ? markedFirearms : commodity == .slaves ? nativeCaptiveCount : 0
      let quantity = max(0, cargo[commodity.rawValue] - reserved)
      if quantity > 0 { amounts.append(.init(commodity: commodity, quantity: quantity)) }
    }
    return amounts
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
      rebuildSalvageSites()
    }
    commander.miningLedger.resetPhysicalBindings(system: systemIdentity)
    commander.cargoDebrisLedger.resetPhysicalBindings(system: systemIdentity)
    commander.salvageLedger.resetPhysicalBindings(system: systemIdentity)
    commander.npcPersistence.resetPhysicalBindings(system: systemIdentity)
    gameplayRevision &+= 1
    ensurePhysicalActors()
    if let freshLaunchTrafficID { initializeNativeLaunchDisposition(bodyID: freshLaunchTrafficID) }
    _ = persistNPCStates()
    do { try prepareNativeCrimboVisit() } catch { return false }
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
    adoptNativePhysicalActors()
    do { try populateNativeStations() } catch {
      notify("RRS STATION ADMISSION UNAVAILABLE", voiced: false)
    }
  }

  // Release completed adoption buffers before station admission enters its own geometry checks.
  private mutating func adoptNativePhysicalActors() {
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
    let flight = Self.currentGameplayFlight(commander)
    guard let playerID = flight.player, let canonical = flight.anchors else { return nil }
    let anchors = Self.gameplayAnchors(bodies, flight: flight, canonical: canonical)
    let actors = Self.gameplayActors(bodies, pose: flight.pose)
    return Self.finishGameplayContext(
      self, flight: flight, playerID: playerID, anchors: anchors, actors: actors)
  }

  @inline(never)
  private static func currentGameplayFlight(_ commander: borrowing Commander)
    -> FlightSimulationState
  {
    commander.flightSimulation
  }

  // Station and actor projection finish before the later protection/player/mining phases.
  @inline(never)
  private static func gameplayAnchors(
    _ bodies: borrowing [SpaceBody], flight: FlightSimulationState, canonical: SystemAnchors
  ) -> SystemAnchors {
    for index in bodies.indices where bodies[index].id == 0 && bodies[index].hull == .station {
      return projectedGameplayAnchors(bodies[index], flight: flight, canonical: canonical)
    }
    return canonical
  }

  @inline(never)
  private static func projectedGameplayAnchors(
    _ station: borrowing SpaceBody, flight: FlightSimulationState, canonical: SystemAnchors
  ) -> SystemAnchors {
    var orientation = Basis3()
    orientation.x = flight.pose.orientation.apply(station.modelVector(.init(1, 0, 0)))
    orientation.y = flight.pose.orientation.apply(station.modelVector(.init(0, 1, 0)))
    orientation.z = flight.pose.orientation.apply(station.modelVector(.init(0, 0, 1)))
    let normal = flight.pose.orientation.apply(station.entranceNormal)
    return .init(
      system: canonical.system,
      station: .init(
        identity: canonical.station.identity,
        position: flight.pose.systemPoint(station.position), orientation: orientation,
        exitPosition: flight.pose.systemPoint(station.entrancePosition) + normal * 400,
        exitDirection: normal),
      arrival: canonical.arrival, planet: canonical.planet, sun: canonical.sun)
  }

  // Borrow each actual body in order; missing physical state retains the original omission rule.
  @inline(never)
  private static func gameplayActors(_ bodies: borrowing [SpaceBody], pose: ShipPose)
    -> [ActorSnapshot]
  {
    var actors: [ActorSnapshot] = []
    for index in bodies.indices {
      if let actor = gameplayActor(bodies[index], pose: pose) { actors.append(actor) }
    }
    return actors
  }

  @inline(never)
  private static func gameplayActor(_ body: borrowing SpaceBody, pose: ShipPose) -> ActorSnapshot? {
    guard let physical = body.physical else { return nil }
    let limits = gameplayActorLimits(body, physical: physical)
    return projectedGameplayActor(body, physical: physical, pose: pose, limits: limits)
  }

  @inline(never)
  private static func gameplayActorLimits(
    _ body: borrowing SpaceBody, physical: borrowing PhysicalActorState
  ) -> (energy: Double, speed: Double) {
    let native: ShipPerformance? = physical.catalogueShipID.flatMap {
      ShipCatalogue.ship($0)?.game
    }
    let maximumEnergy = gameplayActorMaximumEnergy(body, physical: physical, native: native)
    let maximumSpeed = gameplayActorMaximumSpeed(body, native: native)
    return (maximumEnergy, maximumSpeed)
  }

  @inline(never)
  private static func gameplayActorMaximumEnergy(
    _ body: borrowing SpaceBody, physical: borrowing PhysicalActorState, native: ShipPerformance?
  ) -> Double {
    if let identity = body.nativeStationIdentity,
      let maximum = NativeStationSource.binding(for: identity)?.maximumEnergy
    {
      return maximum
    }
    if let maximum = body.scriptNPC?.fit.definition.energy { return maximum }
    if let maximum = physical.npc?.resources?.energyCapacity { return maximum }
    if let maximum = native?.energy { return maximum }
    if let maximum = body.hull.navalEnergy { return maximum }
    return 100
  }

  @inline(never)
  private static func gameplayActorMaximumSpeed(
    _ body: borrowing SpaceBody, native: ShipPerformance?
  ) -> Double {
    if let maximum = body.scriptNPC?.fit.definition.speed { return maximum }
    if let speed = native?.speed { return speed * 18 }
    let speed = ShipCatalogue.nativeShip(body.hull)?.game?.speed ?? 20
    return speed * 18
  }

  @inline(never)
  private static func projectedGameplayActor(
    _ body: borrowing SpaceBody, physical: borrowing PhysicalActorState, pose: ShipPose,
    limits: (energy: Double, speed: Double)
  ) -> ActorSnapshot {
    let maximumEnergy = limits.energy
    let maximumSpeed = limits.speed
    let legal: LegalRecord = physical.npc?.legal ?? LegalRecord()
    let cargo: [CommodityAmount] = physical.npc?.ordinaryCargo ?? []
    var orientation = Basis3()
    orientation.x = pose.orientation.apply(body.orientation.x)
    orientation.y = pose.orientation.apply(body.orientation.y)
    orientation.z = pose.orientation.apply(body.orientation.z)
    return ActorSnapshot(
      identity: physical.identity, hull: body.hull,
      position: pose.systemPoint(body.position), orientation: orientation,
      velocity: physical.velocity, energy: body.energy,
      maximumEnergy: maximumEnergy, maximumSpeedUnitsPerSecond: maximumSpeed,
      legal: legal, npc: physical.npc,
      rock: physical.rock, payload: physical.payload,
      ordinaryCargo: cargo,
      catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
      salvage: physical.salvage)
  }

  @inline(never)
  private static func finishGameplayContext(
    _ game: borrowing Game, flight: FlightSimulationState, playerID: ActorIdentity,
    anchors: SystemAnchors, actors: [ActorSnapshot]
  ) -> EncounterContext {
    let scene = Self.gameplayProtectionAndBudget(game.bodies)
    let player = Self.gameplayPlayer(game, flight: flight, playerID: playerID)
    let miningPresence = Self.gameplayMiningPresence(game)
    let depleted = Self.depletedGameplayRocks(game)
    return .init(
      system: Self.gameplaySystemIdentity(game.commander), seed: Self.gameplayContextSeed(game),
      government: Self.gameplayCurrentSystem(game).government,
      visit: flight.visit, revision: game.gameplayRevision, physicalTime: flight.physicalTime,
      anchors: anchors, player: player, actors: actors, protection: scene.protection,
      budget: scene.budget, perceptionRadius: 6000, depletedRocks: depleted,
      miningPresence: miningPresence)
  }

  @inline(never)
  private static func gameplayProtectionAndBudget(_ bodies: [SpaceBody])
    -> (protection: MissionProtection, budget: AdmissionBudget)
  {
    var protection = MissionProtection()
    protection.protectedActors = Set(
      bodies.filter { !$0.gameplayProtectionReasons.isEmpty }
        .compactMap { $0.physical?.identity })
    protection.blocksNavalEncounter = bodies.contains {
      $0.physical?.blocksNavalEncounter == true
    }
    var budget = AdmissionBudget(total: bodies.count)
    for body in bodies where body.id != 0 {
      if let population = body.physical?.population { budget.active[population, default: 0] += 1 }
    }
    return (protection, budget)
  }

  @inline(never)
  private static func gameplayPlayer(
    _ game: borrowing Game, flight: FlightSimulationState, playerID: ActorIdentity
  ) -> ActorSnapshot {
    return ActorSnapshot(
      identity: playerID, hull: .cobra, position: flight.pose.position,
      orientation: flight.pose.orientation,
      velocity: Self.currentFlightWorldVelocity(game),
      energy: game.energy, maximumEnergy: Self.gameplayPlayerMaximumEnergy(game.commander),
      maximumSpeedUnitsPerSecond: Self.gameplayPlayerMaximumSpeed(game.commander),
      legal: .init(value: Self.gameplayPlayerLegal(game.commander)), npc: nil, rock: nil,
      payload: nil,
      ordinaryCargo: Self.gameplayPlayerCargo(game.commander),
      catalogueShipID: Self.gameplayPlayerShipID(game.commander)
    )
  }

  @inline(never)
  private static func gameplayPlayerMaximumEnergy(_ commander: borrowing Commander) -> Double {
    commander.performance.energy
  }

  @inline(never)
  private static func gameplayPlayerMaximumSpeed(_ commander: borrowing Commander) -> Double {
    commander.performance.speed * 18
  }

  @inline(never)
  private static func gameplayPlayerLegal(_ commander: borrowing Commander) -> Int {
    min(255, commander.legal)
  }

  @inline(never)
  private static func gameplayPlayerCargo(_ commander: borrowing Commander) -> [CommodityAmount] {
    commander.ordinaryCommodityAmounts
  }

  @inline(never)
  private static func gameplayPlayerShipID(_ commander: borrowing Commander) -> String {
    commander.shipID
  }

  @inline(never)
  private static func gameplaySystemIndex(_ commander: borrowing Commander) -> Int {
    commander.system
  }

  @inline(never)
  private static func gameplayGalaxy(_ commander: borrowing Commander) -> Int {
    commander.galaxy
  }

  @inline(never)
  private static func gameplaySystemIdentity(_ commander: borrowing Commander) -> SystemIdentity {
    .init(galaxy: commander.galaxy, system: commander.system)
  }

  @inline(never)
  private static func gameplayCurrentSystem(_ game: borrowing Game) -> StarSystem {
    game.systems[Self.gameplaySystemIndex(game.commander)]
  }

  @inline(never)
  private static func gameplayContextSeed(_ game: borrowing Game) -> UInt64 {
    UInt64(Self.gameplayCurrentSystem(game).seed.a) << 32
      | UInt64(Self.gameplayCurrentSystem(game).seed.b) << 16
      | UInt64(Self.gameplayCurrentSystem(game).seed.c)
  }

  @inline(never)
  private static func gameplayMiningLedger(_ commander: borrowing Commander) -> MiningLedger {
    commander.miningLedger
  }

  @inline(never)
  private static func gameplayMiningPresence(_ game: borrowing Game) -> MiningScenePresence {
    let ledger = Self.gameplayMiningLedger(game.commander)
    return .init(
      ringPresent: ledger.ringPresence(
        system: Self.gameplayCurrentSystem(game), galaxy: Self.gameplayGalaxy(game.commander)),
      includingLegacy: ledger.retainsLegacyFields)
  }

  @inline(never)
  private static func gameplayRockIsDepleted(
    _ rock: RockIdentity, commander: borrowing Commander
  ) -> Bool {
    commander.miningLedger.isDepleted(rock)
  }

  @inline(never)
  private static func depletedGameplayRocks(_ game: borrowing Game) -> Set<RockIdentity> {
    var depleted = Set<RockIdentity>()
    for field in game.miningFields {
      for rock in field.rocks
      where Self.gameplayRockIsDepleted(rock.identity, commander: game.commander) {
        depleted.insert(rock.identity)
      }
    }
    return depleted
  }
}
