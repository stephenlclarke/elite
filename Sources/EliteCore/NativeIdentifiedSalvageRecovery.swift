import Foundation

/// Descriptive target facts; a selected serial never grants capture authority.
public struct NativeIdentifiedSalvageSelectionFacts: Sendable, Equatable {
  let logicalActor: UUID
  let original: UUID
  let fits: Bool
}

/// Only the native post-motion producer constructs an immutable pending capture.
final class NativeIdentifiedSalvagePending: Sendable {
  let capture: NativeIdentifiedSalvageCapture
  fileprivate init(_ capture: NativeIdentifiedSalvageCapture) { self.capture = capture }
}

extension NativeIdentifiedSalvage {
  // JSON object normalization may write integral doubles and signed zero differently.
  // Seal semantic JSON values so an equivalent strict cold save retains its witness.
  private static func witnessHash<T: Encodable>(_ value: T) throws -> String {
    let object = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(value), options: [.fragmentsAllowed])
    let bytes = try JSONSerialization.data(
      withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])
    return ScriptPackLibrary.hash(bytes)
  }

  private static func authorityBits(_ value: Double) -> UInt64 {
    value == 0 ? 0 : value.bitPattern
  }

  static func lossAuthority(_ loss: borrowing NativeIdentifiedSalvageLoss) throws -> UUID {
    let pod = try witnessHash(loss.escapePod)
    let marker = try witnessHash(loss.marker)
    let context = try witnessHash(loss.context)
    return ScriptIdentity.uuid(
      "identified-salvage-loss-authority-v1:\(loss.original):\(loss.operation):\(loss.kind.rawValue):\(loss.actor.system.galaxy):\(loss.actor.system.system):\(loss.actor.visit):\(loss.actor.entity):\(loss.carrier):\(loss.collector.system.galaxy):\(loss.collector.system.system):\(loss.collector.visit):\(loss.collector.entity):\(authorityBits(loss.energy)):\(pod):\(marker):\(context):\(authorityBits(loss.physicalTime)):\(loss.epoch)"
    )
  }

  static func captureAuthority(_ capture: borrowing NativeIdentifiedSalvageCapture) throws -> UUID {
    let equipment = try witnessHash(capture.equipment)
    let marker = try witnessHash(capture.marker)
    return ScriptIdentity.uuid(
      "identified-salvage-capture-v1:\(capture.operation):\(capture.original):\(capture.actor.system.galaxy):\(capture.actor.system.system):\(capture.actor.visit):\(capture.actor.entity):\(capture.collector.system.galaxy):\(capture.collector.system.system):\(capture.collector.visit):\(capture.collector.entity):\(capture.carrier):\(capture.inventoryRevision):\(equipment):\(marker):\(authorityBits(capture.capturePoint.x)):\(authorityBits(capture.capturePoint.y)):\(authorityBits(capture.capturePoint.z)):\(authorityBits(capture.relativeSpeed)):\(authorityBits(capture.startTime)):\(authorityBits(capture.physicalTime)):\(capture.epoch)"
    )
  }
}

extension Game {
  /// This closed query binds the actual native actor to the depot allocation and its retained fit.
  @inline(never)
  func identifiedSalvageAlias(_ body: borrowing SpaceBody) -> String? {
    guard body.missionInstanceID != nil, body.missionActorID != nil,
      body.hull == .cobra, body.position.finite, body.orientation.validRotation
    else { return nil }
    let currentBody = copy body
    let currentSystem = systemIdentity
    return withReadOnlyCommander { commander in
      commander.withReadOnlyScriptState { state in
        Self.identifiedSalvageAlias(
          currentBody, source: state.savedIdentifiedSalvageSource, instances: state.instances,
          system: currentSystem, commander: commander)
      }
    }
  }

  @inline(never)
  private static func identifiedSalvageAlias(
    _ body: borrowing SpaceBody, source: borrowing NativeIdentifiedSalvageSource?,
    instances: borrowing [UUID: ScriptInstance], system: SystemIdentity,
    commander: borrowing Commander
  ) -> String? {
    guard let bodyMission = body.missionInstanceID, let logical = body.missionActorID,
      body.hull == .cobra, body.position.finite, body.orientation.validRotation,
      let source = copy source,
      source.batch == NativeIdentifiedSalvage.batch, source.owner.valid,
      source.owner.world == commander.equipmentOwnerID,
      source.owner.system == SystemIdentity(galaxy: 0, system: 7),
      source.registration.valid, source.registration.station == source.owner,
      NativeIdentifiedSalvageSave.historicalDock(source.registration, commander: commander),
      commander.nativeStations?.mainStations.contains(source.owner) == true,
      source.id == NativeIdentifiedSalvage.sourceIdentity(source.owner),
      NativeIdentifiedSalvage.originalIdentitiesValid(source),
      let mission = instances[source.allocatedMission],
      mission.definition == NativeIdentifiedSalvage.stateID,
      mission.digest == NativeIdentifiedSalvage.digest,
      let state = mission.savedIdentifiedSalvage, state.source == source.id, state.definition.valid,
      state.permission.dock == source.registration,
      state.permission.operation
        == ScriptIdentity.uuid(
          "identified-salvage-permit-v1:\(source.id):\(mission.id)"),
      mission.contract?.group == NativeIdentifiedSalvage.stateID,
      state.permission.source == source.id, state.permission.mission == mission.id,
      bodyMission == mission.id,
      let actor = body.physical?.identity, actor.system == SystemIdentity(galaxy: 0, system: 185),
      actor.system == system, actor.entity > 1,
      actor.entity < commander.flightSimulation.nextActor,
      actor.visit == commander.flightSimulation.visit,
      body.physical?.population == .mission, body.physical?.npc?.role == .mission,
      body.physical?.ordnance == nil, body.physical?.rock == nil, body.physical?.salvage == nil,
      body.physical?.spawnIdentity?.producer == .mission,
      body.physical?.spawnIdentity?.system == actor.system,
      body.physical?.spawnIdentity?.visit == actor.visit,
      let sequence = body.physical?.spawnIdentity?.sequence,
      sequence > 0, sequence < commander.flightSimulation.nextSpawn,
      body.energy.isFinite, body.energy > 0, !body.hostile,
      body.physical?.velocity.finite == true, body.physical?.angularVelocity.finite == true,
      body.physical?.payload == nil, body.physical?.empCrewPod == nil,
      body.physical?.empSource == nil, body.blackjackIdentity == nil,
      let encounter = mission.ownedEncounters[NativeIdentifiedSalvage.encounterID],
      encounter.admitted, encounter.galaxy == 0, encounter.system == 185
    else { return nil }
    for alias in ["pell-cradle"] + NativeIdentifiedSalvage.aliases {
      guard
        logical
          == NativeIdentifiedSalvage.actorIdentity(
            mission: mission.id, digest: mission.digest, alias: alias),
        let retained = encounter.actors[alias], retained.identity == logical,
        retained.presence == .present, retained.body.id == body.id, retained.body.hull == .cobra,
        retained.body.physical?.identity == actor,
        retained.body.scriptNPC?.fit == body.scriptNPC?.fit,
        let npc = body.scriptNPC, npc.fit.valid,
        NativeIdentifiedSalvage.npcValid(npc.fit.definition, package: alias != "pell-cradle"),
        npc.fit.models == [
          npc.fit.definition.model: alias == "pell-cradle"
            ? NativeIdentifiedSalvage.cradleGeometry : NativeIdentifiedSalvage.packageGeometry
        ],
        !NativeIdentifiedSalvage.consumed(logical, commander: commander)
      else { continue }
      if let ordinal = NativeIdentifiedSalvage.aliases.firstIndex(of: alias) {
        let originalID = source.originals[ordinal].id
        guard source.originals[ordinal].custody == .cradle else { return nil }
        if state.captures.contains(where: { $0.original == originalID }) { return nil }
        if state.losses.contains(where: { $0.original == originalID }) { return nil }
        if state.reception?.originals.contains(originalID) == true { return nil }
      }
      return alias
    }
    return nil
  }

  /// The physical frame, work guidance and scoop producer use the same assembled native mesh.
  func identifiedSalvageCollision(_ body: borrowing SpaceBody) -> (mesh: Mesh, mass: Double)? {
    guard let alias = identifiedSalvageAlias(body), let mesh = scriptNPCMesh(body) else {
      return nil
    }
    return (mesh, AsteroidImpactPolicy.massKg(hull: alias == "pell-cradle" ? .cobra : .cargo))
  }

  func identifiedSalvageCompatibleMesh(
    _ body: borrowing SpaceBody, context: EncounterContext? = nil
  ) -> Mesh? {
    guard NativeIdentifiedSalvage.marker(body, commander: commander) else {
      return originalRescueCompatibleMesh(body, context: context)
    }
    return identifiedSalvageCollision(body)?.mesh
  }

  func identifiedSalvageFacts(_ body: borrowing SpaceBody, context: EncounterContext)
    -> NativeIdentifiedSalvageSelectionFacts?
  {
    guard let alias = identifiedSalvageAlias(body),
      let index = NativeIdentifiedSalvage.aliases.firstIndex(of: alias),
      let state = identifiedSalvageState,
      let source = commander.scriptState.savedIdentifiedSalvageSource,
      commander.scriptState.instances[state.permission.mission]?.outcome == .active,
      state.losses.isEmpty, state.reception == nil,
      state.permission.carrier == commander.hullInstanceID,
      body.physical?.identity.system == context.system,
      body.physical?.identity.visit == context.visit,
      let logical = body.missionActorID
    else { return nil }
    return .init(
      logicalActor: logical, original: source.originals[index].id,
      fits: commander.cargoTonnes <= commander.standardCargoCapacity)
  }

  func identifiedSalvageMetadata(_ body: borrowing SpaceBody, context: EncounterContext)
    -> SalvageTargetMetadata?
  {
    guard identifiedSalvageFacts(body, context: context) != nil,
      let mesh = identifiedSalvageCollision(body)?.mesh
    else { return nil }
    return .init(
      category: .cargo, ownership: .missionProtected, claimant: nil,
      wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: mesh.vertices.map(\.length).max() ?? 0),
      workSurfaces: [])
  }

  var hasIdentifiedSalvageTools: Bool {
    guard commander.targetingTier != nil,
      commander.fittedEquipment(at: .targetingCore) != nil,
      commander.fittedEquipment(at: .targetingSalvage) != nil,
      commander.fittedEquipment(at: .utility(.fuelScoops)) != nil
    else { return false }
    return true
  }

  /// Same aperture and relative-motion limits as the existing native recovery provider.
  private func identifiedSalvageApproach(_ body: SpaceBody) -> Double? {
    guard let mesh = identifiedSalvageCollision(body)?.mesh else { return nil }
    let radius = mesh.vertices.map(\.length).max() ?? .infinity
    let offset = body.position - Vector3(0, -45, 55)
    guard radius.isFinite, radius > 0, radius <= 16, offset.finite,
      body.position.z > 0, body.position.y < 0, body.position.length < 85,
      abs(offset.x) + radius <= 16, abs(offset.y) + radius <= 16,
      abs(offset.z) + radius <= 16, let physical = body.physical,
      physical.velocity.finite, physical.angularVelocity.finite, flightWorldVelocity.finite
    else { return nil }
    let omega: Double
    if workGuidance != nil || workBraking != nil {
      omega = lastAppliedWorkMotion?.worldAngularVelocity.length ?? 0
    } else {
      omega = abs(pitch) + abs(yaw) + abs(roll)
    }
    let speed =
      (physical.velocity - flightWorldVelocity).length
      + omega * Vector3(0, -45, 55).length + physical.angularVelocity.length * radius
    guard speed.isFinite, speed <= ScoopApproachController.maximumRelativeSpeed else { return nil }
    return speed
  }

  @inline(never)
  private func identifiedSalvageMarker(
    _ body: borrowing SpaceBody, mission: borrowing ScriptInstance, alias: String
  ) -> [ScriptOwnedActor]? {
    guard var marker = mission.ownedEncounters[NativeIdentifiedSalvage.encounterID]?.actors[alias]
    else { return nil }
    marker.body = copy body
    return [marker]
  }

  fileprivate func identifiedSalvageSeal(startTime: Double) -> NativeIdentifiedSalvagePending? {
    guard !docked, !paused, screen.isFlight, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil, hasIdentifiedSalvageTools,
      let state = identifiedSalvageState, let context = gameplayContext(),
      let purchase = try? commander.purchaseSnapshot(),
      purchase.activeHull == state.permission.carrier,
      let core = commander.fittedEquipment(at: .targetingCore),
      let module = commander.fittedEquipment(at: .targetingSalvage),
      let scoops = commander.fittedEquipment(at: .utility(.fuelScoops)),
      let coreItem = purchase.items.first(where: { $0.id == core.id }),
      let moduleItem = purchase.items.first(where: { $0.id == module.id }),
      let scoopItem = purchase.items.first(where: { $0.id == scoops.id }),
      let mission = commander.scriptState.instances[state.permission.mission]
    else { return nil }
    for bodyIndex in bodies.indices {
      guard let facts = identifiedSalvageFacts(bodies[bodyIndex], context: context), facts.fits,
        let speed = identifiedSalvageApproach(bodies[bodyIndex]),
        let actor = bodies[bodyIndex].physical?.identity,
        let alias = NativeIdentifiedSalvage.aliases.first(where: {
          NativeIdentifiedSalvage.actorIdentity(
            mission: mission.id, digest: mission.digest, alias: $0)
            == facts.logicalActor
        }), let marker = identifiedSalvageMarker(bodies[bodyIndex], mission: mission, alias: alias)
      else { continue }
      if let work = workGuidance {
        guard work.parent == actor, work.mode == .autoScoop(.salvage),
          lastAppliedWorkMotion?.end == commander.flightSimulation.pose
        else { continue }
      }
      let operation = ScriptIdentity.uuid(
        "identified-salvage-pickup-v1:\(state.permission.operation):\(facts.original)")
      let provisional = NativeIdentifiedSalvageCapture(
        original: facts.original, operation: operation, authority: operation,
        logicalActor: facts.logicalActor, actor: actor, collector: context.player.identity,
        carrier: purchase.activeHull, inventoryRevision: purchase.revision,
        equipment: [coreItem, moduleItem, scoopItem], marker: marker,
        capturePoint: bodies[bodyIndex].position, relativeSpeed: speed, startTime: startTime,
        physicalTime: context.physicalTime, epoch: nativeStationRuntimeEpoch)
      guard let authority = try? NativeIdentifiedSalvage.captureAuthority(provisional) else {
        return nil
      }
      return .init(
        .init(
          original: provisional.original, operation: provisional.operation, authority: authority,
          logicalActor: provisional.logicalActor, actor: provisional.actor,
          collector: provisional.collector, carrier: provisional.carrier,
          inventoryRevision: provisional.inventoryRevision, equipment: provisional.equipment,
          marker: provisional.marker, capturePoint: provisional.capturePoint,
          relativeSpeed: provisional.relativeSpeed, startTime: provisional.startTime,
          physicalTime: provisional.physicalTime, epoch: provisional.epoch))
    }
    return nil
  }

  /// Called only with a private producer-minted pending value, including explicit save retry.
  @inline(never)
  @discardableResult
  mutating func retryIdentifiedSalvageCapture() throws -> Bool {
    guard let pending = nativeIdentifiedSalvagePending else { return false }
    let capture = pending.capture
    guard var state = identifiedSalvageState,
      var mission = commander.scriptState.instances[state.permission.mission],
      var source = commander.scriptState.savedIdentifiedSalvageSource,
      let originalIndex = source.originals.firstIndex(where: { $0.id == capture.original }),
      source.originals[originalIndex].custody == .cradle,
      mission.outcome == .active, state.losses.isEmpty, state.reception == nil,
      !state.captures.contains(where: { $0.original == capture.original }),
      commander.flightSimulation.player == capture.collector,
      commander.hullInstanceID == capture.carrier,
      commander.equipmentInventory?.revision == capture.inventoryRevision,
      nativeStationRuntimeEpoch == capture.epoch,
      let index = bodies.firstIndex(where: { $0.physical?.identity == capture.actor }),
      capture.marker.count == 1,
      identifiedSalvageAlias(bodies[index]) == capture.marker[0].alias
    else {
      nativeIdentifiedSalvagePending = nil
      return false
    }
    state.captures.append(capture)
    source.originals[originalIndex].custody = .held(
      capture: capture.operation, carrier: capture.carrier)
    commander.scriptState.savedIdentifiedSalvageSource = source
    mission.savedIdentifiedSalvage = state
    if let index = NativeIdentifiedSalvage.aliases.firstIndex(of: capture.marker[0].alias) {
      mission.milestones.insert(index + 1)
    }
    commander.scriptState.instances[mission.id] = mission
    let body = bodies[index]
    recordScriptActorRemoval(body, destroyed: false)
    workTargetCollected(body)
    bodies.remove(at: index)
    nativeIdentifiedSalvagePending = nil
    return true
  }
}

extension GameRuntime {
  /// Exactly one actual post-motion ingress. No renderer or caller-provided recovery Boolean.
  func commitIdentifiedSalvageCapture(startTime: Double, startPlayer: ActorIdentity?) {
    guard game.identifiedSalvageState != nil, !game.identifiedSalvageLossIsPending,
      startPlayer == game.commander.flightSimulation.player
    else { return }
    let interval = game.commander.flightSimulation.physicalTime - startTime
    guard interval > 0, interval <= 0.1 + 1e-9 else { return }
    if game.nativeIdentifiedSalvagePending == nil {
      game.nativeIdentifiedSalvagePending = game.identifiedSalvageSeal(startTime: startTime)
    }
    guard game.nativeIdentifiedSalvagePending != nil, let publish = scriptPublisher() else {
      return
    }
    var candidate = game
    do {
      guard try candidate.retryIdentifiedSalvageCapture() else {
        game.nativeIdentifiedSalvagePending = nil
        return
      }
      try publish(&candidate)
      game = candidate
      game.notify(
        "PELL ORIGINAL RECOVERED - \(game.identifiedSalvageState?.held.count ?? 0)/2 HELD; RETURN TO AVENOR"
      )
    } catch { game.notify("PELL PROPERTY NOT SAVED - SAVE TO RETRY THE SAME PICKUP") }
  }
}

extension Game {
  var identifiedSalvageLossIsPending: Bool {
    guard let state = identifiedSalvageState,
      let source = commander.scriptState.savedIdentifiedSalvageSource,
      let mission = commander.scriptState.instances[state.permission.mission]
    else { return false }
    if screen == .gameOver, energy.isFinite, energy <= 0, !state.held.isEmpty { return true }
    for (index, original) in source.originals.enumerated() {
      guard NativeIdentifiedSalvage.aliases.indices.contains(index),
        !state.losses.contains(where: { $0.original == original.id }),
        let actor = mission.ownedEncounters[NativeIdentifiedSalvage.encounterID]?.actors[
          NativeIdentifiedSalvage.aliases[index]], actor.presence == .destroyed
      else { continue }
      return true
    }
    return false
  }

  @discardableResult
  mutating func recordIdentifiedSalvageLossIfNeeded() throws -> Bool {
    guard identifiedSalvageLossIsPending,
      var state = identifiedSalvageState,
      let source = commander.scriptState.savedIdentifiedSalvageSource,
      let mission = commander.scriptState.instances[state.permission.mission],
      let player = commander.flightSimulation.player
    else { return false }
    let cause = scriptEventContext(mission)
    let held = Set(state.held)
    let fatal = screen == .gameOver && energy.isFinite && energy <= 0
    for (index, original) in source.originals.enumerated() {
      guard NativeIdentifiedSalvage.aliases.indices.contains(index),
        !state.losses.contains(where: { $0.original == original.id })
      else { continue }
      let kind: NativeIdentifiedSalvageLossKind
      let actor: ActorIdentity
      let witness: [ScriptOwnedActor]
      if let marker = mission.ownedEncounters[NativeIdentifiedSalvage.encounterID]?.actors[
        NativeIdentifiedSalvage.aliases[index]], marker.presence == .destroyed,
        marker.body.energy <= 0, let identity = marker.body.physical?.identity
      {
        kind = .destroyed
        actor = identity
        witness = [marker]
      } else if fatal, held.contains(original.id),
        let capture = state.captures.first(where: { $0.original == original.id })
      {
        kind = .hull
        actor = capture.actor
        witness = []
      } else {
        continue
      }
      var loss = NativeIdentifiedSalvageLoss(
        original: original.id,
        operation: ScriptIdentity.uuid(
          "identified-salvage-loss-v1:\(state.permission.operation):\(original.id):\(kind.rawValue)"
        ),
        authority: state.permission.operation,
        kind: kind, actor: actor, carrier: state.permission.carrier, collector: player,
        energy: kind == .hull ? energy : 0, escapePod: nil, marker: witness, context: cause,
        physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
      loss.authority = try NativeIdentifiedSalvage.lossAuthority(loss)
      state.losses.append(loss)
    }
    guard state.losses.count > (mission.savedIdentifiedSalvage?.losses.count ?? 0) else {
      return false
    }
    try retainIdentifiedSalvageLoss(state)
    nativeIdentifiedSalvagePending = nil
    return true
  }

  func identifiedSalvageEscapePod() -> EquipmentPurchaseItem? {
    guard let state = identifiedSalvageState, !state.held.isEmpty,
      let purchase = try? commander.purchaseSnapshot()
    else { return nil }
    return purchase.items.first { $0.node.key == "Escape Pod" && $0.location != nil }
  }

  /// Invoked inside the actual successful Escape Pod candidate after native pod consumption.
  mutating func loseIdentifiedSalvageOnEscape(pod: EquipmentPurchaseItem?) throws {
    guard var state = identifiedSalvageState, !state.held.isEmpty else { return }
    guard let pod, pod.node.key == "Escape Pod", !docked,
      commander.equipmentInventory?.items.contains(where: { $0.id == pod.id }) == false,
      let player = commander.flightSimulation.player,
      let mission = commander.scriptState.instances[state.permission.mission],
      commander.hullInstanceID == state.permission.carrier
    else { throw SaveError.invalidCommander }
    let context = scriptEventContext(mission)
    for original in state.held {
      guard let capture = state.captures.first(where: { $0.original == original }) else {
        throw SaveError.invalidCommander
      }
      var loss = NativeIdentifiedSalvageLoss(
        original: original,
        operation: ScriptIdentity.uuid(
          "identified-salvage-loss-v1:\(state.permission.operation):\(original):escape"),
        authority: state.permission.operation,
        kind: .escape, actor: capture.actor, carrier: state.permission.carrier, collector: player,
        energy: energy, escapePod: pod, marker: [], context: context,
        physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
      loss.authority = try NativeIdentifiedSalvage.lossAuthority(loss)
      state.losses.append(loss)
    }
    try retainIdentifiedSalvageLoss(state)
    nativeIdentifiedSalvagePending = nil
  }

  private mutating func retainIdentifiedSalvageLoss(_ state: NativeIdentifiedSalvageState) throws {
    guard var mission = commander.scriptState.instances[state.permission.mission],
      var source = commander.scriptState.savedIdentifiedSalvageSource
    else { throw SaveError.invalidCommander }
    for loss in state.losses {
      guard let index = source.originals.firstIndex(where: { $0.id == loss.original }) else {
        throw SaveError.invalidCommander
      }
      source.originals[index].custody = .lost(loss.operation)
    }
    commander.scriptState.savedIdentifiedSalvageSource = source
    if mission.outcome == .active {
      try finishIdentifiedSalvageMission(state, outcome: .failed)
    } else {
      mission.savedIdentifiedSalvage = state
      mission.payloads = NativeIdentifiedSalvage.payloads(
        state, outcome: mission.outcome, source: source)
      commander.scriptState.instances[mission.id] = mission
    }
  }
}

extension GameRuntime {
  func commitIdentifiedSalvageLoss() {
    guard game.identifiedSalvageLossIsPending else { return }
    if game.screen == .gameOver, game.energy < 0 { return }
    guard let publish = scriptPublisher() else { return }
    var candidate = game
    do {
      guard try candidate.recordIdentifiedSalvageLossIfNeeded() else { return }
      try publish(&candidate)
      game = candidate
    } catch { game.notify("PELL LOSS NOT SAVED - ORIGINAL CONDITION RETAINED FOR RETRY") }
  }
}
