import Foundation

/// Closed native evidence; nil bus is a distinct untouched baseline, never numeric full power.
struct NativeCrimboContactSeed: Sendable {
  fileprivate enum Bus: Equatable, Sendable {
    case unmaterializedHealthy
    case materialized(ElectricalReserve)
    var reserve: ElectricalReserve? {
      if case .materialized(let actual) = self { return actual }
      return nil
    }
  }
  fileprivate struct Key: Equatable, Sendable {
    let birth: NativeCrimboOriginalBirth
    let manifest: NativeProviderManifest
    let actor: ActorIdentity
    let player: ActorIdentity
    let hull: UUID
    let inventoryRevision: UInt64
    let epoch: UUID
  }
  fileprivate struct Owner: Sendable {
    let registry: NativeCrimboRegistry
    let birth: NativeCrimboOriginalBirth
    let actor: ActorIdentity
    let player: ActorIdentity
    let hull: UUID
    let inventoryRevision: UInt64
    let crew: [Int]
    let episode: UInt64?
    let recoveredAt: Double?
    let playerBus: NativeCrimboContactSeed.Bus
    let sourceBus: NativeCrimboContactSeed.Bus
    let time: Double
  }
  fileprivate let key: Key
  fileprivate let challenge: UUID
  fileprivate let crew: [Int]
  fileprivate let episode: UInt64?
  fileprivate let recoveredAt: Double?
  fileprivate let playerBus: NativeCrimboContactSeed.Bus
  fileprivate let sourceBus: NativeCrimboContactSeed.Bus
  fileprivate let time: Double
  fileprivate let frame: UInt64
  fileprivate let subjectPosition: Vector3
  fileprivate let playerPose: ShipPose

  fileprivate init(owner: Owner, epoch: UUID, frame: UInt64, subject: Vector3, playerPose: ShipPose)
  {
    key = .init(
      birth: owner.birth, manifest: owner.registry.manifest, actor: owner.actor,
      player: owner.player, hull: owner.hull, inventoryRevision: owner.inventoryRevision,
      epoch: epoch)
    challenge = UUID()
    crew = owner.crew
    episode = owner.episode
    recoveredAt = owner.recoveredAt
    playerBus = owner.playerBus
    sourceBus = owner.sourceBus
    time = owner.time
    self.frame = frame
    subjectPosition = subject
    self.playerPose = playerPose
  }
}

struct NativeCrimboContactContinuity: Sendable {
  fileprivate let key: NativeCrimboContactSeed.Key
  fileprivate let frame: UInt64
  fileprivate let time: Double
  fileprivate let incarnation: UUID
}

/// Native query/reply result only. This value neither folds progress nor grants mission readiness.
struct NativeCrimboContactReceipt: Equatable, Sendable {
  static let radioRangeMeters = 8000.0
  let metric: NativeCrimboMetricProjection
  let senderDevice: UUID
  let receiverDevice: UUID
  let nonce: UUID
  let manifest: NativeProviderManifest
  let continuous: Bool
  let trackingThroughout: Bool
  private let key: NativeCrimboContactSeed.Key
  private let crew: [Int]
  private let episode: UInt64?
  private let recoveredAt: Double?
  private let playerBus: NativeCrimboContactSeed.Bus
  private let sourceBus: NativeCrimboContactSeed.Bus

  private struct Query {
    let nonce: UUID
    let sender: UUID
    let receiver: UUID
    let recipient: ActorIdentity
    let manifest: NativeProviderManifest
    let epoch: UUID
    let frame: UInt64
    let time: Double
  }
  private struct Reply {
    let nonce: UUID
    let sender: UUID
    let receiver: UUID
    let transmitter: ActorIdentity
    let manifest: NativeProviderManifest
    let epoch: UUID
    let frame: UInt64
    let time: Double
  }
  let replyNonce: UUID

  private init(
    metric: NativeCrimboMetricProjection, seed: NativeCrimboContactSeed,
    query: Query, reply: Reply, continuous: Bool, tracking: Bool
  ) {
    self.metric = metric
    key = seed.key
    crew = seed.crew
    episode = seed.episode
    recoveredAt = seed.recoveredAt
    playerBus = seed.playerBus
    sourceBus = seed.sourceBus
    manifest = reply.manifest
    senderDevice = query.sender
    receiverDevice = reply.sender
    nonce = query.nonce
    replyNonce = reply.nonce
    self.continuous = continuous
    trackingThroughout = tracking
  }

  private static func devices(_ seed: NativeCrimboContactSeed) -> (sender: UUID, receiver: UUID) {
    let sender = ScriptIdentity.uuid(
      NativeCrimboOriginalBirth.avionicsPolicy + ":player-radio:" + seed.key.birth.world.uuidString
        + ":"
        + seed.key.hull.uuidString)
    let actor = seed.key.birth.logical.firstActor
    let receiver = ScriptIdentity.uuid(
      NativeCrimboOriginalBirth.avionicsPolicy + ":original-radio:"
        + seed.key.birth.world.uuidString
        + ":\(actor.system.galaxy):\(actor.system.system):\(actor.visit):\(actor.entity)")
    return (sender, receiver)
  }

  /// Only the current native receiver, resolved from actual living crew/devices, can answer.
  private static func answer(_ query: Query, receiver: NativeCrimboContactSeed) -> Reply? {
    let devices = devices(receiver)
    guard !receiver.crew.isEmpty, query.recipient == receiver.key.actor,
      query.receiver == devices.receiver, query.sender == devices.sender,
      query.manifest == receiver.key.manifest, query.epoch == receiver.key.epoch,
      query.frame == receiver.frame, query.time == receiver.time
    else { return nil }
    return .init(
      nonce: query.nonce, sender: devices.receiver, receiver: query.sender,
      transmitter: receiver.key.actor, manifest: receiver.key.manifest,
      epoch: receiver.key.epoch, frame: receiver.frame, time: receiver.time)
  }

  /// Zero extra latency/cost is explicit v1 policy; both addressed native messages are sealed.
  fileprivate static func exchange(
    metric: NativeCrimboMetricProjection, start: NativeCrimboContactSeed,
    receiver: NativeCrimboContactSeed, incarnation: UUID, continuous: Bool, tracking: Bool
  ) -> Self? {
    guard start.key == receiver.key, start.crew == receiver.crew,
      metric.manifest == receiver.key.manifest, metric.world == receiver.key.birth.world,
      metric.player == receiver.key.player, metric.maximumRangeMeters <= radioRangeMeters
    else { return nil }
    let devices = devices(start)
    let nonce = ScriptIdentity.uuid(
      "native-crimbo-query-v1:" + start.key.epoch.uuidString + ":" + incarnation.uuidString
        + ":" + start.challenge.uuidString + ":\(metric.nextBaseline.frame):"
        + devices.sender.uuidString + ":" + devices.receiver.uuidString)
    let query = Query(
      nonce: nonce, sender: devices.sender, receiver: devices.receiver,
      recipient: start.key.actor, manifest: start.key.manifest,
      epoch: start.key.epoch, frame: metric.nextBaseline.frame,
      time: metric.nextBaseline.time)
    guard let reply = answer(query, receiver: receiver), reply.nonce == query.nonce,
      reply.sender == query.receiver, reply.receiver == query.sender,
      reply.transmitter == query.recipient, reply.manifest == query.manifest,
      reply.epoch == query.epoch, reply.frame == query.frame, reply.time == query.time,
      query.sender != query.receiver
    else { return nil }
    return .init(
      metric: metric, seed: receiver, query: query, reply: reply,
      continuous: continuous, tracking: tracking)
  }

  func isCurrent(in game: Game, after baseline: ProviderMissionBaseline? = nil) -> Bool {
    guard let actual = game.beginNativeCrimboContactStep(), actual.key == key,
      actual.crew == crew, actual.episode == episode, actual.recoveredAt == recoveredAt,
      actual.playerBus == playerBus, actual.sourceBus == sourceBus,
      let fact = game.nativeCrimboAttainedMotion, let motion = fact.contactMotion,
      motion.provesLineOfSight(in: game, fact: fact)
    else { return false }
    if trackingThroughout, motion.formation?.next != game.commander.savedCrimboState?.orbit {
      return false
    }
    return metric.isCurrent(
      in: game, expectedMetricRevision: NativeCrimboMetric.revision,
      after: baseline)
  }
}

extension Commander {
  fileprivate func nativeCrimboContactOwner() -> NativeCrimboContactSeed.Owner? {
    guard equipmentStateValid, electricalStateValid, empCustodyStateValid,
      let inventory = equipmentInventory, let player = flightSimulation.player,
      inventory.activeHull == hullInstanceID, inventory.owner == equipmentOwnerID,
      let playerShip = ShipCatalogue.ship(shipID), playerShip.catalogue.origin == .human,
      playerShip.game?.valid == true,
      let registry = savedCrimboState, registry.world == inventory.owner,
      registry.spawnSequence < flightSimulation.nextSpawn, registry.threat == nil,
      (try? registry.validate()) != nil,
      let birth = registry.members[6].originalBirth,
      birth.admittedAt <= flightSimulation.physicalTime,
      case .live(let logical) = registry.members[6].ownership,
      birth.logical == logical,
      let actor = registry.binding(of: registry.members[6], ledger: npcPersistence),
      npcPersistence.logicalIdentity(for: actor) == logical.firstActor,
      npcPersistence.terminalReason(for: logical.firstActor) == nil,
      let snapshot = npcPersistence.snapshot(for: logical.firstActor),
      snapshot.npc.resources?.profile == .nativeHull,
      let sourceShip = ShipCatalogue.ship(birth.catalogueShipID),
      sourceShip.catalogue.origin == .human,
      actor.system == player.system, actor.visit == player.visit
    else { return nil }
    let linked =
      savedEMPState?.records.values.filter {
        $0.custody.logical == logical.firstActor || $0.hull.binding == actor
      } ?? []
    guard linked.count <= 1, linked.first.map({ $0.source == logical.firstActor }) ?? true else {
      return nil
    }
    let crew: [Int]
    let episode: UInt64?
    let recoveredAt: Double?
    if let record = savedEMPState?.records[logical.firstActor] {
      guard nativeCrimboEMPJoin(member: registry.members[6], logical: logical, record: record),
        record.isRecovered, !record.terminal, record.savedOrdinaryTerminal == nil,
        record.crewTotal == birth.crewCount, record.crewAboard > 0,
        snapshot.npc.resources?.electrical != nil
      else { return nil }
      crew = record.aboardOrdinals
      episode = record.currentCrewDisableIncident.id
      recoveredAt = record.savedRecoveredAt
    } else {
      guard npcPersistence.empTransfers[logical.firstActor] == nil else { return nil }
      crew = Array(0..<birth.crewCount)
      episode = nil
      recoveredAt = nil
    }
    let exposedHull =
      savedEMPState?.records.values.contains { record in
        record.weapon.location?.hullInstanceID == inventory.activeHull
          || record.disableEpisodes.contains {
            $0.weapon.location?.hullInstanceID == inventory.activeHull
          }
      } == true
    guard
      savedPlayerElectrical != nil
        || (!exposedHull
          && !(savedEMPCharge?.hull == inventory.activeHull
            && savedEMPCharge?.phase == .released))
    else { return nil }
    let time = flightSimulation.physicalTime
    let sourceBus = snapshot.npc.resources?.electrical
    guard !crew.isEmpty,
      let playerWitness = Self.nativeCrimboBusWitness(savedPlayerElectrical, at: time),
      let sourceWitness = Self.nativeCrimboBusWitness(sourceBus, at: time)
    else { return nil }
    return .init(
      registry: registry, birth: birth, actor: actor, player: player,
      hull: inventory.activeHull, inventoryRevision: inventory.revision,
      crew: crew, episode: episode, recoveredAt: recoveredAt,
      playerBus: playerWitness, sourceBus: sourceWitness, time: time)
  }

  private static func nativeCrimboBusWitness(
    _ bus: ElectricalReserve?, at time: Double
  ) -> NativeCrimboContactSeed.Bus? {
    // Only this already-authenticated untouched hull/birth branch can issue the baseline case.
    guard let bus else { return .unmaterializedHealthy }
    guard bus.valid, bus.remaining > 0, bus.disabledAt == nil, bus.physicalTime == time else {
      return nil
    }
    return .materialized(bus)
  }

}

extension Game {
  func beginNativeCrimboContactStep() -> NativeCrimboContactSeed? {
    guard nativeCrimboLifecycleAvailable, !paused, !docked, screen != .gameOver,
      energy.isFinite, energy > 0, pendingNativeStationDock == nil,
      ![
        Screen.help, .gallery, .library, .navigation, .mission, .handoff, .rumour,
        .showroom, .secret, .title, .demo,
      ].contains(screen),
      let owner = commander.nativeCrimboContactOwner(), let context = gameplayContext(),
      context.system == NativeCrimboRegistry.system, context.player.identity == owner.player,
      context.physicalTime == owner.time,
      bodies.filter({ $0.physical?.identity == owner.actor }).count == 1,
      let body = bodies.first(where: { $0.physical?.identity == owner.actor }), body.energy > 0,
      !isEMPDisabled(body), body.missionInstanceID == nil, body.missionActorID == nil,
      body.scriptNPC == nil, body.physical?.npc?.resources?.electrical == owner.sourceBus.reserve,
      let actual = NPCPersistenceSnapshot.capture(
        body: body, pose: commander.flightSimulation.pose, physicalTime: owner.time,
        protection: context.protection),
      NativeCrimboRegistry.matches(actual, member: owner.registry.members[6])
    else { return nil }
    return .init(
      owner: owner, epoch: nativeStationRuntimeEpoch, frame: gameplayRevision,
      subject: actual.position, playerPose: commander.flightSimulation.pose)
  }

  func consumeNativeCrimboContactStep(
    seed: NativeCrimboContactSeed?, previous: NativeCrimboContactContinuity?
  ) -> (receipt: NativeCrimboContactReceipt?, next: NativeCrimboContactContinuity?) {
    guard let start = seed, let end = beginNativeCrimboContactStep(), start.key == end.key,
      start.frame < UInt64(Int64.max) - 1, end.frame == start.frame + 1,
      start.crew == end.crew, start.episode == end.episode, start.recoveredAt == end.recoveredAt,
      let fact = nativeCrimboAttainedMotion, let motion = fact.contactMotion,
      fact.subjectStart.position == start.subjectPosition, fact.playerStart == start.playerPose,
      abs(fact.startTime - start.time) <= 2 * max(fact.startTime.ulp, start.time.ulp),
      fact.endTime == end.time, fact.frame == end.frame,
      Self.nativeCrimboBusContinues(
        start.playerBus, end.playerBus, duration: end.time - start.time),
      Self.nativeCrimboBusContinues(
        start.sourceBus, end.sourceBus, duration: end.time - start.time),
      let metric = NativeCrimboMetricProjection.project(
        fact, in: self, expectedMetricRevision: NativeCrimboMetric.revision),
      metric.maximumRangeMeters <= NativeCrimboContactReceipt.radioRangeMeters,
      motion.provesLineOfSight(in: self, fact: fact)
    else { return (nil, nil) }
    if let previous, previous.key == end.key,
      previous.frame >= end.frame || previous.time >= end.time
    {
      return (nil, nil)
    }
    let continuous =
      previous.map {
        $0.key == start.key && $0.frame == start.frame && $0.time == start.time
      } == true
    let incarnation = previous.flatMap { continuous ? $0.incarnation : nil } ?? start.challenge
    let tracking =
      motion.formation.map {
        $0.next == commander.savedCrimboState?.orbit
          && $0.qualifies(fact, duration: metric.elapsedSeconds)
      } ?? false
    guard
      let receipt = NativeCrimboContactReceipt.exchange(
        metric: metric, start: start, receiver: end, incarnation: incarnation,
        continuous: continuous, tracking: tracking)
    else { return (nil, nil) }
    return (
      receipt, .init(key: end.key, frame: end.frame, time: end.time, incarnation: incarnation)
    )
  }

  private static func nativeCrimboBusContinues(
    _ start: NativeCrimboContactSeed.Bus, _ end: NativeCrimboContactSeed.Bus, duration: Double
  ) -> Bool {
    guard duration.isFinite, duration > 0, duration <= 0.100001 else { return false }
    switch (start, end) {
    case (.unmaterializedHealthy, .unmaterializedHealthy):
      // Distinct authenticated healthy baseline; no charge is created.
      return true
    case (.materialized(let a), .materialized(let b)):
      guard a.capacity == b.capacity, a.recharge == b.recharge,
        a.disabledAt == nil, b.disabledAt == nil
      else { return false }
      let expected = min(a.capacity, a.remaining + duration * a.recharge)
      return abs(expected - b.remaining) <= max(1, expected) * 1e-8
    default: return false  // Actual first materialization/EMP exposure breaks this interval.
    }
  }
}
