import Foundation

/// Descriptive target facts; a selected serial never grants capture authority.
public struct WayfarerRecordRecoverySelectionFacts: Sendable, Equatable {
  let logicalActor: UUID
  let original: UUID
  let fits: Bool
}

/// Only the native post-motion producer constructs an immutable pending capture.
final class WayfarerRecordRecoveryPending: Sendable {
  let capture: WayfarerRecordRecoveryCapture
  fileprivate init(_ capture: WayfarerRecordRecoveryCapture) { self.capture = capture }
}

extension WayfarerRecordRecovery {
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

  static func lossAuthority(_ loss: borrowing WayfarerRecordRecoveryLoss) throws -> UUID {
    let pod = try witnessHash(loss.escapePod)
    let marker = try witnessHash(loss.marker)
    let context = try witnessHash(loss.context)
    return ScriptIdentity.uuid(
      "record-recovery-loss-authority-v1:\(loss.original):\(loss.operation):\(loss.kind.rawValue):\(loss.actor.system.galaxy):\(loss.actor.system.system):\(loss.actor.visit):\(loss.actor.entity):\(loss.carrier):\(loss.collector.system.galaxy):\(loss.collector.system.system):\(loss.collector.visit):\(loss.collector.entity):\(authorityBits(loss.energy)):\(pod):\(marker):\(context):\(authorityBits(loss.physicalTime)):\(loss.epoch)"
    )
  }

  static func captureAuthority(_ capture: borrowing WayfarerRecordRecoveryCapture) throws -> UUID {
    let equipment = try witnessHash(capture.equipment)
    let marker = try witnessHash(capture.marker)
    return ScriptIdentity.uuid(
      "record-recovery-capture-v1:\(capture.identification):\(capture.operation):\(capture.original):\(capture.actor.system.galaxy):\(capture.actor.system.system):\(capture.actor.visit):\(capture.actor.entity):\(capture.collector.system.galaxy):\(capture.collector.system.system):\(capture.collector.visit):\(capture.collector.entity):\(capture.carrier):\(capture.inventoryRevision):\(equipment):\(marker):\(authorityBits(capture.capturePoint.x)):\(authorityBits(capture.capturePoint.y)):\(authorityBits(capture.capturePoint.z)):\(authorityBits(capture.relativeSpeed)):\(authorityBits(capture.startTime)):\(authorityBits(capture.physicalTime)):\(capture.epoch)"
    )
  }
}

extension Game {
  /// This closed query binds the actual native actor to the depot allocation and its retained fit.
  @inline(never)
  func recordRecoveryAlias(_ body: borrowing SpaceBody) -> String? {
    guard body.missionInstanceID != nil, body.missionActorID != nil,
      body.hull == .cobra, body.position.finite, body.orientation.validRotation
    else { return nil }
    let currentBody = copy body
    let retained = withReadOnlyScriptState { ($0.savedRecordRecoverySource, $0.instances) }
    let currentSystem = systemIdentity
    return withReadOnlyCommander { commander in
      Self.recordRecoveryAlias(
        currentBody, source: retained.0, instances: retained.1, system: currentSystem,
        commander: commander)
    }
  }

  @inline(never)
  private static func recordRecoveryAlias(
    _ body: borrowing SpaceBody, source: WayfarerRecordRecoverySource?,
    instances: borrowing [UUID: ScriptInstance], system: SystemIdentity,
    commander: borrowing Commander
  ) -> String? {
    guard let bodyMission = body.missionInstanceID, let logical = body.missionActorID,
      body.hull == .cobra, body.position.finite, body.orientation.validRotation,
      let source = source,
      source.batch == WayfarerRecordRecovery.batch, source.owner.valid,
      source.owner.world == commander.equipmentOwnerID,
      source.owner.system == SystemIdentity(galaxy: 0, system: 85),
      source.registration.valid, source.registration.station == source.owner,
      WayfarerRecordRecoverySave.historicalDock(source.registration, commander: commander),
      commander.nativeStations?.mainStations.contains(source.owner) == true,
      source.id == WayfarerRecordRecovery.sourceIdentity(source.owner),
      WayfarerRecordRecovery.originalIdentitiesValid(source),
      let mission = instances[source.allocatedMission],
      mission.definition == WayfarerRecordRecovery.stateID,
      mission.digest == WayfarerRecordRecovery.digest,
      let state = mission.savedRecordRecovery, state.source == source.id, state.definition.valid,
      state.permission.dock == source.registration,
      state.permission.operation
        == ScriptIdentity.uuid(
          "record-recovery-permit-v1:\(source.id):\(mission.id)"),
      mission.contract?.group == WayfarerRecordRecovery.stateID,
      state.permission.source == source.id, state.permission.mission == mission.id,
      bodyMission == mission.id,
      let actor = body.physical?.identity, actor.system == SystemIdentity(galaxy: 0, system: 241),
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
      let encounter = mission.ownedEncounters[WayfarerRecordRecovery.encounterID],
      encounter.admitted, encounter.galaxy == 0, encounter.system == 241
    else { return nil }
    for alias in ["w05-cradle"] + WayfarerRecordRecovery.aliases {
      guard
        logical
          == WayfarerRecordRecovery.actorIdentity(
            mission: mission.id, digest: mission.digest, alias: alias),
        let retained = encounter.actors[alias], retained.identity == logical,
        retained.presence == .present, retained.body.id == body.id, retained.body.hull == .cobra,
        retained.body.physical?.identity == actor,
        retained.body.scriptNPC?.fit == body.scriptNPC?.fit,
        let npc = body.scriptNPC, npc.fit.valid,
        WayfarerRecordRecovery.npcValid(npc.fit.definition, package: alias != "w05-cradle"),
        npc.fit.models == [
          npc.fit.definition.model: alias == "w05-cradle"
            ? WayfarerRecordRecovery.cradleGeometry : WayfarerRecordRecovery.packageGeometry
        ],
        !WayfarerRecordRecovery.consumed(logical, commander: commander)
      else { continue }
      if let ordinal = WayfarerRecordRecovery.aliases.firstIndex(of: alias) {
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
  func recordRecoveryCollision(_ body: borrowing SpaceBody) -> (mesh: Mesh, mass: Double)? {
    guard let alias = recordRecoveryAlias(body), let mesh = scriptNPCMesh(body) else {
      return nil
    }
    return (mesh, AsteroidImpactPolicy.massKg(hull: alias == "w05-cradle" ? .cobra : .cargo))
  }

  func recordRecoveryCompatibleMesh(
    _ body: borrowing SpaceBody, context: EncounterContext? = nil
  ) -> Mesh? {
    if let original = inductionCrewLogCompatibleMesh(body) { return original }
    guard WayfarerRecordRecovery.marker(body, commander: commander) else {
      return identifiedSalvageCompatibleMesh(body, context: context)
    }
    return recordRecoveryCollision(body)?.mesh
  }

  func recordRecoveryFacts(_ body: borrowing SpaceBody, context: EncounterContext)
    -> WayfarerRecordRecoverySelectionFacts?
  {
    guard let alias = recordRecoveryAlias(body),
      let index = WayfarerRecordRecovery.aliases.firstIndex(of: alias)
    else { return nil }
    let currentBody = copy body
    return withReadOnlyCommander { commander in
      recordRecoveryFacts(currentBody, context: context, index: index, commander: commander)
    }
  }

  @inline(never)
  private func recordRecoveryFacts(
    _ body: borrowing SpaceBody, context: EncounterContext, index: Int,
    commander: borrowing Commander
  ) -> WayfarerRecordRecoverySelectionFacts? {
    guard let state = recordRecoveryState,
      let source = commander.scriptState.savedRecordRecoverySource,
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

  func recordRecoveryMetadata(_ body: borrowing SpaceBody, context: EncounterContext)
    -> SalvageTargetMetadata?
  {
    guard recordRecoveryFacts(body, context: context) != nil,
      let mesh = recordRecoveryCollision(body)?.mesh
    else { return nil }
    return .init(
      category: .cargo, ownership: .missionProtected, claimant: nil,
      wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: mesh.vertices.map(\.length).max() ?? 0),
      workSurfaces: [])
  }

  var hasRecordRecoveryTools: Bool {
    guard commander.targetingTier != nil,
      commander.fittedEquipment(at: .targetingCore) != nil,
      commander.fittedEquipment(at: .targetingSalvage) != nil,
      commander.fittedEquipment(at: .utility(.fuelScoops)) != nil
    else { return false }
    return true
  }

  /// Same aperture and relative-motion limits as the existing native recovery provider.
  private func recordRecoveryApproach(_ body: SpaceBody) -> Double? {
    guard let mesh = recordRecoveryCollision(body)?.mesh else { return nil }
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
  private func recordRecoveryMarker(
    _ body: borrowing SpaceBody, mission: borrowing ScriptInstance, alias: String
  ) -> [ScriptOwnedActor]? {
    guard var marker = mission.ownedEncounters[WayfarerRecordRecovery.encounterID]?.actors[alias]
    else { return nil }
    marker.body = copy body
    return [marker]
  }

  fileprivate func recordRecoverySeal(
    startTime: Double, committedIdentification: UUID
  ) -> WayfarerRecordRecoveryPending? {
    guard !docked, !paused, screen.isFlight, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil, hasRecordRecoveryTools,
      let state = recordRecoveryState, let identification = state.identification,
      identification.operation == committedIdentification,
      let identifiedAt = identification.observations.last?.physicalTime,
      startTime >= identifiedAt, commander.flightSimulation.physicalTime > identifiedAt,
      let context = gameplayContext(),
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
      guard let facts = recordRecoveryFacts(bodies[bodyIndex], context: context), facts.fits,
        let speed = recordRecoveryApproach(bodies[bodyIndex]),
        let actor = bodies[bodyIndex].physical?.identity,
        let alias = WayfarerRecordRecovery.aliases.first(where: {
          WayfarerRecordRecovery.actorIdentity(
            mission: mission.id, digest: mission.digest, alias: $0)
            == facts.logicalActor
        }), let marker = recordRecoveryMarker(bodies[bodyIndex], mission: mission, alias: alias)
      else { continue }
      if let work = workGuidance {
        guard work.parent == actor, work.mode == .autoScoop(.salvage),
          lastAppliedWorkMotion?.end == commander.flightSimulation.pose
        else { continue }
      }
      let operation = ScriptIdentity.uuid(
        "record-recovery-pickup-v1:\(state.permission.operation):\(facts.original)")
      let provisional = WayfarerRecordRecoveryCapture(
        identification: committedIdentification,
        original: facts.original, operation: operation, authority: operation,
        logicalActor: facts.logicalActor, actor: actor, collector: context.player.identity,
        carrier: purchase.activeHull, inventoryRevision: purchase.revision,
        equipment: [coreItem, moduleItem, scoopItem], marker: marker,
        capturePoint: bodies[bodyIndex].position, relativeSpeed: speed, startTime: startTime,
        physicalTime: context.physicalTime, epoch: nativeStationRuntimeEpoch)
      guard let authority = try? WayfarerRecordRecovery.captureAuthority(provisional) else {
        return nil
      }
      return .init(
        .init(
          identification: provisional.identification,
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
  mutating func retryRecordRecoveryCapture() throws -> Bool {
    guard let pending = nativeRecordRecoveryPending else { return false }
    let capture = pending.capture
    guard var state = recordRecoveryState,
      state.identification?.operation == capture.identification,
      var mission = commander.scriptState.instances[state.permission.mission],
      var source = commander.scriptState.savedRecordRecoverySource,
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
      recordRecoveryAlias(bodies[index]) == capture.marker[0].alias
    else {
      nativeRecordRecoveryPending = nil
      return false
    }
    state.captures.append(capture)
    source.originals[originalIndex].custody = .held(
      capture: capture.operation, carrier: capture.carrier)
    commander.scriptState.savedRecordRecoverySource = source
    mission.savedRecordRecovery = state
    if let index = WayfarerRecordRecovery.aliases.firstIndex(of: capture.marker[0].alias) {
      mission.milestones.insert(index + 2)
    }
    commander.scriptState.instances[mission.id] = mission
    let body = bodies[index]
    recordScriptActorRemoval(body, destroyed: false)
    workTargetCollected(body)
    bodies.remove(at: index)
    nativeRecordRecoveryPending = nil
    return true
  }
}

extension GameRuntime {
  /// Exactly one actual post-motion ingress. No renderer or caller-provided recovery Boolean.
  func commitRecordRecoveryCapture(
    startTime: Double, startPlayer: ActorIdentity?, committedIdentification: UUID?
  ) {
    guard let committedIdentification else { return }
    guard game.recordRecoveryState != nil, !game.recordRecoveryLossIsPending,
      startPlayer == game.commander.flightSimulation.player
    else { return }
    let interval = game.commander.flightSimulation.physicalTime - startTime
    guard interval > 0, interval <= 0.1 + 1e-9 else { return }
    if game.nativeRecordRecoveryPending == nil {
      game.nativeRecordRecoveryPending = game.recordRecoverySeal(
        startTime: startTime, committedIdentification: committedIdentification)
    }
    guard game.nativeRecordRecoveryPending != nil, let publish = scriptPublisher() else {
      return
    }
    var candidate = game
    do {
      guard try candidate.retryRecordRecoveryCapture() else {
        game.nativeRecordRecoveryPending = nil
        return
      }
      try publish(&candidate)
      game = candidate
      game.notify(
        "SENN ORIGINAL RECOVERED - \(game.recordRecoveryState?.held.count ?? 0)/1 HELD; RETURN TO CEDAMAR"
      )
    } catch { game.notify("SENN PROPERTY NOT SAVED - SAVE TO RETRY THE SAME PICKUP") }
  }
}

extension Game {
  var recordRecoveryLossIsPending: Bool {
    guard let state = recordRecoveryState,
      let source = commander.scriptState.savedRecordRecoverySource,
      let mission = commander.scriptState.instances[state.permission.mission]
    else { return false }
    if screen == .gameOver, energy.isFinite, energy <= 0, !state.held.isEmpty { return true }
    for (index, original) in source.originals.enumerated() {
      guard WayfarerRecordRecovery.aliases.indices.contains(index),
        !state.losses.contains(where: { $0.original == original.id }),
        let actor = mission.ownedEncounters[WayfarerRecordRecovery.encounterID]?.actors[
          WayfarerRecordRecovery.aliases[index]], actor.presence == .destroyed
      else { continue }
      return true
    }
    return false
  }

  @discardableResult
  mutating func recordRecoveryLossIfNeeded() throws -> Bool {
    guard recordRecoveryLossIsPending,
      var state = recordRecoveryState,
      let source = commander.scriptState.savedRecordRecoverySource,
      let mission = commander.scriptState.instances[state.permission.mission],
      let player = commander.flightSimulation.player
    else { return false }
    let cause = scriptEventContext(mission)
    let held = Set(state.held)
    let fatal = screen == .gameOver && energy.isFinite && energy <= 0
    for (index, original) in source.originals.enumerated() {
      guard WayfarerRecordRecovery.aliases.indices.contains(index),
        !state.losses.contains(where: { $0.original == original.id })
      else { continue }
      let kind: WayfarerRecordRecoveryLossKind
      let actor: ActorIdentity
      let witness: [ScriptOwnedActor]
      if let marker = mission.ownedEncounters[WayfarerRecordRecovery.encounterID]?.actors[
        WayfarerRecordRecovery.aliases[index]], marker.presence == .destroyed,
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
      var loss = WayfarerRecordRecoveryLoss(
        original: original.id,
        operation: ScriptIdentity.uuid(
          "record-recovery-loss-v1:\(state.permission.operation):\(original.id):\(kind.rawValue)"
        ),
        authority: state.permission.operation,
        kind: kind, actor: actor, carrier: state.permission.carrier, collector: player,
        energy: kind == .hull ? energy : 0, escapePod: nil, marker: witness, context: cause,
        physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
      loss.authority = try WayfarerRecordRecovery.lossAuthority(loss)
      state.losses.append(loss)
    }
    guard state.losses.count > (mission.savedRecordRecovery?.losses.count ?? 0) else {
      return false
    }
    try retainRecordRecoveryLoss(state)
    nativeRecordRecoveryPending = nil
    return true
  }

  func recordRecoveryEscapePod() -> EquipmentPurchaseItem? {
    guard let state = recordRecoveryState, !state.held.isEmpty,
      let purchase = try? commander.purchaseSnapshot()
    else { return nil }
    return purchase.items.first { $0.node.key == "Escape Pod" && $0.location != nil }
  }

  /// Invoked inside the actual successful Escape Pod candidate after native pod consumption.
  mutating func loseRecordRecoveryOnEscape(pod: EquipmentPurchaseItem?) throws {
    guard var state = recordRecoveryState, !state.held.isEmpty else { return }
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
      var loss = WayfarerRecordRecoveryLoss(
        original: original,
        operation: ScriptIdentity.uuid(
          "record-recovery-loss-v1:\(state.permission.operation):\(original):escape"),
        authority: state.permission.operation,
        kind: .escape, actor: capture.actor, carrier: state.permission.carrier, collector: player,
        energy: energy, escapePod: pod, marker: [], context: context,
        physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
      loss.authority = try WayfarerRecordRecovery.lossAuthority(loss)
      state.losses.append(loss)
    }
    try retainRecordRecoveryLoss(state)
    nativeRecordRecoveryPending = nil
  }

  private mutating func retainRecordRecoveryLoss(_ state: WayfarerRecordRecoveryState) throws {
    guard var mission = commander.scriptState.instances[state.permission.mission],
      var source = commander.scriptState.savedRecordRecoverySource
    else { throw SaveError.invalidCommander }
    for loss in state.losses {
      guard let index = source.originals.firstIndex(where: { $0.id == loss.original }) else {
        throw SaveError.invalidCommander
      }
      source.originals[index].custody = .lost(loss.operation)
    }
    commander.scriptState.savedRecordRecoverySource = source
    if mission.outcome == .active {
      try finishRecordRecoveryMission(state, outcome: .failed)
    } else {
      mission.savedRecordRecovery = state
      mission.payloads = WayfarerRecordRecovery.payloads(
        state, outcome: mission.outcome, source: source)
      commander.scriptState.instances[mission.id] = mission
    }
  }
}

extension GameRuntime {
  func commitRecordRecoveryLoss() {
    guard game.recordRecoveryLossIsPending else { return }
    if game.screen == .gameOver, game.energy < 0 { return }
    guard let publish = scriptPublisher() else { return }
    var candidate = game
    do {
      guard try candidate.recordRecoveryLossIfNeeded() else { return }
      try publish(&candidate)
      game = candidate
    } catch { game.notify("SENN LOSS NOT SAVED - ORIGINAL CONDITION RETAINED FOR RETRY") }
  }
}

/// The observer alone creates this attempt-local, immutable two-ended identification.
final class WayfarerRecordRecoveryIdentificationPending: Sendable {
  let receipt: WayfarerRecordRecoveryIdentification
  fileprivate init(_ receipt: WayfarerRecordRecoveryIdentification) { self.receipt = receipt }
}

extension WayfarerRecordRecovery {
  static func identificationAuthority(_ receipt: borrowing WayfarerRecordRecoveryIdentification)
    throws -> UUID
  {
    let observations = try witnessHash(receipt.observations)
    return ScriptIdentity.uuid(
      "record-recovery-identification-authority-v1:\(receipt.operation):\(receipt.source):\(receipt.permission):\(receipt.original):\(observations)"
    )
  }
}

extension Game {
  /// Selection is descriptive. Only matched actual native start/end observations qualify.
  @inline(never)
  func recordRecoveryIdentificationSample() -> WayfarerRecordRecoveryObservation? {
    guard !paused, !docked, !playerEMPDisabled, screen == .front, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil,
      let state = recordRecoveryState, state.identification == nil, state.captures.isEmpty,
      state.losses.isEmpty, state.reception == nil,
      let source = commander.scriptState.savedRecordRecoverySource,
      let original = source.originals.first, original.custody == .cradle,
      let mission = commander.scriptState.instances[state.permission.mission],
      mission.outcome == .active, let carrier = commander.hullInstanceID,
      carrier == state.permission.carrier,
      let owner = commander.equipmentOwnerID, owner == source.owner.world,
      let player = commander.flightSimulation.player, player.entity == 0,
      player.system == SystemIdentity(galaxy: 0, system: 241),
      let selected = informationTargetBody, recordRecoveryAlias(selected) == "cdr-001",
      let actor = selected.physical?.identity, actor.system == player.system,
      actor.visit == player.visit,
      let core = commander.fittedEquipment(at: .targetingCore), commander.targetingTier != nil,
      let module = commander.fittedEquipment(at: .targetingSalvage),
      let inventory = try? commander.purchaseSnapshot(), inventory.activeHull == carrier,
      let coreItem = inventory.items.first(where: { $0.id == core.id }),
      let moduleItem = inventory.items.first(where: { $0.id == module.id }),
      selected.position.length > 0,
      selected.position.unit.dot(Vector3(0, 0, 1)) >= cos(2 * Double.pi / 180),
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 1500,
        radius: 0, includePlayer: false),
      contact.hit.target == .body(selected.id), (250...1500).contains(contact.hit.distance),
      let fixture = bodies.first(where: { recordRecoveryAlias($0) == "w05-cradle" }),
      let recorderMarker = recordRecoveryMarker(selected, mission: mission, alias: "cdr-001"),
      let fixtureMarker = recordRecoveryMarker(fixture, mission: mission, alias: "w05-cradle")
    else { return nil }
    return .init(
      original: original.id, permission: state.permission.operation, owner: owner, carrier: carrier,
      actor: actor, player: player, inventoryRevision: inventory.revision,
      equipment: [coreItem, moduleItem], markers: recorderMarker + fixtureMarker,
      targetPoint: selected.position, surfacePoint: contact.hit.point,
      surfaceDistance: contact.hit.distance,
      physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
  }

  @discardableResult
  mutating func retryRecordRecoveryIdentification() throws -> Bool {
    guard let pending = nativeRecordRecoveryIdentificationPending else { return false }
    let receipt = pending.receipt
    guard var state = recordRecoveryState, state.identification == nil,
      state.captures.isEmpty, state.losses.isEmpty, state.reception == nil,
      var mission = commander.scriptState.instances[state.permission.mission],
      mission.outcome == .active, receipt.permission == state.permission.operation,
      let end = receipt.observations.last,
      end.epoch == nativeStationRuntimeEpoch,
      commander.hullInstanceID == end.carrier,
      commander.equipmentInventory?.revision == end.inventoryRevision,
      commander.flightSimulation.player == end.player,
      bodies.contains(where: {
        $0.physical?.identity == end.actor && recordRecoveryAlias($0) == "cdr-001"
      })
    else {
      nativeRecordRecoveryIdentificationPending = nil
      return false
    }
    state.identification = receipt
    mission.savedRecordRecovery = state
    mission.milestones.insert(1)
    commander.scriptState.instances[mission.id] = mission
    nativeRecordRecoveryIdentificationPending = nil
    return true
  }
}

extension GameRuntime {
  func commitRecordRecoveryIdentification(start: WayfarerRecordRecoveryObservation?) {
    guard game.recordRecoveryState != nil else { return }
    if game.nativeRecordRecoveryIdentificationPending == nil {
      guard let start, let end = game.recordRecoveryIdentificationSample(),
        start.sameAuthority(as: end), end.physicalTime > start.physicalTime,
        end.physicalTime - start.physicalTime <= 0.1 + 1e-9,
        let state = game.recordRecoveryState,
        let source = game.commander.scriptState.savedRecordRecoverySource
      else { return }
      let operation = ScriptIdentity.uuid(
        "record-recovery-identification-v1:\(state.permission.operation):\(start.original)")
      var receipt = WayfarerRecordRecoveryIdentification(
        operation: operation, source: source.id, permission: state.permission.operation,
        original: start.original, authority: operation, observations: [start, end])
      guard let authority = try? WayfarerRecordRecovery.identificationAuthority(receipt) else {
        return
      }
      receipt.authority = authority
      game.nativeRecordRecoveryIdentificationPending = .init(receipt)
    }
    guard let publish = scriptPublisher() else { return }
    var candidate = game
    do {
      guard try candidate.retryRecordRecoveryIdentification() else {
        game.nativeRecordRecoveryIdentificationPending = nil
        return
      }
      try publish(&candidate)
      game = candidate
      game.notify("CDR-001 IDENTIFIED AT CRADLE - SEPARATELY RECOVER THE ORIGINAL")
    } catch {
      game.notify("RECORDER IDENTIFICATION NOT SAVED - NO PICKUP AUTHORITY")
    }
  }
}
